class_name FaceCanvas
extends RefCounted
## A small supersampled painter for face art (see face.gd). Flat shapes only, painted over one
## another and downsampled for smooth edges, the way cel art is inked.
##
## Face space is millimetres: +X is the character's left (the viewer's right), +Y is up, the
## origin is on the centre line at the eye line. The whole face texture is TEX_W x TEX_H pixels
## of unwrapped head surface; a canvas covers a region of it and paints at `ss` times the
## resolution. Painting replaces pixels (no blending), so a translucent mark belongs on a
## canvas of its own, which Face blends onto the texture.

const PPMM := 3.0     # texture pixels per millimetre
const TEX_W := 1024   # 341 mm of unwrapped head surface across
const TEX_H := 768    # 256 mm tall
const EYE_ROW := 360  # pixel row of the eye line: 120 mm of forehead above, 136 mm of cheek and chin below
const MAX_CROSSINGS := 16

var ss: int
var rect: Rect2i  # this canvas on the final texture, in texture pixels
var img: Image

## `region` is in face space (millimetres, Y up). `bg` is the colour under the transparent
## pixels: use the skin colour with alpha 0, so that edges blend toward skin and not toward black.
func _init(region: Rect2, bg := Color(0, 0, 0, 0), supersample := 4) -> void:
	ss = supersample
	rect = px_rect(region)
	img = Image.create(rect.size.x * ss, rect.size.y * ss, false, Image.FORMAT_RGBA8)
	img.fill(bg)

## A face-space region (mm) as whole texture pixels.
static func px_rect(region: Rect2) -> Rect2i:
	var x0 := floori(region.position.x * PPMM + TEX_W * 0.5)
	var x1 := ceili(region.end.x * PPMM + TEX_W * 0.5)
	var y0 := floori(EYE_ROW - region.end.y * PPMM)
	var y1 := ceili(EYE_ROW - region.position.y * PPMM)
	return Rect2i(x0, y0, x1 - x0, y1 - y0)

## Face space (mm) -> this canvas's supersampled pixels.
func to_px(p: Vector2) -> Vector2:
	return Vector2((p.x * PPMM + TEX_W * 0.5 - rect.position.x) * ss, (EYE_ROW - p.y * PPMM - rect.position.y) * ss)

## The painted canvas at texture resolution.
func result() -> Image:
	var out := img.duplicate() as Image
	out.resize(rect.size.x, rect.size.y, Image.INTERPOLATE_TRILINEAR)
	return out

# --- painting ---------------------------------------------------------------------

## Fill a polygon (even-odd) with a flat colour.
func fill_poly(pts: PackedVector2Array, color: Color) -> void:
	var n := pts.size()
	if n < 3:
		return
	var p := PackedVector2Array()
	p.resize(n)
	var top := INF
	var bot := -INF
	for i in n:
		var q := to_px(pts[i])
		p[i] = q
		top = minf(top, q.y)
		bot = maxf(bot, q.y)
	var r0 := maxi(ceili(top - 0.5), 0)
	var r1 := mini(ceili(bot - 0.5) - 1, img.get_height() - 1)
	if r1 < r0:
		return
	var rows := r1 - r0 + 1
	var xs := PackedFloat32Array()
	xs.resize(rows * MAX_CROSSINGS)
	var count := PackedInt32Array()
	count.resize(rows)
	for i in n:
		var a := p[i]
		var b := p[(i + 1) % n]
		if a.y == b.y:
			continue
		if a.y > b.y:
			var t := a
			a = b
			b = t
		var slope := (b.x - a.x) / (b.y - a.y)
		var ra := maxi(ceili(a.y - 0.5), r0)
		var rb := mini(ceili(b.y - 0.5) - 1, r1)
		for r in range(ra, rb + 1):
			var k := r - r0
			if count[k] < MAX_CROSSINGS:
				xs[k * MAX_CROSSINGS + count[k]] = a.x + (float(r) + 0.5 - a.y) * slope
				count[k] += 1
	var w := img.get_width()
	for k in rows:
		var c := count[k]
		if c < 2:
			continue
		var row := xs.slice(k * MAX_CROSSINGS, k * MAX_CROSSINGS + c)
		row.sort()
		for j in range(0, c - 1, 2):
			var x0 := maxi(ceili(row[j] - 0.5), 0)
			var x1 := mini(ceili(row[j + 1] - 0.5), w)
			if x1 > x0:
				img.fill_rect(Rect2i(x0, r0 + k, x1 - x0, 1), color)

## A stroke through `pts` whose thickness at each point is `widths` (mm), with round ends.
func ribbon(pts: PackedVector2Array, widths: PackedFloat32Array, color: Color) -> void:
	var n := pts.size()
	if n < 2 or widths.size() != n:
		return
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in n:
		var t := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var nrm := Vector2(-t.y, t.x)
		var hw := widths[i] * 0.5
		left.append(pts[i] + nrm * hw)
		right.append(pts[i] - nrm * hw)
	var poly := PackedVector2Array(left)
	var steps := 6
	var hw_end := widths[n - 1] * 0.5
	var nrm_end := left[n - 1] - pts[n - 1]
	for k in range(1, steps):
		poly.append(pts[n - 1] + nrm_end.rotated(-PI * k / steps))
	for i in range(n - 1, -1, -1):
		poly.append(right[i])
	var nrm_start := right[0] - pts[0]
	for k in range(1, steps):
		poly.append(pts[0] + nrm_start.rotated(-PI * k / steps))
	if hw_end >= 0.0:
		fill_poly(poly, color)

## A stroke of one thickness.
func line(pts: PackedVector2Array, width: float, color: Color) -> void:
	var w := PackedFloat32Array()
	w.resize(pts.size())
	w.fill(width)
	ribbon(pts, w, color)

# --- shapes -----------------------------------------------------------------------

static func ellipse(c: Vector2, rx: float, ry: float, rot := 0.0, n := 48) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return out

## A smooth curve through the control points (Catmull-Rom), `per` samples a segment.
static func spline(ctrl: PackedVector2Array, per := 10) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := ctrl.size()
	if n < 3:
		return ctrl
	for i in n - 1:
		var p0 := ctrl[maxi(i - 1, 0)]
		var p1 := ctrl[i]
		var p2 := ctrl[i + 1]
		var p3 := ctrl[mini(i + 2, n - 1)]
		for k in per:
			var t := float(k) / per
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(ctrl[n - 1])
	return out

static func shifted(pts: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + d)
	return out

## Thickness along a stroke of `n` points: `a` at the start, `b` at the end, `mid` between,
## reached at `peak` (0..1 along the stroke).
static func taper(n: int, a: float, mid: float, b: float, peak := 0.5) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in n:
		var t := float(i) / maxf(n - 1, 1)
		out.append(lerpf(a, mid, smoothstep(0.0, peak, t)) if t < peak else lerpf(mid, b, smoothstep(peak, 1.0, t)))
	return out
