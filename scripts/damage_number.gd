class_name DamageNumber
extends Label3D
## Floating hit number (or short word): pops, rises, drifts and fades, then frees itself.

const LIFE := 0.85
const ENEMY_HIT := Color(1.0, 0.95, 0.8)
const HEAVY_HIT := Color(1.0, 0.7, 0.3)
const PLAYER_HIT := Color(1.0, 0.35, 0.35)
const GUARDED := Color(0.6, 0.75, 1.0)
const HEAL := Color(0.45, 1.0, 0.55)
const KI := Color(0.75, 0.6, 1.0)

var _t := 0.0
var _drift := Vector3.ZERO

## A number above `pos` (feet position of whoever was hit), added under `parent`.
static func number(parent: Node, pos: Vector3, amount: float, color := ENEMY_HIT, big := false) -> void:
	if amount >= 0.5:
		word(parent, pos, str(int(round(amount))), color, big)

static func word(parent: Node, pos: Vector3, text: String, color := ENEMY_HIT, big := false) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var d := DamageNumber.new()
	d.text = text
	d.modulate = color
	d.font_size = 72 if big else 52
	d.position = pos + Vector3(randf_range(-0.3, 0.3), 2.2, randf_range(-0.1, 0.1))
	d._drift = Vector3(randf_range(-0.5, 0.5), 2.2, 0)
	parent.add_child(d)

func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	pixel_size = 0.008
	outline_size = 14
	outline_modulate = Color(0, 0, 0, 0.9)
	render_priority = 10
	outline_render_priority = 9

func _process(delta: float) -> void:
	_t += delta
	position += _drift * delta
	_drift.y = maxf(_drift.y - 4.0 * delta, 0.3)
	modulate.a = clampf((LIFE - _t) / 0.3, 0.0, 1.0)
	outline_modulate.a = modulate.a * 0.9
	scale = Vector3.ONE * (1.0 + maxf(0.15 - _t, 0.0) * 4.0)
	if _t >= LIFE:
		queue_free()
