"""Measure body landmarks of the character meshes for procedural clothing.

Usage:
    python tools/measure_model.py            # rough draft for all models -> assets/models/landmarks_auto.json
    python tools/measure_model.py --profile oto   # print the width profile for one model

Coordinates match ModelLoader: the body part is scaled to height 1.0, centred on
X/Z and stood on y = 0, facing +Z. ModelLoader multiplies by the model height.
Each model entry below can override any automatic guess (see OVERRIDES).
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS = os.path.join(ROOT, "assets", "models")

# body = OBJ(s) that define the body. The first file defines height and centre.
SOURCES = {
    "oto": ["base_female/model_0.obj"],
    "male_base": ["base_male/model_2.obj"],
    "goku": ["goku/source/goku.obj"],
}

# Hand-checked corrections, in normalized units (fraction of height).
OVERRIDES = {
    "goku": {"head_top": 0.80},  # the hair spikes reach 1.0; the scalp is lower
}


def load(path):
    vs = []
    for line in open(path):
        if line.startswith("v "):
            x, y, z = (float(c) for c in line.split()[1:4])
            vs.append((x, y, z))
    return vs


def normalise(vs):
    xs, ys, zs = zip(*vs)
    h = max(ys) - min(ys)
    cx, cz, y0 = (max(xs) + min(xs)) / 2, (max(zs) + min(zs)) / 2, min(ys)
    return [((x - cx) / h, (y - y0) / h, (z - cz) / h) for x, y, z in vs]


def core_extent(points, gap=0.025):
    """Extent of the contiguous cluster of x values around x = 0."""
    xs = sorted(p[0] for p in points)
    if not xs:
        return 0.0, 0.0
    i = min(range(len(xs)), key=lambda k: abs(xs[k]))
    lo = hi = i
    while lo > 0 and xs[lo] - xs[lo - 1] < gap:
        lo -= 1
    while hi < len(xs) - 1 and xs[hi + 1] - xs[hi] < gap:
        hi += 1
    return xs[lo], xs[hi]


def profile(vs, step=0.01):
    rows = []
    y = 0.0
    while y < 1.0:
        band = [p for p in vs if y <= p[1] < y + step]
        if band:
            lo, hi = core_extent(band)
            core = [p for p in band if lo <= p[0] <= hi]
            zs = [p[2] for p in core]
            rows.append({
                "y": round(y + step / 2, 3),
                "core_w": round(hi - lo, 4),
                "full_w": round(max(p[0] for p in band) - min(p[0] for p in band), 4),
                "z_min": round(min(zs), 4), "z_max": round(max(zs), 4),
            })
        y += step
    return rows


def measure(vs):
    rows = profile(vs)
    by_y = {r["y"]: r for r in rows}

    def row_near(y):
        return min(rows, key=lambda r: abs(r["y"] - y))

    # Arm line: the band with the widest full width in the upper body.
    upper = [r for r in rows if r["y"] > 0.5]
    arm = max(upper, key=lambda r: r["full_w"])
    arm_y = arm["y"]
    span = arm["full_w"] / 2
    # Neck: narrowest core between arms and the top.
    above = [r for r in rows if arm_y < r["y"] < 0.97]
    neck = min(above, key=lambda r: r["core_w"]) if above else row_near(arm_y + 0.05)
    # Head: widest core above the neck.
    head_rows = [r for r in rows if r["y"] > neck["y"]]
    head = max(head_rows, key=lambda r: r["core_w"])
    # Legs split: lowest band where the core no longer spans both legs is the crotch.
    lower = [r for r in rows if r["y"] < 0.6]
    crotch_y = 0.45
    for r in sorted(lower, key=lambda r: -r["y"]):
        band = [p for p in vs if abs(p[1] - r["y"]) < 0.005]
        lo, hi = core_extent(band, gap=0.01)
        if hi - lo < r["full_w"] * 0.6 and r["y"] < arm_y - 0.15:
            crotch_y = r["y"]
            break
    leg_band = [p for p in vs if abs(p[1] - crotch_y * 0.5) < 0.01 and p[0] > 0]
    leg_x = sum(p[0] for p in leg_band) / max(len(leg_band), 1)
    leg_r = (max(p[0] for p in leg_band) - min(p[0] for p in leg_band)) / 2 if leg_band else 0.05
    thigh_band = [p for p in vs if abs(p[1] - crotch_y * 0.9) < 0.01 and p[0] > 0]
    thigh_r = (max(p[0] for p in thigh_band) - min(p[0] for p in thigh_band)) / 2 if thigh_band else leg_r * 1.3
    # Torso below the arms.
    chest = row_near(arm_y - 0.08)
    waist_rows = [r for r in rows if crotch_y + 0.05 < r["y"] < arm_y - 0.1]
    waist = min(waist_rows, key=lambda r: r["core_w"]) if waist_rows else row_near((arm_y + crotch_y) / 2)
    hip = row_near(crotch_y + 0.04)
    # Arm direction: the hand tip is the vertex furthest along +x.
    tip = max(vs, key=lambda p: p[0])
    arm_root_x = chest["core_w"] / 2
    arm_band = [p for p in vs if p[0] > arm_root_x * 1.1 and p[1] > crotch_y]
    root = min(arm_band, key=lambda p: p[0]) if arm_band else (arm_root_x, arm_y, 0)
    arm_r_band = [p for p in vs if abs(p[0] - (root[0] + tip[0]) / 2) < 0.01 and p[1] > crotch_y]
    arm_r = (max(p[1] for p in arm_r_band) - min(p[1] for p in arm_r_band)) / 2 if arm_r_band else 0.03

    return {
        "head_top": max(p[1] for p in vs),
        "head_y": head["y"],
        "head_r": head["core_w"] / 2,
        "head_z": (head["z_min"] + head["z_max"]) / 2,
        "neck_y": neck["y"],
        "neck_r": neck["core_w"] / 2,
        "shoulder_y": arm_y,
        "chest_y": chest["y"],
        "chest_hw": chest["core_w"] / 2,
        "chest_hd": (chest["z_max"] - chest["z_min"]) / 2,
        "chest_z": (chest["z_max"] + chest["z_min"]) / 2,
        "waist_y": waist["y"],
        "waist_hw": waist["core_w"] / 2,
        "waist_hd": (waist["z_max"] - waist["z_min"]) / 2,
        "hip_y": hip["y"],
        "hip_hw": hip["core_w"] / 2,
        "crotch_y": crotch_y,
        "knee_y": crotch_y * 0.5,
        "ankle_y": 0.04,
        "leg_x": leg_x,
        "leg_r": leg_r,
        "thigh_r": thigh_r,
        "arm_root": [root[0], root[1]],
        "hand_tip": [tip[0], tip[1]],
        "arm_r": arm_r,
        "span": span,
    }


def main():
    out = {}
    if "--profile" in sys.argv:
        key = sys.argv[sys.argv.index("--profile") + 1]
        vs = normalise(load(os.path.join(MODELS, SOURCES[key][0])))
        for r in profile(vs):
            print(r)
        return
    for key, files in SOURCES.items():
        vs = normalise(load(os.path.join(MODELS, files[0])))
        m = measure(vs)
        m.update(OVERRIDES.get(key, {}))
        out[key] = {k: (round(v, 4) if isinstance(v, float) else [round(c, 4) for c in v]) for k, v in m.items()}
    # Drafts only: the game reads the hand-checked landmarks.json.
    path = os.path.join(MODELS, "landmarks_auto.json")
    with open(path, "w") as f:
        json.dump(out, f, indent=1)
    print(json.dumps(out, indent=1))
    print("wrote", path)


if __name__ == "__main__":
    main()
