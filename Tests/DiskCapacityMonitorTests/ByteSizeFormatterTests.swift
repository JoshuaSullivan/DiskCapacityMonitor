import XCTest
@testable import DiskCapacityMonitor

final class ByteSizeFormatterTests: XCTestCase {
    func testWholeBytesHaveNoDecimal() {
        XCTAssertEqual(ByteSizeFormatter.string(fromBytes: 0), "0B")
        XCTAssertEqual(ByteSizeFormatter.string(fromBytes: 512), "512B")
        XCTAssertEqual(ByteSizeFormatter.string(fromBytes: 999), "999B")
    }

    func testDecimalUnitsUseOneFractionalDigit() {
        XCTAssertEqual(ByteSizeFormatter.string(fromBytes: 1_000), "1.0KB")
        XCTAssertEqual(ByteSizeFormatter.string(fromBytes: 200_200_000), "200.2MB")
        XCTAssertEqual(ByteSizeFormatter.string(fromBytes: 35_400_000_000), "35.4GB")
    }

    func testBinaryUnits() {
        XCTAssertEqual(ByteSizeFormatter.string(fromBytes: 1_024, binary: true), "1.0KB")
        XCTAssertEqual(ByteSizeFormatter.string(fromBytes: 1_073_741_824, binary: true), "1.0GB")
    }

    func testNegativeValues() {
        XCTAssertEqual(ByteSizeFormatter.string(fromBytes: -2_000_000_000), "-2.0GB")
    }
}
