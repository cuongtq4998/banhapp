import XCTVapor
@testable import App

/// New-device notice to the owner address only: FR-7, BR-13 (TC-B41 to B44).
final class NewDeviceNoticeTests: AdminDatabaseTestCase {
    private func notices() -> [EmailMessage] { mail.sent.filter { $0.kind == .newDeviceNotice } }

    private func signInOnly(_ email: String, installation: UUID, device: String = "iPhone (iOS 17.5)") async throws -> Reply {
        _ = try await requestCode(email)
        await app.services.background.drain()
        let reply = try await signIn(email, try XCTUnwrap(mail.lastCode(to: email)), installation: installation, device: device)
        await app.services.background.drain()
        clock.advance(31)
        return reply
    }

    func testOwnerOnANewPhoneSendsOneNoticeToTheOwnerAddressOnly() async throws {
        let owner = try await addAccount(.owner, "Chu Mau")
        let staff = try await addAccount(.staff)
        let reply = try await signInOnly(owner.email, installation: UUID(), device: "Pixel 8 (Android 14)")
        XCTAssertEqual(reply.status, .created)
        let sent = notices()
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sent[0].to, owner.email)
        XCTAssertTrue(sent[0].body.contains("Pixel 8 (Android 14)"))
        XCTAssertNil(sent[0].body.firstMatch(of: /[0-9]{6}/), "no code")
        XCTAssertFalse(mail.sent.contains { $0.to == staff.email })
    }

    func testNoNoticeForRenewalStaffOrAnInstallationWithALiveSession() async throws {
        let owner = try await addAccount(.owner, "Chu Mau"), staff = try await addAccount(.staff)
        let installation = UUID()
        let phone = try await signedIn(owner.email, installation: installation)
        await app.services.background.drain()
        XCTAssertEqual(notices().count, 1)
        _ = try await refresh(phone.refresh)
        _ = try await signedIn(staff.email)
        let second = try await signInOnly(owner.email, installation: installation)
        XCTAssertEqual(second.status, .created)
        XCTAssertEqual(notices().count, 1, "a live session already used this installation")
    }

    func testOwnerSignedOutAndBackInOnTheSamePhoneIsNewAgain() async throws {
        let owner = try await addAccount(.owner, "Chu Mau")
        let installation = UUID()
        let phone = try await signedIn(owner.email, installation: installation)
        _ = try await authed(.DELETE, "v1/admin/session", phone.access)
        _ = try await signInOnly(owner.email, installation: installation)
        XCTAssertEqual(notices().count, 2)
    }

    func testTwoPhonesGiveTwoNotices() async throws {
        let owner = try await addAccount(.owner, "Chu Mau")
        _ = try await signedIn(owner.email)
        _ = try await signedIn(owner.email)
        await app.services.background.drain()
        XCTAssertEqual(notices().map(\.to), [owner.email, owner.email])
    }

    func testFailingMailNeverBlocksTheSignIn() async throws {
        let owner = try await addAccount(.owner, "Chu Mau")
        _ = try await requestCode(owner.email)
        await app.services.background.drain()
        let code = try XCTUnwrap(mail.lastCode(to: owner.email))
        mail.failNext()
        let reply = try await signIn(owner.email, code)
        await app.services.background.drain()
        XCTAssertEqual(reply.status, .created)
        XCTAssertTrue(notices().isEmpty)
        XCTAssertEqual(mail.attempts, 3, "the code mail, then the notice and its one retry")
    }

    func testDeviceNameRules() async throws {
        let owner = try await addAccount(.owner, "Chu Mau")
        for (name, ok) in [(String(repeating: "x", count: 60), true), (String(repeating: "x", count: 61), false), ("", false),
                           ("Phone\r\nBcc: x@example.com", false), ("Phone\u{0}", false), ("<b>Phone</b>", true)] {
            _ = try await requestCode(owner.email)
            await app.services.background.drain()
            let reply = try await signIn(owner.email, try XCTUnwrap(mail.lastCode(to: owner.email)), device: name)
            XCTAssertEqual(reply.status == .created, ok, name)
            if !ok { XCTAssertEqual(reply.errorCode, "VALIDATION_FAILED", name) }
            clock.advance(31)
        }
    }

    func testSignInNeedsClientHeaders() async throws {
        let staff = try await addAccount(.staff)
        _ = try await requestCode(staff.email)
        await app.services.background.drain()
        let reply = try await send(.POST, "v1/auth/sessions", [
            "email": staff.email, "code": try XCTUnwrap(mail.lastCode(to: staff.email)),
            "installation_id": UUID().uuidString, "device_name": "Phone"
        ])
        XCTAssertEqual(reply.errorCode, "HEADER_INVALID")
        XCTAssertEqual(reply.status, .badRequest)
    }
}
