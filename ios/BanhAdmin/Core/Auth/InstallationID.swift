import Foundation
import UIKit

/// A random id created once per installation (ADR-0022 TQ-9). No hardware identifier is read.
nonisolated enum InstallationID {
    private static let key = "BanhAdminInstallationID"

    /// A missing id means a fresh install (UserDefaults go with the app, the Keychain does not): any
    /// token a deleted install left behind is removed before the new id is created (`onFirstStart`).
    static func current(defaults: UserDefaults = .standard, onFirstStart: () -> Void = {}) -> String {
        if let existing = defaults.string(forKey: key) { return existing }
        onFirstStart()
        let created = UUID().uuidString.lowercased()
        defaults.set(created, forKey: key)
        return created
    }

    /// `iPhone (iOS 17.5)`: the device model and system version, never a name the person gave (R-29).
    @MainActor
    static func deviceName(device: UIDevice? = nil) -> String {
        let device = device ?? .current
        return "\(device.model) (iOS \(device.systemVersion))"
    }
}
