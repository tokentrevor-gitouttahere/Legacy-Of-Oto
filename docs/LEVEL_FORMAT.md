# Level format (`levels/<id>.json`)

A location is a tile map plus lists of props, NPCs, enemies, spawns and exits. `Level`
(`scripts/world/level.gd`) builds it at runtime and `scenes/location.tscn` plays it.
Open one with `python tools/run.py shot level:<id>` or `GameState.travel("<id>", "spawn")`.

## Top-level keys

| Key | Default | Meaning |
| --- | --- | --- |
| `id`, `name` | | File id and display name (toast on arrival) |
| `grid` | required | Array of equal-length strings, one per row (north at the top) |
| `tile` | 2.0 | Metres per cell (use 1.5 for interiors) |
| `base` | `grass` | Ground under markers that use `$base` (trees, spawn, exits) |
| `floor` | base | Ground for walls/doors (`$floor`), used indoors |
| `sky` | `day` | `day, dusk, night, dark_side, wasteland, namek, sky_high, world, interior` |
| `backdrop` | none | String or list: `mountains, mesas, skyline, ocean, clouds` |
| `interior` | false | Low cutaway south walls, closer camera |
| `city_style` | `west` | How `B` blocks become buildings: `west` (domes, round towers), `modern`, `village` |
| `wall_color`, `wall_tex`, `wall_height` | | Look of `#` walls |
| `legend` | | Extra or overridden characters: `{"x": {"ground": "sand", "prop": "rock", "block": true}}` |
| `spawns` | | `{"name": [col, row]}`; `@` in the grid also sets `default` |
| `exits` | | `{"1": {"to": "world" or level id, "spawn": "name", "hidden": false}}` |
| `props` | | `[{"type", "at": [col, row], "rot": deg, "scale", "y", "walkable", "params": {...}}]` |
| `npcs` | | `[{"name", "outfit", "model", "at", "rot", "scale", "lines": ["Name|text", "|narration"]}]`, plus optional `dish` (a `Dishes` id: serves it once for the Menu), `talk` (a `Talks` script, e.g. `roshi_lesson`), `gives` (key item id), `flag` (set after talking), `prompt` (the interact verb, e.g. `"Read"` for a note; `"model": ""` makes the NPC an invisible marker) |
| `enemies` | | `[{"at", "name", "hp", "damage", "speed", "xp", "drop", "food", "behavior", "tier", "boss", "beast", "model", "outfit"}]`, see below |
| `pickups` | | `[{"kind": "red3", "at": [c, r], "id"}]`: placed once; collected for good (flag `id`, default `pickup:<level>:<index>`) |
| `player_outfit` | `oto` | Outfit preset for Oto here |

Cell coordinates are `[column, row]`, may be fractional, and refer to cell centres.

### Enemy keys

- `drop`: a capsule, always dropped: `red`, `blue`, `green` (+1), or with a tier suffix
  `red3`, `blue5` (+3, +5).
- `food`: dropped 35% of the time: `haunch`, `rice_ball`, `fresh_fish`, `senzu`. Every enemy
  may also drop a `ki_mote` (30%).
- `behavior`: `chase` (default), `charger`, `shooter`, `pack` (see `scripts/enemy.gd`).
- `tier`: 1-4. Scales HP, damage and EXP by 1, 2.5, 6 or 15 and tints the model.
- `beast`: a procedural animal (`Beast.KINDS`: wolf, boar, raptor, scorpion, crab,
  pterodactyl) instead of a character model. `tools/make_locations.py` has default stats
  for each (`BEAST_STATS`) and a `beasts()` helper that places them on open ground.
- Enemies wander near their spawn until Oto comes within 12 m (or hits one), and give up
  past 24 m.
- `boss`: `{"phases": [0.5, 0.25], "heal_on_phase": 0.6, "absorbs_ki": true, "drain": 0.5}`
  (`BossKit`; every key optional).

## Tile characters

| Char | Tile | Char | Tile |
| --- | --- | --- | --- |
| ` ` | void (blocked, not drawn) | `#` | wall (blocked) |
| `.` | grass | `B` | building lot (contiguous lots become one building) |
| `,` | dirt | `T` | oak tree (blocked) |
| `:` | sand | `P` | pine tree (blocked) |
| `;` | rock | `Y` | palm on sand (blocked) |
| `o` | wasteland | `b` | bush |
| `s` | snow | `r` | boulder (blocked) |
| `m` | metal floor | `M` | small mesa (blocked) |
| `c` | cloud | `L` | lamp post on pavement |
| `~` | water (blocked) | `D` | door marker |
| `=` | road | `@` | default spawn |
| `_` | pavement | `1`-`9` | exit (see `exits`) |
| `+` | plaza | `W` `F` `C` | wood, tile, carpet floors |

## Props

`Props.DOCS` in `scripts/world/props.gd` lists every prop type and its params; see them all in
the gallery (`python tools/run.py shot gallery --args="--gallery props --page N"`). Solid props
block the cells under their footprint unless the spec sets `"walkable": true`. Colour params
(`color`, `wall`, `awning`, `roof`) take `[r, g, b]` or `"#rrggbb"`.

## Fixtures

Interactive props (`scripts/world/fixture.gd`) go in `props` like any other prop; their
state lasts in `GameState.flags`:

| Type | Params | Behaviour |
| --- | --- | --- |
| `level_gate` | `level`, `w` | Blocks until Oto reaches `level` |
| `memory_gate` | `form` or `flag`, `w` | Blocks until that Shadow form or flag. Never open it ahead of its rung of the memory ladder |
| `key_door` | `key`, `w` | Opens for good when Oto interacts carrying that key item (`Items.KEYS`) |
| `bridge` | `flag`, `w`, `length` | Walkable (over water) once `flag` is set; always, without one |
| `floor_switch` | `flag` | Sets `flag` when stepped on |
| `breakable_rock` | `hp`, `size` | Breaks under melee and ki hits; stays broken |
| `save_lantern` | | Rest: full HP and ki, and save the game |
| `food_pot` | | Chi-Chi's leftovers: 10% HP, as often as she likes |
| `fishing_spot` | (rot) | A jetty pointing along -Z into water. Once Gohan has taught her (flag `paozu_fished`), a timed bite gives a fresh fish worth 30% HP. The spot then rests for 25 s. `shore_spot()` in `make_locations.py` places and turns one |

`levels/dev_fixtures.json` (not on the world map) has one of each. Check it with
`python tools/run.py shot level:dev_fixtures --args="--spawn gate --sim north --setlevel 5"`.

## Workflow

1. Generate a draft: `python tools/gen_level.py town --id my_town --out levels/my_town.json`.
2. Edit the grid by hand, add props/NPCs/exits.
3. `python tools/run.py levels` to validate, then `python tools/run.py shot level:my_town --args="--far"`.
4. To put it on the world map, add an entry to `levels/world.json` (`pos` in metres, origin at
   the map centre; `icon`: city, mountain, island, desert, tower, lookout).

`tools/make_locations.py` builds the canonical locations (and `dev_fixtures`), and it still
reproduces every file exactly. So add things there (its `lantern()` helper places a save
lantern on open ground) and regenerate, rather than editing the JSON. If you ever hand-edit
a level, remove it from that script so the edits are kept.
