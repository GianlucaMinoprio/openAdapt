def test_start_enrollment_golden(feature):
    encode = feature("wire", "encode")
    assert encode(110, 0, b"") == bytes.fromhex("6e0000")

import pytest

@pytest.mark.parametrize("opcode,action,payload", [(42,0,b""),(81,0,b""),(214,0,b""),(-1,0,b""),(110,4,b""),(112,0,b"x"*514)])
def test_reject_unsafe_envelopes(opcode, action, payload, feature):
    encode = feature("wire", "encode")
    with pytest.raises(ValueError):
        encode(opcode, action, payload)

@pytest.mark.parametrize("raw,expected", [("6e02400803",(110,1,b"\x08\x03")),("710080",(113,2,b"")),("7012000a10"+"00"*16,(112,0,b"\x0a\x10"+bytes(16)))])
def test_decode_golden(raw, expected, feature):
    decode = feature("wire", "decode")
    assert decode(bytes.fromhex(raw)) == expected

@pytest.mark.parametrize("raw", [b"",b"\x70",b"\x70\x00",bytes.fromhex("700100"),bytes.fromhex("700000ff"),bytes.fromhex("700202")+bytes(514),bytes.fromhex("2a0000")])
def test_decode_rejects_malformed(raw, feature):
    decode = feature("wire", "decode")
    with pytest.raises(ValueError):
        decode(raw)

def test_protobuf_response_fields(feature):
    parse = feature("wire", "response")
    assert parse(110, bytes.fromhex("0803")) == {1: 3}
    assert parse(110, b"") == {1: 0}  # proto3 default, not missing-field invention
    assert parse(111, bytes.fromhex("0a0180")) == {1: b"\x80"}
    assert parse(112, b"\x0a\x10"+b"E"*16+b"\x12\x10"+b"D"*16) == {1:b"E"*16, 2:b"D"*16}
    assert parse(113, b"") == {}

@pytest.mark.parametrize("op,raw", [(110,"0804"),(110,"08010802"),(110,"108001"),(110,"088000"),(110,"08808080808000"),(111,"0a0280"),(111,"0d00"),(111,""),(112,"0a10"+"11"*16),(112,"0a10"+"11"*16+"120100"),(113,"0800"),(42,"")], ids=lambda v: str(v)[:50])
def test_reject_unsupported_protobuf(op, raw, feature):
    parse = feature("wire", "response")
    with pytest.raises(ValueError):
        parse(op, bytes.fromhex(raw))

def test_request_schema_golden(feature):
    request = feature("wire", "request")
    assert request(110) == b"\x6e\x00\x00"
    assert request(111,b"\x80") == bytes.fromhex("6f03000a0180")
    assert request(112,bytes(16)) == bytes.fromhex("7012000a10")+bytes(16)
    assert request(113,bytes(16)) == bytes.fromhex("7112000a10")+bytes(16)
    assert request(111,bytes(128))[3:6] == bytes.fromhex("0a8001")
    for op,data in [(42,b""),(110,b"x"),(111,b""),(111,bytes(257)),(112,b"x"),(113,b"x")]:
        with pytest.raises(ValueError):
            request(op,data)
