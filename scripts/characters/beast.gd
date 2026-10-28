class_name Beast
extends Node3D
## Procedural low-poly animals for wild areas: Beast.make("wolf", tint). Faces +Z and stands
## on y = 0 like the character models. Enemy calls animate() every frame with a gait phase
## that advances with distance walked, so legs swing only while it moves.
## Kinds: wolf, boar, raptor, scorpion, crab, pterodactyl (flies at fly_height).

const KINDS := ["wolf", "boar", "raptor", "scorpion", "crab", "pterodactyl"]

var kind := ""
var bar_height := 1.4
var fly_height := 0.0
var legs: Array[Node3D] = []
var leg_phase: Array[float] = []
var wings: Array[Node3D] = []
var body: Node3D  # bobs while walking; legs are not under it
var tail: Node3D
var _tint := Color.WHITE

static func make(k: String, tint := Color.WHITE) -> Beast:
	var b := Beast.new()
	b.kind = k
	b.name = "Beast_" + k
	b._tint = tint
	b.body = Node3D.new()
	b.body.name = "body"
	b.add_child(b.body)
	match k:
		"wolf":
			b._wolf()
		"boar":
			b._boar()
		"raptor":
			b._raptor()
		"scorpion":
			b._scorpion()
		"crab":
			b._crab()
		"pterodactyl":
			b._pterodactyl()
		_:
			push_warning("Beast: unknown kind '%s'" % k)
			b._wolf()
	return b

func animate(gait: float, moving: bool, _telegraph: bool, t: float) -> void:
	var amp := 0.55 if moving else 0.0
	for i in legs.size():
		legs[i].rotation.x = sin(gait + leg_phase[i]) * amp
	body.position.y = (absf(sin(gait)) * 0.05) if moving else sin(t * 2.0) * 0.012
	if tail:
		tail.rotation.y = sin(t * (6.0 if moving else 2.5)) * 0.3
	for w in wings:
		w.rotation.z = float(w.get_meta("side")) * sin(t * 7.0) * 0.6
	if fly_height > 0.0:
		body.position.y += fly_height + sin(t * 2.2) * 0.15

# --- kinds ------------------------------------------------------------------

func _wolf() -> void:
	var fur := _m(Color(0.47, 0.47, 0.5), "noise", 2.0)
	var dark := _m(Color(0.22, 0.22, 0.24))
	Props._box(body, Vector3(0, 0.62, -0.05), Vector3(0.42, 0.42, 0.95), fur)
	Props._ball(body, Vector3(0, 0.68, 0.38), 0.27, fur)
	Props._box(body, Vector3(0, 0.86, 0.7), Vector3(0.3, 0.28, 0.32), fur)
	Props._box(body, Vector3(0, 0.8, 0.93), Vector3(0.16, 0.14, 0.24), fur)
	Props._ball(body, Vector3(0, 0.82, 1.05), 0.04, dark)
	for x: float in [-0.09, 0.09]:
		Props._cyl(body, Vector3(x, 0.98, 0.66), 0.0, 0.065, 0.17, fur, 6)
		Props._ball(body, Vector3(x, 0.9, 0.87), 0.025, _glow(Color(1.0, 0.85, 0.3)))
	tail = _pivot(body, Vector3(0, 0.72, -0.5))
	var t := _pivot(tail, Vector3.ZERO)
	t.rotation.x = -2.3
	Props._cyl(t, Vector3.ZERO, 0.03, 0.08, 0.5, fur, 6)
	for side: float in [-1.0, 1.0]:
		_leg(Vector3(0.15 * side, 0.46, 0.33), 0.46, 0.06, fur, 0.0 if side < 0 else PI)
		_leg(Vector3(0.15 * side, 0.46, -0.38), 0.46, 0.06, fur, PI if side < 0 else 0.0)
	bar_height = 1.35

func _boar() -> void:
	var hide_m := _m(Color(0.42, 0.28, 0.18), "noise", 2.0)
	var bristle := _m(Color(0.2, 0.13, 0.09))
	Props._ball(body, Vector3(0, 0.62, 0), 0.46, hide_m).scale = Vector3(1.0, 0.82, 1.45)
	Props._box(body, Vector3(0, 0.98, -0.05), Vector3(0.12, 0.14, 0.85), bristle)
	Props._box(body, Vector3(0, 0.62, 0.72), Vector3(0.38, 0.36, 0.36), hide_m)
	var snout := _pivot(body, Vector3(0, 0.56, 0.9))
	snout.rotation.x = PI / 2
	Props._cyl(snout, Vector3.ZERO, 0.11, 0.12, 0.1, _m(Color(0.75, 0.5, 0.45)))
	for x: float in [-0.13, 0.13]:
		var tusk := _pivot(body, Vector3(x, 0.5, 0.88))
		tusk.rotation = Vector3(-0.6, 0, 0.4 * signf(x))
		Props._cyl(tusk, Vector3.ZERO, 0.0, 0.035, 0.2, _m(Color(0.95, 0.93, 0.85)), 6)
		Props._box(body, Vector3(x, 0.86, 0.66), Vector3(0.08, 0.12, 0.05), hide_m)
		Props._ball(body, Vector3(x, 0.7, 0.9), 0.025, _m(Color(0.05, 0.03, 0.02)))
	tail = _pivot(body, Vector3(0, 0.7, -0.65))
	Props._cyl(tail, Vector3(0, -0.2, 0), 0.02, 0.03, 0.2, bristle, 5)
	for side: float in [-1.0, 1.0]:
		_leg(Vector3(0.22 * side, 0.36, 0.38), 0.36, 0.07, bristle, 0.0 if side < 0 else PI)
		_leg(Vector3(0.22 * side, 0.36, -0.38), 0.36, 0.07, bristle, PI if side < 0 else 0.0)
	bar_height = 1.35

func _raptor() -> void:
	var scale_m := _m(Color(0.32, 0.52, 0.26), "noise", 2.0)
	var belly := _m(Color(0.75, 0.72, 0.5))
	Props._ball(body, Vector3(0, 1.0, 0), 0.32, scale_m).scale = Vector3(0.8, 0.85, 1.4)
	Props._ball(body, Vector3(0, 0.92, 0.12), 0.22, belly).scale = Vector3(0.9, 0.7, 1.2)
	tail = _pivot(body, Vector3(0, 1.02, -0.35))
	var t := _pivot(tail, Vector3.ZERO)
	t.rotation.x = -PI / 2 + 0.15
	Props._cyl(t, Vector3.ZERO, 0.0, 0.17, 1.1, scale_m, 8)
	var neck := _pivot(body, Vector3(0, 1.12, 0.32))
	neck.rotation.x = 0.55
	Props._cyl(neck, Vector3.ZERO, 0.08, 0.11, 0.42, scale_m, 8)
	Props._box(body, Vector3(0, 1.5, 0.62), Vector3(0.2, 0.2, 0.42), scale_m)
	Props._box(body, Vector3(0, 1.4, 0.68), Vector3(0.16, 0.06, 0.34), belly)
	for x: float in [-0.08, 0.08]:
		Props._ball(body, Vector3(x, 1.56, 0.72), 0.025, _glow(Color(1.0, 0.8, 0.2)))
		var arm := _pivot(body, Vector3(x * 2.0, 1.0, 0.42))
		arm.rotation.x = 2.3
		Props._cyl(arm, Vector3.ZERO, 0.025, 0.035, 0.25, scale_m, 5)
	for side: float in [-1.0, 1.0]:
		var hip := _leg(Vector3(0.17 * side, 0.9, 0.0), 0.88, 0.08, scale_m, 0.0 if side < 0 else PI)
		Props._box(hip, Vector3(0, -0.88, 0.08), Vector3(0.12, 0.05, 0.24), scale_m)
	bar_height = 2.0

func _scorpion() -> void:
	var shell := _m(Color(0.4, 0.28, 0.16), "noise", 3.0, {"rough": 0.4})
	var dark := _m(Color(0.18, 0.12, 0.08))
	Props._ball(body, Vector3(0, 0.34, 0), 0.36, shell).scale = Vector3(1.0, 0.45, 1.35)
	tail = _pivot(body, Vector3(0, 0.4, -0.45))
	var segs := [Vector3(0, 0.06, -0.1), Vector3(0, 0.26, -0.24), Vector3(0, 0.48, -0.3), Vector3(0, 0.7, -0.24), Vector3(0, 0.86, -0.08)]
	for i in segs.size():
		Props._ball(tail, segs[i], 0.15 - i * 0.012, shell)
	var sting := _pivot(tail, Vector3(0, 0.88, 0.05))
	sting.rotation.x = 2.2
	Props._cyl(sting, Vector3.ZERO, 0.0, 0.06, 0.22, dark, 6)
	for side: float in [-1.0, 1.0]:
		Props._box(body, Vector3(0.3 * side, 0.33, 0.52), Vector3(0.1, 0.08, 0.38), shell)
		Props._box(body, Vector3(0.36 * side, 0.33, 0.82), Vector3(0.2, 0.1, 0.24), dark)
		for i in 3:
			_splay_leg(Vector3(0.28 * side, 0.32, 0.22 - i * 0.22), side, 0.36, dark, i * 2.1 + (0.0 if side < 0 else PI))
	bar_height = 1.5

func _crab() -> void:
	var shell := _m(Color(0.86, 0.36, 0.2), "noise", 3.0)
	var light := _m(Color(0.95, 0.75, 0.6))
	Props._ball(body, Vector3(0, 0.34, 0), 0.4, shell).scale = Vector3(1.45, 0.5, 1.0)
	for side: float in [-1.0, 1.0]:
		Props._cyl(body, Vector3(0.12 * side, 0.45, 0.28), 0.02, 0.025, 0.16, shell, 5)
		Props._ball(body, Vector3(0.12 * side, 0.63, 0.28), 0.045, _m(Color(0.05, 0.05, 0.05)))
		Props._ball(body, Vector3(0.6 * side, 0.36, 0.42), 0.17, shell).scale = Vector3(1.0, 0.75, 1.3)
		Props._box(body, Vector3(0.62 * side, 0.38, 0.62), Vector3(0.08, 0.06, 0.18), light)
		for i in 3:
			_splay_leg(Vector3(0.45 * side, 0.3, 0.15 - i * 0.18), side, 0.34, shell, i * 2.1 + (0.0 if side < 0 else PI))
	bar_height = 1.1

func _pterodactyl() -> void:
	var skin := _m(Color(0.5, 0.38, 0.36), "noise", 2.0)
	var membrane := _m(Color(0.62, 0.45, 0.4), "", 1.0, {"rough": 0.8})
	Props._ball(body, Vector3.ZERO, 0.24, skin).scale = Vector3(0.8, 0.7, 1.5)
	Props._box(body, Vector3(0, 0.14, 0.42), Vector3(0.14, 0.17, 0.3), skin)
	var beak := _pivot(body, Vector3(0, 0.12, 0.56))
	beak.rotation.x = PI / 2
	Props._cyl(beak, Vector3.ZERO, 0.0, 0.06, 0.42, _m(Color(0.85, 0.75, 0.4)), 6)
	var crest := _pivot(body, Vector3(0, 0.22, 0.38))
	crest.rotation.x = -PI / 2 - 0.4
	Props._cyl(crest, Vector3.ZERO, 0.0, 0.06, 0.4, skin, 5)
	for side: float in [-1.0, 1.0]:
		var w := _pivot(body, Vector3(0.16 * side, 0.05, 0.05))
		w.set_meta("side", side)
		Props._box(w, Vector3(0.7 * side, 0, 0), Vector3(1.35, 0.03, 0.55), membrane)
		Props._box(w, Vector3(0.7 * side, 0.02, 0.24), Vector3(1.35, 0.05, 0.06), skin)
		wings.append(w)
	tail = _pivot(body, Vector3(0, 0, -0.3))
	var t := _pivot(tail, Vector3.ZERO)
	t.rotation.x = -PI / 2
	Props._cyl(t, Vector3.ZERO, 0.0, 0.05, 0.45, skin, 5)
	fly_height = 2.2
	bar_height = 3.0

# --- helpers ----------------------------------------------------------------

func _m(c: Color, tex := "", s := 1.0, extra := {}) -> StandardMaterial3D:
	return Mats.get_mat(c * _tint, tex, s, extra)

func _glow(c: Color) -> StandardMaterial3D:
	return Mats.glow(c, 1.0)

func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.position = pos
	parent.add_child(p)
	return p

## A leg hanging from `hip`, swung on X by animate(). Returns the hip pivot.
func _leg(hip: Vector3, length: float, r: float, m: Material, phase: float) -> Node3D:
	var p := _pivot(self, hip)
	Props._cyl(p, Vector3(0, -length, 0), r * 0.8, r, length, m, 6)
	legs.append(p)
	leg_phase.append(phase)
	return p

## Arthropod legs: splayed out to the side, then down.
func _splay_leg(hip: Vector3, side: float, length: float, m: Material, phase: float) -> void:
	var p := _pivot(self, hip)
	var out := _pivot(p, Vector3.ZERO)
	out.rotation.z = -1.0 * side
	Props._cyl(out, Vector3(0, -length, 0), 0.02, 0.03, length, m, 5)
	legs.append(p)
	leg_phase.append(phase)
