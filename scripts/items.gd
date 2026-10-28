class_name Items
extends RefCounted
## Gear database. Keys other than name/slot are additive bonuses, except:
## "exp" and "stat_mult" and "speed" which are multipliers/fractions (see GameState).
## Weighted gear trades stats and speed for an EXP multiplier (1.25x to 2x).

const DB := {
	"power_gloves": {"name": "Power Gloves", "slot": "hand", "strength": 3.0},
	"energy_bracers": {"name": "Energy Bracers", "slot": "hand", "power": 3.0},
	"heavy_armbands": {"name": "Heavy Armbands", "slot": "hand", "exp": 1.5, "stat_mult": 0.85, "speed": -0.15},
	"battle_suit": {"name": "Battle Suit", "slot": "body", "endurance": 4.0},
	"weighted_suit": {"name": "Weighted Suit", "slot": "body", "exp": 2.0, "stat_mult": 0.7, "speed": -0.3},
	"speed_boots": {"name": "Speed Boots", "slot": "feet", "speed": 0.15},
	"heavy_boots": {"name": "Heavy Boots", "slot": "feet", "exp": 1.25, "stat_mult": 0.9, "speed": -0.1},
	"ki_ring": {"name": "Ki Ring", "slot": "acc", "regen": 3.0},
	"magnet_charm": {"name": "Magnet Charm", "slot": "acc", "magnet": 3.0},
}

## Key items: carried for quests and doors, never equipped (GameState.key_items).
const KEYS := {
	"rusty_key": {"name": "Rusty Key", "text": "Opens an old door somewhere."},
	"scouter": {"name": "Scouter", "text": "Reads exact numbers off anyone she senses. It reads nothing off her."},
}

static func key_name(id: String) -> String:
	return KEYS[id]["name"] if KEYS.has(id) else id.capitalize()

static func slot_fits(id: String, slot: String) -> bool:
	var s: String = DB[id]["slot"]
	return s == slot or (s == "acc" and slot.begins_with("acc"))

static func describe(id: String) -> String:
	if id == "":
		return "(empty)"
	var d: Dictionary = DB[id]
	var bits: Array[String] = []
	for k in ["strength", "power", "endurance", "regen", "magnet"]:
		if d.has(k):
			bits.append("%s +%d" % [k.capitalize(), int(d[k])])
	if d.has("speed"):
		bits.append("Speed %+d%%" % int(d["speed"] * 100.0))
	if d.has("stat_mult"):
		bits.append("Stats x%.2f" % d["stat_mult"])
	if d.has("exp"):
		bits.append("EXP x%.2f" % d["exp"])
	return "%s  (%s)" % [d["name"], ", ".join(bits)]
