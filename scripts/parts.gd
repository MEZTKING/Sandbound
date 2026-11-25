class_name Parts
extends RefCounted
## Every part you can buy in the garage, and what it does.
##
## This is DATA, not code: adding a new part means adding an entry here. The
## truck (rc_car.gd) reads these numbers when it's built. Most values are
## MULTIPLIERS (1.0 = same as standard), so parts are easy to compare.
##
## METAL (kg of iron and steel) matters in the Glass Desert: lodestones pull
## on it. The truck's frame is 10 kg of metal; motors and some parts add more.
##
## Design rule from the pitch: every part solves one problem and costs you
## something else. Nothing is just "better".

const SLOTS := ["tyres", "motor", "battery", "bed"]

const SLOT_NAMES := {
	"tyres": "Tyres",
	"motor": "Motor",
	"battery": "Battery",
	"bed": "Cargo bed",
}

const CATALOGUE := {
	"tyres": {
		"standard": {
			"name": "Standard tyres", "price": 0,
			"desc": "All-rounders.",
			"radius": 0.32, "width": 0.22, "grip": 2.2,
			"sink": 1.0, "dig": 1.0, "drag": 1.0, "paddles": false,
			"puncture": 1.0, "glass_grip": 0.12,
		},
		"balloon": {
			"name": "Balloon tyres", "price": 60,
			"desc": "Fat and soft: float over soft sand. They can't dig themselves in deeper than ~13 cm, so you never beach. Slidier on turns.",
			"radius": 0.36, "width": 0.34, "grip": 1.8,
			"sink": 0.45, "dig": 0.15, "drag": 0.75, "paddles": false,
			"puncture": 1.8, "glass_grip": 0.17,
		},
		"paddle": {
			"name": "Paddle tyres", "price": 90,
			"desc": "Scoops on the tyres: huge grip and climbing. Spin them and you dig a hole fast.",
			"radius": 0.33, "width": 0.24, "grip": 3.4,
			"sink": 1.0, "dig": 2.2, "drag": 1.1, "paddles": true,
			"puncture": 1.0, "glass_grip": 0.08,
		},
		"solid": {
			"name": "Solid tyres", "price": 85,
			"desc": "Solid rubber: glass shards can't puncture them. Heavy and hard: they sink in soft sand and grip less.",
			"radius": 0.31, "width": 0.22, "grip": 1.9,
			"sink": 1.35, "dig": 0.9, "drag": 1.15, "paddles": false,
			"puncture": 0.0, "glass_grip": 0.14, "mass": 6.0,
		},
	},
	"motor": {
		"standard": {
			"name": "Standard motor", "price": 0,
			"desc": "Does the job.",
			"power": 120.0, "top_speed_drag": 0.0, "drain": 1.0, "soft_sand_power": 1.0,
			"metal": 8.0,
		},
		"torque": {
			"name": "Torque motor", "price": 70,
			"desc": "Pulls out of holes and up dunes. Lower top speed, uses more battery.",
			"power": 175.0, "top_speed_drag": 14.0, "drain": 1.25, "soft_sand_power": 1.0,
			"metal": 12.0,
		},
		"sprint": {
			"name": "Sprint motor", "price": 80,
			"desc": "Fast on firm ground. Bogs down in soft sand, thirsty.",
			"power": 160.0, "top_speed_drag": -6.0, "drain": 1.35, "soft_sand_power": 0.55,
			"metal": 6.0,
		},
	},
	"battery": {
		"standard": {
			"name": "Standard battery", "price": 0,
			"desc": "Enough for nearby jobs.",
			"capacity": 100.0, "mass": 0.0, "solar": 0.0,
		},
		"big": {
			"name": "Big battery", "price": 60,
			"desc": "Almost twice the range. Heavy: you sink a bit more.",
			"capacity": 190.0, "mass": 12.0, "solar": 0.0,
		},
		"solar": {
			"name": "Solar panel", "price": 100,
			"desc": "Standard battery that slowly recharges in the sun, even while driving.",
			"capacity": 100.0, "mass": 3.0, "solar": 0.9,
		},
	},
	"bed": {
		"flat": {
			"name": "Flat bed", "price": 0,
			"desc": "Low walls. Things fall off.",
			"wall": 0.2, "cage": false, "mass": 0.0,
		},
		"tall": {
			"name": "Tall walls", "price": 40,
			"desc": "Higher sides. Cargo still flies out on big jumps.",
			"wall": 0.42, "cage": false, "mass": 3.0,
		},
		"cage": {
			"name": "Cargo cage", "price": 90,
			"desc": "Fully enclosed: nothing gets out. Heavy, and top-heavy.",
			"wall": 0.42, "cage": true, "mass": 8.0,
		},
	},
}

## What a brand-new truck has.
static func default_loadout() -> Dictionary:
	return {"tyres": "standard", "motor": "standard", "battery": "standard", "bed": "flat"}


static func get_part(slot: String, id: String) -> Dictionary:
	return CATALOGUE[slot][id]
