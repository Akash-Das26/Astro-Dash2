class_name UITheme
extends RefCounted
## The one theme every screen uses.
##
## The pixel font is loaded from `res://assests/fonts/` at runtime (the folder
## may not exist yet). When it is missing the theme still builds with the
## engine's default font, so screens never fail to load over a missing file.
## Sizes and colours live here, not in each scene, so the whole UI stays on one
## scale.

const FONT_DIR: String = "res://assests/fonts"
const FONT_EXTENSIONS: Array[String] = ["ttf", "otf", "woff", "woff2"]

const SIZE_TITLE: int = 46
const SIZE_HEADING: int = 26
const SIZE_BODY: int = 16
const SIZE_SMALL: int = 13
const SIZE_BUTTON: int = 18

const COLOR_TEXT: Color = Color(0.9, 0.94, 1.0)
const COLOR_MUTED: Color = Color(0.6, 0.68, 0.84)
const COLOR_ACCENT: Color = Color(0.55, 1.0, 0.7)
const COLOR_WARN: Color = Color(1.0, 0.45, 0.4)
const COLOR_GOLD: Color = Color(1.0, 0.85, 0.2)

const BUTTON_FILL: Color = Color(0.05, 0.07, 0.13, 0.95)
const BUTTON_BORDER: Color = Color(0.28, 0.42, 0.66, 0.8)
const BUTTON_HOVER_FILL: Color = Color(0.1, 0.18, 0.28, 1.0)
const BUTTON_HOVER_BORDER: Color = Color(0.5, 1.0, 0.7, 0.9)
const CARD_FILL: Color = Color(0.035, 0.05, 0.1, 0.97)
const CARD_BORDER: Color = Color(0.3, 0.65, 0.5, 0.85)

static var _theme: Theme
static var _font: Font


## The shared theme. Built once, then reused by every screen.
static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	_theme.default_font_size = SIZE_BODY
	var font: Font = load_font()
	if font != null:
		_theme.default_font = font
	_theme.set_font_size("font_size", "Label", SIZE_BODY)
	_theme.set_font_size("font_size", "Button", SIZE_BUTTON)
	_theme.set_font_size("font_size", "CheckButton", SIZE_SMALL)
	_theme.set_font_size("font_size", "HSlider", SIZE_SMALL)
	_theme.set_color("font_color", "Label", COLOR_TEXT)
	_theme.set_color("font_color", "Button", COLOR_TEXT)
	_theme.set_color("font_hover_color", "Button", Color.WHITE)
	_theme.set_color("font_focus_color", "Button", Color.WHITE)
	_theme.set_color("font_disabled_color", "Button", Color(0.42, 0.48, 0.6))
	_theme.set_stylebox("normal", "Button", _box(BUTTON_FILL, BUTTON_BORDER))
	_theme.set_stylebox("hover", "Button", _box(BUTTON_HOVER_FILL, BUTTON_HOVER_BORDER))
	_theme.set_stylebox("pressed", "Button", _box(BUTTON_HOVER_FILL, COLOR_ACCENT))
	_theme.set_stylebox("focus", "Button", _box(Color(0.1, 0.18, 0.28, 0.55), COLOR_GOLD))
	_theme.set_stylebox("disabled", "Button", _box(Color(0.04, 0.05, 0.08, 0.7), Color(0.22, 0.28, 0.38, 0.6)))
	_theme.set_stylebox("panel", "PanelContainer", _card_box())
	_theme.set_stylebox("panel", "Panel", _card_box())
	return _theme


## Applies the theme to a screen root; children inherit it.
static func apply(control: Control) -> void:
	control.theme = get_theme()


## The pixel font if the folder has one, otherwise null (default font).
static func load_font() -> Font:
	if _font != null:
		return _font
	var dir := DirAccess.open(FONT_DIR)
	if dir == null:
		return null
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir():
			var extension: String = entry.get_extension().to_lower()
			if FONT_EXTENSIONS.has(extension):
				var loaded: Resource = ResourceLoader.load(FONT_DIR + "/" + entry)
				if loaded is Font:
					_font = loaded as Font
					break
		entry = dir.get_next()
	dir.list_dir_end()
	return _font


static func has_font() -> bool:
	return load_font() != null


static func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.corner_radius_top_left = 4
	box.corner_radius_top_right = 4
	box.corner_radius_bottom_left = 4
	box.corner_radius_bottom_right = 4
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	return box


static func _card_box() -> StyleBoxFlat:
	var box := _box(CARD_FILL, CARD_BORDER)
	box.corner_radius_top_left = 8
	box.corner_radius_top_right = 8
	box.corner_radius_bottom_left = 8
	box.corner_radius_bottom_right = 8
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 16.0
	box.content_margin_bottom = 16.0
	return box
