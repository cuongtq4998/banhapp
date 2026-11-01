import Foundation
import UIKit

/// Owner calls that bypass the UI: the second sign-in, the cake upload (the system photo picker cannot be
/// driven by a UI test) and the staff deactivation (one phone holds one session, so the owner cannot be
/// signed in on the simulator while the staff member is).
enum LiveOwnerAPI {
    /// Requests a code, reads it from the backend log and signs in. Returns the access token.
    static func signIn(_ email: String) -> String? {
        let offset = LiveLog.size
        let requested = LiveBackend.send("POST", "/v1/auth/code-requests", json: ["email": email])
        guard requested.status == 202, let code = LiveLog.code(after: offset) else { return nil }
        let session = LiveBackend.send("POST", "/v1/auth/sessions", json: [
            "email": email, "code": code, "installation_id": UUID().uuidString, "device_name": "iPhone (iOS 18.0)",
        ])
        return session.json["access_token"] as? String
    }

    /// A 600 x 400 picture made in code (no binary file in the repository).
    static func jpeg() -> Data {
        let size = CGSize(width: 600, height: 400)
        return UIGraphicsImageRenderer(size: size).jpegData(withCompressionQuality: 0.8) { context in
            UIColor(red: 0.9, green: 0.6, blue: 0.2, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.white.setFill()
            context.fill(CGRect(x: 100, y: 100, width: 400, height: 200))
        }
    }

    static func addCake(token: String, name: String, description: String, price: Int) -> LiveResponse {
        let boundary = "live-\(UUID().uuidString)"
        var body = Data()
        func field(_ key: String, _ value: String) {
            body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(key)\"\r\n\r\n\(value)\r\n".utf8))
        }
        field("name", name)
        field("description", description)
        field("price_vnd", String(price))
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"image\"; filename=\"cake.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n".utf8))
        body.append(jpeg())
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        return LiveBackend.send("POST", "/v1/owner/cakes", token: token, headers: ["Content-Type": "multipart/form-data; boundary=\(boundary)"], body: body)
    }

    /// Finds the staff account by its address and sets `is_active`.
    static func setStaffActive(token: String, email: String, active: Bool) -> LiveResponse {
        let list = LiveBackend.send("GET", "/v1/owner/staff", token: token).json["accounts"] as? [[String: Any]] ?? []
        guard let id = list.first(where: { $0["email"] as? String == email })?["account_id"] as? String
        else { return LiveResponse(status: 404, body: Data("no such staff".utf8)) }
        return LiveBackend.send("PATCH", "/v1/owner/staff/\(id)", token: token, json: ["is_active": active])
    }

    static func signOut(token: String) { _ = LiveBackend.send("DELETE", "/v1/admin/session", token: token) }
}
