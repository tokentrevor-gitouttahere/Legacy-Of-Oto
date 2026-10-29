extends Node3D
## The overworld: a large, low-detail continent generated from levels/world.json.
## Oto flies over it; near a location, E lands there. Tab opens the map.
## Terrain, biomes, forests and city silhouettes are generated from noise with
## the world.json seed, so the map is the same every run.

const RES := 161  # height samples per side
const CRUISE := 90.0
const BOOST := 230.0
const FLY_HEIGHT := 45.0
const LAND_RANGE := 110.0

var world := {}
var size := 3000.0
var heights := PackedFloat32Array()
var colors := PackedColorArray()
var locations: Array = []
var flyer: Node3D
var cam: Camera3D
var vel := Vector3.ZERO
var _near := {}
var _map: Control
var _noise := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _forest := FastNoiseLite.new()

func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://levels/world.json"))
	world = parsed if parsed is Dictionary else {}
	size = float(world.get("size", 3000))
	locations = world.get("locations", [])
	_noise.seed = int(world.get("seed", 21))
	_noise.frequency = 0.0009
	_noise.fractal_octaves = 4
	_detail.seed = _noise.seed + 1
	_detail.frequency = 0.006
	_forest.seed = _noise.seed + 2
	_forest.frequency = 0.004
	Skies.apply(self, "world")
	_generate()
	_build_terrain()
	_build_ocean()
	_build_forests()
	_build_locations()
	_build_clouds()
	_spawn_flyer()
	_build_map_ui()
	GameState.menu_enabled = true
	GameState.input_locked = false
	Overlay.hint("Arrows/WASD: fly   Hold X: boost   E: land   Tab: map   Enter: menu")
	Overlay.fade_from(0.6)
	Overlay.toast("World Map", 1.5)

# --- terrain ------------------------------------------------------------------

func _loc_pos(loc: Dictionary) -> Vector2:
	var p: Array = loc["pos"]
	return Vector2(p[0], p[1])

func _raw_height(x: float, z: float) -> float:
	var d := Vector2(x, z).length() / (size * 0.5)
	var land := _noise.get_noise_2d(x, z) * 0.9 + 0.42 - d * d * 1.0 + _detail.get_noise_2d(x, z) * 0.12
	var h := land * 150.0
	if h > 30.0:
		h = 30.0 + (h - 30.0) * 2.2  # sharper highlands
	for loc in locations:
		var lp := _loc_pos(loc)
		var dist := Vector2(x, z).distance_to(lp)
		if loc.get("icon", "") in ["mountain", "peaks"]:
			var ridge := 1.0 - absf(_detail.get_noise_2d(x * 0.5, z * 0.5))
			h += maxf(0.0, 1.0 - dist / 650.0) * ridge * 260.0
		var r := 120.0 if loc.get("icon", "") != "island" else 70.0
		if dist < r * 2.2:
			var k := clampf((r * 2.2 - dist) / (r * 1.2), 0.0, 1.0)
			var flat := 14.0 if loc.get("icon", "") != "island" else 4.0
			h = lerpf(h, flat, k)
	return h

func _biome(x: float, z: float, h: float) -> Color:
	if h < 0.0:
		return Color(0.75, 0.7, 0.55)
	if h < 5.0:
		return Color(0.92, 0.85, 0.62)
	for loc in locations:
		var near := Vector2(x, z).distance_to(_loc_pos(loc)) < 480.0 + _detail.get_noise_2d(x, z) * 120.0
		if loc.get("icon", "") in ["desert", "canyon"] and near:
			return Color(0.85, 0.58, 0.35)
		if loc.get("icon", "") == "ice" and near:
			return Color(0.9, 0.95, 1.0)
	if h > 210.0:
		return Color(0.95, 0.96, 0.98)
	if h > 120.0:
		return Color(0.5, 0.46, 0.42)
	if _forest.get_noise_2d(x, z) > 0.15:
		return Color(0.18, 0.42, 0.18)
	return Color(0.38, 0.6, 0.28)

func _generate() -> void:
	heights.resize(RES * RES)
	colors.resize(RES * RES)
	for j in RES:
		for i in RES:
			var x := (float(i) / (RES - 1) - 0.5) * size
			var z := (float(j) / (RES - 1) - 0.5) * size
			var h := _raw_height(x, z)
			heights[j * RES + i] = h
			colors[j * RES + i] = _biome(x, z, h)

## Bilinear height lookup in world metres.
func height_at(x: float, z: float) -> float:
	var fx := clampf((x / size + 0.5) * (RES - 1), 0.0, RES - 1.001)
	var fz := clampf((z / size + 0.5) * (RES - 1), 0.0, RES - 1.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var a := lerpf(heights[j * RES + i], heights[j * RES + i + 1], tx)
	var b := lerpf(heights[(j + 1) * RES + i], heights[(j + 1) * RES + i + 1], tx)
	return lerpf(a, b, tz)

func biome_at(x: float, z: float) -> Color:
	var i := clampi(int(round((x / size + 0.5) * (RES - 1))), 0, RES - 1)
	var j := clampi(int(round((z / size + 0.5) * (RES - 1))), 0, RES - 1)
	return colors[j * RES + i]

func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in RES:
		for i in RES:
			var x := (float(i) / (RES - 1) - 0.5) * size
			var z := (float(j) / (RES - 1) - 0.5) * size
			st.set_color(colors[j * RES + i])
			st.set_uv(Vector2(i, j))
			st.add_vertex(Vector3(x, heights[j * RES + i], z))
	for j in RES - 1:
		for i in RES - 1:
			var a := j * RES + i
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + RES)
			st.add_index(a + 1)
			st.add_index(a + RES + 1)
			st.add_index(a + RES)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = st.commit()
	mi.material_override = Mats.get_mat(Color.WHITE, "noise", 0.02, {"vertex_color": true, "rough": 1.0})
	add_child(mi)

func _build_ocean() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(size * 4, size * 4)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = Mats.get_mat(Color(0.16, 0.4, 0.72), "water", 0.01, {"rough": 0.15})
	mi.position.y = 1.0
	add_child(mi)

func _build_forests() -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 2.0
	cone.radial_segments = 6
	cone.rings = 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = cone
	var rng := RandomNumberGenerator.new()
	rng.seed = int(world.get("seed", 21)) + 5
	var xforms: Array[Transform3D] = []
	var cols: Array[Color] = []
	for n in 9000:
		var x := rng.randf_range(-0.5, 0.5) * size
		var z := rng.randf_range(-0.5, 0.5) * size
		var h := height_at(x, z)
		if h < 6.0 or h > 160.0 or _forest.get_noise_2d(x, z) < 0.1:
			continue
		if biome_at(x, z).r > 0.6:
			continue  # desert
		var s := rng.randf_range(5.0, 11.0)
		xforms.append(Transform3D(Basis().scaled(Vector3(s, s * 1.6, s)), Vector3(x, h + s * 1.5, z)))
		cols.append(Color(0.1, rng.randf_range(0.28, 0.4), 0.12))
	mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])
		mm.set_instance_color(k, cols[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Mats.get_mat(Color.WHITE, "", 1.0, {"vertex_color": true})
	add_child(mmi)

func _build_locations() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for loc in locations:
		var lp := _loc_pos(loc)
		var ground := maxf(height_at(lp.x, lp.y), 2.0)
		var alt: float = loc.get("altitude", 0.0)
		var base := Vector3(lp.x, ground + alt, lp.y)
		var color: Color = Level._color(loc.get("color", [1, 1, 1]))
		var beam := Props.make("portal_light", {"color": color, "h": 320.0})
		beam.position = Vector3(lp.x, ground, lp.y)
		add_child(beam)
		var label := Label3D.new()
		label.text = loc["name"]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.font_size = 96
		label.pixel_size = 0.35
		label.outline_size = 24
		label.modulate = color.lightened(0.4)
		label.position = base + Vector3(0, 90, 0)
		add_child(label)
		match loc.get("icon", ""):
			"city":
				for k in 40:
					var a := rng.randf() * TAU
					var r := sqrt(rng.randf()) * 110.0
					var w := rng.randf_range(10, 22)
					var tower := Props.make("office_tower" if k % 3 else "round_tower", {"w": w, "d": w, "r": w * 0.5, "h": rng.randf_range(12, 60), "color": Color.from_hsv(rng.randf(), 0.15, 0.95)})
					tower.position = base + Vector3(cos(a) * r, 0, sin(a) * r)
					add_child(tower)
				if loc["id"] == "west_city":
					var cc := Props.make("capsule_corp")
					cc.scale = Vector3.ONE * 2.0
					cc.position = base
					add_child(cc)
				if loc["id"] == "hercule_city":
					var st := Props.make("hercule_statue")
					st.scale = Vector3.ONE * 4.0
					st.position = base
					add_child(st)
			"island":
				var kh := Props.make("kame_house")
				kh.scale = Vector3.ONE * 4.0
				kh.position = base
				add_child(kh)
			"tower":
				var kt := Props.make("korin_tower", {"h": 240.0})
				kt.scale = Vector3.ONE * 2.5
				kt.position = base
				add_child(kt)
			"lookout":
				var lo := Props.make("lookout", {"y": 0.0})
				lo.scale = Vector3.ONE * 3.0
				lo.position = base
				add_child(lo)
			"mountain":
				var gh := Props.make("goku_house")
				gh.scale = Vector3.ONE * 3.0
				gh.position = base
				add_child(gh)
			"canyon":
				for k in 7:
					var m := Props.make("mesa", {"r": rng.randf_range(10, 22), "h": rng.randf_range(25, 55)})
					m.position = base + Vector3(cos(k * 0.9) * 90.0, 0, sin(k * 0.9) * 90.0)
					add_child(m)
			"peaks":
				for k in 5:
					var c := Props.make("crag", {"size": rng.randf_range(10, 16)})
					c.position = base + Vector3(cos(k * 1.3) * 60.0, 0, sin(k * 1.3) * 60.0)
					add_child(c)
			"ice":
				for k in 6:
					var sp := Props.make("ice_spike", {"size": rng.randf_range(8, 14)})
					sp.position = base + Vector3(cos(k * 1.05) * 70.0, 0, sin(k * 1.05) * 70.0)
					add_child(sp)
			"cave":
				var mouth := Props.make("cave_mouth")
				mouth.scale = Vector3.ONE * 8.0
				mouth.position = base
				add_child(mouth)
			"desert":
				for k in 3:
					var pod := Props.make("crater", {"r": 6.0})
					pod.position = base + Vector3(k * 25.0 - 25.0, 0.2, 10.0)
					add_child(pod)

func _build_clouds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var m := Mats.get_mat(Color(1, 1, 1), "", 1.0, {"alpha": 0.8})
	for k in 70:
		var c := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = rng.randf_range(30, 80)
		sm.height = sm.radius * 2.0
		c.mesh = sm
		c.material_override = m
		c.scale = Vector3(1.8, 0.35, 1.2)
		c.position = Vector3(rng.randf_range(-0.6, 0.6) * size, rng.randf_range(230, 330), rng.randf_range(-0.6, 0.6) * size)
		add_child(c)

# --- flight -------------------------------------------------------------------

func _spawn_flyer() -> void:
	flyer = Node3D.new()
	var body := ModelLoader.make("oto")
	Outfits.apply(body, "oto")
	body.scale = Vector3.ONE * 6.0
	body.rotation.x = 1.25  # flying pose: the T-pose reads as arms out
	body.position.y = 4.0
	flyer.add_child(body)
	var aura := ModelLoader.glow_sphere(5.0, Color(0.6, 0.5, 0.9, 0.25))
	aura.position.y = 5.0
	flyer.add_child(aura)
	add_child(flyer)
	var start := Vector2(-850, 300)
	for loc in locations:
		if loc["id"] == GameState.world_from:
			start = _loc_pos(loc) + Vector2(0, 160)
	flyer.position = Vector3(start.x, height_at(start.x, start.y) + FLY_HEIGHT, start.y)
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.far = 6000.0
	cam.rotation_degrees = Vector3(-50, 0, 0)
	add_child(cam)
	cam.current = true
	cam.position = flyer.position + _cam_offset()

func _cam_offset() -> Vector3:
	return Vector3(0, 170, 140) * (0.5 if Controls.zoom else (2.5 if Controls.far else 1.0))

func _process(delta: float) -> void:
	if _map.visible and Input.is_action_just_pressed("map"):
		_map.visible = false
		Overlay.show_hint(true)
	elif not _map.visible and Input.is_action_just_pressed("map") and not GameState.input_locked:
		_map.visible = true
		Overlay.show_hint(false)  # the map shows its own landing line and keys
	if _map.visible:
		_map.queue_redraw()
	var in_dir := Vector2.ZERO
	if not GameState.input_locked:
		in_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var boost := not GameState.input_locked and Input.is_action_pressed("special")
	var target := Vector3(in_dir.x, 0, in_dir.y) * (BOOST if boost else CRUISE)
	vel = vel.lerp(target, minf(3.0 * delta, 1.0))
	var p := flyer.position + vel * delta
	var half := size * 0.5 - 50.0
	p.x = clampf(p.x, -half, half)
	p.z = clampf(p.z, -half, half)
	var want_y := maxf(height_at(p.x, p.z), 1.0) + FLY_HEIGHT
	p.y = lerpf(flyer.position.y, want_y, minf(2.5 * delta, 1.0))
	flyer.position = p
	if vel.length() > 2.0:
		flyer.rotation.y = lerp_angle(flyer.rotation.y, atan2(vel.x, vel.z), 6.0 * delta)
	cam.position = cam.position.lerp(flyer.position + _cam_offset(), minf(4.0 * delta, 1.0))
	_update_landing()

func _update_landing() -> void:
	_near = {}
	var best := LAND_RANGE
	for loc in locations:
		var d := Vector2(flyer.position.x, flyer.position.z).distance_to(_loc_pos(loc))
		if d < best:
			best = d
			_near = loc
	if GameState.input_locked:
		return
	Overlay.set_prompt("E: Land at %s" % _near["name"] if not _near.is_empty() else "")
	if not _near.is_empty() and Input.is_action_just_pressed("interact"):
		Overlay.set_prompt("")
		GameState.travel(_near["id"], "default")

# --- map overlay --------------------------------------------------------------

## The Tab map: the terrain as a hill-shaded chart (deeper sea darker, coasts inked) in a
## UiKit frame, an icon for each kind of place, the landing in reach picked out in gold, and
## Oto's heading.
func _build_map_ui() -> void:
	var img := Image.create(RES, RES, false, Image.FORMAT_RGB8)
	for j in RES:
		for i in RES:
			var h := heights[j * RES + i]
			var c := colors[j * RES + i]
			if h < 1.0:
				c = Color(0.22, 0.5, 0.74).lerp(Color(0.06, 0.18, 0.4), clampf(-h / 45.0, 0.0, 1.0))
			else:
				# light from the north-west: slopes facing it brighter, the far side darker
				var hx := heights[j * RES + mini(i + 1, RES - 1)] - heights[j * RES + maxi(i - 1, 0)]
				var hz := heights[mini(j + 1, RES - 1) * RES + i] - heights[maxi(j - 1, 0) * RES + i]
				c = c * clampf(1.0 - (hx + hz) * 0.006, 0.7, 1.25)
				var coast := false
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var ni := clampi(i + d.x, 0, RES - 1)
					var nj := clampi(j + d.y, 0, RES - 1)
					coast = coast or heights[nj * RES + ni] < 1.0
				if coast:
					c = c.darkened(0.35)
			img.set_pixel(i, j, c)
	var tex := ImageTexture.create_from_image(img)
	var layer := CanvasLayer.new()
	layer.layer = 80
	add_child(layer)
	_map = MapView.new()
	_map.owner_map = self
	_map.tex = tex
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map.visible = false
	layer.add_child(_map)

class MapView extends Control:
	var owner_map: Node
	var tex: Texture2D

	func _draw() -> void:
		var vs := get_viewport_rect().size
		var t := Time.get_ticks_msec() / 1000.0
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.01, 0.05, 0.78))
		var side := minf(vs.x * 0.62, vs.y - 236.0)
		var origin := Vector2((vs.x - side) * 0.5, 92.0)
		var frame := Rect2(origin - Vector2(18, 18), Vector2(side, side) + Vector2(36, 36))
		UiKit.frame(self, frame, UiKit.GOLD, true, 14.0)
		draw_texture_rect(tex, Rect2(origin, Vector2(side, side)), false)
		draw_rect(Rect2(origin, Vector2(side, side)), Color(0, 0, 0, 0.5), false, 2.0)
		# the title, between rules
		var tf := UiKit.spaced(UiKit.display_font(true), 4)
		UiKit.text(self, tf, Vector2(0, 58), "THE WORLD", 34, UiKit.GOLD_PALE, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 5)
		UiKit.rule(self, Vector2(vs.x * 0.5 - 260, 46), Vector2(vs.x * 0.5 - 120, 46), UiKit.GOLD, false)
		UiKit.rule(self, Vector2(vs.x * 0.5 + 120, 46), Vector2(vs.x * 0.5 + 260, 46), UiKit.GOLD, false)
		_compass(origin + Vector2(side - 46, 46))
		var s: float = owner_map.size
		var near: Dictionary = owner_map._near
		var placed: Array[Rect2] = []
		var font := UiKit.body_font()
		var locs: Array = owner_map.locations.duplicate()
		locs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["pos"][1] < b["pos"][1])
		for loc: Dictionary in locs:
			var p: Vector2 = owner_map._loc_pos(loc)
			var sp := origin + (p / s + Vector2(0.5, 0.5)) * side
			var col: Color = Level._color(loc.get("color", [1, 1, 1]))
			var is_near: bool = not near.is_empty() and near.get("id", "") == loc["id"]
			if is_near:
				var pulse := 0.5 + 0.5 * sin(t * 5.0)
				draw_arc(sp, 15.0 + pulse * 4.0, 0.0, TAU, 32, Color(UiKit.GOLD.r, UiKit.GOLD.g, UiKit.GOLD.b, 0.9), 2.5, true)
			_marker(sp, str(loc.get("icon", "")), col)
			# the name to the right, nudged down past any label it would overlap
			var fs := 17 if not is_near else 19
			var w := font.get_string_size(loc["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var lr := Rect2(sp + Vector2(14, -12), Vector2(w, 18))
			for _i in 4:
				var hit := false
				for o: Rect2 in placed:
					if o.intersects(lr):
						hit = true
				if not hit:
					break
				lr.position.y += 18.0
			placed.append(lr)
			UiKit.text(self, font, lr.position + Vector2(0, 15), loc["name"], fs, UiKit.GOLD_PALE if is_near else UiKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, 5)
		# Oto: a gem pointing the way she flies
		var fp: Vector3 = owner_map.flyer.position
		var pp := origin + (Vector2(fp.x, fp.z) / s + Vector2(0.5, 0.5)) * side
		var v: Vector3 = owner_map.vel
		var ang: float = atan2(v.x, -v.z) if v.length() > 2.0 else owner_map.flyer.rotation.y * -1.0 + PI
		var fwd := Vector2(sin(ang), -cos(ang))
		var rt := Vector2(-fwd.y, fwd.x)
		draw_circle(pp, 13.0, Color(0.4, 0.25, 0.75, 0.35))
		var arrow := PackedVector2Array([pp + fwd * 12.0, pp + rt * 7.0 - fwd * 6.0, pp - fwd * 2.0, pp - rt * 7.0 - fwd * 6.0])
		draw_colored_polygon(arrow, UiKit.VIOLET.lightened(0.3))
		draw_polyline(UiKit.closed(arrow), UiKit.INK, 1.5, true)
		# the landing in reach, and the keys
		var by := origin.y + side + 52.0
		if not near.is_empty():
			UiKit.text(self, UiKit.display_font(true), Vector2(0, by), "Over %s" % near["name"], 24, UiKit.GOLD_PALE, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 4)
			UiKit.key_row(self, Vector2(vs.x * 0.5 - 120, by + 32), [["E", "Land"], ["Tab", "Close map"]])
		else:
			UiKit.text(self, UiKit.body_font(true), Vector2(0, by), "Fly over a beam of light to land.", 18, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 4)
			UiKit.key_row(self, Vector2(vs.x * 0.5 - 60, by + 32), [["Tab", "Close map"]])

	## A small icon for each kind of place, on a dark gem in the place's colour.
	func _marker(c: Vector2, icon: String, col: Color) -> void:
		UiKit.diamond(self, c, 11.0, UiKit.INK)
		draw_polyline(UiKit.closed(PackedVector2Array([c + Vector2(0, -11), c + Vector2(11, 0), c + Vector2(0, 11), c + Vector2(-11, 0)])), col, 1.5, true)
		var ink := col.lightened(0.25)
		match icon:
			"city":
				draw_rect(Rect2(c + Vector2(-5, -2), Vector2(3, 6)), ink)
				draw_rect(Rect2(c + Vector2(-1, -6), Vector2(3, 10)), ink)
				draw_rect(Rect2(c + Vector2(3, -3), Vector2(3, 7)), ink)
			"mountain", "peaks":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 4), c + Vector2(-1, -5), c + Vector2(2, 0), c + Vector2(4, -3), c + Vector2(7, 4)]), ink)
			"island":
				draw_circle(c + Vector2(0, 2), 4.0, ink)
				draw_line(c + Vector2(0, 1), c + Vector2(2, -6), ink, 1.5)
			"desert", "canyon":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 4), c + Vector2(-4, -3), c + Vector2(4, -3), c + Vector2(6, 4)]), ink)
			"tower":
				draw_rect(Rect2(c + Vector2(-1.5, -7), Vector2(3, 12)), ink)
			"lookout":
				draw_rect(Rect2(c + Vector2(-6, -2), Vector2(12, 3)), ink)
				draw_line(c + Vector2(0, 1), c + Vector2(0, 5), ink, 1.5)
			"ice":
				for k in 3:
					var a := k * PI / 3.0
					draw_line(c - Vector2(cos(a), sin(a)) * 6.0, c + Vector2(cos(a), sin(a)) * 6.0, ink, 1.5)
			"cave":
				draw_arc(c + Vector2(0, 3), 5.5, PI, TAU, 12, ink, 2.0, true)
				draw_rect(Rect2(c + Vector2(-2.5, -0.5), Vector2(5, 3.5)), UiKit.INK)
			_:
				draw_circle(c, 3.5, ink)

	func _compass(c: Vector2) -> void:
		draw_circle(c, 24.0, Color(0.02, 0.015, 0.04, 0.7))
		draw_arc(c, 24.0, 0.0, TAU, 32, UiKit.GOLD_DIM, 1.5, true)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -20), c + Vector2(5, 0), c + Vector2(0, 4), c + Vector2(-5, 0)]), UiKit.GOLD)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, 20), c + Vector2(5, 0), c + Vector2(0, -4), c + Vector2(-5, 0)]), UiKit.FAINT)
		UiKit.text(self, UiKit.display_font(true), c + Vector2(-6, -26), "N", 16, UiKit.GOLD_PALE, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
