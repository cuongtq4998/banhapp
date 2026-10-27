import Foundation

/// Typed access to a plain dictionary of variables.
struct EnvironmentVariables {
    private let variables: [String: String]

    init(_ variables: [String: String]) {
        self.variables = variables
    }

    /// Trimmed of all whitespace and newlines (a value pasted into a host
    /// console or read from a file often ends with one); empty counts as unset.
    func value(_ key: String) -> String? {
        guard let raw = variables[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        return raw
    }

    func stage() throws -> AppConfig.Stage {
        guard let text = value(AppConfig.Key.appEnv) else { throw AppConfig.Failure.missing(AppConfig.Key.appEnv) }
        guard let stage = AppConfig.Stage(rawValue: text) else { throw AppConfig.Failure.invalid(AppConfig.Key.appEnv) }
        return stage
    }
}
