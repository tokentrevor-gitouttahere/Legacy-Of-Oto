extends Node3D
## Body shape editor (docs/BODY_STUDY.md): sliders for bust, waist, hips, butt and stomach on a
## copy of Oto's base mesh, live. Save the result as a named preset in
## assets/models/body_presets.json. The game's own mesh is never changed. "Oto Body Final" is
## Oto's own body: no other preset may have its exact proportions, and her outfit is only ever
## dressed on that shape (any other shape gets a plain stand-in outfit).
## Drag to turn, wheel to zoom, Esc goes back to the title.
## Dev flags: --amounts bust=2,waist=-1   the starting shape
##            --dress                     start with her outfit on
##            --yaw D --pitch D --dist M  the camera (for screenshots)

const SOURCE := "res://assets/models/base_female/model_0.obj"
const MAX_REASONABLE := "full_figure"
const FALLBACK_MAX := {"bust": 4.0, "waist": -1.8, "hips": 2.5, "butt": 4.0, "stomach": 0.0}
const PANEL_W := 390.0

var _shaper: BodyShape
var _amounts := {}
var _sliders := {}
var _readouts := {}
var _bare: Node3D
var _dressed: Node3D
var _dirty := false
var _cam: Camera3D
var _yaw := 0.0
var _pitch := 6.0
var _dist := 3.8
var _status: Label
var _presets := {}
var _list: OptionButton
var _name_edit: LineEdit
var _dress_check: CheckBox
var _spin_check: CheckBox
var _building := false

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	Overlay.hint("")
	Overlay.fade_from(0.3)  # the title fades to black before loading us
	_shaper = BodyShape.new(load(SOURCE) as Mesh)
	for k: String in BodyShape.PARAMS:
		_amounts[k] = 0.0
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.74, 0.77, 0.81)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.66)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.0
	add_child(key)
	key.look_at_from_position(Vector3.ZERO, Vector3(0.5, -0.6, -0.8), Vector3.UP)
	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.35
	add_child(fill)
	fill.look_at_from_position(Vector3.ZERO, Vector3(-0.7, -0.2, 0.7), Vector3.UP)
	var ground := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.8
	disc.bottom_radius = 0.8
	disc.height = 0.02
	ground.mesh = disc
	ground.position.y = -0.01
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.62, 0.66, 0.7)
	ground.material_override = gm
	add_child(ground)
	_bare = ModelLoader.make("oto")
	add_child(_bare)
	_cam = Camera3D.new()
	_cam.fov = 30
	add_child(_cam)
	_cam.current = true
	_build_ui()
	_presets = BodyShape.load_presets()
	_refresh_list()
	var i := args.find("--amounts")
	if i >= 0 and i + 1 < args.size():
		for pair in args[i + 1].split(","):
			var kv := pair.split("=")
			if kv.size() == 2 and _amounts.has(kv[0]):
				_set_amount(kv[0], float(kv[1]))
	for pair: Array in [["--yaw", "_yaw"], ["--pitch", "_pitch"], ["--dist", "_dist"]]:
		var j := args.find(pair[0])
		if j >= 0 and j + 1 < args.size():
			set(pair[1], float(args[j + 1]))
	_apply_now()
	if "--dress" in args:
		_dress_check.button_pressed = true
	_place_camera()

# --- the panel ---------------------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_right = PANEL_W
	layer.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var title := Label.new()
	title.text = "Body shape"
	title.add_theme_font_size_override("font_size", 24)
	box.add_child(title)
	var note := Label.new()
	note.text = "A copy of Oto's base mesh. The game's own mesh is not touched. Amounts are cm on a 170 cm figure."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 13)
	box.add_child(note)
	for k: String in BodyShape.PARAMS:
		var spec: Dictionary = BodyShape.PARAMS[k]
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = spec["label"]
		label.custom_minimum_size.x = 84
		row.add_child(label)
		var slider := HSlider.new()
		slider.min_value = spec["min"]
		slider.max_value = spec["max"]
		slider.step = 0.1
		slider.value = 0.0
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size.y = 26
		slider.value_changed.connect(func(v: float) -> void: _set_amount(k, v, false))
		slider.drag_ended.connect(func(_changed: bool) -> void: _redress())
		row.add_child(slider)
		var readout := Label.new()
		readout.custom_minimum_size.x = 74
		readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(readout)
		box.add_child(row)
		_sliders[k] = slider
		_readouts[k] = readout
		_show_value(k)
	var row2 := HBoxContainer.new()
	box.add_child(row2)
	_button(row2, "Reset", func() -> void: _load_amounts({}))
	_button(row2, "Max reasonable", func() -> void: _load_amounts(_presets.get(MAX_REASONABLE, FALLBACK_MAX)))
	box.add_child(HSeparator.new())
	var plabel := Label.new()
	plabel.text = "Presets"
	plabel.add_theme_font_size_override("font_size", 18)
	box.add_child(plabel)
	_list = OptionButton.new()
	box.add_child(_list)
	var row3 := HBoxContainer.new()
	box.add_child(row3)
	_button(row3, "Load", func() -> void: _load_selected())
	_button(row3, "Delete", func() -> void: _delete_selected())
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "name for the new preset"
	box.add_child(_name_edit)
	_button(box, "Save as preset", func() -> void: _save_preset())
	box.add_child(HSeparator.new())
	_dress_check = CheckBox.new()
	_dress_check.text = "Dress it (her outfit only on her own shape)"
	_dress_check.toggled.connect(func(_on: bool) -> void: _redress())
	box.add_child(_dress_check)
	var row4 := HBoxContainer.new()
	box.add_child(row4)
	for v: Array in [["Front", 0.0, 6.0], ["Side", -90.0, 6.0], ["Back", 180.0, 6.0], ["Three-quarter", -35.0, 10.0]]:
		_button(row4, v[0], func() -> void:
			_yaw = v[1]
			_pitch = v[2]
			_place_camera())
	_spin_check = CheckBox.new()
	_spin_check.text = "Turn slowly"
	box.add_child(_spin_check)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", Color(0.15, 0.3, 0.15))
	box.add_child(_status)

func _button(parent: Node, text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b

func _show_value(k: String) -> void:
	(_readouts[k] as Label).text = "%+.1f cm" % float(_amounts[k])

## Change one amount. `move`: also move its slider (a preset or a flag set it, not the user).
func _set_amount(k: String, v: float, move := true) -> void:
	_amounts[k] = snappedf(v, 0.1)
	if move:
		(_sliders[k] as HSlider).set_value_no_signal(_amounts[k])
	_show_value(k)
	_dirty = true

func _load_amounts(amounts: Dictionary) -> void:
	for k: String in BodyShape.PARAMS:
		_set_amount(k, float(amounts.get(k, 0.0)))
	_redress()

# --- presets -----------------------------------------------------------------------------------

func _refresh_list(select := "") -> void:
	_list.clear()
	var names: Array = _presets.keys()
	names.sort()
	for n: String in names:
		_list.add_item(n)
		if n == select:
			_list.select(_list.item_count - 1)

func _load_selected() -> void:
	if _list.item_count == 0:
		return
	var n := _list.get_item_text(_list.selected)
	_load_amounts(_presets[n])
	_say("Loaded '%s'." % n)

func _delete_selected() -> void:
	if _list.item_count == 0:
		return
	var n := _list.get_item_text(_list.selected)
	if n == BodyShape.OTO:
		_say("That is Oto's own body: it is her game body, so it cannot be deleted here.")
		return
	_presets.erase(n)
	_say(("Deleted '%s'." % n) if BodyShape.save_presets(_presets) else "Could not write the presets file.")
	_refresh_list()

func _save_preset() -> void:
	var n := _name_edit.text.strip_edges()
	if n.is_empty():
		_say("Type a name first.")
		return
	var table := {}
	for k: String in BodyShape.PARAMS:
		table[k] = float(_amounts[k])
	if n != BodyShape.OTO and BodyShape.same_shape(table, BodyShape.amounts_of(BodyShape.OTO)):
		_say("That is Oto's exact body. No other woman may share her proportions: change something first.")
		return
	_presets[n] = table
	if BodyShape.save_presets(_presets):
		_say("Saved '%s' to assets/models/body_presets.json." % n)
	else:
		_say("Could not write assets/models/body_presets.json (run the game from its project folder).")
	_refresh_list(n)

func _say(text: String) -> void:
	_status.text = text

# --- the figure --------------------------------------------------------------------------------

func _apply_now() -> void:
	var body := _bare.get_child(0).get_child(0) as MeshInstance3D
	body.mesh = _shaper.shape(_amounts)
	_dirty = false
	if _dressed:
		_dressed.visible = false
	_bare.visible = true

## Rebuild the figure in her outfit on the current shape (if the box is ticked).
func _redress() -> void:
	if _building:
		return
	_apply_now()
	if _dressed:
		_dressed.queue_free()
		_dressed = null
	if not _dress_check.button_pressed:
		return
	_building = true
	_say("Dressing her (about two seconds)...")
	await get_tree().process_frame
	await get_tree().process_frame
	_dressed = _shaper.dressed(_amounts)
	add_child(_dressed)
	_bare.visible = false
	_building = false
	_say("")

func _process(delta: float) -> void:
	if _dirty:
		_apply_now()
	if _spin_check and _spin_check.button_pressed:
		_yaw += delta * 20.0
		_place_camera()

func _place_camera() -> void:
	var t := Vector3(0, 1.0, 0)
	var yaw := deg_to_rad(_yaw)
	var pitch := deg_to_rad(_pitch)
	_cam.position = t + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * _dist
	_cam.look_at(t)
	_cam.h_offset = -_dist * 0.16  # shifts the figure to the right of the panel

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_yaw -= (event as InputEventMouseMotion).relative.x * 0.4
		_pitch = clampf(_pitch + (event as InputEventMouseMotion).relative.y * 0.3, -60.0, 80.0)
		_place_camera()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(_dist * 0.92, 0.8)
			_place_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(_dist * 1.08, 7.0)
			_place_camera()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/title.tscn")
