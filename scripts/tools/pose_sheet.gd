extends Node3D
## Oto holding frames of her animations side by side, to pick poses for cutscenes.
##   python tools/run.py shot pose_sheet --resolution 1600x700 --args="--poses r_punch@0.4,cross_punch@0.9,kick@1.26"
## Each entry is anim@seconds. Up to eight; labels show what each one is. --turn D turns them
## all D degrees (90: side-on, facing the viewer's right).

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--poses")
	var spec := args[i + 1] if i >= 0 and i + 1 < args.size() else "r_punch@0.4,cross_punch@0.6,cross_punch@1.13,kick@0.5,roundhouse_kick@0.5,flying@0.5"
	Skies.apply(self, "day")
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	floor_mi.mesh = plane
	floor_mi.material_override = Mats.get_mat(Color(0.55, 0.6, 0.55), "tiles", 0.5)
	add_child(floor_mi)
	var j := args.find("--turn")
	var turn := deg_to_rad(float(args[j + 1])) if j >= 0 and j + 1 < args.size() else 0.0
	var entries := spec.split(",")
	for k in entries.size():
		var parts := entries[k].split("@")
		var ch := Outfits.make_character("oto")
		ch.position = Vector3((k - (entries.size() - 1) / 2.0) * 1.3, 0, 0)
		ch.rotation.y = turn
		add_child(ch)
		var ap: AnimationPlayer = ch.get_meta("anim")
		ap.play(parts[0])
		ap.seek(float(parts[1]) if parts.size() > 1 else 0.0, true)
		ap.pause()
		var l := Label3D.new()
		l.text = entries[k]
		l.pixel_size = 0.004
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = ch.position + Vector3(0, 2.05, 0)
		l.outline_size = 8
		add_child(l)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.position = Vector3(0, 1.2, 5.2 + entries.size() * 0.35)
	cam.look_at(Vector3(0, 0.95, 0))
	cam.fov = 45
