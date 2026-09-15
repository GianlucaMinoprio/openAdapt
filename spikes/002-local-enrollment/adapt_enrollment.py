"""Offline enrollment simulation only. No live enrollment command exists."""
import argparse
import asyncio
import json


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    subcommands = parser.add_subparsers(dest="command", required=True)
    subcommands.add_parser("offline-self-test", allow_abbrev=False,
                           help="simulate all four MODP groups without hardware")
    parser.parse_args(argv)
    from simulation import self_test
    try:
        print(json.dumps(asyncio.run(self_test()), indent=2))
    except (Exception, KeyboardInterrupt) as exc:
        # Exception text from future backends must never disclose keys or packets.
        print(json.dumps({"mode": "OFFLINE SYNTHETIC SELF-TEST", "passed": False,
                          "error_type": type(exc).__name__}))
        return 130 if isinstance(exc, KeyboardInterrupt) else 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
