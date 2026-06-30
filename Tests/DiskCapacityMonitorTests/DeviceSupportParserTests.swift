import XCTest
@testable import DiskCapacityMonitor

final class DeviceSupportParserTests: XCTestCase {
    func testParsesVersionAndBuildWithoutModel() {
        let entry = DeviceSupportParser.parse("16.4 (20E247)")
        XCTAssertEqual(entry?.deviceModel, nil)
        XCTAssertEqual(entry?.version, [16, 4])
        XCTAssertEqual(entry?.build, "20E247")
    }

    func testParsesDeviceModelPrefix() {
        let entry = DeviceSupportParser.parse("iPhone14,2 16.4 (20E247)")
        XCTAssertEqual(entry?.deviceModel, "iPhone14,2")
        XCTAssertEqual(entry?.version, [16, 4])
    }

    func testParsesThreeComponentVersion() {
        let entry = DeviceSupportParser.parse("16.4.1 (20E772a)")
        XCTAssertEqual(entry?.version, [16, 4, 1])
    }

    func testUnparseableNameReturnsNil() {
        XCTAssertNil(DeviceSupportParser.parse("Some random folder"))
    }

    func testGenericGroupKeepsNewestOnly() {
        let names = ["15.5 (19F70)", "16.4 (20E247)", "17.0 (21A328)"]
        let deleted = Set(DeviceSupportParser.supersededFolders(in: names))
        XCTAssertEqual(deleted, ["15.5 (19F70)", "16.4 (20E247)"])
    }

    func testPerDeviceGroupingKeepsNewestPerModel() {
        let names = [
            "iPhone14,2 16.0 (a)",
            "iPhone14,2 17.0 (b)",
            "iPad13,1 15.0 (c)",
        ]
        let deleted = DeviceSupportParser.supersededFolders(in: names)
        XCTAssertEqual(deleted, ["iPhone14,2 16.0 (a)"])
    }

    func testThreeComponentVersionOutranksTwoComponent() {
        let names = ["16.4 (a)", "16.4.1 (b)"]
        XCTAssertEqual(DeviceSupportParser.supersededFolders(in: names), ["16.4 (a)"])
    }

    func testSingleEntryIsNeverDeleted() {
        XCTAssertTrue(DeviceSupportParser.supersededFolders(in: ["16.4 (20E247)"]).isEmpty)
    }
}
