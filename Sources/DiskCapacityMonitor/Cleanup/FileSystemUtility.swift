import Foundation

/// Filesystem helpers shared by cleanup actions and the simulator service.
enum FileSystemUtility {
    /// Recursively sums the size of every file under `url`. Returns 0 for missing paths.
    /// Uses allocated size when available so the number better reflects real disk usage.
    static func directorySize(at url: URL) -> Int64 {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }

        if !isDir.boolValue {
            return fileSize(at: url)
        }

        let keys: Set<URLResourceKey> = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileSizeKey]
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [],
            errorHandler: { _, _ in true }
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let item as URL in enumerator {
            total += fileSize(at: item, keys: keys)
        }
        return total
    }

    private static func fileSize(
        at url: URL,
        keys: Set<URLResourceKey> = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileSizeKey]
    ) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: keys) else { return 0 }
        guard values.isRegularFile != false else { return 0 }
        if let allocated = values.totalFileAllocatedSize { return Int64(allocated) }
        if let size = values.fileSize { return Int64(size) }
        return 0
    }

    /// Deletes everything inside `directory` (but not the directory itself).
    /// - Returns: The number of bytes that were present before deletion.
    /// - Throws: The first error encountered while removing an entry.
    @discardableResult
    static func removeContents(of directory: URL) throws -> Int64 {
        let fm = FileManager.default
        guard fm.fileExists(atPath: directory.path) else { return 0 }

        let reclaimed = directorySize(at: directory)
        let children = try fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: []
        )
        var firstError: Error?
        for child in children {
            do {
                try fm.removeItem(at: child)
            } catch {
                if firstError == nil { firstError = error }
            }
        }
        if let firstError { throw firstError }
        return reclaimed
    }
}
