class_name Hud
extends Control
## HP / Ki / stamina / EXP bars with level, form name and the selected ki technique, and
## the scan panel (T): ki sense gives the nearest foe's name, a power band and its HP bar;
## carrying the Scouter adds exact numbers.

const BANDS := ["Weaker", "Even", "Stronger", "Overwhelming"]
const BAND_COLORS := [Color(0.5, 1.0, 0.6), Color(1, 1, 1), Color(1.0, 0.7, 0.3), Color(1.0, 0.35, 0.35)]
const SENSE_RANGE := 16.0

var player: Player

var _portrait: Portrait
var _ghost_hp := 1.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait = Portrait.new()
	_portrait.position = Vector2(20, 18)
	_portrait.size = Vector2(76, 88)
	add_child(_portrait)
	_portrait.set_speaker("Oto")

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("scan") and not GameState.input_locked:
		GameState.sensing = not GameState.sensing
	if player:
		# the pale trail behind the HP bar catches up a moment after a hit
		var hp := player.hp / player.max_hp
		_ghost_hp = hp if hp > _ghost_hp else move_toward(_ghost_hp, hp, delta * 0.35)
		_portrait.variant = "void" if player.form > 0 else ""
	_portrait.visible = player != null
	queue_redraw()

func _draw() -> void:
	if player == null:
		return
	var font := UiKit.body_font()
	# the plate: portrait medallion, then the meters beside it
	var plate := Rect2(Vector2(12, 10), Vector2(380, 108))
	UiKit.frame(self, plate, UiKit.GOLD, false, 10.0)
	var pr := Rect2(_portrait.position, _portrait.size).grow(2.0)
	draw_polyline(UiKit.closed(UiKit.notched(pr, 7.0)), UiKit.GOLD, 1.5, true)
	var x := 112.0
	var w := 230.0
	UiKit.bar(self, Rect2(Vector2(x, 26), Vector2(w, 14)), player.hp / player.max_hp, UiKit.HP, _ghost_hp)
	UiKit.bar(self, Rect2(Vector2(x, 50), Vector2(w, 11)), player.ki / player.max_ki, UiKit.KI)
	UiKit.bar(self, Rect2(Vector2(x, 70), Vector2(w * 0.62, 6)), player.stamina / player.max_stamina, UiKit.STAMINA)
	var need := GameState.xp_needed(GameState.level)
	UiKit.bar(self, Rect2(Vector2(x, 84), Vector2(w * 0.62, 4)), float(GameState.xp) / need, UiKit.EXP)
	_text(font, Vector2(x + 4, 38), "%d" % int(player.hp), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.9))
	# level badge
	var badge := Vector2(plate.end.x - 22, 34)
	UiKit.diamond(self, badge, 17.0, UiKit.INK)
	draw_polyline(UiKit.closed(PackedVector2Array([badge + Vector2(0, -17), badge + Vector2(17, 0), badge + Vector2(0, 17), badge + Vector2(-17, 0)])), UiKit.GOLD, 1.5, true)
	_text(UiKit.display_font(true), badge + Vector2(-20, 6), "%d" % GameState.level, HORIZONTAL_ALIGNMENT_CENTER, 40, 16, UiKit.GOLD_PALE)
	if player.form > 0:
		_text(UiKit.display_font(true), Vector2(x + w * 0.62 + 16, 80), GameState.FORM_NAMES[player.form].split(":")[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiKit.VIOLET.lightened(0.2))
	var move: String = GameState.KI_MOVES[GameState.ki_move()]["name"]
	_text(font, Vector2(x, 103), "Ki: %s%s" % [move, "   [Q] switch" if GameState.ki_moves.size() > 1 else ""], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.8, 1.0))
	if GameState.stat_points > 0:
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 250.0)
		_text(font, Vector2(16, 136), "%d stat points  [Enter]" % GameState.stat_points, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(UiKit.JADE.r, UiKit.JADE.g + 0.2, UiKit.JADE.b, pulse))

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
	UiKit.frame(self, Rect2(x, 12, w, 112), UiKit.VIOLET, false, 10.0)
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
	UiKit.bar(self, Rect2(Vector2(x + 14, 80), Vector2(w - 34, 8.0)), hp / max_hp, UiKit.STAMINA)
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
