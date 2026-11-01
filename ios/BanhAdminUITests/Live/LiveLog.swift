import Foundation

/// The backend console log: one-time codes (the console mail provider prints them) and the privacy audit.
enum LiveLog {
    /// Every code returned by `code(after:)` in this run; the audit looks for them in the log.
    nonisolated(unsafe) static var seenCodes: [String] = []

    static var size: UInt64 {
        ((try? FileManager.default.attributesOfItem(atPath: Live.logURL.path))?[.size] as? NSNumber)?.uint64Value ?? 0
    }

    private static func text(from offset: UInt64) -> String {
        guard let handle = try? FileHandle(forReadingFrom: Live.logURL) else { return "" }
        defer { try? handle.close() }
        try? handle.seek(toOffset: offset)
        return String(decoding: handle.readDataToEndOfFile(), as: UTF8.self)
    }

    /// The last code printed after `offset`, waiting up to `timeout` seconds for the mail line.
    static func code(after offset: UInt64, timeout: TimeInterval = 10) -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            let codes = text(from: offset).components(separatedBy: "\n").compactMap { line -> String? in
                guard let range = line.range(of: "Mã đăng nhập của bạn là ") else { return nil }
                let digits = line[range.upperBound...].prefix(6)
                return digits.count == 6 && digits.allSatisfy(\.isNumber) ? String(digits) : nil
            }
            if let last = codes.last { seenCodes.append(last); return last }
            Thread.sleep(forTimeInterval: 0.5)
        } while Date() < deadline
        return nil
    }

    /// Lines that break the privacy rule: any line that is not a console mail line and holds a customer
    /// value, a staff or owner address, or a six-digit code that was printed. `values` are the secrets.
    static func leaks(values: [String], codes: [String]) -> [String] {
        let lines = text(from: 0).components(separatedBy: "\n")
        var inMail = false
        var bad: [String] = []
        for line in lines {
            // A console mail is "[mail] <subject>" plus its body lines; the next log record starts with an escape code.
            if line.hasPrefix("[mail]") { inMail = true; continue }
            if inMail, !line.hasPrefix("\u{1B}") { continue }
            inMail = false
            let folded = fold(line)
            for value in values + codes where !value.isEmpty && folded.contains(fold(value)) {
                bad.append("\(value) in: \(line.prefix(200))")
            }
        }
        return bad
    }

    private static func fold(_ text: String) -> String { text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil) }
}
