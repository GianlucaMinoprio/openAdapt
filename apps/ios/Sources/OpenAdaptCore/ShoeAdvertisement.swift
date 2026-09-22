import Foundation

/// Manufacturer metadata identifies a physical shoe, not its pairing state.
/// CoreBluetooth includes the company ID; Android's manufacturer payload does not.
public struct ShoeAdvertisement: Equatable {
    public let side: ShoeSide
    public let identity: Data

    public init?(manufacturerData: Data) {
        let bytes = [UInt8](manufacturerData)
        guard bytes.count >= 10, bytes.prefix(4) == [0x78, 0x00, 0xaf, 0x28] else { return nil }
        side = bytes[9] & 1 == 0 ? .left : .right
        // Five identity bytes and the side bit, as used by the original SDK.
        // Remaining bits are not a documented factory-reset flag.
        identity = Data(bytes[4..<9]) + Data([bytes[9] & 1])
    }
}
