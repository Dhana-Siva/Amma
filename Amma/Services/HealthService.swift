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
    @Published private(set) var isAuthorized = false

    private let store = HKHealthStore()
    private let heartRateType = HKQuantityType(.heartRate)

    private init() {}

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async {
        guard isAvailable else { return }
        do {
            try await store.requestAuthorization(toShare: [], read: [heartRateType])
            isAuthorized = true
            await refresh()
        } catch {
            isAuthorized = false
        }
    }

    func refresh() async {
        guard isAvailable else { return }
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
