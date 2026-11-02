class_name UIIcons
extends RefCounted
## Icons are measured and drawn by their OPAQUE pixels, not by their texture box.
##
## The hull art carries a transparent margin, and it is a different size per skin
## (100x90 hulls, a 70x50 interceptor, 32x32 elites). Centring the texture put
## the visible ship slightly left of and above the box centre, and the
## interceptor low, because its padding is asymmetric.

## Alpha (0-255) at or above this counts as drawn. The art is hard-edged pixel
## art, so anything fainter is padding.
const ALPHA_THRESHOLD: int = 16
## Same margin on every side of an icon box.
const DEFAULT_PADDING: float = 3.0

## Texture instance id -> opaque bounds, in texture pixels.
static var _opaque: Dictionary = {}


## The rectangle the visible pixels occupy, in texture pixels.
static func opaque_rect(texture: Texture2D) -> Rect2:
	if texture == null:
		return Rect2()
	var key: int = texture.get_instance_id()
	if _opaque.has(key):
		return _opaque[key]
	var bounds := Rect2(Vector2.ZERO, texture.get_size())
	var image: Image = texture.get_image()
	if image != null:
		var scan: Image = image
		if scan.is_compressed():
			scan = scan.duplicate() as Image
			scan.decompress()
		if scan.get_format() != Image.FORMAT_RGBA8:
			scan.convert(Image.FORMAT_RGBA8)
		var used: Rect2i = _scan_used(scan)
		if used.size.x > 0 and used.size.y > 0:
			bounds = Rect2(used)
	_opaque[key] = bounds
	return bounds


## One pass over the image, so a faint anti-aliased fringe does not count as art
## the way `Image.get_used_rect()` would.
static func _scan_used(image: Image) -> Rect2i:
	var width: int = image.get_width()
	var height: int = image.get_height()
	var min_x: int = width
	var min_y: int = height
	var max_x: int = -1
	var max_y: int = -1
	for y: int in height:
		for x: int in width:
			if image.get_pixel(x, y).a * 255.0 < float(ALPHA_THRESHOLD):
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


## Uniform scale that fits the opaque pixels into `box_size` without squashing.
static func fit_scale(texture: Texture2D, box_size: Vector2) -> float:
	var used: Rect2 = opaque_rect(texture)
	if used.size.x <= 0.0 or used.size.y <= 0.0:
		return 0.0
	if box_size.x <= 0.0 or box_size.y <= 0.0:
		return 0.0
	return minf(box_size.x / used.size.x, box_size.y / used.size.y)


## The opaque pixels scaled to fit `max_size` and centred in `box`: the same
## padding on all four sides, whatever transparent margin the texture carries.
static func icon_rect(texture: Texture2D, box: Rect2, max_size: Vector2) -> Rect2:
	var used: Rect2 = opaque_rect(texture)
	var scale: float = fit_scale(texture, max_size)
	var drawn: Vector2 = used.size * scale
	return Rect2(box.position + (box.size - drawn) * 0.5, drawn)
