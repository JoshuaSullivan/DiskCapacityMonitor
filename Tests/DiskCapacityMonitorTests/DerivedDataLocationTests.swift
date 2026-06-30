import XCTest
@testable import DiskCapacityMonitor

final class DerivedDataLocationTests: XCTestCase {
    private let fallback = URL(fileURLWithPath: "/Users/test/Library/Developer/Xcode/DerivedData",
                               isDirectory: true)

    private func sanitized(_ raw: String) -> URL {
        DerivedDataCleanup.sanitizedLocation(forRawValue: raw, fallback: fallback)
    }

    func testEmptyValueFallsBack() {
        XCTAssertEqual(sanitized(""), fallback)
        XCTAssertEqual(sanitized("   \n"), fallback)
    }

    func testDefaultKeywordFallsBack() {
        // "Default" is not an absolute path, so it must fall back.
        XCTAssertEqual(sanitized("Default"), fallback)
    }

    func testRelativePathFallsBack() {
        XCTAssertEqual(sanitized("Build/DerivedData"), fallback)
    }

    func testBareRootsAreRefused() {
        XCTAssertEqual(sanitized("/"), fallback)
        XCTAssertEqual(sanitized("/Users"), fallback)
        XCTAssertEqual(sanitized("/Volumes"), fallback)
    }

    func testValidAbsolutePathIsUsed() {
        let raw = "/Users/test/CustomDerived/Data"
        XCTAssertEqual(sanitized(raw).path, "/Users/test/CustomDerived/Data")
    }

    func testTrailingWhitespaceTrimmed() {
        let raw = "/Users/test/CustomDerived/Data\n"
        XCTAssertEqual(sanitized(raw).path, "/Users/test/CustomDerived/Data")
    }
}
