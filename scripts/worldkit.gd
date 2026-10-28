class_name WorldKit
extends RefCounted
## Helpers for building test levels from primitives.

static func environment(root: Node, sky_top: Color, sky_horizon: Color, ambient: Color, ambient_energy: float,
		sun_color: Color, sun_energy: float, sun_rot: Vector3) -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = sky_top
	sky_mat.sky_horizon_color = sky_horizon
	sky_mat.ground_horizon_color = sky_horizon
	sky_mat.ground_bottom_color = sky_top
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = sun_rot
	sun.light_color = sun_color
	sun.light_energy = sun_energy
	sun.shadow_enabled = true
	root.add_child(sun)

static func checker_floor(root: Node, rect: Rect2, c1: Color, c2: Color, tile := 1.0) -> MeshInstance3D:
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	img.set_pixel(0, 0, c1)
	img.set_pixel(1, 1, c1)
	img.set_pixel(1, 0, c2)
	img.set_pixel(0, 1, c2)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_scale = Vector3(rect.size.x / (2.0 * tile), rect.size.y / (2.0 * tile), 1)
	var plane := PlaneMesh.new()
	plane.size = rect.size
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	mi.position = Vector3(rect.get_center().x, 0, rect.get_center().y)
	root.add_child(mi)
	return mi

static func border(root: Node, rect: Rect2, color: Color) -> void:
	box(root, Vector3(rect.get_center().x, 0.25, rect.position.y), Vector3(rect.size.x, 0.5, 0.3), color)
	box(root, Vector3(rect.get_center().x, 0.25, rect.end.y), Vector3(rect.size.x, 0.5, 0.3), color)
	box(root, Vector3(rect.position.x, 0.25, rect.get_center().y), Vector3(0.3, 0.5, rect.size.y), color)
	box(root, Vector3(rect.end.x, 0.25, rect.get_center().y), Vector3(0.3, 0.5, rect.size.y), color)

static func _mat(color: Color, emissive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if emissive:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

static func box(root: Node, pos: Vector3, size: Vector3, color: Color, emissive := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color, emissive)
	mi.position = pos
	root.add_child(mi)
	return mi

static func cylinder(root: Node, pos: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color, false)
	mi.position = pos + Vector3(0, height * 0.5, 0)
	root.add_child(mi)
	return mi

static func ball(root: Node, pos: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color, false)
	mi.position = pos
	root.add_child(mi)
	return mi

static func tree(root: Node, pos: Vector3) -> void:
	cylinder(root, pos, 0.25, 2.0, Color(0.35, 0.22, 0.12))
	ball(root, pos + Vector3(0, 2.8, 0), 1.3, Color(0.15, 0.4, 0.15))
