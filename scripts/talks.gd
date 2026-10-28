class_name Talks
extends RefCounted
## Conversations with game effects, picked by a level NPC's keys:
##   "talk": "roshi_lesson"  Master Roshi's optional lesson (teaches Focused Charge early)
##   "talk": "gohan_fishing" Gohan teaches fishing if she has not learned it yet
##   "talk": "yajirobe"      Yajirobe: his rice (with "dish") and one senzu bean at a time
##   "dish": "<Dishes id>"   a cook who serves that dish once (the Menu)
## Plain NPCs just say their "lines".

static func run(spec: Dictionary, p: Player) -> void:
	var lines: Array = spec.get("lines", [])
	match str(spec.get("talk", "")):
		"roshi_lesson":
			await _roshi(p, lines)
		"gohan_fishing":
			await _gohan(lines)
		"yajirobe":
			await Overlay.say(lines)
			if spec.has("dish"):
				await serve(str(spec["dish"]), p)
			await _yajirobe()
		_:
			await Overlay.say(lines)
			if spec.has("dish"):
				await serve(str(spec["dish"]), p)

static func serve(dish: String, p: Player) -> void:
	if dish in GameState.dishes:
		return
	await Overlay.say(["|She eats the %s. All of it." % Dishes.DB[dish]["name"].to_lower()])
	Dishes.log_dish(dish)
	p.heal(1.0)

static func _gohan(lines: Array) -> void:
	if GameState.flags.get("paozu_fished", false):
		await Overlay.say(lines)
		return
	await Overlay.say([
		"Gohan|Hi, Miss Oto! Do you want to learn to fish?",
		"Gohan|You hold the line, and you wait. That's the hard part.",
	])
	GameState.flags["paozu_fished"] = true
	Overlay.toast("Learned: fishing. Look for a jetty by quiet water.", 3.0)

static func _yajirobe() -> void:
	if GameState.senzu > 0:
		await Overlay.say(["Yajirobe|You've still got a bean. Eat that one first."])
		return
	await Overlay.say(["Yajirobe|Korin says hand these out. One. Don't ask for two."])
	GameState.senzu += 1
	Overlay.toast("Received: Senzu bean (eat it from the Journal page)", 3.0)

static func _roshi(p: Player, lines: Array) -> void:
	var f := GameState.flags
	if f.get("roshi_lesson_done", false):
		await Overlay.say(lines)
	elif f.get("roshi_still_charge", false):
		await Overlay.say([
			"Master Roshi|Ho! You didn't even twitch.",
			"Oto|I was thinking about lunch.",
			"Master Roshi|...Whatever works.",
		])
		f["roshi_lesson_done"] = true
		GameState.learn_charge(2)
	elif Quests.started("roshi_lesson"):
		await Overlay.say(["Master Roshi|Empty first. Then fill back up, still as a turtle on a rock."])
	else:
		await Overlay.say(lines + [
			"Master Roshi|You power up like you're angry at the air. Sit down. Breathe.",
			"Master Roshi|Empty yourself out, then fill back up without moving a muscle. Do it here, on my island, and come tell me.",
		])
		Quests.start("roshi_lesson")
	p.charge_hold = 0.0
