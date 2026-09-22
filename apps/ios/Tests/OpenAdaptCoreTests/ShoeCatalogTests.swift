import XCTest
@testable import OpenAdaptCore

final class ShoeCatalogTests: XCTestCase {
    func testRetailNamesAreDistinctAndIncludeJordan() {
        XCTAssertEqual(Set(ShoeModel.allCases.map(\.name)), Set([
            "Nike Adapt BB", "Nike Adapt BB 2.0", "Nike Adapt Huarache", "Nike Adapt Auto Max", "Air Jordan 11 Adapt"
        ]))
    }
    func testDefaultAliasesDoNotRepeatTheModelName() {
        for name in ["Auto Max", "Nike Adapt AutoMax", "Adapt Auto Max", "NIKE ADAPT AUTO MAX"] {
            XCTAssertTrue(ShoeModel.adaptAutoMax.isDefaultName(name))
        }
        XCTAssertFalse(ShoeModel.adaptAutoMax.isDefaultName("My everyday pair"))
        XCTAssertFalse(ShoeModel.adaptBB.isDefaultName("Nike Adapt BB 2.0"))
        XCTAssertTrue(ShoeModel.adaptBB2.isDefaultName("Nike Adapt BB2"))
        XCTAssertTrue(ShoeModel.jordan11Adapt.isDefaultName("Air Jordan XI Adapt"))
    }
    func testOnlyDocumentedBluetoothFamiliesAreInferred() {
        XCTAssertEqual(ShoeModel.detected(advertisedName: "004-TEST-001"), .adaptAutoMax)
        XCTAssertEqual(ShoeModel.detected(advertisedName: "002-TEST-001"), .adaptHuarache)
        XCTAssertEqual(ShoeModel.detected(advertisedName: "001-TEST-001"), .adaptBB)
        XCTAssertEqual(ShoeModel.detected(advertisedName: "005-TEST-001"), .adaptBB2)
        XCTAssertEqual(ShoeModel.detected(advertisedName: "006-TEST-001"), .jordan11Adapt)
        XCTAssertEqual(ShoeModel.detected(advertisedName: "007-TEST-001"), .jordan11Adapt)
        XCTAssertNil(ShoeModel.detected(advertisedName: "003-TEST-001"))
        XCTAssertNil(ShoeModel.detected(advertisedName: "004-not-a-product"))
        XCTAssertNil(ShoeModel.detected(advertisedName: "Nike Adapt Auto Max"))
    }
    func testManufacturerSideDoesNotDependOnUnknownFlagBits() throws {
        let prefix: [UInt8] = [0x78, 0, 0xaf, 0x28, 1, 2, 3, 4, 5]
        let left = try XCTUnwrap(ShoeAdvertisement(manufacturerData: Data(prefix + [2])))
        let right = try XCTUnwrap(ShoeAdvertisement(manufacturerData: Data(prefix + [1])))
        XCTAssertEqual(left.side, .left)
        XCTAssertEqual(right.side, .right)
        XCTAssertNotEqual(left.identity, right.identity)
        XCTAssertEqual(left, ShoeAdvertisement(manufacturerData: Data(prefix + [0xfe] + Array(repeating: 0, count: 12))))
        XCTAssertEqual(right, ShoeAdvertisement(manufacturerData: Data(prefix + [0xff])))
    }
    func testUnrecognizedOrTruncatedManufacturerDataHasNoSide() {
        XCTAssertNil(ShoeAdvertisement(manufacturerData: Data([0x78, 0, 0xaf, 0x28])))
        XCTAssertNil(ShoeAdvertisement(manufacturerData: Data([0x79, 0, 0xaf, 0x28, 1, 2, 3, 4, 5, 1])))
        XCTAssertNil(ShoeAdvertisement(manufacturerData: Data([0x78, 0, 0xab, 0x28, 1, 2, 3, 4, 5, 1])))
    }
}
