class_name Sigil
extends RefCounted
## The Shadow Saiyans' sigil, "The Wall": a frame with one upright line through it. The line
## is the line of sunlight that split their world; her people lived on its dark side. Chosen
## by the owner on 2026-10-28: black on gold, on the scapular's front panel and engraved on
## both gauntlets. Drawn in code.
##   texture(false): a plaque, white field with the black sigil. Tint the field gold or silver
##                   with the material's albedo colour.
##   texture(true):  the black sigil alone on transparent, for engraving metal.

const TEX_W := 64
const TEX_H := 128
const MARGIN := 6
const STROKE := 6
const WALL := 8  # the upright line is a little heavier than the frame

static var _cache := {}

static func texture(engraving: bool) -> ImageTexture:
	var key := "engraving" if engraving else "plaque"
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(TEX_W, TEX_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0) if engraving else Color.WHITE)
	var ink := Color(0, 0, 0, 1)
	var inner_w := TEX_W - 2 * MARGIN
	var inner_h := TEX_H - 2 * MARGIN
	img.fill_rect(Rect2i(MARGIN, MARGIN, inner_w, STROKE), ink)
	img.fill_rect(Rect2i(MARGIN, TEX_H - MARGIN - STROKE, inner_w, STROKE), ink)
	img.fill_rect(Rect2i(MARGIN, MARGIN, STROKE, inner_h), ink)
	img.fill_rect(Rect2i(TEX_W - MARGIN - STROKE, MARGIN, STROKE, inner_h), ink)
	img.fill_rect(Rect2i(TEX_W / 2 - WALL / 2, MARGIN, WALL, inner_h), ink)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
