class_name FollowCam
extends Camera3D
## Fixed-angle camera that trails a target. Set focus_override to look elsewhere.

var target: Node3D
var offset := Vector3(0, 10, 7)
var focus_override := false
var focus_pos := Vector3.ZERO
var shake := 0.0

func _ready() -> void:
	fov = 40.0
	rotation_degrees = Vector3(-55, 0, 0)
	current = true

func _goal() -> Vector3:
	var base := Vector3.ZERO
	if focus_override:
		base = focus_pos
	elif is_instance_valid(target):
		base = target.position
	return base + offset * (0.55 if Controls.zoom else (3.0 if Controls.far else 1.0))

func snap() -> void:
	position = _goal()

func _process(delta: float) -> void:
	position = position.lerp(_goal(), minf(6.0 * delta, 1.0))
	shake = maxf(shake - delta * 2.0, 0.0)
	h_offset = randf_range(-1.0, 1.0) * shake * 0.3
	v_offset = randf_range(-1.0, 1.0) * shake * 0.3
