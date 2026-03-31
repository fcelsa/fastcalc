import Foundation
import Testing
@testable import FastCalcCore

@Suite("DeletePressTracker")
struct DeletePressTrackerTests {
    // Due pressioni entro la soglia → doppia pressione
    @Test func doublePressWithinThreshold() {
        var tracker = DeletePressTracker(threshold: 0.7)
        let first = tracker.registerPress(at: Date(timeIntervalSince1970: 100))
        let second = tracker.registerPress(at: Date(timeIntervalSince1970: 100.4))

        #expect(first == false)
        #expect(second == true)
    }

    // Pressioni fuori dalla soglia non contano come doppie
    @Test func pressOutsideThresholdIsNotDouble() {
        var tracker = DeletePressTracker(threshold: 0.7)
        _ = tracker.registerPress(at: Date(timeIntervalSince1970: 100))
        let second = tracker.registerPress(at: Date(timeIntervalSince1970: 101.0))

        #expect(second == false)
    }
}
