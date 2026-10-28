class_name Player
extends Node3D

signal charged_from_empty  # charged from 10% ki or less to full without moving
## Oto. 8-direction movement on the XZ plane, sprint/stamina, 3-hit combo and a held
## flurry (four punches), guard, ki barrier, ki techniques (charged orb, rapid blast; `cycle`
## switches), standing ki charge, Shadow forms and interaction. Units are metres.
## The meshes are unrigged, so animation is whole-body procedural for now.

const WALK_SPEED := 4.5
const RUN_SPEED := 8.0
const DOUBLE_TAP_TIME := 0.25
const COMBO_WINDOW := 0.4
const ATTACK_TIME := 0.18
const CHARGE_THRESHOLDS := [0.45, 1.1]
const CHARGE_COST := [8.0, 20.0, 40.0]
const BLAST_INTERVAL := 0.14
const BLAST_COST := 2.0
const HEAVY_DELAY := 0.3  # hold attack this long to start winding up the flurry
const HEAVY_CHARGE := 0.45  # then this long until it is ready; release to strike
const BARRIER_DRAIN := 10.0
const INTERACT_RANGE := 2.6
const MOVE_ACTIONS := ["move_left", "move_right", "move_up", "move_down"]
const FORM_TINT := [0.0, 0.55, 0.65, 0.75]
const FORM_FX := [
	Color(0, 0, 0, 0),
	Color(0.04, 0.0, 0.08, 0.35),
	Color(0.0, 0.0, 0.0, 0.5),
	Color(0.03, 0.0, 0.07, 0.3),
]

var arena := Rect2(-15, -10, 30, 20)

var max_hp: float:
	get:
		return GameState.max_hp()
var max_ki: float:
	get:
		return GameState.max_ki()
var hp := 100.0
var ki := 60.0
var stamina := 100.0
var max_stamina := 100.0

var form := 0
var cinematic := false  # scripted control: no input, no physics
var blocker := Callable()  # optional (pos: Vector3) -> bool, e.g. Level.is_blocked
var outfit := "oto"  # Outfits preset applied in _ready ("" for none)

var facing := Vector3(0, 0, 1)
var combo_step := 0
var attack_timer := 0.0
var combo_timer := 0.0
var hitstun := 0.0
var iframes := 0.0
var knock := Vector3.ZERO
var running := false
var guarding := false
var barrier := false
var charging := false
var charge_time := 0.0
var ki_charging := false
var charge_hold := 0.0  # seconds `charge` has been held still (see GameState.CHARGE_TIERS)
var blast_timer := 0.0
var _still_from_empty := false
var attack_hold := 0.0
var heavy_swing := 0.0
var _moving := false
# the rig (rig.gd): what the animation shows, and the flurry's hits still to land
const STRIKES := ["l_punch", "r_punch", "cross_punch"]  # combo hits 1, 2, 3
const STRIKE_SPEED := 1.6  # punches play this much faster than Mixamo made them
const STRIKE_LEAD := 0.12  # seconds from the press to the fist landing
const FLURRY_SPEED := 1.5
const CALM_AFTER := 3.0  # seconds without fighting before she walks the hot walk
var _ground_speed := 0.0
var _rig_busy := 0.0  # an attack animation is playing for this long
var _flurry: Array = []  # [[seconds until it lands, last hit?], ...]
var _flurry_dmg := 0.0
var _since_fight := 100.0
var _tap_times := {}

var visual: Node3D
var _barrier_fx: MeshInstance3D
var _guard_fx: MeshInstance3D
var _aura_fx: MeshInstance3D
var _charge_fx: MeshInstance3D
var _swing_fx: MeshInstance3D
var _form_fx: MeshInstance3D
var _heavy_fx: MeshInstance3D

func _ready() -> void:
	add_to_group("player")
	visual = ModelLoader.make("oto")
	add_child(visual)
	if outfit != "":
		Outfits.apply(visual, outfit)
	_barrier_fx = _add_fx(1.6, Color(0.5, 0.4, 0.9, 0.3))
	_guard_fx = _add_fx(1.2, Color(0.6, 0.7, 1.0, 0.25))
	_aura_fx = _add_fx(1.3, Color(0.7, 0.5, 1.0, 0.2))
	_charge_fx = _add_fx(0.3, Color(0.45, 0.25, 0.7, 0.9))
	_swing_fx = _add_fx(0.5, Color(1, 1, 1, 0.6))
	_form_fx = _add_fx(1.2, Color(0, 0, 0, 0.4))
	_heavy_fx = _add_fx(0.25, Color(1.0, 0.95, 0.85, 0.85))
	hp = max_hp
	ki = max_ki
	GameState.leveled_up.connect(func(_l: int) -> void:
		hp = max_hp
		ki = max_ki)

func _add_fx(radius: float, color: Color) -> MeshInstance3D:
	var fx := ModelLoader.glow_sphere(radius, color)
	fx.position.y = 0.9
	fx.visible = false
	add_child(fx)
	return fx

func _pressed(action: String) -> bool:
	return not GameState.input_locked and Input.is_action_pressed(action)

func _just(action: String) -> bool:
	return not GameState.input_locked and Input.is_action_just_pressed(action)

func _unhandled_input(event: InputEvent) -> void:
	if GameState.input_locked:
		return
	for a in MOVE_ACTIONS:
		if event.is_action_pressed(a, false, true):
			var now := Time.get_ticks_msec() / 1000.0
			if now - _tap_times.get(a, -10.0) < DOUBLE_TAP_TIME and stamina > 10.0:
				running = true
			_tap_times[a] = now

func charge_level() -> int:
	if charge_time >= CHARGE_THRESHOLDS[1]:
		return 2
	if charge_time >= CHARGE_THRESHOLDS[0]:
		return 1
	return 0

## Change Shadow form. Going up needs ki and an unlocked form; `force` skips both.
func set_form(f: int, force := false) -> void:
	f = clampi(f, 0, 3)
	if f == form:
		return
	if not force and (f > GameState.max_form or (f > form and ki < 10.0)):
		return
	form = f
	_apply_form_visual()

func _apply_form_visual() -> void:
	for m: StandardMaterial3D in visual.get_meta("mats", []):
		var base: Color = m.get_meta("base_color")
		m.albedo_color = base.lerp(Color(0.02, 0.0, 0.04), FORM_TINT[form])
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if form == 2 else BaseMaterial3D.TRANSPARENCY_DISABLED
	# Shadow forms: hair goes pitch black and reflects no light.
	for m: StandardMaterial3D in visual.get_meta("hair_mats", []):
		var base: Color = m.get_meta("base_color")
		m.albedo_color = base if form == 0 else Color(0.0, 0.0, 0.0)
		m.roughness = 0.9 if form == 0 else 1.0
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if form == 2 else BaseMaterial3D.TRANSPARENCY_DISABLED
	_form_fx.visible = form > 0
	(_form_fx.material_override as StandardMaterial3D).albedo_color = FORM_FX[form]
	Outfits.set_silver(visual, form > 0)  # Shadow forms: no gold anywhere on her
	var face: FaceRig = visual.get_meta("face", null)
	if face:
		face.set_form(form, FORM_TINT[form])  # void eyes, black brows; the cold look in forms 2-3
		face.set_alpha(1.0)
	var long_hair: Node3D = visual.get_meta("form3_hair", null)
	if long_hair:
		long_hair.visible = form == 3  # Cohesion: hair past her knees, perfectly still

func _physics_process(delta: float) -> void:
	if cinematic:
		return
	attack_timer = maxf(attack_timer - delta, 0.0)
	combo_timer = maxf(combo_timer - delta, 0.0)
	heavy_swing = maxf(heavy_swing - delta, 0.0)
	iframes = maxf(iframes - delta, 0.0)
	_rig_busy = maxf(_rig_busy - delta, 0.0)
	_since_fight += delta
	_update_flurry(delta)
	if combo_timer == 0.0:
		combo_step = 0

	if form > 0:
		ki -= GameState.FORM_DRAIN[form] * delta
		if ki <= 0.0:
			ki = 0.0
			set_form(0, true)
			Overlay.toast("Your form gives out.")

	if hitstun > 0.0:
		hitstun -= delta
		_move(knock * delta)
		knock = knock.move_toward(Vector3.ZERO, 26.0 * delta)
		_moving = false
		_clamp()
		return

	var in_dir := Vector2.ZERO
	if not GameState.input_locked:
		in_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir := Vector3(in_dir.x, 0, in_dir.y)
	if dir != Vector3.ZERO:
		facing = dir.normalized()
	else:
		running = false

	guarding = _pressed("guard") and not barrier
	if _pressed("guard") and _just("special"):
		barrier = not barrier and ki > 1.0
	if barrier:
		ki -= BARRIER_DRAIN * delta
		if ki <= 0.0:
			ki = 0.0
			barrier = false

	if _just("transform"):
		set_form(form + 1)
	if _just("revert"):
		set_form(form - 1)
	if _just("cycle") and GameState.ki_moves.size() > 1:
		GameState.cycle_ki_move()
		Overlay.toast(GameState.KI_MOVES[GameState.ki_move()]["name"], 1.0)

	_update_charge(delta, dir)

	if _just("attack") and attack_timer == 0.0 and not guarding and not barrier:
		combo_step = combo_step % 3 + 1
		attack_timer = ATTACK_TIME
		combo_timer = COMBO_WINDOW
		_melee(combo_step)
		_strike_anim(STRIKES[combo_step - 1], STRIKE_SPEED)
	_update_heavy(delta)

	if _just("interact"):
		var it := _nearest_interactable()
		if it:
			it.interact(self)

	var speed := WALK_SPEED
	if running and stamina > 0.0 and dir != Vector3.ZERO:
		speed = RUN_SPEED
		stamina = maxf(stamina - 25.0 * delta, 0.0)
		if stamina == 0.0:
			running = false
	else:
		stamina = minf(stamina + 30.0 * delta, max_stamina)
	if guarding or charging:
		speed *= 0.3
	if heavy_winding():
		speed *= 0.4
	if attack_timer > 0.0:
		speed *= 0.2
	speed *= GameState.FORM_SPEED[form] * GameState.speed_mult()
	_moving = dir != Vector3.ZERO
	_ground_speed = speed if _moving else 0.0
	_move(dir * speed * delta)
	_clamp()

## Move with wall sliding: each axis is tried on its own against the blocker.
func _move(step: Vector3) -> void:
	if not blocker.is_valid():
		position += step
		return
	for axis in [Vector3(step.x, 0, 0), Vector3(0, 0, step.z)]:
		if axis == Vector3.ZERO:
			continue
		var probe: Vector3 = position + axis + axis.normalized() * 0.3
		if not blocker.call(probe):
			position += axis

func _nearest_interactable() -> Node3D:
	var best: Node3D = null
	var best_d := INTERACT_RANGE
	for n in get_tree().get_nodes_in_group("interactables"):
		if not n.enabled:
			continue
		var d := Vector2(n.position.x - position.x, n.position.z - position.z).length()
		if d < best_d:
			best_d = d
			best = n
	return best

## Standing still with `charge` held fills ki after the tier's delay; moving, attacking,
## guarding or being hit starts the delay over. Shot charging (`special`) is separate.
func _update_charge(delta: float, dir: Vector3) -> void:
	ki_charging = _pressed("charge") and dir == Vector3.ZERO and not barrier and not guarding and attack_timer == 0.0
	var regen := 1.5 + GameState.gear_sum("regen")
	if ki_charging:
		if charge_hold == 0.0:
			_still_from_empty = ki <= max_ki * 0.1
		charge_hold += delta
		var tier := GameState.charge_info()
		if charge_hold >= float(tier["delay"]):
			ki = minf(ki + max_ki * float(tier["rate"]) * delta, max_ki)
			if _still_from_empty and ki >= max_ki:
				_still_from_empty = false
				charged_from_empty.emit()
	else:
		charge_hold = 0.0
		_still_from_empty = false
		if form == 0:
			ki = minf(ki + regen * delta, max_ki)

	if guarding or barrier:
		charging = false
		charge_time = 0.0
		return
	if GameState.ki_move() == "ki_blast":
		charging = false
		charge_time = 0.0
		blast_timer = maxf(blast_timer - delta, 0.0)
		if _pressed("special") and blast_timer == 0.0:
			_fire_blast()
			blast_timer = BLAST_INTERVAL
		return
	if _pressed("special"):
		charging = true
		charge_time += delta
	elif charging:
		_fire(charge_level())
		charging = false
		charge_time = 0.0

func _fire(level: int) -> void:
	var cost: float = CHARGE_COST[level]
	if ki < cost:
		level = 0
		cost = CHARGE_COST[0]
		if ki < cost:
			return
	ki -= cost
	var shot := KiShot.new()
	shot.position = position + facing * 0.9 + Vector3(0, 1.0, 0)
	var dmg: float = (6.0 + GameState.stat("power") * 1.2 + level * 8.0) * GameState.FORM_DAMAGE[form]
	shot.setup(facing, level, dmg)
	get_parent().add_child(shot)

## A stream of small shots, slightly scattered.
func _fire_blast() -> void:
	if ki < BLAST_COST:
		return
	ki -= BLAST_COST
	var shot := KiShot.new()
	shot.small = true
	var side := facing.cross(Vector3.UP).normalized() * randf_range(-0.25, 0.25)
	shot.position = position + facing * 0.9 + side + Vector3(0, 1.0, 0)
	var dmg: float = (2.0 + GameState.stat("power") * 0.45) * GameState.FORM_DAMAGE[form]
	shot.setup(facing.rotated(Vector3.UP, randf_range(-0.06, 0.06)), 0, dmg)
	get_parent().add_child(shot)

func heavy_winding() -> bool:
	return attack_hold >= HEAVY_DELAY

## Holding attack past HEAVY_DELAY winds up; releasing once HEAVY_CHARGE more has passed
## lands the flurry (_heavy: four punches; the last launches and knocks a charger out of its wind-up).
func _update_heavy(delta: float) -> void:
	if _pressed("attack") and not guarding and not barrier:
		attack_hold += delta
		return
	if attack_hold >= HEAVY_DELAY + HEAVY_CHARGE:
		_heavy()
	attack_hold = 0.0

## The flurry: four fast punches (the quad punch), the last one launching. The held strike's
## damage is shared over the four, with a little more on the last.
func _heavy() -> void:
	combo_step = 0
	combo_timer = 0.0
	_flurry_dmg = (6.0 + GameState.stat("strength") * 1.6) * GameState.FORM_DAMAGE[form]
	var times: Array = [0.0, 0.13, 0.27, 0.41]  # without a rig
	var rig: Dictionary = visual.get_meta("rig", {})
	if rig.has("hits"):
		var hits: Array = rig["hits"]["quad_punch"]
		var start := maxf(float(hits[0]) - STRIKE_LEAD * FLURRY_SPEED, 0.0)
		times = []
		for h: float in hits:
			times.append((h - start) / FLURRY_SPEED)
		_strike_anim("quad_punch", FLURRY_SPEED)
	_flurry.clear()
	for i in times.size():
		_flurry.append([float(times[i]), i == times.size() - 1])
	var total: float = float(times[times.size() - 1]) + 0.15
	attack_timer = total
	heavy_swing = total

func _update_flurry(delta: float) -> void:
	if _flurry.is_empty():
		return
	if hitstun > 0.0:  # a hit breaks the flurry
		_flurry.clear()
		return
	for f: Array in _flurry:
		f[0] = float(f[0]) - delta
	while not _flurry.is_empty() and float(_flurry[0][0]) <= 0.0:
		var last: bool = _flurry[0][1]
		_flurry.pop_front()
		var dmg := _flurry_dmg * (0.34 if last else 0.22)
		var center := position + facing * 1.2
		for e in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("breakables"):
			if e.position.distance_to(center) <= (2.2 if e is Fixture else 1.6):
				e.hurt(dmg, facing, last)

## Play a strike on the rig so that its first blow lands STRIKE_LEAD after now.
func _strike_anim(anim_name: String, speed: float) -> void:
	_since_fight = 0.0
	var ap: AnimationPlayer = visual.get_meta("anim", null)
	var rig: Dictionary = visual.get_meta("rig", {})
	if ap == null or not rig.has("hits"):
		return
	var hits: Array = rig["hits"][anim_name]
	var start := maxf(float(hits[0]) - STRIKE_LEAD * speed, 0.0)
	ap.play(anim_name, 0.05, speed)
	ap.seek(start, true)
	_rig_busy = (float(hits[hits.size() - 1]) - start) / speed + 0.28  # the blow, then a beat of follow-through

## What the rig shows when she is not striking: standing, the walk, or the hot walk when
## nothing has threatened her for a while.
func _animate_rig(ap: AnimationPlayer) -> void:
	if _rig_busy > 0.0:
		return
	var rig: Dictionary = visual.get_meta("rig", {})
	if _moving and _ground_speed > 0.0:
		var walk := "hot_walk" if _calm() and not running else "walk"
		var natural: float = rig.get("walk_speed", {}).get(walk, 1.4)
		var spd := clampf(_ground_speed / natural, 0.7, 2.4)
		if ap.current_animation != walk:
			ap.play(walk, 0.18, spd)
		else:
			ap.speed_scale = spd
	elif ap.current_animation != "idle":
		ap.play("idle", 0.2, 1.0)

func _calm() -> bool:
	if _since_fight < CALM_AFTER:
		return false
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.position.distance_to(position) < 12.0:
			return false
	return true

func _melee(step: int) -> void:
	var dmg: float = (4.0 + GameState.stat("strength") * 0.8 + (2.0 if step == 3 else 0.0)) * GameState.FORM_DAMAGE[form]
	var center := position + facing * 1.0
	for e in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("breakables"):
		if e.position.distance_to(center) <= (2.0 if e is Fixture else 1.3):
			e.hurt(dmg, facing, step == 3)

## Restore a share of max HP (food, rest). Shows the gain as a green number.
func heal(frac: float) -> void:
	var before := hp
	hp = minf(hp + max_hp * frac, max_hp)
	if hp - before >= 0.5:
		DamageNumber.word(get_parent(), position, "+%d" % int(round(hp - before)), DamageNumber.HEAL)

func restore_ki(frac: float) -> void:
	var before := ki
	ki = minf(ki + max_ki * frac, max_ki)
	if ki - before >= 0.5:
		DamageNumber.word(get_parent(), position + Vector3(0.4, 0, 0), "+%d ki" % int(round(ki - before)), DamageNumber.KI)

func hurt(amount: float, from_pos: Vector3) -> void:
	if barrier or iframes > 0.0 or cinematic:
		return
	_since_fight = 0.0
	if form == 2 and randf() < 0.25:
		return  # an edge of her was not there to be hit
	var mult := 1.0 - minf(GameState.stat("endurance") * 0.015, 0.7)
	if guarding:
		mult *= 0.2
	hp -= amount * mult
	charge_hold = 0.0
	DamageNumber.number(get_parent(), position, amount * mult, DamageNumber.GUARDED if guarding else DamageNumber.PLAYER_HIT)
	iframes = 0.5
	if not guarding:
		hitstun = 0.2
		knock = (position - from_pos).normalized() * 7.0
	if hp <= 0.0:
		if GameState.flags.get("no_death", false):
			hp = 1.0
		elif GameState.in_location and GameState.has_save():
			hp = 0.0
			cinematic = true
			GameState.defeat()
		else:
			hp = max_hp
			ki = max_ki
			position = Vector3(arena.get_center().x, 0, arena.get_center().y)

func _clamp() -> void:
	position.x = clampf(position.x, arena.position.x + 0.5, arena.end.x - 0.5)
	position.z = clampf(position.z, arena.position.y + 0.5, arena.end.y - 0.5)

func _process(delta: float) -> void:
	_update_prompt()
	if cinematic:
		return
	var t := Time.get_ticks_msec() / 1000.0
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(facing.x, facing.z), 14.0 * delta)

	var bob := sin(t * 2.0) * 0.01
	var lean := 0.0
	var lunge := Vector3.ZERO
	var ap: AnimationPlayer = visual.get_meta("anim", null)
	if ap:  # the rig animates her; only a lean when running and the knock-back remain
		_animate_rig(ap)
		bob = 0.0
		lean = 0.12 if running and _moving else 0.0
	else:
		if _moving:
			bob = absf(sin(t * (15.0 if running else 10.0))) * 0.06
			lean = 0.2 if running else 0.07
		if attack_timer > 0.0:
			var k := attack_timer / ATTACK_TIME
			lunge = facing * k * 0.35
			lean += 0.3 * k
	if hitstun > 0.0:
		lean = -0.35
	visual.position = Vector3(0, bob, 0) + lunge
	visual.rotation.x = lean
	visual.scale = Vector3(1, 0.93 if guarding else 1.0, 1)

	if form == 2:  # the Void: pieces of her are not there
		var gap := int(t * 9.0) % 4 == 0
		for m: StandardMaterial3D in visual.get_meta("mats", []) + visual.get_meta("hair_mats", []):
			var c: Color = m.albedo_color
			c.a = 0.35 if gap else 1.0
			m.albedo_color = c
		var face: FaceRig = visual.get_meta("face", null)
		if face:
			face.set_alpha(0.35 if gap else 1.0)
	if form > 0:
		_form_fx.scale = Vector3.ONE * (1.0 + (0.12 * sin(t * 20.0) if form == 2 else 0.0))

	_barrier_fx.visible = barrier
	_guard_fx.visible = guarding
	_aura_fx.visible = ki_charging
	if charge_hold < float(GameState.charge_info()["delay"]):
		_aura_fx.scale = Vector3.ONE * (0.55 + 0.4 * charge_hold / float(GameState.charge_info()["delay"]))
	else:
		_aura_fx.scale = Vector3.ONE * (1.0 + 0.1 * sin(t * 18.0))
	_charge_fx.visible = charging and charge_time > 0.1
	if _charge_fx.visible:
		_charge_fx.position = Vector3(0, 1.0, 0) + facing * 0.8
		_charge_fx.scale = Vector3.ONE * (1.0 + charge_level() * 1.2 + 0.2 * sin(t * 25.0))
	_swing_fx.visible = attack_timer > 0.0
	if _swing_fx.visible:
		_swing_fx.position = Vector3(0, 1.0, 0) + facing * 1.0
		_swing_fx.scale = Vector3.ONE * (1.0 + combo_step * 0.25 + (1.2 if heavy_swing > 0.0 else 0.0))
	_heavy_fx.visible = heavy_winding()
	if _heavy_fx.visible:
		var ready_k := clampf((attack_hold - HEAVY_DELAY) / HEAVY_CHARGE, 0.0, 1.0)
		_heavy_fx.position = Vector3(0, 1.1, 0) + facing * 0.6
		_heavy_fx.scale = Vector3.ONE * (0.5 + ready_k * 0.8 + (0.25 * sin(t * 30.0) if ready_k >= 1.0 else 0.0))

func _update_prompt() -> void:
	if GameState.input_locked or cinematic:
		return
	var it := _nearest_interactable()
	Overlay.set_prompt("E: %s" % it.prompt if it else "")
