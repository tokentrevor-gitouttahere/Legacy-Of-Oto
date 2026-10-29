extends Node3D
## UI showcase for screenshots: the dialogue box, narration, toasts, prompts, title cards and
## the portrait sheet of every woman. Over a real location so the panels are judged in place.
##   python tools/run.py shot ui_preview --frames 90 --args="--ui dialogue --speaker Oto"
##   --ui dialogue|narration|toast|prompt|card|portraits   --speaker <name>   --page N (portraits)

const LINES := {
	"Oto": "Oto|The rice was good. I would like to know where the rest of it went.",
	"_": "Speaker|Champion Dogs! The only hot dog the champion himself has never eaten!",
}

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := _arg(args, "--ui", "dialogue")
	var who := _arg(args, "--speaker", "Oto")
	Overlay.auto = false
	Overlay.fade_from(0.01)
	if mode == "portraits":
		_portraits(int(_arg(args, "--page", "0")))
		return
	_backdrop()
	match mode:
		"dialogue":
			var line: String = LINES["Oto"] if who == "Oto" else "%s|%s" % [who, LINES["_"].split("|")[1]]
			Overlay.say([line])
		"narration":
			Overlay.say(["She eats the Bakery melon bread. All of it. Then she looks at the tray as if it owes her an explanation."])
		"toast":
			Overlay.toast("New dish: Bakery melon bread  (4 / 8)", 99.0)
			Overlay.set_prompt("E: Talk to Lottie")
		"prompt":
			Overlay.set_prompt("E: Talk to Mei")
		"card":
			Overlay.card("Mt. Paozu\nThe day after the light", 99.0)

func _arg(args: PackedStringArray, key: String, def: String) -> String:
	var i := args.find(key)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else def

## A sunny field with a few townswomen, so the panels are seen over a game picture.
func _backdrop() -> void:
	Skies.apply(self, "day")
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	floor_mi.mesh = plane
	floor_mi.material_override = Mats.get_mat(Color(0.42, 0.6, 0.32), "grass", 0.5)
	add_child(floor_mi)
	var ids := ["oto", "woman_mei", "woman_lottie"]
	for k in ids.size():
		var ch := Outfits.make_character(ids[k])
		ch.position = Vector3((k - 1) * 1.5, 0, -k * 0.4)
		ch.rotation.y = [0.2, -0.3, 0.4][k]
		add_child(ch)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.position = Vector3(0, 1.7, 4.6)
	cam.look_at(Vector3(0, 1.2, 0))
	cam.fov = 45

## Every woman's portrait, 24 to a page (8 x 3), with her name and role; every third talks.
func _portraits(page: int) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = UiKit.INK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var ids := NpcWomen.ids()
	if page == 0:
		ids.insert(0, "oto")
	var per := 24
	var shown := ids.slice(page * per, page * per + per)
	var vs := get_viewport().get_visible_rect().size
	var cols := 8
	var cw := vs.x / cols
	var chh := vs.y / 3.0
	for k in shown.size():
		var id: String = shown[k]
		var who := "Oto" if id == "oto" else str(NpcWomen.spec(id)["name"])
		var p := Portrait.new()
		p.size = Vector2(cw - 20.0, chh - 62.0)
		p.position = Vector2((k % cols) * cw + 10.0, (k / cols) * chh + 8.0)
		layer.add_child(p)
		p.set_speaker(who)
		p.set_talking(k % 3 == 1)
		var l := Label.new()
		l.text = who + ("" if id == "oto" else "\n" + str(NpcWomen.spec(id).get("role", "")))
		l.position = Vector2((k % cols) * cw + 6.0, (k / cols) * chh + chh - 54.0)
		l.size = Vector2(cw - 12.0, 50.0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.clip_text = true
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", UiKit.speaker_color(who))
		layer.add_child(l)
