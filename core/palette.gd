class_name Palette
## Echo colours by what the sound touched. Objects tag themselves with
## metadata `echo_kind` (one of Kind) so the EchoRenderer knows how to tint them.

enum Kind { WALL, DOOR, EXIT, PICKUP, WATER, ENEMY }

const COLORS := {
	Kind.WALL: Color("2fd8ff"),
	Kind.DOOR: Color("ffb02e"),
	Kind.EXIT: Color("39ff9c"),
	Kind.PICKUP: Color("ffc85a"),
	Kind.WATER: Color("9b6bff"),
	Kind.ENEMY: Color("ff3355"),
}

const PLAYER := Color("d8f6ff")
const UI_DIM := Color("5d7a8c")


static func color(kind: int) -> Color:
	return COLORS.get(kind, COLORS[Kind.WALL])


static func kind_of(collider: Object) -> int:
	if collider != null and collider.has_meta(&"echo_kind"):
		return int(collider.get_meta(&"echo_kind"))
	return Kind.WALL
