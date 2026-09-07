import Foundation
import UIKit

/// Stable, anonymous device identifier used for credits and device-based data ownership.
///
/// Stored in the Keychain so it survives reinstalls. On first run it adopts the identifier existing
/// installs already used (`identifierForVendor`, or the UserDefaults fallback from earlier versions),
/// so nobody loses their free analyses or their tanks when upgrading.
enum DeviceIdentity {
    private static let keychainKey = "ReefBuddy.DeviceIdentity"
    private static let legacyDefaultsKey = "ReefBuddy.DeviceID"

    /// Resolved once per process; Keychain-backed.
    static let deviceId: String = resolve()

    private static func resolve() -> String {
        if let stored = KeychainManager.shared.loadString(for: keychainKey), !stored.isEmpty {
            return stored
        }
        let adopted = vendorIdentifierIfOnMainThread()
            ?? UserDefaults.standard.string(forKey: legacyDefaultsKey)
        let id = adopted ?? UUID().uuidString
        _ = KeychainManager.shared.saveString(id, for: keychainKey)
        return id
    }

    private static func vendorIdentifierIfOnMainThread() -> String? {
        guard Thread.isMainThread else { return nil }
        return MainActor.assumeIsolated { UIDevice.current.identifierForVendor?.uuidString }
    }
}
