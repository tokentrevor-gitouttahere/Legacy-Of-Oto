class_name Npc
extends Node3D
## A character (or invisible marker) the player can talk to with E.
## Set on_interact to an async Callable taking the Player.

var model_key := ""  # empty = invisible marker
var tint := Color.WHITE
var model_scale := 1.0
var display_name := ""
var prompt := "Talk"
var enabled := true
var on_interact := Callable()
var visual: Node3D

func _ready() -> void:
	add_to_group("interactables")
	if model_key != "":
		visual = ModelLoader.make(model_key, tint)
		visual.scale = Vector3.ONE * model_scale
		add_child(visual)
	if display_name != "":
		var l := Label3D.new()
		l.text = display_name
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.pixel_size = 0.006
		l.no_depth_test = true
		l.outline_size = 8
		l.position.y = (1.9 * model_scale if model_key != "" else 1.2)
		add_child(l)
	if prompt == "Talk":
		prompt = "Talk to %s" % display_name if display_name != "" else "Talk"

func face(pos: Vector3) -> void:
	if visual:
		var d := pos - position
		visual.rotation.y = atan2(d.x, d.z)

func interact(player: Player) -> void:
	if on_interact.is_valid():
		face(player.position)
		await on_interact.call(player)
