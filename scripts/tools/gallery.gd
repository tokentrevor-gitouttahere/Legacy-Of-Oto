extends Node3D
## Visual review scene for agents and artists.
##   --gallery outfits [--page N]   dressed characters, 6 per page
##   --gallery props   [--page N]   prop library, 8 per page
##   --gallery beasts                 every Beast kind, walking in place
##   --gallery turnaround [--preset oto] [--shadow]  one outfit up close: front, side and back
##                                    (--shadow: black hair and silver for gold, as in Shadow forms)
##                                    --head: the front figure's head; --turn R: turn it R radians
##   --gallery faces --page N         the face part kit, flat: 0 eyes, 1 brows, 2 mouths, 3 mixed faces,
##                                    4-5 the 40 noses from the reference sheet
##   --gallery orbit [--preset oto] [--shadow]  the camera circles her 360, rises over her head
##                                    and sweeps down below her, then quits (record it with
##                                    Godot's --write-movie; see tools/orbit_video.py)
##   --gallery mesh --mesh res://x.obj  a raw mesh, plain grey, front and side (checking uploads)
##   --gallery anims [--shadow]      the rig's animations in a scripted reel (walk, hot walk, the
##                                    three-hit combo, the flurry), then quits; record with
##                                    tools/orbit_video.py --mode anims
##   --gallery nosesizes --page N     Oto with the long nose at sizes A-D: 0 front, 1 profile, 2 three-quarter
##   --gallery expressions [--page N] [--shadow]  Oto's head in each expression, 4 a page
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
	elif mode == "faces":
		Overlay.hint("")
		_faces(page)
	elif mode == "mesh":  # one raw OBJ, front and side: --mesh res://path.obj
		Overlay.hint("")
		_mesh(cam)
	elif mode == "anims" or mode == "moves":
		Overlay.hint("")
		_reel_table = MOVES if mode == "moves" else REEL
		_anims_setup(cam)
	elif mode == "orbit":
		Overlay.hint("")
		_orbit_setup(cam)
	elif mode == "nosesizes":
		Overlay.hint("")
		_nose_sizes(page, cam)
	elif mode == "expressions":
		Overlay.hint("")
		_expressions(page, cam)
	elif mode == "turnaround":
		var pi := args.find("--preset")
		_turnaround(args[pi + 1] if pi >= 0 and pi + 1 < args.size() else "oto", cam)
	else:
		_outfits(page, cam)

var _orbit_cam: Camera3D
var _orbit_frame := 0
const ORBIT_FPS := 30.0
const ORBIT_LOOK := Vector3(0, 0.95, 0)
const ORBIT_R := 2.6

func _orbit_setup(cam: Camera3D) -> void:
	var args := OS.get_cmdline_user_args()
	var pi := args.find("--preset")
	var ch := Outfits.make_character(args[pi + 1] if pi >= 0 and pi + 1 < args.size() else "oto")
	if "--shadow" in args:
		Outfits.set_silver(ch, true)
		for m: StandardMaterial3D in ch.get_meta("hair_mats", []):
			m.albedo_color = Color(0, 0, 0)
		for m: StandardMaterial3D in ch.get_meta("mats", []):
			m.albedo_color = (m.get_meta("base_color") as Color).lerp(Color(0.02, 0, 0.04), 0.55)
		var face: FaceRig = ch.get_meta("face", null)
		if face:
			face.set_form(1, 0.55)
	add_child(ch)
	cam.fov = 40
	_orbit_cam = cam
	_orbit_place(0.0)

## The path, by seconds: 0-8 a full turn at chest height, 8-11 up over her head, 11-15 down
## past her front to below her, 15-17 back up to level.
func _orbit_place(t: float) -> void:
	var yaw := 0.0
	var pitch := 8.0
	if t < 8.0:
		yaw = 360.0 * smoothstep(0.0, 8.0, t)
	elif t < 11.0:
		var k := smoothstep(8.0, 11.0, t)
		yaw = 360.0 + 45.0 * k
		pitch = lerpf(8.0, 82.0, k)
	elif t < 15.0:
		var k := smoothstep(11.0, 15.0, t)
		yaw = 405.0 - 45.0 * k
		pitch = lerpf(82.0, -72.0, k)
	else:
		yaw = 360.0
		pitch = lerpf(-72.0, 8.0, smoothstep(15.0, 17.0, t))
	var y := deg_to_rad(yaw)
	var pt := deg_to_rad(pitch)
	_orbit_cam.position = ORBIT_LOOK + Vector3(sin(y) * cos(pt), sin(pt), cos(y) * cos(pt)) * ORBIT_R
	_orbit_cam.look_at(ORBIT_LOOK, Vector3.UP if absf(pitch) < 89.0 else Vector3.FORWARD)

# --- the animation reel ----------------------------------------------------------------
var _reel_ch: Node3D
var _reel_ap: AnimationPlayer
var _reel_label: Label
var _reel_cue := -1
var _reel_table: Array = REEL
## [start s, caption, action, camera yaw deg, camera pitch deg, distance]
const REEL := [
	[0.0, "Walk", "walk", 30.0, 12.0, 4.2],
	[6.5, "Hot walk", "hot_walk", 30.0, 12.0, 4.2],
	[13.5, "Three-hit combo: L punch, R punch, cross", "combo", 35.0, 6.0, 2.8],
	[18.0, "Flurry (quad punch)", "flurry", -40.0, 6.0, 2.8],
	[22.0, "Combo, from above", "combo", 20.0, 55.0, 3.0],
	[26.0, "Flurry, from below", "flurry", -25.0, -30.0, 2.9],
	[30.0, "Combo into flurry, from behind", "combo_flurry", 160.0, 15.0, 3.0],
	[36.0, "", "end", 0.0, 0.0, 3.0],
]
## The kicks, flight, falls and reactions: "clip:<name>" plays that animation once, 0.4 s into its
## cue, and holds the last pose (a fall stays down). Each cue is the clip's length plus a second.
const MOVES := [
	[0.0, "Kick", "clip:kick", 35.0, 8.0, 3.2],
	[3.2, "Roundhouse kick", "clip:roundhouse_kick", 35.0, 8.0, 3.2],
	[6.7, "Flying kick (in place)", "clip:flying_kick", 60.0, 8.0, 3.4],
	[9.2, "Flying", "clip:flying", 50.0, 10.0, 4.8],
	[12.9, "Falling", "clip:falling", 30.0, 6.0, 3.6],
	[17.5, "Fall and flat impact", "clip:fall_impact", 70.0, 20.0, 5.0],
	[20.1, "Hit reaction", "clip:hit_reaction", 35.0, 8.0, 3.2],
	[22.7, "Taking a punch", "clip:taking_punch", 35.0, 8.0, 3.2],
	[29.4, "Stunned (in place)", "clip:stunned", 55.0, 20.0, 4.6],
	[32.5, "Defeated", "clip:defeated", 20.0, 8.0, 3.2],
	[40.2, "", "end", 0.0, 0.0, 3.0],
]

func _anims_setup(cam: Camera3D) -> void:
	var ch := Outfits.make_character("oto")
	if "--shadow" in OS.get_cmdline_user_args():
		Outfits.set_silver(ch, true)
		for m: StandardMaterial3D in ch.get_meta("hair_mats", []):
			m.albedo_color = Color(0, 0, 0)
		for m: StandardMaterial3D in ch.get_meta("mats", []):
			m.albedo_color = (m.get_meta("base_color") as Color).lerp(Color(0.02, 0, 0.04), 0.55)
		var face: FaceRig = ch.get_meta("face", null)
		if face:
			face.set_form(1, 0.55)
	add_child(ch)
	_reel_ch = ch
	_reel_ap = ch.get_meta("anim")
	cam.fov = 40
	_orbit_cam = cam
	var layer := CanvasLayer.new()
	add_child(layer)
	_reel_label = Label.new()
	_reel_label.position = Vector2(24, 18)
	_reel_label.add_theme_font_size_override("font_size", 26)
	_reel_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_reel_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_reel_label)

func _reel_strike(anim_name: String) -> void:
	var rig: Dictionary = _reel_ch.get_meta("rig")
	var speed := Player.FLURRY_SPEED if anim_name == "quad_punch" else Player.STRIKE_SPEED
	var hits: Array = rig["hits"][anim_name]
	_reel_ap.play(anim_name, 0.05, speed)
	_reel_ap.seek(maxf(float(hits[0]) - Player.STRIKE_LEAD * speed, 0.0), true)

func _reel_step(t: float) -> void:
	var cue := 0
	for i in _reel_table.size():
		if t >= float(_reel_table[i][0]):
			cue = i
	var c: Array = _reel_table[cue]
	var local := t - float(c[0])
	var action: String = c[2]
	if action == "end":
		get_tree().quit()
		return
	if cue != _reel_cue:
		_reel_cue = cue
		_reel_label.text = c[1]
		if action in ["walk", "hot_walk"]:
			_reel_ap.play(action, 0.2)
		else:
			_reel_ap.play("idle", 0.2)
			_reel_ch.position = Vector3.ZERO
			_reel_ch.rotation.y = 0.0
	if action in ["walk", "hot_walk"]:
		# round a circle, at the ground speed the walk was made for
		var v: float = (_reel_ch.get_meta("rig")["walk_speed"] as Dictionary)[action]
		var r := 1.6
		var a := local * v / r
		_reel_ch.position = Vector3(sin(a) * r, 0, cos(a) * r - r)
		_reel_ch.rotation.y = a + PI / 2.0
	elif action.begins_with("clip:"):
		if _orbit_frame - roundi(float(c[0]) * ORBIT_FPS) == roundi(0.4 * ORBIT_FPS):
			_reel_ap.play(action.substr(5), 0.05)
	else:
		# strikes on a beat: combo every 0.42 s, flurry once, a breath between
		var beat := [] as Array
		match action:
			"combo":
				beat = [[0.4, "l_punch"], [0.82, "r_punch"], [1.24, "cross_punch"], [2.4, "l_punch"], [2.82, "r_punch"], [3.24, "cross_punch"]]
			"flurry":
				beat = [[0.4, "quad_punch"], [2.2, "quad_punch"]]
			"combo_flurry":
				beat = [[0.4, "l_punch"], [0.82, "r_punch"], [1.24, "cross_punch"], [1.9, "quad_punch"], [4.0, "l_punch"], [4.42, "r_punch"], [4.84, "cross_punch"]]
		var frame := _orbit_frame - roundi(float(c[0]) * ORBIT_FPS)  # whole frames: no float misses
		for b: Array in beat:
			if frame == roundi(float(b[0]) * ORBIT_FPS):
				_reel_strike(b[1])
		if not _reel_ap.is_playing() or (_reel_ap.current_animation != "idle" and _reel_ap.current_animation_position > _reel_ap.current_animation_length - 0.05):
			_reel_ap.play("idle", 0.25)
	# the camera: from the cue's angle, drifting a little
	var yaw := deg_to_rad(float(c[3]) + local * 4.0)
	var pitch := deg_to_rad(float(c[4]))
	var look := Vector3(0, 1.0, -1.6) if action in ["walk", "hot_walk"] else Vector3(0, 1.0, 0)
	_orbit_cam.position = look + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * float(c[5])
	_orbit_cam.look_at(look)

func _process(_delta: float) -> void:
	if _orbit_cam and _reel_ch:
		_orbit_frame += 1
		_reel_step(_orbit_frame / ORBIT_FPS)
		return
	if _orbit_cam:
		_orbit_frame += 1
		var t := maxf(_orbit_frame / ORBIT_FPS - 1.0, 0.0)  # a second for the cloth to settle
		_orbit_place(t)
		if t > 17.2:
			get_tree().quit()
		return
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
		var hi := OS.get_cmdline_user_args().find("--hide")  # hide outfit pieces by name: a,b,c
		if hi >= 0:
			for n: String in OS.get_cmdline_user_args()[hi + 1].split(","):
				for node in ch.find_children(n, "", true, false):
					(node as Node3D).visible = false
		var ti := OS.get_cmdline_user_args().find("--turn")  # turn the front figure (radians)
		if k == 0 and ti >= 0:
			ch.rotation.y = float(OS.get_cmdline_user_args()[ti + 1])
		add_child(ch)
		_label(["front", "side", "back"][k], ch.position + Vector3(0, 1.95, 0))
	cam.position = Vector3(0, 1.0, 4.2)
	cam.look_at(Vector3(0, 0.9, 0))
	cam.fov = 42
	if "--closeup" in OS.get_cmdline_user_args():  # the front figure's left gauntlet and the plaque
		cam.position = Vector3(-0.85, 1.32, 0.75)
		cam.look_at(Vector3(-0.85, 1.05, 0.0))
		cam.fov = 40
	if "--torso" in OS.get_cmdline_user_args():  # the front figure from the neck to the knees
		cam.position = Vector3(-1.15, 1.08, 1.7)
		cam.look_at(Vector3(-1.15, 1.0, 0.0))
		cam.fov = 34
	if "--ear" in OS.get_cmdline_user_args():  # the front figure's left ear, face-on (use with --turn -1.95)
		cam.position = Vector3(-1.157, 1.49, 0.62)
		cam.look_at(Vector3(-1.157, 1.49, 0.14))
		cam.fov = 22
	var vi := OS.get_cmdline_user_args().find("--view")  # any close-up: --view px,py,pz,tx,ty,tz,fov
	if vi >= 0:
		var v := OS.get_cmdline_user_args()[vi + 1].split_floats(",")
		cam.position = Vector3(v[0], v[1], v[2])
		cam.look_at(Vector3(v[3], v[4], v[5]), Vector3.UP if absf(v[1] - v[4]) < 0.9 * Vector3(v[0], v[1], v[2]).distance_to(Vector3(v[3], v[4], v[5])) else Vector3.BACK)
		cam.fov = v[6]
	if "--hand" in OS.get_cmdline_user_args():  # the front figure's left hand and gauntlet
		cam.position = Vector3(-0.56, 1.3, 0.42)
		cam.look_at(Vector3(-0.56, 1.2, 0.0))
		cam.fov = 30
	if "--head" in OS.get_cmdline_user_args():  # the front figure's head
		cam.position = Vector3(-1.15, 1.54, 0.95)
		cam.look_at(Vector3(-1.15, 1.52, 0.0))
		cam.fov = 30

## The face kit as flat art on skin, for judging against the reference sheets.
func _faces(page: int) -> void:
	var oto := Face.look("oto")
	var dusk: Color = FaceParts.SKINS["dusk"]
	var cells: Array = []  # [title, Image]
	var on_skin := func(lk: Dictionary, slot: String, st: String, variant: String, skin: Color) -> Image:
		var layer := Face.layer_image(lk, slot, st, variant, skin)
		var img := Image.create(layer.get_width(), layer.get_height(), false, Image.FORMAT_RGBA8)
		img.fill(skin)
		img.blend_rect(layer, Rect2i(Vector2i.ZERO, layer.get_size()), Vector2i.ZERO)
		return img
	match page:
		0:
			for s: String in FaceParts.EYES:
				var lk := oto.duplicate()
				lk["eyes"] = s
				lk.erase("tune")
				cells.append(["eyes: " + s, on_skin.call(lk, "eyes", "open", "", FaceParts.SKINS["peach"])])
			for st: String in FaceParts.EYE_STATES:
				cells.append(["Oto: " + st, on_skin.call(oto, "eyes", st, "", dusk)])
			cells.append(["Oto: Shadow (void)", on_skin.call(oto, "eyes", "open", "void", dusk.lerp(Color(0.02, 0, 0.04), 0.55))])
		1:
			for s: String in FaceParts.BROWS:
				var lk := oto.duplicate()
				lk["brows"] = s
				cells.append(["brows: " + s, on_skin.call(lk, "brows", "calm", "", FaceParts.SKINS["peach"] if s != "calm" else dusk)])
			for st: String in FaceParts.BROW_STATES:
				cells.append(["Oto brows: " + st, on_skin.call(oto, "brows", st, "", dusk)])
			cells.append(["Oto brows: Shadow", on_skin.call(oto, "brows", "calm", "void", dusk.lerp(Color(0.02, 0, 0.04), 0.55))])
		2:
			for s: String in FaceParts.MOUTHS:
				var lk := oto.duplicate()
				lk["mouth"] = s
				cells.append(["mouth: " + s, on_skin.call(lk, "mouth", "closed", "", FaceParts.SKINS["peach"])])
			for st: String in FaceParts.MOUTH_SHAPES:
				cells.append(["Oto mouth: " + st, on_skin.call(oto, "mouth", st, "", dusk)])
		4, 5:  # every nose from the reference sheet, numbered in sheet order
			var all := NoseInks.names()
			for id: String in all.slice((page - 4) * 20, (page - 4) * 20 + 20):
				var lk := {"nose": "wedge", "nose_ink": id}
				cells.append(["#%d %s" % [NoseInks.DB[id]["n"], id], on_skin.call(lk, "nose", "marks", "", FaceParts.SKINS["peach"])])
		_:
			var mixes := [
				["Oto", oto, {}, "", dusk],
				["Oto: cold", oto, Face.EXPRESSIONS["cold"], "", dusk],
				["Oto: smile", oto, Face.EXPRESSIONS["smile"], "", dusk],
				["Oto: Shadow", oto, Face.EXPRESSIONS["cold"], "void", dusk.lerp(Color(0.02, 0, 0.04), 0.65)],
				["mix: tall_oval, arc, soft", {"eyes": "tall_oval", "brows": "arc", "mouth": "soft", "nose": "none"}, {}, "", FaceParts.SKINS["pale"]],
				["mix: triangle, thin, pout", {"eyes": "triangle", "brows": "thin", "mouth": "pout", "nose": "button"}, {}, "", FaceParts.SKINS["peach"]],
				["mix: sharp, slash, frown", {"eyes": "sharp", "brows": "slash", "mouth": "frown", "nose": "pointed"}, Face.EXPRESSIONS["cold"], "", FaceParts.SKINS["tan"]],
				["mix: dot, thin, cat", {"eyes": "dot", "brows": "thin", "mouth": "cat", "nose": "broad"}, {}, "", FaceParts.SKINS["green"]],
			]
			for m: Array in mixes:
				cells.append([m[0], Face.card(m[1], m[2], m[3], m[4])])
	var layer := CanvasLayer.new()
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.16, 0.18)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var cols := 5 if page in [4, 5] else 4
	var size := get_viewport().get_visible_rect().size
	var rows := ceili(cells.size() / float(cols))
	var cw := size.x / cols
	var ch := size.y / rows
	for k in cells.size():
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(cells[k][1])
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.position = Vector2((k % cols) * cw + 4, (k / cols) * ch + 4)
		tr.size = Vector2(cw - 8, ch - 26)
		layer.add_child(tr)
		var l := Label.new()
		l.text = cells[k][0]
		l.position = Vector2((k % cols) * cw + 8, (k / cols) * ch + ch - 24)
		l.add_theme_font_size_override("font_size", 15)
		layer.add_child(l)

func _mesh(cam: Camera3D) -> void:
	var args := OS.get_cmdline_user_args()
	var mesh: Mesh = load(args[args.find("--mesh") + 1])
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.75, 0.75)
	for k in 2:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = m
		mi.position = Vector3((k - 0.5) * 1.6, 0, 0)
		mi.rotation.y = [0.0, PI / 2.0][k]
		add_child(mi)
	cam.position = Vector3(0, 0.9, 3.6)
	cam.look_at(Vector3(0, 0.85, 0))
	cam.fov = 40

## Oto's long nose (#28 in profile, #33 head on) at four sizes, for the owner to pick.
const NOSE_SIZES := [["A", 40.0, 18.0, 14.0], ["B", 50.0, 22.0, 18.0], ["C", 60.0, 26.0, 22.0], ["D", 70.0, 30.0, 26.0]]

func _nose_sizes(page: int, cam: Camera3D) -> void:
	for k in NOSE_SIZES.size():
		var sz: Array = NOSE_SIZES[k]
		var lk: Dictionary = Face.look("oto").duplicate()
		lk["nose"] = "long"
		lk["nose_tune"] = {"len": sz[1], "w": sz[2], "out": sz[3], "size": float(sz[1]) * 0.88}
		Face.define_look("oto_nose_" + str(sz[0]), lk)
		var ch := Outfits.make_character("oto")
		var old: FaceRig = ch.get_meta("face")
		var outfit := old.get_parent()
		outfit.remove_child(old)
		old.free()
		var face := FaceRig.new()
		var hm := Face.head_part(ch).material_override as StandardMaterial3D
		face.setup(ch, "oto_nose_" + str(sz[0]), hm.get_meta("base_color", hm.albedo_color))
		face.set_process(false)
		outfit.add_child(face)
		ch.position = Vector3((k - 1.5) * 0.42, 0, 0)
		ch.rotation.y = [0.0, PI / 2.0, 0.6][clampi(page, 0, 2)]
		add_child(ch)
		_label("%s  %d mm" % [sz[0], int(sz[1])], Vector3(ch.position.x, 1.73, 0.3), 0.0016)
	# orthographic, so every head is seen square-on (a true profile on page 1)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.95
	cam.position = Vector3(0, 1.53, 3.0)
	cam.look_at(Vector3(0, 1.53, 0))

## Oto's head in each expression, four side by side.
func _expressions(page: int, cam: Camera3D) -> void:
	var names := Face.EXPRESSIONS.keys().slice(page * 4, page * 4 + 4)
	for k in names.size():
		var ch := Outfits.make_character("oto")
		ch.position = Vector3((k - 1.5) * 0.42, 0, 0)
		add_child(ch)
		var face: FaceRig = ch.get_meta("face")
		face.set_process(false)  # no blinking in the picture
		if "--shadow" in OS.get_cmdline_user_args():
			face.set_form(1, 0.55)
			for m: StandardMaterial3D in ch.get_meta("mats", []):
				m.albedo_color = (m.get_meta("base_color") as Color).lerp(Color(0.02, 0, 0.04), 0.55)
			for m: StandardMaterial3D in ch.get_meta("hair_mats", []):
				m.albedo_color = Color(0, 0, 0)
		face.express(names[k])
		_label(names[k], ch.position + Vector3(0, 1.75, 0), 0.0016)
	cam.position = Vector3(0, 1.55, 1.35)
	cam.look_at(Vector3(0, 1.52, 0))
	cam.fov = 40

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
