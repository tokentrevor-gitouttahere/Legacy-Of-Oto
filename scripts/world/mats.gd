class_name Mats
extends RefCounted
## Cached materials and procedural textures. Everything is generated in code,
## so new looks need no image files. Textures use world triplanar mapping so
## props never need UVs: `scale` is repeats per metre.

static var _cache := {}

## Plain lit material. tex: "" or one of: noise, windows, windows_lit, bricks,
## planks, tiles, stripes, panels, roof_tiles, asphalt, grass, sand, rock, water.
static func get_mat(color: Color, tex := "", scale := 1.0, extra := {}) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s" % [color.to_html(), tex, scale, str(extra)]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = extra.get("rough", 0.85)
	m.metallic = extra.get("metal", 0.0)
	if tex != "":
		m.albedo_texture = texture(tex)
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * scale
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if extra.get("unshaded", false):
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if extra.has("emit"):
		m.emission_enabled = true
		m.emission = extra["emit"]
		m.emission_energy_multiplier = extra.get("emit_energy", 1.0)
	if extra.has("alpha"):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = extra["alpha"]
	if extra.get("vertex_color", false):
		m.vertex_color_use_as_albedo = true
	if extra.get("double", false):
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = m
	return m

static func glow(color: Color, energy := 1.5) -> StandardMaterial3D:
	return get_mat(color, "", 1.0, {"unshaded": true, "emit": color, "emit_energy": energy})

static func texture(kind: String) -> Texture2D:
	var key := "tex|" + kind
	if _cache.has(key):
		return _cache[key]
	var img: Image
	match kind:
		"noise": img = _noise_img(64, 0.75, 1.0)
		"grass": img = _noise_img(64, 0.8, 1.0)
		"sand": img = _noise_img(64, 0.88, 1.0)
		"rock": img = _strata()
		"asphalt": img = _noise_img(64, 0.85, 1.0)
		"water": img = _noise_img(64, 0.9, 1.0)
		"windows": img = _windows(false)
		"windows_lit": img = _windows(true)
		"bricks": img = _bricks()
		"planks": img = _planks()
		"tiles": img = _tiles()
		"stripes": img = _stripes()
		"panels": img = _panels()
		"roof_tiles": img = _roof_tiles()
		_: img = _noise_img(16, 1.0, 1.0)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t

static func _noise_img(size: int, lo: float, hi: float) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = size * 31 + int(lo * 100)
	for y in size:
		for x in size:
			var v := rng.randf_range(lo, hi)
			img.set_pixel(x, y, Color(v, v, v))
	return img

static func _windows(lit: bool) -> Image:
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	img.fill(Color(1, 1, 1))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for wy in 4:
		for wx in 4:
			var on := lit and rng.randf() < 0.45
			var c := Color(1.0, 0.95, 0.6) if on else Color(0.35, 0.45, 0.55)
			for y in range(wy * 8 + 2, wy * 8 + 7):
				for x in range(wx * 8 + 2, wx * 8 + 6):
					img.set_pixel(x, y, c)
	return img

static func _bricks() -> Image:
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	img.fill(Color(0.95, 0.95, 0.95))
	for row in 4:
		var off := 0 if row % 2 == 0 else 8
		for y in range(row * 8, row * 8 + 8):
			for x in 32:
				if y == row * 8 or (x + off) % 16 == 0:
					img.set_pixel(x, y, Color(0.6, 0.6, 0.6))
	return img

static func _planks() -> Image:
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for x in 32:
		var plank := x / 8
		var shade := 0.85 + 0.1 * ((plank * 37) % 3) / 2.0
		for y in 32:
			var v := shade * rng.randf_range(0.93, 1.0)
			if x % 8 == 0 or (y + plank * 11) % 32 == 0:
				v *= 0.7
			img.set_pixel(x, y, Color(v, v, v))
	return img

static func _tiles() -> Image:
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	img.fill(Color(1, 1, 1))
	for i in 32:
		for k in [0, 16]:
			img.set_pixel(i, k, Color(0.7, 0.7, 0.7))
			img.set_pixel(k, i, Color(0.7, 0.7, 0.7))
	return img

static func _stripes() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	for x in 16:
		for y in 16:
			var v := 1.0 if (x / 4) % 2 == 0 else 0.55
			img.set_pixel(x, y, Color(v, v, v))
	return img

static func _panels() -> Image:
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	img.fill(Color(1, 1, 1))
	for i in 32:
		img.set_pixel(i, 0, Color(0.75, 0.75, 0.78))
		img.set_pixel(0, i, Color(0.75, 0.75, 0.78))
		img.set_pixel(i, 16, Color(0.85, 0.85, 0.88))
	return img

static func _roof_tiles() -> Image:
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	for y in 32:
		for x in 32:
			var off := 0 if (y / 6) % 2 == 0 else 4
			var v := 1.0 if (x + off) % 8 != 0 and y % 6 != 0 else 0.65
			v *= 1.0 - 0.15 * float(y % 6) / 6.0
			img.set_pixel(x, y, Color(v, v, v))
	return img

static func _strata() -> Image:
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for y in 32:
		var band := 0.8 + 0.2 * sin(y * 0.9)
		for x in 32:
			var v := band * rng.randf_range(0.9, 1.0)
			img.set_pixel(x, y, Color(v, v, v))
	return img

## Starfield panorama for night skies.
static func stars() -> Texture2D:
	if _cache.has("stars"):
		return _cache["stars"]
	var img := Image.create(1024, 512, false, Image.FORMAT_RGB8)
	img.fill(Color(0.01, 0.01, 0.04))
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 1400:
		var v := rng.randf_range(0.4, 1.0)
		img.set_pixel(rng.randi_range(0, 1023), rng.randi_range(0, 300), Color(v, v, v * 1.05))
	var t := ImageTexture.create_from_image(img)
	_cache["stars"] = t
	return t
