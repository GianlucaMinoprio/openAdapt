"""Explicit union of the verified Auto Max control and base-light codecs."""
import control_wire
import light_wire

LIGHTS = (20, 222, 237)


def codec(opcode):
    return light_wire if opcode in LIGHTS else control_wire


def request(opcode, value=b""):
    return codec(opcode).request(opcode, value)


def decode(raw):
    if not isinstance(raw, bytes) or not raw:
        raise ValueError("empty live message")
    return codec(raw[0]).decode(raw)


def response(opcode, payload):
    return codec(opcode).response(opcode, payload)
