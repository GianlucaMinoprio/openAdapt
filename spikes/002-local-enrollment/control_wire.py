"""Original, explicitly selected Auto Max status/position wire formats.

The authentication-only codec stays restricted. This codec excludes enrollment,
presets, calibration writes, lights, resets and firmware. Raw positions are not
the Nike iPhone display scale. See CONTROL.md for evidence and limits.
"""
import math
import struct

import wire


def position(value):
    if type(value) is not int or not 0 <= value <= 100:
        raise ValueError("raw position must be an integer from 0 to 100")
    return value


def relative_target(percent, maximum):
    position(percent)
    if type(maximum) is not int or not 1 <= maximum <= 100:
        raise ValueError("current fit maximum must be an integer from 1 to 100")
    # Explicit OpenAdapt scale: nearest integer, positive ties upward. This is
    # supported by the Android relative-position model and saved-mode examples;
    # it is not a claim about Nike's iPhone slider/display rounding.
    return (percent * maximum + 50) // 100


def encode(opcode, action, payload=b""):
    if (type(opcode) is not int or opcode not in (0, 3, 4, 5, 81, 112, 113)
            or type(action) is not int or action not in range(4)
            or not isinstance(payload, bytes) or len(payload) > 513):
        raise ValueError("unsupported control envelope")
    return bytes([opcode]) + (len(payload) | action << 14).to_bytes(2, "little") + payload


def decode(raw):
    if not isinstance(raw, bytes) or len(raw) < 3:
        raise ValueError("short control message")
    word = int.from_bytes(raw[1:3], "little")
    if word & 0x3fff != len(raw) - 3:
        raise ValueError("control message length mismatch")
    encode(raw[0], word >> 14, raw[3:])
    return raw[0], word >> 14, raw[3:]


def request(opcode, value=b""):
    if type(opcode) is not int:
        raise ValueError("integer control opcode required")
    if opcode in (112, 113):
        return wire.request(opcode, value)
    if opcode == 3:
        value = position(value)
        return encode(3, 0, b"\x08" + bytes([value]) if value else b"")
    if type(value) is not bytes or value:
        raise ValueError("unexpected control request value")
    if opcode == 0:
        return encode(0, 0, b"\x08\x08")  # Only Stop, never other servo enums.
    if opcode in (4, 81):
        return encode(opcode, 0)
    raise ValueError("unsupported control request")


def response(opcode, payload):
    if opcode in (112, 113):
        return wire.response(opcode, payload)
    schemas = {0: {}, 3: {}, 4: {1: 0}, 5: {1: 0, 2: 0},
               81: {1: 0, 2: 0, 3: 1, 4: 0, 5: 0}}
    if (opcode not in schemas or not isinstance(payload, bytes)
            or len(payload) > 64):
        raise ValueError("unsupported control response")
    schema, fields, offset = schemas[opcode], {}, 0

    def varint():
        nonlocal offset
        value = 0
        for shift in range(0, 35, 7):
            if offset >= len(payload):
                raise ValueError("truncated control integer")
            byte = payload[offset]
            offset += 1
            value |= (byte & 127) << shift
            if not byte & 128:
                if value > 0xffffffff or (shift and byte == 0):
                    raise ValueError("noncanonical control integer")
                return value
        raise ValueError("oversized control integer")

    while offset < len(payload):
        tag = varint()
        field, kind = tag >> 3, tag & 7
        if field in fields or schema.get(field) != kind:
            raise ValueError("unexpected or duplicate control field")
        if kind == 0:
            fields[field] = varint()
        else:
            if offset + 8 > len(payload):
                raise ValueError("truncated control double")
            fields[field] = struct.unpack_from("<d", payload, offset)[0]
            offset += 8
            if not math.isfinite(fields[field]):
                raise ValueError("nonfinite control double")
    fields = {field: fields.get(field, 0.0 if kind == 1 else 0)
              for field, kind in schema.items()}
    if opcode == 4:
        position(fields[1])
    elif opcode == 5:
        position(fields[2])
    elif opcode == 81:
        position(fields[4])
        if fields[1] not in range(4):
            raise ValueError("unknown charger status")
    return fields
