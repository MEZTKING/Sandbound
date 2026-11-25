class_name TinyFigure
extends RefCounted
## One little person, from the Blender model models/person.glb.
## Used for the driver. The crowd at base uses CrewCrowd instead, which draws
## hundreds of them in a single draw call.

static func make(color: Color, height: float) -> Node3D:
	# The Blender model is 0.3 m tall; its overalls are marked (vertex colour)
	# so this shader can paint them any colour.
	var fig := Models.make("person")
	fig.scale = Vector3.ONE * (height / 0.3)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("palette", Models.PALETTE)
	mat.set_shader_parameter("tint", color)
	_apply(fig, mat)
	return fig


const SHADER := preload("res://shaders/figure.gdshader")


static func _apply(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat
	for c in node.get_children():
		_apply(c, mat)
