import Foundation

public enum CompactActivityText {
    /// Keep score only; commentary, overs and targets belong in expanded content.
    public static func score(_ value: String) -> String {
        let score = value.components(separatedBy: "(")[0].trimmingCharacters(in: .whitespacesAndNewlines)
        return score.isEmpty ? "—" : String(score.prefix(14))
    }
}
