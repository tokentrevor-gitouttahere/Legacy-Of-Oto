class_name KiShot
extends Node3D
## Chargeable ki projectile. Level 0-2 scales size. Hostile shots hit the player.

var direction := Vector3.FORWARD
var level := 0
var damage := 8.0
var speed := 11.0
var life := 1.5
var hostile := false
var small := false  # rapid ki blast
var color := Color(0.45, 0.25, 0.7, 0.9)

func setup(dir: Vector3, lvl: int, dmg: float) -> void:
	direction = dir
	level = lvl
	damage = dmg

func _radius() -> float:
	return 0.12 if small else 0.2 + level * 0.2

func _ready() -> void:
	if small:
		speed = 16.0
		life = 0.9
	add_child(ModelLoader.glow_sphere(_radius(), color))
	add_child(ModelLoader.glow_sphere(_radius() * 0.5, Color(0.9, 0.85, 1.0, 1.0)))

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if hostile:
		var p := get_tree().get_first_node_in_group("player") as Player
		if p and Vector2(p.position.x - position.x, p.position.z - position.z).length() <= _radius() + 0.6:
			p.hurt(damage, position - direction)
			queue_free()
		return
	for e in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("breakables"):
		var d := Vector2(e.position.x - position.x, e.position.z - position.z).length()
		if d <= _radius() + (1.0 if e is Fixture else 0.6):
			e.hurt(damage, direction, level > 0, "ki")
			if level > 0:
				Sfx.play("explosion", 1.3 - level * 0.15, -6.0 + level * 3.0)
			if level < 2:
				queue_free()
				return
