# Sound

Session 5 (2026-10-29). Every sound plays through the `Sfx` autoload (`scripts/sfx.gd`). The files
are Kenney CC0 sounds (`assets/audio/sfx/<name>.ogg`, `assets/audio/voice/`), picked by the owner
from a preview page of candidates; credited in `CREDITS.md`.

```gdscript
Sfx.play("punch")            # a one-shot, with a little pitch variety
Sfx.play("ki_orb", 0.8)      # pitched down
Sfx.loop_on("ki_charge")     # loops: ki_charge, ki_beam; Sfx.loop_off(...) ends one
Sfx.step("grass")            # a footstep for that ground
Sfx.babble("Oto")            # one syllable in the speaker's voice (the dialogue box calls it)
```

Headless runs (tests, screenshots) are silent. Recording with `--write-movie` captures audio.

## Babble

Gibberish while a line types: one syllable per letter, paced by the voice's speed, a little
pitch wander, a lift (Goku) or a settle (everyone else) near the end of a sentence. Style A
(pitched Kenney blips), the owner's pick.

| Voice | Who | Blip | Pitch | Speed |
| --- | --- | --- | --- | --- |
| `oto` | Oto | tone | 209 Hz | 1.00 |
| `woman` | the townswomen, Chi-Chi, Bulma, Mrs. Briefs, Lottie, Clementine | pep | 340 Hz | 1.00 |
| `man` | every other speaker | tone | 118 Hz | 0.95 |
| `goku` | Goku | pluck | 172 Hz, rising at a phrase's end | 1.25 |

A new woman who is not a townswoman goes in `Sfx.WOMEN`. Narration has no voice.

## Effects and where they play

| Name | Event | Name | Event |
| --- | --- | --- | --- |
| punch, punch_heavy, swing | combo hits, the third hit and the flurry finisher, a miss | hurt, guard | Oto hit, a hit on her guard |
| ki_blast, ki_orb | each Ki Blast shot, the Charged Orb | ki_charge (loop) | charging ki (V) or gathering |
| ki_beam (loop) | the Void Beam | explosion | charged shots and the Void Burst hitting |
| form_up, form_down | Shadow forms | flight | the world map's boost |
| enemy_down, rock_break | a foe falls, a rock breaks | door, gate, lantern | doors and exits, gates opening, saving |
| step_grass/stone/wood/snow | footsteps by ground (sand uses snow) | capsule, food, dish | pickups, a new dish |
| level_up, key_item | level up; key items, senzu, a learned technique | ui_move/confirm/back/error/open | menus |
| dialogue_next | advancing dialogue | | |

The intro cutscene uses flight, ki_charge, ki_orb, ki_beam, explosion and rock_break.

## Checking

`python tools/run.py test` checks every file loads and each speaker's voice. To hear them:
`godot --path . --fixed-fps 30 --write-movie tools/out/voice_reel.avi --quit-after 480 -- --scene res://scenes/ui_preview.tscn --ui voices`.
No music yet.
