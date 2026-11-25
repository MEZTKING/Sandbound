class_name DriftRay
extends Node3D
## A drift ray: a flat, wide creature that "swims" in the sand rivers of the
## Drift, with just its back fin showing. Wade into its river slowly and it
## comes for you, slides underneath and FLIPS UP, throwing the truck into the
## air. In the Drift's low gravity, that often means landing on your roof.
##
##   GLIDE --truck wading slowly nearby--> HUNT --right under it--> STRIKE
##     ^                                    |  (truck too fast / left the river)
##     +----------- REST <------------------+---------------------------+
##
## How to beat it:
##   - Cross rivers FAST (over 3 m/s it can't keep up), or don't cross at all.
##   - A gyro stabiliser (workshop) turns you back upright after the flip.
##   - Heavier trucks get thrown less high.
## Like the scorpion, it moves itself by code (no physics body).

signal hunting
signal struck

enum State { GLIDE, HUNT, STRIKE, REST }

@export var notice_range: float = 9.0
@export var glide_speed: float = 1.4
@export var hunt_speed: float = 5.0
@export var escape_speed: float = 3.0      ## Trucks faster than this outrun it.
@export var flip_kick: float = 3.4         ## Upward speed change (m/s) it gives the truck.
@export var rest_s: float = 14.0

var terrain: SandTerrain
var home := Vector3.ZERO
var state: State = State.GLIDE
var _timer := 0.0
var _dir := 1.0                            ## +1 = downstream, -1 = upstream
var _leap := 0.0                           ## 0..1 while leaping out
var _lost := 0.0                           ## seconds the truck has been out of the river
var _body: Node3D
var _wings: Array[Node3D] = []
var _wake: GPUParticles3D


func _ready() -> void:
	_body = Models.make("ray")
	add_child(_body)
	for side in ["L", "R"]:
		var w := Models.part(_body, "wing_" + side)
		if w:
			_wings.append(w)
	_wake = SandDust.make_wheel_spray()
	_wake.amount_ratio = 0.0
	add_child(_wake)
	global_position = home


## Called by the game every physics step.
func update_ray(delta: float, truck: RCCar) -> void:
	_timer += delta
	var to_truck := _flat(truck.global_position - global_position)
	var truck_speed := truck.linear_velocity.length()
	var wading := truck.get_flow_under() > 0.15
	match state:
		State.GLIDE:
			_swim_along_river(delta, glide_speed)
			if wading and to_truck.length() < notice_range and truck_speed < escape_speed:
				_set_state(State.HUNT)
				hunting.emit()
		State.HUNT:
			# Out of the river for a whole second = it lost you. (Checking a
			# single frame made it give up when one wheel bounced on a bank.)
			_lost = 0.0 if wading else _lost + delta
			var step := to_truck.limit_length(hunt_speed * delta)
			var next := global_position + step
			# It can only swim in flowing sand.
			if terrain.get_flow(next.x, next.z) > 0.1:
				global_position = next
			_face(to_truck)
			if truck_speed > escape_speed or _lost > 1.0 or _timer > 8.0:
				_set_state(State.REST)          # outrun, or you got out
			elif to_truck.length() < 1.1:
				_strike(truck)
		State.STRIKE:
			_leap = minf(_leap + delta * 2.5, 1.0)
			if _leap >= 1.0:
				_set_state(State.REST)
		State.REST:
			_swim_along_river(delta, glide_speed * 1.5)
			if _timer > rest_s:
				_set_state(State.GLIDE)
	_place_on_sand(delta)
	_animate()


## Slide out from underneath and flip up: a kick upwards, off-centre, so it
## lifts one side of the truck more than the other (that's what tips it).
func _strike(truck: RCCar) -> void:
	var side := truck.global_basis.x * (1.0 if randf() < 0.5 else -1.0)
	truck.apply_impulse(Vector3.UP * truck.mass * flip_kick, side * 0.45)
	_leap = 0.0
	_set_state(State.STRIKE)
	struck.emit()


## Follow the river's flow (or against it), turning back at the ends or
## when it strays too far from home.
func _swim_along_river(delta: float, speed: float) -> void:
	var p := global_position
	var fv := terrain.get_flow_velocity(p.x, p.z)
	if fv.length() < 0.2 or _flat(p - home).length() > 22.0:
		_dir = -_dir
		fv = _flat(home - p)                # head back towards home
		if fv.length() > 0.01:
			global_position += fv.normalized() * speed * delta
			_face(fv)
		return
	var move := fv.normalized() * _dir * speed * delta
	global_position += move
	_face(move)


func _place_on_sand(delta: float) -> void:
	var p := global_position
	var ground := terrain.get_height(p.x, p.z) if terrain else 0.0
	# Hidden just under the surface (only the fin shows); leaps out to strike.
	var lift := sin(_leap * PI) * 0.9 if state == State.STRIKE else 0.0
	global_position.y = ground - 0.07 + lift
	var moving := state == State.HUNT or state == State.REST
	_wake.amount_ratio = lerpf(_wake.amount_ratio, 0.6 if moving else 0.15, 1.0 - exp(-4.0 * delta))


func _animate() -> void:
	var t := Time.get_ticks_msec() * 0.001
	var beat := sin(t * (9.0 if state == State.HUNT else 3.0)) * 0.25
	for k in _wings.size():
		_wings[k].rotation.z = beat * (1.0 if k == 0 else -1.0)
	_body.rotation.x = -_leap * 1.2 if state == State.STRIKE else 0.0


func _set_state(s: State) -> void:
	state = s
	_timer = 0.0
	_lost = 0.0


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


func _face(dir: Vector3) -> void:
	var d := _flat(dir)
	if d.length() > 0.01:
		look_at(global_position + d, Vector3.UP, true)
