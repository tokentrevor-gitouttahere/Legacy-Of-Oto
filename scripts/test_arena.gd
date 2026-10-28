extends Node3D
## Sandbox: all forms unlocked, some gear, training dummies, a Goku and a male
## base standing around. Good for feeling out combat and the menu.

const ARENA := Rect2(-15, -10, 30, 20)

var player: Player
var cam: FollowCam

func _ready() -> void:
	GameState.new_run()
	GameState.max_form = 3
	GameState.menu_enabled = true
	for id in Items.DB.keys():
		GameState.give_item(id)
	GameState.stat_points = 6

	WorldKit.environment(self, Color(0.05, 0.04, 0.1), Color(0.2, 0.17, 0.3),
		Color(0.6, 0.6, 0.75), 0.7, Color.WHITE, 1.0, Vector3(-60, -30, 0))
	WorldKit.checker_floor(self, ARENA, Color(0.19, 0.16, 0.24), Color(0.15, 0.12, 0.2))
	WorldKit.border(self, ARENA, Color(0.4, 0.32, 0.5))

	player = Player.new()
	player.arena = ARENA
	add_child(player)

	cam = FollowCam.new()
	cam.target = player
	add_child(cam)
	cam.snap()

	var goku := ModelLoader.make("goku")
	goku.position = Vector3(3, 0, -2)
	add_child(goku)
	var male := ModelLoader.make("male_base")
	male.position = Vector3(-3, 0, -2)
	add_child(male)

	var drops := ["red", "blue3", "green5"]
	var foods := ["haunch", "rice_ball", "haunch"]
	var spots := [Vector3(-8, 0, -4), Vector3(8, 0, 3), Vector3(-2, 0, 7)]
	for i in spots.size():
		var e := Enemy.new()
		e.position = spots[i]
		e.arena = ARENA
		e.target = player
		e.capsule_drop = drops[i]
		e.food_drop = foods[i]
		add_child(e)
	var args := OS.get_cmdline_user_args()
	var ci := args.find("--charge")
	if ci >= 0 and ci + 1 < args.size():  # developer check: --charge <tier> --sim charge
		GameState.charge_tier = int(args[ci + 1])
		player.ki = 0.0
		for e in get_tree().get_nodes_in_group("enemies"):
			e.queue_free()
	if "--behaviors" in args:  # developer check: one of each behaviour on beasts, tiers 1-4
		for e in get_tree().get_nodes_in_group("enemies"):
			e.queue_free()
		var specs := [["charger", 2, Vector3(-9, 0, -6), "boar"], ["shooter", 3, Vector3(9, 0, -6), "pterodactyl"],
			["pack", 1, Vector3(-6, 0, 6), "wolf"], ["pack", 1, Vector3(0, 0, 8), "wolf"], ["pack", 4, Vector3(6, 0, 6), "wolf"]]
		for s: Array in specs:
			var e := Enemy.new()
			e.behavior = s[0]
			e.tier = s[1]
			e.position = s[2]
			e.beast = s[3]
			e.arena = ARENA
			e.target = player
			e.food_drop = "haunch"
			add_child(e)
	var mi := args.find("--menutab")
	if mi >= 0 and mi + 1 < args.size():  # developer view of a pause menu tab with sample progress
		GameState.amnesia_reset()
		GameState.menu_enabled = true
		GameState.flags["paozu_fished"] = true
		GameState.flags["roshi_lesson_started"] = true
		GameState.key_items.append("rusty_key")
		GameState.dishes.append("noodle_bowl")
		PauseMenu.open_tab.call_deferred(int(args[mi + 1]))
	if "--sense" in args:  # developer view of the scan panel (--scouter for exact numbers)
		GameState.sensing = true
		if "--scouter" in args:
			GameState.key_items.append("scouter")
	if "--pickups" in args:  # developer view of every pickup
		var kinds := ["red", "red3", "red5", "blue", "blue3", "green5", "haunch", "rice_ball", "fresh_fish", "ki_mote", "senzu"]
		for i in kinds.size():
			var p := Pickup.new()
			p.kind = kinds[i]
			p.position = Vector3(-6.0 + i * 1.2, 0, -3.5)
			add_child(p)

	var layer := CanvasLayer.new()
	var hud := Hud.new()
	hud.player = player
	layer.add_child(hud)
	add_child(layer)
	Overlay.hint("Test arena. Hold Z: heavy strike. Q: switch ki technique. V: charge ki. F/G: form up/down. Enter: stats and gear.")
	Overlay.fade_from(0.4)  # the title fades to black before loading us
