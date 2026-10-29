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
	await _test_sigil_and_silver()
	await _test_face()
	await _test_body_shape()
	await _test_oto_owned()
	await _test_women()
	_test_ui()
	_test_home()
	_test_regions()
	await _test_cutscene()
	await _test_ki_techniques()
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
	for fx: Fixture in by_type.values():
		fx.queue_free()
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

## Drives the real input actions: a held attack lands the flurry; Ki Blast streams.
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
	var blows := 0
	var last_hp := dummy.hp
	for i in 60:
		await get_tree().physics_frame
		if dummy.hp < last_hp:
			blows += 1
			last_hp = dummy.hp
		launched = launched or dummy.knock.length() > 5.0
	_check(launched and blows == 4, "holding attack and releasing lands a four-punch flurry, the last one launching (%d blows)" % blows)
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
	front.wind = 0.0  # measure the settling alone: the wind would roll it round her forward thigh
	for i in 90:  # the rig moves her from the T-pose into her standing pose; let the cloth settle
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
	_check(absf(settled.x - rest.x) < 0.04, "it settles again when she stops (%.3f m off)" % absf(settled.x - rest.x))
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
	for i in 90:  # mid-spin it may trail far behind; what matters is that it comes back whole
		await get_tree().physics_frame
	finite = true
	var pin := outfit.global_transform * front.pin_center
	var far := 0.0
	for p in front.particles():
		finite = finite and p.is_finite()
		far = maxf(far, p.distance_to(pin))
	_check(finite and far < front.length * 1.2, "after a fling through the air the cloth hangs whole again (%.2f m)" % far)
	ch.queue_free()
	await get_tree().process_frame

## The Wall sigil sits on the front panel only and is engraved on both gauntlets; Shadow
## forms turn every bit of her outfit's gold silver, and base form turns it back.
func _test_sigil_and_silver() -> void:
	GameState.new_run()
	GameState.max_form = 3
	var p := Player.new()
	add_child(p)
	await get_tree().physics_frame
	var front: ClothPanel = p.visual.find_child("ScapularFront", true, false)
	var back: ClothPanel = p.visual.find_child("ScapularBack", true, false)
	_check(front.decal_texture != null and back.decal_texture == null, "the sigil is on the front panel only")
	_check(p.visual.find_children("SigilEngraving_*", "", true, false).size() == 2, "both gauntlets carry the engraved sigil")
	var mats: Array = p.visual.get_meta("gold_mats", [])
	var is_silver := func() -> bool:
		for m: StandardMaterial3D in mats:
			if not m.albedo_color.is_equal_approx(m.get_meta("silver_color")):
				return false
		return not front.color_swap.is_empty()
	_check(mats.size() >= 4 and not is_silver.call(), "her gold is gold in base form")
	p.set_form(1, true)
	_check(is_silver.call(), "Shadow Saiyan turns all of the outfit's gold silver")
	var black := true
	for m: StandardMaterial3D in p.visual.get_meta("hair_mats", []):
		black = black and m.albedo_color.is_equal_approx(Color(0, 0, 0))
	_check(black, "and her hair pitch black")
	p.set_form(0, true)
	var gold := true
	for m: StandardMaterial3D in mats:
		gold = gold and m.albedo_color.is_equal_approx(m.get_meta("base_color"))
	_check(gold and front.color_swap.is_empty(), "back in base form, the gold returns")
	p.queue_free()
	await get_tree().process_frame

## Faces (face.gd, face_rig.gd): every part draws, the plates sit just off the head, the eyes
## blink, the mouth moves only while she talks, Shadow forms swap in the void eyes.
func _test_face() -> void:
	var painted := func(img: Image) -> bool:
		if img == null:
			return false
		for y in range(0, img.get_height(), 3):
			for x in range(0, img.get_width(), 3):
				if img.get_pixel(x, y).a > 0.5:
					return true
		return false
	var skin: Color = FaceParts.SKINS["dusk"]
	var ok := true
	for s: String in FaceParts.EYES:
		for st: String in FaceParts.EYE_STATES:
			ok = ok and painted.call(Face.layer_image({"eyes": s}, "eyes", st, "", skin))
	_check(ok, "every eye style draws in every state")
	ok = true
	for s: String in FaceParts.BROWS:
		for st: String in FaceParts.BROW_STATES:
			ok = ok and painted.call(Face.layer_image({"brows": s}, "brows", st, "", skin))
	_check(ok, "every brow style draws in every mood")
	ok = true
	for s: String in FaceParts.MOUTHS:
		for st: String in FaceParts.MOUTH_SHAPES:
			ok = ok and painted.call(Face.layer_image({"mouth": s}, "mouth", st, "", skin))
	_check(ok, "every mouth style draws every shape")
	ok = Face.layer_image({"nose": "none"}, "nose", "marks", "", skin) == null
	for s: String in ["button", "pointed", "broad"]:
		ok = ok and painted.call(Face.layer_image({"nose": s}, "nose", "marks", "", skin))
	_check(ok, "noses draw their marks (and 'none' draws nothing)")
	ok = NoseInks.names().size() == 40
	for id: String in NoseInks.names():
		ok = ok and painted.call(Face.layer_image({"nose": "wedge", "nose_ink": id}, "nose", "marks", "", skin))
	_check(ok, "all 40 noses from the reference sheet draw")
	_check(painted.call(Face.layer_image({"ears": "dbz"}, "ears", "on", "", skin)), "the DBZ ear lines draw")

	GameState.new_run()
	GameState.max_form = 3
	var t0 := Time.get_ticks_msec()
	var p := Player.new()
	add_child(p)
	await get_tree().physics_frame
	var face: FaceRig = p.visual.get_meta("face", null)
	_check(face != null and face.layers.size() == 6 and face.layers.has("ear_l") and face.layers.has("ear_r"), "Oto has a face with its four layers and both ears (built in %d ms)" % (Time.get_ticks_msec() - t0))
	face.set_process(false)
	var frame := Face.head_frame(p.visual)
	var verts: PackedVector3Array = Rig.fit_arrays(face.layers["eyes"])[Mesh.ARRAY_VERTEX]
	var axis: Vector3 = frame["axis"]
	var near := true
	for i in range(0, verts.size(), 7):
		var v := verts[i]
		var from := Vector3(axis.x, v.y, axis.z)
		var hit := Face.cast(frame["tm"], frame["xf"], from, (v - from).normalized())
		var gap := (v - from).length() - ((hit["position"] as Vector3) - from).length() if not hit.is_empty() else -1.0
		near = near and gap > 0.0003 and gap < 0.0035
	_check(near, "the face plates sit 0.3-3.5 mm off the head")
	var open_tex: Texture2D = (face.layers["eyes"].material_override as StandardMaterial3D).albedo_texture
	face.blink()
	face._process(0.07)
	var closed_now := face.shown("eyes") == "closed"
	face._process(0.3)
	var back_tex: Texture2D = (face.layers["eyes"].material_override as StandardMaterial3D).albedo_texture
	_check(closed_now and face.shown("eyes") == "open" and back_tex == open_tex, "a blink closes the eyes and opens them again")
	_check(face.shown("mouth") == "closed", "her mouth is closed when she is not speaking")
	Overlay.talking.emit("Oto", true)
	face._process(0.01)
	var moving := face.shown("mouth") != "closed"
	Overlay.talking.emit("Oto", false)
	_check(moving and face.shown("mouth") == "closed", "the mouth moves while her line types and closes after")
	Overlay.talking.emit("Bulma", true)
	face._process(0.01)
	_check(face.shown("mouth") == "closed", "someone else's line does not move her mouth")
	Overlay.talking.emit("Bulma", false)
	p.set_form(1, true)
	_check(face.variant == "void", "Shadow Saiyan gives her the void eyes")
	p.set_form(0, true)
	_check(face.variant == "" and face.shown("eyes") == "open", "base form gives her own eyes back")
	Outfits.apply(p.visual, "oto")
	await get_tree().process_frame
	var faces := p.visual.find_children("Face", "FaceRig", true, false)
	_check(faces.size() == 1 and p.visual.get_meta("face") == faces[0], "the face survives dressing her again")
	# the rig: skeleton, animations, and the outfit skinned to it
	var ap: AnimationPlayer = p.visual.get_meta("anim", null)
	var sk: Skeleton3D = p.visual.get_meta("skeleton", null)
	var names := ["idle", "walk", "hot_walk", "l_punch", "r_punch", "cross_punch", "quad_punch",
			"kick", "roundhouse_kick", "flying_kick", "flying", "falling", "fall_impact",
			"hit_reaction", "taking_punch", "stunned", "defeated"]
	var has_all := ap != null
	for n: String in names:
		has_all = has_all and ap.has_animation(n)
	_check(has_all and sk != null and sk.get_bone_count() == 65, "Oto is rigged: a 65-bone skeleton and her seventeen animations")
	var lib := Rig.library("oto")
	var drift := 0.0
	for n: String in Rig.RIGS["oto"]["in_place"]:
		var an := lib.get_animation(n)
		for i in an.get_track_count():
			if an.track_get_type(i) == Animation.TYPE_POSITION_3D and an.track_get_path(i).get_subname(0) == "mixamorig_Hips":
				var first: Vector3 = an.track_get_key_value(i, 0)
				for k in an.track_get_key_count(i):
					var v: Vector3 = an.track_get_key_value(i, k)
					drift = maxf(drift, Vector2(v.x - first.x, v.z - first.z).length())
	_check(drift < 0.0001, "the flying kick and the stun play in place (the hips do not travel)")
	var hits_ok := true
	for n: String in Rig.RIGS["oto"]["hits"]:
		for h: float in Rig.RIGS["oto"]["hits"][n]:
			hits_ok = hits_ok and h > 0.0 and h < lib.get_animation(n).length
	_check(hits_ok and lib.get_animation("flying").loop_mode == Animation.LOOP_LINEAR and lib.get_animation("falling").loop_mode == Animation.LOOP_LINEAR
			and lib.get_animation("kick").loop_mode == Animation.LOOP_NONE, "every strike lands inside its animation; flying and falling loop, kicks do not")
	var unskinned := 0
	for mi: MeshInstance3D in p.visual.get_node("Outfit").find_children("*", "MeshInstance3D", true, false):
		if not (mi is ClothPanel) and mi.skin == null:
			unskinned += 1
	_check(unskinned == 0, "every outfit, hair and face piece is skinned to her skeleton (%d not)" % unskinned)
	var follows := true
	for cp: ClothPanel in p.visual.find_children("*", "ClothPanel", true, false):
		follows = follows and cp.pin_node != null
	_check(follows, "her hanging cloth is pinned to bones")
	# her hair stops short of her ears (about 97-118 degrees round, 48 mm below to 35 mm above
	# the eye line on her head)
	var shell: MeshInstance3D = p.visual.find_child("hair_shell", true, false)
	var hv: PackedVector3Array = Rig.fit_arrays(shell)[Mesh.ARRAY_VERTEX]
	var bare := true
	for v in hv:
		var d := v - axis
		var deg := rad_to_deg(absf(atan2(d.x, d.z)))
		var y_mm := d.y * 1000.0
		bare = bare and not (deg > 97.0 and deg < 118.0 and y_mm > -48.0 and y_mm < 35.0)
	_check(bare, "her hair does not touch her ears")
	# fitted clothing: no point of the bodice, sash or trousers inside her body
	var body := Garment.body_frame(p.visual)
	var outside := true
	var pieces := 0
	var worst := {}
	for n: String in ["bodice", "sash", "trousers_hips", "trouser_leg_l", "trouser_leg_r"]:
		var mi: MeshInstance3D = p.visual.find_child(n, true, false)
		if mi == null:
			outside = false
			continue
		pieces += 1
		var ax: Callable = mi.get_meta("axis")
		var gv: PackedVector3Array = Rig.fit_arrays(mi)[Mesh.ARRAY_VERTEX]
		for i in range(0, gv.size(), 3):
			var o: Vector3 = ax.call(gv[i].y)
			var dir := Vector3(gv[i].x - o.x, 0, gv[i].z - o.z)
			var hit := Face.cast(body["tm"], body["xf"], o, dir.normalized())
			if not hit.is_empty() and ((hit["position"] as Vector3) - o).length() > dir.length() + 0.0005:
				outside = false
				var depth := ((hit["position"] as Vector3) - o).length() - dir.length()
				if depth > float(worst.get(n, [0.0])[0]):
					worst[n] = [depth, gv[i]]
	_check(outside and pieces == 5, "her bodice, sash and trousers sit outside her body everywhere" + ("" if worst.is_empty() else " %s" % worst))
	# the outer layer and the gauntlets: no point inside her body
	var outer_ok := true
	var bad := {}
	var outer := p.visual.find_children("scapular_top_*", "", true, false) + p.visual.find_children("gauntlet_?", "", true, false) 		+ p.visual.find_children("hand_wrap_?", "", true, false) + p.visual.find_children("shin_wrap_?", "", true, false)
	for mi: MeshInstance3D in outer:
		var ov: PackedVector3Array = Rig.fit_arrays(mi)[Mesh.ARRAY_VERTEX]
		var on: PackedVector3Array = Rig.fit_arrays(mi)[Mesh.ARRAY_NORMAL]
		for i in range(0, ov.size(), 5):
			# a point is inside if a ray from it out along +Z/-Z (scapular) or up (gauntlet) meets
			# the body an odd number of times; count crossings with short hops
			var inside := false
			var o := ov[i]
			var dir := on[i]  # straight out from the cloth
			var cur := o
			for hop in 16:
				var hit := Face.cast(body["tm"], body["xf"], cur, dir)
				if hit.is_empty():
					break
				inside = not inside
				cur = (hit["position"] as Vector3) + dir * 0.0005
			outer_ok = outer_ok and not inside
			if inside:
				bad[mi.name] = int(bad.get(mi.name, 0)) + 1
	_check(outer_ok and outer.size() == 8, "the scapular, gauntlets, hand and shin wraps sit outside her body (%d pieces)%s" % [outer.size(), "" if bad.is_empty() else " inside: %s" % bad])
	_check(p.visual.find_children("SigilEngraving_*", "", true, false).size() == 2, "the fitted gauntlets still carry the sigil")
	p.queue_free()
	await get_tree().process_frame

## Oto's body, outfit and cloth are hers (docs/BODY_STUDY.md, docs/OTO_OUTFIT.md): her own build,
## the soft tint on her chest, nobody else wearing her pieces or sharing her shape, the scapular
## over her seat.
func _test_oto_owned() -> void:
	GameState.new_run()
	var oto := Outfits.make_character("oto")
	add_child(oto)
	var plain := ModelLoader.make("oto")
	var oto_body := (oto.get_child(0).get_child(0) as MeshInstance3D).mesh
	var plain_body := (plain.get_child(0).get_child(0) as MeshInstance3D).mesh
	_check(Outfits.is_oto(oto) and oto_body.get_aabb().size.z > plain_body.get_aabb().size.z + 0.02, "Oto spawns with her own body, deeper at the bust and seat than the plain base")
	plain.free()
	# the soft darker area on each breast: a hint only, no edge, subtle, front and chest only
	var arrs := oto_body.surface_get_arrays(0)
	var cols: PackedColorArray = arrs[Mesh.ARRAY_COLOR]
	var verts: PackedVector3Array = arrs[Mesh.ARRAY_VERTEX]
	var lo := verts[0]
	var hi := verts[0]
	for v in verts:
		lo = lo.min(v)
		hi = hi.max(v)
	var tinted := 0
	var darkest := 1.0
	var placed := true
	for i in cols.size():
		if cols[i] != Color.WHITE:
			tinted += 1
			darkest = minf(darkest, cols[i].b)
			var w := (verts[i].y - lo.y) / (hi.y - lo.y)
			placed = placed and w > 0.62 and w < 0.78 and verts[i].z > (lo.z + hi.z) * 0.5 and absf(verts[i].x) < 0.12 * (hi.y - lo.y)
	_check(tinted >= 20 and tinted <= 800 and darkest > 0.6 and placed, "a soft darker area on each breast (%d points, darkest %.2f, on the chest, facing front)" % [tinted, darkest])
	var skin_mi := _skin_body(oto)
	_check(skin_mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] != null, "the skinned body carries the same tint")
	# nobody else wears her outfits, has her pieces or her proportions
	var male := ModelLoader.make("male_base")
	add_child(male)
	Outfits.apply(male, "oto")
	var not_hers := ModelLoader.make("oto")
	not_hers.set_meta("custom_body", true)  # a female body with some other shape
	add_child(not_hers)
	Outfits.apply(not_hers, "oto_stage")
	_check(male.get_node_or_null("Outfit") == null and not_hers.get_node_or_null("Outfit") == null, "her outfits refuse any body that is not hers")
	var stray: Array = []
	var own: Dictionary = BodyShape.amounts_of(BodyShape.OTO)
	for n: String in Outfits.PRESETS:
		if n in Outfits.OTO_PRESETS:
			continue
		var sp: Dictionary = Outfits.PRESETS[n]
		for part: String in ["top", "bottom"]:
			if sp.has(part) and (Outfits.OTO_ONLY[part] as Array).has((sp[part] as Dictionary).get("style", "")):
				stray.append(n)
		for a: Dictionary in sp.get("acc", []):
			if (Outfits.OTO_ONLY["acc"] as Array).has(a.get("style", "")):
				stray.append(n)
		if sp.has("build") and BodyShape.same_shape(BodyShape.amounts_of(sp["build"]), own):
			stray.append(n)
	_check(stray.is_empty(), "no other preset wears her pieces or has her build %s" % [stray])
	var twins: Array = []
	var table := BodyShape.load_presets()
	for n: String in table:
		if n != BodyShape.OTO and BodyShape.same_shape(table[n], own):
			twins.append(n)
	_check(not own.is_empty() and twins.is_empty(), "no saved body shape but hers has her exact proportions %s" % [twins])
	var shaper := BodyShape.new(load(BodyShape.SOURCE) as Mesh)
	var other_shape := shaper.dressed({"bust": 1.0})
	var her_shape := shaper.dressed(own)
	add_child(other_shape)
	add_child(her_shape)
	_check(other_shape.find_child("ScapularBack", true, false) == null and her_shape.find_child("ScapularBack", true, false) != null, "the body editor dresses only her own shape in her outfit")
	# the scapular hangs over her seat
	var back: ClothPanel = oto.find_child("ScapularBack", true, false)
	_check(back != null, "her back scapular is a cloth panel")
	for i in 120:
		await get_tree().physics_frame
	var bf := Garment.body_frame(oto)
	var seat := 0
	var through := 0
	for p in back.particles():
		var lp: Vector3 = oto.global_transform.affine_inverse() * p
		var hit := Face.cast(bf["tm"], bf["xf"], Vector3(lp.x, lp.y, -3.0), Vector3(0, 0, 1))
		if not hit.is_empty() and lp.y > 0.5:
			seat += 1
			if lp.z > (hit["position"] as Vector3).z + 0.003:
				through += 1
	_check(seat > 10 and through == 0, "the back scapular hangs outside her seat, not through it (%d of %d points inside)" % [through, seat])
	for n: Node in [oto, male, not_hers, other_shape, her_shape]:
		n.queue_free()
	await get_tree().process_frame

## The townswomen (npc_women.gd): dozens of them, each her own person, none with Oto's body or
## pieces, and their cast clothing outside their bodies.
func _test_women() -> void:
	var ids := NpcWomen.ids()
	_check(ids.size() >= 100 and NpcWomen.DESIGNS.size() >= 24, "there are dozens of townswomen (%d designs, %d with recolours)" % [NpcWomen.DESIGNS.size(), ids.size()])
	var names := {}
	var bad: Array = []
	var own: Dictionary = BodyShape.amounts_of(BodyShape.OTO)
	for id: String in ids:
		var sp := NpcWomen.spec(id)
		names[sp["name"]] = true
		if sp.get("build", "") == BodyShape.OTO or (sp.has("build") and BodyShape.same_shape(BodyShape.amounts_of(sp["build"]), own)):
			bad.append(id)
		for part: String in ["top", "bottom"]:
			if sp.has(part) and (Outfits.OTO_ONLY[part] as Array).has((sp[part] as Dictionary).get("style", "")):
				bad.append(id)
		for a: Dictionary in sp.get("acc", []):
			if (Outfits.OTO_ONLY["acc"] as Array).has(a.get("style", "")) or not (Outfits.ACCESSORIES as Array).has(a.get("style", "")):
				bad.append(id)
		if Face.look(id).is_empty() or not FaceParts.EYES.has(Face.look(id).get("eyes", "")) or not FaceParts.BROWS.has(Face.look(id).get("brows", "")) 				or not FaceParts.MOUTHS.has(Face.look(id).get("mouth", "")) or not FaceParts.NOSES.has(Face.look(id).get("nose", "none")):
			bad.append(id)
	_check(names.size() == ids.size(), "every townswoman has her own name (%d names for %d women)" % [names.size(), ids.size()])
	_check(bad.is_empty(), "no townswoman has Oto's body or pieces, and every face and accessory is a real part %s" % [bad])
	var a := NpcWomen.spec("woman_mei")
	var b := NpcWomen.spec("woman_mei_2")
	_check(a["top"]["style"] == b["top"]["style"] and a["top"]["color"] != b["top"]["color"] and a["hair"]["color"] != b["hair"]["color"],
		"a recolour keeps the cut and changes the clothes and hair colours")
	# cast clothing: no point of her top or trousers inside her body (a curvy build and the plain base)
	for id: String in ["woman_mei", "woman_riko", "woman_marisol"]:
		var w := Outfits.make_character(id)
		add_child(w)
		var body := Garment.body_frame(w)
		var pieces := 0
		var inside := 0
		var where := {}
		for mi: MeshInstance3D in w.find_children("*", "MeshInstance3D", true, false):
			if not mi.has_meta("axis"):
				continue
			pieces += 1
			var ax: Callable = mi.get_meta("axis")
			var gv: PackedVector3Array = Rig.fit_arrays(mi)[Mesh.ARRAY_VERTEX]
			for i in range(0, gv.size(), 5):
				var o: Vector3 = ax.call(gv[i].y)
				var dir := Vector3(gv[i].x - o.x, 0, gv[i].z - o.z)
				var hit := Face.cast(body["tm"], body["xf"], o, dir.normalized())
				if not hit.is_empty() and ((hit["position"] as Vector3) - o).length() > dir.length() + 0.0005:
					inside += 1
					where[mi.name] = [snappedf(((hit["position"] as Vector3) - o).length() - dir.length(), 0.0001), gv[i]]
		_check(pieces >= 1 and inside == 0, "%s's cast clothing sits outside her body (%d pieces, %d points inside) %s" % [NpcWomen.spec(id)["name"], pieces, inside, where])
		w.queue_free()
	await get_tree().process_frame

## The UI kit: speakers find their portraits, and a woman's portrait has real face art.
func _test_ui() -> void:
	_check(UiKit.speaker_look("Oto") == "oto" and UiKit.speaker_look("Mei") == "woman_mei" and UiKit.speaker_look("Goku") == "",
		"dialogue speakers find their portraits (Oto, a townswoman, and an emblem for the rest)")
	var tex := Face.texture("woman_lune", "eyes", "open", "", NpcWomen._c(NpcWomen.spec("woman_lune")["skin"]))
	_check(tex != null and tex.get_width() > 0, "a townswoman's portrait draws her own eyes")
	var known := true
	for id: String in Items.DB.keys() + Items.KEYS.keys() + Dishes.DB.keys():
		known = known and ItemIcons.tint(id) != UiKit.MUTED
	_check(known, "every gear piece, key item and dish has an icon colour")

## Capsule Corp, where Oto lives: every door of the house leads to a room that leads back,
## the house is reached from the lab and from West City, and each new dish has its cook.
func _test_home() -> void:
	var rooms := ["capsule_corp_home", "capsule_corp_kitchen", "capsule_corp_pantry", "capsule_corp_garden",
		"capsule_corp_gravity", "oto_room"]
	var data := {}
	for id: String in rooms + ["capsule_corp_lab", "west_city"]:
		data[id] = JSON.parse_string(FileAccess.get_file_as_string("res://levels/%s.json" % id))
	var broken: Array = []
	for id: String in data:
		for key: String in (data[id].get("exits", {}) as Dictionary):
			var ex: Dictionary = data[id]["exits"][key]
			var to: String = ex.get("to", "")
			if to == "world" or not data.has(to):
				continue
			if not (data[to].get("spawns", {}) as Dictionary).has(ex.get("spawn", "default")):
				broken.append("%s -> %s:%s" % [id, to, ex.get("spawn", "")])
	_check(broken.is_empty(), "every door in and around the house lands on a real spawn %s" % [broken])
	var home_exits: Array = []
	for ex: Dictionary in (data["capsule_corp_home"]["exits"] as Dictionary).values():
		home_exits.append(ex["to"])
	var all_rooms := true
	for id: String in rooms.slice(1):
		all_rooms = all_rooms and id in home_exits and data[id]["exits"]["1"]["to"] == "capsule_corp_home"
	var ways_in := 0
	for id: String in ["capsule_corp_lab", "west_city"]:
		for ex: Dictionary in (data[id]["exits"] as Dictionary).values():
			if ex["to"] == "capsule_corp_home":
				ways_in += 1
	_check(all_rooms and ways_in == 2, "the hall opens on all five rooms and her bedroom, and is reached from the lab and the city")
	var served := {}
	for id: String in data:
		for n: Dictionary in data[id].get("npcs", []):
			if n.has("dish"):
				served[n["dish"]] = true
	var missing: Array = []
	for d: String in ["briefs_shortcake", "freezer_ice_cream", "dome_fruit", "gravity_shake", "midnight_noodles"]:
		if not Dishes.DB.has(d) or not served.has(d):
			missing.append(d)
	_check(missing.is_empty(), "each Capsule Corp dish is on the Menu and has someone to serve it %s" % [missing])
	var den := 0
	for pr: Dictionary in data["oto_room"]["props"]:
		if pr["type"] in ["snack_shelf", "minifridge", "takeout_stack", "pizza_boxes", "bean_bag"]:
			den += 1
		_check(Props.DOCS.has(pr["type"]), "Oto's room prop %s exists" % pr["type"]) if not Props.DOCS.has(pr["type"]) else null
	_check(den >= 8, "her room is a food lover's den (%d snack, fridge and takeout props)" % den)

## The regions and the city (docs/REGIONS.md): each region is on the world map, has a save
## lantern, foes, pickups and a cook whose dish is on the Menu; every tile letter of the kit is
## known; the city's shops lead in and back out; nobody respawns in a wall.
func _test_regions() -> void:
	var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://levels/world.json"))
	var on_map := {}
	for loc: Dictionary in world["locations"]:
		on_map[loc["id"]] = loc
	var bad: Array = []
	for id: String in ["diablo_desert", "granite_peaks", "northern_ice_fields", "crystal_cavern"]:
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://levels/%s.json" % id))
		var lantern := false
		for pr: Dictionary in d.get("props", []):
			lantern = lantern or pr["type"] == "save_lantern"
		var cook := false
		for n: Dictionary in d.get("npcs", []):
			cook = cook or (n.has("dish") and Dishes.DB.has(n["dish"]))
		if not on_map.has(id) or not lantern or not cook or d.get("enemies", []).size() < 5 or d.get("pickups", []).size() < 4:
			bad.append(id)
		var lv := Level.new()
		lv.id = id
		lv.setup(d)
		for k: String in ["default"] + (["island"] if id == "crystal_cavern" else []):
			if lv.is_blocked(lv.spawn_point(k)):
				bad.append("%s:%s spawn blocked" % [id, k])
		for e: Dictionary in d.get("enemies", []):
			if lv.is_blocked(lv.cell_pos(e["at"][0], e["at"][1])):
				bad.append("%s: %s in a wall" % [id, e["name"]])
		lv.free()
	_check(bad.is_empty(), "the four regions are on the map, with a lantern, foes, pickups and a cook, and nothing starts in a wall %s" % [bad])
	var kit := true
	for ch: String in "KnqivwkhIgdVXuZ":
		kit = kit and Level.TILES.has(ch)
		if Level.TILES.has(ch) and Level.TILES[ch].has("prop"):
			kit = kit and Props.DOCS.has(Level.TILES[ch]["prop"])
	_check(kit, "every region-kit tile letter is in the legend, with a real prop")
	var wc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://levels/west_city.json"))
	var shops_ok := true
	for key: String in ["4", "5", "6"]:
		var ex: Dictionary = wc["exits"][key]
		var shop: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://levels/%s.json" % ex["to"]))
		var back: Dictionary = shop["exits"]["1"]
		shops_ok = shops_ok and back["to"] == "west_city" and (wc["spawns"] as Dictionary).has(back["spawn"])
	var furniture := 0
	for pr: Dictionary in wc["props"]:
		if pr["type"] in ["trash_bin", "hydrant", "vending_machine", "phone_booth", "bike_rack", "street_sign", "food_stall", "cafe_table", "hedge"]:
			furniture += 1
	_check(shops_ok and furniture >= 30, "West City's three shops lead in and back out, and its streets are furnished (%d pieces)" % furniture)
	var p := Player.new()
	add_child(p)
	p.respawn_at = Vector3(3, 0, 4)
	p.hp = 1.0
	p.iframes = 0.0
	GameState.in_location = false
	p.hurt(9999.0, p.position + Vector3(1, 0, 0))
	_check(p.position.distance_to(Vector3(3, 0, 4)) < 0.01, "with no save, a fallen Oto gets up at the location's spawn")
	p.queue_free()

## The cutscene director and the intro: the ki animations exist and play in place, the game
## opens on the intro, and it ends (or is skipped) on the title screen.
func _test_cutscene() -> void:
	var lib := Rig.library("oto")
	var ok := true
	for n: String in ["beam", "cast_spell", "ki_blast_1h", "ki_blast_2h", "ki_blast_2h_b", "ki_area", "ki_area_b"]:
		ok = ok and lib.has_animation(n)
	_check(ok, "the seven ki attack animations are in Oto's rig")
	_check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/intro.tscn", "the game opens on the intro cutscene")
	var src := FileAccess.get_file_as_string("res://scripts/cutscene/intro.gd")
	_check(src.contains("title.tscn") and src.contains("func finish"), "the intro ends on the title screen, and a skip goes there too")

## The ki techniques on the rig: the new two wait for the memory ladder, the Void Beam hurts
## what is in line and nothing beside it, the Void Burst hurts what is close, and shots leave
## from between her hands.
func _test_ki_techniques() -> void:
	GameState.new_run()
	_check(not ("void_beam" in GameState.ki_moves) and not ("void_burst" in GameState.ki_moves) and GameState.KI_MOVES.has("void_beam"),
		"Void Beam and Void Burst exist but are not in her starting kit (the memory ladder gives them back)")
	var arena := Rect2(-30, -30, 60, 60)
	var p := Player.new()
	p.arena = arena
	p.outfit = "oto"
	add_child(p)
	await get_tree().process_frame
	p.facing = Vector3(0, 0, 1)
	p.ki = p.max_ki
	var inline := _enemy("chase", Vector3(0, 0, 6), arena, null)
	var aside := _enemy("chase", Vector3(5, 0, 6), arena, null)
	for e: Enemy in [inline, aside]:
		e.max_hp = 9999.0
		e.hp = 9999.0
		e.set_physics_process(false)
		e.set_process(false)
	p._start_beam()
	for i in 20:
		p._update_beam(0.05)
	_check(inline.hp < 9999.0 and is_equal_approx(aside.hp, 9999.0), "the Void Beam hurts what is in line, and nothing beside it")
	var near := _enemy("chase", Vector3(0, 0, -2.5), arena, null)
	near.max_hp = 9999.0
	near.hp = 9999.0
	near.set_physics_process(false)
	var far_hp := aside.hp
	p.ki = p.max_ki
	p._void_burst()
	for i in 20:
		p._update_ki_queue(0.02)
	_check(near.hp < 9999.0 and is_equal_approx(aside.hp, far_hp), "the Void Burst hurts what is close, and not what is far")
	var o := p._ki_origin()
	_check(o.y > 0.7 and o.y < 1.6 and (o - p.global_position).dot(p.facing) > -0.2, "ki leaves from her hands, at chest height in front of her (%.2f m up)" % o.y)
	for n: Node in [p, inline, aside, near]:
		n.queue_free()
	await get_tree().process_frame

## The body shaper (docs/BODY_STUDY.md): the shape itself, the skinned copy, and the outfit.
func _test_body_shape() -> void:
	var src := load("res://assets/models/base_female/model_0.obj") as Mesh
	var shaper := BodyShape.new(src)
	var still := shaper.shape({})
	var same := true
	var a: PackedVector3Array = still.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for i in a.size():
		same = same and a[i].is_equal_approx(shaper.verts[i])
	_check(same and a.size() == shaper.verts.size(), "with every amount at zero the body is the source mesh")
	# the same numbers as tools/body_shape.py gives for the same amounts (probes read from it)
	var amounts := {"bust": 4.0, "waist": -1.8, "hips": 2.5, "butt": 4.0, "stomach": 1.5}
	var d := shaper.delta(amounts)
	var probes := [
		[Vector3(0.093698, 0.877677, -0.097198), Vector3(0.019361, -0.002383, -0.040741)],  # butt
		[Vector3(-0.071732, 1.19871, 0.143589), Vector3(-0.002567, -0.008702, 0.034869)],  # bust
		[Vector3(0.000343, 0.954428, 0.112625), Vector3(0.000012, -0.000357, 0.014362)],  # stomach
		[Vector3(-0.086833, 1.068316, 0.056265), Vector3(0.017248, 0.000006, -0.001466)],  # waist
	]
	var agree := true
	for pr: Array in probes:
		var best := 0
		for i in shaper.verts.size():
			if shaper.verts[i].distance_squared_to(pr[0]) < shaper.verts[best].distance_squared_to(pr[0]):
				best = i
		agree = agree and shaper.verts[best].distance_to(pr[0]) < 1e-4 and d[best].distance_to(pr[1]) < 5e-5
	var seen := {}
	var total := 0.0
	var tears := 0.0
	var body_h := shaper.aabb.size.y
	var fixed := true
	for i in shaper.verts.size():
		var key := Vector3i((shaper.verts[i] * 1e6).round())
		if seen.has(key):
			tears = maxf(tears, d[i].distance_to(d[seen[key]]))
		else:
			seen[key] = i
			total += d[i].length()
		var w := (shaper.verts[i].y - shaper.aabb.position.y) / body_h
		if (w > 0.80 or w < 0.30) and d[i].length() > 0.0:
			fixed = false
	_check(agree and absf(total - 15.838093) < 0.005, "the shaping matches the Python tool (probes and total movement %.3f)" % total)
	_check(tears < 1e-7, "points the mesh repeats at one position move together (no seams tear)")
	_check(fixed, "the head, and the legs below the thigh, do not move")
	# the full figure: her own shape (the big one), then none: no figure changes another's body.
	# Her outfit is hers alone, so the plain body wears a stand-in outfit.
	var big := shaper.dressed(BodyShape.amounts_of(BodyShape.OTO))
	add_child(big)
	var plain := shaper.dressed({})
	add_child(plain)
	var big_mi := _skin_body(big)
	var plain_mi := _skin_body(plain)
	var fresh := (load(Rig.RIGS["oto"]["skin"]) as PackedScene).instantiate()
	var fresh_mi := _skin_body(fresh)
	var z_big := big_mi.mesh.get_aabb().size.z
	var z_plain := plain_mi.mesh.get_aabb().size.z
	var z_file := fresh_mi.mesh.get_aabb().size.z
	_check(z_big > z_file * 1.03 and absf(z_plain - z_file) < 1e-6, "each figure's skinned body is its own: the big one is deeper (%.5f), the plain one is the file's (%.5f vs %.5f)" % [z_big, z_plain, z_file])
	_check((big_mi.mesh.surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) != 0, "the reshaped skinned body keeps its 8 bone weights a point")
	fresh.free()
	_check(big.has_meta("face") and big.get_meta("anim") != null, "a reshaped figure keeps her face and her animations")
	# her outfit sits outside the reshaped body (the same ray test as the stock one)
	var body := Garment.body_frame(big)
	var outside := true
	var pieces := 0
	for n: String in ["bodice", "sash", "trousers_hips", "trouser_leg_l", "trouser_leg_r"]:
		var mi: MeshInstance3D = big.find_child(n, true, false)
		if mi == null:
			outside = false
			continue
		pieces += 1
		var ax: Callable = mi.get_meta("axis")
		var gv: PackedVector3Array = Rig.fit_arrays(mi)[Mesh.ARRAY_VERTEX]
		for i in range(0, gv.size(), 3):
			var o: Vector3 = ax.call(gv[i].y)
			var dir := Vector3(gv[i].x - o.x, 0, gv[i].z - o.z)
			var hit := Face.cast(body["tm"], body["xf"], o, dir.normalized())
			if not hit.is_empty() and ((hit["position"] as Vector3) - o).length() > dir.length() + 0.0005:
				outside = false
	_check(outside and pieces == 5, "her bodice, sash and trousers sit outside a reshaped body everywhere")
	big.queue_free()
	plain.queue_free()
	await get_tree().process_frame

func _skin_body(visual: Node3D) -> MeshInstance3D:
	var sk: Skeleton3D = visual.get_meta("skeleton") if visual.has_meta("skeleton") else visual.find_children("*", "Skeleton3D", true, false)[0]
	return sk.find_children("*", "MeshInstance3D", true, false)[0]

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
