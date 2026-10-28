# Rigging and animation

Oto is rigged with Mixamo's 65-bone skeleton. Her animations come from Mixamo FBX files, and
everything the game builds on her (clothes, gold, hair, the face) bends with the skeleton.

## Files

`assets/models/oto/rig/` holds one FBX per animation. Each file also carries the skinned body,
so any of them works as the skin.

| File | Animation | Used for |
| --- | --- | --- |
| `walk.fbx` | Walking | walking near enemies or after a fight |
| `hot_walk.fbx` | Hot walking | walking when she has been calm for 3 s and no enemy is within 12 m |
| `l_punch.fbx` | Left punch | combo hit 1 |
| `r_punch.fbx` | Right punch | combo hit 2 |
| `cross_punch.fbx` | Cross punch | combo hit 3 (it launches) |
| `quad_punch.fbx` | Quad punch | the flurry: hold attack and release, four hits, the last one launching |
| (none yet) | idle | until an idle animation arrives, she holds the walk's passing frame |

How the files were made: upload `mixamo_upload/oto_clean.zip` to Mixamo, place the markers,
then download each animation as FBX Binary, 30 fps, no keyframe reduction, with "In Place"
ticked for anything that travels.

## How it works (`scripts/characters/rig.gd`)

- `Rig.RIGS` lists each rigged base mesh: its skin file, its animations, which ones loop, the
  idle frame, when each strike lands (`hits`), and the ground speed each walk was made for.
- `Outfits.apply` dresses the static T-pose mesh as before, then calls `Rig.attach`:
  - **The body.** The skinned body is loaded and lined up with the static mesh. Mixamo returned
    it at 1/100 scale, and it lines up to within 0.01 mm. It shares the static body's material,
    so Shadow-form tints still apply. The static mesh stays, hidden: the outfit and face are
    built on it, and the fit checks measure against it.
  - **The outfit.** Every outfit, hair and face piece is skinned. Each vertex takes the bone
    weights of the three nearest body points, so a gauntlet follows the forearm and a trouser
    leg follows the thigh and knee. The mesh a piece was built with is kept as its `fit_mesh`
    meta (`Rig.fit_arrays`).
  - **Hanging cloth.** ClothPanels keep their physics. Their pins ride the bone nearest to
    them, and their leg colliders move with the legs (`ClothPanel.pin_node`, and a third item
    on a collider).
  - **The animations.** An `AnimationPlayer` ("Anim") holds them all. The visual gets the metas
    `anim`, `skeleton` and `rig`.
- `Player` drives it. Combo hits play the three punches at 1.6x speed, timed so that each fist
  lands 0.12 s after the press. The flurry plays the quad punch at 1.5x, and its four hits land
  when its four punches do. Walks play at the player's ground speed relative to the walk's own
  (clamped 0.7-2.4x), with no root motion.
- Dressing Oto with the rig takes about 1.6 s, mostly the weight transfer for about 60 pieces.

## Tools

- `python tools/orbit_video.py --mode anims --no-gif` records the animation reel (walk, hot
  walk, combo, flurry, from level, high, low and behind) to `tools/out/anims.avi`.
- `godot --headless --path . --script res://scripts/tools/probe_anims.gd -- <fbx...>` prints each
  hand's reach over time. That is how the `hits` times were found.
- `godot --headless --path . --script res://scripts/tools/inspect_rig.gd -- <fbx...>` lists the
  nodes, bones and animations in a file.

## Next

- An idle, a run and getting-hit/knock-down animations from Mixamo. The run would replace the
  sped-up walk when sprinting.
- Rig the male base (`mixamo_upload/male_base_clean.zip`) and Goku the same way.
