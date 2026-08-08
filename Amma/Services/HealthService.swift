import Foundation
import HealthKit

/// Reads the most recent heart rate sample from HealthKit — sourced from
/// whatever's actually writing it on the parent's phone, almost always a
/// paired Apple Watch syncing through the Health app. Read-only: Amma never
/// writes to Health, and never needs a watchOS companion app of its own,
/// since a paired Watch already syncs into HealthKit on the phone.
@MainActor
final class HealthService: ObservableObject {
    static let shared = HealthService()

    @Published private(set) var latestBPM: Int?
    @Published private(set) var lastUpdated: Date?
    // HealthKit deliberately never reports back whether *read* access was
    // granted or denied — Apple's privacy design has
    // `authorizationStatus(for:)` always read .notDetermined for read-only
    // types even after the prompt, specifically so apps can't detect a
    // "denied" read and pester the user about it. So this tracks only
    // whether we've ever asked, not what the answer was; if it was denied,
    // refresh() just silently keeps finding no samples, which reads fine
    // as "no reading yet" rather than a broken permission state, and we
    // don't re-show the "Connect Apple Watch" prompt every single launch.
    @Published private(set) var hasRequestedAccess: Bool {
        didSet { UserDefaults.standard.set(hasRequestedAccess, forKey: "healthAccessRequested") }
    }

    private let store = HKHealthStore()
    private let heartRateType = HKQuantityType(.heartRate)

    private init() {
        hasRequestedAccess = UserDefaults.standard.bool(forKey: "healthAccessRequested")
    }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async {
        guard isAvailable else { return }
        hasRequestedAccess = true
        try? await store.requestAuthorization(toShare: [], read: [heartRateType])
        await refresh()
    }

    func refresh() async {
        guard isAvailable, hasRequestedAccess else { return }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let sample = await withCheckedContinuation { (continuation: CheckedContinuation<HKQuantitySample?, Never>) in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                continuation.resume(returning: samples?.first as? HKQuantitySample)
            }
            store.execute(query)
        }
        guard let sample else { return }
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        latestBPM = Int(sample.quantity.doubleValue(for: bpmUnit).rounded())
        lastUpdated = sample.endDate
    }
}
