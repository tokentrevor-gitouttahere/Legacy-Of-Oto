class_name BodyShape
extends RefCounted
## Reshapes the female base mesh: bust, waist, hips, butt, stomach (docs/BODY_STUDY.md).
## Amounts are centimetres on a 170 cm figure; negative reduces. Everything is a smooth function
## of the point's position, so the points the mesh repeats (its seams) move together.
## tools/body_shape.py is the same function in Python; dev_tests checks the two agree.
##
##   var shaper := BodyShape.new(load("res://assets/models/base_female/model_0.obj"))
##   var mesh := shaper.shape({"bust": 2.0, "waist": -1.2})     # a new ArrayMesh; the source is untouched
##
## A reshaped body for the full figure: set the wrapper's "skin_hook" meta to
## BodyShape.skin_hook(shaper, delta) before Outfits.apply (Rig.attach calls it).

## The sliders: label, range (cm). The ranges are what still looks good on this mesh.
const PARAMS := {
	"bust": {"label": "Bust", "min": -2.0, "max": 6.0},
	"waist": {"label": "Waist", "min": -3.0, "max": 3.0},
	"hips": {"label": "Hips", "min": -3.0, "max": 4.0},
	"butt": {"label": "Butt", "min": -2.0, "max": 6.0},
	"stomach": {"label": "Stomach", "min": -2.0, "max": 3.0},
}
const CM := 170.0
const PRESETS_PATH := "res://assets/models/body_presets.json"
const SOURCE := "res://assets/models/base_female/model_0.obj"
## Oto's own body. No other woman may share these exact proportions (dev_tests checks the
## presets, and the editor refuses to save a copy under another name).
const OTO := "Oto Body Final"

# Where things are on the base mesh, in body heights (x across, w up from the soles, z forward).
const WAIST := [0.625, 0.075, 0.075, 0.053]  # centre, reach up, reach down, half-width it changes
const HIPS := [0.50, 0.085, 0.14, 0.094]
const BUST_RADII := Vector3(0.06, 0.075, 0.08)
const BUTT_C := Vector3(0.04, 0.515, -0.045)
const BUTT_RADII := Vector3(0.07, 0.075, 0.07)
const STOMACH_C := Vector3(0.0, 0.57, 0.045)
const STOMACH_RADII := Vector3(0.08, 0.085, 0.09)
const TORSO_Z := 0.02

var aabb: AABB                     # the source mesh's bounds
var verts: PackedVector3Array      # the source points
var tris: PackedInt32Array
var _arrays: Array
var _normals: PackedVector3Array   # the source's own normals
var _welded0: PackedVector3Array   # smooth normals shared by points at the same position
var _weld: PackedInt32Array        # point -> group of points at the same position
var _groups := 0
var _o := Vector3.ZERO
var _h := 1.0
var _p: PackedVector3Array         # the points in body coordinates
var _bust_c: Array[Vector3] = []   # each breast's centre, left (-x) then right

func _init(mesh: Mesh) -> void:
	aabb = mesh.get_aabb()
	_arrays = mesh.surface_get_arrays(0)
	verts = _arrays[Mesh.ARRAY_VERTEX]
	_normals = _arrays[Mesh.ARRAY_NORMAL]
	tris = _arrays[Mesh.ARRAY_INDEX] if _arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if tris.is_empty():
		for i in verts.size():
			tris.append(i)
	var lo := verts[0]
	var hi := verts[0]
	for v in verts:
		lo = lo.min(v)
		hi = hi.max(v)
	_h = hi.y - lo.y
	_o = Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5)
	_p.resize(verts.size())
	for i in verts.size():
		_p[i] = (verts[i] - _o) / _h
	var ids := {}
	_weld.resize(verts.size())
	for i in verts.size():
		var key := Vector3i((verts[i] * 1e6).round())
		if not ids.has(key):
			ids[key] = ids.size()
		_weld[i] = ids[key]
	_groups = ids.size()
	_welded0 = _smooth_normals(verts)
	for s: float in [-1.0, 1.0]:
		var top := PackedVector3Array()
		var zmax := -1e9
		for q in _p:
			if q.y > 0.65 and q.y < 0.75 and s * q.x > 0.008 and s * q.x < 0.07 and q.z > 0.06:
				top.append(q)
				zmax = maxf(zmax, q.z)
		var sum := Vector3.ZERO
		var n := 0
		for q in top:
			if q.z > zmax - 0.006:
				sum += q
				n += 1
		var c := sum / maxf(n, 1)
		c.z -= 0.015  # a little inside, so the surface sits at the peak of the falloff
		_bust_c.append(c)

static func bump(d: float) -> float:
	return 0.5 * (1.0 + cos(PI * clampf(d, 0.0, 1.0)))

## Smooth normals, shared by every point at one position.
func _smooth_normals(pts: PackedVector3Array) -> PackedVector3Array:
	var acc := PackedVector3Array()
	acc.resize(_groups)
	for t in range(0, tris.size(), 3):
		var a := pts[tris[t]]
		var fn := (pts[tris[t + 2]] - a).cross(pts[tris[t + 1]] - a)  # Godot's front faces are clockwise
		acc[_weld[tris[t]]] += fn
		acc[_weld[tris[t + 1]]] += fn
		acc[_weld[tris[t + 2]]] += fn
	var out := PackedVector3Array()
	out.resize(pts.size())
	for i in pts.size():
		var n := acc[_weld[i]]
		out[i] = n.normalized() if n.length_squared() > 1e-24 else Vector3(0, 0, 1)
	return out

## One soft ellipsoid of push: along the surface normal blended with straight forward (or back,
## `toward` = -1), sagging by `droop`. Added to `d` for the point `i`.
func _inflate(i: int, centre: Vector3, radii: Vector3, amount: float, forward: float, droop: float, toward: float) -> Vector3:
	var q := (_p[i] - centre) / radii
	var dist := q.length()
	if dist >= 1.0:
		return Vector3.ZERO
	var k := amount * bump(dist)
	var out := (_welded0[i] * (1.0 - forward) + Vector3(0, 0, forward * toward)) * k
	out.y -= droop * k
	return out

## How far each source point moves, in the mesh's units.
func delta(amounts: Dictionary) -> PackedVector3Array:
	var bust: float = amounts.get("bust", 0.0)
	var waist: float = amounts.get("waist", 0.0)
	var hips: float = amounts.get("hips", 0.0)
	var butt: float = amounts.get("butt", 0.0)
	var stomach: float = amounts.get("stomach", 0.0)
	var out := PackedVector3Array()
	out.resize(verts.size())
	for i in verts.size():
		var p := _p[i]
		var d := Vector3.ZERO
		if bust != 0.0:
			var side := 1 if p.x > 0.0 else 0  # each breast moves only its own side: the gap stays
			if p.x != 0.0:
				d += _inflate(i, _bust_c[side], BUST_RADII, bust / CM, 0.5, 0.25, 1.0)
		if butt != 0.0 and p.x != 0.0:
			var sx := 1.0 if p.x > 0.0 else -1.0
			d += _inflate(i, Vector3(sx * BUTT_C.x, BUTT_C.y, BUTT_C.z), BUTT_RADII, butt / CM, 0.5, 0.0, -1.0)
		if stomach != 0.0:
			d += _inflate(i, STOMACH_C, STOMACH_RADII, stomach / CM, 0.6, 0.0, 1.0)
		for e: Array in [[waist, WAIST], [hips, HIPS]]:
			var amount: float = e[0]
			if amount == 0.0:
				continue
			var spec: Array = e[1]
			var centre: float = spec[0]
			var band := bump((p.y - centre) / float(spec[1])) if p.y > centre else bump((centre - p.y) / float(spec[2]))
			if band <= 0.0:
				continue
			var k := (amount / CM) / float(spec[3])
			d.x += p.x * k * band
			d.z += (p.z - TORSO_Z) * k * 0.6 * band
		out[i] = d * _h
	return out

## A new mesh with the shape applied (points and normals); the source mesh is not changed.
func shape(amounts: Dictionary) -> ArrayMesh:
	return shaped_mesh(delta(amounts))

func shaped_mesh(d: PackedVector3Array) -> ArrayMesh:
	var moved := PackedVector3Array()
	moved.resize(verts.size())
	for i in verts.size():
		moved[i] = verts[i] + d[i]
	var n1 := _smooth_normals(moved)
	var nrm := PackedVector3Array()
	nrm.resize(verts.size())
	for i in verts.size():  # keep any hard edge the source had, add the change in shape
		nrm[i] = (_normals[i] + (n1[i] - _welded0[i])).normalized()
	var arr := _arrays.duplicate()
	arr[Mesh.ARRAY_VERTEX] = moved
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_COLOR] = tint_colors(d)
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return out

## A soft area of darker skin on each breast, on the most forward point of the shaped surface: it
## only suggests where an areola would be, with no edge, no detail and nothing raised, for the
## day an outfit leaves her chest bare. A multiplier on the skin colour (the body material uses
## vertex colours), white everywhere else.
const AREOLA_RADIUS := 0.0155  # body heights (about 2.6 cm)
const AREOLA_DARKEN := Vector3(0.16, 0.27, 0.29)  # what it takes off red, green, blue at its centre

func tint_colors(d: PackedVector3Array) -> PackedColorArray:
	var out := PackedColorArray()
	out.resize(verts.size())
	out.fill(Color.WHITE)
	var body := PackedVector3Array()
	body.resize(verts.size())
	for i in verts.size():
		body[i] = (verts[i] + d[i] - _o) / _h
	for side in 2:
		var c := _bust_c[side]
		var apex := -1
		for i in verts.size():  # the most forward point near this breast's centre
			var q := body[i]
			if (q.x > 0.0) == (side == 1) and absf(q.x - c.x) < 0.03 and absf(q.y - c.y) < 0.03 and (apex < 0 or q.z > body[apex].z):
				apex = i
		if apex < 0:
			continue
		for i in verts.size():
			var dist := (body[i] - body[apex]).length()
			if dist < AREOLA_RADIUS and body[i].z > body[apex].z - 0.02:
				var w := 1.0 - smoothstep(AREOLA_RADIUS * 0.4, AREOLA_RADIUS, dist)
				out[i] = Color(1.0 - AREOLA_DARKEN.x * w, 1.0 - AREOLA_DARKEN.y * w, 1.0 - AREOLA_DARKEN.z * w)
	return out

# --- presets -----------------------------------------------------------------------------------

## name -> {bust, waist, hips, butt, stomach} in cm (the file holds them under "presets").
static func load_presets() -> Dictionary:
	if not FileAccess.file_exists(PRESETS_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PRESETS_PATH))
	if parsed is Dictionary and (parsed as Dictionary).get("presets") is Dictionary:
		return (parsed as Dictionary)["presets"]
	return {}

## Writes every preset (this only works when the game runs from its project folder).
static func save_presets(presets: Dictionary) -> bool:
	var f := FileAccess.open(PRESETS_PATH, FileAccess.WRITE)
	if f == null:
		return false
	var table := {
		"_doc": "Body shapes for the female base mesh, in cm on a 170 cm figure (negative reduces). Made with scenes/body_editor.tscn; read by scripts/characters/body_shape.gd and tools/body_shape.py --preset.",
		"presets": presets,
	}
	f.store_string(JSON.stringify(table, "  ", true) + "\n")
	return true

# --- builds the game uses ----------------------------------------------------------------------

static var _shaper: BodyShape
static var _built := {}  # build name -> {"amounts", "delta", "mesh"}

## A named build's amounts (cm), from the presets file; {} when there is none by that name.
static func amounts_of(build: String) -> Dictionary:
	return load_presets().get(build, {})

## Are these the same proportions (to a tenth of a cm)?
static func same_shape(a: Dictionary, b: Dictionary) -> bool:
	for k: String in PARAMS:
		if absf(float(a.get(k, 0.0)) - float(b.get(k, 0.0))) > 0.05:
			return false
	return true

## Give a female-base wrapper the body of a named build ("" puts the plain base back): the static
## mesh the outfit is built on, and the hook that moves the skinned body to match when Rig.attach
## runs. Shaping takes about 0.1 s and is kept, so every figure of one build shares it.
static func set_build(visual: Node3D, build: String) -> void:
	var body := visual.get_child(0).get_child(0) as MeshInstance3D
	if not visual.has_meta("base_body"):
		visual.set_meta("base_body", body.mesh)
	visual.remove_meta("skin_hook")
	visual.remove_meta("build_amounts")
	visual.remove_meta("build_name")
	if build == "":
		body.mesh = visual.get_meta("base_body")
		return
	if visual.get_meta("model_key", "") != "oto":
		push_warning("BodyShape: builds are made for the female base; '%s' ignored" % build)
		return
	if not _built.has(build):
		var amounts := amounts_of(build)
		if amounts.is_empty():
			push_warning("BodyShape: no build called '%s' in %s" % [build, PRESETS_PATH])
			body.mesh = visual.get_meta("base_body")
			return
		if _shaper == null:
			_shaper = BodyShape.new(load(SOURCE) as Mesh)
		var d := _shaper.delta(amounts)
		_built[build] = {"amounts": amounts, "delta": d, "mesh": _shaper.shaped_mesh(d)}
	var b: Dictionary = _built[build]
	body.mesh = b["mesh"]
	visual.set_meta("build_amounts", b["amounts"])
	visual.set_meta("build_name", build)
	visual.set_meta("skin_hook", skin_hook(_shaper, b["delta"], visual, build))

## The base landmarks (fractions of height) moved to fit a build: the depth of the chest, the width
## and depth of the waist and hips. The fitted clothing measures the real body; these are for the
## pieces that are placed from landmarks (the sash, the scapular's width).
static func landmarks(base: Dictionary, amounts: Dictionary) -> Dictionary:
	var out := base.duplicate()
	var bust: float = amounts.get("bust", 0.0) / CM
	var waist: float = amounts.get("waist", 0.0) / CM
	var hips: float = amounts.get("hips", 0.0) / CM
	var butt: float = amounts.get("butt", 0.0) / CM
	var stomach: float = amounts.get("stomach", 0.0) / CM
	out["chest_hd"] = float(base["chest_hd"]) + bust * 0.5
	out["chest_z"] = float(base["chest_z"]) + bust * 0.5
	out["waist_hw"] = float(base["waist_hw"]) + waist
	out["waist_hd"] = float(base["waist_hd"]) + waist * 0.6 * float(base["waist_hd"]) / float(base["waist_hw"]) + stomach * 0.5
	out["hip_hw"] = float(base["hip_hw"]) + hips
	# the butt is not added to hip_hd: the pieces that use it centre on z = 0 and her seat sticks out
	# behind only (cloth that hangs over it measures the real body instead)
	out["hip_hd"] = float(base["hip_hd"]) + hips * 0.6 * float(base["hip_hd"]) / float(base["hip_hw"])
	return out

# --- the full figure ---------------------------------------------------------------------------

static var _skin_arrays: Array = []  # the skinned (Mixamo) body as its file has it
static var _skin_done := {}  # build name -> [moved arrays, flags]: the match is made once per build

## A callable for a wrapper's "skin_hook" meta: Rig.attach hands it its own skeleton and skinned
## body, and it moves that body the way the static mesh moved. Each point takes the displacement
## of the nearest source point (they are the same surface). Every figure shares one skinned mesh
## resource, so this never edits it: each figure gets a mesh of its own. `key` names the build,
## so the match (about 0.3 s) is made only once.
static func skin_hook(shaper: BodyShape, d: PackedVector3Array, visual: Node3D, key := "") -> Callable:
	return func(sk: Skeleton3D, bmi: MeshInstance3D) -> void: _reshape_skin(sk, bmi, visual, shaper, d, key)

static func _reshape_skin(sk: Skeleton3D, bmi: MeshInstance3D, visual: Node3D, shaper: BodyShape, d: PackedVector3Array, build_key: String) -> void:
	if build_key != "" and _skin_done.has(build_key):
		var done: Array = _skin_done[build_key]
		var again := ArrayMesh.new()
		again.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, (done[0] as Array).duplicate(), [], {}, done[1])
		bmi.mesh = again
		return
	var static_rig := visual.get_child(0) as Node3D
	if _skin_arrays.is_empty():
		_skin_arrays = (bmi.mesh as ArrayMesh).surface_get_arrays(0)
	var arr := _skin_arrays.duplicate(true)
	# Mixamo's skin carries 8 bone weights a point; the surface must be re-added with that flag
	# or Godot reads the weights as 4 a point and the body bends wrongly
	var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if (arr[Mesh.ARRAY_BONES] as PackedInt32Array).size() == 8 * (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() else 0
	# the alignment Rig.attach makes for the unchanged body, to match each point to the source
	var rest := Rig._rest_body(sk, bmi)
	var pos: PackedVector3Array = rest["pos"]
	var rig_box := Rig._box(pos)
	var st_box: AABB = static_rig.transform * shaper.aabb
	var k := st_box.size.y / rig_box.size.y
	var inst_xf := Transform3D(Basis.from_scale(Vector3.ONE * k), st_box.get_center() - rig_box.get_center() * k)
	var to_obj := static_rig.transform.affine_inverse() * inst_xf  # skinned rest space -> source units
	var cell := 0.02
	var grid := {}
	for j in shaper.verts.size():
		var key := Vector3i((shaper.verts[j] / cell).floor())
		if not grid.has(key):
			grid[key] = []
		grid[key].append(j)
	var place := sk.transform * bmi.transform
	var to_local := place.basis.inverse() * inst_xf.basis.inverse() * static_rig.transform.basis
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var tint := shaper.tint_colors(d)
	var colors := PackedColorArray()
	colors.resize(verts.size())
	colors.fill(Color.WHITE)
	for i in verts.size():
		var u := to_obj * pos[i]
		var c := Vector3i((u / cell).floor())
		var best := -1
		var best_d := 1e9
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				for dz in range(-1, 2):
					for j: int in grid.get(c + Vector3i(dx, dy, dz), []):
						var dd := u.distance_squared_to(shaper.verts[j])
						if dd < best_d:
							best_d = dd
							best = j
		if best >= 0:
			colors[i] = tint[best]
			if d[best].length_squared() > 1e-18:
				verts[i] += to_local * d[best]
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = colors
	if arr[Mesh.ARRAY_NORMAL] != null:
		arr[Mesh.ARRAY_NORMAL] = _skin_normals(verts, arr[Mesh.ARRAY_INDEX])
	if build_key != "":
		_skin_done[build_key] = [arr.duplicate(), flags]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
	bmi.mesh = mesh

static func _skin_normals(verts: PackedVector3Array, idx: PackedInt32Array) -> PackedVector3Array:
	var span := 0.0
	for p in verts:
		span = maxf(span, absf(p.y))
	var scale_k := 100000.0 / span
	var sums := {}
	for t in range(0, idx.size(), 3):
		var a := verts[idx[t]]
		var fn := (verts[idx[t + 2]] - a).cross(verts[idx[t + 1]] - a)
		for k in 3:
			var key := Vector3i((verts[idx[t + k]] * scale_k).round())
			sums[key] = sums.get(key, Vector3.ZERO) + fn
	var out := PackedVector3Array()
	out.resize(verts.size())
	for i in verts.size():
		var n: Vector3 = sums.get(Vector3i((verts[i] * scale_k).round()), Vector3.UP)
		out[i] = n.normalized() if n.length_squared() > 1e-24 else Vector3.UP
	return out

## Oto (or any preset on the female base) dressed on a reshaped body: the static mesh, the
## outfit built on it, and the skinned body moved to match. `preset` is an Outfits preset.
func dressed(amounts: Dictionary, preset := "oto") -> Node3D:
	var mine := same_shape(amounts, amounts_of(OTO))
	if preset in Outfits.OTO_PRESETS and not mine:  # her outfit is hers: any other shape gets a plain one
		preset = "civilian_f"
	var d := delta(amounts)
	var visual := ModelLoader.make(Outfits.model_for(preset))
	var body := visual.get_child(0).get_child(0) as MeshInstance3D
	body.mesh = shaped_mesh(d)
	visual.set_meta("skin_hook", skin_hook(self, d, visual))
	visual.set_meta("build_amounts", amounts)
	if mine:
		visual.set_meta("build_name", OTO)
	visual.set_meta("custom_body", true)  # Outfits.apply leaves this body as it is
	Outfits.apply(visual, preset)
	visual.scale = Vector3.ONE * float(Outfits.PRESETS.get(preset, {}).get("scale", 1.0))
	return visual
