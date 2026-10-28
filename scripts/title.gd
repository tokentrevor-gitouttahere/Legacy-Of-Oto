extends Control
## Title screen. Start the prologue or jump to the test arena.

var items := ["Begin: Prologue", "Explore: World Map", "Test Arena", "Prop and Outfit Gallery", "Quit"]
var cursor := 0
var _busy := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if GameState.has_save():
		items.insert(0, "Continue")
	GameState.menu_enabled = false
	GameState.input_locked = false
	GameState.in_location = false
	Overlay.set_prompt("")
	Overlay.hint("")
	Overlay.fade_from(0.6)

func _process(_delta: float) -> void:
	queue_redraw()
	if _busy:
		return
	if Input.is_action_just_pressed("move_down"):
		cursor = (cursor + 1) % items.size()
	if Input.is_action_just_pressed("move_up"):
		cursor = (cursor - 1 + items.size()) % items.size()
	if Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("menu"):
		_choose()

func _choose() -> void:
	_busy = true
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
		"Quit":
			get_tree().quit()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var sz := get_viewport_rect().size  # own size can still be zero on the first frames
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.04, 0.03, 0.08))
	draw_string(font, Vector2(0, sz.y * 0.3), "LEGACY OF OTO", HORIZONTAL_ALIGNMENT_CENTER, sz.x, 64, Color(0.85, 0.75, 1.0))
	draw_string(font, Vector2(0, sz.y * 0.3 + 40), "Not Yet. But Yes.", HORIZONTAL_ALIGNMENT_CENTER, sz.x, 22, Color(0.6, 0.55, 0.7))
	for i in items.size():
		var c := Color.WHITE if i == cursor else Color(0.5, 0.5, 0.6)
		var label: String = ("> " if i == cursor else "  ") + items[i]
		draw_string(font, Vector2(0, sz.y * 0.55 + i * 44), label, HORIZONTAL_ALIGNMENT_CENTER, sz.x, 30, c)
	draw_string(font, Vector2(0, sz.y - 24), "Up/Down: choose    Z or Enter: confirm", HORIZONTAL_ALIGNMENT_CENTER, sz.x, 18, Color(0.5, 0.5, 0.6))
