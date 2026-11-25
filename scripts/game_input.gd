extends Node
## Every control in the game, for keyboard AND controller, in one table.
## (An "autoload": Godot creates it before anything else and every script
## can reach it by name: GameInput.prompt("brake").)
##
## Also:
##   * remembers whether you last used the keyboard or a controller, so the
##     on-screen prompts say "A" or "Space" to match (device_changed signal)
##   * rumble (controller vibration), scaled by the Rumble option
##
## Controller names are Xbox-style; Godot maps PlayStation and Switch pads to
## the same positions (A = cross = B on Switch, the bottom button).

signal device_changed(using_pad: bool)

## Gameplay and menu actions. Each: keys, pad buttons, pad axes (axis, direction).
## The driving layout was decided with an art/design review; see README.
const ACTIONS := {
	# --- Driving
	"accelerate": {"keys": [KEY_W, KEY_UP], "axes": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]]},
	"reverse": {"keys": [KEY_S, KEY_DOWN], "axes": [[JOY_AXIS_TRIGGER_LEFT, 1.0]]},
	"steer_left": {"keys": [KEY_A, KEY_LEFT], "axes": [[JOY_AXIS_LEFT_X, -1.0]]},
	"steer_right": {"keys": [KEY_D, KEY_RIGHT], "axes": [[JOY_AXIS_LEFT_X, 1.0]]},
	"brake": {"keys": [KEY_SPACE], "buttons": [JOY_BUTTON_A]},
	"reset": {"keys": [KEY_R], "buttons": [JOY_BUTTON_Y]},             # pad: hold 0.5 s
	"load_crate": {"keys": [KEY_E], "buttons": [JOY_BUTTON_X]},
	"winch": {"keys": [KEY_F], "buttons": [JOY_BUTTON_RIGHT_SHOULDER]},
	"rescue": {"keys": [KEY_H], "buttons": [JOY_BUTTON_LEFT_SHOULDER]}, # pad: hold 1 s
	"call_crate": {"keys": [KEY_C], "buttons": [JOY_BUTTON_DPAD_UP]},
	"spare": {"keys": [KEY_P], "buttons": [JOY_BUTTON_DPAD_RIGHT]},
	"workshop": {"keys": [KEY_N], "buttons": [JOY_BUTTON_DPAD_DOWN]},
	"help": {"keys": [KEY_F1], "buttons": [JOY_BUTTON_DPAD_LEFT]},
	"map": {"keys": [KEY_M], "buttons": [JOY_BUTTON_BACK]},
	"pause": {"keys": [KEY_ESCAPE], "buttons": [JOY_BUTTON_START]},
	"base_menu": {"keys": [KEY_B], "buttons": [JOY_BUTTON_B]},
	"start": {"keys": [KEY_ENTER, KEY_KP_ENTER], "buttons": [JOY_BUTTON_A, JOY_BUTTON_START]},
	# --- Camera (right stick; the right mouse button does the same)
	"cam_left": {"axes": [[JOY_AXIS_RIGHT_X, -1.0]]},
	"cam_right": {"axes": [[JOY_AXIS_RIGHT_X, 1.0]]},
	"cam_up": {"axes": [[JOY_AXIS_RIGHT_Y, -1.0]]},
	"cam_down": {"axes": [[JOY_AXIS_RIGHT_Y, 1.0]]},
	"cam_recentre": {"buttons": [JOY_BUTTON_RIGHT_STICK]},
	# --- Keyboard-only shortcuts (these live in Options on a controller)
	"graphics": {"keys": [KEY_G]},
	"tilt_shift": {"keys": [KEY_T]},
	"toggle_vsync": {"keys": [KEY_V]},
	"debug_hud": {"keys": [KEY_F3]},
	# --- Workshop
	"ws_up": {"keys": [], "buttons": [JOY_BUTTON_DPAD_UP], "axes": [[JOY_AXIS_LEFT_Y, -1.0]]},
	"ws_down": {"keys": [], "buttons": [JOY_BUTTON_DPAD_DOWN], "axes": [[JOY_AXIS_LEFT_Y, 1.0]]},
	"ws_left": {"keys": [], "buttons": [JOY_BUTTON_DPAD_LEFT], "axes": [[JOY_AXIS_LEFT_X, -1.0]]},
	"ws_right": {"keys": [], "buttons": [JOY_BUTTON_DPAD_RIGHT], "axes": [[JOY_AXIS_LEFT_X, 1.0]]},
	"ws_place": {"buttons": [JOY_BUTTON_A]},
	"ws_remove": {"buttons": [JOY_BUTTON_X]},
	"ws_files": {"buttons": [JOY_BUTTON_Y]},
	"ws_exit": {"keys": [KEY_N], "buttons": [JOY_BUTTON_B]},
	"ws_part_next": {"keys": [KEY_E], "buttons": [JOY_BUTTON_RIGHT_SHOULDER]},
	"ws_part_prev": {"keys": [KEY_Q], "buttons": [JOY_BUTTON_LEFT_SHOULDER]},
	"ws_zoom_in": {"axes": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]]},
	"ws_zoom_out": {"axes": [[JOY_AXIS_TRIGGER_LEFT, 1.0]]},
	# --- Menus: tabs (contracts / garage)
	"menu_tab_next": {"buttons": [JOY_BUTTON_RIGHT_SHOULDER]},
	"menu_tab_prev": {"buttons": [JOY_BUTTON_LEFT_SHOULDER]},
}

## What the prompts say on a controller.
const PAD_NAMES := {
	"accelerate": "RT", "reverse": "LT", "steer_left": "Left stick", "steer_right": "Left stick",
	"brake": "A", "reset": "hold Y", "load_crate": "X", "winch": "RB", "rescue": "hold LB",
	"call_crate": "D-pad Up", "spare": "D-pad Right", "workshop": "D-pad Down", "help": "D-pad Left",
	"map": "View", "pause": "Menu", "base_menu": "B", "start": "A", "cam_recentre": "R3",
	"ws_place": "A", "ws_remove": "X", "ws_files": "Y", "ws_exit": "B", "ws_part_next": "RB",
	"ws_part_prev": "LB", "ws_up": "D-pad", "ws_zoom_in": "RT", "ws_zoom_out": "LT",
}

const STICK_DEADZONE := 0.15
const TRIGGER_DEADZONE := 0.08

var using_pad := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # menus need it while paused
	setup()
	using_pad = not Input.get_connected_joypads().is_empty()


## Put every action into Godot's InputMap (Project Settings > Input Map shows
## the same thing; doing it in code keeps it all readable in one place).
func setup() -> void:
	for action in ACTIONS:
		var def: Dictionary = ACTIONS[action]
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		var axes: Array = def.get("axes", [])
		var dz := STICK_DEADZONE
		for a in axes:
			if a[0] == JOY_AXIS_TRIGGER_LEFT or a[0] == JOY_AXIS_TRIGGER_RIGHT:
				dz = TRIGGER_DEADZONE
		InputMap.add_action(action, dz)
		for key in def.get("keys", []):
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
		for b in def.get("buttons", []):
			var jb := InputEventJoypadButton.new()
			jb.button_index = b
			InputMap.action_add_event(action, jb)
		for a in axes:
			var jm := InputEventJoypadMotion.new()
			jm.axis = a[0]
			jm.axis_value = a[1]
			InputMap.action_add_event(action, jm)
	# Godot's built-in menu actions: make sure the pad works in every menu
	# (A confirms, B goes back, D-pad / left stick move between buttons).
	_add_pad("ui_accept", [JOY_BUTTON_A], [])
	_add_pad("ui_cancel", [JOY_BUTTON_B], [])
	_add_pad("ui_up", [JOY_BUTTON_DPAD_UP], [[JOY_AXIS_LEFT_Y, -1.0]])
	_add_pad("ui_down", [JOY_BUTTON_DPAD_DOWN], [[JOY_AXIS_LEFT_Y, 1.0]])
	_add_pad("ui_left", [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_add_pad("ui_right", [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])


func _add_pad(action: String, buttons: Array, axes: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for b in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = b
		if not InputMap.action_has_event(action, jb):
			InputMap.action_add_event(action, jb)
	for a in axes:
		var jm := InputEventJoypadMotion.new()
		jm.axis = a[0]
		jm.axis_value = a[1]
		if not InputMap.action_has_event(action, jm):
			InputMap.action_add_event(action, jm)


## Which device was used last decides the prompts.
func _input(event: InputEvent) -> void:
	var pad := using_pad
	if event is InputEventJoypadButton:
		pad = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.4:
		pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		pad = false
	elif event is InputEventMouseMotion and event.relative.length() > 4.0:
		pad = false
	if pad != using_pad:
		using_pad = pad
		device_changed.emit(using_pad)


## The name of the button or key for an action: "A" / "Space".
func prompt(action: String) -> String:
	if using_pad:
		return PAD_NAMES.get(action, "?")
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			# The key's name on YOUR keyboard layout (e.g. Z on a French one).
			var code: int = ev.physical_keycode
			if DisplayServer.get_name() != "headless":
				code = DisplayServer.keyboard_get_keycode_from_physical(ev.physical_keycode)
			return OS.get_keycode_string(code if code != 0 else ev.physical_keycode)
	return "?"


## Shake the controller. weak/strong: 0..1 (the two rumble motors).
func rumble(weak: float, strong: float, seconds: float) -> void:
	var scale: float = Settings.get_value("rumble")
	if scale <= 0.0:
		return
	for pad in Input.get_connected_joypads():
		Input.start_joy_vibration(pad, clampf(weak * scale, 0.0, 1.0), clampf(strong * scale, 0.0, 1.0), seconds)
