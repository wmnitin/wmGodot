extends RefCounted
class_name Palette

const PLAYER := Color("2F7BF5")
const ENEMY := Color("E8433A")
const NEUTRAL := Color("C9CCD1")
const WORLD := Color("6FA37A")
const INK := Color("1C2A44")
const CREAM := Color("FFF8EE")
const GOLD := Color("FFD15C")
const DEEP := Color("17345C")


static func team(owner: String) -> Color:
	match owner:
		"player":
			return PLAYER
		"enemy":
			return ENEMY
		"neutral":
			return NEUTRAL
		_:
			return WORLD


static func team_name(owner: String) -> String:
	match owner:
		"player":
			return "You"
		"enemy":
			return "Red"
		"neutral":
			return "Open"
		_:
			return "Wild"
