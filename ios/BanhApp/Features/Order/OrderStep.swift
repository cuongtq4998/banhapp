/// The four screens of the order flow, S-5 to S-8 (UI document section 5).
enum OrderStep: Int, Hashable, CaseIterable {
    case cakes = 1
    case date
    case recipient
    case review

    /// "Step n of 4" counts from 1.
    var number: Int { rawValue }

    static var count: Int { allCases.count }
}
