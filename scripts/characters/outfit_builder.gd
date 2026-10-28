class_name OutfitBuilder
extends RefCounted
## Builds clothing/hair meshes from body landmarks. Used by Outfits.apply().
## All landmark values are fractions of body height; H converts to metres.

var L: Dictionary
var H: float
var root := Node3D.new()
var hair_mats: Array = []
var form3_hair: Node3D = null

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
	return p

## Spheres along the legs and hips (in metres) that hanging cloth drapes over.
func leg_colliders(loose := 1.4, sides: Array = [1.0, -1.0]) -> Array:
	var out: Array = [[Vector3(0, f("hip_y"), 0.0), f("hip_hd") * 1.18], [Vector3(0, f("crotch_y"), 0.0), f("hip_hd") * 1.05]]
	for side: float in sides:
		var x := f("leg_x") * side
		var mid := (f("crotch_y") + f("knee_y")) * 0.5
		out.append([Vector3(x, mid, 0), f("thigh_r") * loose])
		out.append([Vector3(x, f("knee_y"), 0), f("calf_r") * loose * 1.25])
		out.append([Vector3(x * 1.05, (f("knee_y") + f("ankle_y")) * 0.5, 0), f("calf_r") * loose * 1.2])
	return out

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
		"wrap_bodice":  # sleeveless, crossed over at the chest, low standing collar
			_shell(c, 1.06)
			var lap := slab(Vector3(f("chest_hw") * 0.85, f("waist_y"), f("waist_hd") * 1.12),
				Vector3(-f("chest_hw") * 0.55, f("shoulder_y") - 0.01 * H, f("chest_z") + f("chest_hd") * 0.75), 0.02 * H, 0.004 * H, cloth(under))
			lap.position.z += 0.004 * H
			ring(f("neck_y") - 0.014 * H, f("neck_r") * 1.75, f("neck_r") * 1.75, 0.45, cloth(under))
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
			# Own hip shape: the generic _hips cone sits inside wide hips like Oto's.
			var hm := cloth(c)
			var hd := f("hip_hd") / maxf(f("hip_hw"), 0.001) * 1.22
			tube(f("crotch_y") - 0.045 * H, f("hip_y"), f("hip_hw") * 1.12, f("hip_hw") * 1.15, hd, hm, -0.004 * H)
			tube(f("hip_y"), f("waist_y") - 0.01 * H, f("hip_hw") * 1.15, f("waist_hw") * 1.32, hd, hm, -0.003 * H)
			var calf := f("ankle_y") + (f("knee_y") - f("ankle_y")) * 0.55
			var back := Vector3(0, 0, -0.006 * H)  # calves bulge behind the leg line
			for side: float in [1.0, -1.0]:
				var x := f("leg_x") * side
				var knee := Vector3(x * 1.05, f("knee_y"), 0) + back * 0.5
				limb(Vector3(x, f("crotch_y") + 0.01 * H, 0), knee, f("thigh_r") * 1.42, f("calf_r") * 1.95, hm)
				limb(knee, Vector3(x * 1.08, calf, 0) + back, f("calf_r") * 1.95, f("calf_r") * 1.6, hm)
			var wm := cloth(wrap, "noise", 10.0)
			var bind := cloth(wrap.darkened(0.3))
			for side: float in [1.0, -1.0]:
				var x := f("leg_x") * side * 1.08
				var top := Vector3(x, calf + 0.012 * H, -0.006 * H)
				var bot := Vector3(x, f("ankle_y") + 0.004 * H, -0.002 * H)
				limb(bot, top, f("ankle_r") * 1.3, f("calf_r") * 1.45, wm)
				for k in 4:
					var t := (k + 0.5) / 4.0
					var r := lerpf(f("ankle_r") * 1.38, f("calf_r") * 1.52, t)
					var band := ring(lerpf(bot.y, top.y, t), r, r, 0.25, bind)
					band.position.x = x
					band.position.z = lerpf(bot.z, top.z, t)
					band.rotation.z = 0.3 if k % 2 == 0 else -0.3
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
			_cap(m)
			box(h + Vector3(0, -ry * 0.35, -rz * 0.72), Vector3(rx * 2.05, ry * 1.5, rz * 0.55), m)
			box(Vector3(0, (h.y - ry * 1.1 + f("chest_y")) * 0.5, h.z - rz * 0.85), Vector3(rx * 1.7, h.y - ry * 1.1 - f("chest_y") + 0.02 * H, rz * 0.3), m)
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
				var top := h.y - ry * 0.2
				var bottom := f("knee_y")
				box(Vector3(0, (top + bottom) * 0.5, h.z - rz * 1.05), Vector3(rx * 2.4, top - bottom, rz * 0.5), black, form3_hair)
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
			_scapular(c, col(a.get("trim"), Color(0.9, 0.72, 0.3)), col(a.get("emblem"), Color(0.03, 0.02, 0.05)))
		"wide_sash":
			_wide_sash(c)
		"royal_cord":
			_royal_cord(c)
		"gauntlets":
			_gauntlets(c, col(a.get("inlay"), Color(0.02, 0.01, 0.04)))
		"arm_wraps":
			_arm_wraps(c)
		"tail":
			ring(f("waist_y") - 0.005 * H, f("waist_hw") * 1.42, f("waist_hd") * 1.45, 0.4, cloth(c, "noise", 10.0), f("waist_z"))

# --- Oto's queen's attire --------------------------------------------------------
# docs/OTO_OUTFIT.md describes the design. The parts below the sash are ClothPanels.

func _sash_r() -> float:
	return f("waist_hw") * 1.35

func _sash_front() -> float:
	return _sash_r() * f("waist_hd") / maxf(f("waist_hw"), 0.001)

## A long panel over both shoulders, hanging front and back to mid-shin. Above the sash it
## lies on the body; below it, it is cloth: gold-edged, gold hem, and on the front a black
## emblem near the hem (the hole in the world).
func _scapular(c: Color, trim: Color, emblem: Color) -> void:
	var pm := cloth(c, "noise", 5.0)
	var tm := Mats.get_mat(trim, "", 1.0, {"metal": 0.5, "rough": 0.45})
	var w := f("hip_hw") * 1.05
	var t := 0.006 * H
	var top_y := f("shoulder_y") + 0.012 * H
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
	var drop := f("waist_y") - 0.035 * H - (f("knee_y") - (f("knee_y") - f("ankle_y")) * 0.45)
	var cols := leg_colliders()
	var us := [0.0, 0.07, 0.3, 0.5, 0.7, 0.93, 1.0]
	var rows := 9
	for zs: float in [1.0, -1.0]:
		var p := cloth_panel(Vector3(0, f("waist_y") - 0.035 * H, zs * (_sash_front() + 0.003 * H)), Vector3.RIGHT, w, drop, us.size(), rows, cols, c)
		p.us = us
		p.name = "ScapularFront" if zs > 0.0 else "ScapularBack"
		var show_emblem := zs > 0.0
		p.face_color = func(i: int, j: int) -> Color:
			if i == 0 or i == us.size() - 2 or j == rows - 2:
				return trim
			if show_emblem and (i == 2 or i == 3) and (j == rows - 4 or j == rows - 5):
				return emblem
			return c

## A wide linen sash wound twice and knotted at her left hip, two tails hanging free.
func _wide_sash(c: Color) -> void:
	var sm := cloth(c, "noise", 8.0)
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

## The queen's cord: gold over the sash, a gold clasp with a black stone, a short tassel.
func _royal_cord(c: Color) -> void:
	var gold := Mats.get_mat(c, "", 1.0, {"metal": 0.85, "rough": 0.3})
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
## ridges, a spine along the back of the forearm, and a black stone, the queen's insignia.
func _gauntlets(c: Color, inlay: Color) -> void:
	var gold := Mats.get_mat(c, "", 1.0, {"metal": 0.85, "rough": 0.28})
	var deep := Mats.get_mat(c.darkened(0.3), "", 1.0, {"metal": 0.85, "rough": 0.35})
	var stone := Mats.get_mat(inlay, "", 1.0, {"rough": 0.06, "metal": 0.2})
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
		ball(a0.lerp(a1, 0.5) + Vector3(0, (r0 + r1) * 0.5 + 0.002 * H, 0), Vector3(0.012, 0.005, 0.009) * H, stone)

## Linen wraps: over the knuckles, and from the gauntlet up to below the elbow, with a loose end.
func _arm_wraps(c: Color) -> void:
	var wm := cloth(c, "noise", 12.0)
	var bind := cloth(c.darkened(0.2))
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
