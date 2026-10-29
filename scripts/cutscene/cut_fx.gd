class_name CutFx
extends RefCounted
## Effects for cutscenes (and anything else): a ki trail behind a flyer, a charging orb, a
## beam with a hot core and a soft rim, an impact flash, debris and a ring of dust. Each adds
## nodes to `root` and cleans up after itself. Shadow Saiyan colours are void-violet with a pale
## rim, never gold or fire (the story bible).

const VOID_CORE := Color(0.16, 0.04, 0.3)
const VOID_RIM := Color(0.85, 0.75, 1.0)
const VOID_GLOW := Color(0.55, 0.3, 1.0)

static func _glow(c: Color, energy := 2.0, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	return s

## Fading orbs dropped behind `who` every few frames until its "stop" meta is set.
static func trail(root: Node3D, who: Node3D, color: Color) -> Node3D:
	var t := Node3D.new()
	t.name = "Trail"
	root.add_child(t)
	var mat := _glow(color, 2.5, 0.55)
	var timer := Timer.new()
	timer.wait_time = 0.03
	timer.autostart = true
	t.add_child(timer)
	timer.timeout.connect(func() -> void:
		if t.get_meta("stop", false):
			timer.stop()
			return
		var mi := MeshInstance3D.new()
		mi.mesh = _sphere(0.22)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = who.global_position + Vector3(0, 0.9, 0)
		t.add_child(mi)
		var tw := mi.create_tween()
		tw.tween_property(mi, "scale", Vector3.ONE * 0.05, 0.45)
		tw.tween_callback(mi.queue_free))
	return t

## A ball of ki growing at a point (pass a Callable to follow a moving hand). Returns the node;
## free it, or let beam() replace it.
static func charge(root: Node3D, at: Callable, time: float, color := VOID_GLOW) -> Node3D:
	var n := Node3D.new()
	n.name = "Charge"
	root.add_child(n)
	var core := MeshInstance3D.new()
	core.mesh = _sphere(0.12)
	core.material_override = _glow(VOID_CORE, 1.0)
	n.add_child(core)
	var rim := MeshInstance3D.new()
	rim.mesh = _sphere(0.2)
	rim.material_override = _glow(color, 3.0, 0.45)
	n.add_child(rim)
	var light := OmniLight3D.new()
	light.light_color = color
	light.omni_range = 4.0
	light.light_energy = 0.0
	n.add_child(light)
	n.scale = Vector3.ONE * 0.1
	n.position = at.call()
	var tw := n.create_tween().set_parallel()
	tw.tween_property(n, "scale", Vector3.ONE * 1.25, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(light, "light_energy", 1.0, time)
	n.set_process(true)
	var follow := func() -> void:
		if is_instance_valid(n):
			n.position = at.call()
			rim.scale = Vector3.ONE * (1.0 + 0.15 * sin(Time.get_ticks_msec() * 0.03))
	root.get_tree().process_frame.connect(follow)
	n.tree_exiting.connect(func() -> void: root.get_tree().process_frame.disconnect(follow))
	return n

## A beam from `from` to `to`: it shoots out over `grow` seconds, holds for `hold`, then thins
## away. A violet core, a pale rim and a light that travels with its head.
static func beam(root: Node3D, from: Vector3, to: Vector3, grow := 0.18, hold := 0.7, width := 0.55) -> void:
	var n := Node3D.new()
	n.name = "Beam"
	root.add_child(n)
	n.global_position = from
	n.look_at_from_position(from, to, Vector3.UP)
	var length := from.distance_to(to)
	var parts: Array[MeshInstance3D] = []
	for layer: Array in [[width * 0.45, VOID_CORE, 1.0, 1.0], [width, VOID_GLOW, 3.0, 0.6], [width * 1.6, VOID_RIM, 2.0, 0.18]]:
		var cyl := CylinderMesh.new()
		cyl.top_radius = float(layer[0])
		cyl.bottom_radius = float(layer[0])
		cyl.height = 1.0
		cyl.radial_segments = 16
		var mi := MeshInstance3D.new()
		mi.mesh = cyl
		mi.material_override = _glow(layer[1], float(layer[2]), float(layer[3]))
		mi.rotation.x = -PI / 2  # the cylinder's axis along -Z, where look_at points
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(mi)
		parts.append(mi)
	var head := OmniLight3D.new()
	head.light_color = VOID_GLOW
	head.light_energy = 6.0
	head.omni_range = 9.0
	n.add_child(head)
	var muzzle := MeshInstance3D.new()
	muzzle.mesh = _sphere(width * 0.8)
	muzzle.material_override = _glow(VOID_RIM, 3.0, 0.5)
	n.add_child(muzzle)
	var set_len := func(l: float) -> void:
		for mi in parts:
			mi.scale = Vector3(1, maxf(l, 0.01), 1)
			mi.position = Vector3(0, 0, -l * 0.5)
		head.position = Vector3(0, 0, -l)
	set_len.call(0.01)
	var tw := n.create_tween()
	tw.tween_method(set_len, 0.01, length, grow)
	tw.tween_interval(hold)
	tw.tween_method(func(k: float) -> void:
		for mi in parts:
			mi.scale.x = k
			mi.scale.z = k
		muzzle.scale = Vector3.ONE * k
		head.light_energy = 6.0 * k, 1.0, 0.0, 0.35)
	tw.tween_callback(n.queue_free)
	# the beam's surface ripples while it holds
	var ripple := func() -> void:
		if is_instance_valid(n):
			var w := 1.0 + 0.08 * sin(Time.get_ticks_msec() * 0.05)
			parts[1].scale.x = parts[1].scale.x * 0.0 + w * (parts[0].scale.x)
			parts[1].scale.z = parts[1].scale.x
	root.get_tree().process_frame.connect(ripple)
	n.tree_exiting.connect(func() -> void: root.get_tree().process_frame.disconnect(ripple))

## A burst of light and a sphere that swells and fades at a point.
static func impact(root: Node3D, at: Vector3, size := 2.5, color := VOID_RIM) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _sphere(1.0)
	var m := _glow(color, 4.0, 0.85)
	mi.material_override = m
	mi.position = at
	mi.scale = Vector3.ONE * 0.2
	root.add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = 10.0
	l.omni_range = size * 6.0
	l.position = at
	root.add_child(l)
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * size, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.6)
	tw.tween_property(l, "light_energy", 0.0, 0.8)
	tw.chain().tween_callback(func() -> void:
		mi.queue_free()
		l.queue_free())

## Chunks thrown out from a point, tumbling and falling.
static func debris(root: Node3D, at: Vector3, color: Color, count := 14, force := 9.0) -> void:
	var m := Mats.get_mat(color, "strata", 0.8)
	for k in count:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		var s := randf_range(0.2, 0.6)
		box.size = Vector3(s, s * randf_range(0.6, 1.2), s)
		mi.mesh = box
		mi.material_override = m
		mi.position = at
		root.add_child(mi)
		var dir := Vector3(randf_range(-1, 1), randf_range(0.6, 1.6), randf_range(-1, 1)).normalized()
		var vel := dir * force * randf_range(0.6, 1.2)
		var spin := Vector3(randf(), randf(), randf()) * 8.0
		var t0 := Time.get_ticks_msec()
		var step := func() -> void:
			if not is_instance_valid(mi):
				return
			var dt := 1.0 / 60.0
			vel.y -= 18.0 * dt
			mi.position += vel * dt
			mi.rotation += spin * dt
			if mi.position.y < 0.1:
				mi.position.y = 0.1
				vel *= 0.4
				vel.y = absf(vel.y) * 0.3
			if Time.get_ticks_msec() - t0 > 2600:
				mi.queue_free()
		root.get_tree().process_frame.connect(step)
		mi.tree_exiting.connect(func() -> void: root.get_tree().process_frame.disconnect(step))

## A flat ring of dust spreading over the ground.
static func dust_ring(root: Node3D, at: Vector3, radius := 6.0, color := Color(0.85, 0.7, 0.55)) -> void:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.7
	t.outer_radius = 1.0
	mi.mesh = t
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.position = Vector3(at.x, 0.15, at.z)
	mi.scale = Vector3(0.5, 0.25, 0.5)
	root.add_child(mi)
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3(radius, 0.6, radius), 0.9).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 1.0)
	tw.chain().tween_callback(mi.queue_free)

## A soft violet glow round a character (a hush, not a blaze), pulsing; free it to stop.
static func aura(root: Node3D, who: Node3D, color := VOID_GLOW) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _sphere(1.0)
	var m := _glow(color, 1.0, 0.05)
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD  # it brightens what is behind; it never hides her
	m.cull_mode = BaseMaterial3D.CULL_FRONT  # only the far side: a halo round her, not a film over her
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(0.7, 1.15, 0.7)
	root.add_child(mi)
	var follow := func() -> void:
		if is_instance_valid(mi) and is_instance_valid(who):
			mi.global_position = who.global_position + Vector3(0, 1.0, 0)
			var k := 1.0 + 0.06 * sin(Time.get_ticks_msec() * 0.008)
			mi.scale = Vector3(0.7 * k, 1.15 * k, 0.7 * k)
	root.get_tree().process_frame.connect(follow)
	mi.tree_exiting.connect(func() -> void: root.get_tree().process_frame.disconnect(follow))
	return mi
