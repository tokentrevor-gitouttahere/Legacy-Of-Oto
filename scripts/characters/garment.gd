class_name Garment
extends RefCounted
## Clothing cast onto the real body mesh, so the body never shows through and the cloth sits
## the way fabric does: it bridges hollows (between the breasts, the small of the back), hangs
## straight down from the widest point above instead of hugging the body, gathers where a sash
## or a wrap binds it, and folds where it has slack. Used by OutfitBuilder for Oto's bodice and
## trousers; any piece that is a tube round the body or a limb can use it.
##
## A garment is a grid round a vertical axis: columns are angles (0 = the character's front,
## +PI/2 her left), rows run from the hem up to the top edge, which can follow a neckline.

## The body mesh of a ModelLoader wrapper (its first part) as {"tm", "xf"} for Face.cast.
static func body_frame(visual: Node3D) -> Dictionary:
	var rig := visual.get_child(0) as Node3D
	var body := rig.get_child(0) as MeshInstance3D
	return {"tm": Face._tri_mesh(body.mesh), "xf": rig.transform * body.transform}

## The body's front-to-back middle at height y (metres), on the plane x = `x`.
static func centre_z(frame: Dictionary, x: float, y: float) -> float:
	var front := Face.cast(frame["tm"], frame["xf"], Vector3(x, y, 3), Vector3(0, 0, -1))
	var back := Face.cast(frame["tm"], frame["xf"], Vector3(x, y, -3), Vector3(0, 0, 1))
	if front.is_empty() or back.is_empty():
		return 0.0
	return ((front["position"] as Vector3).z + (back["position"] as Vector3).z) * 0.5

## Build a garment. spec (metres unless noted):
##   axis: Callable(y) -> Vector3, the centre the rays start from at each height
##   bottom, top: Callable(theta) -> y, the hem and the top edge (top may follow a neckline)
##   ease (mm): the gap between skin and cloth, or ease_at: Callable(y) -> mm; max_r: rays longer than this (an arm) are cut
##   bridge: how many columns either side a hollow is bridged over
##   hang: how fast the cloth may come back in below a wide point (metres in per metre down;
##     0 hangs straight, large hugs the body)
##   cinch: Callable(y) -> 0..1, where something binds the cloth back to the skin
##   folds: folds round the garment; fold_k: fold depth per metre of slack; fold_min, fold_max (mm)
##   flare (mm): extra width at the hem, growing from `flare_from` (y) down, or along the whole
##     garment's lower part without it; cols, rows
## Returns {"mesh": ArrayMesh, "point": Callable(theta, y) -> Vector3 on the cloth}.
static func tube(frame: Dictionary, spec: Dictionary) -> Dictionary:
	var axis: Callable = spec["axis"]
	var bottom: Callable = spec["bottom"]
	var top: Callable = spec["top"]
	var cinch: Callable = spec.get("cinch", func(_y: float) -> float: return 0.0)
	var ease_mm: float = spec.get("ease", 5.0)
	var ease_at: Callable = spec.get("ease_at", func(_y: float) -> float: return ease_mm)
	var max_r: float = spec.get("max_r", 0.3)
	var bridge: int = spec.get("bridge", 3)
	var hang: float = spec.get("hang", 0.3)
	var folds: int = spec.get("folds", 0)
	var fold_k: float = spec.get("fold_k", 0.0)
	var fold_min: float = float(spec.get("fold_min", 0.0)) * 0.001
	var fold_max: float = float(spec.get("fold_max", 8.0)) * 0.001
	var flare: float = float(spec.get("flare", 0.0)) * 0.001
	var flare_from: float = spec.get("flare_from", -INF)
	var cols: int = spec.get("cols", 72) + 1  # the last column repeats the first
	var rows: int = spec.get("rows", 40)
	var ys := PackedFloat32Array()
	ys.resize(rows * cols)
	var skin := PackedFloat32Array()
	skin.resize(rows * cols)
	# from the top down: a ray that misses the body or runs off along an arm (or between the
	# legs) keeps the distance of the row above
	for j in range(rows - 1, -1, -1):
		for i in cols:
			var th := TAU * float(i) / (cols - 1)
			var y := lerpf(float(bottom.call(th)), float(top.call(th)), float(j) / (rows - 1))
			var k := j * cols + i
			ys[k] = y
			var o: Vector3 = axis.call(y)
			var hit := Face.cast(frame["tm"], frame["xf"], o, Vector3(sin(th), 0, cos(th)))
			var r := ((hit["position"] as Vector3) - o).length() if not hit.is_empty() else INF
			if r > max_r:
				r = skin[k + cols] if j < rows - 1 else max_r
			skin[k] = r
	# bridge hollows round each row: the cloth is stretched over the high points either side
	var bridged := PackedFloat32Array(skin)
	for j in rows:
		for i in cols:
			var best := skin[j * cols + i]
			for d in range(1, bridge + 1):
				var a := skin[j * cols + posmod(i - d, cols - 1)]
				var b := skin[j * cols + posmod(i + d, cols - 1)]
				best = maxf(best, (a + b) * 0.5)
			bridged[j * cols + i] = best
	# hang: from the top edge down, the cloth comes in no faster than `hang` allows; where it
	# is bound it is pulled back to the body, and below a binding it hangs on from there
	var r := PackedFloat32Array()
	r.resize(skin.size())
	var bound := PackedFloat32Array()
	bound.resize(skin.size())
	for k in skin.size():
		bound[k] = clampf(float(cinch.call(ys[k])), 0.0, 1.0)
	var ease := PackedFloat32Array()
	ease.resize(skin.size())
	for k in skin.size():
		ease[k] = float(ease_at.call(ys[k])) * 0.001
	for i in cols:
		var k := (rows - 1) * cols + i
		r[k] = bridged[k] + ease[k]
	for j in range(rows - 2, -1, -1):
		for i in cols:
			var k := j * cols + i
			var above := k + cols
			var drop := ys[above] - ys[k]
			var fit := bridged[k] + ease[k]
			r[k] = lerpf(maxf(fit, r[above] - hang * drop), fit, bound[k])
	# folds where the cloth stands off the body, gathered where it is bound
	var pos := PackedVector3Array()
	var outward := PackedVector3Array()
	var uvs := PackedVector2Array()
	for j in rows:
		var t := float(j) / (rows - 1)
		for i in cols:
			var k := j * cols + i
			var th := TAU * float(i) / (cols - 1)
			var fit := bridged[k] + ease[k]
			var c := bound[k]
			var rr := r[k]
			if folds > 0:
				var depth := minf(fold_min + fold_k * (rr - fit) + c * 0.002, fold_max)
				var wave := sin(th * folds + sin(ys[k] * 23.0 + th * 3.0) * 0.9) + 0.35 * sin(th * folds * 2.0 + ys[k] * 41.0)
				rr += depth * wave * 0.5
			if flare_from > -INF:
				rr += flare * pow(clampf((flare_from - ys[k]) / maxf(flare_from - ys[i], 0.001), 0.0, 1.0), 1.6)
			else:
				rr += flare * pow(1.0 - t, 3.0)
			var dir := Vector3(sin(th), 0, cos(th))
			pos.append((axis.call(ys[k]) as Vector3) + dir * maxf(rr, fit))
			outward.append(dir)
			uvs.append(Vector2(float(i) / (cols - 1) * 4.0, ys[k] * 6.0))
	var lifts := PackedFloat32Array()
	lifts.resize(pos.size())
	var mesh := Face.grid_mesh(pos, outward, uvs, lifts, cols, rows, true)
	var point := func(th: float, y: float) -> Vector3:
		var i := clampi(roundi(fposmod(th, TAU) / TAU * (cols - 1)), 0, cols - 1)
		var lo := 0
		for j in rows:
			if ys[j * cols + i] <= y:
				lo = j
		var hi := mini(lo + 1, rows - 1)
		var a := pos[lo * cols + i]
		var b := pos[hi * cols + i]
		var span := ys[hi * cols + i] - ys[lo * cols + i]
		return a.lerp(b, clampf((y - ys[lo * cols + i]) / span, 0.0, 1.0) if span > 0.0 else 0.0)
	return {"mesh": mesh, "point": point}

## A flat-hung panel over the front (facing 1) or back (facing -1) of the figure: x across
## [-w/2, w/2], y from lo to hi (metres). It lies on whatever is under it (`under`: a list of
## {"tm", "xf", "lift" (mm)}, e.g. the body and a garment over it), spans hollows `bridge`
## columns wide, hangs from its highest point no faster than `hang`, is drawn back where
## `cinch` (Callable(y) -> 0..1) binds it, and folds softly where it has slack. spec "top" and
## "bottom" (Callable(x) -> y) shape its edges; "amp" (mm) caps the folds; "ridges" adds strands.
## Returns {"mesh", "left", "right", "top"}: the edge columns and top row, for trims and straps.
static func panel(under: Array, facing: float, w: float, lo: float, hi: float, spec: Dictionary) -> Dictionary:
	var cols: int = spec.get("cols", 25)
	var rows: int = spec.get("rows", 34)
	var bridge: int = spec.get("bridge", 10)
	var hang: float = spec.get("hang", 0.3)
	var cinch: Callable = spec.get("cinch", func(_y: float) -> float: return 0.0)
	var folds: float = spec.get("folds", 3.0)
	var depth := PackedFloat32Array()  # how far out (along facing) the surface under it is
	depth.resize(cols * rows)
	# the top edge may be cut (a neckline): "top": Callable(x) -> y, else straight at `hi`
	var top_at: Callable = spec.get("top", func(_x: float) -> float: return hi)
	var bottom_at: Callable = spec.get("bottom", func(_x: float) -> float: return lo)  # a shaped hem
	var amp_max: float = float(spec.get("amp", 3.0)) * 0.001  # deepest fold or ridge
	var ridges: float = spec.get("ridges", 0.0)  # strand ridges (hair), on top of the folds
	var xs := PackedFloat32Array()
	for i in cols:
		xs.append(lerpf(-w * 0.5, w * 0.5, float(i) / (cols - 1)))
	var ys := PackedFloat32Array()  # per sample: rows run from lo up to the top edge
	ys.resize(cols * rows)
	for j in rows:
		for i in cols:
			ys[j * cols + i] = lerpf(float(bottom_at.call(xs[i])), float(top_at.call(xs[i])), float(j) / (rows - 1))
	for j in rows:
		for i in cols:
			var best := -INF
			for u: Dictionary in under:
				var hit := Face.cast(u["tm"], u["xf"], Vector3(xs[i], ys[j * cols + i], facing * 3.0), Vector3(0, 0, -facing))
				if not hit.is_empty():
					best = maxf(best, (hit["position"] as Vector3).z * facing + float(u.get("lift", 0.0)) * 0.001)
			depth[j * cols + i] = best if best > -INF else 0.0
	# fill misses from the row above
	for j in range(rows - 2, -1, -1):
		for i in cols:
			if depth[j * cols + i] == 0.0:
				depth[j * cols + i] = depth[(j + 1) * cols + i]
	# lie over the small folds of what is underneath: the highest point near each sample
	var span: int = spec.get("span", 2)
	var lifted := PackedFloat32Array(depth)
	for j in rows:
		for i in cols:
			var best := -INF
			for dj in range(-span, span + 1):
				for di in range(-span, span + 1):
					best = maxf(best, depth[clampi(j + dj, 0, rows - 1) * cols + clampi(i + di, 0, cols - 1)])
			lifted[j * cols + i] = best
	var bridged := PackedFloat32Array(lifted)
	for j in rows:
		for i in cols:
			var best := lifted[j * cols + i]
			for d in range(1, bridge + 1):
				var a := lifted[j * cols + clampi(i - d, 0, cols - 1)]
				var b := lifted[j * cols + clampi(i + d, 0, cols - 1)]
				best = maxf(best, (a + b) * 0.5)
			bridged[j * cols + i] = best
	# then smooth it, so the panel is one even surface
	for pass_k in 3:
		var sm := PackedFloat32Array(bridged)
		for j in rows:
			for i in cols:
				var acc := 0.0
				for dj in range(-1, 2):
					for di in range(-1, 2):
						acc += bridged[clampi(j + dj, 0, rows - 1) * cols + clampi(i + di, 0, cols - 1)]
				sm[j * cols + i] = maxf(acc / 9.0, lifted[j * cols + i])
		bridged = sm
	var z := PackedFloat32Array(bridged)
	for j in range(rows - 2, -1, -1):
		for i in cols:
			var k := j * cols + i
			var drop := ys[k + cols] - ys[k]
			var c: float = clampf(float(cinch.call(ys[k])), 0.0, 1.0)
			z[k] = lerpf(maxf(bridged[k], z[k + cols] - hang * drop), depth[k], c)  # bound: down onto what is under it
	var pos := PackedVector3Array()
	var outward := PackedVector3Array()
	var uvs := PackedVector2Array()
	for j in rows:
		for i in cols:
			var k := j * cols + i
			var slack := maxf(z[k] - bridged[k], 0.0)
			var amp := minf(0.0006 + 0.25 * slack, amp_max)
			var u := float(i) / (cols - 1)
			var wave := sin(u * PI * 2.0 * folds + 0.6 + sin(ys[k] * 31.0) * 0.5) * (0.4 + 0.6 * sin(u * PI))
			if ridges > 0.0:
				wave += 0.8 * absf(sin(u * PI * ridges + 0.4 * sin(ys[k] * 17.0)))
			pos.append(Vector3(xs[i], ys[k], (z[k] + amp * maxf(wave, -0.3)) * facing))
			outward.append(Vector3(0, 0, facing))
			uvs.append(Vector2(u, float(j) / (rows - 1) * 2.0))
	var lifts := PackedFloat32Array()
	lifts.resize(pos.size())
	var mesh := Face.grid_mesh(pos, outward, uvs, lifts, cols, rows)
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	var top := PackedVector3Array()
	for j in rows:
		left.append(pos[j * cols])
		right.append(pos[j * cols + cols - 1])
	for i in cols:
		top.append(pos[(rows - 1) * cols + i])
	return {"mesh": mesh, "left": left, "right": right, "top": top}

## A flat strip `w` wide through points `pts`, each lifted along `outs` by `lift` (metres).
static func strip(pts: PackedVector3Array, outs: PackedVector3Array, w: float, lift := 0.0) -> ArrayMesh:
	var n := pts.size()
	var verts := PackedVector3Array()
	var nrm := PackedVector3Array()
	for i in n:
		var tg := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var side := tg.cross(outs[i]).normalized() * w * 0.5
		var base := pts[i] + outs[i] * lift
		verts.append_array([base + side, base - side])
		nrm.append_array([outs[i], outs[i]])
	var idx := PackedInt32Array()
	for i in n - 1:
		var a := i * 2
		if (verts[a + 1] - verts[a]).cross(verts[a + 3] - verts[a]).dot(nrm[a]) > 0.0:
			idx.append_array([a, a + 3, a + 1, a, a + 2, a + 3])
		else:
			idx.append_array([a, a + 1, a + 3, a, a + 3, a + 2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh

## A sleeve round a limb from `a` to `b` (metres, near the limb's middle): rings of rays cast out
## from the limb's real centre line, so it fits the arm or hand it covers. spec:
##   ease (mm) or ease_at: Callable(s) -> mm, s = 0 at `a` to 1 at `b`
##   bump: Callable(s, ang) -> mm added (ridges, rims, a spine); ang 0 = up, PI/2 = front
##   reach: how far out the rays start (metres; default max_r)
##   bridge: columns either side a hollow is spanned (a rigid shell spans more); smooth: passes
##   of smoothing; max_r (metres)
##   cols (round), rows (along)
## Returns {"mesh", "point": Callable(s, ang) -> Vector3, "normal": Callable(s, ang) -> Vector3}.
static func sleeve(frame: Dictionary, a: Vector3, b: Vector3, spec: Dictionary) -> Dictionary:
	var cols: int = spec.get("cols", 40) + 1
	var rows: int = spec.get("rows", 24)
	var bridge: int = spec.get("bridge", 2)
	var max_r: float = spec.get("max_r", 0.08)
	var reach: float = spec.get("reach", max_r)
	var ease_mm: float = spec.get("ease", 2.0)
	var ease_at: Callable = spec.get("ease_at", func(_s: float) -> float: return ease_mm)
	var bump: Callable = spec.get("bump", func(_s: float, _ang: float) -> float: return 0.0)
	var d := (b - a).normalized()
	var ref := Vector3.UP if absf(d.y) < 0.9 else Vector3.BACK  # an upright limb (a shin): ang 0 = front
	var up := (ref - d * d.dot(ref)).normalized()
	var side := d.cross(up)
	var front_sign := 1.0 if side.z >= 0.0 else -1.0  # so that ang PI/2 is the front (+Z) on both arms
	var dir_of := func(ang: float) -> Vector3: return up * cos(ang) + side * sin(ang) * front_sign
	# the limb's real middle at each ring: halfway between its top and bottom, and front and back
	var centres := PackedVector3Array()
	for j in rows:
		var p := a.lerp(b, float(j) / (rows - 1))
		var c := p
		var t := Face.cast(frame["tm"], frame["xf"], p + up * max_r, -up)
		var bo := Face.cast(frame["tm"], frame["xf"], p - up * max_r, up)
		if not t.is_empty() and not bo.is_empty():
			c += up * (((t["position"] as Vector3) - p).dot(up) + ((bo["position"] as Vector3) - p).dot(up)) * 0.5
		var fr := Face.cast(frame["tm"], frame["xf"], p + side * max_r, -side)
		var bk := Face.cast(frame["tm"], frame["xf"], p - side * max_r, side)
		if not fr.is_empty() and not bk.is_empty():
			c += side * (((fr["position"] as Vector3) - p).dot(side) + ((bk["position"] as Vector3) - p).dot(side)) * 0.5
		centres.append(c)
	# smooth the centre line
	for pass_k in 2:
		var sm := PackedVector3Array(centres)
		for j in range(1, rows - 1):
			sm[j] = (centres[j - 1] + centres[j] * 2.0 + centres[j + 1]) * 0.25
		centres = sm
	var r := PackedFloat32Array()
	r.resize(rows * cols)
	for j in rows:
		for i in cols:
			var ang := TAU * float(i) / (cols - 1)
			var dir: Vector3 = dir_of.call(ang)
			# from outside in, starting `reach` out so the whole limb (a hand's edge, a heel) is
			# inside the start; a hit beyond max_r is something else (the other leg), so then
			# from the middle out
			var hit := Face.cast(frame["tm"], frame["xf"], centres[j] + dir * reach, -dir)
			var rr := ((hit["position"] as Vector3) - centres[j]).dot(dir) if not hit.is_empty() else -1.0
			if rr > max_r or rr <= 0.0:
				var out := Face.cast(frame["tm"], frame["xf"], centres[j], dir)
				rr = ((out["position"] as Vector3) - centres[j]).dot(dir) if not out.is_empty() else -1.0
			r[j * cols + i] = rr
	# misses (past the fingertips): the ring before
	for j in rows:
		for i in cols:
			if r[j * cols + i] <= 0.0:
				r[j * cols + i] = r[(j - 1) * cols + i] if j > 0 else 0.02
	var bridged := PackedFloat32Array(r)
	for j in rows:
		for i in cols:
			var best := r[j * cols + i]
			for k in range(1, bridge + 1):
				best = maxf(best, (r[j * cols + posmod(i - k, cols - 1)] + r[j * cols + posmod(i + k, cols - 1)]) * 0.5)
			bridged[j * cols + i] = best
	# smooth: lumps under it (knuckles, the thumb's root) do not show through, and it never
	# goes inside what it covers
	for pass_k in int(spec.get("smooth", 0)):
		var sm := PackedFloat32Array(bridged)
		for j in rows:
			for i in cols:
				var acc := 0.0
				for dj in range(-1, 2):
					for di in range(-1, 2):
						acc += bridged[clampi(j + dj, 0, rows - 1) * cols + posmod(i + di, cols - 1)]
				sm[j * cols + i] = maxf(acc / 9.0, r[j * cols + i])
		bridged = sm
	var pos := PackedVector3Array()
	var outward := PackedVector3Array()
	var uvs := PackedVector2Array()
	for j in rows:
		var s := float(j) / (rows - 1)
		for i in cols:
			var ang := TAU * float(i) / (cols - 1)
			var dir: Vector3 = dir_of.call(ang)
			var rr := bridged[j * cols + i] + (float(ease_at.call(s)) + float(bump.call(s, ang))) * 0.001
			pos.append(centres[j] + dir * rr)
			outward.append(dir)
			uvs.append(Vector2(float(i) / (cols - 1) * 2.0, s))
	var lifts := PackedFloat32Array()
	lifts.resize(pos.size())
	var mesh := Face.grid_mesh(pos, outward, uvs, lifts, cols, rows, true)
	var point := func(s: float, ang: float) -> Vector3:
		var j := clampi(roundi(s * (rows - 1)), 0, rows - 1)
		var i := posmod(roundi(fposmod(ang, TAU) / TAU * (cols - 1)), cols - 1)
		return pos[j * cols + i]
	var normal := func(_s: float, ang: float) -> Vector3: return dir_of.call(ang)
	return {"mesh": mesh, "point": point, "normal": normal, "rows": rows, "cols": cols - 1}

## A patch lying on a sleeve over s0..s1 along and ang0..ang1 round, `lift` metres off it, its
## UVs 0..1 (u round, v along): a curved plate for an engraving or a badge.
static func patch(g: Dictionary, s0: float, s1: float, ang0: float, ang1: float, lift: float) -> ArrayMesh:
	var n := 12
	var pos := PackedVector3Array()
	var outward := PackedVector3Array()
	var uvs := PackedVector2Array()
	var lifts := PackedFloat32Array()
	for j in n:
		var v := float(j) / (n - 1)
		for i in n:
			var u := float(i) / (n - 1)
			var s := lerpf(s0, s1, v)
			var ang := lerpf(ang0, ang1, u)
			pos.append(g["point"].call(s, ang))
			outward.append(g["normal"].call(s, ang))
			uvs.append(Vector2(u, v))
			lifts.append(lift * 1000.0)
	return Face.grid_mesh(pos, outward, uvs, lifts, n, n)

## A cloth material that shows both sides (the inside shows at hems and armholes).
static func two_sided(m: StandardMaterial3D) -> StandardMaterial3D:
	var d := m.duplicate() as StandardMaterial3D
	d.cull_mode = BaseMaterial3D.CULL_DISABLED
	return d

## A band lying on a garment along face-on points (theta, y): trims, lapels, binding. `w` wide
## (metres), `lift` off the cloth.
static func band(point: Callable, path: Array, w: float, lift: float, axis: Callable) -> ArrayMesh:
	var pts := PackedVector3Array()
	for p: Vector2 in path:
		pts.append(point.call(p.x, p.y))
	var verts := PackedVector3Array()
	var nrm := PackedVector3Array()
	var n := pts.size()
	for i in n:
		var c: Vector3 = axis.call(pts[i].y)
		var out := Vector3(pts[i].x - c.x, 0, pts[i].z - c.z).normalized()
		var tg := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var side := tg.cross(out).normalized() * w * 0.5
		var base := pts[i] + out * lift
		verts.append_array([base + side, base - side])
		nrm.append_array([out, out])
	var idx := PackedInt32Array()
	for i in n - 1:
		var a := i * 2
		if (verts[a + 1] - verts[a]).cross(verts[a + 3] - verts[a]).dot(nrm[a]) > 0.0:
			idx.append_array([a, a + 3, a + 1, a, a + 2, a + 3])
		else:
			idx.append_array([a, a + 1, a + 3, a, a + 3, a + 2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh
