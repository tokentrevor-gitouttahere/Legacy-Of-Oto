extends Node3D
## Body-shape study (docs/BODY_STUDY.md): Oto's base mesh reshaped by BodyShape, side by side on a
## plain ground. The game's own mesh is never touched; every figure is a copy.
##   --study "original;curvy;bust=4,butt=4"   figures, left to right: "original", a preset from
##                                            assets/models/body_presets.json, or amounts (cm)
##   --view front|back|side                   side lines them up along z, her front to the right
##   --dress [--pose idle|walk|kick|...] [--at SECONDS]
##                                            the full Oto: her outfit built on the reshaped body,
##                                            the skinned (Mixamo) body reshaped the same way, posed
##   --size M --cy M --spacing M              the orthographic frame (height in metres, centre) and the gap
## Without --dress the figures are bare torsos (arms cut off at the shoulder so they can stand
## close). Use with: python tools/run.py shot body_study --resolution 1600x800 --args="--study original;curvy"

const SOURCE := "res://assets/models/base_female/model_0.obj"
const SKIN := Color(0.29, 0.16, 0.09)
const HEIGHT := 1.7
const CUT_X := 0.15  # metres: past this, above CUT_Y, is arm
const CUT_Y := 1.12

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var names := _arg(args, "--study", "original;curvy").split(";")
	var view := _arg(args, "--view", "front")
	var dress := "--dress" in args
	var spacing := float(_arg(args, "--spacing", "0.7" if dress else "0.5"))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.80, 0.82, 0.85)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.57, 0.62)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.1
	add_child(sun)
	# from the camera's side and above, so the form reads in the shading
	var travel := Vector3(0.5, -0.6, -0.8)
	match view:
		"side":
			travel = Vector3(1.0, -0.55, -0.35)
		"back":
			travel = Vector3(-0.5, -0.6, 0.8)
	sun.look_at_from_position(Vector3.ZERO, travel, Vector3.UP)

	var base := load(SOURCE) as Mesh
	var shaper := BodyShape.new(base)
	var presets := BodyShape.load_presets()
	var bounds := base.get_aabb()
	var s := HEIGHT / bounds.size.y
	var mat := StandardMaterial3D.new()
	mat.albedo_color = SKIN
	mat.roughness = 0.8
	var cy := float(_arg(args, "--cy", "1.02"))
	var size := float(_arg(args, "--size", "1.0"))
	for i in names.size():
		var holder := Node3D.new()
		var along := (i - (names.size() - 1) * 0.5) * spacing
		match view:
			"side":
				holder.position = Vector3(0, 0, along)
			"back":
				holder.position = Vector3(-along, 0, 0)
			_:
				holder.position = Vector3(along, 0, 0)
		add_child(holder)
		var amounts := _amounts(names[i], presets)
		names[i] = names[i].replace("_", " ") if presets.has(names[i].replace("_", " ")) else names[i]
		if dress:
			var figure := shaper.dressed(amounts)
			holder.add_child(figure)
			var pose := _arg(args, "--pose", "idle")
			if pose != "idle":
				var ap: AnimationPlayer = figure.get_meta("anim")
				ap.play(pose)
				var hits: Array = figure.get_meta("rig").get("hits", {}).get(pose, [])
				var at := float(_arg(args, "--at", "-1"))
				ap.seek(at if at >= 0.0 else (float(hits[0]) if not hits.is_empty() else 0.4), true)
				ap.pause()
		else:
			var mi := MeshInstance3D.new()
			mi.mesh = _torso_only(shaper.shape(amounts), bounds, s)
			mi.material_override = mat
			mi.scale = Vector3.ONE * s
			mi.position = Vector3(-(bounds.position.x + bounds.size.x * 0.5) * s, -bounds.position.y * s, -(bounds.position.z + bounds.size.z * 0.5) * s)
			holder.add_child(mi)
		var label := Label3D.new()
		label.text = names[i]
		label.pixel_size = 0.0011 * size
		label.font_size = 56
		label.outline_size = 12
		label.position = Vector3(0, cy - size * 0.46, 0)
		label.no_depth_test = true
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		holder.add_child(label)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = size
	add_child(cam)
	var centre := Vector3(0, cy, 0)
	match view:
		"side":
			cam.look_at_from_position(centre + Vector3(-6, 0, 0), centre)
		"back":
			cam.look_at_from_position(centre + Vector3(0, 0, -6), centre)
		_:
			cam.look_at_from_position(centre + Vector3(0, 0, 6), centre)
	cam.current = true

func _arg(args: PackedStringArray, key: String, fallback: String) -> String:
	var i := args.find(key)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else fallback

## "original", a preset's name, or "bust=4,waist=-1.8".
func _amounts(token: String, presets: Dictionary) -> Dictionary:
	token = token.replace("_", " ") if presets.has(token.replace("_", " ")) else token  # "Oto_Body_Final"
	if presets.has(token):
		return presets[token]
	var out := {}
	if "=" in token:
		for pair in token.split(","):
			var kv := pair.split("=")
			if kv.size() == 2 and BodyShape.PARAMS.has(kv[0]):
				out[kv[0]] = float(kv[1])
	return out

## The mesh without the arms (triangles wholly out past the shoulder line), in the mesh's own
## units: so the figures can stand close together.
func _torso_only(mesh: Mesh, bounds: AABB, s: float) -> ArrayMesh:
	var arr := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var keep := PackedInt32Array()
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if idx.is_empty():
		for i in v.size():
			idx.append(i)
	for t in range(0, idx.size(), 3):
		var cut := true
		for k in 3:
			var p := v[idx[t + k]]
			var x := absf(p.x - (bounds.position.x + bounds.size.x * 0.5)) * s
			var y := (p.y - bounds.position.y) * s
			cut = cut and x > CUT_X and y > CUT_Y
		if not cut:
			keep.append_array(PackedInt32Array([idx[t], idx[t + 1], idx[t + 2]]))
	arr[Mesh.ARRAY_INDEX] = keep
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return out
