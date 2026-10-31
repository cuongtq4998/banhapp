import Foundation
import XCTest
import XCTVapor
import NIOConcurrencyHelpers
@testable import AppUnderTest

/// Minimal JSON tree for the slice 1 contract checks. Own type so the checks
/// can tell an integer from a boolean and from a float (api.md section 3).
enum J: Decodable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([J])
    case object([String: J])

    init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Int.self) { self = .int(v) }
        else if let v = try? c.decode(Double.self) { self = .double(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([J].self) { self = .array(v) }
        else { self = .object(try c.decode([String: J].self)) }
    }

    static func parse(_ data: Data) throws -> J { try JSONDecoder().decode(J.self, from: data) }

    var object: [String: J]? { if case .object(let o) = self { return o }; return nil }
    var array: [J]? { if case .array(let a) = self { return a }; return nil }
    var string: String? { if case .string(let s) = self { return s }; return nil }
    var int: Int? { if case .int(let i) = self { return i }; return nil }

    subscript(key: String) -> J? { object?[key] }

    /// Every string in the tree (keys and values), for text scans.
    var allText: [String] {
        switch self {
        case .string(let s): return [s]
        case .array(let a): return a.flatMap(\.allText)
        case .object(let o): return o.flatMap { [$0.key] + $0.value.allText }
        default: return []
        }
    }
}

/// One finished response, detached from the tester so it can leave the closure.
struct Reply: Sendable {
    let status: HTTPResponseStatus
    let headers: HTTPHeaders
    let body: Data
    var text: String { String(decoding: body, as: UTF8.self) }
    var json: J? { try? J.parse(body) }
    var errorCode: String? { json?["error"]?["code"]?.string }
    func header(_ name: String) -> String? { headers.first(name: name) }
}

/// Invariant: every access to `value` goes through `lock`.
private final class Box: @unchecked Sendable {
    private let lock = NIOLock()
    private var value: Reply?
    func set(_ r: Reply) { lock.withLock { value = r } }
    func get() -> Reply? { lock.withLock { value } }
}

extension Application {
    /// Sends one request through the in-memory tester and returns the reply.
    func qaSend(_ method: HTTPMethod, _ path: String, headers: HTTPHeaders = [:], body: ByteBuffer? = nil) async throws -> Reply {
        let box = Box()
        try await self.test(method, path, headers: headers, body: body) { res async throws in
            box.set(Reply(status: res.status, headers: res.headers, body: Data(res.body.readableBytesView)))
        }
        return try XCTUnwrap(box.get(), "no response for \(method) \(path)")
    }
}
