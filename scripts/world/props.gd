class_name Props
extends RefCounted
## Procedural prop library. Props.make("dome_house", {"color": Color.RED})
## returns a Node3D standing on y = 0 at the origin, front facing +Z.
## Each prop sets meta "block" (Vector2 half-extents in metres, ZERO = walkable)
## so the level builder can mark its cells as solid.
## Every type is listed in DOCS with its params; keep DOCS in sync when adding.

const DOCS := {
	# nature
	"tree_oak": "Round leafy tree. size", "tree_pine": "Conifer. size", "tree_palm": "Palm tree. size",
	"bush": "Low round bush. size, color", "rock": "Boulder. size, color", "mesa": "Flat-topped rock column. r, h",
	"crater": "Scorched hollow. r", "pond": "Round pond. r", "flowers": "Flower patch. color", "log": "Fallen log",
	# village
	"dome_house": "Round white house with dome roof. r, color (roof), wall", "goku_house": "Goku's dome house with annex",
	"kame_house": "Pink beach house with red roof", "hut": "Small hut with straw roof", "fence": "Fence along +X. length",
	"well": "Stone well", "windmill": "Windmill", "farm_plot": "Crop rows. w, d",
	# city
	"capsule_corp": "Capsule Corporation dome headquarters", "dome_building": "Domed city building. r, h, color",
	"round_tower": "Cylindrical tower with dome cap. r, h, color", "office_tower": "Box tower with windows. w, d, h, color",
	"shop": "Shop with striped awning and sign. text, color", "apartment": "Apartment block. w, d, h, color",
	"hercule_mansion": "Hercule's mansion", "hercule_statue": "Gold statue of the champion on a plinth",
	"tournament_ring": "Stone fighting stage. size", "stands": "Spectator stands along +X. length",
	"billboard": "Billboard. text, color", "lamp_post": "Street lamp. light (bool)", "bench": "Park bench",
	"fountain": "Plaza fountain. r", "car": "Rounded car. color", "hover_car": "Hovering car. color",
	"bus_stop": "Bus stop shelter", "traffic_light": "Traffic light", "flag_pole": "Flag pole. color",
	"radio_tower": "Lattice radio mast. h", "planter": "Tree planter box",
	# landmarks
	"korin_tower": "Korin's tower pillar. h", "lookout": "Kami's floating lookout. y", "space_pod": "Saiyan attack pod",
	"dragon_ball": "Dragon Ball. stars", "capsule_ship": "Capsule Corp round spaceship", "sign": "Wooden sign. text",
	"exit_marker": "Glowing exit ring", "portal_light": "Pillar of light (world map marker). color, h",
	# interior
	"table": "Table. w, d", "chair": "Chair", "bed": "Bed. color", "counter": "Kitchen counter. length",
	"shelf": "Bookshelf", "rug": "Rug. w, d, color", "fridge": "Fridge", "stove": "Stove", "sofa": "Sofa. color",
	"tv": "Television", "lab_bench": "Lab workbench", "computer": "Computer terminal", "capsule_rack": "Rack of capsules",
	"plant_pot": "Potted plant", "floor_lamp": "Floor lamp with light", "dinner_table": "Table set with bowls",
	"crate": "Wooden crate", "barrel": "Barrel", "gravity_machine": "Capsule Corp gravity machine column",
	"trophy": "Gold trophy on a stand", "pillar": "Stone pillar. h", "torii": "Shrine gate",
	# Capsule Corp home: Oto's room, the pantry, the gravity chamber
	"snack_shelf": "Shelf packed with snacks, jars and instant noodles", "takeout_stack": "Stack of takeout boxes with chopsticks. n",
	"minifridge": "Small fridge with a snack-shaped magnet", "pizza_boxes": "Flat stack of pizza boxes on the floor (walkable). n",
	"bean_bag": "Floor cushion seat. color", "sigil_banner": "Hanging banner with the Wall sigil. color",
	"pantry_rack": "Steel pantry shelving: rice sacks, capsule cans, jars", "freezer": "Chest freezer, frosted",
	"weight_rack": "Rack of heavy dumbbells", "punching_bag": "Hanging punching bag. color",
	# region kit (docs/REGIONS.md): also the tile letters K h k I g d V X u Z
	"cliff": "Tile-filling strata rock column; a row makes a canyon wall. color, h", "cave_column": "Dark cave wall column. color, h",
	"cactus": "Saguaro cactus", "hoodoo": "Sandstone spire with a cap rock", "dead_tree": "Bare dead tree",
	"bones": "Giant bleached ribs and skull", "tent": "Nomad tent. color", "campfire": "Campfire with light",
	"crag": "Jagged mountain boulder pile. color", "snow_cap": "Flat snow mound (walkable)", "snow_drift": "Snow drift (walkable)",
	"snow_pine": "Pine tree under snow", "ice_spike": "Cluster of ice spikes", "ice_block": "Stacked blocks of clear ice",
	"igloo": "Snow-brick igloo", "stalagmite": "Cave stalagmite. color", "crystal_cluster": "Glowing crystals. color, light (bool)",
	"glow_mushroom": "Glowing cave mushrooms. color", "rock_arch": "Natural stone arch along +X (walk under). span, color",
	"cave_mouth": "Dark cave opening in a rock face",
	# city kit
	"vending_machine": "Drinks vending machine. color", "food_stall": "Street food stall with awning. text, color",
	"cafe_table": "Cafe table with umbrella and two chairs. color", "phone_booth": "Glass phone booth. color",
	"trash_bin": "Street bin. color", "hydrant": "Fire hydrant", "hedge": "Clipped hedge along +X. length",
	"street_sign": "Street name sign. text", "bike_rack": "Bike rack", "market_crates": "Stacked produce crates",
	# fixtures: interactive in locations (behaviour in scripts/world/fixture.gd)
	"level_gate": "Barrier of hard light between posts; opens at a level. level, w",
	"memory_gate": "Void seal between dark posts; opens with a form or flag. form or flag, w",
	"key_door": "Locked wooden door in a frame. key (item id), w",
	"bridge": "Plank bridge along +Z; extends when its flag is set. flag, w, length",
	"floor_switch": "Pressure plate that sets a flag. flag",
	"breakable_rock": "Cracked boulder that breaks under hits. hp, size",
	"save_lantern": "Stone lantern: rest and save", "food_pot": "Cooking pot of leftovers (heals)",
	"fishing_spot": "Short jetty with a bobber; the jetty points along -Z into the water (rot it)",
}

static func types() -> Array:
	return DOCS.keys()

static func make(type: String, p: Dictionary = {}) -> Node3D:
	var n := Node3D.new()
	n.name = type
	n.set_meta("block", Vector2.ZERO)
	var s: float = p.get("size", 1.0)
	match type:
		"tree_oak":
			_cyl(n, Vector3.ZERO, 0.22 * s, 0.3 * s, 2.2 * s, _m(Color(0.4, 0.26, 0.15), "planks", 2.0))
			for c in [Vector3(0, 3.0, 0), Vector3(0.7, 2.6, 0.3), Vector3(-0.6, 2.7, -0.3), Vector3(0.1, 3.4, -0.5)]:
				_ball(n, c * s, 1.2 * s, _m(Color(0.2, 0.48, 0.18), "noise", 1.0))
			_block(n, 0.5 * s, 0.5 * s)
		"tree_pine":
			_cyl(n, Vector3.ZERO, 0.2 * s, 0.25 * s, 1.5 * s, _m(Color(0.38, 0.24, 0.14)))
			for i in 3:
				_cyl(n, Vector3(0, (1.2 + i * 1.1) * s, 0), 0.0, (1.6 - i * 0.4) * s, 1.8 * s, _m(Color(0.12, 0.35, 0.18), "noise", 1.0))
			_block(n, 0.5 * s, 0.5 * s)
		"tree_palm":
			var trunk_m := _m(Color(0.55, 0.42, 0.28), "stripes", 2.0)
			for i in 6:
				_cyl(n, Vector3(i * 0.12 * s, i * 0.7 * s, 0), 0.17 * s, 0.2 * s, 0.75 * s, trunk_m)
			var top := Vector3(0.72 * s, 4.3 * s, 0)
			for a in 7:
				var leaf := _box(n, top, Vector3(2.4 * s, 0.06, 0.5 * s), _m(Color(0.2, 0.55, 0.2)))
				leaf.rotation = Vector3(0, a * TAU / 7.0, -0.35)
				leaf.position += Vector3(cos(a * TAU / 7.0), -0.3, -sin(a * TAU / 7.0)) * 1.0 * s
			_block(n, 0.4 * s, 0.4 * s)
		"bush":
			var c: Color = p.get("color", Color(0.22, 0.5, 0.2))
			_ball(n, Vector3(0, 0.4, 0) * s, 0.7 * s, _m(c, "noise", 2.0))
			_ball(n, Vector3(0.5, 0.35, 0.2) * s, 0.5 * s, _m(c.darkened(0.1), "noise", 2.0))
		"rock":
			var r := _ball(n, Vector3(0, 0.35 * s, 0), 0.8 * s, _m(p.get("color", Color(0.5, 0.48, 0.45)), "rock", 1.5))
			r.scale = Vector3(1.2, 0.7, 1.0)
			_block(n, 0.8 * s, 0.7 * s)
		"mesa":
			var r: float = p.get("r", 3.0)
			var h: float = p.get("h", 10.0)
			var rock_m := _m(Color(0.75, 0.45, 0.28), "rock", 0.3)
			_cyl(n, Vector3.ZERO, r * 0.85, r, h, rock_m, 9)
			_cyl(n, Vector3(0, h, 0), r * 0.75, r * 0.88, 0.6, _m(Color(0.7, 0.55, 0.35)), 9)
			_block(n, r * 0.9, r * 0.9)
		"crater":
			var r: float = p.get("r", 2.2)
			_cyl(n, Vector3(0, 0.02, 0), r, r, 0.04, _m(Color(0.12, 0.1, 0.1)), 24)
			var rim := _torus(n, Vector3(0, 0.05, 0), r * 0.95, r * 1.15, _m(Color(0.35, 0.3, 0.25), "rock", 1.0))
			rim.scale.y = 0.4
		"pond":
			var r: float = p.get("r", 4.0)
			_cyl(n, Vector3(0, 0.0, 0), r + 0.3, r + 0.3, 0.06, _m(Color(0.45, 0.4, 0.32), "sand", 1.0), 24)
			_cyl(n, Vector3(0, 0.04, 0), r, r, 0.04, _m(Color(0.2, 0.45, 0.8), "water", 0.5, {"rough": 0.1}), 24)
			_block(n, r * 0.8, r * 0.8)
		"flowers":
			var c: Color = p.get("color", Color(1.0, 0.85, 0.3))
			var rng := RandomNumberGenerator.new()
			rng.seed = 5
			for i in 9:
				_ball(n, Vector3(rng.randf_range(-0.8, 0.8), 0.15, rng.randf_range(-0.8, 0.8)), 0.09, _m(c))
		"log":
			var l := _cyl(n, Vector3.ZERO, 0.25, 0.25, 2.2, _m(Color(0.42, 0.28, 0.16), "planks", 2.0))
			l.rotation.z = PI / 2
			l.position = Vector3(1.1, 0.25, 0)

		"dome_house":
			var r: float = p.get("r", 3.0)
			var wall: Color = p.get("wall", Color(0.95, 0.93, 0.88))
			_cyl(n, Vector3.ZERO, r, r, 2.4, _m(wall, "panels", 0.5), 20)
			var roof := _ball(n, Vector3(0, 2.4, 0), r * 1.04, _m(p.get("color", Color(0.85, 0.35, 0.2)), "roof_tiles", 0.8))
			roof.scale.y = 0.7
			_box(n, Vector3(0, 1.0, r - 0.05), Vector3(1.1, 2.0, 0.3), _m(Color(0.45, 0.3, 0.2), "planks", 2.0))
			for a in [-0.7, 0.7, 2.4, -2.4]:
				_box(n, Vector3(sin(a) * r, 1.4, cos(a) * r), Vector3(0.7, 0.7, 0.2), _m(Color(0.3, 0.45, 0.6))).rotation.y = a
			_block(n, r, r)
		"goku_house":
			var main := make("dome_house", {"r": 3.2, "color": Color(0.9, 0.4, 0.2)})
			n.add_child(main)
			var annex := make("dome_house", {"r": 2.0, "color": Color(0.9, 0.4, 0.2)})
			annex.position = Vector3(4.2, 0, -0.8)
			n.add_child(annex)
			_cyl(n, Vector3(-1.2, 3.6, -1.5), 0.25, 0.25, 1.4, _m(Color(0.6, 0.55, 0.5), "bricks", 3.0))
			_block(n, 6.0, 3.4)
		"kame_house":
			_box(n, Vector3(0, 0.2, 0), Vector3(8, 0.4, 7), _m(Color(0.85, 0.8, 0.65), "planks", 1.0))
			_box(n, Vector3(0, 2.0, 0), Vector3(6, 3.2, 5), _m(Color(0.98, 0.65, 0.7), "panels", 0.5))
			var roof := _cyl(n, Vector3(0, 3.6, 0), 0.0, 4.6, 2.2, _m(Color(0.8, 0.15, 0.15), "roof_tiles", 0.8), 4)
			roof.rotation.y = PI / 4
			_box(n, Vector3(0, 1.4, 2.52), Vector3(1.2, 2.0, 0.1), _m(Color(0.45, 0.3, 0.2), "planks", 2.0))
			for x in [-2.0, 2.0]:
				_box(n, Vector3(x, 2.2, 2.52), Vector3(1.0, 0.9, 0.08), _m(Color(0.4, 0.6, 0.75)))
			_label(n, "KAME HOUSE", Vector3(0, 3.0, 2.56), 64, Color(0.9, 0.1, 0.1))
			_block(n, 4.0, 3.5)
		"hut":
			_box(n, Vector3(0, 1.1, 0), Vector3(3, 2.2, 3), _m(Color(0.7, 0.55, 0.38), "planks", 1.5))
			_cyl(n, Vector3(0, 2.2, 0), 0.0, 2.6, 1.6, _m(Color(0.85, 0.75, 0.4), "stripes", 2.0), 8)
			_box(n, Vector3(0, 0.9, 1.52), Vector3(0.9, 1.8, 0.08), _m(Color(0.3, 0.2, 0.12)))
			_block(n, 1.6, 1.6)
		"fence":
			var length: float = p.get("length", 4.0)
			var wood := _m(Color(0.55, 0.38, 0.22), "planks", 2.0)
			var posts := int(length / 1.5) + 1
			for i in posts:
				_box(n, Vector3(i * length / (posts - 1), 0.5, 0), Vector3(0.12, 1.0, 0.12), wood)
			for y in [0.4, 0.8]:
				_box(n, Vector3(length / 2, y, 0), Vector3(length, 0.08, 0.06), wood)
		"well":
			_cyl(n, Vector3.ZERO, 0.8, 0.8, 0.8, _m(Color(0.6, 0.6, 0.6), "bricks", 3.0), 12)
			for x in [-0.7, 0.7]:
				_box(n, Vector3(x, 1.2, 0), Vector3(0.1, 1.6, 0.1), _m(Color(0.45, 0.3, 0.2)))
			_cyl(n, Vector3(0, 2.0, 0), 0.0, 1.1, 0.6, _m(Color(0.6, 0.25, 0.2)), 4).rotation.y = PI / 4
			_block(n, 0.8, 0.8)
		"windmill":
			_cyl(n, Vector3.ZERO, 0.9, 1.4, 6.0, _m(Color(0.9, 0.88, 0.82), "bricks", 1.0), 10)
			_cyl(n, Vector3(0, 6.0, 0), 0.0, 1.2, 1.2, _m(Color(0.6, 0.25, 0.2)), 10)
			for a in 4:
				var blade := _box(n, Vector3(0, 5.6, 1.3), Vector3(0.5, 3.6, 0.06), _m(Color(0.85, 0.8, 0.7), "stripes", 3.0))
				blade.rotation.z = a * PI / 2
				blade.position += Vector3(sin(a * PI / 2), cos(a * PI / 2), 0) * 1.8
			_block(n, 1.4, 1.4)
		"farm_plot":
			var w: float = p.get("w", 6.0)
			var d: float = p.get("d", 4.0)
			_box(n, Vector3(0, 0.03, 0), Vector3(w, 0.06, d), _m(Color(0.4, 0.28, 0.18), "noise", 2.0))
			var rows := int(d / 0.8)
			for i in rows:
				_box(n, Vector3(0, 0.2, -d / 2 + 0.4 + i * 0.8), Vector3(w * 0.95, 0.3, 0.3), _m(Color(0.3, 0.6, 0.2), "noise", 3.0))

		"capsule_corp":
			var white := _m(Color(0.96, 0.96, 0.95), "panels", 0.15)
			var dome := _ball(n, Vector3.ZERO, 14.0, white)
			dome.scale.y = 0.62
			var ring := _torus(n, Vector3(0, 3.5, 0), 13.0, 14.6, _m(Color(0.35, 0.55, 0.85)))
			ring.scale.y = 0.5
			var tower := make("round_tower", {"r": 3.0, "h": 14.0, "color": Color(0.95, 0.95, 0.95)})
			tower.position = Vector3(-11, 0, -6)
			n.add_child(tower)
			_box(n, Vector3(0, 1.6, 13.5), Vector3(5, 3.2, 3), _m(Color(0.9, 0.9, 0.9), "panels", 0.5))
			_box(n, Vector3(0, 1.3, 15.02), Vector3(2.4, 2.6, 0.1), _m(Color(0.3, 0.45, 0.6), "", 1.0, {"rough": 0.2}))
			_label(n, "CAPSULE CORP.", Vector3(0, 7.2, 12.0), 400, Color(0.15, 0.3, 0.75))
			var logo := _cyl(n, Vector3(0, 7.4, 11.2), 1.6, 1.6, 0.1, _m(Color(0.15, 0.3, 0.75)), 20)
			logo.rotation.x = PI / 2
			logo.position = Vector3(0, 10.5, 10.0)
			_label(n, "CC", Vector3(0, 10.5, 10.1), 260, Color.WHITE)
			_block(n, 14.0, 14.0)
		"dome_building":
			var r: float = p.get("r", 5.0)
			var h: float = p.get("h", 4.0)
			var c: Color = p.get("color", Color(0.95, 0.93, 0.9))
			_cyl(n, Vector3.ZERO, r, r, h, _m(c, "windows", 0.3), 20)
			var dome := _ball(n, Vector3(0, h, 0), r, _m(c.lightened(0.1), "panels", 0.3))
			dome.scale.y = 0.6
			_box(n, Vector3(0, 1.2, r - 0.1), Vector3(1.8, 2.4, 0.4), _m(Color(0.3, 0.45, 0.6), "", 1.0, {"rough": 0.2}))
			_block(n, r, r)
		"round_tower":
			var r: float = p.get("r", 3.0)
			var h: float = p.get("h", 16.0)
			var c: Color = p.get("color", Color(0.9, 0.9, 0.95))
			_cyl(n, Vector3.ZERO, r, r, h, _m(c, "windows_lit", 0.35), 16)
			var cap := _ball(n, Vector3(0, h, 0), r * 1.05, _m(c.lightened(0.1), "panels", 0.3))
			cap.scale.y = 0.55
			_cyl(n, Vector3(0, h + r * 0.5, 0), 0.06, 0.08, 3.0, _m(Color(0.7, 0.7, 0.7)))
			_block(n, r, r)
		"office_tower":
			var w: float = p.get("w", 8.0)
			var d: float = p.get("d", 8.0)
			var h: float = p.get("h", 20.0)
			var c: Color = p.get("color", Color(0.75, 0.82, 0.9))
			_box(n, Vector3(0, h / 2, 0), Vector3(w, h, d), _m(c, "windows_lit", 0.35))
			_box(n, Vector3(0, h + 0.3, 0), Vector3(w * 0.7, 0.6, d * 0.7), _m(c.darkened(0.3)))
			_box(n, Vector3(0, 1.3, d / 2 + 0.05), Vector3(2.4, 2.6, 0.1), _m(Color(0.25, 0.35, 0.45), "", 1.0, {"rough": 0.2}))
			_block(n, w / 2, d / 2)
		"shop":
			var c: Color = p.get("color", Color(0.95, 0.9, 0.75))
			_box(n, Vector3(0, 1.6, 0), Vector3(5, 3.2, 4), _m(c, "bricks", 0.8))
			var awn := _box(n, Vector3(0, 2.6, 2.4), Vector3(5.2, 0.1, 1.2), _m(p.get("awning", Color(0.85, 0.2, 0.2)), "stripes", 1.5))
			awn.rotation.x = 0.3
			_box(n, Vector3(0, 1.1, 2.02), Vector3(3.6, 1.6, 0.08), _m(Color(0.4, 0.55, 0.7), "", 1.0, {"rough": 0.2}))
			_label(n, p.get("text", "SHOP"), Vector3(0, 3.5, 2.06), 120, Color(0.15, 0.1, 0.1))
			_block(n, 2.5, 2.0)
		"apartment":
			var w: float = p.get("w", 10.0)
			var d: float = p.get("d", 8.0)
			var h: float = p.get("h", 12.0)
			var c: Color = p.get("color", Color(0.95, 0.85, 0.7))
			_box(n, Vector3(0, h / 2, 0), Vector3(w, h, d), _m(c, "windows", 0.4))
			var floors := int(h / 3.0)
			for f in range(1, floors):
				_box(n, Vector3(0, f * 3.0, d / 2 + 0.4), Vector3(w * 0.9, 0.15, 0.8), _m(c.darkened(0.2)))
			_block(n, w / 2, d / 2)
		"hercule_mansion":
			var white := _m(Color(0.98, 0.97, 0.94), "panels", 0.3)
			var gold := _m(Color(0.95, 0.75, 0.2), "", 1.0, {"metal": 0.6, "rough": 0.3})
			_box(n, Vector3(0, 4, 0), Vector3(24, 8, 14), white)
			_box(n, Vector3(0, 8.3, 0), Vector3(25, 0.6, 15), gold)
			var top := _ball(n, Vector3(0, 8.6, 0), 4.0, gold)
			top.scale.y = 0.6
			for x in range(-10, 11, 4):
				_cyl(n, Vector3(x, 0, 7.6), 0.45, 0.5, 7.6, white, 12)
			_box(n, Vector3(0, 7.9, 7.8), Vector3(24, 0.8, 1.2), white)
			_box(n, Vector3(0, 1.8, 7.05), Vector3(3, 3.6, 0.1), _m(Color(0.55, 0.3, 0.15), "planks", 1.0))
			_label(n, "HERCULE", Vector3(0, 6.6, 8.45), 380, Color(0.85, 0.6, 0.1))
			_block(n, 12.5, 7.8)
		"hercule_statue":
			_box(n, Vector3(0, 1.5, 0), Vector3(3, 3, 3), _m(Color(0.8, 0.78, 0.75), "bricks", 0.6))
			var champ := ModelLoader.make("male_base", Color(1.0, 0.8, 0.3))
			champ.scale = Vector3.ONE * 2.2
			champ.position.y = 3.0
			n.add_child(champ)
			_ball(n, Vector3(0, 3.0 + 1.85 * 2.2, 0.05), 0.38 * 2.2, _m(Color(0.95, 0.75, 0.25), "", 1.0, {"metal": 0.6, "rough": 0.3}))
			_label(n, "WORLD CHAMPION", Vector3(0, 1.6, 1.52), 110, Color(0.3, 0.2, 0.1))
			_block(n, 1.6, 1.6)
		"tournament_ring":
			var size: float = p.get("size", 16.0)
			_box(n, Vector3(0, 0.5, 0), Vector3(size, 1.0, size), _m(Color(0.85, 0.82, 0.75), "tiles", 0.5))
			for side in 4:
				var step := _box(n, Vector3(0, 0.25, size / 2 + 0.5), Vector3(4, 0.5, 1), _m(Color(0.8, 0.78, 0.7), "tiles", 0.5))
				step.position = step.position.rotated(Vector3.UP, side * PI / 2)
				step.rotation.y = side * PI / 2
		"stands":
			var length: float = p.get("length", 20.0)
			for tier in 5:
				_box(n, Vector3(length / 2, 0.4 + tier * 0.8, -tier * 1.2), Vector3(length, 0.8 + tier * 1.6, 1.2), _m(Color(0.6, 0.6, 0.65), "stripes", 0.5))
			_block(n, 0.0, 0.0)
		"billboard":
			for x in [-2.0, 2.0]:
				_box(n, Vector3(x, 2.5, 0), Vector3(0.2, 5, 0.2), _m(Color(0.5, 0.5, 0.5)))
			_box(n, Vector3(0, 5.5, 0), Vector3(6, 2.5, 0.2), _m(p.get("color", Color(0.95, 0.8, 0.2))))
			_label(n, p.get("text", "ADVERTISE HERE"), Vector3(0, 5.5, 0.12), 110, Color(0.1, 0.1, 0.1))
			_block(n, 2.2, 0.3)
		"lamp_post":
			_cyl(n, Vector3.ZERO, 0.07, 0.1, 4.0, _m(Color(0.3, 0.3, 0.35), "", 1.0, {"metal": 0.5}))
			_ball(n, Vector3(0, 4.1, 0), 0.3, Mats.glow(Color(1.0, 0.95, 0.75)))
			if p.get("light", false):
				var l := OmniLight3D.new()
				l.position.y = 4.0
				l.omni_range = 8.0
				l.light_color = Color(1.0, 0.9, 0.7)
				n.add_child(l)
			_block(n, 0.2, 0.2)
		"bench":
			var wood := _m(Color(0.6, 0.4, 0.22), "planks", 2.0)
			_box(n, Vector3(0, 0.45, 0), Vector3(2.0, 0.1, 0.5), wood)
			_box(n, Vector3(0, 0.8, -0.22), Vector3(2.0, 0.5, 0.08), wood)
			for x in [-0.9, 0.9]:
				_box(n, Vector3(x, 0.22, 0), Vector3(0.1, 0.45, 0.45), _m(Color(0.3, 0.3, 0.3)))
		"fountain":
			var r: float = p.get("r", 3.0)
			_cyl(n, Vector3.ZERO, r, r, 0.6, _m(Color(0.85, 0.83, 0.8), "bricks", 1.0), 20)
			_cyl(n, Vector3(0, 0.55, 0), r - 0.25, r - 0.25, 0.06, _m(Color(0.3, 0.55, 0.85), "water", 0.5, {"rough": 0.1}), 20)
			_cyl(n, Vector3.ZERO, 0.35, 0.45, 2.2, _m(Color(0.85, 0.83, 0.8), "bricks", 1.0))
			_ball(n, Vector3(0, 2.4, 0), 0.5, _m(Color(0.6, 0.8, 1.0), "", 1.0, {"alpha": 0.6}))
			_block(n, r, r)
		"car":
			var c: Color = p.get("color", Color(0.85, 0.2, 0.2))
			var body := _ball(n, Vector3(0, 0.65, 0), 1.0, _m(c, "", 1.0, {"rough": 0.3, "metal": 0.3}))
			body.scale = Vector3(1.0, 0.5, 2.0)
			var cab := _ball(n, Vector3(0, 0.95, -0.2), 0.75, _m(Color(0.4, 0.55, 0.7), "", 1.0, {"rough": 0.1}))
			cab.scale = Vector3(1.0, 0.6, 1.2)
			for x in [-0.85, 0.85]:
				for z in [-1.2, 1.2]:
					var w := _cyl(n, Vector3(x, 0.32, z), 0.32, 0.32, 0.25, _m(Color(0.1, 0.1, 0.1)))
					w.rotation.z = PI / 2
					w.position = Vector3(x, 0.32, z)
			_block(n, 1.0, 2.0)
		"hover_car":
			var c: Color = p.get("color", Color(0.3, 0.6, 0.9))
			var body := _ball(n, Vector3(0, 1.0, 0), 1.0, _m(c, "", 1.0, {"rough": 0.3, "metal": 0.3}))
			body.scale = Vector3(1.0, 0.45, 1.9)
			var cab := _ball(n, Vector3(0, 1.3, -0.1), 0.7, _m(Color(0.6, 0.8, 0.95), "", 1.0, {"alpha": 0.6, "rough": 0.05}))
			cab.scale = Vector3(1.0, 0.7, 1.3)
			_cyl(n, Vector3(0, 0.02, 0), 1.0, 1.0, 0.02, _m(Color(0, 0, 0), "", 1.0, {"alpha": 0.25}), 16)
			_block(n, 1.0, 1.9)
		"bus_stop":
			_box(n, Vector3(0, 2.4, 0), Vector3(3.5, 0.12, 1.5), _m(Color(0.35, 0.55, 0.8)))
			_box(n, Vector3(0, 1.2, -0.7), Vector3(3.5, 2.4, 0.06), _m(Color(0.7, 0.85, 0.95), "", 1.0, {"alpha": 0.4}))
			_box(n, Vector3(0, 0.45, -0.4), Vector3(3.0, 0.1, 0.5), _m(Color(0.5, 0.5, 0.55)))
			_block(n, 1.7, 0.7)
		"traffic_light":
			_cyl(n, Vector3.ZERO, 0.08, 0.08, 3.2, _m(Color(0.25, 0.25, 0.28)))
			_box(n, Vector3(0, 3.6, 0), Vector3(0.4, 1.1, 0.35), _m(Color(0.15, 0.15, 0.15)))
			for i in 3:
				_ball(n, Vector3(0, 3.95 - i * 0.35, 0.18), 0.11, Mats.glow([Color(1, 0.2, 0.2), Color(1, 0.8, 0.2), Color(0.2, 1, 0.4)][i], 0.8))
		"flag_pole":
			_cyl(n, Vector3.ZERO, 0.06, 0.08, 7.0, _m(Color(0.85, 0.85, 0.85), "", 1.0, {"metal": 0.6}))
			_box(n, Vector3(0.8, 6.3, 0), Vector3(1.6, 1.0, 0.03), _m(p.get("color", Color(0.9, 0.2, 0.2)), "", 1.0, {"double": true}))
		"radio_tower":
			var h: float = p.get("h", 25.0)
			_cyl(n, Vector3.ZERO, 0.15, 1.6, h, _m(Color(0.85, 0.3, 0.25), "stripes", 0.5), 4)
			_ball(n, Vector3(0, h, 0), 0.25, Mats.glow(Color(1, 0.2, 0.2)))
			_block(n, 1.2, 1.2)
		"planter":
			_box(n, Vector3(0, 0.3, 0), Vector3(1.6, 0.6, 1.6), _m(Color(0.75, 0.72, 0.68), "bricks", 1.5))
			var t := make("tree_oak", {"size": 0.6})
			t.position.y = 0.6
			n.add_child(t)
			_block(n, 0.8, 0.8)

		"korin_tower":
			var h: float = p.get("h", 60.0)
			_cyl(n, Vector3.ZERO, 1.6, 1.8, h, _m(Color(0.95, 0.93, 0.85), "stripes", 0.25), 16)
			for i in range(1, int(h / 10)):
				_cyl(n, Vector3(0, i * 10.0, 0), 1.85, 1.85, 0.6, _m(Color(0.8, 0.2, 0.2)), 16)
			var top := _ball(n, Vector3(0, h + 2.0, 0), 4.0, _m(Color(0.95, 0.9, 0.8), "panels", 0.3))
			top.scale.y = 0.6
			_cyl(n, Vector3(0, h + 2.0, 0), 0.0, 3.0, 2.5, _m(Color(0.8, 0.2, 0.2), "roof_tiles", 0.5), 12)
			_block(n, 1.8, 1.8)
		"lookout":
			var y: float = p.get("y", 40.0)
			var under := _ball(n, Vector3(0, y, 0), 14.0, _m(Color(0.95, 0.93, 0.88), "panels", 0.1))
			under.scale.y = 0.35
			_cyl(n, Vector3(0, y, 0), 14.0, 14.0, 0.5, _m(Color(0.95, 0.95, 0.92), "tiles", 0.3), 32)
			var palace := make("dome_building", {"r": 5.0, "h": 4.0, "color": Color(0.97, 0.97, 0.95)})
			palace.position = Vector3(0, y + 0.5, -3)
			n.add_child(palace)
			for a in 6:
				var tr := make("tree_palm", {"size": 0.8})
				tr.position = Vector3(cos(a * TAU / 6.0) * 10.0, y + 0.5, sin(a * TAU / 6.0) * 10.0)
				n.add_child(tr)
		"space_pod":
			var pod := _ball(n, Vector3(0, 1.0, 0), 1.0, _m(Color(0.92, 0.92, 0.9), "panels", 1.0, {"metal": 0.4, "rough": 0.3}))
			pod.scale.y = 1.05
			var win := _ball(n, Vector3(0, 1.2, 0.75), 0.5, _m(Color(0.6, 0.1, 0.15), "", 1.0, {"rough": 0.1}))
			win.scale = Vector3(1.0, 0.7, 0.5)
			_block(n, 1.0, 1.0)
		"dragon_ball":
			_ball(n, Vector3(0, 0.2, 0), 0.18, _m(Color(1.0, 0.6, 0.1), "", 1.0, {"emit": Color(1.0, 0.5, 0.1), "emit_energy": 0.6, "rough": 0.1}))
			var stars: int = p.get("stars", 4)
			for i in stars:
				var a := TAU * i / stars
				_ball(n, Vector3(cos(a) * 0.05, 0.2 + sin(a) * 0.05, 0.17), 0.025, _m(Color(0.9, 0.1, 0.1)))
		"capsule_ship":
			var white := _m(Color(0.95, 0.95, 0.95), "panels", 0.5, {"metal": 0.3})
			_ball(n, Vector3(0, 6.0, 0), 5.0, white)
			for a in 4:
				var leg := _box(n, Vector3(cos(a * PI / 2 + 0.78) * 4.0, 1.5, sin(a * PI / 2 + 0.78) * 4.0), Vector3(0.4, 3.5, 0.4), _m(Color(0.6, 0.6, 0.65)))
				leg.rotation.z = 0.0
			_label(n, "CAPSULE CORP.", Vector3(0, 6.0, 5.05), 140, Color(0.15, 0.3, 0.75))
			_block(n, 4.5, 4.5)
		"sign":
			_box(n, Vector3(0, 0.6, 0), Vector3(0.12, 1.2, 0.12), _m(Color(0.45, 0.3, 0.18)))
			_box(n, Vector3(0, 1.3, 0), Vector3(1.6, 0.7, 0.08), _m(Color(0.7, 0.55, 0.35), "planks", 3.0))
			_label(n, p.get("text", "->"), Vector3(0, 1.3, 0.05), 60, Color(0.15, 0.08, 0.05))
		"exit_marker":
			var ring := _torus(n, Vector3(0, 0.05, 0), 0.7, 0.9, Mats.glow(p.get("color", Color(0.6, 0.85, 1.0))))
			ring.scale.y = 0.3
			_cyl(n, Vector3(0, 0.1, 0), 0.0, 0.3, 0.4, Mats.glow(p.get("color", Color(0.6, 0.85, 1.0))), 6)
		"portal_light":
			var h: float = p.get("h", 60.0)
			_cyl(n, Vector3.ZERO, 1.2, 1.2, h, Mats.get_mat(p.get("color", Color(1.0, 0.9, 0.5)), "", 1.0, {"unshaded": true, "alpha": 0.35}), 12)

		"table":
			var w: float = p.get("w", 2.0)
			var d: float = p.get("d", 1.2)
			var wood := _m(p.get("color", Color(0.55, 0.36, 0.2)), "planks", 2.0)
			_box(n, Vector3(0, 0.75, 0), Vector3(w, 0.08, d), wood)
			for x in [-w / 2 + 0.1, w / 2 - 0.1]:
				for z in [-d / 2 + 0.1, d / 2 - 0.1]:
					_box(n, Vector3(x, 0.37, z), Vector3(0.08, 0.74, 0.08), wood)
			_block(n, w / 2, d / 2)
		"chair":
			var wood := _m(p.get("color", Color(0.55, 0.36, 0.2)), "planks", 2.0)
			_box(n, Vector3(0, 0.45, 0), Vector3(0.5, 0.06, 0.5), wood)
			_box(n, Vector3(0, 0.75, -0.22), Vector3(0.5, 0.6, 0.06), wood)
			for x in [-0.2, 0.2]:
				for z in [-0.2, 0.2]:
					_box(n, Vector3(x, 0.22, z), Vector3(0.05, 0.45, 0.05), wood)
		"bed":
			_box(n, Vector3(0, 0.25, 0), Vector3(1.4, 0.5, 2.2), _m(Color(0.5, 0.35, 0.22), "planks", 2.0))
			_box(n, Vector3(0, 0.55, 0.2), Vector3(1.3, 0.15, 1.7), _m(p.get("color", Color(0.4, 0.55, 0.85)), "noise", 2.0))
			_box(n, Vector3(0, 0.62, -0.8), Vector3(1.0, 0.15, 0.4), _m(Color(0.95, 0.95, 0.95)))
			_block(n, 0.7, 1.1)
		"counter":
			var length: float = p.get("length", 3.0)
			_box(n, Vector3(0, 0.45, 0), Vector3(length, 0.9, 0.7), _m(Color(0.9, 0.88, 0.85), "panels", 1.5))
			_box(n, Vector3(0, 0.92, 0), Vector3(length + 0.05, 0.06, 0.75), _m(Color(0.35, 0.35, 0.38), "noise", 2.0))
			_block(n, length / 2, 0.35)
		"shelf":
			var wood := _m(Color(0.5, 0.33, 0.2), "planks", 2.0)
			_box(n, Vector3(0, 1.0, 0), Vector3(1.6, 2.0, 0.4), wood)
			var rng := RandomNumberGenerator.new()
			rng.seed = 9
			for row in 3:
				for i in 8:
					var bc := Color.from_hsv(rng.randf(), 0.5, 0.7)
					_box(n, Vector3(-0.65 + i * 0.18, 0.4 + row * 0.6, 0.12), Vector3(0.12, 0.4, 0.25), _m(bc))
			_block(n, 0.8, 0.2)
		"rug":
			var w: float = p.get("w", 3.0)
			var d: float = p.get("d", 2.0)
			_box(n, Vector3(0, 0.01, 0), Vector3(w, 0.02, d), _m(p.get("color", Color(0.7, 0.25, 0.25)), "stripes", 1.0))
		"fridge":
			_box(n, Vector3(0, 0.95, 0), Vector3(0.8, 1.9, 0.7), _m(Color(0.95, 0.95, 0.96), "", 1.0, {"rough": 0.3}))
			_box(n, Vector3(0.3, 1.2, 0.36), Vector3(0.05, 0.5, 0.04), _m(Color(0.6, 0.6, 0.6)))
			_block(n, 0.4, 0.35)
		"stove":
			_box(n, Vector3(0, 0.45, 0), Vector3(0.9, 0.9, 0.7), _m(Color(0.85, 0.85, 0.85)))
			for x in [-0.2, 0.2]:
				for z in [-0.15, 0.15]:
					_cyl(n, Vector3(x, 0.9, z), 0.1, 0.1, 0.02, _m(Color(0.1, 0.1, 0.1)))
			_cyl(n, Vector3(0.2, 0.92, 0.15), 0.18, 0.15, 0.25, _m(Color(0.3, 0.3, 0.32), "", 1.0, {"metal": 0.6}))
			_block(n, 0.45, 0.35)
		"sofa":
			var c: Color = p.get("color", Color(0.75, 0.45, 0.3))
			_box(n, Vector3(0, 0.25, 0), Vector3(2.2, 0.5, 0.9), _m(c, "noise", 2.0))
			_box(n, Vector3(0, 0.65, -0.35), Vector3(2.2, 0.8, 0.2), _m(c, "noise", 2.0))
			for x in [-1.05, 1.05]:
				_box(n, Vector3(x, 0.45, 0), Vector3(0.2, 0.5, 0.9), _m(c.darkened(0.1), "noise", 2.0))
			_block(n, 1.1, 0.45)
		"tv":
			_box(n, Vector3(0, 0.3, 0), Vector3(1.4, 0.6, 0.5), _m(Color(0.4, 0.28, 0.18), "planks", 2.0))
			_box(n, Vector3(0, 0.95, 0), Vector3(1.0, 0.7, 0.5), _m(Color(0.15, 0.15, 0.15)))
			_box(n, Vector3(0, 0.95, 0.26), Vector3(0.8, 0.55, 0.02), Mats.glow(Color(0.4, 0.6, 0.8), 0.6))
			_block(n, 0.7, 0.25)
		"lab_bench":
			_box(n, Vector3(0, 0.45, 0), Vector3(3.0, 0.9, 0.9), _m(Color(0.85, 0.87, 0.9), "panels", 1.0))
			_box(n, Vector3(-0.8, 1.05, 0), Vector3(0.6, 0.3, 0.4), _m(Color(0.3, 0.3, 0.35)))
			for i in 3:
				_cyl(n, Vector3(0.4 + i * 0.3, 0.9, 0.1), 0.06, 0.08, 0.25, _m(Color.from_hsv(i * 0.3, 0.6, 0.9), "", 1.0, {"alpha": 0.7}))
			_block(n, 1.5, 0.45)
		"computer":
			_box(n, Vector3(0, 0.45, 0), Vector3(1.6, 0.9, 0.8), _m(Color(0.8, 0.82, 0.86), "panels", 1.0))
			var screen := _box(n, Vector3(0, 1.4, -0.2), Vector3(1.5, 0.9, 0.08), _m(Color(0.2, 0.2, 0.22)))
			screen.rotation.x = -0.15
			_box(n, Vector3(0, 1.4, -0.15), Vector3(1.35, 0.75, 0.02), Mats.glow(Color(0.3, 0.9, 0.6), 0.5))
			_block(n, 0.8, 0.4)
		"capsule_rack":
			_box(n, Vector3(0, 0.9, 0), Vector3(2.0, 1.8, 0.5), _m(Color(0.75, 0.78, 0.82), "panels", 1.0))
			for row in 3:
				for i in 6:
					var cap := _cyl(n, Vector3(-0.75 + i * 0.3, 0.45 + row * 0.5, 0.26), 0.06, 0.06, 0.2, _m(Color.from_hsv(float(i) / 6.0, 0.4, 0.95)))
					cap.rotation.x = PI / 2
					cap.position = Vector3(-0.75 + i * 0.3, 0.45 + row * 0.5, 0.3)
			_block(n, 1.0, 0.25)
		"plant_pot":
			_cyl(n, Vector3.ZERO, 0.3, 0.22, 0.45, _m(Color(0.7, 0.4, 0.25)))
			_ball(n, Vector3(0, 0.85, 0), 0.45, _m(Color(0.2, 0.5, 0.25), "noise", 3.0))
		"floor_lamp":
			_cyl(n, Vector3.ZERO, 0.03, 0.15, 1.6, _m(Color(0.3, 0.3, 0.3)))
			_cyl(n, Vector3(0, 1.5, 0), 0.15, 0.3, 0.35, Mats.glow(Color(1.0, 0.9, 0.7), 0.8))
			var l := OmniLight3D.new()
			l.position.y = 1.6
			l.omni_range = 6.0
			l.light_color = Color(1.0, 0.85, 0.65)
			n.add_child(l)
		"dinner_table":
			n.add_child(make("table", {"w": 2.4, "d": 1.4}))
			for x in [-0.8, 0.0, 0.8]:
				for z in [-0.35, 0.35]:
					_cyl(n, Vector3(x, 0.79, z), 0.14, 0.09, 0.1, _m(Color(0.95, 0.95, 0.95)))
					_ball(n, Vector3(x, 0.88, z), 0.1, _m(Color(0.98, 0.97, 0.9)))
			_block(n, 1.2, 0.7)
		"crate":
			_box(n, Vector3(0, 0.45, 0), Vector3(0.9, 0.9, 0.9), _m(Color(0.6, 0.45, 0.28), "planks", 2.0))
			_block(n, 0.45, 0.45)
		"barrel":
			_cyl(n, Vector3.ZERO, 0.4, 0.4, 1.0, _m(Color(0.5, 0.35, 0.2), "planks", 3.0), 12)
			_block(n, 0.4, 0.4)
		"gravity_machine":
			_cyl(n, Vector3.ZERO, 1.2, 1.4, 0.4, _m(Color(0.8, 0.82, 0.86), "panels", 1.0), 16)
			_cyl(n, Vector3(0, 0.4, 0), 0.5, 0.6, 1.4, _m(Color(0.9, 0.9, 0.92), "panels", 1.0, {"metal": 0.4}), 16)
			_box(n, Vector3(0, 1.3, 0.55), Vector3(0.6, 0.4, 0.06), Mats.glow(Color(1.0, 0.3, 0.3), 0.8))
			_ball(n, Vector3(0, 2.0, 0), 0.35, Mats.glow(Color(0.5, 0.8, 1.0), 1.0))
			_block(n, 1.3, 1.3)
		"snack_shelf":
			var wood := _m(Color(0.45, 0.3, 0.2), "planks", 2.0)
			_box(n, Vector3(0, 0.9, -0.2), Vector3(1.4, 1.8, 0.05), wood)  # open-fronted: a back, two sides, a top
			for x in [-0.68, 0.68]:
				_box(n, Vector3(x, 0.9, 0), Vector3(0.04, 1.8, 0.45), wood)
			_box(n, Vector3(0, 1.79, 0), Vector3(1.4, 0.04, 0.45), wood)
			var rng := RandomNumberGenerator.new()
			rng.seed = 21
			for row in 3:
				_box(n, Vector3(0, 0.32 + row * 0.55, 0.05), Vector3(1.32, 0.03, 0.4), wood)
				for i in 6:
					var x := -0.55 + i * 0.22
					var y := 0.34 + row * 0.55
					match (i + row) % 3:
						0:  # a cup of instant noodles
							_cyl(n, Vector3(x, y, 0.1), 0.08, 0.06, 0.16, _m(Color(0.96, 0.95, 0.9)))
							_cyl(n, Vector3(x, y + 0.15, 0.1), 0.085, 0.085, 0.015, _m(Color.from_hsv(rng.randf(), 0.7, 0.9)))
						1:  # a bright snack bag
							var bag := _box(n, Vector3(x, y + 0.14, 0.12), Vector3(0.16, 0.26, 0.08), _m(Color.from_hsv(rng.randf(), 0.75, 0.95)))
							bag.rotation.z = rng.randf_range(-0.15, 0.15)
						_:  # a jar
							_cyl(n, Vector3(x, y, 0.1), 0.07, 0.07, 0.18, _m(Color(0.85, 0.6, 0.25), "", 1.0, {"alpha": 0.8}))
							_cyl(n, Vector3(x, y + 0.18, 0.1), 0.072, 0.072, 0.03, _m(Color(0.8, 0.2, 0.2)))
			_block(n, 0.7, 0.22)
		"takeout_stack":
			var k: int = int(p.get("n", 3))
			for i in k:
				var b := Node3D.new()
				b.position = Vector3(0.02 * sin(i * 2.1), 0.0, 0.02 * cos(i * 1.3))
				b.rotation.y = i * 0.35
				n.add_child(b)
				_cyl(b, Vector3(0, i * 0.17, 0), 0.13, 0.1, 0.16, _m(Color(0.97, 0.96, 0.93)), 4)
				_cyl(b, Vector3(0, i * 0.17 + 0.07, 0), 0.132, 0.132, 0.025, _m(Color(0.85, 0.15, 0.15)), 4)
			var sticks := _box(n, Vector3(0.05, k * 0.17 + 0.01, 0), Vector3(0.012, 0.012, 0.32), _m(Color(0.8, 0.65, 0.4)))
			sticks.rotation.y = 0.4
		"minifridge":
			_box(n, Vector3(0, 0.42, 0), Vector3(0.6, 0.84, 0.55), _m(Color(0.95, 0.95, 0.97), "", 1.0, {"rough": 0.3}))
			_box(n, Vector3(0.22, 0.5, 0.28), Vector3(0.04, 0.3, 0.03), _m(Color(0.6, 0.6, 0.62)))
			_cyl(n, Vector3(-0.1, 0.62, 0.285), 0.07, 0.07, 0.01, _m(Color(1.0, 0.7, 0.3)))  # a magnet shaped like a dumpling
			_box(n, Vector3(0, 0.86, 0), Vector3(0.62, 0.02, 0.57), _m(Color(0.35, 0.35, 0.38)))
			_block(n, 0.3, 0.28)
		"pizza_boxes":
			var k: int = int(p.get("n", 3))
			for i in k:
				var bx := _box(n, Vector3(0.03 * i, 0.03 + i * 0.05, -0.02 * i), Vector3(0.45, 0.045, 0.45), _m(Color(0.78, 0.62, 0.42)))
				bx.rotation.y = i * 0.3
			_cyl(n, Vector3(0, k * 0.05 + 0.02, 0), 0.08, 0.08, 0.005, _m(Color(0.85, 0.15, 0.15)))
		"bean_bag":
			var c: Color = p.get("color", Color(0.85, 0.45, 0.25))
			var seat := _ball(n, Vector3(0, 0.28, 0), 0.5, _m(c, "noise", 3.0))
			seat.scale = Vector3(1.0, 0.6, 1.0)
			var back := _ball(n, Vector3(0, 0.5, -0.25), 0.4, _m(c.darkened(0.08), "noise", 3.0))
			back.scale = Vector3(1.0, 0.8, 0.6)
			_block(n, 0.45, 0.45)
		"sigil_banner":
			var c: Color = p.get("color", Color(0.09, 0.27, 0.16))
			_cyl(n, Vector3(-0.55, 2.3, 0), 0.025, 0.025, 1.1, _m(Color(0.93, 0.73, 0.3), "", 1.0, {"metal": 0.7})).rotation.z = PI / 2
			_box(n, Vector3(0, 1.6, 0), Vector3(0.9, 1.4, 0.02), _m(c, "noise", 3.0))
			var pm := StandardMaterial3D.new()  # its own material: the shared ones are cached
			pm.albedo_color = Color(0.93, 0.73, 0.3)
			pm.albedo_texture = Sigil.texture(false)
			pm.metallic = 0.5
			pm.roughness = 0.4
			var quad := QuadMesh.new()  # a quad, so the sigil texture covers the face once
			quad.size = Vector2(0.35, 0.7)
			_add(n, quad, Vector3(0, 1.65, 0.02), pm)
			_box(n, Vector3(0, 0.88, 0), Vector3(0.9, 0.05, 0.03), _m(Color(0.93, 0.73, 0.3), "", 1.0, {"metal": 0.7}))
		"pantry_rack":
			var steel := _m(Color(0.78, 0.8, 0.84), "", 1.0, {"metal": 0.5, "rough": 0.4})
			for x in [-0.95, 0.95]:
				for z in [-0.22, 0.22]:
					_box(n, Vector3(x, 1.0, z), Vector3(0.04, 2.0, 0.04), steel)
			var rng := RandomNumberGenerator.new()
			rng.seed = 33
			for row in 4:
				var y := 0.1 + row * 0.55
				_box(n, Vector3(0, y, 0), Vector3(1.95, 0.03, 0.48), steel)
				if row == 0:
					for i in 3:  # rice sacks on the bottom shelf
						var sack := _ball(n, Vector3(-0.6 + i * 0.6, y + 0.2, 0), 0.24, _m(Color(0.9, 0.86, 0.75), "noise", 4.0))
						sack.scale = Vector3(1.0, 0.85, 0.8)
				else:
					for i in 7:
						var x := -0.78 + i * 0.26
						if (i + row) % 2 == 0:  # capsule cans
							_cyl(n, Vector3(x, y + 0.02, 0.05), 0.08, 0.08, 0.2, _m(Color.from_hsv(rng.randf(), 0.45, 0.95), "", 1.0, {"metal": 0.4}))
						else:  # jars
							_cyl(n, Vector3(x, y + 0.02, 0.05), 0.07, 0.07, 0.22, _m(Color.from_hsv(rng.randf() * 0.15, 0.7, 0.8), "", 1.0, {"alpha": 0.85}))
			_block(n, 1.0, 0.25)
		"freezer":
			_box(n, Vector3(0, 0.45, 0), Vector3(1.6, 0.9, 0.8), _m(Color(0.93, 0.95, 0.98), "", 1.0, {"rough": 0.25}))
			_box(n, Vector3(0, 0.92, 0), Vector3(1.62, 0.06, 0.82), _m(Color(0.75, 0.88, 0.98), "", 1.0, {"alpha": 0.7}))
			_box(n, Vector3(0, 0.97, 0), Vector3(1.3, 0.04, 0.6), _m(Color(1, 1, 1), "noise", 6.0))  # frost
			_block(n, 0.8, 0.4)
		"weight_rack":
			var steel := _m(Color(0.25, 0.25, 0.28), "", 1.0, {"metal": 0.7, "rough": 0.35})
			_box(n, Vector3(0, 0.45, 0), Vector3(1.8, 0.06, 0.5), steel)
			_box(n, Vector3(0, 0.85, 0), Vector3(1.8, 0.06, 0.5), steel)
			for x in [-0.85, 0.85]:
				_box(n, Vector3(x, 0.45, 0), Vector3(0.06, 0.9, 0.5), steel)
			for row in 2:
				for i in 4:
					var x := -0.6 + i * 0.4
					var y := 0.55 + row * 0.4
					var bar := _cyl(n, Vector3(x - 0.15, y, 0), 0.025, 0.025, 0.3, steel)
					bar.rotation.z = PI / 2
					bar.position = Vector3(x, y, 0)
					for side: float in [-0.13, 0.13]:
						var plate := _cyl(n, Vector3.ZERO, 0.09 + row * 0.02, 0.09 + row * 0.02, 0.06, _m(Color(0.1, 0.1, 0.12), "", 1.0, {"metal": 0.4}))
						plate.rotation.z = PI / 2
						plate.position = Vector3(x + side, y, 0)
			_block(n, 0.9, 0.25)
		"punching_bag":
			var c: Color = p.get("color", Color(0.75, 0.15, 0.15))
			_cyl(n, Vector3(0, 2.2, 0), 0.015, 0.015, 0.8, _m(Color(0.3, 0.3, 0.3), "", 1.0, {"metal": 0.6}))
			_cyl(n, Vector3(0, 0.9, 0), 0.28, 0.28, 1.3, _m(c, "noise", 2.0), 14)
			_cyl(n, Vector3(0, 2.15, 0), 0.24, 0.28, 0.08, _m(c.darkened(0.3)), 14)
			_block(n, 0.3, 0.3)
		# --- region kit: cliffs, desert, mountains, ice, caves ---------------------------
		"cliff":
			# a tile-filling rock column with strata; neighbouring cliffs overlap into one wall
			var c: Color = p.get("color", Color(0.62, 0.42, 0.3))
			var h: float = float(p.get("h", 6.0)) * s
			var m := _m(c, "strata", 0.6)
			_cyl(n, Vector3.ZERO, 1.25, 1.5, h, m, 7)
			_cyl(n, Vector3(0.2, h, -0.1), 0.6, 1.2, 0.8 * s, _m(c.darkened(0.12), "strata", 0.6), 6)
			_block(n, 1.0, 1.0)
		"cave_column":
			var c: Color = p.get("color", Color(0.24, 0.22, 0.28))
			var h: float = float(p.get("h", 7.0)) * s
			_cyl(n, Vector3.ZERO, 1.2, 1.55, h, _m(c, "strata", 0.5), 7)
			_cyl(n, Vector3(0, h, 0), 0.0, 1.2, 1.6 * s, _m(c.darkened(0.1), "noise", 1.0), 7)
			_block(n, 1.0, 1.0)
		"cactus":
			var g := _m(Color(0.3, 0.55, 0.28), "noise", 3.0)
			_cyl(n, Vector3.ZERO, 0.2 * s, 0.24 * s, 2.4 * s, g, 10)
			_ball(n, Vector3(0, 2.4 * s, 0), 0.2 * s, g)
			for side: float in [1.0, -1.0]:
				var y := (1.0 + (0.3 if side > 0 else 0.0)) * s
				var arm := _cyl(n, Vector3.ZERO, 0.13 * s, 0.13 * s, 0.45 * s, g, 8)
				arm.rotation.z = -side * PI / 2
				arm.position = Vector3(0, y, 0)
				_cyl(n, Vector3(side * 0.45 * s, y - 0.05 * s, 0), 0.12 * s, 0.13 * s, 0.75 * s, g, 8)
				_ball(n, Vector3(side * 0.45 * s, y + 0.7 * s, 0), 0.12 * s, g)
			_block(n, 0.3, 0.3)
		"hoodoo":
			# a weathered sandstone spire with a harder cap rock
			var rock := _m(Color(0.8, 0.5, 0.32), "strata", 0.8)
			var y := 0.0
			for k in 4:
				var r := (0.9 - k * 0.16) * s
				var hh := (1.3 - k * 0.1) * s
				_cyl(n, Vector3(0, y, 0), r * 0.82, r, hh, rock, 8)
				y += hh
			_cyl(n, Vector3(0.05, y, 0), 0.5 * s, 0.35 * s, 0.35 * s, _m(Color(0.55, 0.38, 0.28), "noise", 1.0), 8)
			_block(n, 0.8, 0.8)
		"dead_tree":
			var wood := _m(Color(0.42, 0.34, 0.28), "planks", 2.0)
			_cyl(n, Vector3.ZERO, 0.12 * s, 0.22 * s, 2.2 * s, wood, 7)
			for k in 4:
				var b := _cyl(n, Vector3.ZERO, 0.03 * s, 0.08 * s, 1.0 * s, wood, 5)
				b.rotation = Vector3(0.9, k * 1.7, 0)
				b.position = Vector3(0, (1.3 + k * 0.25) * s, 0)
			_block(n, 0.25, 0.25)
		"bones":
			# the bleached ribs and skull of something very large
			var bone := _m(Color(0.93, 0.9, 0.82))
			for k in 5:
				var rib := _torus(n, Vector3(0, 0.2, (k - 2) * 0.55 * s), 0.9 * s, 1.0 * s, bone)
				rib.rotation.x = PI / 2
				rib.rotation.z = 0.2
				rib.scale = Vector3(1.0, 1.0, 0.25)
			var skull := _ball(n, Vector3(0.0, 0.45 * s, 1.9 * s), 0.55 * s, bone)
			skull.scale = Vector3(1.0, 0.8, 1.3)
			_cyl(n, Vector3(0, 0.1, 0), 0.06 * s, 0.06 * s, 3.0 * s, bone).rotation.x = PI / 2
		"tent":
			var c: Color = p.get("color", Color(0.85, 0.75, 0.55))
			var t := _cyl(n, Vector3.ZERO, 0.0, 1.6, 2.2, _m(c, "noise", 2.0), 6)
			t.rotation.y = 0.3
			_box(n, Vector3(0, 0.55, 1.15), Vector3(0.7, 1.1, 0.05), _m(c.darkened(0.45)))
			_block(n, 1.3, 1.3)
		"campfire":
			var wood := _m(Color(0.4, 0.26, 0.15), "planks", 2.0)
			for k in 3:
				var lg := _cyl(n, Vector3.ZERO, 0.07, 0.07, 0.8, wood, 6)
				lg.rotation = Vector3(PI / 2, k * PI / 3, 0)
				lg.position = Vector3(0, 0.08, 0)
			for k in 8:
				var a := TAU * k / 8.0
				_ball(n, Vector3(cos(a) * 0.45, 0.06, sin(a) * 0.45), 0.1, _m(Color(0.45, 0.43, 0.4)))
			_cyl(n, Vector3(0, 0.1, 0), 0.0, 0.25, 0.6, Mats.glow(Color(1.0, 0.55, 0.15), 2.0), 6)
			var fl := OmniLight3D.new()
			fl.position.y = 0.6
			fl.omni_range = 7.0
			fl.light_energy = 1.4
			fl.light_color = Color(1.0, 0.65, 0.35)
			n.add_child(fl)
		"crag":
			# a jagged mountain boulder pile, for slopes and passes
			var rock := _m(p.get("color", Color(0.52, 0.5, 0.5)), "strata", 0.8)
			for k in 4:
				var b := _cyl(n, Vector3(sin(k * 2.1) * 0.6 * s, 0, cos(k * 1.7) * 0.6 * s), 0.0, (0.9 - k * 0.12) * s, (2.6 - k * 0.4) * s, rock, 5)
				b.rotation.z = 0.15 * (k - 1.5)
			_block(n, 1.0, 1.0)
		"snow_cap":
			# snow lying on whatever is under it: a flattened white mound, walkable
			var cap := _ball(n, Vector3(0, 0.05, 0), 1.0 * s, _m(Color(0.96, 0.97, 1.0), "noise", 4.0))
			cap.scale = Vector3(1.0, 0.18, 1.0)
		"snow_drift":
			var dr := _ball(n, Vector3(0, 0.0, 0), 0.8 * s, _m(Color(0.95, 0.97, 1.0), "noise", 4.0))
			dr.scale = Vector3(1.3, 0.35, 0.9)
		"snow_pine":
			n.add_child(make("tree_pine", {"size": s}))
			var white := _m(Color(0.96, 0.97, 1.0), "noise", 3.0)
			for k in 3:  # snow lying on each tier of branches
				var y := (1.15 + k * 0.85) * s
				_cyl(n, Vector3(0, y, 0), (0.55 - k * 0.15) * s, (1.25 - k * 0.3) * s, 0.28 * s, white, 8)
			_cyl(n, Vector3(0, 3.3 * s, 0), 0.0, 0.3 * s, 0.45 * s, white, 8)
			_block(n, 0.5 * s, 0.5 * s)
		"ice_spike":
			var ice := _m(Color(0.7, 0.88, 1.0), "", 1.0, {"alpha": 0.82, "rough": 0.1, "metal": 0.2})
			for k in 4:
				var sp := _cyl(n, Vector3(sin(k * 2.4) * 0.45 * s, 0, cos(k * 2.4) * 0.45 * s), 0.0, (0.55 - k * 0.08) * s, (3.0 - k * 0.55) * s, ice, 6)
				sp.rotation = Vector3(0.12 * cos(k * 1.3), 0, 0.12 * sin(k * 2.0))
			_block(n, 0.8, 0.8)
		"ice_block":
			var ice := _m(Color(0.72, 0.88, 1.0), "", 1.0, {"alpha": 0.78, "rough": 0.08})
			var b := _box(n, Vector3(0, 0.6 * s, 0), Vector3(1.3, 1.2, 1.3) * s, ice)
			b.rotation.y = 0.4
			_box(n, Vector3(0.3, 1.45 * s, 0.1), Vector3(0.7, 0.5, 0.7) * s, ice).rotation.y = 1.1
			_block(n, 0.7, 0.7)
		"igloo":
			var snow := _m(Color(0.95, 0.97, 1.0), "bricks", 1.5)
			var dome := _ball(n, Vector3.ZERO, 2.0, snow)
			dome.scale = Vector3(1.0, 0.8, 1.0)
			var tunnel := _cyl(n, Vector3(0, 0.55, 2.0), 0.6, 0.6, 1.4, snow, 10)
			tunnel.rotation.x = PI / 2
			tunnel.position = Vector3(0, 0.55, 1.6)
			_box(n, Vector3(0, 0.45, 2.3), Vector3(0.75, 0.9, 0.05), _m(Color(0.1, 0.12, 0.18)))
			_block(n, 2.0, 2.0)
		"stalagmite":
			var rock := _m(p.get("color", Color(0.38, 0.35, 0.4)), "strata", 0.8)
			_cyl(n, Vector3.ZERO, 0.0, 0.55 * s, 2.4 * s, rock, 7)
			_cyl(n, Vector3(0.5 * s, 0, 0.2 * s), 0.0, 0.3 * s, 1.3 * s, rock, 6)
			_block(n, 0.5, 0.5)
		"crystal_cluster":
			# glowing crystals in a rough star; "light" adds a real light (keep them few)
			var c: Color = p.get("color", Color(0.45, 0.8, 1.0))
			var glow := Mats.glow(c, 1.6)
			for k in 6:
				var a := TAU * k / 6.0 + 0.3
				var cr := _cyl(n, Vector3.ZERO, 0.0, (0.32 - k * 0.02) * s, (2.4 - k * 0.22) * s, glow, 6)
				cr.rotation = Vector3(cos(a) * 0.45, 0, sin(a) * 0.45)
				cr.position = Vector3(cos(a) * 0.25, 0, sin(a) * 0.25) * s
			_cyl(n, Vector3.ZERO, 0.0, 0.42 * s, 3.2 * s, glow, 6)
			_ball(n, Vector3(0, 0.05, 0), 0.75 * s, _m(Color(0.25, 0.23, 0.3), "noise", 1.0)).scale = Vector3(1, 0.3, 1)
			if p.get("light", true):
				var l := OmniLight3D.new()
				l.position.y = 1.4
				l.omni_range = 9.0
				l.light_energy = 1.2
				l.light_color = c
				n.add_child(l)
			_block(n, 0.6, 0.6)
		"glow_mushroom":
			var c: Color = p.get("color", Color(0.4, 1.0, 0.75))
			for k in 3:
				var off := Vector3(sin(k * 2.2), 0, cos(k * 2.2)) * 0.3 * s
				var hh := (0.5 - k * 0.12) * s
				_cyl(n, off, 0.05 * s, 0.06 * s, hh, _m(Color(0.85, 0.85, 0.8)), 6)
				var cap := _ball(n, off + Vector3(0, hh, 0), (0.22 - k * 0.04) * s, Mats.glow(c, 1.2))
				cap.scale = Vector3(1.0, 0.45, 1.0)
		"rock_arch":
			# a natural stone arch along +X; walk under it
			var rock := _m(p.get("color", Color(0.45, 0.42, 0.46)), "strata", 0.7)
			var span: float = float(p.get("span", 4.0))
			for side: float in [-1.0, 1.0]:
				_cyl(n, Vector3(side * span * 0.5, 0, 0), 0.6, 0.9, 3.4, rock, 7)
			var top := _box(n, Vector3(0, 3.6, 0), Vector3(span + 1.6, 0.9, 1.4), rock)
			top.rotation.z = 0.04
			n.set_meta("footprint", Vector2(span * 0.5 + 0.9, 0.7))
		"cave_mouth":
			# a dark opening in a rock face (an exit marker usually stands in it)
			var rock := _m(Color(0.4, 0.37, 0.4), "strata", 0.7)
			_cyl(n, Vector3(0, 0, -0.5), 2.4, 3.0, 4.2, rock, 9)
			var hole := _ball(n, Vector3(0, 1.1, 2.55), 1.35, _m(Color(0.02, 0.02, 0.03)))
			hole.scale = Vector3(1.0, 1.3, 0.35)
			_block(n, 2.2, 1.4)
		# --- city kit ------------------------------------------------------------------
		"vending_machine":
			var c: Color = p.get("color", Color(0.85, 0.15, 0.2))
			_box(n, Vector3(0, 0.95, 0), Vector3(0.9, 1.9, 0.7), _m(c, "", 1.0, {"rough": 0.4}))
			_box(n, Vector3(-0.12, 1.15, 0.36), Vector3(0.55, 1.0, 0.02), Mats.glow(Color(0.85, 0.95, 1.0), 0.7))
			for k in 4:
				_box(n, Vector3(-0.12 + (k % 2) * 0.24 - 0.12, 1.4 - (k / 2) * 0.4, 0.37), Vector3(0.16, 0.3, 0.02), _m(Color.from_hsv(k * 0.23, 0.7, 0.95)))
			_box(n, Vector3(0.3, 0.3, 0.36), Vector3(0.22, 0.12, 0.02), _m(Color(0.1, 0.1, 0.1)))
			_block(n, 0.45, 0.35)
		"food_stall":
			# a street-food stall: counter, striped awning on poles, a sign; text, color
			var c: Color = p.get("color", Color(0.85, 0.25, 0.2))
			var wood := _m(Color(0.6, 0.42, 0.26), "planks", 2.0)
			_box(n, Vector3(0, 0.5, 0), Vector3(2.4, 1.0, 1.0), wood)
			_box(n, Vector3(0, 1.02, 0.05), Vector3(2.5, 0.06, 1.1), _m(Color(0.92, 0.9, 0.86)))
			for x in [-1.15, 1.15]:
				_box(n, Vector3(x, 1.4, -0.45), Vector3(0.08, 2.8, 0.08), wood)
			var aw := _box(n, Vector3(0, 2.75, 0.15), Vector3(2.8, 0.06, 1.6), _m(c, "stripes", 1.0))
			aw.rotation.x = 0.25
			for k in 3:
				_cyl(n, Vector3(-0.7 + k * 0.7, 1.05, 0.2), 0.16, 0.12, 0.14, _m(Color(0.95, 0.95, 0.93)))
				_cyl(n, Vector3(-0.7 + k * 0.7, 1.19, 0.2), 0.13, 0.13, 0.02, _m(Color(0.9, 0.6, 0.25)))
			if p.has("text"):
				_label(n, str(p["text"]), Vector3(0, 3.15, 0.8), 64, Color.WHITE)
			_block(n, 1.25, 0.55)
		"cafe_table":
			var metal := _m(Color(0.85, 0.85, 0.88), "", 1.0, {"metal": 0.5})
			_cyl(n, Vector3.ZERO, 0.04, 0.25, 0.75, metal, 10)
			_cyl(n, Vector3(0, 0.74, 0), 0.45, 0.45, 0.04, metal, 16)
			_cyl(n, Vector3.ZERO, 0.025, 0.025, 2.3, metal, 6)
			_cyl(n, Vector3(0, 2.0, 0), 0.0, 1.2, 0.4, _m(p.get("color", Color(0.95, 0.55, 0.3)), "stripes", 1.0), 8)
			for side: float in [1.0, -1.0]:
				var chair := make("chair", {"color": Color(0.82, 0.82, 0.85)})
				chair.position = Vector3(side * 0.75, 0, 0)
				chair.rotation.y = -side * PI / 2
				n.add_child(chair)
			_block(n, 0.5, 0.5)
		"phone_booth":
			var c: Color = p.get("color", Color(0.25, 0.55, 0.85))
			for x in [-0.5, 0.5]:
				for z in [-0.5, 0.5]:
					_box(n, Vector3(x, 1.15, z), Vector3(0.08, 2.3, 0.08), _m(c))
			_box(n, Vector3(0, 2.35, 0), Vector3(1.15, 0.12, 1.15), _m(c))
			_box(n, Vector3(0, 1.2, 0), Vector3(1.0, 2.1, 1.0), _m(Color(0.75, 0.9, 1.0), "", 1.0, {"alpha": 0.3}))
			_box(n, Vector3(0, 1.3, -0.4), Vector3(0.3, 0.4, 0.1), _m(Color(0.2, 0.2, 0.22)))
			_block(n, 0.55, 0.55)
		"trash_bin":
			_cyl(n, Vector3.ZERO, 0.3, 0.26, 0.9, _m(p.get("color", Color(0.3, 0.55, 0.35)), "panels", 2.0), 12)
			_cyl(n, Vector3(0, 0.9, 0), 0.32, 0.32, 0.06, _m(Color(0.25, 0.25, 0.27)), 12)
			_block(n, 0.3, 0.3)
		"hydrant":
			var red := _m(Color(0.85, 0.15, 0.15), "", 1.0, {"rough": 0.4})
			_cyl(n, Vector3.ZERO, 0.16, 0.2, 0.7, red, 10)
			_ball(n, Vector3(0, 0.72, 0), 0.17, red)
			_cyl(n, Vector3(0, 0.45, 0), 0.07, 0.07, 0.5, red, 8).rotation.z = PI / 2
		"hedge":
			var length: float = float(p.get("length", 3.0))
			var hd := _box(n, Vector3(0, 0.55, 0), Vector3(length, 1.1, 0.8), _m(Color(0.22, 0.45, 0.2), "noise", 2.0))
			hd.scale = Vector3(1, 1, 1)
			_block(n, length * 0.5, 0.4)
		"street_sign":
			_cyl(n, Vector3.ZERO, 0.04, 0.04, 2.6, _m(Color(0.55, 0.55, 0.58), "", 1.0, {"metal": 0.5}), 6)
			_box(n, Vector3(0, 2.4, 0), Vector3(1.3, 0.32, 0.04), _m(Color(0.15, 0.45, 0.3)))
			if p.has("text"):
				_label(n, str(p["text"]), Vector3(0, 2.4, 0.04), 40, Color.WHITE)
		"bike_rack":
			var metal := _m(Color(0.6, 0.6, 0.65), "", 1.0, {"metal": 0.6})
			for k in 4:
				var loop := _torus(n, Vector3((k - 1.5) * 0.4, 0.4, 0), 0.32, 0.38, metal)
				loop.rotation.y = PI / 2
				loop.rotation.z = PI / 2
		"market_crates":
			# stacked produce crates, a market-street filler
			var wood := _m(Color(0.66, 0.5, 0.3), "planks", 2.0)
			for k in 3:
				var off := Vector3((k - 1) * 0.65, 0, (k % 2) * 0.2)
				_box(n, off + Vector3(0, 0.25, 0), Vector3(0.6, 0.5, 0.45), wood)
				for f in 3:
					_ball(n, off + Vector3((f - 1) * 0.16, 0.52, 0), 0.09, _m(Color.from_hsv([0.0, 0.08, 0.25][k], 0.8, 0.9)))
			_block(n, 1.0, 0.3)
		"trophy":
			_box(n, Vector3(0, 0.5, 0), Vector3(0.7, 1.0, 0.7), _m(Color(0.3, 0.2, 0.25), "planks", 2.0))
			var gold := _m(Color(0.95, 0.75, 0.2), "", 1.0, {"metal": 0.8, "rough": 0.25})
			_cyl(n, Vector3(0, 1.0, 0), 0.15, 0.25, 0.15, gold)
			_cyl(n, Vector3(0, 1.15, 0), 0.06, 0.06, 0.3, gold)
			_cyl(n, Vector3(0, 1.45, 0), 0.3, 0.12, 0.45, gold)
			_block(n, 0.35, 0.35)
		"pillar":
			var h: float = p.get("h", 4.0)
			_cyl(n, Vector3.ZERO, 0.45, 0.55, h, _m(Color(0.9, 0.88, 0.82), "bricks", 1.0), 12)
			_box(n, Vector3(0, h + 0.15, 0), Vector3(1.3, 0.3, 1.3), _m(Color(0.85, 0.83, 0.78)))
			_block(n, 0.55, 0.55)
		"torii":
			var red := _m(Color(0.85, 0.2, 0.15))
			for x in [-2.0, 2.0]:
				_cyl(n, Vector3(x, 0, 0), 0.2, 0.25, 4.5, red, 10)
			_box(n, Vector3(0, 4.6, 0), Vector3(5.6, 0.35, 0.5), red)
			_box(n, Vector3(0, 3.8, 0), Vector3(4.6, 0.25, 0.3), red)

		"level_gate":
			var w: float = p.get("w", 4.0)
			var stone := _m(Color(0.62, 0.6, 0.58), "bricks", 1.0)
			for x in [-w / 2.0, w / 2.0]:
				_box(n, Vector3(x, 1.4, 0), Vector3(0.5, 2.8, 0.6), stone)
				_box(n, Vector3(x, 2.9, 0), Vector3(0.7, 0.2, 0.8), stone)
			var bar := _group(n, "barrier")
			_box(bar, Vector3(0, 1.25, 0), Vector3(w - 0.5, 2.5, 0.12), Mats.get_mat(Color(0.55, 0.8, 1.0), "", 1.0, {"unshaded": true, "alpha": 0.4}))
			var num := str(int(p.get("level", 1)))
			for side: float in [1.0, -1.0]:
				var l := _label(bar, num, Vector3(0, 1.3, 0.08 * side), 150, Color(1, 1, 1))
				l.double_sided = false
				l.rotation.y = 0.0 if side > 0.0 else PI
			_block(n, w / 2.0, 0.5)
		"memory_gate":
			var w: float = p.get("w", 4.0)
			var obsidian := _m(Color(0.1, 0.09, 0.12), "rock", 1.0, {"rough": 0.3})
			for x in [-w / 2.0, w / 2.0]:
				_box(n, Vector3(x, 1.5, 0), Vector3(0.45, 3.0, 0.45), obsidian)
			var bar := _group(n, "barrier")
			_box(bar, Vector3(0, 1.3, 0), Vector3(w - 0.45, 2.6, 0.1), Mats.get_mat(Color(0.02, 0.0, 0.04), "", 1.0, {"unshaded": true, "alpha": 0.85}))
			_box(bar, Vector3(0, 1.3, 0), Vector3(w - 0.3, 2.75, 0.06), Mats.get_mat(Color(0.35, 0.25, 0.5), "", 1.0, {"unshaded": true, "alpha": 0.25}))
			_block(n, w / 2.0, 0.5)
		"key_door":
			var w: float = p.get("w", 2.0)
			var frame := _m(Color(0.5, 0.48, 0.45), "bricks", 1.0)
			for x in [-w / 2.0 - 0.2, w / 2.0 + 0.2]:
				_box(n, Vector3(x, 1.4, 0), Vector3(0.4, 2.8, 0.5), frame)
			_box(n, Vector3(0, 2.95, 0), Vector3(w + 0.8, 0.3, 0.55), frame)
			var bar := _group(n, "barrier")
			_box(bar, Vector3(0, 1.3, 0), Vector3(w, 2.6, 0.15), _m(Color(0.48, 0.32, 0.18), "planks", 1.0))
			_box(bar, Vector3(w * 0.3, 1.3, 0.1), Vector3(0.18, 0.25, 0.06), _m(Color(0.95, 0.75, 0.25), "", 1.0, {"metal": 0.8}))
			_block(n, w / 2.0 + 0.2, 0.4)
		"bridge":
			var w: float = p.get("w", 2.0)
			var length: float = p.get("length", 6.0)
			var deck := _group(n, "deck")
			_box(deck, Vector3(0, 0.08, 0), Vector3(w, 0.14, length), _m(Color(0.6, 0.45, 0.28), "planks", 1.0))
			for x in [-w / 2.0 + 0.05, w / 2.0 - 0.05]:
				_box(deck, Vector3(x, 0.55, 0), Vector3(0.08, 0.08, length), _m(Color(0.45, 0.3, 0.18)))
				var posts := maxi(int(length / 1.5), 1)
				for z in posts + 1:
					_box(deck, Vector3(x, 0.3, -length / 2.0 + z * length / float(posts)), Vector3(0.08, 0.5, 0.08), _m(Color(0.45, 0.3, 0.18)))
			n.set_meta("footprint", Vector2(w / 2.0, length / 2.0))
		"floor_switch":
			_cyl(n, Vector3.ZERO, 0.7, 0.75, 0.08, _m(Color(0.4, 0.4, 0.42), "rock", 1.0))
			var plate := _group(n, "plate")
			_cyl(plate, Vector3(0, 0.08, 0), 0.5, 0.5, 0.12, _m(Color(0.75, 0.6, 0.3), "", 1.0, {"metal": 0.5}))
			_cyl(n, Vector3(0, 0.09, 0), 0.52, 0.52, 0.02, Mats.glow(Color(0.5, 1.0, 0.6))).name = "light"
			n.get_node("light").visible = false
		"breakable_rock":
			var r := _ball(n, Vector3(0, 0.6 * s, 0), 1.0 * s, _m(Color(0.55, 0.5, 0.46), "rock", 1.5))
			r.scale = Vector3(1.1, 0.8, 1.0)
			var crack := _m(Color(0.1, 0.08, 0.08))
			for a: float in [0.4, 2.0, 3.7, 5.2]:
				var c := _box(n, Vector3(cos(a) * 0.92 * s, 0.7 * s, sin(a) * 0.85 * s), Vector3(0.05, 0.75 * s, 0.4 * s), crack)
				c.rotation = Vector3(0.3, -a, 0.2)
			_block(n, 0.95 * s, 0.95 * s)
		"save_lantern":
			var stone := _m(Color(0.72, 0.7, 0.66), "rock", 1.0)
			_cyl(n, Vector3.ZERO, 0.35, 0.45, 0.25, stone, 8)
			_cyl(n, Vector3(0, 0.25, 0), 0.12, 0.15, 0.7, stone, 8)
			_box(n, Vector3(0, 1.0, 0), Vector3(0.6, 0.1, 0.6), stone)
			_box(n, Vector3(0, 1.27, 0), Vector3(0.4, 0.44, 0.4), Mats.glow(Color(1.0, 0.85, 0.55), 1.2))
			_cyl(n, Vector3(0, 1.49, 0), 0.0, 0.55, 0.38, stone, 4).rotation.y = PI / 4
			var glow := OmniLight3D.new()
			glow.light_color = Color(1.0, 0.85, 0.6)
			glow.omni_range = 4.0
			glow.light_energy = 0.8
			glow.position.y = 1.3
			n.add_child(glow)
			_block(n, 0.4, 0.4)
		"fishing_spot":
			var wood := _m(Color(0.55, 0.4, 0.25), "planks", 1.0)
			_box(n, Vector3(0, 0.1, -0.85), Vector3(0.9, 0.12, 1.9), wood)
			for x: float in [-0.4, 0.4]:
				_cyl(n, Vector3(x, -0.3, -1.7), 0.06, 0.06, 0.55, wood, 6)
			var rod := Node3D.new()
			rod.position = Vector3(0.35, 0.16, -1.5)
			rod.rotation.x = -0.9
			n.add_child(rod)
			_cyl(rod, Vector3.ZERO, 0.012, 0.025, 1.6, _m(Color(0.3, 0.2, 0.1)), 5)
			_ball(n, Vector3(0.35, 0.05, -3.0), 0.07, _m(Color(0.95, 0.2, 0.15)))
			_ball(n, Vector3(0.35, 0.11, -3.0), 0.045, _m(Color(0.97, 0.97, 0.97)))
		"food_pot":
			var iron := _m(Color(0.25, 0.25, 0.28), "", 1.0, {"metal": 0.6, "rough": 0.4})
			_cyl(n, Vector3.ZERO, 0.4, 0.34, 0.42, iron)
			_cyl(n, Vector3(0, 0.42, 0), 0.06, 0.42, 0.08, iron)
			_ball(n, Vector3(0, 0.53, 0), 0.06, _m(Color(0.5, 0.35, 0.2)))
			_block(n, 0.4, 0.4)
		_:
			push_warning("Props: unknown type '%s'" % type)
			_box(n, Vector3(0, 0.5, 0), Vector3(1, 1, 1), _m(Color(1, 0, 1)))
	return n

# --- building blocks -------------------------------------------------------

static func _m(color: Color, tex := "", scale := 1.0, extra := {}) -> StandardMaterial3D:
	return Mats.get_mat(color, tex, scale, extra)

static func _block(n: Node3D, hx: float, hz: float) -> void:
	n.set_meta("block", Vector2(hx, hz))

## A named child that fixtures animate (e.g. "barrier", "deck", "plate").
static func _group(n: Node3D, group_name: String) -> Node3D:
	var g := Node3D.new()
	g.name = group_name
	n.add_child(g)
	return g

static func _box(n: Node3D, center: Vector3, size: Vector3, m: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(n, mesh, center, m)

## Cylinder standing on `base` (bottom centre). r_top 0 makes a cone.
static func _cyl(n: Node3D, base: Vector3, r_top: float, r_bot: float, h: float, m: Material, sides := 16) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_top
	mesh.bottom_radius = r_bot
	mesh.height = h
	mesh.radial_segments = sides
	mesh.rings = 1
	return _add(n, mesh, base + Vector3(0, h / 2.0, 0), m)

static func _ball(n: Node3D, center: Vector3, r: float, m: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = 20
	mesh.rings = 10
	return _add(n, mesh, center, m)

static func _torus(n: Node3D, center: Vector3, inner: float, outer: float, m: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	return _add(n, mesh, center, m)

static func _add(n: Node3D, mesh: Mesh, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	n.add_child(mi)
	return mi

static func _label(n: Node3D, text: String, pos: Vector3, font_px: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_px
	l.pixel_size = 0.01
	l.modulate = color
	l.outline_size = 0
	l.position = pos
	n.add_child(l)
	return l
