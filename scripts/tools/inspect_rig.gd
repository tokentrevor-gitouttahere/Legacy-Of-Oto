extends SceneTree
## Prints what is inside rigged character files: nodes, skeleton bones, meshes, animations.
##   godot --headless --path . --script res://scripts/tools/inspect_rig.gd -- res://a.fbx [...]

func _init() -> void:
	for path: String in OS.get_cmdline_user_args():
		var ps: PackedScene = load(path)
		var root := ps.instantiate()
		print("=== ", path)
		_walk(root, 0)
		for ap: AnimationPlayer in root.find_children("*", "AnimationPlayer", true, false):
			for n in ap.get_animation_list():
				var a := ap.get_animation(n)
				print("  anim '%s' %.2fs tracks %d loop %d" % [n, a.length, a.get_track_count(), a.loop_mode])
				for t in mini(a.get_track_count(), 4):
					print("    ", a.track_get_path(t), " type ", a.track_get_type(t))
		root.free()
	quit()

func _walk(n: Node, d: int) -> void:
	if d > 6:
		return
	var extra := ""
	if n is Skeleton3D:
		var s := n as Skeleton3D
		extra = " bones %d: %s" % [s.get_bone_count(), ", ".join(PackedStringArray(range(mini(s.get_bone_count(), 70)).map(func(i: int) -> String: return s.get_bone_name(i))))]
	elif n is MeshInstance3D:
		var mi := n as MeshInstance3D
		extra = " aabb %s skin %s" % [mi.get_aabb(), mi.skin != null]
	elif n is Node3D:
		extra = " xf %s" % (n as Node3D).transform
	print("  ".repeat(d), n.name, " <", n.get_class(), ">", extra)
	for c in n.get_children():
		_walk(c, d + 1)
