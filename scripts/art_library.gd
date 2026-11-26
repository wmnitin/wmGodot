extends RefCounted
class_name ArtLibrary

## Every sprite the match draws. Swap the PNG at the same path
## and the rules do not need to change.

const DISC := "res://assets/sprites/disc.png"
const TOWER_FACE := "res://assets/sprites/tower_face.png"
const TOWER_TOP := "res://assets/sprites/tower_top.png"
const RIM := "res://assets/sprites/rim.png"
const SHADOW := "res://assets/sprites/shadow.png"
const PIP := "res://assets/sprites/pip.png"
const BACKGROUND := "res://assets/sprites/background.png"
const ICON := "res://assets/sprites/icon.png"
const SOLDIER := {
	"player": "res://assets/sprites/soldier_player.png",
	"enemy": "res://assets/sprites/soldier_enemy.png",
}
const PORTRAIT := {
	"outpost": "res://assets/sprites/capybara.png",
	"factory": "res://assets/sprites/capybara_factory.png",
	"artillery": "res://assets/sprites/capybara_artillery.png",
	"blockade": "res://assets/sprites/bramble.png",
	"hazard": "res://assets/sprites/mud.png",
}

## Disc art is a white circle of this radius inside a 256px texture.
const DISC_TEX_RADIUS := 120.0


static func texture(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var loaded = load(path)
	return loaded as Texture2D


static func portrait(type_id: String) -> Texture2D:
	var path: String = PORTRAIT.get(type_id, PORTRAIT["outpost"])
	return texture(path)


static func soldier(team: String) -> Texture2D:
	var path: String = SOLDIER.get(team, SOLDIER["player"])
	return texture(path)
