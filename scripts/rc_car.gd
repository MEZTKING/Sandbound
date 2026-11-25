class_name RCCar
extends VehicleBody3D
## A small remote-controlled truck that sinks into and digs up the sand.
##
## Godot's VehicleBody3D is a "raycast vehicle": each wheel is a ray pointing
## down with a spring on it. That's how most driving games work. Our job is to
## add what the sand does:
##   1. Wheels PRESS ruts into the sand (more when heavily loaded).
##   2. Wheels that SPIN (slip) DIG, so flooring it in soft sand gets you stuck.
##   3. Sand adds DRAG, so driving through it is slower than on packed ruts.
##   4. Soft dune sand is worse for all of that; firm hardpan is better.
##
## The truck is BUILT FROM PARTS (see parts.gd): set `parts` before adding it
## to the scene. To change parts, the game builds a new truck.
## In this car, the FRONT is +Z.

## Which part is in each slot, e.g. {"tyres": "balloon", ...}.
var parts: Dictionary = Parts.default_loadout()
## What's bolted to each socket, e.g. {"L0": "ballast", "F1": "winch"}.
## See build_parts.gd. Set before adding the truck to the scene.
var build: Dictionary = {}
## Paint job and tuning (set before adding the truck to the scene).
var paint: Dictionary = PaintJob.default_paint()
# Visual pieces, so a newly fitted part can "pop" into place.
var _body_model: Node3D
var _bed_model: Node3D
var _tyre_models: Array[Node3D] = []
## Short gearing: the motor runs out of revs above this speed (m/s).
var governor_speed := INF
var _part_models := {}      # socket id -> model
var tuning: Dictionary = Tuning.defaults()

@export var brake_power: float = 3.0
@export var max_steer: float = 0.55         ## Radians.
@export var steer_speed: float = 3.0

@export_group("Sand interaction")
@export var press_rate: float = 0.25        ## m/s a rolling wheel sinks in.
@export var rut_depth: float = 0.07         ## m: how deep a normal rut gets.
## m/s extra digging at full wheel slip. (Was 0.9: so fast that every tyre
## hit bottom in half a second and balloon tyres were no better than paddles.)
@export var dig_rate: float = 0.3
@export var dig_depth: float = 0.35         ## m: how deep spinning wheels can dig.
@export var sand_drag: float = 26.0         ## Resistance from ploughing through sand.
@export var sink_drag: float = 25.0         ## Extra drag per metre the wheels have sunk in.

@export_group("Battery")
@export var drain_per_second: float = 1.5   ## % of a standard battery at full throttle.
@export var limp_power: float = 0.15        ## Fraction of power left when the battery is flat.

# Stats that come from the parts (filled in by _apply_parts).
var engine_power := 120.0
var wheel_radius := 0.32
var wheel_width := 0.22
var wheel_grip := 2.2
var sink_mult := 1.0
var dig_mult := 1.0
var drag_mult := 1.0
var top_speed_drag := 0.0
var drain_mult := 1.0
var soft_sand_power := 1.0
var battery_capacity := 100.0
var battery := 100.0
var solar_rate := 0.0

# What the build gives us (filled in by _add_build_parts).
var bumpers := {}                           ## surface normal -> how many bumpers face that way
var winch_socket := ""                      ## "F1" or "B1" if there's a winch
var has_net := false
var has_hitch := false
var headlights: Array[SpotLight3D] = []
var has_buzzer := false
var _pinned := {}                           ## wheel index -> true (a scorpion has it)
var lights_on := false
## 0..1, set by the game from the time of day. Solar only works in daylight.
var daylight := 1.0
@export var headlight_drain: float = 0.25   ## % battery per second per light.

@export_group("Winch")
@export var winch_force: float = 1100.0     ## Newtons of pull.
@export var winch_range: float = 8.0        ## How far the anchor flies.
@export var winch_drain: float = 3.0        ## % battery per second while reeling.
var winch_anchor := Vector3.INF             ## Where the anchor is stuck (INF = not out).
var _cable: MeshInstance3D

var terrain: SandTerrain
var wheels: Array[VehicleWheel3D] = []
var cargo_anchor: Node3D                    ## Where cargo sits on the bed.
var _steer := 0.0
var _spin_amount := 0.0                     ## 0..1, shown on the HUD.
var _sprays: Array[GPUParticles3D] = []
var _last_stamp: Array[Vector3] = []        ## Where each wheel last stamped a tread.
var _spin_stamp_timer := 0.0
var _hardness_under := 0.5                  ## How firm the ground is under us (HUD).
var _throttle := 0.0                        ## Smoothed throttle (see _physics_process).

@export_group("Salt crust")
## Newtons per wheel that full-strength (1.0) crust can hold. Thin crust is
## weaker in proportion. A plain 60 kg truck puts ~150 N on each wheel, so it
## cracks crust weaker than 0.5 (the grey kind) and rides on thick white crust.
@export var crust_strength_n: float = 300.0
## Extra weight on board (cargo), set by the game. Heavier = more cracking.
var extra_load := 0.0
## Emitted when a wheel breaks through the crust (the game plays a sound).
signal crust_cracked(where: Vector3)

@export_group("Glass Desert")
## Seconds of fast driving over shard rubble before a tyre punctures (each
## wheel counts on its own; driving slowly counts much less).
@export var shard_seconds: float = 0.6
## Below this speed, shards barely hurt (creep across rubble!).
@export var shard_safe_speed: float = 0.8
signal punctured(wheel_index: int)
var metal_mass := 10.0                      ## kg of iron and steel (lodestones pull on it)
var glass_grip := 0.3                       ## grip on glass, as a fraction of normal
var puncture_mult := 1.0                    ## 0 = can't puncture
var flats: Array[bool] = []                 ## which wheels have a puncture
var spares := 0                             ## spare wheels on board (P fits one)
var _shard_exposure := PackedFloat32Array()
var _glass_under := 0.0                     ## how much of the truck is on glass (HUD)

@export_group("The Drift")
## Extra depth (m) a slow wheel sinks into a flowing sand river.
@export var river_sink: float = 0.22
## Torque (N m) each gyro uses to push the truck upright.
@export var gyro_torque: float = 200.0
## Downforce per wing: newtons per (m/s) squared.
@export var wing_downforce: float = 3.0
var gyros := 0
var wings := 0
var _flow_under := 0.0                      ## how much of the truck is in a river (HUD)
var _gyro_working := 0.0                    ## 0..1, for the HUD and battery
var _stall_time := 0.0                      ## How long we've been pushing without moving.

## Keyboard throttle is all-or-nothing, so we ease it in like an RC trigger.
## (Slamming full power on from a standstill dug a hole every time you set off.)
@export var throttle_rise: float = 2.0      ## Per second: 0 to full in half a second.
## Wheels only count as "spinning in place" (and dig) after pushing this long
## without getting anywhere.
@export var stall_grace: float = 0.5

## Distance between tread bars. Stamps are placed exactly this far apart so
## the tread pattern lines up into one continuous track.
const TREAD_PITCH := 0.064


func _ready() -> void:
	_apply_parts()
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.25, 0)    # low = harder to flip
	_build_body()
	_add_build_parts()
	for x in [-0.62, 0.62]:
		for z in [0.68, -0.68]:
			_add_wheel(Vector3(x, -0.05, z), z > 0.0)
	PaintJob.apply(self, paint)
	# One dust spray per wheel, attached to the body (not the spinning wheel).
	for w in wheels:
		var spray := SandDust.make_wheel_spray()
		spray.position = w.position + Vector3(0, -wheel_radius - 0.05, -0.1)
		add_child(spray)
		_sprays.append(spray)
		_last_stamp.append(Vector3.INF)
		flats.append(false)
		_shard_exposure.append(0.0)


## Read the stats of the fitted parts.
func _apply_parts() -> void:
	var t := Parts.get_part("tyres", parts["tyres"])
	var m := Parts.get_part("motor", parts["motor"])
	var b := Parts.get_part("battery", parts["battery"])
	var bed := Parts.get_part("bed", parts["bed"])
	wheel_radius = t["radius"]
	wheel_width = t["width"]
	wheel_grip = t["grip"]
	sink_mult = t["sink"]
	glass_grip = t.get("glass_grip", 0.3)
	puncture_mult = t.get("puncture", 1.0)
	dig_mult = t["dig"]
	drag_mult = t["drag"]
	engine_power = m["power"]
	top_speed_drag = m["top_speed_drag"]
	# Tuning (garage sliders).
	var press := Tuning.pressure_effects(Tuning.value(tuning, "pressure"))
	wheel_grip *= press.x
	sink_mult *= press.y
	drag_mult *= press.z
	var gear := Tuning.value(tuning, "gearing")
	engine_power *= gear                 # more pull...
	# ...but a lower top speed (and tall gears the other way round). Two
	# tries that the customisation test measured and rejected: a fixed extra
	# drag (low gears ended up FASTER) and drag x gear squared (it killed the
	# extra pull too). What works: tall gears (< 1) get less drag, so they
	# run faster; short gears (> 1) keep their pull but the motor runs out of
	# revs at a lower speed (a "governor", like a real RC speed controller).
	if gear < 1.0:
		drag_mult *= gear * gear
	else:
		governor_speed = 7.4 / gear
	dig_mult *= gear                     # and the wheels spin up more easily
	drain_mult = m["drain"]
	soft_sand_power = m["soft_sand_power"]
	battery_capacity = b["capacity"]
	battery = battery_capacity
	solar_rate = b["solar"]
	mass = 60.0 + b["mass"] + bed["mass"] + t.get("mass", 0.0)
	metal_mass = 10.0 + m.get("metal", 8.0) + (6.0 if bed["cage"] else 0.0)
	# Heavier trucks sink more.
	sink_mult *= mass / 60.0


func _build_body() -> void:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.85, 0.25, 0.15)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.15, 0.15, 0.17)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.55, 0.57, 0.6)
	metal.metallic = 0.8
	metal.roughness = 0.35

	# Chassis: one box for physics, one for looks.
	# Physics: plain boxes. Looks: the Blender model (models/truck_body.glb).
	_add_box(Vector3(1.0, 0.25, 1.8), Vector3(0, 0, 0), null, true)
	_body_model = Models.make("truck_body")
	add_child(_body_model)

	# Walls around the cargo bed (back half).
	var bed := Parts.get_part("bed", parts["bed"])
	var wall_h: float = bed["wall"]
	var bed_y := 0.125 + wall_h * 0.5
	for spec in [
		[Vector3(1.0, wall_h, 0.05), Vector3(0, bed_y, -0.875)],   # back
		[Vector3(0.05, wall_h, 1.0), Vector3(-0.475, bed_y, -0.4)], # left
		[Vector3(0.05, wall_h, 1.0), Vector3(0.475, bed_y, -0.4)],  # right
	]:
		_add_box(spec[0], spec[1], null, true)       # physics only...
	# ...the looks: the Blender model (red walls, a rail on top, ribs).
	_bed_model = Models.make("bed_high" if wall_h > 0.3 else "bed_low")
	add_child(_bed_model)
	if bed["cage"]:
		# Bars on top and a front wall: a closed box the cargo can't escape.
		var top := 0.125 + wall_h + 0.3
		_add_box(Vector3(1.0, 0.03, 1.0), Vector3(0, top, -0.4), null, true)   # invisible roof...
		for z in [-0.85, -0.6, -0.35, -0.1]:
			_add_box(Vector3(1.0, 0.03, 0.03), Vector3(0, top, z), metal, false)  # ...that looks like bars
		for x in [-0.475, 0.475]:
			for z in [-0.875, 0.075]:
				_add_box(Vector3(0.04, top - 0.125, 0.04), Vector3(x, 0.125 + (top - 0.125) * 0.5, z), metal, false)
		_add_box(Vector3(1.0, top - 0.125, 0.04), Vector3(0, 0.125 + (top - 0.125) * 0.5, 0.1), metal, true)

	# Cab at the front, with the tiny driver standing on top.
	_add_box(Vector3(0.8, 0.3, 0.5), Vector3(0, 0.275, 0.55), null, true)
	var driver := TinyFigure.make(Color(0.2, 0.5, 0.95), 0.32)
	driver.position = Vector3(0, 0.425, 0.6)
	add_child(driver)

	# Battery: a box under the cab. Big battery = big box. Solar = panel on the cab.
	var bat := Parts.get_part("battery", parts["battery"])
	var cell := StandardMaterial3D.new()
	cell.albedo_color = Color(0.2, 0.7, 0.3)
	_add_box(Vector3(0.5 if bat["capacity"] > 100.0 else 0.3, 0.12, 0.3), Vector3(0, 0.185, 0.0), cell, false)
	if bat["solar"] > 0.0:
		var panel := StandardMaterial3D.new()
		panel.albedo_color = Color(0.08, 0.12, 0.3)
		panel.metallic = 0.6
		panel.roughness = 0.2
		_add_box(Vector3(0.78, 0.02, 0.36), Vector3(0, 0.435, 0.5), panel, false)

	cargo_anchor = Node3D.new()
	cargo_anchor.position = Vector3(0, 0.33, -0.4)
	add_child(cargo_anchor)


## Bolt on every part from `build`. Each part's mass sits where the part is,
## so the centre of mass moves: that's what makes lopsided builds lean.
func _add_build_parts() -> void:
	var total_mass := mass
	var weighted := center_of_mass * mass   # sum of (mass x position)
	var bed_wall: float = Parts.get_part("bed", parts["bed"])["wall"]
	for socket_id in build:
		var part_id: String = build[socket_id]
		if not BuildParts.CATALOGUE.has(part_id) or not BuildParts.SOCKETS.has(socket_id) \
				or not BuildParts.fits(part_id, socket_id):
			continue   # (an old or hand-edited build file with a mistake: skip it)
		var part: Dictionary = BuildParts.CATALOGUE[part_id]
		var xform := BuildParts.part_transform(part_id, socket_id)
		if part_id == "net":
			xform.origin.y = 0.125 + bed_wall + 0.02   # stretched over the top of the walls
		var size: Vector3 = part["size"]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = part["color"]
		match part_id:
			"ballast":
				mat.metallic = 0.6
				mat.roughness = 0.5
			"solar_tile":
				mat.metallic = 0.6
				mat.roughness = 0.2
			"net":
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color.a = 0.0
		if part_id != "net":
			var model := _add_part_box(size, xform, mat, part_id)
			if model:
				_part_models[socket_id] = model
		match part_id:
			"bumper":
				var n: Vector3 = BuildParts.SOCKETS[socket_id]["normal"]
				bumpers[n] = bumpers.get(n, 0) + 1
			"battery_cell":
				battery_capacity += 45.0
				battery += 45.0
			"solar_tile":
				solar_rate += 0.35
			"winch":
				winch_socket = socket_id
			"net":
				has_net = true
				_add_net_visual(xform)
			"hitch":
				has_hitch = true
			"headlight":
				_add_headlight(xform, socket_id)
			"buzzer":
				has_buzzer = true
			"spare":
				spares += 1
			"gyro":
				gyros += 1
			"wing":
				wings += 1
		total_mass += part["mass"]
		metal_mass += part.get("metal", 0.0)
		weighted += xform.origin * part["mass"]
	mass = total_mass
	center_of_mass = weighted / total_mass


## Part boxes are rotated to face out from the truck, so they need a full
## transform (not just a position). Physics: a plain box. Looks: the Blender
## model models/part_<id>.glb (or a coloured box if there isn't one).
func _add_part_box(size: Vector3, xform: Transform3D, mat: Material, part_id := "") -> Node3D:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.transform = xform
	add_child(col)
	if ResourceLoader.exists("res://models/part_%s.glb" % part_id):
		var model := Models.make("part_" + part_id)
		model.transform = xform
		add_child(model)
		return model
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.transform = xform
	mi.material_override = mat
	add_child(mi)
	return mi


func _add_net_visual(xform: Transform3D) -> void:
	# Criss-crossed straps over the bed (looks only; the real strap is a joint).
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.55, 0.15)
	for k in 5:
		var t := -0.4 + k * 0.2
		for along_x in [true, false]:
			var strap := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.92, 0.015, 0.025) if along_x else Vector3(0.025, 0.015, 0.92)
			strap.mesh = bm
			strap.material_override = m
			strap.position = xform.origin + (Vector3(0, 0, t) if along_x else Vector3(t, 0, 0))
			add_child(strap)


func _add_headlight(xform: Transform3D, socket_id: String) -> void:
	var spot := SpotLight3D.new()
	spot.position = xform.origin + xform.basis.z * 0.04
	# A spotlight shines along its -Z. Point it ahead and a little down
	# (roof lights too, not at the sky).
	var aim := Vector3(0, -0.12, 1).normalized()
	if BuildParts.SOCKETS[socket_id]["group"] == "roof":
		aim = Vector3(0, -0.3, 1).normalized()
	spot.basis = Basis.looking_at(aim)
	spot.spot_range = 18.0
	spot.spot_angle = 30.0
	spot.light_energy = 4.0
	spot.light_color = Color(1.0, 0.95, 0.8)
	spot.shadow_enabled = headlights.is_empty()   # only the first one: shadows cost
	spot.visible = false
	add_child(spot)
	headlights.append(spot)
	# The lamp itself glows when on.
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1, 0.95, 0.7)
	glow.emission_enabled = true
	glow.emission = Color(1, 0.9, 0.6)
	glow.emission_energy_multiplier = 0.0
	spot.set_meta("glow", glow)
	var lens := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.1, 0.06, 0.01)
	lens.mesh = bm
	lens.transform = xform * Transform3D(Basis(), Vector3(0, 0, 0.035))
	lens.material_override = glow
	add_child(lens)


## A scorpion grabs (or lets go of) a wheel.
func pin_wheel(wi: int, on: bool) -> void:
	if wi < 0 or wi >= wheels.size():
		return
	if on:
		_pinned[wi] = true
	else:
		_pinned.erase(wi)
		wheels[wi].brake = brake


func is_pinned() -> bool:
	return not _pinned.is_empty()


func set_lights(on: bool) -> void:
	lights_on = on and not headlights.is_empty()
	for spot in headlights:
		spot.visible = lights_on
		(spot.get_meta("glow") as StandardMaterial3D).emission_energy_multiplier = 3.0 if lights_on else 0.0


## Where a trailer's tow-bar attaches (world space).
func get_hitch_point() -> Vector3:
	var xform := BuildParts.part_transform("hitch", "B1")
	return to_global(xform.origin + xform.basis.z * 0.12)


## How much a bumper softens a hit that shoves the truck in `push_dir`
## (world space). 0 = no help, 0.7 = 70% softer.
func ram_protection(push_dir: Vector3) -> float:
	# The face that gets hit is the one facing AGAINST the push.
	var local_push := (global_basis.inverse() * push_dir).normalized()
	var best := 0.0
	for n in bumpers:
		if n.dot(-local_push) > 0.6:
			best = maxf(best, minf(bumpers[n] * 0.35, 0.7))
	return best


## F: fire the anchor (or reel it back in if it's out).
func toggle_winch() -> String:
	if winch_socket == "":
		return "No winch fitted (build one in the workshop)."
	if winch_anchor != Vector3.INF:
		release_winch()
		return "Winch released."
	# Fire it straight out the way the winch faces, into the sand 8 m away.
	var socket: Dictionary = BuildParts.SOCKETS[winch_socket]
	var out := global_basis * Vector3(socket["normal"])
	out.y = 0.0
	out = out.normalized()
	var p := global_position + out * winch_range
	winch_anchor = Vector3(p.x, terrain.get_height(p.x, p.z), p.z)
	terrain.press(winch_anchor, 0.12, 0.05, 0.05)   # the stake's little crater
	return "Anchor out! Reeling in... (F to let go)"


func release_winch() -> void:
	winch_anchor = Vector3.INF
	if _cable:
		_cable.visible = false


func _winch_point() -> Vector3:
	var xform := BuildParts.part_transform("winch", winch_socket)
	return to_global(xform.origin + xform.basis.z * 0.08)


func _update_winch(delta: float) -> void:
	if winch_anchor == Vector3.INF:
		return
	var from := _winch_point()
	var to := winch_anchor - from
	if to.length() < 1.2 or battery <= 0.0:
		release_winch()
		return
	# Pull from where the winch is bolted (so it also turns the truck).
	apply_force(to.normalized() * winch_force, from - global_position)
	battery = maxf(battery - winch_drain * delta, 0.0)
	_draw_cable(from, winch_anchor)


func _draw_cable(a: Vector3, b: Vector3) -> void:
	if _cable == null:
		_cable = MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.008
		cyl.bottom_radius = 0.008
		cyl.height = 1.0
		cyl.radial_segments = 6
		_cable.mesh = cyl
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.1, 0.1, 0.1)
		_cable.material_override = m
		_cable.top_level = true
		_cable.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(_cable)
	_cable.visible = true
	var mid := (a + b) * 0.5
	var dir := (b - a)
	# A cylinder points along Y: stretch it to the cable's length and aim it.
	var y := dir.normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	_cable.global_transform = Transform3D(Basis(x, y * dir.length(), z), mid)


## A box: `solid` adds a collider, `mat` (if not null) adds a visible mesh.
func _add_box(size: Vector3, pos: Vector3, mat: Material, solid: bool) -> void:
	if solid:
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		col.shape = box
		col.position = pos
		add_child(col)
	if mat:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.position = pos
		mi.material_override = mat
		add_child(mi)


func _add_wheel(pos: Vector3, is_front: bool) -> void:
	var w := VehicleWheel3D.new()
	# Wider tyres sit further out so they don't hit the body.
	w.position = pos + Vector3(signf(pos.x) * (wheel_width - 0.22) * 0.5, 0, 0)
	w.wheel_radius = wheel_radius
	w.wheel_rest_length = Tuning.value(tuning, "ride_height")
	w.suspension_travel = 0.2
	w.suspension_stiffness = Tuning.value(tuning, "stiffness")   # (Godot multiplies these by the car's mass)
	w.suspension_max_force = 6000.0
	w.damping_compression = 2.0
	w.damping_relaxation = 2.6
	w.wheel_friction_slip = wheel_grip
	w.wheel_roll_influence = 0.3      # < 1 makes rollovers less likely
	w.use_as_steering = is_front
	w.use_as_traction = true          # 4x4
	add_child(w)
	wheels.append(w)

	# The tyre model (Blender: models/tyre_*.glb). It's a child of the wheel,
	# so Godot spins and steers it for us.
	var tyre := Models.make("tyre_" + parts["tyres"])
	w.add_child(tyre)
	_tyre_models.append(tyre)


## Throttle -1..1, steer -1..1 (+ = left), brake 0..1. Called by the player
## controller each physics tick. Kept separate from input so AI or a test
## script can drive the car too.
var throttle_input := 0.0
var steer_input := 0.0
var brake_input := 0.0


func _physics_process(delta: float) -> void:
	# Ease the throttle up; let go (or reverse direction) instantly.
	var rising := absf(throttle_input) > absf(_throttle) and signf(throttle_input) == signf(_throttle)
	if _throttle == 0.0 and throttle_input != 0.0:
		rising = true
	_throttle = move_toward(_throttle, throttle_input, (throttle_rise if rising else 8.0) * delta)
	_steer = move_toward(_steer, steer_input * max_steer, steer_speed * delta)
	steering = _steer
	_update_battery(delta)
	# Godot ignores the brake while any engine force is applied, so braking
	# cuts the throttle.
	if brake_input > 0.0:
		engine_force = 0.0
	else:
		var power := engine_power
		if battery <= 0.0:
			power *= limp_power   # flat battery: crawl home
		# Some motors struggle in soft sand.
		power *= lerpf(soft_sand_power, 1.0, _hardness_under)
		# Out of revs (short gearing): the push fades over the last 15%.
		var fwd_speed := absf(linear_velocity.dot(global_basis.z))
		if fwd_speed > governor_speed * 0.85:
			power *= clampf((governor_speed - fwd_speed) / (governor_speed * 0.15), 0.0, 1.0)
		engine_force = _throttle * power
	brake = brake_input * brake_power
	# Drag brake, like a real RC motor: off the throttle, the motor resists a
	# little, and nearly stopped it holds firm (so a parked truck doesn't roll
	# away in the wind or down a dune).
	if absf(throttle_input) < 0.05 and brake_input == 0.0:
		brake = brake_power * (0.8 if linear_velocity.length() < 0.6 else 0.3)
	# A scorpion is clamped on: that wheel is locked solid. (This must come
	# AFTER setting `brake`, which sets every wheel's brake.)
	for wi in _pinned:
		wheels[wi].brake = 40.0
		wheels[wi].engine_force = 0.0
	_interact_with_sand(delta)
	_update_winch(delta)
	_update_gyro_and_wing(delta)


func _update_battery(delta: float) -> void:
	# Capacity is in "% of a standard battery", so a big battery lasts longer.
	battery -= absf(_throttle) * drain_per_second * drain_mult * delta
	battery += solar_rate * daylight * delta
	if lights_on:
		battery -= headlight_drain * headlights.size() * delta
	battery = clampf(battery, 0.0, battery_capacity)


## Charge the battery (the base does this).
func recharge(amount: float) -> void:
	battery = minf(battery + amount, battery_capacity)


func get_battery_percent() -> float:
	return battery / battery_capacity * 100.0


func _interact_with_sand(delta: float) -> void:
	if terrain == null:
		return
	var touching := 0
	var spin_total := 0.0
	var sink_total := 0.0
	var hard_total := 0.0
	var glass_total := 0.0
	var flow_total := 0.0
	var ground_speed := linear_velocity.length()
	var forward_speed := linear_velocity.dot(global_basis.z)
	_spin_stamp_timer -= delta
	# Pushing hard but not moving, for longer than the grace time = really stuck.
	if absf(_throttle) > 0.3 and ground_speed < 0.5:
		_stall_time += delta
	else:
		_stall_time = 0.0
	var stuck := clampf((_stall_time - stall_grace) / 0.5, 0.0, 1.0)
	for wi in wheels.size():
		var w := wheels[wi]
		if not w.is_in_contact():
			_sprays[wi].amount_ratio = 0.0
			_last_stamp[wi] = Vector3.INF
			continue
		touching += 1
		# Wheel slip. Godot's raycast wheels don't really spin freely, so we
		# fake it: lots of throttle while barely moving = the wheels are
		# spinning in place. Plus Godot's own skid info (1 = grip, 0 = sliding).
		var slip := clampf(1.0 - w.get_skidinfo(), 0.0, 1.0)
		slip = maxf(slip, absf(_throttle) * stuck)
		spin_total += slip

		var contact := w.global_position - global_basis.y * wheel_radius
		if w.has_method("get_contact_point"):
			contact = w.get_contact_point()
		# Soft sand (hardness 0) swallows wheels; firm hardpan (1) barely marks.
		_check_crust(contact, ground_speed)
		var hard := terrain.get_hardness(contact.x, contact.z)
		var g := terrain.get_glass(contact.x, contact.z)
		var on_glass := g > SandTile.GLASS_SHEET
		hard_total += hard
		var softness := lerpf(1.5, 0.2, hard)
		w.wheel_friction_slip = wheel_grip * lerpf(0.9, 1.3, hard)
		if on_glass:
			# Smooth glass: tyres skate. Brake early, steer gently.
			w.wheel_friction_slip = wheel_grip * glass_grip
			glass_total += 1.0
		elif g > 0.25:
			_check_shards(wi, ground_speed, delta)
		if flats[wi]:
			w.wheel_friction_slip *= 0.55   # a flat tyre squirms
		var amount := (press_rate * sink_mult + slip * dig_rate * dig_mult) * softness * delta
		var max_depth := (rut_depth * sink_mult + slip * dig_depth * dig_mult) * softness
		# Flowing sand (Ring 3) swallows slow wheels; going fast you skim.
		var fl := terrain.get_flow(contact.x, contact.z)
		if fl > 0.05:
			var slow := 1.0 - clampf(ground_speed / 4.0, 0.0, 1.0)
			amount += fl * slow * 0.8 * sink_mult * delta
			max_depth += fl * slow * river_sink * sink_mult
			flow_total += fl
			w.wheel_friction_slip *= 1.0 - fl * 0.6   # the sand moves under the tyre
		terrain.press(contact, wheel_radius * 0.75 * (wheel_width / 0.22), amount, max_depth)
		sink_total += terrain.get_sink(contact.x, contact.z)
		if not on_glass:
			_stamp_tread(wi, contact, slip, hard)
		else:
			_last_stamp[wi] = Vector3.INF

		# Dust: more with speed, lots more when the wheels spin. Less on hardpan.
		var spray := _sprays[wi]
		spray.amount_ratio = (clampf(ground_speed / 7.0, 0.0, 1.0) * 0.5 + slip * 0.8) * lerpf(1.0, 0.35, hard)
		# Spray goes out behind the wheel, whichever way it's turning.
		var pm := spray.process_material as ParticleProcessMaterial
		pm.direction.z = -1.0 if forward_speed >= -0.2 else 1.0

	_spin_amount = spin_total / maxf(touching, 1)
	if touching > 0:
		_hardness_under = hard_total / touching
		_glass_under = glass_total / touching
		_flow_under = flow_total / touching

	# Sand drag: ploughing through sand slows you down, and the deeper the
	# wheels have sunk the harder it gets. This is what makes you "stuck".
	if touching > 0:
		var v := linear_velocity
		v.y = 0.0
		var sink := sink_total / touching
		var ground := lerpf(1.3, 0.55, _hardness_under)
		var drag := (sand_drag * drag_mult * ground + top_speed_drag) * (1.0 + sink * sink_drag)
		drag *= 1.0 - _glass_under * 0.6           # glass: almost nothing to plough through
		drag += _flat_count() * 8.0                # flat tyres drag
		drag += _flow_under * 18.0 * sink_mult     # wading through a river
		apply_central_force(-v * drag * (float(touching) / wheels.size()))


## Salt crust: does this wheel's share of the weight break it?
## Going fast helps a little: each bit of crust only carries you briefly.
func _check_crust(contact: Vector3, speed: float) -> void:
	var c := terrain.get_crust(contact.x, contact.z)
	if c <= 0.02:
		return
	var load_n := (mass + extra_load) * 9.8 / wheels.size()
	load_n *= lerpf(1.0, 0.75, clampf(speed / 6.0, 0.0, 1.0))
	if load_n > c * crust_strength_n:
		if terrain.break_crust(contact, wheel_radius * 1.4, 0.07):
			crust_cracked.emit(contact)


## Glass shards: fast driving over rubble builds up "exposure" on a wheel
## until the tyre punctures. Creeping over it is much safer.
func _check_shards(wi: int, speed: float, delta: float) -> void:
	if puncture_mult <= 0.0 or flats[wi]:
		return
	var danger := clampf((speed - shard_safe_speed) / 2.2, 0.0, 1.0) * 0.95 + 0.05 * clampf(speed, 0.0, 1.0)
	_shard_exposure[wi] += danger * puncture_mult * delta / shard_seconds
	if _shard_exposure[wi] >= 1.0:
		puncture(wi)


## Pop a tyre: the wheel gets smaller (that corner drops) and grips less.
func puncture(wi: int) -> void:
	if flats[wi]:
		return
	flats[wi] = true
	_shard_exposure[wi] = 0.0
	wheels[wi].wheel_radius = wheel_radius * 0.72
	for c in wheels[wi].get_children():
		if c is Node3D:
			(c as Node3D).scale = Vector3(1.0, 0.72, 0.72)   # squashed (the tyre's axle is X)
	punctured.emit(wi)


func _flat_count() -> int:
	var n := 0
	for f in flats:
		if f:
			n += 1
	return n


func flat_count() -> int:
	return _flat_count()


## Fix every flat (the crew at a base). Returns how many were fixed.
func repair_all() -> int:
	var n := _flat_count()
	for wi in wheels.size():
		flats[wi] = false
		_shard_exposure[wi] = 0.0
		wheels[wi].wheel_radius = wheel_radius
		for c in wheels[wi].get_children():
			if c is Node3D:
				(c as Node3D).scale = Vector3.ONE
	return n


## P: swap one flat tyre for a spare.
func use_spare() -> String:
	if _flat_count() == 0:
		return "No flat tyres."
	if spares <= 0:
		return "No spare wheel! Build one in the workshop (or crawl to a base)."
	for wi in wheels.size():
		if flats[wi]:
			flats[wi] = false
			_shard_exposure[wi] = 0.0
			wheels[wi].wheel_radius = wheel_radius
			for c in wheels[wi].get_children():
				if c is Node3D:
					(c as Node3D).scale = Vector3.ONE
			spares -= 1
			return "Spare fitted. %d spare%s left." % [spares, "" if spares == 1 else "s"]
	return ""


## Gyro: torque that turns the truck back upright (only tipping, not
## steering). Wing: downforce that grows with speed squared.
func _update_gyro_and_wing(delta: float) -> void:
	_gyro_working = 0.0
	if gyros > 0:
		var up := global_basis.y
		var axis := up.cross(Vector3.UP)          # the way to turn to get upright
		var tilt := axis.length()
		if up.y < 0.0:
			axis = global_basis.z if axis.length() < 0.01 else axis.normalized()
			tilt = 1.0                            # upside down: full power
		var spin := angular_velocity - Vector3.UP * angular_velocity.dot(Vector3.UP)
		var torque := axis.normalized() * minf(tilt * 3.0, 1.0) * gyro_torque * gyros if tilt > 0.02 else Vector3.ZERO
		torque -= spin * gyro_torque * 0.25 * gyros   # damping: no wobble
		apply_torque(torque)
		_gyro_working = clampf(tilt * 3.0, 0.0, 1.0)
		if battery > 0.0:
			battery = maxf(battery - _gyro_working * 0.6 * gyros * delta, 0.0)
	if wings > 0:
		var v := linear_velocity.dot(global_basis.z)
		apply_central_force(-global_basis.y * wing_downforce * wings * v * v)
		apply_central_force(-linear_velocity * 0.6 * wings)   # a little drag


func get_flow_under() -> float:
	return _flow_under


func is_gyro_working() -> bool:
	return _gyro_working > 0.2


## 0..1: how much of the truck is on glass right now.
func get_glass_under() -> float:
	return _glass_under


## Leave a tyre-tread print in the GPU track map.
func _stamp_tread(wi: int, contact: Vector3, slip: float, hard: float) -> void:
	var tracks := terrain.tracks
	if tracks == null:
		return
	# Which way this wheel points (front wheels steer).
	var heading := global_basis.z.rotated(global_basis.y, wheels[wi].steering)
	heading.y = 0.0
	heading = heading.normalized()
	var size := Vector2(wheel_width + 0.02, TREAD_PITCH * 3.0)
	var depth := lerpf(0.4, 0.15, hard)   # faint prints on hardpan
	var last := _last_stamp[wi]
	if last == Vector3.INF or last.distance_to(contact) > 1.0:
		_last_stamp[wi] = contact   # just landed or teleported: start fresh
		return
	var moved := last.distance_to(contact)
	if moved >= TREAD_PITCH:
		# Place prints at exact tread-pitch steps along the path.
		var dir := (contact - last) / moved
		var steps := int(moved / TREAD_PITCH)
		for n in steps:
			var p := last + dir * TREAD_PITCH * (n + 1)
			tracks.stamp(SandTracks.TYRE, p, heading, size, depth)
		_last_stamp[wi] = last + dir * TREAD_PITCH * steps
	elif slip > 0.5 and _spin_stamp_timer <= 0.0:
		# Spinning in place: smear the sand where the tyre is.
		tracks.stamp(SandTracks.TYRE, contact, heading.rotated(Vector3.UP, randf_range(-0.2, 0.2)), size, 0.25 * slip)
		if wi == wheels.size() - 1:
			_spin_stamp_timer = 0.08


func get_spin_amount() -> float:
	return _spin_amount


## 0 = soft sand, 1 = firm hardpan, under the wheels right now.
func get_ground_hardness() -> float:
	return _hardness_under


## A part was just fitted: make it pop into place (small, then a bounce).
## `what` is a garage slot ("tyres", "bed"...) or a workshop socket ("L1").
func pop_in(what: String) -> void:
	var nodes: Array[Node3D] = []
	match what:
		"tyres":
			nodes = _tyre_models
		"bed":
			nodes = [_bed_model]
		"motor", "battery":
			nodes = [_body_model]
		_:
			if _part_models.has(what):
				nodes = [_part_models[what]]
	for n in nodes:
		if n == null:
			continue
		var full := n.scale
		n.scale = full * 0.4
		var tw := n.create_tween()
		tw.tween_property(n, "scale", full * 1.12, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "scale", full, 0.12)


## Repaint without rebuilding (the Paint tab's live preview).
func set_paint(p: Dictionary) -> void:
	paint = p.duplicate()
	PaintJob.apply(self, paint)


## Hold the truck perfectly still (the workshop uses this). Locking every
## axis instead of `freeze`: a frozen VehicleBody3D makes Godot's wheel
## maths divide by zero, which spams "!v.is_finite()" errors when drawing.
func hold(on: bool) -> void:
	for axis in ["axis_lock_linear_x", "axis_lock_linear_y", "axis_lock_linear_z",
			"axis_lock_angular_x", "axis_lock_angular_y", "axis_lock_angular_z"]:
		set(axis, on)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


## Stand the car upright at a position (used for reset).
func place_at(pos: Vector3, yaw: float) -> void:
	global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	reset_physics_interpolation()   # teleported: don't smooth from the old spot
	release_winch()
