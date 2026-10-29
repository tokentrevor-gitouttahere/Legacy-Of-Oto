class_name Level
extends Node3D
## A location built from a tile map in res://levels/<id>.json. See
## docs/LEVEL_FORMAT.md for the format. Level.load_level("west_city") returns
## a built Level; it answers is_blocked(pos), spawn_point(name), exit_at(pos).

const GROUND := {
	"grass": Color(0.3, 0.55, 0.25), "dirt": Color(0.55, 0.42, 0.28), "sand": Color(0.9, 0.82, 0.6),
	"rock": Color(0.55, 0.5, 0.45), "wasteland": Color(0.78, 0.55, 0.35), "road": Color(0.22, 0.22, 0.24),
	"pavement": Color(0.58, 0.58, 0.57), "plaza": Color(0.72, 0.69, 0.62), "wood": Color(0.62, 0.44, 0.27),
	"tile": Color(0.9, 0.9, 0.88), "carpet": Color(0.55, 0.22, 0.22), "water": Color(0.2, 0.45, 0.8),
	"snow": Color(0.93, 0.95, 0.98), "metal": Color(0.75, 0.78, 0.82), "cloud": Color(0.97, 0.97, 1.0),
	# regions: canyon floors, scree, sea ice, cave rock and the deep cave lake
	"sandstone": Color(0.82, 0.52, 0.32), "gravel": Color(0.5, 0.48, 0.46), "ice": Color(0.74, 0.87, 0.95),
	"cave": Color(0.4, 0.34, 0.32), "deep": Color(0.01, 0.04, 0.1),
}

## Default legend. Levels may add or override characters in "legend".
## "$base" = the level's base ground, "$floor" = its floor (interiors).
const TILES := {
	" ": {"void": true, "block": true},
	".": {"ground": "grass"}, ",": {"ground": "dirt"}, ":": {"ground": "sand"}, ";": {"ground": "rock"},
	"o": {"ground": "wasteland"}, "s": {"ground": "snow"}, "m": {"ground": "metal"}, "c": {"ground": "cloud"},
	"~": {"ground": "water", "block": true},
	"=": {"ground": "road"}, "_": {"ground": "pavement"}, "+": {"ground": "plaza"},
	"W": {"ground": "wood"}, "F": {"ground": "tile"}, "C": {"ground": "carpet"},
	"#": {"ground": "$floor", "wall": true, "block": true},
	"B": {"ground": "pavement", "building": true, "block": true},
	"T": {"ground": "$base", "prop": "tree_oak", "block": true, "jitter": true},
	"P": {"ground": "$base", "prop": "tree_pine", "block": true, "jitter": true},
	"Y": {"ground": "sand", "prop": "tree_palm", "block": true, "jitter": true},
	"b": {"ground": "$base", "prop": "bush", "jitter": true},
	"r": {"ground": "$base", "prop": "rock", "block": true, "jitter": true},
	"M": {"ground": "wasteland", "prop": "mesa", "params": {"r": 1.8, "h": 8.0}, "block": true, "jitter": true},
	"L": {"ground": "pavement", "prop": "lamp_post"},
	"D": {"ground": "$floor", "door": true},
	"@": {"ground": "$base", "spawn": true},
	# region kit (docs/REGIONS.md): cliffs and canyon walls, desert, ice, caves
	"K": {"ground": "$base", "prop": "cliff", "block": true, "jitter": true},
	"n": {"ground": "sandstone"}, "q": {"ground": "gravel"}, "i": {"ground": "ice"}, "v": {"ground": "cave"},
	"w": {"ground": "deep", "block": true},
	"k": {"ground": "sand", "prop": "cactus", "block": true, "jitter": true},
	"h": {"ground": "sandstone", "prop": "hoodoo", "block": true, "jitter": true},
	"I": {"ground": "ice", "prop": "ice_spike", "block": true, "jitter": true},
	"g": {"ground": "snow", "prop": "snow_pine", "block": true, "jitter": true},
	"d": {"ground": "snow", "prop": "snow_drift", "jitter": true},
	"V": {"ground": "cave", "prop": "cave_column", "block": true, "jitter": true},
	"X": {"ground": "cave", "prop": "crystal_cluster", "params": {"light": false}, "block": true, "jitter": true},
	"u": {"ground": "cave", "prop": "glow_mushroom", "jitter": true},
	"Z": {"ground": "cave", "prop": "stalagmite", "block": true, "jitter": true},
}

const BUILDING_STYLES := ["west", "modern", "village"]

var id := ""
var data := {}
var tile := 2.0
var cols := 0
var rows := 0
var grid: PackedStringArray
var blocked := PackedByteArray()
var tiles := {}
var exits_by_cell := {}
var spawns := {}
var rect := Rect2()
var npcs: Array = []
var enemy_specs: Array = []
var pickup_specs: Array = []
## Interactive props for Fixture: {type, spec, node, cells, index}.
var fixtures: Array = []
var _rng := RandomNumberGenerator.new()

static func load_data(level_id: String) -> Dictionary:
	var path := "res://levels/%s.json" % level_id
	if not FileAccess.file_exists(path):
		push_error("Level not found: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Level JSON did not parse: " + path)
		return {}
	return parsed

static func load_level(level_id: String) -> Level:
	var lv := Level.new()
	lv.id = level_id
	lv.setup(load_data(level_id))
	return lv

func setup(d: Dictionary) -> void:
	data = d
	name = "Level_" + id
	tile = float(d.get("tile", 2.0))
	grid = PackedStringArray(d.get("grid", ["@"]))
	rows = grid.size()
	for row in grid:
		cols = maxi(cols, row.length())
	rect = Rect2(0, 0, cols * tile, rows * tile)
	tiles = TILES.duplicate(true)
	var legend: Dictionary = d.get("legend", {})
	for k in legend:
		tiles[k] = legend[k]
	blocked.resize(cols * rows)
	_rng.seed = int(d.get("seed", hash(id)))
	_build_ground()
	_build_cells()
	_build_buildings()
	_build_props()
	_build_backdrop()
	npcs = d.get("npcs", [])
	enemy_specs = d.get("enemies", [])
	pickup_specs = d.get("pickups", [])
	for k in d.get("spawns", {}):
		var at: Array = d["spawns"][k]
		spawns[k] = cell_pos(at[0], at[1])

# --- queries ---------------------------------------------------------------

func ch(c: int, r: int) -> String:
	if r < 0 or r >= rows or c < 0 or c >= grid[r].length():
		return " "
	return grid[r][c]

func tile_def(c: int, r: int) -> Dictionary:
	var k := ch(c, r)
	if tiles.has(k):
		return tiles[k]
	return {"ground": "$base"}  # unknown characters are plain ground

func cell_of(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / tile), floori(pos.z / tile))

## World position of a cell centre; fractional cells are allowed.
func cell_pos(c: float, r: float) -> Vector3:
	return Vector3((c + 0.5) * tile, 0, (r + 0.5) * tile)

func is_blocked(pos: Vector3) -> bool:
	var c := cell_of(pos)
	if c.x < 0 or c.y < 0 or c.x >= cols or c.y >= rows:
		return true
	return blocked[c.y * cols + c.x] == 1

func spawn_point(spawn_name: String) -> Vector3:
	if spawns.has(spawn_name):
		return spawns[spawn_name]
	if spawns.has("default"):
		return spawns["default"]
	return Vector3(rect.get_center().x, 0, rect.get_center().y)

func exit_at(pos: Vector3) -> Dictionary:
	return exits_by_cell.get(cell_of(pos), {})

func is_interior() -> bool:
	return data.get("interior", false)

func _ground_name(def: Dictionary) -> String:
	var g: String = def.get("ground", "$base")
	if g == "$base":
		g = data.get("base", data.get("floor", "grass"))
	if g == "$floor":
		g = data.get("floor", data.get("base", "grass"))
	return g

func _block_cell(c: int, r: int) -> void:
	if c >= 0 and r >= 0 and c < cols and r < rows:
		blocked[r * cols + c] = 1

## Fixtures open and close cells at runtime (gates, doors, bridges, rocks).
func set_cells_blocked(cells: Array, on: bool) -> void:
	for cell: Vector2i in cells:
		blocked[cell.y * cols + cell.x] = 1 if on else 0

## Cells whose centres lie within `half` (metres) of `center`.
func cells_under(center: Vector3, half: Vector2) -> Array:
	var out: Array = []
	if half == Vector2.ZERO:
		return out
	for r in range(maxi(floori((center.z - half.y) / tile), 0), mini(ceili((center.z + half.y) / tile) + 1, rows)):
		for c in range(maxi(floori((center.x - half.x) / tile), 0), mini(ceili((center.x + half.x) / tile) + 1, cols)):
			var cp := cell_pos(c, r)
			if absf(cp.x - center.x) < half.x and absf(cp.z - center.z) < half.y:
				out.append(Vector2i(c, r))
	return out

# --- building --------------------------------------------------------------

func _build_ground() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var wet := SurfaceTool.new()  # water and the deep lake: their own glossy surface
	wet.begin(Mesh.PRIMITIVE_TRIANGLES)
	wet.set_normal(Vector3.UP)
	var any_wet := false
	for r in rows:
		for c in cols:
			var def := tile_def(c, r)
			if def.get("void", false):
				continue
			var base: Color = GROUND.get(_ground_name(def), Color.MAGENTA)
			var j := 0.04 * (float(hash(Vector2i(c, r)) % 100) / 100.0 - 0.5)
			var col := Color(base.r + j, base.g + j, base.b + j)
			var y := -0.08 if _ground_name(def) in ["water", "deep"] else 0.0
			var x0 := c * tile
			var z0 := r * tile
			var quad := [Vector3(x0, y, z0), Vector3(x0 + tile, y, z0), Vector3(x0 + tile, y, z0 + tile), Vector3(x0, y, z0 + tile)]
			var target := wet if y < 0.0 else st
			any_wet = any_wet or y < 0.0
			for i in [0, 1, 2, 0, 2, 3]:
				target.set_color(col)
				target.add_vertex(quad[i])
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = st.commit()
	mi.material_override = Mats.get_mat(Color.WHITE, "noise", 0.5, {"vertex_color": true})
	add_child(mi)
	if any_wet:
		var wi := MeshInstance3D.new()
		wi.name = "Water"
		wi.mesh = wet.commit()
		wi.material_override = Mats.get_mat(Color.WHITE, "noise", 0.15, {"vertex_color": true, "rough": 0.06, "metal": 0.35})
		add_child(wi)

func _build_cells() -> void:
	var wall_h: float = data.get("wall_height", 3.0)
	var wall_m := Mats.get_mat(_color(data.get("wall_color", [0.92, 0.88, 0.8])), data.get("wall_tex", "panels"), 0.5)
	var walls := Node3D.new()
	walls.name = "Walls"
	add_child(walls)
	for r in rows:
		for c in cols:
			var key := ch(c, r)
			var def := tile_def(c, r)
			if def.get("block", false):
				_block_cell(c, r)
			var center := cell_pos(c, r)
			if def.get("wall", false):
				# Cutaway: walls with nothing walkable to their south are drawn low so
				# the camera can see into rooms.
				var low: bool = is_interior() and tile_def(c, r + 1).get("void", false)
				var h := 0.4 if low else wall_h
				var mesh := BoxMesh.new()
				mesh.size = Vector3(tile, h, tile)
				var mi := MeshInstance3D.new()
				mi.mesh = mesh
				mi.material_override = wall_m
				mi.position = center + Vector3(0, h / 2.0, 0)
				walls.add_child(mi)
			if def.has("prop"):
				var params: Dictionary = _params(def.get("params", {}))
				if def.get("jitter", false):
					params["size"] = _rng.randf_range(0.8, 1.2) * float(params.get("size", 1.0))
				var p := Props.make(def["prop"], params)
				p.position = center
				if def.get("jitter", false):
					p.rotation.y = _rng.randf() * TAU
					p.position += Vector3(_rng.randf_range(-0.2, 0.2), 0, _rng.randf_range(-0.2, 0.2)) * tile
				add_child(p)
			if def.get("spawn", false):
				spawns["default"] = center
			if key.is_valid_int():
				var ex: Dictionary = data.get("exits", {}).get(key, {})
				exits_by_cell[Vector2i(c, r)] = ex
				if not ex.get("hidden", false):
					var m := Props.make("exit_marker")
					m.position = center
					add_child(m)
			if def.get("door", false):
				var frame := Props.make("exit_marker", {"color": Color(1.0, 0.85, 0.5)})
				frame.position = center
				add_child(frame)

func _build_buildings() -> void:
	var style: String = data.get("city_style", "west")
	var seen := {}
	var index := 0
	for r in rows:
		for c in cols:
			if seen.has(Vector2i(c, r)) or not tile_def(c, r).get("building", false):
				continue
			# Flood-fill this block of building cells.
			var queue := [Vector2i(c, r)]
			seen[Vector2i(c, r)] = true
			var lo := Vector2i(c, r)
			var hi := Vector2i(c, r)
			while not queue.is_empty():
				var cell: Vector2i = queue.pop_back()
				lo = Vector2i(mini(lo.x, cell.x), mini(lo.y, cell.y))
				hi = Vector2i(maxi(hi.x, cell.x), maxi(hi.y, cell.y))
				for dlt in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nb: Vector2i = cell + dlt
					if not seen.has(nb) and tile_def(nb.x, nb.y).get("building", false):
						seen[nb] = true
						queue.append(nb)
			_place_building(style, lo, hi, index)
			index += 1

func _place_building(style: String, lo: Vector2i, hi: Vector2i, index: int) -> void:
	var w := (hi.x - lo.x + 1) * tile
	var d := (hi.y - lo.y + 1) * tile
	var center := cell_pos((lo.x + hi.x) / 2.0, (lo.y + hi.y) / 2.0)
	var small := minf(w, d)
	var rng := RandomNumberGenerator.new()
	rng.seed = _rng.seed + index * 7919
	var pastel := Color.from_hsv(rng.randf(), rng.randf_range(0.1, 0.3), rng.randf_range(0.85, 0.98))
	var p: Node3D
	var roll := rng.randf()
	match style:
		"village":
			if roll < 0.75:
				p = Props.make("dome_house", {"r": minf(small * 0.45, 4.0), "color": Color.from_hsv(rng.randf_range(0.0, 0.1), 0.6, 0.85)})
			else:
				p = Props.make("hut")
		"modern":
			if roll < 0.6:
				p = Props.make("office_tower", {"w": w * 0.9, "d": d * 0.9, "h": rng.randf_range(12, 40), "color": pastel})
			else:
				p = Props.make("apartment", {"w": w * 0.9, "d": d * 0.9, "h": rng.randf_range(9, 18), "color": pastel})
		_:
			if roll < 0.4 and small >= 6.0:
				p = Props.make("dome_building", {"r": small * 0.45, "h": rng.randf_range(3, 8), "color": pastel})
			elif roll < 0.7:
				p = Props.make("round_tower", {"r": small * 0.4, "h": rng.randf_range(10, 32), "color": pastel})
			else:
				p = Props.make("office_tower", {"w": w * 0.88, "d": d * 0.88, "h": rng.randf_range(8, 26), "color": pastel})
	p.position = center
	add_child(p)

func _build_props() -> void:
	var specs: Array = data.get("props", [])
	for i in specs.size():
		var spec: Dictionary = specs[i]
		var p := Props.make(spec["type"], _params(spec.get("params", {})))
		var at: Array = spec["at"]
		p.position = cell_pos(at[0], at[1]) + Vector3(0, float(spec.get("y", 0.0)), 0)
		var rot: float = spec.get("rot", 0.0)
		p.rotation.y = deg_to_rad(rot)
		if spec.has("scale"):
			p.scale = Vector3.ONE * float(spec["scale"])
		add_child(p)
		# "footprint" (bridges) marks the cells a fixture controls without blocking them.
		var solid: bool = p.get_meta("block", Vector2.ZERO) != Vector2.ZERO and not spec.get("walkable", false)
		var half: Vector2 = p.get_meta("footprint", p.get_meta("block", Vector2.ZERO)) * float(spec.get("scale", 1.0))
		if int(round(rot / 90.0)) % 2 != 0:
			half = Vector2(half.y, half.x)
		var cells := cells_under(p.position, half)
		if solid:
			for cell: Vector2i in cells:
				_block_cell(cell.x, cell.y)
		if spec["type"] in Fixture.TYPES:
			fixtures.append({"type": spec["type"], "spec": spec, "node": p, "cells": cells, "index": i})

func _build_backdrop() -> void:
	var kinds: Variant = data.get("backdrop", [])
	if kinds is String:
		kinds = [kinds]
	var center := Vector3(rect.get_center().x, 0, rect.get_center().y)
	var radius := rect.size.length() * 0.5 + 25.0
	for kind in kinds:
		match kind:
			"mountains", "mesas", "skyline":
				var count := 28
				for i in count:
					var a := TAU * i / count + _rng.randf_range(-0.05, 0.05)
					var pos := center + Vector3(cos(a), 0, sin(a)) * (radius + _rng.randf_range(0, 40))
					var p: Node3D
					if kind == "mountains":
						p = Node3D.new()
						var h := _rng.randf_range(25, 60)
						Props._cyl(p, Vector3.ZERO, 0.0, h * 0.8, h, Mats.get_mat(Color(0.35, 0.5, 0.45), "rock", 0.05), 7)
						Props._cyl(p, Vector3(0, h * 0.75, 0), 0.0, h * 0.2, h * 0.25, Mats.get_mat(Color(0.95, 0.95, 0.97)), 7)
					elif kind == "mesas":
						p = Props.make("mesa", {"r": _rng.randf_range(6, 14), "h": _rng.randf_range(12, 30)})
					else:
						p = Props.make("office_tower", {"w": _rng.randf_range(8, 16), "d": _rng.randf_range(8, 16), "h": _rng.randf_range(20, 70), "color": Color(0.6, 0.65, 0.75)})
					p.position = pos
					add_child(p)
			"ocean":
				var plane := PlaneMesh.new()
				plane.size = Vector2(radius * 6, radius * 6)
				var mi := MeshInstance3D.new()
				mi.mesh = plane
				mi.material_override = Mats.get_mat(Color(0.18, 0.42, 0.75), "water", 0.2, {"rough": 0.15})
				mi.position = center + Vector3(0, -0.15, 0)
				add_child(mi)
			"clouds":
				for i in 40:
					var a := _rng.randf() * TAU
					var pos := center + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(radius * 0.6, radius * 2.0)
					var cloud := MeshInstance3D.new()
					var sm := SphereMesh.new()
					sm.radius = _rng.randf_range(6, 16)
					sm.height = sm.radius * 2
					cloud.mesh = sm
					cloud.material_override = Mats.get_mat(Color(1, 1, 1), "", 1.0, {"alpha": 0.85})
					cloud.position = pos + Vector3(0, _rng.randf_range(-20, -6), 0)
					cloud.scale = Vector3(1.6, 0.45, 1.0)
					add_child(cloud)

# --- helpers ---------------------------------------------------------------

## JSON colours ([r, g, b], [r, g, b, a] or "#rrggbb") become Color for keys
## named color/wall/awning/roof.
static func _params(raw: Dictionary) -> Dictionary:
	var out := {}
	for k in raw:
		var v: Variant = raw[k]
		if (k.contains("color") or k in ["wall", "awning", "roof"]) and (v is Array or v is String):
			out[k] = _color(v)
		else:
			out[k] = v
	return out

static func _color(v: Variant) -> Color:
	if v is String:
		return Color.html(v)
	var a: Array = v
	return Color(a[0], a[1], a[2], a[3] if a.size() > 3 else 1.0)
