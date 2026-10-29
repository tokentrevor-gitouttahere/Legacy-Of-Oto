# Regions and the region kit

Session 5 (2026-10-29). Reusable pieces for big locations, and four regions built with them.
Use the kit for any new desert, mountain, snow or cave area, and the city kit for any town.

## Tile letters (`Level.TILES`, any level)

| Char | Tile | Char | Tile |
| --- | --- | --- | --- |
| `K` | cliff: a strata rock column; rows of them make canyon walls and ridges (blocked) | `n` | sandstone (canyon floor) |
| `k` | cactus on sand (blocked) | `h` | hoodoo, a sandstone spire (blocked) |
| `q` | gravel / scree | `i` | sea ice |
| `I` | ice spikes on ice (blocked) | `g` | snowy pine (blocked) |
| `d` | snow drift (walkable) | `v` | cave floor |
| `V` | cave wall column (blocked) | `X` | glowing crystals in the wall (blocked; no light) |
| `u` | glowing mushrooms (walkable) | `Z` | stalagmite (blocked) |
| `w` | deep water, the cave lake (blocked) | | |

Recolour or resize a tile per level with `legend` (`cliff_legend(color, h)` in
`tools/make_locations.py` makes red rock, grey granite or blue ice from the same `K`). Water and
deep water render as their own glossy surface.

## Skies

`desert` (hot, orange horizon), `alpine` (crisp blue), `arctic` (pale, low sun) and `cavern`
(no sky, a soft cool fill light; crystals with `light: true` add colour). The older
`day, dusk, night, dark_side, wasteland, namek, sky_high, world, interior` still apply.

## Props (`Props.DOCS`; see `--gallery props --page 9-13`)

- **Desert:** cliff, hoodoo, cactus, dead_tree, bones (giant ribs and skull), tent, campfire (with light).
- **Mountains:** crag, rock_arch (walk under it), snow_cap, cave_mouth.
- **Ice:** ice_spike, ice_block, igloo, snow_drift, snow_pine.
- **Caves:** cave_column, stalagmite, crystal_cluster (`color`, `light`), glow_mushroom.
- **City:** vending_machine, food_stall (`text`, `color`), cafe_table, phone_booth, trash_bin,
  hydrant, hedge (`length`), street_sign (`text`), bike_rack, market_crates; plus the existing
  bench, lamp_post, shop, billboard.

## Generators (`tools/gen_level.py`)

| Function | Makes |
| --- | --- |
| `canyons(cols, rows, seed)` | desert: noise mesas and canyon walls, sandstone valleys from the middle to the edges, cacti, hoodoos |
| `peaks(cols, rows, seed)` | mountains: ridges, scree, meadows, snow toward the north, a switchback trail to a `summit` spawn |
| `ice_fields(cols, rows, seed)` | arctic: snowfields, sea ice with leads of open water to the north, ice cliffs and spikes, pines to the south |
| `cavern(cols, rows, seed, lake)` | a cave grown by cellular automaton, a huge lake with an `island` spawn and a winding rock bridge, crystals, mushrooms; exit on the south wall |
| `Noise(seed, scale)` | smooth value noise for your own terrain |
| `wander(g, a, b, ch, width, rng)` | a winding, round-brushed path: valleys, trails, bridges |
| `reachable`, `seal_unreachable` | flood fill from the spawn; pockets nobody can reach become wall |
| `cutaway(g, wall)` | rock below the floor's south edge becomes void, so it never stands between the camera and Oto |

City helpers in `tools/make_locations.py`: `street_furniture(g, rng)` (bins, hydrants, machines,
booths, racks and signs facing the road), `dress_parks(g, rng)`, `scatter_townswomen(g, count, rng)`
(named townswomen with their faces), `open_spot`, `scatter_pickups`, `foes` (people who fight).

## The regions (all on the world map; the map edge or the cave mouth leads back out)

| Level | What is there |
| --- | --- |
| `diablo_desert` | red canyons; a nomad camp (Nadia: Nomad flatbread), an oasis, giant bones; scorpions, raptors and Sand Bandits (tier 2) |
| `granite_peaks` | switchbacks to a summit hut (Vesna: Goat-herder's cheese), crags and a rock arch; wolves, boars, pterodactyls (tier 2) |
| `northern_ice_fields` | sea ice with open leads, ice cliffs; an igloo camp (Yuki: Ice-hole fish soup); wolves and crabs (tier 3), Frost Raiders |
| `crystal_cavern` | the huge lake with an island and a rock bridge, lit crystals; Kaia (Glowcap skewers); Crystal Crawlers and Lake Crabs (tier 3), and on the island The Lake Warden (tier 4 boss, optional) |

Each has a save lantern, capsules and food. World-map icons: `canyon`, `peaks`, `ice`, `cave`.

## West City

The shopping street is now two blocks: six shops, three you can walk into
(`west_city_noodle_bar`: Mei, Mei's pork buns; `west_city_bakery`: Clementine;
`west_city_capsule_shop`: Rei), and a market row of four food stalls (Kesi: Street takoyaki),
cafe tables (Marisol: Cafe coffee and its cake) and benches. Street furniture lines the sidewalks,
parks have hedges, benches and flowers, and 14 named townswomen walk the streets.
