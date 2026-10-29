class_name Pickup
extends Node3D
## Things on the ground Oto collects by walking over them (gear with "magnet" widens
## the reach). Stat capsules: red = Strength, blue = Power, green = Endurance, with an
## optional tier suffix for +3 or +5 ("red3", "blue5"); they stay until collected.
## Food and ki motes (enemy drops) restore a share of HP or ki and fade after a while.

const CAPSULES := {
	"red": {"stat": "strength", "color": Color(0.9, 0.15, 0.15)},
	"blue": {"stat": "power", "color": Color(0.2, 0.4, 1.0)},
	"green": {"stat": "endurance", "color": Color(0.2, 0.85, 0.3)},
}
const FOOD := {
	"haunch": {"name": "Haunch", "hp": 0.25},
	"rice_ball": {"name": "Rice ball", "hp": 0.15},
	"fresh_fish": {"name": "Fresh fish", "hp": 0.3},
	"ki_mote": {"name": "Ki mote", "ki": 0.2},
	"senzu": {"name": "Senzu bean", "hp": 1.0, "ki": 1.0},
}
const DROP_LIFE := 14.0

var kind := "red"
var flag := ""  # placed pickups: set in GameState.flags when collected, so it stays gone
var _mesh: Node3D
var _life := DROP_LIFE
var _spin := 2.0

## "red3" -> ["red", 3]; "haunch" -> ["haunch", 0].
static func parse(k: String) -> Array:
	for base: String in CAPSULES:
		if k == base:
			return [base, 1]
		if k.begins_with(base) and k.substr(base.length()).is_valid_int():
			return [base, int(k.substr(base.length()))]
	return [k, 0]

static func is_known(k: String) -> bool:
	return FOOD.has(k) or CAPSULES.has(parse(k)[0])

func _ready() -> void:
	_mesh = Node3D.new()
	_mesh.position.y = 0.6
	add_child(_mesh)
	var p := parse(kind)
	if CAPSULES.has(p[0]):
		_build_capsule(CAPSULES[p[0]]["color"], p[1])
	else:
		_build_food()

func _build_capsule(color: Color, amount: int) -> void:
	var r := 0.18 + (0.04 if amount >= 3 else 0.0) + (0.04 if amount >= 5 else 0.0)
	var capsule := CapsuleMesh.new()
	capsule.radius = r
	capsule.height = r * 3.3
	_add(capsule, Vector3.ZERO, Mats.glow(color, 1.0))
	if amount >= 3:
		var band := TorusMesh.new()
		band.inner_radius = r * 0.95
		band.outer_radius = r * 1.25
		_add(band, Vector3.ZERO, Mats.glow(Color(1.0, 0.85, 0.3) if amount >= 5 else Color(1, 1, 1), 1.2))

func _build_food() -> void:
	match kind:
		"haunch":
			var bone := CylinderMesh.new()
			bone.top_radius = 0.04
			bone.bottom_radius = 0.05
			bone.height = 0.35
			var b := _add(bone, Vector3(0.18, 0.0, 0), Mats.get_mat(Color(0.95, 0.92, 0.85)))
			b.rotation.z = PI / 2
			var meat := SphereMesh.new()
			meat.radius = 0.2
			meat.height = 0.4
			_add(meat, Vector3(-0.05, 0, 0), Mats.get_mat(Color(0.55, 0.27, 0.12), "noise", 3.0)).scale = Vector3(1.3, 0.9, 0.9)
		"rice_ball":
			var tri := CylinderMesh.new()
			tri.top_radius = 0.2
			tri.bottom_radius = 0.2
			tri.height = 0.16
			tri.radial_segments = 3
			var t := _add(tri, Vector3.ZERO, Mats.get_mat(Color(0.97, 0.97, 0.94)))
			t.rotation = Vector3(PI / 2, 0, PI / 2)
			var nori := BoxMesh.new()
			nori.size = Vector3(0.14, 0.12, 0.18)
			_add(nori, Vector3(0, -0.1, 0), Mats.get_mat(Color(0.08, 0.15, 0.1)))
		"fresh_fish":
			var body := SphereMesh.new()
			body.radius = 0.12
			body.height = 0.24
			_add(body, Vector3.ZERO, Mats.get_mat(Color(0.6, 0.7, 0.8), "", 1.0, {"metal": 0.5, "rough": 0.3})).scale = Vector3(2.2, 1.0, 0.6)
			var tail := CylinderMesh.new()
			tail.top_radius = 0.0
			tail.bottom_radius = 0.12
			tail.height = 0.18
			_add(tail, Vector3(-0.3, 0, 0), Mats.get_mat(Color(0.5, 0.6, 0.72))).rotation.z = PI / 2
		"senzu":
			var bean := SphereMesh.new()
			bean.radius = 0.09
			bean.height = 0.18
			_add(bean, Vector3.ZERO, Mats.glow(Color(0.45, 0.85, 0.35), 0.6)).scale = Vector3(1.0, 0.75, 1.5)
		_:  # ki_mote
			_mesh.add_child(ModelLoader.glow_sphere(0.16, Color(0.8, 0.65, 1.0, 0.9)))
			_mesh.add_child(ModelLoader.glow_sphere(0.08, Color(1.0, 0.95, 1.0, 1.0)))
			_spin = 0.0

func _add(mesh: Mesh, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	_mesh.add_child(mi)
	return mi

func _process(delta: float) -> void:
	_mesh.rotation.y += delta * _spin
	_mesh.position.y = 0.6 + sin(Time.get_ticks_msec() / 300.0) * 0.1
	if FOOD.has(kind) and flag == "":
		_life -= delta
		_mesh.visible = _life > 3.0 or int(_life * 8.0) % 2 == 0
		if _life <= 0.0:
			queue_free()
			return
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null or p.cinematic:
		return
	var reach := 1.0 + GameState.gear_sum("magnet")
	if Vector2(p.position.x - position.x, p.position.z - position.z).length() < reach:
		_collect(p)

func _collect(p: Player) -> void:
	if flag != "":
		GameState.flags[flag] = true
	var parsed := parse(kind)
	if CAPSULES.has(parsed[0]):
		var stat_name: String = CAPSULES[parsed[0]]["stat"]
		var gained := GameState.add_capsule(stat_name, parsed[1])
		Sfx.play("capsule", 1.0 + int(parsed[1]) * 0.03)
		if gained > 0:
			Overlay.toast("%s capsule: %s +%d" % [String(parsed[0]).capitalize(), stat_name.capitalize(), gained])
		else:
			Overlay.toast("%s is already at its peak." % stat_name.capitalize())
	elif kind == "senzu":
		GameState.senzu += 1
		Sfx.play("key_item")
		Overlay.toast("A senzu bean. Into her pocket, for later.", 2.0)
	else:
		var f: Dictionary = FOOD[kind]
		Sfx.play("food", 1.3 if kind == "ki_mote" else 1.0)
		if f.has("hp"):
			p.heal(f["hp"])
		if f.has("ki"):
			p.restore_ki(f["ki"])
		if kind != "ki_mote":
			Overlay.toast(f["name"], 1.2)
	queue_free()
