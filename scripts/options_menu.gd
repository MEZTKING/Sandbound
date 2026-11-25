class_name OptionsMenu
extends VBoxContainer
## The Options page (used from the title screen and the pause menu). Every
## change is applied and saved at once (Settings autoload). Works with a
## controller: D-pad to move, left/right to change a slider, A to toggle.

signal back


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	add_child(UIKit.label("OPTIONS", 30, UIKit.ACCENT))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	add_child(grid)
	_choice(grid, "Display mode", "display_mode", Settings.DISPLAY_MODES)
	_slider(grid, "Resolution scale", "render_scale", 0.5, 1.0, 0.1, true)
	_toggle(grid, "V-Sync", "vsync")
	_choice(grid, "FPS cap", "fps_cap", ["Off", "30", "60", "120"])
	_choice(grid, "Graphics quality", "quality", Settings.QUALITY_NAMES)
	_toggle(grid, "Tilt-shift blur", "tilt_shift")
	_slider(grid, "Master volume", "master_volume", 0.0, 1.0, 0.1, true)
	_slider(grid, "Music volume", "music_volume", 0.0, 1.0, 0.1, true)
	_slider(grid, "Sound effects volume", "sfx_volume", 0.0, 1.0, 0.1, true)
	_slider(grid, "Camera sensitivity", "camera_sensitivity", 1, 10, 1, false)
	_toggle(grid, "Invert camera X", "invert_x")
	_toggle(grid, "Invert camera Y", "invert_y")
	_toggle(grid, "Camera shake", "camera_shake")
	_slider(grid, "Rumble", "rumble", 0.0, 1.0, 0.25, true)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	row.add_child(UIKit.button("Reset to defaults", func():
		Settings.reset_to_defaults()
		_refresh_all(), 18))
	row.add_child(UIKit.button("Back", func(): back.emit(), 18))


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back.emit()


var _refreshers: Array[Callable] = []


func _refresh_all() -> void:
	for f in _refreshers:
		f.call()


func _row_label(grid: GridContainer, text: String) -> void:
	grid.add_child(UIKit.label(text, 18))


func _choice(grid: GridContainer, text: String, key: String, names: Array) -> void:
	_row_label(grid, text)
	var o := OptionButton.new()
	for n in names:
		o.add_item(str(n))
	o.custom_minimum_size.x = 260
	o.add_theme_font_size_override("font_size", 18)
	UIKit.style_focus(o)
	o.selected = int(Settings.get_value(key))
	o.item_selected.connect(func(i): Settings.set_value(key, i))
	_refreshers.append(func(): o.selected = int(Settings.get_value(key)))
	grid.add_child(o)


func _toggle(grid: GridContainer, text: String, key: String) -> void:
	_row_label(grid, text)
	var c := CheckButton.new()
	c.button_pressed = bool(Settings.get_value(key))
	UIKit.style_focus(c)
	c.toggled.connect(func(on): Settings.set_value(key, on))
	_refreshers.append(func(): c.set_pressed_no_signal(bool(Settings.get_value(key))))
	grid.add_child(c)


func _slider(grid: GridContainer, text: String, key: String, lo: float, hi: float, step: float, percent: bool) -> void:
	_row_label(grid, text)
	var row := HBoxContainer.new()
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(200, 28)
	s.value = float(Settings.get_value(key))
	UIKit.style_focus(s)
	var v := UIKit.label("", 16)
	v.custom_minimum_size.x = 56
	var show := func():
		var x: float = s.value
		v.text = ("%d%%" % int(round(x * 100.0))) if percent else str(int(x))
	show.call()
	s.value_changed.connect(func(x):
		Settings.set_value(key, x if percent or step < 1.0 else int(x))
		show.call())
	_refreshers.append(func():
		s.set_value_no_signal(float(Settings.get_value(key)))
		show.call())
	row.add_child(s)
	row.add_child(v)
	grid.add_child(row)
