import XCTest
@testable import OpenAdaptCore

final class PairingExportTests: XCTestCase {
    func testExportMatchesOmarchyFixtureAndRetainsUnknownCalibration() throws {
        let pair = ShoePair(id: "pair-synthetic-export", name: "Synthetic Auto Max", shoes: [
            "left": credential(.left), "right": credential(.right)
        ])
        let exported = try PairingExport.encode(pair)
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../omarchy/tests/fixtures/iphone-pairing.synthetic.json")
        XCTAssertEqual(try JSONSerialization.jsonObject(with: exported) as? NSDictionary,
                       try JSONSerialization.jsonObject(with: Data(contentsOf: fixture)) as? NSDictionary)
        XCTAssertEqual(try ProfileImport.decode(exported), [pair])
        XCTAssertFalse(try XCTUnwrap(ProfileImport.decode(exported).first).credential(.left).hasFitCalibration)
    }

    func testIncompleteOrUnverifiedPairCannotBeExported() {
        XCTAssertThrowsError(try PairingExport.encode(ShoePair(id: "partial", name: "Partial",
            shoes: ["left": credential(.left)])))
        var row = credential(.right)
        row = ShoeCredential(profile: row.profile, credentialStatus: "candidate", advertisedName: row.advertisedName,
            keyHex: row.keyHex, fitMaximum: 0, address: "", peripheralID: row.peripheralID, shoeIdentity: row.shoeIdentity)
        XCTAssertThrowsError(try PairingExport.encode(ShoePair(id: "candidate", name: "Candidate",
            shoes: ["left": credential(.left), "right": row])))
    }

    func testLegacyExportPreservesVerifiedAddressesAndCalibration() throws {
        let pair = ShoePair(id: "legacy", name: "Legacy", shoes: Dictionary(uniqueKeysWithValues: ShoeSide.allCases.map { side in
            (side.rawValue, ShoeCredential(profile: "auto-max-2.4.3M", credentialStatus: "hardware-verified",
                advertisedName: "004-SYNTHETIC-000", keyHex: credential(side).keyHex, fitMaximum: 60,
                address: "02:00:00:00:00:0" + (side == .left ? "1" : "2"), peripheralID: nil, shoeIdentity: nil))
        }))
        XCTAssertEqual(try ProfileImport.decode(PairingExport.encode(pair)), [pair])
    }

    private func credential(_ side: ShoeSide) -> ShoeCredential {
        ShoeCredential(profile: "auto-max-2.4.3M", credentialStatus: "hardware-verified", advertisedName: "004-SYNTHETIC-000",
            keyHex: side == .left ? "000102030405060708090a0b0c0d0e0f" : "101112131415161718191a1b1c1d1e1f",
            fitMaximum: 0, address: "", peripheralID: UUID(uuidString: "00000000-0000-4000-8000-00000000000" + (side == .left ? "1" : "2")),
            shoeIdentity: Data([2, 3, 4, 5, side == .left ? 6 : 7, side == .left ? 0 : 1]))
    }
}
