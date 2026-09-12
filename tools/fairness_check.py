#!/usr/bin/env python3
"""
HOSTIS fairness check (docs/FAIRNESS.md section 2).

Scans every .sqf and .fsm file under addons/ for the commands the fairness contract
restricts and fails on any occurrence that is not listed in tools/fairness_allow.txt.

The allow list is the audit ledger: one line per allowed occurrence,
    <path>|<command>|<reason>
with '/' as the path separator relative to the repository root. A line whose reason
starts with "TODO" is a known breach with the milestone that removes it.

Rules enforced (R = rule in FAIRNESS.md):
  R1  reveal, doTarget, doFire, commandTarget, commandFire, doWatch, doSuppressiveFire,
      commandSuppressiveFire
  R3  setSkill, setUnitTrait
  R4  allPlayers, playableUnits, switchableUnits, allUnits, allDeadMen
  R5  setPos, setPosATL, setPosASL, setPosASL2, setPosWorld, setVehiclePosition,
      addMagazine, addMagazines, addMagazineCargo, addMagazineCargoGlobal, setVehicleAmmo,
      setVehicleAmmoDef, createUnit, createVehicle

Only the debug folder (addons/*/functions/debug) is exempt. Comments are stripped
before matching. Usage: python3 tools/fairness_check.py  (exit code = number of breaches)
"""
import os
import re
import sys

RULES = {
    "R1": ["reveal", "doTarget", "doFire", "commandTarget", "commandFire", "doWatch",
           "doSuppressiveFire", "commandSuppressiveFire"],
    "R3": ["setSkill", "setUnitTrait"],
    "R4": ["allPlayers", "playableUnits", "switchableUnits", "allUnits", "allDeadMen"],
    "R5": ["setPos", "setPosATL", "setPosASL", "setPosASL2", "setPosWorld", "setVehiclePosition",
           "addMagazine", "addMagazines", "addMagazineCargo", "addMagazineCargoGlobal",
           "setVehicleAmmo", "setVehicleAmmoDef", "createUnit", "createVehicle"],
}
COMMANDS = {cmd: rule for rule, cmds in RULES.items() for cmd in cmds}
PATTERN = re.compile(r"(?<![\w_])(" + "|".join(sorted(COMMANDS, key=len, reverse=True)) + r")(?![\w_])")
COMMENT = re.compile(r"/\*.*?\*/|//[^\n]*", re.S)
STRING = re.compile(r'"(?:[^"]|"")*"')

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDONS = os.path.join(ROOT, "addons")
ALLOW_FILE = os.path.join(ROOT, "tools", "fairness_allow.txt")


def load_allow():
    allowed = set()
    if not os.path.exists(ALLOW_FILE):
        return allowed
    with open(ALLOW_FILE, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split("|", 2)
            if len(parts) < 2:
                continue
            allowed.add((parts[0].strip(), parts[1].strip()))
    return allowed


def scan_file(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        text = f.read()
    if path.endswith(".fsm"):
        # FSM files hold the script inside C-style strings; unescape the doubled quotes
        text = text.replace('""', "'")
    text = COMMENT.sub("", text)
    if not path.endswith(".fsm"):
        text = STRING.sub('""', text)
    found = {}
    for match in PATTERN.finditer(text):
        cmd = match.group(1)
        line = text.count("\n", 0, match.start()) + 1
        found.setdefault(cmd, []).append(line)
    return found


def main():
    allowed = load_allow()
    breaches = 0
    used = set()
    for dirpath, _, filenames in os.walk(ADDONS):
        rel_dir = os.path.relpath(dirpath, ROOT).replace(os.sep, "/")
        if "/functions/debug" in rel_dir:
            continue
        for name in filenames:
            if not (name.endswith(".sqf") or name.endswith(".fsm")):
                continue
            rel = rel_dir + "/" + name
            found = scan_file(os.path.join(dirpath, name))
            for cmd, lines in sorted(found.items()):
                key = (rel, cmd)
                if key in allowed:
                    used.add(key)
                    continue
                breaches += 1
                print(f"FAIRNESS {COMMANDS[cmd]}: {rel} uses `{cmd}` at line(s) {', '.join(map(str, lines))}")
    stale = allowed - used
    for rel, cmd in sorted(stale):
        print(f"note: allow-list entry no longer matches anything: {rel}|{cmd}")
    if breaches:
        print(f"\n{breaches} unlisted use(s). Cite the guard or the rule in tools/fairness_allow.txt (docs/FAIRNESS.md section 2).")
    else:
        print("Fairness check PASSED")
    sys.exit(breaches)


if __name__ == "__main__":
    main()
