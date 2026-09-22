import Foundation

/// A standard Device Information read identifies a version; it does not prove
/// enrollment, control compatibility, or that this is the latest Nike release.
public struct ShoeFirmware: Equatable {
    public static let testedVersion = "2.4.3M"
    public let version: String
    public let supportsExistingKeyControl: Bool

    public init(data: Data) throws {
        guard !data.isEmpty, data.count <= 64 else { throw AdaptError.malformedMessage }
        let bytes = Array(data)
        let end = bytes.firstIndex(of: 0) ?? bytes.count
        guard end > 0, end <= 32, bytes[end...].allSatisfy({ $0 == 0 }),
              let version = String(bytes: bytes[..<end], encoding: .ascii),
              version.range(of: "^[A-Za-z0-9][A-Za-z0-9._-]*$", options: .regularExpression) != nil else {
            throw AdaptError.malformedMessage
        }
        self.version = version
        let tested = Data(Self.testedVersion.utf8)
        // Preserve the exact, previously verified control gate. Reading another
        // version never opts it into the command protocol.
        supportsExistingKeyControl = data == tested || data == tested + Data(repeating: 0, count: 14)
    }
}
