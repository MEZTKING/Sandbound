class_name DungBeetle
extends RigidBody3D
## The first enemy. It doesn't do "damage": it RAMS your truck from the side
## to roll it over and spill your cargo. That's the game's enemy rule:
## enemies attack your physics, not a health bar.
##
## It runs on a STATE MACHINE, the most useful pattern for game AI. The beetle
## is always in exactly one state, and each state has its own behaviour and
## its own rules for switching to another state:
##
##   WANDER  --sees truck-->  NOTICE  --facing it-->  WINDUP  --wait-->  CHARGE
##     ^                                                                   |
##     +---------------------------  RECOVER  <--hit or missed-------------+
##
## The WINDUP (rearing up) is a warning so you can dodge. The CHARGE locks in
## its direction when it starts, so steering out of the way works.
## Beat it with a wide, low vehicle, a bumper, or just good driving.

signal rammed(beetle: DungBeetle)
signal started_charge(beetle: DungBeetle)

enum State { WANDER, NOTICE, WINDUP, CHARGE, RECOVER }

@export var sight_range: float = 10.0     ## Notices the truck inside this distance.
@export var give_up_range: float = 18.0   ## Loses interest beyond this.
@export var wander_speed: float = 0.8
@export var charge_speed: float = 5.5
@export var move_force: float = 900.0     ## Max push its legs can make.
@export var ram_impulse: float = 140.0    ## How hard it hits. 100 = harmless shove, 140 = spills cargo, 180 = rolls trucks.
@export var windup_time: float = 0.8
@export var max_charge_time: float = 2.2
@export var recover_time: float = 2.5

var target: RCCar
var terrain: SandTerrain
var safe_center := Vector3.ZERO           ## Beetles leave you alone near base.
var safe_radius := 0.0
var state: State = State.WANDER

var _home: Vector3
var _timer := 0.0
var _wander_dir := Vector3.FORWARD
var _charge_dir := Vector3.ZERO
var _visual: Node3D
var _legs: Array[Node3D] = []
var _leg_phase := 0.0
var _footprint_timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mass = 25.0
	# Stay upright, only turn left/right (a real beetle would flip over...
	# that could be a fun feature later).
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	# Needed so body_entered fires when it bumps into something.
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

	var mat := PhysicsMaterial.new()
	mat.friction = 0.4
	physics_material_override = mat
	# A capsule lying lengthways: round shapes slide over bumpy sand, boxes
	# catch their corners on it.
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.24
	cap.height = 0.9
	col.shape = cap
	col.rotation.x = PI / 2
	col.position.y = -0.04
	add_child(col)

	_build_visual()
	_home = global_position
	_rng.seed = hash(global_position)
	_wander_dir = Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()


# ---------------------------------------------------------------------------
# The state machine
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_timer += delta
	var to_car := Vector3.ZERO
	var dist := INF
	if target and target.is_inside_tree() and not _car_is_safe():
		to_car = target.global_position - global_position
		to_car.y = 0.0
		dist = to_car.length()

	match state:
		State.WANDER:
			# Amble about, drifting back home if it strays too far.
			if _timer > 3.0:
				_timer = 0.0
				var random_dir := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1))
				var to_home := _home - global_position
				to_home.y = 0.0
				if to_home.length() > 6.0:
					random_dir += to_home.normalized() * 1.5
				_wander_dir = random_dir.normalized()
			_move(_wander_dir, wander_speed)
			_face(_wander_dir, delta)
			if dist < sight_range:
				_set_state(State.NOTICE)

		State.NOTICE:
			# Stop and turn to face the truck.
			_move(Vector3.ZERO, 0.0)
			_face(to_car, delta)
			if dist > give_up_range:
				_set_state(State.WANDER)
			elif _facing(to_car) > 0.95 or _timer > 1.2:
				_set_state(State.WINDUP)

		State.WINDUP:
			# Rear up: the warning. Keep tracking the truck.
			_move(Vector3.ZERO, 0.0)
			_face(to_car, delta)
			if dist > give_up_range:
				_set_state(State.WANDER)
			elif _timer > windup_time:
				# Aim a little ahead of where the truck is going, then COMMIT.
				var aim := target.global_position + target.linear_velocity * 0.4 - global_position
				aim.y = 0.0
				_charge_dir = aim.normalized()
				_set_state(State.CHARGE)
				started_charge.emit(self)

		State.CHARGE:
			_move(_charge_dir, charge_speed)
			_face(_charge_dir, delta)
			if _timer > max_charge_time:
				_set_state(State.RECOVER)   # missed!

		State.RECOVER:
			# Stagger backwards briefly, then catch its breath.
			_move(-_charge_dir if _timer < 0.4 else Vector3.ZERO, 1.0)
			if _timer > recover_time:
				_set_state(State.NOTICE if dist < sight_range else State.WANDER)

	_animate(delta)
	_leave_footprints(delta)


func _set_state(s: State) -> void:
	state = s
	_timer = 0.0


func _car_is_safe() -> bool:
	return safe_radius > 0.0 and target.global_position.distance_to(safe_center) < safe_radius


func _on_body_entered(body: Node) -> void:
	if state != State.CHARGE or body != target:
		return
	# The ram: shove the truck sideways and a bit up, applied ABOVE its centre
	# of mass so it also tips it (that's the torque that rolls it over).
	var impulse := _charge_dir * ram_impulse + Vector3.UP * ram_impulse * 0.45
	# Bumpers on the side we hit soften the blow.
	if target.has_method("ram_protection"):
		impulse *= 1.0 - target.ram_protection(_charge_dir)
	target.apply_impulse(impulse, Vector3.UP * 0.3)
	# Newton's third law: the beetle bounces back too.
	apply_central_impulse(-_charge_dir * ram_impulse * 0.5)
	rammed.emit(self)
	_set_state(State.RECOVER)


# ---------------------------------------------------------------------------
# Movement helpers
# ---------------------------------------------------------------------------

## Push toward a target velocity. Like a car's cruise control: the further we
## are from the speed we want, the harder the legs push (up to move_force).
func _move(dir: Vector3, speed: float) -> void:
	var want := dir * speed
	var have := linear_velocity
	have.y = 0.0
	var force := (want - have) * mass * 5.0
	force.y = 0.0
	apply_central_force(force.limit_length(move_force))


## Turn to face a direction by setting spin speed (front is +Z).
func _face(dir: Vector3, _delta: float) -> void:
	if dir.length() < 0.01:
		angular_velocity.y = 0.0
		return
	var want := atan2(dir.x, dir.z)
	var diff := wrapf(want - global_rotation.y, -PI, PI)
	angular_velocity.y = clampf(diff * 6.0, -5.0, 5.0)


## 1 = facing straight at it, 0 = side on, -1 = facing away.
func _facing(dir: Vector3) -> float:
	if dir.length() < 0.01:
		return 1.0
	var fwd := global_basis.z
	fwd.y = 0.0
	return fwd.normalized().dot(dir.normalized())


func _leave_footprints(delta: float) -> void:
	if terrain == null:
		return
	_footprint_timer -= delta
	if _footprint_timer <= 0.0 and linear_velocity.length() > 0.4:
		_footprint_timer = 0.12
		terrain.press(global_position + Vector3.DOWN * 0.25, 0.2, 0.01, 0.03)
		if terrain.tracks:
			var fwd := global_basis.z
			fwd.y = 0.0
			terrain.tracks.stamp(SandTracks.BEETLE_FEET, global_position, fwd.normalized(), Vector2(0.5, 0.5), 0.6)


# ---------------------------------------------------------------------------
# Looks
# ---------------------------------------------------------------------------

## The Blender model (models/beetle.glb). Its legs are separate objects,
## leg_L0..leg_R2, with their pivot at the hip, so _animate can swing them.
func _build_visual() -> void:
	_visual = Models.make("beetle")
	add_child(_visual)
	for side in ["L", "R"]:
		for k in 3:
			var leg := Models.part(_visual, "leg_%s%d" % [side, k])
			if leg:
				_legs.append(leg)


func _animate(delta: float) -> void:
	var speed := linear_velocity.length()
	_leg_phase += delta * (4.0 + speed * 6.0) * (1.0 if speed > 0.15 else 0.0)
	for n in _legs.size():
		# Alternate legs swing in opposite directions (a tripod gait).
		_legs[n].rotation.y = sin(_leg_phase + (n % 2) * PI) * 0.4
	# Rear up (nose up) during the windup so the player sees it coming.
	var rear := -0.45 if state == State.WINDUP else 0.0
	_visual.rotation.x = lerpf(_visual.rotation.x, rear, 1.0 - exp(-10.0 * delta))
