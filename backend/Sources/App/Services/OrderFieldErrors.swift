import BanhContracts

/// Field-level errors of `VALIDATION_FAILED` on `POST /v1/orders` (api.md
/// section 5). The message keys named in the catalogue are used where the UI
/// has a text for them; every other field problem shows `ERR_SERVER`.
enum OrderFieldError {
    typealias Entry = APIErrorResponse.FieldError

    enum Name {
        static let items = "items"
        static let deliveryDate = "delivery_date"
        static let slotID = "slot_id"
        static let customer = "customer"
        static let customerName = "customer.name"
        static let customerPhone = "customer.phone"
        static let customerAddress = "customer.address"
        static let customerDistrictID = "customer.district_id"
        static let note = "note"
        static let expectedTotal = "expected_total_vnd"
    }

    /// A field whose value is missing, of the wrong type or out of range:
    /// `<FIELD>_INVALID` with the generic key.
    static func invalid(_ field: String, code: String) -> Entry {
        Entry(field: field, code: code, messageKey: APIErrorCode.genericMessageKey)
    }

    static func unknown(_ field: String) -> Entry { invalid(field, code: "FIELD_UNKNOWN") }

    static let nameRequired = Entry(field: Name.customerName, code: "NAME_REQUIRED", messageKey: "ERR_NAME_REQUIRED")
    static let phoneRequired = Entry(field: Name.customerPhone, code: "PHONE_REQUIRED", messageKey: "ERR_PHONE_REQUIRED")
    static let phoneInvalid = Entry(field: Name.customerPhone, code: "PHONE_INVALID", messageKey: "ERR_PHONE_INVALID")
    static let addressRequired = Entry(field: Name.customerAddress, code: "ADDRESS_REQUIRED", messageKey: "ERR_ADDRESS_REQUIRED")
    static let districtRequired = Entry(field: Name.customerDistrictID, code: "DISTRICT_REQUIRED", messageKey: "ERR_DISTRICT_REQUIRED")
    static let noteTooLong = Entry(field: Name.note, code: "NOTE_TOO_LONG", messageKey: "ERR_NOTE_MAX")
}
