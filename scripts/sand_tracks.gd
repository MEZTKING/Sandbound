class_name SandTracks
extends SubViewport
## High-detail tracks in the sand, drawn on the GPU.
##
## The physics sand grid has a point every 25 cm. That's fine for how the truck
## sinks, but far too coarse for a tyre tread. So there's a second, much finer
## layer just for looks: a big image covering the whole desert (4096 x 4096
## = 1.6 cm per pixel) that only the graphics card touches.
##
## Wheels, feet and crates STAMP small hand-painted images into it:
##   red   = how much the sand is pressed down
##   green = sand pushed up at the edges
## The sand shader reads it to add the tread pattern, the lighting bumps and
## the packed-sand colour.
##
## The trick that makes it cheap: this is a SubViewport (a hidden screen) that
## is never cleared. Each frame we only draw the NEW stamps on top of what's
## already there, with "add" blending. Nothing is ever redrawn.

## The stamp images. Repaint them in textures/stamps/.
const TYRE := preload("res://textures/stamps/tyre_tread.png")
const BEETLE_FEET := preload("res://textures/stamps/beetle_feet.png")
const CRATE := preload("res://textures/stamps/crate.png")

var world_size_m := 64.0
var _painter := _Painter.new()
var _eraser := _Eraser.new()


func setup(size_m: float, resolution: int) -> void:
	world_size_m = size_m
	size = Vector2i(resolution, resolution)
	disable_3d = true
	transparent_bg = true
	use_hdr_2d = true                          # 16-bit precision: stamps add up smoothly
	render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE   # clear once, then never
	render_target_update_mode = SubViewport.UPDATE_ONCE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_painter.material = mat
	_painter.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_painter)
	# The eraser subtracts a little from EVERY pixel: wind smoothing tracks away.
	var sub := CanvasItemMaterial.new()
	sub.blend_mode = CanvasItemMaterial.BLEND_MODE_SUB
	_eraser.material = sub
	add_child(_eraser)


## Press a stamp into the sand.
##   world_pos: centre of the stamp
##   forward:   which way the stamp's "down the image" direction points
##   size_m:    stamp size in metres (across, along)
##   strength:  how much to add (several overlapping stamps add up)
func stamp(tex: Texture2D, world_pos: Vector3, forward: Vector3, size_m: Vector2, strength: float) -> void:
	var px_per_m := size.x / world_size_m
	var half := world_size_m * 0.5
	var pos := Vector2(world_pos.x + half, world_pos.z + half) * px_per_m
	# Image x = world x, image y = world z. Rotate so the image's +y points
	# along `forward`.
	var angle := atan2(-forward.x, forward.z)
	_painter.stamps.append([tex, pos, angle, size_m * px_per_m, strength])
	_painter.queue_redraw()
	# Render this viewport once more this frame to bake the new stamps in.
	render_target_update_mode = SubViewport.UPDATE_ONCE


## Fade every track a little (wind blowing sand over them). 0.02 = 2%.
## The shader ignores anything that goes below zero.
func fade(amount: float) -> void:
	_eraser.amount += amount
	_eraser.queue_redraw()
	render_target_update_mode = SubViewport.UPDATE_ONCE


## Godot keeps a node's drawing until it's asked to redraw. If we left the
## eraser's rectangle (or the painter's stamps) there, the NEXT time the
## viewport renders for some other reason they'd be applied again. So after
## drawing, each one redraws itself empty on the next frame.
class _Eraser extends Node2D:
	var amount := 0.0
	var _dirty := false

	func _draw() -> void:
		if amount > 0.0:
			var vp := get_viewport() as SubViewport
			draw_rect(Rect2(Vector2.ZERO, vp.size), Color(amount, amount, 0.0, 1.0))
			_dirty = true
		amount = 0.0

	func _process(_delta: float) -> void:
		if _dirty and amount == 0.0:
			_dirty = false
			queue_redraw()   # draws nothing: wipes the old rectangle


## Draws the queued stamps once, then forgets them. Because the viewport only
## re-renders when there are new stamps, each stamp is added exactly once.
class _Painter extends Node2D:
	var stamps: Array = []
	var _dirty := false

	func _process(_delta: float) -> void:
		if _dirty and stamps.is_empty():
			_dirty = false
			queue_redraw()   # draws nothing: wipes the old stamps

	func _draw() -> void:
		_dirty = not stamps.is_empty()
		for s in stamps:
			draw_set_transform(s[1], s[2], Vector2.ONE)
			var sz: Vector2 = s[3]
			draw_texture_rect(s[0], Rect2(-sz * 0.5, sz), false, Color(1, 1, 1, s[4]))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		stamps.clear()
