class_name UiKit
extends RefCounted
## The game's look for every screen: colours, fonts and the drawing helpers the dialogue box,
## pause menu, HUD and title share. Everything is drawn in code on a CanvasItem.
##
## The style is the Shadow Saiyans' court: void-violet lacquer panels edged in gold, Oto's jade
## as the second accent, and the Wall sigil (a frame split by one upright line, see sigil.gd)
## as the ornament. Gold is trim, never fire: the Shadow forms stay void and hush.

const INK := Color(0.025, 0.018, 0.045)
const PANEL := Color(0.07, 0.05, 0.11, 0.95)
const PANEL_LO := Color(0.035, 0.025, 0.06, 0.97)
const GOLD := Color(0.93, 0.74, 0.34)
const GOLD_DIM := Color(0.55, 0.42, 0.2)
const GOLD_PALE := Color(1.0, 0.92, 0.7)
const JADE := Color(0.32, 0.72, 0.5)
const VIOLET := Color(0.64, 0.52, 0.92)
const TEXT := Color(0.96, 0.94, 0.99)
const MUTED := Color(0.62, 0.58, 0.72)
const FAINT := Color(0.4, 0.37, 0.5)
const HP := Color(0.86, 0.22, 0.3)
const KI := Color(0.56, 0.38, 0.95)
const STAMINA := Color(0.32, 0.8, 0.46)
const EXP := Color(0.95, 0.8, 0.32)

## Who speaks in what colour, and which face look draws their portrait (Face.LOOKS or
## NpcWomen). Anyone else gets a colour from their name and an emblem portrait.
const SPEAKERS := {
	"Oto": {"color": Color(0.62, 0.86, 0.68), "look": "oto"},
	"Goku": {"color": Color(1.0, 0.66, 0.3)},
	"Gohan": {"color": Color(0.82, 0.6, 1.0)},
	"Chi-Chi": {"color": Color(1.0, 0.55, 0.6)},
	"Bulma": {"color": Color(0.45, 0.85, 0.95)},
	"Krillin": {"color": Color(1.0, 0.74, 0.4)},
	"Master Roshi": {"color": Color(1.0, 0.82, 0.55)},
	"Piccolo": {"color": Color(0.6, 0.92, 0.5)},
	"Vegeta": {"color": Color(0.55, 0.65, 1.0)},
	"Yajirobe": {"color": Color(0.9, 0.78, 0.5)},
	"Hercule": {"color": Color(1.0, 0.85, 0.35)},
}

static var _fonts := {}

## The game's fonts ship in assets/fonts (SIL OFL 1.1, see the OFL-*.txt beside them), so the
## web build looks the same as the desktop: EB Garamond for names and titles, Nunito for text.
const DISPLAY := "res://assets/fonts/EBGaramond-Variable.ttf"
const DISPLAY_ITALIC := "res://assets/fonts/EBGaramond-Italic-Variable.ttf"
const BODY := "res://assets/fonts/Nunito-Variable.ttf"
const BODY_ITALIC := "res://assets/fonts/Nunito-Italic-Variable.ttf"

## A shipped variable font at a weight (100-900), cached.
static func _font(path: String, weight: int) -> Font:
	var key := "%s|%d" % [path, weight]
	if not _fonts.has(key):
		var base := load(path) as FontFile
		if base == null:
			_fonts[key] = ThemeDB.fallback_font
		else:
			var v := FontVariation.new()
			v.base_font = base
			v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
			_fonts[key] = v
	return _fonts[key]

## The display face for titles and names.
static func display_font(bold := true) -> Font:
	return _font(DISPLAY, 700 if bold else 500)

## The body face for dialogue and menus.
static func body_font(italic := false) -> Font:
	return _font(BODY_ITALIC if italic else BODY, 500)

## A font with extra space between letters, for small capitals and the logo.
static func spaced(base: Font, glyph: int) -> Font:
	var key := "%s|%d" % [base.get_instance_id(), glyph]
	if not _fonts.has(key):
		var v := FontVariation.new()
		v.base_font = base
		v.set_spacing(TextServer.SPACING_GLYPH, glyph)
		_fonts[key] = v
	return _fonts[key]

static func speaker_color(who: String) -> Color:
	if SPEAKERS.has(who):
		return SPEAKERS[who]["color"]
	var look := NpcWomen.look_for_speaker(who)
	if look != "":
		return NpcWomen.speaker_color(look)
	var h := float(abs(who.hash()) % 1000) / 1000.0
	return Color.from_hsv(h, 0.45, 1.0)

static func speaker_look(who: String) -> String:
	if SPEAKERS.has(who):
		return SPEAKERS[who].get("look", "")
	return NpcWomen.look_for_speaker(who)

# --- text -------------------------------------------------------------------------------

## Text with a soft dark outline, readable on any ground.
static func text(ci: CanvasItem, font: Font, pos: Vector2, s: String, font_size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := 5) -> void:
	if outline > 0:
		ci.draw_string_outline(font, pos, s, align, width, font_size, outline, Color(0, 0, 0, 0.75 * color.a))
	ci.draw_string(font, pos, s, align, width, font_size, color)

## Words wrapped to `width` pixels.
static func wrap(font: Font, s: String, width: float, font_size: int) -> Array[String]:
	var lines: Array[String] = []
	var line := ""
	for word in s.split(" "):
		var attempt := word if line == "" else line + " " + word
		if line != "" and font.get_string_size(attempt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
			lines.append(line)
			line = word
		else:
			line = attempt
	if line != "":
		lines.append(line)
	return lines

# --- shapes -----------------------------------------------------------------------------

## A rectangle filled top to bottom from `top` to `bottom`.
static func gradient_rect(ci: CanvasItem, r: Rect2, top: Color, bottom: Color) -> void:
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))

## A rectangle with its four corners cut at 45 degrees (the panel shape).
static func notched(r: Rect2, cut: float) -> PackedVector2Array:
	var a := r.position
	var b := r.end
	return PackedVector2Array([
		Vector2(a.x + cut, a.y), Vector2(b.x - cut, a.y), Vector2(b.x, a.y + cut), Vector2(b.x, b.y - cut),
		Vector2(b.x - cut, b.y), Vector2(a.x + cut, b.y), Vector2(a.x, b.y - cut), Vector2(a.x, a.y + cut)])

static func closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out

static func diamond(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), color)

## The Wall: a frame split by one upright line. `h` is its height; it is half as wide.
static func sigil(ci: CanvasItem, c: Vector2, h: float, color: Color, stroke := 0.0) -> void:
	var w := h * 0.5
	var s := stroke if stroke > 0.0 else maxf(h * 0.08, 1.5)
	var r := Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
	ci.draw_rect(Rect2(r.position, Vector2(w, s)), color)
	ci.draw_rect(Rect2(Vector2(r.position.x, r.end.y - s), Vector2(w, s)), color)
	ci.draw_rect(Rect2(r.position, Vector2(s, h)), color)
	ci.draw_rect(Rect2(Vector2(r.end.x - s, r.position.y), Vector2(s, h)), color)
	ci.draw_rect(Rect2(Vector2(c.x - s * 0.65, r.position.y), Vector2(s * 1.3, h)), color)

## The standard panel: lacquer fill, a gold edge and an inner hairline, cut corners with
## small diamonds. `accent` tints the edge; `sigil_top` puts the Wall on the top edge.
static func frame(ci: CanvasItem, r: Rect2, accent := GOLD, sigil_top := false, cut := 12.0) -> void:
	var outer := notched(r, cut)
	var shadow := notched(Rect2(r.position + Vector2(0, 6), r.size), cut)
	ci.draw_colored_polygon(shadow, Color(0, 0, 0, 0.35))
	ci.draw_polygon(outer, PackedColorArray([PANEL, PANEL, PANEL_LO, PANEL_LO, PANEL_LO, PANEL_LO, PANEL, PANEL]))
	# a faint sheen across the top third
	var sheen := Rect2(r.position + Vector2(cut, 2), Vector2(r.size.x - cut * 2, r.size.y * 0.32))
	gradient_rect(ci, sheen, Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.0))
	ci.draw_polyline(closed(outer), accent, 2.0, true)
	var inner := notched(r.grow(-6), maxf(cut - 4.0, 2.0))
	ci.draw_polyline(closed(inner), Color(accent.r, accent.g, accent.b, 0.28), 1.0, true)
	for p: Vector2 in [Vector2(r.position.x + cut * 0.5, r.position.y + cut * 0.5), Vector2(r.end.x - cut * 0.5, r.position.y + cut * 0.5),
			Vector2(r.end.x - cut * 0.5, r.end.y - cut * 0.5), Vector2(r.position.x + cut * 0.5, r.end.y - cut * 0.5)]:
		diamond(ci, p, 3.0, accent)
	if sigil_top:
		var c := Vector2(r.get_center().x, r.position.y)
		diamond(ci, c, 13.0, INK)
		ci.draw_polyline(closed(PackedVector2Array([c + Vector2(0, -13), c + Vector2(13, 0), c + Vector2(0, 13), c + Vector2(-13, 0)])), accent, 1.5, true)
		sigil(ci, c, 13.0, accent, 1.5)

## A horizontal rule that fades out at both ends, with a diamond in the middle.
static func rule(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, gem := true) -> void:
	var mid := (a + b) * 0.5
	var clear := Color(color.r, color.g, color.b, 0.0)
	ci.draw_polygon(PackedVector2Array([a, mid, mid + Vector2(0, 1.5), a + Vector2(0, 1.5)]), PackedColorArray([clear, color, color, clear]))
	ci.draw_polygon(PackedVector2Array([mid, b, b + Vector2(0, 1.5), mid + Vector2(0, 1.5)]), PackedColorArray([color, clear, clear, color]))
	if gem:
		diamond(ci, mid + Vector2(0, 0.75), 4.0, color)

## A meter: a dark trough, a fill lit from above, a gloss line, quarter ticks and a gold
## cap. `ghost` is a trailing amount drawn behind the fill (damage just taken).
static func bar(ci: CanvasItem, r: Rect2, frac: float, color: Color, ghost := -1.0) -> void:
	frac = clampf(frac, 0.0, 1.0)
	var trough := r.grow(2.0)
	ci.draw_rect(trough, Color(0, 0, 0, 0.85))
	ci.draw_rect(r, Color(color.r * 0.16, color.g * 0.16, color.b * 0.2, 1.0))
	if ghost > frac:
		ci.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(ghost, 0.0, 1.0), r.size.y)), Color(1, 1, 1, 0.35))
	if frac > 0.0:
		var f := Rect2(r.position, Vector2(r.size.x * frac, r.size.y))
		gradient_rect(ci, f, color.lightened(0.35), color.darkened(0.25))
		ci.draw_rect(Rect2(f.position + Vector2(0, 1), Vector2(f.size.x, maxf(r.size.y * 0.18, 1.0))), Color(1, 1, 1, 0.35))
	for q in [0.25, 0.5, 0.75]:
		var x: float = r.position.x + r.size.x * q
		ci.draw_line(Vector2(x, r.position.y), Vector2(x, r.position.y + r.size.y * 0.4), Color(0, 0, 0, 0.45), 1.0)
	ci.draw_rect(trough, GOLD_DIM, false, 1.0)
	diamond(ci, Vector2(trough.end.x + 1.0, trough.get_center().y), minf(trough.size.y * 0.5 + 1.0, 7.0), GOLD)

## A selected row: a soft bar that glows toward its left edge, with a pointer gem.
static func highlight(ci: CanvasItem, r: Rect2, accent := GOLD, t := 0.0) -> void:
	var pulse := 0.75 + 0.25 * sin(t * 4.0)
	var c := Color(accent.r, accent.g, accent.b, 0.26 * pulse)
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([c, Color(c.r, c.g, c.b, 0.0), Color(c.r, c.g, c.b, 0.0), c]))
	ci.draw_line(r.position, Vector2(r.position.x, r.end.y), accent, 2.0)
	diamond(ci, Vector2(r.position.x - 10.0 + sin(t * 5.0) * 1.5, r.get_center().y), 4.5, accent)

## A key hint chip: "[Z] Confirm".
static func key_chip(ci: CanvasItem, pos: Vector2, key: String, label: String, font_size := 16) -> float:
	var font := body_font()
	var kw := maxf(font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 12.0, 24.0)
	var r := Rect2(pos + Vector2(0, -font_size - 1), Vector2(kw, font_size + 8))
	ci.draw_rect(r, Color(1, 1, 1, 0.08))
	ci.draw_rect(r, GOLD_DIM, false, 1.0)
	ci.draw_string(font, Vector2(r.position.x, pos.y + 1), key, HORIZONTAL_ALIGNMENT_CENTER, kw, font_size, GOLD_PALE)
	var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	text(ci, font, pos + Vector2(kw + 6.0, 1), label, font_size, MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
	return kw + 6.0 + lw + 22.0

## A row of key chips; `items` is [[key, label], ...].
static func key_row(ci: CanvasItem, pos: Vector2, items: Array, font_size := 16) -> void:
	var x := pos.x
	for it: Array in items:
		x += key_chip(ci, Vector2(x, pos.y), it[0], it[1], font_size)

# --- the logo ---------------------------------------------------------------------------

## LEGACY OF / OTO with the line of sunlight through the T: the line that split the Shadow
## Saiyans' world, gold on the lit side of the word and violet on the dark. `width` is the
## width of OTO; `t` animates the light; `alpha` fades it in.
static func logo(ci: CanvasItem, center: Vector2, width: float, t := 0.0, alpha := 1.0) -> void:
	var big := int(width * 0.42)
	var font := spaced(display_font(true), int(width * 0.03))
	var small := spaced(display_font(true), int(width * 0.025))
	var sz := font.get_string_size("OTO", HORIZONTAL_ALIGNMENT_LEFT, -1, big)
	var base := center + Vector2(-sz.x * 0.5, big * 0.36)
	var a := clampf(alpha, 0.0, 1.0)
	# the line of sunlight, behind the word, through the T
	var tx := base.x + font.get_string_size("O", HORIZONTAL_ALIGNMENT_LEFT, -1, big).x + font.get_string_size("T", HORIZONTAL_ALIGNMENT_LEFT, -1, big).x * 0.47
	var top := center.y - big * 1.05
	var bottom := center.y + big * 0.95
	var shimmer := 0.85 + 0.15 * sin(t * 1.7)
	for k in 6:
		var w := 2.0 + k * k * 2.2
		var c := Color(1.0, 0.9, 0.62, 0.09 * a * shimmer / (1.0 + k * 0.4))
		ci.draw_rect(Rect2(tx - w * 0.5, top, w, bottom - top), c)
	ci.draw_polygon(PackedVector2Array([Vector2(tx - 1.2, top), Vector2(tx + 1.2, top), Vector2(tx + 1.2, bottom), Vector2(tx - 1.2, bottom)]),
		PackedColorArray([Color(1, 0.95, 0.8, 0), Color(1, 0.95, 0.8, 0), Color(1, 0.95, 0.8, 0.9 * a), Color(1, 0.95, 0.8, 0.9 * a)]))
	# a mote of light slides down the line
	var my := lerpf(top, bottom, fmod(t * 0.18, 1.0))
	ci.draw_circle(Vector2(tx, my), 3.0, Color(1, 0.97, 0.88, 0.8 * a))
	ci.draw_circle(Vector2(tx, my), 9.0, Color(1, 0.9, 0.6, 0.18 * a))
	# OTO, letter by letter: a deep shadow, a gold outline, then the lit side gold, the T the
	# line's own pale light, the dark side violet
	var letters := [["O", Color(1.0, 0.84, 0.46)], ["T", Color(1.0, 0.96, 0.86)], ["O", Color(0.52, 0.42, 0.8)]]
	var xs: Array[float] = []
	var x := base.x
	for l: Array in letters:
		xs.append(x)
		x += font.get_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, big).x
	for i in 3:
		var at := Vector2(xs[i], base.y)
		ci.draw_string_outline(font, at + Vector2(0, 6), letters[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, big, int(big * 0.12), Color(0, 0, 0, 0.6 * a))
	for i in 3:
		ci.draw_string_outline(font, Vector2(xs[i], base.y), letters[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, big, int(big * 0.07), Color(GOLD.r, GOLD.g, GOLD.b, a))
	for i in 3:
		ci.draw_string_outline(font, Vector2(xs[i], base.y), letters[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, big, int(big * 0.035), Color(0.08, 0.05, 0.12, a))
	for i in 3:
		var c: Color = letters[i][1]
		ci.draw_string(font, Vector2(xs[i], base.y), letters[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, big, Color(c.r, c.g, c.b, a))
	# LEGACY OF above, between two rules
	var ls := int(width * 0.075)
	var lw := small.get_string_size("LEGACY OF", HORIZONTAL_ALIGNMENT_LEFT, -1, ls).x
	var ly := center.y - big * 0.62
	text(ci, small, Vector2(center.x - lw * 0.5, ly), "LEGACY OF", ls, Color(GOLD_PALE.r, GOLD_PALE.g, GOLD_PALE.b, a), HORIZONTAL_ALIGNMENT_LEFT, -1, 6)
	var gap := lw * 0.5 + 18.0
	rule(ci, Vector2(center.x - width * 0.55, ly - ls * 0.35), Vector2(center.x - gap, ly - ls * 0.35), Color(GOLD.r, GOLD.g, GOLD.b, a), false)
	rule(ci, Vector2(center.x + gap, ly - ls * 0.35), Vector2(center.x + width * 0.55, ly - ls * 0.35), Color(GOLD.r, GOLD.g, GOLD.b, a), false)
	diamond(ci, Vector2(center.x - gap + 6.0, ly - ls * 0.35), 3.5, Color(GOLD.r, GOLD.g, GOLD.b, a))
	diamond(ci, Vector2(center.x + gap - 6.0, ly - ls * 0.35), 3.5, Color(GOLD.r, GOLD.g, GOLD.b, a))
