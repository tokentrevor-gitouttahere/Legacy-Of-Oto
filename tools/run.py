"""Run Godot for this project from the command line: import, check, screenshot.

    python tools/run.py import                      re-import assets, report script errors
    python tools/run.py shot title                  screenshot scenes/title.tscn
    python tools/run.py shot level:west_city        screenshot a tile-map location
    python tools/run.py shot gallery --args="--gallery props --page 1"
    python tools/run.py shot prologue_fight --frames 400 --args="--sim fight --skipfight"
    python tools/run.py levels                      validate every levels/*.json
    python tools/run.py test                        headless rule checks (scenes/dev_tests.tscn)

Godot is found from $GODOT, tools/godot_path.txt, or the default download path.
Pass Godot-side flags with --args="..." (the = matters). Screenshots go to tools/out/<name>.png (git-ignored); the PNG path and any
SCRIPT ERROR lines are printed. Exit code 1 means errors were found.
"""
import argparse
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tools", "out")
DEFAULT_GODOT = r"C:\Users\Owner\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
ERROR_RE = re.compile(r"SCRIPT ERROR|Parse Error|ERROR:|Compile Error")
IGNORED = ("model_0.mtl", "Couldn't open MTL")


def godot():
    if os.environ.get("GODOT"):
        return os.environ["GODOT"]
    cfg = os.path.join(ROOT, "tools", "godot_path.txt")
    if os.path.exists(cfg):
        return open(cfg).read().strip()
    return DEFAULT_GODOT


def run(args, timeout):
    try:
        p = subprocess.run([godot(), "--path", ROOT] + args, capture_output=True, text=True,
                           timeout=timeout, encoding="utf-8", errors="replace")
        out = p.stdout + p.stderr
    except subprocess.TimeoutExpired as e:
        out = (e.stdout or b"").decode("utf-8", "replace") if isinstance(e.stdout, bytes) else (e.stdout or "")
        out += "\nTIMEOUT after %ss" % timeout
    lines = out.splitlines()
    errors = []
    for i, line in enumerate(lines):
        if ERROR_RE.search(line) and not any(s in line for s in IGNORED):
            errors.append("\n".join(lines[i:i + 3]))
    return out, errors


def cmd_import(a):
    _, errors = run(["--headless", "--import"], a.timeout)
    report(errors)


def cmd_shot(a):
    os.makedirs(OUT, exist_ok=True)
    target = a.target
    extra = a.args.split() if a.args else []
    if target.startswith("level:"):
        scene = "res://scenes/location.tscn"
        extra += ["--level", target[6:]]
        name = target[6:]
    else:
        scene = target if target.startswith("res://") else "res://scenes/%s.tscn" % target
        name = os.path.splitext(os.path.basename(scene))[0]
    name = a.name or name
    png = os.path.join(OUT, name + ".png")
    if os.path.exists(png):
        os.remove(png)
    args = ["--resolution", a.resolution, "--", "--scene", scene, "--shot", png,
            "--frames", str(a.frames), "--auto-dialogue"] + extra
    _, errors = run(args, a.timeout)
    print(png if os.path.exists(png) else "NO SCREENSHOT")
    report(errors)


def cmd_test(a):
    out, errors = run(["--headless", "--", "--scene", "res://scenes/dev_tests.tscn"], a.timeout)
    lines = [l for l in out.splitlines() if l.startswith(("PASS", "FAIL", "TESTS DONE"))]
    for line in lines:
        print(line)
    if not any(l.startswith("TESTS DONE") for l in lines):
        print("tests did not finish")
        errors.append("tests did not finish")
    errors += [l for l in lines if l.startswith("FAIL")]
    report(errors)


def cmd_levels(a):
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    from validate_levels import validate_all
    problems = validate_all()
    for p in problems:
        print(p)
    print("levels OK" if not problems else "%d problem(s)" % len(problems))
    sys.exit(1 if problems else 0)


def report(errors):
    for e in errors[:20]:
        print(e)
    print("no errors" if not errors else "%d error(s)" % len(errors))
    if errors:
        sys.exit(1)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("import")
    p.add_argument("--timeout", type=int, default=180)
    p.set_defaults(fn=cmd_import)
    p = sub.add_parser("shot")
    p.add_argument("target")
    p.add_argument("--frames", type=int, default=60)
    p.add_argument("--args", default="")
    p.add_argument("--name", default="")
    p.add_argument("--resolution", default="1280x720")
    p.add_argument("--timeout", type=int, default=120)
    p.set_defaults(fn=cmd_shot)
    p = sub.add_parser("test")
    p.add_argument("--timeout", type=int, default=120)
    p.set_defaults(fn=cmd_test)
    p = sub.add_parser("levels")
    p.set_defaults(fn=cmd_levels)
    a = ap.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
