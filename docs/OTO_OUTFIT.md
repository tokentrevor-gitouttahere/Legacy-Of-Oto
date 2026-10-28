# Oto's queen's attire

The outfit Oto wears from the prologue on: what she wore as queen of the Shadow Saiyans. It is
the `oto` preset in `scripts/characters/outfits.gd`. The earlier green bodysuit is still there
as `oto_stage`. Check it with
`python tools/run.py shot gallery --args="--gallery turnaround --preset oto"`.

## Brief

The owner (2026-10-28) asked for:
- Ancient-feeling clothing with a **scapular**.
- **Realistic cloth physics.**
- **Golden gauntlets** that start just behind the wrist and stop halfway to the elbow, part of
  her attire as queen.

The references were monk and warrior wear: a hanging front panel, a wrapped sash, bound
forearms and shins. They were for mood, not to copy. The design document adds three rules:
- Her stage outfit is "green with gold trim and a skirt panel that swings as she moves".
- She arrives with **no shoes**.
- Gold belongs to her clothing, never to her Shadow forms.

## Layers

| Layer | Look | Style key |
| --- | --- | --- |
| Bodice | Sleeveless deep-green linen, crossed over at the chest, low standing collar. Arms and shoulders bare | top `wrap_bodice` |
| Scapular | One long panel over both shoulders, hanging front and back to mid-shin. Gold-thread edges, gold hem; on the front only, a gold plaque bearing the sigil in black | acc `scapular` |
| Sash | Wide undyed linen wound twice, knotted at her left hip, two tails hanging free | acc `wide_sash` |
| Royal cord | Gold cord over the sash, gold disc clasp with a black stone, a short gold tassel | acc `royal_cord` |
| Trousers | Loose, muted charcoal-green, gathered into cross-bound linen shin wraps. Bare feet | bottom `wrapped` |
| Gauntlets | Rigid gold bracers from just behind the wrist to halfway to the elbow, slightly flared. Two raised ridges, a spine along the back of the forearm, and the sigil engraved on the outer face | acc `gauntlets` |
| Wraps | Linen over the knuckles, and from the gauntlets up to below the elbow, with a loose trailing end | acc `arm_wraps` |

**Palette:**
- bodice `#174529`
- scapular `#24663d`
- trim and gold `#e6b84c` / `#edba4c`
- sigil black on gold
- linen `#d1c7b2`
- trousers `#333d33`

Her skin is chocolate brown and her hair pale grey, as before.

## The sigil: The Wall

The Shadow Saiyans' mark, chosen by the owner on 2026-10-28. It is a frame with one upright
line through it: the line of sunlight that split their world, with her people on its dark
side.
- **Colours:** black on gold.
- **Where:** a plaque on the scapular's front panel (not the back), and engraved on the outer
  face of both gauntlets. On the gauntlets its long axis runs along the forearm, so the line
  stands upright when her arms are down.
- **Code:** `scripts/characters/sigil.gd` draws it in code.
  - The plaque is a white field with a black sigil, tinted by its material.
  - The engraving is the black sigil on transparent.
  - On the cloth it is a decal that follows the moving panel.

## Shadow forms: gold turns silver

In any Shadow Saiyan form her hair goes pitch black and all of the outfit's gold turns
brushed silver. That covers the gauntlets, the cord, clasp and tassel, the gold-thread edges
and hem, and the sigil plaque. Base form turns it back to gold. This keeps the design rule
that Shadow forms never use gold.
- `OutfitBuilder.metal()` makes each gold material unique to the character and registers its
  silver.
- `Outfits.set_silver(visual, on)` swaps them, along with the cloth panels' gold faces.
  `Player._apply_form_visual` calls it on every form change.
- To preview it: `--gallery turnaround --preset oto --shadow`. Add `--closeup` to frame the
  gauntlet and the plaque.

## Cloth physics

These pieces are `ClothPanel`s (`scripts/characters/cloth_panel.gd`):
- the scapular below the sash, front and back
- the two sash tails
- the tassel
- the two wrap ends

Each one is a grid of verlet particles:
- **Pinned top row:** it follows the body, so every step, lean and bob drives it.
- **The rest:** falls under gravity, sways in a light gusting wind, and holds its shape
  through stretch, shear and bend links.
- **Colliders:** it is pushed out of sphere colliders on the hips and legs
  (`OutfitBuilder.leg_colliders`) and kept above the ground.
- **Colour:** set per face, which keeps the gold edges, hem and emblem crisp.
- **Teleports:** a jump of more than 3 m (a scene start, a teleport) resets it in a settled
  pose.
- **Fast motion:** a per-frame speed cap keeps the prologue fling from tearing it apart.

The tests in `scripts/tools/dev_tests.gd` (`_test_cloth`) check that the scapular trails behind
her when she runs, settles when she stops, never passes behind her legs and survives a fling.

**Tuning:** `ClothPanel` vars (`damping`, `wind`, `iterations`, `max_step`) control the feel. A
heavier panel wants lower `wind`; a lighter tail wants more `rows`.

## When the rigs arrive

Like all clothing here, the static parts follow the bind pose. With the Mixamo rigs:
- parent the bodice, sash and gauntlets to bone attachments (chest, hips, forearms);
- keep the ClothPanels where they are, but pin them to those attachments;
- move the leg colliders onto the thigh and shin bones so the panels react to real steps.
