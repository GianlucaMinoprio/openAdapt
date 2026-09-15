import asyncio
import pytest
from wire import request,encode

def test_segmentation_wrap_golden(feature):
    segments=feature("transport","segments")
    raw=request(112,bytes(16))
    assert segments(raw,63)==[bytes.fromhex("3f7012000a10")+bytes(14),bytes.fromhex("800000")]
    assert segments(request(110),0)==[bytes.fromhex("806e0000")]

def test_receive_reassembly_apk_ack_cadence(feature):
    Receiver=feature("transport","Receiver")
    r=Receiver()
    packets=feature("transport","segments")(encode(112,1,b"E"*36),0)
    assert r.feed(packets[0]) == (None,None)
    assert r.feed(packets[1]) == (None,bytes.fromhex("c100"))
    assert r.feed(packets[2]) == (encode(112,1,b"E"*36),None)
    assert r.feed(bytes.fromhex("83710040")) == (bytes.fromhex("710040"),bytes.fromhex("c300"))

@pytest.mark.parametrize("case", ["empty","short","oversize","flow","out-of-order","duplicate","duplicate-final","overflow","truncated-final"])
def test_receiver_fail_closed(feature,case):
    r=feature("transport","Receiver")()
    packet=b"\x00"+b"X"*19
    if case=="duplicate": r.feed(packet)
    if case=="duplicate-final": r.feed(bytes.fromhex("80710040"))
    if case=="overflow":
        for seq in range(27): r.feed(bytes([seq])+b"X"*19)
    bad={"empty":b"","short":b"\x00","oversize":b"\x00"+bytes(20),"flow":b"\xc1\x00","out-of-order":b"\x01X","duplicate":packet,"duplicate-final":bytes.fromhex("80710040"),"overflow":b"\x1b"+b"X"*19,"truncated-final":bytes.fromhex("80700100")}[case]
    with pytest.raises(ValueError): r.feed(bad)

async def test_request_transport_end_to_end(feature):
    Transport=feature("transport","Transport")
    writes=[]
    async def write(packet):
        writes.append(packet)
        if packet[0]&128 and not packet[0]&64:
            channel.notify(bytes.fromhex("806e02400803"))
    channel=Transport(write,timeout=0.1)
    assert await channel.request(110)=={1:3}
    assert writes==[bytes.fromhex("806e0000")]
