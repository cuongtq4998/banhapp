import BanhCore
import Foundation
import Observation

/// S-A13 (staff sheet) and the sign-out buttons of the owner's Settings tab (FR-2, FR-4).
@Observable
final class AccountViewModel {
    let user: SignedInUser
    var toast: String?
    var showsSignOutOthers = false
    var showsSignOut = false
    private(set) var isBusy = false
    private(set) var successCount = 0

    private let api: any AccountAPI
    private let onSignOut: () -> Void

    init(user: SignedInUser, api: any AccountAPI, onSignOut: @escaping () -> Void) {
        self.user = user
        self.api = api
        self.onSignOut = onSignOut
    }

    var roleText: LocalizedStringResource {
        user.account.role == .owner ? AStrings.roleOwner : AStrings.roleStaff
    }

    /// Other phones fail their next request with 401 (api/06 10.6); this phone stays signed in.
    func signOutOthers() async {
        showsSignOutOthers = false
        isBusy = true
        defer { isBusy = false }
        do {
            try await api.signOutOthers()
            successCount += 1
            toast = String(localized: AStrings.signOutOthersDone)
        } catch {
            guard !(error is SessionEnded) else { return }
            toast = String(localized: (error as? APIError)?.isConnectivity == true ? AStrings.offlineSave : AStrings.errGeneric)
        }
    }

    /// Clears this phone at once; the server is told afterwards (offline: retried, TQ-D6).
    func signOut() {
        showsSignOut = false
        onSignOut()
    }
}
