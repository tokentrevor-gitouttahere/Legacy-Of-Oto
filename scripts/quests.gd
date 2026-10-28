class_name Quests
extends RefCounted
## Quest registry, read by the Journal page. A quest is active once GameState.flags[start]
## is set; each step is done when its flag is set; a quest with every step done is
## complete. Story scripts, Talks and level NPCs ("flag" key) set the flags.

const DB := {
	"a_place_to_eat": {
		"title": "A Place to Eat",
		"start": "amnesia",
		"steps": [
			{"flag": "paozu_fished", "text": "Learn to fish with Gohan."},
			{"flag": "paozu_chopsticks", "text": "Learn chopsticks from Chi-Chi."},
			{"flag": "paozu_sparred", "text": "Show Goku what your body remembers."},
		],
	},
	"roshi_lesson": {
		"title": "The Turtle Hermit's Lesson",
		"start": "roshi_lesson_started",
		"steps": [
			{"flag": "roshi_still_charge", "text": "On Roshi's island, empty your ki, then charge it back to full without moving."},
			{"flag": "roshi_lesson_done", "text": "Tell Master Roshi."},
		],
	},
}

static func started(id: String) -> bool:
	return bool(GameState.flags.get(DB[id]["start"], false))

static func step_done(step: Dictionary) -> bool:
	return bool(GameState.flags.get(step["flag"], false))

static func complete(id: String) -> bool:
	for step: Dictionary in DB[id]["steps"]:
		if not step_done(step):
			return false
	return true

## Sets the start flag and announces the quest.
static func start(id: String) -> void:
	if not started(id):
		GameState.flags[DB[id]["start"]] = true
		Overlay.toast("New in the journal: %s" % DB[id]["title"], 2.5)

## Quest ids in DB order: [active, completed].
static func split() -> Array:
	var active: Array = []
	var done: Array = []
	for id: String in DB:
		if started(id):
			(done if complete(id) else active).append(id)
	return [active, done]
