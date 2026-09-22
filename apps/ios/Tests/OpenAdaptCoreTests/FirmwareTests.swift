import XCTest
@testable import OpenAdaptCore

final class FirmwareTests: XCTestCase {
    func testTestedRevisionAndObservedPaddingAllowExistingKeyControl() throws {
        for data in [Data("2.4.3M".utf8), Data("2.4.3M".utf8) + Data(repeating: 0, count: 14)] {
            let report = try ShoeFirmware(data: data)
            XCTAssertEqual(report.version, "2.4.3M")
            XCTAssertTrue(report.supportsExistingKeyControl)
            XCTAssertNoThrow(try ShoeCrypto.verifyFirmware(data))
        }
    }
    func testOtherVersionsCanBeInspectedWithoutEnablingControl() throws {
        for version in ["2.3.0M", "2.4.2M", "3.0.0M", "unknown"] {
            let data = Data(version.utf8)
            let report = try ShoeFirmware(data: data)
            XCTAssertEqual(report.version, version)
            XCTAssertFalse(report.supportsExistingKeyControl)
            XCTAssertThrowsError(try ShoeCrypto.verifyFirmware(data))
        }
    }
    func testUnobservedPaddingDoesNotLoosenControlGate() throws {
        let data = Data("2.4.3M".utf8) + Data([0])
        XCTAssertEqual(try ShoeFirmware(data: data).version, "2.4.3M")
        XCTAssertFalse(try ShoeFirmware(data: data).supportsExistingKeyControl)
        XCTAssertThrowsError(try ShoeCrypto.verifyFirmware(data))
    }
    func testMalformedReportsAreRejected() {
        for data in [Data(), Data([0]), Data([255]), Data("2.4\n3M".utf8),
                     Data("2.4.3M\0junk".utf8), Data(repeating: 65, count: 65)] {
            XCTAssertThrowsError(try ShoeFirmware(data: data))
        }
    }
}
