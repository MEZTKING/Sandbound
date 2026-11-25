class_name Weather
extends Node3D
## Wind gusts. Every minute or so the wind picks up for a few seconds:
##   - it shoves the truck (and trailer, and loose cargo) sideways
##   - sand streams across the screen
##   - the haze thickens
##   - it slowly smooths your tyre tracks away (the track map fades)
##
## The wind always blows from the same direction as the ripples in the sand
## (the shader's wind_angle_deg), because that's what makes ripples.

signal gust_started

@export var min_gap_s: float = 45.0       ## Calm time between gusts.
@export var max_gap_s: float = 90.0
@export var gust_length_s: float = 7.0
@export var truck_push: float = 420.0     ## Newtons at full gust.
@export var track_fade_per_s: float = 0.08

var wind_dir := Vector3.RIGHT              ## Where the wind blows TO.
var strength := 0.0                        ## 0 = calm, 1 = full gust (smooth).
var _timer := 0.0
var _gusting := 0.0                        ## seconds left in this gust
var _fade_timer := 0.0
var _sand: GPUParticles3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 77
	_timer = _rng.randf_range(min_gap_s, max_gap_s) * 0.5
	_sand = _make_blowing_sand()
	add_child(_sand)


func set_wind_angle(deg: float) -> void:
	# Ripple crests run across the wind; the shader's angle rotates its texture,
	# and the ripples in our texture run along X, so the wind blows along Z
	# rotated by that angle.
	wind_dir = Vector3(0, 0, 1).rotated(Vector3.UP, deg_to_rad(-deg))


## Start a gust now (tests use this).
func start_gust() -> void:
	_gusting = gust_length_s
	_timer = _rng.randf_range(min_gap_s, max_gap_s)
	gust_started.emit()


## Called every physics step by the game.
func update_weather(delta: float, follow: Vector3, bodies: Array, tracks: Object) -> void:
	if _gusting > 0.0:
		_gusting -= delta
	else:
		_timer -= delta
		if _timer <= 0.0:
			start_gust()
	# Smoothly rise and fall instead of switching on and off.
	var want := 1.0 if _gusting > 0.0 else 0.0
	strength = move_toward(strength, want, delta / 1.5)
	if strength <= 0.001:
		_sand.amount_ratio = 0.0
		return
	for b in bodies:
		if b is RigidBody3D and is_instance_valid(b):
			var area_factor: float = b.get_meta("wind_area", 1.0)
			var force := wind_dir * truck_push * strength * area_factor
			# Wheeled things: the wind mostly shoves them SIDEWAYS. Along their
			# wheels it only gets 15%, or a parked truck rolls away like a
			# sail-cart (the wind test caught one doing 12 m/s off the map).
			if b is VehicleBody3D:
				var fwd: Vector3 = (b as VehicleBody3D).global_basis.z
				fwd.y = 0.0
				fwd = fwd.normalized()
				var along: Vector3 = fwd * force.dot(fwd)
				force = (force - along) + along * 0.15
			b.apply_central_force(force)
	_sand.global_position = follow
	_sand.amount_ratio = strength
	# Wind smooths the tracks away, a little at a time.
	_fade_timer += delta
	if tracks and _fade_timer > 0.25:
		tracks.fade(track_fade_per_s * _fade_timer * strength)
		_fade_timer = 0.0


func _make_blowing_sand() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 400
	p.lifetime = 2.0
	p.amount_ratio = 0.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-30, -5, -30), Vector3(60, 15, 60))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(14, 1.2, 14)
	m.direction = Vector3(0, 0.05, 1)
	m.spread = 8.0
	m.initial_velocity_min = 5.0
	m.initial_velocity_max = 9.0
	m.gravity = Vector3(0, -0.5, 0)
	m.scale_min = 0.03
	m.scale_max = 0.09
	var fade := Gradient.new()
	fade.set_color(0, Color(0.85, 0.72, 0.55, 0.0))
	fade.add_point(0.2, Color(0.85, 0.72, 0.55, 0.6))
	fade.set_color(fade.get_point_count() - 1, Color(0.85, 0.72, 0.55, 0.0))
	var ft := GradientTexture1D.new()
	ft.gradient = fade
	m.color_ramp = ft
	p.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 0.25)       # streaks
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = SandDust.PUFF
	q.material = mat
	p.draw_pass_1 = q
	return p


## Rotate the blowing sand to match the wind (call after set_wind_angle).
func _process(_delta: float) -> void:
	if _sand and _sand.amount_ratio > 0.0:
		_sand.global_basis = Basis.looking_at(-wind_dir)


func is_gusting() -> bool:
	return strength > 0.3


## "north-west" etc. (north = -Z, the direction the base faces the dunes).
func from_direction() -> String:
	var from := -wind_dir
	var names := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
	var a := fposmod(atan2(from.x, -from.z), TAU)
	return names[int(round(a / (TAU / 8.0))) % 8]
