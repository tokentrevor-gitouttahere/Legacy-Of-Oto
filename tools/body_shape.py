"""Reshape the female base mesh (bust, waist, hips, butt, stomach) into a COPY, never the original.

    python tools/body_shape.py --out tools/out/x.obj --bust 2 --waist -1.5
    python tools/body_shape.py --preset full_figure --out tools/out/full_figure.obj
                                                  a preset saved in scenes/body_editor.tscn
    python tools/body_shape.py --presets          write every study preset to tools/out/body_study/
    python tools/body_shape.py --report           measure the source mesh

This is the offline twin of scripts/characters/body_shape.gd (the one the game and the editor
use; dev_tests checks that they agree). Use it to export a reshaped OBJ, for example to rig it
in Mixamo. Amounts are centimetres on a 170 cm figure (the game's height for Oto). Bust, butt
and stomach push the surface out (negative: in) inside a soft ellipsoid; waist and hips change
the half-width of the torso at their height (negative: narrower), smoothly, about the body's
axis. Everything is a smooth function of the vertex position, so the points the mesh repeats
(its seams) move together and nothing tears. The head, arms, hands and legs below the hips
do not move.
"""
import argparse
import json
import os
import shutil

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "models", "base_female", "model_0.obj")
SAVED = os.path.join(ROOT, "assets", "models", "body_presets.json")  # made in scenes/body_editor.tscn
STUDY = os.path.join(ROOT, "tools", "out", "body_study")
CM = 170.0  # the figure's height in cm; a normalised unit is one body height

PRESETS = {
    "bust_up": {"bust": 2.0},
    "bust_down": {"bust": -1.0},
    "waist_slim": {"waist": -1.5},
    "waist_wide": {"waist": 1.5},
    "hips_wide": {"hips": 2.0},
    "hips_narrow": {"hips": -1.5},
    "stomach_soft": {"stomach": 1.5},
    "stomach_flat": {"stomach": -1.0},
    "butt_up": {"butt": 2.5},
    "butt_down": {"butt": -1.5},
    "curvy": {"bust": 2.0, "waist": -1.2, "hips": 2.0},
    "slim": {"bust": -1.0, "waist": -0.5, "hips": -1.2},
    # how far each can go before it stops looking good (see docs/BODY_STUDY.md): bust and butt
    # at 3 / 4 / 5 cm, with the waist drawn in and the hips out to keep the proportions
    "max_a": {"bust": 3.0, "butt": 3.0, "waist": -1.5, "hips": 2.0},
    "max_b": {"bust": 4.0, "butt": 4.0, "waist": -1.8, "hips": 2.5},
    "max_c": {"bust": 5.0, "butt": 5.0, "waist": -2.0, "hips": 3.0},
}


def bump(d):
    """1 at d = 0, 0 at d >= 1, smooth in between."""
    d = np.clip(d, 0.0, 1.0)
    return 0.5 * (1.0 + np.cos(np.pi * d))


def load_obj(path):
    lines = open(path).read().split("\n")
    v, vn, f = [], [], []
    for line in lines:
        if line.startswith("v "):
            v.append([float(c) for c in line.split()[1:4]])
        elif line.startswith("vn "):
            vn.append([float(c) for c in line.split()[1:4]])
        elif line.startswith("f "):
            f.append([[int(i) if i else 0 for i in t.split("/")] for t in line.split()[1:]])
    f = np.array(f)  # (faces, 3, 3): v, vt, vn indices
    assert f.shape[1] == 3, "triangles only"
    assert (f[:, :, 0] == f[:, :, 2]).all(), "this tool expects each vertex to have its own normal"
    return lines, np.array(v), np.array(vn), f[:, :, 0] - 1


def welded_normals(v, tri):
    """Smooth normals shared by every vertex at the same position (the mesh repeats points)."""
    key = np.round(v * 1e6).astype(np.int64)
    _, inv = np.unique(key, axis=0, return_inverse=True)
    inv = inv.reshape(-1)
    fn = np.cross(v[tri[:, 1]] - v[tri[:, 0]], v[tri[:, 2]] - v[tri[:, 0]])  # zero when degenerate
    acc = np.zeros((inv.max() + 1, 3))
    for k in range(3):
        np.add.at(acc, inv[tri[:, k]], fn)
    n = acc[inv]
    ln = np.linalg.norm(n, axis=1, keepdims=True)
    return np.where(ln > 1e-12, n / np.maximum(ln, 1e-12), np.array([0.0, 0.0, 1.0]))


class Frame:
    """Body coordinates: x across, w = height from the soles, z front, all in body heights."""

    def __init__(self, v):
        lo, hi = v.min(0), v.max(0)
        self.h = hi[1] - lo[1]
        self.o = np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])

    def to_body(self, v):
        return (v - self.o) / self.h


# --- landmarks of the source mesh (measured with --report; see docs/BODY_STUDY.md) --------------
# Height of each band's centre, how far it reaches up and how far down (body heights). The
# hips taper out slowly down the thigh, so the widening has no corner where it ends.
WAIST = (0.625, 0.075, 0.075, 0.053)  # centre, up, down, the half-width it changes (waist at its narrowest)
HIPS = (0.50, 0.085, 0.14, 0.094)
BUST_RADII = np.array([0.06, 0.075, 0.08])  # x, w, z reach of each lobe
BUTT_C = np.array([0.04, 0.515, -0.045])  # x (each side), w, z of a cheek's centre, inside the surface
BUTT_RADII = np.array([0.07, 0.075, 0.07])
STOMACH_C = np.array([0.0, 0.57, 0.045])
STOMACH_RADII = np.array([0.08, 0.085, 0.09])
TORSO_Z = 0.02  # the torso's depth centre at the waist


def bust_centres(p):
    """The apex of each breast: the mean of the highest-forward points on each side. The mesh
    repeats points; each position counts once (as it does once the game has imported it)."""
    p = np.unique(p, axis=0)
    out = []
    for s in (-1.0, 1.0):
        sel = (p[:, 1] > 0.65) & (p[:, 1] < 0.75) & (s * p[:, 0] > 0.008) & (s * p[:, 0] < 0.07) & (p[:, 2] > 0.06)
        top = p[sel]
        top = top[top[:, 2] > top[:, 2].max() - 0.006]
        c = top.mean(0)
        c[2] -= 0.015  # centre a little inside, so the surface sits at the peak of the falloff
        out.append(c)
    return out


def inflate(p, n, centre, radii, amount, forward=0.5, droop=0.0, toward=1.0):
    """Push the surface out (or in) inside a soft ellipsoid: along its normal, blended with
    straight to the front (toward = 1) or the back (-1) so the swelling does not spread
    sideways, and sagging by `droop`."""
    d = np.linalg.norm((p - centre) / radii, axis=1)
    k = (amount * bump(d))[:, None]
    out = (n * (1.0 - forward) + np.array([0.0, 0.0, forward * toward])) * k
    out[:, 1] -= droop * k[:, 0]
    return out


def deform(p, n, bust=0.0, waist=0.0, hips=0.0, stomach=0.0, butt=0.0):
    """Displacement of each body-space point p (with its welded normal n), in body heights."""
    d = np.zeros_like(p)
    if bust:
        # each breast moves only the points on its own side, so the swelling does not fill the
        # gap between them
        for side, c in zip((-1.0, 1.0), bust_centres(p)):
            on_side = (p[:, 0] * side > 0.0)[:, None]
            d += np.where(on_side, inflate(p, n, c, BUST_RADII, bust / CM, 0.5, 0.25), 0.0)
    if butt:  # the same for the cheeks, pushed back, so the cleft stays
        for side in (-1.0, 1.0):
            on_side = (p[:, 0] * side > 0.0)[:, None]
            c = np.array([side * BUTT_C[0], BUTT_C[1], BUTT_C[2]])
            d += np.where(on_side, inflate(p, n, c, BUTT_RADII, butt / CM, 0.5, 0.0, -1.0), 0.0)
    if stomach:
        d += inflate(p, n, STOMACH_C, STOMACH_RADII, stomach / CM, 0.6)
    for amount, (centre, up, down, half_x) in ((waist, WAIST), (hips, HIPS)):
        if amount:
            k = (amount / CM) / half_x  # change in half-width, as a scale of the torso's width
            w = p[:, 1]
            band = np.where(w > centre, bump((w - centre) / up), bump((centre - w) / down))
            d[:, 0] += p[:, 0] * k * band
            d[:, 2] += (p[:, 2] - TORSO_Z) * k * 0.6 * band
    return d


def reshape(src, out, **amounts):
    lines, v, vn, tri = load_obj(src)
    fr = Frame(v)
    p = fr.to_body(v)
    n0 = welded_normals(v, tri)
    d = deform(p, n0, **amounts) * fr.h
    v1 = v + d
    n1 = welded_normals(v1, tri)
    vn1 = vn + (n1 - n0)  # keep any hard edge the source had, add the change in shape
    vn1 /= np.maximum(np.linalg.norm(vn1, axis=1, keepdims=True), 1e-12)
    moved = np.linalg.norm(d, axis=1) > 1e-9
    os.makedirs(os.path.dirname(out), exist_ok=True)
    iv = ivn = 0
    with open(out, "w", newline="\n") as fh:
        text = []
        for line in lines:
            if line.startswith("v "):
                text.append("v %.9g %.9g %.9g " % tuple(v1[iv]) if moved[iv] else line)
                iv += 1
            elif line.startswith("vn "):
                text.append("vn %.9g %.9g %.9g " % tuple(vn1[ivn]) if moved[ivn] else line)
                ivn += 1
            else:
                text.append(line)
        fh.write("\n".join(text))
    return v1, fr, int(moved.sum()), float(np.abs(d).max() * CM)


def report(path):
    _, v, _, _ = load_obj(path)
    p = Frame(v).to_body(v)
    print("slice  half-width(cm)  front(cm)  back(cm)   [torso only, bust band excludes the arms]")
    for name, w, lim in (("bust", 0.70, 0.085), ("under-bust", 0.66, 0.085), ("waist", 0.625, 0.12),
                         ("stomach", 0.555, 0.12), ("hips", 0.50, 0.12)):
        sel = (np.abs(p[:, 1] - w) < 0.008) & (np.abs(p[:, 0]) < lim)
        q = p[sel]
        print("%-10s %8.1f %12.1f %10.1f" % (name, q[:, 0].max() * CM, q[:, 2].max() * CM, q[:, 2].min() * CM))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--src", default=SRC)
    ap.add_argument("--out")
    ap.add_argument("--presets", action="store_true")
    ap.add_argument("--preset", help="a preset saved by the body editor")
    ap.add_argument("--report", action="store_true")
    for k in ("bust", "waist", "hips", "stomach", "butt"):
        ap.add_argument("--" + k, type=float, default=None, help="cm, negative to reduce")
    a = ap.parse_args()
    amounts = {k: 0.0 for k in ("bust", "waist", "hips", "stomach", "butt")}
    if a.preset:
        with open(SAVED) as fh:
            amounts.update(json.load(fh)["presets"][a.preset])
    amounts.update({k: getattr(a, k) for k in amounts if getattr(a, k) is not None})
    if a.report:
        report(a.src)
        return
    if a.presets:
        os.makedirs(STUDY, exist_ok=True)
        shutil.copyfile(a.src, os.path.join(STUDY, "oto_clone.obj"))
        print("oto_clone.obj  (unchanged copy)")
        for name, amounts in PRESETS.items():
            out = os.path.join(STUDY, "oto_%s.obj" % name)
            _, _, moved, mx = reshape(a.src, out, **amounts)
            print("oto_%s.obj  %s  moved %d points, up to %.2f cm" % (name, amounts, moved, mx))
        return
    if not a.out:
        ap.error("--out, --presets or --report")
    _, _, moved, mx = reshape(a.src, a.out, **amounts)
    print("%s: moved %d points, up to %.2f cm" % (a.out, moved, mx))


if __name__ == "__main__":
    main()
