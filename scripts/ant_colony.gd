class_name AntColony
extends Node3D
## A nest of ants that steal cargo left lying in the sand.
##
## Drop your crate near a nest and leave it there: after a few seconds a
## column of ants marches out, surrounds it and hauls it home. If it reaches
## the nest, it's gone. Drive close and they scatter (they're tiny, you're a
## truck), then come back. Get there, park and press E before they regroup.
##
## Like the beetle it's a STATE MACHINE, but for a whole colony at once:
##
##   HOME --cargo lying nearby--> MARCHING --ants arrive--> CARRYING --at nest--> (stolen)
##              ^                    |  ^                      |
##              |                    v  |                      v
##          RETURNING <--cargo gone-- SCATTERED <--truck close--+
##
## Each ant just walks toward a TARGET point. Each state only decides the
## targets: the nest, a spot around the crate, or away from the truck.
## That's a simple way to make lots of little things look busy and alive.
##
## Drawing: 40 ants are ONE MultiMesh (one draw call), like the crew at base.

signal stole_cargo(colony: AntColony)

enum State { HOME, MARCHING, CARRYING, SCATTERED, RETURNING }

@export var ant_count: int = 40
@export var notice_range: float = 12.0    ## Senses cargo lying within this distance.
@export var notice_delay: float = 4.0     ## Cargo must lie still this long first.
@export var walk_speed: float = 1.5       ## Ants are fast for their size.
@export var carry_speed: float = 0.45     ## How fast they drag cargo home.
@export var scare_distance: float = 2.4   ## A truck this close scares them off.
@export var scare_time: float = 3.0

var terrain: SandTerrain
var state: State = State.HOME

var _pos := PackedVector3Array()          # each ant's position
var _target := PackedVector3Array()       # where each ant is heading
var _ring := PackedVector2Array()         # each ant's spot around the cargo
var _start_delay := PackedFloat32Array()  # so they leave the nest in a column
var _timer := 0.0
var _lying_time := 0.0
var _focus := Vector3.INF                 # ants standing still face this (the cargo)
var _mm := MultiMesh.new()
var _rng := RandomNumberGenerator.new()

const ANT_SHADER := """
shader_type spatial;
uniform sampler2D palette : source_color, filter_nearest_mipmap;
void vertex() {
	// Little side-to-side waddle, different for each ant.
	float id = float(INSTANCE_ID);
	VERTEX.x += sin(TIME * 30.0 + id * 1.7) * 0.006 * smoothstep(0.0, 0.05, VERTEX.z + 0.05);
}
void fragment() {
	ALBEDO = texture(palette, UV).rgb * mix(1.0, COLOR.g, 0.6);   // baked corner shading
	ROUGHNESS = 0.35;
	SPECULAR = 0.6;
}
"""


func _ready() -> void:
	_rng.seed = hash(global_position)
	_pos.resize(ant_count)
	_target.resize(ant_count)
	_ring.resize(ant_count)
	_start_delay.resize(ant_count)
	for i in ant_count:
		_pos[i] = global_position
		_target[i] = global_position
		var a := _rng.randf() * TAU
		_ring[i] = Vector2(cos(a), sin(a)) * _rng.randf_range(0.32, 0.62)
		_start_delay[i] = i * 0.12
	_build_visuals()


func _build_visuals() -> void:
	# The nest hole: a dark disc on top of the mound.
	var hole := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.09
	disc.bottom_radius = 0.09
	disc.height = 0.02
	hole.mesh = disc
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.05, 0.03, 0.02)
	hole.material_override = black
	add_child(hole)
	hole.global_position = global_position + Vector3(0, 0.01, 0)

	# One ant: the Blender model (models/ant.glb), drawn 40 times at once.
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.mesh = Models.mesh("ant")
	_mm.instance_count = ant_count
	_mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = ANT_SHADER
	mat.shader = sh
	mat.set_shader_parameter("palette", Models.PALETTE)
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.top_level = true            # ant positions are already in world space
	add_child(mmi)


## Called by the game every physics step.
##   cargo:       the cargo, or null
##   lying_loose: true if the cargo is off the truck (dropped)
func update_colony(delta: float, cargo: Cargo, lying_loose: bool, truck: Node3D) -> void:
	_timer += delta
	var nest := global_position
	var has_loose_cargo := cargo != null and lying_loose
	var truck_near_cargo := has_loose_cargo and truck.global_position.distance_to(cargo.global_position) < scare_distance

	match state:
		State.HOME:
			if has_loose_cargo and cargo.global_position.distance_to(nest) < notice_range \
					and cargo.linear_velocity.length() < 0.3:
				_lying_time += delta
				if _lying_time > notice_delay:
					_set_state(State.MARCHING)
			else:
				_lying_time = 0.0
			return   # nothing to animate: everyone's inside

		State.MARCHING:
			if not has_loose_cargo:
				_set_state(State.RETURNING)
			elif truck_near_cargo:
				_scatter(truck)
			else:
				var arrived := 0
				_focus = cargo.global_position
				for i in ant_count:
					_target[i] = _ring_spot(cargo, i)
					if _flat_dist(_pos[i], _target[i]) < 0.15:
						arrived += 1
				if arrived > ant_count * 0.8:
					_set_state(State.CARRYING)

		State.CARRYING:
			if not has_loose_cargo:
				_set_state(State.RETURNING)
			elif truck_near_cargo:
				_scatter(truck)
			else:
				_drag_home(cargo, nest)
				_focus = cargo.global_position
				for i in ant_count:
					_target[i] = _ring_spot(cargo, i)
				var to_nest := cargo.global_position - nest
				to_nest.y = 0.0
				if to_nest.length() < 0.6:
					stole_cargo.emit(self)
					_set_state(State.RETURNING)

		State.SCATTERED:
			if _timer > scare_time:
				_set_state(State.MARCHING if has_loose_cargo else State.RETURNING)

		State.RETURNING:
			var home := 0
			for i in ant_count:
				_target[i] = nest
				if _flat_dist(_pos[i], nest) < 0.1:
					home += 1
			if home == ant_count:
				_set_state(State.HOME)

	_move_ants(delta)


## Distance ignoring height (ants walk on the sand surface).
func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _set_state(s: State) -> void:
	state = s
	_focus = Vector3.INF
	_timer = 0.0
	_lying_time = 0.0


## Everyone runs directly away from the truck.
func _scatter(truck: Node3D) -> void:
	for i in ant_count:
		var away := _pos[i] - truck.global_position
		away.y = 0.0
		away = away.normalized() if away.length() > 0.01 else Vector3.RIGHT
		_target[i] = _pos[i] + away.rotated(Vector3.UP, _rng.randf_range(-0.6, 0.6)) * _rng.randf_range(2.0, 3.5)
	_set_state(State.SCATTERED)


func _ring_spot(cargo: Cargo, i: int) -> Vector3:
	var c := cargo.global_position
	return Vector3(c.x + _ring[i].x, 0.0, c.z + _ring[i].y)


## Drag the cargo toward the nest. They lift a bit (less friction) and push.
func _drag_home(cargo: Cargo, nest: Vector3) -> void:
	var dir := nest - cargo.global_position
	dir.y = 0.0
	dir = dir.normalized()
	var have := cargo.linear_velocity
	have.y = 0.0
	# Ants are famously strong: they carry most of the weight (so the cargo
	# barely rubs on the sand) and push hard enough to get it up the mound.
	# Slow-moving bodies "fall asleep" in the physics engine (to save work),
	# and a sleeping body ignores forces. Keep it awake while we carry it.
	cargo.sleeping = false
	# Full push while slower than walking pace, ease off when faster.
	# (A push that gets weaker as you near the target speed stalls on any
	# slope: lesson learned from the ant test.)
	var along := have.dot(dir)
	var push := dir * cargo.mass * (7.0 if along < carry_speed else -2.0)
	# Cancel sideways drift so the cargo heads straight home.
	push -= (have - dir * along) * cargo.mass * 4.0
	cargo.apply_central_force(push)
	cargo.apply_central_force(Vector3.UP * cargo.mass * 9.8 * 0.8)


func _move_ants(delta: float) -> void:
	var visible := 0
	for i in ant_count:
		# Leave the nest one after another, so they come out in a column.
		if state == State.MARCHING and _timer < _start_delay[i]:
			_pos[i] = global_position
			continue
		var to := _target[i] - _pos[i]
		to.y = 0.0
		var step := walk_speed * delta
		var heading := Vector3.FORWARD
		if _focus != Vector3.INF:
			var f := _focus - _pos[i]
			f.y = 0.0
			if f.length() > 0.01:
				heading = f.normalized()   # face the cargo, pushing it
		if to.length() > 0.02:
			heading = to.normalized()
			# A bit of wobble: ants never walk quite straight.
			heading = heading.rotated(Vector3.UP, sin(_timer * 7.0 + i) * 0.4)
			_pos[i] += heading * minf(step, to.length())
		_pos[i].y = terrain.get_height(_pos[i].x, _pos[i].z) if terrain else _pos[i].y
		# Ants at the nest hole are "inside" and not drawn.
		if _flat_dist(_pos[i], global_position) > 0.12:
			_mm.set_instance_transform(visible, Transform3D(Basis.looking_at(-heading), _pos[i]))
			visible += 1
	_mm.visible_instance_count = visible
