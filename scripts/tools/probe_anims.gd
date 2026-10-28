extends SceneTree
## For each rig animation: each hand's reach ahead of the chest over time (punch impacts),
## computed straight from the tracks (no AnimationPlayer needed).

func _init() -> void:
	for path: String in OS.get_cmdline_user_args():
		var root: Node3D = (load(path) as PackedScene).instantiate()
		var sk: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
		var ap: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false)[0]
		var a := ap.get_animation("mixamo_com")
		var tracks := {}  # bone -> {pos, rot}
		for t in a.get_track_count():
			var bone := sk.find_bone(String(a.track_get_path(t).get_subname(0)))
			if bone < 0:
				continue
			if not tracks.has(bone):
				tracks[bone] = {}
			tracks[bone][a.track_get_type(t)] = t
		var n := 60
		var line := ""
		for k in n + 1:
			var time := a.length * k / n
			var glob := {}
			for b in sk.get_bone_count():
				var rest := sk.get_bone_rest(b)
				var pos := rest.origin
				var rot := rest.basis.get_rotation_quaternion()
				var tr: Dictionary = tracks.get(b, {})
				if tr.has(Animation.TYPE_POSITION_3D):
					pos = a.position_track_interpolate(tr[Animation.TYPE_POSITION_3D], time)
				if tr.has(Animation.TYPE_ROTATION_3D):
					rot = a.rotation_track_interpolate(tr[Animation.TYPE_ROTATION_3D], time)
				var local := Transform3D(Basis(rot), pos)
				var parent := sk.get_bone_parent(b)
				glob[b] = (glob[parent] as Transform3D) * local if parent >= 0 else local
			var chest: Vector3 = (glob[sk.find_bone("mixamorig_Spine2")] as Transform3D).origin
			var lf: float = ((glob[sk.find_bone("mixamorig_LeftHand")] as Transform3D).origin - chest).z / 0.017 * 1.7
			var rf: float = ((glob[sk.find_bone("mixamorig_RightHand")] as Transform3D).origin - chest).z / 0.017 * 1.7
			var ft: float = ((glob[sk.find_bone("mixamorig_LeftFoot")] as Transform3D).origin - (glob[sk.find_bone("mixamorig_RightFoot")] as Transform3D).origin).length() / 0.017 * 1.7
			line += "\n  t %.3f  L %.3f  R %.3f  F %.3f" % [time, lf, rf, ft]
		print("=== ", path.get_file(), " len %.3f" % a.length, line)
		root.free()
	quit()
