extends Node3D
## Headless rule checks: python tools/run.py test. Prints PASS/FAIL lines and quits with
## exit code 1 on any failure. Uses its own save file, so a real save is never touched.

var _fails := 0

func _ready() -> void:
	GameState.save_path = "user://test_save.json"
	_test_caps()
	_test_charge()
	_test_save_round_trip()
	await _test_fixtures()
	await _test_behaviors()
	await _test_moves()
	await _test_quests()
	await _test_boss_kit()
	await _test_content()
	await _test_cloth()
	if FileAccess.file_exists(GameState.save_path):
		DirAccess.remove_absolute(GameState.save_path)
	print("TESTS DONE: %d failure(s)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

func _check(cond: bool, what: String) -> void:
	if cond:
		print("PASS ", what)
	else:
		_fails += 1
		print("FAIL ", what)

func _test_caps() -> void:
	GameState.new_run()
	GameState.base_stats["strength"] = GameState.STAT_CAP - 2
	_check(GameState.add_capsule("strength", 5) == 2, "capsule gain stops at the stat cap")
	GameState.stat_points = 3
	_check(not GameState.spend_point("strength"), "no points into a capped stat")
	_check(GameState.spend_point("power"), "points still go into other stats")
	GameState.level = GameState.LEVEL_CAP - 1
	GameState.add_xp(100000000)
	_check(GameState.level == GameState.LEVEL_CAP and GameState.xp == 0, "levels stop at the cap")

func _test_charge() -> void:
	GameState.new_run()
	_check(GameState.charge_info()["name"] == "Basic Charge", "a new run starts at Basic Charge")
	GameState.learn_charge(2)
	GameState.learn_charge(1)
	_check(GameState.charge_tier == 2, "learning a lower tier never lowers the charge")
	GameState.start_power_fantasy()
	_check(GameState.charge_info()["name"] == "Perfect Charge", "the prologue has Perfect Charge")
	GameState.amnesia_reset()
	_check(GameState.charge_tier == 0, "the throw strips it back to Basic")

func _test_save_round_trip() -> void:
	GameState.new_run()
	GameState.level = 7
	GameState.base_stats["power"] = 12
	GameState.charge_tier = 3
	GameState.flags["test_flag"] = true
	GameState.give_item("ki_ring")
	GameState.equipment["acc1"] = "ki_ring"
	GameState.key_items.append("rusty_key")
	GameState.dishes.append("west_city_ramen")
	GameState.current_level = "wasteland"
	GameState.save_game(Vector3(12.5, 0, 30.0))
	GameState.new_run()
	_check(GameState.load_game(), "the save loads")
	_check(GameState.level == 7 and GameState.base_stats["power"] == 12, "level and stats survive a save")
	_check(GameState.charge_tier == 3 and GameState.flags.get("test_flag", false), "charge tier and flags survive")
	_check(GameState.equipment["acc1"] == "ki_ring" and GameState.has_key("rusty_key"), "gear and key items survive")
	_check("west_city_ramen" in GameState.dishes, "the Menu survives")
	_check(GameState.pending_level == "wasteland" and GameState.pending_pos.is_equal_approx(Vector3(12.5, 0, 30.0)), "Oto reloads where she saved")

func _test_fixtures() -> void:
	GameState.new_run()
	var lv := Level.load_level("dev_fixtures")
	add_child(lv)
	var by_type := {}
	for f in lv.fixtures:
		var fx := Fixture.new()
		fx.setup(lv, f)
		add_child(fx)
		by_type[f["type"]] = fx
	await get_tree().process_frame
	var gate: Fixture = by_type["level_gate"]
	var cell: Vector2i = gate.cells[0]
	var at := lv.cell_pos(cell.x, cell.y)
	_check(lv.is_blocked(at), "a level 5 gate blocks at level 1")
	GameState.level = 5
	await get_tree().process_frame
	_check(not lv.is_blocked(at), "the gate opens at level 5")
	var bridge: Fixture = by_type["bridge"]
	var water: Vector2i = bridge.cells[0]
	_check(lv.is_blocked(lv.cell_pos(water.x, water.y)), "water under a retracted bridge is blocked")
	GameState.flags["dev_switch"] = true
	await get_tree().process_frame
	_check(not lv.is_blocked(lv.cell_pos(water.x, water.y)), "the bridge extends when its switch flag is set")
	var rock: Fixture = by_type["breakable_rock"]
	var rc: Vector2i = rock.cells[0]
	rock.hurt(100.0, Vector3.FORWARD, false)
	_check(not lv.is_blocked(lv.cell_pos(rc.x, rc.y)) and GameState.flags.get(rock.id, false), "a broken rock clears its cells and stays broken")
	var door: Fixture = by_type["key_door"]
	var dc: Vector2i = door.cells[0]
	_check(lv.is_blocked(lv.cell_pos(dc.x, dc.y)), "a key door blocks without its key")
	lv.queue_free()

## Runs enemies against a stationary Oto for a few simulated seconds.
func _test_behaviors() -> void:
	GameState.new_run()
	GameState.flags["no_death"] = true
	var arena := Rect2(-8, -8, 16, 16)
	var player := Player.new()
	player.arena = arena
	player.position = Vector3(-6, 0, 0)
	add_child(player)
	player.cinematic = false
	var charger := _enemy("charger", Vector3(2, 0, 0), arena, player)
	var shooter := _enemy("shooter", Vector3(0, 0, 6), arena, player)
	var pack: Array = []
	for i in 3:
		pack.append(_enemy("pack", Vector3(-6 + i, 0, -5), arena, player))
	var seen := {}
	var max_lunging := 0
	var min_shooter_dist := 99.0
	for frame in 400:
		await get_tree().physics_frame
		seen[charger.state] = true
		min_shooter_dist = minf(min_shooter_dist, shooter.position.distance_to(player.position)) if frame > 120 else min_shooter_dist
		var lunging := 0
		for e: Enemy in pack:
			if e.state == "lunge":
				lunging += 1
		max_lunging = maxi(max_lunging, lunging)
	_check(seen.has("windup") and seen.has("dash"), "a charger winds up, then dashes")
	_check(seen.has("stunned"), "a charger that runs into the arena edge is stunned")
	_check(min_shooter_dist > 3.5, "a shooter keeps its distance (closest %.1f m)" % min_shooter_dist)
	_check(max_lunging <= 1, "only one of a pack lunges at a time")
	_check(player.hp < player.max_hp, "the enemies actually hit Oto")
	for n: Node in [player, charger, shooter] + pack:
		n.queue_free()
	await get_tree().process_frame

## Drives the real input actions: a held attack lands a heavy strike; Ki Blast streams.
func _test_moves() -> void:
	GameState.new_run()
	GameState.flags["no_death"] = true
	var player := Player.new()
	player.arena = Rect2(-10, -10, 20, 20)
	add_child(player)
	player.facing = Vector3(0, 0, 1)
	var dummy := _enemy("chase", Vector3(0, 0, 1.2), player.arena, player)
	dummy.speed = 0.0
	dummy.damage = 0.0
	dummy.max_hp = 500.0
	dummy.hp = 500.0
	Input.action_press("attack")
	for i in 60:
		await get_tree().physics_frame
	Input.action_release("attack")
	var launched := false
	for i in 4:
		await get_tree().physics_frame
		launched = launched or dummy.knock.length() > 5.0
	_check(launched, "holding attack and releasing lands a heavy, launching strike")
	GameState.ki_move_index = GameState.ki_moves.find("ki_blast")
	player.ki = player.max_ki
	Input.action_press("special")
	var shots := 0
	for i in 40:
		await get_tree().physics_frame
		for n in get_children():
			if n is KiShot and n.small and not n.has_meta("counted"):
				n.set_meta("counted", true)
				shots += 1
	Input.action_release("special")
	_check(shots >= 4 and player.ki < player.max_ki, "Ki Blast fires a stream of small shots (%d)" % shots)
	player.queue_free()
	dummy.queue_free()
	await get_tree().process_frame

func _test_boss_kit() -> void:
	GameState.new_run()
	var arena := Rect2(-10, -10, 20, 20)
	var boss := _enemy("chase", Vector3(0, 0, 5), arena, null)
	boss.max_hp = 100.0
	boss.hp = 100.0
	boss.kit = BossKit.new(boss, [0.5, 0.25])
	boss.kit.absorbs_ki = true
	boss.kit.heal_on_phase = 0.6
	var fired: Array = []
	boss.kit.phase.connect(func(i: int, _f: float) -> void: fired.append(i))
	boss.hp = 80.0
	boss.hurt(10.0, Vector3.FORWARD, false, "ki")
	_check(is_equal_approx(boss.hp, 90.0), "a ki-absorbing boss heals from ki shots")
	boss.hurt(45.0, Vector3.FORWARD, false)
	_check(fired == [0] and is_equal_approx(boss.hp, 60.0), "falling to 50% fires phase 0 once and heals to 60%")
	boss.hurt(40.0, Vector3.FORWARD, false)
	_check(fired == [0, 1], "phases fire in order, once each")
	var saiyan := LifeSaiyan.new()
	add_child(saiyan)
	var beats: Array = []
	saiyan.mid_reached.connect(func() -> void: beats.append("mid"))
	saiyan.threshold_reached.connect(func() -> void: beats.append("end"))
	saiyan.hurt(saiyan.max_hp * 0.5, Vector3.FORWARD, false)
	saiyan.hurt(saiyan.max_hp * 0.3, Vector3.FORWARD, false)
	_check(beats == ["mid", "end"] and saiyan.frozen and is_equal_approx(saiyan.hp, saiyan.max_hp * 0.25), "the prologue boss keeps its two beats on the kit")
	var p := Player.new()
	p.arena = arena
	add_child(p)
	var weak := _enemy("chase", Vector3(3, 0, 3), arena, null)
	var strong := _enemy("chase", Vector3(-3, 0, 3), arena, null)
	strong.max_hp = 4000.0
	strong.damage = 80.0
	await get_tree().process_frame
	_check(Hud.band(weak, p) <= 1 and Hud.band(strong, p) == 3, "ki sense reads a dummy as weaker/even and a brute as overwhelming")
	for n: Node in [boss, saiyan, p, weak, strong]:
		n.queue_free()
	await get_tree().process_frame

func _test_content() -> void:
	GameState.new_run()
	Overlay.auto = true
	for k: String in Beast.KINDS:
		var b := Beast.make(k)
		_check(b.legs.size() > 0 or b.wings.size() > 0, "the %s beast has moving parts" % k)
		b.free()
	var arena := Rect2(-30, -30, 60, 60)
	var p := Player.new()
	p.arena = arena
	add_child(p)
	var far := _enemy("chase", Vector3(20, 0, 0), arena, p)
	far.beast = "wolf"
	for i in 60:
		await get_tree().physics_frame
	_check(not far.engaged and far.position.distance_to(Vector3(20, 0, 0)) < 6.0, "a beast out of aggro range wanders near home")
	far.position = Vector3(6, 0, 0)
	await get_tree().physics_frame
	_check(far.engaged, "a beast engages once Oto is in range")
	var gohan := {"talk": "gohan_fishing", "lines": ["Gohan|The fish are biting today, Miss Oto!"]}
	await Talks.run(gohan, p)
	_check(GameState.flags.get("paozu_fished", false), "Gohan teaches fishing when she has not learned it")
	var yaj := {"talk": "yajirobe", "dish": "yajirobe_rice", "lines": ["Yajirobe|What? I'm on break."]}
	await Talks.run(yaj, p)
	await Talks.run(yaj, p)
	_check(GameState.senzu == 1 and "yajirobe_rice" in GameState.dishes, "Yajirobe serves his rice once and hands out one senzu at a time")
	p.hp = 1.0
	PauseMenu._eat_senzu()
	_check(GameState.senzu == 0 and is_equal_approx(p.hp, p.max_hp), "a senzu from the bag restores Oto fully")
	_check(Dishes.DB.size() >= 8, "the Menu has enough dishes to reach the 8-dish milestone")
	Overlay.auto = false
	far.queue_free()
	p.queue_free()
	await get_tree().process_frame

## Oto's scapular: trails when she runs, settles when she stops, stays in front of her legs
## and above the ground, and survives a fling without blowing up.
func _test_cloth() -> void:
	GameState.new_run()
	var ch := Outfits.make_character("oto")
	add_child(ch)
	var front: ClothPanel = ch.find_child("ScapularFront", true, false)
	_check(front != null and ch.find_children("*", "ClothPanel", true, false).size() >= 6, "Oto's outfit has its cloth panels")
	for i in 20:
		await get_tree().physics_frame
	var outfit := front.get_parent() as Node3D
	var bottom := func() -> Vector3:
		var p := front.particles()
		return outfit.global_transform.affine_inverse() * p[p.size() - front.cols / 2 - 1]
	var rest: Vector3 = bottom.call()
	for i in 30:  # run along +X at 8 m/s
		ch.position.x += 8.0 / 60.0
		await get_tree().physics_frame
	var running: Vector3 = bottom.call()
	_check(running.x < rest.x - 0.05, "the scapular trails behind when she runs (%.2f m)" % (rest.x - running.x))
	for i in 150:
		await get_tree().physics_frame
	var settled: Vector3 = bottom.call()
	_check(absf(settled.x - rest.x) < 0.04, "it settles again when she stops")
	var behind := false
	var finite := true
	for p in front.particles():
		var lp := outfit.global_transform.affine_inverse() * p
		behind = behind or lp.z < 0.0
		finite = finite and p.is_finite()
	_check(not behind, "the front panel never passes behind her legs")
	_check(finite and front.lowest_y() >= front.floor_y - 0.001, "the cloth stays finite and above the ground")
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ch, "position", ch.position + Vector3(-14, 22, 8), 1.5)
	tw.tween_property(ch, "rotation:x", TAU * 2.0, 1.5)
	await tw.finished
	finite = true
	var pin := outfit.global_transform * front.pin_center
	var far := 0.0
	for p in front.particles():
		finite = finite and p.is_finite()
		far = maxf(far, p.distance_to(pin))
	_check(finite and far < front.length * 1.6, "a fling through the air does not tear the cloth apart")
	ch.queue_free()
	await get_tree().process_frame

func _enemy(kind: String, pos: Vector3, arena: Rect2, target: Player) -> Enemy:
	var e := Enemy.new()
	e.behavior = kind
	e.position = pos
	e.arena = arena
	e.target = target
	add_child(e)
	return e

func _test_quests() -> void:
	GameState.new_run()
	Overlay.auto = true
	_check(Quests.split()[0].is_empty(), "no quests before the story starts")
	GameState.amnesia_reset()
	_check("a_place_to_eat" in Quests.split()[0], "waking on Mt. Paozu starts A Place to Eat")
	for f: String in ["paozu_fished", "paozu_chopsticks", "paozu_sparred"]:
		GameState.flags[f] = true
	_check("a_place_to_eat" in Quests.split()[1], "its three steps complete it")
	var hp0 := GameState.max_hp()
	for id: String in Dishes.DB.keys().slice(0, 3):
		Dishes.log_dish(id)
	_check(not Dishes.log_dish("noodle_bowl"), "a dish is only logged once")
	_check(is_equal_approx(GameState.max_hp(), hp0 + 20.0), "three dishes raise max HP by 20")
	# Roshi's lesson: talk, charge from empty to full standing still, talk again.
	var player := Player.new()
	player.arena = Rect2(-10, -10, 20, 20)
	add_child(player)
	var roshi := {"talk": "roshi_lesson", "lines": ["Master Roshi|Ho ho."]}
	await Talks.run(roshi, player)
	_check(Quests.started("roshi_lesson"), "talking to Roshi starts his lesson")
	var fired := [false]
	player.charged_from_empty.connect(func() -> void:
		fired[0] = true
		GameState.flags["roshi_still_charge"] = true)
	GameState.charge_tier = 4  # speeds the test up; the rule is the same at every tier
	player.ki = 0.0
	Input.action_press("charge")
	for i in 260:
		await get_tree().physics_frame
		if fired[0]:
			break
	Input.action_release("charge")
	_check(fired[0], "charging from empty to full without moving is noticed")
	GameState.charge_tier = 1
	await Talks.run(roshi, player)
	_check(GameState.charge_tier == 2 and Quests.complete("roshi_lesson"), "Roshi teaches Focused Charge")
	Overlay.auto = false
	player.queue_free()
