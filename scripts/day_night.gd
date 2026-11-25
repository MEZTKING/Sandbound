class_name DayNight
extends Node
## The sun goes round. One full day takes `day_length_s` seconds.
##
## `time` runs 0..1: 0 = midnight, 0.25 = sunrise, 0.5 = noon, 0.75 = sunset.
## Everything else is worked out from how high the sun is:
##   daylight 1 = full day, 0 = night. Solar panels, the sky colours, the
##   light levels and the sand glints all follow it.
## At night a dim blue "moon" light takes over, so you can just about see,
## and headlights become very useful.

@export var day_length_s: float = 480.0     ## 8 minutes per full day.
@export var time: float = 0.33              ## Start mid-morning.
@export var paused := false

var sun: DirectionalLight3D
var moon: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
## Anything with set_shader_parameter(): the world passes itself, so every
## sand tile gets the change.
var sand_material: Object
var daylight := 1.0

# Sky colours: [top, horizon] for day, dusk and night.
const DAY := [Color(0.3, 0.5, 0.82), Color(0.88, 0.8, 0.68)]
const DUSK := [Color(0.25, 0.3, 0.55), Color(0.95, 0.55, 0.3)]
const NIGHT := [Color(0.02, 0.03, 0.08), Color(0.08, 0.09, 0.15)]


func setup(p_sun: DirectionalLight3D, p_env: Environment, p_sand: Object) -> void:
	sun = p_sun
	env = p_env
	sky_mat = env.sky.sky_material
	sand_material = p_sand
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.shadow_enabled = false
	sun.get_parent().add_child(moon)
	_apply()


## The haze colour of the ring the camera is in (main.gd sets it).
var haze_tint := Color(1.0, 0.9, 0.75)   # (applied every frame in _process)


func _process(delta: float) -> void:
	if not paused:
		time = fposmod(time + delta / day_length_s, 1.0)
	_apply()


## Jump to a time of day (the base lets you wait for morning).
func skip_to(t: float) -> void:
	time = t
	_apply()


func _apply() -> void:
	if sun == null:
		return
	# Sun height: +1 at noon, -1 at midnight.
	var height := sin((time - 0.25) * TAU)
	daylight = smoothstep(-0.08, 0.25, height)
	var dusk := 1.0 - absf(clampf(height * 4.0, -1.0, 1.0))   # 1 near the horizon

	# The sun swings across the sky from east to west.
	# (Capped at 40 degrees so there are always long shadows to read the dunes by.)
	# (A low sun is what makes ruts and ripples readable: capped near 40.)
	var elevation := asin(clampf(height, -1.0, 1.0)) * 0.45
	sun.rotation = Vector3(-elevation, deg_to_rad(35.0) + (time - 0.5) * PI, 0.0)
	sun.light_energy = daylight * 1.6
	sun.light_color = Color(1.0, 0.93, 0.82).lerp(Color(1.0, 0.6, 0.35), dusk)
	sun.visible = height > -0.12
	# The moon is opposite the sun.
	moon.rotation = Vector3(deg_to_rad(-40.0), sun.rotation.y + PI, 0.0)
	moon.light_energy = (1.0 - daylight) * 0.18
	moon.visible = daylight < 0.95

	var top: Color = NIGHT[0].lerp(DAY[0], daylight).lerp(DUSK[0], dusk * 0.6)
	var horizon: Color = NIGHT[1].lerp(DAY[1], daylight).lerp(DUSK[1], dusk * 0.8)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = horizon.darkened(0.1)
	env.ambient_light_energy = lerpf(0.2, 0.6, daylight) if env.ambient_light_source == Environment.AMBIENT_SOURCE_SKY \
			else lerpf(0.15, 0.5, daylight)
	env.fog_light_color = horizon * haze_tint
	env.volumetric_fog_albedo = (Color(0.95, 0.86, 0.72) * haze_tint).lerp(Color(0.35, 0.4, 0.6), 1.0 - daylight)

	if sand_material:
		# Glints come from whichever light is up.
		var light_dir := sun.global_basis.z if daylight > 0.05 else moon.global_basis.z
		sand_material.set_shader_parameter("sun_direction", light_dir)
		sand_material.set_shader_parameter("glint_strength", lerpf(1.5, 6.0, daylight))


func is_night() -> bool:
	return daylight < 0.3


## "14:05"
func clock() -> String:
	var minutes := int(time * 24.0 * 60.0)
	return "%02d:%02d" % [minutes / 60, minutes % 60]
