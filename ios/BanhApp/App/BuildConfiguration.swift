import Foundation

/// Reads the values the build injects into Info.plist (`Config/Project.xcconfig`, `Config/Info.plist`).
enum BuildConfiguration {
    private static let apiBaseURLKey = "BanhAPIBaseURL"
    private static let versionKey = "CFBundleShortVersionString"
    private static let unknownVersion = "0"

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

    static func appVersion(in bundle: Bundle) -> String {
        bundle.object(forInfoDictionaryKey: versionKey) as? String ?? unknownVersion
    }
}
