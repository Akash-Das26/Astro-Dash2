class_name CreditsCard
extends Control
## The CREDITS card: a rolling list built from Credits.groups(). Any key or click
## pauses the roll, Esc/B closes the card. The card is shaped like the other
## overlays: a dimmer, a centred panel sized to its content and a close button.

signal closed

const ROLL_CLIP: String = "Panel/Margin/Box/Roll"
const ROLL_BOX: String = "Panel/Margin/Box/Roll/RollBox"
const CLOSE_BUTTON: String = "Panel/Margin/Box/Header/CloseButton"
const GROUP_SIZE: int = 15
const ENTRY_SIZE: int = 12
const DETAIL_SIZE: int = 11
const SECTION_GAP: float = 12.0
const ROW_GAP: float = 7.0
const ROLL_BOTTOM_SLACK: float = 24.0

@onready var _clip: Control = get_node(ROLL_CLIP)
@onready var _roll: VBoxContainer = get_node(ROLL_BOX)
@onready var _close: Button = get_node(CLOSE_BUTTON)

var _paused: bool = false
var _offset: float = 0.0
var _built: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_process(false)
	_close.pressed.connect(close)


## Shows the card and starts the roll from the top. Safe to call on the same
## instance every time the button is pressed.
func open() -> void:
	if not _built:
		# Built after this frame's layout, so the clipped area already has its
		# real width and every line wraps to it instead of to zero.
		_built = true
		_build.call_deferred()
	_offset = 0.0
	_roll.position = Vector2.ZERO
	_paused = false
	visible = true
	set_process(true)
	_close.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	set_process(false)
	closed.emit()


func _process(delta: float) -> void:
	if _paused or not visible:
		return
	_offset -= Tuning.CREDITS_SCROLL_SPEED * delta
	# Loop once the last line has cleared the top, so the card never runs dry.
	if -_offset > _roll.size.y + ROLL_BOTTOM_SLACK:
		_offset = 0.0
	_roll.position = Vector2(0.0, _offset)


## A key or a click pauses the roll; Esc/B (or any close action) closes the card.
## Marked handled through the stored viewport, before anything can change scene.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	if event.is_action_pressed(&"ui_cancel"):
		viewport.set_input_as_handled()
		close()
		return
	var pressed: bool = false
	var key_event := event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo:
		pressed = true
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null and mouse_event.pressed:
		pressed = true
	if not pressed:
		return
	viewport.set_input_as_handled()
	_paused = not _paused


## One label per line: "title — author (license)", the source URL under it and a
## gap between groups. Labels wrap to the clip width, so no line widens the card.
func _build() -> void:
	for child: Node in _roll.get_children():
		_roll.remove_child(child)
		child.queue_free()
	var width: float = maxf(_clip.size.x, 1.0)
	for group: Dictionary in Credits.groups():
		_add_line(
			String(group.get("title", "")), GROUP_SIZE, Color(1.0, 0.85, 0.45), width
		)
		for entry: Dictionary in group.get("entries", []):
			_add_line(
				"%s — %s (%s)" % [
					String(entry.get("title", "")), String(entry.get("author", "")),
					String(entry.get("license", "")),
				],
				ENTRY_SIZE, Color(0.86, 0.92, 1.0), width
			)
			var detail: String = _detail_for(entry)
			if not detail.is_empty():
				_add_line(detail, DETAIL_SIZE, Color(0.55, 0.64, 0.8), width)
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(width, SECTION_GAP)
		_roll.add_child(spacer)
	# The two fixed lines the card always ends on.
	_add_line(Credits.CODE_LINE, ENTRY_SIZE, Color(0.86, 0.92, 1.0), width)
	_add_line(Credits.ENGINE_LINE, ENTRY_SIZE, Color(0.86, 0.92, 1.0), width)
	_roll.custom_minimum_size = Vector2(width, 0.0)


## The source URL, the license link, or both.
func _detail_for(entry: Dictionary) -> String:
	var url: String = String(entry.get("url", ""))
	var license_link: String = Credits.license_url(entry)
	if url.is_empty():
		return license_link
	if license_link.is_empty():
		return url
	return "%s  ·  %s" % [url, license_link]


func _add_line(text: String, size: int, color: Color, width: float) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0.0)
	_roll.add_child(label)
