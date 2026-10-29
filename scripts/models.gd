class_name ModelLoader
extends RefCounted
## Loads a character from one or more meshes, scales the whole set to a target
## height and stands it on the origin facing +Z. Add new characters to MODELS.
## A part may set "texture" or "color"; a part with neither keeps the materials
## from its OBJ's .mtl. Overridden materials are listed in the wrapper's "mats"
## meta so forms and effects can tint them.

const MALE_SKIN := "res://assets/models/base_male/HUM-Skin-G.png"

const MODELS := {
	"oto": {
		"height": 1.7,
		# vertex colours multiply the skin: BodyShape's soft darker area on each breast
		"parts": [{"path": "res://assets/models/base_female/model_0.obj", "color": Color(0.29, 0.16, 0.09), "vertex_color": true}],
	},
	"goku": {
		"height": 1.75,
		"parts": [{"path": "res://assets/models/goku/source/goku.obj"}],
	},
	# Body (model_2) is 1.55 m to the neck; the head (model_0) and ears (model_1)
	# sit on top, so the full figure is about 1.85 m.
	"male_base": {
		"height": 1.55,
		"parts": [
			{"path": "res://assets/models/base_male/model_2.obj", "texture": MALE_SKIN},
			{"path": "res://assets/models/base_male/model_0.obj", "texture": MALE_SKIN, "role": "head"},
			{"path": "res://assets/models/base_male/model_1.obj", "texture": MALE_SKIN, "role": "ears"},
		],
	},
}

## `tint` multiplies each overridden material (Goku's own materials ignore it).
static func make(key: String, tint: Color = Color.WHITE) -> Node3D:
	var info: Dictionary = MODELS[key]
	var meshes: Array[Mesh] = []
	for i in info["parts"].size():
		meshes.append(load(info["parts"][i]["path"]))
	# The first part is the body: it alone sets the height and centre, so hair and
	# accessories sit on top of a body of the stated height (matches landmarks.json).
	var bounds := meshes[0].get_aabb()

	var s: float = info["height"] / bounds.size.y
	var wrapper := Node3D.new()
	var rig := Node3D.new()
	rig.scale = Vector3.ONE * s
	rig.position = Vector3(
		-(bounds.position.x + bounds.size.x * 0.5) * s,
		-bounds.position.y * s,
		-(bounds.position.z + bounds.size.z * 0.5) * s)
	wrapper.add_child(rig)

	var mats: Array = []
	for i in meshes.size():
		var part: Dictionary = info["parts"][i]
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[i]
		mi.name = part.get("role", "part%d" % i)
		if part.has("texture") or part.has("color"):
			var m := StandardMaterial3D.new()
			m.roughness = 0.8
			m.vertex_color_use_as_albedo = part.get("vertex_color", false)
			if part.has("texture"):
				m.albedo_texture = load(part["texture"])
			var base: Color = part.get("color", Color.WHITE)
			m.albedo_color = base * tint
			m.set_meta("base_color", m.albedo_color)
			mi.material_override = m
			mats.append(m)
		rig.add_child(mi)
	wrapper.set_meta("mats", mats)
	wrapper.set_meta("model_key", key)
	wrapper.set_meta("height", float(info["height"]))
	return wrapper

## A flat, self-lit silhouette of a character (used for Yamoshi's light).
static func make_glowing(key: String, color: Color) -> Node3D:
	var w := make(key)
	for mi in w.get_child(0).get_children():
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		(mi as MeshInstance3D).material_override = m
	return w

static func glow_sphere(radius: float, color: Color) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = Color(color.r, color.g, color.b)
	m.emission_energy_multiplier = 0.8
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	mi.material_override = m
	return mi
