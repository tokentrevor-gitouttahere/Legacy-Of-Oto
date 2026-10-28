extends Node3D
## Opening: Oto at full power against the life-energy Saiyan, on the dark side of
## her world. Before the fight can end, Yamoshi's light arrives and throws her
## through time; her forms fall away and she wakes on Mt. Paozu.

const ARENA := Rect2(-18, -12, 36, 24)

var player: Player
var boss: LifeSaiyan
var cam: FollowCam
var _mid_line_done := false
var _cutscene_started := false

func _ready() -> void:
	GameState.new_run()
	GameState.start_power_fantasy()
	GameState.flags["no_death"] = true
	GameState.menu_enabled = false
	_build_world()

	player = Player.new()
	player.arena = ARENA
	player.position = Vector3(-6, 0, 0)
	player.facing = Vector3.RIGHT
	add_child(player)

	boss = LifeSaiyan.new()
	boss.arena = ARENA
	boss.target = player
	boss.position = Vector3(7, 0, 0)
	boss.threshold_reached.connect(_on_threshold)
	boss.mid_reached.connect(_on_mid)
	add_child(boss)
	if "--skipfight" in OS.get_cmdline_user_args():
		boss.hp = boss.max_hp * 0.27  # developer shortcut to the cutscene
		boss.kit.skip_to(1)
		_mid_line_done = true

	cam = FollowCam.new()
	cam.target = player
	add_child(cam)
	cam.snap()

	var layer := CanvasLayer.new()
	var hud := Hud.new()
	hud.player = player
	layer.add_child(hud)
	add_child(layer)

	_intro()

func _build_world() -> void:
	WorldKit.environment(self, Color(0.02, 0.02, 0.05), Color(0.35, 0.28, 0.4),
		Color(0.35, 0.33, 0.5), 0.6, Color(0.7, 0.65, 0.85), 0.6, Vector3(-55, 70, 0))
	WorldKit.checker_floor(self, ARENA, Color(0.12, 0.1, 0.16), Color(0.1, 0.085, 0.14), 2.0)
	WorldKit.border(self, ARENA, Color(0.25, 0.2, 0.3))
	# The Wall: a line of sunlight on the horizon, far to the east.
	WorldKit.box(self, Vector3(40, 15, 0), Vector3(1.0, 30.0, 90.0), Color(1.0, 0.93, 0.7), true)

func _intro() -> void:
	GameState.input_locked = true
	await Overlay.fade_from(1.5)
	await Overlay.say(["|The dark side of the world. A few hours from The Wall."])
	GameState.input_locked = false
	Overlay.hint("Move: arrows/WASD (double-tap to run)   Z: attack   Hold X: ki   C: guard   C+X: barrier   Q: ki technique   V: charge ki   F/G: form up/down   Enter: menu")

func _on_mid() -> void:
	if not _mid_line_done:
		_mid_line_done = true
		_mid_line()

func _mid_line() -> void:
	boss.frozen = true
	await Overlay.say([
		"Oto|Stop. You are burning yourself down.",
		"???|That is what it is for.",
	])
	boss.frozen = false

func _on_threshold() -> void:
	if _cutscene_started:
		return
	_cutscene_started = true
	_cutscene()

func _cutscene() -> void:
	GameState.input_locked = true
	Overlay.hint("")
	Overlay.set_prompt("")
	player.guarding = false
	player.barrier = false
	player.charging = false
	await Overlay.say([
		"|His hair is white. His skin is thin as paper. He is smiling.",
		"Oto|Enough. You have nothing left to spend.",
		"???|Then it was well spent.",
	])

	# The god-light arrives from the direction of The Wall.
	cam.shake = 1.0
	await Overlay.flash(Color(1.0, 0.95, 0.7), 1.5)
	var yamoshi := ModelLoader.make_glowing("male_base", Color(1.0, 0.97, 0.8))
	yamoshi.position = Vector3(player.position.x + 5.0, 0, player.position.z)
	yamoshi.rotation.y = -PI / 2.0
	add_child(yamoshi)
	cam.focus_override = true
	cam.focus_pos = (player.position + yamoshi.position) * 0.5
	await get_tree().create_timer(1.6).timeout

	# He does not rescue her. He aims her. (Wordless: his words belong to the epilogue.)
	player.cinematic = true
	var dest := Vector3(player.position.x - 14.0, 22.0, player.position.z + 8.0)
	var fling := create_tween()
	fling.set_parallel(true)
	fling.tween_property(player, "position", dest, 3.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fling.tween_property(player.visual, "rotation:x", TAU * 3.0, 3.2)
	cam.focus_override = false
	cam.shake = 1.0

	# Everything she had comes off her on the way.
	for f in [3, 2, 1, 0]:
		await get_tree().create_timer(0.7).timeout
		if f > 0:
			Overlay.toast("%s  lost" % GameState.FORM_NAMES[f], 1.2)
		player.set_form(f - 1, true)
	await fling.finished

	await Overlay.fade_to(Color(1.0, 0.97, 0.85), 1.2)
	GameState.amnesia_reset()
	await Overlay.card("Days before the Saiyans arrive.", 2.5)
	get_tree().change_scene_to_file("res://scenes/paozu.tscn")
