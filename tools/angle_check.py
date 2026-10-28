"""Shoot every part of a character's outfit from three heights: level, high (looking down) and
low (looking up), and paste them into one contact sheet per part.

    python tools/angle_check.py            -> tools/out/angles_<part>.png and angles_all.png
    python tools/angle_check.py --shadow   Shadow form (angles_shadow_*.png)

The front figure of the gallery turnaround stands at x = -1.15 facing +Z. Each part has a target
point (metres) and a camera distance; the three cameras sit in front of it at a slight turn.
"""
import argparse
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import run  # noqa: E402

X = -1.15
# part: (target x offset, target y, target z, distance, yaw degrees)
PARTS = {
    "head": (0.0, 1.52, 0.0, 0.75, 25),
    "ears": (0.0, 1.5, 0.0, 0.6, 80),
    "hair_back": (0.0, 1.45, 0.0, 0.9, 170),
    "chest": (0.0, 1.2, 0.0, 0.9, 20),
    "back": (0.0, 1.15, 0.0, 1.0, 180),
    "sash": (0.0, 1.0, 0.0, 0.8, -35),
    "gauntlet_l": (0.62, 1.2, 0.0, 0.55, 20),
    "gauntlet_r": (-0.62, 1.2, 0.0, 0.55, -20),
    "hips": (0.0, 0.85, 0.0, 1.1, 30),
    "legs": (0.0, 0.45, 0.0, 1.3, -25),
    "shins_feet": (0.0, 0.15, 0.0, 0.8, 30),
    "heels": (0.0, 0.15, 0.0, 0.8, 160),
}
HEIGHTS = {"level": 0.0, "high": 55.0, "low": -50.0}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--shadow", action="store_true")
    ap.add_argument("--only", default="")
    a = ap.parse_args()
    from PIL import Image, ImageDraw
    tag = "shadow_" if a.shadow else ""
    rows = []
    for part, (dx, ty, tz, dist, yaw) in PARTS.items():
        if a.only and part not in a.only.split(","):
            continue
        shots = []
        for hname, pitch in HEIGHTS.items():
            y, p = math.radians(yaw), math.radians(pitch)
            tx = X + dx
            cx = tx + math.sin(y) * math.cos(p) * dist
            cy = ty + math.sin(p) * dist
            cz = tz + math.cos(y) * math.cos(p) * dist
            view = "%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,40" % (cx, cy, cz, tx, ty, tz)
            name = "ang_%s%s_%s" % (tag, part, hname)
            extra = "--gallery turnaround --preset oto --view " + view + (" --shadow" if a.shadow else "")
            args = ["--resolution", "640x480", "--", "--scene", "res://scenes/gallery.tscn",
                    "--shot", os.path.join(run.OUT, name + ".png"), "--frames", "40", "--auto-dialogue"] + extra.split()
            _, errors = run.run(args, 300)
            for e in errors:
                print(e)
            shots.append((hname, os.path.join(run.OUT, name + ".png")))
        sheet = Image.new("RGB", (3 * 427, 320 + 24), (30, 30, 34))
        d = ImageDraw.Draw(sheet)
        for k, (hname, png) in enumerate(shots):
            if os.path.exists(png):
                sheet.paste(Image.open(png).convert("RGB").resize((427, 320)), (k * 427, 24))
            d.text((k * 427 + 8, 5), "%s - %s" % (part, hname), fill=(240, 240, 240))
        out = os.path.join(run.OUT, "angles_%s%s.png" % (tag, part))
        sheet.save(out)
        rows.append(sheet)
        print(out)
    if rows and not a.only:
        allsheet = Image.new("RGB", (rows[0].width, sum(r.height for r in rows)))
        y = 0
        for r in rows:
            allsheet.paste(r, (0, y))
            y += r.height
        allsheet.save(os.path.join(run.OUT, "angles_%sall.png" % tag))


if __name__ == "__main__":
    main()
