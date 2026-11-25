class_name CrewCrowd
extends MultiMeshInstance3D
## Hundreds of tiny crew members at a base, drawn with ONE MultiMesh.
##
## Optimisation lesson: 300 separate MeshInstance3D nodes = 300 draw calls.
## A MultiMesh sends one mesh + a list of transforms to the GPU = 1 draw call.
## The mesh is the Blender model (models/person.glb). Each person gets their
## own overall colour and hops, all in the shader (shaders/figure.gdshader),
## using the instance number: no CPU work at all.

@export var count: int = 300
@export var radius: float = 7.0


## The crew gather in GROUPS around props (tents, toolboxes, crates,
## barrels) instead of standing evenly spread: clusters with gaps between
## them read as "people doing things". A few stand at the pad's edge,
## watching the truck.
const PROPS := ["prop_tent", "prop_toolbox", "crate", "barrel", "prop_toolbox", "prop_tent", "crate"]


func setup(terrain: SandTerrain, center: Vector3, keep_clear: float) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = TinyFigure.SHADER
	mat.set_shader_parameter("palette", Models.PALETTE)
	mat.set_shader_parameter("crowd", true)
	material_override = mat

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Models.mesh("person")
	mm.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Where the groups are: spread round the pad, with a little randomness.
	var groups := maxi(4, count / 40)
	var spots: Array[Vector3] = []
	for g in groups:
		var a := (g + rng.randf_range(-0.25, 0.25)) * TAU / groups
		var d := rng.randf_range(keep_clear + 1.8, radius - 0.8)
		var p := Vector3(center.x + cos(a) * d, 0, center.z + sin(a) * d)
		p.y = terrain.get_height(p.x, p.z)
		spots.append(p)
		var prop_name: String = PROPS[g % PROPS.size()]
		var prop := Models.make(prop_name)
		add_child(prop)
		prop.global_position = p
		prop.rotation.y = rng.randf() * TAU
		if prop_name == "crate":
			prop.global_position.y += 0.2     # cargo models are centred on their middle
		elif prop_name == "barrel":
			prop.global_position.y += 0.25
	var watchers := count / 7
	for n in count:
		var x: float
		var z: float
		var look: Vector3
		if n < watchers:
			# Watching the pad from its edge.
			var a := rng.randf() * TAU
			var d := keep_clear + rng.randf_range(0.2, 0.9)
			x = center.x + cos(a) * d
			z = center.z + sin(a) * d
			look = center
		else:
			# Gathered round a prop, facing it.
			var spot := spots[n % groups]
			var a := rng.randf() * TAU
			var d := rng.randf_range(0.55, 1.6)
			x = spot.x + cos(a) * d
			z = spot.z + sin(a) * d
			look = spot
		var y := terrain.get_height(x, z)
		# Face the prop or the pad. (Model front = +Z.)
		var basis := Basis.looking_at(Vector3(look.x - x, 0, look.z - z), Vector3.UP, true)
		mm.set_instance_transform(n, Transform3D(basis, Vector3(x, y, z)))
	multimesh = mm
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
