class_name Workshop
extends Node
## Build mode. At base, press N (or the Workshop button in the base menu).
##
##   Left click a socket   bolt the selected part on (buys it if you have none spare)
##   Right click a part    take it off (it goes back in your parts box)
##   Right-drag / A D      orbit the camera      Mouse wheel   zoom
##   N or Esc              done
##
## The sockets light up GREEN where the selected part fits. The red ball is
## the truck's centre of mass: keep it low and in the middle for a stable
## truck, or don't, and see what happens.
##
## Builds save as small text files you can share (button: Open builds folder).

signal finished

var main: Node          # the game (main.gd), which owns money, parts and the truck
var active := false
var selected := "ballast"

var _yaw := 0.6
var _pitch := 0.45
var _dist := 3.6
var _hover := ""
var _dragging := false
var _drag_moved := 0.0
var _markers := {}                  # socket id -> MeshInstance3D
var _com_ball: MeshInstance3D
var _ui: CanvasLayer
var _palette: HBoxContainer
var _info: Label
var _stats: Label
var _mat_fit := StandardMaterial3D.new()
var _mat_no := StandardMaterial3D.new()
var _mat_hover := StandardMaterial3D.new()
# Controller: a socket "cursor" instead of the mouse.
var _cursor := "C0"
var _nav_cooldown := 0.0
var _files_popup: PanelContainer
var _hint: Label

const BUILDS_DIR := "user://builds"


func _ready() -> void:
	for m in [_mat_fit, _mat_no, _mat_hover]:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.no_depth_test = true
	_mat_fit.albedo_color = Color(0.2, 1.0, 0.3, 0.8)
	_mat_no.albedo_color = Color(1, 1, 1, 0.15)
	_mat_hover.albedo_color = Color(1.0, 0.85, 0.1, 0.95)
	for id in BuildParts.SOCKETS:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.07, 0.07, 0.07)
		mi.mesh = bm
		mi.top_level = true
		mi.visible = false
		add_child(mi)
		_markers[id] = mi
	_com_ball = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.04
	sm.height = 0.08
	_com_ball.mesh = sm
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(1, 0.15, 0.1)
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.no_depth_test = true
	_com_ball.material_override = red
	_com_ball.top_level = true
	_com_ball.visible = false
	add_child(_com_ball)
	_build_ui()


# ---------------------------------------------------------------------------
# Entering / leaving
# ---------------------------------------------------------------------------

func enter() -> void:
	active = true
	_ui.visible = true
	_files_popup.visible = false
	_set_frozen(true)
	_refresh()
	_update_hint()


func leave() -> void:
	active = false
	_ui.visible = false
	for id in _markers:
		_markers[id].visible = false
	_com_ball.visible = false
	_set_frozen(false)
	finished.emit()


## While building, the truck sits still. (The trailer isn't frozen: it
## settles onto its wheels and the hitch joint holds it in place.)
func _set_frozen(on: bool) -> void:
	main.car.hold(on)


# ---------------------------------------------------------------------------
# Placing and removing
# ---------------------------------------------------------------------------

func place(socket_id: String, part_id: String) -> bool:
	if main.build.has(socket_id):
		return false
	if not BuildParts.fits(part_id, socket_id):
		_say("A %s doesn't fit there." % BuildParts.CATALOGUE[part_id]["name"].to_lower())
		return false
	if part_id in ["winch", "hitch"] and part_id in main.build.values():
		_say("Only one %s per truck." % BuildParts.CATALOGUE[part_id]["name"].to_lower())
		return false
	if main.inventory.get(part_id, 0) > 0:
		main.inventory[part_id] -= 1
	else:
		var price: int = BuildParts.CATALOGUE[part_id]["price"]
		if main.money < price:
			_say("Not enough money ($%d)." % price)
			return false
		main.money -= price
	main.build[socket_id] = part_id
	main.crew_carry_to(main.car.to_global(BuildParts.SOCKETS[socket_id]["pos"]))
	_rebuild()
	main.car.pop_in(socket_id)      # it pops into place
	return true


func remove(socket_id: String) -> void:
	if not main.build.has(socket_id):
		return
	var part_id: String = main.build[socket_id]
	main.build.erase(socket_id)
	main.inventory[part_id] = main.inventory.get(part_id, 0) + 1
	_rebuild()


func clear_all() -> void:
	for socket_id in main.build.keys():
		remove(socket_id)


func _rebuild() -> void:
	main.apply_build()
	_set_frozen(active)
	_refresh()


# ---------------------------------------------------------------------------
# Build files (shareable)
# ---------------------------------------------------------------------------

## Save the truck's design (slot parts + build) as a little JSON file.
func save_build(slot: int) -> String:
	DirAccess.make_dir_recursive_absolute(BUILDS_DIR)
	var path := "%s/build_%d.json" % [BUILDS_DIR, slot]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "Couldn't save."
	f.store_string(JSON.stringify({"version": 1, "fitted": main.fitted, "build": main.build}, "  "))
	return "Saved build %d." % slot


## Load a design, buying whatever parts you don't already have.
func load_build(slot: int) -> String:
	var path := "%s/build_%d.json" % [BUILDS_DIR, slot]
	if not FileAccess.file_exists(path):
		return "Build %d is empty." % slot
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY or not data.has("build"):
		return "Build %d is broken." % slot
	# What would it cost? Count parts against what you own (spare + on the truck).
	var have: Dictionary = main.inventory.duplicate()
	for p in main.build.values():
		have[p] = have.get(p, 0) + 1
	var cost := 0
	var new_build := {}
	for socket_id in data["build"]:
		var part_id: String = data["build"][socket_id]
		if not BuildParts.CATALOGUE.has(part_id) or not BuildParts.SOCKETS.has(socket_id) \
				or not BuildParts.fits(part_id, socket_id):
			continue
		new_build[socket_id] = part_id
		if have.get(part_id, 0) > 0:
			have[part_id] -= 1
		else:
			cost += BuildParts.CATALOGUE[part_id]["price"]
	var new_fitted := {}
	for slot_name in Parts.SLOTS:
		var id: String = data.get("fitted", {}).get(slot_name, main.fitted[slot_name])
		if not Parts.CATALOGUE[slot_name].has(id):
			id = main.fitted[slot_name]
		new_fitted[slot_name] = id
		if not id in main.owned[slot_name]:
			cost += Parts.get_part(slot_name, id)["price"]
	if cost > main.money:
		return "That build needs $%d of parts you don't have." % cost
	# Pay, then swap: everything on the truck goes in the box, the new build comes out.
	main.money -= cost
	for slot_name in new_fitted:
		if not new_fitted[slot_name] in main.owned[slot_name]:
			main.owned[slot_name].append(new_fitted[slot_name])
	main.fitted = new_fitted
	main.inventory = have
	main.build = new_build
	_rebuild()
	return "Loaded build %d%s." % [slot, " (bought parts: $%d)" % cost if cost > 0 else ""]


# ---------------------------------------------------------------------------
# Camera, picking, markers
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if not active:
		return
	var car: RCCar = main.car
	var target := car.global_position + Vector3(0, 0.15, -0.3)
	var off := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _dist
	var cam: Camera3D = main.camera
	cam.global_position = target + car.global_basis * off
	cam.look_at(target)
	var pad: bool = GameInput.using_pad
	if pad and not _files_popup.visible:
		_pad_controls(_delta)
	# Markers on every socket: green = the selected part fits, yellow = hover.
	var mouse := get_viewport().get_mouse_position()
	_hover = ""
	var best := 28.0
	for id in BuildParts.SOCKETS:
		var s: Dictionary = BuildParts.SOCKETS[id]
		var p := car.to_global(s["pos"] + Vector3(s["normal"]) * 0.05)
		var mi: MeshInstance3D = _markers[id]
		mi.global_position = p
		var occupied: bool = main.build.has(id)
		mi.visible = not occupied
		if not cam.is_position_behind(p):
			var d := cam.unproject_position(p).distance_to(mouse)
			if d < best:
				best = d
				_hover = id
		mi.material_override = _mat_fit if BuildParts.fits(selected, id) else _mat_no
	if pad:
		_hover = _cursor
		# Occupied sockets have no marker: show the cursor anyway.
		_markers[_cursor].visible = true
	if _hover != "" and _markers[_hover].visible:
		_markers[_hover].material_override = _mat_hover
	_com_ball.visible = true
	_com_ball.global_position = car.to_global(car.center_of_mass)
	_show_hover_info()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_dist = maxf(1.6, _dist - 0.25)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_dist = minf(8.0, _dist + 0.25)
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _hover != "":
			if not main.build.has(_hover):
				if place(_hover, selected):
					_say("Bolted on: %s" % BuildParts.CATALOGUE[selected]["name"])
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_dragging = true
				_drag_moved = 0.0
			else:
				_dragging = false
				if _drag_moved < 5.0 and _hover != "" and main.build.has(_hover):
					_say("Removed: %s (back in the parts box)" % BuildParts.CATALOGUE[main.build[_hover]]["name"])
					remove(_hover)
	elif event is InputEventMouseMotion and _dragging:
		_drag_moved += event.relative.length()
		_yaw -= event.relative.x * 0.01
		_pitch = clampf(_pitch + event.relative.y * 0.01, -0.2, 1.3)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_A, KEY_LEFT:
				_yaw += 0.3
			KEY_D, KEY_RIGHT:
				_yaw -= 0.3
			KEY_Q, KEY_E:
				var ids := BuildParts.CATALOGUE.keys()
				selected = ids[posmod(ids.find(selected) + (1 if event.physical_keycode == KEY_E else -1), ids.size())]
				_refresh()
	if event.is_action_pressed("ws_exit") and not _files_popup.visible:
		leave()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and _files_popup.visible:
		_files_popup.visible = false
		get_viewport().set_input_as_handled()


## Controller: move the socket cursor, orbit, zoom, pick parts, place/remove.
func _pad_controls(delta: float) -> void:
	# Right stick orbits, triggers zoom.
	var stick := Vector2(Input.get_axis("cam_left", "cam_right"), Input.get_axis("cam_up", "cam_down"))
	_yaw -= stick.x * 2.2 * delta
	_pitch = clampf(_pitch + stick.y * 1.6 * delta, -0.2, 1.3)
	_dist = clampf(_dist + (Input.get_action_strength("ws_zoom_out") - Input.get_action_strength("ws_zoom_in")) * 3.0 * delta, 1.6, 8.0)
	# D-pad / left stick: jump to the nearest socket in that direction on screen.
	_nav_cooldown -= delta
	var dir := Vector2.ZERO
	for a in [["ws_left", Vector2.LEFT], ["ws_right", Vector2.RIGHT], ["ws_up", Vector2.UP], ["ws_down", Vector2.DOWN]]:
		if Input.is_action_just_pressed(a[0]) or (Input.is_action_pressed(a[0]) and _nav_cooldown <= 0.0):
			dir = a[1]
	if dir != Vector2.ZERO:
		_nav_cooldown = 0.28
		_move_cursor(dir)
	elif stick.length() < 0.1:
		_frame_cursor(delta)
	if Input.is_action_just_pressed("ws_part_next") or Input.is_action_just_pressed("ws_part_prev"):
		var ids := BuildParts.CATALOGUE.keys()
		var k := ids.find(selected) + (1 if Input.is_action_just_pressed("ws_part_next") else -1)
		selected = ids[posmod(k, ids.size())]
		_refresh()
	if Input.is_action_just_pressed("ws_place") and not main.build.has(_cursor):
		if place(_cursor, selected):
			_say("Bolted on: %s" % BuildParts.CATALOGUE[selected]["name"])
	if Input.is_action_just_pressed("ws_remove") and main.build.has(_cursor):
		_say("Removed: %s (back in the parts box)" % BuildParts.CATALOGUE[main.build[_cursor]]["name"])
		remove(_cursor)
	if Input.is_action_just_pressed("ws_files"):
		_files_popup.visible = true
		UIKit.focus_first(_files_popup)


func _move_cursor(dir: Vector2) -> void:
	var cam: Camera3D = main.camera
	var car: RCCar = main.car
	var here := cam.unproject_position(car.to_global(BuildParts.SOCKETS[_cursor]["pos"]))
	var best := ""
	var best_score := INF
	for id in BuildParts.SOCKETS:
		if id == _cursor:
			continue
		var p := car.to_global(BuildParts.SOCKETS[id]["pos"])
		if cam.is_position_behind(p):
			continue
		var d := cam.unproject_position(p) - here
		var along := d.dot(dir)
		if along <= 4.0:
			continue
		var score := along + absf(d.dot(Vector2(-dir.y, dir.x))) * 2.0   # prefer straight ahead
		if score < best_score:
			best_score = score
			best = id
	if best != "":
		_cursor = best


## Swing the camera round to face the selected socket.
func _frame_cursor(delta: float) -> void:
	var n: Vector3 = BuildParts.SOCKETS[_cursor]["normal"]
	var t := 1.0 - exp(-3.0 * delta)
	if absf(n.y) < 0.5:
		_yaw = lerp_angle(_yaw, atan2(n.x, n.z), t)
		_pitch = lerpf(_pitch, 0.45, t)
	else:
		_pitch = lerpf(_pitch, 1.1 if n.y > 0.0 else -0.15, t)


func _update_hint() -> void:
	if _hint == null:
		return
	if GameInput.using_pad:
		_hint.text = "D-pad / left stick: pick a socket   A: bolt on   X: remove   LB / RB: choose part   Right stick: orbit   LT / RT: zoom   Y: save / load   B: done   (red ball = centre of mass)"
	else:
		_hint.text = "Left click: bolt on   Right click: remove   Right-drag / A D: orbit   Wheel: zoom   Q / E: choose part   N: done   (red ball = centre of mass)"


func _show_hover_info() -> void:
	if _hover != "" and main.build.has(_hover):
		var part: Dictionary = BuildParts.CATALOGUE[main.build[_hover]]
		_info.text = "%s at %s. Right-click to remove." % [part["name"], _hover]
	else:
		var part: Dictionary = BuildParts.CATALOGUE[selected]
		_info.text = "%s ($%d, %d kg): %s" % [part["name"], part["price"], int(part["mass"]), part["desc"]]


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 9
	_ui.visible = false
	add_child(_ui)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_ui.add_child(margin)
	var root := VBoxContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var title := _label("WORKSHOP", 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_stats = _label("", 16)
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_stats)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(spacer)

	_info = _label("", 16)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info.add_theme_color_override("font_color", Color(1, 0.9, 0.7))
	root.add_child(_info)

	_palette = HBoxContainer.new()
	_palette.add_theme_constant_override("separation", 6)
	root.add_child(_palette)

	var files := HBoxContainer.new()
	files.add_theme_constant_override("separation", 6)
	root.add_child(files)
	for n in 3:
		files.add_child(_button("Save %d" % (n + 1), func(): _say(save_build(n + 1))))
	for n in 3:
		files.add_child(_button("Load %d" % (n + 1), func(): _say(load_build(n + 1))))
	files.add_child(_button("Open builds folder", func():
		DirAccess.make_dir_recursive_absolute(BUILDS_DIR)
		OS.shell_open(ProjectSettings.globalize_path(BUILDS_DIR))))
	files.add_child(_button("Clear build", clear_all))
	files.add_child(_button("Done", leave))
	_hint = _label("", 14)
	root.add_child(_hint)
	GameInput.device_changed.connect(func(_p): _update_hint())
	# Controller: save / load builds in a little popup (Y).
	_files_popup = UIKit.panel(Vector2(360, 0))
	_files_popup.visible = false
	var pop_center := CenterContainer.new()
	pop_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pop_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(pop_center)
	pop_center.add_child(_files_popup)
	var pop := VBoxContainer.new()
	pop.add_theme_constant_override("separation", 8)
	_files_popup.add_child(pop)
	pop.add_child(UIKit.label("BUILDS", 24, UIKit.ACCENT))
	for n in 3:
		var row := HBoxContainer.new()
		row.add_child(UIKit.button("Load %d" % (n + 1), func():
			_say(load_build(n + 1))
			_files_popup.visible = false, 18))
		row.add_child(UIKit.button("Save %d" % (n + 1), func():
			_say(save_build(n + 1))
			_files_popup.visible = false, 18))
		pop.add_child(row)
	pop.add_child(UIKit.button("Close", func(): _files_popup.visible = false, 18))


func _refresh() -> void:
	for c in _palette.get_children():
		c.queue_free()
	for id in BuildParts.CATALOGUE:
		var part: Dictionary = BuildParts.CATALOGUE[id]
		var spare: int = main.inventory.get(id, 0)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.button_pressed = id == selected
		b.text = "%s\n%s" % [part["name"], "%d spare" % spare if spare > 0 else "$%d" % part["price"]]
		b.custom_minimum_size = Vector2(150, 50)
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(func():
			selected = id
			_refresh())
		_palette.add_child(b)
	var car: RCCar = main.car
	var com: Vector3 = car.center_of_mass
	var side := "centred" if absf(com.x) < 0.02 else ("%d cm %s" % [int(absf(com.x) * 100), "right" if com.x > 0 else "left"])
	var warn := ""
	if absf(com.x) > 0.06:
		warn = "\nLopsided: it will lean and tip that way!"
	elif com.y > -0.15:
		warn = "\nTop-heavy: easier to roll over."
	_stats.text = "$%d   Mass %d kg   Centre of mass: %s, %d cm %s, %d cm below the deck%s" % [
		main.money, int(car.mass), side, int(absf(com.z) * 100), "forward" if com.z > 0 else "back",
		int((0.125 - com.y) * 100), warn]


func _say(text: String) -> void:
	main.show_message(text)
	_refresh()


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE     # mouse only: on a pad, A bolts parts on
	b.text = text
	b.add_theme_font_size_override("font_size", 14)
	b.pressed.connect(cb)
	return b
