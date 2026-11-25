class_name SandDust
extends RefCounted
## Sand spray and dust puffs, using GPU particles (the graphics card moves
## every particle, so hundreds cost almost nothing).
##
## Particles are little camera-facing squares textured with
## textures/particles/dust_puff.png (repaint it!). They're tinted sand colour,
## grow, slow down, fall and fade out.

const PUFF := preload("res://textures/particles/dust_puff.png")
const SAND_TINT := Color(0.82, 0.68, 0.5)


## A continuous spray behind a wheel. Set `amount_ratio` (0..1) every frame
## to control how much it sprays.
static func make_wheel_spray() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 64
	p.lifetime = 1.3
	p.local_coords = false          # particles stay in the world, not stuck to the truck
	p.amount_ratio = 0.0
	p.draw_pass_1 = _puff_mesh()
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, 0.7, -1)   # backwards (the truck's front is +Z) and up
	m.spread = 25.0
	m.initial_velocity_min = 0.4
	m.initial_velocity_max = 1.6
	m.gravity = Vector3(0, -1.2, 0)     # fine dust falls slowly
	m.damping_min = 0.8
	m.damping_max = 1.6
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.08
	_set_look(m, 0.12, 0.45, 0.55)
	p.process_material = m
	return p


## A one-off burst (crate landing, beetle slam). Adds itself to `parent`,
## plays once, and deletes itself.
static func burst(parent: Node, pos: Vector3, strength: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = int(clampf(16 + strength * 12, 16, 64))
	p.lifetime = 1.6
	p.one_shot = true
	p.explosiveness = 0.9
	p.local_coords = false
	p.draw_pass_1 = _puff_mesh()
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 75.0
	m.initial_velocity_min = 0.3 * strength
	m.initial_velocity_max = 0.9 * strength
	m.gravity = Vector3(0, -1.5, 0)
	m.damping_min = 1.0
	m.damping_max = 2.0
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.25
	_set_look(m, 0.2, 0.7, 0.6)
	p.process_material = m
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)


static func _set_look(m: ParticleProcessMaterial, size_min: float, size_max: float, alpha: float) -> void:
	m.scale_min = size_min
	m.scale_max = size_max
	# Grow over the particle's life (dust spreads out)...
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 1.6))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	m.scale_curve = grow_tex
	# ...and fade out.
	var fade := Gradient.new()
	fade.set_color(0, Color(SAND_TINT, alpha))
	fade.set_color(1, Color(SAND_TINT, 0.0))
	var fade_tex := GradientTexture1D.new()
	fade_tex.gradient = fade
	m.color_ramp = fade_tex
	m.angle_min = 0.0
	m.angle_max = 360.0


static func _puff_mesh() -> QuadMesh:
	var q := QuadMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = PUFF
	mat.vertex_color_use_as_albedo = true      # takes the tint/fade from the particle
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.proximity_fade_enabled = true          # no hard line where it meets the sand
	mat.proximity_fade_distance = 0.3
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = mat
	return q
