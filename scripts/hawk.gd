class_name Hawk
extends Node3D
## A hawk that steals cargo from above, by day.
##
##   SOAR ----spots unsecured cargo----> STALK (circles overhead: your warning)
##     ^                                    |
##     |                                  DIVE (watch for its shadow!)
##     |                                    |
##   RETREAT <--net/cage/too heavy--- grab? --yes--> CARRY --gets tired--> drops it
##     ^                                                                       |
##     +-----------------------------------------------------------------------+
##
## It can only lift light cargo (crate, eggs, ice). It can't get at cargo
## that's strapped down with a net or locked in the cage. When it gets tired
## it DROPS the cargo from about 2 m, somewhere out in the dunes: damage,
## and maybe right next to an ant nest. At night it goes home to roost.
##
## It isn't a physics body: it flies by moving itself (code steering), which
## is simpler and smoother for a flying animal.

signal stalking
signal grabbed(cargo: Cargo)
signal dropped(cargo: Cargo)
signal foiled(reason: String)

enum State { ROOST, SOAR, STALK, DIVE, CARRY, RETREAT }

@export var soar_height: float = 13.0
@export var soar_radius: float = 12.0
@export var spot_range: float = 32.0
@export var max_lift_kg: float = 8.5
@export var carry_time: float = 4.5
@export var cooldown_s: float = 35.0
## Stay inside the map (the edges of the desert rise into walls at ~22 m).
@export var play_area: float = 20.0

var terrain: SandTerrain
var roost := Vector3.ZERO                  # where it sleeps (a dead tree)
var state: State = State.SOAR
var velocity := Vector3.ZERO
var carrying: Cargo
var _timer := 0.0
var _cooldown := 12.0
var _angle := 0.0
var _wings: Array[Node3D] = []
var _flap := 0.0


func _ready() -> void:
	_build_body()
	global_position = roost + Vector3(0, soar_height, 0)


## Called by the game every physics step.
##   secured:  the cargo is strapped down (net) or caged
##   daylight: 0..1 (hawks only hunt by day)
func update_hawk(delta: float, cargo: Cargo, secured: bool, daylight: float) -> void:
	_timer += delta
	_cooldown -= delta
	var night := daylight < 0.3
	var target := global_position
	var speed := 6.0

	match state:
		State.ROOST:
			target = roost + Vector3(0, 1.3, 0)
			speed = 4.0
			if not night:
				_set_state(State.SOAR)
		State.SOAR:
			if night:
				_set_state(State.ROOST)
			_angle += delta * 0.35
			var center := roost
			if cargo and _cooldown <= 0.0 and _flat(cargo.global_position - global_position).length() < spot_range:
				center = cargo.global_position
				if _timer > 3.0:
					_set_state(State.STALK)
					stalking.emit()
			target = Vector3(center.x, 0, center.z) + Vector3(cos(_angle), 0, sin(_angle)) * soar_radius
			target.y = _ground(target) + soar_height
		State.STALK:
			if cargo == null or night:
				_set_state(State.RETREAT)
			else:
				_angle += delta * 0.9
				var c := cargo.global_position
				target = c + Vector3(cos(_angle) * 4.0, 8.0, sin(_angle) * 4.0)
				speed = 7.0
				if _timer > 4.0:
					_set_state(State.DIVE)
		State.DIVE:
			if cargo == null:
				_set_state(State.RETREAT)
			else:
				target = cargo.global_position + Vector3(0, 0.45, 0)
				speed = 11.0
				if global_position.distance_to(target) < 0.6:
					_try_grab(cargo, secured)
		State.CARRY:
			speed = 3.0
			# Fly away low and slow, struggling with the weight.
			var away := _flat(velocity).normalized() if _flat(velocity).length() > 0.5 else Vector3.FORWARD
			# Near the edge of the map? Turn back toward the middle.
			if maxf(absf(global_position.x), absf(global_position.z)) > play_area - 4.0:
				away = _flat(-global_position).normalized()
			target = global_position + away * 5.0
			target.y = _ground(global_position) + 2.4
			if carrying:
				carrying.global_transform = Transform3D(carrying.global_basis, global_position + Vector3(0, -0.45, 0))
			if _timer > carry_time:
				_drop()
		State.RETREAT:
			target = global_position + Vector3(0, 3, 0) + _flat(global_position - roost).normalized() * -2.0
			target.y = _ground(global_position) + soar_height
			if _timer > 4.0:
				_set_state(State.SOAR)

	# Never fly off the map (the hawk test once carried a crate 2.6 km away).
	target.x = clampf(target.x, -play_area, play_area)
	target.z = clampf(target.z, -play_area, play_area)
	# Steer toward the target (like the beetle's _move, but in the air).
	var want := (target - global_position).limit_length(speed)
	velocity = velocity.lerp(want, clampf(delta * 3.0, 0.0, 1.0))
	global_position += velocity * delta
	if _flat(velocity).length() > 0.2:
		look_at(global_position + velocity, Vector3.UP, true)   # +Z faces forward
	_animate(delta)


func _try_grab(cargo: Cargo, secured: bool) -> void:
	if secured:
		foiled.emit("net")
		_give_up()
	elif cargo.mass > max_lift_kg:
		foiled.emit("heavy")
		_give_up()
	else:
		carrying = cargo
		cargo.set_carried(true)
		_set_state(State.CARRY)
		grabbed.emit(cargo)


func _drop() -> void:
	var c := carrying
	carrying = null
	if c and is_instance_valid(c):
		c.set_carried(false)
		c.linear_velocity = velocity * 0.5
		dropped.emit(c)
	_give_up()


## Let go of whatever it's doing (the game also calls this if the cargo vanishes).
func _give_up() -> void:
	_cooldown = cooldown_s
	_set_state(State.RETREAT)


func release_if_carrying() -> void:
	if carrying:
		_drop()


func _set_state(s: State) -> void:
	state = s
	_timer = 0.0


func _ground(p: Vector3) -> float:
	return terrain.get_height(p.x, p.z) if terrain else 0.0


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


## The Blender model (models/hawk.glb). The wings are separate objects,
## wing_L and wing_R, pivoting at the shoulders, so _animate can flap them.
func _build_body() -> void:
	var model := Models.make("hawk")
	add_child(model)
	for side in [["L", -1.0], ["R", 1.0]]:
		var wing := Models.part(model, "wing_" + side[0])
		if wing:
			wing.set_meta("side", side[1])
			_wings.append(wing)


func _animate(delta: float) -> void:
	# Soaring: wings out, barely moving. Carrying or climbing: hard flapping.
	var flapping := state in [State.CARRY, State.RETREAT, State.ROOST] or velocity.y > 1.0
	_flap += delta * (11.0 if flapping else 1.5)
	var amount := 0.6 if flapping else 0.08
	if state == State.DIVE:
		amount = 0.0
	for p in _wings:
		var side: float = p.get_meta("side")
		var tuck := 0.9 if state == State.DIVE else 0.0   # wings swept back to dive
		p.rotation = Vector3(0, -tuck * side, sin(_flap) * amount * side)
