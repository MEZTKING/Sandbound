class_name BuildParts
extends RefCounted
## The parts you BUILD onto the truck in the workshop, and where they can go.
##
## The truck has SOCKETS: fixed mounting points on its sides, front, back,
## cab roof, underside and over the cargo bed. Each part can go in some kinds
## of socket. Where you put things matters, because every part has real mass:
## heavy parts on one side make the truck lean and tip that way, heavy parts
## up high make it top-heavy, heavy parts underneath keep it planted (but
## lower its belly, so it can get beached on bumps).
##
## How a part sits on a socket: its box is (width, height, depth), where
## DEPTH points straight out from the truck's surface. See part_transform().

## Socket id -> where it is on the truck (front of the truck is +Z).
##   pos:    a point on the truck's surface
##   normal: which way is "out" from the surface there
##   group:  side / front / back / roof / under / bed
const SOCKETS := {
	# Left side (-X) and right side (+X), between the wheels.
	"L0": {"pos": Vector3(-0.5, 0.0, -0.22), "normal": Vector3.LEFT, "group": "side"},
	"L1": {"pos": Vector3(-0.5, 0.0, 0.0), "normal": Vector3.LEFT, "group": "side"},
	"L2": {"pos": Vector3(-0.5, 0.0, 0.22), "normal": Vector3.LEFT, "group": "side"},
	"R0": {"pos": Vector3(0.5, 0.0, -0.22), "normal": Vector3.RIGHT, "group": "side"},
	"R1": {"pos": Vector3(0.5, 0.0, 0.0), "normal": Vector3.RIGHT, "group": "side"},
	"R2": {"pos": Vector3(0.5, 0.0, 0.22), "normal": Vector3.RIGHT, "group": "side"},
	# Front (+Z) and back (-Z). The middle ones take a winch or the hitch.
	"F0": {"pos": Vector3(-0.3, 0.0, 0.9), "normal": Vector3.BACK, "group": "front"},
	"F1": {"pos": Vector3(0.0, 0.0, 0.9), "normal": Vector3.BACK, "group": "front", "center": true},
	"F2": {"pos": Vector3(0.3, 0.0, 0.9), "normal": Vector3.BACK, "group": "front"},
	"B0": {"pos": Vector3(-0.3, 0.0, -0.9), "normal": Vector3.FORWARD, "group": "back"},
	"B1": {"pos": Vector3(0.0, 0.0, -0.9), "normal": Vector3.FORWARD, "group": "back", "center": true},
	"B2": {"pos": Vector3(0.3, 0.0, -0.9), "normal": Vector3.FORWARD, "group": "back"},
	# Cab roof, either side of the driver.
	"C0": {"pos": Vector3(-0.24, 0.425, 0.55), "normal": Vector3.UP, "group": "roof"},
	"C1": {"pos": Vector3(0.24, 0.425, 0.55), "normal": Vector3.UP, "group": "roof"},
	# Underneath the chassis.
	"U0": {"pos": Vector3(-0.25, -0.125, 0.35), "normal": Vector3.DOWN, "group": "under"},
	"U1": {"pos": Vector3(0.25, -0.125, 0.35), "normal": Vector3.DOWN, "group": "under"},
	"U2": {"pos": Vector3(-0.25, -0.125, -0.35), "normal": Vector3.DOWN, "group": "under"},
	"U3": {"pos": Vector3(0.25, -0.125, -0.35), "normal": Vector3.DOWN, "group": "under"},
	# Over the cargo bed.
	"N": {"pos": Vector3(0.0, 0.125, -0.4), "normal": Vector3.UP, "group": "bed"},
}

## Every buildable part. "groups" = which sockets it fits; "center_only" =
## only the middle front/back socket. "size" = (width, height, depth).
const CATALOGUE := {
	"ballast": {
		"name": "Ballast weight", "price": 15, "mass": 12.0,
		"size": Vector3(0.2, 0.18, 0.18), "color": Color(0.22, 0.22, 0.24), "metal": 12.0,
		"groups": ["side", "front", "back", "roof", "under"],
		"desc": "12 kg of iron. Low down = harder to flip. On one side = you lean that way.",
	},
	"bumper": {
		"name": "Bumper", "price": 25, "mass": 5.0,
		"size": Vector3(0.32, 0.14, 0.05), "color": Color(0.9, 0.7, 0.1), "metal": 4.0,
		"groups": ["side", "front", "back"],
		"desc": "Softens beetle rams on that side of the truck (35% each, up to 70%).",
	},
	"battery_cell": {
		"name": "Battery cell", "price": 35, "mass": 6.0,
		"size": Vector3(0.2, 0.16, 0.14), "color": Color(0.2, 0.7, 0.3), "metal": 2.0,
		"groups": ["side", "roof", "under"],
		"desc": "+45% range each. Heavy-ish: think about where it goes.",
	},
	"solar_tile": {
		"name": "Solar tile", "price": 40, "mass": 1.5,
		"size": Vector3(0.3, 0.3, 0.02), "color": Color(0.08, 0.12, 0.3),
		"groups": ["roof"],
		"desc": "Recharges the battery a little, all the time, even while driving.",
	},
	"winch": {
		"name": "Winch + sand anchor", "price": 70, "mass": 7.0,
		"size": Vector3(0.22, 0.14, 0.14), "color": Color(0.5, 0.52, 0.55), "metal": 6.0,
		"groups": ["front", "back"], "center_only": true,
		"desc": "Press F: fires an anchor 8 m into the sand and reels you in. Gets you out of holes.",
	},
	"net": {
		"name": "Cargo net", "price": 45, "mass": 1.0,
		"size": Vector3(0.9, 0.9, 0.02), "color": Color(0.85, 0.8, 0.6),
		"groups": ["bed"],
		"desc": "Straps the cargo down (a real joint). Snaps in a hard crash.",
	},
	"headlight": {
		"name": "Headlight", "price": 20, "mass": 0.8,
		"size": Vector3(0.12, 0.08, 0.06), "color": Color(1.0, 0.95, 0.7),
		"groups": ["front", "roof"],
		"desc": "Lights the way at night (switches on at dusk). Uses a little battery.",
	},
	"buzzer": {
		"name": "Buzzer", "price": 40, "mass": 2.0,
		"size": Vector3(0.12, 0.1, 0.08), "color": Color(0.95, 0.85, 0.1), "metal": 1.5,
		"groups": ["side", "front", "back"],
		"desc": "Zaps any scorpion that clamps onto a wheel, within a second.",
	},
	"sandbag": {
		"name": "Sandbag", "price": 8, "mass": 10.0, "metal": 0.0,
		"size": Vector3(0.24, 0.14, 0.18), "color": Color(0.72, 0.62, 0.42),
		"groups": ["side", "front", "back", "roof", "under"],
		"desc": "10 kg of sand in a sack. Ballast with NO metal: lodestones in the Glass Desert ignore it.",
	},
	"spare": {
		"name": "Spare wheel", "price": 30, "mass": 4.0, "metal": 1.0,
		"size": Vector3(0.3, 0.3, 0.12), "color": Color(0.15, 0.15, 0.16),
		"groups": ["back", "roof"],
		"desc": "Glass shards puncture tyres. Press P to swap a flat for this spare (the crew restocks it at any base).",
	},
	"gyro": {
		"name": "Gyro stabiliser", "price": 90, "mass": 5.0, "metal": 4.0,
		"size": Vector3(0.2, 0.16, 0.2), "color": Color(0.3, 0.6, 0.9),
		"groups": ["roof", "under"],
		"desc": "A spinning flywheel that pushes the truck back upright. Saves you from flips (low gravity, drift rays). Uses battery while it works.",
	},
	"wing": {
		"name": "Downforce wing", "price": 50, "mass": 2.0, "metal": 1.0,
		"size": Vector3(0.56, 0.12, 0.1), "color": Color(0.9, 0.9, 0.92),
		"groups": ["roof", "back"],
		"desc": "Air pushes it down, harder the faster you go: more grip at speed, especially in the Drift's low gravity. Adds a little drag.",
	},
	"hitch": {
		"name": "Hitch + trailer", "price": 120, "mass": 3.0,
		"size": Vector3(0.08, 0.08, 0.2), "color": Color(0.3, 0.3, 0.32), "metal": 3.0,
		"groups": ["back"], "center_only": true,
		"desc": "Tows a trailer on a swivelling joint. Cargo rides on the trailer, low and safe, but it drags in soft sand.",
	},
}


static func fits(part_id: String, socket_id: String) -> bool:
	var part: Dictionary = CATALOGUE[part_id]
	var socket: Dictionary = SOCKETS[socket_id]
	if not socket["group"] in part["groups"]:
		return false
	if part.get("center_only", false) and not socket.get("center", false):
		return false
	return true


## Where a part sits (in the truck's own space) when bolted to a socket:
## its local +Z points out of the surface, and it sits just outside it.
static func part_transform(part_id: String, socket_id: String) -> Transform3D:
	var socket: Dictionary = SOCKETS[socket_id]
	var n: Vector3 = socket["normal"]
	var size: Vector3 = CATALOGUE[part_id]["size"]
	# Build a basis whose Z is the surface normal.
	var hint := Vector3.UP if absf(n.y) < 0.9 else Vector3.FORWARD
	var x := hint.cross(n).normalized()
	var y := n.cross(x)
	var basis := Basis(x, y, n)
	return Transform3D(basis, socket["pos"] + n * size.z * 0.5)
