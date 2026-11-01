import BanhCore
import Foundation

/// Server answers of the cake form mapped to field messages, banners and toasts.
extension CakeFormViewModel {
    func apply(_ error: Error) {
        guard !(error is SessionEnded) else { return }
        guard let failure = error as? APIError else { return banner = String(localized: AStrings.errGeneric) }
        if failure.isConnectivity { return banner = String(localized: AStrings.offlineSave) }
        switch failure.code {
        case "CAKE_LIMIT_REACHED": banner = String(localized: AStrings.errCakesFull)
        case "LAST_ACTIVE_CAKE":
            isActive = original?.isActive ?? true
            flash(String(localized: AStrings.errLastCake))
        case "IMAGE_TOO_LARGE": errors["image"] = String(localized: AStrings.errImgSize)
        case "NOT_FOUND": isGone = true
        case "VALIDATION_FAILED" where !failure.fieldProblems.isEmpty: apply(fields: failure.fieldProblems)
        default: banner = String(localized: isAdd ? AStrings.errUpload : AStrings.errGeneric)
        }
    }

    func apply(fields: [FieldProblem]) {
        var found: [String: String] = [:]
        for problem in fields {
            switch (problem.field, problem.code) {
            case ("name", "NAME_TAKEN"): found["name"] = String(localized: AStrings.errCakeNameDup)
            case ("name", _): found["name"] = FieldRules.server(problem, AStrings.fCakeName, max: 100)
            case ("description", _): found["description"] = FieldRules.server(problem, AStrings.fCakeDesc, max: 300)
            case ("price_vnd", _): found["price_vnd"] = FieldRules.server(problem, AStrings.fPrice, range: 1...100_000_000)
            case ("image", "IMAGE_REQUIRED"): found["image"] = String(localized: AStrings.errImgRequired)
            case ("image", "IMAGE_TYPE_UNSUPPORTED"): found["image"] = String(localized: AStrings.errImgType)
            case ("image", _): found["image"] = String(localized: AStrings.errImgRead)
            default: banner = String(localized: AStrings.errGeneric)
            }
        }
        errors = found
        let order = [("name", AdminOwnerID.cakeName), ("description", AdminOwnerID.cakeDesc), ("price_vnd", AdminOwnerID.cakePrice)]
        focusRequest = order.first { found[$0.0] != nil }?.1
    }
}
