extends Node3D
## Visual review scene for agents and artists.
##   --gallery outfits [--page N]   dressed characters, 6 per page
##   --gallery props   [--page N]   prop library, 8 per page
##   --gallery beasts                 every Beast kind, walking in place
##   --gallery turnaround [--preset oto] [--shadow]  one outfit up close: front, side and back
##                                    (--shadow: black hair and silver for gold, as in Shadow forms)
## Use with tools/run.py shot to get screenshots.

const PER_PAGE := {"outfits": 6, "props": 8}

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = GameState.flags.get("gallery_mode", "outfits")
	var page: int = GameState.flags.get("gallery_page", 0)
	Overlay.fade_from(0.3)
	Overlay.hint("Left/Right: page   Up/Down: outfits, props, models, beasts   Enter: back to title")
	var i := args.find("--gallery")
	if i >= 0 and i + 1 < args.size():
		mode = args[i + 1]
	i = args.find("--page")
	if i >= 0 and i + 1 < args.size():
		page = int(args[i + 1])
	Skies.apply(self, "day")
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	floor_mi.mesh = plane
	floor_mi.material_override = Mats.get_mat(Color(0.55, 0.6, 0.55), "tiles", 0.5)
	add_child(floor_mi)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	if mode == "props":
		_props(page, cam)
	elif mode == "models":
		_models(cam)
	elif mode == "beasts":
		_beasts(cam)
	elif mode == "turnaround":
		var pi := args.find("--preset")
		_turnaround(args[pi + 1] if pi >= 0 and pi + 1 < args.size() else "oto", cam)
	else:
		_outfits(page, cam)

func _process(_delta: float) -> void:
	var mode: String = GameState.flags.get("gallery_mode", "outfits")
	var page: int = GameState.flags.get("gallery_page", 0)
	var modes := ["outfits", "props", "models", "beasts"]
	var t := Time.get_ticks_msec() / 1000.0
	for c in get_children():
		if c is Beast:
			c.animate(t * 6.0, true, false, t)
	if Input.is_action_just_pressed("menu"):
		Overlay.hint("")
		get_tree().change_scene_to_file("res://scenes/title.tscn")
		return
	var changed := false
	if Input.is_action_just_pressed("move_right"):
		page += 1
		changed = true
	if Input.is_action_just_pressed("move_left"):
		page = maxi(page - 1, 0)
		changed = true
	if Input.is_action_just_pressed("move_down") or Input.is_action_just_pressed("move_up"):
		mode = modes[(modes.find(mode) + 1) % modes.size()]
		page = 0
		changed = true
	if changed:
		var total: int = Outfits.presets().size() if mode == "outfits" else Props.types().size()
		var per: int = PER_PAGE.get(mode, 1)
		page = mini(page, maxi((total - 1) / per, 0))
		GameState.flags["gallery_mode"] = mode
		GameState.flags["gallery_page"] = page
		get_tree().reload_current_scene()

## Raw base meshes, close up on the heads (for checking landmarks).
func _models(cam: Camera3D) -> void:
	var keys := ["oto", "male_base", "male_base", "goku"]
	for k in keys.size():
		var m := ModelLoader.make(keys[k])
		m.position = Vector3((k - 1.5) * 0.9, 0, 0)
		if k == 2:
			m.get_child(0).get_node("hair").visible = false
		add_child(m)
	cam.position = Vector3(0, 1.75, 2.6)
	cam.look_at(Vector3(0, 1.5, 0))
	cam.fov = 45

func _turnaround(preset: String, cam: Camera3D) -> void:
	for k in 3:
		var ch := Outfits.make_character(preset)
		if "--shadow" in OS.get_cmdline_user_args():
			Outfits.set_silver(ch, true)
			for m: StandardMaterial3D in ch.get_meta("hair_mats", []):
				m.albedo_color = Color(0, 0, 0)
		ch.position = Vector3((k - 1) * 1.15, 0, 0)
		ch.rotation.y = [0.0, PI / 2.0, PI][k]
		add_child(ch)
		_label(["front", "side", "back"][k], ch.position + Vector3(0, 1.95, 0))
	cam.position = Vector3(0, 1.0, 4.2)
	cam.look_at(Vector3(0, 0.9, 0))
	cam.fov = 42
	if "--closeup" in OS.get_cmdline_user_args():  # the front figure's left gauntlet and the plaque
		cam.position = Vector3(-0.85, 1.32, 0.75)
		cam.look_at(Vector3(-0.85, 1.05, 0.0))
		cam.fov = 40
	if "--head" in OS.get_cmdline_user_args():  # the front figure's head
		cam.position = Vector3(-1.15, 1.54, 0.95)
		cam.look_at(Vector3(-1.15, 1.52, 0.0))
		cam.fov = 30

func _beasts(cam: Camera3D) -> void:
	for k in Beast.KINDS.size():
		var b := Beast.make(Beast.KINDS[k])
		b.position = Vector3((k - (Beast.KINDS.size() - 1) / 2.0) * 2.2, 0, 0)
		b.rotation.y = 0.6
		add_child(b)
		_label(Beast.KINDS[k], b.position + Vector3(0, b.bar_height + 0.4, 0))
	cam.position = Vector3(0, 3.2, 8.5)
	cam.look_at(Vector3(0, 0.9, 0))
	cam.fov = 50

func _outfits(page: int, cam: Camera3D) -> void:
	var keys := Outfits.presets()
	var n: int = PER_PAGE["outfits"]
	var shown := keys.slice(page * n, page * n + n)
	for k in shown.size():
		var ch := Outfits.make_character(shown[k])
		ch.position = Vector3((k - (shown.size() - 1) / 2.0) * 1.6, 0, 0)
		ch.rotation.y = 0.35 if k % 2 == 0 else -0.35
		add_child(ch)
		_label(shown[k], ch.position + Vector3(0, 2.25, 0))
	cam.position = Vector3(0, 1.6, 6.5)
	cam.look_at(Vector3(0, 1.0, 0))
	cam.fov = 50

func _props(page: int, cam: Camera3D) -> void:
	var keys := Props.types()
	var n: int = PER_PAGE["props"]
	var shown := keys.slice(page * n, page * n + n)
	var x := 0.0
	var spots: Array[float] = []
	var nodes: Array[Node3D] = []
	for k in shown:
		var p := Props.make(k)
		var aabb := _aabb(p)
		var w := maxf(aabb.size.x, 2.0)
		x += w * 0.5
		p.position = Vector3(x - aabb.get_center().x, 0, 0)
		spots.append(x)
		nodes.append(p)
		add_child(p)
		_label(k, Vector3(x, aabb.end.y + 1.0, 0), 0.03)
		x += w * 0.5 + 2.0
	for p in nodes:
		p.position.x -= x * 0.5
	for c in get_children():
		if c is Label3D:
			c.position.x -= x * 0.5
	var dist := maxf(x * 0.9, 12.0)
	cam.position = Vector3(0, dist * 0.35, dist)
	cam.look_at(Vector3(0, 2.0, 0))
	cam.fov = 50

## Bounds of a node's meshes in its own space (works before it enters the tree).
func _aabb(n: Node3D) -> AABB:
	var acc: Array[AABB] = []
	_collect(n, Transform3D.IDENTITY, acc)
	if acc.is_empty():
		return AABB()
	var box := acc[0]
	for b in acc:
		box = box.merge(b)
	return box

func _collect(n: Node, xf: Transform3D, acc: Array[AABB]) -> void:
	for c in n.get_children():
		if c is Node3D:
			var cxf: Transform3D = xf * (c as Node3D).transform
			if c is MeshInstance3D:
				acc.append(cxf * (c as MeshInstance3D).get_aabb())
			_collect(c, cxf, acc)

func _label(text: String, pos: Vector3, px := 0.006) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 48
	l.pixel_size = px
	l.outline_size = 10
	l.position = pos
	add_child(l)
