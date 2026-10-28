extends Node
## Autoload. Run state: level, stats, forms, gear, story flags.

signal leveled_up(new_level: int)

const FORM_NAMES := ["Base", "Shadow Saiyan", "Shadow Saiyan 2: the Void", "Shadow Saiyan 3: Cohesion"]
const FORM_DAMAGE := [1.0, 1.8, 2.6, 3.4]
const FORM_SPEED := [1.0, 1.2, 1.35, 1.15]
const FORM_DRAIN := [0.0, 2.0, 5.0, 9.0]  # ki per second
const SLOTS := ["hand", "body", "feet", "acc1", "acc2", "acc3"]
const STATS := ["strength", "power", "endurance"]
const LEVEL_CAP := 100
const STAT_CAP := 255  # caps what points and capsules add; gear and forms apply on top
## Standing-still ki charge. delay: seconds before ki starts to rise; rate: share of max
## ki per second. Each tier is taught by someone (docs/MECHANICS_REFERENCE.md).
const CHARGE_TIERS := [
	{"name": "Basic Charge", "delay": 1.0, "rate": 0.08},
	{"name": "Steady Charge", "delay": 0.7, "rate": 0.12},
	{"name": "Focused Charge", "delay": 0.45, "rate": 0.18},
	{"name": "Deep Charge", "delay": 0.25, "rate": 0.25},
	{"name": "Perfect Charge", "delay": 0.1, "rate": 0.35},
]
## Ki techniques on `special`, cycled with `cycle`. Later ones are unlocked by the
## memory ladder (the design document decides which), via learn_ki_move().
const KI_MOVES := {
	"charged_orb": {"name": "Charged Orb", "text": "Hold to charge three levels; the third pierces."},
	"ki_blast": {"name": "Ki Blast", "text": "Hold for a stream of small, cheap shots."},
}

var level := 1
var xp := 0
var stat_points := 0
var base_stats := {"strength": 5, "power": 5, "endurance": 5}
var capsule_stats := {"strength": 0, "power": 0, "endurance": 0}
var max_form := 0
var charge_tier := 0
var ki_moves: Array = ["charged_orb", "ki_blast"]
var ki_move_index := 0
var flags := {}
var inventory: Array = []
var equipment := {"hand": "", "body": "", "feet": "", "acc1": "", "acc2": "", "acc3": ""}
var key_items: Array = []
var dishes: Array = []  # the Menu: dish ids Oto has eaten (Dishes.DB)
var senzu := 0  # carried senzu beans; eaten from the Journal page (full HP and ki)
var input_locked := false
var menu_enabled := false
var pending_level := ""
var pending_spawn := "default"
var pending_pos := Vector3.INF  # exact arrival point (loading a save); INF = use pending_spawn
var world_from := ""  # location id the player last left for the world map
var current_level := ""  # location id Oto is standing in
var in_location := false  # true in tile-map locations, where a defeat reloads the save
var sensing := false  # the scan panel (T) is open; not saved

var save_path := "user://save.json"  # tests point this elsewhere
var _defeated := false

## Fade out and load a tile-map location (res://levels/<id>.json).
func travel(level_id: String, spawn := "default") -> void:
	input_locked = true
	await Overlay.fade_to(Color.BLACK, 0.5)
	input_locked = false
	pending_level = level_id
	pending_spawn = spawn
	get_tree().change_scene_to_file("res://scenes/location.tscn")

## Fade out and fly the world map, starting above `from_level`.
func travel_world(from_level := "") -> void:
	input_locked = true
	await Overlay.fade_to(Color.BLACK, 0.5)
	input_locked = false
	world_from = from_level
	get_tree().change_scene_to_file("res://scenes/world_map.tscn")

func new_run() -> void:
	level = 1
	xp = 0
	stat_points = 0
	base_stats = {"strength": 5, "power": 5, "endurance": 5}
	capsule_stats = {"strength": 0, "power": 0, "endurance": 0}
	max_form = 0
	charge_tier = 0
	ki_moves = ["charged_orb", "ki_blast"]
	ki_move_index = 0
	flags = {}
	inventory = []
	equipment = {"hand": "", "body": "", "feet": "", "acc1": "", "acc2": "", "acc3": ""}
	key_items = []
	dishes = []
	senzu = 0
	input_locked = false
	in_location = false
	pending_pos = Vector3.INF

## Opening of the game: Oto at full strength with every Shadow form.
func start_power_fantasy() -> void:
	level = 60
	xp = 0
	stat_points = 0
	base_stats = {"strength": 30, "power": 30, "endurance": 30}
	max_form = 3
	charge_tier = CHARGE_TIERS.size() - 1

## The throw through time: everything she had is gone.
func amnesia_reset() -> void:
	new_run()
	flags["amnesia"] = true

func charge_info() -> Dictionary:
	return CHARGE_TIERS[charge_tier]

## A lesson or spar teaches a charge tier; lower tiers than the current one do nothing.
func learn_charge(tier: int) -> void:
	if tier > charge_tier:
		charge_tier = mini(tier, CHARGE_TIERS.size() - 1)
		Overlay.toast("Learned: %s" % CHARGE_TIERS[charge_tier]["name"], 3.0)

func ki_move() -> String:
	return ki_moves[ki_move_index % ki_moves.size()]

func cycle_ki_move() -> void:
	ki_move_index = (ki_move_index + 1) % ki_moves.size()

func learn_ki_move(id: String) -> void:
	if id not in ki_moves and KI_MOVES.has(id):
		ki_moves.append(id)
		Overlay.toast("Learned: %s" % KI_MOVES[id]["name"], 3.0)

func xp_needed(lv: int) -> int:
	return 20 + lv * lv * 4

func add_xp(amount: int) -> void:
	if level >= LEVEL_CAP:
		xp = 0
		return
	xp += int(round(amount * exp_mult()))
	while level < LEVEL_CAP and xp >= xp_needed(level):
		xp -= xp_needed(level)
		level += 1
		stat_points += 3
		leveled_up.emit(level)
		Overlay.toast("Level %d!  +3 stat points" % level)
	if level >= LEVEL_CAP:
		xp = 0

func max_hp() -> float:
	return 100.0 + (level - 1) * 10.0 + Dishes.hp_bonus(dishes.size())

func max_ki() -> float:
	return 60.0 + (level - 1) * 4.0

func gear_sum(key: String) -> float:
	var total := 0.0
	for id in equipment.values():
		if id != "":
			total += float(Items.DB[id].get(key, 0.0))
	return total

func gear_mult(key: String) -> float:
	var total := 1.0
	for id in equipment.values():
		if id != "":
			total *= float(Items.DB[id].get(key, 1.0))
	return total

func stat(stat_name: String) -> float:
	var raw := float(base_stats[stat_name]) + float(capsule_stats[stat_name]) + gear_sum(stat_name)
	return raw * gear_mult("stat_mult")

func speed_mult() -> float:
	return maxf(1.0 + gear_sum("speed"), 0.3)

func exp_mult() -> float:
	return gear_mult("exp")

## Points plus capsules: the part of a stat that STAT_CAP limits.
func trained(stat_name: String) -> int:
	return int(base_stats[stat_name]) + int(capsule_stats[stat_name])

func spend_point(stat_name: String) -> bool:
	if stat_points <= 0 or trained(stat_name) >= STAT_CAP:
		return false
	base_stats[stat_name] += 1
	stat_points -= 1
	return true

## Returns how much was actually added (less than `amount` near the cap).
func add_capsule(stat_name: String, amount := 1) -> int:
	var gain := clampi(STAT_CAP - trained(stat_name), 0, amount)
	capsule_stats[stat_name] += gain
	return gain

func give_item(id: String) -> void:
	if id not in inventory:
		inventory.append(id)

func give_key(id: String) -> void:
	if id not in key_items:
		key_items.append(id)
		Overlay.toast("Received: %s" % Items.key_name(id))

func has_key(id: String) -> bool:
	return id in key_items

# --- saving -----------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(save_path)

## Save points call this with Oto's position in current_level.
func save_game(pos: Vector3) -> void:
	var d := {
		"version": 1, "level": level, "xp": xp, "stat_points": stat_points,
		"base_stats": base_stats, "capsule_stats": capsule_stats, "max_form": max_form,
		"charge_tier": charge_tier, "ki_moves": ki_moves, "flags": flags, "inventory": inventory,
		"equipment": equipment, "key_items": key_items, "dishes": dishes, "senzu": senzu,
		"location": current_level, "pos": [pos.x, pos.z],
	}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_error("Could not write " + save_path)
		return
	f.store_string(JSON.stringify(d, "\t"))

## Restores the run from disk and sets pending_level / pending_pos; travel there next.
func load_game() -> bool:
	if not has_save():
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not parsed is Dictionary:
		push_error("Save file did not parse: " + save_path)
		return false
	var d: Dictionary = parsed
	new_run()
	level = int(d.get("level", 1))
	xp = int(d.get("xp", 0))
	stat_points = int(d.get("stat_points", 0))
	for s: String in STATS:
		base_stats[s] = int(d.get("base_stats", {}).get(s, 5))
		capsule_stats[s] = int(d.get("capsule_stats", {}).get(s, 0))
	max_form = int(d.get("max_form", 0))
	charge_tier = int(d.get("charge_tier", 0))
	ki_moves = d.get("ki_moves", ki_moves)
	flags = d.get("flags", {})
	inventory = d.get("inventory", [])
	for slot: String in SLOTS:
		equipment[slot] = str(d.get("equipment", {}).get(slot, ""))
	key_items = d.get("key_items", [])
	dishes = d.get("dishes", [])
	senzu = int(d.get("senzu", 0))
	pending_level = str(d.get("location", "west_city"))
	var pos: Array = d.get("pos", [])
	pending_pos = Vector3(float(pos[0]), 0, float(pos[1])) if pos.size() == 2 else Vector3.INF
	return true

func continue_game() -> void:
	if load_game():
		travel(pending_level, "default")

## Oto fell in a location: back to the last save (Player falls back to a respawn without one).
func defeat() -> void:
	if _defeated:
		return
	_defeated = true
	input_locked = true
	await Overlay.fade_to(Color.BLACK, 1.0)
	await Overlay.card("Oto falls.\nShe wakes by the last lamp she rested at.", 1.8)
	_defeated = false
	if load_game():
		travel(pending_level, "default")
	else:
		input_locked = false

## Items that could go in `slot` right now (not worn in another slot).
func equip_options(slot: String) -> Array:
	var opts: Array = [""]
	for id in inventory:
		if Items.slot_fits(id, slot):
			var worn_elsewhere := false
			for s in SLOTS:
				if s != slot and equipment[s] == id:
					worn_elsewhere = true
			if not worn_elsewhere:
				opts.append(id)
	return opts

func cycle_equipment(slot: String) -> void:
	var opts := equip_options(slot)
	var i := opts.find(equipment[slot])
	equipment[slot] = opts[(i + 1) % opts.size()]
