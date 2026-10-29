class_name ItemIcons
extends RefCounted
## Small cel icons for gear, key items, meals and equipment slots, drawn in code on any
## CanvasItem: ItemIcons.draw(ci, "power_gloves", rect). Each sits on a lacquer tile with a
## rim in its rarity colour; an unknown id gets a capsule.

const INK := Color(0.05, 0.03, 0.06)

## Gear tint: weighted training gear is iron grey, the rest takes its stat's colour.
static func tint(id: String) -> Color:
	if Items.DB.has(id):
		var d: Dictionary = Items.DB[id]
		if d.has("exp"):
			return Color(0.62, 0.62, 0.7)
		if d.has("strength"):
			return Color(0.92, 0.4, 0.35)
		if d.has("power"):
			return Color(0.62, 0.48, 0.98)
		if d.has("endurance"):
			return Color(0.4, 0.75, 0.95)
		if d.has("speed"):
			return Color(0.45, 0.9, 0.55)
		return UiKit.GOLD
	if Items.KEYS.has(id):
		return UiKit.GOLD
	if Dishes.DB.has(id):
		return Color(1.0, 0.72, 0.4)
	return UiKit.MUTED

## The tile and icon. `empty` draws a dim slot outline for `id` (a slot name or gear id).
static func draw(ci: CanvasItem, id: String, r: Rect2, empty := false) -> void:
	var c := tint(id)
	var tile := UiKit.notched(r, r.size.x * 0.16)
	ci.draw_colored_polygon(tile, Color(0.02, 0.015, 0.035, 0.9))
	UiKit.gradient_rect(ci, Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, r.size.y * 0.5)), Color(c.r, c.g, c.b, 0.16), Color(c.r, c.g, c.b, 0.0))
	ci.draw_polyline(UiKit.closed(tile), c if not empty else UiKit.FAINT, 1.5, true)
	var u := r.size.x / 32.0  # icons are drawn on a 32-unit grid
	var o := r.position
	var p := func(x: float, y: float) -> Vector2:
		return o + Vector2(x, y) * u
	var fill := c if not empty else Color(UiKit.FAINT.r, UiKit.FAINT.g, UiKit.FAINT.b, 0.6)
	var hi := fill.lightened(0.45)
	var key := id
	if empty:
		key = _slot_icon(id)
	match key:
		"power_gloves", "gloves":
			_shape(ci, [p.call(9, 25), p.call(8, 14), p.call(10, 9), p.call(13, 8), p.call(14, 12), p.call(16, 7), p.call(19, 7), p.call(20, 11), p.call(23, 10), p.call(25, 13), p.call(24, 25)], fill, u)
			ci.draw_rect(Rect2(p.call(8, 22), Vector2(17, 4) * u), fill.darkened(0.3))
			_shine(ci, p.call(12, 12), p.call(14, 18), hi, u)
		"energy_bracers", "heavy_armbands":
			for k in 2:
				var y := 9.0 + k * 9.0
				_shape(ci, [p.call(7, y), p.call(25, y), p.call(25, y + 6), p.call(7, y + 6)], fill, u)
				ci.draw_line(p.call(9, y + 3), p.call(23, y + 3), hi, 1.2 * u)
			if key == "heavy_armbands":
				for x: float in [11.0, 16.0, 21.0]:
					ci.draw_circle(p.call(x, 12), 1.3 * u, INK)
					ci.draw_circle(p.call(x, 21), 1.3 * u, INK)
			else:
				UiKit.diamond(ci, p.call(16, 12), 2.2 * u, Color(1, 1, 1, 0.8))
		"battle_suit", "weighted_suit", "body":
			_shape(ci, [p.call(10, 6), p.call(13, 8), p.call(19, 8), p.call(22, 6), p.call(27, 11), p.call(24, 15), p.call(22, 13), p.call(22, 26), p.call(10, 26), p.call(10, 13), p.call(8, 15), p.call(5, 11)], fill, u)
			ci.draw_line(p.call(16, 9), p.call(16, 26), fill.darkened(0.35), 1.2 * u)
			if key == "weighted_suit":
				for y: float in [15.0, 20.0]:
					ci.draw_rect(Rect2(p.call(11, y), Vector2(10, 2.5) * u), INK)
			_shine(ci, p.call(12, 11), p.call(12, 20), hi, u)
		"speed_boots", "heavy_boots", "feet":
			_shape(ci, [p.call(11, 6), p.call(18, 6), p.call(18, 19), p.call(26, 22), p.call(26, 26), p.call(9, 26), p.call(10, 18)], fill, u)
			ci.draw_rect(Rect2(p.call(10, 9), Vector2(8, 2) * u), fill.darkened(0.3))
			if key == "speed_boots":
				for k in 3:
					ci.draw_line(p.call(2 + k, 12 + k * 4), p.call(7, 12 + k * 4), Color(1, 1, 1, 0.65), 1.3 * u)
			_shine(ci, p.call(13, 9), p.call(13, 18), hi, u)
		"ki_ring", "acc":
			ci.draw_arc(p.call(16, 18), 7.5 * u, 0.0, TAU, 32, fill, 3.0 * u, true)
			ci.draw_arc(p.call(16, 18), 9.0 * u, -2.2, -0.9, 12, hi, 1.0 * u, true)
			UiKit.diamond(ci, p.call(16, 9), 4.0 * u, Color(0.75, 0.6, 1.0) if not empty else fill)
			UiKit.diamond(ci, p.call(15, 8), 1.4 * u, Color(1, 1, 1, 0.8))
		"magnet_charm":
			ci.draw_arc(p.call(16, 14), 7.0 * u, PI, TAU, 20, fill, 4.0 * u, false)
			ci.draw_rect(Rect2(p.call(7, 14), Vector2(4, 8) * u), fill)
			ci.draw_rect(Rect2(p.call(21, 14), Vector2(4, 8) * u), fill)
			ci.draw_rect(Rect2(p.call(7, 22), Vector2(4, 3) * u), Color(0.95, 0.95, 0.95))
			ci.draw_rect(Rect2(p.call(21, 22), Vector2(4, 3) * u), Color(0.95, 0.95, 0.95))
		"hand":
			_shape(ci, [p.call(9, 25), p.call(8, 14), p.call(13, 9), p.call(19, 8), p.call(25, 13), p.call(24, 25)], fill, u)
		"rusty_key":
			ci.draw_arc(p.call(11, 12), 5.0 * u, 0.0, TAU, 24, Color(0.75, 0.45, 0.25), 2.5 * u, true)
			ci.draw_line(p.call(15, 15), p.call(26, 26), Color(0.75, 0.45, 0.25), 2.5 * u)
			ci.draw_line(p.call(22, 22), p.call(25, 19), Color(0.75, 0.45, 0.25), 2.2 * u)
			ci.draw_line(p.call(24, 24), p.call(27, 21), Color(0.75, 0.45, 0.25), 2.2 * u)
		"scouter":
			_shape(ci, [p.call(6, 14), p.call(20, 9), p.call(27, 10), p.call(27, 22), p.call(20, 23), p.call(6, 18)], Color(0.2, 0.85, 0.35, 0.8), u)
			ci.draw_rect(Rect2(p.call(4, 12), Vector2(5, 9) * u), Color(0.85, 0.85, 0.85))
			ci.draw_line(p.call(9, 15), p.call(25, 12), Color(1, 1, 1, 0.6), 1.0 * u)
		"senzu":
			_shape(ci, [p.call(10, 18), p.call(12, 10), p.call(18, 8), p.call(23, 13), p.call(22, 21), p.call(15, 25)], Color(0.45, 0.78, 0.3), u)
			ci.draw_arc(p.call(16, 16), 4.5 * u, 2.4, 4.4, 10, Color(0.25, 0.5, 0.18), 1.2 * u, true)
			_shine(ci, p.call(13, 12), p.call(13, 16), Color(0.85, 1, 0.75), u)
		"dish":
			_dish(ci, p, u, fill)
		_:
			if Dishes.DB.has(key):
				_dish(ci, p, u, fill)
			else:  # a capsule
				_shape(ci, [p.call(10, 10), p.call(22, 10), p.call(25, 16), p.call(22, 22), p.call(10, 22), p.call(7, 16)], fill, u)
				ci.draw_line(p.call(16, 10), p.call(16, 22), INK, 1.5 * u)
				_shine(ci, p.call(11, 13), p.call(14, 13), hi, u)

## A steaming bowl with chopsticks.
static func _dish(ci: CanvasItem, p: Callable, u: float, c: Color) -> void:
	for k in 3:
		var x := 11.0 + k * 5.0
		ci.draw_polyline(PackedVector2Array([p.call(x, 13), p.call(x + 1.5, 10), p.call(x, 7), p.call(x + 1.5, 4)]), Color(1, 1, 1, 0.45), 1.2 * u, true)
	ci.draw_line(p.call(18, 4), p.call(27, 15), Color(0.75, 0.55, 0.3), 1.4 * u)
	ci.draw_line(p.call(21, 3), p.call(28, 14), Color(0.75, 0.55, 0.3), 1.4 * u)
	_shape(ci, [p.call(5, 15), p.call(27, 15), p.call(24, 22), p.call(19, 25), p.call(13, 25), p.call(8, 22)], c, u)
	ci.draw_rect(Rect2(p.call(5, 14), Vector2(22, 2.5) * u), c.lightened(0.3))
	ci.draw_line(p.call(9, 19), p.call(23, 19), c.darkened(0.3), 1.4 * u)

static func _shape(ci: CanvasItem, pts: Array, c: Color, u: float) -> void:
	var poly := PackedVector2Array()
	for q: Vector2 in pts:
		poly.append(q)
	ci.draw_colored_polygon(poly, c)
	ci.draw_polyline(UiKit.closed(poly), INK, maxf(1.2 * u, 1.0), true)

static func _shine(ci: CanvasItem, a: Vector2, b: Vector2, c: Color, u: float) -> void:
	ci.draw_line(a, b, Color(c.r, c.g, c.b, 0.7), 1.4 * u)

## Which icon an empty slot shows.
static func _slot_icon(slot: String) -> String:
	if slot.begins_with("acc"):
		return "acc"
	return slot
