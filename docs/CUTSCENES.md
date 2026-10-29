# Cutscenes

Session 5 (2026-10-29). Cutscenes are scripts: one GDScript per scene that extends `Cutscene`
(`scripts/cutscene/cutscene.gd`) and writes its beats in `play()` with awaits. The scene file
is one root node plus the script, like every other scene.

```gdscript
extends Cutscene

func play() -> void:
	sky("dusk")
	open_set(Color(0.86, 0.62, 0.42), "noise", "mesa", ["cactus", "rock"])
	var oto := actor("oto", Vector3(30, 14, 26))
	camera_at(Vector3(-9, 2.5, 12), Vector3(6, 4, 4), 55)
	await Overlay.fade_from(1.2)
	fly(oto, oto.position, Vector3(0, 2, 0), 2.6)            # no await: the camera moves with it
	await camera_follow(oto, Vector3(-6, 1.8, 8), 2.6)
	anim(oto, "beam")
	await wait(1.0)
	CutFx.beam(self, bone_pos(oto, "RightHand"), Vector3(-3, 2, -24))
	await Overlay.say(["Oto|Not yet."])                     # dialogue boxes work as anywhere

func finish() -> void:                                        # after the last beat, or a skip
	get_tree().change_scene_to_file("res://scenes/title.tscn")
```

## The director (`Cutscene`)

| Call | Does |
| --- | --- |
| `stage(level_id)` / `open_set(ground, tex, ring_prop, near_props)` / `sky(preset)` | the set: a level as scenery, or an open plain with props round the horizon (clear sight lines) |
| `actor(preset, pos)` | a dressed character |
| `anim(ch, name, speed)`, `anim_speed(ch, s)`, `hold(ch, name, seconds)` | play an animation; `hold` freezes a frame (a pose) |
| `face(ch, point)`, `face_expr(ch, "cold")`, `bone_pos(ch, "RightHand")` | turn, set an expression, find a hand or head in the world |
| `move(ch, to, time, bend)`, `fly(ch, from, to, time, bend)` | ease along a curve; `fly` adds the flying pose and a ki trail |
| `camera_at`, `camera_to(pos, look, time, fov)`, `camera_follow(ch, offset, time)`, `shake(time, amount)` | the camera |
| `wait(seconds)` | a beat |

Leave out `await` to run things at the same time. Any confirm or cancel press skips: the scene
stops and `finish()` runs (set `skippable = false` for one that must not be skipped).

## Effects (`CutFx`, `scripts/cutscene/cut_fx.gd`)

`trail`, `charge` (an orb that follows a Callable position), `beam(from, to, grow, hold, width)`,
`impact`, `debris`, `dust_ring`, `aura`. They use void-violet with a pale rim, never gold or
fire (the Shadow forms' rule), and tidy themselves up.

## Picking poses

`scenes/pose_sheet.tscn` renders Oto holding frames side by side:
`python tools/run.py shot pose_sheet --resolution 1800x700 --args="--turn 90 --poses beam@0.72,beam@1.0"`.
`scripts/tools/probe_anims.gd` prints each hand's reach over time (when a punch or beam lands).

## Oto's ki animations (added 2026-10-29, Mixamo, all in place)

| Name | Mixamo | Length | Moments |
| --- | --- | --- | --- |
| `beam` | BEAM | 3.33 s | hands back 0.72, both thrust out 1.0 to 2.7 |
| `cast_spell` | Casting Spell | 7.70 s | a long gather; a crouched cast near 3.0 |
| `ki_blast_1h` | Standing 1H Magic Attack 01 | 2.30 s | right hand out at 1.11 |
| `ki_blast_2h` | Standing 2H Magic Attack 01 | 2.70 s | both hands out at 1.35 |
| `ki_blast_2h_b` | Standing 2H Magic Attack 02 | 2.63 s | both hands out at 1.49 |
| `ki_area` | Standing 2H Magic Area Attack 01 | 2.97 s | release at 1.83 |
| `ki_area_b` | Standing 2H Magic Area Attack 02 | 3.27 s | release at 1.47 |

They are not used in combat yet: wiring them to the ki techniques is a gameplay decision.

## The intro (`scenes/intro.tscn`, `scripts/cutscene/intro.gd`)

The game opens on it (`run/main_scene`). Oto flies in low over a dusk desert, lands, gathers ki
between her hands with the `beam` animation, fires a void-violet beam that shatters a sandstone
spire, turns to the camera in her stance, and the title fades in. Any key skips to the title.
About 12 seconds.
