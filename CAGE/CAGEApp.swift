import SwiftUI
import UIKit

@main
struct CAGEApp: App {
    @UIApplicationDelegateAdaptor(CAGEAppDelegate.self) private var appDelegate
    @StateObject private var stepManager = HealthKitStepManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            CAGEWebContainer(stepManager: stepManager)
                .ignoresSafeArea()
                .preferredColorScheme(.dark)
                .onAppear {
                    stepManager.startIfPreviouslyEnabled()
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        stepManager.startIfPreviouslyEnabled()
                        stepManager.refreshToday()
                        stepManager.syncHistory(days: 30)
                    }
                }
        }
    }
}

final class CAGEAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // HealthKit observer delivery is registered by HealthKitStepManager after the user opts in.
        true
    }
}
