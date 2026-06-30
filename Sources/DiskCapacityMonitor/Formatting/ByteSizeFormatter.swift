import Foundation

/// Formats raw byte counts into compact, human-readable strings with exactly one
/// fractional digit for KB and larger (e.g. `35.4GB`, `200.2MB`). Whole bytes are
/// shown without a decimal (e.g. `512B`).
///
/// Pure value type with no side effects so it can be unit-tested directly.
enum ByteSizeFormatter {
    private static let units = ["B", "KB", "MB", "GB", "TB", "PB", "EB"]

    /// - Parameters:
    ///   - bytes: The number of bytes to format.
    ///   - binary: When `true`, uses base-1024 units; otherwise base-1000 (the default,
    ///     matching Finder's display convention).
    static func string(fromBytes bytes: Int64, binary: Bool = false) -> String {
        let base = binary ? 1024.0 : 1000.0
        var value = Double(bytes)
        let negative = value < 0
        value = abs(value)

        var index = 0
        while value >= base && index < units.count - 1 {
            value /= base
            index += 1
        }

        let sign = negative ? "-" : ""
        if index == 0 {
            return "\(sign)\(Int(value.rounded()))B"
        }
        return String(format: "%@%.1f%@", sign, value, units[index])
    }
}
