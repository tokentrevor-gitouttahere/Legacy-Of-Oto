class_name Cutscene
extends Node3D
## The cutscene director: a scene is a script that extends Cutscene and writes its beats in
## `play()` with awaits, one line per beat:
##
##   var oto := actor("oto", Vector3(0, 0, 0))
##   await fly(oto, from, to, 2.5)                # glide along a curve in the flying pose
##   hold(oto, "cross_punch", 1.13)               # freeze a frame of an animation (a pose)
##   await camera_to(pos, look_at, 1.2)           # ease the camera; omit the await to overlap
##   await wait(0.4)
##   shake(0.4, 0.25)
##
## Sets: stage("level_id") builds a level as scenery (no foes, no HUD); or sky(...) plus ground().
## Skipping: any confirm or cancel press ends the scene at once and runs finish(); a scene
## puts what must happen at the end (change scene, set a flag) in finish(). Overlay text,
## fades and cards work as anywhere else. Effects are in CutFx.

signal skipped

var cam: Camera3D
var skippable := true
var _done := false
var _shake := 0.0
var _shake_amp := 0.0
var _cam_base := Vector3.ZERO
var _stage: Node3D

func _ready() -> void:
	GameState.menu_enabled = false
	GameState.input_locked = true
	Overlay.hint("")
	Overlay.set_prompt("")
	cam = Camera3D.new()
	cam.fov = 50
	add_child(cam)
	cam.current = true
	_cam_base = cam.position
	await get_tree().process_frame
	if not is_inside_tree():  # replaced before it began (another scene was loaded over it)
		return
	await play()
	_end()

## Override: the beats.
func play() -> void:
	pass

## Override: what happens after the last beat or a skip (change scene, set flags).
func finish() -> void:
	pass

func _end() -> void:
	if _done:
		return
	_done = true
	GameState.input_locked = false
	for l: String in ["ki_charge", "ki_beam"]:  # a skip must not leave a loop running
		Sfx.loop_off(l)
	finish()

func _process(delta: float) -> void:
	if skippable and not _done and (Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("menu")
			or Input.is_action_just_pressed("interact")) and not Overlay.auto:
		skipped.emit()
		_end()
	if _shake > 0.0:
		_shake -= delta
		var k := _shake_amp * clampf(_shake * 4.0, 0.0, 1.0)
		cam.h_offset = randf_range(-k, k)
		cam.v_offset = randf_range(-k, k)
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0

# --- sets -------------------------------------------------------------------------------

## A level as scenery: its ground, walls, props and sky, without foes or NPCs.
func stage(level_id: String) -> Level:
	var lv := Level.load_level(level_id)
	add_child(lv)
	Skies.apply(self, lv.data.get("sky", "day"))
	_stage = lv
	return lv

func sky(preset: String) -> void:
	Skies.apply(self, preset)

## An open set: a ground plane `size` metres across, and `ring` props scattered round the
## horizon (mesas, crags, pines...) with `near` props dotted closer in. Clear sight lines for the
## camera, which a playable level's walls often block.
func open_set(ground: Color, tex: String, ring: String, near: Array, seed := 3, size := 400.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	mi.mesh = plane
	mi.material_override = Mats.get_mat(ground, tex, 0.08)
	add_child(mi)
	for k in 26:
		var a := TAU * k / 26.0 + rng.randf_range(-0.1, 0.1)
		var r := rng.randf_range(70.0, 130.0)
		var p := Props.make(ring, {"r": rng.randf_range(6, 14), "h": rng.randf_range(14, 32), "size": rng.randf_range(4, 8)})
		p.position = Vector3(cos(a) * r, 0, sin(a) * r)
		add_child(p)
	for k in 22:
		var a := rng.randf() * TAU
		var r := rng.randf_range(14.0, 55.0)
		var p := Props.make(near[k % near.size()], {"size": rng.randf_range(0.8, 1.4)})
		p.position = Vector3(cos(a) * r, 0, sin(a) * r)
		p.rotation.y = rng.randf() * TAU
		add_child(p)

# --- actors -----------------------------------------------------------------------------

## A dressed character standing at `pos`, facing +Z (turn with face()).
func actor(preset: String, pos: Vector3) -> Node3D:
	var ch := Outfits.make_character(preset)
	ch.position = pos
	add_child(ch)
	return ch

func anim(ch: Node3D, name: String, speed := 1.0) -> void:
	var ap: AnimationPlayer = ch.get_meta("anim", null)
	if ap:
		ap.speed_scale = speed
		ap.play(name)

func anim_speed(ch: Node3D, speed: float) -> void:
	var ap: AnimationPlayer = ch.get_meta("anim", null)
	if ap:
		ap.speed_scale = speed

## Freeze `ch` at `seconds` into an animation: a pose.
func hold(ch: Node3D, name: String, seconds: float) -> void:
	var ap: AnimationPlayer = ch.get_meta("anim", null)
	if ap:
		ap.play(name)
		ap.seek(seconds, true)
		ap.pause()

## Turn to face a point (characters face +Z).
func face(ch: Node3D, at: Vector3) -> void:
	var d := at - ch.global_position
	ch.rotation.y = atan2(d.x, d.z)

func face_expr(ch: Node3D, expression: String) -> void:
	var f: Variant = ch.get_meta("face", null)
	if f:
		(f as FaceRig).express(expression)

## Where a bone is in the world ("RightHand", "Head", ...: the end of a Mixamo bone name).
func bone_pos(ch: Node3D, bone: String) -> Vector3:
	var sk: Skeleton3D = ch.get_meta("skeleton", null)
	if sk == null:
		return ch.global_position + Vector3(0, 1.2, 0)
	for b in sk.get_bone_count():
		if sk.get_bone_name(b).ends_with(bone):
			return sk.global_transform * sk.get_bone_global_pose(b).origin
	return ch.global_position + Vector3(0, 1.2, 0)

## Move along a quadratic curve through `bend` (defaults to a straight line), easing in and out.
func move(ch: Node3D, to: Vector3, time: float, bend := Vector3.INF, ease_kind := Tween.EASE_IN_OUT) -> void:
	var from := ch.position
	var mid := (from + to) * 0.5 if bend == Vector3.INF else bend
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		var a := from.lerp(mid, t)
		var b := mid.lerp(to, t)
		ch.position = a.lerp(b, t), 0.0, 1.0, time).set_trans(Tween.TRANS_SINE).set_ease(ease_kind)
	await tw.finished

## Fly in the flying pose along a curve, the body pitched along the path, with a ki trail.
func fly(ch: Node3D, from: Vector3, to: Vector3, time: float, bend := Vector3.INF, trail_color := Color(0.62, 0.45, 1.0)) -> void:
	ch.position = from
	anim(ch, "flying")
	face(ch, to)
	var trail := CutFx.trail(self, ch, trail_color)
	await move(ch, to, time, bend, Tween.EASE_OUT)
	trail.set_meta("stop", true)

# --- camera -----------------------------------------------------------------------------

func camera_at(pos: Vector3, look: Vector3, fov := -1.0) -> void:
	cam.position = pos
	cam.look_at(look)
	if fov > 0.0:
		cam.fov = fov

## Ease the camera to a new place and aim over `time`; `fov` < 0 keeps the lens.
func camera_to(pos: Vector3, look: Vector3, time: float, fov := -1.0) -> void:
	var p0 := cam.position
	var aim0 := cam.global_position - cam.global_basis.z * 10.0
	var f0 := cam.fov
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		cam.position = p0.lerp(pos, t)
		cam.look_at(aim0.lerp(look, t))
		if fov > 0.0:
			cam.fov = lerpf(f0, fov, t), 0.0, 1.0, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished

## Keep the camera on a moving actor for `time`, from an offset.
func camera_follow(ch: Node3D, offset: Vector3, time: float, look_up := 1.0) -> void:
	var t := 0.0
	while t < time and not _done:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		cam.position = cam.position.lerp(ch.global_position + offset, minf(dt * 4.0, 1.0))
		cam.look_at(ch.global_position + Vector3(0, look_up, 0))

func shake(time: float, amount: float) -> void:
	_shake = time
	_shake_amp = amount

# --- time -------------------------------------------------------------------------------

func wait(seconds: float) -> void:
	if _done or not is_inside_tree():
		return
	await get_tree().create_timer(seconds).timeout
