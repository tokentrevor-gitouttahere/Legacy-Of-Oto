class_name Enemy
extends Node3D
## A field enemy. behavior:
##   chase    walks in and hits (the default)
##   charger  stops, telegraphs, then dashes in a straight line; a wall stuns it, and a heavy
##            hit during the wind-up knocks it out of the charge
##   shooter  keeps its distance, strafes and fires ki shots
##   pack     circles Oto with its pack and darts in, one at a time
## tier (1-4) scales HP, damage and EXP and tints the model, so one model serves several
## regions. With model_key set it uses a character model. In spar mode it never dies: at
## 45% HP it emits spar_ended and stands down. An optional BossKit (`kit`) adds phases,
## ki absorption and drain-on-contact (level JSON "boss" key).
## Until Oto comes within aggro_range (or hits it) an enemy wanders near where it spawned;
## it gives up once she is twice that far away.

signal died
signal spar_ended

const TIER_SCALE := [1.0, 1.0, 2.5, 6.0, 15.0]  # index = tier
const TIER_TINT := [Color.WHITE, Color.WHITE, Color(0.75, 0.85, 1.0), Color(1.0, 0.85, 0.45), Color(0.65, 0.5, 0.85)]
const BODY_COLOR := Color(0.7, 0.3, 0.25)

var arena := Rect2(-15, -10, 30, 20)
var target: Player
var blocker := Callable()  # optional (pos: Vector3) -> bool, e.g. Level.is_blocked
var display_name := "Training Dummy"
var model_key := ""
var beast := ""  # a Beast kind ("wolf", "boar"...): a procedural animal instead of a model
var tint := Color.WHITE
var behavior := "chase"
var tier := 1
var max_hp := 40.0
var hp := 40.0
var speed := 2.3
var damage := 8.0
var xp_reward := 12
var capsule_drop := ""  # a Pickup capsule kind ("red", "blue3", "green5"...) or ""
var food_drop := ""  # a Pickup food kind ("haunch", "rice_ball"...) dropped some of the time
var food_chance := 0.35
var ki_chance := 0.3
var spar := false
var frozen := false
var kit: BossKit
var aggro_range := 12.0
var engaged := false

var hitstun := 0.0
var knock := Vector3.ZERO
var attack_cooldown := 0.0
var flash := 0.0
var state := "move"
var state_time := 0.0
var dash_dir := Vector3.ZERO
var struck := false
var orbit_angle := 0.0
var orbit_dir := 1.0
var lunge_timer := 0.0
var home := Vector3.ZERO
var _wander_to := Vector3.ZERO
var _wander_wait := 0.0
var _last_pos := Vector3.ZERO
var gait := 0.0  # walk cycle phase, advanced by distance moved (Beasts animate from it)

var _visual: Node3D
var _mat: StandardMaterial3D
var _bar: MeshInstance3D
var _color := BODY_COLOR

func _ready() -> void:
	add_to_group("enemies")
	home = position
	_wander_to = position
	_last_pos = position
	var t := clampi(tier, 1, 4)
	max_hp *= TIER_SCALE[t]
	damage *= TIER_SCALE[t]
	xp_reward = int(round(xp_reward * TIER_SCALE[t]))
	hp = max_hp
	orbit_angle = randf() * TAU
	orbit_dir = 1.0 if randf() < 0.5 else -1.0
	lunge_timer = randf_range(1.5, 3.5)
	var bar_height := 2.0
	if beast != "":
		var b := Beast.make(beast, tint * TIER_TINT[t])
		_visual = b
		add_child(b)
		bar_height = b.bar_height
	elif model_key == "":
		_color = BODY_COLOR * TIER_TINT[t]
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.4
		capsule.height = 1.7
		_mat = StandardMaterial3D.new()
		_mat.albedo_color = _color
		var body := MeshInstance3D.new()
		body.mesh = capsule
		body.material_override = _mat
		body.position.y = 0.85
		add_child(body)
	else:
		_visual = ModelLoader.make(model_key, tint * TIER_TINT[t])
		add_child(_visual)
		bar_height = 2.15

	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 0.1)
	var bar_mat := StandardMaterial3D.new()
	bar_mat.albedo_color = Color(0.3, 0.9, 0.3)
	bar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bar_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_bar = MeshInstance3D.new()
	_bar.mesh = quad
	_bar.material_override = bar_mat
	_bar.position.y = bar_height
	add_child(_bar)

## kind is "melee" or "ki" (ki shots).
func hurt(amount: float, dir: Vector3, launch: bool, kind := "melee") -> void:
	if frozen:
		return
	engaged = true
	if kit:
		amount = kit.incoming(amount, kind)
	hp = minf(hp - amount, max_hp)
	if kit:
		var before := hp
		hp = kit.check(hp, max_hp)
		if hp > before + 0.5:
			DamageNumber.word(get_parent(), position + Vector3(0, 0.5, 0), "Recovers!", DamageNumber.HEAL)
	DamageNumber.number(get_parent(), position, amount, DamageNumber.HEAVY_HIT if launch else DamageNumber.ENEMY_HIT, launch)
	flash = 0.1
	if state == "dash":
		launch = false  # a charging body does not get knocked aside by a jab
	else:
		hitstun = 0.45 if launch else 0.15
		knock = dir * (11.0 if launch else 2.0)
	if state == "windup" and launch:
		_enter("stunned")  # punished the tell
		DamageNumber.word(get_parent(), position + Vector3(0, 0.5, 0), "Broken!", DamageNumber.HEAVY_HIT)
	if spar and hp <= max_hp * 0.45:
		hp = max_hp * 0.45
		frozen = true
		spar_ended.emit()
		return
	if hp <= 0.0:
		GameState.add_xp(xp_reward)
		if capsule_drop != "":
			_drop(capsule_drop, Vector3.ZERO)
		if food_drop != "" and randf() < food_chance:
			_drop(food_drop, Vector3(0.6, 0, 0.3))
		if randf() < ki_chance:
			_drop("ki_mote", Vector3(-0.6, 0, 0.3))
		Sfx.play("enemy_down")
		died.emit()
		queue_free()

func _drop(kind: String, offset: Vector3) -> void:
	var p := Pickup.new()
	p.kind = kind
	p.position = position + offset
	get_parent().add_child(p)

func _enter(s: String) -> void:
	state = s
	state_time = 0.0
	struck = false

func _physics_process(delta: float) -> void:
	flash = maxf(flash - delta, 0.0)
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	state_time += delta
	_update_look()
	_bar.scale.x = maxf(hp / max_hp, 0.01)
	if frozen:
		return
	if hitstun > 0.0:
		hitstun -= delta
		_step(knock * delta)
		knock = knock.move_toward(Vector3.ZERO, 20.0 * delta)
		_clamp()
		return
	if not is_instance_valid(target) or target.cinematic:
		return
	var to := target.position - position
	to.y = 0
	var dist := to.length()
	if not engaged and dist < aggro_range:
		engaged = true
	elif engaged and dist > aggro_range * 2.0 and not spar:
		engaged = false
		_enter("move")
	if not engaged:
		_wander(delta)
		_clamp()
		return
	if _visual and state != "dash":
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(to.x, to.z), 10.0 * delta)
	match behavior:
		"charger":
			_charger(delta, to, dist)
		"shooter":
			_shooter(delta, to, dist)
		"pack":
			_pack(delta, to, dist)
		_:
			_chase(delta, to, dist)
	_clamp()

## Idle: amble between random spots within 4 m of home.
func _wander(delta: float) -> void:
	_wander_wait -= delta
	var go := _wander_to - position
	go.y = 0
	if go.length() > 0.3:
		_step(go.normalized() * speed * 0.35 * delta)
		if _visual:
			_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(go.x, go.z), 5.0 * delta)
	elif _wander_wait <= 0.0:
		_wander_to = home + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
		_wander_wait = randf_range(1.5, 4.0)

func _chase(delta: float, to: Vector3, dist: float) -> void:
	if dist > 1.3:
		_step(to.normalized() * speed * delta)
	elif attack_cooldown == 0.0:
		_hit(damage)
		attack_cooldown = 1.0

func _charger(delta: float, to: Vector3, dist: float) -> void:
	match state:
		"move":
			if dist < 7.0 and attack_cooldown == 0.0:
				_enter("windup")
			else:
				_chase(delta, to, dist)
		"windup":
			dash_dir = to.normalized()
			if state_time > 0.6:
				_enter("dash")
		"dash":
			var hit_wall := _step(dash_dir * 13.0 * delta)
			if not struck and dist < 1.3:
				struck = true
				_hit(damage * 1.5)
			if hit_wall:
				_enter("stunned")
			elif state_time > 0.55:
				_enter("recover")
		"stunned":
			if state_time > 1.4:
				attack_cooldown = 1.5
				_enter("move")
		"recover":
			if state_time > 0.6:
				attack_cooldown = 2.0
				_enter("move")

func _shooter(delta: float, to: Vector3, dist: float) -> void:
	var away := -to.normalized()
	if dist < 4.5:
		_step(away * speed * delta)
	elif dist > 8.0:
		_step(-away * speed * delta)
	else:
		_step(away.rotated(Vector3.UP, PI / 2.0 * orbit_dir) * speed * 0.6 * delta)
		if state_time > 2.0:
			orbit_dir = -orbit_dir
			state_time = 0.0
	if attack_cooldown == 0.0 and dist < 11.0:
		var shot := KiShot.new()
		shot.hostile = true
		shot.color = Color(1.0, 0.55, 0.25, 0.9)
		shot.position = position + Vector3(0, 1.0, 0) + to.normalized() * 0.6
		shot.setup(to.normalized(), 0, damage)
		get_parent().add_child(shot)
		attack_cooldown = 2.2

func _pack(delta: float, to: Vector3, dist: float) -> void:
	match state:
		"move":
			orbit_angle += orbit_dir * 0.9 * delta
			var spot := target.position + Vector3(cos(orbit_angle), 0, sin(orbit_angle)) * 3.6
			var go := spot - position
			go.y = 0
			if go.length() > 0.2:
				_step(go.normalized() * minf(speed * 1.3, go.length() / maxf(delta, 0.001)) * delta)
			lunge_timer -= delta
			# Only one of the pack darts in at a time.
			if lunge_timer <= 0.0 and not _packmate_lunging():
				_enter("lunge")
				dash_dir = to.normalized()
		"lunge":
			_step(dash_dir * 9.0 * delta)
			if not struck and dist < 1.3:
				struck = true
				_hit(damage)
			if struck or state_time > 0.5:
				lunge_timer = randf_range(2.0, 4.0)
				_enter("move")

## A contact hit on Oto; a draining boss heals from it.
func _hit(amount: float) -> void:
	target.hurt(amount, position)
	if kit and kit.drain_on_contact > 0.0:
		hp = minf(hp + kit.contact_heal(amount), max_hp)

func _packmate_lunging() -> bool:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and e is Enemy and e.behavior == "pack" and e.state == "lunge":
			return true
	return false

## Move with wall sliding (like Player._move). Returns true if a wall or the arena edge
## stopped the move.
func _step(v: Vector3) -> bool:
	var stopped := false
	for axis in [Vector3(v.x, 0, 0), Vector3(0, 0, v.z)]:
		if axis == Vector3.ZERO:
			continue
		if _blocked(position + axis + axis.normalized() * 0.35):
			stopped = true
		else:
			position += axis
	return stopped

func _blocked(p: Vector3) -> bool:
	if p.x < arena.position.x + 0.5 or p.x > arena.end.x - 0.5 or p.z < arena.position.y + 0.5 or p.z > arena.end.y - 0.5:
		return true
	return blocker.is_valid() and blocker.call(p)

func _process(_delta: float) -> void:
	var moved := Vector2(position.x - _last_pos.x, position.z - _last_pos.z).length()
	_last_pos = position
	gait += moved * 2.2
	if _visual and _visual.has_method("animate"):
		_visual.animate(gait, moved > 0.001, state == "windup", Time.get_ticks_msec() / 1000.0)

func _update_look() -> void:
	var telegraph := state == "windup" and int(state_time * 12.0) % 2 == 0
	var dazed := state == "stunned"
	if _mat:
		if flash > 0.0:
			_mat.albedo_color = Color.WHITE
		elif telegraph:
			_mat.albedo_color = Color(1.0, 0.85, 0.4)
		elif dazed:
			_mat.albedo_color = _color.lerp(Color(0.5, 0.5, 0.6), 0.5)
		else:
			_mat.albedo_color = _color
	if _visual:
		_visual.scale = Vector3.ONE * (1.05 if flash > 0.0 or telegraph else 1.0)
		_visual.rotation.z = 0.25 * sin(state_time * 9.0) if dazed else 0.0

func _clamp() -> void:
	position.x = clampf(position.x, arena.position.x + 0.5, arena.end.x - 0.5)
	position.z = clampf(position.z, arena.position.y + 0.5, arena.end.y - 0.5)
