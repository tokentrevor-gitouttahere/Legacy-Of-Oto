extends Control
## Title screen. Start the prologue, continue, or open the developer rooms.
##
## Three layers: a painted sky (the void at the top, a dusk horizon, stars, and the line of
## sunlight that split the Shadow Saiyans' world standing up out of it), Oto herself in a 3D
## viewport, lit gold from the lit side and violet from the dark, and over both the logo and
## the menu. Everything fades in; the light on the line drifts.

var items := ["Begin: Prologue", "Explore: World Map", "Test Arena", "Prop and Outfit Gallery", "Body Shape Editor", "Quit"]
const NOTES := {
	"Continue": "Pick up from the last lamp she rested at.",
	"Begin: Prologue": "Level 60, every Shadow form, and the fight that took them.",
	"Explore: World Map": "Fly the world map from West City.",
	"Test Arena": "Developer room: foes, pickups and every move.",
	"Prop and Outfit Gallery": "Developer room: props, outfits and the townswomen.",
	"Body Shape Editor": "Developer room: reshape the female base.",
	"Quit": "",
}
var cursor := 0
var _busy := false
var _t := 0.0
var _sky: Control
var _fg: Control
var _box: SubViewportContainer  # sized from the window: this Control can be zero-sized
var _stars: Array = []  # [pos (0..1), size, phase]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if GameState.has_save():
		items.insert(0, "Continue")
	Music.play_area("title")  # carries on from the intro without a restart
	GameState.menu_enabled = false
	GameState.input_locked = false
	GameState.in_location = false
	Overlay.set_prompt("")
	Overlay.hint("")
	Overlay.fade_from(0.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 140:
		_stars.append([Vector2(rng.randf(), rng.randf() * 0.62), rng.randf_range(0.6, 2.0), rng.randf() * TAU])
	_sky = _layer(_draw_sky)
	_stage()
	_fg = _layer(_draw_fg)

func _layer(fn: Callable) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(fn)
	add_child(c)
	return c

## Oto in her own small world: a transparent viewport over the painted sky.
func _stage() -> void:
	var box := SubViewportContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.stretch = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.34, 0.28, 0.48)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()  # the lit side: warm gold from her right
	key.light_color = Color(1.0, 0.85, 0.6)
	key.light_energy = 1.5
	key.rotation = Vector3(deg_to_rad(-18), deg_to_rad(-62), 0)
	vp.add_child(key)
	var rim := OmniLight3D.new()  # the dark side: violet from behind on her left
	rim.light_color = Color(0.6, 0.45, 1.0)
	rim.light_energy = 3.0
	rim.omni_range = 5.0
	rim.position = Vector3(1.6, 1.9, -1.4)
	vp.add_child(rim)
	var oto := Outfits.make_character("oto")
	oto.rotation.y = -0.38
	vp.add_child(oto)
	var cam := Camera3D.new()
	cam.fov = 26
	cam.position = Vector3(-1.25, 1.05, 4.9)
	vp.add_child(cam)
	cam.look_at(Vector3(-0.62, 1.0, 0))
	cam.current = true
	_box = box

func _process(delta: float) -> void:
	_t += delta
	_box.size = get_viewport_rect().size
	_sky.queue_redraw()
	_fg.queue_redraw()
	if _busy:
		return
	if Input.is_action_just_pressed("move_down") or Input.is_action_just_pressed("move_up"):
		Sfx.play("ui_move")
	if Input.is_action_just_pressed("move_down"):
		cursor = (cursor + 1) % items.size()
	if Input.is_action_just_pressed("move_up"):
		cursor = (cursor - 1 + items.size()) % items.size()
	if Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("menu"):
		_choose()

func _choose() -> void:
	_busy = true
	Sfx.play("ui_confirm")
	match items[cursor]:
		"Continue":
			GameState.continue_game()
		"Begin: Prologue":
			await Overlay.fade_to(Color.BLACK, 0.8)
			get_tree().change_scene_to_file("res://scenes/prologue_fight.tscn")
		"Explore: World Map":
			GameState.new_run()
			GameState.max_form = 3
			GameState.travel_world("west_city")
		"Test Arena":
			await Overlay.fade_to(Color.BLACK, 0.5)
			get_tree().change_scene_to_file("res://scenes/test_arena.tscn")
		"Prop and Outfit Gallery":
			await Overlay.fade_to(Color.BLACK, 0.5)
			get_tree().change_scene_to_file("res://scenes/gallery.tscn")
		"Body Shape Editor":
			await Overlay.fade_to(Color.BLACK, 0.5)
			get_tree().change_scene_to_file("res://scenes/body_editor.tscn")
		"Quit":
			get_tree().quit()

# --- the sky ----------------------------------------------------------------------------

func _draw_sky() -> void:
	var sz := get_viewport_rect().size  # own size can still be zero on the first frames
	var horizon := sz.y * 0.7
	UiKit.gradient_rect(_sky, Rect2(Vector2.ZERO, Vector2(sz.x, horizon * 0.55)), Color(0.015, 0.01, 0.035), Color(0.06, 0.035, 0.11))
	UiKit.gradient_rect(_sky, Rect2(Vector2(0, horizon * 0.55), Vector2(sz.x, horizon * 0.45)), Color(0.06, 0.035, 0.11), Color(0.32, 0.16, 0.22))
	UiKit.gradient_rect(_sky, Rect2(Vector2(0, horizon), Vector2(sz.x, sz.y - horizon)), Color(0.07, 0.04, 0.09), Color(0.02, 0.012, 0.03))
	for s: Array in _stars:
		var p: Vector2 = s[0]
		var tw := 0.55 + 0.45 * sin(_t * 1.3 + float(s[2]))
		_sky.draw_circle(Vector2(p.x * sz.x, p.y * sz.y), float(s[1]) * 0.7, Color(0.9, 0.88, 1.0, 0.55 * tw * (1.0 - p.y)))
	# a far ridge of mountains along the horizon
	var ridge := PackedVector2Array([Vector2(0, sz.y)])
	for i in 33:
		var x := sz.x * i / 32.0
		var h := 26.0 + 22.0 * sin(i * 1.7) + 14.0 * sin(i * 0.53 + 1.0)
		ridge.append(Vector2(x, horizon - h))
	ridge.append(Vector2(sz.x, sz.y))
	_sky.draw_colored_polygon(ridge, Color(0.05, 0.03, 0.07))
	# the line of sunlight, up from the horizon behind her, and its glow on the ridge
	var lx := sz.x * 0.66
	var a := clampf(_t * 0.6, 0.0, 1.0)
	for k in 7:
		var w := 2.0 + k * k * 4.0
		_sky.draw_rect(Rect2(lx - w * 0.5, 0, w, horizon), Color(1.0, 0.86, 0.6, 0.05 * a / (1.0 + k * 0.3)))
	_sky.draw_rect(Rect2(lx - 1.0, 0, 2.0, horizon), Color(1.0, 0.95, 0.82, 0.75 * a))
	for k in 24:
		_sky.draw_circle(Vector2(lx, horizon - 6.0), 10.0 + k * k * 0.75, Color(1.0, 0.75, 0.45, 0.014 * a))
	# slow motes rising on the lit side
	for i in 18:
		var ph := fmod(_t * 0.05 + i * 0.137, 1.0)
		var x := lx - 260.0 + fmod(i * 97.0, 240.0) + sin(_t + i) * 8.0
		_sky.draw_circle(Vector2(x, horizon - ph * horizon * 0.8), 1.6, Color(1.0, 0.85, 0.55, 0.5 * sin(ph * PI) * a))

# --- logo and menu ----------------------------------------------------------------------

func _draw_fg() -> void:
	var sz := get_viewport_rect().size
	# a vignette that darkens the left, where the words are
	_fg.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(sz.x * 0.62, 0), Vector2(sz.x * 0.62, sz.y), Vector2(0, sz.y)]),
		PackedColorArray([Color(0, 0, 0, 0.55), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.6)]))
	var lx := sz.x * 0.27
	var fade := clampf((_t - 0.2) * 0.9, 0.0, 1.0)
	UiKit.logo(_fg, Vector2(lx, sz.y * 0.22), minf(sz.x * 0.36, 520.0), _t, fade)
	UiKit.text(_fg, UiKit.body_font(true), Vector2(lx - 300.0, sz.y * 0.22 + minf(sz.x * 0.36, 520.0) * 0.3), "Not Yet. But Yes.", 22,
		Color(0.85, 0.8, 0.95, fade * 0.9), HORIZONTAL_ALIGNMENT_CENTER, 600.0, 4)
	# the menu panel
	var m := clampf((_t - 0.7) * 2.5, 0.0, 1.0)
	var row_h := 42.0
	var pw := 420.0
	var ph := items.size() * row_h + 40.0
	var pr := Rect2(Vector2(lx - pw * 0.5, sz.y * 0.475 + (1.0 - m) * 20.0), Vector2(pw, ph))
	_fg.modulate.a = 1.0
	if m <= 0.0:
		return
	var font := UiKit.spaced(UiKit.display_font(true), 1)
	var c_panel := Color(1, 1, 1, m)
	_fg.draw_set_transform(Vector2.ZERO)
	UiKit.frame(_fg, pr, Color(UiKit.GOLD.r, UiKit.GOLD.g, UiKit.GOLD.b, m), true)
	for i in items.size():
		var y := pr.position.y + 32.0 + i * row_h
		var row := Rect2(Vector2(pr.position.x + 30.0, y), Vector2(pw - 60.0, row_h - 6.0))
		var on := i == cursor
		if on:
			UiKit.highlight(_fg, row, UiKit.GOLD, _t)
		var dev: bool = items[i] in ["Test Arena", "Prop and Outfit Gallery", "Body Shape Editor"]
		var col := UiKit.GOLD_PALE if on else (UiKit.FAINT.lightened(0.25) if dev else UiKit.TEXT)
		UiKit.text(_fg, font, Vector2(row.position.x + 18.0, y + 28.0), items[i], 23 if not dev else 20, Color(col.r, col.g, col.b, m * c_panel.a))
	var note: String = NOTES.get(items[cursor], "")
	if note != "":
		UiKit.text(_fg, UiKit.body_font(true), Vector2(pr.position.x - 120.0, pr.end.y + 30.0), note, 17, Color(UiKit.MUTED.r, UiKit.MUTED.g, UiKit.MUTED.b, m), HORIZONTAL_ALIGNMENT_CENTER, pw + 240.0, 3)
	UiKit.key_row(_fg, Vector2(26.0, sz.y - 24.0), [["Up/Down", "Choose"], ["Z / Enter", "Confirm"]])
	UiKit.text(_fg, UiKit.body_font(), Vector2(0, sz.y - 22.0), "A fan game. Dragon Ball belongs to its creators.", 13, Color(1, 1, 1, 0.35), HORIZONTAL_ALIGNMENT_RIGHT, sz.x - 24.0, 2)
