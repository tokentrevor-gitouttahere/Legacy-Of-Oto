class_name Face
extends RefCounted
## Faces: character looks built from the FaceParts kit, their textures, and the plates that
## wrap them onto a head. FaceRig (face_rig.gd) is the live face on a character; this file is
## the data and the builders it uses. Design and how to make a new face: docs/OTO_FACE.md.
##
## A face is four transparent LAYERS (eyes, brows, mouth, nose marks), each a thin plate
## ray-cast onto the real head mesh and textured from FaceParts canvases, so blinking or a
## mouth change swaps one small texture. The nose and chin are small 3D shapes in the head's
## own skin material, so skin tint and Shadow forms follow them.

## Character recipes. eyes/brows/mouth/nose/chin name FaceParts styles; "tune" overrides the
## eye style's numbers; "pal" overrides palette colours; "blink" is the range between blinks (s).
const LOOKS := {
	"oto": {
		# nose: the owner wants it longer and wider, after sheet nose #28 in profile and #33 head
		# on; sizes A-D are on --gallery nosesizes, waiting for their pick ("nose_tune" sets it)
		"eyes": "almond", "tune": {"iris_dx": 1.0, "w": 62.0, "lid_h": 22.0},
		# very dark violet eyes with a dim catch-light; pale lilac-grey brows that read on dark skin
		"pal": {"iris": Color(0.07, 0.05, 0.1), "iris_lo": Color(0.11, 0.07, 0.15), "glint": Color(0.52, 0.52, 0.64),
			"brow": Color(0.6, 0.58, 0.64)},
		"brows": "calm", "mouth": "still", "nose": "long", "chin": "soft",
		"nose_tune": {"len": 60.0, "w": 26.0, "out": 22.0, "size": 52.8},  # size C, the owner's pick
		# her head mesh has ears: the DBZ ear lines are inked on them, seen from the side
		"ears": "dbz",
		"blink": [5.5, 9.0],
	},
}

## Named combinations of part states.
const EXPRESSIONS := {
	"neutral": {"eyes": "open", "brows": "calm", "mouth": "closed"},
	"cold": {"eyes": "narrow", "brows": "cold", "mouth": "closed"},
	"smile": {"eyes": "open", "brows": "raised", "mouth": "smile"},
	"surprise": {"eyes": "wide", "brows": "raised", "mouth": "oh"},
	"sad": {"eyes": "half", "brows": "sad", "mouth": "frown"},
	"eat": {"eyes": "happy", "brows": "calm", "mouth": "ah"},
	"sleep": {"eyes": "closed", "brows": "flat", "mouth": "closed"},
}

## Layer regions in face space (mm, Rect2 x, y, w, h with y the bottom edge). They cover the
## left-side canvases FaceParts draws and their mirrors.
const REGIONS := {
	"eyes": Rect2(-120, -52, 240, 122),
	"brows": Rect2(-124, 6, 248, 96),
	"mouth": Rect2(-52, -116, 104, 66),
	"nose": Rect2(-44, -84, 88, 106),
}

## Ears are not on the face texture: each has a plate projected onto the ear from the side it
## faces, with art in ear space (mm across the ear, +X toward the back of the head, +Y up,
## the origin at the ear's middle). EAR_REGION is the art's canvas; HEADS gives each mesh's
## ear: its middle (degrees round from the front, mm from the eye line), the way it faces
## (degrees) and its size (mm).
const EAR_REGION := Rect2(-36, -52, 72, 104)
## How far each plate stands off the skin (mm): apart, so overlapping plates do not fight.
const LIFT := {"eyes": 1.2, "brows": 1.6, "mouth": 1.2, "nose": 1.6}

## Where each base mesh's eye line is (metres above the feet, before preset scaling).
const HEADS := {"oto": {"eye_y": 1.498,
	# measured on the mesh: the ear stands out 95-123 degrees round, 50 mm below to 36 above the eye line
	"ear": {"deg": 110.0, "y": -7.0, "faces": 112.0, "w": 46.0, "h": 82.0}}}

const R_REF := 140.0  # mm of unwrapped surface per radian round the head axis
const GRID_MM := 4.0  # plate grid spacing

static var _tex := {}
static var _tri := {}

static var _defined := {}

static func look(id: String) -> Dictionary:
	return _defined.get(id, LOOKS.get(id, {}))

## Add a look at run time (the gallery's nose trials); its textures cache under `id`.
static func define_look(id: String, lk: Dictionary) -> void:
	_defined[id] = lk

## The eye style with the look's tuning applied.
static func eye_style(lk: Dictionary) -> Dictionary:
	var st: Dictionary = (FaceParts.EYES[lk.get("eyes", "almond")] as Dictionary).duplicate()
	st.merge(lk.get("tune", {}), true)
	return st

# --- textures ---------------------------------------------------------------------------

## The texture for one layer in one state, cached. Null when the layer has nothing to show.
static func texture(look_id: String, slot: String, st: String, variant: String, skin: Color) -> ImageTexture:
	var key := "%s|%s|%s|%s|%s" % [look_id, slot, st, variant, skin.to_html()]
	if _tex.has(key):
		return _tex[key]
	var img := layer_image(look(look_id), slot, st, variant, skin)
	var tex: ImageTexture = null
	if img:
		img.generate_mipmaps()
		tex = ImageTexture.create_from_image(img)
	_tex[key] = tex
	return tex

static func layer_image(lk: Dictionary, slot: String, st: String, variant: String, skin: Color) -> Image:
	var pal := FaceParts.palette(lk.get("pal", {}), skin, variant)
	var lr := FaceCanvas.px_rect(REGIONS[slot] if REGIONS.has(slot) else EAR_REGION)
	var img := Image.create(lr.size.x, lr.size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(skin.r, skin.g, skin.b, 0.0))
	match slot:
		"eyes":
			var style := eye_style(lk)
			var es: Dictionary = FaceParts.EYE_STATES.get(st, {})
			var left := FaceParts.eye(style, es, pal)
			_blend(img, lr, left, false)
			var gaze: float = es.get("look", 0.0)
			if gaze != 0.0:
				var es_r := es.duplicate()
				es_r["look"] = -gaze
				_blend(img, lr, FaceParts.eye(style, es_r, pal), true)
			else:
				_blend(img, lr, left, true)
		"brows":
			var cv := FaceParts.brow(FaceParts.BROWS[lk.get("brows", "calm")], FaceParts.BROW_STATES.get(st, {}), pal)
			_blend(img, lr, cv, false)
			_blend(img, lr, cv, true)
		"mouth":
			_blend(img, lr, FaceParts.mouth(FaceParts.MOUTHS[lk.get("mouth", "still")], st, pal), false)
		"nose":
			var nose: Dictionary = (FaceParts.NOSES[lk.get("nose", "none")] as Dictionary).duplicate()
			nose.merge(lk.get("nose_tune", {}), true)
			var cv := FaceParts.nose_marks(nose, pal, lk.get("nose_ink", ""))
			if cv == null:
				return null
			_blend(img, lr, cv, false)
		"ears":
			var cv := FaceParts.ear(FaceParts.EARS.get(lk.get("ears", "none"), {}), lk.get("ear_size", Vector2(46, 82)), pal)
			if cv == null:
				return null
			return cv.result()
	return img

## Paint a canvas onto a layer image, or its mirror across the centre line.
static func _blend(dst: Image, lr: Rect2i, cv: FaceCanvas, mirror: bool) -> void:
	var src := cv.result()
	var x := cv.rect.position.x
	if mirror:
		src.flip_x()
		x = FaceCanvas.TEX_W - (cv.rect.position.x + cv.rect.size.x)
	dst.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i(x, cv.rect.position.y) - lr.position)

## A whole flat face on skin, `crop` (mm) of it: the parts sheet and portraits. `states` maps
## slot -> state (missing slots are neutral).
static func card(lk: Dictionary, states: Dictionary, variant: String, skin: Color, crop := Rect2(-124, -120, 248, 222)) -> Image:
	var cr := FaceCanvas.px_rect(crop)
	var img := Image.create(cr.size.x, cr.size.y, false, Image.FORMAT_RGBA8)
	img.fill(skin)
	for slot: String in ["eyes", "brows", "mouth", "nose"]:
		var st: String = states.get(slot, EXPRESSIONS["neutral"].get(slot, ""))
		var layer := layer_image(lk, slot, st, variant, skin)
		if layer:
			img.blend_rect(layer, Rect2i(Vector2i.ZERO, layer.get_size()), FaceCanvas.px_rect(REGIONS[slot]).position - cr.position)
	return img

# --- the head ---------------------------------------------------------------------------

## The head mesh of a ModelLoader wrapper: the part named "head", else the first part.
static func head_part(visual: Node3D) -> MeshInstance3D:
	var rig := visual.get_child(0)
	var h := rig.get_node_or_null("head")
	return (h if h else rig.get_child(0)) as MeshInstance3D

static func _tri_mesh(mesh: Mesh) -> TriangleMesh:
	var id := mesh.get_rid().get_id()
	if not _tri.has(id):
		_tri[id] = mesh.generate_triangle_mesh()
	return _tri[id]

## A ray against the head in wrapper space: {"position", "normal"} or empty. The normal faces
## along the ray (outward, for the rays cast from inside the head).
static func cast(tm: TriangleMesh, xf: Transform3D, from: Vector3, dir: Vector3) -> Dictionary:
	var inv := xf.affine_inverse()
	var hit: Dictionary = tm.intersect_ray(inv * from, (inv.basis * dir).normalized())
	if hit.is_empty():
		return {}
	var n := (xf.basis * (hit["normal"] as Vector3)).normalized()
	return {"position": xf * (hit["position"] as Vector3), "normal": n if n.dot(dir) >= 0.0 else -n}

## Everything a plate needs to know about one head, in wrapper space.
static func head_frame(visual: Node3D) -> Dictionary:
	var head := head_part(visual)
	var xf: Transform3D = (visual.get_child(0) as Node3D).transform * head.transform
	var tm := _tri_mesh(head.mesh)
	var key: String = visual.get_meta("model_key", "oto")
	var eye_y: float = HEADS.get(key, {}).get("eye_y", float(visual.get_meta("height", 1.7)) * 0.881)
	var front := cast(tm, xf, Vector3(0, eye_y, 3), Vector3(0, 0, -1))
	var back := cast(tm, xf, Vector3(0, eye_y, -3), Vector3(0, 0, 1))
	var z := 0.0
	if not front.is_empty() and not back.is_empty():
		z = ((front["position"] as Vector3).z + (back["position"] as Vector3).z) * 0.5
	return {"tm": tm, "xf": xf, "eye_y": eye_y, "axis": Vector3(0, eye_y, z), "head": head}

## Where a face-space point (mm) lands on the head: {"position", "normal"} in wrapper space.
static func surface(frame: Dictionary, x_mm: float, y_mm: float) -> Dictionary:
	var th := x_mm / R_REF
	var axis: Vector3 = frame["axis"]
	var from := Vector3(axis.x, float(frame["eye_y"]) + y_mm * 0.001, axis.z)
	var dir := Vector3(sin(th), 0, cos(th))
	var hit := cast(frame["tm"], frame["xf"], from, dir)
	if hit.is_empty():
		return {"position": from + dir * R_REF * 0.001, "normal": dir}
	return hit

## A plate wrapped on the head over `region`, standing `lift_mm` off it, its UVs matching the
## region's texture pixels.
static func plate(frame: Dictionary, region: Rect2, lift_mm: float) -> ArrayMesh:
	var pr := FaceCanvas.px_rect(region)
	var cols := maxi(ceili(pr.size.x / FaceCanvas.PPMM / GRID_MM), 2) + 1
	var rows := maxi(ceili(pr.size.y / FaceCanvas.PPMM / GRID_MM), 2) + 1
	var pos := PackedVector3Array()
	var uvs := PackedVector2Array()
	var radial := PackedVector3Array()
	for j in rows:
		var v := float(j) / (rows - 1)
		var y_mm := (FaceCanvas.EYE_ROW - (pr.position.y + v * pr.size.y)) / FaceCanvas.PPMM
		for i in cols:
			var u := float(i) / (cols - 1)
			var x_mm := (pr.position.x + u * pr.size.x - FaceCanvas.TEX_W * 0.5) / FaceCanvas.PPMM
			var hit := surface(frame, x_mm, y_mm)
			pos.append(hit["position"])
			radial.append(Vector3(sin(x_mm / R_REF), 0, cos(x_mm / R_REF)))
			uvs.append(Vector2(u, v))
	var lifts := PackedFloat32Array()
	lifts.resize(pos.size())
	lifts.fill(lift_mm)
	return grid_mesh(pos, radial, uvs, lifts, cols, rows)

## A mesh over a grid of surface points (row-major, `cols` across), each pushed `lifts` mm out
## along its normal. `outward` only decides which way the normals face.
## `wrap`: the grid goes all the way round (its last column repeats its first), so the normals
## at that seam use the neighbours on both sides and the shading has no line.
static func grid_mesh(pos: PackedVector3Array, outward: PackedVector3Array, uvs: PackedVector2Array, lifts: PackedFloat32Array, cols: int, rows: int, wrap := false) -> ArrayMesh:
	var nrm := PackedVector3Array()
	nrm.resize(pos.size())
	var verts := PackedVector3Array()
	verts.resize(pos.size())
	for j in rows:
		for i in cols:
			var k := j * cols + i
			var dx := pos[j * cols + mini(i + 1, cols - 1)] - pos[j * cols + maxi(i - 1, 0)]
			if wrap and (i == 0 or i == cols - 1):
				dx = pos[j * cols + 1] - pos[j * cols + cols - 2]
			var dy := pos[maxi(j - 1, 0) * cols + i] - pos[mini(j + 1, rows - 1) * cols + i]
			var n := dy.cross(dx).normalized()
			if n == Vector3.ZERO:
				n = outward[k]
			if n.dot(outward[k]) < 0.0:
				n = -n
			nrm[k] = n
			verts[k] = pos[k] + n * lifts[k] * 0.001
	var idx := PackedInt32Array()
	for j in rows - 1:
		for i in cols - 1:
			var tl := j * cols + i
			var tr := tl + 1
			var bl := tl + cols
			var br := bl + 1
			# Godot's front faces wind clockwise seen from outside: (b - a) x (c - a) points in
			if (verts[tr] - verts[tl]).cross(verts[br] - verts[tl]).dot(nrm[tl] + nrm[br]) > 0.0:
				idx.append_array([tl, br, tr, tl, bl, br])
			else:
				idx.append_array([tl, tr, br, tl, br, bl])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh

# --- hair that fits the head ----------------------------------------------------------------

## A hair shell cast onto the real head: from a fringe line in front (scalloped strands, mm
## above the eye line) over the crown and down to the nape, `thick` mm deep, with a skirt at
## the hairline so its edge has body. `spec`: fringe (centre height), temple (height where it
## turns down at the sides), nape (lowest point behind), strands (scallops across the fringe).
static func hair_shell(frame: Dictionary, spec: Dictionary) -> ArrayMesh:
	var fringe: float = spec.get("fringe", 58.0)
	var temple: float = spec.get("temple", 30.0)
	var nape: float = spec.get("nape", -110.0)
	var strands: int = spec.get("strands", 7)
	var ear_top: float = spec.get("ear_top", 35.0)
	var thick: float = spec.get("thick", 11.0)
	var axis: Vector3 = frame["axis"]
	var c := axis + Vector3(0, 0.05, 0)
	var cols := 145
	var rows := 40
	var out := PackedVector3Array()
	var uvs := PackedVector2Array()
	var lifts := PackedFloat32Array()
	var r := PackedFloat32Array()  # distance from the centre to the skin, per grid point
	for j in rows:
		var t := float(j) / (rows - 1)
		for i in cols:
			var th := lerpf(-PI, PI, float(i) / (cols - 1))
			var y_h := hairline(th, fringe, temple, nape, strands, ear_top)
			var phi0 := atan2(y_h * 0.001 - 0.05, 0.13)
			# row 0 is the skirt, on the skin; row 1 the edge; then up to the crown
			var phi := lerpf(phi0, deg_to_rad(90.0), maxf(t - 1.0 / (rows - 1), 0.0) * (rows - 1) / (rows - 2))  # up to the crown: no hole
			var dir := Vector3(sin(th) * cos(phi), sin(phi), cos(th) * cos(phi))
			var hit := cast(frame["tm"], frame["xf"], c, dir)
			r.append(((hit["position"] as Vector3) - c).length() if not hit.is_empty() else 0.13)
			out.append(dir)
			uvs.append(Vector2(float(i) / (cols - 1), t))
			lifts.append(0.6 if j == 0 else thick * lerpf(0.8, 1.0, t))
	# The shell spans small bumps instead of dipping between them: each point takes the largest
	# distance round it, so no edge of the grid cuts under the skin.
	var pos := PackedVector3Array()
	pos.resize(r.size())
	for j in rows:
		for i in cols:
			var best := 0.0
			for dj in range(-2, 3):
				for di in range(-2, 3):
					var jj := clampi(j + dj, 0, rows - 1)
					var ii := posmod(i + di, cols - 1)
					best = maxf(best, r[jj * cols + ii])
			var k := j * cols + i
			pos[k] = c + out[k] * best
	return grid_mesh(pos, out, uvs, lifts, cols, rows, true)

## The hairline's height (mm from the eye line) at angle `th` round the head (0 = the face).
static func hairline(th: float, fringe: float, temple: float, nape: float, strands: int, ear_top := 35.0) -> float:
	var d := absf(th)
	var front := deg_to_rad(38.0)
	if d < front:
		# strands: points hanging from the fringe, swept a little toward her right
		var s := (th + front) / (2.0 * front) * strands + 0.25
		var tri := 1.0 - absf(fposmod(s, 1.0) * 2.0 - 1.0)
		return fringe + 6.0 * d / front - 11.0 * tri * tri
	if d < deg_to_rad(62.0):
		return lerpf(fringe + 6.0, temple, smoothstep(front, deg_to_rad(62.0), d))
	# The ears stay bare: the hairline rises over each ear (on Oto's head about 97-118 degrees
	# round, 48 mm below to 35 mm above the eye line) with a gap, and falls again behind it.
	var over := ear_top + 10.0
	if d < deg_to_rad(90.0):
		return lerpf(temple, over, smoothstep(deg_to_rad(62.0), deg_to_rad(90.0), d))
	if d < deg_to_rad(128.0):
		return over + 3.0 * sin(PI * (d - deg_to_rad(90.0)) / deg_to_rad(38.0))
	if d < deg_to_rad(150.0):
		return lerpf(over, nape * 0.75, smoothstep(deg_to_rad(128.0), deg_to_rad(150.0), d))
	return lerpf(nape * 0.75, nape, smoothstep(deg_to_rad(150.0), PI, d))

## One loose strand falling from the fringe beside the face, kept outside the eye: a ribbon
## through face-space points (mm), `w` wide at the root, tapering to a point.
static func strand(frame: Dictionary, path: PackedVector2Array, w: float, lift: float) -> ArrayMesh:
	var n := path.size()
	var verts := PackedVector3Array()
	var nrm := PackedVector3Array()
	var pts := PackedVector3Array()
	var ns := PackedVector3Array()
	for i in n:
		var hit := surface(frame, path[i].x, path[i].y)
		ns.append(hit["normal"])
		pts.append((hit["position"] as Vector3) + (hit["normal"] as Vector3) * (lift + 3.0 * sin(PI * float(i) / (n - 1))) * 0.001)
	for i in n:
		var tg := (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var side := tg.cross(ns[i]).normalized()
		var hw := w * 0.5 * (1.0 - pow(float(i) / (n - 1), 1.5)) * 0.001
		verts.append_array([pts[i] + side * hw, pts[i] - side * hw])
		nrm.append_array([ns[i], ns[i]])
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

## A plate over one ear (side 1 = her left, -1 = her right), cast straight onto the ear from
## the side it faces so its art is not squeezed; UVs match EAR_REGION's pixels. Null if the
## mesh has no ear in HEADS.
static func ear_plate(frame: Dictionary, model_key: String, side: float, lift_mm := 1.0) -> ArrayMesh:
	var ear: Dictionary = HEADS.get(model_key, {}).get("ear", {})
	if ear.is_empty():
		return null
	var mid := surface(frame, deg_to_rad(float(ear["deg"])) * R_REF, float(ear["y"]))
	var f := deg_to_rad(float(ear["faces"]))
	var out := Vector3(sin(f), 0, cos(f))
	var back := Vector3(cos(f), 0, -sin(f))  # along the ear toward the back of the head
	var centre: Vector3 = mid["position"]
	var mirror := func(v: Vector3) -> Vector3: return Vector3(v.x * side, v.y, v.z)
	var pr := FaceCanvas.px_rect(EAR_REGION)
	var cols := 37
	var rows := 53
	var pos := PackedVector3Array()
	var outward := PackedVector3Array()
	var uvs := PackedVector2Array()
	for j in rows:
		var v := float(j) / (rows - 1)
		var y_mm := (FaceCanvas.EYE_ROW - (pr.position.y + v * pr.size.y)) / FaceCanvas.PPMM
		for i in cols:
			var u := float(i) / (cols - 1)
			var x_mm := (pr.position.x + u * pr.size.x - FaceCanvas.TEX_W * 0.5) / FaceCanvas.PPMM
			var p := centre + back * x_mm * 0.001 + Vector3.UP * y_mm * 0.001
			var from: Vector3 = mirror.call(p + out * 0.12)
			var dir: Vector3 = mirror.call(-out)
			var hit := cast(frame["tm"], frame["xf"], from, dir)
			pos.append(hit["position"] if not hit.is_empty() else mirror.call(p))
			outward.append(mirror.call(out))
			uvs.append(Vector2(u, v))
	var lifts := PackedFloat32Array()
	lifts.resize(pos.size())
	lifts.fill(lift_mm)
	return grid_mesh(pos, outward, uvs, lifts, cols, rows)

## A small ellipsoid of the head's own skin set into the face (nose or chin); null for none.
static func bump(frame: Dictionary, spec: Dictionary) -> MeshInstance3D:
	if spec.is_empty():
		return null
	var head0: MeshInstance3D = frame["head"]
	var skin_mat: Material = head0.material_override if head0.material_override else head0.get_active_material(0)
	if spec.get("shape", "ball") == "wedge":
		var w := MeshInstance3D.new()
		w.mesh = wedge(frame, spec)
		w.material_override = skin_mat
		return w
	var hit := surface(frame, 0.0, float(spec["y"]) + float(spec.get("h", 0.0)) * 0.5)
	var n: Vector3 = hit["normal"]
	n = Vector3(0, n.y * 0.3, n.z).normalized() if absf(n.z) > 0.2 else Vector3(0, 0, 1)
	var out: float = spec["out"]
	var rz := out + 4.0
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 24
	s.rings = 12
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = skin_mat
	var basis := Basis.looking_at(-n, Vector3.UP).rotated(Vector3.RIGHT, -float(spec.get("tilt", 0.0)))
	mi.transform = Transform3D(basis.scaled_local(Vector3(float(spec["w"]), float(spec["h"]), rz * 2.0) * 0.001),
		(hit["position"] as Vector3) + n * (out - rz) * 0.001)
	return mi

## The DBZ nose as a faceted ridge: flush with the face at the bridge and the nostril wings,
## rising to a tip `out` mm off it, with a small underside.
static func wedge(frame: Dictionary, spec: Dictionary) -> ArrayMesh:
	var y: float = spec["y"]
	var ln: float = spec["len"]
	var w: float = spec["w"]
	var out: float = spec["out"]
	var at := func(x: float, yy: float, off: float) -> Vector3:
		var h := surface(frame, x, yy)
		return (h["position"] as Vector3) + (h["normal"] as Vector3) * off * 0.001
	# tip_k: how far up the tip sits (of the length); the underside from it back to the face is
	# the triangle DBZ noses show in profile. mid_k: how far out the ridge is halfway down.
	var tip_k: float = spec.get("tip_k", 0.1)
	var mid_k: float = spec.get("mid_k", 0.45)
	var top: Vector3 = at.call(0.0, y + ln, -1.0)
	var mid: Vector3 = at.call(0.0, y + ln * 0.5, out * mid_k)
	var tip: Vector3 = at.call(0.0, y + maxf(ln * tip_k, 3.0), out)
	var sl: Vector3 = at.call(-w * 0.32, y + ln * 0.55, -1.0)
	var sr: Vector3 = at.call(w * 0.32, y + ln * 0.55, -1.0)
	var wl: Vector3 = at.call(-w * 0.5, y + maxf(ln * tip_k, 3.0) * 0.8, -1.0)
	var wr: Vector3 = at.call(w * 0.5, y + maxf(ln * tip_k, 3.0) * 0.8, -1.0)
	var under: Vector3 = at.call(0.0, y - 1.0, -1.0)
	var axis: Vector3 = frame["axis"]
	var tris := [[top, sl, mid], [sl, wl, mid], [mid, wl, tip], [top, mid, sr], [sr, mid, wr], [mid, tip, wr], [wl, under, tip], [tip, under, wr]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t: Array in tris:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var c: Vector3 = t[2]
		var centre := (a + b + c) / 3.0
		var outward := centre - Vector3(axis.x, centre.y, axis.z)
		var n := (b - a).cross(c - a)
		if n.dot(outward) > 0.0:  # Godot's front faces wind clockwise seen from outside
			var tmp := b
			b = c
			c = tmp
			n = -n
		for v: Vector3 in [a, b, c]:
			st.set_normal(-n.normalized())
			st.add_vertex(v)
	return st.commit()
