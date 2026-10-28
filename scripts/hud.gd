class_name Hud
extends Control
## HP / Ki / stamina / EXP bars with level, form name and the selected ki technique, and
## the scan panel (T): ki sense gives the nearest foe's name, a power band and its HP bar;
## carrying the Scouter adds exact numbers.

const BANDS := ["Weaker", "Even", "Stronger", "Overwhelming"]
const BAND_COLORS := [Color(0.5, 1.0, 0.6), Color(1, 1, 1), Color(1.0, 0.7, 0.3), Color(1.0, 0.35, 0.35)]
const SENSE_RANGE := 16.0

var player: Player

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("scan") and not GameState.input_locked:
		GameState.sensing = not GameState.sensing
	queue_redraw()

func _draw() -> void:
	if player == null:
		return
	var font := ThemeDB.fallback_font
	_bar(Vector2(16, 16), player.hp / player.max_hp, Color(0.85, 0.2, 0.25), 260.0, 16.0)
	_bar(Vector2(16, 40), player.ki / player.max_ki, Color(0.55, 0.35, 0.9), 260.0, 16.0)
	_bar(Vector2(16, 64), player.stamina / player.max_stamina, Color(0.3, 0.8, 0.4), 160.0, 10.0)
	var need := GameState.xp_needed(GameState.level)
	_bar(Vector2(16, 82), float(GameState.xp) / need, Color(0.95, 0.8, 0.3), 160.0, 6.0)
	_text(font, Vector2(290, 30), "Lv %d" % GameState.level, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	if player.form > 0:
		_text(font, Vector2(290, 54), GameState.FORM_NAMES[player.form], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.75, 0.6, 1.0))
	var move: String = GameState.KI_MOVES[GameState.ki_move()]["name"]
	_text(font, Vector2(290, 80), "Ki: %s%s" % [move, "  (Q)" if GameState.ki_moves.size() > 1 else ""], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.8, 0.75, 1.0))
	if GameState.stat_points > 0:
		_text(font, Vector2(190, 98), "%d stat points (Enter)" % GameState.stat_points, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.6, 1, 0.7))

	if GameState.sensing:
		_draw_sense(font)

## 0-3: how a fight would go, from how many of Oto's hits it takes against how many of its own.
static func band(e: Node3D, p: Player) -> int:
	var my_hit: float = (4.0 + GameState.stat("strength") * 0.8) * GameState.FORM_DAMAGE[p.form]
	var hits_to_win := float(e.get("max_hp")) / maxf(my_hit, 1.0)
	var their_hit: float = float(e.get("damage")) if e.get("damage") != null else 10.0
	their_hit *= 1.0 - minf(GameState.stat("endurance") * 0.015, 0.7)
	var r := hits_to_win / (p.max_hp / maxf(their_hit, 0.1))
	return 0 if r < 0.25 else (1 if r < 0.8 else (2 if r < 2.5 else 3))

func _nearest_foe() -> Node3D:
	var best: Node3D = null
	var best_d := SENSE_RANGE
	for e: Node3D in get_tree().get_nodes_in_group("enemies"):
		var d := e.position.distance_to(player.position)
		if d < best_d:
			best_d = d
			best = e
	return best

func _draw_sense(font: Font) -> void:
	var w := 320.0
	var x := get_viewport_rect().size.x - w - 16.0
	var scouter := GameState.has_key("scouter")
	draw_rect(Rect2(x, 16, w, 104), Color(0.03, 0.02, 0.06, 0.8))
	_text(font, Vector2(x + 12, 40), "SCOUTER" if scouter else "KI SENSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.7, 0.65, 0.9))
	var e := _nearest_foe()
	if e == null:
		_text(font, Vector2(x + 12, 72), "Nothing nearby.", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.6, 0.6, 0.7))
		return
	var who: String = str(e.get("display_name")) if e.get("display_name") != null else "???"
	_text(font, Vector2(x + 12, 68), who, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	var b := band(e, player)
	_text(font, Vector2(x + 12, 68), BANDS[b], HORIZONTAL_ALIGNMENT_RIGHT, w - 24, 20, BAND_COLORS[b])
	var hp: float = e.get("hp")
	var max_hp: float = e.get("max_hp")
	_bar(Vector2(x + 12, 80), hp / max_hp, Color(0.3, 0.9, 0.3), w - 24, 8.0)
	if scouter:
		var atk: Variant = e.get("damage")
		_text(font, Vector2(x + 12, 110), "HP %d / %d    Attack %s" % [int(hp), int(max_hp), str(int(atk)) if atk != null else "?"], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.6, 1.0, 0.6))

## Text with a dark outline, readable on sand and snow as well as at night.
func _text(font: Font, pos: Vector2, text: String, align: HorizontalAlignment, width: float, font_size: int, color: Color) -> void:
	draw_string_outline(font, pos, text, align, width, font_size, 6, Color(0, 0, 0, 0.85))
	draw_string(font, pos, text, align, width, font_size, color)

func _bar(pos: Vector2, frac: float, color: Color, width: float, height: float) -> void:
	draw_rect(Rect2(pos - Vector2(2, 2), Vector2(width + 4, height + 4)), Color.BLACK)
	draw_rect(Rect2(pos, Vector2(width * clampf(frac, 0.0, 1.0), height)), color)
