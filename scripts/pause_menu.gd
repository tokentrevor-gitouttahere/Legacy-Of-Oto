extends CanvasLayer
## Autoload. Pause menu tabs: stat allocation, equipment (6 slots), journal (quests and
## key items) and the Menu (dishes eaten). The character card on the left shows Oto's
## portrait, her meters, forms, the ki charge tier and ki techniques. Drawn with UiKit.

const TABS := ["STATS", "EQUIPMENT", "JOURNAL", "MENU"]
const CARD_W := 360.0

var is_open := false
var tab := 0
var cursor := 0
var _ctl: Control
var _portrait: Portrait
var _t := 0.0
var _open := 0.0

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ctl = Control.new()
	_ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ctl.draw.connect(_draw_menu)
	add_child(_ctl)
	_portrait = Portrait.new()
	_ctl.add_child(_portrait)
	visible = false

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("menu"):
		if is_open:
			_close()
		elif GameState.menu_enabled and not GameState.input_locked:
			_open_menu()
		return
	if not is_open:
		return
	_t += delta
	_open = minf(_open + delta * 6.0, 1.0)
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

func _open_menu() -> void:
	is_open = true
	tab = 0
	cursor = 0
	_open = 0.0
	visible = true
	_portrait.set_speaker("Oto")
	Overlay.show_hint(false)
	get_tree().paused = true

## Developer screenshots: open straight onto a tab.
func open_tab(t: int) -> void:
	_open_menu()
	tab = clampi(t, 0, TABS.size() - 1)
	_ctl.queue_redraw()

func _close() -> void:
	is_open = false
	visible = false
	Overlay.show_hint(true)
	get_tree().paused = false

# --- drawing ----------------------------------------------------------------------------

func _draw_menu() -> void:
	var sz := _ctl.get_viewport_rect().size
	var a := _open
	# the world behind dims to violet, darker at the edges
	_ctl.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.02, 0.01, 0.04, 0.9 * a))
	UiKit.gradient_rect(_ctl, Rect2(Vector2.ZERO, Vector2(sz.x, sz.y * 0.2)), Color(0, 0, 0, 0.5 * a), Color(0, 0, 0, 0))
	UiKit.gradient_rect(_ctl, Rect2(Vector2(0, sz.y * 0.8), Vector2(sz.x, sz.y * 0.2)), Color(0, 0, 0, 0), Color(0, 0, 0, 0.5 * a))
	var slide := (1.0 - a) * 24.0
	var m := 32.0
	_draw_tabs(sz, m)
	var card := Rect2(Vector2(m - slide, 92), Vector2(CARD_W, sz.y - 92 - 70))
	_draw_card(card)
	var main := Rect2(Vector2(card.end.x + 24.0 + slide, 92), Vector2(sz.x - card.end.x - 24.0 - m, sz.y - 92 - 70))
	UiKit.frame(_ctl, main, UiKit.GOLD, true)
	var inner := main.grow(-28.0)
	inner.position.y += 14.0
	match tab:
		0:
			_draw_stats(inner)
		1:
			_draw_equipment(inner)
		2:
			_draw_journal(inner)
		3:
			_draw_dishes(inner)
	var hints := [["Left/Right", "Tab"], ["Up/Down", "Move"]]
	match tab:
		0:
			hints.append(["Z", "Raise stat"])
		1:
			hints.append(["Z", "Change gear"])
		2:
			if GameState.senzu > 0:
				hints.append(["Z", "Eat a senzu"])
	hints.append(["Enter", "Close"])
	UiKit.key_row(_ctl, Vector2(m + 6.0, sz.y - 26.0), hints)

func _draw_tabs(sz: Vector2, m: float) -> void:
	var font := UiKit.spaced(UiKit.display_font(true), 3)
	var fs := 22
	# a small mark of the house at the left
	UiKit.sigil(_ctl, Vector2(m + 12.0, 46.0), 30.0, UiKit.GOLD)
	UiKit.text(_ctl, UiKit.spaced(UiKit.display_font(true), 4), Vector2(m + 34.0, 56.0), "OTO", 28, UiKit.GOLD_PALE)
	var widths: Array[float] = []
	var total := 0.0
	for s: String in TABS:
		var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 48.0
		widths.append(w)
		total += w + 10.0
	var x := (sz.x - total) * 0.5 + 60.0
	for i in TABS.size():
		var r := Rect2(Vector2(x, 26.0), Vector2(widths[i], 42.0))
		var on := i == tab
		var poly := UiKit.notched(r, 10.0)
		_ctl.draw_colored_polygon(poly, Color(0.2, 0.13, 0.3, 0.95) if on else Color(0.05, 0.035, 0.08, 0.9))
		_ctl.draw_polyline(UiKit.closed(poly), UiKit.GOLD if on else UiKit.GOLD_DIM, 2.0 if on else 1.0, true)
		if on:
			UiKit.gradient_rect(_ctl, Rect2(r.position + Vector2(10, 2), Vector2(r.size.x - 20, 16)), Color(1, 1, 1, 0.1), Color(1, 1, 1, 0))
			UiKit.diamond(_ctl, Vector2(r.get_center().x, r.end.y + 6.0), 4.0, UiKit.GOLD)
		UiKit.text(_ctl, font, Vector2(r.position.x, r.position.y + 29.0), TABS[i], fs, UiKit.GOLD_PALE if on else UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 3)
		x += widths[i] + 10.0
	var lv := "Lv %d" % GameState.level
	UiKit.text(_ctl, UiKit.display_font(true), Vector2(sz.x - m - 120.0, 56.0), lv, 28, UiKit.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, 120.0)

## Oto's card: portrait, meters, forms, charge tier, ki techniques.
func _draw_card(r: Rect2) -> void:
	UiKit.frame(_ctl, r, UiKit.JADE)
	var font := UiKit.body_font()
	var x := r.position.x + 22.0
	var w := r.size.x - 44.0
	var ph := minf(r.size.y * 0.27, 170.0)
	_portrait.position = Vector2(x, r.position.y + 20.0)
	_portrait.size = Vector2(ph * 0.82, ph)
	var pr := Rect2(_portrait.position, _portrait.size).grow(3.0)
	_ctl.draw_colored_polygon(UiKit.notched(pr, 8.0), UiKit.INK)
	_ctl.draw_polyline(UiKit.closed(UiKit.notched(pr, 8.0)), UiKit.GOLD, 1.5, true)
	var nx := pr.end.x + 16.0
	var ny := r.position.y + 50.0
	UiKit.text(_ctl, UiKit.spaced(UiKit.display_font(true), 2), Vector2(nx, ny), "Oto", 32, UiKit.speaker_color("Oto"))
	var p := get_tree().get_first_node_in_group("player") as Player
	var form := p.form if p else 0
	UiKit.text(_ctl, font, Vector2(nx, ny + 26.0), GameState.FORM_NAMES[form] if form < GameState.FORM_NAMES.size() else "", 16, UiKit.VIOLET if form > 0 else UiKit.MUTED)
	UiKit.text(_ctl, font, Vector2(nx, ny + 52.0), "Level %d" % GameState.level, 18, UiKit.TEXT)
	if GameState.stat_points > 0:
		UiKit.text(_ctl, font, Vector2(nx, ny + 76.0), "%d points to place" % GameState.stat_points, 15, UiKit.JADE.lightened(0.3))
	var y := pr.end.y + 30.0
	var hp := p.hp / p.max_hp if p else 1.0
	var ki := p.ki / p.max_ki if p else 1.0
	var need := GameState.xp_needed(GameState.level)
	for row: Array in [["HP", hp, UiKit.HP, "%d" % GameState.max_hp()], ["KI", ki, UiKit.KI, "%d" % GameState.max_ki()],
			["EXP", float(GameState.xp) / maxf(need, 1.0), UiKit.EXP, "%d / %d" % [GameState.xp, need]]]:
		UiKit.text(_ctl, font, Vector2(x, y), row[0], 14, UiKit.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
		UiKit.text(_ctl, font, Vector2(x, y), row[3], 14, UiKit.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, w - 10.0, 3)
		UiKit.bar(_ctl, Rect2(Vector2(x, y + 6.0), Vector2(w - 12.0, 9.0)), row[1], row[2])
		y += 34.0
	UiKit.rule(_ctl, Vector2(x, y), Vector2(x + w, y), UiKit.GOLD_DIM)
	y += 24.0
	_section(Vector2(x, y), "FORMS")
	y += 8.0
	for i in GameState.FORM_NAMES.size():
		y += 21.0
		var have: bool = i <= GameState.max_form
		var gem := UiKit.VIOLET if have else UiKit.FAINT
		UiKit.diamond(_ctl, Vector2(x + 6.0, y - 5.0), 4.5 if i == form else 3.5, gem if i != form else UiKit.GOLD)
		UiKit.text(_ctl, font, Vector2(x + 20.0, y), GameState.FORM_NAMES[i] if have else "? ? ?", 16, UiKit.TEXT if have else UiKit.FAINT, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
	y += 28.0
	_section(Vector2(x, y), "KI CHARGE")
	var tier := GameState.charge_info()
	UiKit.text(_ctl, font, Vector2(x, y), "%s  %.2fs  %d%%/s" % [tier["name"], tier["delay"], int(float(tier["rate"]) * 100.0)], 15, UiKit.VIOLET.lightened(0.2), HORIZONTAL_ALIGNMENT_RIGHT, w, 3)
	y += 26.0
	_section(Vector2(x, y), "KI TECHNIQUES")
	for id: String in GameState.ki_moves:
		y += 21.0
		var sel := id == GameState.ki_move()
		if sel:
			UiKit.diamond(_ctl, Vector2(x + 6.0, y - 5.0), 3.5, UiKit.GOLD)
		UiKit.text(_ctl, font, Vector2(x + 20.0, y), str(GameState.KI_MOVES[id]["name"]), 16, UiKit.TEXT if sel else UiKit.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)

func _section(pos: Vector2, title: String) -> void:
	UiKit.text(_ctl, UiKit.spaced(UiKit.display_font(true), 2), pos, title, 15, UiKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)

func _heading(r: Rect2, title: String, sub: String) -> float:
	UiKit.text(_ctl, UiKit.spaced(UiKit.display_font(true), 2), r.position + Vector2(0, 6), title, 28, UiKit.GOLD_PALE)
	if sub != "":
		UiKit.text(_ctl, UiKit.body_font(true), r.position + Vector2(0, 34), sub, 17, UiKit.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
	UiKit.rule(_ctl, r.position + Vector2(0, 50), r.position + Vector2(r.size.x, 50), UiKit.GOLD_DIM, false)
	return r.position.y + 90.0

func _row_rect(r: Rect2, y: float, h: float) -> Rect2:
	return Rect2(Vector2(r.position.x + 14.0, y - h * 0.68), Vector2(r.size.x - 14.0, h))

func _draw_stats(r: Rect2) -> void:
	var font := UiKit.body_font()
	var y := _heading(r, "Training", "Three points each level, placed where she chooses.")
	UiKit.text(_ctl, font, Vector2(r.position.x, r.position.y + 6.0), "Points: %d" % GameState.stat_points, 22, UiKit.JADE.lightened(0.3) if GameState.stat_points > 0 else UiKit.MUTED, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x)
	var colors := [UiKit.HP, UiKit.KI, Color(0.4, 0.75, 0.95)]
	var blurbs := {"strength": "Hits harder up close.", "power": "Ki attacks hit harder.", "endurance": "Takes less from every blow."}
	for i in GameState.STATS.size():
		var s: String = GameState.STATS[i]
		var row := _row_rect(r, y, 74.0)
		if i == cursor:
			UiKit.highlight(_ctl, row, UiKit.GOLD, _t)
		var x := row.position.x + 14.0
		UiKit.text(_ctl, UiKit.display_font(true), Vector2(x, y), s.capitalize(), 24, UiKit.TEXT)
		UiKit.text(_ctl, font, Vector2(x, y + 22.0), blurbs.get(s, ""), 15, UiKit.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
		var bx := x + 210.0
		var bw := row.size.x - 210.0 - 150.0
		UiKit.bar(_ctl, Rect2(Vector2(bx, y - 12.0), Vector2(bw, 12.0)), GameState.trained(s) / float(GameState.STAT_CAP), colors[i])
		UiKit.text(_ctl, font, Vector2(bx, y + 22.0), "base %d   capsules %d" % [GameState.base_stats[s], GameState.capsule_stats[s]], 14, UiKit.FAINT.lightened(0.3), HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
		UiKit.text(_ctl, UiKit.display_font(true), Vector2(row.end.x - 130.0, y + 2.0), "%.1f" % GameState.stat(s), 28, UiKit.GOLD_PALE, HORIZONTAL_ALIGNMENT_RIGHT, 70.0)
		if GameState.trained(s) >= GameState.STAT_CAP:
			UiKit.text(_ctl, font, Vector2(row.end.x - 52.0, y), "MAX", 15, UiKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
		elif GameState.stat_points > 0:
			UiKit.key_chip(_ctl, Vector2(row.end.x - 52.0, y), "Z", "+1", 15)
		y += 92.0

func _draw_equipment(r: Rect2) -> void:
	var font := UiKit.body_font()
	var y := _heading(r, "Equipment", "Weighted gear trades strength and speed for more EXP.")
	var labels := {"hand": "Hands", "body": "Body", "feet": "Feet", "acc1": "Accessory", "acc2": "Accessory", "acc3": "Accessory"}
	var row_h := minf((r.end.y - y - 40.0) / GameState.SLOTS.size(), 64.0)
	for i in GameState.SLOTS.size():
		var slot: String = GameState.SLOTS[i]
		var id: String = GameState.equipment[slot]
		var row := _row_rect(r, y, row_h - 6.0)
		if i == cursor:
			UiKit.highlight(_ctl, row, UiKit.GOLD, _t)
		var icon := Rect2(Vector2(row.position.x + 12.0, row.position.y + 3.0), Vector2(row.size.y - 6.0, row.size.y - 6.0))
		ItemIcons.draw(_ctl, id if id != "" else slot, icon, id == "")
		var x := icon.end.x + 16.0
		UiKit.text(_ctl, font, Vector2(x, row.position.y + 20.0), labels.get(slot, slot).to_upper(), 13, UiKit.GOLD_DIM.lightened(0.3), HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
		if id == "":
			UiKit.text(_ctl, font, Vector2(x, row.position.y + 44.0), "(empty)", 20, UiKit.FAINT.lightened(0.2), HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
		else:
			var d: Dictionary = Items.DB[id]
			UiKit.text(_ctl, UiKit.display_font(true), Vector2(x, row.position.y + 45.0), d["name"], 22, ItemIcons.tint(id).lightened(0.35))
			var desc := Items.describe(id)
			var k := desc.find("(")
			UiKit.text(_ctl, font, Vector2(row.end.x - 12.0 - 420.0, row.position.y + 40.0), desc.substr(k + 1, desc.length() - k - 2) if k >= 0 else "", 15, UiKit.MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 420.0, 3)
		y += row_h
	y += 6.0
	UiKit.text(_ctl, font, Vector2(r.position.x + 14.0, y), "EXP x%.2f      Speed x%.2f" % [GameState.exp_mult(), GameState.speed_mult()], 18, UiKit.VIOLET.lightened(0.25), HORIZONTAL_ALIGNMENT_LEFT, -1, 3)

func _eat_senzu() -> void:
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null or GameState.senzu <= 0:
		return
	GameState.senzu -= 1
	p.hp = p.max_hp
	p.ki = p.max_ki
	Overlay.toast("She eats a senzu bean. Everything comes back.", 2.0)

func _draw_journal(r: Rect2) -> void:
	var font := UiKit.body_font()
	var y := _heading(r, "Journal", "")
	var col_w := r.size.x * 0.6
	if GameState.senzu > 0:
		var row := _row_rect(r, y, 52.0)
		UiKit.highlight(_ctl, Rect2(row.position, Vector2(col_w, row.size.y)), UiKit.JADE, _t)
		ItemIcons.draw(_ctl, "senzu", Rect2(Vector2(row.position.x + 10.0, row.position.y + 4.0), Vector2(44, 44)))
		UiKit.text(_ctl, font, Vector2(row.position.x + 66.0, y + 4.0), "Senzu beans  x%d" % GameState.senzu, 21, UiKit.TEXT)
		y += 64.0
	var parts := Quests.split()
	var active: Array = parts[0]
	var done: Array = parts[1]
	if active.is_empty() and done.is_empty():
		UiKit.text(_ctl, UiKit.body_font(true), Vector2(r.position.x + 14.0, y), "Nothing yet.", 19, UiKit.FAINT.lightened(0.2))
		y += 40.0
	for id: String in active:
		UiKit.diamond(_ctl, Vector2(r.position.x + 18.0, y - 7.0), 5.0, UiKit.GOLD)
		UiKit.text(_ctl, UiKit.display_font(true), Vector2(r.position.x + 32.0, y), Quests.DB[id]["title"], 22, UiKit.GOLD_PALE)
		y += 30.0
		for step: Dictionary in Quests.DB[id]["steps"]:
			var ok := Quests.step_done(step)
			var box := Rect2(Vector2(r.position.x + 34.0, y - 14.0), Vector2(14, 14))
			_ctl.draw_rect(box, Color(0, 0, 0, 0.5))
			_ctl.draw_rect(box, UiKit.GOLD_DIM if not ok else UiKit.JADE, false, 1.5)
			if ok:
				_ctl.draw_polyline(PackedVector2Array([box.position + Vector2(2, 7), box.position + Vector2(6, 11), box.position + Vector2(13, 1)]), UiKit.JADE.lightened(0.3), 2.0, true)
			for line in UiKit.wrap(font, str(step["text"]), col_w - 70.0, 17):
				UiKit.text(_ctl, font, Vector2(r.position.x + 58.0, y), line, 17, UiKit.FAINT.lightened(0.25) if ok else UiKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
				y += 24.0
		y += 12.0
	for id: String in done:
		UiKit.text(_ctl, font, Vector2(r.position.x + 32.0, y), "%s  -  done" % Quests.DB[id]["title"], 18, UiKit.FAINT.lightened(0.2))
		y += 28.0
	# key items in a column on the right
	var kx := r.position.x + col_w + 30.0
	var kw := r.end.x - kx
	var ky := r.position.y + 90.0
	_section(Vector2(kx, ky), "KEY ITEMS")
	ky += 16.0
	if GameState.key_items.is_empty():
		UiKit.text(_ctl, UiKit.body_font(true), Vector2(kx, ky + 22.0), "None yet.", 17, UiKit.FAINT.lightened(0.2))
	for k: String in GameState.key_items:
		ItemIcons.draw(_ctl, k, Rect2(Vector2(kx, ky), Vector2(44, 44)))
		UiKit.text(_ctl, UiKit.display_font(true), Vector2(kx + 56.0, ky + 18.0), Items.key_name(k), 18, UiKit.GOLD_PALE)
		var txt: String = Items.KEYS.get(k, {}).get("text", "")
		var ly := ky + 38.0
		for line in UiKit.wrap(font, txt, kw - 60.0, 14):
			UiKit.text(_ctl, font, Vector2(kx + 56.0, ly), line, 14, UiKit.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
			ly += 18.0
		ky = maxf(ky + 58.0, ly + 10.0)

func _draw_dishes(r: Rect2) -> void:
	var font := UiKit.body_font()
	var count := GameState.dishes.size()
	var y := _heading(r, "The Menu", "Every meal on this planet, at least once.")
	UiKit.text(_ctl, UiKit.display_font(true), Vector2(r.position.x, r.position.y + 6.0), "%d / %d" % [count, Dishes.DB.size()], 26, UiKit.GOLD_PALE, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x)
	var cols := 2
	var cw := (r.size.x - 14.0) / cols
	var ids: Array = Dishes.DB.keys()
	var row_h := 58.0
	for k in ids.size():
		var id: String = ids[k]
		var d: Dictionary = Dishes.DB[id]
		var eaten := id in GameState.dishes
		var x := r.position.x + 14.0 + (k % cols) * cw
		var ty := y - 30.0 + (k / cols) * row_h
		ItemIcons.draw(_ctl, id, Rect2(Vector2(x, ty), Vector2(46, 46)), not eaten)
		UiKit.text(_ctl, UiKit.display_font(true), Vector2(x + 58.0, ty + 20.0), d["name"] if eaten else "? ? ?", 19, UiKit.TEXT if eaten else UiKit.FAINT.lightened(0.15))
		UiKit.text(_ctl, font, Vector2(x + 58.0, ty + 40.0), d["place"], 14, UiKit.MUTED if eaten else UiKit.FAINT, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
	y += ceili(ids.size() / float(cols)) * row_h + 10.0
	var next := Dishes.next_milestone(count)
	if next > 0:
		var m: Dictionary = Dishes.MILESTONES[next]
		var reward := ("max HP +%d" % m["hp"]) if m.has("hp") else ("+%d stat points" % m["points"])
		UiKit.text(_ctl, font, Vector2(r.position.x + 14.0, y), "Next: %d dishes  -  %s" % [next, reward], 18, UiKit.JADE.lightened(0.3), HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
		UiKit.bar(_ctl, Rect2(Vector2(r.position.x + 14.0, y + 12.0), Vector2(r.size.x * 0.5, 10.0)), count / float(next), UiKit.EXP)
	if Dishes.hp_bonus(count) > 0.0:
		UiKit.text(_ctl, font, Vector2(r.position.x + r.size.x * 0.55 + 40.0, y), "Max HP from the Menu: +%d" % int(Dishes.hp_bonus(count)), 18, UiKit.VIOLET.lightened(0.25), HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
