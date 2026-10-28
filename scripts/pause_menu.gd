extends CanvasLayer
## Autoload. Pause menu tabs: stat allocation, equipment (6 slots), journal (quests and
## key items) and the Menu (dishes eaten). The right column lists forms, the ki charge
## tier and ki techniques.

const TABS := ["STATS", "EQUIPMENT", "JOURNAL", "MENU"]

var is_open := false
var tab := 0
var cursor := 0
var _ctl: Control

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ctl = Control.new()
	_ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ctl.draw.connect(_draw_menu)
	add_child(_ctl)
	visible = false

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("menu"):
		if is_open:
			_close()
		elif GameState.menu_enabled and not GameState.input_locked:
			_open()
		return
	if not is_open:
		return
	var rows := _row_count()
	if Input.is_action_just_pressed("move_down"):
		cursor = (cursor + 1) % rows
	if Input.is_action_just_pressed("move_up"):
		cursor = (cursor - 1 + rows) % rows
	if Input.is_action_just_pressed("move_right"):
		tab = (tab + 1) % TABS.size()
		cursor = 0
	if Input.is_action_just_pressed("move_left"):
		tab = (tab - 1 + TABS.size()) % TABS.size()
		cursor = 0
	if Input.is_action_just_pressed("attack"):
		if tab == 0:
			GameState.spend_point(GameState.STATS[cursor])
		elif tab == 1:
			GameState.cycle_equipment(GameState.SLOTS[cursor])
		elif tab == 2:
			_eat_senzu()
	_ctl.queue_redraw()

func _row_count() -> int:
	match tab:
		0:
			return GameState.STATS.size()
		1:
			return GameState.SLOTS.size()
	return 1

func _open() -> void:
	is_open = true
	tab = 0
	cursor = 0
	visible = true
	Overlay.show_hint(false)
	get_tree().paused = true

## Developer screenshots: open straight onto a tab.
func open_tab(t: int) -> void:
	_open()
	tab = clampi(t, 0, TABS.size() - 1)
	_ctl.queue_redraw()

func _close() -> void:
	is_open = false
	visible = false
	Overlay.show_hint(true)
	get_tree().paused = false

func _draw_menu() -> void:
	var font := ThemeDB.fallback_font
	var sz := _ctl.get_viewport_rect().size
	_ctl.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.03, 0.02, 0.06, 0.93))
	var x := 80.0
	var y := 70.0
	var tx := x
	for i in TABS.size():
		_ctl.draw_string(font, Vector2(tx, y), TABS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE if tab == i else Color(0.5, 0.5, 0.6))
		tx += font.get_string_size(TABS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x + 36.0
	_ctl.draw_string(font, Vector2(x, sz.y - 30), "Left/Right: tab   Up/Down: move   Z: confirm   Enter: close", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.7, 0.7, 0.8))
	y += 50.0
	var info := "Level %d    EXP %d / %d    HP %d    Ki %d" % [GameState.level, GameState.xp, GameState.xp_needed(GameState.level), GameState.max_hp(), GameState.max_ki()]
	_ctl.draw_string(font, Vector2(x, y), info, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 0.9, 0.6))
	y += 50.0
	var width := sz.x - 440.0 - x - 40.0
	match tab:
		0:
			_draw_stats(font, x, y)
		1:
			_draw_equipment(font, x, y)
		2:
			_draw_journal(font, x, y, width)
		3:
			_draw_dishes(font, x, y, width)
	_draw_side(font, sz.x - 440.0)

func _draw_stats(font: Font, x: float, y: float) -> void:
	_ctl.draw_string(font, Vector2(x, y), "Stat points: %d" % GameState.stat_points, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.6, 1, 0.7))
	y += 44.0
	for i in GameState.STATS.size():
		var s: String = GameState.STATS[i]
		var line := "%s   %.1f   (base %d, capsules %d)" % [s.capitalize(), GameState.stat(s), GameState.base_stats[s], GameState.capsule_stats[s]]
		if GameState.trained(s) >= GameState.STAT_CAP:
			line += "    MAX"
		elif GameState.stat_points > 0:
			line += "    [Z: +1]"
		_row(font, Vector2(x, y), line, i == cursor)
		y += 40.0

func _draw_equipment(font: Font, x: float, y: float) -> void:
	for i in GameState.SLOTS.size():
		var slot: String = GameState.SLOTS[i]
		_row(font, Vector2(x, y), "%s:  %s" % [slot, Items.describe(GameState.equipment[slot])], i == cursor)
		y += 40.0
	y += 10.0
	_ctl.draw_string(font, Vector2(x, y), "EXP x%.2f    Speed x%.2f" % [GameState.exp_mult(), GameState.speed_mult()], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.8, 0.8, 1))

func _eat_senzu() -> void:
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null or GameState.senzu <= 0:
		return
	GameState.senzu -= 1
	p.hp = p.max_hp
	p.ki = p.max_ki
	Overlay.toast("She eats a senzu bean. Everything comes back.", 2.0)

func _draw_journal(font: Font, x: float, y: float, width: float) -> void:
	if GameState.senzu > 0:
		_row(font, Vector2(x, y), "Senzu beans: %d    [Z: eat one]" % GameState.senzu, true)
		y += 48.0
	var parts := Quests.split()
	var active: Array = parts[0]
	var done: Array = parts[1]
	if active.is_empty() and done.is_empty():
		_ctl.draw_string(font, Vector2(x, y), "Nothing yet.", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.6, 0.6, 0.7))
		y += 40.0
	for id: String in active:
		_ctl.draw_string(font, Vector2(x, y), Quests.DB[id]["title"], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 0.85, 0.5))
		y += 32.0
		for step: Dictionary in Quests.DB[id]["steps"]:
			var ok := Quests.step_done(step)
			for line in _wrap(font, ("[x] " if ok else "[  ] ") + str(step["text"]), width - 24.0, 19):
				_ctl.draw_string(font, Vector2(x + 24.0, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(0.6, 0.6, 0.7) if ok else Color.WHITE)
				y += 26.0
		y += 12.0
	for id: String in done:
		_ctl.draw_string(font, Vector2(x, y), "%s  (done)" % Quests.DB[id]["title"], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.55, 0.55, 0.65))
		y += 32.0
	y += 16.0
	_ctl.draw_string(font, Vector2(x, y), "KEY ITEMS", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	y += 30.0
	if GameState.key_items.is_empty():
		_ctl.draw_string(font, Vector2(x, y), "(none)", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(0.6, 0.6, 0.7))
	for k: String in GameState.key_items:
		_ctl.draw_string(font, Vector2(x, y), Items.key_name(k), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(0.85, 0.85, 1.0))
		y += 26.0

func _draw_dishes(font: Font, x: float, y: float, _width: float) -> void:
	var count := GameState.dishes.size()
	_ctl.draw_string(font, Vector2(x, y), "Every meal on this planet, at least once.", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.75, 0.7, 0.85))
	y += 36.0
	_ctl.draw_string(font, Vector2(x, y), "%d / %d dishes" % [count, Dishes.DB.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 0.85, 0.5))
	y += 36.0
	for id: String in Dishes.DB:
		var d: Dictionary = Dishes.DB[id]
		var eaten := id in GameState.dishes
		_ctl.draw_string(font, Vector2(x + 12.0, y), ("%s  (%s)" % [d["name"], d["place"]]) if eaten else ("???  (%s)" % d["place"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE if eaten else Color(0.5, 0.5, 0.6))
		y += 28.0
	y += 14.0
	var next := Dishes.next_milestone(count)
	if next > 0:
		var m: Dictionary = Dishes.MILESTONES[next]
		var reward := ("max HP +%d" % m["hp"]) if m.has("hp") else ("+%d stat points" % m["points"])
		_ctl.draw_string(font, Vector2(x, y), "Next: %d dishes, %s" % [next, reward], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.6, 1, 0.7))
	if Dishes.hp_bonus(count) > 0.0:
		_ctl.draw_string(font, Vector2(x, y + 28.0), "Max HP from the Menu: +%d" % int(Dishes.hp_bonus(count)), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.8, 0.8, 1))

func _draw_side(font: Font, fx: float) -> void:
	var y := 70.0
	_ctl.draw_string(font, Vector2(fx, y), "FORMS", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
	for i in GameState.FORM_NAMES.size():
		y += 36.0
		var have: bool = i <= GameState.max_form
		_ctl.draw_string(font, Vector2(fx, y), GameState.FORM_NAMES[i] if have else "???", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color.WHITE if have else Color(0.4, 0.4, 0.5))
	y += 60.0
	_ctl.draw_string(font, Vector2(fx, y), "KI CHARGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
	y += 36.0
	var tier := GameState.charge_info()
	_ctl.draw_string(font, Vector2(fx, y), "%s  (%.2fs, %d%%/s)" % [tier["name"], tier["delay"], int(float(tier["rate"]) * 100.0)], HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color(0.8, 0.7, 1.0))
	y += 60.0
	_ctl.draw_string(font, Vector2(fx, y), "KI TECHNIQUES", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
	for id: String in GameState.ki_moves:
		y += 34.0
		var sel := id == GameState.ki_move()
		_ctl.draw_string(font, Vector2(fx, y), ("> " if sel else "  ") + str(GameState.KI_MOVES[id]["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color.WHITE if sel else Color(0.7, 0.7, 0.8))

func _row(font: Font, pos: Vector2, text: String, selected: bool) -> void:
	if selected:
		_ctl.draw_rect(Rect2(pos + Vector2(-14, -26), Vector2(_ctl.get_viewport_rect().size.x - 520.0, 34)), Color(0.3, 0.2, 0.5, 0.6))
	_ctl.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)

func _wrap(font: Font, text: String, width: float, font_size: int) -> Array:
	var lines: Array = []
	var line := ""
	for word in text.split(" "):
		var attempt := word if line == "" else line + " " + word
		if line != "" and font.get_string_size(attempt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
			lines.append(line)
			line = word
		else:
			line = attempt
	if line != "":
		lines.append(line)
	return lines
