class_name Battle
extends Resource
## One battle: how many waves, how many enemies in each, which kinds, how busy
## the asteroid field is and which background the arena uses. The galaxy map
## builds these per body; the debug harness builds one from a preset.
##
## Presets live in Tuning.BATTLES as plain dictionaries so they stay easy to
## edit while balancing. The extra fields below are only filled in by the
## campaign and keep their neutral defaults for a preset.

@export var title: String = ""
@export var waves: int = 1
@export var enemies_per_wave: int = 10
## { fighter kind (StringName): weight }. Weights decide the mix, not the count.
@export var enemy_mix: Dictionary = {}
@export var asteroid_density: float = 0.5
@export var background: Texture2D
## True for the red band, where enemy shots switch to a yellow-white outline so
## they stay readable against the backdrop.
@export var hot_backdrop: bool = false
## Difficulty from the body's distance band and trait: fighter HP and the gap
## between enemy shots. 1.0/1.0 is the baseline.
@export var hp_scale: float = 1.0
@export var fire_interval_scale: float = 1.0
## Citadel boss guarding this body. An empty colour means no boss.
@export var boss_color: StringName = &""
@export var boss_title: String = ""
@export var boss_hp: int = 0
## Flat energy banked on victory, on top of the orbs dropped in the fight.
@export var reward_energy: int = 0


## Builds a battle from a Tuning.BATTLES row. Unknown keys fall back to the
## default so a typo in a preset cannot leave the arena empty.
static func preset(key: StringName) -> Battle:
	var row: Dictionary = Tuning.BATTLES.get(key, Tuning.BATTLES[Tuning.DEFAULT_BATTLE])
	var battle := Battle.new()
	battle.title = String(row.get("title", String(key).to_upper()))
	battle.waves = maxi(int(row.get("waves", 1)), 1)
	battle.enemies_per_wave = maxi(int(row.get("enemies_per_wave", 1)), 1)
	battle.enemy_mix = (row.get("mix", {}) as Dictionary).duplicate()
	battle.asteroid_density = maxf(float(row.get("asteroid_density", 0.0)), 0.0)
	battle.background = row.get("background", null) as Texture2D
	return battle


func has_boss() -> bool:
	return boss_color != &""


## Enemies the whole battle will spawn, for the HUD's "killed / total" readout.
func enemy_total() -> int:
	return waves * enemies_per_wave
