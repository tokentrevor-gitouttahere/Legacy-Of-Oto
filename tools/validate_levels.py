"""Static checks for levels/*.json. Run: python tools/validate_levels.py

Checks: grid present and rectangular, characters known (default legend + level
legend), every exit digit in the grid has an "exits" entry and vice versa, exit
targets and spawn names exist, prop types exist in scripts/world/props.gd,
outfits exist in scripts/characters/outfits.gd, and positions are on the map.
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_CHARS = set(" .,:;osmc~=_+WFC#BTPYbrML D@") | set("123456789")


def _keys_from_gd(path, const):
    text = open(os.path.join(ROOT, path), encoding="utf-8").read()
    start = text.index("const %s" % const)
    depth = 0
    body = []
    for ch in text[start:]:
        body.append(ch)
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                break
    block = "".join(body)
    # top-level keys only: a quoted name followed by ':' at nesting depth 1
    keys, depth = set(), 0
    for m in re.finditer(r'[{}]|"([A-Za-z0-9_]+)"\s*:', block):
        if m.group(0) == "{":
            depth += 1
        elif m.group(0) == "}":
            depth -= 1
        elif depth == 1:
            keys.add(m.group(1))
    return keys


def validate_all():
    props = _keys_from_gd("scripts/world/props.gd", "DOCS")
    outfits = set(_keys_from_gd("scripts/characters/outfits.gd", "PRESETS"))
    # the townswomen (npc_women.gd): woman_<design> and its recolours woman_<design>_2..4
    for d in _keys_from_gd("scripts/characters/npc_women.gd", "DESIGNS"):
        outfits.update(["woman_" + d] + ["woman_%s_%d" % (d, n) for n in (2, 3, 4)])
    levels = {}
    problems = []
    for path in sorted(glob.glob(os.path.join(ROOT, "levels", "*.json"))):
        lid = os.path.splitext(os.path.basename(path))[0]
        if lid == "world":
            continue
        try:
            levels[lid] = json.load(open(path, encoding="utf-8"))
        except ValueError as e:
            problems.append("%s: bad JSON: %s" % (lid, e))
    for lid, d in levels.items():
        p = lambda msg: problems.append("%s: %s" % (lid, msg))  # noqa: E731
        grid = d.get("grid")
        if not grid:
            p("no grid")
            continue
        cols, rows = max(len(r) for r in grid), len(grid)
        if any(len(r) != cols for r in grid):
            p("rows have different lengths (short rows are padded with void)")
        legend = set(d.get("legend", {}).keys())
        used = set("".join(grid))
        unknown = used - DEFAULT_CHARS - legend
        if unknown:
            p("unknown tile characters: %s" % "".join(sorted(unknown)))
        digits = {c for c in used if c.isdigit()}
        exits = d.get("exits", {})
        for k in digits - set(exits):
            p("exit '%s' in grid but not in exits" % k)
        for k, ex in exits.items():
            if k not in digits:
                p("exits['%s'] defined but not in grid" % k)
            to = ex.get("to", "world")
            if to != "world":
                if to not in levels:
                    p("exit '%s' goes to missing level '%s'" % (k, to))
                else:
                    spawn = ex.get("spawn", "default")
                    target = levels[to]
                    has_at = any("@" in r for r in target.get("grid", []))
                    if spawn not in target.get("spawns", {}) and not (spawn == "default" and has_at):
                        p("exit '%s' -> %s: spawn '%s' not defined there" % (k, to, spawn))
        for name, at in d.get("spawns", {}).items():
            if not (0 <= at[0] < cols and 0 <= at[1] < rows):
                p("spawn '%s' off the map" % name)
        for spec in d.get("props", []):
            if spec.get("type") not in props:
                p("unknown prop type '%s'" % spec.get("type"))
            at = spec.get("at", [-1, -1])
            if not (-1 <= at[0] <= cols and -1 <= at[1] <= rows):
                p("prop %s off the map at %s" % (spec.get("type"), at))
        for spec in d.get("npcs", []):
            if spec.get("outfit") and spec["outfit"] not in outfits:
                p("npc %s: unknown outfit '%s'" % (spec.get("name"), spec["outfit"]))
            if "lines" not in spec:
                p("npc %s has no lines" % spec.get("name"))
    world = os.path.join(ROOT, "levels", "world.json")
    if os.path.exists(world):
        for loc in json.load(open(world)).get("locations", []):
            if loc["id"] not in levels:
                problems.append("world.json: location '%s' has no level file" % loc["id"])
    return problems


if __name__ == "__main__":
    probs = validate_all()
    for x in probs:
        print(x)
    print("levels OK" if not probs else "%d problem(s)" % len(probs))
    sys.exit(1 if probs else 0)
