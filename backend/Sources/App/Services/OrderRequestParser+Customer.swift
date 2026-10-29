import Foundation
import BanhContracts

extension OrderRequestParser {
    struct Customer {
        let name: String
        let phone: String
        let address: String
        let districtID: UUID
    }

    private static let customerKeys: Set<String> = ["name", "phone", "address", "district_id"]

    mutating func readCustomer(_ value: JSONValue?) -> Customer? {
        guard case .object(let object)? = value else {
            fail(OrderFieldError.invalid(Name.customer, code: "CUSTOMER_INVALID"))
            return nil
        }
        rejectUnknown(object, allowed: Self.customerKeys, prefix: Name.customer + ".")
        let name = readText(
            object["name"], minLength: 1, maxLength: OrderText.nameMaxLength, allowsNewline: false,
            missing: OrderFieldError.nameRequired, invalid: OrderFieldError.invalid(Name.customerName, code: "NAME_INVALID")
        )
        let phone = readPhone(object["phone"])
        let address = readText(
            object["address"], minLength: 1, maxLength: OrderText.addressMaxLength, allowsNewline: true,
            missing: OrderFieldError.addressRequired, invalid: OrderFieldError.invalid(Name.customerAddress, code: "ADDRESS_INVALID")
        )
        let districtID = readDistrict(object["district_id"])
        guard let name, let phone, let address, let districtID else { return nil }
        return Customer(name: name, phone: phone, address: address, districtID: districtID)
    }

    mutating func readNote(_ value: JSONValue?) -> String? {
        switch value {
        case nil, .null?:
            return nil
        case .string(let raw)?:
            switch OrderText.normalise(raw, minLength: 0, maxLength: InputLimits.noteMaxLength, allowsNewline: true) {
            case .success(let text): return text.isEmpty ? nil : text
            case .failure(.tooLong): fail(OrderFieldError.noteTooLong)
            case .failure: fail(OrderFieldError.invalid(Name.note, code: "NOTE_INVALID"))
            }
            return nil
        default:
            fail(OrderFieldError.invalid(Name.note, code: "NOTE_INVALID"))
            return nil
        }
    }

    /// A missing, null or blank value is "required"; any other problem is "invalid".
    private mutating func readText(
        _ value: JSONValue?, minLength: Int, maxLength: Int, allowsNewline: Bool,
        missing: OrderFieldError.Entry, invalid: OrderFieldError.Entry
    ) -> String? {
        guard case .string(let raw)? = value else {
            fail(value == nil || value == .null ? missing : invalid)
            return nil
        }
        switch OrderText.normalise(raw, minLength: minLength, maxLength: maxLength, allowsNewline: allowsNewline) {
        case .success(let text): return text
        case .failure(.empty): fail(missing)
        case .failure: fail(invalid)
        }
        return nil
    }

    private mutating func readPhone(_ value: JSONValue?) -> String? {
        guard case .string(let raw)? = value else {
            fail(value == nil || value == .null ? OrderFieldError.phoneRequired : OrderFieldError.phoneInvalid)
            return nil
        }
        if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fail(OrderFieldError.phoneRequired)
            return nil
        }
        guard let phone = PhoneNumber.normalise(raw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            fail(OrderFieldError.phoneInvalid)
            return nil
        }
        return phone
    }

    private mutating func readDistrict(_ value: JSONValue?) -> UUID? {
        if value == nil || value == .null {
            fail(OrderFieldError.districtRequired)
            return nil
        }
        return readUUID(value, field: Name.customerDistrictID, code: "DISTRICT_INVALID")
    }
}
