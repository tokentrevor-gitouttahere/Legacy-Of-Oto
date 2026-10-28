class_name FaceRig
extends Node3D
## The live face on a character (see face.gd): its layers and their current states, blinking,
## the mouth while the character speaks, and Shadow forms. Outfits.apply adds it under the
## outfit as "Face" and sets the visual's "face" meta to it.

const BLINK := [["half", 0.05], ["closed", 0.08], ["half", 0.05]]
const VISEMES := ["ah", "oh", "ee", "wide", "closed"]

var look_id := ""
var look: Dictionary
var base_skin: Color
var skin: Color
var speaker := ""        # the Overlay speaker name this face talks for ("Oto")
var variant := ""        # "void" in Shadow forms
var state := {"eyes": "open", "brows": "calm", "mouth": "closed", "nose": "marks", "ear_l": "on", "ear_r": "on"}
var expression := "neutral"
var talking := false
var layers := {}         # slot -> MeshInstance3D
var _shown := {}         # slot -> the state its texture shows now
var _blink_in := 0.0
var _blink_t := -1.0
var _talk_in := 0.0
var _alpha := 1.0

## Build the face for `visual` (a ModelLoader wrapper) with look `id`.
func setup(visual: Node3D, id: String, skin_color: Color) -> void:
	name = "Face"
	look_id = id
	look = Face.look(id)
	base_skin = skin_color
	skin = skin_color
	var frame := Face.head_frame(visual)
	var model_key: String = visual.get_meta("model_key", "oto")
	for slot: String in Face.REGIONS.keys() + ["ear_l", "ear_r"]:
		var mesh: Mesh
		if slot.begins_with("ear"):
			mesh = Face.ear_plate(frame, model_key, 1.0 if slot == "ear_l" else -1.0)
			if mesh == null:
				continue
		else:
			mesh = Face.plate(frame, Face.REGIONS[slot], Face.LIFT[slot])
		var mi := MeshInstance3D.new()
		mi.name = slot
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.8
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		mi.material_override = m
		add_child(mi)
		layers[slot] = mi
	for part: String in ["nose", "chin"]:
		var table: Dictionary = FaceParts.NOSES if part == "nose" else FaceParts.CHINS
		var spec: Dictionary = (table.get(look.get(part, ""), {}) as Dictionary).duplicate()
		if part == "nose" and not spec.is_empty():
			spec.merge(look.get("nose_tune", {}), true)
		var b := Face.bump(frame, spec)
		if b:
			b.name = part + "_shape"
			add_child(b)
	_next_blink()
	_refresh()
	_prewarm()

## Draw the blink and talking frames now, not mid-game (textures are cached per look and skin).
func _prewarm() -> void:
	for st: String in ["half", "closed"]:
		Face.texture(look_id, "eyes", st, variant, skin)
	for st: String in VISEMES:
		Face.texture(look_id, "mouth", st, variant, skin)

func _ready() -> void:
	if speaker != "" and Overlay.has_signal("talking"):
		Overlay.connect("talking", _on_talking)

func _exit_tree() -> void:
	if Overlay.has_signal("talking") and Overlay.is_connected("talking", _on_talking):
		Overlay.disconnect("talking", _on_talking)

func _on_talking(who: String, on: bool) -> void:
	if who != speaker:
		return
	if on:
		start_talking()
	else:
		stop_talking()

# --- API --------------------------------------------------------------------------------

func express(id: String) -> void:
	if not Face.EXPRESSIONS.has(id):
		push_warning("FaceRig: unknown expression '%s'" % id)
		return
	expression = id
	for slot: String in Face.EXPRESSIONS[id]:
		state[slot] = Face.EXPRESSIONS[id][slot]
	_refresh()

func set_part(slot: String, st: String) -> void:
	state[slot] = st
	_refresh()

func start_talking() -> void:
	talking = true
	_talk_in = 0.0

func stop_talking() -> void:
	talking = false
	_show("mouth", state["mouth"])

func blink() -> void:
	if state["eyes"] in ["closed", "happy"]:
		return
	_blink_t = 0.0

## Shadow forms: void eyes and black brows, the skin darkened like the body's, and in the
## deeper forms the cold look.
func set_form(form: int, tint: float) -> void:
	variant = "void" if form > 0 else ""
	skin = base_skin.lerp(Color(0.02, 0.0, 0.04), tint)
	express("cold" if form >= 2 else "neutral")
	_prewarm()

## The Void's flicker: the face fades with the body.
func set_alpha(a: float) -> void:
	_alpha = a
	for mi: MeshInstance3D in layers.values():
		var m := mi.material_override as StandardMaterial3D
		m.albedo_color.a = a

# --- running ----------------------------------------------------------------------------

func _process(delta: float) -> void:
	_blink_in -= delta
	if _blink_in <= 0.0 and _blink_t < 0.0:
		blink()
		_next_blink()
	if _blink_t >= 0.0:
		_blink_t += delta
		var t := _blink_t
		var shown := ""
		for step: Array in BLINK:
			if t < float(step[1]):
				shown = step[0]
				break
			t -= float(step[1])
		if shown == "":
			_blink_t = -1.0
			shown = state["eyes"]
		_show("eyes", shown)
	if talking:
		_talk_in -= delta
		if _talk_in <= 0.0:
			var cur: String = _shown.get("mouth", "")
			var pick: String = cur
			while pick == cur:
				pick = VISEMES[randi() % VISEMES.size()]
			_show("mouth", pick)
			_talk_in = randf_range(0.09, 0.14)

func _next_blink() -> void:
	var r: Array = look.get("blink", [4.0, 7.0])
	_blink_in = randf_range(float(r[0]), float(r[1]))

func _refresh() -> void:
	for slot: String in layers:
		if slot == "mouth" and talking:
			continue
		if slot == "eyes" and _blink_t >= 0.0:
			continue
		_show(slot, state[slot], true)

func _show(slot: String, st: String, force := false) -> void:
	if not force and _shown.get(slot, "") == st:
		return
	_shown[slot] = st
	var mi: MeshInstance3D = layers[slot]
	var tex := Face.texture(look_id, "ears" if slot.begins_with("ear") else slot, st, variant, skin)
	mi.visible = tex != null
	(mi.material_override as StandardMaterial3D).albedo_texture = tex

## The state a layer shows right now (blinks and talking included).
func shown(slot: String) -> String:
	return _shown.get(slot, "")
