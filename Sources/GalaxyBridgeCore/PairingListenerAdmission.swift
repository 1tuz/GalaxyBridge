import Foundation

/// Admits NWListener callbacks only for the listener generation currently armed
/// by PairingCoordinator.start(). Stale cancel/fail events from a replaced
/// listener must not kill a fresh re-pair session.
public enum PairingListenerAdmission: Sendable {
    public static func admits(eventGeneration: UInt64, armedGeneration: UInt64) -> Bool {
        eventGeneration == armedGeneration && armedGeneration != 0
    }
}
