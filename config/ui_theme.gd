class_name UITheme
extends RefCounted
## The one theme every screen uses.
##
## Two optional OFL pixel fonts are loaded from `res://assets/fonts/`
## (searched one folder deep): Pixelify Sans for body copy and Press Start 2P
## for titles, banners and big numbers. The display font is exposed as the
## `DisplayLabel` / `DisplayButton` type variations, so a scene only has to set
## `theme_type_variation` on those nodes.
##
## Every file is optional. When a font is missing the theme builds with the
## engine's default font and the type variations are simply never registered,
## so screens still load and nothing errors. Sizes and colours live here, not in
## each scene, so the whole UI stays on one scale.

const FONT_DIR: String = "res://assets/fonts"
## Only importable formats: a stray .bdf/.fnt without an import file would make
## ResourceLoader log an error, so those are skipped silently instead.
const FONT_EXTENSIONS: Array[String] = ["ttf", "otf", "woff", "woff2"]
## Case-insensitive filename hints. First match wins.
const BODY_FONT_HINTS: Array[String] = ["pixelify"]
const DISPLAY_FONT_HINTS: Array[String] = ["press"]
## How many folder levels under FONT_DIR are searched (the packs ship in their
## own subfolders).
const FONT_SCAN_DEPTH: int = 2

const SIZE_TITLE: int = 46
const SIZE_HEADING: int = 26
const SIZE_BODY: int = 16
const SIZE_SMALL: int = 13
const SIZE_BUTTON: int = 18
## Press Start 2P is much wider than a normal face, so the display variation
## starts smaller than the regular title scale.
const SIZE_DISPLAY: int = 30

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
static var _display_font: Font
static var _scanned: bool = false


## The shared theme. Built once, then reused by every screen.
static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	_theme.default_font_size = SIZE_BODY
	_scan_fonts()
	if _font != null:
		_theme.default_font = _font
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
	# Titles, banners and big numbers. Without the file these variations do not
	# exist, and a node asking for one just falls back to its own class.
	if _display_font != null:
		_theme.set_type_variation("DisplayLabel", "Label")
		_theme.set_font("font", "DisplayLabel", _display_font)
		_theme.set_font_size("font_size", "DisplayLabel", SIZE_DISPLAY)
		_theme.set_type_variation("DisplayButton", "Button")
		_theme.set_font("font", "DisplayButton", _display_font)
		_theme.set_font_size("font_size", "DisplayButton", SIZE_DISPLAY)
	return _theme


## Applies the theme to a screen root; children inherit it.
static func apply(control: Control) -> void:
	control.theme = get_theme()


## The body font if one was found, otherwise null (default font).
static func load_font() -> Font:
	_scan_fonts()
	return _font


static func body_font() -> Font:
	_scan_fonts()
	return _font


static func display_font() -> Font:
	_scan_fonts()
	return _display_font


static func has_font() -> bool:
	return body_font() != null


static func has_display_font() -> bool:
	return display_font() != null


## Scans the font folder once, picking the first file whose name contains a
## hint. Missing folder or unreadable font is not an error.
static func _scan_fonts() -> void:
	if _scanned:
		return
	_scanned = true
	# Each face is found on its own; when one is missing its nodes simply use
	# the engine default font instead of inheriting the other face.
	_font = _find(BODY_FONT_HINTS, FONT_SCAN_DEPTH)
	_display_font = _find(DISPLAY_FONT_HINTS, FONT_SCAN_DEPTH)


static func _find(hints: Array[String], depth: int) -> Font:
	for hint: String in hints:
		var found: Font = _scan_dir(FONT_DIR, hint, depth)
		if found != null:
			return found
	return null


static func _scan_dir(path: String, hint: String, depth: int) -> Font:
	var dir := DirAccess.open(path)
	if dir == null:
		return null
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full: String = path + "/" + entry
		if dir.current_is_dir():
			if depth > 0:
				var nested: Font = _scan_dir(full, hint, depth - 1)
				if nested != null:
					dir.list_dir_end()
					return nested
		elif FONT_EXTENSIONS.has(entry.get_extension().to_lower()):
			if hint.is_empty() or entry.to_lower().contains(hint):
				var loaded: Resource = ResourceLoader.load(full)
				if loaded is Font:
					dir.list_dir_end()
					return loaded as Font
		entry = dir.get_next()
	dir.list_dir_end()
	return null


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
