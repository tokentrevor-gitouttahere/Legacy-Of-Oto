class_name LifeSaiyan
extends Node3D
## The unnamed first-age Saiyan who gets stronger by spending his own life.
## His health is also his power: the lower it falls, the harder and faster he
## hits. His BossKit has two phases: at 55% HP mid_reached (the "burning yourself down"
## exchange), and at 25% he stops and emits threshold_reached (the cutscene trigger).

signal mid_reached
signal threshold_reached

var arena := Rect2(-18, -12, 36, 24)
var target: Player
var max_hp := 2200.0
var hp := 2200.0
var threshold := 0.25
var frozen := false

var hitstun := 0.0
var knock := Vector3.ZERO
var flash := 0.0
var state := "approach"
var state_time := 0.0
var strike_dir := Vector3.ZERO
var struck := false
var cycles := 0
var kit: BossKit

var visual: Node3D
var _aura: MeshInstance3D
var _bar: MeshInstance3D

func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp
	kit = BossKit.new(self, [0.55, threshold])
	kit.phase.connect(_on_phase)
	visual = ModelLoader.make("male_base")
	add_child(visual)
	Outfits.apply(visual, "life_saiyan")
	_aura = ModelLoader.glow_sphere(1.2, Color(1.0, 0.7, 0.25, 0.25))
	_aura.position.y = 0.9
	add_child(_aura)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 0.12)
	var bar_mat := StandardMaterial3D.new()
	bar_mat.albedo_color = Color(0.95, 0.65, 0.2)
	bar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bar_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_bar = MeshInstance3D.new()
	_bar.mesh = quad
	_bar.material_override = bar_mat
	_bar.position.y = 2.2
	add_child(_bar)

## 1.0 at full health, 3.0 as he burns out.
func rage() -> float:
	return 1.0 + (1.0 - hp / max_hp) * 2.0

func hurt(amount: float, dir: Vector3, launch: bool, kind := "melee") -> void:
	if frozen:
		return
	amount = kit.incoming(amount, kind)
	hp -= amount
	DamageNumber.number(get_parent(), position, amount, DamageNumber.HEAVY_HIT if launch else DamageNumber.ENEMY_HIT, launch)
	flash = 0.12
	if launch or amount > 25.0:
		hitstun = 0.3
		knock = dir * 5.0
		_enter("approach")
	_check_threshold()

func _check_threshold() -> void:
	kit.check(hp, max_hp)

func _on_phase(index: int, _fraction: float) -> void:
	if index == 0:
		mid_reached.emit()
	else:
		frozen = true
		hp = max_hp * threshold
		threshold_reached.emit()

func _enter(s: String) -> void:
	state = s
	state_time = 0.0
	struck = false

func _physics_process(delta: float) -> void:
	var r := rage()
	flash = maxf(flash - delta, 0.0)
	_bar.scale.x = maxf(hp / max_hp, 0.01)
	_aura.scale = Vector3.ONE * (0.9 + (r - 1.0) * 0.5 + 0.08 * sin(Time.get_ticks_msec() / 90.0))
	var t := (r - 1.0) / 2.0
	visual.scale = Vector3(lerpf(1.0, 0.86, t), 1.0, lerpf(1.0, 0.86, t)) * (1.05 if flash > 0.0 else 1.0)
	if frozen or not is_instance_valid(target):
		return
	if hitstun > 0.0:
		hitstun -= delta
		position += knock * delta
		knock = knock.move_toward(Vector3.ZERO, 20.0 * delta)
		_clamp()
		return

	if hp > max_hp * threshold + 5.0:
		hp -= 1.2 * r * delta  # he is spending himself
		_check_threshold()
	state_time += delta
	var to := target.position - position
	to.y = 0
	var dist := to.length()
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(to.x, to.z), 10.0 * delta)

	match state:
		"approach":
			position += to.normalized() * 3.2 * sqrt(r) * delta
			if dist < 2.4 and state_time > 0.3:
				_enter("windup")
		"windup":
			strike_dir = to.normalized()
			_aura.scale *= 1.3
			if state_time > 0.55 / r:
				_enter("strike")
		"strike":
			position += strike_dir * 9.0 * r * delta
			if not struck and dist < 1.5:
				struck = true
				target.hurt(10.0 * r, position)
				hp -= 5.0
				_check_threshold()
			if state_time > 0.3:
				_enter("recover")
		"recover":
			if state_time > 0.7 / r:
				cycles += 1
				_enter("volley" if cycles % 3 == 0 else "approach")
		"volley":
			if state_time > 0.4:
				_fire_volley(to.normalized(), r)
				_enter("approach")
	_clamp()

func _fire_volley(dir: Vector3, r: float) -> void:
	for a in [-0.25, 0.0, 0.25]:
		var shot := KiShot.new()
		shot.hostile = true
		shot.color = Color(1.0, 0.65, 0.2, 0.9)
		shot.position = position + Vector3(0, 1.1, 0)
		shot.setup(dir.rotated(Vector3.UP, a), 0, 6.0 * r)
		get_parent().add_child(shot)

func _clamp() -> void:
	position.x = clampf(position.x, arena.position.x + 0.5, arena.end.x - 0.5)
	position.z = clampf(position.z, arena.position.y + 0.5, arena.end.y - 0.5)
