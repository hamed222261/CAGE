import Foundation
import HealthKit
import Combine

/// Read-only integration with Apple Health. CAGE never writes health samples.
final class HealthKitStepManager: ObservableObject {
    @Published private(set) var statusMessage = "Noch nicht verbunden"

    private let healthStore = HKHealthStore()
    private let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount)!
    private let optedInKey = "CAGE.HealthKit.StepCount.OptedIn"
    private var observerQuery: HKObserverQuery?

    var onTodayUpdate: ((Int, String, String) -> Void)?
    var onHistoryUpdate: (([[String: Any]]) -> Void)?
    var onStatus: ((String) -> Void)?

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            publishStatus("Apple Health ist auf diesem Gerät nicht verfügbar.")
            return
        }

        healthStore.requestAuthorization(toShare: [], read: [stepsType]) { [weak self] success, error in
            guard let self else { return }
            DispatchQueue.main.async {
                if let error {
                    self.publishStatus("Apple-Health-Anfrage fehlgeschlagen: \(error.localizedDescription)")
                    return
                }
                // HealthKit intentionally does not reveal whether read access was denied.
                UserDefaults.standard.set(true, forKey: self.optedInKey)
                self.publishStatus(success ? "Apple-Health-Freigabe angefragt. Prüfe bei Bedarf die Health-Einstellungen." : "Freigabe-Anfrage beendet. Prüfe die Health-Einstellungen.")
                self.startBackgroundObserver()
                self.refreshToday()
                self.syncHistory(days: 30)
            }
        }
    }

    func startIfPreviouslyEnabled() {
        guard UserDefaults.standard.bool(forKey: optedInKey) else { return }
        startBackgroundObserver()
    }

    private func startBackgroundObserver() {
        guard HKHealthStore.isHealthDataAvailable(), observerQuery == nil else { return }

        let query = HKObserverQuery(sampleType: stepsType, predicate: nil) { [weak self] _, completion, error in
            guard let self else {
                completion()
                return
            }
            if let error {
                self.publishStatus("HealthKit-Hintergrundupdate: \(error.localizedDescription)")
                completion()
                return
            }
            self.refreshToday {
                self.syncHistory(days: 7)
                completion()
            }
        }
        observerQuery = query
        healthStore.execute(query)
        healthStore.enableBackgroundDelivery(for: stepsType, frequency: .hourly) { [weak self] enabled, error in
            if let error {
                self?.publishStatus("Hintergrundaktualisierung konnte nicht aktiviert werden: \(error.localizedDescription)")
            } else if enabled {
                self?.publishStatus("Apple Health verbunden · Hintergrund-Sync aktiv")
            }
        }
    }

    func refreshToday(completion: (() -> Void)? = nil) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion?()
            return
        }
        let start = Calendar.current.startOfDay(for: Date())
        let end = Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: stepsType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, statistics, error in
            guard let self else {
                completion?()
                return
            }
            if let error {
                self.publishStatus("Schritte konnten nicht gelesen werden: \(error.localizedDescription)")
                completion?()
                return
            }
            let count = Int(statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
            let dateKey = Self.dayKey(Date())
            let stamp = ISO8601DateFormatter().string(from: Date())
            UserDefaults.standard.set(count, forKey: "CAGE.HealthKit.Steps.\(dateKey)")
            UserDefaults.standard.set(dateKey, forKey: "CAGE.HealthKit.LastDate")
            DispatchQueue.main.async {
                self.onTodayUpdate?(count, dateKey, stamp)
                completion?()
            }
        }
        healthStore.execute(query)
    }

    /// Backfills daily totals so the CAGE calendar can show the recent Apple Health history.
    func syncHistory(days: Int) {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -max(1, days - 1), to: today) ?? today
        var interval = DateComponents()
        interval.day = 1
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let query = HKStatisticsCollectionQuery(
            quantityType: stepsType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: today,
            intervalComponents: interval
        )
        query.initialResultsHandler = { [weak self] _, collection, error in
            guard let self, error == nil, let collection else {
                if let error { self?.publishStatus("Schrittverlauf konnte nicht gelesen werden: \(error.localizedDescription)") }
                return
            }
            var rows: [[String: Any]] = []
            collection.enumerateStatistics(from: start, to: Date()) { statistics, _ in
                let steps = Int(statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                rows.append(["date": Self.dayKey(statistics.startDate), "steps": steps, "updatedAt": ISO8601DateFormatter().string(from: Date())])
            }
            DispatchQueue.main.async {
                self.onHistoryUpdate?(rows)
            }
        }
        healthStore.execute(query)
    }

    private func publishStatus(_ message: String) {
        DispatchQueue.main.async {
            self.statusMessage = message
            self.onStatus?(message)
        }
    }

    private static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
