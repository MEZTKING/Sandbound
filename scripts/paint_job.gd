class_name PaintJob
extends RefCounted
## The truck's paint: a body colour, a trim colour and one decal. Free to
## change in the garage (Paint tab). Like parts.gd, it's mostly DATA: add a
## colour or a decal by adding an entry.
##
## How it's drawn: every model is coloured from the shared palette. The
## truck gets its OWN copy of the model material with "use_paint" on, which
## swaps the two truck-paint squares of the palette for your colours (see
## shaders/model.gdshader). Decals are thin flat shapes stuck to the body.

## Name, colour. Chosen to sit well on sand, salt, black iron and lilac.
const COLORS := [
	["Vermilion", Color(0.74, 0.20, 0.12)],
	["Ochre", Color(0.80, 0.56, 0.16)],
	["Saffron", Color(0.93, 0.70, 0.18)],
	["Terracotta", Color(0.72, 0.38, 0.24)],
	["Bone", Color(0.90, 0.85, 0.74)],
	["Cactus", Color(0.36, 0.50, 0.30)],
	["Oasis Teal", Color(0.14, 0.50, 0.50)],
	["Dusk Indigo", Color(0.22, 0.24, 0.46)],
	["Oxblood", Color(0.42, 0.10, 0.12)],
	["Soot", Color(0.13, 0.12, 0.12)],
]

## id -> shown name. Decals are painted in the trim colour.
const DECALS := {
	"none": "None",
	"centre_stripe": "Centre stripe",
	"twin_stripes": "Twin stripes",
	"side_flash": "Side flash",
	"race_number": "Race number",
	"flames": "Flames",
	"beetle": "Beetle",
}


static func default_paint() -> Dictionary:
	return {"body": 0, "trim": 9, "decal": "centre_stripe", "number": 7}


static func body_color(paint: Dictionary) -> Color:
	return COLORS[clampi(int(paint.get("body", 0)), 0, COLORS.size() - 1)][1]


static func trim_color(paint: Dictionary) -> Color:
	return COLORS[clampi(int(paint.get("trim", 9)), 0, COLORS.size() - 1)][1]


## Paint a truck: its own material copy, and the decal shapes.
static func apply(car: Node3D, paint: Dictionary) -> void:
	# The truck's own material: made once, then only its colours change.
	# (The first version made a new one each time and looked for the shared
	# palette to swap out, which a repainted truck no longer had: repainting
	# did nothing. The customisation test caught it.)
	var mat: ShaderMaterial = car.get_meta("paint_material") if car.has_meta("paint_material") else null
	if mat == null:
		mat = Models.palette_material().duplicate()
		mat.set_shader_parameter("use_paint", true)
		car.set_meta("paint_material", mat)
	mat.set_shader_parameter("paint_color", body_color(paint))
	mat.set_shader_parameter("trim_color", trim_color(paint))
	_swap_material(car, Models.palette_material(), mat)
	var old := car.get_node_or_null("Decals")
	if old:
		old.free()
	var decals := Node3D.new()
	decals.name = "Decals"
	car.add_child(decals)
	_add_decal(decals, str(paint.get("decal", "none")), trim_color(paint), int(paint.get("number", 7)))


static func _swap_material(n: Node, from: Material, to: Material) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in mi.get_surface_override_material_count():
			if mi.get_surface_override_material(i) == from:
				mi.set_surface_override_material(i, to)
	for c in n.get_children():
		_swap_material(c, from, to)


## Where things go on the truck (its front is +Z, sides are x = +-0.5,
## the cab roof is at y = 0.46). The doors sit between the wheel arches.
const ROOF_Y := 0.462
const DOOR_X := 0.513


static func _add_decal(root: Node3D, id: String, color: Color, number: int) -> void:
	match id:
		"centre_stripe":
			_flat(root, Vector2(0.12, 0.34), Vector3(0, ROOF_Y, 0.52), color)
		"twin_stripes":
			for x in [-0.09, 0.09]:
				_flat(root, Vector2(0.04, 0.34), Vector3(x, ROOF_Y, 0.52), color)
		"side_flash":
			for s in [-1.0, 1.0]:
				_side(root, "decal_side_flash", Vector2(0.58, 0.17), s, color)
		"flames":
			for s in [-1.0, 1.0]:
				_side(root, "decal_flames", Vector2(0.58, 0.17), s, color)
		"beetle":
			_flat(root, Vector2(0.26, 0.26), Vector3(0, ROOF_Y, 0.52), color, "decal_beetle")
		"race_number":
			for s in [-1.0, 1.0]:
				var l := _number(number, color, 0.0016)
				root.add_child(l)
				l.position = Vector3(s * DOOR_X, 0.02, 0.0)
				l.rotation.y = PI / 2.0 * s
			var top := _number(number, color, 0.0022)
			root.add_child(top)
			top.position = Vector3(0, ROOF_Y, 0.52)
			top.rotation = Vector3(-PI / 2.0, PI, 0)


static func _number(number: int, color: Color, px: float) -> Label3D:
	var l := Label3D.new()
	l.text = str(clampi(number, 0, 99))
	l.font = UIKit.TITLE_FONT
	l.font_size = 96
	l.pixel_size = px
	l.modulate = color
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	return l


static func _material(color: Color, texture: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.45
	if texture != "":
		m.albedo_texture = load("res://textures/decals/%s.png" % texture)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	return m


## A flat shape lying on top of something (roof).
static func _flat(root: Node3D, size: Vector2, pos: Vector3, color: Color, texture := "") -> void:
	var mi := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = _material(color, texture)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


## A shape on a door (side = -1 left, +1 right), facing out.
static func _side(root: Node3D, texture: String, size: Vector2, side: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = _material(color, texture)
	mi.position = Vector3(side * DOOR_X, 0.02, 0.0)
	# Quads face +Z: turn them to face out of the side, front of the shape forward.
	mi.rotation.y = PI / 2.0 * side
	if side < 0.0:
		mi.scale.x = -1.0     # mirror, so the shape points forward on both sides
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
