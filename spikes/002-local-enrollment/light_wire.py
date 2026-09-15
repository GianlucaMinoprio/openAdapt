"""Original Auto Max base-color and lights-off codec; no motor/enrollment API."""
import wire


def rgb(value):
    if not isinstance(value, (tuple, list)) or len(value) != 3 or any(
            type(c) is not int or not 0 <= c <= 255 for c in value):
        raise ValueError("three integer RGB components required")
    return tuple(value)


def varint(value):
    result = bytearray()
    while value >= 128:
        result.append((value & 127) | 128)
        value >>= 7
    result.append(value)
    return bytes(result)


def encode(opcode, action, payload=b""):
    if (type(opcode) is not int or opcode not in (20, 112, 113, 222, 237)
            or type(action) is not int or action not in range(4)
            or not isinstance(payload, bytes) or len(payload) > 513):
        raise ValueError("unsupported light envelope")
    return bytes([opcode]) + (len(payload) | action << 14).to_bytes(2, "little") + payload


def decode(raw):
    if not isinstance(raw, bytes) or len(raw) < 3:
        raise ValueError("short light message")
    word = int.from_bytes(raw[1:3], "little")
    if word & 0x3fff != len(raw) - 3:
        raise ValueError("light message length mismatch")
    encode(raw[0], word >> 14, raw[3:])
    return raw[0], word >> 14, raw[3:]


def request(opcode, value=b""):
    if type(opcode) is not int:
        raise ValueError("integer light opcode required")
    if opcode in (112, 113):
        return wire.request(opcode, value)
    if opcode == 222:
        payload = b"\x08\x04"
        for field, component in enumerate(rgb(value), 2):
            if component:
                payload += bytes([field << 3]) + varint(component * 256)
        return encode(222, 0, payload)
    if type(value) is not bytes or value:
        raise ValueError("unexpected light request value")
    if opcode == 237:
        return encode(237, 0)
    if opcode == 20:
        return encode(20, 3)  # Original app's preview EVENT has a shoe ACK.
    raise ValueError("unsupported light request")


def response(opcode, payload):
    if opcode in (112, 113):
        return wire.response(opcode, payload)
    if opcode not in (20, 222, 237) or payload != b"":
        raise ValueError("unexpected light acknowledgement")
    return {}
