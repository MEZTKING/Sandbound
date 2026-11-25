class_name Trailer
extends VehicleBody3D
## A two-wheeled trailer, towed on a real physics JOINT at the hitch.
##
## Unlike bolted parts (which become part of the truck's body), the trailer is
## its own body. A Generic6DOFJoint3D ("6 degrees of freedom": 3 ways to slide,
## 3 ways to turn) ties it to the truck's hitch ball:
##   - sliding: locked in all 3 directions (it can't come off the ball)
##   - turning left/right (yaw):  free up to ~80 degrees (jack-knife!)
##   - tipping up/down (pitch):   free up to ~35 degrees (bumps, dune crests)
##   - rolling sideways:          only ~20 degrees (a real hitch is stiff there)
##
## Its wheels sink, leave tracks and drag in soft sand like the truck's, but
## they have no motor: the truck has to pull all of that.
## Front is +Z, like the truck.

const WHEEL_RADIUS := 0.28
const TONGUE_TIP := Vector3(0, 0.0, 1.15)   ## where it hooks onto the hitch ball

@export var sand_drag: float = 14.0
@export var press_rate: float = 0.2
@export var rut_depth: float = 0.06

var terrain: SandTerrain
var cargo_anchor: Node3D
var extra_load := 0.0                       ## Cargo weight on board (set by the game).
var wheels: Array[VehicleWheel3D] = []
var joint: Generic6DOFJoint3D
var _last_stamp: Array[Vector3] = []


func _ready() -> void:
	mass = 22.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.1, 0)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.85, 0.25, 0.15)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.15, 0.15, 0.17)
	_box(Vector3(0.9, 0.12, 1.1), Vector3.ZERO, paint)              # bed
	_box(Vector3(0.9, 0.2, 0.04), Vector3(0, 0.16, -0.53), dark)     # walls...
	_box(Vector3(0.9, 0.2, 0.04), Vector3(0, 0.16, 0.53), dark)
	_box(Vector3(0.04, 0.2, 1.1), Vector3(-0.43, 0.16, 0), dark)
	_box(Vector3(0.04, 0.2, 1.1), Vector3(0.43, 0.16, 0), dark)
	_box(Vector3(0.06, 0.06, 0.62), Vector3(0, 0.0, 0.85), dark)     # tow bar
	for x in [-0.55, 0.55]:
		var w := VehicleWheel3D.new()
		w.position = Vector3(x, -0.04, -0.1)
		w.wheel_radius = WHEEL_RADIUS
		w.wheel_rest_length = 0.15
		w.suspension_travel = 0.15
		w.suspension_stiffness = 40.0
		w.suspension_max_force = 4000.0
		w.damping_compression = 2.0
		w.damping_relaxation = 2.6
		w.wheel_friction_slip = 2.5
		w.wheel_roll_influence = 0.3
		add_child(w)
		wheels.append(w)
		_last_stamp.append(Vector3.INF)
		var tyre := Models.make("tyre_standard")
		tyre.scale = Vector3(0.75, WHEEL_RADIUS / 0.32, WHEEL_RADIUS / 0.32)
		w.add_child(tyre)
	add_child(Models.make("trailer"))
	cargo_anchor = Node3D.new()
	cargo_anchor.position = Vector3(0, 0.265, -0.05)
	add_child(cargo_anchor)


## Physics only: the looks come from the Blender model (models/trailer.glb).
func _box(size: Vector3, pos: Vector3, _mat: Material) -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = pos
	add_child(col)


## Line the trailer up behind the truck and lock it onto the hitch ball.
## Call after both are in the scene.
func attach_to(truck: RCCar) -> void:
	var hitch := truck.get_hitch_point()
	var yaw := truck.global_rotation.y
	global_transform = Transform3D(Basis(Vector3.UP, yaw), hitch - Basis(Vector3.UP, yaw) * TONGUE_TIP)
	linear_velocity = truck.linear_velocity
	angular_velocity = Vector3.ZERO
	reset_physics_interpolation()

	joint = Generic6DOFJoint3D.new()
	get_parent().add_child(joint)
	joint.global_transform = Transform3D(truck.global_basis, hitch)
	joint.node_a = joint.get_path_to(truck)
	joint.node_b = joint.get_path_to(self)
	# Sliding stays locked (the default). Turning gets limits:
	_limit(Vector3.AXIS_X, 0.6)    # pitch
	_limit(Vector3.AXIS_Y, 1.4)    # yaw: jack-knife
	_limit(Vector3.AXIS_Z, 0.35)   # roll
	joint.set_exclude_nodes_from_collision(true)


func _limit(axis: int, angle: float) -> void:
	var lo := Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT
	var hi := Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT
	var flag := Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT
	match axis:
		Vector3.AXIS_X:
			joint.set_param_x(lo, -angle)
			joint.set_param_x(hi, angle)
			joint.set_flag_x(flag, true)
		Vector3.AXIS_Y:
			joint.set_param_y(lo, -angle)
			joint.set_param_y(hi, angle)
			joint.set_flag_y(flag, true)
		Vector3.AXIS_Z:
			joint.set_param_z(lo, -angle)
			joint.set_param_z(hi, angle)
			joint.set_flag_z(flag, true)


## Remove the trailer and its joint.
func detach_and_free() -> void:
	if joint:
		joint.queue_free()
	queue_free()


## How far the tow bar is from where it should be on the hitch (0 = attached).
func hitch_gap(truck: RCCar) -> float:
	return to_global(TONGUE_TIP).distance_to(truck.get_hitch_point())


func _physics_process(delta: float) -> void:
	if terrain == null:
		return
	var touching := 0
	var hard_total := 0.0
	for wi in wheels.size():
		var w := wheels[wi]
		if not w.is_in_contact():
			_last_stamp[wi] = Vector3.INF
			continue
		touching += 1
		var contact := w.global_position - global_basis.y * WHEEL_RADIUS
		if w.has_method("get_contact_point"):
			contact = w.get_contact_point()
		# Trailers break salt crust too (their own weight plus the cargo's).
		var c := terrain.get_crust(contact.x, contact.z)
		if c > 0.02 and (mass + extra_load) * 9.8 / wheels.size() > c * 300.0:
			terrain.break_crust(contact, WHEEL_RADIUS * 1.4, 0.07)
		var hard := terrain.get_hardness(contact.x, contact.z)
		hard_total += hard
		var softness := lerpf(1.5, 0.2, hard)
		terrain.press(contact, WHEEL_RADIUS * 0.6, press_rate * softness * delta, rut_depth * softness)
		_stamp(wi, contact, hard)
	if touching > 0:
		# No motor: the sand just holds it back, more in soft sand.
		var v := linear_velocity
		v.y = 0.0
		var ground := lerpf(1.4, 0.5, hard_total / touching)
		apply_central_force(-v * sand_drag * ground * (float(touching) / wheels.size()))


func _stamp(wi: int, contact: Vector3, hard: float) -> void:
	if terrain.tracks == null:
		return
	var pitch := RCCar.TREAD_PITCH
	var last := _last_stamp[wi]
	if last == Vector3.INF or last.distance_to(contact) > 1.0:
		_last_stamp[wi] = contact
		return
	var moved := last.distance_to(contact)
	if moved < pitch:
		return
	var heading := global_basis.z
	heading.y = 0.0
	heading = heading.normalized()
	var dir := (contact - last) / moved
	var steps := int(moved / pitch)
	for n in steps:
		terrain.tracks.stamp(SandTracks.TYRE, last + dir * pitch * (n + 1), heading,
				Vector2(0.18, pitch * 3.0), lerpf(0.35, 0.12, hard))
	_last_stamp[wi] = last + dir * pitch * steps
