class_name OutfitBuilder
extends RefCounted
## Builds clothing/hair meshes from body landmarks. Used by Outfits.apply().
## All landmark values are fractions of body height; H converts to metres.

var L: Dictionary
var H: float
var root := Node3D.new()
var hair_mats: Array = []
var form3_hair: Node3D = null
var gold_mats: Array = []  # unique per character: Shadow forms turn them silver (Outfits.set_silver)
var cloth_panels: Array = []
var metal_swap := {}  # gold face colours on cloth panels -> their silver
var body := {}  # Garment.body_frame of the visual, when known: fitted clothing casts onto it
var bodice_point := Callable()  # a point on the fitted bodice (theta, y), for pieces that lie on it
var bodice_mesh: Mesh = null    # the fitted bodice, for pieces that lie over it
var _sash_g := {}  # the fitted sash's shape (Garment.tube result), built on first use

func _init(landmarks: Dictionary, height: float) -> void:
	L = landmarks
	H = height

# --- landmark access ---------------------------------------------------------

func f(k: String) -> float:
	return float(L.get(k, 0.0)) * H

func pt(k: String, side := 1.0) -> Vector3:
	var a: Array = L[k]
	return Vector3(a[0] * side, a[1], 0.0) * H

func head() -> Vector3:
	var a: Array = L["head_c"]
	return Vector3(a[0], a[1], a[2]) * H

# --- primitives ---------------------------------------------------------------

static func col(v: Variant, fallback := Color.WHITE) -> Color:
	if v == null:
		return fallback
	if v is Color:
		return v
	var a: Array = v
	return Color(a[0], a[1], a[2])

func cloth(c: Color, tex := "noise", scale := 6.0) -> StandardMaterial3D:
	return Mats.get_mat(c, tex, scale, {"rough": 0.9})

## Gold that turns silver in Shadow forms: a unique material registered in gold_mats.
func metal(c: Color, rough := 0.3, metal_k := 0.65) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal_k
	m.roughness = rough
	m.set_meta("base_color", c)
	m.set_meta("silver_color", to_silver(c))
	m.set_meta("base_rough", rough)
	m.set_meta("base_metal", metal_k)
	gold_mats.append(m)
	metal_swap[c] = to_silver(c)
	return m

## A neutral silver that stands in for a gold of the same brightness (a cool tint turns
## blue once the metal reflects the sky).
static func to_silver(c: Color) -> Color:
	var l := maxf(c.r, maxf(c.g, c.b)) * 0.86
	return Color(l * 1.02, l, l * 0.96)  # a touch warm, against blue skies

func hair_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()  # unique per character: forms recolour it
	m.albedo_color = c
	m.roughness = 0.9
	m.set_meta("base_color", c)
	hair_mats.append(m)
	return m

func limb(a: Vector3, b: Vector3, ra: float, rb: float, m: Material, sides := 10, parent: Node3D = null) -> MeshInstance3D:
	var d := b - a
	if d.y < 0.0:
		var t := a
		a = b
		b = t
		var tr := ra
		ra = rb
		rb = tr
		d = -d
	if d.length() < 0.0001:
		return null
	var mesh := CylinderMesh.new()
	mesh.top_radius = rb
	mesh.bottom_radius = ra
	mesh.height = d.length()
	mesh.radial_segments = sides
	mesh.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.basis = Basis(Quaternion(Vector3.UP, d.normalized()))
	mi.position = (a + b) * 0.5
	(parent if parent else root).add_child(mi)
	return mi

func ball(c: Vector3, r: Vector3, m: Material, parent: Node3D = null) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 14
	mesh.rings = 8
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = c
	mi.scale = r
	(parent if parent else root).add_child(mi)
	return mi

func box(c: Vector3, size: Vector3, m: Material, parent: Node3D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = c
	(parent if parent else root).add_child(mi)
	return mi

func ring(y: float, rx: float, rz: float, thick: float, m: Material, z := 0.0) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 1.0 - thick
	mesh.outer_radius = 1.0
	mesh.rings = 20
	mesh.ring_segments = 6
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = Vector3(0, y, z)
	mi.scale = Vector3(rx, thick * rx * 0.8, rz)
	root.add_child(mi)
	return mi

## A thin board from a to b (its height), `w` wide along X and `t` thick: cloth lying on the body.
func slab(a: Vector3, b: Vector3, w: float, t: float, m: Material) -> MeshInstance3D:
	var d := b - a
	var mi := box((a + b) * 0.5, Vector3(w, d.length(), t), m)
	mi.basis = Basis(Quaternion(Vector3.UP, d.normalized()))
	return mi

## A ClothPanel added to the outfit (see cloth_panel.gd).
func cloth_panel(pin: Vector3, across: Vector3, w: float, length: float, cols: int, rows: int, colliders: Array, color: Color) -> ClothPanel:
	var p := ClothPanel.new()
	p.pin_center = pin
	p.across = across
	p.width = w
	p.length = length
	p.cols = cols
	p.rows = rows
	p.colliders = colliders
	p.base_color = color
	p.name = "Cloth"
	root.add_child(p)
	cloth_panels.append(p)
	return p

## Spheres along the legs and hips (in metres) that hanging cloth drapes over. `seat` ("front" or
## "back"), on a body whose mesh is known, swaps the two big hip spheres for a column of small
## ones tucked just inside her real skin on that side, so cloth lies over her belly or her seat
## (whatever shape she has) instead of standing off it or passing through.
func leg_colliders(loose := 1.4, sides: Array = [1.0, -1.0], seat := "") -> Array:
	var out: Array = []
	if seat == "" or body.is_empty():
		out = [[Vector3(0, f("hip_y"), 0.0), f("hip_hd") * 1.18], [Vector3(0, f("crotch_y"), 0.0), f("hip_hd") * 1.05]]
	else:
		out = _seat_colliders(seat == "front", sides)
	for side: float in sides:
		var x := f("leg_x") * side
		var mid := (f("crotch_y") + f("knee_y")) * 0.5
		out.append([Vector3(x, mid, 0), f("thigh_r") * loose])
		out.append([Vector3(x, f("knee_y"), 0), f("calf_r") * loose * 1.25])
		out.append([Vector3(x * 1.05, (f("knee_y") + f("ankle_y")) * 0.5, 0), f("calf_r") * loose * 1.2])
	return out

## Small spheres down one side (front or back) of her hips, each tucked just inside the outermost
## layer a ray from that side meets: her skin, or the trousers, the bodice's peplum or the sash
## over it (they stand off the skin by a couple of centimetres). The cloth hanging over them
## stands off by its own thickness.
func _seat_colliders(front: bool, sides: Array) -> Array:
	var layers := _layers()
	var out: Array = []
	var r := 0.05
	var from := f("crotch_y") - 0.05 * H  # down past the crease of the seat, over the back of the thigh
	var to := f("waist_y") - 0.012 * H
	var steps := 9
	for k in steps:
		var y := lerpf(from, to, float(k) / (steps - 1))
		var xs: Array = [0.0]
		for side: float in sides:
			xs.append(f("leg_x") * 0.9 * side)
		for x: float in xs:  # down the middle, and through the middle of each cheek or thigh
			var z := _outer_z(layers, x, y, front)
			if absf(z) < 100.0:  # a centimetre of room: cloth over cloth, whose folds stand off a little
				out.append([Vector3(x, y, z - r if front else z + r), r + 0.012])
	return out

## Her body and the fitted pieces over it that cloth hanging from the waist must clear:
## [[TriangleMesh, Transform3D], ...].
func _layers() -> Array:
	var layers: Array = [[body["tm"], body["xf"]]]
	for n in ["trousers_hips", "bodice", "sash"]:
		var mi := root.get_node_or_null(n) as MeshInstance3D
		if mi:
			layers.append([mi.mesh.generate_triangle_mesh(), mi.transform])
	return layers

## The z of the outermost layer a ray along the body meets at (x, y), from the front or the
## back; infinity (of the wrong sign) when it meets none.
func _outer_z(layers: Array, x: float, y: float, front: bool) -> float:
	var z := -INF if front else INF
	for layer: Array in layers:
		var hit := Face.cast(layer[0], layer[1], Vector3(x, y, 3.0 if front else -3.0), Vector3(0, 0, -1.0 if front else 1.0))
		if not hit.is_empty():
			var hz: float = (hit["position"] as Vector3).z
			z = maxf(z, hz) if front else minf(z, hz)
	return z

## An elliptical vertical tube (torso, skirt) from y0 (radius w0) to y1 (radius w1).
func tube(y0: float, y1: float, w0: float, w1: float, depth_ratio: float, m: Material, z := 0.0) -> MeshInstance3D:
	var mi := limb(Vector3(0, y0, 0), Vector3(0, y1, 0), w0, w1, m, 16)
	mi.scale = Vector3(1, 1, depth_ratio)
	mi.position.z = z
	return mi

# --- whole outfit -------------------------------------------------------------

func build(spec: Dictionary) -> void:
	if spec.has("hair"):
		_hair(spec["hair"])
	if spec.has("top"):
		_top(spec["top"])
	if spec.has("bottom"):
		_bottom(spec["bottom"])
	if spec.has("feet"):
		_feet(spec["feet"])
	for a in spec.get("acc", []):
		_acc(a)

# --- torso --------------------------------------------------------------------

func _shell(c: Color, loose: float) -> void:
	var m := cloth(c)
	var dr := f("chest_hd") / maxf(f("chest_hw"), 0.001)
	var wr := f("waist_hd") / maxf(f("waist_hw"), 0.001)
	tube(f("waist_y") - 0.02 * H, f("chest_y"), f("waist_hw") * loose, f("chest_hw") * loose, (dr + wr) * 0.5, m, f("chest_z"))
	var top_r := maxf(f("neck_r") * 1.6, f("shoulder_x") * 0.85) * loose
	tube(f("chest_y"), f("shoulder_y") + 0.01 * H, f("chest_hw") * loose, top_r, dr, m, f("chest_z") * 0.5)

func _sleeves(c: Color, length: String, loose: float) -> void:
	if length == "none":
		return
	var m := cloth(c)
	for side: float in [1.0, -1.0]:
		var a := pt("arm_root", side)
		var e := pt("elbow", side)
		var w := pt("wrist", side)
		ball(a, Vector3.ONE * f("arm_r") * 1.5 * loose, m)
		if length == "short":
			limb(a, a.lerp(e, 0.6), f("arm_r") * 1.35 * loose, f("arm_r") * 1.3 * loose, m)
		else:
			limb(a, e, f("arm_r") * 1.3 * loose, f("forearm_r") * 1.35 * loose, m)
			limb(e, w.lerp(e, 0.08), f("forearm_r") * 1.35 * loose, f("forearm_r") * 1.45 * loose, m)

func _hips(c: Color, loose: float) -> void:
	tube(f("crotch_y") - 0.06 * H, f("waist_y"), f("hip_hw") * loose * 0.9, f("waist_hw") * loose * 1.05,
		f("hip_hd") / maxf(f("hip_hw"), 0.001), cloth(c))

func _top(t: Dictionary) -> void:
	var c := col(t.get("color"), Color.WHITE)
	var under := col(t.get("under"), c)
	match t.get("style", "none"):
		"gi":
			_shell(c, 1.18)
			_sleeves(c, t.get("sleeves", "none"), 1.1)
			box(Vector3(0, f("chest_y") + 0.03 * H, f("chest_z") + f("chest_hd") * 1.12), Vector3(f("chest_hw") * 0.5, f("chest_hw") * 0.9, 0.01 * H), cloth(under))
		"tunic":
			_shell(c, 1.14)
			_sleeves(c, t.get("sleeves", "long"), 1.12)
		"tank":
			_shell(c, 1.08)
		"bodysuit":
			_shell(c, 1.07)
			_sleeves(c, t.get("sleeves", "long"), 1.02)
		"armor":
			_shell(under, 1.05)
			_sleeves(under, t.get("sleeves", "short"), 1.02)
			var am := Mats.get_mat(c, "panels", 3.0, {"rough": 0.4})
			var dr := f("chest_hd") / maxf(f("chest_hw"), 0.001)
			tube(f("waist_y") + 0.02 * H, f("shoulder_y"), f("waist_hw") * 1.3, f("chest_hw") * 1.32, dr, am, f("chest_z"))
			var pad := Mats.get_mat(col(t.get("pads"), c), "panels", 3.0, {"rough": 0.4})
			for side: float in [1.0, -1.0]:
				var a := pt("arm_root", side)
				var p := ball(a + Vector3(0, f("arm_r") * 1.2, 0), Vector3(f("arm_r") * 2.6, f("arm_r") * 1.1, f("arm_r") * 2.3), pad)
				p.rotation.z = -0.35 * side
				for k in 3:
					var flap := box(Vector3(side * f("chest_hw") * 0.6, f("waist_y") - (0.03 + k * 0.0) * H, f("chest_z")), Vector3(f("hip_hw") * 0.7, 0.06 * H, f("hip_hd") * 2.3), pad)
					flap.visible = k == 0
		"dress":
			_shell(c, 1.12)
			_sleeves(c, t.get("sleeves", "short"), 1.1)
			tube(f("ankle_y") + 0.06 * H, f("waist_y"), f("hip_hw") * 1.9, f("waist_hw") * 1.15, f("hip_hd") / f("hip_hw") * 1.2, cloth(c))
		"jacket":
			_shell(c, 1.18)
			_sleeves(c, t.get("sleeves", "long"), 1.15)
			ring(f("neck_y") - 0.01 * H, f("neck_r") * 1.9, f("neck_r") * 1.9, 0.45, cloth(c.darkened(0.15)))
		"lab_coat":
			_shell(under, 1.08)
			_shell(c, 1.2)
			_sleeves(c, "long", 1.15)
			tube(f("knee_y"), f("waist_y"), f("hip_hw") * 1.6, f("waist_hw") * 1.25, f("hip_hd") / f("hip_hw") * 1.2, cloth(c))
		"wrap_bodice":  # sleeveless, crossed over at the chest, no collar (the owner took the ring off)
			if not body.is_empty():
				_fitted_bodice(c, under)
				return
			_shell(c, 1.06)
			var lap := slab(Vector3(f("chest_hw") * 0.85, f("waist_y"), f("waist_hd") * 1.12),
				Vector3(-f("chest_hw") * 0.55, f("shoulder_y") - 0.01 * H, f("chest_z") + f("chest_hd") * 0.75), 0.02 * H, 0.004 * H, cloth(under))
			lap.position.z += 0.004 * H
		"vest":
			_shell(under, 1.07)
			var vm := cloth(c)
			for side: float in [1.0, -1.0]:
				box(Vector3(side * f("chest_hw") * 0.6, (f("waist_y") + f("shoulder_y")) * 0.5, f("chest_z") + f("chest_hd") * 1.1), Vector3(f("chest_hw") * 0.75, f("shoulder_y") - f("waist_y"), 0.012 * H), vm)
			box(Vector3(0, (f("waist_y") + f("shoulder_y")) * 0.5, f("chest_z") - f("chest_hd") * 1.1), Vector3(f("chest_hw") * 2.1, f("shoulder_y") - f("waist_y"), 0.012 * H), vm)

# --- legs ---------------------------------------------------------------------

func _legs(c: Color, thigh_k: float, knee_k: float, ankle_k: float, to_y: float) -> void:
	var m := cloth(c)
	for side: float in [1.0, -1.0]:
		var x := f("leg_x") * side
		var top := Vector3(x, f("crotch_y") + 0.01 * H, 0)
		var knee := Vector3(x * 1.05, f("knee_y"), 0)
		if to_y >= f("knee_y"):
			limb(top, Vector3(x, to_y, 0), f("thigh_r") * thigh_k, f("thigh_r") * (thigh_k + knee_k) * 0.5, m)
		else:
			limb(top, knee, f("thigh_r") * thigh_k, f("calf_r") * knee_k, m)
			limb(knee, Vector3(x * 1.08, to_y, 0), f("calf_r") * knee_k, f("ankle_r") * ankle_k, m)

func _bottom(b: Dictionary) -> void:
	var c := col(b.get("color"), Color(0.3, 0.3, 0.35))
	match b.get("style", "none"):
		"pants":
			_hips(c, 1.1)
			_legs(c, 1.12, 1.25, 1.35, f("ankle_y") + 0.01 * H)
		"baggy":
			_hips(c, 1.25)
			_legs(c, 1.45, 1.9, 1.3, f("ankle_y") + 0.03 * H)
		"tights":
			_hips(c, 1.05)
			_legs(c, 1.06, 1.1, 1.15, f("ankle_y") + 0.01 * H)
		"shorts":
			_hips(c, 1.12)
			_legs(c, 1.2, 1.2, 1.2, f("knee_y") + 0.1 * H)
		"skirt":
			_hips(c, 1.08)
			tube(f("knee_y") + 0.04 * H, f("waist_y"), f("hip_hw") * 1.6, f("waist_hw") * 1.15, f("hip_hd") / f("hip_hw") * 1.2, cloth(c))
		"wrapped":  # loose trousers gathered into cross-bound shin wraps; feet stay bare
			var wrap := col(b.get("wrap"), Color(0.86, 0.83, 0.74))
			if not body.is_empty():
				_fitted_trousers(c)
				_shin_wraps(wrap)
				return
			# Own hip shape: the generic _hips cone sits inside wide hips like Oto's.
			var hm := cloth(c)
			var hd := f("hip_hd") / maxf(f("hip_hw"), 0.001) * 1.22
			tube(f("crotch_y") - 0.045 * H, f("hip_y"), f("hip_hw") * 1.12, f("hip_hw") * 1.15, hd, hm, -0.004 * H)
			tube(f("hip_y"), f("waist_y") - 0.01 * H, f("hip_hw") * 1.15, f("waist_hw") * 1.32, hd, hm, -0.003 * H)
			var calf := _calf_y()
			var back := Vector3(0, 0, -0.006 * H)  # calves bulge behind the leg line
			for side: float in [1.0, -1.0]:
				var x := f("leg_x") * side
				var knee := Vector3(x * 1.05, f("knee_y"), 0) + back * 0.5
				limb(Vector3(x, f("crotch_y") + 0.01 * H, 0), knee, f("thigh_r") * 1.42, f("calf_r") * 1.95, hm)
				limb(knee, Vector3(x * 1.08, calf, 0) + back, f("calf_r") * 1.95, f("calf_r") * 1.6, hm)
			_shin_wraps(wrap)
		"skirt_panel":
			var under := col(b.get("under"), c.darkened(0.3))
			_hips(under, 1.06)
			_legs(under, 1.06, 1.1, 1.15, f("ankle_y") + 0.03 * H)
			var m := cloth(c)
			var h := f("waist_y") - f("knee_y") - 0.03 * H
			var cy := f("waist_y") - h * 0.5
			for zs: float in [1.0, -1.0]:
				var panel := box(Vector3(0, cy, zs * f("hip_hd") * 1.25), Vector3(f("hip_hw") * 1.25, h, 0.012 * H), m)
				panel.rotation.x = 0.12 * zs
				panel.name = "skirt_panel"

func _calf_y() -> float:
	return f("ankle_y") + (f("knee_y") - f("ankle_y")) * 0.55

## Cross-bound wraps from the ankle to mid-calf.
func _shin_wraps(wrap: Color) -> void:
	if not body.is_empty():
		_fitted_shin_wraps(wrap)
		return
	var wm := cloth(wrap, "noise", 10.0)
	var bind := cloth(wrap.darkened(0.3))
	for side: float in [1.0, -1.0]:
		var x := f("leg_x") * side * 1.08
		var top := Vector3(x, _calf_y() + 0.012 * H, -0.006 * H)
		var bot := Vector3(x, f("ankle_y") + 0.004 * H, -0.002 * H)
		limb(bot, top, f("ankle_r") * 1.3, f("calf_r") * 1.45, wm)
		for k in 4:
			var t := (k + 0.5) / 4.0
			var r := lerpf(f("ankle_r") * 1.38, f("calf_r") * 1.52, t)
			var band := ring(lerpf(bot.y, top.y, t), r, r, 0.25, bind)
			band.position.x = x
			band.position.z = lerpf(bot.z, top.z, t)
			band.rotation.z = 0.3 if k % 2 == 0 else -0.3

## Shin wraps shaped to her real legs, from just above the ankle bone (so they take in the back
## of the heel) to mid-calf, with the edges of the turns and four cross-bound cords.
func _fitted_shin_wraps(wrap: Color) -> void:
	var wm := Garment.two_sided(cloth(wrap, "noise", 10.0))
	var bind := Garment.two_sided(cloth(wrap.darkened(0.3)))
	var bot_y := f("ankle_y") * 0.75
	var top_y := _calf_y() + 0.012 * H
	for side: float in [1.0, -1.0]:
		var x := f("leg_x") * side * 1.08
		var a := Vector3(x, bot_y, Garment.centre_z(body, x, bot_y + 0.02))
		var b := Vector3(x, top_y, Garment.centre_z(body, x, top_y))
		var turns := func(s: float, _ang: float) -> float: return 0.8 * absf(sin(s * PI * 6.0))
		var g := Garment.sleeve(body, a, b, {
			"ease_at": func(s: float) -> float: return 2.5 + 1.0 * s,
			"bump": turns, "bridge": 4, "smooth": 3, "cols": 48, "rows": 30, "max_r": 0.085, "reach": 0.09,
		})
		_add_piece(g["mesh"], wm, "shin_wrap_" + ("l" if side > 0.0 else "r"))
		for k in 4:
			var t := (k + 0.5) / 4.0
			var lo := t - 0.02
			var hi := t + 0.02
			var cord := Garment.sleeve(body, a.lerp(b, lo), a.lerp(b, hi), {
				"ease_at": func(s: float) -> float: return 4.3 + 1.0 * lerpf(lo, hi, s) + 1.0 * sin(PI * s),
				"bridge": 4, "smooth": 3, "cols": 48, "rows": 5, "max_r": 0.085, "reach": 0.09,
			})
			_add_piece(cord["mesh"], bind, "shin_cord")

# --- fitted clothing (Garment) --------------------------------------------------

## The body's middle at height y, its x from `x_of`, cached per millimetre.
func _axis(x_of: Callable) -> Callable:
	var cache := {}
	var frame := body
	return func(y: float) -> Vector3:
		var key := roundi(y * 1000.0)
		if not cache.has(key):
			var x: float = x_of.call(y)
			cache[key] = Vector3(x, y, Garment.centre_z(frame, x, y))
		return cache[key]

func _garment(spec: Dictionary, m: StandardMaterial3D, node_name: String) -> Dictionary:
	var g := Garment.tube(body, spec)
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = g["mesh"]
	mi.material_override = Garment.two_sided(m)
	mi.set_meta("axis", spec["axis"])  # for the checks: the cloth must stay outside the body along it
	root.add_child(mi)
	return g

## Oto's wrap bodice cast onto her body: over the bust and bridged between, falling to the
## sash, which gathers it; a short flared peplum below; a crossed lapel; sleeveless armholes.
func _fitted_bodice(c: Color, under: Color) -> void:
	var axis := _axis(func(_y: float) -> float: return 0.0)
	var sh := f("shoulder_y") - 0.004 * H
	var armpit := pt("arm_root").y - f("arm_r") * 1.3
	var neck_low := f("chest_y") - 0.022 * H  # a deep V: the wrap opens over her cleavage
	var v_mid := 0.0
	var top := func(th: float) -> float:
		var d := wrapf(th, -PI, PI)
		var a := absf(d)
		var y := sh
		if a < 0.95:
			var v := absf(d - v_mid)
			y = lerpf(neck_low, sh, pow(smoothstep(0.0, 0.85, v), 0.7)) if v < 0.85 else sh
		elif a < 1.35:
			y = lerpf(sh, armpit, smoothstep(0.95, 1.35, a))
		elif a < 1.8:
			y = armpit
		elif a < 2.2:
			y = lerpf(armpit, sh, smoothstep(1.8, 2.2, a))
		else:
			y = sh - 0.008 * H * smoothstep(2.6, PI, a)  # a shallow dip at the back of the neck
		return y
	var hem := f("waist_y") - 0.065 * H
	var sash_lo := f("waist_y") - 0.035 * H
	var sash_hi := f("waist_y") + 0.03 * H
	var g := _garment({
		"axis": axis, "top": top,
		"bottom": func(th: float) -> float: return hem + 0.006 * H * sin(th * 3.0 + 0.7),
		"ease": 4.0, "max_r": f("chest_hw") * 1.75, "bridge": 4, "hang": 0.35,
		"cinch": func(y: float) -> float:
			return smoothstep(sash_lo - 0.006 * H, sash_lo, y) * (1.0 - smoothstep(sash_hi, sash_hi + 0.018 * H, y)),
		"folds": 9, "fold_k": 0.35, "fold_min": 0.8, "flare": 14.0, "flare_from": sash_lo - 0.004 * H, "cols": 96, "rows": 48,
	}, cloth(c), "bodice")
	bodice_point = g["point"]
	bodice_mesh = g["mesh"]
	# the V's edges, faced in the darker under-colour, down to where the wrap crosses
	for sgn: float in [1.0, -1.0]:
		var path := []
		for k in 13:
			var v := 0.85 * k / 12.0
			path.append(Vector2(sgn * v, lerpf(neck_low, sh, pow(smoothstep(0.0, 0.85, v), 0.7)) - 0.006 * H))
		var lap := MeshInstance3D.new()
		lap.name = "lapel"
		lap.mesh = Garment.band(g["point"], path, 0.012 * H, 0.0015, axis)
		lap.material_override = Garment.two_sided(cloth(under))
		root.add_child(lap)

## Loose trousers cast onto her hips and legs: they hang straight from the hips and thighs,
## fold where they stand off the leg, and gather into the shin wraps.
func _fitted_trousers(c: Color) -> void:
	var m := cloth(c)
	var waist := f("waist_y") - 0.01 * H
	# the mesh's real crotch, found from below (the landmark is only a guide)
	var up := Face.cast(body["tm"], body["xf"], Vector3(0, f("knee_y"), Garment.centre_z(body, 0.0, f("hip_y"))), Vector3.UP)
	var crotch: float = (up["position"] as Vector3).y if not up.is_empty() else f("crotch_y")
	var hips_lo := crotch - 0.025 * H
	var peplum := f("waist_y") - 0.065 * H  # the bodice's hem: the trousers sit snug under it
	_garment({
		"axis": _axis(func(_y: float) -> float: return 0.0),
		"bottom": func(_th: float) -> float: return hips_lo,
		"top": func(_th: float) -> float: return waist,
		"ease_at": func(y: float) -> float: return lerpf(16.0, 2.0, smoothstep(peplum - 0.04 * H, peplum - 0.008 * H, y)),
		"max_r": f("hip_hw") * 1.6, "bridge": 3, "hang": 0.25,
		"folds": 11, "fold_k": 0.2, "fold_min": 1.0, "cols": 96, "rows": 30,
	}, m, "trousers_hips")
	var bottom := _calf_y() + 0.01 * H
	var knee := f("knee_y")
	for side: float in [1.0, -1.0]:
		var x0 := f("leg_x") * side
		var x_of := func(y: float) -> float:
			if y > knee:
				return x0 * lerpf(1.05, 1.0, (y - knee) / (crotch - knee))
			return x0 * lerpf(1.08, 1.05, (y - bottom) / (knee - bottom))
		_garment({
			"axis": _axis(x_of),
			"bottom": func(_th: float) -> float: return bottom,
			"top": func(_th: float) -> float: return crotch - 0.004 * H,  # below it the legs are apart
			"ease": 13.0, "max_r": f("thigh_r") * 2.2, "bridge": 2, "hang": 0.06,
			"cinch": func(y: float) -> float: return 1.0 - smoothstep(bottom, bottom + 0.05 * H, y),
			"folds": 7, "fold_k": 0.3, "fold_min": 2.0, "cols": 64, "rows": 44,
		}, m, "trouser_leg_" + ("l" if side > 0.0 else "r"))

# --- feet ---------------------------------------------------------------------

func _feet(ft: Dictionary) -> void:
	var c := col(ft.get("color"), Color(0.2, 0.15, 0.1))
	var m := cloth(c, "noise", 8.0)
	for side: float in [1.0, -1.0]:
		var x := f("leg_x") * side * 1.08
		var toe := Vector3(x, f("ankle_y") * 0.55, f("foot_z") * 0.45)
		match ft.get("style", "none"):
			"boots":
				var top := Vector3(x * 0.98, f("ankle_y") + (f("knee_y") - f("ankle_y")) * 0.5, 0)
				limb(Vector3(x, 0.0, 0), top, f("ankle_r") * 1.55, f("calf_r") * 1.35, m)
				ring(top.y, f("calf_r") * 1.45, f("calf_r") * 1.45, 0.3, cloth(c.darkened(0.25))).position.x = top.x
				ball(toe, Vector3(f("ankle_r") * 1.6, f("ankle_y") * 0.75, f("foot_z") * 0.85), m)
			"shoes":
				ball(toe, Vector3(f("ankle_r") * 1.45, f("ankle_y") * 0.7, f("foot_z") * 0.8), m)
				limb(Vector3(x, 0.0, 0), Vector3(x, f("ankle_y") * 1.2, 0), f("ankle_r") * 1.45, f("ankle_r") * 1.3, m)
			"sandals":
				box(Vector3(x, 0.006 * H, f("foot_z") * 0.3), Vector3(f("ankle_r") * 2.6, 0.012 * H, f("foot_z") * 1.9), m)
				ring(f("ankle_y") * 0.6, f("ankle_r") * 1.3, f("ankle_r") * 1.3, 0.3, m).position.x = x

# --- hair ---------------------------------------------------------------------

func _cap(m: Material, grow := 1.0) -> void:
	var h := head()
	ball(h + Vector3(0, f("head_ry") * 0.24, -f("head_rz") * 0.18),
		Vector3(f("head_r") * 1.14, f("head_ry") * 0.92, f("head_rz") * 1.08) * grow, m)

func _spike(base: Vector3, dir: Vector3, length: float, r: float, m: Material) -> void:
	limb(base, base + dir.normalized() * length, r, 0.0, m, 6)

func _hair(hs: Dictionary) -> void:
	var style: String = hs.get("style", "keep")
	if style in ["keep", "bald"]:
		return
	var c := col(hs.get("color"), Color(0.08, 0.07, 0.07))
	var m := hair_mat(c)
	var h := head()
	var rx := f("head_r")
	var ry := f("head_ry")
	var rz := f("head_rz")
	match style:
		"long":
			# With "shell", Outfits.apply casts the cap, fringe and loose strand onto the real
			# head (Face.hair_shell); only the length down the back is built here.
			# With "shell", Outfits.apply also hangs the length down her back as a draped sheet
			# (Outfits._hair_back); boxes only for heads without it.
			var shell: bool = hs.get("shell", false)
			if not shell:
				_cap(m)
				box(h + Vector3(0, -ry * 0.35, -rz * 0.72), Vector3(rx * 2.05, ry * 1.5, rz * 0.45), m)
				box(Vector3(0, (h.y - ry * 1.1 + f("chest_y")) * 0.5, h.z - rz * 0.85), Vector3(rx * 1.7, h.y - ry * 1.1 - f("chest_y") + 0.02 * H, rz * 0.3), m)
			if not shell:
				for side: float in [1.0, -1.0]:
					box(h + Vector3(side * rx * 0.98, -ry * 0.35, -rz * 0.1), Vector3(rx * 0.3, ry * 1.2, rz * 1.0), m)
				# the loose strand of bangs
				var bang := box(h + Vector3(rx * 0.4, ry * 0.05, rz * 0.9), Vector3(rx * 0.3, ry * 0.9, rz * 0.12), m)
				bang.rotation.z = 0.25
			if hs.get("form3", false):
				form3_hair = Node3D.new()
				form3_hair.name = "form3_hair"
				root.add_child(form3_hair)
				var black := Mats.get_mat(Color(0, 0, 0), "", 1.0, {"rough": 1.0})
				if not shell:
					var top := h.y - ry * 0.2
					var bottom := f("knee_y")
					box(Vector3(0, (top + bottom) * 0.5, h.z - rz * 1.05), Vector3(rx * 2.4, top - bottom, rz * 0.5), black, form3_hair)
				form3_hair.set_meta("mat", black)
				form3_hair.visible = false
		"saiyan_spiky":
			_cap(m)
			var n: int = hs.get("spikes", 8)
			var length: float = hs.get("length", 1.0) * ry * 1.6
			for i in n:
				var a := lerpf(-1.9, 1.9, float(i) / maxf(n - 1, 1))
				var e := 0.35 + 0.35 * sin(i * 1.7)
				var dir := Vector3(sin(a) * cos(e), sin(e), -cos(a) * cos(e))
				_spike(h + dir * rx * 0.75 + Vector3(0, ry * 0.25, 0), dir, length * (0.75 + 0.25 * cos(i * 2.3)), rx * 0.42, m)
			for bx: float in [-0.45, 0.0, 0.45]:
				_spike(h + Vector3(bx * rx, ry * 0.55, rz * 0.6), Vector3(bx * 0.6, -0.5, 1.0), ry * 0.7, rx * 0.28, m)
		"flame":
			_cap(m)
			for i in 9:
				var a := TAU * i / 9.0
				var dir := Vector3(sin(a) * 0.35, 1.0, -0.15 + cos(a) * 0.3)
				_spike(h + Vector3(sin(a) * rx * 0.6, ry * 0.45, cos(a) * rz * 0.4 - rz * 0.1), dir, ry * 2.2 * (0.8 + 0.2 * cos(i * 1.3)), rx * 0.45, m)
			_spike(h + Vector3(0, ry * 0.6, rz * 0.65), Vector3(0, -0.6, 1.0), ry * 0.5, rx * 0.3, m)
		"very_long_spiky":
			_cap(m, 1.05)
			for i in 6:
				var a := lerpf(-1.6, 1.6, i / 5.0)
				var dir := Vector3(sin(a), 0.5, -cos(a))
				_spike(h + dir * rx * 0.7 + Vector3(0, ry * 0.3, 0), dir, ry * 1.3, rx * 0.4, m)
			for i in 6:
				var x := lerpf(-rx * 1.1, rx * 1.1, i / 5.0)
				var base := h + Vector3(x * 0.6, 0, -rz * 0.8)
				var tip := Vector3(x * 1.8, f("knee_y") + 0.04 * H * i, h.z - rz * 2.2)
				limb(base, tip, 0.0, rx * 0.65, m, 6)
		"bun":
			_cap(m)
			ball(h + Vector3(0, ry * 0.75, -rz * 0.7), Vector3.ONE * rx * 0.55, m)
			box(h + Vector3(0, ry * 0.8, rz * 0.62), Vector3(rx * 1.7, ry * 0.22, rz * 0.25), m)
		"bob":
			_cap(m, 1.06)
			for side: float in [1.0, -1.0]:
				box(h + Vector3(side * rx * 0.95, -ry * 0.25, -rz * 0.05), Vector3(rx * 0.35, ry * 1.1, rz * 1.6), m)
			box(h + Vector3(0, -ry * 0.25, -rz * 0.85), Vector3(rx * 2.1, ry * 1.1, rz * 0.4), m)
			box(h + Vector3(0, ry * 0.75, rz * 0.66), Vector3(rx * 1.8, ry * 0.22, rz * 0.25), m)
		"ponytail":
			_cap(m)
			var base := h + Vector3(0, ry * 0.35, -rz * 0.95)
			limb(base, Vector3(0, f("shoulder_y") - 0.04 * H, h.z - rz * 1.4), rx * 0.32, rx * 0.12, m, 8)
			box(h + Vector3(0, ry * 0.8, rz * 0.62), Vector3(rx * 1.6, ry * 0.2, rz * 0.25), m)
		"afro":
			ball(h + Vector3(0, ry * 0.55, -rz * 0.25), Vector3(rx * 1.75, ry * 1.25, rz * 1.6), m)
		"short":
			_cap(m, 0.97)
		"turban":
			ball(h + Vector3(0, ry * 0.4, -rz * 0.05), Vector3(rx * 1.2, ry * 0.85, rz * 1.15), m)
			ring(h.y + ry * 0.05, rx * 1.15, rz * 1.1, 0.35, Mats.get_mat(Color(0.75, 0.2, 0.35))).position.z = h.z

# --- accessories ----------------------------------------------------------------

func _acc(a: Dictionary) -> void:
	var c := col(a.get("color"), Color(0.8, 0.2, 0.2))
	var m := cloth(c)
	var h := head()
	match a.get("style", ""):
		"sash":
			ring(f("waist_y"), f("waist_hw") * 1.32, f("waist_hd") * 1.32, 0.35, m, f("waist_z"))
			for k in 2:
				var tail := box(Vector3(f("waist_hw") * 0.9, f("waist_y") - (0.05 + k * 0.02) * H, f("waist_hd") * 1.25), Vector3(0.04 * H, 0.1 * H, 0.01 * H), m)
				tail.rotation.z = 0.15 + k * 0.2
		"belt":
			ring(f("waist_y") - 0.01 * H, f("waist_hw") * 1.25, f("waist_hd") * 1.25, 0.25, m, f("waist_z"))
			box(Vector3(0, f("waist_y") - 0.01 * H, f("waist_z") + f("waist_hd") * 1.3), Vector3(0.05 * H, 0.03 * H, 0.01 * H), Mats.get_mat(Color(0.9, 0.75, 0.3), "", 1.0, {"metal": 0.7, "rough": 0.3}))
		"trim":
			ring(f("waist_y") - 0.01 * H, f("waist_hw") * 1.16, f("waist_hd") * 1.16, 0.2, m, f("waist_z"))
			ring(f("neck_y") - 0.015 * H, f("neck_r") * 2.2, f("neck_r") * 2.2, 0.25, m)
			for side: float in [1.0, -1.0]:
				var a0 := pt("arm_root", side)
				var cuff := limb(a0.lerp(pt("elbow", side), 0.58), a0.lerp(pt("elbow", side), 0.64), f("arm_r") * 1.45, f("arm_r") * 1.45, m)
				cuff.name = "trim"
		"wristbands":
			for side: float in [1.0, -1.0]:
				var e := pt("elbow", side)
				var w := pt("wrist", side)
				limb(e.lerp(w, 0.72), e.lerp(w, 0.98), f("forearm_r") * 1.5, f("forearm_r") * 1.5, m)
		"gloves":
			for side: float in [1.0, -1.0]:
				var w := pt("wrist", side)
				var tip := pt("hand_tip", side)
				ball(w.lerp(tip, 0.55), Vector3(f("forearm_r") * 1.7, f("forearm_r") * 1.7, f("forearm_r") * 1.5), m)
				limb(pt("elbow", side).lerp(w, 0.75), w, f("forearm_r") * 1.6, f("forearm_r") * 1.55, m)
		"scouter":
			var dev := Mats.get_mat(Color(0.85, 0.85, 0.85), "panels", 20.0, {"rough": 0.4})
			box(h + Vector3(-f("head_r") * 1.05, 0, 0), Vector3(0.025 * H, 0.05 * H, 0.05 * H), dev)
			box(h + Vector3(-f("head_r") * 0.95, f("head_ry") * 0.05, f("head_rz") * 0.6), Vector3(0.01 * H, 0.008 * H, f("head_rz") * 1.0), dev)
			box(h + Vector3(-f("head_r") * 0.5, f("head_ry") * 0.1, f("head_rz") * 1.12), Vector3(f("head_r") * 0.75, f("head_ry") * 0.4, 0.003 * H), Mats.get_mat(c, "", 1.0, {"alpha": 0.55, "unshaded": true}))
		"headband":
			ring(h.y + f("head_ry") * 0.3, f("head_r") * 1.08, f("head_rz") * 1.05, 0.25, m, h.z)
		"cape":
			var top := f("shoulder_y") + 0.01 * H
			var bottom := f("ankle_y") + 0.04 * H
			var cape := box(Vector3(0, (top + bottom) * 0.5, f("chest_z") - f("chest_hd") * 1.45), Vector3(f("shoulder_x") * 2.6, top - bottom, 0.012 * H), cloth(c, "noise", 3.0))
			cape.rotation.x = -0.06
			for side: float in [1.0, -1.0]:
				ball(pt("arm_root", side) + Vector3(0, f("arm_r"), 0), Vector3(f("arm_r") * 2.4, f("arm_r") * 1.3, f("arm_r") * 2.4), cloth(c))
		"mustache":
			for side: float in [1.0, -1.0]:
				var tip := h + Vector3(side * f("head_r") * 0.7, -f("head_ry") * 0.55, f("head_rz") * 0.85)
				limb(h + Vector3(0, -f("head_ry") * 0.35, f("head_rz") * 1.0), tip, f("head_r") * 0.15, f("head_r") * 0.06, hair_mat(c), 6)
		"glasses":
			for side: float in [1.0, -1.0]:
				var lens := ring(0, f("head_r") * 0.3, f("head_r") * 0.3, 0.3, m)
				lens.position = h + Vector3(side * f("head_r") * 0.38, f("head_ry") * 0.05, f("head_rz") * 1.02)
				lens.rotation.x = PI / 2
		"hat_ball":
			var hat_m := cloth(c, "stripes", 4.0)
			var top_y := h.y + f("head_ry") * 0.95
			limb(Vector3(0, top_y - f("head_ry") * 0.45, h.z), Vector3(0, top_y + f("head_ry") * 0.15, h.z), f("head_r") * 1.12, f("head_r") * 0.9, hat_m, 14)
			var ball_node := Props.make("dragon_ball", {"stars": 4})
			ball_node.scale = Vector3.ONE * (f("head_r") * 0.9 / 0.18)
			ball_node.position = Vector3(0, top_y + f("head_ry") * 0.15 - 0.2 * ball_node.scale.y + f("head_r") * 0.8, h.z)
			root.add_child(ball_node)
		"earrings":
			for side: float in [1.0, -1.0]:
				ball(h + Vector3(side * f("head_r") * 1.0, -f("head_ry") * 0.45, 0), Vector3.ONE * 0.012 * H, Mats.get_mat(c, "", 1.0, {"metal": 0.8, "rough": 0.2}))
		"apron":
			box(Vector3(0, (f("chest_y") + f("knee_y")) * 0.5, f("chest_z") + f("chest_hd") * 1.25), Vector3(f("chest_hw") * 1.6, f("chest_y") - f("knee_y"), 0.01 * H), m)
		"antennae":
			for side: float in [1.0, -1.0]:
				var base := h + Vector3(side * f("head_r") * 0.3, f("head_ry") * 0.75, f("head_rz") * 0.5)
				limb(base, base + Vector3(side * 0.01 * H, f("head_ry") * 0.9, f("head_rz") * 0.6), f("head_r") * 0.08, f("head_r") * 0.05, m, 6)
		"third_eye":
			ball(h + Vector3(0, f("head_ry") * 0.4, f("head_rz") * 0.97), Vector3(f("head_r") * 0.12, f("head_r") * 0.08, f("head_r") * 0.05), Mats.get_mat(Color(0.95, 0.9, 0.85)))
		"scapular":
			_scapular(c, col(a.get("trim"), Color(0.9, 0.72, 0.3)), col(a.get("sigil"), Color(0.93, 0.73, 0.3)))
		"wide_sash":
			_wide_sash(c)
		"royal_cord":
			_royal_cord(c)
		"gauntlets":
			_gauntlets(c)
		"arm_wraps":
			_arm_wraps(c)
		"tail":
			ring(f("waist_y") - 0.005 * H, f("waist_hw") * 1.42, f("waist_hd") * 1.45, 0.4, cloth(c, "noise", 10.0), f("waist_z"))

# --- Oto's queen's attire --------------------------------------------------------
# docs/OTO_OUTFIT.md describes the design. The parts below the sash are ClothPanels.

func _sash_r() -> float:
	if not body.is_empty():
		return absf((_fitted_sash()["point"].call(PI / 2.0, f("waist_y")) as Vector3).x)
	return f("waist_hw") * 1.35

func _sash_front() -> float:
	if not body.is_empty():
		return (_fitted_sash()["point"].call(0.0, f("waist_y") - 0.03 * H) as Vector3).z
	return _sash_r() * f("waist_hd") / maxf(f("waist_hw"), 0.001)

## The sash cast round her waist over the bodice: wound linen, so it stands straight and smooth.
func _fitted_sash() -> Dictionary:
	if _sash_g.is_empty():
		var lo := f("waist_y") - 0.035 * H
		var hi := f("waist_y") + 0.03 * H
		var spec := {
			"axis": _axis(func(_y: float) -> float: return 0.0),
			"bottom": func(_th: float) -> float: return lo,
			"top": func(_th: float) -> float: return hi,
			"ease": 13.0, "max_r": f("hip_hw") * 1.5, "bridge": 5, "hang": 0.0,
			"folds": 16, "fold_min": 0.7, "fold_max": 1.0, "cols": 96, "rows": 12,
		}
		_sash_g = Garment.tube(body, spec)
		_sash_g["axis"] = spec["axis"]
	return _sash_g

## A long panel over both shoulders, hanging front and back to mid-shin. Above the sash it
## lies on the body; below it, it is cloth: gold-edged, gold hem, and on the front a gold
## plaque bearing the sigil in black (Sigil, "The Wall").
func _scapular(c: Color, trim: Color, plaque: Color) -> void:
	var pm := cloth(c, "noise", 5.0)
	var tm := metal(trim, 0.45, 0.5)
	metal_swap[plaque] = to_silver(plaque)
	var w := f("hip_hw") * 1.05
	var t := 0.006 * H
	var top_y := f("shoulder_y") + 0.012 * H
	if bodice_mesh != null:
		_fitted_scapular_top(pm, tm, w, t)
	else:
		_board_scapular_top(pm, tm, w, t, top_y)
	_scapular_cloth(c, trim, plaque, w)

## The scapular above the sash as draped cloth: front and back panels lying on the bodice,
## hanging straight down from the bust and the shoulder blades and tucked under the sash, joined
## by two straps that follow the real curve of her shoulders. Gold trims its long edges.
func _fitted_scapular_top(pm: StandardMaterial3D, tm: StandardMaterial3D, w: float, t: float) -> void:
	var under := [
		{"tm": body["tm"], "xf": body["xf"], "lift": 11.0},  # as high as over the bodice, so the V-neck leaves no step
		{"tm": bodice_mesh.generate_triangle_mesh(), "xf": Transform3D.IDENTITY, "lift": 5.0},  # clear of the lapel
	]
	var lo := f("waist_y") + 0.012 * H  # tucked behind the top of the sash
	var hi := f("shoulder_y") - 0.02 * H
	var sash_hi := f("waist_y") + 0.03 * H
	var cinch := func(y: float) -> float: return 1.0 - smoothstep(sash_hi - 0.004 * H, sash_hi + 0.02 * H, y)
	var pmat := Garment.two_sided(pm)
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED  # its own material: Shadow forms turn it silver
	var v_low := f("chest_y") - 0.016 * H  # the bottom of the front panel's V, just above the bodice's
	var tops := {}
	for facing: float in [1.0, -1.0]:
		var spec := {"hang": 0.3 if facing > 0.0 else 0.15, "cinch": cinch, "folds": 2.5, "cols": 49, "rows": 64}
		if facing > 0.0:  # the front is cut in a V that follows the bodice's, so it sits round her chest
			spec["top"] = func(x: float) -> float: return lerpf(v_low, hi, pow(smoothstep(0.0, w * 0.27, absf(x)), 0.75))
		var g := Garment.panel(under, facing, w, lo, hi, spec)
		var mi := MeshInstance3D.new()
		mi.name = "scapular_top_" + ("front" if facing > 0.0 else "back")
		mi.mesh = g["mesh"]
		mi.material_override = pmat
		root.add_child(mi)
		tops[facing] = g["top"]
		var outs := PackedVector3Array()
		outs.resize((g["left"] as PackedVector3Array).size())
		outs.fill(Vector3(0, 0, facing))
		for edge: String in ["left", "right"]:
			var trim := MeshInstance3D.new()
			trim.name = "scapular_trim"
			trim.mesh = Garment.strip(g[edge], outs, 0.006 * H, 0.0012)
			trim.material_override = tm
			root.add_child(trim)
		if facing > 0.0:  # gold along the V
			var top_pts: PackedVector3Array = g["top"]
			var vp := PackedVector3Array()
			for p in top_pts:
				if absf(p.x) < w * 0.28:
					vp.append(p + Vector3(0, -0.002 * H, 0))
			var vo := PackedVector3Array()
			vo.resize(vp.size())
			vo.fill(Vector3(0, 0, 1))
			var vt := MeshInstance3D.new()
			vt.name = "scapular_trim"
			vt.mesh = Garment.strip(vp, vo, 0.006 * H, 0.0012)
			vt.material_override = tm
			root.add_child(vt)
	# the straps over the shoulders, either side of the neck
	var tops_f: PackedVector3Array = tops[1.0]
	var tops_b: PackedVector3Array = tops[-1.0]
	var n := tops_f.size()
	for side: float in [1.0, -1.0]:
		var x := side * w * 0.36
		var i := clampi(roundi((x / w + 0.5) * (n - 1)), 0, n - 1)
		var a := tops_f[i]
		var b := tops_b[i]
		var pts := PackedVector3Array([a])
		var steps := 14
		var bodice_tm: TriangleMesh = under[1]["tm"]
		var ys := PackedFloat32Array()
		var start := f("neck_y") + 0.01 * H  # below the chin: above it the rays would find the head
		for k in range(1, steps):
			var zz := lerpf(a.z, b.z, float(k) / steps)
			var yy := maxf(a.y, b.y)
			var hit := Face.cast(body["tm"], body["xf"], Vector3(x, start, zz), Vector3.DOWN)
			if not hit.is_empty():
				yy = maxf(yy, (hit["position"] as Vector3).y + 0.006)
			var hb := Face.cast(bodice_tm, Transform3D.IDENTITY, Vector3(x, start, zz), Vector3.DOWN)
			if not hb.is_empty():
				yy = maxf(yy, (hb["position"] as Vector3).y + 0.004)
			ys.append(yy)
		# the strap is stretched over the shoulder: no dips between its high points
		for k in ys.size():
			var lo_l := ys.slice(0, k + 1)
			var lo_r := ys.slice(k)
			var left_max := -INF
			var right_max := -INF
			for v in lo_l:
				left_max = maxf(left_max, v)
			for v in lo_r:
				right_max = maxf(right_max, v)
			pts.append(Vector3(x, minf(left_max, right_max), lerpf(a.z, b.z, float(k + 1) / steps)))
		pts.append(b)
		var outs := PackedVector3Array()
		for k in pts.size():
			var tg := (pts[mini(k + 1, pts.size() - 1)] - pts[maxi(k - 1, 0)]).normalized()
			var o := Vector3.RIGHT.cross(tg).normalized()
			if o.y < -0.01 or (absf(o.y) <= 0.01 and o.z * (a.z - b.z) < 0.0):
				o = -o
			outs.append(o)
		var strap := MeshInstance3D.new()
		strap.name = "scapular_strap"
		strap.mesh = Garment.strip(pts, outs, w * 0.28)
		strap.material_override = pmat
		root.add_child(strap)

## The scapular above the sash as boards (bodies without a fitted bodice).
func _board_scapular_top(pm: StandardMaterial3D, tm: StandardMaterial3D, w: float, t: float, top_y: float) -> void:
	var front := [Vector3(0, top_y, f("neck_r") * 2.4), Vector3(0, f("chest_y"), f("chest_z") + f("chest_hd") * 1.12), Vector3(0, f("waist_y"), f("waist_hd") * 1.12)]
	var back := [Vector3(0, top_y, -f("neck_r") * 2.4), Vector3(0, f("chest_y"), f("chest_z") - f("chest_hd") * 1.12), Vector3(0, f("waist_y"), -f("waist_hd") * 1.12)]
	for pts: Array in [front, back]:
		for k in 2:
			slab(pts[k], pts[k + 1], w, t, pm)
			for side: float in [1.0, -1.0]:
				var e := Vector3(side * w * 0.5, 0, 0)
				slab(pts[k] + e, pts[k + 1] + e, 0.006 * H, t * 1.4, tm)
	# over the shoulders: two bands either side of the neck
	for side: float in [1.0, -1.0]:
		box(Vector3(side * w * 0.36, top_y, 0), Vector3(w * 0.28, t, f("neck_r") * 4.8), pm)

## The scapular below the sash: two ClothPanels, front and back, gold-edged, the sigil in front.
func _scapular_cloth(c: Color, trim: Color, plaque: Color, w: float) -> void:
	var drop := f("waist_y") - 0.035 * H - (f("knee_y") - (f("knee_y") - f("ankle_y")) * 0.45)
	var us := [0.0, 0.07, 0.3, 0.5, 0.7, 0.93, 1.0]
	var layers := _layers() if not body.is_empty() else []
	var pin_y := f("waist_y") - 0.035 * H
	for zs: float in [1.0, -1.0]:
		# the back hangs over her real seat (whatever shape it is), on close rows: the peplum and
		# the seat are only a few cm tall. The front is as it always was.
		var rows := 9 if zs > 0.0 else 12
		var cols := leg_colliders(1.4, [1.0, -1.0], "" if zs > 0.0 else "back")
		var pin_z := zs * (_sash_front() + 0.003 * H)
		if zs < 0.0 and not layers.is_empty():  # hang from outside whatever she wears at the waist (the peplum flares)
			var outer := _outer_z(layers, 0.0, pin_y, zs > 0.0)
			if absf(outer) < 100.0:
				pin_z = maxf(pin_z, outer + 0.012) if zs > 0.0 else minf(pin_z, outer - 0.012)
		var p := cloth_panel(Vector3(0, pin_y, pin_z), Vector3.RIGHT, w, drop, us.size(), rows, cols, c)
		p.us = us
		p.name = "ScapularFront" if zs > 0.0 else "ScapularBack"
		p.face_color = func(i: int, j: int) -> Color:
			if i == 0 or i == us.size() - 2 or j == rows - 2:
				return trim
			return c
		if zs > 0.0:  # the sigil: front panel only
			p.decal_texture = Sigil.texture(false)
			p.decal_rect = Rect2(0.32, 0.48, 0.36, 0.28)
			p.decal_color = plaque

## A wide linen sash wound twice and knotted at her left hip, two tails hanging free.
func _wide_sash(c: Color) -> void:
	var sm := cloth(c, "noise", 8.0)
	if not body.is_empty():
		_fitted_sash_pieces(c, sm)
		return
	var r := _sash_r()
	var dr := f("waist_hd") / maxf(f("waist_hw"), 0.001)
	tube(f("waist_y") - 0.035 * H, f("waist_y") + 0.03 * H, r, r * 1.03, dr, sm, f("waist_z"))
	var wind := ring(f("waist_y") + 0.008 * H, r * 1.06, _sash_front() * 1.06, 0.3, cloth(c.darkened(0.1), "noise", 8.0), f("waist_z"))
	wind.rotation.z = 0.07
	var knot := Vector3(r * 0.92, f("waist_y") - 0.004 * H, _sash_front() * 0.55)
	ball(knot, Vector3(0.024, 0.021, 0.018) * H, sm)
	for k in 2:
		var tail := cloth_panel(knot + Vector3(0.004 * H * (k * 2 - 1), -0.014 * H, 0.004 * H), Vector3(0.25, 0, 1),
			0.03 * H, (0.15 + k * 0.06) * H, 2, 6, leg_colliders(1.45, [1.0]), c)
		tail.name = "SashTail"
		tail.tex_scale = Vector2(1, 3)

## The fitted sash: the wound band, the second winding a little tilted, the knot at her left
## hip and its two tails.
func _fitted_sash_pieces(c: Color, sm: StandardMaterial3D) -> void:
	var g := _fitted_sash()
	var mi := MeshInstance3D.new()
	mi.name = "sash"
	mi.mesh = g["mesh"]
	mi.set_meta("axis", g["axis"])
	mi.material_override = Garment.two_sided(sm)
	root.add_child(mi)
	var wind := MeshInstance3D.new()
	wind.name = "sash_wind"
	wind.mesh = Garment.band(g["point"], _round_path(f("waist_y") + 0.008 * H, 0.006 * H), 0.02 * H, 0.0025, g["axis"])
	wind.material_override = Garment.two_sided(cloth(c.darkened(0.1), "noise", 8.0))
	root.add_child(wind)
	var side: Vector3 = g["point"].call(1.25, f("waist_y") - 0.004 * H)
	var axis: Vector3 = g["axis"].call(side.y)
	var out := Vector3(side.x - axis.x, 0, side.z - axis.z).normalized()
	var knot := side + out * 0.008 * H
	ball(knot, Vector3(0.024, 0.021, 0.018) * H, sm)
	for k in 2:
		var tail := cloth_panel(knot + Vector3(0.004 * H * (k * 2 - 1), -0.014 * H, 0.004 * H) + out * 0.004 * H, Vector3(0.25, 0, 1),
			0.03 * H, (0.15 + k * 0.06) * H, 2, 6, leg_colliders(1.45, [1.0]), c)
		tail.name = "SashTail"
		tail.tex_scale = Vector2(1, 3)

## (theta, y) points once round the body at height y, tilted `tilt` metres side to side.
func _round_path(y: float, tilt: float) -> Array:
	var path := []
	for i in 97:
		var th := TAU * i / 96.0
		path.append(Vector2(th, y + tilt * sin(th)))
	return path

## The queen's cord: gold over the sash, a gold clasp with a black stone, a short tassel.
func _royal_cord(c: Color) -> void:
	var gold := metal(c)
	if not body.is_empty():
		var g := _fitted_sash()
		var cord := MeshInstance3D.new()
		cord.name = "royal_cord"
		cord.mesh = Garment.band(g["point"], _round_path(f("waist_y") - 0.027 * H, 0.0), 0.006 * H, 0.003, g["axis"])
		gold.cull_mode = BaseMaterial3D.CULL_DISABLED  # its own material: Shadow forms turn it silver
		cord.material_override = gold
		root.add_child(cord)
	else:
		ring(f("waist_y") - 0.027 * H, _sash_r() * 1.05, _sash_front() * 1.07, 0.18, gold, f("waist_z"))
	var at := Vector3(0, f("waist_y") - 0.004 * H, _sash_front() + 0.004 * H)
	var disc := limb(at - Vector3(0, 0, 0.003 * H), at + Vector3(0, 0, 0.003 * H), 0.017 * H, 0.017 * H, gold, 14)
	disc.rotation = Vector3(PI / 2, 0, 0)
	disc.position = at
	ball(at + Vector3(0, 0, 0.004 * H), Vector3(0.008, 0.008, 0.004) * H, Mats.get_mat(Color(0.02, 0.01, 0.04), "", 1.0, {"rough": 0.08}))
	var tassel_cols := leg_colliders(1.5)
	tassel_cols.append([Vector3(0, f("hip_y"), 0.0), f("hip_hd") * 1.32])
	var tassel := cloth_panel(at + Vector3(0, -0.017 * H, 0.006 * H), Vector3.RIGHT, 0.012 * H, 0.08 * H, 2, 5, tassel_cols, c)
	tassel.name = "Tassel"
	tassel.tex_scale = Vector2(1, 1)

## Rigid gold bracers from just behind the wrist to halfway to the elbow: two raised
## ridges, a spine along the back of the forearm, and the sigil engraved on the outer face.
func _gauntlets(c: Color) -> void:
	var gold := metal(c, 0.28)
	var deep := metal(c.darkened(0.3), 0.35)
	var ink := _sigil_ink()
	if not body.is_empty():
		_fitted_gauntlets(gold, deep, ink)
		return
	_can_gauntlets(gold, deep, ink)

func _sigil_ink() -> StandardMaterial3D:
	var ink := StandardMaterial3D.new()
	ink.albedo_texture = Sigil.texture(true)
	ink.albedo_color = Color(0.04, 0.03, 0.03)
	ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	ink.alpha_scissor_threshold = 0.5
	ink.roughness = 0.6
	ink.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return ink

## Gold bracers shaped to her real forearm: a smooth shell from just behind the wrist to halfway
## to the elbow, flared lips at both ends, two raised ridges, a spine along the back of the
## forearm and the sigil engraved on the outer face.
func _fitted_gauntlets(gold: StandardMaterial3D, deep: StandardMaterial3D, ink: StandardMaterial3D) -> void:
	gold.cull_mode = BaseMaterial3D.CULL_DISABLED
	deep.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side: float in [1.0, -1.0]:
		var w := _real_wrist(side)
		var e := pt("elbow", side)
		var a0 := w.lerp(e, 0.04)
		var a1 := w.lerp(e, 0.5)
		var lip := func(s: float) -> float: return 1.8 * (1.0 - smoothstep(0.0, 0.07, s) + smoothstep(0.93, 1.0, s))
		var g := Garment.sleeve(body, a0, a1, {
			"ease_at": func(s: float) -> float: return 5.0 + 1.5 * s + float(lip.call(s)),
			"bridge": 6, "cols": 48, "rows": 22,
		})
		_add_piece(g["mesh"], gold, "gauntlet_L" if side > 0.0 else "gauntlet_R")
		for t: float in [0.13, 0.87]:  # the two raised ridges
			var lo := t - 0.03
			var hi := t + 0.03
			var ring := Garment.sleeve(body, a0.lerp(a1, lo), a0.lerp(a1, hi), {
				"ease_at": func(s: float) -> float: return 5.0 + 1.5 * lerpf(lo, hi, s) + 2.6 * sin(PI * s),
				"bridge": 6, "cols": 48, "rows": 6,
			})
			_add_piece(ring["mesh"], deep, "gauntlet_ridge")
		# the spine along the back (top) of the forearm
		var pts := PackedVector3Array()
		var outs := PackedVector3Array()
		for k in 17:
			var s := lerpf(0.04, 0.96, k / 16.0)
			pts.append(g["point"].call(s, 0.0))
			outs.append(g["normal"].call(s, 0.0))
		_add_piece(Garment.strip(pts, outs, 0.006 * H, 0.0012), deep, "gauntlet_spine")
		# the engraving on the outer face (front, +Z), its long axis along the forearm, curved
		# with the gold
		var eng := MeshInstance3D.new()
		eng.name = "SigilEngraving_L" if side > 0.0 else "SigilEngraving_R"  # her left is +X
		eng.mesh = Garment.patch(g, 0.24, 0.76, PI / 2.0 - 0.42, PI / 2.0 + 0.42, 0.0008)
		ink.cull_mode = BaseMaterial3D.CULL_DISABLED
		eng.material_override = ink
		root.add_child(eng)

## The real wrist on the mesh: the narrowest point of the arm between the hand and the elbow.
## (On Oto's mesh the "wrist" landmark sits at the base of the fingers.)
func _real_wrist(side: float) -> Vector3:
	var tip := pt("hand_tip", side)
	var e := pt("elbow", side)
	var best := INF
	var at := pt("wrist", side)
	for k in 41:
		var p := tip.lerp(e, lerpf(0.08, 0.6, k / 40.0))
		var size := 0.0
		for axis: Vector3 in [Vector3.UP, Vector3.BACK]:
			var a := Face.cast(body["tm"], body["xf"], p + axis * 0.08, -axis)
			var b := Face.cast(body["tm"], body["xf"], p - axis * 0.08, axis)
			if a.is_empty() or b.is_empty():
				size = INF
				break
			size += ((a["position"] as Vector3) - (b["position"] as Vector3)).length()
		if size < best:
			best = size
			at = p
	return at

func _add_piece(mesh: Mesh, m: Material, node_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = m
	root.add_child(mi)
	return mi

## Rigid cylinders (bodies without a fitted outfit).
func _can_gauntlets(gold: StandardMaterial3D, deep: StandardMaterial3D, ink: StandardMaterial3D) -> void:
	for side: float in [1.0, -1.0]:
		var w := pt("wrist", side)
		var e := pt("elbow", side)
		var a0 := w.lerp(e, 0.06)
		var a1 := w.lerp(e, 0.5)
		var r0 := f("forearm_r") * 1.42
		var r1 := f("forearm_r") * 1.62
		limb(a0, a1, r0, r1, gold, 14)
		var dir := (a1 - a0).normalized()
		for t: float in [0.1, 0.9]:
			var p := a0.lerp(a1, t)
			var r := lerpf(r0, r1, t) * 1.1
			limb(p - dir * 0.004 * H, p + dir * 0.004 * H, r, r, deep, 14)
		limb(a0 + Vector3(0, r0 * 0.98, 0), a1 + Vector3(0, r1 * 0.98, 0), 0.0035 * H, 0.0045 * H, deep, 6)
		# The engraving faces forward (+Z, toward the camera), its long axis along the forearm.
		var rm := (r0 + r1) * 0.5
		var quad := QuadMesh.new()
		quad.size = Vector2(rm * 0.75, a0.distance_to(a1) * 0.62)
		var eng := MeshInstance3D.new()
		eng.name = "SigilEngraving_L" if side > 0.0 else "SigilEngraving_R"  # her left is +X
		eng.mesh = quad
		eng.material_override = ink
		var za := Vector3(0, 0, 1)
		eng.basis = Basis(dir.cross(za), dir, za)
		eng.position = a0.lerp(a1, 0.5) + Vector3(0, 0, rm + 0.0015 * H)
		root.add_child(eng)

## Linen wraps shaped to her hands and forearms: round the palm and over the knuckles (the
## fingers stay bare), and from under the gauntlet to below the elbow, in turns that overlap a
## little, three binding cords and a loose end.
func _fitted_arm_wraps(c: Color, wm: StandardMaterial3D, bind: StandardMaterial3D) -> void:
	var wmat := Garment.two_sided(wm)
	var bmat := Garment.two_sided(bind)
	for side: float in [1.0, -1.0]:
		var w := _real_wrist(side)
		var e := pt("elbow", side)
		var tip := pt("hand_tip", side)
		var turns := func(s: float, _ang: float) -> float: return 0.7 * absf(sin(s * PI * 5.0))  # the edges of each turn
		var hand := Garment.sleeve(body, w.lerp(e, 0.05), w.lerp(tip, 0.5), {  # the palm, to the knuckles
			"ease_at": func(_s: float) -> float: return 2.6,
			"bump": func(s: float, _ang: float) -> float: return 0.4 * absf(sin(s * PI * 3.0)),
			"bridge": 10, "smooth": 6, "cols": 48, "rows": 18, "max_r": 0.08, "reach": 0.12,
		})
		_add_piece(hand["mesh"], wmat, "hand_wrap_" + ("l" if side > 0.0 else "r"))
		var fore := Garment.sleeve(body, w.lerp(e, 0.46), w.lerp(e, 0.86), {
			"ease_at": func(s: float) -> float: return 2.2 + 0.6 * smoothstep(0.85, 1.0, s),
			"bump": turns, "bridge": 3, "cols": 40, "rows": 20,
		})
		_add_piece(fore["mesh"], wmat, "forearm_wrap")
		for t: float in [0.6, 0.73, 0.86]:
			var s0 := (t - 0.46) / 0.4
			var cord := Garment.sleeve(body, w.lerp(e, t - 0.012), w.lerp(e, t + 0.012), {
				"ease_at": func(s: float) -> float: return 3.6 + 1.2 * sin(PI * s) + 0.6 * s0,
				"bridge": 3, "cols": 40, "rows": 4,
			})
			_add_piece(cord["mesh"], bmat, "wrap_cord")
		var dir := (e - w).normalized()
		var hang_at: Vector3 = fore["point"].call(0.95, PI)  # under the forearm
		var end := cloth_panel(hang_at, dir, 0.013 * H, 0.075 * H, 2, 5, [], c)
		end.name = "WrapEnd"
		end.tex_scale = Vector2(1, 2)

## Linen wraps: over the knuckles, and from the gauntlet up to below the elbow, with a loose end.
func _arm_wraps(c: Color) -> void:
	var wm := cloth(c, "noise", 12.0)
	var bind := cloth(c.darkened(0.2))
	if not body.is_empty():
		_fitted_arm_wraps(c, wm, bind)
		return
	for side: float in [1.0, -1.0]:
		var w := pt("wrist", side)
		var e := pt("elbow", side)
		var tip := pt("hand_tip", side)
		limb(w.lerp(e, 0.04), w.lerp(tip, 0.72), f("forearm_r") * 1.18, f("forearm_r") * 1.22, wm, 8)
		limb(w.lerp(e, 0.48), w.lerp(e, 0.86), f("forearm_r") * 1.32, f("forearm_r") * 1.42, wm, 8)
		var dir := (e - w).normalized()
		for t: float in [0.6, 0.73, 0.86]:
			var p := w.lerp(e, t)
			limb(p - dir * 0.003 * H, p + dir * 0.003 * H, f("forearm_r") * 1.5, f("forearm_r") * 1.5, bind, 8)
		var end := cloth_panel(w.lerp(e, 0.84) + Vector3(0, -f("forearm_r") * 1.35, 0), dir, 0.013 * H, 0.075 * H, 2, 5, [], c)
		end.name = "WrapEnd"
		end.tex_scale = Vector2(1, 2)
