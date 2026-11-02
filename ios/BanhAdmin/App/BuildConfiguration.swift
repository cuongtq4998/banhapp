import Foundation

/// Reads the values the build injects into Info.plist (`Config/Project.xcconfig`, `Config/Info.plist`).
enum BuildConfiguration {
    private static let apiBaseURLKey = "BanhAPIBaseURL"
    private static let versionKey = "CFBundleShortVersionString"
    private static let unknownVersion = "0.0.0"

    /// The API address. A missing or malformed value is a build mistake, so it stops the app at start.
    static func apiBaseURL(in bundle: Bundle) -> URL {
        guard let text = bundle.object(forInfoDictionaryKey: apiBaseURLKey) as? String,
              let url = URL(string: text), url.scheme != nil, url.host != nil
        else {
            fatalError("Info.plist key \(apiBaseURLKey) must hold the API address; set API_BASE_URL in the xcconfig.")
        }
        return url
    }

    /// The `X-App-Version` header value: three groups of 1 to 5 digits (api/05 section 9).
    static func appVersion(in bundle: Bundle) -> String {
        headerVersion(bundle.object(forInfoDictionaryKey: versionKey) as? String ?? unknownVersion)
    }

    static func headerVersion(_ raw: String) -> String {
        let groups = raw.split(separator: ".", omittingEmptySubsequences: false)
        let valid = (1...3).contains(groups.count) && groups.allSatisfy {
            (1...5).contains($0.count) && $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber)
        }
        guard valid else { return unknownVersion }
        return (groups.map(String.init) + Array(repeating: "0", count: 3 - groups.count)).joined(separator: ".")
    }
}
