extends CanvasLayer
## Autoload. Dialogue box, fades, flashes, title cards, toasts and hints, drawn with UiKit.
##
## The dialogue box slides up with the speaker's portrait (Portrait: a drawn head that talks
## and blinks for anyone with a face look, an emblem for the rest) and a name plate in their
## colour. Text types out with short rests on punctuation; a gem bobs when the line is done.
## Narration (a line with no speaker) has no portrait and reads in italics.

## A line starts typing (on) or is fully shown (off): faces (FaceRig) move their mouths only while
## their speaker's line types.
signal talking(speaker: String, on: bool)

const CPS := 48.0          # characters per second
const REST := {".": 7.0, "!": 7.0, "?": 7.0, ",": 3.0, ";": 4.0, ":": 4.0}  # extra characters' worth of pause
const BOX_H := 0.22        # box height, share of the screen

var auto := false  # developer flag: auto-advance dialogue

var _fade: ColorRect
var _card: Control
var _card_text := ""
var _box: Control
var _portrait: Portrait
var _text: Label
var _speaker := ""
var _line_done := false
var _open := 0.0           # 0..1, the box's slide-in
var _toast: Control
var _toast_text := ""
var _hint: Label
var _prompt: Control
var _prompt_text := ""
var _toast_time := 0.0
var _t := 0.0

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	_hint = Label.new()
	_hint.add_theme_font_override("font", UiKit.body_font())
	_hint.add_theme_font_size_override("font_size", 17)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_hint.add_theme_constant_override("outline_size", 5)
	_hint.anchor_top = 0.95
	_hint.anchor_bottom = 1.0
	_hint.anchor_right = 1.0
	_hint.offset_left = 18
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	_prompt = _canvas(_draw_prompt)
	_toast = _canvas(_draw_toast)
	_toast.modulate.a = 0.0

	_box = _canvas(_draw_box)
	_box.visible = false
	_portrait = Portrait.new()
	_box.add_child(_portrait)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_override("font", UiKit.body_font())
	_text.add_theme_font_size_override("font_size", 26)
	_text.add_theme_color_override("font_color", UiKit.TEXT)
	_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_text.add_theme_constant_override("shadow_offset_x", 1)
	_text.add_theme_constant_override("shadow_offset_y", 2)
	_text.add_theme_constant_override("line_spacing", 4)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_text)

	_card = _canvas(_draw_card)
	_card.modulate.a = 0.0

	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	move_child(_fade, 0)
	move_child(_card, get_child_count() - 1)

## A full-screen control that draws itself with `fn`.
func _canvas(fn: Callable) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(fn.bind(c))
	add_child(c)
	return c

func _process(delta: float) -> void:
	_t += delta
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time * 2.0, 0.0, 1.0)
		_toast.queue_redraw()
	if _box.visible:
		_layout_box()
		_box.queue_redraw()
	if _prompt_text != "":
		_prompt.queue_redraw()

func hint(text: String) -> void:
	_hint.text = text

## The pause menu hides the hint line so it does not print over the menu's own help.
func show_hint(on: bool) -> void:
	_hint.visible = on
	_prompt.visible = on

func set_prompt(text: String) -> void:
	_prompt_text = text
	_prompt.queue_redraw()

func toast(text: String, time := 2.2) -> void:
	_toast_text = text
	_toast_time = time
	_toast.queue_redraw()

func _pressed() -> bool:
	return auto or Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("interact")

## Lines are "Speaker|text"; no bar means narration.
func say(lines: Array) -> void:
	var prev := GameState.input_locked
	GameState.input_locked = true
	set_prompt("")
	_box.visible = true
	_open = 0.0
	var tw := create_tween()
	tw.tween_property(self, "_open", 1.0, 0.0 if auto else 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for line in lines:
		var s: String = line
		var tx := s
		var sp := ""
		var k := s.find("|")
		if k >= 0:
			sp = s.substr(0, k)
			tx = s.substr(k + 1)
		_show_line(sp, tx)
		talking.emit(sp, true)
		_portrait.set_talking(true)
		var budget := 0.0
		while _text.visible_characters < tx.length():
			await get_tree().process_frame
			budget += get_process_delta_time() * CPS
			while budget >= 1.0 and _text.visible_characters < tx.length():
				var ch := tx[_text.visible_characters]
				_text.visible_characters += 1
				budget -= 1.0 + float(REST.get(ch, 0.0))
			_portrait.talking = budget >= -1.0  # the mouth rests on the pauses
			if _pressed():
				_text.visible_characters = tx.length()
		talking.emit(sp, false)
		_portrait.set_talking(false)
		_line_done = true
		var wait := 0.0
		await get_tree().process_frame
		while not _pressed():
			await get_tree().process_frame
			wait += get_process_delta_time()
			if auto and wait > 0.02:
				break
	_box.visible = false
	GameState.input_locked = prev

func _show_line(sp: String, tx: String) -> void:
	_speaker = sp
	_line_done = false
	_portrait.visible = sp != ""
	if sp != "":
		_portrait.set_speaker(sp)
	_text.add_theme_font_override("font", UiKit.body_font(sp == ""))
	_text.add_theme_color_override("font_color", UiKit.TEXT if sp != "" else Color(0.84, 0.8, 0.95))
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if sp != "" else HORIZONTAL_ALIGNMENT_CENTER
	_text.text = tx
	_text.visible_characters = 0
	_layout_box()

# --- layout and drawing ---------------------------------------------------------------

func _box_rect() -> Rect2:
	var vs := _box.get_viewport_rect().size
	var h := vs.y * BOX_H
	var w := minf(vs.x * 0.9, 1240.0)
	var slide := (1.0 - _open) * 30.0
	return Rect2(Vector2((vs.x - w) * 0.5, vs.y - h - vs.y * 0.035 + slide), Vector2(w, h))

func _layout_box() -> void:
	var r := _box_rect()
	_box.modulate.a = _open
	var ps := r.size.y + 24.0
	_portrait.position = Vector2(r.position.x + 18.0, r.end.y - ps - 12.0)
	_portrait.size = Vector2(ps, ps) * Vector2(0.86, 1.0)
	var left := r.position.x + (ps * 0.86 + 44.0 if _speaker != "" else 48.0)
	_text.position = Vector2(left, r.position.y + (34.0 if _speaker != "" else 30.0))
	_text.size = Vector2(r.end.x - left - 40.0, r.size.y - 44.0)

func _draw_box(c: Control) -> void:
	var r := _box_rect()
	var accent := UiKit.speaker_color(_speaker) if _speaker != "" else UiKit.VIOLET
	UiKit.frame(c, r, UiKit.GOLD, _speaker == "")
	if _speaker != "":
		# the portrait's own frame sits behind it, standing up out of the box
		var pr := Rect2(_portrait.position, _portrait.size).grow(5.0)
		c.draw_colored_polygon(UiKit.notched(pr, 10.0), UiKit.INK)
		c.draw_polyline(UiKit.closed(UiKit.notched(pr, 10.0)), UiKit.GOLD, 2.0, true)
		c.draw_polyline(UiKit.closed(UiKit.notched(pr.grow(-3.0), 8.0)), Color(accent.r, accent.g, accent.b, 0.5), 1.0, true)
		# the name plate: a tab on the box's top edge in the speaker's colour
		var font := UiKit.spaced(UiKit.display_font(true), 1)
		var fs := 24
		var nw := font.get_string_size(_speaker, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 44.0
		var nr := Rect2(Vector2(_text.position.x - 18.0, r.position.y - 20.0), Vector2(nw, 38.0))
		c.draw_colored_polygon(UiKit.notched(nr, 9.0), accent.darkened(0.7))
		c.draw_polyline(UiKit.closed(UiKit.notched(nr, 9.0)), accent, 2.0, true)
		UiKit.diamond(c, Vector2(nr.position.x + 12.0, nr.get_center().y), 3.5, accent)
		UiKit.text(c, font, Vector2(nr.position.x + 24.0, nr.position.y + 27.0), _speaker, fs, accent.lightened(0.25), HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	else:
		UiKit.rule(c, Vector2(r.position.x + r.size.x * 0.3, r.end.y - 18.0), Vector2(r.end.x - r.size.x * 0.3, r.end.y - 18.0), Color(UiKit.VIOLET.r, UiKit.VIOLET.g, UiKit.VIOLET.b, 0.6))
	if _line_done:
		var p := Vector2(r.end.x - 34.0, r.end.y - 24.0 + sin(_t * 6.0) * 3.0)
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(-9, -6), p + Vector2(9, -6), p + Vector2(0, 5)]), UiKit.GOLD)
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(-9, 1), p + Vector2(9, 1), p + Vector2(0, 12)]), Color(UiKit.GOLD.r, UiKit.GOLD.g, UiKit.GOLD.b, 0.4))

func _draw_prompt(c: Control) -> void:
	if _prompt_text == "":
		return
	var vs := c.get_viewport_rect().size
	var key := ""
	var label := _prompt_text
	var k := _prompt_text.find(": ")
	if k > 0 and k <= 6:
		key = _prompt_text.substr(0, k)
		label = _prompt_text.substr(k + 2)
	var font := UiKit.body_font()
	var fs := 21
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + (54.0 if key != "" else 0.0) + 44.0
	var r := Rect2(Vector2((vs.x - w) * 0.5, vs.y * 0.8), Vector2(w, 42.0))
	var glow := 0.5 + 0.5 * sin(_t * 3.0)
	c.draw_colored_polygon(UiKit.notched(r.grow(3.0), 12.0), Color(UiKit.GOLD.r, UiKit.GOLD.g, UiKit.GOLD.b, 0.12 * glow))
	UiKit.frame(c, r, UiKit.GOLD, false, 10.0)
	var x := r.position.x + 22.0
	if key != "":
		var kr := Rect2(Vector2(x, r.position.y + 8.0), Vector2(30.0, 26.0))
		c.draw_rect(kr, Color(UiKit.GOLD.r, UiKit.GOLD.g, UiKit.GOLD.b, 0.2))
		c.draw_rect(kr, UiKit.GOLD, false, 1.5)
		c.draw_string(font, Vector2(kr.position.x, kr.position.y + 20.0), key, HORIZONTAL_ALIGNMENT_CENTER, kr.size.x, 18, UiKit.GOLD_PALE)
		x += 44.0
	UiKit.text(c, font, Vector2(x, r.position.y + 29.0), label, fs, UiKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)

func _draw_toast(c: Control) -> void:
	if _toast_text == "" or _toast.modulate.a <= 0.0:
		return
	var vs := c.get_viewport_rect().size
	var font := UiKit.body_font()
	var fs := 22
	var lines := UiKit.wrap(font, _toast_text, minf(vs.x * 0.6, 760.0), fs)
	var w := 0.0
	for l in lines:
		w = maxf(w, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	w += 96.0
	var h := 26.0 + lines.size() * 30.0
	var drop := (1.0 - clampf(_toast.modulate.a * 3.0, 0.0, 1.0)) * -12.0
	var r := Rect2(Vector2((vs.x - w) * 0.5, vs.y * 0.09 + drop), Vector2(w, h))
	UiKit.frame(c, r, UiKit.GOLD, false, 10.0)
	UiKit.sigil(c, Vector2(r.position.x + 26.0, r.get_center().y), 22.0, UiKit.GOLD)
	for i in lines.size():
		UiKit.text(c, font, Vector2(r.position.x + 48.0, r.position.y + 34.0 + i * 30.0), lines[i], fs, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER, w - 72.0, 3)

func _draw_card(c: Control) -> void:
	if _card_text == "":
		return
	var vs := c.get_viewport_rect().size
	var font := UiKit.display_font(false)
	var fs := 34
	var lines: Array[String] = []
	for para in _card_text.split("\n"):
		lines.append_array(UiKit.wrap(font, para, vs.x * 0.7, fs))
	var h := lines.size() * 48.0
	var y := (vs.y - h) * 0.5
	UiKit.sigil(c, Vector2(vs.x * 0.5, y - 46.0), 34.0, UiKit.GOLD)
	UiKit.rule(c, Vector2(vs.x * 0.3, y - 14.0), Vector2(vs.x * 0.7, y - 14.0), UiKit.GOLD_DIM, false)
	for i in lines.size():
		UiKit.text(c, font, Vector2(0, y + 36.0 + i * 48.0), lines[i], fs, UiKit.GOLD_PALE, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 4)
	UiKit.rule(c, Vector2(vs.x * 0.3, y + h + 24.0), Vector2(vs.x * 0.7, y + h + 24.0), UiKit.GOLD_DIM)

# --- fades and cards ------------------------------------------------------------------

func fade_to(color: Color, time := 1.0) -> void:
	_fade.color = Color(color.r, color.g, color.b, _fade.color.a)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, time)
	await tw.finished

func fade_from(time := 1.0) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, time)
	await tw.finished

func flash(color: Color, time := 1.0) -> void:
	_fade.color = Color(color.r, color.g, color.b, 1.0)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, time)
	await tw.finished

func card(text: String, hold := 2.5) -> void:
	await fade_to(Color.BLACK, 0.8)
	_card_text = text
	_card.queue_redraw()
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 0.8)
	await tw.finished
	await get_tree().create_timer(hold).timeout
	tw = create_tween()
	tw.tween_property(_card, "modulate:a", 0.0, 0.8)
	await tw.finished
