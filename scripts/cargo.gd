class_name Cargo
extends RigidBody3D
## Something to deliver. It's a real physics object: it slides, tips, rolls
## and falls off.
##
## It tracks its CONDITION (100% = perfect). Hard knocks damage it, and the
## delivery pays less for a damaged load. At 0% it's ruined.
##
## How we detect a "hard knock": every physics step we compare the velocity
## with the step before. A big sudden change means it hit something.
## (Gravity alone only changes it by ~0.16 m/s per step.)
##
## Set `type_id` before adding it to the scene to pick what it is.

## Emitted when it hits something. `on_sand` = it landed in the sand.
signal impact(pos: Vector3, speed_change: float, on_sand: bool)
signal smashed

## Every kind of cargo. "fragility" multiplies damage; "melt" loses condition
## per second all by itself; "shape" is "box" or "barrel"; "metal" = kg of
## iron in it (lodestones in the Glass Desert pull on it).
const TYPES := {
	"crate": {
		"name": "Crate", "shape": "box", "size": Vector3(0.5, 0.4, 0.5), "mass": 6.0,
		"fragility": 1.0, "melt": 0.0, "friction": 0.9,
		"color": Color(0.55, 0.36, 0.18), "pay_mult": 1.0,
		"metal": 0.5,
		"desc": "Nothing special. Don't drop it.",
	},
	"eggs": {
		"name": "Egg crate", "shape": "box", "size": Vector3(0.55, 0.25, 0.45), "mass": 3.0,
		"fragility": 3.0, "melt": 0.0, "friction": 0.9,
		"color": Color(0.95, 0.92, 0.82), "pay_mult": 1.7,
		"metal": 0.0,
		"desc": "Very fragile: every bump costs you.",
	},
	"barrel": {
		"name": "Water barrel", "shape": "barrel", "size": Vector3(0.36, 0.5, 0.36), "mass": 10.0,
		"fragility": 0.6, "melt": 0.0, "friction": 0.6,
		"color": Color(0.2, 0.4, 0.75), "pay_mult": 1.3,
		"metal": 3.0,
		"desc": "Tough, but round: if it falls over, it rolls.",
	},
	"engine": {
		"name": "Engine block", "shape": "box", "size": Vector3(0.45, 0.35, 0.4), "mass": 22.0,
		"fragility": 0.3, "melt": 0.0, "friction": 1.0,
		"color": Color(0.35, 0.37, 0.4), "pay_mult": 1.5,
		"metal": 22.0,
		"desc": "Nearly indestructible, but so heavy your truck sinks and struggles.",
	},
	"kit": {
		"name": "Outpost kit", "shape": "box", "size": Vector3(0.6, 0.38, 0.5), "mass": 14.0,
		"fragility": 0.5, "melt": 0.0, "friction": 0.9,
		"color": Color(0.9, 0.5, 0.15), "pay_mult": 1.0,
		"metal": 6.0,
		"desc": "Everything the crew needs to build an outpost. Heavy: thin crust won't hold you.",
	},
	"orb": {
		"name": "Signal orb", "shape": "ball", "size": Vector3(0.34, 0.34, 0.34), "mass": 1.5,
		"fragility": 1.6, "melt": 0.0, "friction": 0.4,
		"color": Color(0.55, 0.85, 1.0), "pay_mult": 2.4,
		"metal": 0.0, "bounce": 0.45,
		"desc": "A glowing orb from the hull. Light and round: it rolls, and in low gravity it bounces like a balloon.",
	},
	"ice": {
		"name": "Ice block", "shape": "box", "size": Vector3(0.45, 0.45, 0.45), "mass": 8.0,
		"fragility": 1.2, "melt": 1.1, "friction": 0.08,
		"color": Color(0.75, 0.9, 1.0), "pay_mult": 1.9,
		"metal": 0.0,
		"desc": "Melts in the sun (about 1% a second) and slides around like crazy.",
	},
}

@export var type_id := "crate"
## Knocks gentler than this (m/s of sudden speed change) do no damage.
@export var damage_threshold := 3.0
## Condition lost per m/s above the threshold (times fragility).
@export var damage_per_ms := 12.0

var condition := 100.0
var type_def: Dictionary
var _last_velocity := Vector3.ZERO
var _band_paint := StandardMaterial3D.new()


func _ready() -> void:
	type_def = TYPES[type_id]
	mass = type_def["mass"]
	var mat := PhysicsMaterial.new()
	mat.friction = type_def["friction"]
	mat.bounce = type_def.get("bounce", 0.05)
	physics_material_override = mat
	# Needed to see what we hit in _integrate_forces.
	contact_monitor = true
	max_contacts_reported = 4

	var size: Vector3 = type_def["size"]
	var body_paint := StandardMaterial3D.new()
	body_paint.albedo_color = type_def["color"]
	if type_id == "ice":
		body_paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		body_paint.albedo_color.a = 0.75
		body_paint.roughness = 0.1
		body_paint.metallic_specular = 0.9
	if type_id == "engine":
		body_paint.metallic = 0.7
		body_paint.roughness = 0.4

	var col := CollisionShape3D.new()
	# (There used to be a plain box/cylinder MeshInstance here too. Since the
	# Blender models arrived it was never shown, or freed: one leaked node per
	# cargo, and a crash on exit now and then. Leak hunting with
	# `godot --verbose` found it: it lists every object still alive at exit.)
	var band := MeshInstance3D.new()
	if type_def["shape"] == "ball":
		var sphere := SphereShape3D.new()
		sphere.radius = size.x * 0.5
		col.shape = sphere
		var bm := CylinderMesh.new()      # the condition band: a ring round its middle
		bm.top_radius = size.x * 0.5 + 0.004
		bm.bottom_radius = size.x * 0.5 + 0.004
		bm.height = size.y * 0.08
		band.mesh = bm
	elif type_def["shape"] == "barrel":
		var cyl_shape := CylinderShape3D.new()
		cyl_shape.radius = size.x * 0.5
		cyl_shape.height = size.y
		col.shape = cyl_shape
		var bm := CylinderMesh.new()
		bm.top_radius = size.x * 0.5 + 0.005
		bm.bottom_radius = size.x * 0.5 + 0.005
		bm.height = size.y * 0.08
		band.mesh = bm
	else:
		var box := BoxShape3D.new()
		box.size = size
		col.shape = box
		var bb := BoxMesh.new()
		bb.size = Vector3(size.x + 0.02, size.y * 0.08, size.z + 0.02)
		band.mesh = bb
	add_child(col)
	# Looks: the Blender model for this cargo (models/<type>.glb). The plain
	# box/cylinder above is only its physics shape.
	add_child(Models.make(type_id))
	# The coloured band shows condition: blue when perfect, red when ruined.
	band.material_override = _band_paint
	add_child(band)
	_update_band()


func _physics_process(delta: float) -> void:
	var melt: float = type_def["melt"]
	if melt > 0.0 and condition > 0.0:
		condition = maxf(condition - melt * delta, 0.0)
		_update_band()
		if condition <= 0.0:
			smashed.emit()


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var v := state.linear_velocity
	var change := (v - _last_velocity).length()
	_last_velocity = v
	# While frozen, the game is moving it (a hawk's talons, the crew lifting
	# it back on). Those jumps aren't crashes. (The hawk test caught this:
	# crates were smashing themselves in mid-air.)
	if freeze:
		return
	if change < 1.2 or state.get_contact_count() == 0:
		return
	var pos := global_position
	var on_sand := false
	for i in state.get_contact_count():
		if state.get_contact_collider_object(i) is SandTile:
			on_sand = true
			pos = state.get_contact_collider_position(i)
	impact.emit(pos, change, on_sand)
	if change > damage_threshold and condition > 0.0:
		var damage: float = (change - damage_threshold) * damage_per_ms * type_def["fragility"]
		condition = maxf(condition - damage, 0.0)
		_update_band()
		if condition <= 0.0:
			smashed.emit()


## Picked up by something that moves it directly (a hawk, the crew lifting it
## back on). It's frozen AND stops colliding: a frozen "kinematic" body acts as
## if it had infinite mass, so dragging it through the truck's bed walls
## launched the whole truck into the sky (the hawk test found that).
func set_carried(on: bool) -> void:
	if on:
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		freeze = true
		collision_layer = 0
		collision_mask = 0
	else:
		collision_layer = 1
		collision_mask = 1
		freeze = false
		reset_impact_tracking()


## Call after teleporting it, so the jump doesn't count as a crash.
func reset_impact_tracking() -> void:
	_last_velocity = linear_velocity


func display_name() -> String:
	return type_def["name"] if type_def else "Crate"


func _update_band() -> void:
	_band_paint.albedo_color = Color(0.85, 0.2, 0.15).lerp(Color(0.2, 0.6, 0.9), condition / 100.0)
