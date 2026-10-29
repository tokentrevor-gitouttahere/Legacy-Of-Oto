"""Procedural tile-map generator for levels/*.json (see docs/LEVEL_FORMAT.md).

CLI (prints JSON, or writes it with --out):
    python tools/gen_level.py city --id my_city --name "My City" --cols 80 --rows 60 --seed 3 --style west
    python tools/gen_level.py town --id village --cols 50 --rows 40
    python tools/gen_level.py wild --id forest --kind forest|wasteland|plains|snow
    python tools/gen_level.py island --id isle --cols 40 --rows 40
    python tools/gen_level.py interior --id hut_inside --cols 14 --rows 10 --floor W

Library use (see tools/make_locations.py): every generator returns a Grid you
can edit (fill, put, paint landmarks) before calling level_json().
"""
import argparse
import json
import random


class Grid:
    def __init__(self, cols, rows, fill="."):
        self.cols, self.rows = cols, rows
        self.cells = [[fill] * cols for _ in range(rows)]
        self.props, self.npcs, self.enemies = [], [], []
        self.pickups = []  # placed pickups: {"kind": "red3", "at": [c, r]}, collected once
        self.spawns, self.exits = {}, {}
        self.blocks = []  # city blocks: (x0, y0, x1, y1) inclusive

    def inside(self, c, r):
        return 0 <= c < self.cols and 0 <= r < self.rows

    def get(self, c, r):
        return self.cells[r][c] if self.inside(c, r) else " "

    def put(self, c, r, ch):
        if self.inside(c, r):
            self.cells[r][c] = ch

    def fill(self, c0, r0, c1, r1, ch):
        """Fill the inclusive rectangle."""
        for r in range(r0, r1 + 1):
            for c in range(c0, c1 + 1):
                self.put(c, r, ch)

    def ring(self, c0, r0, c1, r1, ch):
        for c in range(c0, c1 + 1):
            self.put(c, r0, ch)
            self.put(c, r1, ch)
        for r in range(r0, r1 + 1):
            self.put(c0, r, ch)
            self.put(c1, r, ch)

    def blob(self, cx, cy, radius, ch, rng, only=None):
        """Roughly circular blob with a noisy edge."""
        for r in range(int(cy - radius - 2), int(cy + radius + 3)):
            for c in range(int(cx - radius - 2), int(cx + radius + 3)):
                d = ((c - cx) ** 2 + (r - cy) ** 2) ** 0.5
                if d < radius + rng.uniform(-1.2, 1.2) and (only is None or self.get(c, r) in only):
                    self.put(c, r, ch)

    def scatter(self, ch, count, rng, only=".", margin=2):
        for _ in range(count):
            c = rng.randint(margin, self.cols - 1 - margin)
            r = rng.randint(margin, self.rows - 1 - margin)
            if self.get(c, r) in only:
                self.put(c, r, ch)

    def path(self, a, b, ch, width=1, only=None):
        """L-shaped path between two cells."""
        (c0, r0), (c1, r1) = a, b
        for c in range(min(c0, c1), max(c0, c1) + 1):
            for w in range(width):
                if only is None or self.get(c, r0 + w) in only:
                    self.put(c, r0 + w, ch)
        for r in range(min(r0, r1), max(r0, r1) + 1):
            for w in range(width):
                if only is None or self.get(c1 + w, r) in only:
                    self.put(c1 + w, r, ch)

    def prop(self, type_, col, row, rot=0, **params):
        spec = {"type": type_, "at": [col, row]}
        if rot:
            spec["rot"] = rot
        if params:
            spec["params"] = params
        self.props.append(spec)
        return spec

    def npc(self, name, outfit, c, r, lines, rot=0, model=None, **extra):
        spec = {"name": name, "at": [c, r], "lines": lines}
        if outfit:
            spec["outfit"] = outfit
        if rot:
            spec["rot"] = rot
        if model:
            spec["model"] = model
        spec.update(extra)
        self.npcs.append(spec)

    def rows_text(self):
        return ["".join(row) for row in self.cells]


def level_json(grid, id_, name, **meta):
    d = {"id": id_, "name": name}
    d.update(meta)
    d["grid"] = grid.rows_text()
    if grid.spawns:
        d["spawns"] = grid.spawns
    if grid.exits:
        d["exits"] = grid.exits
    if grid.props:
        d["props"] = grid.props
    if grid.npcs:
        d["npcs"] = grid.npcs
    if grid.enemies:
        d["enemies"] = grid.enemies
    if grid.pickups:
        d["pickups"] = grid.pickups
    return d


def dump(d):
    """JSON with one grid row per line, so the map stays readable in diffs."""
    grid = d.pop("grid")
    body = json.dumps(d, indent=1)
    rows = ",\n".join("  " + json.dumps(row) for row in grid)
    d["grid"] = grid
    return body[:-2] + ',\n "grid": [\n' + rows + "\n ]\n}\n"


# --- generators -----------------------------------------------------------------

def city(cols, rows, seed=1, block=9, road=2, margin=3, park_rate=0.15, base="."):
    """Grid of roads (=), sidewalks (_), building lots (B), parks, lamps (L).
    Road ends at the map edge become exit "1" (to the world map)."""
    rng = random.Random(seed)
    g = Grid(cols, rows, base)
    step = block + road
    xs = list(range(margin, cols - margin, step))
    ys = list(range(margin, rows - margin, step))
    for x in xs:
        g.fill(x, 0, x + road - 1, rows - 1, "=")
    for y in ys:
        g.fill(0, y, cols - 1, y + road - 1, "=")
    for i, x in enumerate(xs[:-1]):
        for j, y in enumerate(ys[:-1]):
            x0, y0, x1, y1 = x + road, y + road, xs[i + 1] - 1, ys[j + 1] - 1
            if x1 - x0 < 3 or y1 - y0 < 3:
                continue
            g.blocks.append((x0, y0, x1, y1))
            g.ring(x0, y0, x1, y1, "_")
            for (c, r) in [(x0, y0), (x1, y0), (x0, y1), (x1, y1)]:
                g.put(c, r, "L")
            if rng.random() < park_rate:
                g.fill(x0 + 1, y0 + 1, x1 - 1, y1 - 1, ".")
                g.scatter("T", (x1 - x0) * (y1 - y0) // 10, rng, only=".", margin=0)
                g.prop("fountain", (x0 + x1) / 2, (y0 + y1) / 2)
            else:
                _lots(g, x0 + 1, y0 + 1, x1 - 1, y1 - 1, rng)
    # exits where roads leave the map
    for x in xs:
        for c in range(x, x + road):
            g.put(c, 0, "1")
            g.put(c, rows - 1, "1")
    for y in ys:
        for r in range(y, y + road):
            g.put(0, r, "1")
            g.put(cols - 1, r, "1")
    g.exits["1"] = {"to": "world"}
    g.spawns["default"] = [xs[len(xs) // 2] + road // 2, ys[len(ys) // 2] + road + 1]
    return g


def _lots(g, x0, y0, x1, y1, rng):
    """Split a block interior into building lots separated by 1-cell paths."""
    c = x0
    while c <= x1:
        w = min(rng.randint(3, 5), x1 - c + 1)
        r = y0
        while r <= y1:
            h = min(rng.randint(3, 5), y1 - r + 1)
            if w >= 2 and h >= 2:
                g.fill(c, r, c + w - 1, r + h - 1, "B")
            r += h + 1
        c += w + 1


def clear_block(g, blk, fill="+", keep_ring=True):
    x0, y0, x1, y1 = blk
    if keep_ring:
        g.fill(x0 + 1, y0 + 1, x1 - 1, y1 - 1, fill)
    else:
        g.fill(x0, y0, x1, y1, fill)


def town(cols, rows, seed=1, houses=10, base="."):
    """Village: dirt paths (,), dome houses (B lots, village style), trees, fields."""
    rng = random.Random(seed)
    g = Grid(cols, rows, base)
    cx, cy = cols // 2, rows // 2
    g.fill(cx - 1, 0, cx, rows - 1, ",")
    g.fill(0, cy - 1, cols - 1, cy, ",")
    placed = 0
    for _ in range(houses * 10):
        if placed >= houses:
            break
        c = rng.randint(3, cols - 7)
        r = rng.randint(3, rows - 7)
        if all(g.get(cc, rr) == base for cc in range(c - 1, c + 5) for rr in range(r - 1, r + 5)):
            g.fill(c, r, c + 2, r + 2, "B")
            g.path((c + 1, r + 3), (cx, r + 3), ",", only=base)
            placed += 1
    g.scatter("T", cols * rows // 40, rng)
    g.scatter("b", cols * rows // 60, rng)
    for x in (cx - 1, cx):
        g.put(x, 0, "1")
        g.put(x, rows - 1, "1")
    for y in (cy - 1, cy):
        g.put(0, y, "1")
        g.put(cols - 1, y, "1")
    g.exits["1"] = {"to": "world"}
    g.spawns["default"] = [cx, cy + 2]
    return g


def wild(cols, rows, seed=1, kind="forest"):
    """Open terrain. forest: trees and a pond. wasteland: mesas and rocks.
    plains: grass, flowers, scattered trees. snow: pines on snow."""
    rng = random.Random(seed)
    base = {"forest": ".", "wasteland": "o", "plains": ".", "snow": "s"}[kind]
    g = Grid(cols, rows, base)
    if kind == "forest":
        for _ in range(6):
            g.blob(rng.randint(0, cols), rng.randint(0, rows), rng.randint(4, 9), "T", rng, only=".")
        g.blob(cols * 0.3, rows * 0.65, 4, "~", rng)
        g.scatter("b", cols * rows // 50, rng)
    elif kind == "wasteland":
        g.scatter("M", cols * rows // 90, rng, only="o")
        g.scatter("r", cols * rows // 60, rng, only="o")
        for _ in range(3):
            g.blob(rng.randint(0, cols), rng.randint(0, rows), rng.randint(3, 6), ";", rng, only="o")
    elif kind == "plains":
        g.scatter("T", cols * rows // 120, rng)
        g.scatter("b", cols * rows // 80, rng)
    elif kind == "snow":
        for _ in range(5):
            g.blob(rng.randint(0, cols), rng.randint(0, rows), rng.randint(3, 7), "P", rng, only="s")
    cx, cy = cols // 2, rows // 2
    g.fill(cx - 2, cy - 2, cx + 2, cy + 2, base)
    g.ring(0, 0, cols - 1, rows - 1, "1")
    g.exits["1"] = {"to": "world"}
    g.spawns["default"] = [cx, cy]
    return g


def island(cols, rows, seed=1, radius=None):
    rng = random.Random(seed)
    g = Grid(cols, rows, "~")
    r = radius or min(cols, rows) * 0.3
    g.blob(cols / 2, rows / 2, r, ":", rng)
    g.blob(cols / 2, rows / 2, r * 0.55, ".", rng, only=":")
    g.scatter("Y", int(r * 1.5), rng, only=":")
    g.spawns["default"] = [cols // 2, int(rows / 2 + r * 0.6)]
    return g


def interior(cols, rows, floor="W"):
    """A walled room with a void border (south walls render low for the camera)
    and an exit door "1" in the middle of the south wall."""
    g = Grid(cols + 2, rows + 2, " ")
    g.fill(1, 1, cols, rows, floor)
    g.ring(1, 1, cols, rows, "#")
    door = (cols + 2) // 2
    g.put(door, rows, "1")
    g.spawns["default"] = [door, rows - 1]
    g.spawns["door"] = [door, rows - 1]
    return g


# --- region kit (docs/REGIONS.md) -------------------------------------------------
# Building blocks for big outdoor and underground regions, reusable for any new location:
# value noise, winding paths, reachability, and four region builders. Tile letters are in
# docs/LEVEL_FORMAT.md: K cliff, n sandstone, k cactus, h hoodoo, q gravel, i ice, I ice spikes,
# g snowy pine, d drift, v cave floor, V cave wall, X crystals, u mushrooms, Z stalagmite, w deep water.

import math as _math


class Noise:
    """Smooth 2D value noise in [0, 1]; `scale` is the feature size in cells."""

    def __init__(self, seed, scale=8.0, octaves=3):
        self.rng = random.Random(seed)
        self.scale = scale
        self.octaves = octaves
        self.table = [self.rng.random() for _ in range(4096)]

    def _v(self, x, y):
        return self.table[(x * 73856093 ^ y * 19349663) & 4095]

    def _smooth(self, x, y):
        x0, y0 = _math.floor(x), _math.floor(y)
        fx, fy = x - x0, y - y0
        fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        a = self._v(x0, y0) + (self._v(x0 + 1, y0) - self._v(x0, y0)) * fx
        b = self._v(x0, y0 + 1) + (self._v(x0 + 1, y0 + 1) - self._v(x0, y0 + 1)) * fx
        return a + (b - a) * fy

    def __call__(self, c, r):
        total, amp, norm, f = 0.0, 1.0, 0.0, 1.0 / self.scale
        for _ in range(self.octaves):
            total += self._smooth(c * f, r * f) * amp
            norm += amp
            amp *= 0.5
            f *= 2.0
        return total / norm


def wander(g, a, b, ch, width, rng, wiggle=0.35, step=4):
    """A winding path of `ch` from a to b, `width` cells wide (valleys, trails, rock bridges)."""
    (c, r), (c1, r1) = a, b
    pts = [(c, r)]
    n = max(int(max(abs(c1 - c), abs(r1 - r)) / step), 1)
    for i in range(1, n):
        t = i / n
        pc, pr = c + (c1 - c) * t, r + (r1 - r) * t
        span = max(abs(c1 - c), abs(r1 - r)) * wiggle
        pts.append((pc + rng.uniform(-span, span) * 0.25, pr + rng.uniform(-span, span) * 0.25))
    pts.append((c1, r1))
    rad = width / 2.0
    for p, q in zip(pts, pts[1:]):  # a round brush along each segment, so bends are smooth
        steps = max(int(max(abs(q[0] - p[0]), abs(q[1] - p[1])) * 2), 1)
        for k in range(steps + 1):
            x = p[0] + (q[0] - p[0]) * k / steps
            y = p[1] + (q[1] - p[1]) * k / steps
            for dr in range(-int(rad) - 1, int(rad) + 2):
                for dc in range(-int(rad) - 1, int(rad) + 2):
                    if dc * dc + dr * dr <= rad * rad + 0.25:
                        cc, rr = int(round(x + dc)), int(round(y + dr))
                        if g.inside(cc, rr):
                            g.put(cc, rr, ch)


def reachable(g, start, walkable):
    """Cells reachable on foot from `start` through characters in `walkable` (and exits)."""
    seen = {tuple(start)}
    todo = [tuple(start)]
    while todo:
        c, r = todo.pop()
        for dc, dr in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nb = (c + dc, r + dr)
            if nb not in seen and g.inside(*nb) and (g.get(*nb) in walkable or g.get(*nb).isdigit()):
                seen.add(nb)
                todo.append(nb)
    return seen


def seal_unreachable(g, start, walkable, wall):
    """Turn walkable pockets nobody can reach from `start` into `wall`, so nothing is placed
    where Oto cannot go. Returns how many cells were sealed."""
    ok = reachable(g, start, walkable)
    n = 0
    for r in range(g.rows):
        for c in range(g.cols):
            if g.get(c, r) in walkable and (c, r) not in ok:
                g.put(c, r, wall)
                n += 1
    return n


def cutaway(g, wall):
    """The camera looks north from the south: solid `wall` with more wall to its north is
    made void from the bottom up, leaving one row of wall along the floor's south edge, so
    rock below the floor never stands between the camera and Oto."""
    for c in range(g.cols):
        r = g.rows - 1
        while r > 0 and g.get(c, r) in (wall, "X") and g.get(c, r - 1) in (wall, "X"):
            g.put(c, r, " ")
            r -= 1


def _edge_exit(g):
    g.ring(0, 0, g.cols - 1, g.rows - 1, "1")
    g.exits["1"] = {"to": "world"}


def canyons(cols, rows, seed=1):
    """Desert: mesas and canyon walls (K) over sand, sandstone valleys winding between them,
    hoodoos, cacti, rocks and dead trees. Spawn in the middle; the map edge leads out."""
    rng = random.Random(seed)
    nz = Noise(seed, scale=9.0)
    g = Grid(cols, rows, ":")
    for r in range(rows):
        for c in range(cols):
            v = nz(c, r)
            if v > 0.6:
                g.put(c, r, "K")
            elif v > 0.55:
                g.put(c, r, "n")
    cx, cy = cols // 2, rows // 2
    for _ in range(5):  # valleys from the middle out to the edges
        a = rng.uniform(0, _math.tau)
        end = (int(cx + _math.cos(a) * cols * 0.48), int(cy + _math.sin(a) * rows * 0.48))
        wander(g, (cx, cy), end, "n", 3, rng)
    for _ in range(3):  # side canyons
        wander(g, (rng.randint(4, cols - 5), rng.randint(4, rows - 5)), (rng.randint(4, cols - 5), rng.randint(4, rows - 5)), "n", 2, rng)
    g.scatter("k", cols * rows // 70, rng, only=":")
    g.scatter("h", cols * rows // 160, rng, only="n:")
    g.scatter("r", cols * rows // 120, rng, only=":n")
    g.fill(cx - 3, cy - 3, cx + 3, cy + 3, "n")
    g.spawns["default"] = [cx, cy]
    _edge_exit(g)
    seal_unreachable(g, (cx, cy), set(":n"), "K")
    return g


def peaks(cols, rows, seed=1):
    """Mountains: ridges of grey cliff (K) and crags, scree slopes (q), alpine meadows in the
    valleys, pines, and snow toward the summit (north). A switchback trail climbs to the top."""
    rng = random.Random(seed)
    nz = Noise(seed, scale=7.0)
    ridge = Noise(seed + 1, scale=14.0)
    g = Grid(cols, rows, ".")
    for r in range(rows):
        for c in range(cols):
            alt = 1.0 - r / rows  # higher to the north
            v = nz(c, r) * 0.65 + abs(ridge(c, r) - 0.5) * 0.9 + alt * 0.25
            snow = alt > 0.7
            if v > 0.78:
                g.put(c, r, "K")
            elif v > 0.68:
                g.put(c, r, "s" if snow else "q")
            elif v > 0.6:
                g.put(c, r, "s" if snow else ";")
            elif snow:
                g.put(c, r, "s")
    cx, cy = cols // 2, rows - 6
    sx, sy = cols // 2, 5
    pts = [(cx, cy)]
    for k in range(1, 6):  # switchbacks up the slope
        pts.append((cols // 2 + (cols // 3 if k % 2 else -cols // 3), cy - (cy - sy) * k // 6))
    pts.append((sx, sy))
    for p, q in zip(pts, pts[1:]):
        wander(g, p, q, ",", 2, rng, wiggle=0.15)
    g.scatter("P", cols * rows // 50, rng, only=".")
    g.scatter("g", cols * rows // 90, rng, only="s")
    g.scatter("r", cols * rows // 90, rng, only=".;q")
    g.fill(cx - 2, cy - 2, cx + 2, cy + 2, ",")
    g.fill(sx - 2, sy - 2, sx + 2, sy + 2, "s")
    g.spawns["default"] = [cx, cy]
    g.spawns["summit"] = [sx, sy + 1]
    _edge_exit(g)
    seal_unreachable(g, (cx, cy), set(".,;qs"), "K")
    return g


def ice_fields(cols, rows, seed=1):
    """Arctic: snowfields and sea ice (i) with leads of open water, ice cliffs (K), ice-spike
    clusters, drifts and snowy pines along the landward (south) edge."""
    rng = random.Random(seed)
    nz = Noise(seed, scale=8.0)
    cracks = Noise(seed + 7, scale=5.0)
    g = Grid(cols, rows, "s")
    for r in range(rows):
        for c in range(cols):
            sea = 1.0 - r / rows  # the sea ice lies north
            v = nz(c, r)
            if sea > 0.45 and v < 0.55:
                g.put(c, r, "i")
                if abs(cracks(c, r) - 0.5) < 0.03 and sea > 0.55:
                    g.put(c, r, "~")
            elif v > 0.72:
                g.put(c, r, "K")
    g.scatter("I", cols * rows // 80, rng, only="si")
    g.scatter("d", cols * rows // 50, rng, only="s")
    for _ in range(4):
        g.blob(rng.randint(0, cols), rng.randint(int(rows * 0.7), rows), rng.randint(3, 5), "g", rng, only="s")
    cx, cy = cols // 2, int(rows * 0.7)
    g.fill(cx - 3, cy - 3, cx + 3, cy + 3, "s")
    g.spawns["default"] = [cx, cy]
    _edge_exit(g)
    seal_unreachable(g, (cx, cy), set("sid"), "K")
    return g


def cavern(cols, rows, seed=1, lake=0.32):
    """Underground: a cave grown by cellular automaton (V walls, v floor), a huge dark lake (w)
    in the middle with an island reached by a winding rock bridge, crystals on the walls,
    mushrooms and stalagmites. The entrance (exit "1") is on the south wall."""
    rng = random.Random(seed)
    g = Grid(cols, rows, "V")
    cells = [[rng.random() < 0.5 for _ in range(cols)] for _ in range(rows)]
    for _ in range(5):
        nxt = [[False] * cols for _ in range(rows)]
        for r in range(rows):
            for c in range(cols):
                n = sum(cells[rr][cc] for rr in range(r - 1, r + 2) for cc in range(c - 1, c + 2)
                        if 0 <= rr < rows and 0 <= cc < cols and (rr, cc) != (r, c))
                nxt[r][c] = n >= 5 or (cells[r][c] and n >= 4)
        cells = nxt
    for r in range(2, rows - 2):
        for c in range(2, cols - 2):
            if cells[r][c]:
                g.put(c, r, "v")
    cx, cy = cols // 2, rows // 2
    # the lake: an oval, ragged at the shore, with an island
    rx, ry = cols * lake, rows * lake
    for r in range(rows):
        for c in range(cols):
            d = ((c - cx) / rx) ** 2 + ((r - cy) / ry) ** 2
            if d < 1.0 + rng.uniform(-0.12, 0.12):
                g.put(c, r, "w")
            elif d < 1.6 and g.get(c, r) == "V" and 2 < c < cols - 3 and 2 < r < rows - 3:
                g.put(c, r, "v")  # a walkable shore all the way round
    g.blob(cx + rx * 0.25, cy - ry * 0.15, max(rx * 0.22, 3), "v", rng)
    ex, ey = cx, rows - 3
    wander(g, (ex, ey), (cx, int(cy + ry * 1.1)), "v", 3, rng, wiggle=0.2)
    island = (int(cx + rx * 0.25), int(cy - ry * 0.15))
    wander(g, (cx, int(cy + ry * 1.05)), island, "v", 2, rng, wiggle=0.4)  # the rock bridge
    g.spawns["default"] = [ex, ey]
    g.spawns["island"] = list(island)
    seal_unreachable(g, (ex, ey), set("v"), "V")
    # dress the walls: crystals where the floor meets them, mushrooms and stalagmites on the floor
    for r in range(1, rows - 1):
        for c in range(1, cols - 1):
            if g.get(c, r) == "V" and any(g.get(c + dc, r + dr) == "v" for dc, dr in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                if rng.random() < 0.12:
                    g.put(c, r, "X")
    g.scatter("u", cols * rows // 45, rng, only="v")
    g.scatter("Z", cols * rows // 110, rng, only="v")
    for k in ("default", "island"):
        c, r = g.spawns[k]
        g.fill(c - 1, r - 1, c + 1, r + 1, "v")
    cutaway(g, "V")
    g.put(ex, rows - 2, "1")  # the way out, last so nothing paints over it
    for c in range(ex - 2, ex + 3):
        g.put(c, rows - 1, " ")
    g.exits["1"] = {"to": "world"}
    return g


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("kind", choices=["city", "town", "wild", "island", "interior"])
    ap.add_argument("--id", required=True)
    ap.add_argument("--name", default="")
    ap.add_argument("--cols", type=int, default=60)
    ap.add_argument("--rows", type=int, default=45)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--style", default="west", help="city building style: west, modern, village")
    ap.add_argument("--wild", dest="wild_kind", default="forest")
    ap.add_argument("--floor", default="W")
    ap.add_argument("--out", default="")
    a = ap.parse_args()
    meta = {"sky": "day"}
    if a.kind == "city":
        g = city(a.cols, a.rows, a.seed)
        meta.update(city_style=a.style, base=".", backdrop="skyline")
    elif a.kind == "town":
        g = town(a.cols, a.rows, a.seed)
        meta.update(city_style="village", base=".", backdrop="mountains")
    elif a.kind == "wild":
        g = wild(a.cols, a.rows, a.seed, a.wild_kind)
        meta.update(base={"wasteland": "wasteland", "snow": "snow"}.get(a.wild_kind, "grass"),
                    sky="wasteland" if a.wild_kind == "wasteland" else "day",
                    backdrop="mesas" if a.wild_kind == "wasteland" else "mountains")
    elif a.kind == "island":
        g = island(a.cols, a.rows, a.seed)
        meta.update(base="sand", backdrop="ocean")
    else:
        g = interior(a.cols, a.rows, a.floor)
        g.exits["1"] = {"to": "world"}
        meta.update(interior=True, tile=1.5, sky="interior", floor={"W": "wood", "F": "tile", "C": "carpet"}.get(a.floor, "wood"))
    d = level_json(g, a.id, a.name or a.id.replace("_", " ").title(), **meta)
    text = dump(d)
    if a.out:
        open(a.out, "w").write(text)
        print("wrote", a.out)
    else:
        print(text)


if __name__ == "__main__":
    main()
