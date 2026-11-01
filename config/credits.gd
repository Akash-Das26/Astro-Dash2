class_name Credits
extends RefCounted
## The single source of credits: the in-game roll, the Settings NOW PLAYING line
## and the tests all read this instead of repeating names.
##
## Every entry here came from the asset's own page. Anything marked TODO is
## deliberately unknown (see docs/todo.md) rather than guessed.

const CODE_LINE: String = "Code: MIT, © 2026 Akash Das"
const ENGINE_LINE: String = "Made with Godot Engine"

const LICENSE_URLS: Dictionary = {
	&"cc_by_3": "https://creativecommons.org/licenses/by/3.0/",
	&"cc_by_sa_3": "https://creativecommons.org/licenses/by-sa/3.0/",
	&"cc0_1": "https://creativecommons.org/publicdomain/zero/1.0/",
}

## The order the roll lists the tracks in, and the keys of MUSIC.
const MUSIC_ORDER: Array[String] = [
	"Orbital Colossus",
	"n-Dimensions (Main Theme - Retro Ver",
	"8-bit_perilous_dungeon",
	"8bit",
	"Preparing for War",
]

## Keyed by the base name the playlist reports (file name without extension).
const MUSIC: Dictionary = {
	"Orbital Colossus": {
		"title": "Space Boss Battle Theme",
		"author": "Matthew Pablo",
		"license": "CC BY 3.0",
		"license_key": &"cc_by_3",
		"url": "https://opengameart.org/content/space-boss-battle-theme",
	},
	"n-Dimensions (Main Theme - Retro Ver": {
		"title": "Space Dimensions (8bit/Retro Version)",
		"author": "Matthew Pablo",
		"license": "CC BY 3.0",
		"license_key": &"cc_by_3",
		"url": "https://opengameart.org/content/space-dimensions-8bitretro-version",
	},
	"8-bit_perilous_dungeon": {
		"title": "8-bit Perilous Dungeon",
		"author": "HydroGene",
		"license": "CC0",
		"license_key": &"cc0_1",
		"url": "https://opengameart.org/content/8-bit-perilous-dungeon",
	},
	"8bit": {
		"title": "8bit thingy",
		"author": "extenz",
		"license": "CC BY 3.0",
		"license_key": &"cc_by_3",
		"url": "https://opengameart.org/content/8bit-thingy",
	},
	"Preparing for War": {
		"title": "Prepare for War",
		"author": "Trevor Lentz",
		"license": "CC BY-SA 3.0",
		"license_key": &"cc_by_sa_3",
		"url": "https://opengameart.org/content/prepare-for-war",
	},
}

const SOUND_EFFECTS: Array[Dictionary] = [
	{
		"title": "512 Sound Effects (8-bit style)",
		"author": "SubspaceAudio (Juhani Junkala)",
		"license": "CC0",
		"license_key": &"cc0_1",
		"url": "https://opengameart.org/content/512-sound-effects-8-bit-style",
	},
	{
		"title": "Ove's Essential Game Audio Pack Collection",
		"author": "OveMelaa",
		"license": "CC BY 3.0",
		"license_key": &"cc_by_3",
		"url": "https://opengameart.org/content/oves-essential-game-audio-pack-collection-160-files-updated",
	},
]

const FONTS: Array[Dictionary] = [
	{
		"title": "Pixelify Sans",
		"author": "Stefie Justprince",
		"license": "SIL OFL 1.1",
		"url": "https://fonts.google.com/specimen/Pixelify+Sans",
	},
	{
		"title": "Press Start 2P",
		"author": "CodeMan38",
		"license": "SIL OFL 1.1",
		"url": "https://fonts.google.com/specimen/Press+Start+2P",
	},
]

## The two sprite packs are still waiting for their owner's data.
const ART: Array[Dictionary] = [
	{
		"title": "SpacePixels sprite packs",
		"author": "TODO",
		"license": "TODO",
		"url": "TODO",
	},
	{
		"title": "Space backgrounds pack",
		"author": "TODO",
		"license": "TODO",
		"url": "TODO",
	},
]


## The entry for one track, by base name or file name. Empty when the track has
## no credit (the tests check that this never happens for a shipped file).
static func music_entry(track: String) -> Dictionary:
	var base: String = track.get_file().get_basename()
	if MUSIC.has(base):
		return MUSIC[base]
	return {}


## "Space Boss Battle Theme — Matthew Pablo", or empty when uncredited.
static func music_label(track: String) -> String:
	var entry: Dictionary = music_entry(track)
	if entry.is_empty():
		return ""
	return "%s — %s" % [String(entry["title"]), String(entry["author"])]


## The license link for an entry, or empty when it has none (the fonts).
static func license_url(entry: Dictionary) -> String:
	var key: StringName = StringName(entry.get("license_key", &""))
	return String(LICENSE_URLS.get(key, ""))


static func has_credit(entry: Dictionary) -> bool:
	return not String(entry.get("title", "")).is_empty() \
		and not String(entry.get("author", "")).is_empty() \
		and not String(entry.get("license", "")).is_empty()


## True when the license needs the author named on screen.
static func needs_attribution(entry: Dictionary) -> bool:
	var license: String = String(entry.get("license", "")).to_upper()
	return license.begins_with("CC BY")


## Every shipped music file that has no credits entry.
static func uncredited_music(file_names: PackedStringArray) -> PackedStringArray:
	var missing: PackedStringArray = PackedStringArray()
	for file_name: String in file_names:
		if music_entry(file_name).is_empty():
			missing.append(file_name)
	return missing


## The roll, grouped and ready to draw: [{ "title": "MUSIC", "entries": [...] }].
static func groups() -> Array[Dictionary]:
	var music: Array[Dictionary] = []
	for track: String in MUSIC_ORDER:
		if MUSIC.has(track):
			music.append(MUSIC[track])
	return [
		{"title": "MUSIC", "entries": music},
		{"title": "SOUND EFFECTS", "entries": SOUND_EFFECTS.duplicate(true)},
		{"title": "ART", "entries": ART.duplicate(true)},
		{"title": "FONTS", "entries": FONTS.duplicate(true)},
		{"title": "ENGINE", "entries": [
			{"title": "Godot Engine", "author": "Godot contributors", "license": "MIT",
				"url": "https://godotengine.org"},
		]},
	]
