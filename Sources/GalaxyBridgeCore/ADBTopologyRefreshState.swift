import Foundation

/// Serializes periodic `adb devices` probes and lets the caller avoid
/// republishing an unchanged device snapshot. The probe itself remains in the
/// macOS transport layer; this value type keeps the lifecycle deterministic.
public struct ADBTopologyRefreshState: Sendable {
    private var isInFlight = false

    public init() {}

    @discardableResult
    public mutating func begin() -> Bool {
        guard !isInFlight else { return false }
        isInFlight = true
        return true
    }

    public mutating func finish() {
        isInFlight = false
    }

    public static func shouldPublish<T: Equatable>(previous: T, current: T) -> Bool {
        previous != current
    }

    /// A failed `adb devices` probe must not wipe the last good topology.
    /// Clearing rows looks like a permanent disconnect after Refresh.
    public static func rowsAfterProbeFailure<T>(previous: [T]) -> [T] {
        previous
    }
}
