class_name NpcWomen
extends RefCounted
## The women of the world: townsfolk, cooks, fighters and travellers on the female base, each a
## face look and an outfit. DESIGNS are the hand-made women; COLORWAYS recolour each one into
## three more (new clothes and hair colours, the same cut and face shape, a different person
## with her own name). Presets are "woman_<id>" and "woman_<id>_<n>" (n = 2..4); the face look
## has the same id. Outfits.preset_spec() and Face.look() find them here.
##
## None of them wears Oto's build or any piece of her attire (Outfits.OTO_ONLY): a woman's
## body is the plain base or one of the editor's other builds. dev_tests checks both.
##
## A design: name, role, skin, build ("" = plain base), face (a Face look), hair, top,
## bottom, feet, acc (Outfits styles).

const DESIGNS := {
	"mei": {"name": "Mei", "role": "noodle cook, West City",
		"skin": [0.98, 0.84, 0.72], "build": "curvy",
		"face": {"eyes": "wide_round", "brows": "arc", "mouth": "soft", "nose": "button", "chin": "round",
			"pal": {"iris": [0.28, 0.16, 0.08], "iris_lo": [0.5, 0.3, 0.14], "brow": [0.12, 0.08, 0.06]}},
		"hair": {"style": "bun", "color": [0.1, 0.07, 0.06]},
		"top": {"style": "tunic", "color": [0.85, 0.22, 0.2], "sleeves": "short"},
		"bottom": {"style": "pants", "color": [0.15, 0.15, 0.2]},
		"feet": {"style": "shoes", "color": [0.12, 0.1, 0.1]},
		"acc": [{"style": "apron", "color": [0.96, 0.94, 0.9]}, {"style": "headband", "color": [0.96, 0.94, 0.9]}]},
	"ayame": {"name": "Ayame", "role": "Capsule Corp engineer",
		"skin": [0.99, 0.87, 0.78], "build": "slim",
		"face": {"eyes": "almond", "brows": "thin", "mouth": "still", "nose": "pointed", "chin": "pointed",
			"tune": {"w": 54.0, "lid_h": 22.0}, "pal": {"iris": [0.1, 0.28, 0.35], "iris_lo": [0.2, 0.5, 0.6], "brow": [0.2, 0.12, 0.08]}},
		"hair": {"style": "ponytail", "color": [0.45, 0.22, 0.12]},
		"top": {"style": "jacket", "color": [0.95, 0.93, 0.88], "sleeves": "long"},
		"bottom": {"style": "pants", "color": [0.25, 0.3, 0.42]},
		"feet": {"style": "boots", "color": [0.3, 0.3, 0.32]},
		"acc": [{"style": "belt", "color": [0.2, 0.2, 0.22]}, {"style": "glasses", "color": [0.15, 0.15, 0.18]}, {"style": "gloves", "color": [0.95, 0.6, 0.2]}]},
	"kesi": {"name": "Kesi", "role": "courier, West City",
		"skin": [0.47, 0.3, 0.2], "build": "",
		"face": {"eyes": "triangle", "brows": "calm", "mouth": "pout", "nose": "broad", "chin": "soft",
			"pal": {"iris": [0.16, 0.09, 0.04], "iris_lo": [0.38, 0.22, 0.1], "brow": [0.06, 0.04, 0.03], "glint": [1.0, 1.0, 1.0]}},
		"hair": {"style": "afro", "color": [0.06, 0.05, 0.05]},
		"top": {"style": "vest", "color": [0.95, 0.75, 0.15], "under": [0.15, 0.15, 0.18]},
		"bottom": {"style": "shorts", "color": [0.2, 0.22, 0.3]},
		"feet": {"style": "boots", "color": [0.95, 0.95, 0.92]},
		"acc": [{"style": "wristbands", "color": [0.95, 0.75, 0.15]}, {"style": "earrings", "color": [0.95, 0.8, 0.35]}]},
	"riko": {"name": "Riko", "role": "city police",
		"skin": [0.96, 0.8, 0.66], "build": "",
		"face": {"eyes": "sharp", "brows": "thin", "mouth": "flat", "nose": "wedge", "chin": "square",
			"tune": {"tilt": 0.18, "ink": [3.6, 6.0]}, "pal": {"iris": [0.08, 0.12, 0.2], "iris_lo": [0.2, 0.28, 0.45], "brow": [0.08, 0.06, 0.05]}},
		"hair": {"style": "bob", "color": [0.07, 0.07, 0.1]},
		"top": {"style": "jacket", "color": [0.14, 0.2, 0.42], "sleeves": "long"},
		"bottom": {"style": "pants", "color": [0.14, 0.2, 0.42]},
		"feet": {"style": "boots", "color": [0.08, 0.08, 0.1]},
		"acc": [{"style": "belt", "color": [0.08, 0.08, 0.1]}, {"style": "gloves", "color": [0.95, 0.95, 0.95]}]},
	"hana": {"name": "Hana", "role": "florist",
		"skin": [1.0, 0.88, 0.8], "build": "curvy",
		"face": {"eyes": "tall_oval", "brows": "arc", "mouth": "soft", "nose": "none", "chin": "round",
			"pal": {"iris": [0.24, 0.32, 0.12], "iris_lo": [0.45, 0.58, 0.25], "brow": [0.45, 0.28, 0.16], "lip": [0.85, 0.45, 0.5]}},
		"hair": {"style": "long", "color": [0.72, 0.45, 0.25], "shell": true, "length": 1.05},
		"top": {"style": "dress", "color": [0.98, 0.8, 0.85], "sleeves": "short"},
		"feet": {"style": "sandals", "color": [0.8, 0.6, 0.4]},
		"acc": [{"style": "sash", "color": [0.4, 0.65, 0.35]}, {"style": "apron", "color": [0.55, 0.75, 0.45]}]},
	"tamsin": {"name": "Tamsin", "role": "tournament fighter",
		"skin": [0.85, 0.65, 0.5], "build": "",
		"face": {"eyes": "sharp", "brows": "slash", "mouth": "flat", "nose": "pointed", "chin": "pointed",
			"tune": {"w": 50.0, "lid_h": 22.0, "lashes": 1, "lash_len": 4.0}, "pal": {"iris": [0.35, 0.12, 0.08], "iris_lo": [0.6, 0.25, 0.12], "brow": [0.1, 0.06, 0.05]}},
		"hair": {"style": "saiyan_spiky", "color": [0.12, 0.08, 0.06], "spikes": 5, "length": 0.45},
		"top": {"style": "gi", "color": [0.2, 0.5, 0.75], "under": [0.1, 0.1, 0.12]},
		"bottom": {"style": "baggy", "color": [0.2, 0.5, 0.75]},
		"feet": {"style": "boots", "color": [0.1, 0.1, 0.12]},
		"acc": [{"style": "sash", "color": [0.1, 0.1, 0.12]}, {"style": "wristbands", "color": [0.85, 0.2, 0.2]}, {"style": "headband", "color": [0.85, 0.2, 0.2]}]},
	"nadia": {"name": "Nadia", "role": "desert nomad",
		"skin": [0.66, 0.46, 0.32], "build": "slim",
		"face": {"eyes": "almond", "brows": "calm", "mouth": "still", "nose": "long", "chin": "soft",
			"nose_tune": {"len": 44.0, "w": 18.0, "out": 13.0, "size": 38.0}, "tune": {"w": 56.0, "lid_h": 21.0},
			"pal": {"iris": [0.3, 0.2, 0.06], "iris_lo": [0.65, 0.45, 0.15], "brow": [0.1, 0.07, 0.05]}},
		"hair": {"style": "turban", "color": [0.85, 0.72, 0.5]},
		"top": {"style": "tunic", "color": [0.78, 0.62, 0.42], "sleeves": "long"},
		"bottom": {"style": "baggy", "color": [0.6, 0.45, 0.3]},
		"feet": {"style": "sandals", "color": [0.4, 0.28, 0.16]},
		"acc": [{"style": "sash", "color": [0.2, 0.45, 0.55]}, {"style": "earrings", "color": [0.95, 0.8, 0.35]}]},
	"pia": {"name": "Pia", "role": "school student",
		"skin": [0.99, 0.86, 0.76], "build": "slim",
		"face": {"eyes": "triangle", "brows": "thin", "mouth": "cat", "nose": "button", "chin": "round",
			"pal": {"iris": [0.12, 0.2, 0.45], "iris_lo": [0.3, 0.45, 0.8], "brow": [0.12, 0.08, 0.06]}},
		"hair": {"style": "ponytail", "color": [0.1, 0.08, 0.07]},
		"top": {"style": "tunic", "color": [0.95, 0.95, 0.97], "sleeves": "short"},
		"bottom": {"style": "skirt", "color": [0.18, 0.2, 0.4]},
		"feet": {"style": "shoes", "color": [0.2, 0.12, 0.08]},
		"acc": [{"style": "trim", "color": [0.18, 0.2, 0.4]}]},
	"odette": {"name": "Odette", "role": "pilot",
		"skin": [0.93, 0.76, 0.62], "build": "",
		"face": {"eyes": "almond", "brows": "arc", "mouth": "still", "nose": "wedge", "chin": "pointed",
			"pal": {"iris": [0.22, 0.3, 0.32], "iris_lo": [0.45, 0.58, 0.6], "brow": [0.55, 0.42, 0.25]}},
		"hair": {"style": "short", "color": [0.85, 0.7, 0.42]},
		"top": {"style": "bodysuit", "color": [0.32, 0.36, 0.25], "sleeves": "long"},
		"bottom": {"style": "pants", "color": [0.32, 0.36, 0.25]},
		"feet": {"style": "boots", "color": [0.3, 0.2, 0.12]},
		"acc": [{"style": "belt", "color": [0.3, 0.2, 0.12]}, {"style": "scouter", "color": [0.85, 0.55, 0.2]}, {"style": "gloves", "color": [0.3, 0.2, 0.12]}]},
	"grandma_suki": {"name": "Grandma Suki", "role": "retired cook, Paozu",
		"skin": [0.95, 0.8, 0.68], "build": "",
		"face": {"eyes": "dot", "brows": "thin", "mouth": "soft", "nose": "button", "chin": "round",
			"pal": {"brow": [0.75, 0.75, 0.78]}},
		"hair": {"style": "bun", "color": [0.88, 0.88, 0.9]},
		"top": {"style": "dress", "color": [0.42, 0.3, 0.5], "sleeves": "long"},
		"feet": {"style": "sandals", "color": [0.3, 0.22, 0.15]},
		"acc": [{"style": "apron", "color": [0.85, 0.8, 0.65]}, {"style": "glasses", "color": [0.6, 0.45, 0.2]}]},
	"lune": {"name": "Lune", "role": "idol singer",
		"skin": [1.0, 0.89, 0.82], "build": "curvy",
		"face": {"eyes": "wide_round", "brows": "arc", "mouth": "pout", "nose": "none", "chin": "pointed",
			"tune": {"lashes": 4, "lash_len": 8.0}, "pal": {"iris": [0.45, 0.12, 0.42], "iris_lo": [0.85, 0.35, 0.75], "brow": [0.6, 0.3, 0.5], "lip": [0.92, 0.38, 0.55]}},
		"hair": {"style": "long", "color": [0.95, 0.55, 0.72], "shell": true, "length": 0.95},
		"top": {"style": "dress", "color": [0.55, 0.85, 0.95], "sleeves": "none"},
		"feet": {"style": "boots", "color": [0.98, 0.98, 0.98]},
		"acc": [{"style": "trim", "color": [0.98, 0.98, 0.98]}, {"style": "earrings", "color": [0.98, 0.9, 0.5]}, {"style": "gloves", "color": [0.98, 0.98, 0.98]}]},
	"bryn": {"name": "Bryn", "role": "mechanic",
		"skin": [0.9, 0.72, 0.58], "build": "full_figure",
		"face": {"eyes": "triangle", "brows": "slash", "mouth": "flat", "nose": "broad", "chin": "square",
			"pal": {"iris": [0.2, 0.15, 0.1], "iris_lo": [0.4, 0.3, 0.18], "brow": [0.35, 0.15, 0.08]}},
		"hair": {"style": "ponytail", "color": [0.55, 0.18, 0.08]},
		"top": {"style": "tank", "color": [0.92, 0.9, 0.85]},
		"bottom": {"style": "baggy", "color": [0.35, 0.42, 0.28]},
		"feet": {"style": "boots", "color": [0.25, 0.18, 0.12]},
		"acc": [{"style": "belt", "color": [0.45, 0.32, 0.18]}, {"style": "gloves", "color": [0.85, 0.75, 0.2]}, {"style": "headband", "color": [0.85, 0.2, 0.2]}]},
	"sora": {"name": "Sora", "role": "shrine keeper",
		"skin": [1.0, 0.88, 0.8], "build": "",
		"face": {"eyes": "almond", "brows": "calm", "mouth": "still", "nose": "none", "chin": "soft",
			"tune": {"w": 52.0, "lid_h": 18.0}, "pal": {"iris": [0.1, 0.08, 0.08], "iris_lo": [0.25, 0.2, 0.2], "brow": [0.06, 0.05, 0.05]}},
		"hair": {"style": "long", "color": [0.04, 0.04, 0.06], "shell": true, "length": 0.85},
		"top": {"style": "tunic", "color": [0.97, 0.97, 0.95], "sleeves": "long"},
		"bottom": {"style": "baggy", "color": [0.78, 0.12, 0.15]},
		"feet": {"style": "sandals", "color": [0.9, 0.88, 0.85]},
		"acc": [{"style": "sash", "color": [0.78, 0.12, 0.15]}]},
	"zara": {"name": "Zara", "role": "bodyguard",
		"skin": [0.32, 0.2, 0.14], "build": "",
		"face": {"eyes": "sharp", "brows": "thin", "mouth": "still", "nose": "broad", "chin": "pointed",
			"tune": {"w": 52.0, "tilt": 0.2}, "pal": {"iris": [0.12, 0.07, 0.04], "iris_lo": [0.3, 0.18, 0.1], "brow": [0.04, 0.03, 0.03], "glint": [1.0, 1.0, 1.0]}},
		"hair": {"style": "short", "color": [0.05, 0.04, 0.04]},
		"top": {"style": "jacket", "color": [0.08, 0.08, 0.1], "sleeves": "long"},
		"bottom": {"style": "pants", "color": [0.08, 0.08, 0.1]},
		"feet": {"style": "shoes", "color": [0.05, 0.05, 0.06]},
		"acc": [{"style": "glasses", "color": [0.02, 0.02, 0.02]}, {"style": "earrings", "color": [0.9, 0.9, 0.95]}]},
	"wren": {"name": "Wren", "role": "fisher, the coast",
		"skin": [0.82, 0.6, 0.42], "build": "",
		"face": {"eyes": "wide_round", "brows": "calm", "mouth": "soft", "nose": "button", "chin": "soft",
			"pal": {"iris": [0.15, 0.25, 0.3], "iris_lo": [0.3, 0.5, 0.55], "brow": [0.3, 0.2, 0.12]}},
		"hair": {"style": "bob", "color": [0.4, 0.26, 0.14]},
		"top": {"style": "vest", "color": [0.85, 0.5, 0.18], "under": [0.88, 0.86, 0.8]},
		"bottom": {"style": "shorts", "color": [0.22, 0.3, 0.38]},
		"feet": {"style": "boots", "color": [0.85, 0.75, 0.2]},
		"acc": [{"style": "hat_ball", "color": [0.85, 0.5, 0.18]}]},
	"ilse": {"name": "Ilse", "role": "lab scientist",
		"skin": [1.0, 0.9, 0.84], "build": "",
		"face": {"eyes": "tall_oval", "brows": "thin", "mouth": "flat", "nose": "pointed", "chin": "pointed",
			"pal": {"iris": [0.2, 0.3, 0.45], "iris_lo": [0.45, 0.6, 0.8], "brow": [0.7, 0.62, 0.45]}},
		"hair": {"style": "bun", "color": [0.9, 0.82, 0.6]},
		"top": {"style": "lab_coat", "color": [0.97, 0.97, 0.97], "under": [0.55, 0.25, 0.35]},
		"bottom": {"style": "skirt", "color": [0.25, 0.25, 0.3]},
		"feet": {"style": "shoes", "color": [0.1, 0.1, 0.12]},
		"acc": [{"style": "glasses", "color": [0.6, 0.12, 0.15]}]},
	"marisol": {"name": "Marisol", "role": "cafe owner",
		"skin": [0.8, 0.58, 0.4], "build": "full_figure",
		"face": {"eyes": "wide_round", "brows": "arc", "mouth": "soft", "nose": "broad", "chin": "round",
			"tune": {"lashes": 3, "lash_len": 7.0}, "pal": {"iris": [0.22, 0.12, 0.05], "iris_lo": [0.45, 0.25, 0.1], "brow": [0.1, 0.06, 0.04], "lip": [0.62, 0.22, 0.25]}},
		"hair": {"style": "long", "color": [0.12, 0.07, 0.05], "shell": true, "length": 1.1},
		"top": {"style": "dress", "color": [0.62, 0.18, 0.22], "sleeves": "short"},
		"feet": {"style": "shoes", "color": [0.2, 0.1, 0.08]},
		"acc": [{"style": "apron", "color": [0.95, 0.92, 0.85]}, {"style": "earrings", "color": [0.95, 0.8, 0.35]}]},
	"kaia": {"name": "Kaia", "role": "island diver",
		"skin": [0.6, 0.4, 0.27], "build": "slim",
		"face": {"eyes": "triangle", "brows": "calm", "mouth": "soft", "nose": "button", "chin": "soft",
			"pal": {"iris": [0.1, 0.2, 0.18], "iris_lo": [0.2, 0.45, 0.4], "brow": [0.08, 0.05, 0.04]}},
		"hair": {"style": "ponytail", "color": [0.08, 0.06, 0.05]},
		"top": {"style": "bodysuit", "color": [0.1, 0.55, 0.6], "sleeves": "short"},
		"bottom": {"style": "tights", "color": [0.1, 0.55, 0.6]},
		"feet": {"style": "none"},
		"acc": [{"style": "trim", "color": [0.95, 0.85, 0.3]}, {"style": "wristbands", "color": [0.95, 0.85, 0.3]}]},
	"vesna": {"name": "Vesna", "role": "mountain herder",
		"skin": [0.97, 0.82, 0.7], "build": "",
		"face": {"eyes": "almond", "brows": "slash", "mouth": "still", "nose": "long", "chin": "square",
			"nose_tune": {"len": 40.0, "w": 17.0, "out": 12.0, "size": 34.0},
			"pal": {"iris": [0.3, 0.35, 0.2], "iris_lo": [0.55, 0.6, 0.35], "brow": [0.25, 0.15, 0.08]}},
		"hair": {"style": "long", "color": [0.38, 0.22, 0.12], "shell": true, "length": 1.2},
		"top": {"style": "jacket", "color": [0.55, 0.35, 0.22], "sleeves": "long"},
		"bottom": {"style": "skirt", "color": [0.3, 0.42, 0.3]},
		"feet": {"style": "boots", "color": [0.28, 0.18, 0.1]},
		"acc": [{"style": "sash", "color": [0.85, 0.2, 0.2]}, {"style": "cape", "color": [0.6, 0.55, 0.45]}]},
	"jun": {"name": "Jun", "role": "gym trainer",
		"skin": [0.95, 0.8, 0.66], "build": "",
		"face": {"eyes": "sharp", "brows": "calm", "mouth": "frown", "nose": "wedge", "chin": "square",
			"tune": {"w": 52.0, "tilt": 0.16, "lid_h": 22.0}, "pal": {"iris": [0.1, 0.08, 0.06], "iris_lo": [0.28, 0.2, 0.12], "brow": [0.06, 0.05, 0.04]}},
		"hair": {"style": "short", "color": [0.08, 0.06, 0.06]},
		"top": {"style": "tank", "color": [0.85, 0.15, 0.2]},
		"bottom": {"style": "tights", "color": [0.1, 0.1, 0.12]},
		"feet": {"style": "shoes", "color": [0.95, 0.95, 0.95]},
		"acc": [{"style": "wristbands", "color": [0.95, 0.95, 0.95]}, {"style": "headband", "color": [0.95, 0.95, 0.95]}]},
	"saphira": {"name": "Saphira", "role": "off-world trader",
		"skin": [0.62, 0.74, 0.95], "build": "curvy",
		"face": {"eyes": "almond", "brows": "arc", "mouth": "still", "nose": "none", "chin": "pointed",
			"tune": {"w": 60.0, "lid_h": 24.0}, "pal": {"iris": [0.6, 0.45, 0.05], "iris_lo": [0.95, 0.8, 0.3], "brow": [0.2, 0.25, 0.5], "lip": [0.35, 0.3, 0.65]}},
		"hair": {"style": "very_long_spiky", "color": [0.92, 0.95, 1.0]},
		"top": {"style": "armor", "color": [0.2, 0.18, 0.35], "under": [0.08, 0.08, 0.12], "pads": [0.85, 0.7, 0.3]},
		"bottom": {"style": "tights", "color": [0.08, 0.08, 0.12]},
		"feet": {"style": "boots", "color": [0.85, 0.7, 0.3]},
		"acc": [{"style": "earrings", "color": [0.85, 0.7, 0.3]}, {"style": "cape", "color": [0.45, 0.2, 0.55]}]},
	"talia": {"name": "Talia", "role": "Saiyan mercenary",
		"skin": [0.9, 0.74, 0.6], "build": "",
		"face": {"eyes": "sharp", "brows": "slash", "mouth": "frown", "nose": "pointed", "chin": "pointed",
			"tune": {"w": 54.0, "lid_h": 21.0, "lashes": 1, "lash_len": 5.0}, "pal": {"iris": [0.05, 0.04, 0.04], "iris_lo": [0.15, 0.12, 0.1], "brow": [0.04, 0.04, 0.05]}},
		"hair": {"style": "saiyan_spiky", "color": [0.05, 0.05, 0.07], "spikes": 7, "length": 0.8},
		"top": {"style": "armor", "color": [0.92, 0.9, 0.85], "under": [0.25, 0.12, 0.35], "pads": [0.55, 0.45, 0.25]},
		"bottom": {"style": "tights", "color": [0.25, 0.12, 0.35]},
		"feet": {"style": "boots", "color": [0.92, 0.9, 0.85]},
		"acc": [{"style": "scouter", "color": [0.2, 0.6, 0.95]}, {"style": "gloves", "color": [0.92, 0.9, 0.85]}, {"style": "tail", "color": [0.35, 0.25, 0.18]}]},
	"lottie": {"name": "Lottie", "role": "baker",
		"skin": [1.0, 0.86, 0.76], "build": "full_figure",
		"face": {"eyes": "tall_oval", "brows": "arc", "mouth": "soft", "nose": "button", "chin": "round",
			"pal": {"iris": [0.35, 0.22, 0.1], "iris_lo": [0.6, 0.42, 0.2], "brow": [0.65, 0.4, 0.2], "lip": [0.88, 0.5, 0.5]}},
		"hair": {"style": "bun", "color": [0.82, 0.55, 0.28]},
		"top": {"style": "dress", "color": [0.98, 0.88, 0.6], "sleeves": "short"},
		"feet": {"style": "shoes", "color": [0.55, 0.3, 0.2]},
		"acc": [{"style": "apron", "color": [0.98, 0.98, 0.96]}, {"style": "headband", "color": [0.98, 0.98, 0.96]}]},
	"noor": {"name": "Noor", "role": "news reporter",
		"skin": [0.75, 0.55, 0.4], "build": "",
		"face": {"eyes": "almond", "brows": "thin", "mouth": "soft", "nose": "wedge", "chin": "pointed",
			"tune": {"lashes": 3, "lash_len": 7.0}, "pal": {"iris": [0.18, 0.1, 0.05], "iris_lo": [0.42, 0.26, 0.12], "brow": [0.08, 0.05, 0.04], "lip": [0.58, 0.25, 0.3]}},
		"hair": {"style": "bob", "color": [0.1, 0.07, 0.05]},
		"top": {"style": "jacket", "color": [0.75, 0.15, 0.22], "sleeves": "long"},
		"bottom": {"style": "skirt", "color": [0.12, 0.12, 0.15]},
		"feet": {"style": "shoes", "color": [0.08, 0.08, 0.1]},
		"acc": [{"style": "earrings", "color": [0.95, 0.95, 0.98]}, {"style": "belt", "color": [0.08, 0.08, 0.1]}]},
	"elodie": {"name": "Elodie", "role": "librarian",
		"skin": [0.98, 0.85, 0.74], "build": "",
		"face": {"eyes": "wide_round", "brows": "thin", "mouth": "still", "nose": "pointed", "chin": "soft",
			"pal": {"iris": [0.3, 0.2, 0.1], "iris_lo": [0.55, 0.4, 0.2], "brow": [0.3, 0.18, 0.1]}},
		"hair": {"style": "long", "color": [0.28, 0.16, 0.1], "shell": true, "length": 1.25},
		"top": {"style": "vest", "color": [0.35, 0.28, 0.45], "under": [0.92, 0.9, 0.85]},
		"bottom": {"style": "skirt", "color": [0.28, 0.22, 0.2]},
		"feet": {"style": "shoes", "color": [0.25, 0.15, 0.1]},
		"acc": [{"style": "glasses", "color": [0.35, 0.22, 0.12]}]},
	"ama": {"name": "Ama", "role": "farmer",
		"skin": [0.4, 0.25, 0.16], "build": "curvy",
		"face": {"eyes": "wide_round", "brows": "calm", "mouth": "soft", "nose": "broad", "chin": "round",
			"pal": {"iris": [0.14, 0.08, 0.04], "iris_lo": [0.32, 0.2, 0.1], "brow": [0.05, 0.04, 0.03], "glint": [1.0, 1.0, 1.0]}},
		"hair": {"style": "bun", "color": [0.06, 0.05, 0.05]},
		"top": {"style": "tunic", "color": [0.35, 0.55, 0.3], "sleeves": "short"},
		"bottom": {"style": "pants", "color": [0.45, 0.35, 0.22]},
		"feet": {"style": "boots", "color": [0.3, 0.2, 0.12]},
		"acc": [{"style": "sash", "color": [0.95, 0.7, 0.2]}, {"style": "headband", "color": [0.95, 0.7, 0.2]}]},
	"yuki": {"name": "Yuki", "role": "ice-skater, the north",
		"skin": [1.0, 0.9, 0.86], "build": "slim",
		"face": {"eyes": "tall_oval", "brows": "arc", "mouth": "cat", "nose": "none", "chin": "pointed",
			"pal": {"iris": [0.25, 0.4, 0.6], "iris_lo": [0.55, 0.75, 0.95], "brow": [0.75, 0.78, 0.85]}},
		"hair": {"style": "bob", "color": [0.92, 0.94, 0.98]},
		"top": {"style": "jacket", "color": [0.55, 0.75, 0.95], "sleeves": "long"},
		"bottom": {"style": "tights", "color": [0.95, 0.95, 0.98]},
		"feet": {"style": "boots", "color": [0.95, 0.95, 0.98]},
		"acc": [{"style": "gloves", "color": [0.95, 0.95, 0.98]}, {"style": "trim", "color": [0.98, 0.98, 1.0]}]},
	"roza": {"name": "Roza", "role": "biker",
		"skin": [0.92, 0.75, 0.62], "build": "",
		"face": {"eyes": "almond", "brows": "slash", "mouth": "pout", "nose": "wedge", "chin": "pointed",
			"tune": {"w": 58.0, "lid_h": 20.0, "tilt": 0.16}, "pal": {"iris": [0.3, 0.08, 0.1], "iris_lo": [0.6, 0.2, 0.22], "brow": [0.2, 0.05, 0.06], "lip": [0.55, 0.1, 0.18]}},
		"hair": {"style": "flame", "color": [0.7, 0.1, 0.18]},
		"top": {"style": "jacket", "color": [0.12, 0.1, 0.1], "sleeves": "long"},
		"bottom": {"style": "tights", "color": [0.2, 0.18, 0.2]},
		"feet": {"style": "boots", "color": [0.12, 0.1, 0.1]},
		"acc": [{"style": "belt", "color": [0.75, 0.75, 0.8]}, {"style": "gloves", "color": [0.12, 0.1, 0.1]}, {"style": "earrings", "color": [0.75, 0.75, 0.8]}]},
	"priya": {"name": "Priya", "role": "doctor",
		"skin": [0.7, 0.5, 0.36], "build": "",
		"face": {"eyes": "tall_oval", "brows": "calm", "mouth": "still", "nose": "wedge", "chin": "soft",
			"pal": {"iris": [0.15, 0.08, 0.04], "iris_lo": [0.35, 0.2, 0.1], "brow": [0.06, 0.04, 0.03]}},
		"hair": {"style": "ponytail", "color": [0.05, 0.04, 0.04]},
		"top": {"style": "lab_coat", "color": [0.97, 0.97, 0.97], "under": [0.4, 0.7, 0.68]},
		"bottom": {"style": "pants", "color": [0.4, 0.7, 0.68]},
		"feet": {"style": "shoes", "color": [0.95, 0.95, 0.95]},
		"acc": [{"style": "earrings", "color": [0.95, 0.8, 0.35]}]},
	"ingrid": {"name": "Ingrid", "role": "blacksmith",
		"skin": [0.96, 0.78, 0.65], "build": "full_figure",
		"face": {"eyes": "triangle", "brows": "slash", "mouth": "flat", "nose": "broad", "chin": "square",
			"pal": {"iris": [0.25, 0.32, 0.38], "iris_lo": [0.45, 0.55, 0.62], "brow": [0.6, 0.42, 0.2]}},
		"hair": {"style": "ponytail", "color": [0.9, 0.72, 0.4]},
		"top": {"style": "tank", "color": [0.4, 0.35, 0.32]},
		"bottom": {"style": "baggy", "color": [0.28, 0.25, 0.22]},
		"feet": {"style": "boots", "color": [0.2, 0.14, 0.1]},
		"acc": [{"style": "apron", "color": [0.45, 0.3, 0.18]}, {"style": "wristbands", "color": [0.45, 0.3, 0.18]}, {"style": "gloves", "color": [0.45, 0.3, 0.18]}]},
	"celeste": {"name": "Celeste", "role": "ballroom dancer",
		"skin": [0.55, 0.36, 0.25], "build": "curvy",
		"face": {"eyes": "almond", "brows": "arc", "mouth": "soft", "nose": "button", "chin": "pointed",
			"tune": {"w": 60.0, "lashes": 4, "lash_len": 8.5}, "pal": {"iris": [0.25, 0.12, 0.05], "iris_lo": [0.55, 0.3, 0.12], "brow": [0.06, 0.04, 0.03], "lip": [0.55, 0.15, 0.3]}},
		"hair": {"style": "long", "color": [0.08, 0.05, 0.04], "shell": true, "length": 1.0},
		"top": {"style": "dress", "color": [0.55, 0.1, 0.45], "sleeves": "none"},
		"feet": {"style": "shoes", "color": [0.85, 0.7, 0.3]},
		"acc": [{"style": "earrings", "color": [0.85, 0.7, 0.3]}, {"style": "trim", "color": [0.85, 0.7, 0.3]}, {"style": "gloves", "color": [0.08, 0.06, 0.08]}]},
}

## Each recolour: a hue turn and saturation/brightness scale for the clothes, and an offset
## into HAIR and IRIS so the new woman's hair and eyes change too.
const COLORWAYS := [
	{"tag": "2", "hue": 0.5, "sat": 1.0, "val": 1.0, "hair": 2, "iris": 1},
	{"tag": "3", "hue": 0.2, "sat": 0.9, "val": 1.05, "hair": 4, "iris": 2},
	{"tag": "4", "hue": 0.8, "sat": 0.6, "val": 0.82, "hair": 6, "iris": 3},
]

const HAIR := [[0.06, 0.05, 0.06], [0.3, 0.18, 0.1], [0.55, 0.2, 0.1], [0.88, 0.72, 0.42], [0.85, 0.85, 0.88],
	[0.2, 0.55, 0.6], [0.9, 0.5, 0.65], [0.15, 0.18, 0.4], [0.45, 0.28, 0.16], [0.1, 0.07, 0.05]]
const IRIS := [[0.18, 0.1, 0.05], [0.12, 0.28, 0.4], [0.2, 0.35, 0.15], [0.4, 0.15, 0.4], [0.5, 0.35, 0.08], [0.1, 0.08, 0.08]]

## The recoloured women's names, three for each design in DESIGNS order.
const NAMES := [
	"Lin", "Fen", "Xiu", "Mara", "Tove", "Ines", "Abeni", "Zuri", "Folake", "Kana", "Rei", "Miko",
	"Daisy", "Poppy", "Iris", "Sasha", "Vera", "Kira", "Leila", "Samira", "Yara", "Momo", "Nell", "Tess",
	"Juliette", "Maren", "Signe", "Hilde", "Agnes", "Ruth", "Seren", "Aria", "Nova", "Dalia", "Fumi", "Haru",
	"Ivy", "Coral", "Pearl", "Nami", "Ume", "Chiyo", "Ottilie", "Greta", "Liesl", "Ebony", "Imani", "Nia",
	"Paloma", "Pilar", "Rosa", "Moana", "Leilani", "Malia", "Katya", "Olga", "Mila", "Mei-Lin", "Sun", "Hye",
	"Andromeda", "Lyra", "Vega", "Kessa", "Raya", "Brakka", "Clementine", "Muffin", "Honey", "Farah", "Zainab", "Rania",
	"Beatrix", "Maud", "Clara", "Efua", "Adwoa", "Kesia", "Hoshi", "Aiko", "Neve", "Scarlett", "Ruby", "Jade",
	"Anjali", "Meera", "Tara", "Freya", "Brunhild", "Solveig", "Amara", "Desta", "Sade",
]

static var _specs := {}
static var _looks := {}
static var _speakers := {}

## Every woman's preset id, the designs first, then their recolours in order.
static func ids() -> Array[String]:
	_build()
	var out: Array[String] = []
	for id: String in _specs:
		out.append(id)
	return out

static func has(id: String) -> bool:
	_build()
	return _specs.has(id)

## The Outfits preset for a woman (with "face", "speaker", "name" and "role").
static func spec(id: String) -> Dictionary:
	_build()
	return _specs.get(id, {})

## Her face look (Face.look reads it).
static func look(id: String) -> Dictionary:
	_build()
	return _looks.get(id, {})

## The look id of the woman who speaks as `who` ("" if none).
static func look_for_speaker(who: String) -> String:
	_build()
	return _speakers.get(who, "")

## Her name's colour in the dialogue box: her clothes' main colour, lifted to be readable.
static func speaker_color(id: String) -> Color:
	var sp := spec(id)
	var c := _c((sp.get("top", {}) as Dictionary).get("color", [0.9, 0.8, 0.9]))
	var h := c.h
	return Color.from_hsv(h, clampf(c.s, 0.25, 0.6), 1.0)

static func _build() -> void:
	if not _specs.is_empty():
		return
	var designs: Array = DESIGNS.keys()
	for i in designs.size():
		var key: String = designs[i]
		var d: Dictionary = DESIGNS[key]
		_add("woman_" + key, d, str(d["name"]))
	for w in COLORWAYS.size():
		for i in designs.size():
			var key: String = designs[i]
			var way: Dictionary = COLORWAYS[w]
			var nm: String = NAMES[(i * COLORWAYS.size() + w) % NAMES.size()]
			_add("woman_%s_%s" % [key, way["tag"]], recolor(DESIGNS[key], way, i), nm)

static func _add(id: String, d: Dictionary, nm: String) -> void:
	# "fitted" gives the builder her body; "cast" makes it cast the ordinary styles onto it
	var sp := {"model": "oto", "fitted": true, "cast": true, "name": nm, "speaker": nm, "role": d.get("role", ""), "face": id}
	for k: String in ["skin", "hair", "top", "bottom", "feet", "acc"]:
		if d.has(k):
			sp[k] = (d[k] as Variant)
	if str(d.get("build", "")) != "":
		sp["build"] = d["build"]
	_specs[id] = sp
	_looks[id] = _face(d.get("face", {}))
	_speakers[nm] = id

## A Face look from the table's plain arrays (Colors in "pal", ears on, sane defaults).
static func _face(f: Dictionary) -> Dictionary:
	var lk := f.duplicate(true)
	var pal := {}
	for k: String in (f.get("pal", {}) as Dictionary):
		pal[k] = _c(f["pal"][k])
	lk["pal"] = pal
	if lk.has("tune"):
		var tune := {}
		for k: String in (f["tune"] as Dictionary):
			var v: Variant = f["tune"][k]
			tune[k] = v
		lk["tune"] = tune
	lk["ears"] = "dbz"
	if not lk.has("blink"):
		lk["blink"] = [3.5, 7.0]
	return lk

## A design in a new colourway: every clothing colour turned round the wheel, the hair and
## eyes from the shared tables. Skin, cut and face shape stay.
static func recolor(d: Dictionary, way: Dictionary, index: int) -> Dictionary:
	var out := d.duplicate(true)
	for part: String in ["top", "bottom", "feet"]:
		if out.has(part):
			out[part] = _turn_all(out[part], way)
	var acc: Array = []
	for a: Dictionary in out.get("acc", []):
		acc.append(_turn_all(a, way) if a.get("style", "") not in ["glasses"] else a)
	out["acc"] = acc
	if out.has("hair"):
		var hs: Dictionary = out["hair"]
		if hs.get("style", "") not in ["turban", "bald"]:
			hs["color"] = HAIR[(index + int(way["hair"])) % HAIR.size()]
	var face: Dictionary = out.get("face", {})
	var pal: Dictionary = face.get("pal", {})
	var iris: Array = IRIS[(index + int(way["iris"])) % IRIS.size()]
	pal["iris"] = iris
	pal["iris_lo"] = [minf(iris[0] * 2.0 + 0.1, 1.0), minf(iris[1] * 2.0 + 0.1, 1.0), minf(iris[2] * 2.0 + 0.1, 1.0)]
	if out.has("hair") and pal.has("brow"):
		var hc := _c(out["hair"]["color"])
		var br := hc.darkened(0.35) if hc.v > 0.3 else hc
		pal["brow"] = [br.r, br.g, br.b]
	face["pal"] = pal
	out["face"] = face
	return out

static func _turn_all(part: Dictionary, way: Dictionary) -> Dictionary:
	var out := part.duplicate(true)
	for k: String in ["color", "under", "pads", "wrap", "trim"]:
		if out.has(k):
			var c := _turn(_c(out[k]), way)
			out[k] = [c.r, c.g, c.b]
	return out

## One colour turned: neutrals (white, black, greys) keep their hue and only shift in value.
static func _turn(c: Color, way: Dictionary) -> Color:
	if c.s < 0.12:
		return Color.from_hsv(c.h, c.s, clampf(c.v * (1.0 + (float(way["val"]) - 1.0) * 0.5), 0.0, 1.0))
	# capped so a turn never lands on neon (a lime or acid green reads as a glitch on cloth)
	return Color.from_hsv(fposmod(c.h + float(way["hue"]), 1.0), clampf(c.s * float(way["sat"]), 0.0, 0.78), clampf(c.v * float(way["val"]), 0.0, 0.86))

static func _c(v: Variant) -> Color:
	if v is Color:
		return v
	var a: Array = v
	return Color(float(a[0]), float(a[1]), float(a[2]))
