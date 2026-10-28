"""Repair an OBJ for rigging (Mixamo): weld duplicate points, drop broken (zero-area)
triangles, recompute smooth normals, and report the mesh's health before and after.

    python tools/clean_mesh.py assets/models/base_female/model_0.obj mixamo_upload/oto_clean.obj
    python tools/clean_mesh.py <in.obj> <out.obj> --zip mixamo_upload/oto_clean.zip

The input is left unchanged. Positions, the triangles' winding and the scale are kept, so
the clean mesh lines up exactly with the original (and with landmarks.json).

A mesh with texture coordinates (vt) keeps them: only its broken triangles are dropped and every
other line is copied as it is, so the .mtl and textures still apply. --zip-extra adds those files.
"""
import argparse
import math
import os
import zipfile
from collections import defaultdict


def load(path):
    V, F = [], []
    for line in open(path, encoding="utf-8", errors="replace"):
        p = line.split()
        if not p:
            continue
        if p[0] == "v":
            V.append(tuple(map(float, p[1:4])))
        elif p[0] == "f":
            idx = [int(t.split("/")[0]) - 1 for t in p[1:]]
            for k in range(1, len(idx) - 1):
                F.append((idx[0], idx[k], idx[k + 1]))
    return V, F


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def health(V, F, label):
    edges = defaultdict(int)
    broken = 0
    for f in F:
        if len(set(f)) < 3 or math.sqrt(sum(x * x for x in cross(sub(V[f[1]], V[f[0]]), sub(V[f[2]], V[f[0]])))) < 1e-12:
            broken += 1
            continue
        for a, b in ((f[0], f[1]), (f[1], f[2]), (f[2], f[0])):
            edges[(min(a, b), max(a, b))] += 1
    open_e = sum(1 for n in edges.values() if n == 1)
    nonman = sum(1 for n in edges.values() if n > 2)
    used = {i for f in F for i in f}
    print("%-6s points %5d (used %5d)  triangles %5d  broken %5d  open edges %d  non-manifold edges %d"
          % (label, len(V), len(used), len(F), broken, open_e, nonman))


def clean(V, F):
    key, remap, out_v = {}, [], []
    for v in V:  # weld points that sit on top of each other
        k = (round(v[0], 6), round(v[1], 6), round(v[2], 6))
        if k not in key:
            key[k] = len(out_v)
            out_v.append(v)
        remap.append(key[k])
    seen, out_f = set(), []
    for f in F:
        g = tuple(remap[i] for i in f)
        if len(set(g)) < 3:
            continue
        n = cross(sub(out_v[g[1]], out_v[g[0]]), sub(out_v[g[2]], out_v[g[0]]))
        if math.sqrt(sum(x * x for x in n)) < 1e-12:
            continue
        s = tuple(sorted(g))
        if s in seen:  # the same triangle twice
            continue
        seen.add(s)
        out_f.append(g)
    used = sorted({i for f in out_f for i in f})  # drop points no triangle uses
    pack = {old: new for new, old in enumerate(used)}
    return [out_v[i] for i in used], [tuple(pack[i] for i in f) for f in out_f]


def normals(V, F):
    acc = [[0.0, 0.0, 0.0] for _ in V]
    for f in F:  # area-weighted face normals
        n = cross(sub(V[f[1]], V[f[0]]), sub(V[f[2]], V[f[0]]))
        for i in f:
            for k in range(3):
                acc[i][k] += n[k]
    out = []
    for a in acc:
        L = math.sqrt(sum(x * x for x in a)) or 1.0
        out.append((a[0] / L, a[1] / L, a[2] / L))
    return out


def drop_broken_keep_uv(src, dst, V):
    """Copy the OBJ, leaving out faces whose corners share a position or have no area."""
    dropped = 0
    with open(dst, "w", encoding="utf-8", newline="\n") as out:
        for line in open(src, encoding="utf-8", errors="replace"):
            p = line.split()
            if p and p[0] == "f":
                idx = [int(t.split("/")[0]) - 1 for t in p[1:]]
                pts = [tuple(round(c, 6) for c in V[i]) for i in idx]
                n = cross(sub(V[idx[1]], V[idx[0]]), sub(V[idx[2]], V[idx[0]])) if len(idx) == 3 else (1, 0, 0)
                if len(set(pts)) < len(pts) or math.sqrt(sum(x * x for x in n)) < 1e-12:
                    dropped += 1
                    continue
            out.write(line if line.endswith("\n") else line + "\n")
    return dropped


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--zip", default="")
    ap.add_argument("--zip-extra", nargs="*", default=[])
    a = ap.parse_args()
    V, F = load(a.src)
    if any(l.startswith("vt ") for l in open(a.src, encoding="utf-8", errors="replace")):
        health(V, F, "before")
        print("has texture coordinates: dropped %d broken faces, kept everything else" % drop_broken_keep_uv(a.src, a.dst, V))
        V2, F2 = load(a.dst)
        health(V2, F2, "after")
        if a.zip:
            with zipfile.ZipFile(a.zip, "w", zipfile.ZIP_DEFLATED) as z:
                z.write(a.dst, os.path.basename(a.dst))
                for e in a.zip_extra:
                    z.write(e, os.path.basename(e))
            print(a.zip)
        return
    health(V, F, "before")
    V2, F2 = clean(V, F)
    health(V2, F2, "after")
    N = normals(V2, F2)
    name = os.path.splitext(os.path.basename(a.dst))[0]
    with open(a.dst, "w", encoding="utf-8", newline="\n") as out:
        out.write("# cleaned by tools/clean_mesh.py from %s\no %s\n" % (os.path.basename(a.src), name))
        for v in V2:
            out.write("v %.6f %.6f %.6f\n" % v)
        for n in N:
            out.write("vn %.5f %.5f %.5f\n" % n)
        for f in F2:
            out.write("f %d//%d %d//%d %d//%d\n" % (f[0] + 1, f[0] + 1, f[1] + 1, f[1] + 1, f[2] + 1, f[2] + 1))
    print(a.dst)
    if a.zip:
        with zipfile.ZipFile(a.zip, "w", zipfile.ZIP_DEFLATED) as z:
            z.write(a.dst, os.path.basename(a.dst))
            for e in a.zip_extra:
                z.write(e, os.path.basename(e))
        print(a.zip)


if __name__ == "__main__":
    main()
