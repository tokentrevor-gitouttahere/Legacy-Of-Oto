"""Builds the canonical locations into levels/*.json and the world list.

    python tools/make_locations.py            # (re)write every location below
    python tools/make_locations.py west_city  # just one

This is a starting point, not the source of truth: once a level is hand-edited,
remove it from LOCATIONS (or stop running this) so edits are not overwritten.
Each function shows how to compose a level with tools/gen_level.py.
"""
import json
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_level as gl  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LEVELS = os.path.join(ROOT, "levels")


def write(d):
    os.makedirs(LEVELS, exist_ok=True)
    path = os.path.join(LEVELS, d["id"] + ".json")
    with open(path, "w", newline="\n") as f:
        f.write(gl.dump(d))
    print("wrote", os.path.relpath(path, ROOT))


WALKABLE = set(".,:;osmc=_+WFC")


def lantern(g, c, r):
    """A save lantern on the nearest open ground to (c, r): walkable all around, clear of NPCs."""
    taken = {(round(n["at"][0]), round(n["at"][1])) for n in g.npcs}
    taken |= {(int(v[0]), int(v[1])) for v in g.spawns.values()}
    for rad in range(0, 14):
        for dr in range(-rad, rad + 1):
            for dc in range(-rad, rad + 1):
                cc, rr = c + dc, r + dr
                if max(abs(dc), abs(dr)) != rad or (cc, rr) in taken:
                    continue
                if all(g.get(cc + x, rr + y) in WALKABLE for x in (-1, 0, 1) for y in (-1, 0, 1)):
                    g.prop("save_lantern", cc, rr)
                    return
    raise ValueError("no open ground for a lantern near %s" % ((c, r),))


# Beast defaults per kind; a tier (1-4) scales HP, damage and EXP in the game.
BEAST_STATS = {
    "wolf": {"name": "Wolf", "hp": 45, "damage": 5, "speed": 3.2, "xp": 15, "behavior": "pack", "food": "haunch"},
    "boar": {"name": "Boar", "hp": 90, "damage": 8, "speed": 2.6, "xp": 30, "behavior": "charger", "food": "haunch"},
    "raptor": {"name": "Raptor", "hp": 60, "damage": 7, "speed": 3.6, "xp": 22, "behavior": "chase", "food": "haunch"},
    "scorpion": {"name": "Scorpion", "hp": 70, "damage": 8, "speed": 2.0, "xp": 25, "behavior": "chase"},
    "crab": {"name": "Crab", "hp": 80, "damage": 5, "speed": 1.6, "xp": 18, "behavior": "chase", "food": "haunch"},
    "pterodactyl": {"name": "Pterodactyl", "hp": 50, "damage": 6, "speed": 2.8, "xp": 28, "behavior": "shooter", "food": "haunch"},
}


def open_ground(g, c, r):
    return all(g.get(c + x, r + y) in WALKABLE for x in (-1, 0, 1) for y in (-1, 0, 1))


def beasts(g, kind, count, area, seed, tier=1, keep_away=9):
    """`count` beasts of a kind on open ground inside area (c0, r0, c1, r1), at least
    keep_away cells from the default spawn so they are not on Oto as she arrives."""
    rng = random.Random(seed)
    sc, sr = g.spawns.get("default", [-99, -99])
    c0, r0, c1, r1 = area
    placed = 0
    for _ in range(400):
        if placed == count:
            return
        c, r = rng.randint(c0, c1), rng.randint(r0, r1)
        if placed and BEAST_STATS[kind]["behavior"] == "pack":  # a pack sticks together
            first = g.enemies[-placed]["at"]
            c, r = first[0] + rng.randint(-3, 3), first[1] + rng.randint(-3, 3)
        if open_ground(g, c, r) and max(abs(c - sc), abs(r - sr)) >= keep_away:
            spec = {"at": [c, r], "beast": kind, "tier": tier}
            spec.update(BEAST_STATS[kind])
            g.enemies.append(spec)
            placed += 1
    raise ValueError("only placed %d of %d %s in %s" % (placed, count, kind, area))


def shore_spot(g, c, r):
    """A fishing spot on the walkable cell nearest (c, r) that touches water ("~"),
    turned so its jetty points into the water."""
    rot_for = {(0, -1): 0, (0, 1): 180, (1, 0): -90, (-1, 0): 90}
    for rad in range(0, 16):
        for dr in range(-rad, rad + 1):
            for dc in range(-rad, rad + 1):
                cc, rr = c + dc, r + dr
                if max(abs(dc), abs(dr)) != rad or g.get(cc, rr) not in WALKABLE:
                    continue
                for (dx, dy), rot in rot_for.items():
                    if g.get(cc + dx, rr + dy) == "~":
                        g.prop("fishing_spot", cc, rr, rot=rot)
                        return
    raise ValueError("no shore near %s" % ((c, r),))


def merge_blocks(g, blocks, fill):
    """Clear a rectangle covering several city blocks (and the roads between)."""
    x0 = min(b[0] for b in blocks)
    y0 = min(b[1] for b in blocks)
    x1 = max(b[2] for b in blocks)
    y1 = max(b[3] for b in blocks)
    g.fill(x0, y0, x1, y1, fill)
    g.ring(x0, y0, x1, y1, "_")
    return x0, y0, x1, y1


def block_at(g, col, row):
    """The city block containing (col, row), or the nearest one."""
    return min(g.blocks, key=lambda b: abs((b[0] + b[2]) / 2 - col) + abs((b[1] + b[3]) / 2 - row))


CIVILIAN_LINES = [
    ["|They wave.", "Civilian|Lovely day for it."],
    ["Civilian|Did you see the news? Hercule did it again!"],
    ["Civilian|Capsule Corp makes everything. My house is in my pocket."],
    ["Civilian|Careful crossing. The hover cars never stop."],
    ["Civilian|I've never seen hair that colour."],
]


def scatter_civilians(g, count, rng, allowed="_+"):
    outfits = ["civilian_m", "civilian_m2", "civilian_f", "civilian_f2", "shopkeeper"]
    placed = 0
    for _ in range(count * 20):
        if placed >= count:
            break
        c, r = rng.randint(2, g.cols - 3), rng.randint(2, g.rows - 3)
        if g.get(c, r) in allowed:
            g.npc("Citizen", rng.choice(outfits), c, r, rng.choice(CIVILIAN_LINES), rot=rng.choice([0, 90, 180, 270]))
            placed += 1


# --- locations --------------------------------------------------------------------

def west_city():
    rng = random.Random(7)
    g = gl.city(96, 72, seed=7, block=11, road=2)
    # Capsule Corp compound: four blocks around the centre become one campus.
    b1 = block_at(g, 40, 22)
    b2 = block_at(g, 54, 34)
    x0, y0, x1, y1 = merge_blocks(g, [b1, b2], "+")
    g.fill(x0 + 1, y0 + 1, x1 - 1, y1 - 1, ".")
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2 - 1
    g.prop("capsule_corp", cx, cy)
    g.fill(int(cx) - 1, int(cy) + 8, int(cx) + 1, y1, "+")
    g.put(int(cx), int(cy) + 8, "2")
    g.exits["2"] = {"to": "capsule_corp_lab", "spawn": "door"}
    g.spawns["cc_door"] = [int(cx), int(cy) + 10]
    g.spawns["default"] = [int(cx), y1 + 2]
    for c, r in [(x0 + 2, y0 + 2), (x1 - 2, y0 + 2), (x0 + 2, y1 - 2), (x1 - 2, y1 - 2)]:
        g.prop("tree_oak", c, r)
    g.prop("capsule_ship", x1 - 6, y0 + 6)
    g.npc("Bulma", "bulma", int(cx) + 2, int(cy) + 10, [
        "Bulma|Oh! You must be the one Goku found in a hole.",
        "Bulma|Welcome to Capsule Corporation. Don't touch anything that beeps.",
    ], rot=180)
    # Shopping street south of the campus.
    shop_blk = block_at(g, cx, y1 + 10)
    sx0, sy0, sx1, sy1 = shop_blk
    g.fill(sx0 + 1, sy0 + 1, sx1 - 1, sy1 - 1, "_")
    names = ["NOODLES", "CAPSULES", "BAKERY", "ARCADE", "BOOKS"]
    for i, c in enumerate(range(sx0 + 3, sx1 - 1, 4)):
        g.prop("shop", c, sy0 + 3, text=names[i % len(names)], awning=[0.85, 0.2 + 0.15 * i, 0.3])
    for c in range(sx0 + 2, sx1, 5):
        g.prop("bench", c, sy1 - 1, rot=180)
    g.prop("billboard", sx1 - 2, sy1 - 3, text="CAPSULE CORP: LIFE IN A CAPSULE", color=[0.95, 0.95, 1.0])
    g.npc("Noodle Vendor", "shopkeeper", sx0 + 3, sy0 + 5, ["Noodle Vendor|First bowl's on the house. You look like you need it."], rot=180,
          dish="noodle_bowl")
    bakery = next((p for p in g.props if p["type"] == "shop" and p.get("params", {}).get("text") == "BAKERY"), None)
    g.npc("Baker", "shopkeeper", bakery["at"][0] if bakery else sx0 + 7, sy0 + 5,
          ["Baker|Melon bread, fresh out. Take one before the lunch rush."], rot=180, dish="melon_bread")
    # Hover cars over the roads.
    for _ in range(14):
        c, r = rng.randint(3, g.cols - 4), rng.randint(3, g.rows - 4)
        if g.get(c, r) == "=":
            spec = g.prop("hover_car", c, r, rot=rng.choice([0, 90]), color=[rng.random(), rng.random(), rng.random()])
            spec["walkable"] = True
    scatter_civilians(g, 14, rng)
    lantern(g, g.spawns["default"][0] + 2, g.spawns["default"][1])
    write(gl.level_json(g, "west_city", "West City", sky="day", base="grass", city_style="west", backdrop="skyline"))


def capsule_corp_lab():
    g = gl.interior(26, 16, floor="F")
    for c in (5, 13, 21):
        g.prop("lab_bench", c, 7)
    for c in (4, 9, 14, 19, 24):
        g.prop("computer", c, 2.2, rot=180)
    g.prop("capsule_rack", 2.5, 12, rot=90)
    g.prop("capsule_rack", 25.5, 12, rot=270)
    g.prop("gravity_machine", 13.5, 12)
    for c, r in [(2.5, 2.5), (25.5, 2.5)]:
        g.prop("plant_pot", c, r)
    g.prop("rug", 13.5, 12, w=8, d=5, color=[0.3, 0.45, 0.75])
    g.npc("Bulma", "bulma", 9, 10, [
        "Bulma|That column is a gravity machine. Dad says it goes up to a hundred times.",
        "Bulma|Please don't set it to a hundred times.",
        "Bulma|Oh, and Mom baked again. Take the tray before Dad finds it.",
    ], rot=180, dish="capsule_corp_cookies")
    g.npc("Dr. Brief", "scientist", 18, 9, [
        "Dr. Brief|A Saiyan with no tail? Fascinating. Would you mind standing on this scale?",
        "Oto|...Is it food?",
        "Dr. Brief|It is not food.",
    ], rot=180)
    g.exits["1"] = {"to": "west_city", "spawn": "cc_door"}
    write(gl.level_json(g, "capsule_corp_lab", "Capsule Corp: Laboratory", interior=True, tile=1.5,
                        sky="interior", floor="tile", wall_color=[0.88, 0.92, 0.98], wall_tex="panels"))


def hercule_city():
    rng = random.Random(11)
    g = gl.city(96, 72, seed=11, block=11, road=2, park_rate=0.1)
    # Champion Plaza with the statue.
    p0, p1 = block_at(g, 40, 34), block_at(g, 54, 34)
    x0, y0, x1, y1 = merge_blocks(g, [p0, p1], "+")
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    g.prop("hercule_statue", cx, cy)
    g.prop("fountain", cx - 8, cy, r=2.5)
    g.prop("fountain", cx + 8, cy, r=2.5)
    for c in range(x0 + 2, x1 - 1, 4):
        g.prop("flag_pole", c, y0 + 1.5, color=[0.95, 0.75, 0.2])
    g.spawns["default"] = [int(cx), y1 - 2]
    # Hercule's mansion north of the plaza.
    m = block_at(g, cx, y0 - 10)
    mx0, my0, mx1, my1 = merge_blocks(g, [m, block_at(g, cx + 13, y0 - 10)], ".")
    mcx, mcy = (mx0 + mx1) / 2, (my0 + my1) / 2 - 1
    g.prop("hercule_mansion", mcx, mcy)
    g.fill(int(mcx) - 1, int(mcy) + 5, int(mcx) + 1, my1, "+")
    g.put(int(mcx), int(mcy) + 5, "2")
    g.exits["2"] = {"to": "hercule_mansion_hall", "spawn": "door"}
    g.spawns["mansion_door"] = [int(mcx), int(mcy) + 7]
    for c in (mx0 + 2, mx1 - 2):
        g.prop("pillar", c, my1 - 1.5, h=5)
    g.npc("Vendor", "shopkeeper", int(cx) + 4, y1 - 3, [
        "Vendor|Champion Dogs! The only hot dog the champion himself has never eaten!",
        "Oto|Then I will eat his.",
    ], dish="champion_hot_dog")
    g.npc("Hercule", "hercule", int(mcx) + 3, int(mcy) + 7, [
        "Hercule|HA HA HA! Another fan! Sorry, no autographs on Tuesdays.",
        "Oto|It is Thursday.",
        "Hercule|...One autograph, then.",
    ], rot=180)
    # Dojo grounds with a stage.
    d = block_at(g, 20, 52)
    gl.clear_block(g, d, "+")
    g.prop("tournament_ring", (d[0] + d[2]) / 2, (d[1] + d[3]) / 2, size=12)
    g.npc("Dojo Student", "krillin", d[0] + 2, d[1] + 2, ["Dojo Student|Master Hercule says the Cell Games were all tricks of the light.", "Oto|Mm."])
    for _ in range(6):
        c, r = rng.randint(3, g.cols - 4), rng.randint(3, g.rows - 4)
        if g.get(c, r) == "_":
            g.prop("billboard", c, r, rot=rng.choice([0, 90]), text="HERCULE! WORLD CHAMPION", color=[0.95, 0.75, 0.2])
    for _ in range(16):
        c, r = rng.randint(3, g.cols - 4), rng.randint(3, g.rows - 4)
        if g.get(c, r) == "=":
            g.prop("car", c, r, rot=rng.choice([0, 90]), color=[rng.random(), rng.random(), rng.random()])["walkable"] = True
    scatter_civilians(g, 16, rng)
    lantern(g, g.spawns["default"][0] + 2, g.spawns["default"][1])
    write(gl.level_json(g, "hercule_city", "Hercule City", sky="day", base="grass", city_style="modern", backdrop="skyline"))


def hercule_mansion_hall():
    g = gl.interior(22, 14, floor="C")
    g.prop("rug", 12, 8, w=6, d=9, color=[0.9, 0.7, 0.2])
    for c in range(3, 22, 3):
        g.prop("trophy", c, 2.2)
    g.prop("sofa", 6, 10, color=[0.8, 0.2, 0.2])
    g.prop("tv", 6, 6.5, rot=180)
    g.prop("shelf", 21.5, 8, rot=270)
    g.prop("dinner_table", 17, 11.5)
    for c, r in [(2.5, 12.5), (21.5, 12.5)]:
        g.prop("plant_pot", c, r)
    g.npc("Hercule", "hercule", 15, 8, [
        "Hercule|Every one of these trophies is real. Mostly.",
        "Hercule|You fight? Ha! Maybe one day you'll be as strong as me.",
        "Oto|Maybe one day.",
        "Hercule|Help yourself to the buffet! A champion feeds his fans!",
    ], rot=180, dish="champions_buffet")
    g.exits["1"] = {"to": "hercule_city", "spawn": "mansion_door"}
    write(gl.level_json(g, "hercule_mansion_hall", "Hercule's Mansion", interior=True, tile=1.5, sky="interior",
                        floor="carpet", wall_color=[0.98, 0.95, 0.85], wall_tex="panels"))


def mt_paozu():
    rng = random.Random(4)
    g = gl.wild(70, 56, seed=4, kind="forest")
    g.fill(25, 14, 46, 32, ".")
    g.path((35, 31), (35, 55), ",", width=2)
    g.prop("goku_house", 35, 20)
    g.put(35, 22, "2")
    g.exits["2"] = {"to": "goku_house_interior", "spawn": "door"}
    g.spawns["house_door"] = [35, 24]
    g.spawns["default"] = [36, 28]
    g.prop("crater", 44, 29, r=2.4)
    g.prop("pond", 28, 29, r=3.0)
    g.prop("farm_plot", 43, 17, w=6, d=4)
    g.prop("fence", 39.5, 15, length=7)
    g.prop("log", 30, 24)
    for _ in range(6):
        g.prop("flowers", rng.uniform(26, 46), rng.uniform(15, 31), color=[1.0, rng.uniform(0.3, 0.9), 0.3])
    g.npc("Chi-Chi", "chichi", 33, 24, ["Chi-Chi|Dinner is at six. Not five past. Six."], rot=180)
    g.npc("Gohan", "gohan_kid", 29, 27, ["Gohan|The fish are biting today, Miss Oto!"], talk="gohan_fishing")
    g.prop("fishing_spot", 28, 31)  # south edge of the pond, jetty pointing north into it
    shore_spot(g, 21, 33)
    beasts(g, "wolf", 3, (50, 4, 66, 14), seed=41)
    beasts(g, "boar", 2, (40, 38, 62, 52), seed=42)
    beasts(g, "raptor", 2, (4, 6, 18, 20), seed=43)
    g.npc("Goku", None, 40, 26, ["Goku|Hey, Oto! Want to spar?", "Oto|Yes."], model="goku")
    lantern(g, g.spawns["default"][0] + 2, g.spawns["default"][1])
    write(gl.level_json(g, "mt_paozu", "Mt. Paozu", sky="dusk", base="grass", backdrop="mountains"))


def goku_house_interior():
    g = gl.interior(14, 10, floor="W")
    g.prop("dinner_table", 7.5, 5.5)
    for c in (6.5, 8.5):
        g.prop("chair", c, 4.4)
        g.prop("chair", c, 6.6, rot=180)
    g.prop("stove", 2.5, 2.2, rot=180)
    g.prop("counter", 5, 2.2, rot=180, length=2.5)
    g.prop("fridge", 7.5, 2.2, rot=180)
    g.prop("bed", 12.5, 3.5, color=[0.85, 0.5, 0.3])
    g.prop("bed", 12.5, 7.5, color=[0.4, 0.55, 0.85], scale=0.7)
    g.prop("rug", 7.5, 8.5, w=4, d=2, color=[0.7, 0.3, 0.25])
    g.prop("shelf", 1.5, 7, rot=90)
    g.npc("Chi-Chi", "chichi", 4, 5, [
        "Chi-Chi|Sit. Eat. You are too thin for someone who eats like that.",
        "Oto|Every meal on this planet, at least once.",
        "Chi-Chi|Then start with seconds.",
    ], dish="chichi_dumplings")
    g.exits["1"] = {"to": "mt_paozu", "spawn": "house_door"}
    g.prop("food_pot", 5, 2.2)
    g.props[-1]["y"] = 0.95  # on the counter: Chi-Chi's leftovers, as often as she likes
    write(gl.level_json(g, "goku_house_interior", "Goku's House", interior=True, tile=1.5, sky="interior",
                        floor="wood", wall_color=[0.95, 0.9, 0.8], wall_tex="planks"))


def kame_house():
    g = gl.island(46, 46, seed=2, radius=12)
    g.prop("kame_house", 23, 21)
    g.fill(22, 34, 23, 45, "+")
    g.put(22, 45, "1")
    g.put(23, 45, "1")
    g.exits["1"] = {"to": "world"}
    g.spawns["default"] = [23, 30]
    g.npc("Master Roshi", "master_roshi", 20, 26, [
        "Master Roshi|A Saiyan girl from ten thousand years ago? Ho ho. I've heard stranger things this week.",
        "Master Roshi|...No I haven't.",
    ], rot=180, talk="roshi_lesson")
    shore_spot(g, 23, 40)
    beasts(g, "crab", 2, (10, 15, 16, 29), seed=51, keep_away=7)
    beasts(g, "crab", 1, (30, 15, 36, 29), seed=52, keep_away=7)
    g.npc("Krillin", "krillin", 27, 26, ["Krillin|Goku said you can make yourself disappear. Can you teach me that?",
                                        "|He has grilled too many fish. She helps."], rot=180, dish="kame_fish_skewers")
    lantern(g, g.spawns["default"][0] + 2, g.spawns["default"][1])
    write(gl.level_json(g, "kame_house", "Kame House", sky="day", base="sand", backdrop="ocean", legend={"+": {"ground": "wood"}}))


def wasteland():
    rng = random.Random(9)
    g = gl.wild(80, 60, seed=9, kind="wasteland")
    cx, cy = 40, 30
    g.fill(cx - 8, cy - 6, cx + 8, cy + 6, "o")
    g.prop("crater", cx - 4, cy - 2, r=3.5)
    g.prop("space_pod", cx - 4, cy - 2)
    g.prop("crater", cx + 5, cy - 3, r=3.5)
    g.prop("space_pod", cx + 5, cy - 3)
    g.spawns["default"] = [cx, cy + 5]
    for i in range(6):
        g.enemies.append({"at": [cx - 6 + i * 2.5, cy - 8], "hp": 60, "damage": 6, "xp": 25, "name": "Saibaman",
                          "drop": rng.choice(["", "", "red", "green"]), "behavior": "pack"})
    lantern(g, cx + 3, cy + 6)
    # A rock pocket behind a level 5 gate, with capsules for whoever trains up first.
    px0, py0, px1, py1 = 60, 42, 70, 50
    g.fill(px0, py0, px1, py1, "o")
    g.ring(px0, py0, px1, py1, "r")
    g.put(65, py0, "o")
    g.put(66, py0, "o")
    g.prop("level_gate", 65.5, py0, level=5)
    g.pickups += [{"kind": "blue3", "at": [63, 46]}, {"kind": "green3", "at": [68, 46]}]
    beasts(g, "scorpion", 2, (62, 44, 68, 48), seed=71, tier=2, keep_away=0)
    beasts(g, "scorpion", 3, (6, 40, 24, 56), seed=72)
    beasts(g, "pterodactyl", 2, (54, 6, 74, 18), seed=73)
    write(gl.level_json(g, "wasteland", "The Wasteland", sky="wasteland", base="wasteland", backdrop="mesas"))


def korin_forest():
    g = gl.wild(50, 40, seed=12, kind="forest")
    g.fill(18, 12, 32, 28, ".")
    g.prop("korin_tower", 25, 18, h=90)
    g.prop("torii", 25, 25)
    g.prop("sign", 27, 27, text="KORIN TOWER")
    g.spawns["default"] = [25, 27]
    g.npc("Pilgrim", "civilian_m2", 22, 24, ["Pilgrim|They say a cat lives at the top. And he makes beans."])
    g.npc("Yajirobe", "yajirobe", 29, 22, [
        "Yajirobe|What? I'm on break. There's rice on the fire if you want some. Don't touch my fish.",
    ], rot=200, dish="yajirobe_rice", talk="yajirobe")
    shore_spot(g, 20, 24)
    beasts(g, "wolf", 3, (34, 3, 47, 11), seed=61, tier=2)
    beasts(g, "boar", 2, (34, 29, 47, 37), seed=62, tier=2)
    beasts(g, "raptor", 1, (3, 3, 14, 12), seed=63, tier=2)
    lantern(g, g.spawns["default"][0] + 2, g.spawns["default"][1])
    write(gl.level_json(g, "korin_forest", "Korin's Holy Land", sky="day", base="grass", backdrop="mountains"))


def kami_lookout():
    rng = random.Random(3)
    g = gl.Grid(50, 50, " ")
    g.blob(25, 25, 19, "c", rng)
    g.blob(25, 25, 17, "+", rng, only="c")
    g.prop("dome_building", 25, 18, r=6, h=4, color=[0.97, 0.97, 0.95])
    for i in range(8):
        import math
        a = i / 8 * math.tau
        g.prop("tree_palm", 25 + math.cos(a) * 13, 25 + math.sin(a) * 13)
    g.ring(0, 0, 49, 49, " ")
    for c in range(23, 28):
        g.put(c, 44, "1")
    g.exits["1"] = {"to": "world"}
    g.spawns["default"] = [25, 30]
    g.npc("Kami", "kami", 25, 24, [
        "Kami|You are not from this age, child. I can see that much, and not much more.",
        "Kami|Popo will show you the Room of Spirit and Time. When you are ready.",
    ], rot=180)
    lantern(g, g.spawns["default"][0] + 2, g.spawns["default"][1])
    write(gl.level_json(g, "kami_lookout", "Kami's Lookout", sky="sky_high", base="plaza", backdrop="clouds"))


def dev_fixtures():
    """Developer room with one of each fixture; not on the world map. Check it with
    python tools/run.py shot level:dev_fixtures --args="--setlevel 5 --setform 1"."""
    g = gl.Grid(30, 15, ".")
    g.ring(0, 0, 29, 14, "#")
    g.fill(1, 6, 28, 6, "#")
    for c0 in (7, 14, 21):  # three openings in the dividing wall
        g.put(c0, 6, ".")
        g.put(c0 + 1, 6, ".")
    g.prop("level_gate", 7.5, 6, level=5)
    g.prop("memory_gate", 14.5, 6, form=1)
    g.prop("key_door", 21.5, 6, key="rusty_key", w=3.4)
    g.pickups += [{"kind": "red3", "at": [7.5, 3]}, {"kind": "blue3", "at": [14.5, 3]}, {"kind": "green3", "at": [21.5, 3]}]
    g.fill(19, 7, 21, 13, "~")
    g.prop("bridge", 20, 10, rot=90, flag="dev_switch", length=6)
    g.prop("floor_switch", 15, 10, flag="dev_switch")
    g.prop("breakable_rock", 11, 10, hp=40)
    g.prop("save_lantern", 3, 12)
    g.prop("food_pot", 6, 12)
    g.pickups.append({"kind": "red5", "at": [25, 10]})
    g.npc("Caretaker", "civilian_m", 4, 8, ["Caretaker|Lost this years ago. Maybe it opens something."], gives="rusty_key")
    g.spawns["default"] = [3, 10]
    g.spawns["gate"] = [7.5, 9]
    g.spawns["lantern"] = [3, 11]  # under the level gate, for walk-through checks (--spawn gate --sim north)
    g.put(1, 13, "1")
    g.exits["1"] = {"to": "world"}
    write(gl.level_json(g, "dev_fixtures", "Fixture Test Room", sky="day", base="grass", wall_color=[0.7, 0.68, 0.64], wall_tex="bricks"))


LOCATIONS = {
    "west_city": west_city, "capsule_corp_lab": capsule_corp_lab, "hercule_city": hercule_city,
    "hercule_mansion_hall": hercule_mansion_hall, "mt_paozu": mt_paozu, "goku_house_interior": goku_house_interior,
    "kame_house": kame_house, "wasteland": wasteland, "korin_forest": korin_forest, "kami_lookout": kami_lookout,
    "dev_fixtures": dev_fixtures,
}

# World map placement (metres on a 3000 x 3000 map, origin at the centre).
WORLD = [
    {"id": "west_city", "name": "West City", "pos": [-850, 150], "icon": "city", "color": [0.4, 0.7, 1.0]},
    {"id": "mt_paozu", "name": "Mt. Paozu", "pos": [900, -750], "icon": "mountain", "color": [0.5, 1.0, 0.5]},
    {"id": "hercule_city", "name": "Hercule City", "pos": [450, 250], "icon": "city", "color": [1.0, 0.8, 0.3]},
    {"id": "kame_house", "name": "Kame House", "pos": [250, 1150], "icon": "island", "color": [1.0, 0.6, 0.7]},
    {"id": "wasteland", "name": "The Wasteland", "pos": [-700, 800], "icon": "desert", "color": [1.0, 0.55, 0.3]},
    {"id": "korin_forest", "name": "Korin Tower", "pos": [-100, -350], "icon": "tower", "color": [0.95, 0.95, 0.8]},
    {"id": "kami_lookout", "name": "Kami's Lookout", "pos": [-100, -420], "icon": "lookout", "color": [1.0, 1.0, 1.0], "altitude": 260},
]


def main():
    only = sys.argv[1:]
    for k, fn in LOCATIONS.items():
        if not only or k in only:
            fn()
    if not only:
        path = os.path.join(LEVELS, "world.json")
        with open(path, "w", newline="\n") as f:
            json.dump({"size": 3000, "seed": 21, "locations": WORLD}, f, indent=1)
        print("wrote levels/world.json")


if __name__ == "__main__":
    main()
