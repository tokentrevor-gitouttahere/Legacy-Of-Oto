# UI and the townswomen

Session 5 (2026-10-29). Every screen is drawn in code with one kit, and the world has 124
women on the female base: 31 hand-designed women, each recoloured three ways.

## The look (`scripts/ui/ui_kit.gd`, `UiKit`)

The Shadow Saiyans' court: void-violet lacquer panels edged in gold, Oto's jade as the second
accent, and the Wall sigil (a frame split by one upright line) as the ornament. Gold is trim,
never fire. The fonts ship with the game in `assets/fonts/` (SIL OFL 1.1, licences beside
them), so the web build matches the desktop: **EB Garamond** (variable, weights 400-800) for
names and titles, **Nunito** for body text. `UiKit.display_font()` / `body_font()` return them
at a weight through a `FontVariation`.

| Helper | What |
| --- | --- |
| `frame(ci, rect, accent, sigil_top)` | the standard panel: cut corners, gold edge, inner hairline, corner gems |
| `bar(ci, rect, frac, color, ghost)` | a meter lit from above, quarter ticks, gold cap; `ghost` trails damage |
| `highlight`, `rule`, `diamond`, `sigil` | selected row, fading rule, gem, the Wall |
| `key_chip`, `key_row` | "[Z] Confirm" hints |
| `logo(ci, center, width, t, alpha)` | LEGACY OF / OTO: the lit O gold, the T the line's pale light, the dark O violet, the line of sunlight through the T |
| `SPEAKERS`, `speaker_color`, `speaker_look` | name colours, and which face draws a speaker's portrait |

## Dialogue (`scripts/overlay.gd`, `scripts/ui/portrait.gd`)

`Overlay.say(["Name|line"])` is unchanged. The box slides up. The portrait stands out of it,
with a name plate in the speaker's colour. Text types at 48 characters a second and rests on
punctuation, and a gem bobs when the line is done. A line with no speaker is narration: no
portrait, centred italics.

`Portrait` draws a head and shoulders for anyone with a face look (Oto, every townswoman). It
uses the same face layers as the 3D face (`Face.texture`), on a cel head with her hair style,
hair colour, skin and top colour. While her line types, the mouth runs through the visemes. It
closes on the pauses, and she blinks. Everyone else gets an emblem with their initial in their
colour, and sound rings while they speak. Toasts, the interaction prompt ("E: Talk to Mei" is
drawn as a key chip) and title cards use the same kit.

## Menus

- **Pause menu** (`pause_menu.gd`): Oto's card on the left (portrait, HP/Ki/EXP, forms, charge
  tier, techniques) and tabbed pages on the right. Stats get bars and blurbs. Equipment gets
  icon tiles. The journal has drawn checkboxes and key items with descriptions. The Menu is a
  grid of dish tiles with a milestone bar. Input is unchanged.
- **Item icons** (`scripts/ui/item_icons.gd`, `ItemIcons.draw(ci, id, rect, empty)`): every gear
  piece, key item, the senzu, dishes and empty slots, on a tile in the stat's colour.
- **HUD** (`hud.gd`): a portrait medallion (void eyes in Shadow forms), framed meters with a
  damage trail, a level gem, and a framed ki-sense panel.
- **Title** (`title.gd`): a painted void sky and mountain ridge with the line of sunlight rising
  from the horizon. Oto stands in a 3D viewport, lit gold from the lit side and violet from the
  dark. The logo and a framed menu sit on the left, developer rooms in dim type, with a note
  under the selected entry.

## The townswomen (`scripts/characters/npc_women.gd`, `NpcWomen`)

- `DESIGNS`: 31 women, each with a name, a role (cook, engineer, courier, police, florist,
  fighter, nomad...), skin, a body build (the plain base, `curvy`, `slim` or `full_figure`,
  never Oto's), a face look (FaceParts eyes, brows, mouth, nose, chin, iris, brow and lip
  colours), hair and an outfit.
- `COLORWAYS`: each design three more times. Clothes turn round the colour wheel (neutrals keep
  their hue; saturation and brightness are capped so nothing goes neon). Hair and eyes come from
  shared tables, and each woman gets a new name from `NAMES`.
- Presets are `woman_<id>` and `woman_<id>_2..4`; `Outfits.preset_spec()` and `Face.look()`
  find them. Put one in a level like any outfit (`"outfit": "woman_mei"`). Her speaker name is
  her `name`, so `"Mei|..."` lines show her portrait.
- **Cast clothing**: on the female base the old box-and-cone tops let the bust and belly through
  (Chi-Chi and Bulma still do). The women's presets set `"cast": true`, so `OutfitBuilder` casts
  tank, bodysuit, tunic, gi, jacket, vest, lab coat, armour, dress, pants, baggy, tights, shorts
  and skirt onto the real body with `Garment.tube` (`_cast_top` / `_cast_bottom`). dev_tests
  checks that no point is inside the body.
- Aprons are cloth now (a `ClothPanel` tied at the waist), for every preset.

## Checking it

```
python tools/run.py shot ui_preview --frames 120 --args="--ui dialogue --speaker Mei"   # also narration, toast, prompt, card
python tools/run.py shot ui_preview --resolution 1600x900 --args="--ui portraits --page 0"  # 24 portraits a page, pages 0-5
python tools/run.py shot gallery --resolution 1600x900 --args="--gallery women --page 0"    # six women in 3D a page, pages 0-20
python tools/run.py shot test_arena --frames 90 --args="--sim menu --menutab 1"             # a pause-menu tab
python tools/run.py shot title --frames 200
```

## Open

- Every woman on the female base but Oto now gets cast clothing by default
  (`Outfits.apply` sets `"cast"` for model `oto`); Chi-Chi, Bulma, the civilians and Mrs. Briefs
  included. The male base is several overlapping parts, which casting tears, so its box clothes
  are eased instead (landmarks `"ease_k": 1.14`). Its head and ears are flat skin now: their UVs
  were made for a texture that never came with the model.
- Most townswomen are not placed in levels yet; five work at Capsule Corp (Ayame, Lottie, Bryn, Hana, Jun).
- No sound for typing or menus yet.
