extends Node
## The Options: loaded from and saved to user://settings.cfg, applied at once.
## (An autoload: reach it from anywhere as Settings.get_value("vsync").)
##
## To add an option: add a default below, then handle it in apply() and give
## it a row in options_menu.gd.

signal changed

const PATH := "user://settings.cfg"
const DISPLAY_MODES := ["Borderless fullscreen", "Windowed", "Exclusive fullscreen"]
const QUALITY_NAMES := ["Low", "Medium", "High"]
const FPS_CAPS := [0, 30, 60, 120]      # 0 = no cap

const DEFAULTS := {
	"display_mode": 0,          # index into DISPLAY_MODES
	"render_scale": 1.0,        # 0.5 .. 1.0 (lower = faster, blurrier)
	"vsync": true,
	"fps_cap": 0,               # index into FPS_CAPS
	"quality": 1,               # 0 Low, 1 Medium, 2 High
	"tilt_shift": true,
	"master_volume": 0.8,
	"music_volume": 0.7,
	"sfx_volume": 1.0,
	"camera_sensitivity": 5,    # 1 .. 10
	"invert_x": false,
	"invert_y": false,
	"camera_shake": true,
	"rumble": 1.0,              # 0 = off
	"tutorial_tips": true,      # Old Pip's tips
}

var values := {}
var first_run := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_audio_buses()
	load_settings()
	apply()


func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS[key])


func set_value(key: String, value: Variant) -> void:
	values[key] = value
	apply()
	save_settings()
	changed.emit()


func reset_to_defaults() -> void:
	values = DEFAULTS.duplicate()
	_device_defaults()
	apply()
	save_settings()
	changed.emit()


func load_settings() -> void:
	values = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		first_run = true
		_device_defaults()
		return
	for key in DEFAULTS:
		values[key] = cfg.get_value("options", key, DEFAULTS[key])


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in values:
		cfg.set_value("options", key, values[key])
	cfg.save(PATH)


## First launch on a small screen like the Steam Deck (1280 x 800): lighter
## settings so it runs smoothly on battery.
func _device_defaults() -> void:
	var screen := DisplayServer.screen_get_size()
	if screen.x > 0 and screen.x <= 1280 and screen.y <= 800:
		values["quality"] = 1
		values["render_scale"] = 0.8


## Separate volume sliders need separate audio "buses": Music and SFX both
## feed the Master bus.
func _make_audio_buses() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")


func apply() -> void:
	# Display mode (not while running headless tests: there's no window).
	if DisplayServer.get_name() != "headless" and not Engine.is_editor_hint():
		match int(get_value("display_mode")):
			0: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			1: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			2: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		DisplayServer.window_set_vsync_mode(
				DisplayServer.VSYNC_ENABLED if get_value("vsync") else DisplayServer.VSYNC_DISABLED)
		# Render the 3D world at a lower resolution and upscale it (FSR):
		# the menus and text stay sharp.
		var vp := get_tree().root
		var scale: float = get_value("render_scale")
		vp.scaling_3d_scale = scale
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2 if scale < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
	Engine.max_fps = FPS_CAPS[clampi(int(get_value("fps_cap")), 0, FPS_CAPS.size() - 1)]
	_set_volume("Master", get_value("master_volume"))
	_set_volume("Music", get_value("music_volume"))
	_set_volume("SFX", get_value("sfx_volume"))


func _set_volume(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(i, v <= 0.001)
