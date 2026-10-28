class_name Outfits
extends RefCounted
## Procedural clothing, hair and accessories fitted to each base mesh using
## assets/models/landmarks.json. Outfits.apply(model_wrapper, "chichi").
##
## A preset is {hair, top, bottom, feet, acc}. Each part is {"style": ..., "color": ...}.
## Colours may be Color or [r, g, b]. Hair materials are listed in the wrapper's
## "hair_mats" meta so Shadow forms can turn hair black.
##
## The meshes are unrigged T/A-poses, so pieces follow the bind pose. When the
## Mixamo rigs arrive, parent each piece to a BoneAttachment3D named by its
## "anchor" meta (head, chest, hips, upper_arm.R, ...) instead.

const LANDMARKS_PATH := "res://assets/models/landmarks.json"

const HAIR_STYLES := ["long", "saiyan_spiky", "flame", "very_long_spiky", "bun", "bob", "ponytail", "afro", "short", "bald", "turban", "keep"]
const TOP_STYLES := ["gi", "tunic", "tank", "bodysuit", "armor", "dress", "jacket", "lab_coat", "vest", "wrap_bodice", "none"]
const BOTTOM_STYLES := ["pants", "baggy", "tights", "shorts", "skirt", "skirt_panel", "wrapped", "none"]
const FEET_STYLES := ["boots", "shoes", "sandals", "none"]
const ACCESSORIES := ["sash", "belt", "wristbands", "gloves", "scouter", "headband", "cape", "mustache", "glasses", "hat_ball", "earrings", "trim", "apron", "antennae", "third_eye", "tail",
	"scapular", "wide_sash", "royal_cord", "gauntlets", "arm_wraps"]  # the last five are Oto's queen's attire (cloth physics)

const PRESETS := {
	"oto": {  # her queen's attire: docs/OTO_OUTFIT.md
		"model": "oto",
		"hair": {"style": "long", "color": [0.8, 0.8, 0.83], "form3": true},
		"top": {"style": "wrap_bodice", "color": [0.09, 0.27, 0.16], "under": [0.05, 0.17, 0.1]},
		"bottom": {"style": "wrapped", "color": [0.2, 0.24, 0.2], "wrap": [0.84, 0.8, 0.7]},
		"acc": [
			{"style": "scapular", "color": [0.14, 0.4, 0.24], "trim": [0.9, 0.72, 0.3], "sigil": [0.93, 0.73, 0.3]},
			{"style": "wide_sash", "color": [0.82, 0.78, 0.66]},
			{"style": "royal_cord", "color": [0.93, 0.73, 0.3]},
			{"style": "gauntlets", "color": [0.93, 0.73, 0.3]},
			{"style": "arm_wraps", "color": [0.86, 0.83, 0.74]},
		],
	},
	"oto_stage": {  # the earlier green bodysuit with gold trim (stage-art look)
		"model": "oto",
		"hair": {"style": "long", "color": [0.8, 0.8, 0.83], "form3": true},
		"top": {"style": "bodysuit", "color": [0.13, 0.42, 0.24], "sleeves": "short"},
		"bottom": {"style": "skirt_panel", "color": [0.13, 0.42, 0.24], "under": [0.09, 0.25, 0.15]},
		"feet": {"style": "none"},
		"acc": [{"style": "trim", "color": [0.95, 0.75, 0.25]}, {"style": "sash", "color": [0.95, 0.75, 0.25]}],
	},
	"chichi": {
		"skin": [0.98, 0.84, 0.74],
		"model": "oto",
		"hair": {"style": "bun", "color": [0.05, 0.05, 0.07]},
		"top": {"style": "dress", "color": [0.5, 0.25, 0.6], "sleeves": "short"},
		"feet": {"style": "shoes", "color": [0.3, 0.15, 0.2]},
		"acc": [{"style": "sash", "color": [0.85, 0.2, 0.25]}],
	},
	"gohan_kid": {
		"skin": [1.0, 0.84, 0.7],
		"scale": 0.55,
		"hair": {"style": "saiyan_spiky", "color": [0.05, 0.05, 0.07], "spikes": 6},
		"top": {"style": "tunic", "color": [0.45, 0.22, 0.5], "sleeves": "long"},
		"bottom": {"style": "baggy", "color": [0.45, 0.22, 0.5]},
		"feet": {"style": "shoes", "color": [0.2, 0.15, 0.1]},
		"acc": [{"style": "sash", "color": [0.85, 0.2, 0.2]}, {"style": "hat_ball", "color": [0.9, 0.5, 0.2]}, {"style": "tail", "color": [0.45, 0.3, 0.2]}],
	},
	"bulma": {
		"skin": [0.99, 0.86, 0.77],
		"model": "oto",
		"hair": {"style": "bob", "color": [0.2, 0.62, 0.68]},
		"top": {"style": "jacket", "color": [0.95, 0.55, 0.65], "sleeves": "long"},
		"bottom": {"style": "pants", "color": [0.22, 0.32, 0.6]},
		"feet": {"style": "boots", "color": [0.9, 0.9, 0.9]},
		"acc": [{"style": "belt", "color": [0.2, 0.2, 0.2]}],
	},
	"krillin": {
		"skin": [1.0, 0.83, 0.7],
		"scale": 0.82,
		"hair": {"style": "bald"},
		"top": {"style": "gi", "color": [0.95, 0.5, 0.15], "under": [0.2, 0.3, 0.7]},
		"bottom": {"style": "baggy", "color": [0.95, 0.5, 0.15]},
		"feet": {"style": "boots", "color": [0.15, 0.2, 0.45]},
		"acc": [{"style": "sash", "color": [0.2, 0.3, 0.7]}, {"style": "wristbands", "color": [0.2, 0.3, 0.7]}],
	},
	"yamcha": {
		"skin": [0.95, 0.78, 0.62],
		"hair": {"style": "saiyan_spiky", "color": [0.05, 0.05, 0.07], "spikes": 5, "length": 0.6},
		"top": {"style": "gi", "color": [0.95, 0.5, 0.15], "under": [0.2, 0.3, 0.7]},
		"bottom": {"style": "baggy", "color": [0.95, 0.5, 0.15]},
		"feet": {"style": "boots", "color": [0.15, 0.2, 0.45]},
		"acc": [{"style": "sash", "color": [0.2, 0.3, 0.7]}, {"style": "wristbands", "color": [0.2, 0.3, 0.7]}],
	},
	"tien": {
		"skin": [1.0, 0.85, 0.72],
		"hair": {"style": "bald"},
		"top": {"style": "tank", "color": [0.2, 0.55, 0.3]},
		"bottom": {"style": "baggy", "color": [0.85, 0.85, 0.82]},
		"feet": {"style": "shoes", "color": [0.2, 0.2, 0.2]},
		"acc": [{"style": "sash", "color": [0.85, 0.2, 0.2]}, {"style": "third_eye"}],
	},
	"piccolo": {
		"skin": [0.45, 0.8, 0.4],
		"hair": {"style": "turban", "color": [0.97, 0.97, 0.97]},
		"top": {"style": "gi", "color": [0.35, 0.2, 0.5], "under": [0.35, 0.2, 0.5]},
		"bottom": {"style": "baggy", "color": [0.35, 0.2, 0.5]},
		"feet": {"style": "shoes", "color": [0.45, 0.3, 0.18]},
		"acc": [{"style": "sash", "color": [0.4, 0.7, 0.9]}, {"style": "cape", "color": [0.97, 0.97, 0.97]}, {"style": "antennae", "color": [0.45, 0.8, 0.4]}],
	},
	"vegeta": {
		"skin": [1.0, 0.84, 0.7],
		"hair": {"style": "flame", "color": [0.05, 0.05, 0.07]},
		"top": {"style": "armor", "color": [0.95, 0.95, 0.92], "under": [0.15, 0.2, 0.55], "pads": [0.85, 0.7, 0.3]},
		"bottom": {"style": "tights", "color": [0.15, 0.2, 0.55]},
		"feet": {"style": "boots", "color": [0.95, 0.95, 0.92]},
		"acc": [{"style": "gloves", "color": [0.95, 0.95, 0.92]}, {"style": "scouter", "color": [0.2, 0.85, 0.3]}, {"style": "tail", "color": [0.4, 0.28, 0.2]}],
	},
	"raditz": {
		"skin": [0.95, 0.8, 0.66],
		"hair": {"style": "very_long_spiky", "color": [0.05, 0.05, 0.07]},
		"top": {"style": "armor", "color": [0.25, 0.2, 0.2], "under": [0.08, 0.08, 0.1], "pads": [0.3, 0.22, 0.2]},
		"bottom": {"style": "tights", "color": [0.08, 0.08, 0.1]},
		"feet": {"style": "boots", "color": [0.9, 0.9, 0.88]},
		"acc": [{"style": "wristbands", "color": [0.75, 0.15, 0.15]}, {"style": "scouter", "color": [0.85, 0.2, 0.2]}, {"style": "tail", "color": [0.4, 0.28, 0.2]}],
	},
	"nappa": {
		"skin": [0.95, 0.8, 0.66],
		"hair": {"style": "bald"},
		"top": {"style": "armor", "color": [0.85, 0.82, 0.7], "under": [0.1, 0.1, 0.12], "pads": [0.4, 0.3, 0.2]},
		"bottom": {"style": "tights", "color": [0.1, 0.1, 0.12]},
		"feet": {"style": "boots", "color": [0.9, 0.9, 0.88]},
		"acc": [{"style": "mustache", "color": [0.05, 0.05, 0.07]}, {"style": "wristbands", "color": [0.1, 0.1, 0.12]}, {"style": "scouter", "color": [0.2, 0.85, 0.3]}, {"style": "tail", "color": [0.4, 0.28, 0.2]}],
	},
	"hercule": {
		"skin": [0.85, 0.62, 0.45],
		"hair": {"style": "afro", "color": [0.06, 0.05, 0.05]},
		"top": {"style": "none"},
		"bottom": {"style": "baggy", "color": [0.97, 0.97, 0.95]},
		"feet": {"style": "boots", "color": [0.8, 0.15, 0.15]},
		"acc": [{"style": "mustache", "color": [0.06, 0.05, 0.05]}, {"style": "belt", "color": [0.1, 0.1, 0.1]}, {"style": "wristbands", "color": [0.85, 0.15, 0.15]}, {"style": "cape", "color": [0.95, 0.75, 0.2]}],
	},
	"life_saiyan": {
		"skin": [0.9, 0.75, 0.6],
		"hair": {"style": "saiyan_spiky", "color": [0.9, 0.88, 0.8], "spikes": 9},
		"top": {"style": "tunic", "color": [0.55, 0.35, 0.2], "sleeves": "none"},
		"bottom": {"style": "baggy", "color": [0.35, 0.22, 0.12]},
		"feet": {"style": "sandals", "color": [0.4, 0.28, 0.15]},
		"acc": [{"style": "sash", "color": [0.9, 0.6, 0.2]}, {"style": "wristbands", "color": [0.6, 0.45, 0.25]}],
	},
	"saiyan_soldier": {
		"skin": [0.9, 0.74, 0.6],
		"hair": {"style": "saiyan_spiky", "color": [0.05, 0.05, 0.07]},
		"top": {"style": "armor", "color": [0.3, 0.32, 0.3], "under": [0.12, 0.12, 0.3], "pads": [0.6, 0.5, 0.3]},
		"bottom": {"style": "tights", "color": [0.12, 0.12, 0.3]},
		"feet": {"style": "boots", "color": [0.9, 0.9, 0.88]},
		"acc": [{"style": "scouter", "color": [0.2, 0.85, 0.3]}],
	},
	"scientist": {
		"skin": [1.0, 0.86, 0.75],
		"hair": {"style": "short", "color": [0.55, 0.55, 0.58]},
		"top": {"style": "lab_coat", "color": [0.96, 0.96, 0.96], "under": [0.3, 0.4, 0.6]},
		"bottom": {"style": "pants", "color": [0.3, 0.3, 0.35]},
		"feet": {"style": "shoes", "color": [0.2, 0.15, 0.1]},
		"acc": [{"style": "glasses", "color": [0.1, 0.1, 0.1]}],
	},
	"shopkeeper": {
		"skin": [0.8, 0.6, 0.45],
		"hair": {"style": "short", "color": [0.35, 0.22, 0.12]},
		"top": {"style": "tunic", "color": [0.85, 0.85, 0.75], "sleeves": "short"},
		"bottom": {"style": "pants", "color": [0.3, 0.25, 0.2]},
		"feet": {"style": "shoes", "color": [0.2, 0.15, 0.1]},
		"acc": [{"style": "apron", "color": [0.85, 0.3, 0.25]}],
	},
	"civilian_m": {
		"skin": [0.7, 0.5, 0.35],
		"hair": {"style": "short", "color": [0.15, 0.1, 0.07]},
		"top": {"style": "jacket", "color": [0.3, 0.45, 0.65], "sleeves": "long"},
		"bottom": {"style": "pants", "color": [0.25, 0.25, 0.3]},
		"feet": {"style": "shoes", "color": [0.15, 0.1, 0.08]},
	},
	"civilian_m2": {
		"skin": [1.0, 0.85, 0.72],
		"hair": {"style": "saiyan_spiky", "color": [0.6, 0.4, 0.2], "spikes": 4, "length": 0.4},
		"top": {"style": "vest", "color": [0.85, 0.65, 0.25], "under": [0.95, 0.95, 0.95]},
		"bottom": {"style": "shorts", "color": [0.3, 0.45, 0.3]},
		"feet": {"style": "sandals", "color": [0.4, 0.3, 0.2]},
	},
	"civilian_f": {
		"skin": [0.98, 0.83, 0.7],
		"model": "oto",
		"hair": {"style": "ponytail", "color": [0.55, 0.3, 0.15]},
		"top": {"style": "dress", "color": [0.95, 0.85, 0.4], "sleeves": "short"},
		"feet": {"style": "shoes", "color": [0.7, 0.3, 0.3]},
	},
	"civilian_f2": {
		"skin": [0.6, 0.42, 0.3],
		"model": "oto",
		"hair": {"style": "bob", "color": [0.1, 0.08, 0.06]},
		"top": {"style": "jacket", "color": [0.4, 0.7, 0.75], "sleeves": "long"},
		"bottom": {"style": "skirt", "color": [0.3, 0.3, 0.45]},
		"feet": {"style": "boots", "color": [0.2, 0.2, 0.25]},
	},
	"kami": {
		"skin": [0.45, 0.8, 0.4],
		"hair": {"style": "bald"},
		"top": {"style": "dress", "color": [0.97, 0.97, 0.95], "sleeves": "long"},
		"feet": {"style": "shoes", "color": [0.45, 0.3, 0.18]},
		"acc": [{"style": "antennae", "color": [0.45, 0.8, 0.4]}, {"style": "sash", "color": [0.85, 0.2, 0.2]}],
	},
	"yajirobe": {
		"skin": [0.98, 0.8, 0.66],
		"scale": 0.86,
		"hair": {"style": "short", "color": [0.06, 0.05, 0.05]},
		"top": {"style": "gi", "color": [0.55, 0.45, 0.28], "under": [0.35, 0.3, 0.2]},
		"bottom": {"style": "baggy", "color": [0.3, 0.26, 0.18]},
		"feet": {"style": "sandals", "color": [0.4, 0.3, 0.2]},
		"acc": [{"style": "sash", "color": [0.2, 0.25, 0.4]}, {"style": "wristbands", "color": [0.2, 0.25, 0.4]}],
	},
	"master_roshi": {
		"skin": [1.0, 0.86, 0.75],
		"scale": 0.8,
		"hair": {"style": "bald"},
		"top": {"style": "vest", "color": [0.95, 0.6, 0.3], "under": [0.95, 0.6, 0.3]},
		"bottom": {"style": "shorts", "color": [0.95, 0.6, 0.3]},
		"feet": {"style": "sandals", "color": [0.5, 0.35, 0.2]},
		"acc": [{"style": "glasses", "color": [0.05, 0.05, 0.05]}, {"style": "mustache", "color": [0.97, 0.97, 0.97]}],
	},
}

static var _lm := {}

static func landmarks(model_key: String) -> Dictionary:
	if _lm.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LANDMARKS_PATH))
		_lm = parsed if parsed is Dictionary else {}
	return _lm.get(model_key, _lm.get("male_base", {}))

static func presets() -> Array:
	return PRESETS.keys()

## Base mesh a preset is designed for ("oto" = the female base).
static func model_for(preset: String) -> String:
	return PRESETS.get(preset, {}).get("model", "male_base")

## A dressed character: base mesh + outfit, scaled by the preset's "scale".
static func make_character(preset: String) -> Node3D:
	var visual := ModelLoader.make(model_for(preset))
	apply(visual, preset)
	visual.scale = Vector3.ONE * float(PRESETS.get(preset, {}).get("scale", 1.0))
	return visual

static func apply(visual: Node3D, preset: String) -> void:
	if not PRESETS.has(preset):
		push_warning("Outfits: unknown preset '%s'" % preset)
		return
	var old := visual.get_node_or_null("Outfit")
	if old:
		visual.remove_child(old)
		old.queue_free()
	var key: String = visual.get_meta("model_key", "oto")
	var b := OutfitBuilder.new(landmarks(key), float(visual.get_meta("height", 1.8)))
	var spec: Dictionary = PRESETS[preset]
	# "skin" replaces the body colour (it multiplies the male base's texture).
	if spec.has("skin"):
		for m: StandardMaterial3D in visual.get_meta("mats", []):
			m.albedo_color = _c(spec["skin"])
			m.set_meta("base_color", m.albedo_color)
	b.build(spec)
	b.root.name = "Outfit"
	visual.add_child(b.root)
	visual.set_meta("hair_mats", b.hair_mats)
	visual.set_meta("gold_mats", b.gold_mats)
	visual.set_meta("cloth_panels", b.cloth_panels)
	visual.set_meta("metal_swap", b.metal_swap)
	if b.form3_hair:
		visual.set_meta("form3_hair", b.form3_hair)

## Shadow forms: the outfit's gold turns silver (and back). Hair is handled by the Player.
static func set_silver(visual: Node3D, on: bool) -> void:
	for m: StandardMaterial3D in visual.get_meta("gold_mats", []):
		m.albedo_color = m.get_meta("silver_color") if on else m.get_meta("base_color")
		var rough: float = m.get_meta("base_rough", 0.3)
		var metal_k: float = m.get_meta("base_metal", 0.65)
		m.roughness = maxf(rough, 0.42) if on else rough  # brushed, so it does not mirror the sky
		m.metallic = minf(metal_k, 0.5) if on else metal_k
	var swap: Dictionary = visual.get_meta("metal_swap", {}) if on else {}
	for p: ClothPanel in visual.get_meta("cloth_panels", []):
		p.color_swap = swap

static func _c(v: Variant) -> Color:
	if v is Color:
		return v
	var a: Array = v
	return Color(a[0], a[1], a[2])
