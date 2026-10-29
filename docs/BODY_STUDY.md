# Body shapes

Oto's body can be reshaped (bust, waist, hips, butt, stomach), and **it is: her game body is the
build `Oto Body Final`** (bust 4.5, waist 0.8, hips 1.7, butt 5.0, stomach 0.6 cm; see "Oto's body"
below). The mesh file (`assets/models/base_female/model_0.obj`) is never edited: every shape is a copy
made in memory when a character is dressed.

## Oto's body (locked)

- The owner made the shape in the editor (2026-10-28) and said it becomes the new Oto model.
- `outfits.gd`: the `oto` and `oto_stage` presets carry `"build": "Oto Body Final"`. `Outfits.apply`
  swaps in that body (static mesh, outfit built on it, skinned body moved to match) for every
  character dressed with them: the player, the world-map flyer, the gallery. Shaping takes about 0.1 s
  and the skinned match about 0.3 s, both done once and kept.
- **No other woman may share her proportions** (owner's rule). Other women use other builds made in
  the editor, or the plain base. `dev_tests` checks that no other preset has a build equal to hers and
  that no saved shape but hers has her exact amounts; the editor refuses to save a copy of hers under
  another name, and cannot delete hers.
- **Her outfits are hers alone** (owner's rule): `Outfits.OTO_PRESETS` (`oto`, `oto_stage`) are only
  dressed on her own body (`Outfits.is_oto`), and `Outfits.OTO_ONLY` lists the pieces that exist only for
  her queen's attire (wrap bodice, wrapped trousers, scapular, wide sash, royal cord, gauntlets, arm
  wraps): any other preset that uses one is stripped of it, and `dev_tests` fails. The editor's dress-it
  box puts her outfit on her own shape only; any other shape gets a stand-in (`civilian_f`).
- A new woman's build: make it in the editor, save it, and give her outfit preset `"build": "<name>"`.

## The soft tint on her chest

Each shaped body has a soft area of darker skin on each breast (`BodyShape.tint_colors`, vertex
colours that multiply the skin), at the most forward point, 2.6 cm wide, fading out: a hint of an
areola for the day an outfit leaves her chest bare, with no edge, no detail and nothing raised. It
takes 16-29% off the skin colour at its centre (`AREOLA_DARKEN`, `AREOLA_RADIUS`). The skinned body
carries the same colours. The plain base, and so every woman without a build, has none.

## The study

## The tool

Title screen, **Body Shape Editor** (or run `scenes/body_editor.tscn`):

- Sliders for Bust, Waist, Hips, Butt, Stomach, in cm on a 170 cm figure (negative reduces). The body
  updates as you drag. Reset, and **Max reasonable** (the `full_figure` preset).
- **Save as preset** writes `assets/models/body_presets.json` (name -> the five amounts). Load and
  Delete work on the same list. The file only saves when the game runs from its project folder.
- **Wear her outfit** dresses her queen's attire on the new shape (about two seconds, when you let go
  of a slider). Front, Side, Back, Three-quarter, Turn slowly; drag to turn, wheel to zoom, Esc: title.
- Ranges (what still looks good): bust -2..6, waist -3..3, hips -3..4, butt -2..6, stomach -2..3.

Presets so far: `curvy` (bust 2, waist -1.2, hips 2), `slim` (-1, -0.5, -1.2), and `full_figure`
(bust 4, waist -1.8, hips 2.5, butt 4), the most the shape carries before it stops looking good: at
bust and butt 5 the breasts begin to bulge past the ribcage seen from behind.

## The code

| File | What |
| --- | --- |
| `scripts/characters/body_shape.gd` | `BodyShape`: `BodyShape.new(mesh).shape({"bust": 4, ...})` returns a new mesh; `dressed(amounts)` returns the full rigged, dressed figure; presets file I/O |
| `scripts/tools/body_editor.gd`, `scenes/body_editor.tscn` | the slider tool |
| `scripts/tools/body_study.gd`, `scenes/body_study.tscn` | side-by-side renders: `python tools/run.py shot body_study --resolution 1800x800 --args="--study original;curvy;full_figure --view front"` (`--view side\|back`, `--dress` for the full figure, `--pose kick`) |
| `tools/body_shape.py` | the same shaping offline, to export a reshaped OBJ (`--preset full_figure --out x.obj`), for example to rig it in Mixamo |
| `scripts/characters/rig.gd` | one optional hook: a wrapper's `skin_hook` meta is called with the skeleton and the skinned body before `Rig.attach` reads them |

`dev_tests.gd` (`_test_body_shape`) checks: zero amounts give the source mesh; the GDScript shaping
matches the Python tool at four probe points and in total movement; seams do not tear; the head and
legs below the thigh do not move; each figure's skinned body is its own; the skinned body keeps its
8 bone weights; her bodice, sash and trousers sit outside a reshaped body.

## How the shape is made

Every amount is a smooth function of a point's position (in body heights from the soles, so it
scales with the figure), so the points the mesh repeats at its seams move together. Bust, butt and
stomach push the surface out (or in) inside a soft ellipsoid, along its normal blended with
straight forward (back for the butt), the bust sagging a little; each breast and cheek only moves
the points on its own side, so the gap between them stays. Waist and hips change the half-width of
the torso at their height (hips also push the back), with a long taper down the thigh so there is no
corner. The head, arms, hands and the legs below the thigh do not move (the lobe edges reach the arm
roots by under a millimetre).

## Things that went wrong on the way (so they are not rediscovered)

1. **The skinned body must move too.** What you see and animate is the Mixamo copy of the body, not
   the OBJ. `BodyShape.skin_hook` moves each of its points by the displacement of the nearest source
   point (they are the same surface), carried into the skinned mesh's own space. It lands exactly: the
   rest positions come out within 1e-6 of what was asked.
2. **Every figure shares one skinned mesh resource.** Editing it in place changes every figure that
   loads the file, and a second figure then reshapes an already reshaped body. The hook never edits
   it: it starts from the file's own arrays and gives each figure a new mesh.
3. **The skinned mesh has 8 bone weights a point.** Re-adding a surface without
   `Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS` makes Godot read 4, and the body bends wrongly in any pose.
4. **Bounding boxes line the two bodies up.** `Rig.attach` aligns the skinned body to the static mesh by
   their boxes. A bust that sticks out changes the static box; the skinned body must change the same
   way or it slides a few millimetres, and the face plates and shin wraps (millimetres off the skin) are
   buried. Moving both by one function keeps the boxes in step.

## What the outfit does

It is built on the reshaped static mesh, so it follows the new shape on its own: the bodice rounds
over the bust, the trousers fill out over the hips and butt (checked front, side and back).
Small ragged bits at the lower bodice edge and at the sash are the stock outfit's, not new.

## Limits

- It is a low-poly body (4234 points): small and medium changes are smooth; the largest are visibly
  rounded shapes rather than soft ones. Bust or butt past 5 cm bulges.
- The same function does not apply to the male base or Goku: their landmarks (`BodyShape` constants)
  are Oto's.
- Dressing takes about two seconds with a reshaped body (the stock figure is the same).

## Cloth that has to clear her new shape

- **The scapular's back panel** used to hang from a pin symmetrical with the front, on spheres
  centred on her old hips, so a bigger seat went through it. Now (`OutfitBuilder._seat_colliders`) it hangs
  from outside whatever she wears at the waist (the peplum flares) and from a column of small spheres
  tucked into the outermost layer a ray meets (skin, trousers, bodice or sash) down the middle and over
  each cheek, down past the crease of the seat. It has 12 rows instead of 9, so the few centimetres of
  peplum and seat are not skipped. The front panel is as it always was (a front version with the same
  colliders let the panel settle in a different place after a run, and nobody asked for it).
- The landmarks the builder places things by (`landmarks.json`) are moved to fit a build
  (`BodyShape.landmarks`): chest depth, waist and hip width and depth. The butt is deliberately not added
  to the hip depth, which the front hip spheres share.
