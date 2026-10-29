class_name Dishes
extends RefCounted
## The Menu: Oto's goal of eating every meal on the planet, at least once. Cooks (level
## NPCs with a "dish" key) serve each dish once through Talks.serve, which logs it in
## GameState.dishes. Milestones raise max HP or give stat points.

const DB := {
	"noodle_bowl": {"name": "West City noodle bowl", "place": "West City"},
	"chichi_dumplings": {"name": "Chi-Chi's dumplings", "place": "Goku's House"},
	"kame_fish_skewers": {"name": "Grilled fish skewers", "place": "Kame House"},
	"melon_bread": {"name": "Bakery melon bread", "place": "West City"},
	"capsule_corp_cookies": {"name": "Capsule Corp cookies", "place": "Capsule Corp"},
	"champion_hot_dog": {"name": "Champion hot dog", "place": "Hercule City"},
	"champions_buffet": {"name": "The champion's buffet", "place": "Hercule's Mansion"},
	"yajirobe_rice": {"name": "Yajirobe's rice", "place": "Korin's Holy Land"},
	# Capsule Corp, where she lives now
	"briefs_shortcake": {"name": "Mrs. Briefs' strawberry shortcake", "place": "Capsule Corp kitchen"},
	"freezer_ice_cream": {"name": "Rescued freezer ice cream", "place": "Capsule Corp pantry"},
	"dome_fruit": {"name": "Garden dome fruit platter", "place": "Capsule Corp garden"},
	"gravity_shake": {"name": "Ten-gravity protein shake", "place": "Gravity chamber"},
	"midnight_noodles": {"name": "Midnight cup noodles", "place": "Oto's room"},
	# the regions
	"desert_flatbread": {"name": "Nomad flatbread", "place": "Diablo Desert"},
	"herder_cheese": {"name": "Goat-herder's cheese", "place": "Granite Peaks"},
	"ice_fish_soup": {"name": "Ice-hole fish soup", "place": "Northern Ice Fields"},
	"glowcap_skewers": {"name": "Glowcap skewers", "place": "Crystal Cavern"},
	# West City's market street and shops
	"cafe_cake": {"name": "Cafe coffee and its cake", "place": "West City market"},
	"takoyaki": {"name": "Street takoyaki", "place": "West City market"},
	"mei_pork_buns": {"name": "Mei's pork buns", "place": "Mei's Noodle Bar"},
}
## Dish count -> reward. "hp" adds to max HP for good; "points" are stat points.
const MILESTONES := {3: {"hp": 20}, 5: {"points": 3}, 8: {"hp": 30}, 12: {"points": 5}, 16: {"hp": 50}}

static func hp_bonus(count: int) -> float:
	var total := 0.0
	for n: int in MILESTONES:
		if count >= n:
			total += float(MILESTONES[n].get("hp", 0))
	return total

static func next_milestone(count: int) -> int:
	for n: int in MILESTONES:
		if count < n:
			return n
	return -1

## Logs a dish; returns false if she has had it already.
static func log_dish(id: String) -> bool:
	if id in GameState.dishes:
		return false
	GameState.dishes.append(id)
	Sfx.play("dish")
	var count := GameState.dishes.size()
	if MILESTONES.has(count):
		var m: Dictionary = MILESTONES[count]
		if m.has("points"):
			GameState.stat_points += int(m["points"])
			Overlay.toast("%d dishes on the Menu: +%d stat points" % [count, m["points"]], 3.0)
		if m.has("hp"):
			Overlay.toast("%d dishes on the Menu: max HP +%d" % [count, m["hp"]], 3.0)
	else:
		Overlay.toast("New on the Menu: %s (%d)" % [DB[id]["name"], count], 2.5)
	return true
