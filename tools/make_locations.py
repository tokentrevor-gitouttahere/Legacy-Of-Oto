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


WALKABLE = set(".,:;osmc=_+WFCnqivud")


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


def _taken(g):
    used = {(round(p["at"][0]), round(p["at"][1])) for p in g.props}
    used |= {(round(n["at"][0]), round(n["at"][1])) for n in g.npcs}
    used |= {(int(v[0]), int(v[1])) for v in g.spawns.values()}
    return used


def street_furniture(g, rng, rate=0.05):
    """Bins, hydrants, vending machines, phone booths, bike racks and street signs on the
    sidewalk cells that face a road, never next to an exit or on top of something else."""
    kinds = ["trash_bin", "trash_bin", "hydrant", "vending_machine", "phone_booth", "bike_rack", "street_sign"]
    streets = ["ROSE ST", "CAPSULE AVE", "PAN ROAD", "SATAN BLVD", "BRIEF ST", "NORTH 9TH", "DRAGON WAY"]
    used = _taken(g)
    for r in range(1, g.rows - 1):
        for c in range(1, g.cols - 1):
            if g.get(c, r) != "_" or rng.random() > rate or (c, r) in used:
                continue
            road = [(dc, dr) for dc, dr in ((1, 0), (-1, 0), (0, 1), (0, -1)) if g.get(c + dc, r + dr) == "="]
            near_exit = any(g.get(c + dc, r + dr).isdigit() for dc in (-2, -1, 0, 1, 2) for dr in (-2, -1, 0, 1, 2))
            if not road or near_exit:
                continue
            dc, dr = road[0]
            rot = {(0, 1): 0, (0, -1): 180, (1, 0): 90, (-1, 0): 270}[(dc, dr)]  # face the road
            kind = rng.choice(kinds)
            spec = g.prop(kind, c, r, rot=rot, **({"text": rng.choice(streets)} if kind == "street_sign" else
                                                 {"color": [rng.random() * 0.6 + 0.3, 0.2, 0.25]} if kind == "vending_machine" else {}))
            spec["walkable"] = kind in ("hydrant", "street_sign", "bike_rack")
            used.add((c, r))


def dress_parks(g, rng):
    """Hedges round the edge of every park block, benches facing in, and flowers."""
    for (x0, y0, x1, y1) in g.blocks:
        inner = [(c, r) for r in range(y0 + 1, y1) for c in range(x0 + 1, x1)]
        if not inner or sum(g.get(c, r) in ".T" for c, r in inner) < len(inner) * 0.8:
            continue
        w = x1 - x0 - 2
        g.prop("hedge", (x0 + x1) / 2, y0 + 1, length=w * 2 * 0.8)
        g.prop("hedge", (x0 + x1) / 2, y1 - 1, length=w * 2 * 0.8)
        for k in range(2):
            g.prop("bench", x0 + 2 + k * (w - 2), (y0 + y1) / 2, rot=90 if k == 0 else 270)
        for _ in range(3):
            c, r = rng.randint(x0 + 2, x1 - 2), rng.randint(y0 + 2, y1 - 2)
            if g.get(c, r) == ".":
                g.prop("flowers", c, r)


TOWNSWOMAN_LINES = [
    ["{n}|Lovely day for it. Don't tell anyone, but I skipped work."],
    ["{n}|The noodle bar does a second bowl free if you finish the first in under a minute.", "Oto|Fifty seconds."],
    ["{n}|Have you seen Capsule Corp's new fridge? It holds a week of groceries in one capsule."],
    ["{n}|West City at night is all lights. You should see it from a hover car."],
    ["{n}|If you're looking for the bakery, follow the smell."],
    ["|She waves, and goes back to her phone."],
]


def _women_designs():
    """(design id, name) for every townswoman design in scripts/characters/npc_women.gd."""
    import re
    text = open(os.path.join(ROOT, "scripts", "characters", "npc_women.gd"), encoding="utf-8").read()
    return re.findall(r'^\t"([a-z_]+)": \{"name": "([^"]+)"', text, re.M)


def scatter_townswomen(g, count, rng, allowed="_+", skip=("mei", "lottie", "marisol", "kesi", "ayame", "bryn", "hana", "jun",
                                                         "nadia", "vesna", "yuki", "kaia")):
    """Townswomen out in the city (npc_women.gd), each with her own name and face; the ones
    who work somewhere in particular are left out."""
    pool = [(d, n) for d, n in _women_designs() if d not in skip]
    rng.shuffle(pool)
    used = _taken(g)
    placed = 0
    for _ in range(count * 40):
        if placed >= min(count, len(pool)):
            break
        c, r = rng.randint(2, g.cols - 3), rng.randint(2, g.rows - 3)
        if g.get(c, r) in allowed and (c, r) not in used:
            d, n = pool[placed]
            g.npc(n, "woman_" + d, c, r, [line.format(n=n) for line in rng.choice(TOWNSWOMAN_LINES)],
                  rot=rng.choice([0, 90, 180, 270]))
            used.add((c, r))
            placed += 1


def shop_room(level_id, name, cols, rows, floor, wall_color, back_spawn):
    g = gl.interior(cols, rows, floor=floor)
    g.exits["1"] = {"to": "west_city", "spawn": back_spawn}
    return g


def west_city_noodle_bar():
    g = shop_room("west_city_noodle_bar", "Noodle Bar", 12, 8, "W", [0.95, 0.88, 0.75], "noodle_door")
    g.prop("counter", 6.5, 3.2, length=6)
    for c in (4.5, 6, 7.5, 9):
        g.prop("chair", c, 4.4, rot=180)
    g.prop("stove", 4, 2.2, rot=180)
    g.prop("stove", 5.2, 2.2, rot=180)
    g.prop("snack_shelf", 9.5, 2.2, rot=180)
    g.prop("table", 3, 6.4, w=1.4, d=1.0)
    g.prop("table", 10, 6.4, w=1.4, d=1.0)
    g.prop("plant_pot", 11.2, 7.3)
    g.npc("Mei", "woman_mei", 6.5, 2.3, [
        "Mei|Sit anywhere. The counter's best: you can watch me cook.",
        "Mei|Pork buns, fresh. I make forty a day. You may be the first person to eat forty.",
    ], rot=180, dish="mei_pork_buns")
    write(gl.level_json(g, "west_city_noodle_bar", "Mei's Noodle Bar", interior=True, tile=1.5, sky="interior",
                        floor="wood", wall_color=[0.95, 0.88, 0.75], wall_tex="planks"))


def west_city_bakery():
    g = shop_room("west_city_bakery", "Bakery", 12, 8, "F", [0.98, 0.93, 0.85], "bakery_door")
    g.prop("counter", 6.5, 3, length=7)
    for c in (3, 10):
        g.prop("pantry_rack", c, 2.2)
    g.prop("cafe_table", 3.5, 6.2, color=[0.95, 0.7, 0.8])
    g.prop("cafe_table", 9.5, 6.2, color=[0.7, 0.85, 0.95])
    g.prop("plant_pot", 1.8, 7.4)
    g.npc("Clementine", "woman_lottie_2", 6.5, 2.2, [
        "Clementine|My sister bakes for Capsule Corp now. I got the shop. I think I got the better deal.",
        "Oto|You got the shop with the bread in it.",
        "Clementine|Exactly.",
    ], rot=180)
    write(gl.level_json(g, "west_city_bakery", "West City Bakery", interior=True, tile=1.5, sky="interior",
                        floor="tile", wall_color=[0.98, 0.93, 0.85], wall_tex="bricks"))


def west_city_capsule_shop():
    g = shop_room("west_city_capsule_shop", "Capsule Shop", 12, 8, "F", [0.9, 0.93, 0.98], "capsule_door")
    for c, r, rot in [(2.6, 3, 90), (10.4, 3, 270), (2.6, 6, 90), (10.4, 6, 270)]:
        g.prop("capsule_rack", c, r, rot=rot)
    g.prop("counter", 6.5, 2.6, length=4)
    g.prop("computer", 6.5, 1.9, rot=180)
    g.prop("vending_machine", 9, 1.9, rot=180, color=[0.2, 0.45, 0.85])
    g.npc("Rei", "woman_riko_3", 6.5, 3.6, [
        "Rei|House capsules, car capsules, fridge capsules. The fridge capsules sell out first. I wonder why.",
        "Oto|...",
        "Rei|You've bought four this week.",
    ], rot=180)
    write(gl.level_json(g, "west_city_capsule_shop", "Capsule Shop", interior=True, tile=1.5, sky="interior",
                        floor="tile", wall_color=[0.9, 0.93, 0.98], wall_tex="panels"))


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
    # the house's own front door, east of the lab's
    hx = int(cx) + 5
    g.fill(hx - 1, int(cy) + 8, hx + 1, int(cy) + 11, "+")
    g.put(hx, int(cy) + 8, "3")
    g.exits["3"] = {"to": "capsule_corp_home", "spawn": "front"}
    g.spawns["cc_front"] = [hx, int(cy) + 10]
    g.prop("sign", hx + 1.6, int(cy) + 9.5, text="HOME")
    g.spawns["default"] = [int(cx), y1 + 2]
    for c, r in [(x0 + 2, y0 + 2), (x1 - 2, y0 + 2), (x0 + 2, y1 - 2), (x1 - 2, y1 - 2)]:
        g.prop("tree_oak", c, r)
    g.prop("capsule_ship", x1 - 6, y0 + 6)
    g.npc("Bulma", "bulma", int(cx) + 2, int(cy) + 10, [
        "Bulma|Oh! You must be the one Goku found in a hole.",
        "Bulma|Welcome to Capsule Corporation. Don't touch anything that beeps.",
    ], rot=180)
    # Shopping street south of the campus: two blocks joined into one, six shops (three you can
    # walk into), and a market row of food stalls and cafe tables along the south side.
    shop_blk = block_at(g, cx, y1 + 10)
    east_blk = block_at(g, shop_blk[2] + 8, (shop_blk[1] + shop_blk[3]) / 2)
    sx0, sy0, sx1, sy1 = merge_blocks(g, [shop_blk, east_blk], "_")
    names = ["NOODLES", "BAKERY", "CAPSULES", "ARCADE", "BOOKS", "FLOWERS"]
    doors = {"NOODLES": ("4", "west_city_noodle_bar", "noodle_door"), "BAKERY": ("5", "west_city_bakery", "bakery_door"),
             "CAPSULES": ("6", "west_city_capsule_shop", "capsule_door")}
    shop_at = {}
    for i, c in enumerate(range(sx0 + 3, sx1 - 1, 4)):
        if i >= len(names):
            break
        g.prop("shop", c, sy0 + 2, text=names[i], awning=[0.85, 0.2 + 0.12 * i, 0.3 + 0.08 * i])
        shop_at[names[i]] = c
        if names[i] in doors:
            ch, to, sp = doors[names[i]]
            g.put(c, sy0 + 3, ch)
            g.exits[ch] = {"to": to, "spawn": "door"}
            g.spawns[sp] = [c, sy0 + 4]
    stalls = [("TAKOYAKI", [0.9, 0.3, 0.2]), ("DUMPLINGS", [0.25, 0.55, 0.85]), ("KEBABS", [0.95, 0.6, 0.15]),
              ("ICE CREAM", [0.95, 0.5, 0.7])]
    for i, (text, col) in enumerate(stalls):
        g.prop("food_stall", sx0 + 4 + i * 5, sy1 - 2, text=text, color=col)  # facing the street, south
        g.prop("market_crates", sx0 + 6.4 + i * 5, sy1 - 1.4)
    for k in range(3):
        g.prop("cafe_table", sx1 - 9 + k * 3, sy0 + 7, color=[0.95, 0.55 - k * 0.1, 0.3 + k * 0.15])
    for c in range(sx0 + 2, sx1, 6):
        g.prop("bench", c, sy0 + 9, rot=180)
    g.prop("billboard", sx1 - 2, sy1 - 4, text="CAPSULE CORP: LIFE IN A CAPSULE", color=[0.95, 0.95, 1.0])
    g.npc("Noodle Vendor", "shopkeeper", shop_at["NOODLES"] - 1.5, sy0 + 5, ["Noodle Vendor|First bowl's on the house. You look like you need it."], rot=180,
          dish="noodle_bowl")
    g.npc("Baker", "shopkeeper", shop_at["BAKERY"] + 1.5, sy0 + 5,
          ["Baker|Melon bread, fresh out. Take one before the lunch rush."], rot=180, dish="melon_bread")
    g.npc("Marisol", "woman_marisol", sx1 - 6, sy0 + 8.4, [
        "Marisol|Table for one? You look like a table for four.",
        "Marisol|Our coffee comes with a cake. The cake is not optional.",
    ], rot=200, dish="cafe_cake")
    for i, (text, _) in enumerate(stalls):
        if text == "TAKOYAKI":
            g.npc("Kesi", "woman_kesi", sx0 + 2.2 + i * 5, sy1 - 1.2, [
                "Kesi|I deliver all day and eat here all night. Try the takoyaki. Blow on it first.",
                "Oto|Why?",
                "Kesi|...You'll see.",
            ], rot=0, dish="takoyaki")
    # Hover cars over the roads.
    for _ in range(14):
        c, r = rng.randint(3, g.cols - 4), rng.randint(3, g.rows - 4)
        if g.get(c, r) == "=":
            spec = g.prop("hover_car", c, r, rot=rng.choice([0, 90]), color=[rng.random(), rng.random(), rng.random()])
            spec["walkable"] = True
    street_furniture(g, random.Random(71))
    dress_parks(g, random.Random(72))
    scatter_civilians(g, 14, rng)
    scatter_townswomen(g, 14, random.Random(73))
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
    g.put(26, 8, "2")  # east: the hall of the house, where Oto lives now
    g.exits["2"] = {"to": "capsule_corp_home", "spawn": "from_lab"}
    g.spawns["home_door"] = [25, 8]
    g.prop("sign", 24.6, 6.6, rot=270, text="HOME")
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



# --- Capsule Corp home: where Oto lives now ---------------------------------------
# A hall with the living room in it, and a door to each room. The rooms lead back to the hall;
# the hall leads to the lab (west) and out to West City (south).

CC_WALLS = dict(interior=True, tile=1.5, sky="interior")
HOME_ROOMS = [  # door char, hall cell, level id
    ("3", (4, 1), "capsule_corp_kitchen"),
    ("4", (9, 1), "capsule_corp_pantry"),
    ("5", (14, 1), "capsule_corp_garden"),
    ("6", (19, 1), "capsule_corp_gravity"),
    ("7", (22, 7), "oto_room"),
]


def room(cols, rows, floor):
    """A room whose south door ("1") leads back into the hall, by its own door."""
    return gl.interior(cols, rows, floor=floor)


def back_to_hall(g, level_id):
    g.exits["1"] = {"to": "capsule_corp_home", "spawn": "from_" + level_id}


def capsule_corp_home():
    g = gl.interior(22, 14, floor="C")
    for ch, (c, r), to in HOME_ROOMS:
        g.put(c, r, ch)
        g.exits[ch] = {"to": to, "spawn": "door"}
        g.spawns["from_" + to] = [c - 1, r] if c == 22 else [c, r + 1]
    g.put(1, 7, "2")
    g.exits["2"] = {"to": "capsule_corp_lab", "spawn": "home_door"}
    g.spawns["from_lab"] = [2, 7]
    g.exits["1"] = {"to": "west_city", "spawn": "cc_front"}
    g.spawns["front"] = list(g.spawns["door"])
    labels = {"3": "KITCHEN", "4": "PANTRY", "5": "GARDEN", "6": "GRAVITY ROOM"}
    for ch, (c, r), _ in HOME_ROOMS:
        if ch in labels:
            g.prop("sign", c + 1.3, r + 1, text=labels[ch])
    g.prop("sign", 20.8, 5.8, rot=270, text="OTO")
    # the living room: a rug, three sofas round the TV, lamps and plants
    g.prop("rug", 11.5, 8, w=8, d=5, color=[0.32, 0.5, 0.72])
    g.prop("tv", 11.5, 5.2)
    g.prop("sofa", 11.5, 10.3, rot=180, color=[0.95, 0.92, 0.86])
    g.prop("sofa", 8.3, 8, rot=90, color=[0.95, 0.92, 0.86])
    g.prop("sofa", 14.7, 8, rot=270, color=[0.95, 0.92, 0.86])
    g.prop("table", 11.5, 8, w=2.0, d=1.0, color=[0.85, 0.85, 0.88])
    g.prop("takeout_stack", 11.2, 8, n=2)
    g.props[-1]["y"] = 0.8
    for c, r in [(6.6, 5), (16.4, 5), (6.6, 11.6), (16.4, 11.6)]:
        g.prop("floor_lamp", c, r)
    for c, r in [(2.5, 2.5), (21.5, 2.5), (2.5, 13), (21.5, 13)]:
        g.prop("plant_pot", c, r)
    g.prop("shelf", 2.4, 10.4, rot=90)
    g.prop("capsule_rack", 21.6, 10.6, rot=270)
    g.npc("Ayame", "woman_ayame", 9.8, 10.5, [
        "Ayame|You're the new houseguest? Bulma said you'd find the kitchen before you found your room.",
        "Oto|The kitchen is the first door.",
        "Ayame|...She was right.",
    ], rot=180)
    write(gl.level_json(g, "capsule_corp_home", "Capsule Corp: Home", floor="carpet", wall_color=[0.96, 0.93, 0.88],
                        wall_tex="panels", **CC_WALLS))


def capsule_corp_kitchen():
    g = room(16, 10, "F")
    back_to_hall(g, "capsule_corp_kitchen")
    # the kitchen along the north wall, an island in the middle, the dining tables to the south
    g.prop("fridge", 2.6, 2.3, rot=180)
    g.prop("fridge", 3.6, 2.3, rot=180)
    g.prop("counter", 6.4, 2.3, rot=180, length=3.5)
    g.prop("stove", 9, 2.3, rot=180)
    g.prop("stove", 10.2, 2.3, rot=180)
    g.prop("counter", 13, 2.3, rot=180, length=3.5)
    g.prop("food_pot", 5.9, 2.3)
    g.props[-1]["y"] = 0.95  # leftovers on the counter, as often as she likes
    g.prop("takeout_stack", 13.8, 2.3, n=2)
    g.props[-1]["y"] = 0.95
    g.prop("counter", 8.5, 4.6, length=4.5)
    for c in (7, 8.5, 10):
        g.prop("chair", c, 5.6, rot=180)
    g.prop("rug", 8.5, 8, w=13, d=3, color=[0.85, 0.55, 0.3])
    for cx in (5, 12):
        g.prop("dinner_table", cx, 8)
        for c in (cx - 0.9, cx + 0.9):
            g.prop("chair", c, 7.1, rot=0)
            g.prop("chair", c, 8.9, rot=180)
    for c, r in [(2, 9.2), (15, 9.2)]:
        g.prop("plant_pot", c, r)
    g.npc("Mrs. Briefs", "mrs_briefs", 7.8, 3.4, [
        "Mrs. Briefs|Oh, you're up! I made a cake. I always make a cake.",
        "Mrs. Briefs|Bulma says you eat like a whole army. Isn't that wonderful? Nobody ever finishes my cakes.",
        "Oto|I will finish it.",
    ], rot=180, dish="briefs_shortcake")
    g.npc("Lottie", "woman_lottie", 12, 3.4, [
        "Lottie|Mrs. Briefs hired me to keep up with you. They told me it was a full-time job.",
        "Lottie|They undersold it.",
    ], rot=180)
    write(gl.level_json(g, "capsule_corp_kitchen", "Capsule Corp: Kitchen", floor="tile", wall_color=[0.98, 0.95, 0.9],
                        wall_tex="panels", **CC_WALLS))


def capsule_corp_pantry():
    g = room(13, 9, "F")
    back_to_hall(g, "capsule_corp_pantry")
    for r in (2.4, 4.9):
        for c in (3.8, 9.2):
            g.prop("pantry_rack", c, r)
    g.prop("pantry_rack", 6.5, 2.4)  # the back wall; the aisle runs down the middle below it
    g.prop("freezer", 2.8, 7.4, rot=90)
    g.prop("freezer", 11.2, 7.4, rot=270)
    g.prop("barrel", 4.6, 8.3)
    g.prop("barrel", 8.4, 8.3)
    g.prop("crate", 9.6, 8.3)
    g.pickups += [{"kind": "rice_ball", "at": [6.5, 4]}, {"kind": "rice_ball", "at": [3.8, 6.6]},
                  {"kind": "haunch", "at": [6.5, 5.8]}, {"kind": "rice_ball", "at": [9.2, 6.6]}]
    g.npc("Bryn", "woman_bryn", 10.2, 6.6, [
        "Bryn|The freezer's capsule core iced over. Everything in it thaws in ten minutes.",
        "Bryn|So. Ten minutes. Go.",
    ], rot=200, dish="freezer_ice_cream")
    write(gl.level_json(g, "capsule_corp_pantry", "Capsule Corp: Pantry", floor="tile", wall_color=[0.86, 0.88, 0.9],
                        wall_tex="panels", **CC_WALLS))


def capsule_corp_garden():
    rng = random.Random(41)
    g = room(20, 14, ".")
    back_to_hall(g, "capsule_corp_garden")
    g.fill(9, 5, 12, 7, "~")  # the pond
    g.fill(10, 8, 12, 13, ",")  # a dirt path from the door
    for c, r in [(3, 3), (18, 3), (3, 12), (18, 12), (6, 7), (16, 7)]:
        g.prop("tree_palm", c, r, size=0.8)
    for c, r in [(6, 3.5), (15, 3.5), (5, 10), (16, 10), (8, 11), (14, 11)]:
        g.prop("flowers", c, r)
    for _ in range(10):
        c, r = rng.randint(3, 18), rng.randint(3, 12)
        if g.get(c, r) == ".":
            g.prop("bush", c + 0.5, r + 0.5, size=0.6)
    g.npc("Hana", "woman_hana", 13.6, 9, [
        "Hana|Dr. Brief keeps the dome at summer all year. The fruit never stops coming.",
        "Hana|Take a plate. The parrots are getting ahead of you.",
    ], rot=200, dish="dome_fruit")
    write(gl.level_json(g, "capsule_corp_garden", "Capsule Corp: Garden Dome", base="grass", floor="grass",
                        wall_color=[0.82, 0.92, 0.98], wall_tex="panels", **CC_WALLS))


def capsule_corp_gravity():
    g = room(15, 11, "m")
    back_to_hall(g, "capsule_corp_gravity")
    g.prop("gravity_machine", 8, 5.2)
    g.prop("rug", 8, 5.2, w=5, d=5, color=[0.25, 0.25, 0.3])
    g.prop("weight_rack", 3.5, 2.4)
    g.prop("weight_rack", 12.5, 2.4)
    for c, r in [(2.8, 6), (13.2, 6), (2.8, 9), (13.2, 9)]:
        g.prop("punching_bag", c, r, color=[0.75, 0.15, 0.15])
    g.enemies += [
        {"at": [4.5, 4.5], "name": "Training Drone", "hp": 40, "damage": 4, "speed": 2.6, "xp": 6, "behavior": "chase"},
        {"at": [11.5, 4.5], "name": "Training Drone", "hp": 40, "damage": 4, "speed": 2.6, "xp": 6, "behavior": "shooter"},
        {"at": [5, 8.5], "name": "Training Drone", "hp": 40, "damage": 4, "speed": 2.6, "xp": 6, "behavior": "chase"},
    ]
    g.npc("Jun", "woman_jun", 11, 8.8, [
        "Jun|I run a class in here at ten times gravity. Nobody comes back for the second lesson.",
        "Jun|Have a shake. It's mostly protein.",
    ], rot=200, dish="gravity_shake")
    write(gl.level_json(g, "capsule_corp_gravity", "Capsule Corp: Gravity Room", floor="metal", wall_color=[0.55, 0.58, 0.64],
                        wall_tex="panels", **CC_WALLS))


def oto_room():
    """Her room: a guest room turned food lover's den."""
    g = room(11, 8, "W")
    back_to_hall(g, "oto_room")
    g.prop("bed", 9.2, 3.3, color=[0.09, 0.27, 0.16])
    g.prop("sigil_banner", 9.2, 2.05)
    g.prop("minifridge", 7.3, 2.2, rot=180)
    g.prop("takeout_stack", 8.0, 2.1, n=3)
    for r in (3, 4.6, 6.2):
        g.prop("snack_shelf", 2.4, r, rot=90)
    g.prop("tv", 4.8, 2.2)
    g.prop("rug", 5, 4.4, w=4, d=3, color=[0.85, 0.55, 0.25])
    g.prop("bean_bag", 4.8, 4.9, rot=180, color=[0.9, 0.48, 0.2])
    g.prop("pizza_boxes", 3.8, 6.6, n=4)
    g.prop("pizza_boxes", 6.4, 3.6, n=2)
    g.prop("takeout_stack", 3.6, 7.4, n=4)
    g.prop("takeout_stack", 4.2, 7.5, n=2)
    g.prop("takeout_stack", 10.2, 7.2, n=3)
    g.prop("table", 8.6, 6.2, w=1.6, d=1.0)
    g.prop("food_pot", 8.6, 6.2)
    g.props[-1]["y"] = 0.8  # last night's pot, still warm
    g.prop("save_lantern", 10.3, 4.9)
    g.npc("Note on the minifridge", "", 7.3, 3.0, [
        "|A note on the minifridge, in Bulma's handwriting:",
        "|\"Oto. This fridge restocks itself every night. It is not a challenge. - B.\"",
        "|Under it, in a different hand: \"Accepted.\"",
    ], prompt="Read", dish="midnight_noodles")
    g.npcs[-1]["model"] = ""  # an invisible marker: the note itself
    g.spawns["bed"] = [7.3, 3.9]  # beside the bed, facing the minifridge
    write(gl.level_json(g, "oto_room", "Oto's Room", floor="wood", wall_color=[0.93, 0.9, 0.84],
                        wall_tex="panels", **CC_WALLS))



# --- the regions (docs/REGIONS.md): desert canyons, mountains, ice fields, crystal cavern ---------

def cliff_legend(color, h=6.0):
    """Recolour the K cliff tile for one level (red rock, grey granite, blue ice, ...)."""
    return {"K": {"ground": "$base", "prop": "cliff", "params": {"color": color, "h": h}, "block": True, "jitter": True}}


def open_spot(g, c, r, radius=12):
    """The walkable cell nearest (c, r) whose 3x3 block is all walkable (room for a prop or a camp)."""
    for rad in range(radius + 1):
        for dr in range(-rad, rad + 1):
            for dc in range(-rad, rad + 1):
                cc, rr = c + dc, r + dr
                if max(abs(dc), abs(dr)) == rad and all(g.get(cc + x, rr + y) in WALKABLE for x in (-1, 0, 1) for y in (-1, 0, 1)):
                    return cc, rr
    raise ValueError("no open spot near %s" % ((c, r),))


def scatter_pickups(g, kinds, seed, area=None, keep_away=8):
    """One pickup of each kind on open ground, away from the default spawn."""
    rng = random.Random(seed)
    c0, r0, c1, r1 = area or (2, 2, g.cols - 3, g.rows - 3)
    sc, sr = g.spawns["default"]
    for kind in kinds:
        for _ in range(500):
            c, r = rng.randint(c0, c1), rng.randint(r0, r1)
            if open_ground(g, c, r) and max(abs(c - sc), abs(r - sr)) >= keep_away:
                g.pickups.append({"kind": kind, "at": [c, r]})
                break


def foes(g, name, count, area, seed, outfit, hp, damage, xp, behavior="chase", tier=1, drop="", keep_away=9):
    """People who fight: bandits and the like, on open ground in `area`."""
    rng = random.Random(seed)
    sc, sr = g.spawns["default"]
    c0, r0, c1, r1 = area
    placed = 0
    for _ in range(500):
        if placed == count:
            return
        c, r = rng.randint(c0, c1), rng.randint(r0, r1)
        if open_ground(g, c, r) and max(abs(c - sc), abs(r - sr)) >= keep_away:
            g.enemies.append({"at": [c, r], "name": name, "outfit": outfit, "hp": hp, "damage": damage, "xp": xp,
                              "behavior": behavior, "tier": tier, "drop": drop or rng.choice(["", "red", "green", "blue"])})
            placed += 1
    raise ValueError("only placed %d of %d %s" % (placed, count, name))


def diablo_desert():
    g = gl.canyons(84, 64, seed=31)
    rng = random.Random(31)
    cx, cy = g.spawns["default"]
    # a nomad camp by the spawn: tents round a fire, and Nadia cooking
    camp = open_spot(g, cx + 4, cy - 3)
    g.fill(camp[0] - 3, camp[1] - 3, camp[0] + 3, camp[1] + 3, "n")
    g.prop("campfire", camp[0], camp[1])
    for dc, dr, rot in [(-2.5, -1.5, 30), (2.5, -1.5, -30), (0, -3, 0)]:
        g.prop("tent", camp[0] + dc, camp[1] + dr, rot=rot, color=[0.85, 0.72, 0.5])
    g.npc("Nadia", "woman_nadia", camp[0] + 1.5, camp[1] + 1.2, [
        "Nadia|You walked here? Nobody walks here. Sit. The bread is nearly done.",
        "Oto|I can wait for bread.",
        "Nadia|You say that like it costs you something.",
    ], rot=200, dish="desert_flatbread")
    lantern(g, camp[0] - 2, camp[1] + 2)
    # an oasis, and the bones of something enormous in a far valley
    oasis = open_spot(g, 14, 50)
    g.blob(oasis[0], oasis[1], 3, "~", rng, only=":n")
    for k in range(5):
        c, r = oasis[0] + rng.randint(-5, 5), oasis[1] + rng.randint(-5, 5)
        if g.get(c, r) == ":":
            g.put(c, r, "Y")
    bones = open_spot(g, 66, 14)
    g.prop("bones", bones[0], bones[1], rot=40, size=1.6)
    for k in range(3):
        g.prop("dead_tree", bones[0] - 4 + k * 4, bones[1] + 3)
    beasts(g, "scorpion", 4, (4, 4, 80, 60), seed=311, tier=2)
    beasts(g, "raptor", 3, (40, 30, 80, 60), seed=312, tier=2)
    foes(g, "Sand Bandit", 4, (4, 4, 40, 30), seed=313, outfit="civilian_m2", hp=120, damage=9, xp=40, behavior="chase", tier=2)
    scatter_pickups(g, ["red3", "blue3", "green3", "rice_ball", "haunch"], seed=314)
    g.pickups.append({"kind": "red5", "at": [bones[0], bones[1] + 2]})
    write(gl.level_json(g, "diablo_desert", "Diablo Desert", sky="desert", base="sand", backdrop="mesas",
                        legend=cliff_legend([0.66, 0.36, 0.24], 7.0)))


def granite_peaks():
    g = gl.peaks(64, 80, seed=32)
    rng = random.Random(32)
    cx, cy = g.spawns["default"]
    sx, sy = g.spawns["summit"]
    lantern(g, cx + 2, cy - 1)
    # the herder's hut at the summit, with the best view and the worst wind
    hut = open_spot(g, sx, sy + 3)
    g.fill(hut[0] - 3, hut[1] - 2, hut[0] + 3, hut[1] + 2, "s")
    g.prop("hut", hut[0], hut[1] - 1)
    g.prop("campfire", hut[0] + 2, hut[1] + 1)
    g.npc("Vesna", "woman_vesna", hut[0] - 1.5, hut[1] + 1.2, [
        "Vesna|Four hours up the switchbacks, and you're not even breathing hard.",
        "Vesna|The goats think you're one of them. Have some of their cheese. They won't mind.",
    ], rot=200, dish="herder_cheese")
    lantern(g, hut[0] + 3, hut[1] + 2)
    for k in range(10):  # crags and rock arches along the trail
        c, r = rng.randint(4, g.cols - 5), rng.randint(8, g.rows - 10)
        if open_ground(g, c, r) and g.get(c, r) in ".;q":
            g.prop("crag", c, r, size=rng.uniform(0.7, 1.2), color=[0.55, 0.54, 0.56])
    arch = open_spot(g, g.cols // 2, g.rows // 2)
    g.prop("rock_arch", arch[0], arch[1], span=4.0, color=[0.55, 0.54, 0.56])
    beasts(g, "wolf", 5, (4, 30, 60, 70), seed=321, tier=2)
    beasts(g, "boar", 3, (4, 40, 60, 74), seed=322, tier=2)
    beasts(g, "pterodactyl", 3, (4, 4, 60, 28), seed=323, tier=2)
    scatter_pickups(g, ["red3", "blue3", "green3", "haunch", "rice_ball"], seed=324)
    g.pickups.append({"kind": "blue5", "at": [sx + 2, sy]})
    write(gl.level_json(g, "granite_peaks", "Granite Peaks", sky="alpine", base="grass", backdrop="mountains",
                        legend=cliff_legend([0.55, 0.55, 0.58], 8.0)))


def northern_ice_fields():
    g = gl.ice_fields(80, 64, seed=33)
    rng = random.Random(33)
    cx, cy = g.spawns["default"]
    # an igloo camp on the snow, by a fire, with a skater who knows where the fish are
    camp = open_spot(g, cx - 6, cy + 3)
    g.fill(camp[0] - 4, camp[1] - 3, camp[0] + 4, camp[1] + 3, "s")
    for dc, dr in [(-3, -1), (3, -1)]:
        g.prop("igloo", camp[0] + dc, camp[1] + dr, rot=180)
    g.prop("campfire", camp[0], camp[1] + 1.5)
    g.npc("Yuki", "woman_yuki", camp[0] + 1.6, camp[1] + 2.2, [
        "Yuki|Careful out on the sea ice. The dark lines are open water, and it's very cold water.",
        "Yuki|We cut a hole this morning. The soup is mostly fish. The rest is also fish.",
    ], rot=200, dish="ice_fish_soup")
    lantern(g, camp[0] - 2, camp[1] + 3)
    for k in range(8):
        c, r = rng.randint(4, g.cols - 5), rng.randint(4, g.rows - 5)
        if open_ground(g, c, r) and g.get(c, r) in "si":
            g.prop("ice_block", c, r, size=rng.uniform(0.8, 1.3))
    beasts(g, "wolf", 6, (4, 30, 76, 60), seed=331, tier=3)
    beasts(g, "crab", 4, (4, 4, 76, 30), seed=332, tier=3)
    foes(g, "Frost Raider", 3, (4, 4, 76, 40), seed=333, outfit="saiyan_soldier", hp=160, damage=12, xp=60, behavior="shooter", tier=2)
    scatter_pickups(g, ["red3", "blue3", "green3", "red5", "fresh_fish"], seed=334)
    write(gl.level_json(g, "northern_ice_fields", "Northern Ice Fields", sky="arctic", base="snow", backdrop="mountains",
                        legend=cliff_legend([0.72, 0.86, 0.96], 5.0)))


def crystal_cavern():
    g = gl.cavern(70, 56, seed=34)
    rng = random.Random(34)
    ex, ey = g.spawns["default"]
    ix, iy = g.spawns["island"]
    lantern(g, ex + 2, ey - 2)
    # a few real lights in big crystals round the lake (most crystals only glow)
    shore = [(c, r) for r in range(2, g.rows - 2) for c in range(2, g.cols - 2)
             if g.get(c, r) == "v" and any(g.get(c + dc, r + dr) == "w" for dc, dr in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    rng.shuffle(shore)
    colors = [[0.45, 0.8, 1.0], [0.75, 0.5, 1.0], [0.4, 1.0, 0.75]]
    for k, (c, r) in enumerate(shore[:9]):
        g.prop("crystal_cluster", c, r, size=1.4, color=colors[k % 3])
    g.prop("crystal_cluster", ix + 2, iy - 1, size=2.0, color=[0.75, 0.5, 1.0])
    g.npc("Kaia", "woman_kaia", ex - 2, ey - 4, [
        "Kaia|I came down to dive the lake. It's the deepest water I've ever seen, and something lives on the island.",
        "Kaia|Want some glowcaps? They taste like mushrooms that are proud of themselves.",
    ], rot=160, dish="glowcap_skewers")
    beasts(g, "scorpion", 4, (2, 2, 68, 54), seed=341, tier=3)
    beasts(g, "crab", 3, (2, 2, 68, 54), seed=342, tier=3)
    # the island is the Warden's alone: no other beast starts on it
    g.enemies = [e for e in g.enemies if max(abs(e["at"][0] - ix), abs(e["at"][1] - iy)) > 9]
    for e in g.enemies:
        if e.get("beast") == "scorpion":
            e["name"] = "Crystal Crawler"
        elif e.get("beast") == "crab":
            e["name"] = "Lake Crab"
    # the island's keeper, an optional fight
    g.enemies.append({"at": [ix, iy], "name": "The Lake Warden", "beast": "crab", "tier": 4, "hp": 900, "damage": 18,
                      "speed": 1.8, "xp": 400, "behavior": "charger", "drop": "blue5",
                      "boss": {"phases": [0.5, 0.25], "heal_on_phase": 0.0, "absorbs_ki": False, "drain": 0.0}})
    scatter_pickups(g, ["red3", "blue3", "green3", "rice_ball"], seed=343)
    g.pickups += [{"kind": "red5", "at": [ix - 1, iy + 1]}, {"kind": "green5", "at": [ix + 1, iy + 1]}]
    legend = {"V": {"ground": "cave", "prop": "cave_column", "params": {"h": 4.0}, "block": True, "jitter": True}}
    write(gl.level_json(g, "crystal_cavern", "Crystal Cavern", sky="cavern", base="cave", floor="cave", legend=legend))


LOCATIONS = {
    "west_city": west_city, "capsule_corp_lab": capsule_corp_lab, "hercule_city": hercule_city,
    "hercule_mansion_hall": hercule_mansion_hall, "mt_paozu": mt_paozu, "goku_house_interior": goku_house_interior,
    "kame_house": kame_house, "wasteland": wasteland, "korin_forest": korin_forest, "kami_lookout": kami_lookout,
    "dev_fixtures": dev_fixtures,
    "capsule_corp_home": capsule_corp_home, "capsule_corp_kitchen": capsule_corp_kitchen,
    "capsule_corp_pantry": capsule_corp_pantry, "capsule_corp_garden": capsule_corp_garden,
    "capsule_corp_gravity": capsule_corp_gravity, "oto_room": oto_room,
    "diablo_desert": diablo_desert, "granite_peaks": granite_peaks, "northern_ice_fields": northern_ice_fields,
    "crystal_cavern": crystal_cavern,
    "west_city_noodle_bar": west_city_noodle_bar, "west_city_bakery": west_city_bakery,
    "west_city_capsule_shop": west_city_capsule_shop,
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
    {"id": "diablo_desert", "name": "Diablo Desert", "pos": [-1200, 900], "icon": "canyon", "color": [1.0, 0.6, 0.35]},
    {"id": "granite_peaks", "name": "Granite Peaks", "pos": [450, -1000], "icon": "peaks", "color": [0.8, 0.85, 0.95]},
    {"id": "northern_ice_fields", "name": "Northern Ice Fields", "pos": [-650, -1000], "icon": "ice", "color": [0.7, 0.9, 1.0]},
    {"id": "crystal_cavern", "name": "Crystal Cavern", "pos": [1150, 350], "icon": "cave", "color": [0.7, 0.55, 1.0]},
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
