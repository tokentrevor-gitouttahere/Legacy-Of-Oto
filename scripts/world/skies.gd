class_name Skies
extends RefCounted
## Lighting and sky presets. Skies.apply(root, "day") adds a WorldEnvironment
## and a sun. Interiors get warm ambient light and no visible sky.

const PRESETS := {
	"day": {"top": Color(0.25, 0.5, 0.9), "horizon": Color(0.75, 0.85, 0.95), "ambient": Color(0.75, 0.78, 0.85), "ambient_e": 0.6, "sun": Color(1, 0.97, 0.9), "sun_e": 1.2, "sun_rot": Vector3(-50, -35, 0), "fog": 0.0},
	"dusk": {"top": Color(0.25, 0.4, 0.7), "horizon": Color(0.95, 0.6, 0.4), "ambient": Color(0.75, 0.62, 0.62), "ambient_e": 0.65, "sun": Color(1, 0.75, 0.55), "sun_e": 1.0, "sun_rot": Vector3(-25, -60, 0), "fog": 0.0},
	"night": {"stars": true, "ambient": Color(0.35, 0.4, 0.6), "ambient_e": 0.5, "sun": Color(0.6, 0.7, 1.0), "sun_e": 0.35, "sun_rot": Vector3(-60, 20, 0), "fog": 0.0},
	"dark_side": {"top": Color(0.02, 0.02, 0.05), "horizon": Color(0.35, 0.28, 0.4), "ambient": Color(0.35, 0.33, 0.5), "ambient_e": 0.6, "sun": Color(0.7, 0.65, 0.85), "sun_e": 0.6, "sun_rot": Vector3(-55, 70, 0), "fog": 0.0},
	"wasteland": {"top": Color(0.4, 0.6, 0.9), "horizon": Color(0.95, 0.8, 0.6), "ambient": Color(0.85, 0.75, 0.65), "ambient_e": 0.6, "sun": Color(1, 0.92, 0.8), "sun_e": 1.3, "sun_rot": Vector3(-60, -20, 0), "fog": 0.0},
	"namek": {"top": Color(0.2, 0.6, 0.45), "horizon": Color(0.6, 0.9, 0.7), "ambient": Color(0.6, 0.8, 0.7), "ambient_e": 0.6, "sun": Color(0.9, 1.0, 0.9), "sun_e": 1.1, "sun_rot": Vector3(-45, 30, 0), "fog": 0.0},
	"sky_high": {"top": Color(0.2, 0.45, 0.95), "horizon": Color(0.95, 0.97, 1.0), "ambient": Color(0.85, 0.88, 0.95), "ambient_e": 0.7, "sun": Color(1, 1, 0.95), "sun_e": 1.3, "sun_rot": Vector3(-60, -30, 0), "fog": 0.0},
	"world": {"top": Color(0.2, 0.45, 0.9), "horizon": Color(0.8, 0.88, 0.97), "ambient": Color(0.75, 0.78, 0.85), "ambient_e": 0.6, "sun": Color(1, 0.97, 0.9), "sun_e": 1.2, "sun_rot": Vector3(-55, -35, 0), "fog": 0.00022},
	"desert": {"top": Color(0.3, 0.52, 0.88), "horizon": Color(1.0, 0.78, 0.52), "ambient": Color(0.95, 0.8, 0.65), "ambient_e": 0.62, "sun": Color(1, 0.9, 0.72), "sun_e": 1.45, "sun_rot": Vector3(-62, -15, 0), "fog": 0.0},
	"alpine": {"top": Color(0.16, 0.4, 0.88), "horizon": Color(0.82, 0.9, 1.0), "ambient": Color(0.75, 0.8, 0.92), "ambient_e": 0.62, "sun": Color(1, 0.98, 0.94), "sun_e": 1.25, "sun_rot": Vector3(-42, -40, 0), "fog": 0.0},
	"arctic": {"top": Color(0.42, 0.58, 0.85), "horizon": Color(0.93, 0.95, 1.0), "ambient": Color(0.82, 0.87, 0.97), "ambient_e": 0.72, "sun": Color(1, 0.9, 0.8), "sun_e": 1.0, "sun_rot": Vector3(-18, -50, 0), "fog": 0.0},
	"cavern": {"bg": Color(0.01, 0.01, 0.025), "ambient": Color(0.52, 0.5, 0.62), "ambient_e": 0.95, "sun": Color(0.7, 0.75, 1.0), "sun_e": 0.45, "sun_rot": Vector3(-80, 10, 0), "fog": 0.0},
	"interior": {"bg": Color(0.02, 0.02, 0.03), "ambient": Color(1.0, 0.9, 0.8), "ambient_e": 0.9, "sun": Color(1, 0.95, 0.85), "sun_e": 0.5, "sun_rot": Vector3(-70, -20, 0), "fog": 0.0},
}

static func apply(root: Node, preset: String) -> void:
	var p: Dictionary = PRESETS.get(preset, PRESETS["day"])
	var env := Environment.new()
	if p.has("bg"):
		env.background_mode = Environment.BG_COLOR
		env.background_color = p["bg"]
	else:
		var sky := Sky.new()
		if p.get("stars", false):
			var pano := PanoramaSkyMaterial.new()
			pano.panorama = Mats.stars()
			sky.sky_material = pano
		else:
			var sm := ProceduralSkyMaterial.new()
			sm.sky_top_color = p["top"]
			sm.sky_horizon_color = p["horizon"]
			sm.ground_horizon_color = p["horizon"]
			sm.ground_bottom_color = p["top"].darkened(0.3)
			sky.sky_material = sm
		env.background_mode = Environment.BG_SKY
		env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = p["ambient"]
	env.ambient_light_energy = p["ambient_e"]
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.85
	if p["fog"] > 0.0:
		env.fog_enabled = true
		env.fog_light_color = p.get("horizon", Color.WHITE)
		env.fog_density = p["fog"]
		env.fog_sky_affect = 0.3
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = p["sun_rot"]
	sun.light_color = p["sun"]
	sun.light_energy = p["sun_e"]
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	root.add_child(sun)
