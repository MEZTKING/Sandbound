@tool
extends MeshInstance3D
## A 4 m patch of sand with two tyre ruts and a strip of hardpan crust on
## the right, drawn IN THE EDITOR with the real sand material. Open tools/sand_preview.tscn, then paint your textures:
## every time you save a PNG and click back into Godot, this updates.
##
## It feeds the shader heights and hardness exactly like the real terrain
## (textures that lift a flat grid), so what you see here is what you get
## in the game.

@export var size_m: float = 4.0
@export var resolution: int = 128
@export var rut_depth_m: float = 0.08
## Tick this box to rebuild after changing the settings above.
@export var rebuild: bool = false:
	set(v):
		if is_inside_tree():
			_build()


func _ready() -> void:
	material_override = load("res://materials/sand_material.tres")
	_build()


## Height (m) of the test patch at x, z: flat sand with two tyre ruts running
## along z, each with a little ridge of pushed-up sand beside it.
func _shape(x: float) -> Vector2:
	var packed := 0.0
	var piled := 0.0
	for track_x in [-0.6, 0.6]:
		var d := absf(x - track_x)
		packed = maxf(packed, (1.0 - smoothstep(0.08, 0.16, d)) * rut_depth_m)
		piled = maxf(piled, (1.0 - absf(d - 0.22) / 0.07) * rut_depth_m * 0.4)
	return Vector2(packed, maxf(piled, 0.0))


func _build() -> void:
	# Like the real terrain: a FLAT grid, and textures holding the heights
	# (and hardness) that the sand shader lifts it with.
	var n := resolution + 1
	var step := size_m / resolution
	var h := PackedFloat32Array()        # heights, in "cells" (like the terrain)
	var orig := PackedFloat32Array()
	var surf := PackedByteArray()
	var verts := PackedVector3Array()
	for j in n:
		for i in n:
			var x := -size_m * 0.5 + i * step
			var z := -size_m * 0.5 + j * step
			var sh := _shape(x)
			h.append((sh.y - sh.x) / step)
			orig.append(0.0)
			# Hardpan on the right-hand strip shows your crust textures.
			surf.append_array([int(smoothstep(1.1, 1.5, x) * 255.0), 0, 0, 255])
			verts.append(Vector3(x, 0.0, z))
	var idx := PackedInt32Array()
	for j in resolution:
		for i in resolution:
			var a := j * n + i
			idx.append_array([a, a + 1, a + n, a + 1, a + n + 1, a + n])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = m
	custom_aabb = AABB(Vector3(-size_m, -1, -size_m), Vector3(size_m * 2, 2, size_m * 2))
	var mat: ShaderMaterial = load("res://materials/sand_material.tres").duplicate()
	mat.set_shader_parameter("height_map", ImageTexture.create_from_image(Image.create_from_data(n, n, false, Image.FORMAT_RF, h.to_byte_array())))
	mat.set_shader_parameter("original_map", ImageTexture.create_from_image(Image.create_from_data(n, n, false, Image.FORMAT_RF, orig.to_byte_array())))
	mat.set_shader_parameter("surface_map", ImageTexture.create_from_image(Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, surf)))
	mat.set_shader_parameter("tile_origin", Vector2.ZERO)
	mat.set_shader_parameter("cell_size", step)
	mat.set_shader_parameter("half_cells", resolution * 0.5)
	material_override = mat
