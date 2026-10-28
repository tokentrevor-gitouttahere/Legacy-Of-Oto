class_name Fixture
extends Node3D
## Behaviour for a location's interactive props. Level builds the prop and finds the
## cells under it (Level.fixtures); location.gd adds one Fixture per entry.
##   level_gate      blocks until GameState.level >= params.level
##   memory_gate     blocks until GameState.max_form >= params.form, or flag params.flag is set.
##                   It must never open before its rung of the memory ladder.
##   key_door        opens for good when Oto interacts carrying key item params.key
##   bridge          walkable once flag params.flag is set (always, without a flag)
##   floor_switch    sets flag params.flag (or its own id) when Oto steps on it
##   breakable_rock  takes melee and ki hits (params.hp); stays broken
##   save_lantern    rest: full HP and ki, and save the game
##   food_pot        Chi-Chi's leftovers: 10% HP, as often as she likes
##   fishing_spot    a bite, a press of E in time, a fresh fish (30% HP); needs Gohan's
##                   lesson (flag paozu_fished), then rests for FISH_REST seconds
## Lasting state is kept in GameState.flags under `id` (params.id, or "fx:<level>:<index>").

const TYPES := ["level_gate", "memory_gate", "key_door", "bridge", "floor_switch", "breakable_rock", "save_lantern", "food_pot", "fishing_spot"]
const FISH_REST := 25.0

var type := ""
var params := {}
var id := ""
var level: Level
var prop: Node3D
var cells: Array = []
var open := false
var hp := 0.0
var _rest_until := 0.0
# Interactable interface (Player._nearest_interactable).
var enabled := false
var prompt := ""

func setup(lv: Level, f: Dictionary) -> void:
	level = lv
	type = f["type"]
	prop = f["node"]
	cells = f["cells"]
	params = f["spec"].get("params", {})
	id = str(params.get("id", "fx:%s:%d" % [lv.id, f["index"]]))
	position = prop.position
	name = "Fixture_%s_%d" % [type, f["index"]]

func _ready() -> void:
	match type:
		"level_gate", "memory_gate", "key_door", "bridge":
			open = _condition()
			_apply(true)
			if type != "bridge":
				add_to_group("interactables")
		"floor_switch":
			open = bool(GameState.flags.get(_switch_flag(), false))
			_press(true)
		"breakable_rock":
			open = bool(GameState.flags.get(id, false))
			hp = float(params.get("hp", 60.0))
			if open:
				_crumble(true)
			else:
				add_to_group("breakables")
		"save_lantern":
			add_to_group("interactables")
			enabled = true
			prompt = "Rest by the lamp (save)"
		"food_pot":
			add_to_group("interactables")
			enabled = true
			prompt = "Eat Chi-Chi's leftovers"
		"fishing_spot":
			add_to_group("interactables")
			enabled = true
			prompt = "Fish"

func _condition() -> bool:
	match type:
		"level_gate":
			return GameState.level >= int(params.get("level", 1))
		"memory_gate":
			if params.has("form"):
				return GameState.max_form >= int(params["form"])
			return bool(GameState.flags.get(str(params.get("flag", "")), false))
		"key_door":
			return bool(GameState.flags.get(id, false))
		"bridge":
			return not params.has("flag") or bool(GameState.flags.get(str(params["flag"]), false))
	return false

func _switch_flag() -> String:
	return str(params.get("flag", id))

func _process(_delta: float) -> void:
	match type:
		"level_gate", "memory_gate", "bridge":
			if not open and _condition():
				open = true
				_apply(false)
		"floor_switch":
			if open:
				return
			var p := get_tree().get_first_node_in_group("player") as Player
			if p and Vector2(p.position.x - position.x, p.position.z - position.z).length() < 0.9:
				open = true
				GameState.flags[_switch_flag()] = true
				_press(false)
				Overlay.toast("Click.", 1.0)

## Gates, doors and bridges: sync blocked cells, prompt and visuals with `open`.
func _apply(instant: bool) -> void:
	if not is_instance_valid(level):
		return
	if type == "bridge":
		level.set_cells_blocked(cells, not open)
		var deck := prop.get_node("deck") as Node3D
		if open and not instant:
			deck.visible = true
			deck.scale.z = 0.02
			create_tween().tween_property(deck, "scale:z", 1.0, 0.8).set_trans(Tween.TRANS_BACK)
			Overlay.toast("A bridge slides out.", 1.5)
		else:
			deck.visible = open
		return
	level.set_cells_blocked(cells, not open)
	enabled = not open
	match type:
		"level_gate":
			prompt = "Sealed: Level %d" % int(params.get("level", 1))
		"memory_gate":
			prompt = "Sealed"
		"key_door":
			prompt = "Locked door"
	var bar := prop.get_node("barrier") as Node3D
	if not open:
		return
	if instant:
		bar.visible = false
		return
	var tw := create_tween()
	tw.tween_property(bar, "scale:y", 0.01, 0.7).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(bar.hide)
	match type:
		"level_gate":
			Overlay.toast("The barrier lowers.", 2.0)
		"memory_gate":
			Overlay.toast("The seal lets her through.", 2.0)
		"key_door":
			Overlay.toast("Unlocked: %s" % Items.key_name(str(params.get("key", ""))), 2.0)

func _press(instant: bool) -> void:
	var plate := prop.get_node("plate") as Node3D
	(prop.get_node("light") as Node3D).visible = open
	if open:
		if instant:
			plate.position.y = -0.08
		else:
			create_tween().tween_property(plate, "position:y", -0.08, 0.15)

func interact(p: Player) -> void:
	match type:
		"level_gate":
			await Overlay.say(["|A wall of hard light. The number %d is cut into both posts." % int(params.get("level", 1)), "|Not yet."])
		"memory_gate":
			await Overlay.say(["|The air here has a hole in it. Something on the other side is waiting for a part of her she has not found yet."])
		"key_door":
			var key := str(params.get("key", ""))
			if GameState.has_key(key):
				GameState.flags[id] = true
				open = true
				_apply(false)
			else:
				await Overlay.say(["|Locked. It wants the %s." % Items.key_name(key)])
		"save_lantern":
			p.hp = p.max_hp
			p.ki = p.max_ki
			GameState.save_game(p.position)
			Overlay.toast("She rests by the lamp. Game saved.", 2.0)
		"food_pot":
			p.heal(0.1)
			Overlay.toast("Chi-Chi's leftovers", 1.2)
		"fishing_spot":
			await _fish(p)

## One cast: wait for a bite, then press E within 0.9 s. A catch heals 30% HP.
func _fish(p: Player) -> void:
	if not GameState.flags.get("paozu_fished", false):
		await Overlay.say(["|Quiet water, and fish in it. She does not know yet how you get one out."])
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < _rest_until:
		Overlay.toast("The fish have gone quiet here. Later.", 1.5)
		return
	GameState.input_locked = true
	Overlay.set_prompt("")
	Overlay.toast("Waiting for a bite...", 1.4)
	await get_tree().create_timer(randf_range(1.2, 2.8)).timeout
	Overlay.toast("A bite!  Press E!", 0.9)
	var t := 0.0
	var hit := Overlay.auto
	while t < 0.9 and not hit:
		await get_tree().process_frame
		t += get_process_delta_time()
		hit = Input.is_action_just_pressed("interact")
	GameState.input_locked = false
	if hit:
		_rest_until = Time.get_ticks_msec() / 1000.0 + FISH_REST
		p.heal(Pickup.FOOD["fresh_fish"]["hp"])
		Overlay.toast("Fresh fish. She eats it right there on the jetty.", 2.0)
	else:
		Overlay.toast("It got away.", 1.2)

## Breakable rocks share the enemy hurt() signature so melee and ki shots can hit them.
func hurt(amount: float, _dir: Vector3, _launch: bool, _kind := "melee") -> void:
	if type != "breakable_rock" or open:
		return
	hp -= amount
	DamageNumber.number(get_parent(), position, amount)
	var shake := create_tween()
	shake.tween_property(prop, "position:x", position.x + 0.08, 0.04)
	shake.tween_property(prop, "position:x", position.x, 0.04)
	if hp <= 0.0:
		open = true
		GameState.flags[id] = true
		remove_from_group("breakables")
		_crumble(false)

func _crumble(instant: bool) -> void:
	level.set_cells_blocked(cells, false)
	if instant:
		prop.visible = false
		return
	var tw := create_tween()
	tw.tween_property(prop, "scale", Vector3(1.3, 0.05, 1.3), 0.35).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(prop.hide)
