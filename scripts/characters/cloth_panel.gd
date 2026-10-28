class_name ClothPanel
extends MeshInstance3D
## A hanging strip of cloth simulated with verlet particles. The top row is pinned to the
## character, so it follows every step, lean and bob. The rest swings under gravity and a
## light wind, keeps its size through distance constraints, and is pushed out of sphere
## colliders (hips, legs) and above the ground, so it drapes over the body instead of
## passing through it. Colours are per face (face_color), so trim and hems stay crisp.
## An optional decal (decal_texture over decal_rect) is drawn on the outer face and moves
## with the cloth. color_swap recolours faces and the decal (Shadow forms: gold to silver).
## Configure the vars, then add it under the outfit root; it starts settled on its first
## physics frame. Units are metres in the parent's space.

var cols := 4  # particles across
var rows := 8  # particles down
var us: Array = []  # column positions across the width, 0..1 (default: even)
var width := 0.3
var length := 0.6
var pin_center := Vector3.ZERO  # middle of the pinned top edge (parent space)
var across := Vector3.RIGHT  # width direction (parent space)
var hang := Vector3.DOWN  # direction the cloth hangs at rest (parent space)
var colliders: Array = []  # [[centre (parent space), radius], ...]; a third item, a Node3D,
	# moves that collider with the node (its frame is the parent's at rest: Rig followers)
var pin_node: Node3D = null  # when set, the pins ride this node (a bone) instead of the parent
var floor_y := 0.02  # world height the cloth stays above
var damping := 0.985
var wind := 0.5
var iterations := 5
var max_step := 0.25  # metres a particle may move per frame (keeps flings stable)
var face_color := Callable()  # (column, row) -> Color; default white
var base_color := Color.WHITE
var tex_scale := Vector2(3, 6)
var decal_texture: Texture2D = null
var decal_rect := Rect2()  # in panel space: x across (0..1), y down from the pins (0..1)
var decal_color := Color.WHITE
var color_swap := {}  # Color -> Color

var _cloth_mat: StandardMaterial3D
var _decal_mat: StandardMaterial3D

var _p := PackedVector3Array()  # positions (world)
var _q := PackedVector3Array()  # previous positions (world)
var _links: Array = []  # [a, b, rest length]
var _mesh := ArrayMesh.new()
var _t := 0.0
var _last_pin := Vector3.INF

func _ready() -> void:
	if us.is_empty():
		for i in cols:
			us.append(float(i) / float(cols - 1))
	cols = us.size()
	_t = randf() * 10.0
	mesh = _mesh
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true  # face colours are authored like albedo colours
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.92
	m.albedo_texture = Mats.texture("noise")
	m.uv1_scale = Vector3(tex_scale.x, tex_scale.y, 1)
	_cloth_mat = m
	if decal_texture:
		_decal_mat = StandardMaterial3D.new()
		_decal_mat.albedo_texture = decal_texture
		_decal_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_decal_mat.metallic = 0.7
		_decal_mat.roughness = 0.35
		_decal_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	extra_cull_margin = 2.0

## Rest position of particle (i, j) in the parent's space.
func _layout(i: int, j: int) -> Vector3:
	return pin_center + across.normalized() * ((float(us[i]) - 0.5) * width) + hang.normalized() * (length * float(j) / float(rows - 1))

func _reset(xf: Transform3D) -> void:
	_p.resize(cols * rows)
	_q.resize(cols * rows)
	for j in rows:
		for i in cols:
			_p[j * cols + i] = xf * _layout(i, j)
	_q = _p.duplicate()
	_links.clear()
	for j in rows:
		for i in cols:
			var k := j * cols + i
			for o: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(2, 0), Vector2i(0, 2)]:
				var i2 := i + o.x
				var j2 := j + o.y
				if i2 >= 0 and i2 < cols and j2 < rows:
					var k2 := j2 * cols + i2
					_links.append([k, k2, _p[k].distance_to(_p[k2])])
	for n in 45:  # settle over the hips before the first frame is drawn
		_step(xf, 1.0 / 60.0)

func _physics_process(delta: float) -> void:
	var parent := get_parent() as Node3D
	if parent == null or not is_visible_in_tree():
		return
	var xf := pin_node.global_transform if is_instance_valid(pin_node) else parent.global_transform
	var pin := xf * pin_center
	if _p.is_empty() or pin.distance_to(_last_pin) > 3.0:
		_reset(xf)
	_last_pin = pin
	_t += delta
	_step(xf, delta)
	_rebuild(xf)

func _step(xf: Transform3D, delta: float) -> void:
	var dt2 := delta * delta
	var gust := 0.6 + 0.4 * sin(_t * 0.9) * sin(_t * 0.37)
	var wind_v := xf.basis.orthonormalized() * Vector3(sin(_t * 0.7) * 0.5, 0.0, 0.35 + cos(_t * 1.1) * 0.3) * wind * gust
	var accel := Vector3(0, -9.8, 0)
	for j in rows:
		for i in cols:
			var k := j * cols + i
			if j == 0:
				_p[k] = xf * _layout(i, 0)
				_q[k] = _p[k]
				continue
			var p := _p[k]
			var v := (p - _q[k]) * damping
			if v.length() > max_step:
				v = v.normalized() * max_step
			_q[k] = p
			var flutter := 0.7 + 0.3 * sin(_t * 2.3 + k * 0.9)
			_p[k] = p + v + (accel + wind_v * flutter) * dt2
	var sc := xf.basis.get_scale().x
	var world_cols: Array = []
	for c: Array in colliders:
		var cx := (c[2] as Node3D).global_transform if c.size() > 2 and is_instance_valid(c[2]) else xf
		world_cols.append([cx * (c[0] as Vector3), float(c[1]) * sc])
	for it in iterations:
		for l: Array in _links:
			var a: int = l[0]
			var b: int = l[1]
			var wa := 0.0 if a < cols else 1.0
			var wb := 0.0 if b < cols else 1.0
			if wa + wb == 0.0:
				continue
			var d := _p[b] - _p[a]
			var dl := d.length()
			if dl < 0.000001:
				continue
			var corr := d * ((dl - float(l[2])) / dl / (wa + wb))
			_p[a] += corr * wa
			_p[b] -= corr * wb
		for k in range(cols, _p.size()):
			var p := _p[k]
			for wc: Array in world_cols:
				var c: Vector3 = wc[0]
				var r: float = wc[1]
				var d := p - c
				var dl := d.length()
				if dl < r and dl > 0.000001:
					p = c + d / dl * r
			if p.y < floor_y:
				p.y = floor_y
			_p[k] = p

func _rebuild(_xf: Transform3D) -> void:
	var inv := (get_parent() as Node3D).global_transform.affine_inverse()
	var local := PackedVector3Array()
	local.resize(_p.size())
	for k in _p.size():
		local[k] = inv * _p[k]
	var normals := PackedVector3Array()
	normals.resize(_p.size())
	for j in rows:
		for i in cols:
			var k := j * cols + i
			var dx := local[j * cols + mini(i + 1, cols - 1)] - local[j * cols + maxi(i - 1, 0)]
			var dy := local[mini(j + 1, rows - 1) * cols + i] - local[maxi(j - 1, 0) * cols + i]
			var n := dy.cross(dx)
			normals[k] = n.normalized() if n.length() > 0.000001 else Vector3.FORWARD
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in rows - 1:
		for i in cols - 1:
			var c: Color = face_color.call(i, j) if face_color.is_valid() else base_color
			c = color_swap.get(c, c)
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var ii := i + corner.x
				var jj := j + corner.y
				var k := jj * cols + ii
				st.set_color(c)
				st.set_normal(normals[k])
				st.set_uv(Vector2(float(us[ii]), float(jj) / float(rows - 1)))
				st.add_vertex(local[k])
	_mesh.clear_surfaces()
	st.commit(_mesh)
	_mesh.surface_set_material(0, _cloth_mat)
	if _decal_mat:
		_decal_mat.albedo_color = color_swap.get(decal_color, decal_color)
		var sd := SurfaceTool.new()
		sd.begin(Mesh.PRIMITIVE_TRIANGLES)
		var nu := 3
		var nv := 6
		for b in nv:
			for a in nu:
				for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]:
					var s := float(a + corner.x) / nu
					var t := float(b + corner.y) / nv
					var at := _sample(local, normals, decal_rect.position.x + s * decal_rect.size.x, decal_rect.position.y + t * decal_rect.size.y)
					sd.set_normal(at[1])
					sd.set_uv(Vector2(s, t))
					sd.add_vertex(at[0] + at[1] * 0.0025)
		sd.commit(_mesh)
		_mesh.surface_set_material(1, _decal_mat)

## Position and normal at panel coordinates (u across, v down), bilinear on the particle grid.
func _sample(local: PackedVector3Array, normals: PackedVector3Array, u: float, v: float) -> Array:
	var i := 0
	while i < cols - 2 and u > float(us[i + 1]):
		i += 1
	var fu := clampf((u - float(us[i])) / maxf(float(us[i + 1]) - float(us[i]), 0.0001), 0.0, 1.0)
	var rv := clampf(v, 0.0, 1.0) * (rows - 1)
	var j := mini(int(rv), rows - 2)
	var fv := rv - j
	var k00 := j * cols + i
	var k10 := k00 + 1
	var k01 := k00 + cols
	var k11 := k01 + 1
	var p := local[k00].lerp(local[k10], fu).lerp(local[k01].lerp(local[k11], fu), fv)
	var n := normals[k00].lerp(normals[k10], fu).lerp(normals[k01].lerp(normals[k11], fu), fv)
	return [p, n.normalized() if n.length() > 0.0001 else Vector3.FORWARD]

## Lowest point of the cloth in world space (tests).
func lowest_y() -> float:
	var y := INF
	for p in _p:
		y = minf(y, p.y)
	return y

func particles() -> PackedVector3Array:
	return _p
