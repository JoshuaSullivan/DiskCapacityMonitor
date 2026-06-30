import Foundation

/// Result of running an external command.
struct ShellResult {
    let exitCode: Int32
    let standardOutput: String
    let standardError: String

    var succeeded: Bool { exitCode == 0 }
}

/// Thin wrapper around `Process` for invoking command-line tools (`xcrun`, `defaults`).
enum Shell {
    /// Runs `executable` with `arguments` and returns its captured output.
    /// - Throws: If the process fails to launch.
    @discardableResult
    static func run(_ executable: String, _ arguments: [String]) throws -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()

        // Drain both pipes concurrently: if either stdout or stderr fills its ~64 KB
        // buffer, the child blocks on write until we read it. Reading them sequentially
        // on one thread would deadlock when the not-yet-read pipe is the one that fills.
        var outData = Data()
        var errData = Data()
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "Shell.pipeReader", attributes: .concurrent)
        group.enter()
        queue.async {
            outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.enter()
        queue.async {
            errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.wait()
        process.waitUntilExit()

        return ShellResult(
            exitCode: process.terminationStatus,
            standardOutput: String(data: outData, encoding: .utf8) ?? "",
            standardError: String(data: errData, encoding: .utf8) ?? ""
        )
    }
}
