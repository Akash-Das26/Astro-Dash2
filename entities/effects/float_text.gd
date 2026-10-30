class_name FloatText
extends Node2D
## World-space label for "+150 COMBO!" at the kill location: it rises and fades
## on its own and frees itself. Drawn with the theme font, so it needs no
## texture (a pixel font can replace the fallback later).

const FONT_SIZE: int = 15

var text: String = ""
var tint: Color = Color.WHITE

var _life: float = Tuning.COMBO_FLOAT_LIFE
var _age: float = 0.0
var _rise: float = Tuning.COMBO_FLOAT_RISE


func setup(label: String, color: Color, life_time: float = Tuning.COMBO_FLOAT_LIFE, rise: float = Tuning.COMBO_FLOAT_RISE) -> void:
	text = label
	tint = color
	_life = maxf(life_time, 0.05)
	_rise = rise


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	position.y -= _rise * delta / _life
	queue_redraw()


func _draw() -> void:
	var width: float = 220.0
	var height: float = 20.0
	var font := ThemeDB.fallback_font
	var alpha: float = clampf(1.0 - _age / _life, 0.0, 1.0)
	draw_string(
		font,
		Vector2(-width * 0.5, height * 0.5),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		width,
		FONT_SIZE,
		Color(tint.r, tint.g, tint.b, alpha)
	)
