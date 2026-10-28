class_name FaceParts
extends RefCounted
## The face part kit: eyes, brows, mouths and nose marks drawn as cel art, plus the 3D nose and
## chin shapes. Parts are interchangeable: a Face look (face.gd) picks one of each and a skin
## colour, and FaceRig animates them. Everything is in face space (FaceCanvas): millimetres,
## +X toward the character's left, +Y up, the origin on the centre line at the eye line.
##
## The eye, brow and mouth styles are traced from the owner's reference sheets (2026-10-28):
##   tall_oval   Chi-Chi, baby Bulma: tall egg-shaped eye, huge oval iris, lashes
##   triangle    Pan, Marron: rounded triangle, apex toward the nose
##   almond      Android 18, Mai: narrow, heavy upper line, slim lower, one flick
##   wide_round  Videl: wide and round, lash flicks
##   sharp       Vegeta, Goku, Piccolo: angular wedge, heavy lid (the hard-edged sheet)
##   dot         the bare dot eye
## Mouths follow the pencil sheet: dash, dash with a lower lip, slight smile, frown, cat, and
## the open shapes (ah, oh, ee, wide, grin).

# --- skin colours -----------------------------------------------------------------------

const SKINS := {
	"dusk": Color(0.29, 0.16, 0.09),   # Oto: brown-purple of dusk
	"deep": Color(0.36, 0.21, 0.14),
	"tan": Color(0.7, 0.5, 0.35),
	"peach": Color(0.98, 0.83, 0.7),
	"pale": Color(1.0, 0.86, 0.76),
	"green": Color(0.45, 0.8, 0.4),    # Namekians
}

# --- eyes -------------------------------------------------------------------------------
# up / low: profile of the upper and lower lid, [s along the eye, height as a fraction of
# lid_h / low_h]. tilt: how far the outer corner sits above the inner one. ink: thickness of
# the upper lid line, inner to outer.

const EYES := {
	"tall_oval": {"w": 46.0, "x": 28.0, "tilt": 0.05, "lid_h": 36.0, "low_h": 17.0,
		"up": [[0, 0], [0.08, 0.5], [0.26, 0.9], [0.5, 1.0], [0.75, 0.9], [0.93, 0.5], [1, 0]],
		"low": [[0, 0], [0.1, 0.55], [0.3, 0.93], [0.55, 1.0], [0.8, 0.72], [1, 0]],
		"iris": [14.5, 26.0], "ink": [3.2, 5.2], "wing": 3.0, "lashes": 3, "lash_len": 7.5},
	"triangle": {"w": 48.0, "x": 27.0, "tilt": 0.08, "lid_h": 32.0, "low_h": 15.0,
		"up": [[0, 0], [0.1, 0.55], [0.28, 1.0], [0.52, 0.84], [0.78, 0.5], [1, 0]],
		"low": [[0, 0], [0.25, 0.7], [0.55, 1.0], [0.82, 0.68], [1, 0]],
		"iris": [13.0, 21.0], "ink": [2.8, 5.0], "wing": 4.0, "lashes": 2, "lash_len": 6.5},
	"almond": {"w": 58.0, "x": 26.0, "tilt": 0.12, "lid_h": 24.0, "low_h": 12.0,
		"up": [[0, 0], [0.06, 0.4], [0.22, 0.88], [0.4, 1.0], [0.62, 0.86], [0.82, 0.5], [1, 0]],
		"low": [[0, 0], [0.12, 0.5], [0.35, 0.92], [0.6, 1.0], [0.85, 0.6], [1, 0]],
		"iris": [13.5, 18.0], "ink": [2.6, 5.6], "wing": 7.0, "lashes": 2, "lash_len": 6.0, "crease": true},
	"wide_round": {"w": 50.0, "x": 27.0, "tilt": 0.04, "lid_h": 30.0, "low_h": 22.0,
		"up": [[0, 0], [0.08, 0.55], [0.28, 0.95], [0.5, 1.0], [0.75, 0.92], [0.93, 0.55], [1, 0]],
		"low": [[0, 0], [0.1, 0.6], [0.3, 0.95], [0.55, 1.0], [0.8, 0.8], [1, 0]],
		"iris": [15.0, 20.0], "ink": [3.0, 5.0], "wing": 3.5, "lashes": 3, "lash_len": 6.5},
	"sharp": {"w": 56.0, "x": 22.0, "tilt": 0.26, "lid_h": 24.0, "low_h": 9.0, "angular": true,
		"up": [[0, 0], [0.3, 0.78], [0.78, 1.0], [1, 0.1]],
		"low": [[0, 0], [0.4, 0.8], [0.85, 0.6], [1, 0]],
		"iris": [11.5, 15.0], "ink": [5.0, 8.0], "wing": 0.0, "lashes": 0, "lash_len": 0.0, "glint": 0.7},
	"dot": {"w": 12.0, "x": 50.0, "dot": true, "iris": [4.5, 6.5]},
}

## Eye states: o = how open (1 normal), closed = "down" (blink, sleep) or "up" (a happy arc),
## iris_k = iris size, squint = lower lid raised, glint = catch-light, look = gaze, in mm.
const EYE_STATES := {
	"open": {},
	"half": {"o": 0.5},
	"narrow": {"o": 0.7, "squint": 0.35},
	"wide": {"o": 1.22, "iris_k": 0.78},
	"closed": {"closed": "down"},
	"happy": {"closed": "up"},
	"left": {"look": 5.0},
	"right": {"look": -5.0},
}

# --- brows ------------------------------------------------------------------------------

const BROWS := {
	"calm": {"pts": [[22, 40], [56, 47], [94, 39]], "w": [2.6, 3.6, 0.9]},
	"arc": {"pts": [[24, 52], [56, 62], [92, 50]], "w": [1.6, 2.2, 0.6]},   # the thin floating arc
	"thin": {"pts": [[20, 42], [58, 47], [96, 50]], "w": [1.8, 2.2, 1.0]},
	"slash": {"pts": [[16, 34], [56, 44], [98, 56]], "w": [9.0, 9.5, 5.0]},  # the heavy slab
}

## lift / tilt in mm (tilt > 0 raises the inner end: worry; < 0 lowers it: anger),
## arch scales the curve, w the thickness.
const BROW_STATES := {
	"calm": {},
	"raised": {"lift": 9.0, "arch": 1.2},
	"angry": {"tilt": -9.0, "lift": -5.0, "arch": 0.6},
	"cold": {"tilt": -4.0, "lift": -3.0, "arch": 0.3},
	"sad": {"tilt": 9.0, "lift": 2.0},
	"flat": {"arch": 0.0},
}

# --- mouths -----------------------------------------------------------------------------
# w = width, y = baseline, ink = line thickness, curve > 0 turns the corners up, lip = depth
# of the lower lip (0 = none).

const MOUTHS := {
	"still": {"w": 32.0, "y": -80.0, "ink": 2.4, "curve": 0.8, "lip": 5.0},
	"flat": {"w": 34.0, "y": -80.0, "ink": 2.4, "curve": 0.4, "lip": 0.0},
	"soft": {"w": 36.0, "y": -80.0, "ink": 2.2, "curve": 3.0, "lip": 5.5},
	"pout": {"w": 30.0, "y": -80.0, "ink": 2.2, "curve": 0.0, "lip": 8.0},
	"frown": {"w": 32.0, "y": -80.0, "ink": 2.4, "curve": -3.5, "lip": 0.0},
	"cat": {"w": 38.0, "y": -80.0, "ink": 2.2, "cat": true, "lip": 0.0},
}

## Mouth shapes: the closed shapes use the style's own line; the open ones are shared.
const MOUTH_SHAPES := ["closed", "smile", "frown", "ah", "oh", "ee", "wide", "grin"]

# --- 3D nose and chin -------------------------------------------------------------------
# Small shapes of the skin's own material, set into the head. "ball": an ellipsoid w x h, `out`
# off the face. "wedge": the DBZ nose, a ridge from the bridge down to a tip `out` off the face,
# `len` long and `w` wide at the nostrils. y is the height of the nose's bottom from the eye
# line; "ink" is the default mark drawn on it (NoseInks), "size" that mark's height in mm.

const NOSES := {
	"none": {},
	"button": {"shape": "ball", "w": 16.0, "h": 13.0, "out": 5.0, "y": -40.0, "ink": "round_small", "size": 16.0},
	"wedge": {"shape": "wedge", "w": 15.0, "len": 30.0, "out": 8.0, "y": -46.0, "ink": "l_foot", "size": 28.0},
	# sheet #28 in profile (a stem down to a triangle base), #33 head on
	"long": {"shape": "wedge", "w": 22.0, "len": 50.0, "out": 15.0, "y": -50.0, "tip_k": 0.1, "mid_k": 0.42, "ink": "tick_tri", "size": 44.0},
	"pointed": {"shape": "wedge", "w": 11.0, "len": 34.0, "out": 11.0, "y": -48.0, "ink": "angle_open", "size": 32.0},
	"broad": {"shape": "ball", "w": 26.0, "h": 15.0, "out": 6.5, "y": -46.0, "ink": "nostrils_front", "size": 22.0},
}

const CHINS := {
	"soft": {},
	"round": {"w": 54.0, "h": 22.0, "out": 3.0, "y": -126.0},
	"pointed": {"w": 28.0, "h": 30.0, "out": 7.0, "y": -128.0},
	"square": {"w": 62.0, "h": 20.0, "out": 4.0, "y": -124.0},
}

# --- ears -------------------------------------------------------------------------------
# DBZ ears from the owner's ear sheet (2026-10-28), inked onto the ear the head mesh already
# has. Strokes are [width, [u, v], ...] across the ear's rect: u from its front edge (toward
# the face) to the back, v from the lobe up. "fill" strokes are closed and shaded.

const EARS := {
	"none": {},
	"dbz": {"fill": [4, 5], "shade": [6], "s": [
		# the rim: up the front, over the top, down the back, round the lobe
		[1.0, [0.22, 0.86], [0.38, 0.98], [0.62, 0.99], [0.82, 0.86], [0.93, 0.6], [0.88, 0.32], [0.7, 0.1], [0.46, 0.0], [0.24, 0.04], [0.14, 0.14]],
		# the fold inside the rim: the big C, from the front of the top round to above the lobe
		[0.8, [0.3, 0.8], [0.48, 0.9], [0.68, 0.84], [0.78, 0.6], [0.72, 0.34], [0.56, 0.2]],
		# the ridge inside it, forked at the top
		[0.7, [0.42, 0.72], [0.58, 0.68], [0.62, 0.48], [0.52, 0.3]],
		[0.6, [0.42, 0.72], [0.3, 0.62]],
		# the tragus, a small shaded block in front of the hole
		[0.8, [0.12, 0.54], [0.26, 0.56], [0.3, 0.45], [0.18, 0.42], [0.12, 0.54]],
		# the stair-step notch near the lobe
		[0.9, [0.1, 0.16], [0.16, 0.27], [0.27, 0.27], [0.3, 0.33], [0.42, 0.31], [0.44, 0.22], [0.3, 0.16], [0.1, 0.16]],
		# the bowl's shadow, from under the ridge down behind the tragus
		[0.0, [0.3, 0.62], [0.5, 0.62], [0.56, 0.45], [0.46, 0.3], [0.34, 0.36], [0.32, 0.5], [0.3, 0.62]],
		[0.6, [0.36, 0.6], [0.5, 0.6], [0.54, 0.5]],
		[0.6, [0.32, 0.56], [0.44, 0.44], [0.46, 0.3]],
	]},
}

## An ear's lines in ear space (Face.EAR_REGION: mm, +X toward the back of the head), the ear
## `size` mm across and tall round the origin. Null when the style draws nothing.
static func ear(style: Dictionary, size: Vector2, pal: Dictionary) -> FaceCanvas:
	if style.is_empty():
		return null
	var skin: Color = pal["skin"]
	var cv := FaceCanvas.new(Face.EAR_REGION, Color(skin.r, skin.g, skin.b, 0.0))
	var rect := Rect2(-size * 0.5, size)
	var ink := skin.lerp(Color(0.02, 0.01, 0.02), 0.8)
	ink.a = 0.95
	var strokes: Array = style["s"]
	var fills: Array = style.get("fill", [])
	var shades: Array = style.get("shade", [])
	for k in strokes.size():
		var st: Array = strokes[k]
		var pts := PackedVector2Array()
		for i in range(1, st.size()):
			pts.append(rect.position + Vector2(float(st[i][0]) * rect.size.x, float(st[i][1]) * rect.size.y))
		if k in shades:
			var c := ink
			c.a = 0.4
			cv.fill_poly(FaceCanvas.spline(pts, 6), c)
			continue
		if k in fills:
			var c := ink
			c.a = 0.45
			cv.fill_poly(pts, c)
		var path := pts if k in fills else FaceCanvas.spline(pts, 8)
		var w := float(st[0]) * 2.5
		cv.ribbon(path, FaceCanvas.taper(path.size(), w * 0.45, w, w * 0.4, 0.5), ink)
	return cv

# --- colours ----------------------------------------------------------------------------

## Every colour a face needs, from the look and the skin. variant "void" is a Shadow form's
## eyes: black irises that reflect nothing, black brows.
static func palette(look: Dictionary, skin: Color, variant := "") -> Dictionary:
	var pal := {
		"skin": skin,
		"sclera": look.get("sclera", Color(0.93, 0.91, 0.9)),
		"shadow": look.get("shadow", Color(0.71, 0.67, 0.72)),
		"iris": look.get("iris", Color(0.12, 0.08, 0.06)),
		"iris_lo": look.get("iris_lo", Color(0.3, 0.2, 0.14)),
		"pupil": Color(0.01, 0.0, 0.02),
		"glint": look.get("glint", Color(0.92, 0.92, 0.95)),
		"ink": look.get("ink", Color(0.04, 0.03, 0.05)),
		"brow": look.get("brow", Color(0.1, 0.07, 0.06)),
		"mouth_in": Color(0.13, 0.03, 0.05),
		"tooth": Color(0.93, 0.9, 0.86),
		"tongue": Color(0.62, 0.22, 0.3),
		"no_glint": false,
	}
	var lip: Color = look.get("lip", skin.lerp(Color(0.44, 0.2, 0.31), 0.58))
	pal["lip"] = lip
	pal["mouth_ink"] = look.get("mouth_ink", Color(0.12, 0.05, 0.07).lerp(skin, 0.12))
	pal["crease"] = skin.lerp(Color(0.02, 0.01, 0.02), 0.5)
	pal["lower"] = (pal["ink"] as Color).lerp(skin, 0.5)
	if variant == "void":
		for k: String in ["iris", "iris_lo", "pupil"]:
			pal[k] = Color(0, 0, 0)
		pal["brow"] = Color(0.02, 0.02, 0.03)
		pal["no_glint"] = true
		pal["sclera"] = (pal["sclera"] as Color).darkened(0.12)
	return pal

# --- eyes -------------------------------------------------------------------------------

## The character's LEFT eye (the +X one); the right eye is this mirrored.
static func eye(style: Dictionary, st: Dictionary, pal: Dictionary) -> FaceCanvas:
	var skin: Color = pal["skin"]
	var cv := FaceCanvas.new(Rect2(6, -52, 114, 122), Color(skin.r, skin.g, skin.b, 0.0))
	var ink: Color = pal["ink"]
	if style.get("dot", false):
		var iris: Array = style["iris"]
		var look: float = st.get("look", 0.0)
		var c := Vector2(float(style["x"]) + look, 0.0)
		if st.get("closed", "") != "" or float(st.get("o", 1.0)) < 0.14:
			cv.line(PackedVector2Array([c + Vector2(-5, 0), c, c + Vector2(5, 0)]), 2.2, ink)
		else:
			cv.fill_poly(FaceCanvas.ellipse(c, float(iris[0]), float(iris[1])), ink)
		return cv
	var w: float = style["w"]
	var inner := Vector2(float(style.get("x", 26.0)), 0.0)
	var tilt: float = float(style.get("tilt", 0.1)) + float(st.get("tilt", 0.0))
	var a := Vector2(cos(tilt), sin(tilt))
	var n := Vector2(-a.y, a.x)
	var o: float = st.get("o", 1.0)
	var closed: String = st.get("closed", "")
	if closed == "" and o < 0.14:
		closed = "down"
	if closed != "":
		_closed_eye(cv, style, inner, a, n, w, pal, closed)
		return cv
	var lid: float = float(style["lid_h"]) * o
	var low: float = float(style["low_h"]) * lerpf(0.72, 1.0, clampf(o, 0.0, 1.0)) * (1.0 + maxf(o - 1.0, 0.0) * 0.8) * (1.0 - 0.5 * float(st.get("squint", 0.0)))
	var angular: bool = style.get("angular", false)
	var upper := _curve(style["up"], inner, a, n, w, lid, angular)
	var lower := _curve(style["low"], inner, a, n, w, -low, angular)
	var shape := PackedVector2Array(upper)
	for i in range(lower.size() - 2, 0, -1):
		shape.append(lower[i])
	cv.fill_poly(shape, pal["sclera"])
	# the upper lid's shadow on the eye
	var drop := 2.4 + 2.0 * clampf(o, 0.0, 1.0)
	for band: PackedVector2Array in Geometry2D.clip_polygons(shape, FaceCanvas.shifted(shape, Vector2(0, -drop))):
		cv.fill_poly(band, pal["shadow"])
	# iris, its lighter lower ring, the pupil and the catch-lights, all cut by the lids
	var k: float = st.get("iris_k", 1.0)
	var irx: float = float(style["iris"][0]) * k
	var iry: float = float(style["iris"][1]) * k
	var gaze: float = float(st.get("look", 0.0)) + float(style.get("iris_dx", 0.0))
	var ic := inner + a * (w * 0.5 + gaze) + n * ((lid - low) * 0.5)
	_clipped(cv, FaceCanvas.ellipse(ic, irx, iry, tilt * 0.5), shape, pal["iris"])
	_clipped(cv, FaceCanvas.ellipse(ic - n * (iry * 0.16), irx * 0.8, iry * 0.7, tilt * 0.5), shape, pal["iris_lo"])
	_clipped(cv, FaceCanvas.ellipse(ic + n * (iry * 0.04), irx * 0.45, iry * 0.36, tilt * 0.5), shape, pal["pupil"])
	var glint: float = float(st.get("glint", 1.0)) * float(style.get("glint", 1.0))
	if glint > 0.0 and not pal["no_glint"]:
		_clipped(cv, FaceCanvas.ellipse(ic + a * (irx * 0.38) + n * (iry * 0.4), irx * 0.22 * glint, iry * 0.18 * glint), shape, pal["glint"])
		_clipped(cv, FaceCanvas.ellipse(ic - a * (irx * 0.34) - n * (iry * 0.4), irx * 0.09 * glint, iry * 0.08 * glint), shape, pal["glint"])
	# the upper lid line: thick, heavier toward the outer corner, ending in a wing
	var m := upper.size()
	var ink_in: float = style["ink"][0]
	var ink_out: float = style["ink"][1]
	var path := PackedVector2Array(upper)
	var wing: float = style.get("wing", 0.0)
	if wing > 0.0:
		var wdir := (upper[m - 1] - upper[m - 3]).normalized().rotated(0.3)
		for j in range(1, 5):
			var t := float(j) / 4.0
			path.append(upper[m - 1] + wdir * (wing * t) + n * (wing * 0.14 * t * t))
	var widths := PackedFloat32Array()
	for i in path.size():
		if i < m:
			widths.append(lerpf(ink_in, ink_out, smoothstep(0.0, 0.7, float(i) / float(m - 1))))
		else:
			widths.append(lerpf(ink_out, 0.5, float(i - m + 1) / 4.0))
	var lifted := PackedVector2Array()
	for i in path.size():
		var tg := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		lifted.append(path[i] + Vector2(-tg.y, tg.x) * widths[i] * 0.45)
	cv.ribbon(lifted, widths, ink)
	_lashes(cv, style, upper, n, ink, 1.0)
	if style.get("crease", false) and o > 0.6:
		var from := int(m * 0.28)
		var fold := PackedVector2Array()
		for i in range(from, int(m * 0.94)):
			fold.append(upper[i] + n * (6.0 + 3.0 * float(i) / m))
		cv.ribbon(fold, FaceCanvas.taper(fold.size(), 0.4, 1.5, 0.4), pal["crease"])
	var under := PackedVector2Array()
	for i in range(int(lower.size() * 0.1), int(lower.size() * 0.94)):
		under.append(lower[i] - n * 0.8)
	cv.ribbon(under, FaceCanvas.taper(under.size(), 0.6, 1.3, 0.6), pal["lower"])
	return cv

static func _closed_eye(cv: FaceCanvas, style: Dictionary, inner: Vector2, a: Vector2, n: Vector2, w: float, pal: Dictionary, kind: String) -> void:
	var up := kind == "up"
	var depth: float = 11.0 if up else 9.0
	var pts := PackedVector2Array()
	for i in 11:
		var s := float(i) / 10.0
		pts.append(inner + a * (w * s) + n * (sin(PI * s) * depth * (1.0 if up else -1.0)))
	var sp := FaceCanvas.spline(pts, 5)
	var ink_out: float = style["ink"][1] if style.has("ink") else 4.0
	cv.ribbon(sp, FaceCanvas.taper(sp.size(), 2.8, maxf(ink_out, 4.0), 1.6, 0.55), pal["ink"])
	var m := sp.size()
	for j in 3:
		var u := float(j) / 2.0
		var idx := int(lerpf(0.94, 0.7, u) * (m - 1))
		var tg := (sp[mini(idx + 1, m - 1)] - sp[maxi(idx - 1, 0)]).normalized()
		var dir := tg.rotated((0.55 + 0.35 * u) * (1.0 if up else -1.0))
		var len := 6.5 * lerpf(1.0, 0.75, u)
		cv.ribbon(PackedVector2Array([sp[idx], sp[idx] + dir * len * 0.55 + n * (0.8 if up else -0.8), sp[idx] + dir * len]), PackedFloat32Array([2.0, 1.4, 0.4]), pal["ink"])

static func _lashes(cv: FaceCanvas, style: Dictionary, upper: PackedVector2Array, n: Vector2, ink: Color, scale: float) -> void:
	var count: int = style.get("lashes", 0)
	var m := upper.size()
	for k in count:
		var u := float(k) / maxf(count - 1, 1)
		var idx := int(lerpf(0.96, 0.68, u) * (m - 1))
		var base := upper[idx]
		var tg := (upper[mini(idx + 1, m - 1)] - upper[maxi(idx - 1, 0)]).normalized()
		var dir := tg.rotated(lerpf(0.35, 1.0, u))
		var len: float = float(style.get("lash_len", 6.0)) * lerpf(1.0, 0.75, u) * scale
		cv.ribbon(PackedVector2Array([base - tg * 0.5, base + dir * len * 0.5 + n * (len * 0.08), base + dir * len]), PackedFloat32Array([2.2, 1.5, 0.4]), ink)

## A lid profile [[s, h], ...] as points on the face: s along the eye, h up from the corner line.
static func _curve(prof: Array, inner: Vector2, a: Vector2, n: Vector2, w: float, hs: float, angular: bool) -> PackedVector2Array:
	var ctrl := PackedVector2Array()
	for e: Array in prof:
		ctrl.append(inner + a * (float(e[0]) * w) + n * (float(e[1]) * hs))
	return ctrl if angular else FaceCanvas.spline(ctrl, 8)

static func _clipped(cv: FaceCanvas, poly: PackedVector2Array, mask: PackedVector2Array, color: Color) -> void:
	for p: PackedVector2Array in Geometry2D.intersect_polygons(poly, mask):
		cv.fill_poly(p, color)

# --- brows ------------------------------------------------------------------------------

## The character's LEFT brow (+X); the right is its mirror.
static func brow(style: Dictionary, mood: Dictionary, pal: Dictionary) -> FaceCanvas:
	var skin: Color = pal["skin"]
	var cv := FaceCanvas.new(Rect2(6, 6, 118, 96), Color(skin.r, skin.g, skin.b, 0.0))
	var raw: Array = style["pts"]
	var n := raw.size()
	var first := Vector2(float(raw[0][0]), float(raw[0][1]))
	var last := Vector2(float(raw[n - 1][0]), float(raw[n - 1][1]))
	var arch: float = mood.get("arch", 1.0)
	var lift: float = mood.get("lift", 0.0)
	var tilt: float = mood.get("tilt", 0.0)
	var ctrl := PackedVector2Array()
	for i in n:
		var p := Vector2(float(raw[i][0]), float(raw[i][1]))
		var t := float(i) / float(n - 1)
		var base_y := lerpf(first.y, last.y, (p.x - first.x) / (last.x - first.x))
		p.y = base_y + (p.y - base_y) * arch + lift + tilt * (1.0 - t) - tilt * 0.35 * t
		ctrl.append(p)
	var pts := FaceCanvas.spline(ctrl, 10)
	var wk: float = mood.get("w", 1.0)
	var w: Array = style["w"]
	cv.ribbon(pts, FaceCanvas.taper(pts.size(), float(w[0]) * wk, float(w[1]) * wk, float(w[2]) * wk, 0.5), pal["brow"])
	return cv

# --- mouths -----------------------------------------------------------------------------

static func mouth(style: Dictionary, shape: String, pal: Dictionary) -> FaceCanvas:
	var skin: Color = pal["skin"]
	var cv := FaceCanvas.new(Rect2(-52, -116, 104, 66), Color(skin.r, skin.g, skin.b, 0.0))
	var w: float = style["w"]
	var y0: float = style["y"]
	var ink_w: float = style["ink"]
	var ink: Color = pal["mouth_ink"]
	var lip_c: Color = pal["lip"]
	match shape:
		"closed", "smile", "frown":
			var curve: float = style.get("curve", 0.0)
			if shape == "smile":
				curve = maxf(curve, 0.0) + 4.5
			elif shape == "frown":
				curve = -4.0
			var lip: float = style.get("lip", 0.0)
			if shape == "frown":
				lip = minf(lip, 3.0)
			var line := PackedVector2Array()
			for i in 9:
				var x := -w * 0.5 + w * float(i) / 8.0
				var t := x / (w * 0.5)
				line.append(Vector2(x, y0 + curve * t * t))
			if style.get("cat", false):
				cv.line(FaceCanvas.spline(PackedVector2Array([Vector2(0, y0 + 1.5), Vector2(-w * 0.2, y0 - 3.0), Vector2(-w * 0.5, y0 + 2.2)]), 8), ink_w, ink)
				cv.line(FaceCanvas.spline(PackedVector2Array([Vector2(0, y0 + 1.5), Vector2(w * 0.2, y0 - 3.0), Vector2(w * 0.5, y0 + 2.2)]), 8), ink_w, ink)
			else:
				if lip > 0.5:
					var bottom := FaceCanvas.spline(PackedVector2Array([
						Vector2(-w * 0.3, y0 + curve * 0.36 - ink_w * 0.3), Vector2(-w * 0.15, y0 - lip * 0.8),
						Vector2(0, y0 - lip), Vector2(w * 0.15, y0 - lip * 0.8), Vector2(w * 0.3, y0 + curve * 0.36 - ink_w * 0.3)]), 6)
					var fill := PackedVector2Array(bottom)
					for i in range(6, 1, -1):
						var x := -w * 0.3 + w * 0.6 * float(i - 2) / 4.0
						fill.append(Vector2(x, y0 + curve * pow(x / (w * 0.5), 2.0)))
					cv.fill_poly(fill, lip_c)
					cv.fill_poly(FaceCanvas.ellipse(Vector2(0, y0 - lip * 0.5), w * 0.07, 0.9), lip_c.lightened(0.28))
				cv.ribbon(line, FaceCanvas.taper(line.size(), ink_w * 0.55, ink_w, ink_w * 0.55, 0.5), ink)
		_:
			var dims := {"ah": [0.52, 9.5, 0.0, false, true], "oh": [0.26, 10.0, 0.0, false, true],
				"ee": [0.88, 5.0, 0.0, true, false], "wide": [0.8, 17.0, 0.0, true, true], "grin": [1.0, 10.0, 3.0, true, true]}
			var d: Array = dims.get(shape, dims["ah"])
			var ww: float = w * float(d[0])
			var hh: float = float(d[1])
			var top_curve: float = d[2]
			var edge := PackedVector2Array()
			for i in 13:
				var x := -ww * 0.5 + ww * float(i) / 12.0
				edge.append(Vector2(x, y0 + top_curve * pow(x / (ww * 0.5), 2.0)))
			var hole := PackedVector2Array(edge)
			for i in range(11, 0, -1):
				var x := -ww * 0.5 + ww * float(i) / 12.0
				var t := x / (ww * 0.5)
				hole.append(Vector2(x, y0 - hh * pow(maxf(1.0 - t * t, 0.0), 0.62)))
			cv.fill_poly(FaceCanvas.ellipse(Vector2(0, y0 - hh * 0.35), ww * 0.5 + 2.6, hh * 0.5 + 2.4), lip_c)  # the lips round the opening
			cv.fill_poly(hole, pal["mouth_in"])
			if d[4]:
				_clipped(cv, FaceCanvas.ellipse(Vector2(0, y0 - hh * 0.8), ww * 0.32, hh * 0.3), hole, pal["tongue"])
			if d[3]:
				var teeth := PackedVector2Array(edge)
				var low := FaceCanvas.shifted(edge, Vector2(0, -hh * 0.34))
				for i in range(low.size() - 1, -1, -1):
					teeth.append(low[i])
				_clipped(cv, teeth, hole, pal["tooth"])
			var rim := PackedVector2Array(hole)
			rim.append(hole[0])
			cv.line(rim, ink_w * 0.8, ink)
	return cv

# --- nose marks (2D) ----------------------------------------------------------------------

## The nose's ink (NoseInks), translucent so that it works on any skin; null for none. `ink`
## replaces the nose's own mark.
static func nose_marks(nose: Dictionary, pal: Dictionary, ink := "") -> FaceCanvas:
	var kind: String = ink if ink != "" else nose.get("ink", "")
	if kind == "" or not NoseInks.DB.has(kind):
		return null
	var skin: Color = pal["skin"]
	var cv := FaceCanvas.new(Rect2(-44, -80, 88, 90), Color(skin.r, skin.g, skin.b, 0.0))
	var shade := skin.lerp(Color(0.02, 0.01, 0.02), 0.62)
	shade.a = 0.9
	NoseInks.draw(cv, kind, Vector2(0, float(nose.get("y", -44.0))), float(nose.get("size", 26.0)), shade)
	return cv
