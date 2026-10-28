class_name NoseInks
extends RefCounted
## The DBZ-style nose marks: every nose on the owner's pencil reference sheet (2026-10-28),
## redrawn as ink strokes, numbered in sheet order (rows left to right). A look picks one by
## name ("nose_ink"); FaceParts.nose_marks draws it.
##
## Each entry: "s" strokes, each [width, [x, y], [x, y], ...] in nose units: y = 0 at the bottom
## of the nose, y = 1 at the top of its line, x to the viewer's right (side views point their tip
## to the viewer's left, as the sheet does). "fill" lists strokes that are closed shapes to shade
## in (alpha of the ink), "curve" draws smooth curves instead of the sheet's angled pencil lines.

const DB := {
	# --- row 1: front and three-quarter views
	"flared_front": {"n": 1, "s": [
		[1.0, [-0.75, 0.2], [-0.5, 0.05], [-0.3, 0.18], [-0.12, 0.06], [0.0, 0.12], [0.12, 0.06], [0.3, 0.18], [0.5, 0.05], [0.75, 0.2]],
		[0.8, [-1.0, 0.4], [-0.75, 0.2], [-0.62, -0.05]], [0.8, [1.0, 0.4], [0.75, 0.2], [0.62, -0.05]],
		[0.6, [-0.32, 1.0], [-0.2, 0.78]], [0.6, [0.32, 1.0], [0.22, 0.78]]]},
	"cup_side": {"n": 2, "curve": true, "s": [
		[1.0, [-0.05, 0.8], [-0.3, 0.3], [-0.25, 0.05], [0.05, 0.0], [0.3, 0.12], [0.36, 0.3]],
		[0.7, [-0.18, 0.32], [0.08, 0.42], [0.3, 0.32]]]},
	"profile_s": {"n": 3, "curve": true, "s": [
		[1.0, [0.2, 1.0], [0.22, 0.55], [0.15, 0.3], [-0.15, 0.22], [-0.3, 0.3], [-0.2, 0.42]],
		[0.8, [0.0, 0.18], [0.15, 0.05], [0.05, -0.15], [-0.15, -0.45]]]},
	"nostrils_front": {"n": 4, "curve": true, "s": [
		[1.0, [-0.42, 0.85], [-0.55, 0.4], [-0.5, 0.12]], [1.0, [0.42, 0.85], [0.55, 0.4], [0.5, 0.12]],
		[0.8, [-0.36, 0.04], [-0.22, 0.2], [-0.08, 0.06]], [0.8, [0.08, 0.06], [0.22, 0.2], [0.36, 0.04]],
		[0.6, [0.0, 0.98], [0.05, 0.78]]]},
	"wedge_tall": {"n": 5, "fill": [0], "s": [
		[1.0, [0.25, 0.95], [0.32, 0.35], [0.08, 0.04], [-0.42, 0.0], [0.15, 0.4], [0.25, 0.95]],
		[0.6, [0.1, 1.32], [0.2, 1.14]], [0.6, [0.22, 1.36], [0.32, 1.2]]]},
	# --- row 2
	"big_flared": {"n": 6, "curve": true, "s": [
		[1.0, [-0.6, 0.22], [-0.42, 0.05], [-0.2, 0.0], [0.0, 0.06], [0.2, 0.0], [0.42, 0.05], [0.6, 0.22]],
		[1.0, [-0.6, 0.22], [-0.72, 0.42], [-0.55, 0.55]], [1.0, [0.6, 0.22], [0.72, 0.42], [0.55, 0.55]],
		[0.8, [-0.72, 0.26], [-0.95, 0.12], [-1.15, 0.06]], [0.8, [0.72, 0.26], [0.95, 0.12], [1.15, 0.06]],
		[0.7, [-0.24, 0.92], [-0.2, 0.6]], [0.7, [0.24, 0.92], [0.2, 0.6]], [0.6, [-0.12, 1.06], [0.25, 1.06]]]},
	"round_small": {"n": 7, "curve": true, "s": [
		[1.0, [-0.3, 0.7], [-0.32, 0.3], [-0.42, 0.14], [-0.25, 0.0], [0.05, -0.02], [0.3, 0.1], [0.38, 0.35]]]},
	"round_wide": {"n": 8, "curve": true, "s": [
		[1.0, [-0.5, 0.55], [-0.5, 0.2], [-0.35, 0.03], [0.0, 0.0], [0.3, 0.08], [0.5, 0.25], [0.52, 0.45]],
		[0.6, [-0.1, 0.36], [0.16, 0.39]]]},
	"chevron_wide": {"n": 9, "fill": [0], "s": [
		[0.8, [-1.0, 0.36], [0.0, 0.06], [1.0, 0.36], [1.0, 0.24], [0.0, -0.1], [-1.0, 0.24], [-1.0, 0.36]]]},
	"facet": {"n": 10, "fill": [0], "s": [
		[0.6, [-0.35, 0.0], [0.0, 0.3], [0.42, 0.36], [0.06, 0.05], [-0.35, 0.0]]]},
	# --- row 3: the side-view ticks
	"angle_open": {"n": 11, "s": [[1.0, [0.3, 1.0], [-0.25, 0.35], [0.05, -0.05]]]},
	"tri_tall": {"n": 12, "fill": [0], "s": [[1.0, [0.1, 1.0], [-0.12, 0.0], [0.15, 0.05], [0.1, 1.0]]]},
	"angle_thin": {"n": 13, "s": [[0.7, [0.2, 0.85], [-0.15, 0.3], [0.1, 0.05]]]},
	"hook_c": {"n": 14, "curve": true, "s": [[1.0, [0.35, 0.95], [0.0, 0.55], [-0.2, 0.2], [-0.05, 0.0], [0.15, 0.05]]]},
	"l_foot": {"n": 15, "s": [[1.0, [0.2, 1.0], [-0.15, 0.15], [-0.05, 0.04], [0.45, 0.1]]]},
	"j_loop": {"n": 16, "curve": true, "s": [[1.0, [0.25, 1.0], [0.25, 0.25], [0.15, 0.04], [-0.15, 0.05], [-0.25, 0.2], [0.0, 0.25]]]},
	"s_tick": {"n": 17, "curve": true, "s": [[1.0, [0.1, 0.95], [0.0, 0.6], [-0.2, 0.35], [0.0, 0.15], [-0.05, 0.0], [0.1, -0.1]]]},
	# --- row 4
	"caida": {"n": 18, "s": [[1.0, [-0.2, 0.36], [0.0, 0.0], [0.15, 0.42]], [0.8, [-0.06, 0.26], [0.05, 0.4]]]},
	"long_kink": {"n": 19, "s": [[1.0, [0.1, 1.0], [0.0, 0.55], [-0.3, 0.2], [0.2, 0.1], [0.25, -0.1]]]},
	"d_shape": {"n": 20, "fill": [0], "s": [[1.0, [-0.05, 0.75], [0.2, 0.4], [0.1, 0.0], [-0.05, 0.0], [-0.05, 0.75]]]},
	"j_foot": {"n": 21, "fill": [0], "s": [[1.0, [0.25, 1.0], [0.3, 0.25], [0.2, 0.0], [-0.4, 0.05], [-0.3, 0.16], [0.25, 0.1]]]},
	"z_kink": {"n": 22, "s": [[1.0, [0.0, 1.0], [0.1, 0.6], [-0.25, 0.15], [0.15, 0.15], [0.05, 0.0], [0.3, -0.1]]]},
	"j_long": {"n": 23, "curve": true, "s": [[1.0, [0.45, 1.0], [0.25, 0.6], [0.2, 0.15], [0.0, 0.0], [-0.35, 0.0]], [0.7, [-0.35, 0.0], [0.0, 0.08]]]},
	"spike": {"n": 24, "fill": [0], "s": [[1.0, [0.05, 1.0], [0.15, 0.25], [-0.05, 0.0], [0.02, 0.5], [0.05, 1.0]]]},
	# --- row 5
	"l_small_tri": {"n": 25, "fill": [0], "s": [[1.0, [0.15, 0.8], [0.25, 0.2], [0.2, 0.0], [-0.3, 0.05], [0.0, 0.2], [0.2, 0.1]]]},
	"loop_small": {"n": 26, "curve": true, "s": [[1.0, [0.15, 0.85], [0.0, 0.45], [-0.25, 0.15], [-0.1, 0.0], [0.25, 0.05], [-0.1, 0.12]]]},
	"k_wedge": {"n": 27, "fill": [0], "s": [[1.0, [0.05, 0.95], [-0.3, 0.4], [0.15, 0.04], [0.32, 0.14], [-0.05, 0.36], [0.05, 0.95]]]},
	"j_tri": {"n": 28, "fill": [0], "s": [[1.0, [0.2, 1.0], [0.35, 0.45], [0.3, 0.15], [0.1, 0.05], [-0.35, 0.15], [0.05, 0.25], [0.3, 0.15]]]},
	"profile_long": {"n": 29, "s": [[1.0, [0.1, 1.4], [0.15, 1.2], [0.0, 1.1], [-0.45, 0.35], [-0.3, 0.15], [0.0, 0.2], [0.15, 0.05], [0.45, 0.0]]]},
	"j_soft": {"n": 30, "curve": true, "s": [[1.0, [0.1, 0.9], [0.25, 0.4], [0.2, 0.1], [0.0, 0.0], [-0.25, 0.05]]]},
	# --- row 6
	"profile_down": {"n": 31, "s": [[0.9, [0.2, 1.0], [-0.2, 0.15]], [0.9, [-0.2, 0.15], [0.45, 0.32]],
		[0.6, [-0.05, 0.3], [0.05, 0.1]], [0.4, [0.3, 0.8], [0.9, 1.1]]]},
	"l_short": {"n": 32, "s": [[1.0, [0.0, 0.7], [0.05, 0.1], [0.1, 0.0], [0.4, 0.02]]]},
	"tick_tri": {"n": 33, "fill": [0], "s": [[1.0, [0.05, 0.85], [0.0, 0.25], [-0.2, 0.05], [0.25, 0.0], [0.05, 0.25]]]},
	"chev_small": {"n": 34, "s": [[1.0, [-0.05, 0.4], [0.12, 0.2], [0.0, 0.0]]]},
	"tri_small": {"n": 35, "fill": [0], "s": [[1.0, [0.1, 0.55], [-0.15, 0.05], [0.15, 0.0], [0.1, 0.55]]]},
	# --- row 7
	"hook_low": {"n": 36, "curve": true, "s": [[1.0, [0.15, 0.6], [0.2, 0.25], [0.05, 0.05], [-0.35, 0.0]]]},
	"gt_tiny": {"n": 37, "curve": true, "s": [[0.8, [-0.05, 0.45], [0.1, 0.25], [-0.05, 0.05]]]},
	"tri_filled": {"n": 38, "fill": [0], "solid": true, "s": [[1.0, [0.15, 0.85], [0.05, 0.35], [-0.2, 0.1], [0.1, 0.0], [0.15, 0.85]]]},
	"diamond_open": {"n": 39, "s": [[0.8, [0.15, 0.75], [-0.1, 0.4], [0.0, 0.05], [0.15, 0.25], [0.15, 0.75]]]},
	"profile_kink": {"n": 40, "s": [[1.0, [0.2, 1.3], [0.1, 1.05], [0.15, 0.85], [-0.1, 0.35], [-0.4, 0.05], [-0.1, 0.1], [0.2, 0.05]]]},
}

## Names in sheet order.
static func names() -> Array:
	var out := DB.keys()
	out.sort_custom(func(a: String, b: String) -> bool: return int(DB[a]["n"]) < int(DB[b]["n"]))
	return out

## Draw nose `id` on `cv`: its bottom at `bottom` (face space, mm), `size` mm from bottom to
## the top of its line, ink `color` (fills use the colour's alpha halved, or full when "solid").
static func draw(cv: FaceCanvas, id: String, bottom: Vector2, size: float, color: Color, ink := 1.5) -> void:
	var nose: Dictionary = DB.get(id, {})
	if nose.is_empty():
		return
	var strokes: Array = nose["s"]
	var fills: Array = nose.get("fill", [])
	var curve: bool = nose.get("curve", false)
	for k in strokes.size():
		var st: Array = strokes[k]
		var pts := PackedVector2Array()
		for i in range(1, st.size()):
			pts.append(bottom + Vector2(float(st[i][0]), float(st[i][1])) * size)
		if k in fills:
			var shade := color
			shade.a = color.a if nose.get("solid", false) else color.a * 0.5
			cv.fill_poly(pts, shade)
		var path := FaceCanvas.spline(pts, 8) if curve and pts.size() >= 3 else _dense(pts)
		var w: float = float(st[0]) * ink * size / 30.0
		cv.ribbon(path, FaceCanvas.taper(path.size(), w * 0.4, w, w * 0.35, 0.45), color)

## A polyline with points along each segment, so the stroke tapers along its whole length
## and keeps its corners.
static func _dense(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in pts.size() - 1:
		for k in 4:
			out.append(pts[i].lerp(pts[i + 1], k / 4.0))
	out.append(pts[pts.size() - 1])
	return out
