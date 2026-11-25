class_name UIKit
extends RefCounted
## Small helpers so every menu looks the same and works with a controller:
## buttons show a clear highlight when they're selected ("focused") with the
## D-pad, and every menu can put the focus on its first button.

const ACCENT := Color(1.0, 0.75, 0.35)


static func panel(min_size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.085, 0.07, 0.95)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(22)
	p.add_theme_stylebox_override("panel", style)
	return p


static func label(text: String, size: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, cb: Callable, size := 22) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(320, 46)
	style_focus(b)
	b.pressed.connect(cb)
	return b


## A thick orange outline on the focused control, so pad users always see
## where they are.
static func style_focus(c: Control) -> void:
	var f := StyleBoxFlat.new()
	f.draw_center = false
	f.border_color = ACCENT
	f.set_border_width_all(3)
	f.set_corner_radius_all(6)
	f.set_expand_margin_all(2)
	c.add_theme_stylebox_override("focus", f)


## Full-screen dark backdrop + centred box: the layout every menu uses.
static func backdrop(layer_node: CanvasLayer, alpha := 0.65) -> CenterContainer:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, alpha)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer_node.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer_node.add_child(center)
	return center


## Focus the first focusable control inside `root` (call when a menu opens).
static func focus_first(root: Node) -> void:
	var c := _first_focusable(root)
	if c:
		c.grab_focus.call_deferred()


static func _first_focusable(n: Node) -> Control:
	if n is Control and (n as Control).focus_mode == Control.FOCUS_ALL and (n as Control).is_visible_in_tree():
		return n
	for child in n.get_children():
		var found := _first_focusable(child)
		if found:
			return found
	return null
