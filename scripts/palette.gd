extends RefCounted
class_name Palette

const PLAYER := Color("2D7DFF")
const ENEMY := Color("FF4D55")
const NEUTRAL := Color("8E97A8")
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
