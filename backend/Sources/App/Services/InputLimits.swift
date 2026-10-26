/// Input-safety bounds that are fixed in code, not shop configuration
/// (ADR-0013 keeps only these out of the tables; they come from ADR-0009 and
/// the PRD).
enum InputLimits {
    /// Longest order note, in characters (FR-18). Also checked by the
    /// database (`customer_order.note`).
    static let noteMaxLength = 200
}
