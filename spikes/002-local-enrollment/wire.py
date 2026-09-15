"""Original, restricted CoreRF message codec. See PROTOCOL.md."""

def encode(opcode, action, payload=b""):
    if opcode not in (110, 111, 112, 113) or action not in range(4) or len(payload) > 513:
        raise ValueError("unsafe message envelope")
    return bytes([opcode]) + (len(payload) | action << 14).to_bytes(2, "little") + payload

def decode(raw):
    if len(raw) < 3:
        raise ValueError("short message")
    word = int.from_bytes(raw[1:3], "little")
    if word & 0x3fff != len(raw) - 3:
        raise ValueError("message length mismatch")
    encode(raw[0], word >> 14, raw[3:])
    return raw[0], word >> 14, raw[3:]

def response(opcode, payload):
    schemas = {110: {1: 0}, 111: {1: 2}, 112: {1: 2, 2: 2}, 113: {}}
    if opcode not in schemas or len(payload) > 513:
        raise ValueError("unsupported response")
    schema = schemas[opcode]
    fields = {}
    i = 0
    def varint():
        nonlocal i
        value = 0
        for shift in range(0, 35, 7):
            if i >= len(payload):
                raise ValueError("truncated protobuf integer")
            byte = payload[i]
            i += 1
            value |= (byte & 127) << shift
            if byte < 128:
                if shift and byte == 0:
                    raise ValueError("noncanonical protobuf integer")
                return value
        raise ValueError("oversize protobuf integer")
    while i < len(payload):
        tag = varint()
        number, kind = tag >> 3, tag & 7
        if number in fields or schema.get(number) != kind:
            raise ValueError("unexpected or duplicate protobuf field")
        if kind == 0:
            fields[number] = varint()
        else:
            size = varint()
            if i + size > len(payload):
                raise ValueError("truncated protobuf bytes")
            fields[number] = payload[i:i+size]
            i += size
    if opcode == 110 and not fields:
        fields[1] = 0
    if fields.keys() != schema.keys():
        raise ValueError("missing protobuf field")
    if opcode == 110 and fields[1] not in range(4):
        raise ValueError("unsupported MODP group")
    if opcode == 111 and not 1 <= len(fields[1]) <= 256:
        raise ValueError("invalid public key length")
    if opcode == 112 and any(len(value) != 16 for value in fields.values()):
        raise ValueError("invalid nonce length")
    return fields

def request(opcode, value=b""):
    if opcode == 110 and not value:
        return encode(opcode, 0)
    if opcode == 111 and 1 <= len(value) <= 256 or opcode in (112,113) and len(value) == 16:
        n = len(value)
        size = bytes([n]) if n < 128 else bytes([(n & 127) | 128, n >> 7])
        return encode(opcode, 0, b"\x0a" + size + value)
    raise ValueError("unsafe request schema")
