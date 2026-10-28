# Legacy of Oto: guide for agents

A Godot 4.7 top-down 3D action RPG in the style of Legacy of Goku, retelling DBZ through Oto,
an amnesiac first-age Saiyan queen. Story and character bible: `docs/` holds build status;
the source story documents live with the user (Oto Story, Oto Design Document). Keep
canon outcomes intact and follow the design document's tone and memory-ladder rules.

## Layout

| Path | What |
| --- | --- |
| `project.godot` | Autoloads: GameState, Overlay, PauseMenu, Controls |
| `scripts/game_state.gd` | Level, stats, forms, charge tier, ki techniques, gear, key items, flags, the Menu, saving, `travel()` / `travel_world()` |
| `scripts/overlay.gd` | Dialogue (`await Overlay.say(["Name|line"])`), fades, cards, toasts, prompts |
| `scripts/player.gd` | Oto: movement, combat, forms, interaction, optional `blocker` for walls |
| `scripts/enemy.gd`, `life_saiyan.gd`, `ki_shot.gd` | Enemies (behaviours, tiers, drops), the prologue boss, projectiles |
| `scripts/boss_kit.gd` | `BossKit`: boss phases, ki absorption, drain on contact |
| `scripts/pickup.gd`, `damage_number.gd`, `hud.gd` | Capsules, food and ki motes; floating numbers; HUD and the scan panel |
| `scripts/quests.gd`, `dishes.gd`, `talks.gd`, `items.gd` | Quest registry, the Menu, NPC conversations with effects, gear and key items |
| `scripts/models.gd` | `ModelLoader`: base meshes (oto, male_base, goku) |
| `scripts/characters/` | `Outfits` presets and `OutfitBuilder` (clothes, hair, accessories); `Beast` procedural animals |
| `scripts/world/` | `Props` library, `Mats` textures, `Skies`, `Level` tile maps, `Fixture` (gates, doors, lanterns...), `location.gd`, `world_map.gd` |
| `scripts/tools/dev_tests.gd` | Headless rule checks, run by `python tools/run.py test` |
| `scenes/` | title, prologue_fight, paozu (story), location (any level), world_map, test_arena, gallery, dev_tests |
| `levels/*.json` | Tile-map locations; `levels/world.json` places them on the world map |
| `assets/models/` | OBJ meshes and `landmarks.json` (body measurements for clothing) |
| `docs/MECHANICS_REFERENCE.md` | Legacy of Goku II systems vs ours, gameplay backlog, open decisions. Read before building a gameplay system |
| `tools/` | Python tools for building and checking (see below) |

## Tools (run from the project root)

```
python tools/run.py import                         # re-import, report script errors
python tools/run.py shot <scene|level:id>          # screenshot -> tools/out/<name>.png, prints errors
python tools/run.py shot level:west_city --args="--far"
python tools/run.py shot gallery --args="--gallery props --page 2"
python tools/run.py levels                         # validate all levels/*.json
python tools/run.py test                           # headless rule checks (PASS/FAIL lines)
python tools/gen_level.py city --id foo ...        # generate a new tile map (city/town/wild/island/interior)
python tools/make_locations.py [id]                # regenerate the canonical locations
python tools/model_sheet.py male_base              # front/side silhouette with grid, for landmarks
python tools/publish_web.py                        # export the Web preset and deploy it to GitHub Pages
```

Repo: github.com/tokentrevor-gitouttahere/Legacy-Of-Oto (public). Live build:
tokentrevor-gitouttahere.github.io/Legacy-Of-Oto (gh-pages). `HANDOFF.txt` has the session history,
the owner's decisions and the lines waiting for review.

Always look at the screenshot after a visual change (Read the PNG). `run.py` exits 1 on any
SCRIPT ERROR. Developer flags (after `--`, or via `--args=`): `--scene`, `--level`, `--shot`,
`--frames`, `--sim fight|menu|walk|map`, `--timescale`, `--auto-dialogue`, `--zoom`, `--far`,
`--skipfight` (prologue), `--spar` (paozu), `--gallery outfits|props|models|beasts --page N`.
Run state: `--setlevel N`, `--setform N`, `--givekey id`, and `--spawn name` in locations.
More sims: `--sim charge|north|interact`. Test arena only: `--pickups`, `--behaviors`,
`--charge <tier>` (with `--sim charge`), `--menutab N`, `--sense [--scouter]`. Run
`python tools/run.py test` after any rule change, and add a check for each new rule.

## Conventions

- Everything is built in code; `.tscn` files are one root node plus a script. Write scene files
  without a UTF-8 BOM (PowerShell `Set-Content -Encoding utf8` adds one and breaks them).
- GDScript is statically typed where inference works. Values from arrays/dictionaries are
  Variant, so declare their type (`var x: float = arr[0]`, `for side: float in [1.0, -1.0]`).
- Never name a method `_set`/`_get` (they override Object's).
- Units are metres; characters face +Z; `Level` cells are `tile` metres (2.0 outdoors, 1.5 indoors).
- New prop: add to `Props.DOCS` and the `match` in `Props.make`, set `_block()` if solid,
  check it in the gallery. An interactive prop is also a fixture: add its type to
  `Fixture.TYPES` and its behaviour in `fixture.gd`.
- New quest: add it to `Quests.DB` (start flag, step flags). Set the flags from story
  scripts, `Talks` or a level NPC's `flag` key. New dish: add it to `Dishes.DB` and give
  a cook NPC `"dish": "<id>"`.
- New outfit: add a preset to `Outfits.PRESETS` (styles listed at the top of `outfits.gd`),
  check it in the gallery. New location: see `docs/LEVEL_FORMAT.md`.
- Place things in the canonical locations through `tools/make_locations.py`, then
  regenerate. It reproduces the level files exactly.
- The meshes are unrigged T/A-poses; animation is procedural for now. Clothing follows the bind
  pose; when Mixamo rigs arrive, parent outfit pieces to bone attachments (see `outfits.gd`).
- Credit asset creators in `CREDITS.md` (CC BY 4.0 requires it).
