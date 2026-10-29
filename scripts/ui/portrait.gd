class_name Portrait
extends Control
## The speaker's portrait in the dialogue box. A speaker with a face look (Oto, the women of
## npc_women.gd) is drawn as a head and shoulders: the real face layers from Face (the same
## art her 3D face uses) on a cel-shaded head, with her hair and clothes colours. While her
## line types the mouth runs through the visemes, and she blinks. Anyone else gets an emblem:
## a silhouette in their colour with their initial, and sound rings while they speak.

const VISEMES := ["ah", "oh", "ee", "wide", "closed"]
const INK := Color(0.05, 0.03, 0.06)

var speaker := ""
var look_id := ""
var accent := Color.WHITE
var talking := false
var variant := ""   # "void": Shadow-form eyes
var expression := "neutral"

var _skin := Color(0.9, 0.75, 0.6)
var _hair := Color(0.1, 0.08, 0.07)
var _hair_style := "short"
var _cloth := Color(0.3, 0.3, 0.4)
var _mouth := "closed"
var _eyes := "open"
var _talk_in := 0.0
var _blink_in := 2.0
var _blink_t := -1.0
var _t := 0.0

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_speaker(who: String) -> void:
	if who == speaker:
		return
	speaker = who
	accent = UiKit.speaker_color(who)
	look_id = UiKit.speaker_look(who)
	if look_id == "oto":
		_skin = FaceParts.SKINS["dusk"].lightened(0.12)
		_hair = Color(0.8, 0.8, 0.83)
		_hair_style = "oto"
		_cloth = Color(0.09, 0.27, 0.16)
	elif look_id != "":
		var sp := NpcWomen.spec(look_id)
		_skin = NpcWomen._c(sp.get("skin", [0.9, 0.75, 0.6]))
		var hs: Dictionary = sp.get("hair", {})
		_hair = NpcWomen._c(hs.get("color", [0.1, 0.08, 0.07]))
		_hair_style = hs.get("style", "short")
		_cloth = NpcWomen._c((sp.get("top", {}) as Dictionary).get("color", [0.3, 0.3, 0.4]))
	_mouth = "closed"
	_eyes = "open"
	if look_id != "":
		for st: String in VISEMES + ["closed"]:
			Face.texture(look_id, "mouth", st, variant, _skin)
		for st: String in ["open", "half", "closed"]:
			Face.texture(look_id, "eyes", st, variant, _skin)
	queue_redraw()

func set_talking(on: bool) -> void:
	talking = on
	_talk_in = 0.0
	if not on:
		_mouth = Face.EXPRESSIONS.get(expression, {}).get("mouth", "closed")

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	if talking:
		_talk_in -= delta
		if _talk_in <= 0.0:
			var pick := _mouth
			while pick == _mouth:
				pick = VISEMES[randi() % VISEMES.size()]
			_mouth = pick
			_talk_in = randf_range(0.08, 0.13)
	_blink_in -= delta
	if _blink_in <= 0.0 and _blink_t < 0.0:
		_blink_t = 0.0
		_blink_in = randf_range(2.5, 5.5)
	if _blink_t >= 0.0:
		_blink_t += delta
		_eyes = "half" if _blink_t < 0.05 or (_blink_t > 0.13 and _blink_t < 0.18) else ("closed" if _blink_t < 0.13 else "open")
		if _blink_t >= 0.18:
			_blink_t = -1.0
	queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var bg := accent.darkened(0.72)
	UiKit.gradient_rect(self, r, bg.lightened(0.08), Color(0.02, 0.015, 0.04))
	# a soft halo behind the head, in the speaker's colour
	for k in 5:
		draw_circle(Vector2(size.x * 0.5, size.y * 0.42), size.x * (0.48 - k * 0.07), Color(accent.r, accent.g, accent.b, 0.05))
	if look_id != "":
		_draw_face()
	else:
		_draw_emblem()

# --- a drawn head ---------------------------------------------------------------------

## Face space (mm, +Y up, origin at the eye line) to this control's pixels.
func _k() -> float:
	return size.y / 400.0

func _p(mm: Vector2) -> Vector2:
	var bob := sin(_t * 9.0) * 1.2 if talking else sin(_t * 1.4) * 0.6
	return Vector2(size.x * 0.5, size.y * 0.43 + bob) + Vector2(mm.x, -mm.y) * _k()

func _poly(pts_mm: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts_mm:
		out.append(_p(q))
	return out

## An egg: wide at the brow, narrowing to the chin.
func _head_mm() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 48:
		var a := TAU * i / 48.0
		var x := cos(a) * 104.0
		var y := sin(a) * 132.0
		if y < 0.0:
			x *= 1.0 - 0.32 * pow(-y / 132.0, 1.6)
		pts.append(Vector2(x, y))
	return pts

func _ellipse_mm(c: Vector2, rx: float, ry: float, n := 32) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func _fill(pts_mm: PackedVector2Array, c: Color, outline := 2.0) -> void:
	var pts := _poly(pts_mm)
	draw_colored_polygon(pts, c)
	if outline > 0.0:
		draw_polyline(UiKit.closed(pts), INK, outline, true)

func _draw_face() -> void:
	var shade := _skin.darkened(0.22)
	var hair_dark := _hair.darkened(0.3)
	# shoulders and neck
	var cloth := PackedVector2Array([Vector2(-190, -330), Vector2(-185, -205), Vector2(-120, -172), Vector2(-40, -160),
		Vector2(40, -160), Vector2(120, -172), Vector2(185, -205), Vector2(190, -330)])
	_back_hair(hair_dark)
	_fill(PackedVector2Array([Vector2(-36, -100), Vector2(36, -100), Vector2(40, -175), Vector2(-40, -175)]), shade)
	_fill(cloth, _cloth)
	_fill(PackedVector2Array([Vector2(-40, -160), Vector2(0, -200), Vector2(40, -160)]), _skin.darkened(0.1), 1.5)
	# ears, head, a jaw shadow
	for side: float in [1.0, -1.0]:
		_fill(_ellipse_mm(Vector2(side * 102.0, -12.0), 16.0, 30.0, 20), _skin)
	_fill(_head_mm(), _skin, 2.5)
	draw_colored_polygon(_poly(PackedVector2Array([Vector2(-70, -95), Vector2(-30, -128), Vector2(30, -128), Vector2(70, -95), Vector2(40, -118), Vector2(-40, -118)])), Color(shade.r, shade.g, shade.b, 0.6))
	# cheek warmth
	for side: float in [1.0, -1.0]:
		draw_circle(_p(Vector2(side * 58.0, -48.0)), 13.0 * _k(), Color(0.95, 0.4, 0.45, 0.07))
	# the face layers, exactly as on her 3D face
	for slot: String in ["nose", "mouth", "eyes", "brows"]:
		var st: String
		match slot:
			"eyes": st = _eyes
			"mouth": st = _mouth
			"nose": st = "marks"
			_: st = Face.EXPRESSIONS.get(expression, {}).get("brows", "calm")
		var tex := Face.texture(look_id, slot, st, variant, _skin)
		if tex == null:
			continue
		var lr := FaceCanvas.px_rect(Face.REGIONS[slot])
		var mm_pos := (Vector2(lr.position) - Vector2(FaceCanvas.TEX_W * 0.5, FaceCanvas.EYE_ROW)) / FaceCanvas.PPMM
		var top_left := _p(Vector2(mm_pos.x, -mm_pos.y))
		draw_texture_rect(tex, Rect2(top_left, Vector2(lr.size) / FaceCanvas.PPMM * _k()), false)
	_front_hair(hair_dark)

## A lock of hair falling past the cheek on one side: full at the temple, tapering to a point.
func _lock(side: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for q: Array in [[98, 50], [124, 0], [134, -70], [128, -150], [114, -205], [108, -150], [100, -80], [92, -20], [90, 30]]:
		pts.append(Vector2(side * float(q[0]), float(q[1])))
	return pts

func _back_hair(dark: Color) -> void:
	match _hair_style:
		"long", "oto":
			_fill(PackedVector2Array([Vector2(-120, 70), Vector2(-138, -120), Vector2(-150, -330), Vector2(150, -330), Vector2(138, -120), Vector2(120, 70)]), dark)
		"bob":
			_fill(PackedVector2Array([Vector2(-122, 80), Vector2(-132, -60), Vector2(-118, -110), Vector2(118, -110), Vector2(132, -60), Vector2(122, 80)]), dark)
		"bun":
			_fill(_ellipse_mm(Vector2(0, 150), 52.0, 46.0), _hair)
		"ponytail":
			_fill(PackedVector2Array([Vector2(90, 90), Vector2(150, 40), Vector2(168, -80), Vector2(140, -200), Vector2(122, -90), Vector2(108, 20)]), dark)
		"afro":
			_fill(_ellipse_mm(Vector2(0, 50), 178.0, 150.0, 40), _hair)
		"very_long_spiky":
			_fill(PackedVector2Array([Vector2(-120, 80), Vector2(-190, -60), Vector2(-150, -120), Vector2(-200, -250), Vector2(-120, -200), Vector2(-90, -330),
				Vector2(90, -330), Vector2(120, -200), Vector2(200, -250), Vector2(150, -120), Vector2(190, -60), Vector2(120, 80)]), dark)

func _front_hair(dark: Color) -> void:
	var cap := PackedVector2Array()
	match _hair_style:
		"bald", "keep":
			return
		"turban":
			_fill(PackedVector2Array([Vector2(-118, 30), Vector2(-125, 120), Vector2(-60, 185), Vector2(60, 185), Vector2(125, 120), Vector2(118, 30), Vector2(0, 58)]), _hair)
			draw_polyline(_poly(PackedVector2Array([Vector2(-110, 70), Vector2(0, 100), Vector2(110, 70)])), _hair.darkened(0.25), 3.0, true)
			return
		"saiyan_spiky", "flame", "very_long_spiky":
			var tall := 1.8 if _hair_style == "flame" else 1.0
			cap.append(Vector2(-112, -10))
			var n := 7
			for i in n + 1:
				var u := float(i) / n
				var a := lerpf(PI * 0.95, PI * 0.05, u)
				var reach := (175.0 + 25.0 * sin(i * 2.1)) * (tall if absf(u - 0.5) < 0.3 else 1.0)
				cap.append(Vector2(cos(a) * 108.0, sin(a) * 120.0 + 10.0))
				if i < n:
					var am := lerpf(PI * 0.95, PI * 0.05, u + 0.5 / n)
					cap.append(Vector2(cos(am) * reach * 0.85, sin(am) * reach + 10.0))
			cap.append(Vector2(112, -10))
			for x: float in [70.0, 30.0, -10.0, -50.0, -90.0]:
				cap.append(Vector2(x + 20.0, 40.0))
				cap.append(Vector2(x, 78.0 + (x * 0.1)))
		_:
			# a cap over the crown with a fringe: side-swept for Oto, a straight fringe for a bob,
			# a centre part for the rest
			var fringe_y := 62.0
			cap.append(Vector2(-116, -30 if _hair_style in ["long", "oto", "bob"] else 10))
			for i in 25:
				var a := lerpf(PI * 1.02, -PI * 0.02, i / 24.0)
				cap.append(Vector2(cos(a) * 118.0, sin(a) * 140.0 + 4.0))
			cap.append(Vector2(116, -30 if _hair_style in ["long", "oto", "bob"] else 10))
			match _hair_style:
				"oto":
					for q: Array in [[100, 40], [70, 70], [40, 58], [0, 78], [-40, 60], [-62, 30], [-84, 0], [-96, -40], [-110, -20]]:
						cap.append(Vector2(q[0], q[1]))
				"bob":
					for x: float in [96.0, 64.0, 32.0, 0.0, -32.0, -64.0, -96.0]:
						cap.append(Vector2(x + 12.0, 54.0))
						cap.append(Vector2(x, 46.0))
				_:
					cap.append(Vector2(92, 40))
					cap.append(Vector2(45, fringe_y + 14.0))
					cap.append(Vector2(4, fringe_y + 40.0))
					cap.append(Vector2(-4, fringe_y + 40.0))
					cap.append(Vector2(-45, fringe_y + 14.0))
					cap.append(Vector2(-92, 40))
	_fill(cap, _hair, 2.5)
	# a band of light across the crown
	var shine := PackedVector2Array()
	for i in 9:
		var a := lerpf(PI * 0.72, PI * 0.38, i / 8.0)
		shine.append(Vector2(cos(a) * 98.0, sin(a) * 118.0))
	draw_polyline(_poly(shine), Color(1, 1, 1, 0.16), 4.0 * _k(), true)
	if _hair_style == "long" or _hair_style == "oto":
		var side := _lock(-1.0)
		_fill(side, _hair, 2.0)
		var side_r := _lock(1.0)
		_fill(side_r, _hair, 2.0)
	if _hair_style == "bun":
		draw_line(_p(Vector2(-60, 112)), _p(Vector2(60, 112)), dark, 3.0)

# --- an emblem ------------------------------------------------------------------------

func _draw_emblem() -> void:
	var c := Vector2(size.x * 0.5, size.y * 0.5)
	var dark := accent.darkened(0.55)
	var bob := sin(_t * 9.0) * 1.5 if talking else 0.0
	# the silhouette: a head and shoulders in the speaker's colour
	var hc := c + Vector2(0, -size.y * 0.1 + bob)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-size.x * 0.42, size.y * 0.55), c + Vector2(-size.x * 0.38, size.y * 0.26),
		c + Vector2(-size.x * 0.16, size.y * 0.14), c + Vector2(size.x * 0.16, size.y * 0.14), c + Vector2(size.x * 0.38, size.y * 0.26),
		c + Vector2(size.x * 0.42, size.y * 0.55)]), dark)
	draw_circle(hc, size.x * 0.22, dark)
	draw_arc(hc, size.x * 0.22, 0.0, TAU, 40, accent, 2.0, true)
	var font := UiKit.display_font(true)
	var initial := speaker.substr(0, 1).to_upper() if speaker != "" else "?"
	var fs := int(size.y * 0.26)
	UiKit.text(self, font, Vector2(0, hc.y + fs * 0.36), initial, fs, accent.lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER, size.x, 4)
	if talking:
		for k in 3:
			var ph := fmod(_t * 1.6 + k / 3.0, 1.0)
			var rad := size.x * (0.26 + ph * 0.24)
			draw_arc(hc, rad, -0.7, 0.7, 16, Color(accent.r, accent.g, accent.b, 0.5 * (1.0 - ph)), 2.0, true)
			draw_arc(hc, rad, PI - 0.7, PI + 0.7, 16, Color(accent.r, accent.g, accent.b, 0.5 * (1.0 - ph)), 2.0, true)
