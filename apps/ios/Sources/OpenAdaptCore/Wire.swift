import Foundation

public struct WireMessage: Equatable {
    public let opcode: UInt8
    public let action: UInt8
    public let payload: Data
    public init(opcode: UInt8, action: UInt8, payload: Data = Data()) throws {
        guard [0, 3, 4, 5, 20, 81, 82, 110, 111, 112, 113, 178, 179, 222, 237].contains(opcode), action < 4,
              payload.count <= 513 else { throw AdaptError.malformedMessage }
        self.opcode = opcode; self.action = action; self.payload = payload
    }
    public var encoded: Data {
        let word = UInt16(payload.count) | UInt16(action) << 14
        return Data([opcode, UInt8(word & 255), UInt8(word >> 8)]) + payload
    }
    public static func decode(_ data: Data) throws -> Self {
        let bytes = [UInt8](data)
        guard bytes.count >= 3 else { throw AdaptError.malformedMessage }
        let word = Int(bytes[1]) | Int(bytes[2]) << 8
        guard word & 0x3fff == bytes.count - 3 else { throw AdaptError.malformedMessage }
        return try Self(opcode: bytes[0], action: UInt8(word >> 14), payload: Data(bytes.dropFirst(3)))
    }
    public static func request(_ opcode: UInt8, value: Data = Data()) throws -> Self {
        var payload = Data()
        var action: UInt8 = 0
        switch opcode {
        case 112, 113:
            guard value.count == 16 else { throw AdaptError.malformedMessage }
            payload = Data([10, 16]) + value
        case 0: payload = Data([8, 8])
        case 3:
            guard value.count == 1, value[0] <= 100 else { throw AdaptError.malformedMessage }
            if value[0] != 0 { payload = Data([8, value[0]]) }
        case 82:
            // Match captured proto3 encoding: false omits field 1 entirely.
            guard value.count == 1, value[0] <= 1 else { throw AdaptError.malformedMessage }
            if value[0] == 1 { payload = Data([8, 1]) }
        case 178:
            // On: captured double-tap → Unlace. Off: archived GestureOff
            // model (none → none), also observed in setting readback.
            guard value.count == 1, value[0] <= 1 else { throw AdaptError.malformedMessage }
            let setting: UInt8 = value[0] == 1 ? 2 : 1
            payload = Data([10, 4, 8, setting, 16, setting])
        case 222:
            guard value.count == 3 else { throw AdaptError.malformedMessage }
            payload = Data([8, 4])
            for (index, component) in value.enumerated() where component != 0 {
                payload.append(UInt8((index + 2) << 3))
                payload.append(contentsOf: varint(UInt32(component) * 256))
            }
        case 20: action = 3
        case 4, 81, 179, 237: break
        default: throw AdaptError.malformedMessage
        }
        if ![3, 82, 112, 113, 178, 222].contains(opcode), !value.isEmpty { throw AdaptError.malformedMessage }
        return try Self(opcode: opcode, action: action, payload: payload)
    }
    static func varint(_ number: UInt32) -> [UInt8] {
        var number = number; var output = [UInt8]()
        while number >= 128 { output.append(UInt8(number & 127) | 128); number >>= 7 }
        output.append(UInt8(number)); return output
    }
    public enum Field: Equatable {
        case integer(UInt32), bytes(Data), double(Double), gestures(ShoeGestureConfiguration)
        public var integer: Int? { if case let .integer(value) = self { return Int(value) }; return nil }
        public var bytes: Data? { if case let .bytes(value) = self { return value }; return nil }
        public var gestures: ShoeGestureConfiguration? { if case let .gestures(value) = self { return value }; return nil }
    }
    public func fields() throws -> [Int: Field] {
        if opcode == 179 { return [1: .gestures(try ShoeGestureConfiguration(payload: payload))] }
        if opcode == 111, action == 3 {
            guard payload.isEmpty else { throw AdaptError.malformedMessage }
            return [:]
        }
        let schemas: [UInt8: [Int: Int]] = [0: [:], 3: [:], 4: [1: 0], 5: [1: 0, 2: 0],
            81: [1: 0, 2: 0, 3: 1, 4: 0, 5: 0], 82: [:], 110: [1: 0], 111: [1: 2],
            112: [1: 2, 2: 2], 113: [:], 178: [1: 0], 20: [:], 222: [:], 237: [:]]
        guard let schema = schemas[opcode], payload.count <= (opcode == 111 ? 259 : 64) else { throw AdaptError.malformedMessage }
        let bytes = [UInt8](payload); var index = 0; var result = [Int: Field]()
        func integer() throws -> UInt32 {
            var result: UInt32 = 0
            for shift in stride(from: 0, through: 28, by: 7) {
                guard index < bytes.count else { throw AdaptError.malformedMessage }
                let byte = bytes[index]; index += 1
                guard shift != 28 || byte <= 15 else { throw AdaptError.malformedMessage }
                result |= UInt32(byte & 127) << shift
                if byte < 128 {
                    guard shift == 0 || byte != 0 else { throw AdaptError.malformedMessage }
                    return result
                }
            }
            throw AdaptError.malformedMessage
        }
        while index < bytes.count {
            let tag = try integer(); let field = Int(tag >> 3); let kind = Int(tag & 7)
            guard schema[field] == kind, result[field] == nil else { throw AdaptError.malformedMessage }
            switch kind {
            case 0: result[field] = .integer(try integer())
            case 2:
                let size = Int(try integer())
                guard (opcode == 111 ? (1...256).contains(size) : size == 16), index + size <= bytes.count else { throw AdaptError.malformedMessage }
                result[field] = .bytes(Data(bytes[index..<index + size])); index += size
            case 1:
                guard index + 8 <= bytes.count else { throw AdaptError.malformedMessage }
                var bits: UInt64 = 0
                for offset in 0..<8 { bits |= UInt64(bytes[index + offset]) << (offset * 8) }
                let value = Double(bitPattern: bits)
                guard value.isFinite else { throw AdaptError.malformedMessage }
                result[field] = .double(value); index += 8
            default: throw AdaptError.malformedMessage
            }
        }
        for (field, kind) in schema where result[field] == nil {
            guard kind != 2 else { throw AdaptError.malformedMessage }
            result[field] = kind == 1 ? .double(0) : .integer(0)
        }
        let positionField = opcode == 4 ? 1 : opcode == 5 ? 2 : opcode == 81 ? 4 : nil
        if let field = positionField, !(0...100).contains(result[field]?.integer ?? -1) { throw AdaptError.malformedMessage }
        if opcode == 81, !(0...3).contains(result[1]?.integer ?? -1) { throw AdaptError.malformedMessage }
        if opcode == 110, !(0...3).contains(result[1]?.integer ?? -1) { throw AdaptError.malformedMessage }
        return result
    }
}

public struct FragmentReceiver {
    public private(set) var sequence = 0
    private var buffer = Data()
    public init() {}
    public mutating func feed(_ packet: Data) throws -> (message: WireMessage?, acknowledgement: Data?) {
        let bytes = [UInt8](packet)
        guard (2...20).contains(bytes.count), bytes[0] & 64 == 0 else { throw AdaptError.malformedMessage }
        let incoming = Int(bytes[0] & 63)
        guard incoming == sequence else { throw AdaptError.sequence }
        guard buffer.count + bytes.count - 1 <= 516 else { throw AdaptError.malformedMessage }
        buffer.append(contentsOf: bytes.dropFirst())
        let ack = incoming % 2 == 1 ? Data([UInt8(incoming) | 192, 0]) : nil
        sequence = (sequence + 1) % 64
        if bytes[0] & 128 != 0 {
            let message = try WireMessage.decode(buffer); buffer.removeAll(keepingCapacity: true)
            return (message, ack)
        }
        return (nil, ack)
    }
    public static func fragments(_ message: WireMessage, sequence: Int) -> [Data] {
        let bytes = [UInt8](message.encoded)
        return stride(from: 0, to: bytes.count, by: 19).map { index in
            let final = index + 19 >= bytes.count
            return Data([UInt8((sequence + index / 19) % 64) | (final ? 128 : 0)]) + Data(bytes[index..<min(index + 19, bytes.count)])
        }
    }
}
