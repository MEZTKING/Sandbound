class_name MapOverlay
extends CanvasLayer
## The map (M key). The picture is painted from the terrain itself: one pixel
## per 2 metres, coloured by what the ground is (dune sand, hardpan, white
## salt crust, thin grey crust, black sand, glass, shards) and shaded by
## height. Markers are drawn on top.
##
## Painting 160 x 160 = 25,600 pixels takes a moment, so it's only repainted
## when you open the map, not every frame.

var main: Node
var _picture := TextureRect.new()
var _markers := _Markers.new()
var _legend: Label

const M_PER_PX := 2.5          ## metres of ground per map pixel
const SHOWN_SIZE := 600.0      ## how big the map is on screen


func _ready() -> void:
	layer = 15
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	center.add_child(box)
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	# Keep it square: don't stretch to the (wider) legend below.
	_picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_picture)
	_markers.overlay = self
	_picture.add_child(_markers)
	_legend = Label.new()
	_legend.text = "Square = base / outpost    Letters = delivery points    Red dots = ant nests    Purple = lodestones    Orange = your cargo    Arrow = you    (M to close)\nPale = hardpan    White = thick salt crust    Grey = THIN crust: cracks under weight    Black = magnetic sand    Green = glass (slippery)    Speckled = SHARDS\nLilac = the Drift (low gravity)    Blue bands = flowing sand RIVERS"
	_legend.add_theme_font_size_override("font_size", 14)
	box.add_child(_legend)


func toggle() -> void:
	visible = not visible
	if visible:
		_paint()


func _paint() -> void:
	var t: SandTerrain = main.terrain
	var size_px := int(t.half_extent() * 2.0 / M_PER_PX)
	var img := Image.create(size_px, size_px, false, Image.FORMAT_RGB8)
	var sand := Color(0.82, 0.66, 0.44)
	var hardpan := Color(0.88, 0.8, 0.66)
	var thick := Color(0.97, 0.97, 0.95)
	var thin := Color(0.6, 0.63, 0.66)
	var black := Color(0.3, 0.3, 0.33)
	var glass_c := Color(0.25, 0.45, 0.42)
	var half := t.half_extent()
	for py in size_px:
		for px in size_px:
			var x := (px + 0.5) * M_PER_PX - half
			var z := (py + 0.5) * M_PER_PX - half
			var h := t.get_height(x, z)
			var c := sand.lerp(hardpan, t.get_hardness(x, z))
			var crust := t.get_crust(x, z)
			if crust > 0.05:
				c = c.lerp(thin.lerp(thick, smoothstep(0.4, 0.6, crust)), smoothstep(0.05, 0.15, crust))
			if t.ring_at(x, z) == 3:
				c = Color(0.78, 0.72, 0.88)
				# Rivers: blue bands (checked a little wide, so they show at this scale).
				if t.get_flow(x, z) > 0.1 or t.get_flow(x + 1.2, z) > 0.3 or t.get_flow(x, z + 1.2) > 0.3:
					c = Color(0.45, 0.65, 1.0)
			elif t.ring_at(x, z) == 2:
				c = black
				var g := t.get_glass(x, z)
				if g > SandTile.GLASS_SHEET:
					c = glass_c
				elif g > 0.25:
					c = Color(0.75, 0.85, 0.82) if (px + py) % 2 == 0 else black   # shards: speckled
			# Light from the north-west: slopes facing it are brighter.
			var slope := (t.get_height(x - M_PER_PX, z - M_PER_PX) - h) * 0.5
			c = c.darkened(clampf(slope, -0.3, 0.3)).lightened(clampf(-slope, 0.0, 0.3) * 0.5)
			img.set_pixel(px, py, c)
	_picture.texture = ImageTexture.create_from_image(img)
	_picture.custom_minimum_size = Vector2(SHOWN_SIZE, SHOWN_SIZE)
	_markers.size = _picture.custom_minimum_size
	_markers.queue_redraw()


## World x/z -> position on the map picture. Uses the picture's REAL drawn
## size (the first version assumed it and the markers ended up in the wrong
## places when the picture got stretched).
func to_map(p: Vector3) -> Vector2:
	var half: float = main.terrain.half_extent()
	var scale := _picture.size.x / (half * 2.0)
	return Vector2(p.x + half, p.z + half) * scale


class _Markers extends Control:
	var overlay: MapOverlay

	func _process(_delta: float) -> void:
		if overlay and overlay.visible:
			queue_redraw()

	func _draw() -> void:
		var m = overlay.main
		size = overlay._picture.size
		var font := ThemeDB.fallback_font
		# Ant nests and lodestones.
		for n in m.ANT_NESTS:
			draw_circle(overlay.to_map(n), 3.0, Color(0.8, 0.15, 0.1))
		for l in m.LODESTONES:
			draw_circle(overlay.to_map(l), 5.0, Color(0.6, 0.2, 0.85))
		# Delivery points (the current target is highlighted).
		for i in m.DELIVERY_SPOTS.size():
			var p: Vector2 = overlay.to_map(m.DELIVERY_SPOTS[i])
			var is_target: bool = m.has_job and m.target_index == i
			var col := Color(0.3, 0.75, 1.0) if is_target else Color(0.1, 0.25, 0.45)
			if i == 12 or i == m.GLASS_SITE_INDEX or i == m.DRIFT_SITE_INDEX:
				if not is_target:
					continue    # outpost sites: the square shows them once built
			draw_circle(p, 9.0 if is_target else 7.0, col)
			draw_string(font, p + Vector2(-5, 4), m.spot_letter(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		# Bases and outposts.
		for st in m.stations:
			var p: Vector2 = overlay.to_map(st["pos"])
			if st["built"]:
				draw_rect(Rect2(p - Vector2(8, 8), Vector2(16, 16)), Color(0.95, 0.75, 0.2))
				draw_string(font, p + Vector2(11, 5), st["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
			else:
				draw_rect(Rect2(p - Vector2(7, 7), Vector2(14, 14)), Color(0.95, 0.75, 0.2), false, 2.0)
				draw_string(font, p + Vector2(10, 5), st["name"] + " (site)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.7))
		# Your cargo.
		if m.cargo and is_instance_valid(m.cargo):
			draw_circle(overlay.to_map(m.cargo.global_position), 6.0, Color(1.0, 0.55, 0.1))
		# You: an arrow pointing the way the truck faces.
		var cp: Vector2 = overlay.to_map(m.car.global_position)
		var f: Vector3 = m.car.global_basis.z
		var dir := Vector2(f.x, f.z).normalized()
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([cp + dir * 14, cp - dir * 8 + side * 8, cp - dir * 8 - side * 8]), Color(1, 0.2, 0.2))
