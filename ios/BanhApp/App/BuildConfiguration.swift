import Foundation

/// Reads the values the build injects into Info.plist (`Config/Project.xcconfig`, `Config/Info.plist`).
enum BuildConfiguration {
    private static let apiBaseURLKey = "BanhAPIBaseURL"
    private static let versionKey = "CFBundleShortVersionString"
    private static let unknownVersion = "0.0.0"
    private static let versionGroups = 3
    private static let versionGroupDigits = 5

    /// The API address. A missing or malformed value is a build mistake, so it stops the app at start
    /// instead of failing later on every request.
    static func apiBaseURL(in bundle: Bundle) -> URL {
        guard let text = bundle.object(forInfoDictionaryKey: apiBaseURLKey) as? String,
              let url = URL(string: text), url.scheme != nil, url.host != nil
        else {
            fatalError("Info.plist key \(apiBaseURLKey) must hold the API address; set API_BASE_URL in the xcconfig.")
        }
        return url
    }

    /// The `X-App-Version` header value (api.md section 1): three groups of 1 to 5 digits. The build
    /// setting may hold fewer groups ("1.0"), so missing ones are filled with 0 and anything that is
    /// not digits (a suffix like "-beta") makes the value unknown: `POST /v1/orders` rejects a bad header.
    static func appVersion(in bundle: Bundle) -> String {
        headerVersion(bundle.object(forInfoDictionaryKey: versionKey) as? String ?? unknownVersion)
    }

    static func headerVersion(_ raw: String) -> String {
        let groups = raw.split(separator: ".", omittingEmptySubsequences: false)
        let valid = (1...versionGroups).contains(groups.count) && groups.allSatisfy {
            (1...versionGroupDigits).contains($0.count) && $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber)
        }
        guard valid else { return unknownVersion }
        return (groups.map(String.init) + Array(repeating: "0", count: versionGroups - groups.count)).joined(separator: ".")
    }
}
