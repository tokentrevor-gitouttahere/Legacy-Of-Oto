class_name Rig
extends RefCounted
## Mixamo rigs (docs/RIGGING.md). A rigged base mesh gets its skinned body, skeleton and
## animations from the FBX files in RIGS, and everything the outfit built on the static T-pose
## mesh (clothes, gold, hair, the face) is skinned to the same skeleton: each vertex takes the
## bone weights of the body points nearest to it, so it bends with the body under it. Hanging
## cloth (ClothPanel) keeps its physics and follows the bone it is pinned to.
##
## The static mesh stays in the wrapper, hidden: the outfit and face are built on it, and the
## rule checks measure against it. Outfits.apply calls attach() after dressing.

const DIR := "res://assets/models/oto/rig/"
const RIGS := {
	"oto": {
		"skin": DIR + "walk.fbx",  # every file carries the skinned body; any one will do
		"anims": {
			"walk": DIR + "walk.fbx",
			"hot_walk": DIR + "hot_walk.fbx",
			"l_punch": DIR + "l_punch.fbx",
			"r_punch": DIR + "r_punch.fbx",
			"cross_punch": DIR + "cross_punch.fbx",
			"quad_punch": DIR + "quad_punch.fbx",
			"kick": DIR + "kick.fbx",
			"roundhouse_kick": DIR + "roundhouse_kick.fbx",
			"flying_kick": DIR + "flying_kick.fbx",
			"flying": DIR + "flying.fbx",
			"falling": DIR + "falling.fbx",
			"fall_impact": DIR + "fall_impact.fbx",
			"hit_reaction": DIR + "hit_reaction.fbx",
			"taking_punch": DIR + "taking_punch.fbx",
			"stunned": DIR + "stunned.fbx",
			"defeated": DIR + "defeated.fbx",
			# ki attacks (session 5): Mixamo's beam, spell and magic attacks
			"beam": DIR + "beam.fbx",                   # [BEAM]
			"cast_spell": DIR + "cast_spell.fbx",       # [Casting Spell]
			"ki_blast_1h": DIR + "ki_blast_1h.fbx",     # [Standing 1H Magic Attack 01]
			"ki_blast_2h": DIR + "ki_blast_2h.fbx",     # [Standing 2H Magic Attack 01]
			"ki_blast_2h_b": DIR + "ki_blast_2h_b.fbx", # [Standing 2H Magic Attack 02]
			"ki_area": DIR + "ki_area.fbx",             # [Standing 2H Magic Area Attack 01]
			"ki_area_b": DIR + "ki_area_b.fbx",         # [Standing 2H Magic Area Attack 02]
		},
		"loop": ["walk", "hot_walk", "flying", "falling"],
		# Downloaded without "In Place": the hips travel along the floor. Hold the spot (keep the
		# height); the game moves her.
		"in_place": ["flying_kick", "stunned"],
		# No idle animation yet: hold the walk's passing frame (feet together).
		"idle": ["walk", 0.032],
		# Seconds into each animation where a strike lands (each hand's furthest reach ahead of
		# the chest, measured by scripts/tools/probe_anims.gd).
		"hits": {"l_punch": [0.57], "r_punch": [0.40], "cross_punch": [1.13], "quad_punch": [0.235, 0.444, 0.679, 0.914],
			"kick": [1.26], "roundhouse_kick": [1.0], "flying_kick": [0.45],
			# ki releases: the hands' furthest reach (docs/CUTSCENES.md)
			"ki_blast_1h": [1.11], "ki_blast_2h": [1.35], "beam": [1.0], "ki_area": [1.83]},
		# where each ki attack's hands are drawn back, gathering (a held pose while charging)
		"gathers": {"ki_blast_2h": 0.94, "beam": 0.72, "ki_area": 0.74},
		# Ground speed the walks were made for (m/s): stride from the feet, per cycle.
		"walk_speed": {"walk": 1.47, "hot_walk": 1.0},
	},
}

static var _libs := {}

static func has_rig(model_key: String) -> bool:
	return RIGS.has(model_key)

static func info(model_key: String) -> Dictionary:
	return RIGS.get(model_key, {})

## Every animation of a rig in one library (cached), plus "idle".
static func library(model_key: String) -> AnimationLibrary:
	if _libs.has(model_key):
		return _libs[model_key]
	var inf: Dictionary = RIGS[model_key]
	var lib := AnimationLibrary.new()
	for anim_name: String in inf["anims"]:
		var src: Node = (load(inf["anims"][anim_name]) as PackedScene).instantiate()
		var ap: AnimationPlayer = src.find_children("*", "AnimationPlayer", true, false)[0]
		var a := (ap.get_animation(ap.get_animation_list()[0]) as Animation).duplicate(true) as Animation
		a.loop_mode = Animation.LOOP_LINEAR if anim_name in inf["loop"] else Animation.LOOP_NONE
		if anim_name in inf.get("in_place", []):
			_in_place(a)
		lib.add_animation(anim_name, a)
		src.free()
	var idle: Array = inf["idle"]
	lib.add_animation("idle", _held(lib.get_animation(idle[0]), float(idle[1])))
	_libs[model_key] = lib
	return lib

## The hips keep their height but not their ground track: every key takes the first key's x and z.
static func _in_place(a: Animation) -> void:
	for i in a.get_track_count():
		if a.track_get_type(i) != Animation.TYPE_POSITION_3D or a.track_get_path(i).get_subname(0) != "mixamorig_Hips":
			continue
		var first: Vector3 = a.track_get_key_value(i, 0)
		for k in a.track_get_key_count(i):
			var p: Vector3 = a.track_get_key_value(i, k)
			a.track_set_key_value(i, k, Vector3(first.x, p.y, first.z))

## One frame of `a`, held.
static func _held(a: Animation, t: float) -> Animation:
	var out := Animation.new()
	out.length = 1.0
	out.loop_mode = Animation.LOOP_LINEAR
	for i in a.get_track_count():
		var ty := a.track_get_type(i)
		if ty not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
			continue
		var j := out.add_track(ty)
		out.track_set_path(j, a.track_get_path(i))
		match ty:
			Animation.TYPE_POSITION_3D:
				out.position_track_insert_key(j, 0.0, a.position_track_interpolate(i, t))
			Animation.TYPE_ROTATION_3D:
				out.rotation_track_insert_key(j, 0.0, a.rotation_track_interpolate(i, t))
			_:
				out.scale_track_insert_key(j, 0.0, a.scale_track_interpolate(i, t))
	return out

## The mesh arrays a piece was built with, in its own (pre-skinning) space: what the fit
## checks measure. For a piece that is not skinned, its mesh's.
static func fit_arrays(mi: MeshInstance3D) -> Array:
	var m: Mesh = mi.get_meta("fit_mesh", mi.mesh)
	return m.surface_get_arrays(0)

# --- attaching ------------------------------------------------------------------------------

## Give a dressed ModelLoader wrapper its rig: skinned body, skeleton, animations; skin the
## outfit to it. Sets the visual's "anim" (AnimationPlayer), "skeleton" and "rig" metas.
static func attach(visual: Node3D) -> void:
	var key: String = visual.get_meta("model_key", "")
	if not RIGS.has(key):
		return
	var old := visual.get_node_or_null("Rigged")
	if old:
		visual.remove_child(old)
		old.free()
	var static_rig := visual.get_child(0) as Node3D
	var body := static_rig.get_child(0) as MeshInstance3D
	var inst: Node3D = (load(RIGS[key]["skin"]) as PackedScene).instantiate()
	inst.name = "Rigged"
	for ap: AnimationPlayer in inst.find_children("*", "AnimationPlayer", true, false):
		ap.get_parent().remove_child(ap)
		ap.free()
	var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	var bmi: MeshInstance3D = sk.find_children("*", "MeshInstance3D", true, false)[0]
	var hook: Callable = visual.get_meta("skin_hook", Callable())
	if hook.is_valid():  # a reshaped body (docs/BODY_STUDY.md) moves this copy of the skinned mesh first
		hook.call(sk, bmi)
	# line the rig's rest pose up with the static mesh (Mixamo returns it at 1/100 scale)
	var rest := _rest_body(sk, bmi)
	var rig_box := _box(rest["pos"])
	var st_box: AABB = (static_rig.transform * body.transform) * body.mesh.get_aabb()
	var k := st_box.size.y / rig_box.size.y
	inst.transform = Transform3D(Basis.from_scale(Vector3.ONE * k), st_box.get_center() - rig_box.get_center() * k)
	visual.add_child(inst)
	bmi.material_override = body.material_override  # the same material: forms tint it
	bmi.extra_cull_margin = 1.0
	body.visible = false
	var S := inst.transform * sk.transform  # the skeleton in wrapper space
	var pos_w := PackedVector3Array()
	for p: Vector3 in rest["pos"]:
		pos_w.append(inst.transform * p)
	var grid := _Grid.new(pos_w, 0.03)
	# the outfit's skin: bind i is bone i, and mesh space is skeleton space
	var skin := Skin.new()
	for b in sk.get_bone_count():
		skin.add_bind(b, sk.get_bone_global_rest(b).affine_inverse())
	var outfit := visual.get_node_or_null("Outfit")
	if outfit:
		var pieces: Array = []
		for mi: MeshInstance3D in outfit.find_children("*", "MeshInstance3D", true, false):
			if not (mi is ClothPanel):
				pieces.append([mi, _rel(mi, visual)])
		for e: Array in pieces:
			_skin_piece(e[0], e[1], visual, S, sk, skin, grid, rest)
		var followers := {}
		for p: ClothPanel in outfit.find_children("*", "ClothPanel", true, false):
			_follow(p, visual, S, sk, grid, rest, followers)
	var anim := AnimationPlayer.new()
	anim.name = "Anim"
	inst.add_child(anim)
	anim.root_node = NodePath("..")
	anim.add_animation_library("", library(key))
	anim.play("idle")
	visual.set_meta("anim", anim)
	visual.set_meta("skeleton", sk)
	visual.set_meta("rig", RIGS[key])

## The skinned body at rest, in the FBX root's space: positions, and each point's four
## strongest bones (skeleton bone indices) and weights.
static func _rest_body(sk: Skeleton3D, bmi: MeshInstance3D) -> Dictionary:
	var arr := bmi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var w: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var per := bones.size() / v.size()
	var bind_bone := PackedInt32Array()
	for b in bmi.skin.get_bind_count():
		var bone := bmi.skin.get_bind_bone(b)
		bind_bone.append(bone if bone >= 0 else sk.find_bone(bmi.skin.get_bind_name(b)))
	var pos := PackedVector3Array()
	var top_b := PackedInt32Array()
	var top_w := PackedFloat32Array()
	var place := sk.transform * bmi.transform
	for i in v.size():
		var p := Vector3.ZERO
		var pairs: Array = []
		for k in per:
			var wt := w[i * per + k]
			if wt <= 0.0:
				continue
			var bi := bones[i * per + k]
			p += wt * (sk.get_bone_global_rest(bind_bone[bi]) * bmi.skin.get_bind_pose(bi) * v[i])
			pairs.append([wt, bind_bone[bi]])
		pairs.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		for k in 4:
			top_b.append(int(pairs[k][1]) if k < pairs.size() else 0)
			top_w.append(float(pairs[k][0]) if k < pairs.size() else 0.0)
		pos.append(place * p)
	return {"pos": pos, "bones": top_b, "weights": top_w}

static func _box(pts: PackedVector3Array) -> AABB:
	var box := AABB(pts[0], Vector3.ZERO)
	for p in pts:
		box = box.expand(p)
	return box

## A node's transform in the wrapper's space.
static func _rel(n: Node, top: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur := n
	while cur != null and cur != top:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf

## Bone weights for a point (wrapper space): blended from the three nearest body points.
## Returns [bones (4), weights (4)]. Written without allocations: it runs for every vertex.
static func _weights_at(p: Vector3, grid: _Grid, rest: Dictionary) -> Array:
	var near := grid.nearest3(p)
	var tb: PackedInt32Array = rest["bones"]
	var tw: PackedFloat32Array = rest["weights"]
	var ab := PackedInt32Array()
	ab.resize(12)
	var aw := PackedFloat32Array()
	aw.resize(12)
	var n := 0
	for e in 3:
		var idx: int = near[e * 2]
		if idx < 0:
			continue
		var f := 1.0 / (near[e * 2 + 1] + 0.004)
		for k in 4:
			var wt := tw[idx * 4 + k]
			if wt <= 0.0:
				continue
			var b := tb[idx * 4 + k]
			var j := 0
			while j < n and ab[j] != b:
				j += 1
			if j == n:
				ab[n] = b
				aw[n] = 0.0
				n += 1
			aw[j] += wt * f
	var bones := PackedInt32Array([0, 0, 0, 0])
	var weights := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var total := 0.0
	for k in 4:  # the four strongest
		var best := -1
		for j in n:
			if aw[j] > 0.0 and (best < 0 or aw[j] > aw[best]):
				best = j
		if best < 0:
			break
		bones[k] = ab[best]
		weights[k] = aw[best]
		total += aw[best]
		aw[best] = 0.0
	if total > 0.0:
		for k in 4:
			weights[k] /= total
	else:
		weights[0] = 1.0
	return [bones, weights]

## Skin one outfit piece: its vertices move into skeleton space with bone weights taken from
## the body under them; its node is placed on the skeleton's frame. The mesh it was built with
## is kept as "fit_mesh".
static func _skin_piece(mi: MeshInstance3D, rel: Transform3D, visual: Node3D, S: Transform3D, sk: Skeleton3D, skin: Skin, grid: _Grid, rest: Dictionary) -> void:
	var src := mi.mesh
	if src == null:
		return
	var surfaces: Array = []
	if src is PrimitiveMesh:
		surfaces.append([(src as PrimitiveMesh).get_mesh_arrays(), (src as PrimitiveMesh).material, Mesh.PRIMITIVE_TRIANGLES])
	elif src is ArrayMesh:
		for s in src.get_surface_count():
			surfaces.append([src.surface_get_arrays(s), src.surface_get_material(s), (src as ArrayMesh).surface_get_primitive_type(s)])
	else:
		return
	var to_s := S.affine_inverse() * rel
	var nb := to_s.basis.inverse().transposed()
	var out := ArrayMesh.new()
	for e: Array in surfaces:
		var arr: Array = e[0]
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: Variant = arr[Mesh.ARRAY_NORMAL]
		var nv := PackedVector3Array()
		var nn := PackedVector3Array()
		var bones := PackedInt32Array()
		var weights := PackedFloat32Array()
		for i in v.size():
			var bw := _weights_at(rel * v[i], grid, rest)
			bones.append_array(bw[0])
			weights.append_array(bw[1])
			nv.append(to_s * v[i])
			if n != null and (n as PackedVector3Array).size() == v.size():
				nn.append((nb * (n as PackedVector3Array)[i]).normalized())
		arr[Mesh.ARRAY_VERTEX] = nv
		arr[Mesh.ARRAY_NORMAL] = nn if not nn.is_empty() else null
		arr[Mesh.ARRAY_TANGENT] = null
		arr[Mesh.ARRAY_BONES] = bones
		arr[Mesh.ARRAY_WEIGHTS] = weights
		out.add_surface_from_arrays(e[2], arr)
		if e[1]:
			out.surface_set_material(out.get_surface_count() - 1, e[1])
	mi.set_meta("fit_mesh", src)
	mi.mesh = out
	mi.skin = skin
	mi.skeleton = mi.get_path_to(sk)
	mi.transform = _rel(mi.get_parent(), visual).affine_inverse() * S
	mi.extra_cull_margin = 1.0

## Hanging cloth keeps its physics but follows the body: its pins ride the bone nearest to
## them, and each collider the bone nearest to it. A follower is a node on a bone that sits
## exactly on the wrapper's frame at rest, so the cloth's settings (wrapper space) stay valid.
static func _follow(p: ClothPanel, visual: Node3D, S: Transform3D, sk: Skeleton3D, grid: _Grid, rest: Dictionary, followers: Dictionary) -> void:
	var prel := _rel(p.get_parent(), visual)
	p.pin_node = _follower(_bone_at(prel * p.pin_center, grid, rest), sk, S, followers)
	var cols: Array = []
	for c: Array in p.colliders:
		var centre: Vector3 = prel * (c[0] as Vector3)
		cols.append([c[0], c[1], _follower(_bone_at(centre, grid, rest), sk, S, followers)])
	p.colliders = cols

static func _bone_at(p: Vector3, grid: _Grid, rest: Dictionary) -> int:
	var bw := _weights_at(p, grid, rest)
	return (bw[0] as PackedInt32Array)[0]

static func _follower(bone: int, sk: Skeleton3D, S: Transform3D, followers: Dictionary) -> Node3D:
	if followers.has(bone):
		return followers[bone]
	var att := BoneAttachment3D.new()
	att.name = "Follow_" + sk.get_bone_name(bone)
	sk.add_child(att)
	att.bone_name = sk.get_bone_name(bone)
	var f := Node3D.new()
	f.name = "Frame"
	f.transform = (S * sk.get_bone_global_rest(bone)).affine_inverse()  # wrapper frame at rest
	att.add_child(f)
	followers[bone] = f
	return f

## Points in buckets, for nearest-point lookups.
class _Grid:
	var cell: float
	var pts: PackedVector3Array
	var buckets := {}

	func _init(points: PackedVector3Array, cell_size: float) -> void:
		cell = cell_size
		pts = points
		var lists := {}  # plain Arrays first: a packed array in a Dictionary is a copy on read
		for i in pts.size():
			var key := Vector3i((pts[i] / cell).floor())
			if not lists.has(key):
				lists[key] = []
			(lists[key] as Array).append(i)
		for key: Vector3i in lists:
			buckets[key] = PackedInt32Array(lists[key])

	## The three nearest points: [i0, d0, i1, d1, i2, d2] (index -1 where there is none),
	## searching outward ring by ring until something is found, then one ring more.
	func nearest3(p: Vector3) -> PackedFloat32Array:
		var c := Vector3i((p / cell).floor())
		var out := PackedFloat32Array([-1, INF, -1, INF, -1, INF])
		var ring := 1
		var found_at := -1
		while ring <= 12:
			for x in range(c.x - ring, c.x + ring + 1):
				for y in range(c.y - ring, c.y + ring + 1):
					for z in range(c.z - ring, c.z + ring + 1):
						if ring > 1 and absi(x - c.x) < ring and absi(y - c.y) < ring and absi(z - c.z) < ring:
							continue  # an inner cell, already searched
						var b: Variant = buckets.get(Vector3i(x, y, z))
						if b == null:
							continue
						for i: int in b:
							var d := p.distance_to(pts[i])
							if d < out[5]:
								if d < out[1]:
									out[4] = out[2]; out[5] = out[3]
									out[2] = out[0]; out[3] = out[1]
									out[0] = i; out[1] = d
								elif d < out[3]:
									out[4] = out[2]; out[5] = out[3]
									out[2] = i; out[3] = d
								else:
									out[4] = i; out[5] = d
			if out[0] >= 0.0 and found_at < 0:
				found_at = ring
			if found_at >= 0 and ring >= found_at + 1:
				break
			ring += 1
		return out
