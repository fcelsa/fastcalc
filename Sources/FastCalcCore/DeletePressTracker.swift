import Foundation

public struct DeletePressTracker: Sendable {
    public let threshold: TimeInterval
    private var lastPressDate: Date?

    public init(threshold: TimeInterval = 0.7) {
        self.threshold = threshold
        self.lastPressDate = nil
    }

    public mutating func registerPress(at now: Date = Date()) -> Bool {
        defer { lastPressDate = now }
        guard let previous = lastPressDate else {
            return false
        }
        return now.timeIntervalSince(previous) <= threshold
    }

    public mutating func reset() {
        lastPressDate = nil
    }
}
