class_name Scorpion
extends Node3D
## A Salt Flats scorpion. It waits buried in the crust, and when a truck rolls
## past it darts out and CLAMPS a wheel, pinning it so the truck drags and
## slews sideways.
##
##   BURIED --truck passes close--> STRIKE (darts at the nearest wheel)
##     ^                               |
##   FLEE <--shaken off / zapped-- CLAMPED (that wheel is locked)
##
## How to get free:
##   - Rock it off: keep the throttle down so the wheels fight it; after
##     about 2 seconds of hard throttle it loses its grip.
##   - Build a BUZZER (workshop): it zaps any scorpion that clamps on.
## Like the hawk, it moves itself by code (no physics body).

signal clamped(wheel_index: int)
signal shaken_off(how: String)

enum State { BURIED, STRIKE, CLAMPED, FLEE }

@export var strike_range: float = 3.0
@export var strike_speed: float = 5.0
@export var shake_needed_s: float = 2.0   ## Seconds of hard throttle to rock it off.
@export var zap_after_s: float = 0.6      ## A buzzer zaps it this fast.
@export var rest_s: float = 25.0          ## Time hiding before it'll strike again.

var terrain: SandTerrain
var home := Vector3.ZERO
var state: State = State.BURIED
var wheel_index := -1
var _timer := 0.0
var _rest := 0.0
var _shake := 0.0
var _flee_to := Vector3.ZERO
var _body: Node3D
var _tail: Node3D
var _claws: Array[Node3D] = []


func _ready() -> void:
	_build_body()
	global_position = home
	_set_state(State.BURIED)


## Called by the game every physics step.
func update_scorpion(delta: float, truck: RCCar) -> void:
	_timer += delta
	_rest -= delta
	match state:
		State.BURIED:
			global_position = Vector3(home.x, _ground(home) - 0.06, home.z)
			if _rest <= 0.0 and truck and _flat(truck.global_position - home).length() < strike_range \
					and truck.linear_velocity.length() > 0.5:
				_set_state(State.STRIKE)
		State.STRIKE:
			var wi := _nearest_wheel(truck)
			var target := truck.wheels[wi].global_position
			var to := _flat(target - global_position)
			global_position += to.limit_length(strike_speed * delta)
			global_position.y = _ground(global_position)
			_face(to)
			if to.length() < 0.35:
				wheel_index = wi
				truck.pin_wheel(wi, true)
				_set_state(State.CLAMPED)
				clamped.emit(wi)
			elif _timer > 2.5:
				_flee()   # missed
		State.CLAMPED:
			var w := truck.wheels[wheel_index]
			# Hang on to the outside of the wheel.
			var side := signf(w.position.x)
			global_position = w.global_position + truck.global_basis.x * side * (truck.wheel_width * 0.5 + 0.12) \
					+ Vector3.DOWN * 0.15
			_face(truck.global_basis.x * -side)
			# Rocking it off: hard throttle (either way) shakes it loose.
			if absf(truck.throttle_input) > 0.6:
				_shake += delta
			if truck.has_buzzer and _timer > zap_after_s:
				_release(truck, "zapped")
			elif _shake > shake_needed_s:
				_release(truck, "shaken")
		State.FLEE:
			var to := _flat(_flee_to - global_position)
			global_position += to.limit_length(3.5 * delta)
			global_position.y = _ground(global_position)
			_face(to)
			if to.length() < 0.2:
				home = _flee_to
				_set_state(State.BURIED)
	_animate()


func _release(truck: RCCar, how: String) -> void:
	truck.pin_wheel(wheel_index, false)
	wheel_index = -1
	shaken_off.emit(how)
	_flee()


## Let go no matter what (truck rebuilt, teleported...).
func release_now(truck: RCCar) -> void:
	if state == State.CLAMPED and truck:
		truck.pin_wheel(wheel_index, false)
	wheel_index = -1
	_set_state(State.BURIED)
	global_position = home


func _flee() -> void:
	_rest = rest_s
	var a := randf() * TAU
	_flee_to = home + Vector3(cos(a), 0, sin(a)) * 6.0
	_set_state(State.FLEE)


func _nearest_wheel(truck: RCCar) -> int:
	var best := 0
	for i in truck.wheels.size():
		if truck.wheels[i].global_position.distance_to(global_position) \
				< truck.wheels[best].global_position.distance_to(global_position):
			best = i
	return best


func _set_state(s: State) -> void:
	state = s
	_timer = 0.0
	_shake = 0.0


func _ground(p: Vector3) -> float:
	return terrain.get_height(p.x, p.z) if terrain else 0.0


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


func _face(dir: Vector3) -> void:
	if dir.length() > 0.01:
		look_at(global_position + dir, Vector3.UP, true)


## The Blender model (models/scorpion.glb): claw_L, claw_R and tail are
## separate objects so they can snap and wag.
func _build_body() -> void:
	_body = Models.make("scorpion")
	add_child(_body)
	for side in ["L", "R"]:
		var claw := Models.part(_body, "claw_" + side)
		if claw:
			_claws.append(claw)
	_tail = Models.part(_body, "tail")
	if _tail == null:
		_tail = Node3D.new()


func _animate() -> void:
	var t := Time.get_ticks_msec() * 0.001
	# Buried: only the tail tip pokes out. Otherwise: snapping claws, wagging tail.
	_body.position.y = -0.05 if state == State.BURIED else 0.0
	var snap := 0.0 if state == State.BURIED else sin(t * (18.0 if state == State.CLAMPED else 8.0)) * 0.3
	for k in _claws.size():
		_claws[k].rotation.y = snap * (1.0 if k == 0 else -1.0)
	_tail.rotation.x = sin(t * 3.0) * 0.15
