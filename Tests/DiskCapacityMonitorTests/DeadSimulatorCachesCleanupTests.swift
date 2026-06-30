import XCTest
@testable import DiskCapacityMonitor

final class DeadSimulatorCachesCleanupTests: XCTestCase {
    private var tempRoot: URL!
    private let fm = FileManager.default

    override func setUpWithError() throws {
        tempRoot = fm.temporaryDirectory
            .appendingPathComponent("dcm-sim-tests-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: tempRoot)
    }

    private func deadDir(forDevice uuid: String) -> URL {
        tempRoot
            .appendingPathComponent(uuid, isDirectory: true)
            .appendingPathComponent(DeadSimulatorCachesCleanup.deadRelativePath, isDirectory: true)
    }

    func testClearsDeadContentsButKeepsDeadDirectory() async throws {
        // Device A: a Dead dir containing a 2,000-byte payload.
        let deadA = deadDir(forDevice: "AAAA")
        try fm.createDirectory(at: deadA, withIntermediateDirectories: true)
        let payload = deadA.appendingPathComponent("App-XYZ/blob.bin")
        try fm.createDirectory(at: payload.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(count: 2_000).write(to: payload)

        // Device B: an empty Dead dir (should be skipped).
        let deadB = deadDir(forDevice: "BBBB")
        try fm.createDirectory(at: deadB, withIntermediateDirectories: true)

        // Device C: no Dead dir at all.
        try fm.createDirectory(
            at: tempRoot.appendingPathComponent("CCCC/data", isDirectory: true),
            withIntermediateDirectories: true
        )

        let result = await DeadSimulatorCachesCleanup(devicesRoot: tempRoot).run()

        XCTAssertGreaterThanOrEqual(result.bytesReclaimed, 2_000)
        XCTAssertTrue(result.errors.isEmpty)
        // Only device A had content cleared.
        XCTAssertTrue(result.summary.contains("1 simulator"))

        // The payload is gone, but the Dead directory itself remains.
        XCTAssertFalse(fm.fileExists(atPath: payload.path))
        XCTAssertTrue(fm.fileExists(atPath: deadA.path))
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: deadA.path).count, 0)
    }

    func testNoDevicesReportsNothing() async throws {
        let emptyRoot = tempRoot.appendingPathComponent("missing", isDirectory: true)
        let result = await DeadSimulatorCachesCleanup(devicesRoot: emptyRoot).run()
        XCTAssertEqual(result.bytesReclaimed, 0)
        XCTAssertTrue(result.errors.isEmpty)
    }
}
