extends Node3D
## Generic location scene: builds GameState.pending_level (or `--level <id>`),
## spawns Oto, NPCs and enemies, and handles exits. Story scenes can extend this.

var level: Level
var player: Player
var cam: FollowCam
var _exits_armed := false

func _ready() -> void:
	var id := GameState.pending_level
	var args := OS.get_cmdline_user_args()
	var i := args.find("--level")
	if i >= 0 and i + 1 < args.size():
		id = args[i + 1]
	if id == "":
		id = "west_city"
	i = args.find("--spawn")
	if i >= 0 and i + 1 < args.size():
		GameState.pending_spawn = args[i + 1]
	level = Level.load_level(id)
	add_child(level)
	Skies.apply(self, level.data.get("sky", "day"))

	GameState.current_level = id
	GameState.in_location = true
	player = Player.new()
	player.arena = level.rect
	player.blocker = level.is_blocked
	player.respawn_at = level.spawn_point("default")
	player.ground_at = level.ground_at
	player.position = level.spawn_point(GameState.pending_spawn)
	if GameState.pending_pos != Vector3.INF:  # loading a save
		player.position = GameState.pending_pos
		GameState.pending_pos = Vector3.INF
	player.outfit = level.data.get("player_outfit", "oto")
	add_child(player)
	player.charged_from_empty.connect(_on_charged_from_empty)
	for f in level.fixtures:
		var fx := Fixture.new()
		fx.setup(level, f)
		add_child(fx)

	cam = FollowCam.new()
	cam.target = player
	if level.is_interior():
		cam.offset = Vector3(0, 12, 8.5)
	add_child(cam)
	cam.snap()

	_spawn_npcs()
	_spawn_enemies()
	_spawn_pickups()

	var layer := CanvasLayer.new()
	var hud := Hud.new()
	hud.player = player
	layer.add_child(hud)
	add_child(layer)

	GameState.menu_enabled = true
	GameState.input_locked = false
	Overlay.hint("")
	Overlay.fade_from(0.5)
	Overlay.toast(level.data.get("name", id), 2.0)

func _spawn_npcs() -> void:
	for spec in level.npcs:
		var n := Npc.new()
		var outfit: String = spec.get("outfit", "")
		n.model_key = spec.get("model", Outfits.model_for(outfit) if outfit != "" else "male_base")
		n.display_name = spec.get("name", "")
		n.prompt = spec.get("prompt", "Talk")  # e.g. "Read" for a note
		n.model_scale = float(spec.get("scale", Outfits.preset_spec(outfit).get("scale", 1.0)))
		if spec.has("tint"):
			n.tint = Level._color(spec["tint"])
		var at: Array = spec["at"]
		n.position = level.cell_pos(at[0], at[1])
		if not spec.has("lines"):
			spec["lines"] = ["%s|..." % n.display_name]
		n.on_interact = func(p: Player) -> void:
			await Talks.run(spec, p)
			_after_talk(spec)
		add_child(n)
		if outfit != "" and n.visual:
			Outfits.apply(n.visual, outfit)
		if n.visual:
			n.visual.rotation.y = deg_to_rad(float(spec.get("rot", 0.0)))

## Roshi's lesson: empty ki, then charge back to full without moving, on his island.
func _on_charged_from_empty() -> void:
	if level.id == "kame_house" and Quests.started("roshi_lesson") and not GameState.flags.get("roshi_still_charge", false):
		GameState.flags["roshi_still_charge"] = true
		Overlay.toast("Still as a turtle on a rock. Go and tell Roshi.", 3.0)

## Optional NPC keys: "gives" (key item id), "flag" (set after the first talk).
## "talk" and "dish" are handled by Talks.
func _after_talk(spec: Dictionary) -> void:
	if spec.has("gives"):
		GameState.give_key(spec["gives"])
	if spec.has("flag"):
		GameState.flags[spec["flag"]] = true

func _spawn_enemies() -> void:
	for spec in level.enemy_specs:
		var e := Enemy.new()
		var at: Array = spec["at"]
		e.position = level.cell_pos(at[0], at[1])
		e.arena = level.rect
		e.target = player
		e.max_hp = float(spec.get("hp", 40.0))
		e.damage = float(spec.get("damage", 8.0))
		e.speed = float(spec.get("speed", 2.3))
		e.xp_reward = int(spec.get("xp", 12))
		e.model_key = spec.get("model", "")
		e.beast = spec.get("beast", "")
		e.capsule_drop = spec.get("drop", "")
		e.food_drop = spec.get("food", "")
		e.behavior = spec.get("behavior", "chase")
		e.tier = int(spec.get("tier", 1))
		e.display_name = spec.get("name", "Enemy")
		e.blocker = level.is_blocked
		if spec.has("boss"):  # {"phases": [0.5], "heal_on_phase": 0.6, "absorbs_ki": true, "drain": 0.5}
			var b: Dictionary = spec["boss"]
			e.kit = BossKit.new(e, b.get("phases", []))
			e.kit.heal_on_phase = float(b.get("heal_on_phase", 0.0))
			e.kit.absorbs_ki = bool(b.get("absorbs_ki", false))
			e.kit.drain_on_contact = float(b.get("drain", 0.0))
		if spec.has("tint"):
			e.tint = Level._color(spec["tint"])
		add_child(e)
		if spec.has("outfit") and e.get_child_count() > 0 and e.model_key != "":
			Outfits.apply(e.get_child(0), spec["outfit"])

## Placed pickups (capsules hidden around the map) are collected once; the flag remembers.
func _spawn_pickups() -> void:
	for i in level.pickup_specs.size():
		var spec: Dictionary = level.pickup_specs[i]
		var flag := str(spec.get("id", "pickup:%s:%d" % [level.id, i]))
		if GameState.flags.get(flag, false):
			continue
		var p := Pickup.new()
		p.kind = spec.get("kind", "red")
		p.flag = flag
		var at: Array = spec["at"]
		p.position = level.cell_pos(at[0], at[1])
		add_child(p)

func _process(_delta: float) -> void:
	if GameState.input_locked or player.cinematic:
		return
	var ex := level.exit_at(player.position)
	if ex.is_empty():
		_exits_armed = true
		return
	if not _exits_armed:
		return  # standing on the exit we arrived through
	_exits_armed = false
	var to: String = ex.get("to", "world")
	if to == "world":
		GameState.travel_world(level.id)
	else:
		GameState.travel(to, ex.get("spawn", "default"))
