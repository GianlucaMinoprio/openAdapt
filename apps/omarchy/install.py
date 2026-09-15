#!/usr/bin/env python3
"""Install the user-owned Omarchy widget. Never contacts a shoe.

Optional profile/state imports must be local owner-only JSON files. Existing
profiles and state are preserved. The shell layout is backed up before editing.
"""
import argparse
import datetime
import json
import os
from pathlib import Path
import shlex
import shutil
import stat
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parents[1]
PLUGIN = "io.github.gianlucaminoprio.openadapt"


def private_import(source, destination):
    if destination.exists():
        return
    info=source.lstat()
    if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o600:
        raise SystemExit("The import file must be owner-owned with mode 0600.")
    data=json.loads(source.read_text())
    with destination.open("x") as output:
        json.dump(data,output,indent=2)
        output.write("\n")
    destination.chmod(0o600)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile",type=Path)
    parser.add_argument("--state",type=Path)
    args=parser.parse_args()
    os.umask(0o077)
    config=Path(os.environ.get("XDG_CONFIG_HOME",Path.home()/".config"))
    statehome=Path(os.environ.get("XDG_STATE_HOME",Path.home()/".local/state"))
    private=config/"openadapt"
    state=statehome/"openadapt"
    for directory in (private,state,private/"backups"):
        directory.mkdir(parents=True,mode=0o700,exist_ok=True)
        if directory.is_symlink() or stat.S_IMODE(directory.stat().st_mode) != 0o700:
            raise SystemExit("OpenAdapt private directories require mode 0700.")
    python=PROJECT/"spikes/002-local-enrollment/.venv/bin/python"
    if not python.is_file():
        raise SystemExit("Create the enrollment spike's locked virtual environment first.")
    subprocess.run(["omarchy","plugin","validate",str(ROOT/"plugin")],check=True)
    if args.profile:
        private_import(args.profile,private/"profiles.private.json")
    if args.state:
        private_import(args.state,state/"state.json")
    launchers=Path.home()/".local/bin"
    launchers.mkdir(parents=True,exist_ok=True)
    launcher=launchers/"openadapt-control"
    launcher.write_text("#!/bin/sh\nexec "+shlex.quote(str(python))+" "+shlex.quote(str(ROOT/"backend/openadapt_app.py"))+" \"$@\"\n")
    launcher.chmod(0o700)
    session_launcher=launchers/"openadapt-session"
    session_launcher.write_text("#!/bin/sh\nexec "+shlex.quote(str(python))+" "+shlex.quote(str(ROOT/"backend/openadapt_session.py"))+"\n")
    session_launcher.chmod(0o700)
    destination=config/"omarchy/plugins"/PLUGIN
    if destination.exists():
        stamp=datetime.datetime.now().strftime("%Y%m%dT%H%M%S%f")
        shutil.copytree(destination,private/"backups"/("plugin-"+stamp))
        shutil.copytree(ROOT/"plugin",destination,dirs_exist_ok=True)
    else:
        staging=private/"plugin-staging"
        if staging.exists():
            raise SystemExit("An earlier plugin staging directory needs review.")
        shutil.copytree(ROOT/"plugin",staging)
        destination.parent.mkdir(parents=True,exist_ok=True)
        staging.rename(destination)
    shell=config/"omarchy/shell.json"
    data=json.loads(shell.read_text())
    stamp=datetime.datetime.now().strftime("%Y%m%dT%H%M%S%f")
    shutil.copy2(shell,private/"backups"/("shell-"+stamp+".json"))
    layout=data["bar"]["layout"]
    present=any(any(row.get("id")==PLUGIN for row in layout.get(section,[])) for section in ("left","center","right"))
    if not present:
        right=layout.setdefault("right",[])
        index=next((i+1 for i,row in enumerate(right) if row.get("id")=="gianluk.agents"),0)
        right.insert(index,{"id":PLUGIN})
        shell.write_text(json.dumps(data,indent=2)+"\n")
    applications=Path.home()/".local/share/applications"
    applications.mkdir(parents=True,exist_ok=True)
    (applications/"openadapt.desktop").write_text("[Desktop Entry]\nType=Application\nName=OpenAdapt\nComment=Control your Auto Max shoes\nExec=omarchy-shell "+PLUGIN+" open\nIcon="+str(destination/"openadapt.svg")+"\nTerminal=false\nCategories=Utility;\n")
    subprocess.run(["omarchy-shell","shell","rescanPlugins"],check=True)
    print(json.dumps({"installed":str(destination),"launcher":str(launcher),"hardware_accessed":False}))


if __name__=="__main__":
    main()
