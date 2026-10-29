extends Node3D
## Mt. Paozu, days before Raditz. Oto wakes in a crater with no forms, no
## skills and one word. She meets Goku, Gohan and Chi-Chi, learns to fish and
## to eat with chopsticks, and has her first spar with Goku.

const ARENA := Rect2(-22, -16, 44, 32)
const HOUSE_POS := Vector3(10, 0, -9)

var player: Player
var cam: FollowCam
var goku: Npc
var gohan: Npc
var chichi: Npc
var fished := false
var ate := false
var sparred := false

func _ready() -> void:
	if not GameState.flags.get("amnesia", false):
		GameState.amnesia_reset()
	GameState.menu_enabled = false
	GameState.flags["no_death"] = true
	Music.play_area("town")
	_build_world()

	player = Player.new()
	player.arena = ARENA
	player.position = Vector3(0, 0, 0)
	add_child(player)

	cam = FollowCam.new()
	cam.target = player
	add_child(cam)
	cam.snap()

	gohan = _npc("male_base", Color.WHITE, 0.55, "Gohan", Vector3(8, 0, 7), "gohan_kid")
	gohan.on_interact = _talk_gohan
	goku = _npc("goku", Color.WHITE, 1.0, "Goku", Vector3(7, 0, 6))
	goku.on_interact = _talk_goku
	chichi = _npc("oto", Color.WHITE, 1.0, "Chi-Chi", HOUSE_POS + Vector3(-2.5, 0, 3.0), "chichi")
	chichi.on_interact = _talk_chichi
	var crater := _npc("", Color.WHITE, 1.0, "Crater", Vector3(0, 0, 0))
	crater.prompt = "Look at the crater"
	crater.on_interact = _look_crater

	var layer := CanvasLayer.new()
	var hud := Hud.new()
	hud.player = player
	layer.add_child(hud)
	add_child(layer)

	if "--spar" in OS.get_cmdline_user_args():  # developer shortcut to the spar
		fished = true
		ate = true
		goku.position = Vector3(3, 0, 3)
		goku.on_interact.call(player)
		return
	_intro()

func _npc(model: String, tint: Color, model_scale: float, nm: String, pos: Vector3, outfit := "") -> Npc:
	var n := Npc.new()
	n.model_key = model
	n.tint = tint
	n.model_scale = model_scale
	n.display_name = nm
	n.position = pos
	add_child(n)
	if outfit != "" and n.visual:
		Outfits.apply(n.visual, outfit)
	return n

func _build_world() -> void:
	WorldKit.environment(self, Color(0.25, 0.4, 0.7), Color(0.95, 0.65, 0.4),
		Color(0.75, 0.65, 0.65), 0.7, Color(1.0, 0.8, 0.6), 1.1, Vector3(-30, -50, 0))
	WorldKit.checker_floor(self, ARENA, Color(0.24, 0.45, 0.2), Color(0.21, 0.41, 0.18), 2.0)
	WorldKit.border(self, ARENA, Color(0.3, 0.25, 0.15))
	# crater
	var disc := WorldKit.cylinder(self, Vector3(0, 0, 0), 2.2, 0.05, Color(0.12, 0.1, 0.1))
	disc.position.y = 0.03
	# pond
	var pond := WorldKit.cylinder(self, Vector3(-9, 0, 6), 4.0, 0.05, Color(0.2, 0.45, 0.8))
	pond.position.y = 0.04
	# house
	WorldKit.box(self, HOUSE_POS + Vector3(0, 1.5, 0), Vector3(6, 3, 5), Color(0.9, 0.8, 0.6))
	WorldKit.box(self, HOUSE_POS + Vector3(0, 3.4, 0), Vector3(6.6, 0.8, 5.6), Color(0.7, 0.25, 0.2))
	for p in [Vector3(-14, 0, -8), Vector3(-16, 0, 2), Vector3(16, 0, 8), Vector3(-6, 0, -12), Vector3(18, 0, -2), Vector3(-18, 0, 10)]:
		WorldKit.tree(self, p)

func _intro() -> void:
	GameState.input_locked = true
	player.cinematic = true
	player.visual.rotation.x = -PI / 2.0
	player.visual.position.y = 0.25
	goku.position = Vector3(7, 0, 6)
	gohan.position = goku.position + Vector3(0, 1.55, 0)
	Overlay.flash(Color.WHITE, 1.5)
	await get_tree().create_timer(1.0).timeout
	await Overlay.card("Mt. Paozu", 1.5)
	await Overlay.fade_from(1.0)

	# Goku walks over with Gohan on his shoulders.
	cam.focus_override = true
	cam.focus_pos = Vector3(3, 0, 3)
	goku.face(player.position)
	var walk := create_tween()
	walk.set_parallel(true)
	walk.tween_property(goku, "position", Vector3(1.6, 0, 2.2), 2.5)
	walk.tween_property(gohan, "position", Vector3(1.6, 1.55, 2.2), 2.5)
	await walk.finished
	await Overlay.say([
		"Gohan|Daddy, there's a lady in the hole.",
		"Goku|Huh. So there is!",
	])
	var rise := create_tween()
	rise.set_parallel(true)
	rise.tween_property(player.visual, "rotation:x", 0.0, 1.2)
	rise.tween_property(player.visual, "position:y", 0.0, 1.2)
	await rise.finished
	await Overlay.say([
		"|She sits up the way someone does who is not sure what sitting is for.",
		"Oto|Where is this?",
		"|She looks for her past the way you check a pocket for your keys.",
		"Oto|I do not know. I do not know anything.",
		"|A word rises, like a stone at the bottom of a well.",
		"Oto|Oto. It is the only thing that came with me.",
		"Goku|Oto! Cool name.",
	])

	# Chi-Chi decides she is a stray.
	cam.focus_pos = Vector3(4, 0, 0)
	var arrive := create_tween()
	arrive.tween_property(chichi, "position", Vector3(3.2, 0, 0.8), 2.0)
	await arrive.finished
	chichi.face(goku.position)
	await Overlay.say([
		"Chi-Chi|Goku! Another stray from a hole in the ground?",
		"Chi-Chi|No shoes. No name. No past. That is a stray if I ever saw one.",
		"Goku|Aw, Chi-Chi...",
		"Chi-Chi|And you! Do not bring people home from holes in the ground. I will not say it twice.",
		"Chi-Chi|...I said it twice. Here. A blanket. Come inside when you are ready.",
	])
	Overlay.toast("Received: Blanket")

	# Back to the clearing; the little people go back to what they were doing.
	var settle := create_tween()
	settle.set_parallel(true)
	settle.tween_property(goku, "position", Vector3(7, 0, -2), 1.5)
	settle.tween_property(gohan, "position", Vector3(-7, 0, 4), 1.5)
	settle.tween_property(chichi, "position", HOUSE_POS + Vector3(-2.5, 0, 3.0), 1.5)
	await settle.finished
	cam.focus_override = false
	player.cinematic = false
	player.facing = Vector3(0, 0, 1)
	GameState.input_locked = false
	GameState.menu_enabled = true
	Overlay.hint("E: talk. Enter: menu. Goku wants to see what you remember, but go and meet Gohan and Chi-Chi first.")

func _look_crater(_p: Player) -> void:
	await Overlay.say([
		"|No ship. No fire. No smoke. Only a clean hollow in the grass, as if a light had been put out.",
	])

func _talk_gohan(_p: Player) -> void:
	if fished:
		await Overlay.say(["Gohan|You're really good at this, Miss Oto!"])
		return
	await Overlay.say([
		"Gohan|Hi, Miss Oto! Do you want to learn to fish?",
		"Gohan|You hold the line, and you wait. That's the hard part.",
	])
	await _fish()
	fished = true
	GameState.flags["paozu_fished"] = true
	await Overlay.say(["Gohan|You got one! Daddy will be so happy. Chi-Chi too."])
	GameState.give_item("heavy_boots")
	Overlay.toast("Found: Heavy Boots (in the fish's stomach?)")
	_check_ready()

func _fish() -> void:
	GameState.input_locked = true
	var caught := false
	while not caught:
		Overlay.toast("Waiting for a bite...", 1.2)
		await get_tree().create_timer(randf_range(1.2, 2.8)).timeout
		Overlay.toast("A bite!  Press E!", 0.9)
		var t := 0.0
		var hit := Overlay.auto
		while t < 0.9 and not hit:
			await get_tree().process_frame
			t += get_process_delta_time()
			if Input.is_action_just_pressed("interact"):
				hit = true
		if hit:
			caught = true
		else:
			await Overlay.say(["Gohan|Oh, it got away! Try again."])
	GameState.input_locked = false
	GameState.add_xp(20)

func _talk_chichi(_p: Player) -> void:
	if ate:
		await Overlay.say(["Chi-Chi|There is more where that came from. Sit. Eat."])
		return
	await Overlay.say([
		"Chi-Chi|Sit. Eat. Hold them like this... no, like THIS.",
		"|The chopsticks click. Click. A rice ball falls on the floor.",
		"Oto|...Again, please.",
		"Chi-Chi|Good. That is the right answer.",
	])
	ate = true
	GameState.flags["paozu_chopsticks"] = true
	GameState.add_xp(15)
	Overlay.toast("Learned: chopsticks")
	_check_ready()

func _check_ready() -> void:
	if fished and ate:
		Overlay.hint("Goku is waiting in the clearing. E to talk.")

func _talk_goku(_p: Player) -> void:
	if sparred:
		return
	if not (fished and ate):
		await Overlay.say([
			"Goku|Hey, Oto! Go and see Gohan and Chi-Chi first. I'll be right here.",
		])
		return
	await Overlay.say([
		"Goku|I'd like to see what you remember.",
		"Oto|I do not think I remember anything.",
		"Goku|Your body might!",
	])
	await _spar()

func _spar() -> void:
	var foe := Enemy.new()
	foe.model_key = "goku"
	foe.display_name = "Goku"
	foe.spar = true
	foe.max_hp = 160.0
	foe.speed = 3.3
	foe.damage = 4.0
	foe.arena = ARENA
	foe.target = player
	foe.position = goku.position
	goku.visible = false
	goku.enabled = false
	add_child(foe)
	Overlay.hint("Spar! Z: attack   C: guard   Hold X: ki shot")
	await foe.spar_ended
	Overlay.hint("")
	await Overlay.say([
		"Goku|Okay, okay! Your body remembers more than you do.",
		"|By the end of it her breath has gone slow and even, the way it went at the pond, waiting for a bite.",
	])
	GameState.learn_charge(1)
	sparred = true
	GameState.flags["paozu_sparred"] = true
	await get_tree().create_timer(2.0).timeout
	GameState.input_locked = true
	await Overlay.card("Not even a week from now a pod will fall out of the sky,\nand the word Saiyan will land on Earth with it.", 4.0)
	await Overlay.card("End of the current build\nNext: the Saiyan Saga", 3.0)
	GameState.input_locked = false
	get_tree().change_scene_to_file("res://scenes/title.tscn")
