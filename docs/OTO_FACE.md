# Oto's face, and the face kit

Oto's face is the first face in the game. It is also the trial for a reusable system: every
later NPC and canon face is built from the same parts.

## What the owner asked for (2026-10-28)

- A face for Oto, drawn from three reference sheets: DBZ female eye shapes (Pan, Marron, baby
  Bulma, Chi-Chi, Android 18, Mai, Videl), a pencil sheet of anime mouths, and a sheet of
  hard-edged angry male eyes and brows.
- Everything a face needs: eyes that blink, a mouth that moves while the character speaks and
  stays closed otherwise, a nose and a chin.
- Smooth cel-style art, not blocks. Parts must mix and match: different eyes, noses, face
  shapes and skin colours combine into different faces.

Nothing was copied from the references. They guide the shapes only, so they are not credited
in `CREDITS.md`.

## Oto's look (`Face.LOOKS["oto"]`)

| Part | Choice | Why (design document) |
| --- | --- | --- |
| Eyes | `almond` (Android 18 / Mai family), widened to 62 mm, lid 22 mm, gaze 1 mm outward | Calm and cool. "So dark they seem to be looking at something just behind you." |
| Iris | near-black violet, dim catch-light | very dark eyes |
| Brows | `calm`, pale lilac-grey | Her hair is pale grey, and black ink barely shows on her dusk-brown skin |
| Mouth | `still`: a deadpan dash with a small plum lower lip | She does not fidget |
| Nose | `long`: a DBZ ridge in her own skin, after sheet nose #28 in profile and #33 head on; size C, the owner's pick (60 mm long, 26 wide, 22 out), with ink `tick_tri` | The owner asked for a longer, wider nose, several times the first one |
| Ears | `dbz`: ink lines on the ears her head mesh already has (rim, inner fold, forked ridge, tragus, stair-step notch, a shaded bowl), from the owner's ear sheet | |
| Chin | `soft` (the head's own shape) | |
| Blink | every 5.5-9 s, slow and rare | |

In Shadow forms she gets the `void` variant: black irises with no catch-light, black brows, and
the skin darkened like her body. Forms 2-3 use the `cold` expression (narrowed eyes, flatter
brows). Her eyes are never gold and never glow.

Her hair (preset `"shell": true`) is cast onto the real head: a cap with a scalloped fringe just
above the brows, sides that turn down past the temples, and one loose strand of bangs falling
beside her right eye, outside it. Her ears stay bare: the owner wants the hair NOT to touch them,
so the hairline arches over each ear with a gap and falls behind it (`Face.hairline`; the ear
on her head is about 97-118 degrees round from the front, 48 mm below to 35 mm above the eye
line, `"ear_top"` in the hair spec).

## Ears

The head mesh has ear shapes; the DBZ lines are drawn onto them. Each ear has its own plate,
cast straight onto the ear from the side it faces (`Face.ear_plate`) so the art is not
squeezed, with art in ear space (`FaceParts.EARS`, `FaceParts.ear`). Where the ear is on each
mesh is in `Face.HEADS[...]["ear"]` (measured on Oto's head: 95-123 degrees round from the front,
50 mm below to 36 mm above the eye line). Close-up: `--gallery turnaround --preset oto --ear --turn -1.95`.

## Noses

`scripts/characters/nose_inks.gd` holds all 40 noses from the owner's pencil sheet, numbered in
sheet order (rows left to right): front views with nostrils (1, 4, 6), rounded three-quarter
cups (2, 7, 8), profiles (3, 29, 31, 40), and the angled side-view ticks, hooks and wedges that
make up most of the sheet. Each is ink strokes in nose units; a look picks one with
`"nose_ink"`, or the 3D nose's default ink is used. The 3D shapes are in `FaceParts.NOSES`:
`ball` (button, broad) or `wedge` (wedge, pointed, long). A look can change a nose's numbers
with `"nose_tune"`. `--gallery nosesizes --page 0|1|2` shows Oto's long nose at sizes A-D
(40/50/60/70 mm) from the front, in profile and three-quarter. The owner kept all 40: `--gallery faces --page 4` and `--page 5`.

## How it works

| File | Role |
| --- | --- |
| `scripts/characters/face_canvas.gd` | `FaceCanvas`: a 4x supersampled flat painter (polygons, tapered ribbons, splines). Face space is millimetres, +X toward the character's left, +Y up, origin on the centre line at the eye line. The full face texture is 1024 x 768 px = 341 x 256 mm of unwrapped head. |
| `scripts/characters/face_parts.gd` | `FaceParts`: the kit as data and drawing code. `EYES`, `EYE_STATES`, `BROWS`, `BROW_STATES`, `MOUTHS`, `MOUTH_SHAPES`, `NOSES`, `CHINS`, `SKINS`, `palette()`. It draws the left side, which is mirrored for the right. |
| `scripts/characters/face.gd` | `Face`: `LOOKS` (character recipes), `EXPRESSIONS`, cached layer textures, `card()` (a flat face image, for sheets and portraits), and the head plates: grids ray-cast onto the real head mesh (`plate`, `hair_shell`, `strand`, `bump`). |
| `scripts/characters/face_rig.gd` | `FaceRig`: the live face, added by `Outfits.apply` under the outfit as `Face` (visual meta `"face"`). It has `express()`, `set_part()`, `blink()`, `start_talking()` / `stop_talking()`, `set_form()` and `set_alpha()`. |

- There are four layers (eyes, brows, mouth, nose marks). Each is its own transparent plate
  1.2-1.6 mm off the skin, so a blink or a mouth shape swaps one small texture. Textures are
  cached per look, state, variant and skin. A face draws its blink and talking frames when it
  attaches (about 80 ms for Oto), not during play.
- Talking: `Overlay.say` emits `talking(speaker, on)`. A face whose preset `"speaker"` matches
  the speaker cycles through ah/oh/ee/wide/closed every 0.09-0.14 s, never showing the same
  shape twice in a row, and closes when the line has finished typing.
- Forms: `Player._apply_form_visual` calls `set_form`, and the form-2 flicker fades the face
  with the body.

## Making a new face

1. Add a look to `Face.LOOKS`: choose `eyes`, `brows`, `mouth`, `nose` and `chin` from the
   FaceParts tables, and optionally `tune` (eye numbers), `pal` (colours) and `blink`.
2. Give the outfit preset `"face": "<look>"` and `"speaker": "<dialogue name>"`.
3. Check it with:
   - `python tools/run.py shot gallery --args="--gallery faces --page 3"` (add it to the mixes there)
   - `python tools/run.py shot gallery --args="--gallery turnaround --preset <id> --head"`
4. For a new part style, add an entry to the FaceParts table. New eye styles are lid profiles
   plus numbers, so most need no new code.

Untested so far: plates on `male_base` (which has a separate head part) and on `goku`. Each
base mesh needs an eye-line height in `Face.HEADS`.

## Gallery views

- `--gallery faces --page 0..3`: eyes, brows, mouths, then whole faces (Oto in four moods and
  four mixed faces on other skins).
- `--gallery expressions --page 0|1 [--shadow]`: Oto's head in every expression.
- `--gallery turnaround --preset oto --head [--turn 0.7]`: her head, front or three-quarter.
