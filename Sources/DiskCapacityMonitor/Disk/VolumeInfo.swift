import Foundation

/// Snapshot of a mounted volume's capacity at a moment in time.
struct VolumeInfo: Identifiable, Hashable {
    /// Stable identifier — the file-system path of the volume's mount point.
    let id: String
    let url: URL
    let name: String
    let totalCapacity: Int64
    let availableCapacity: Int64
    let isSystemVolume: Bool

    /// Fraction (0...1) of the volume that is free. Returns 0 for unknown totals.
    var fractionFree: Double {
        guard totalCapacity > 0 else { return 0 }
        return Double(availableCapacity) / Double(totalCapacity)
    }
}
