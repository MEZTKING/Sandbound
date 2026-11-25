class_name Models
extends RefCounted
## Loads the Blender models in res://models/ (made by tools/blender/make_models.py).
##
## Every model is coloured from ONE palette texture: textures/models/palette.png.
## The .glb files carry their own copy of it, but we swap in the real file here,
## so when you repaint palette.png, every model changes. The model shader
## (shaders/model.gdshader) adds roughness/metal/glow from palette_material.png,
## the corner shading baked in Blender, and desert dust. Parts with the
## "glass" material (ice, shards) get a see-through version.
##
##   Models.make("beetle")         -> a new Node3D with the beetle in it
##   Models.mesh("ant")            -> just the mesh (for MultiMesh crowds)

const PALETTE := preload("res://textures/models/palette.png")
const MATERIAL_PALETTE := preload("res://textures/models/palette_material.png")
const GRIME := preload("res://textures/models/grime.png")
const SHADER := preload("res://shaders/model.gdshader")

static var _palette_mat: ShaderMaterial
static var _glass_mat: StandardMaterial3D


static func make(model_name: String) -> Node3D:
	var scene: PackedScene = load("res://models/%s.glb" % model_name)
	var node: Node3D = scene.instantiate()
	_fix_materials(node)
	return node


## The first mesh in a model (for MultiMesh, which draws one mesh many times).
static func mesh(model_name: String) -> Mesh:
	var node := make(model_name)
	var mi := _find_mesh(node)
	var m: Mesh = mi.mesh if mi else null
	node.free()
	return m


## The one material every model shares (one shader = cheap to draw).
## Empty the shared materials (on exit, while the renderer still exists:
## see SandTerrain._exit_tree for why).
static func clear_cache() -> void:
	_palette_mat = null
	_glass_mat = null


static func palette_material() -> ShaderMaterial:
	if _palette_mat == null:
		_palette_mat = ShaderMaterial.new()
		_palette_mat.shader = SHADER
		_palette_mat.set_shader_parameter("palette", PALETTE)
		_palette_mat.set_shader_parameter("material_palette", MATERIAL_PALETTE)
		_palette_mat.set_shader_parameter("grime", GRIME)
		_palette_mat.set_shader_parameter("palette_rows", float(PALETTE.get_height()) / (PALETTE.get_width() / 8.0))
	return _palette_mat


static func glass_material() -> StandardMaterial3D:
	if _glass_mat == null:
		_glass_mat = StandardMaterial3D.new()
		_glass_mat.albedo_texture = PALETTE
		# Nearest: each part samples the middle of one flat colour square.
		_glass_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		_glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass_mat.albedo_color = Color(1, 1, 1, 0.72)
		_glass_mat.roughness = 0.08
		_glass_mat.metallic_specular = 0.9
	return _glass_mat


static func _fix_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			var glass := m != null and m.resource_name == "glass"
			mi.set_surface_override_material(i, glass_material() if glass else palette_material())
	for c in node.get_children():
		_fix_materials(c)


static func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for c in node.get_children():
		var found := _find_mesh(c)
		if found:
			return found
	return null


## Find a part of a model by its Blender object name (e.g. "leg_L0").
static func part(node: Node, part_name: String) -> Node3D:
	return node.find_child(part_name, true, false) as Node3D
