import Foundation

public enum CompactActivityText {
    /// Keep score only; commentary, overs and targets belong in expanded content.
    public static func score(_ value: String) -> String {
        let score = value.components(separatedBy: "(")[0].trimmingCharacters(in: .whitespacesAndNewlines)
        return score.isEmpty ? "—" : String(score.prefix(14))
    }
    /// Only cricket has overs/target annotations here. Other sports may use
    /// parentheses as part of a score (for example a tennis tiebreak).
    public static func satelliteScore(_ value: String, cricket: Bool) -> String {
        let value = cricket ? value.components(separatedBy: "(")[0] : value
        let score = value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return score.isEmpty ? "—" : score
    }
}
