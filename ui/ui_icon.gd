class_name UIIcon
extends Control
## One texture drawn in a box, aligned by its OPAQUE pixels: the visible art is
## centred with the same margin on all four sides, no matter how much
## transparent padding the source carries and how lopsided it is.
##
## Drop it in as a child of the button or slot that owns the box; the control
## fills the box and draws the icon inside it.

@export var padding: float = UIIcons.DEFAULT_PADDING
@export var tint: Color = Color.WHITE:
	set(value):
		tint = value
		queue_redraw()

var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_padding(value: float) -> void:
	padding = maxf(value, 0.0)
	queue_redraw()


## The rect the opaque pixels occupy, in this control's local space. The layout
## tests read this instead of guessing from the texture.
func drawn_rect() -> Rect2:
	var max_size: Vector2 = size - Vector2.ONE * padding * 2.0
	return UIIcons.icon_rect(texture, Rect2(Vector2.ZERO, size), max_size)


func _draw() -> void:
	if texture == null:
		return
	var max_size: Vector2 = size - Vector2.ONE * padding * 2.0
	if max_size.x <= 0.0 or max_size.y <= 0.0:
		return
	draw_texture_rect_region(
		texture, drawn_rect(), UIIcons.opaque_rect(texture), tint
	)
