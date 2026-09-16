#!/usr/bin/env python3
"""Build and sign two personal shortcuts bound to this OpenAdapt distribution."""
import argparse
import json
import plistlib
import subprocess
import tempfile
import uuid
from pathlib import Path


def workflow(name, intent, parameters, bundle_id, team_id):
    return {
        "WFWorkflowName": name,
        "WFWorkflowActions": [{
            "WFWorkflowActionIdentifier": f"{bundle_id}.{intent}",
            "WFWorkflowActionParameters": {
                "AppIntentDescriptor": {
                    "AppIntentIdentifier": intent, "BundleIdentifier": bundle_id,
                    "Name": "OpenAdapt", "TeamIdentifier": team_id,
                },
                "UUID": str(uuid.uuid4()).upper(), **parameters,
            },
        }],
        "WFWorkflowClientVersion": "2600.0.0",
        "WFWorkflowMinimumClientVersion": 900,
        "WFWorkflowMinimumClientVersionString": "900",
        "WFWorkflowIcon": {"WFWorkflowIconStartColor": 4282601983, "WFWorkflowIconGlyphNumber": 59511},
        "WFWorkflowImportQuestions": [], "WFWorkflowInputContentItemClasses": [],
        "WFWorkflowOutputContentItemClasses": [], "WFWorkflowTypes": [],
        "WFWorkflowHasShortcutInputVariables": False,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--team-id", required=True)
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parents[1] / "Config/SiriShortcuts")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    # Commit the files and manifest only after both signatures succeed.
    with tempfile.TemporaryDirectory(prefix="openadapt-shortcuts-") as directory:
        temporary = Path(directory)
        names = []
        for name, intent, parameters in [
            ("Tie my shoes", "TieShoesIntent", {}),
            ("Untie my shoes", "LoosenShoesIntent", {"shoes": "both"}),
        ]:
            unsigned = temporary / f"{name}.unsigned.shortcut"
            signed = temporary / f"{name}.shortcut"
            unsigned.write_bytes(plistlib.dumps(workflow(name, intent, parameters, args.bundle_id, args.team_id), fmt=plistlib.FMT_BINARY))
            subprocess.run(["shortcuts", "sign", "--mode", "anyone", "--input", str(unsigned), "--output", str(signed)], check=True)
            if not signed.is_file() or signed.stat().st_size == 0:
                raise RuntimeError(f"Signing produced no file for {name}")
            names.append(signed.name)
        for name in names:
            (args.output / name).write_bytes((temporary / name).read_bytes())
        (args.output / "manifest.json").write_text(json.dumps({"bundleIdentifier": args.bundle_id, "files": names}, indent=2) + "\n")
    print("Signed Tie my shoes and Untie my shoes. No shoe credentials are included.")


if __name__ == "__main__":
    main()
