extends CanvasLayer
## Autoload. Dialogue box, fades, flashes, title cards, toasts and hints.

var auto := false  # developer flag: auto-advance dialogue

var _fade: ColorRect
var _card: Label
var _panel: Panel
var _speaker: Label
var _text: Label
var _toast: Label
var _hint: Label
var _prompt: Label
var _toast_time := 0.0

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	_hint = _label(20, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_LEFT)
	_hint.anchor_top = 0.93
	_hint.anchor_bottom = 1.0
	_hint.anchor_right = 1.0
	_hint.offset_left = 16

	_prompt = _label(24, Color(1, 0.9, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
	_prompt.anchor_top = 0.82
	_prompt.anchor_bottom = 0.9
	_prompt.anchor_right = 1.0

	_toast = _label(26, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER)
	_toast.anchor_top = 0.1
	_toast.anchor_bottom = 0.18
	_toast.anchor_right = 1.0
	_toast.modulate.a = 0.0

	_panel = Panel.new()
	_panel.anchor_left = 0.05
	_panel.anchor_right = 0.95
	_panel.anchor_top = 0.72
	_panel.anchor_bottom = 0.96
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.03, 0.07, 0.92)
	sb.border_color = Color(0.6, 0.5, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.visible = false
	add_child(_panel)
	_speaker = Label.new()
	_speaker.position = Vector2(24, 12)
	_speaker.add_theme_font_size_override("font_size", 24)
	_speaker.add_theme_color_override("font_color", Color(1, 0.8, 0.4))
	_panel.add_child(_speaker)
	_text = Label.new()
	_text.position = Vector2(24, 50)
	_text.anchor_right = 1.0
	_text.offset_right = -24
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 24)
	_panel.add_child(_text)

	_card = _label(34, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER)
	_card.anchor_top = 0.35
	_card.anchor_bottom = 0.65
	_card.anchor_right = 1.0
	_card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card.modulate.a = 0.0

	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	move_child(_fade, 0)
	move_child(_card, get_child_count() - 1)

func _label(font_size: int, color: Color, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func _process(delta: float) -> void:
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time * 2.0, 0.0, 1.0)

func hint(text: String) -> void:
	_hint.text = text

## The pause menu hides the hint line so it does not print over the menu's own help.
func show_hint(on: bool) -> void:
	_hint.visible = on
	_prompt.visible = on

func set_prompt(text: String) -> void:
	_prompt.text = text

func toast(text: String, time := 2.2) -> void:
	_toast.text = text
	_toast_time = time

func _pressed() -> bool:
	return auto or Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("interact")

## Lines are "Speaker|text"; no bar means narration.
func say(lines: Array) -> void:
	var prev := GameState.input_locked
	GameState.input_locked = true
	set_prompt("")
	_panel.visible = true
	for line in lines:
		var s: String = line
		var tx := s
		var sp := ""
		var k := s.find("|")
		if k >= 0:
			sp = s.substr(0, k)
			tx = s.substr(k + 1)
		_speaker.text = sp
		_text.text = tx
		_text.visible_characters = 0
		var t := 0.0
		while _text.visible_characters < tx.length():
			await get_tree().process_frame
			t += get_process_delta_time()
			_text.visible_characters = mini(int(t * 45.0), tx.length())
			if _pressed():
				_text.visible_characters = tx.length()
		var wait := 0.0
		await get_tree().process_frame
		while not _pressed():
			await get_tree().process_frame
			wait += get_process_delta_time()
			if auto and wait > 0.02:
				break
	_panel.visible = false
	GameState.input_locked = prev

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
	_card.text = text
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 0.8)
	await tw.finished
	await get_tree().create_timer(hold).timeout
	tw = create_tween()
	tw.tween_property(_card, "modulate:a", 0.0, 0.8)
	await tw.finished
