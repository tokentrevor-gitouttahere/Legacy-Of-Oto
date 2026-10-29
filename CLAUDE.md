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
| `scripts/overlay.gd` | Dialogue (`await Overlay.say(["Name|line"])`) with talking portraits, fades, cards, toasts, prompts |
| `scripts/ui/` | `UiKit` (colours, fonts, panels, bars, the logo), `Portrait` (talking dialogue portraits), `ItemIcons`; see `docs/UI.md` |
| `scripts/characters/npc_women.gd` | `NpcWomen`: 31 designed townswomen (face + outfit) and three recolours of each, presets `woman_<id>[_2..4]` |
| `scripts/player.gd` | Oto: movement, combat, forms, interaction, optional `blocker` for walls |
| `scripts/enemy.gd`, `life_saiyan.gd`, `ki_shot.gd` | Enemies (behaviours, tiers, drops), the prologue boss, projectiles |
| `scripts/boss_kit.gd` | `BossKit`: boss phases, ki absorption, drain on contact |
| `scripts/pickup.gd`, `damage_number.gd`, `hud.gd` | Capsules, food and ki motes; floating numbers; HUD and the scan panel |
| `scripts/quests.gd`, `dishes.gd`, `talks.gd`, `items.gd` | Quest registry, the Menu, NPC conversations with effects, gear and key items |
| `scripts/models.gd` | `ModelLoader`: base meshes (oto, male_base, goku) |
| `scripts/characters/rig.gd` | `Rig`: Mixamo skeleton and animations, skinning the outfit to it (`docs/RIGGING.md`); FBX files in `assets/models/oto/rig/` |
| `scripts/characters/` | `Outfits` presets and `OutfitBuilder` (clothes, hair, accessories); `ClothPanel` cloth physics; `Beast` procedural animals; faces: `FaceCanvas` painter, `FaceParts` kit, `Face` looks and head plates, `FaceRig` live face, `NoseInks` the 40 DBZ noses (`docs/OTO_FACE.md`); `Garment` clothing cast onto the real body |
| `scripts/characters/body_shape.gd` | `BodyShape`: reshape the female base (bust, waist, hips, butt, stomach) as a copy, with the skinned body moved to match; presets in `assets/models/body_presets.json`; the slider tool is `scenes/body_editor.tscn` (title menu). Not used by the game's characters yet (`docs/BODY_STUDY.md`) |
| `scripts/world/` | `Props` library, `Mats` textures, `Skies`, `Level` tile maps, `Fixture` (gates, doors, lanterns...), `location.gd`, `world_map.gd` |
| `scripts/tools/dev_tests.gd` | Headless rule checks, run by `python tools/run.py test` |
| `scenes/` | title, prologue_fight, paozu (story), location (any level), world_map, test_arena, gallery, dev_tests, body_editor, body_study, ui_preview |
| `levels/*.json` | Tile-map locations; `levels/world.json` places them on the world map. Capsule Corp home (where Oto lives): `capsule_corp_home` (hall and living room) leads to `capsule_corp_kitchen`, `_pantry`, `_garden`, `_gravity` and `oto_room`, and to the lab and West City |
| Regions | `diablo_desert`, `granite_peaks`, `northern_ice_fields`, `crystal_cavern`, built with the region kit: tile letters, props, skies and generators in `docs/REGIONS.md` (read it before building a new outdoor or cave area). West City shops: `west_city_noodle_bar`, `_bakery`, `_capsule_shop` |
| `assets/fonts/` | EB Garamond (titles, names) and Nunito (text), SIL OFL; used through `UiKit` |
| `assets/models/` | OBJ meshes and `landmarks.json` (body measurements for clothing) |
| `docs/MECHANICS_REFERENCE.md` | Legacy of Goku II systems vs ours, gameplay backlog, open decisions. Read before building a gameplay system |
| `tools/` | Python tools for building and checking (see below) |

## Tools (run from the project root)

```
python tools/run.py import                         # re-import, report script errors
python tools/run.py shot <scene|level:id>          # screenshot -> tools/out/<name>.png, prints errors
python tools/run.py shot level:west_city --args="--far"
python tools/run.py shot gallery --args="--gallery props --page 2"
python tools/run.py shot gallery --resolution 1600x900 --args="--gallery women --page 0"   # the townswomen in 3D
python tools/run.py shot ui_preview --frames 120 --args="--ui dialogue --speaker Mei"   # dialogue, narration, toast, prompt, card, portraits
python tools/run.py levels                         # validate all levels/*.json
python tools/run.py test                           # headless rule checks (PASS/FAIL lines)
python tools/gen_level.py city --id foo ...        # generate a new tile map (city/town/wild/island/interior)
python tools/make_locations.py [id]                # regenerate the canonical locations
python tools/model_sheet.py male_base              # front/side silhouette with grid, for landmarks
python tools/publish_web.py                        # export the Web preset and deploy it to GitHub Pages
python tools/orbit_video.py [--shadow]             # 360 orbit + over/under -> tools/out/orbit.avi/.gif
python tools/orbit_video.py --mode anims --no-gif  # the animation reel -> tools/out/anims.avi
python tools/orbit_video.py --mode moves --no-gif  # kicks, flight, falls, reactions -> tools/out/moves.avi
python tools/angle_check.py [--shadow] [--only a,b] # every outfit part level/high/low -> tools/out/angles_*.png
python tools/run.py shot body_study --resolution 1800x800 --args="--study original;curvy;full_figure --view front [--dress]"  # reshaped bodies side by side
python tools/body_shape.py --preset full_figure --out tools/out/x.obj  # export a reshaped OBJ (offline twin of BodyShape)
```

Repo: github.com/tokentrevor-gitouttahere/Legacy-Of-Oto (public). Live build:
tokentrevor-gitouttahere.github.io/Legacy-Of-Oto (gh-pages). `HANDOFF.txt` has the session history,
the owner's decisions and the lines waiting for review.

Always look at the screenshot after a visual change (Read the PNG). `run.py` exits 1 on any
SCRIPT ERROR. Developer flags (after `--`, or via `--args=`): `--scene`, `--level`, `--shot`,
`--frames`, `--sim fight|menu|walk|map`, `--timescale`, `--auto-dialogue`, `--zoom`, `--far`,
`--skipfight` (prologue), `--spar` (paozu), `--gallery outfits|props|models|beasts --page N`,
`--gallery turnaround --preset <id>` (one outfit up close: front, side, back; `--head` frames the
face, `--torso` the body, `--turn R` turns it, `--hide a,b` hides outfit pieces by name),
`--gallery faces --page 0-5` (the flat face kit; pages 4-5 are the noses), `--gallery nosesizes
--page 0-2`, turnaround `--ear` (the left ear face-on, with `--turn -1.95`), `--hand` (the left gauntlet), `--gallery expressions
--page N [--shadow]`.
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
  check it in the gallery turnaround. Hanging cloth (panels, tails) is a `ClothPanel` added with
  `OutfitBuilder.cloth_panel()`. Look at a screenshot of what you changed. Do not run the
  every-part sweep `tools/angle_check.py` (level, high, low) by default: the owner said (2026-10-28) to
  ask them before doing it. Oto's queen's attire (`docs/OTO_OUTFIT.md`) is the example.
  Clothing that must not let the body through goes in `Garment.tube` (preset `"fitted": true`
  gives the builder the body mesh). Fix a misfit in the clothing first; reshaping the body is
  fine when the owner asks for it (they said "adjust the clothing" about one fit problem, not
  as a rule).
  New face: add a look to `Face.LOOKS` and `"face": "<look>"` (plus `"speaker"`) to the preset;
  check it in `--gallery faces --page 3` and the turnaround `--head`. New location: see
  `docs/LEVEL_FORMAT.md`.
- Place things in the canonical locations through `tools/make_locations.py`, then
  regenerate. It reproduces the level files exactly.
- **Oto is hers alone** (owner's rules, `docs/BODY_STUDY.md`): her body is the build `Oto Body Final`
  (`"build"` on her outfit presets; made in the Body Shape Editor, `assets/models/body_presets.json`);
  no other woman may share her exact proportions, and her outfits (`oto`, `oto_stage`) and the pieces
  of her queen's attire (`Outfits.OTO_ONLY`) are never put on another model. `dev_tests` enforces it.
  Another woman gets her own build in the editor, or the plain base.
- Oto is rigged (`docs/RIGGING.md`): build clothing on the static T-pose mesh as before;
  `Rig.attach` skins every outfit piece to the skeleton afterwards (fit checks read
  `Rig.fit_arrays`). male_base and goku are still unrigged with procedural motion.
  Re-time strikes with `scripts/tools/probe_anims.gd` when an animation changes.
- UI is drawn with `UiKit` (`docs/UI.md`); new screens use its `frame`, `bar` and `text`, not raw
  `draw_string` on the fallback font. A new speaker with a face gets a portrait automatically.
- New townswoman: add a design to `NpcWomen.DESIGNS` (plus three names to `NAMES` for her
  recolours); never Oto's build or pieces. Her clothes are cast onto her body (`"cast": true`).
- Credit asset creators in `CREDITS.md` (CC BY 4.0 requires it).
