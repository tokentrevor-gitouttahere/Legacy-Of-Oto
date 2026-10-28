"""Render front and side silhouettes of a character mesh with a measuring grid.

Usage:
    python tools/model_sheet.py oto [out.png]

Units match assets/models/landmarks.json: the body is 1.0 tall, centred on X/Z,
standing on y = 0, facing +Z. Grid lines every 0.05, labelled every 0.1.
Use it to read off landmark heights and widths by eye, then edit landmarks.json.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from measure_model import MODELS, SOURCES, load, normalise  # noqa: E402

PX = 900  # pixels per unit of height


def faces(path):
    vs, fs = [], []
    for line in open(path):
        if line.startswith("v "):
            vs.append([float(c) for c in line.split()[1:4]])
        elif line.startswith("f "):
            idx = [int(t.split("/")[0]) - 1 for t in line.split()[1:]]
            for k in range(1, len(idx) - 1):
                fs.append((idx[0], idx[k], idx[k + 1]))
    return vs, fs


def render(key, out):
    path = os.path.join(MODELS, SOURCES[key][0])
    raw, fs = faces(path)
    vs = np.array(normalise([tuple(v) for v in raw]))
    margin = 60
    view_w = 1.0  # x from -0.5 to 0.5
    w = int(view_w * PX) + margin * 2
    h = int(1.05 * PX) + margin * 2
    sheet = Image.new("RGB", (w * 2, h), (250, 250, 250))
    for panel, (ax, name) in enumerate([(0, "front (x)"), (2, "side (z, front = right)")]):
        img = Image.new("RGB", (w, h), (250, 250, 250))
        d = ImageDraw.Draw(img)
        def to_px(u, y):
            return (margin + (u + view_w / 2) * PX, margin + (1.05 - y) * PX)
        # grid
        for i in range(0, 22):
            y = i * 0.05
            col = (200, 200, 200) if i % 2 else (150, 150, 220)
            d.line([to_px(-0.5, y), to_px(0.5, y)], fill=col)
            if i % 2 == 0:
                d.text((4, to_px(0, y)[1] - 6), "%.1f" % y, fill=(0, 0, 160))
        for i in range(-10, 11):
            u = i * 0.05
            col = (200, 200, 200) if i % 2 else (150, 150, 220)
            d.line([to_px(u, 0), to_px(u, 1.05)], fill=col)
            if i % 2 == 0:
                d.text((to_px(u, 0)[0] - 8, h - margin + 6), "%.1f" % u, fill=(0, 0, 160))
        for a, b, c in fs:
            pts = [to_px(vs[i][ax], vs[i][1]) for i in (a, b, c)]
            d.polygon(pts, fill=(60, 40, 40))
        d.text((margin, 10), "%s  %s" % (key, name), fill=(0, 0, 0))
        sheet.paste(img, (panel * w, 0))
    sheet.save(out)
    print(out)


if __name__ == "__main__":
    key = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "docs", "model_sheets", key + ".png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    render(key, out)
