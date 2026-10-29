extends Node
## Autoload. Registers the input map and handles developer launch arguments
## (everything after `--`): --scene <res://...>  --shot <png>  --frames <n>
## --zoom  --far  --timescale <x>  --auto-dialogue  --sim <fight|menu|walk|map|charge|north|ki>
## --setlevel <n>  --setform <n>  --givekey <id>  (and --spawn <name> in locations)

var zoom := false
var far := false
var sim := ""
var _t := 0.0
var _shot_path := ""
var _shot_frames := 30

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -100  # simulated input lands before other nodes read it
	_bind("move_left", [KEY_LEFT, KEY_A], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_bind("move_right", [KEY_RIGHT, KEY_D], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_bind("move_up", [KEY_UP, KEY_W], [JOY_BUTTON_DPAD_UP], [[JOY_AXIS_LEFT_Y, -1.0]])
	_bind("move_down", [KEY_DOWN, KEY_S], [JOY_BUTTON_DPAD_DOWN], [[JOY_AXIS_LEFT_Y, 1.0]])
	_bind("attack", [KEY_Z, KEY_J], [JOY_BUTTON_A])
	_bind("special", [KEY_X, KEY_K], [JOY_BUTTON_B])
	_bind("cycle", [KEY_Q], [JOY_BUTTON_LEFT_SHOULDER])
	_bind("guard", [KEY_C, KEY_L], [JOY_BUTTON_RIGHT_SHOULDER])
	_bind("charge", [KEY_V], [JOY_BUTTON_Y])
	_bind("interact", [KEY_E], [JOY_BUTTON_X])
	_bind("transform", [KEY_F], [JOY_BUTTON_RIGHT_STICK])
	_bind("revert", [KEY_G], [JOY_BUTTON_LEFT_STICK])
	_bind("map", [KEY_TAB], [JOY_BUTTON_BACK])
	_bind("scan", [KEY_T], [])  # ki sense / scouter panel (no pad button free yet)
	_bind("menu", [KEY_ENTER, KEY_ESCAPE], [JOY_BUTTON_START])
	_parse_args.call_deferred()

func _bind(action: String, keys: Array, buttons: Array, axes: Array = []) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.3)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b in buttons:
		var ev := InputEventJoypadButton.new()
		ev.button_index = b
		InputMap.action_add_event(action, ev)
	for a in axes:
		var ev := InputEventJoypadMotion.new()
		ev.axis = a[0]
		ev.axis_value = a[1]
		InputMap.action_add_event(action, ev)

func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	zoom = "--zoom" in args
	far = "--far" in args
	if "--auto-dialogue" in args:
		Overlay.auto = true
	var i := args.find("--sim")
	if i >= 0 and i + 1 < args.size():
		sim = args[i + 1]
	i = args.find("--timescale")
	if i >= 0 and i + 1 < args.size():
		Engine.time_scale = float(args[i + 1])
	i = args.find("--frames")
	if i >= 0 and i + 1 < args.size():
		_shot_frames = int(args[i + 1])
	# Run-state shortcuts for checking gates and doors: --setlevel N --setform N --givekey id
	i = args.find("--setlevel")
	if i >= 0 and i + 1 < args.size():
		GameState.level = int(args[i + 1])
	i = args.find("--setform")
	if i >= 0 and i + 1 < args.size():
		GameState.max_form = int(args[i + 1])
	i = args.find("--givekey")
	if i >= 0 and i + 1 < args.size():
		GameState.key_items.append(args[i + 1])
	i = args.find("--scene")
	if i >= 0 and i + 1 < args.size():
		get_tree().change_scene_to_file(args[i + 1])
	i = args.find("--shot")
	if i >= 0 and i + 1 < args.size():
		_shot_path = args[i + 1]
		_take_shot()

func _take_shot() -> void:
	for n in _shot_frames:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(_shot_path)
	get_tree().quit()

func _process(delta: float) -> void:
	if sim == "":
		return
	_t += delta
	match sim:
		"fight":
			var phase := fmod(_t, 4.0)
			_press("move_right", phase < 1.5)
			_press("move_left", phase >= 2.5 and phase < 3.0)
			_press("attack", fmod(_t, 0.25) < 0.1)
			_press("special", phase > 1.5 and fmod(_t, 2.0) < 0.8)
			_press("transform", fmod(_t, 1.5) < 0.1)
			_press("guard", fmod(_t, 7.0) > 6.0)
		"ki":  # hold special for 1.1 s, let go for 0.9 s: charge and fire the current ki technique
			_press("special", fmod(_t, 2.0) < 1.1)
		"menu":
			_press("menu", fmod(_t, 3.0) < 0.1)
			_press("move_down", fmod(_t, 0.7) < 0.1)
			_press("move_right", fmod(_t, 2.1) < 0.1)
			_press("attack", fmod(_t, 0.5) < 0.1)
		"map":
			_press("map", _t > 0.5 and _t < 0.6)
			_press("move_up", _t > 0.7)
		"charge":
			_press("charge", true)
		"north":
			_press("move_up", true)
		"interact":
			_press("interact", fmod(_t, 0.5) < 0.1)
		"walk":
			_press("move_right", fmod(_t, 3.0) < 1.5)
			_press("move_down", fmod(_t, 4.0) > 2.0)
			_press("interact", fmod(_t, 2.0) < 0.1)

func _press(action: String, on: bool) -> void:
	if on and not Input.is_action_pressed(action):
		Input.action_press(action)
	elif not on and Input.is_action_pressed(action):
		Input.action_release(action)
