import json
import subprocess
import sys
from pathlib import Path

import pytest

from session import Session
from simulation import SyntheticPeer, self_test


async def test_full_synthetic_exchange_all_groups():
    result = await self_test()
    assert result["passed"] is True
    assert result["hardware_accessed"] is False
    assert result["shoe_authentication_proven"] is False
    assert [row["group"] for row in result["groups"]] == [0, 1, 2, 3]
    assert all(row["enrollment_commands"] == [110, 111, 112, 113] for row in result["groups"])


async def test_transport_sequence_wrap_across_many_messages():
    peer = SyntheticPeer(key=bytes(range(16)))
    try:
        for _ in range(35):
            await Session(peer.channel).authenticate_existing(peer.key)
        assert peer.channel.sent == 140  # Two segments per request, two requests.
        assert peer.channel.tx_sequence == 12
        assert peer.commands == [112, 113] * 35
    finally:
        peer.channel.close()


@pytest.mark.parametrize("args,code", [(["offline-self-test"], 0), (["enroll"], 2), (["authenticate"], 2)])
def test_cli_has_only_offline_entrypoint(args, code):
    root = Path(__file__).resolve().parents[1]
    # Allow asyncio's local socketpair, but forbid network connections and DNS.
    script = """
import sys
def guard(event, args):
    if event in ('socket.connect', 'socket.bind', 'socket.getaddrinfo'):
        raise RuntimeError('offline CLI attempted socket access')
sys.addaudithook(guard)
from adapt_enrollment import main
raise SystemExit(main(sys.argv[1:]))
"""
    result = subprocess.run([sys.executable, "-c", script, *args], cwd=root,
                            capture_output=True, text=True, timeout=5)
    if code == 0:
        data = json.loads(result.stdout)
        assert data["passed"] and not data["hardware_accessed"]
        assert "key_hex" not in result.stdout
    assert result.returncode == code
