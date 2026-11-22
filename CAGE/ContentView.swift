import SwiftUI
import WebKit

struct CAGEWebContainer: View {
    @ObservedObject var stepManager: HealthKitStepManager

    var body: some View {
        CAGEWebView(stepManager: stepManager)
            .background(Color(red: 7/255, green: 17/255, blue: 28/255))
    }
}

struct CAGEWebView: UIViewRepresentable {
    @ObservedObject var stepManager: HealthKitStepManager

    func makeCoordinator() -> Coordinator {
        Coordinator(stepManager: stepManager)
    }

    func makeUIView(context: Context) -> WKWebView {
        let content = WKUserContentController()
        content.add(context.coordinator, name: "cageSteps")
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = content
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 7/255, green: 17/255, blue: 28/255, alpha: 1)
        webView.scrollView.backgroundColor = webView.backgroundColor
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        let coordinator = context.coordinator
        stepManager.onTodayUpdate = { [weak coordinator] steps, date, updatedAt in
            coordinator?.sendToday(steps: steps, date: date, updatedAt: updatedAt)
        }
        stepManager.onHistoryUpdate = { [weak coordinator] rows in
            coordinator?.sendHistory(rows)
        }
        stepManager.onStatus = { [weak coordinator] message in
            coordinator?.sendStatus(message)
        }

        if let htmlURL = Bundle.main.url(forResource: "CAGE", withExtension: "html") {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        } else {
            let errorHTML = "<html><body style='background:#07111c;color:white;font:16px -apple-system;padding:24px'>CAGE.html fehlt im App-Bundle.</body></html>"
            webView.loadHTMLString(errorHTML, baseURL: nil)
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "cageSteps")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        weak var webView: WKWebView?
        private let stepManager: HealthKitStepManager

        init(stepManager: HealthKitStepManager) {
            self.stepManager = stepManager
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any], let action = body["action"] as? String else { return }
            switch action {
            case "requestPermission":
                stepManager.requestAuthorization()
            case "refresh":
                stepManager.startIfPreviouslyEnabled()
                stepManager.refreshToday()
                stepManager.syncHistory(days: 30)
            default:
                break
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("window.CAGEHealthKitSteps && window.CAGEHealthKitSteps.nativeReady();")
        }

        func sendToday(steps: Int, date: String, updatedAt: String) {
            send(function: "receive", object: ["steps": steps, "date": date, "updatedAt": updatedAt])
        }

        func sendHistory(_ rows: [[String: Any]]) {
            guard let data = try? JSONSerialization.data(withJSONObject: rows),
                  let json = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                self.webView?.evaluateJavaScript("window.CAGEHealthKitSteps && window.CAGEHealthKitSteps.receiveHistory(\(json));")
            }
        }

        func sendStatus(_ message: String) {
            send(function: "receive", object: ["status": message, "updatedAt": ISO8601DateFormatter().string(from: Date())])
        }

        private func send(function: String, object: [String: Any]) {
            guard let data = try? JSONSerialization.data(withJSONObject: object),
                  let json = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                self.webView?.evaluateJavaScript("window.CAGEHealthKitSteps && window.CAGEHealthKitSteps.\(function)(\(json));")
            }
        }
    }
}
