extends Node3D
## Builds the world and runs the game loop (plus day and night, wind, a hawk,
## the story, and sound):
##   at base: pick a contract, fit parts (B opens the base menu)
##   -> the crew loads the cargo -> drive to the beacon -> settle it in the ring
##   -> get paid (less if damaged) -> drive back to base (recharge) -> repeat.
##
## Everything is created in code so you can read the whole game top to bottom.
##
## Dropped the crate? It leaves a dent, gets damaged by hard knocks (less pay),
## and a marker shows where it is. Drive next to it and press E to load it.

const BASE_POS := Vector3(0, 0, 20)
const BASE_RADIUS := 3.0
## Delivery points A-F (Home Dunes), G-L (Salt Flats), M-R (Glass Desert),
## S-X (the Drift), and the three outpost sites (12, 19 and 26).
const DELIVERY_SPOTS: Array[Vector3] = [
	Vector3(-12, 0, -16),   # A
	Vector3(15, 0, -6),     # B
	Vector3(-18, 0, 2),     # C
	Vector3(6, 0, -22),     # D
	Vector3(18, 0, 12),     # E
	Vector3(-19, 0, 17),    # F
	Vector3(-55, 0, -58),   # G   (Salt Flats from here on)
	Vector3(52, 0, -66),    # H
	Vector3(70, 0, 8),      # I
	Vector3(-72, 0, 28),    # J
	Vector3(24, 0, 72),     # K
	Vector3(-40, 0, -82),   # L   (the far edge)
	Vector3(0, 0, -64),     # 12: the outpost site
	Vector3(-42, 0, -122),  # M   (Glass Desert from here on)
	Vector3(48, 0, -106),   # N
	Vector3(-108, 0, -96),  # O
	Vector3(112, 0, -84),   # P
	Vector3(78, 0, -136),   # Q
	Vector3(-70, 0, -140),  # R   (the edge of the world)
	Vector3(0, 0, -118),    # 19: the glass outpost site
	Vector3(-60, 0, -182),  # S   (the Drift from here on)
	Vector3(72, 0, -196),   # T
	Vector3(-150, 0, -196), # U
	Vector3(178, 0, -120),  # V
	Vector3(120, 0, -204),  # W
	Vector3(-186, 0, -60),  # X
	Vector3(0, 0, -190),    # 26: the drift station site
]
const HOME_DESTS: Array[int] = [0, 1, 2, 3, 4, 5]
const FLATS_DESTS: Array[int] = [6, 7, 8, 9, 10, 11]
const GLASS_DESTS: Array[int] = [13, 14, 15, 16, 17, 18]
const OUTPOST_POS := Vector3(0, 0, -64)
const GLASS_OUTPOST_POS := Vector3(0, 0, -118)
const GLASS_SITE_INDEX := 19
const DRIFT_DESTS: Array[int] = [20, 21, 22, 23, 24, 25]
const DRIFT_POS := Vector3(0, 0, -190)
const DRIFT_SITE_INDEX := 26
## Drift rays hunt in the sand rivers near these points (each finds the
## nearest river when its patch of the world has loaded).
const RAY_AREAS: Array[Vector3] = [
	Vector3(-150, 0, -180), Vector3(40, 0, -186), Vector3(-30, 0, -204),
	Vector3(160, 0, -160), Vector3(-184, 0, -120), Vector3(100, 0, -184),
]
## The hull: whatever is buried by point R.
const HULL_POS := Vector3(-80, 0, -154)
## Lodestones: magnetic rocks in the Glass Desert. They pull on METAL.
const LODESTONES: Array[Vector3] = [
	Vector3(-16, 0, -100), Vector3(24, 0, -128), Vector3(-62, 0, -116),
	Vector3(88, 0, -110), Vector3(-96, 0, -130), Vector3(124, 0, -30),
	Vector3(-124, 0, 40), Vector3(60, 0, 122), Vector3(-84, 0, 116),
]
## Pull = MAGNET_PULL x metal kg / (distance^2 + 9), in newtons.
const MAGNET_PULL := 300.0
const MAGNET_RANGE := 22.0
const REPAIR_COST := 5          ## per flat tyre, at any base
const TRAVEL_COST := 15         ## crew shuttle between bases
## Scorpions lie in wait out on the flats (some right on the outpost road).
const SCORPION_HOMES: Array[Vector3] = [
	Vector3(2, 0, -44), Vector3(-30, 0, -60), Vector3(30, 0, -55),
	Vector3(55, 0, -30), Vector3(-50, 0, -20), Vector3(45, 0, 40),
]
## Ant nests. Don't leave cargo lying near them.
const ANT_NESTS: Array[Vector3] = [
	Vector3(-6, 0, -4),
	Vector3(9, 0, 3),
	Vector3(-2, 0, -14),
]
const RESCUE_COST := 25
const HAWK_ROOST := Vector3(19, 0, -19)
## Where progress is saved. "user://" is a per-game folder Godot picks for you
## (on Windows: %APPDATA%/Godot/app_userdata/Sand Rover Prototype).
const SAVE_PATH := "user://save.json"
const DELIVERY_RADIUS := 2.2
## Where dung beetles live. They wander near here and charge if you come close.
const BEETLE_HOMES: Array[Vector3] = [
	Vector3(-6, 0, 2),
	Vector3(10, 0, -12),
	Vector3(-15, 0, -8),
]

var terrain: SandTerrain
var car: RCCar
var cargo: Cargo
var camera: Camera3D
var beacon: Node3D
var hud: Label
var message: Label
var sun: DirectionalLight3D
var env: Environment
var crate_marker: Node3D
## High = all the fancy lighting (needs the Forward+ renderer). G toggles it.
var high_quality := true
var tilt_shift := true

var money := 0
var deliveries := 0
var target_index := 0
var has_job := false           # true = you have cargo to deliver
var contract: Dictionary = {}  # the job you're doing (see contracts.gd)
var offers: Array[Dictionary] = []
## Parts on the truck, and parts you've bought (see parts.gd).
var fitted: Dictionary = Parts.default_loadout()
var owned: Dictionary = {"tyres": ["standard"], "motor": ["standard"], "battery": ["standard"], "bed": ["flat"]}
var menu: BaseMenu
## The workshop build: socket id -> part id (see build_parts.gd), plus the
## spare parts in your parts box (part id -> how many).
var build: Dictionary = {}
var inventory: Dictionary = {}
var workshop: Workshop
var day_night: DayNight
var weather: Weather
var hawk: Hawk
var sfx: Sfx
var story_progress := 0        # how many story contracts are done
## Bases you can use: charging, contracts, workshop, rescue. The outpost
## appears when you deliver its kit (story contract 11).
var stations: Array[Dictionary] = [
	{"id": "home", "name": "Home Base", "pos": BASE_POS, "built": true},
	{"id": "outpost", "name": "Salt Flats Outpost", "pos": OUTPOST_POS, "built": false, "site": 12},
	{"id": "glass", "name": "Glass Outpost", "pos": GLASS_OUTPOST_POS, "built": false, "site": GLASS_SITE_INDEX},
	{"id": "drift", "name": "Drift Station", "pos": DRIFT_POS, "built": false, "site": DRIFT_SITE_INDEX},
]
var rays: Array[DriftRay] = []
var _rays_placed := {}          # RAY_AREAS index -> true once its ray exists
var scorpions: Array[Scorpion] = []
var map_overlay: MapOverlay
var _site_nodes := {}          # station id -> stakes and sign, removed once it's built
var _storm_timer := 120.0       # seconds until the next magnet storm
var _storm_left := 0.0          # seconds left of the current storm
var _storm_overlay: ColorRect
var lodestone_nodes: Array[Node3D] = []
var _crack_cooldown := 0.0
var _station_lamps: Array[OmniLight3D] = []
var title_screen: TitleMenu
var pause_menu: PauseMenu
## Set before reloading the scene for "New Game": skip the title screen.
static var skip_title := false
const SAVE_VERSION := 2
var quality := 1                # 0 Low, 1 Medium, 2 High (Options)
var _hold := {}                 # action -> seconds held (pad: hold to confirm)
var _cam_yaw := 0.0             # right stick / right mouse: look around
var _cam_pitch := 0.0
var _cam_idle := 0.0
var _shake := 0.0
var _air_time := 0.0            # seconds with no wheel on the ground
var _was_dropped := false
var _last_vy := 0.0
var _glass_rescue_used := false # for the "Self-Sufficient" achievement
var help_screen: CanvasLayer
var base_light: OmniLight3D
var _contract_time := 0.0      # seconds since the current contract started
var _engine_snd: AudioStreamPlayer3D
var _sand_snd: AudioStreamPlayer3D
var _winch_snd: AudioStreamPlayer3D
var _wind_snd: AudioStreamPlayer
var _cheer_due := false        # cheer when you get home after a delivery
var trailer: Trailer
var _net_joint: Generic6DOFJoint3D
## A crash harder than this (sudden speed change, m/s) snaps the cargo net.
const NET_BREAK := 6.5
var colonies: Array[AntColony] = []
var _rng := RandomNumberGenerator.new()
var _flat_warned := false
var _show_debug := false   # F3
var _was_at_base := true
var _settle_in_zone := 0.0     # seconds the crate has been resting in the ring
var _message_time := 0.0
var beetles: Array[DungBeetle] = []
var _loading := false          # crate is being lifted back onto the truck
var _load_t := 0.0
var _load_from := Transform3D()
var _impact_cooldown := 0.0
var gpu_info := ""
var _autotest := false
var _soaktest := false
var _beetletest := false
var _droptest := false
var _anttest := false
var _looptest := false
var _buildtest := false
var _m4test := ""              # "hawktest", "windtest", "daytest", "storytest", or a milestone 5 test
var _test_time := 0.0
var _worst_physics_ms := 0.0
var _sum_physics_ms := 0.0
var _samples := 0


func _ready() -> void:
	_autotest = "--autotest" in OS.get_cmdline_user_args()
	_soaktest = "--soaktest" in OS.get_cmdline_user_args()
	_beetletest = "--beetletest" in OS.get_cmdline_user_args()
	_droptest = "--droptest" in OS.get_cmdline_user_args()
	_anttest = "--anttest" in OS.get_cmdline_user_args()
	_looptest = "--looptest" in OS.get_cmdline_user_args()
	_buildtest = "--buildtest" in OS.get_cmdline_user_args()
	for t in ["hawktest", "windtest", "daytest", "storytest", "worldtest", "crusttest", "scorpiontest", "outposttest",
			"glasstest", "magnettest", "shardtest", "traveltest",
			"gravitytest", "flowtest", "raytest", "drifttest", "controllertest"]:
		if ("--" + t) in OS.get_cmdline_user_args():
			_m4test = t
	_rng.seed = 2026
	# The fancy lighting needs the Forward+ renderer (what you get on a
	# desktop graphics card). The fallback renderer gets the simple look.
	quality = int(Settings.get_value("quality"))
	if _rendering_method() == "gl_compatibility":
		quality = 0      # the simple renderer only does the simple look
	high_quality = quality > 0
	tilt_shift = bool(Settings.get_value("tilt_shift"))
	Achievements.enabled = not _is_test()
	Settings.changed.connect(_on_settings_changed)
	_build_environment()

	terrain = SandTerrain.new()
	terrain.track_resolution = 4096 if high_quality else 2048
	terrain.flat_pads.append(Vector3(BASE_POS.x, BASE_POS.z, BASE_RADIUS + 1.0))
	terrain.flat_pads.append(Vector3(OUTPOST_POS.x, OUTPOST_POS.z, BASE_RADIUS + 1.0))
	terrain.flat_pads.append(Vector3(GLASS_OUTPOST_POS.x, GLASS_OUTPOST_POS.z, BASE_RADIUS + 1.0))
	terrain.flat_pads.append(Vector3(DRIFT_POS.x, DRIFT_POS.z, BASE_RADIUS + 1.0))
	for s in DELIVERY_SPOTS:
		terrain.flat_pads.append(Vector3(s.x, s.z, DELIVERY_RADIUS))
	for n in ANT_NESTS:
		terrain.mounds.append(Vector3(n.x, n.z, 0.9))
	add_child(terrain)
	# The sand shader needs to know where the sun is, for the glints.
	terrain.set_shader_parameter("sun_direction", sun.global_basis.z)

	var crowd := CrewCrowd.new()
	add_child(crowd)
	crowd.setup(terrain, _on_ground(BASE_POS), BASE_RADIUS + 0.5)
	_build_base_pad(BASE_POS)

	car = RCCar.new()
	car.terrain = terrain
	car.parts = fitted.duplicate()
	car.build = build.duplicate()
	add_child(car)
	car.place_at(_on_ground(BASE_POS) + Vector3(0, 0.8, 0), PI)  # face -Z, toward the dunes

	for nest in ANT_NESTS:
		var colony := AntColony.new()
		colony.terrain = terrain
		colony.position = _on_ground(nest)
		add_child(colony)
		colony.stole_cargo.connect(_on_cargo_stolen)
		colonies.append(colony)
	_add_spot_labels()
	for home in SCORPION_HOMES:
		var sc := Scorpion.new()
		sc.terrain = terrain
		sc.home = home
		add_child(sc)
		sc.clamped.connect(func(_w):
			jolt(0.8)
			_show_message("A SCORPION has your wheel! Floor it to shake it off.")
			sfx.play("beetle_hiss", sc.global_position, 2.0, 1.4))
		sc.shaken_off.connect(func(how):
			_show_message("ZAP! The buzzer fried it." if how == "zapped" else "Shook it off!")
			sfx.play("click" if how == "zapped" else "thud", sc.global_position))
		scorpions.append(sc)
	for st in stations:
		if st["id"] != "home":
			_build_outpost_site(st)
	_build_lodestones()
	_build_hull()

	for home in BEETLE_HOMES:
		_spawn_beetle(home)

	beacon = _make_beacon()
	add_child(beacon)
	beacon.visible = false
	crate_marker = _make_crate_marker()
	add_child(crate_marker)

	camera = Camera3D.new()
	# The camera moves every frame in _process, not in physics, so physics
	# interpolation must leave it alone.
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.fov = 70
	add_child(camera)
	_apply_quality()
	camera.global_position = car.global_position + Vector3(0, 3, 6)

	sfx = Sfx.new()
	add_child(sfx)
	_attach_car_sounds()
	_wind_snd = sfx.make_ambient_loop("wind")

	day_night = DayNight.new()
	add_child(day_night)
	day_night.setup(sun, env, terrain)
	weather = Weather.new()
	add_child(weather)
	var wind_angle = terrain.get_shader_parameter("wind_angle_deg")
	weather.set_wind_angle(wind_angle if wind_angle != null else 20.0)
	weather.gust_started.connect(func():
		_show_message("Wind gust from the %s!" % weather.from_direction()))
	_build_hawk()
	base_light = OmniLight3D.new()
	base_light.light_color = Color(1.0, 0.75, 0.45)
	base_light.omni_range = 9.0
	base_light.light_energy = 0.0
	add_child(base_light)
	base_light.global_position = _on_ground(BASE_POS) + Vector3(0, 2.5, 0)

	_build_hud()
	_storm_overlay = ColorRect.new()
	_storm_overlay.color = Color(0.45, 0.2, 0.7, 0.0)
	_storm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_storm_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var storm_layer := CanvasLayer.new()
	storm_layer.layer = 1
	storm_layer.add_child(_storm_overlay)
	add_child(storm_layer)
	help_screen = Screens.make_help()
	add_child(help_screen)
	map_overlay = MapOverlay.new()
	map_overlay.main = self
	add_child(map_overlay)
	menu = BaseMenu.new()
	add_child(menu)
	menu.contract_picked.connect(_on_contract_picked)
	menu.part_clicked.connect(_on_part_clicked)
	menu.workshop_pressed.connect(_open_workshop)
	menu.travel_pressed.connect(_fast_travel)
	menu.wait_pressed.connect(func(until: float):
		day_night.skip_to(until)
		offers = _make_offers()
		_refresh_menu())
	workshop = Workshop.new()
	workshop.main = self
	add_child(workshop)
	workshop.finished.connect(func(): hud.visible = true)
	menu.visible = false
	if not _is_test():
		_load_game()
	else:
		terrain.finish_all_tiles()      # no background threads during tests
		day_night.paused = true         # tests run in steady daylight
		weather.min_gap_s = 9999.0      # ...and no surprise gusts
		weather.max_gap_s = 9999.0
		weather._timer = 9999.0
		_storm_timer = 1e9              # ...and no magnet storms
		if _m4test != "hawktest":
			hawk._cooldown = 1e9        # ...and no hawk, unless that's the test
	offers = _make_offers()
	if _autotest or _soaktest or _beetletest or _droptest or _anttest:
		_start_contract({"cargo": "crate", "dest": 0, "pay": 50, "distance": 0.0})
	elif _buildtest:
		_run_buildtest()
	elif _m4test != "":
		call("_run_" + _m4test)
	elif not _looptest and not skip_title:
		# The title screen first.
		title_screen = TitleMenu.new()
		title_screen.has_save = FileAccess.file_exists(SAVE_PATH)
		add_child(title_screen)
		title_screen.continue_game.connect(_leave_title)
		title_screen.new_game.connect(_new_game)
		title_screen.quit_game.connect(_quit_game)
		hud.visible = false
	elif skip_title:
		skip_title = false
		_open_menu.call_deferred()
		_show_message("Welcome to base! Pick your first contract.")
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.return_to_title.connect(func():
		_save_game()
		get_tree().paused = false
		get_tree().reload_current_scene())
	pause_menu.quit_game.connect(_quit_game)
	Input.joy_connection_changed.connect(func(_device, connected):
		if not connected:
			_auto_pause())
	Achievements.unlocked.connect(func(_id, title):
		_show_message("Achievement: %s" % title)
		sfx.play("chime", car.global_position, -4.0, 1.3))
	gpu_info = _describe_gpu()
	print(gpu_info)


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

## All the controls (keyboard and controller) are set up by the GameInput
## autoload: scripts/game_input.gd.


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("help") and not _is_test() and not workshop.active:
		help_screen.visible = not help_screen.visible
	if Input.is_action_just_pressed("map") and not _is_test():
		map_overlay.toggle()
	if title_screen and title_screen.visible:
		car.brake_input = 1.0
	elif _buildtest or _m4test != "":
		pass   # these tests run as coroutines (they drive the truck themselves)
	elif _looptest:
		_run_looptest(delta)
	elif _anttest:
		_run_anttest(delta)
	elif _droptest:
		_run_droptest(delta)
	elif _beetletest:
		_run_beetletest(delta)
	elif _soaktest:
		_run_soaktest(delta)
	elif _autotest:
		_run_autotest(delta)
	elif workshop.active:
		pass   # the workshop handles its own input; the truck is frozen
	elif menu.visible:
		# Menu open: the truck waits with the handbrake on.
		car.throttle_input = 0.0
		car.steer_input = 0.0
		car.brake_input = 1.0
		if Input.is_action_just_pressed("base_menu"):
			_close_menu()
		elif Input.is_action_just_pressed("workshop"):
			_open_workshop()
	else:
		_drive_input(delta)
	_impact_cooldown -= delta
	if has_job:
		_contract_time += delta
	_update_loading(delta)
	_update_delivery(delta)
	_update_base(delta)
	_update_world(delta)
	# Only the nest closest to loose cargo goes after it (no tug of war).
	var loose := _crate_dropped() and not _hawk_has_cargo()
	var closest: AntColony = null
	if loose:
		for colony in colonies:
			if closest == null or colony.global_position.distance_to(cargo.global_position) \
					< closest.global_position.distance_to(cargo.global_position):
				closest = colony
	for colony in colonies:
		colony.update_colony(delta, cargo, loose and colony == closest, car)


## Driving controls (keyboard or controller: GameInput maps both).
func _drive_input(delta: float) -> void:
	# Analog: triggers and the stick give anything from 0 to 1.
	car.throttle_input = Input.get_axis("reverse", "accelerate")
	car.steer_input = Input.get_axis("steer_right", "steer_left")
	car.brake_input = Input.get_action_strength("brake")
	if Input.is_action_just_pressed("base_menu"):
		if _at_base():
			_open_menu()
		elif not GameInput.using_pad:
			_show_message("The base menu only works at a base.")
	# On a controller, flip and rescue need a HOLD (no accidents).
	if _pressed_or_held("rescue", 1.0, delta):
		_rescue()
	if _pressed_or_held("reset", 0.5, delta):
		_reset_car()
	if Input.is_action_just_pressed("spare"):
		_show_message(car.use_spare())
	if Input.is_action_just_pressed("winch"):
		_show_message(car.toggle_winch())
	if Input.is_action_just_pressed("workshop"):
		if _at_base():
			_open_workshop()
		else:
			_show_message("The workshop is at a base.")
	if Input.is_action_just_pressed("debug_hud") and OS.is_debug_build():
		_show_debug = not _show_debug
	if Input.is_action_just_pressed("toggle_vsync"):
		Settings.set_value("vsync", not Settings.get_value("vsync"))
		_show_message("V-Sync " + ("on" if Settings.get_value("vsync") else "off"))
	if Input.is_action_just_pressed("load_crate"):
		_try_load_crate()
	if Input.is_action_just_pressed("call_crate"):
		_call_replacement_crate()
	if Input.is_action_just_pressed("tilt_shift"):
		Settings.set_value("tilt_shift", not Settings.get_value("tilt_shift"))
	if Input.is_action_just_pressed("graphics"):
		Settings.set_value("quality", (int(Settings.get_value("quality")) + 1) % 3)
		_show_message("Graphics: " + Settings.QUALITY_NAMES[int(Settings.get_value("quality"))])


## Keyboard: a tap. Controller: hold for `seconds` (fires once per hold).
func _pressed_or_held(action: String, seconds: float, delta: float) -> bool:
	if not GameInput.using_pad:
		return Input.is_action_just_pressed(action)
	if Input.is_action_pressed(action):
		var before: float = _hold.get(action, 0.0)
		_hold[action] = before + delta
		return before < seconds and before + delta >= seconds
	_hold[action] = 0.0
	return false


## How far a held button has got (0..1), for the HUD.
func _hold_progress(action: String, seconds: float) -> float:
	return clampf(_hold.get(action, 0.0) / seconds, 0.0, 1.0)


## Esc / Menu: close whatever is open first, otherwise pause.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("screenshot"):
		_take_screenshot()
		return
	if _is_test() or (title_screen and title_screen.visible) or pause_menu.visible:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if help_screen.visible:
			help_screen.visible = false
		elif map_overlay.visible:
			map_overlay.toggle()
		elif menu.visible:
			_close_menu()
		elif workshop.active:
			workshop.leave()
		else:
			_save_game()
			pause_menu.open()
	# Right mouse button held: look around (like the right stick).
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT) and not workshop.active:
		var sens: float = Settings.get_value("camera_sensitivity") * 0.0012
		_cam_yaw -= event.relative.x * sens * (-1.0 if Settings.get_value("invert_x") else 1.0)
		_cam_pitch += event.relative.y * sens * (-1.0 if Settings.get_value("invert_y") else 1.0)
		_cam_idle = 0.0


func _exit_tree() -> void:
	Models.clear_cache()
	# Stop every sound now, so looping sounds don't outlive the scene.
	for p in find_children("*", "AudioStreamPlayer", true, false) + find_children("*", "AudioStreamPlayer3D", true, false):
		p.stop()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game()           # closing the window: save first
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_auto_pause()          # alt-tab, Steam overlay, Steam Deck suspend


## F12: save what's on screen to the Screenshots folder (for your store page).
func _take_screenshot() -> void:
	var dir := "user://screenshots"
	DirAccess.make_dir_recursive_absolute(dir)
	var file := "%s/sand_rover_%s.png" % [dir, Time.get_datetime_string_from_system().replace(":", "-")]
	get_viewport().get_texture().get_image().save_png(file)
	_show_message("Screenshot saved: " + ProjectSettings.globalize_path(file))


func _auto_pause() -> void:
	if _is_test() or pause_menu == null or pause_menu.visible or (title_screen and title_screen.visible):
		return
	_save_game()
	pause_menu.open()


func _leave_title() -> void:
	title_screen.visible = false
	hud.visible = true
	sfx.play("click")
	_open_menu()
	_show_message("Welcome to base! Pick your first contract.")


func _new_game() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	skip_title = true
	get_tree().reload_current_scene()


func _quit_game() -> void:
	_save_game()
	get_tree().quit()


func _on_settings_changed() -> void:
	var q := int(Settings.get_value("quality"))
	var t := bool(Settings.get_value("tilt_shift"))
	if _rendering_method() == "gl_compatibility":
		q = 0
	if q != quality or t != tilt_shift:
		quality = q
		high_quality = q > 0
		tilt_shift = t
		_apply_quality()


func _process(delta: float) -> void:
	if not workshop.active:
		_update_camera(delta)
	_update_tilt_shift(delta)
	_update_haze(delta)
	_update_crate_marker()
	_update_hud(delta)
	_update_sounds()


# ---------------------------------------------------------------------------
# Delivery loop
# ---------------------------------------------------------------------------

func _update_delivery(delta: float) -> void:
	if has_job and cargo and not _loading:
		var t := _on_ground(DELIVERY_SPOTS[target_index])
		var flat := Vector2(cargo.global_position.x - t.x, cargo.global_position.z - t.z)
		if flat.length() < DELIVERY_RADIUS and cargo.linear_velocity.length() < 0.4:
			_settle_in_zone += delta
			if _settle_in_zone > 0.75:
				_complete_delivery()
		else:
			_settle_in_zone = 0.0



## At any built base (home or outpost)?
func _at_base() -> bool:
	return not _station_here().is_empty()


## The built base you're parked at, or {}.
func _station_here() -> Dictionary:
	for st in stations:
		if st["built"]:
			var p: Vector3 = st["pos"]
			if Vector2(car.global_position.x - p.x, car.global_position.z - p.z).length() < BASE_RADIUS + 0.5:
				return st
	return {}


## The closest built base (for rescues and "return to base").
func _nearest_station() -> Dictionary:
	var best: Dictionary = stations[0]
	for st in stations:
		if st["built"] and car.global_position.distance_to(st["pos"]) < car.global_position.distance_to(best["pos"]):
			best = st
	return best


## Where the crew comes from for animations: the base you're at.
func _here_pos() -> Vector3:
	var st := _station_here()
	return st["pos"] if not st.is_empty() else BASE_POS


## At base: recharge, and pop the menu up when you arrive without a job.
func _update_base(delta: float) -> void:
	var arrived := _at_base() and not _was_at_base
	_was_at_base = _at_base()
	if not _at_base():
		if car.get_battery_percent() > 0.0:
			_flat_warned = false
		elif not _flat_warned:
			_flat_warned = true
			_show_message("Battery flat! Crawl home, or %s for a rescue ($%d)." % [GameInput.prompt("rescue"), RESCUE_COST])
		return
	car.recharge(30.0 * delta)
	_flat_warned = false
	if arrived:
		_service_truck()
	# Welcome home: the crowd cheers if you just made a delivery.
	if arrived and _cheer_due:
		_cheer_due = false
		sfx.play("cheer", car.global_position)
	# Pop the menu up once when you arrive without a job (you can close it).
	if arrived and not has_job and not _is_test():
		_open_menu()


func _complete_delivery() -> void:
	deliveries += 1
	_unstrap_cargo()
	var condition := cargo.condition
	GameInput.rumble(0.4, 0.0, 0.3)
	# Achievements.
	Achievements.unlock("ACH_FIRST_DELIVERY")
	if condition >= 99.5:
		Achievements.add("pristine", 1, 10, "ACH_PRISTINE_10")
	if condition < 10.0:
		Achievements.unlock("ACH_BARELY")
	if car.flat_count() > 0 or car.is_pinned():
		Achievements.unlock("ACH_SCORPION_FLAT")
	var pay := int(round(float(contract["pay"]) * condition / 100.0))   # damaged = less pay
	# Story twists.
	var story_done := contract.has("story")
	var note := ""
	if contract.has("min_condition") and condition < contract["min_condition"]:
		pay = 0
		story_done = false
		note = "The client refused it: under %d%% condition. Try again!" % contract["min_condition"]
	elif contract.has("deadline") and _contract_time > contract["deadline"]:
		pay /= 2
		story_done = false
		note = "Late! (%d s, the deadline was %d s) Half pay. Try again!" % [int(_contract_time), contract["deadline"]]
	money += pay
	cargo.queue_free()
	cargo = null
	has_job = false
	_settle_in_zone = 0.0
	beacon.visible = false
	var delivered_cargo: String = contract["cargo"]
	if story_done:
		story_progress += 1
		if story_progress >= Story.CONTRACTS.size():
			Achievements.unlock("ACH_STORY_DONE")
		if story_progress == 22 and not _glass_rescue_used:
			Achievements.unlock("ACH_NO_RESCUE_RING")   # all six Glass Desert jobs, no tow
	var built_name := ""
	if delivered_cargo == "kit" and note == "":
		for st in stations:
			if st.get("site", -1) == int(contract["dest"]):
				_build_outpost(st["id"])
				built_name = st["name"]
	offers = _make_offers()
	_save_game()
	if note != "":
		sfx.play("fail")
		_show_message(note)
	else:
		sfx.play("chime")
		_cheer_due = true
		var msg := "Delivered at %d%% condition! +$%d  Head back to base for the next job." % [int(condition), pay]
		var ending: String = contract.get("ending", "") if story_done else ""
		if delivered_cargo == "kit":
			msg = "The crew built the %s! You can recharge, take jobs, build and fast-travel there now." % built_name.to_upper()
		if ending != "":
			msg = ending
		_show_message(msg)
		if ending != "" or delivered_cargo == "kit":
			_message_time = 12.0


func _load_cargo(type_id: String = "crate") -> void:
	_unstrap_cargo()
	if cargo:
		cargo.queue_free()
	cargo = Cargo.new()
	cargo.type_id = type_id
	add_child(cargo)
	cargo.impact.connect(_on_crate_impact)
	cargo.smashed.connect(_on_crate_smashed, CONNECT_DEFERRED)
	cargo.set_meta("wind_area", 0.04)   # small: the wind nudges it, not throws it
	_loading = false
	_put_cargo_on_bed()
	_strap_cargo()


## Place the cargo standing on the truck bed (taller cargo sits higher).
## (Only moves it: connecting signals here was a bug that the build test found.)
func _put_cargo_on_bed() -> void:
	var size: Vector3 = cargo.type_def["size"]
	cargo.global_transform = _cargo_anchor().global_transform.translated_local(Vector3(0, size.y * 0.5 - 0.2 + 0.01, 0))
	cargo.reset_physics_interpolation()   # it teleported: don't smooth from the old spot
	cargo.linear_velocity = car.linear_velocity
	cargo.reset_impact_tracking()


func _set_target(i: int) -> void:
	target_index = i
	beacon.global_position = _on_ground(DELIVERY_SPOTS[i])
	beacon.visible = true


func _reset_car() -> void:
	var p := car.global_position
	var cargo_was_on := _crate_on_truck()
	car.place_at(Vector3(p.x, terrain.get_height(p.x, p.z) + 1.0, p.z), car.global_rotation.y)
	_sync_trailer()
	if cargo_was_on:
		_put_cargo_on_bed()
		cargo.reset_physics_interpolation()
		cargo.reset_impact_tracking()
		_strap_cargo()


# ---------------------------------------------------------------------------
# Base: contracts, garage, rescue
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# The living world: day and night, wind, the hawk, sound
# ---------------------------------------------------------------------------

func _is_test() -> bool:
	return _autotest or _soaktest or _beetletest or _droptest or _anttest or _looptest \
			or _buildtest or _m4test != ""


## The contract board: the next story job (if it can be offered now) and
## random jobs to fill the rest.
func _make_offers() -> Array[Dictionary]:
	# The board depends on where you are: the outpost sends you around the
	# Salt Flats (for more money), home sends you around the dunes.
	# (The glass outpost sends you around the Glass Desert, for even more.)
	var st: Dictionary = _station_here() if car else {}
	var here_id: String = st["id"] if not st.is_empty() else "home"
	var from: Vector3 = st["pos"] if not st.is_empty() else BASE_POS
	var dests: Array[int] = HOME_DESTS
	var bonus := 1.0
	var extra: Array[String] = []
	if here_id == "outpost":
		dests = FLATS_DESTS
		bonus = 1.4
	elif here_id == "glass":
		dests = GLASS_DESTS
		bonus = 1.9
	elif here_id == "drift":
		dests = DRIFT_DESTS
		bonus = 2.5
		extra = ["orb"]
	var list := Contracts.make_offers(_rng, DELIVERY_SPOTS, from, deliveries, dests, bonus, extra)
	var story := Story.next_offer(story_progress, DELIVERY_SPOTS, from,
			day_night.is_night() if day_night else false, here_id)
	if not story.is_empty():
		list[0] = story
	return list


func _update_world(delta: float) -> void:
	_update_feel_and_achievements(delta)
	# Keep the ground solid (active tiles) around the truck, trailer and cargo.
	var focus: Array[Vector3] = [car.global_position]
	if trailer:
		focus.append(trailer.global_position)
	if cargo:
		focus.append(cargo.global_position)
	terrain.focus_points = focus
	# Weight on board matters for the salt crust.
	var cargo_mass := cargo.mass if cargo and _crate_on_truck() else 0.0
	car.extra_load = cargo_mass if trailer == null else 0.0
	if trailer:
		trailer.extra_load = cargo_mass
	_crack_cooldown -= delta
	# Scorpions.
	for sc in scorpions:
		sc.update_scorpion(delta, car)
	# Glass Desert: lodestones and magnet storms.
	_update_magnets(delta)
	# The Drift: low gravity, sand rivers, rays.
	_update_drift(delta)
	# Day and night.
	car.daylight = day_night.daylight
	car.set_lights(day_night.daylight < 0.45)
	base_light.light_energy = (1.0 - day_night.daylight) * 2.5
	for lamp in _station_lamps:
		lamp.light_energy = base_light.light_energy
	# Wind pushes the truck, trailer and loose cargo.
	var bodies: Array = [car]
	if trailer:
		trailer.set_meta("wind_area", 0.5)
		bodies.append(trailer)
	if cargo and _crate_dropped() and not _hawk_has_cargo():
		bodies.append(cargo)
	weather.update_weather(delta, camera.global_position, bodies, terrain.tracks)
	# Safety net: a truck that leaves the map or falls through it comes back.
	var cp := car.global_position
	var edge := terrain.half_extent() - 5.0
	if absf(cp.x) > edge or absf(cp.z) > edge or cp.y < terrain.get_height(cp.x, cp.z) - 3.0:
		var back := Vector3(clampf(cp.x, -edge + 10, edge - 10), 0, clampf(cp.z, -edge + 10, edge - 10))
		terrain.ensure_active_at(back.x, back.z)
		_release_scorpions()
		car.place_at(_on_ground(back) + Vector3(0, 1.0, 0), car.global_rotation.y)
		_sync_trailer()
		_show_message("Whoa, back you come.")
	# Safety net: anything that falls through the world goes back on the sand.
	if cargo and not cargo.freeze and cargo.global_position.y < terrain.get_height(cargo.global_position.x, cargo.global_position.z) - 3.0:
		var p := cargo.global_position
		var e := terrain.half_extent() - 15.0
		_drop_cargo_at(Vector3(clampf(p.x, -e, e), 0, clampf(p.z, -e, e)))
	# The hawk.
	hawk.update_hawk(delta, cargo if has_job else null, _cargo_secured(), day_night.daylight)
	if cargo == null and hawk.carrying:
		hawk.carrying = null


## Cargo the hawk can't take: strapped down with the net, or locked in the cage.
func _cargo_secured() -> bool:
	if cargo == null or not _crate_on_truck():
		return false
	return _net_joint != null or (fitted["bed"] == "cage" and trailer == null)


func _hawk_has_cargo() -> bool:
	return hawk != null and hawk.carrying != null and hawk.carrying == cargo


func _build_hawk() -> void:
	# A dead tree on a dune for the hawk to roost in.
	var roost := _on_ground(HAWK_ROOST)
	var tree := Models.make("dead_tree")
	add_child(tree)
	tree.global_position = roost
	hawk = Hawk.new()
	hawk.terrain = terrain
	hawk.roost = roost
	add_child(hawk)
	hawk.stalking.connect(func():
		_show_message("A hawk is circling over your cargo...")
		sfx.play("hawk_screech", hawk.global_position))
	hawk.grabbed.connect(func(_c):
		GameInput.rumble(0.5, 0.2, 0.3)
		Achievements.unlock("ACH_HAWK_ROBBED")
		_unstrap_cargo()
		_show_message("The hawk grabbed your cargo!")
		sfx.play("hawk_screech", hawk.global_position, 3.0))
	hawk.dropped.connect(func(c):
		_show_message("It dropped it! Go find it (follow the marker) before the ants do."))
	hawk.foiled.connect(func(reason):
		sfx.play("hawk_screech", hawk.global_position, -3.0, 1.3)
		_show_message("The net held! The hawk gives up." if reason == "net" else "Too heavy for the hawk!"))


## Engine, sand and winch sounds ride on the truck (rebuilt with it).
func _attach_car_sounds() -> void:
	car.crust_cracked.connect(_on_crust_cracked)
	car.punctured.connect(func(_w):
		jolt(0.7)
		_show_message("FLAT TYRE! %s fits a spare, or creep to a base." % GameInput.prompt("spare")))
	_engine_snd = sfx.make_loop("engine", car)
	_sand_snd = sfx.make_loop("sand", car)
	_winch_snd = sfx.make_loop("winch", car)


func _update_sounds() -> void:
	if _engine_snd == null or not is_instance_valid(_engine_snd):
		return
	var speed := car.linear_velocity.length()
	var effort := absf(car.throttle_input)
	# The motor whines higher as it goes faster, and louder when you push it.
	_engine_snd.pitch_scale = 0.7 + speed * 0.09 + effort * 0.25
	_engine_snd.volume_db = linear_to_db(0.15 + effort * 0.45)
	var crunch := clampf(speed / 6.0, 0.0, 1.0) * 0.7 + car.get_spin_amount() * 0.6
	_sand_snd.volume_db = linear_to_db(maxf(crunch * (1.0 - car.get_ground_hardness() * 0.6), 0.001))
	_sand_snd.pitch_scale = 0.8 + speed * 0.05
	_winch_snd.volume_db = 0.0 if car.winch_anchor != Vector3.INF else -80.0
	_wind_snd.volume_db = linear_to_db(0.08 + weather.strength * 0.8)


# ---------------------------------------------------------------------------
# Ring 1: salt crust, scorpions, the outpost
# ---------------------------------------------------------------------------

func _on_crust_cracked(where: Vector3) -> void:
	sfx.play("thud", where, -4.0, 1.6)
	if _crack_cooldown <= 0.0:
		_crack_cooldown = 6.0
		SandDust.burst(self, where, 0.8)
		_show_message("CRACK! The crust broke under you. Thin grey crust can't take the weight.")


## Teleports and rebuilds: scorpions let go and go back into hiding.
func _release_scorpions() -> void:
	for sc in scorpions:
		sc.release_now(car)


## Before it's built: stakes, string and a sign where the outpost will go.
func _build_outpost_site(st: Dictionary) -> void:
	var at := _on_ground(st["pos"])
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.4, 0.25)
	var nodes: Array = _site_nodes.get(st["id"], [])
	for k in 6:
		var a := k * TAU / 6.0
		var stake := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.03
		cyl.bottom_radius = 0.04
		cyl.height = 0.5
		stake.mesh = cyl
		stake.material_override = wood
		add_child(stake)
		stake.global_position = at + Vector3(cos(a), 0, sin(a)) * BASE_RADIUS + Vector3(0, 0.25, 0)
		nodes.append(stake)
	_site_nodes[st["id"]] = nodes


func _station(id: String) -> Dictionary:
	for st in stations:
		if st["id"] == id:
			return st
	return {}


## Deliver the kit and the crew builds this: pad, crowd, lamp, radio mast.
func _build_outpost(id: String = "outpost") -> void:
	var st := _station(id)
	if st.is_empty() or st["built"]:
		return
	st["built"] = true
	if stations.all(func(x): return x["built"]):
		Achievements.unlock("ACH_OUTPOSTS_ALL")
	for n in _site_nodes.get(id, []):
		n.queue_free()
	_site_nodes.erase(id)
	var pos: Vector3 = st["pos"]
	terrain.ensure_active_at(pos.x, pos.z)
	var at := _on_ground(pos)
	_build_base_pad(pos)
	var crowd := CrewCrowd.new()
	crowd.count = 80
	crowd.radius = 5.5
	add_child(crowd)
	crowd.setup(terrain, at, BASE_RADIUS + 0.5)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.75, 0.45)
	lamp.omni_range = 9.0
	add_child(lamp)
	lamp.global_position = at + Vector3(0, 2.5, 0)
	lamp.set_meta("station_lamp", true)
	_station_lamps.append(lamp)
	# A radio mast for listening to the signal.
	var mast := Models.make("mast")
	add_child(mast)
	mast.global_position = at + Vector3(BASE_RADIUS + 1.2, 0, 0)
	var blink := OmniLight3D.new()
	blink.light_color = Color(1, 0.2, 0.1)
	blink.omni_range = 3.0
	blink.light_energy = 2.0
	add_child(blink)
	blink.global_position = mast.global_position + Vector3(0, 5.05, 0)
	var sign := Label3D.new()
	sign.text = st["name"]
	sign.font_size = 48
	sign.pixel_size = 0.01
	sign.outline_size = 10
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sign)
	sign.global_position = at + Vector3(0, 2.2, 0)


# ---------------------------------------------------------------------------
# Ring 2: lodestones, magnet storms, shards
# ---------------------------------------------------------------------------

## Lodestones: big dark magnetic rocks. Solid (you can crash into them).
func _build_lodestones() -> void:
	for p in LODESTONES:
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.75
		col.shape = sphere
		col.position.y = 0.35
		body.add_child(col)
		body.add_child(Models.make("lodestone"))
		add_child(body)
		body.global_position = _on_ground(p) - Vector3(0, 0.1, 0)
		lodestone_nodes.append(body)


## How strongly magnets pull right now (storms make it much worse).
func magnet_strength() -> float:
	if _storm_left <= 0.0:
		return 1.0
	# Storms pulse: the pull surges and fades every couple of seconds.
	return 2.2 + sin(Time.get_ticks_msec() * 0.003) * 0.8


## Pull on everything metal: the truck, its trailer, and metal cargo.
## Magnetism falls off fast with distance (1 / distance squared): far away
## you barely feel it, right next to a lodestone it's very hard to escape.
func _update_magnets(delta: float) -> void:
	# Storms come and go (only felt in the Glass Desert).
	_storm_timer -= delta
	if _storm_left > 0.0:
		_storm_left -= delta
		if _storm_left <= 0.0:
			_storm_timer = _rng.randf_range(100.0, 160.0)
			if terrain.ring_at(car.global_position.x, car.global_position.z) == 2:
				_show_message("The magnet storm has passed.")
	elif _storm_timer <= 0.0:
		start_magnet_storm(25.0)
	var in_glass := terrain.ring_at(camera.global_position.x, camera.global_position.z) == 2 if camera else false
	var haze := 0.0
	if _storm_left > 0.0 and in_glass:
		haze = 0.1 + sin(Time.get_ticks_msec() * 0.003) * 0.05
	_storm_overlay.color.a = lerpf(_storm_overlay.color.a, haze, 1.0 - exp(-3.0 * delta))
	var mult := magnet_strength()
	var reach := MAGNET_RANGE * (1.5 if mult > 1.0 else 1.0)
	var pulled: Array = [[car, car.metal_mass]]
	if trailer:
		pulled.append([trailer, 8.0])
	if cargo and not cargo.freeze:
		pulled.append([cargo, float(cargo.type_def.get("metal", 0.0))])
	for item in pulled:
		var body: RigidBody3D = item[0]
		var metal: float = item[1]
		if metal <= 0.0:
			continue
		var f := magnet_force_at(body.global_position, metal, mult, reach)
		if f != Vector3.ZERO:
			body.apply_central_force(f)


## The magnetic force (N) on `metal` kg at a point.
func magnet_force_at(p: Vector3, metal: float, mult := 1.0, reach := MAGNET_RANGE) -> Vector3:
	var total := Vector3.ZERO
	for l in LODESTONES:
		var to := Vector3(l.x - p.x, 0, l.z - p.z)
		var d := to.length()
		if d > reach or d < 0.01:
			continue
		var fade := 1.0 - smoothstep(reach * 0.8, reach, d)   # no sudden edge
		total += to / d * MAGNET_PULL * metal * mult / (d * d + 9.0) * fade
	return total.limit_length(1500.0)


func start_magnet_storm(seconds: float) -> void:
	_storm_left = seconds
	if terrain.ring_at(car.global_position.x, car.global_position.z) == 2:
		_show_message("MAGNET STORM! Lodestones pull much harder. Keep away from the black rocks.")
		sfx.play("hawk_screech", car.global_position, -12.0, 0.35)


func storm_active() -> bool:
	return _storm_left > 0.0


## Arriving at a base: the crew fixes flat tyres and restocks spare wheels.
func _service_truck() -> void:
	car.spares = build.values().count("spare")
	var flats := car.flat_count()
	if flats > 0:
		car.repair_all()
		money -= REPAIR_COST * flats
		_show_message("The crew patched %d flat tyre%s. -$%d" % [flats, "" if flats == 1 else "s", REPAIR_COST * flats])


## Fast travel: the crew shuttles you (truck and all) to another built base.
## Not while you have a job: the cargo would have to come too.
func _travel_options() -> Array:
	var here := _station_here()
	var list := []
	for st in stations:
		if not st["built"] or (not here.is_empty() and st["id"] == here["id"]):
			continue
		var ok := not has_job and money >= TRAVEL_COST
		var why := "Finish your job first." if has_job else ("Not enough money." if money < TRAVEL_COST else "")
		list.append({"id": st["id"], "name": st["name"], "cost": TRAVEL_COST, "ok": ok, "why": why})
	return list


func _fast_travel(id: String) -> void:
	var st := _station(id)
	if st.is_empty() or not st["built"] or has_job or money < TRAVEL_COST:
		return
	money -= TRAVEL_COST
	Achievements.unlock("ACH_FAST_TRAVEL")
	var pos: Vector3 = st["pos"]
	terrain.ensure_active_at(pos.x, pos.z)
	_release_scorpions()
	car.place_at(_on_ground(pos) + Vector3(0, 0.8, 0), car.global_rotation.y)
	_sync_trailer()
	_was_at_base = true
	_service_truck()
	offers = _make_offers()
	_save_game()
	_refresh_menu()
	sfx.play("click")
	_show_message("The crew shuttle drops you at the %s. -$%d" % [st["name"], TRAVEL_COST])


# ---------------------------------------------------------------------------
# Ring 3: the Drift (low gravity, sand rivers, drift rays, the hull)
# ---------------------------------------------------------------------------

## Physics things that feel the Drift: the truck, its trailer, the cargo.
func _drift_bodies() -> Array[RigidBody3D]:
	var list: Array[RigidBody3D] = [car]
	if trailer:
		list.append(trailer)
	if cargo and not cargo.freeze:
		list.append(cargo)
	return list


func _update_drift(delta: float) -> void:
	for body in _drift_bodies():
		var p := body.global_position
		# Low gravity: Godot multiplies the world's gravity by gravity_scale.
		body.gravity_scale = terrain.gravity_at(p.x, p.z)
		# Sand rivers: anything sitting in one is carried downstream, like a
		# boat in a current: a force that pulls its speed towards the flow.
		var ground := terrain.get_height(p.x, p.z)
		if p.y - ground > 0.9:
			continue                     # in the air: rivers can't touch it
		var fv := terrain.get_flow_velocity(p.x, p.z)
		if fv == Vector3.ZERO:
			continue
		var v := body.linear_velocity
		v.y = 0.0
		var grip := 2.5   # (light loose cargo floats off fastest)
		var along := (fv - v).dot(fv.normalized())
		body.apply_central_force(fv.normalized() * maxf(along, 0.0) * body.mass * grip)
	# Drift rays: placed once their patch of the world exists.
	for i in RAY_AREAS.size():
		if not _rays_placed.has(i):
			_try_place_ray(i)
	for r in rays:
		r.update_ray(delta, car)


## Find the strongest river point near the area and put a ray there.
func _try_place_ray(i: int) -> void:
	var a: Vector3 = RAY_AREAS[i]
	if terrain.tile_at(a.x, a.z) == null:
		return                           # not generated yet: try again later
	var best := Vector3.INF
	var best_f := 0.75
	for dz in range(-24, 25, 2):
		for dx in range(-24, 25, 2):
			var f := terrain.get_flow(a.x + dx, a.z + dz)
			if f > best_f:
				best_f = f
				best = Vector3(a.x + dx, 0, a.z + dz)
	_rays_placed[i] = true
	if best == Vector3.INF:
		return                           # no river here
	var r := DriftRay.new()
	r.terrain = terrain
	r.home = best
	add_child(r)
	r.struck.connect(func():
		jolt(1.0)
		_show_message("A DRIFT RAY flipped up under you! (Cross rivers faster than 3 m/s, or build a gyro.)")
		sfx.play("thud", car.global_position, 2.0, 0.6)
		SandDust.burst(self, car.global_position, 1.5))
	r.hunting.connect(func():
		_show_message("Something is moving in the river towards you...")
		sfx.play("beetle_hiss", r.global_position, 0.0, 0.6))
	rays.append(r)


## The hull: a huge curved metal ship, half buried by point R. Blinking.
func _build_hull() -> void:
	var at := _on_ground(HULL_POS)
	var body := StaticBody3D.new()
	add_child(body)
	body.global_position = at + Vector3(0, -0.6, 0)
	body.rotation.y = 0.5
	body.add_child(Models.make("hull"))
	for spec in [[Vector3(4.0, 2.4, 13.0), Vector3(0, 1.0, 0)], [Vector3(2.4, 1.2, 4.0), Vector3(0, 2.6, -2.0)]]:
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = spec[0]
		col.shape = box
		col.position = spec[1]
		body.add_child(col)
	for k in 3:
		var blink := OmniLight3D.new()
		blink.light_color = Color(0.4, 0.85, 1.0)
		blink.omni_range = 6.0
		blink.light_energy = 1.5
		body.add_child(blink)
		blink.position = Vector3(1.9, 2.0, -3.0 + k * 3.5)
		var tw := create_tween().set_loops()
		tw.tween_property(blink, "light_energy", 0.1, 0.8 + k * 0.3).set_delay(k * 0.4)
		tw.tween_property(blink, "light_energy", 1.8, 0.4)


# ---------------------------------------------------------------------------
# Building: workshop, trailer, cargo net
# ---------------------------------------------------------------------------

func _open_workshop() -> void:
	if not _at_base():
		return
	_close_menu()
	hud.visible = false
	car.release_winch()
	workshop.enter()


## The workshop changed the build: make a new truck from it.
func apply_build() -> void:
	_rebuild_car()
	_save_game()


func show_message(text: String) -> void:
	_show_message(text)


## Cargo rides on the trailer if there is one, else on the truck.
func _cargo_anchor() -> Node3D:
	return trailer.cargo_anchor if trailer else car.cargo_anchor


## Make the trailer match the build: hitch fitted = trailer attached behind.
func _sync_trailer() -> void:
	if trailer:
		var old := trailer
		trailer = null
		remove_child(old)
		old.detach_and_free()
	if car.has_hitch:
		trailer = Trailer.new()
		trailer.terrain = terrain
		add_child(trailer)
		trailer.attach_to(car)


## The cargo net is a real JOINT: a Generic6DOFJoint3D with everything locked
## ties the cargo to the bed. It holds through bumps and beetle rams, and
## snaps (we delete it) in a hard crash.
func _strap_cargo() -> void:
	_unstrap_cargo()
	if not car.has_net or cargo == null or not _crate_on_truck():
		return
	var carrier: Node3D = trailer if trailer else car
	_net_joint = Generic6DOFJoint3D.new()
	add_child(_net_joint)
	_net_joint.global_transform = Transform3D(carrier.global_basis, cargo.global_position)
	_net_joint.node_a = _net_joint.get_path_to(carrier)
	_net_joint.node_b = _net_joint.get_path_to(cargo)


func _unstrap_cargo() -> void:
	if _net_joint:
		_net_joint.queue_free()
		_net_joint = null


## A crew member runs out from the crowd carrying a box to `pos`.
func crew_carry_to(pos: Vector3) -> void:
	var a := randf() * TAU
	var from := _on_ground(_here_pos() + Vector3(cos(a), 0, sin(a)) * (BASE_RADIUS + 1.5))
	var to := _on_ground(Vector3(pos.x, 0, pos.z) + (Vector3(pos.x, 0, pos.z) - Vector3(car.global_position.x, 0, car.global_position.z)).normalized() * 0.25)
	var fig := TinyFigure.make(Color(0.95, 0.55, 0.15), 0.3)
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.14, 0.1, 0.14)
	box.mesh = bm
	box.position.y = 0.35
	fig.add_child(box)
	add_child(fig)
	fig.global_position = from
	fig.look_at_from_position(from, Vector3(to.x, from.y, to.z) + Vector3(0.001, 0, 0))
	var tw := create_tween()
	tw.tween_property(fig, "global_position", to, 0.5)
	tw.tween_callback(box.queue_free)
	tw.tween_property(fig, "global_position", to + Vector3.UP * 0.15, 0.1)
	tw.tween_property(fig, "global_position", to, 0.1)
	tw.tween_property(fig, "global_position", from, 0.5)
	tw.tween_callback(fig.queue_free)


# ---------------------------------------------------------------------------
# Saving: money, deliveries and parts, as a small JSON text file.
# ---------------------------------------------------------------------------

func _save_game() -> void:
	if _is_test():
		return   # tests never touch your real save
	if title_screen and title_screen.visible:
		return   # still on the title screen: nothing to save yet
	var data := {"save_version": SAVE_VERSION, "money": money, "deliveries": deliveries, "fitted": fitted, "owned": owned,
		"build": build, "inventory": inventory, "story": story_progress, "time": day_night.time,
		"outposts": stations.filter(func(st): return st["built"] and st["id"] != "home").map(func(st): return st["id"]),
		"glass_rescue_used": _glass_rescue_used}
	# Written to a temp file and swapped in: a crash mid-save can't break it.
	SaveIO.write_json(SAVE_PATH, data)


func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return   # broken file: start fresh rather than crash
	# (save_version: 1 = milestones 1-7, 2 = adds glass_rescue_used. Older
	# saves just get the defaults for anything they don't have.)
	money = int(data.get("money", 0))
	_glass_rescue_used = bool(data.get("glass_rescue_used", false))
	story_progress = int(data.get("story", 0))
	if data.get("outpost", false):
		_build_outpost("outpost")       # (saves from milestone 5)
	for id in data.get("outposts", []):
		_build_outpost(str(id))
	day_night.time = float(data.get("time", day_night.time))
	deliveries = int(data.get("deliveries", 0))
	for slot in Parts.SLOTS:
		var have: Array = data.get("owned", {}).get(slot, [])
		for id in have:
			if Parts.CATALOGUE[slot].has(id) and not id in owned[slot]:
				owned[slot].append(id)
		var fit: String = data.get("fitted", {}).get(slot, "")
		if fit in owned[slot]:
			fitted[slot] = fit
	for socket_id in data.get("build", {}):
		var part_id: String = data["build"][socket_id]
		if BuildParts.CATALOGUE.has(part_id) and BuildParts.SOCKETS.has(socket_id) and BuildParts.fits(part_id, socket_id):
			build[socket_id] = part_id
	for part_id in data.get("inventory", {}):
		if BuildParts.CATALOGUE.has(part_id):
			inventory[part_id] = int(data["inventory"][part_id])
	if car.parts != fitted or not build.is_empty():
		_rebuild_car()
	print("Loaded save: $%d, %d deliveries" % [money, deliveries])


func _open_menu() -> void:
	menu.visible = true
	if not has_job:
		offers = _make_offers()   # each base has its own board
	_refresh_menu()


func _close_menu() -> void:
	menu.visible = false


func _refresh_menu() -> void:
	var job_text := "No job right now."
	if has_job:
		job_text = "Current job: %s to %s, for $%d.\nFinish it before taking another." % [
			Cargo.TYPES[contract["cargo"]]["name"], Contracts.spot_name(int(contract["dest"])), contract["pay"]]
	var note := ""
	if not has_job and story_progress < Story.CONTRACTS.size():
		var next: Dictionary = Story.CONTRACTS[story_progress]
		var here := _station_here()
		var here_id: String = here["id"] if not here.is_empty() else "home"
		if next.get("from", "home") != here_id:
			note = "Next story job, \"%s\", starts at the %s." % [next["title"],
					_station(next.get("from", "home"))["name"]]
		elif next.get("night", false) and not day_night.is_night():
			note = "Next story job, \"%s\", is a night job. Come back after dark, or wait." % next["title"]
	elif story_progress >= Story.CONTRACTS.size():
		note = "Story complete! Ring 3 is coming in the next milestone."
	menu.refresh({
		"story_note": note,
		"money": money,
		"offers": [] if has_job else offers,
		"job_text": job_text,
		"fitted": fitted,
		"owned": owned,
		"travel": _travel_options(),
	})


func _on_contract_picked(i: int) -> void:
	if has_job or i >= offers.size():
		return
	_start_contract(offers[i])
	_close_menu()
	_play_crew_fitting()
	_show_message("The crew loaded the %s. Deliver it to %s! (%s for the map)" % [
		cargo.display_name().to_lower(), Contracts.spot_name(target_index), GameInput.prompt("map")])


func _start_contract(c: Dictionary) -> void:
	contract = c
	has_job = true
	_contract_time = 0.0
	_load_cargo(c["cargo"])
	_set_target(c["dest"])


## Buy a part (if not owned) and fit it. The crew swarms the truck.
func _on_part_clicked(slot: String, id: String) -> void:
	var part := Parts.get_part(slot, id)
	if not id in owned[slot]:
		if money < part["price"]:
			return
		money -= part["price"]
		owned[slot].append(id)
	fitted[slot] = id
	_play_crew_fitting()
	_rebuild_car()
	_refresh_menu()
	_save_game()
	_show_message("Fitted: %s" % part["name"])


## Parts change how the truck is built, so build a new one in the same spot.
## Rumble for landings, cargo falling off and wheelspin, plus the
## achievements that are about where you are rather than what just happened.
func _update_feel_and_achievements(delta: float) -> void:
	if _is_test():
		return
	var touching := 0
	for w in car.wheels:
		touching += 1 if w.is_in_contact() else 0
	var vy := car.linear_velocity.y
	if touching > 0 and _last_vy < -3.5:
		jolt(clampf(-_last_vy / 8.0, 0.3, 1.0))      # hard landing
	_last_vy = vy if touching == 0 else 0.0
	var dropped := _crate_dropped()
	if dropped and not _was_dropped:
		GameInput.rumble(0.5, 0.15, 0.25)              # it fell off!
	_was_dropped = dropped
	if car.get_spin_amount() > 0.6 and car.get_ground_hardness() < 0.4:
		GameInput.rumble(0.12, 0.0, 0.1)               # wheels churning sand
	var ring := terrain.ring_at(car.global_position.x, car.global_position.z)
	if ring >= 1:
		Achievements.unlock("ACH_RING_SALT")
	if ring >= 2:
		Achievements.unlock("ACH_RING_GLASS")
	if ring >= 3:
		Achievements.unlock("ACH_RING_DRIFT")
	_air_time = _air_time + delta if touching == 0 and ring == 3 else 0.0
	if _air_time >= 5.0:
		Achievements.unlock("ACH_DRIFT_AIR")
	if build.size() >= BuildParts.SOCKETS.size():
		Achievements.unlock("ACH_FULL_BUILD")


func _rebuild_car() -> void:
	var xform := car.global_transform
	var charge := car.get_battery_percent()
	var cargo_was_on := cargo != null and _crate_on_truck()
	var old := car
	remove_child(old)          # remove NOW, so the two trucks never overlap
	old.queue_free()
	car = RCCar.new()
	car.terrain = terrain
	car.parts = fitted.duplicate()
	car.build = build.duplicate()
	add_child(car)
	car.global_transform = xform
	car.reset_physics_interpolation()
	car.battery = car.battery_capacity * charge / 100.0
	for b in beetles:
		b.target = car
	_release_scorpions()
	_attach_car_sounds()
	_sync_trailer()
	if cargo_was_on:
		_put_cargo_on_bed()
		cargo.linear_velocity = Vector3.ZERO
		cargo.reset_physics_interpolation()
		cargo.reset_impact_tracking()
		_strap_cargo()


## The fun part: a gang of tiny crew run out, swarm the truck, and run back.
func _play_crew_fitting() -> void:
	sfx.play("ratchet", car.global_position)
	var colors := [Color(0.95, 0.55, 0.15), Color(0.2, 0.55, 0.95), Color(0.3, 0.75, 0.35)]
	var center := car.global_position
	for n in 18:
		var fig := TinyFigure.make(colors[n % 3], 0.3)
		add_child(fig)
		var a := randf() * TAU
		var from := _on_ground(_here_pos() + Vector3(cos(a), 0, sin(a)) * (BASE_RADIUS + 1.5))
		var at := Vector3(center.x, 0, center.z) + Vector3(cos(a), 0, sin(a)) * randf_range(0.6, 1.0)
		at = _on_ground(at)
		fig.global_position = from
		fig.look_at_from_position(from, Vector3(at.x, from.y, at.z) + Vector3(0.001, 0, 0))
		var tw := create_tween()
		tw.tween_interval(randf() * 0.25)
		tw.tween_property(fig, "global_position", at, 0.45)
		for hop in 3:   # hammering away
			tw.tween_property(fig, "global_position", at + Vector3.UP * 0.12, 0.1)
			tw.tween_property(fig, "global_position", at, 0.1)
		tw.tween_property(fig, "global_position", from, 0.45)
		tw.tween_callback(fig.queue_free)


## H: the crew comes to tow you home. Your cargo comes too if it's on the truck.
func _rescue() -> void:
	if _at_base():
		return
	money -= RESCUE_COST
	if story_progress >= 16 and story_progress < 22:
		_glass_rescue_used = true     # (story jobs 17-22 are the Glass Desert)
	var cargo_was_on := cargo != null and _crate_on_truck()
	var home: Dictionary = _nearest_station()
	terrain.ensure_active_at(home["pos"].x, home["pos"].z)
	_release_scorpions()
	car.place_at(_on_ground(home["pos"]) + Vector3(0, 0.8, 0), PI)
	_sync_trailer()
	if cargo_was_on:
		_put_cargo_on_bed()
		cargo.linear_velocity = Vector3.ZERO
		cargo.reset_physics_interpolation()
		cargo.reset_impact_tracking()
		_strap_cargo()
	_save_game()
	_show_message("Towed back to %s. -$%d" % [home["name"], RESCUE_COST])


func _on_cargo_stolen(colony: AntColony) -> void:
	if cargo == null:
		return
	SandDust.burst(self, colony.global_position, 1.5)
	GameInput.rumble(0.5, 0.2, 0.3)
	var what := cargo.display_name()
	cargo.queue_free()
	cargo = null
	has_job = false
	beacon.visible = false
	offers = _make_offers()
	sfx.play("fail")
	_show_message("The ants took your %s! Contract failed. Back to base." % what.to_lower())


## Floating letters over each delivery point, so you can find them.
func _add_spot_labels() -> void:
	for i in DELIVERY_SPOTS.size():
		var l := Label3D.new()
		var site_of := ""
		for st in stations:
			if st.get("site", -1) == i:
				site_of = st["id"]
				l.text = st["name"] + " site"
		var site := site_of != ""
		if not site:
			l.text = spot_letter(i)
		l.font_size = 64
		l.pixel_size = 0.01
		l.outline_size = 12
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.modulate = Color(1, 1, 1, 0.8)
		add_child(l)
		l.global_position = _on_ground(DELIVERY_SPOTS[i]) + Vector3(0, 1.6, 0)
		if site:
			# Replaced by the outpost's own sign once it's built.
			var nodes: Array = _site_nodes.get(site_of, [])
			nodes.append(l)
			_site_nodes[site_of] = nodes


# ---------------------------------------------------------------------------
# Dropped crates
# ---------------------------------------------------------------------------

func _crate_on_truck() -> bool:
	return cargo != null and cargo.global_position.distance_to(_cargo_anchor().global_position) < 0.8


func _crate_dropped() -> bool:
	return has_job and cargo != null and not _loading and not _crate_on_truck() and not _hawk_has_cargo()


## E: if the truck is parked next to the dropped crate, lift it back on.
## (Imagine your tiny driver hopping off and heaving it up.)
func _try_load_crate() -> void:
	if not _crate_dropped():
		return
	var to_crate := cargo.global_position - car.global_position
	to_crate.y = 0.0
	if to_crate.length() > 2.8:
		_show_message("Get closer to the crate (%d m away)" % int(to_crate.length()))
		return
	if car.linear_velocity.length() > 1.5:
		_show_message("Stop the truck first!")
		return
	_loading = true
	_load_t = 0.0
	# Snatched back from the ants?
	for colony in colonies:
		if colony.state != AntColony.State.HOME and colony.state != AntColony.State.RETURNING:
			Achievements.add("ant_recover", 1, 5, "ACH_ANT_RECOVER")
			break
	_load_from = cargo.global_transform
	_unstrap_cargo()
	cargo.set_carried(true)   # we move it ourselves for a moment


## Animate the crate in an arc onto the truck bed.
func _update_loading(delta: float) -> void:
	if not _loading or cargo == null:
		return
	_load_t = minf(_load_t + delta / 0.7, 1.0)
	var to := _cargo_anchor().global_transform
	var pos := _load_from.origin.lerp(to.origin, _load_t) + Vector3.UP * sin(_load_t * PI) * 1.0
	var rot := _load_from.basis.orthonormalized().slerp(to.basis.orthonormalized(), _load_t)
	cargo.global_transform = Transform3D(rot, pos)
	if _load_t >= 1.0:
		_loading = false
		cargo.set_carried(false)
		cargo.linear_velocity = car.linear_velocity
		cargo.reset_impact_tracking()
		_strap_cargo()
		_show_message("Crate back on board!")


## C: the crew sends a new crate (if yours is lost or wrecked). Costs $10.
func _call_replacement_crate() -> void:
	if not has_job:
		return
	money -= 10
	_load_cargo(contract.get("cargo", "crate"))
	_show_message("The crew sent a replacement %s. -$10" % cargo.display_name().to_lower())


func _on_crate_impact(pos: Vector3, speed_change: float, on_sand: bool) -> void:
	if _net_joint and speed_change > NET_BREAK:
		_unstrap_cargo()
		_show_message("The cargo net snapped!")
	if not on_sand or _impact_cooldown > 0.0:
		return
	_impact_cooldown = 0.25
	sfx.play("thud", pos, linear_to_db(clampf(speed_change / 6.0, 0.2, 1.0)))
	# Dent the sand, stamp the crate's shape into it, and throw up some dust.
	terrain.press(pos, 0.3, speed_change * 0.02, minf(speed_change * 0.03, 0.15))
	if terrain.tracks:
		var fwd := cargo.global_basis.z
		fwd.y = 0.0
		terrain.tracks.stamp(SandTracks.CRATE, cargo.global_position, fwd.normalized(),
				Vector2(0.7, 0.7), clampf(speed_change / 4.0, 0.3, 1.2))
	SandDust.burst(self, pos, clampf(speed_change * 0.6, 0.8, 3.0))


func _on_crate_smashed() -> void:
	if cargo == null:
		return
	_unstrap_cargo()
	SandDust.burst(self, cargo.global_position, 3.0)
	var what := cargo.display_name()
	cargo.queue_free()
	cargo = null
	has_job = false
	beacon.visible = false
	sfx.play("fail")
	_show_message("%s ruined! Contract failed. Drive back to base for a new job." % what)
	offers = _make_offers()


func _make_crate_marker() -> Node3D:
	var root := Node3D.new()
	var arrow := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.18
	cone.bottom_radius = 0.0
	cone.height = 0.35
	arrow.mesh = cone
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.55, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.1)
	mat.emission_energy_multiplier = 2.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arrow.material_override = mat
	root.add_child(arrow)
	var label := Label3D.new()
	label.text = "your crate"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true      # visible even behind a dune
	label.position.y = 0.4
	label.pixel_size = 0.004
	label.outline_size = 8
	root.add_child(label)
	root.visible = false
	return root


func _update_crate_marker() -> void:
	var show := _crate_dropped()
	crate_marker.visible = show
	if show:
		var bob := sin(Time.get_ticks_msec() * 0.005) * 0.08
		crate_marker.global_position = cargo.get_global_transform_interpolated().origin + Vector3(0, 0.75 + bob, 0)


## The letter shown on a delivery point (A-R; the outpost sites have none).
func spot_letter(i: int) -> String:
	return Contracts.spot_letter(i)


func _on_ground(p: Vector3) -> Vector3:
	return Vector3(p.x, terrain.get_height(p.x, p.z), p.z)


# ---------------------------------------------------------------------------
# Camera: follows behind the car, smoothed
# ---------------------------------------------------------------------------

func _update_camera(delta: float) -> void:
	# Follow where the car is DRAWN this frame (smoothed between physics
	# steps), not its raw physics position, or the camera would stutter.
	var car_xform := car.get_global_transform_interpolated()
	var car_pos := car_xform.origin
	var fwd := car_xform.basis.z    # the car's front is +Z
	fwd.y = 0.0
	if fwd.length() < 0.1:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized()
	# Look around with the right stick (or right mouse); let go and after 2 s
	# it swings back behind the truck. R3 snaps it back at once.
	var stick := Vector2(Input.get_axis("cam_left", "cam_right"), Input.get_axis("cam_up", "cam_down"))
	if stick.length() > 0.05:
		var sens: float = Settings.get_value("camera_sensitivity") * 0.45
		_cam_yaw -= stick.x * sens * delta * (-1.0 if Settings.get_value("invert_x") else 1.0)
		_cam_pitch += stick.y * sens * delta * (-1.0 if Settings.get_value("invert_y") else 1.0)
		_cam_idle = 0.0
	else:
		_cam_idle += delta
	if Input.is_action_just_pressed("cam_recentre"):
		_cam_idle = 99.0
	if _cam_idle > 2.0:
		var back := 1.0 - exp(-(30.0 if _cam_idle > 50.0 else 3.0) * delta)
		_cam_yaw = lerpf(_cam_yaw, 0.0, back)
		_cam_pitch = lerpf(_cam_pitch, 0.0, back)
	_cam_yaw = wrapf(_cam_yaw, -PI, PI)
	var base_pitch := atan2(2.6, 5.0)                     # ~27 degrees above
	var pitch := clampf(base_pitch + _cam_pitch, deg_to_rad(5.0), deg_to_rad(60.0))
	_cam_pitch = pitch - base_pitch
	var dist := Vector2(5.0, 2.6).length()
	var dir := (-fwd).rotated(Vector3.UP, _cam_yaw)
	var want := car_pos + dir * cos(pitch) * dist + Vector3.UP * sin(pitch) * dist
	# Don't go under the sand.
	want.y = maxf(want.y, terrain.get_height(want.x, want.z) + 0.8)
	var t := 1.0 - exp(-4.0 * delta)   # frame-rate independent smoothing
	camera.global_position = camera.global_position.lerp(want, t)
	camera.look_at(car_pos + Vector3.UP * 0.6)
	# Camera shake (rams, hard landings), if it's switched on in Options.
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 2.5, 0.0)
		if Settings.get_value("camera_shake"):
			camera.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.08


## A jolt: rumble the controller and shake the camera.
func jolt(strength: float) -> void:
	GameInput.rumble(strength * 0.6, strength, 0.25 + strength * 0.2)
	_shake = maxf(_shake, strength)


# ---------------------------------------------------------------------------
# World dressing
# ---------------------------------------------------------------------------

func _build_environment() -> void:
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.0
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.shadow_enabled = true
	add_child(sun)

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.3, 0.5, 0.82)
	sky_mat.sky_horizon_color = Color(0.88, 0.8, 0.68)
	sky_mat.ground_horizon_color = Color(0.85, 0.72, 0.55)
	sky_mat.ground_bottom_color = Color(0.55, 0.45, 0.33)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


## Switch between the simple look and the high-quality look (G key).
func _apply_quality() -> void:
	if high_quality:
		# Light bouncing off the sky and sand, like real daylight.
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 1.0
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		# AgX keeps bright sand from blowing out to white.
		env.tonemap_mode = Environment.TONE_MAPPER_AGX
		env.tonemap_exposure = 1.15
		# AgX is gentle and slightly grey: win back some punch.
		env.adjustment_enabled = true
		env.adjustment_contrast = 1.12
		env.adjustment_saturation = 1.12
		env.adjustment_brightness = 1.0
		# Ambient occlusion: soft contact shadows under the truck, in ruts,
		# around the crowd's feet. Radius about half a truck length.
		env.ssao_enabled = true
		env.ssao_radius = 0.9
		env.ssao_intensity = 1.6
		env.ssao_power = 1.5
		# Screen-space indirect light: sunlit sand bounces warm light onto things.
		env.ssil_enabled = true
		env.ssil_radius = 1.8
		env.ssil_intensity = 0.8
		# Desert haze that the sunlight glows through (thin: the horizon was
		# washing out), plus distance fog that fades far dunes into the sky
		# ("aerial perspective": how real distance looks).
		env.fog_enabled = true
		env.fog_density = 0.0015
		env.fog_aerial_perspective = 0.6
		env.fog_sun_scatter = 0.15
		env.fog_sky_affect = 0.0
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.002
		env.volumetric_fog_albedo = Color(0.95, 0.86, 0.72)
		env.volumetric_fog_anisotropy = 0.5
		env.volumetric_fog_length = 96.0
		env.volumetric_fog_sky_affect = 0.25   # keep the sky mostly clear
		# A gentle glow so sand glints sparkle.
		env.glow_enabled = true
		env.glow_intensity = 0.5
		env.glow_bloom = 0.05
		env.glow_hdr_threshold = 1.1
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
		# Medium: the same look without the two most expensive effects.
		if quality < 2:
			env.ssil_enabled = false
			env.volumetric_fog_enabled = false
			env.fog_density = 0.003
		# Soft-edged shadows, like the real sun (it's not a point).
		sun.light_angular_distance = 0.5
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		sun.directional_shadow_max_distance = 50.0
	else:
		# Cheap and simple: fixed ambient light, plain distance fog.
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.6, 0.65, 0.8)
		env.ambient_light_energy = 0.5
		env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.adjustment_enabled = false
		env.ssao_enabled = false
		env.ssil_enabled = false
		env.volumetric_fog_enabled = false
		env.glow_enabled = false
		env.fog_enabled = true
		env.fog_sky_affect = 0.0
		env.fog_light_color = Color(0.9, 0.8, 0.65)
		env.fog_density = 0.004
		sun.light_angular_distance = 0.0
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_max_distance = 35.0

	# Tilt-shift: blur near and far so the world looks like a miniature
	# photographed up close. That's what sells "you are tiny" (T key).
	if high_quality and tilt_shift:
		var cam_fx := CameraAttributesPractical.new()
		cam_fx.dof_blur_far_enabled = true
		cam_fx.dof_blur_far_distance = 16.0
		cam_fx.dof_blur_far_transition = 14.0
		cam_fx.dof_blur_near_enabled = true
		cam_fx.dof_blur_near_distance = 1.2
		cam_fx.dof_blur_near_transition = 1.0
		cam_fx.dof_blur_amount = TILT_SHIFT_BLUR
		camera.attributes = cam_fx
	else:
		camera.attributes = null


## Tilt-shift strength (60% of the first version: enough to feel tiny, not
## so much it smears the picture). It fades out at speed and on the map.
const TILT_SHIFT_BLUR := 0.048


func _update_tilt_shift(delta: float) -> void:
	var fx := camera.attributes as CameraAttributesPractical
	if fx == null:
		return
	var want := TILT_SHIFT_BLUR
	want *= 1.0 - smoothstep(5.0, 9.0, car.linear_velocity.length())   # fast: see where you're going
	if map_overlay.visible:
		want = 0.0
	fx.dof_blur_amount = move_toward(fx.dof_blur_amount, want, delta * 0.1)


## Each ring tints the haze its own colour: warm sand, white salt, cold
## iron, lilac. Blended smoothly as the camera moves between rings.
const RING_HAZE: Array[Color] = [Color(1.0, 0.9, 0.75), Color(0.95, 0.96, 1.0),
		Color(0.7, 0.75, 0.82), Color(0.85, 0.78, 1.0)]


func _update_haze(delta: float) -> void:
	var p := camera.global_position
	var want: Color = RING_HAZE[terrain.ring_at(p.x, p.z)]
	day_night.haze_tint = day_night.haze_tint.lerp(want, 1.0 - exp(-1.5 * delta))


func _rendering_method() -> String:
	if RenderingServer.has_method("get_current_rendering_method"):
		return RenderingServer.call("get_current_rendering_method")
	return str(ProjectSettings.get_setting("rendering/renderer/rendering_method"))


## The base pad is a DECAL: an image projected down onto whatever is below
## it, so it follows the sand when wheels churn it up (a flat disc would poke
## through). It only paints the sand layer, not trucks driving over it.
## Repaint it: textures/decals/base_pad.png
## The landing pad at a base: the Blender model (concrete slabs, painted
## rings, a kerb and four lamps). It's only looks: the ground under it was
## already flattened and made hard by the terrain.
func _build_base_pad(where: Vector3) -> Node3D:
	var pad := Models.make("landing_pad")
	add_child(pad)
	pad.global_position = _on_ground(where) - Vector3(0, 0.015, 0)
	return pad


func _make_beacon() -> Node3D:
	var root := Node3D.new()
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.3, 0.7, 1.0, 0.35)
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.emission_enabled = true
	glow.emission = Color(0.3, 0.7, 1.0)
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	if _rendering_method() == "gl_compatibility":
		var ring := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = DELIVERY_RADIUS
		cyl.bottom_radius = DELIVERY_RADIUS
		cyl.height = 0.06
		ring.mesh = cyl
		ring.material_override = glow
		root.add_child(ring)
	else:
		# A glowing ring projected onto the sand (textures/decals/delivery_ring.png).
		var ring_tex: Texture2D = load("res://textures/decals/delivery_ring.png")
		var d := Decal.new()
		d.size = Vector3(DELIVERY_RADIUS * 2.0 + 0.3, 3.0, DELIVERY_RADIUS * 2.0 + 0.3)
		d.texture_emission = ring_tex   # glow only: the ring is light, not paint
		d.emission_energy = 3.0
		d.cull_mask = SandTerrain.SAND_RENDER_LAYER
		root.add_child(d)

	var pole := MeshInstance3D.new()
	var pc := CylinderMesh.new()
	pc.top_radius = 0.08
	pc.bottom_radius = 0.08
	pc.height = 12.0
	pole.mesh = pc
	pole.position.y = 6.0
	pole.material_override = glow
	root.add_child(pole)
	return root


# ---------------------------------------------------------------------------
# Enemies
# ---------------------------------------------------------------------------

func _spawn_beetle(home: Vector3) -> DungBeetle:
	var b := DungBeetle.new()
	b.target = car
	b.terrain = terrain
	b.safe_center = BASE_POS     # the crew protects you at base
	b.safe_radius = 14.0         # (8 m let one ram a new player right at the exit)
	b.position = _on_ground(home) + Vector3(0, 0.5, 0)
	add_child(b)
	b.started_charge.connect(func(bb):
		_show_message("Beetle charging!")
		sfx.play("beetle_hiss", bb.global_position))
	b.rammed.connect(func(_b):
		_show_message("RAMMED!")
		jolt(1.0)
		sfx.play("thud", car.global_position, 2.0)
		SandDust.burst(self, car.global_position + Vector3.DOWN * 0.3, 2.0))
	beetles.append(b)
	return b


# ---------------------------------------------------------------------------
# Graphics card info
# ---------------------------------------------------------------------------

## Which GPU and renderer Godot is actually using. If this names your
## integrated graphics (Intel / AMD Radeon "Graphics") instead of your
## gaming card, see the README section "Is it using my graphics card?".
func _describe_gpu() -> String:
	var gpu := RenderingServer.get_video_adapter_name()
	var method := str(ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	if RenderingServer.has_method("get_current_rendering_method"):
		method = RenderingServer.call("get_current_rendering_method")
	var driver := ""
	if RenderingServer.has_method("get_current_rendering_driver_name"):
		driver = RenderingServer.call("get_current_rendering_driver_name")
	return "GPU: %s  (%s %s)" % [gpu, driver, method]


## V cycles through the ways of syncing frames to your screen:
##   On       classic V-Sync: no tearing, a little input lag.
##   Mailbox  triple buffering: no tearing, less lag (if your driver has it).
##   Adaptive V-Sync, but tears instead of stuttering when FPS drops.
##   Off      fastest, but the picture TEARS when things move fast.
## Tearing while it's On? See "Screen tearing" in the README: the usual cause
## is running the game embedded in the editor window.
const VSYNC_MODES := [
	[DisplayServer.VSYNC_ENABLED, "On"],
	[DisplayServer.VSYNC_MAILBOX, "Mailbox (triple buffered)"],
	[DisplayServer.VSYNC_ADAPTIVE, "Adaptive"],
	[DisplayServer.VSYNC_DISABLED, "Off (may tear)"],
]

func _toggle_vsync() -> void:
	var now := DisplayServer.window_get_vsync_mode()
	var i := 0
	for k in VSYNC_MODES.size():
		if VSYNC_MODES[k][0] == now:
			i = k
	var next: Array = VSYNC_MODES[(i + 1) % VSYNC_MODES.size()]
	DisplayServer.window_set_vsync_mode(next[0])
	# The driver may not support a mode: report what we actually got.
	var got := DisplayServer.window_get_vsync_mode()
	var label: String = ("unsupported here, still " + _vsync_name(got)) if got != next[0] else next[1]
	_show_message("V-Sync: %s" % label)


func _vsync_name(mode: int) -> String:
	for m in VSYNC_MODES:
		if m[0] == mode:
			return m[1]
	return "?"


# ---------------------------------------------------------------------------
# HUD
# ---------------------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(16, 12)
	hud.add_theme_font_size_override("font_size", 18)
	hud.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.add_theme_constant_override("outline_size", 6)
	layer.add_child(hud)
	message = Label.new()
	message.anchor_left = 0.5
	message.anchor_right = 0.5
	message.position = Vector2(-300, 80)
	message.size = Vector2(600, 40)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 26)
	message.add_theme_color_override("font_outline_color", Color.BLACK)
	message.add_theme_constant_override("outline_size", 8)
	layer.add_child(message)


func _show_message(text: String) -> void:
	message.text = text
	message.modulate.a = 1.0
	_message_time = 3.0


func _update_hud(delta: float) -> void:
	var lines: Array[String] = []
	var wind := "   WIND from the %s!" % weather.from_direction() if weather.is_gusting() else ""
	var region: String = ["Home Dunes", "Salt Flats", "Glass Desert", "The Drift"][terrain.ring_at(car.global_position.x, car.global_position.z)]
	lines.append("$%d   Deliveries: %d   Story: %d/%d   %s   %s %s%s" % [money, deliveries, story_progress,
			Story.CONTRACTS.size(), region, day_night.clock(), "night" if day_night.is_night() else "day", wind])
	if has_job:
		var t := _on_ground(DELIVERY_SPOTS[target_index])
		var title := ("\"%s\": " % contract["title"]) if contract.has("title") else ""
		lines.append("Job: %s%s to %s (%d m)   pays $%d" % [title, Cargo.TYPES[contract["cargo"]]["name"],
				Contracts.spot_name(target_index), int(car.global_position.distance_to(t)), contract["pay"]])
		if contract.has("deadline"):
			var left := float(contract["deadline"]) - _contract_time
			lines.append("Time left: %d s%s" % [maxi(int(left), 0), "  LATE (half pay)" if left < 0 else ""])
		if contract.has("min_condition"):
			lines.append("Client wants at least %d%% condition" % contract["min_condition"])
		if cargo == null:
			pass
		elif _hawk_has_cargo():
			lines.append("Cargo: CARRIED OFF BY A HAWK!")
		elif _loading:
			lines.append("Cargo: loading...")
		elif _crate_dropped():
			lines.append("Cargo DROPPED (%d%%): drive next to it and press %s   (%s = replacement, $10)" % [
					int(cargo.condition), GameInput.prompt("load_crate"), GameInput.prompt("call_crate")])
		else:
			lines.append("Cargo condition: %d%%" % int(cargo.condition))
	elif _at_base():
		lines.append("At base: %s for contracts and the garage" % GameInput.prompt("base_menu"))
	else:
		var st := _nearest_station()
		lines.append("No job. Return to %s: %d m" % [st["name"], int(car.global_position.distance_to(_on_ground(st["pos"])))])
	# Battery gauge: [#######---]
	var pct := car.get_battery_percent()
	var bars := int(round(pct / 10.0))
	var charging := "  charging" if _at_base() and pct < 100.0 else ""
	var flat := "  FLAT! (%s = rescue $%d)" % [GameInput.prompt("rescue"), RESCUE_COST] if pct <= 0.0 else ""
	lines.append("Battery [%s%s] %d%%%s%s" % ["#".repeat(bars), "-".repeat(10 - bars), int(pct), charging, flat])
	var hard := car.get_ground_hardness()
	var ground := "firm hardpan" if hard > 0.66 else ("soft sand" if hard < 0.33 else "mixed")
	lines.append("Speed %.1f m/s   Wheel spin %d%%   Ground: %s" % [car.linear_velocity.length(), int(car.get_spin_amount() * 100.0), ground])
	if _show_debug:
		var vsync := DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
		lines.append("")
		lines.append("FPS %d (V-Sync %s)   Frame %.1f ms   Physics %.1f ms   Draw calls %d" % [
			Engine.get_frames_per_second(), _vsync_name(DisplayServer.window_get_vsync_mode()),
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
		lines.append(gpu_info)
		lines.append("Sand: %s" % terrain.debug_stats())
	lines.append("")
	if car.winch_socket != "":
		lines.append("Winch: %s   (%s)" % ["REELING IN" if car.winch_anchor != Vector3.INF else "ready", GameInput.prompt("winch")])
	if car.has_net and cargo:
		lines.append("Cargo net: %s" % ("holding" if _net_joint else "not strapped"))
	if car.is_pinned():
		lines.append("SCORPION on a wheel! Hold the throttle to shake it off.")
	if car.flat_count() > 0:
		lines.append("FLAT TYRE x%d!  %s = fit a spare (%d on board), or limp to a base" % [car.flat_count(), GameInput.prompt("spare"), car.spares])
	if terrain.ring_at(car.global_position.x, car.global_position.z) == 2:
		var pull := magnet_force_at(car.global_position, car.metal_mass, magnet_strength()).length()
		lines.append("Metal on board: %d kg   Magnetic pull: %d N%s%s" % [int(car.metal_mass), int(pull),
				"   MAGNET STORM!" if storm_active() else "", "   on GLASS: slippery!" if car.get_glass_under() > 0.5 else ""])
	var grav := terrain.gravity_at(car.global_position.x, car.global_position.z)
	if grav < 0.99:
		var river := ""
		if car.get_flow_under() > 0.2:
			river = "   IN A SAND RIVER: %s" % ("skimming" if car.linear_velocity.length() > 4.0 else "sinking! Go faster or get out")
		lines.append("Gravity %d%%%s%s" % [int(grav * 100.0), river, "   gyro: righting you" if car.is_gyro_working() else ""])
	for h in [["reset", 0.5, "Flipping"], ["rescue", 1.0, "Calling the tow"]]:
		var prog := _hold_progress(h[0], h[1])
		if GameInput.using_pad and prog > 0.0 and prog < 1.0:
			lines.append("%s... [%s%s]" % [h[2], "#".repeat(int(prog * 10)), "-".repeat(10 - int(prog * 10))])
	lines.append("%s controls    %s map    %s pause" % [GameInput.prompt("help"), GameInput.prompt("map"), GameInput.prompt("pause")])
	hud.text = "\n".join(lines)
	_message_time -= delta
	message.modulate.a = clampf(_message_time, 0.0, 1.0)


# ---------------------------------------------------------------------------
# Automatic test: run with  godot -- --autotest  (drives by itself, prints, quits)
# ---------------------------------------------------------------------------

func _run_autotest(delta: float) -> void:
	_test_time += delta
	car.steer_input = 0.0
	car.brake_input = 0.0
	if _test_time < 1.0:
		car.throttle_input = 0.0                     # let it settle on the sand
	elif _test_time < 5.0:
		car.throttle_input = 1.0
		car.steer_input = 0.3 if _test_time > 3.5 else 0.0
	elif _test_time < 7.0:
		car.throttle_input = 0.0
		car.brake_input = 1.0
	elif _test_time < 9.0:
		# Pretend the car is stuck (pin it in place) and floor it: the wheels
		# should spin and dig a hole.
		car.axis_lock_linear_x = true
		car.axis_lock_linear_z = true
		car.throttle_input = 1.0
	elif _test_time < 9.5:
		car.axis_lock_linear_x = false
		car.axis_lock_linear_z = false
		car.throttle_input = 0.0
	else:
		var changed := 0
		var deepest := 0.0
		var home: SandTile = terrain.tiles[Vector2i.ZERO]
		for k in home.heights.size():
			var d := (home.original[k] - home.heights[k]) * home.cell_size
			if absf(d) > 0.005:
				changed += 1
			deepest = maxf(deepest, d)
		print("AUTOTEST car=", car.global_position, " up=", car.global_basis.y.y,
			" cargo_on=", cargo != null and cargo.global_position.distance_to(car.global_position) < 1.5,
			" changed_cells=", changed, " deepest_rut_m=", snappedf(deepest, 0.001),
			" worst_physics_ms=", snappedf(_worst_physics_ms, 0.01),
			" avg_physics_ms=", snappedf(_sum_physics_ms / maxi(_samples, 1), 0.01))
		print("PROFILE ms total: press=", terrain.prof_press_us / 1000, " settle=", terrain.prof_settle_us / 1000,
			" collision=", terrain.prof_collision_us / 1000, " mesh=", terrain.prof_mesh_us / 1000,
			" rebuilds=", terrain.prof_mesh_rebuilds, " frames=", Engine.get_process_frames(),
			" over ", Engine.get_physics_frames(), " physics ticks")
		get_tree().quit()
		return
	var ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	if _test_time > 1.0:
		_worst_physics_ms = maxf(_worst_physics_ms, ms)
		_sum_physics_ms += ms
		_samples += 1
	# Optional screenshots:  -- --autotest --shots=/some/folder
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots=") and Engine.get_physics_frames() % 60 == 0 and int(_test_time * 2) % 2 == 0:
			var img := get_viewport().get_texture().get_image()
			if img:
				img.save_png(a.substr(8) + "/shot_%02d.png" % int(_test_time))
	if Engine.get_physics_frames() % 60 == 0:
		var cd := cargo.global_position.distance_to(_cargo_anchor().global_position) if cargo else -1.0
		print("t=%.1f pos=%s speed=%.2f spin=%.2f cargo_offset=%.2f" % [_test_time, car.global_position, car.linear_velocity.length(), car.get_spin_amount(), cd])


# ---------------------------------------------------------------------------
# Soak test: drive around for a long time and check the game doesn't slow
# down.  godot --headless --path . -- --soaktest
# (A "soak test" catches problems that only appear over time, like the sand
# slowdown this was written to find.)
# ---------------------------------------------------------------------------

var _soak_ms := 0.0
var _soak_wp := 1
var _soak_stuck := 0.0
var _soak_resets := 0
var _soak_last_frames := 0
var _soak_n := 0

func _run_soaktest(delta: float) -> void:
	_test_time += delta
	car.battery = car.battery_capacity   # this test measures speed, not range
	# Drive a loop between the base and the delivery spots, like a player would.
	var route: Array[Vector3] = [BASE_POS]
	route.append_array(DELIVERY_SPOTS)
	var goal := route[_soak_wp % route.size()]
	var to_goal := goal - car.global_position
	to_goal.y = 0.0
	if to_goal.length() < 3.0:
		_soak_wp += 1
	var fwd := car.global_basis.z
	fwd.y = 0.0
	var angle := fwd.normalized().signed_angle_to(to_goal.normalized(), Vector3.UP)
	car.steer_input = clampf(angle * 2.0, -1.0, 1.0)
	car.throttle_input = 1.0
	car.brake_input = 0.0
	# Flipped or stuck for 3 seconds: reset like a player pressing R.
	_soak_stuck = _soak_stuck + delta if car.linear_velocity.length() < 0.5 else 0.0
	if car.global_basis.y.y < 0.3 or _soak_stuck > 3.0:
		_reset_car()
		_soak_stuck = 0.0
		_soak_resets += 1
	_soak_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_soak_n += 1
	if Engine.get_physics_frames() % 600 == 0:
		var frames := Engine.get_process_frames() - _soak_last_frames
		_soak_last_frames = Engine.get_process_frames()
		print("   fps=%d  physics_steps_per_frame=%.1f  objects=%d resources=%d nodes=%d draw_calls=%d vram_mb=%.1f static_mb=%.1f" % [
			Engine.get_frames_per_second(), 600.0 / maxi(frames, 1),
			Performance.get_monitor(Performance.OBJECT_COUNT),
			Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
		print("t=%3ds  avg_physics_ms=%.2f  %s  pos=(%d,%d) speed=%.1f waypoints=%d resets=%d" % [int(_test_time), _soak_ms / _soak_n, terrain.debug_stats(), car.global_position.x, car.global_position.z, car.linear_velocity.length(), _soak_wp - 1, _soak_resets])
		_soak_ms = 0.0
		_soak_n = 0
	if _test_time > 90.0:
		get_tree().quit()


# ---------------------------------------------------------------------------
# Beetle test: park the truck away from base, put a beetle nearby, check
# that it notices, winds up, charges and rams.  -- --beetletest
# ---------------------------------------------------------------------------

var _bt_beetle: DungBeetle
var _bt_last_state := -1
var _bt_rams := 0
var _bt_min_up := 1.0
var _bt_max_push := 0.0

func _run_beetletest(delta: float) -> void:
	_test_time += delta
	car.throttle_input = 0.0
	car.steer_input = 0.0
	car.brake_input = 0.0
	if _bt_beetle == null:
		for b in beetles:
			b.queue_free()
		beetles.clear()
		var spot := Vector3(2, 0, -2)
		car.place_at(_on_ground(spot) + Vector3(0, 0.8, 0), 0.0)
		_load_cargo()
		# Beetle 7 m to the truck's side.
		_bt_beetle = _spawn_beetle(spot + Vector3(7, 0, 0))
		_bt_beetle.rammed.connect(func(_b):
			_bt_rams += 1
			print("t=%.2f RAM" % _test_time))
	if _bt_beetle.state != _bt_last_state:
		_bt_last_state = _bt_beetle.state
		print("t=%.2f beetle state -> %s" % [_test_time, DungBeetle.State.keys()[_bt_beetle.state]])
	if _bt_beetle.state == DungBeetle.State.CHARGE and Engine.get_physics_frames() % 12 == 0:
		print("   charging: speed=%.2f dist=%.2f" % [_bt_beetle.linear_velocity.length(), _bt_beetle.global_position.distance_to(car.global_position)])
	if _test_time > 1.0:
		_bt_min_up = minf(_bt_min_up, car.global_basis.y.y)
		_bt_max_push = maxf(_bt_max_push, Vector2(car.linear_velocity.x, car.linear_velocity.z).length())
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots=") and Engine.get_physics_frames() % 30 == 0:
			var img := get_viewport().get_texture().get_image()
			if img:
				img.save_png(a.substr(8) + "/beetle_%03d.png" % int(_test_time * 10))
	if _test_time > 8.0:
		print("BEETLETEST rams=", _bt_rams, " max_truck_push_speed=", snappedf(_bt_max_push, 0.01),
			" min_truck_up=", snappedf(_bt_min_up, 0.01), " cargo_still_on=",
			cargo != null and cargo.global_position.distance_to(_cargo_anchor().global_position) < 0.5)
		get_tree().quit()


# ---------------------------------------------------------------------------
# Drop test: drop the crate from 2 m beside the parked truck, check it dents
# the sand and gets damaged, then load it back with E.  -- --droptest
# ---------------------------------------------------------------------------

var _dt_landed_at := Vector3.INF
var _dt_impacts := 0

func _run_droptest(delta: float) -> void:
	_test_time += delta
	car.throttle_input = 0.0
	car.steer_input = 0.0
	car.brake_input = 1.0
	if _test_time - delta <= 0.0:
		for b in beetles:
			b.queue_free()
		beetles.clear()
		car.place_at(_on_ground(Vector3(2, 0, -2)) + Vector3(0, 0.8, 0), 0.0)
		_load_cargo()
		cargo.impact.connect(func(pos, _c, on_sand):
			if on_sand:
				_dt_impacts += 1
				if _dt_landed_at == Vector3.INF:
					_dt_landed_at = pos)
	if _test_time > 1.0 and _test_time - delta <= 1.0:
		# Drop it from 2 m up, 1.6 m to the truck's side.
		var p := car.global_position + car.global_basis.x * 1.6
		p.y = terrain.get_height(p.x, p.z) + 2.0
		cargo.global_transform = Transform3D(Basis(Vector3.UP, 0.4), p)
		cargo.linear_velocity = Vector3.ZERO
		cargo.reset_physics_interpolation()
		cargo.reset_impact_tracking()
		print("t=%.2f crate dropped from 2 m" % _test_time)
	if _test_time > 3.5 and _test_time - delta <= 3.5:
		print("t=%.2f dropped=%s condition=%d%% sand_impacts=%d dent_cm=%.1f" % [_test_time,
			_crate_dropped(), int(cargo.condition), _dt_impacts,
			terrain.get_sink(_dt_landed_at.x, _dt_landed_at.z) * 100.0 if _dt_landed_at != Vector3.INF else -1.0])
		_try_load_crate()
		print("t=%.2f pressed E: loading=%s" % [_test_time, _loading])
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots=") and Engine.get_physics_frames() % 15 == 0:
			var img := get_viewport().get_texture().get_image()
			if img:
				img.save_png(a.substr(8) + "/drop_%03d.png" % int(_test_time * 10))
	if _test_time > 5.5:
		print("DROPTEST loaded_back=", _crate_on_truck(), " condition=", int(cargo.condition),
			" marker_visible=", crate_marker.visible)
		get_tree().quit()


# ---------------------------------------------------------------------------
# Ant test:  -- --anttest
#   Part A: leave a crate by a nest and watch from afar: the ants should
#           march out, haul it home and steal it.
#   Part B: drop another; when they're hauling it, drive up: they should
#           scatter, and pressing E should save it.
# ---------------------------------------------------------------------------

var _at_phase := 0
var _at_last_states := {}
var _at_stolen_time := -1.0

func _run_anttest(delta: float) -> void:
	_test_time += delta
	car.throttle_input = 0.0
	car.steer_input = 0.0
	car.brake_input = 1.0
	for b in beetles:
		b.queue_free()
	beetles.clear()
	for ci in colonies.size():
		var st: int = colonies[ci].state
		if _at_last_states.get(ci, -1) != st:
			_at_last_states[ci] = st
			print("t=%5.2f nest %d -> %s" % [_test_time, ci, AntColony.State.keys()[st]])
	if cargo and Engine.get_physics_frames() % 120 == 0 and _at_phase == 1:
		var cp := cargo.global_position
		print("   crate is %.2f m from nest 0" % Vector2(cp.x - colonies[0].global_position.x, cp.z - colonies[0].global_position.z).length())
	var nest0 := colonies[0].global_position
	var nest1 := colonies[1].global_position
	match _at_phase:
		0:
			car.place_at(_on_ground(nest0 + Vector3(12, 0, 0)) + Vector3(0, 0.8, 0), 0.0)
			_drop_cargo_at(nest0 + Vector3(3, 0, 0))
			_at_phase = 1
		1:
			if cargo == null and _at_stolen_time < 0.0:
				_at_stolen_time = _test_time
				print("PART A: stolen after %.1f s (has_job=%s)" % [_test_time, has_job])
			if _test_time > 30.0 or _at_stolen_time > 0.0 and _test_time > _at_stolen_time + 1.0:
				if _at_stolen_time < 0.0:
					print("PART A: NOT stolen within 30 s")
				_start_contract({"cargo": "crate", "dest": 1, "pay": 50, "distance": 0.0})
				car.place_at(_on_ground(nest1 + Vector3(12, 0, 0)) + Vector3(0, 0.8, 0), 0.0)
				_drop_cargo_at(nest1 + Vector3(3.5, 0, 0))
				_at_phase = 2
		2:
			if colonies[1].state == AntColony.State.CARRYING and _timer_since(2.0):
				# Drive up next to the crate.
				var c := cargo.global_position
				car.place_at(_on_ground(c + Vector3(1.8, 0, 0)) + Vector3(0, 0.8, 0), 0.0)
				print("t=%5.2f truck arrives next to the crate" % _test_time)
				_at_phase = 3
				_at_mark = _test_time
		3:
			if _test_time > _at_mark + 0.5:
				_try_load_crate()
				_at_phase = 4
				_at_mark = _test_time
		4:
			if _test_time > _at_mark + 1.5:
				print("ANTTEST partA_stolen=", _at_stolen_time > 0.0,
					" partB_scattered=", colonies[1].state != AntColony.State.CARRYING,
					" partB_saved=", cargo != null and _crate_on_truck(), " has_job=", has_job)
				get_tree().quit()
	if _test_time > 80.0:
		print("ANTTEST timeout in phase ", _at_phase)
		get_tree().quit()

var _at_mark := 0.0
var _at_carry_since := -1.0

func _timer_since(seconds: float) -> bool:
	if _at_carry_since < 0.0:
		_at_carry_since = _test_time
	return _test_time > _at_carry_since + seconds


## Put the cargo down on the sand somewhere (as if it fell off).
func _drop_cargo_at(p: Vector3) -> void:
	cargo.global_transform = Transform3D(Basis(), _on_ground(p) + Vector3(0, 0.4, 0))
	cargo.linear_velocity = Vector3.ZERO
	cargo.reset_physics_interpolation()
	cargo.reset_impact_tracking()


# ---------------------------------------------------------------------------
# Loop test: the whole game loop, driven by code.  -- --looptest
# ---------------------------------------------------------------------------

var _lt_phase := 0
var _lt_mark := 0.0
var _lt_results := {}
var _lt_dig := {}
var _lt_spin_start := 0.0

func _run_looptest(delta: float) -> void:
	_test_time += delta
	car.steer_input = 0.0
	match _lt_phase:
		0:
			for b in beetles:
				b.queue_free()
			beetles.clear()
			money = 300
			# Garage: buy balloon tyres and a big battery.
			_on_part_clicked("tyres", "balloon")
			_on_part_clicked("battery", "big")
			_lt_results["balloon_fitted"] = car.parts["tyres"] == "balloon" and is_equal_approx(car.wheel_radius, 0.36)
			_lt_results["money_after_parts"] = money
			_lt_phase = 1
			_lt_mark = _test_time
		1:
			# Dig test: pin the truck on soft sand and floor it for 2 s.
			if _test_time > _lt_mark + 0.5:
				_lt_dig_start(Vector3(-24, 0, -4))
				_lt_phase = 2
				_lt_mark = _test_time
		2:
			# Spin stuck for 3 s. A truck is beached once its wheels are ~25 cm
			# down (the belly rests on the sand). Balloon tyres must never get
			# there; paddle tyres dig right down to it.
			car.throttle_input = 1.0
			if _test_time > _lt_mark + 3.0:
				_lt_dig["balloon"] = _lt_dig_measure()
				_on_part_clicked("tyres", "paddle")
				_lt_dig_start(Vector3(-24, 0, 4))
				_lt_phase = 3
				_lt_mark = _test_time
		3:
			car.throttle_input = 1.0
			if _test_time > _lt_mark + 3.0:
				_lt_dig["paddle"] = _lt_dig_measure()
				car.throttle_input = 0.0
				car.axis_lock_linear_x = false
				car.axis_lock_linear_z = false
				print("dig test (stuck, 3 s full throttle): balloon %.1f cm, paddle %.1f cm, hardness there %.2f / %.2f" % [
					_lt_dig["balloon"] * 100, _lt_dig["paddle"] * 100,
					terrain.get_hardness(-24, -4), terrain.get_hardness(-24, 4)])
				_lt_results["balloon_never_beaches"] = _lt_dig["balloon"] < 0.16
				_lt_results["paddle_digs_to_belly"] = _lt_dig["paddle"] > 0.2
				# Battery drains with throttle.
				_lt_results["battery_after_digging"] = int(car.get_battery_percent())
				# Rescue brings you home for a fee.
				var before := money
				_rescue()
				_lt_results["rescue_home"] = _at_base() and money == before - RESCUE_COST
				_lt_phase = 4
				_lt_mark = _test_time
		4:
			# Contract: take offer 0, then deliver by placing the truck and cargo.
			if _test_time > _lt_mark + 0.5:
				_lt_results["recharged"] = car.get_battery_percent() > _lt_results["battery_after_digging"]
				var offer: Dictionary = offers[0]
				_on_contract_picked(0)
				_lt_results["contract_cargo"] = cargo.type_id == offer["cargo"]
				var dest := _on_ground(DELIVERY_SPOTS[target_index])
				car.place_at(dest + Vector3(4, 0.8, 0), 0.0)
				_drop_cargo_at(dest)
				_lt_results["money_before_delivery"] = money
				_lt_phase = 5
				_lt_mark = _test_time
		5:
			if not has_job:
				_lt_results["paid"] = money - _lt_results["money_before_delivery"]
				_lt_results["new_offers"] = offers.size()
				print("LOOPTEST ", _lt_results)
				get_tree().quit()
			elif _test_time > _lt_mark + 6.0:
				print("LOOPTEST delivery did not complete ", _lt_results)
				get_tree().quit()


func _lt_dig_start(at: Vector3) -> void:
	car.axis_lock_linear_x = false
	car.axis_lock_linear_z = false
	car.place_at(_on_ground(at) + Vector3(0, 0.6, 0), 0.0)
	car.axis_lock_linear_x = true
	car.axis_lock_linear_z = true


func _lt_dig_measure() -> float:
	var deepest := 0.0
	for w in car.wheels:
		var p := w.global_position
		deepest = maxf(deepest, terrain.get_sink(p.x, p.z))
	return deepest



# ---------------------------------------------------------------------------
# Build test: do different builds behave differently?  -- --buildtest
# Written as a coroutine: "await" pauses it for some physics steps, so the
# test reads top to bottom like a script.
# ---------------------------------------------------------------------------

func _wait(seconds: float) -> void:
	for i in int(seconds * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


func _bt_set_build(b: Dictionary) -> void:
	build = b.duplicate()
	_rebuild_car()


func _bt_park(at: Vector3, yaw: float) -> void:
	car.axis_lock_linear_x = false
	car.axis_lock_linear_z = false
	car.place_at(_on_ground(at) + Vector3(0, 0.6, 0), yaw)
	_sync_trailer()


func _bt_lean() -> float:
	# Sideways tilt in degrees: how far the truck's right-hand (+X) side has
	# dipped below level. + = leaning to the +X side, - = to the -X side.
	return -rad_to_deg(asin(clampf(car.global_basis.x.y, -1, 1)))


func _run_buildtest() -> void:
	await _wait(0.5)
	for b in beetles:
		b.queue_free()
	beetles.clear()
	var r := {}
	var pad := BASE_POS + Vector3(0, 0, 0)

	# 1. Lopsided: all the ballast on the left.
	_bt_set_build({})
	_bt_park(pad, 0.0)
	car.brake_input = 1.0
	await _wait(2.0)
	var lean_even := _bt_lean()
	_bt_set_build({"L0": "ballast", "L1": "ballast", "L2": "ballast", "U0": "ballast", "U2": "ballast", "C0": "ballast"})
	_bt_park(pad, 0.0)
	await _wait(2.0)
	r["1_lean_empty_deg"] = snappedf(lean_even, 0.1)
	r["1_lean_left_heavy_deg"] = snappedf(_bt_lean(), 0.1)
	r["1_com_x_cm"] = snappedf(car.center_of_mass.x * 100.0, 0.1)
	r["1_mass_kg"] = int(car.mass)

	# 2. Bumpers vs a beetle ram (the beetle comes from +X and hits the right side).
	var pushes := []
	for bb in [{}, {"R0": "bumper", "R1": "bumper"}]:
		_bt_set_build(bb)
		var spot := Vector3(2, 0, -2)
		_bt_park(spot, 0.0)
		car.brake_input = 1.0
		await _wait(0.5)
		var beetle := _spawn_beetle(spot + Vector3(7, 0, 0))
		var hit := [false]
		beetle.rammed.connect(func(_b): hit[0] = true)
		var max_push := 0.0
		for i in 360:
			await get_tree().physics_frame
			max_push = maxf(max_push, Vector2(car.linear_velocity.x, car.linear_velocity.z).length())
			if hit[0] and i > 0:
				await _wait(0.5)
				max_push = maxf(max_push, Vector2(car.linear_velocity.x, car.linear_velocity.z).length())
				break
		beetles.erase(beetle)
		beetle.queue_free()
		pushes.append(snappedf(max_push, 0.01))
	r["2_ram_push_no_bumper"] = pushes[0]
	r["2_ram_push_2_bumpers"] = pushes[1]

	# 3. Winch: dig in on soft sand, then try to drive out with and without it.
	var moved := []
	for with_winch in [false, true]:
		_bt_set_build({"F1": "winch"} if with_winch else {})
		var spot := Vector3(-24, 0, -4) if not with_winch else Vector3(-24, 0, 6)
		_bt_park(spot, 0.0)
		car.axis_lock_linear_x = true
		car.axis_lock_linear_z = true
		car.brake_input = 0.0
		car.throttle_input = 1.0
		await _wait(2.5)            # spin and dig in
		car.axis_lock_linear_x = false
		car.axis_lock_linear_z = false
		var start := car.global_position
		if with_winch:
			car.toggle_winch()
		await _wait(3.0)
		car.throttle_input = 0.0
		car.release_winch()
		moved.append(snappedf(Vector2(car.global_position.x - start.x, car.global_position.z - start.z).length(), 0.01))
	r["3_escape_m_throttle_only"] = moved[0]
	r["3_escape_m_with_winch"] = moved[1]

	# 4. Cargo net: shove the truck hard sideways with cargo on board.
	var kept := []
	for with_net in [false, true]:
		_bt_set_build({"N": "net"} if with_net else {})
		_bt_park(Vector3(2, 0, -2), 0.0)
		car.brake_input = 1.0
		_start_contract({"cargo": "crate", "dest": 0, "pay": 50, "distance": 0.0})
		await _wait(0.5)
		car.apply_impulse(Vector3(-1, 0.5, 0) * 220.0, Vector3.UP * 0.3)
		await _wait(2.0)
		kept.append(cargo != null and _crate_on_truck())
	r["4_cargo_kept_no_net"] = kept[0]
	r["4_cargo_kept_with_net"] = kept[1]

	# 5. Trailer: drive straight then turn; the joint must hold.
	var speeds := []
	var worst_gap := 0.0
	for with_trailer in [false, true]:
		_bt_set_build({"B1": "hitch"} if with_trailer else {})
		_bt_park(BASE_POS + Vector3(0, 0, -2), PI)
		_start_contract({"cargo": "crate", "dest": 0, "pay": 50, "distance": 0.0})
		car.brake_input = 0.0
		car.throttle_input = 1.0
		var top := 0.0
		for i in 480:
			car.steer_input = 0.0 if i < 300 else 0.8
			await get_tree().physics_frame
			top = maxf(top, car.linear_velocity.length())
			if trailer:
				worst_gap = maxf(worst_gap, trailer.hitch_gap(car))
		car.throttle_input = 0.0
		car.steer_input = 0.0
		speeds.append(snappedf(top, 0.01))
		if with_trailer:
			r["5_cargo_on_trailer"] = cargo != null and _crate_on_truck()
			r["5_trailer_upright"] = trailer.global_basis.y.y > 0.7
	r["5_top_speed_no_trailer"] = speeds[0]
	r["5_top_speed_trailer"] = speeds[1]
	r["5_worst_hitch_gap_cm"] = snappedf(worst_gap * 100.0, 0.1)

	# 6. Workshop accounting + build files.
	_bt_set_build({})
	_bt_park(BASE_POS, PI)
	inventory = {}
	money = 100
	workshop.enter()
	var placed := workshop.place("L0", "ballast") and workshop.place("R0", "ballast")
	var not_fit := workshop.place("C0", "bumper")
	r["6_money_after_2_ballast"] = money
	r["6_bumper_on_roof_refused"] = not not_fit and placed
	workshop.remove("R0")
	r["6_spare_after_remove"] = inventory.get("ballast", 0)
	workshop.save_build(3)
	workshop.clear_all()
	var msg := workshop.load_build(3)
	r["6_load_build"] = build == {"L0": "ballast"}
	r["6_load_msg"] = msg
	workshop.leave()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://builds/build_3.json"))
	print("BUILDTEST ", JSON.stringify(r, "  "))
	get_tree().quit()


# ---------------------------------------------------------------------------
# Milestone 4 tests (coroutines): --daytest --windtest --hawktest --storytest
# ---------------------------------------------------------------------------

func _m4_clear_beetles() -> void:
	for b in beetles:
		b.queue_free()
	beetles.clear()


func _m4_deliver_now() -> void:
	# Put the cargo in the delivery ring and let it settle.
	terrain.ensure_active_at(DELIVERY_SPOTS[target_index].x, DELIVERY_SPOTS[target_index].z)
	var dest := _on_ground(DELIVERY_SPOTS[target_index])
	# (Ground height where the TRUCK goes, not at the ring: the first version
	# spawned the truck inside a slope and it fell through the world.)
	car.place_at(_on_ground(dest + Vector3(4, 0, 0)) + Vector3(0, 0.6, 0), 0.0)
	_sync_trailer()
	_drop_cargo_at(dest)
	await _wait(2.0)


func _run_daytest() -> void:
	await _wait(0.3)
	_m4_clear_beetles()
	var r := {}
	money = 1000
	fitted["battery"] = "solar"
	owned["battery"].append("solar")
	build = {"F1": "headlight", "C0": "headlight"}
	_rebuild_car()
	car.place_at(_on_ground(BASE_POS + Vector3(0, 0, -8)) + Vector3(0, 0.6, 0), PI)   # off the charging pad
	car.brake_input = 1.0
	for t in [0.5, 0.0]:
		day_night.skip_to(t)
		car.battery = 50.0
		await _wait(2.0)
		var key := "noon" if t == 0.5 else "midnight"
		r[key + "_clock"] = day_night.clock()
		r[key + "_daylight"] = snappedf(day_night.daylight, 0.01)
		r[key + "_solar_gain_per_2s"] = snappedf(car.battery - 50.0, 0.01)
		r[key + "_headlights_on"] = car.lights_on
		r[key + "_base_lamp"] = snappedf(base_light.light_energy, 0.01)
	story_progress = 3   # next is "Night Shift"
	day_night.skip_to(0.5)
	r["night_job_offered_by_day"] = _make_offers()[0].has("story")
	day_night.skip_to(0.9)
	r["night_job_offered_at_night"] = _make_offers()[0].get("title", "") == "Night Shift"
	print("DAYTEST ", JSON.stringify(r, "  "))
	get_tree().quit()


func _run_windtest() -> void:
	await _wait(0.3)
	_m4_clear_beetles()
	var r := {}
	weather.wind_dir = Vector3.RIGHT          # a crosswind for a truck driving along -Z
	var drift := []
	for gust in [false, true]:
		car.place_at(_on_ground(Vector3(-20, 0, 14)) + Vector3(0, 0.6, 0), PI)
		car.brake_input = 0.0
		car.throttle_input = 0.0
		await _wait(0.5)
		var start := car.global_position
		if gust:
			weather.start_gust()
		car.throttle_input = 0.7
		await _wait(4.0)
		car.throttle_input = 0.0
		drift.append(snappedf(car.global_position.x - start.x, 0.01))
		r["max_gust_strength"] = snappedf(weather.strength, 0.01) if gust else 0.0
	r["sideways_drift_calm_m"] = drift[0]
	r["sideways_drift_gust_m"] = drift[1]
	# Parked (no throttle, no brake) with the gust blowing straight along the
	# wheels: the parking brake should hold it. Loose cargo should only shuffle.
	weather.wind_dir = Vector3.BACK
	car.place_at(_on_ground(Vector3(-20, 0, 14)) + Vector3(0, 0.6, 0), PI)
	_start_contract({"cargo": "crate", "dest": 1, "pay": 50, "distance": 0.0})
	_drop_cargo_at(Vector3(-18, 0, 14))
	car.throttle_input = 0.0
	car.brake_input = 0.0
	await _wait(1.0)
	var parked_at := car.global_position
	var cargo_at := cargo.global_position
	weather.start_gust()
	await _wait(6.0)
	r["parked_truck_moved_m"] = snappedf(car.global_position.distance_to(parked_at), 0.01)
	r["loose_crate_moved_m"] = snappedf(cargo.global_position.distance_to(cargo_at), 0.01)
	r["crate_condition"] = int(cargo.condition)
	print("WINDTEST ", JSON.stringify(r, "  "))
	get_tree().quit()


func _run_hawktest() -> void:
	await _wait(0.3)
	_m4_clear_beetles()
	for colony in colonies:
		colony.notice_delay = 9999.0   # keep the ants out of this one
	var r := {}
	var spot := Vector3(8, 0, -16)
	var events := []
	hawk.grabbed.connect(func(_c): events.append("grabbed"))
	hawk.dropped.connect(func(_c): events.append("dropped"))
	hawk.foiled.connect(func(why): events.append("foiled:" + why))
	for trial in ["plain", "net", "heavy"]:
		build = {"N": "net"} if trial == "net" else {}
		_rebuild_car()
		car.place_at(_on_ground(spot) + Vector3(0, 0.6, 0), 0.0)
		car.brake_input = 1.0
		_start_contract({"cargo": "engine" if trial == "heavy" else "crate", "dest": 1, "pay": 50, "distance": 0.0})
		await _wait(0.5)
		events.clear()
		hawk._cooldown = 0.0
		hawk._set_state(Hawk.State.SOAR)
		hawk._timer = 10.0
		var t := 0.0
		while t < 40.0 and not ("dropped" in events or events.any(func(e): return e.begins_with("foiled"))):
			await _wait(0.25)
			t += 0.25
		await _wait(2.5)   # let a dropped crate land
		r[trial + "_events"] = events.duplicate()
		r[trial + "_seconds"] = t
		if cargo:
			r[trial + "_cargo_on_truck"] = _crate_on_truck()
			r[trial + "_condition"] = int(cargo.condition)
			r[trial + "_dropped_m_from_truck"] = snappedf(cargo.global_position.distance_to(car.global_position), 0.1)
			r[trial + "_cargo_pos"] = str(cargo.global_position.snapped(Vector3.ONE * 0.1))
			r[trial + "_truck_pos"] = str(car.global_position.snapped(Vector3.ONE * 0.1))
			r[trial + "_hawk_pos"] = str(hawk.global_position.snapped(Vector3.ONE * 0.1))
	print("HAWKTEST ", JSON.stringify(r, "  "))
	get_tree().quit()


func _run_storytest() -> void:
	await _wait(0.3)
	_m4_clear_beetles()
	var r := {}
	day_night.skip_to(0.5)
	story_progress = 0
	offers = _make_offers()
	r["first_offer"] = offers[0].get("title", "(none)")
	_on_contract_picked(0)
	await _m4_deliver_now()
	r["after_first_progress"] = story_progress
	# Eggs, min 60%: deliver at 40% -> refused.
	offers = _make_offers()
	_on_contract_picked(0)
	cargo.condition = 40.0
	var m0 := money
	await _m4_deliver_now()
	r["eggs_at_40_paid"] = money - m0
	r["eggs_at_40_progress"] = story_progress
	# Deadline: "Race the Sun" (70 s), delivered at 80 s -> half pay, no progress.
	story_progress = 4
	offers = _make_offers()
	_on_contract_picked(0)
	_contract_time = 80.0
	m0 = money
	await _m4_deliver_now()
	r["late_ice_paid_of_150"] = money - m0
	r["late_ice_progress"] = story_progress
	# The last one, at night -> the ending.
	story_progress = 9
	day_night.skip_to(0.9)
	offers = _make_offers()
	r["final_offer"] = offers[0].get("title", "(none)")
	_on_contract_picked(0)
	await _m4_deliver_now()
	r["final_progress"] = story_progress
	r["ending_shown"] = message.text.begins_with("The receiver crackles")
	r["final_message"] = message.text.left(60)
	print("STORYTEST ", JSON.stringify(r, "  "))
	get_tree().quit()



# ---------------------------------------------------------------------------
# Milestone 5 tests: --worldtest --crusttest --scorpiontest --outposttest
# ---------------------------------------------------------------------------

## Teleport the truck anywhere in the world (making sure the ground is solid).
func _m5_put_truck(at: Vector3, yaw: float) -> void:
	terrain.ensure_active_at(at.x, at.z)
	_release_scorpions()
	car.axis_lock_linear_x = false
	car.axis_lock_linear_z = false
	car.place_at(_on_ground(at) + Vector3(0, 0.6, 0), yaw)
	_sync_trailer()


func _run_worldtest() -> void:
	var r := {}
	var t0 := Time.get_ticks_msec()
	terrain.finish_all_tiles()
	r["tiles"] = terrain.tiles.size()
	await _wait(0.3)
	_m4_clear_beetles()
	# 1. Seams: where two tiles meet, their shared row of points must match.
	r["seam_max_mismatch_cm"] = snappedf(_m5_worst_seam() * 25.0, 0.01)
	# 2. Press ruts right across the seam between the home tile and its east neighbour.
	terrain.ensure_active_at(40, 0)
	for k in 20:
		terrain.press(Vector3(32.0, 0, -6.0 + k * 0.6), 0.3, 0.05, 0.15)
	r["seam_after_ruts_mismatch_cm"] = snappedf(_m5_worst_seam() * 25.0, 0.01)
	# 3. Streaming: at base, then teleported out to point I on the flats.
	_m5_put_truck(BASE_POS, PI)
	await _wait(1.5)
	r["active_at_base"] = terrain.debug_stats().split(" ")[0]
	_m5_put_truck(DELIVERY_SPOTS[8], PI)
	await _wait(2.0)
	r["active_at_point_I"] = terrain.debug_stats().split(" ")[0]
	r["far_corner_tile_active"] = terrain.tiles[Vector2i(-3, -3)].active
	# 4. Drive across the border between two tiles (x = 32 m).
	_m5_put_truck(Vector3(26, 0, 4), PI / 2.0)   # facing +X
	await _wait(0.5)
	var lowest := 9.0
	var ms := 0.0
	var n := 0
	car.throttle_input = 1.0
	for f in 300:
		await get_tree().physics_frame
		var p := car.global_position
		lowest = minf(lowest, p.y - terrain.get_height(p.x, p.z))
		ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		n += 1
	car.throttle_input = 0.0
	r["drove_to_x"] = snappedf(car.global_position.x, 0.1)
	r["lowest_above_ground_m"] = snappedf(lowest, 0.01)
	r["avg_physics_ms_while_crossing"] = snappedf(ms / n, 0.01)
	r["setup_ms"] = Time.get_ticks_msec() - t0
	print("WORLDTEST ", JSON.stringify(r, "  "))
	get_tree().quit()


## Largest height difference (cell units) along any shared tile edge.
func _m5_worst_seam() -> float:
	var worst := 0.0
	for c in terrain.tiles:
		var a: SandTile = terrain.tiles[c]
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			if not terrain.tiles.has(c + d):
				continue
			var b: SandTile = terrain.tiles[c + d]
			var last := a.cells_per_side
			for k in a.verts_per_side:
				var ha := a.heights[a.idx(last, k)] if d.x == 1 else a.heights[a.idx(k, last)]
				var hb := b.heights[b.idx(0, k)] if d.x == 1 else b.heights[b.idx(k, 0)]
				worst = maxf(worst, absf(ha - hb))
	return worst


func _m5_find(pred: Callable) -> Vector3:
	for z in range(-80, 81, 2):
		for x in range(-80, 81, 2):
			if maxf(absf(x), absf(z)) > 48 and pred.call(float(x), float(z)):
				return Vector3(x, 0, z)
	return Vector3.INF


func _m5_crust_under_wheels() -> float:
	var total := 0.0
	for w in car.wheels:
		total += terrain.get_crust(w.global_position.x, w.global_position.z)
	return total / car.wheels.size()


func _run_crusttest() -> void:
	terrain.finish_all_tiles()
	await _wait(0.3)
	_m4_clear_beetles()
	var r := {}
	# A flat-ish spot with THIN crust and one with THICK crust.
	var thin := _m5_find(func(x, z): return terrain.get_crust(x, z) > 0.2 and terrain.get_crust(x, z) < 0.35 \
			and terrain.get_crust(x + 1.5, z + 1.5) < 0.4 and terrain.get_crust(x - 1.5, z - 1.5) > 0.15)
	var thick := _m5_find(func(x, z): return terrain.get_crust(x, z) > 0.85 \
			and terrain.get_crust(x + 1.5, z + 1.5) > 0.85 and terrain.get_crust(x - 1.5, z - 1.5) > 0.85)
	r["thin_spot"] = str(thin)
	r["thick_spot"] = str(thick)
	for trial in [["light_on_thin", thin, ""], ["light_on_thick", thick, ""], ["heavy_on_thick", thick, "engine"]]:
		_m5_put_truck(trial[1], 0.0)
		car.brake_input = 1.0
		if trial[2] != "":
			_start_contract({"cargo": trial[2], "dest": 6, "pay": 50, "distance": 0.0})
		else:
			if cargo:
				cargo.queue_free()
				cargo = null
			has_job = false
		var before := _m5_crust_under_wheels()
		await _wait(1.5)
		r[trial[0] + "_crust_before"] = snappedf(before, 0.01)
		r[trial[0] + "_crust_after"] = snappedf(_m5_crust_under_wheels(), 0.01)
		var sink := 0.0
		for w in car.wheels:
			sink = maxf(sink, terrain.get_sink(w.global_position.x, w.global_position.z))
		r[trial[0] + "_wheel_dropped_cm"] = snappedf(sink * 100.0, 0.1)
	print("CRUSTTEST ", JSON.stringify(r, "  "))
	get_tree().quit()


func _run_scorpiontest() -> void:
	terrain.finish_all_tiles()
	await _wait(0.3)
	_m4_clear_beetles()
	var r := {}
	var sc := scorpions[0]
	var events := []
	sc.clamped.connect(func(_w): events.append("clamped"))
	sc.shaken_off.connect(func(how): events.append(how))
	for trial in ["plain", "buzzer"]:
		build = {"R1": "buzzer", "L1": "buzzer"} if trial == "buzzer" else {}
		_rebuild_car()
		sc.release_now(car)
		sc._rest = 0.0
		events.clear()
		# Drive past the scorpion's hiding spot, 1.5 m to one side.
		_m5_put_truck(sc.home + Vector3(1.5, 0, 8), PI)   # facing -Z, towards it
		await _wait(0.5)
		car.throttle_input = 0.6
		var t := 0.0
		var speed_before := 0.0
		var speed_clamped := 99.0
		var clamp_time := -1.0
		while t < 12.0:
			await _wait(0.1)
			t += 0.1
			if events.is_empty():
				speed_before = maxf(speed_before, car.linear_velocity.length())
			if "clamped" in events and clamp_time < 0.0:
				clamp_time = t
				car.throttle_input = 1.0   # floor it to shake it off
			if clamp_time > 0.0 and car.is_pinned():
				speed_clamped = minf(speed_clamped, car.linear_velocity.length())
			if events.size() >= 2:
				break
		car.throttle_input = 0.0
		r[trial + "_events"] = events.duplicate()
		r[trial + "_free_after_s"] = snappedf(t - clamp_time, 0.1) if clamp_time > 0.0 else -1.0
		r[trial + "_speed_before"] = snappedf(speed_before, 0.1)
		r[trial + "_slowest_while_clamped"] = snappedf(speed_clamped, 0.1)
		r[trial + "_wheel_free_now"] = not car.is_pinned()
	print("SCORPIONTEST ", JSON.stringify(r, "  "))
	get_tree().quit()


func _run_outposttest() -> void:
	terrain.finish_all_tiles()
	await _wait(0.3)
	_m4_clear_beetles()
	var r := {}
	money = 500
	story_progress = 10      # next: "The Outpost"
	_m5_put_truck(BASE_POS, PI)
	await _wait(0.5)
	offers = _make_offers()
	r["home_story_offer"] = offers[0].get("title", "(none)")
	_on_contract_picked(0)
	r["cargo"] = cargo.type_id
	await _m4_deliver_now()
	r["outpost_built"] = stations[1]["built"]
	r["story_after"] = story_progress
	# At the outpost: its own board, charging.
	_m5_put_truck(OUTPOST_POS, PI)
	car.battery = 20.0
	await _wait(1.5)
	r["at_a_base"] = _at_base()
	r["station_here"] = _station_here().get("name", "")
	r["charging"] = car.battery > 20.0
	offers = _make_offers()
	r["outpost_story_offer"] = offers[0].get("title", "(none)")
	var dests := []
	for o in offers:
		dests.append(Contracts.spot_name(int(o["dest"])))
	r["outpost_offer_destinations"] = dests
	# Rescue from out on the flats goes to the NEAREST base.
	_m5_put_truck(DELIVERY_SPOTS[7], PI)   # point H
	await _wait(0.5)
	_rescue()
	await _wait(0.5)
	r["rescued_to"] = _station_here().get("name", "(nowhere)")
	print("OUTPOSTTEST ", JSON.stringify(r, "  "))
	get_tree().quit()


# ---------------------------------------------------------------------------
# Milestone 6 tests (the Glass Desert). Run with  godot -- --glasstest  etc.
# ---------------------------------------------------------------------------

## A spot in Ring 2 where `pred` holds along a straight line `length` m long
## heading +X from it (checked every half metre).
func _m6_find_line(pred: Callable, length: float) -> Vector3:
	for z in range(-140, -95, 3):
		for x in range(-140, 140, 3):
			var ok := true
			var d := 0.0
			while d <= length:
				if not pred.call(float(x) + d, float(z)):
					ok = false
					break
				d += 0.5
			if ok:
				return Vector3(x, 0, z)
	return Vector3.INF


func _m6_put(at: Vector3, yaw: float) -> void:
	_m5_put_truck(at, yaw)
	car.repair_all()
	await _wait(0.6)


## Drive at a steady speed (a tiny cruise control) for `seconds`.
func _m6_cruise(speed: float, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		var v := car.linear_velocity.dot(car.global_basis.z)
		car.throttle_input = clampf((speed - v) * 0.8 + 0.15, 0.0, 1.0)
	car.throttle_input = 0.0


func _run_glasstest() -> void:
	terrain.finish_all_tiles()
	await _wait(0.3)
	_m4_clear_beetles()
	var r := {}
	var on_glass := _m6_find_line(func(x, z): return terrain.get_glass(x, z) > 0.9 \
			and terrain.get_glass(x, z + 1.2) > 0.9 and terrain.get_glass(x, z - 1.2) > 0.9, 14.0)
	var on_sand := _m6_find_line(func(x, z): return terrain.get_glass(x, z) < 0.01 \
			and terrain.get_glass(x, z + 1.2) < 0.01 and terrain.get_glass(x, z - 1.2) < 0.01 \
			and terrain.ring_at(x, z) == 2, 14.0)
	r["glass_spot"] = str(on_glass)
	r["sand_spot"] = str(on_sand)
	# 1. Braking: drive at 4 m/s, slam the brakes, measure how far it slides.
	for trial in [["glass", on_glass], ["sand", on_sand]]:
		await _m6_put(trial[1], PI / 2.0)    # facing +X, along the strip
		await _m6_cruise(4.0, 2.0)
		var v0 := car.linear_velocity.length()
		var p0 := car.global_position
		car.brake_input = 1.0
		var t := 0.0
		while t < 6.0 and car.linear_velocity.length() > 0.15:
			await get_tree().physics_frame
			t += 1.0 / Engine.physics_ticks_per_second
		car.brake_input = 0.0
		r[trial[0] + "_speed_before_brake"] = snappedf(v0, 0.1)
		r[trial[0] + "_braking_distance_m"] = snappedf(car.global_position.distance_to(p0), 0.01)
		r[trial[0] + "_glass_under"] = snappedf(car.get_glass_under(), 0.01)
	# 2. Glass never dents: press hard on it.
	var p := on_glass + Vector3(3, 0, 0)
	var h0 := terrain.get_height(p.x, p.z)
	for k in 30:
		terrain.press(p, 0.4, 0.05, 0.3)
	r["glass_dent_cm"] = snappedf((h0 - terrain.get_height(p.x, p.z)) * 100.0, 0.01)
	var q := on_sand + Vector3(3, 0, 0)
	var hq := terrain.get_height(q.x, q.z)
	for k in 30:
		terrain.press(q, 0.4, 0.05, 0.3)
	r["sand_dent_cm"] = snappedf((hq - terrain.get_height(q.x, q.z)) * 100.0, 0.01)
	print("GLASSTEST ", JSON.stringify(r, "  "))
	get_tree().quit()


func _run_magnettest() -> void:
	terrain.finish_all_tiles()
	await _wait(0.3)
	_m4_clear_beetles()
	var r := {}
	var stone: Vector3 = LODESTONES[0]
	money = 500
	# Drive north past the lodestone, 6 m to its east, with three builds.
	for trial in [["plain", {}], ["iron_ballast", {"L0": "ballast", "R0": "ballast", "U0": "ballast"}],
			["sandbags", {"L0": "sandbag", "R0": "sandbag", "U0": "sandbag"}]]:
		build = trial[1]
		_rebuild_car()
		var start := stone + Vector3(6.0, 0, 8.0)
		await _m6_put(start, PI)          # facing -Z (north), past the stone
		r[trial[0] + "_metal_kg"] = car.metal_mass
		r[trial[0] + "_pull_at_start_N"] = int(magnet_force_at(car.global_position, car.metal_mass).length())
		await _m6_cruise(2.0, 6.0)
		var closest := 99.0
		closest = minf(closest, Vector2(car.global_position.x - stone.x, car.global_position.z - stone.z).length())
		r[trial[0] + "_x_drift_toward_stone_m"] = snappedf(start.x - car.global_position.x, 0.01)
		r[trial[0] + "_now_from_stone_m"] = snappedf(closest, 0.01)
	# Stuck to the rock? Start 2 m away and try to drive off: light vs iron-heavy.
	for trial in [["light", {}], ["heavy", {"L0": "ballast", "R0": "ballast", "U0": "ballast"}]]:
		build = trial[1]
		_rebuild_car()
		await _m6_put(stone + Vector3(2.6, 0, 0), PI / 2.0)    # facing +X, away from it
		var d0 := Vector2(car.global_position.x - stone.x, car.global_position.z - stone.z).length()
		car.throttle_input = 1.0
		await _wait(3.0)
		car.throttle_input = 0.0
		r[trial[0] + "_escape_moved_m"] = snappedf(Vector2(car.global_position.x - stone.x, car.global_position.z - stone.z).length() - d0, 0.01)
	# Storms.
	r["strength_calm"] = snappedf(magnet_strength(), 0.01)
	start_magnet_storm(5.0)
	r["strength_in_storm"] = snappedf(magnet_strength(), 0.01)
	r["engine_cargo_pull_at_5m_N"] = int(magnet_force_at(stone + Vector3(5, 0, 0), 22.0).length())
	build = {}
	print("MAGNETTEST ", JSON.stringify(r, "  "))
	get_tree().quit()


func _run_shardtest() -> void:
	terrain.finish_all_tiles()
	await _wait(0.3)
	_m4_clear_beetles()
	var r := {}
	money = 500
	var rubble := _m6_find_line(func(x, z): var g := terrain.get_glass(x, z); return g > 0.3 and g < 0.7 \
			and terrain.get_glass(x, z + 1.0) > 0.3 and terrain.get_glass(x, z + 1.0) < 0.7 \
			and terrain.get_glass(x, z - 1.0) > 0.3 and terrain.get_glass(x, z - 1.0) < 0.7, 5.0)
	r["rubble_spot"] = str(rubble)
	var pops := [0]
	car.punctured.connect(func(_w): pops[0] += 1)
	for trial in [["fast_standard", 4.0, "standard"], ["slow_standard", 0.8, "standard"], ["fast_solid", 4.0, "solid"]]:
		fitted["tyres"] = trial[2]
		if not trial[2] in owned["tyres"]:
			owned["tyres"].append(trial[2])
		_rebuild_car()
		car.punctured.connect(func(_w): pops[0] += 1)
		await _m6_put(rubble - Vector3(1.5, 0, 0), PI / 2.0)
		# Cross the 5 m of rubble at a steady speed (or as fast as the sand allows).
		var x0 := car.global_position.x
		await _m6_cruise(trial[1], 4.0 if trial[1] > 2.0 else 7.0)
		r[trial[0] + "_flats"] = car.flat_count()
		r[trial[0] + "_moved_m"] = snappedf(car.global_position.x - x0, 0.1)
		r[trial[0] + "_most_exposure"] = snappedf(Array(car._shard_exposure).max(), 0.01)
	# A spare (press P), then the crew patches the rest at base.
	fitted["tyres"] = "standard"
	build = {"B0": "spare"}
	_rebuild_car()
	car.puncture(0)
	car.puncture(3)
	r["spares_on_board"] = car.spares
	r["use_spare"] = car.use_spare()
	r["flats_after_spare"] = car.flat_count()
	r["use_spare_again"] = car.use_spare()
	var m0 := money
	_m5_put_truck(BASE_POS + Vector3(10, 0, 0), PI)
	await _wait(0.5)
	_m5_put_truck(BASE_POS, PI)
	await _wait(1.0)
	r["flats_after_base"] = car.flat_count()
	r["repair_paid"] = m0 - money
	r["spares_restocked"] = car.spares
	build = {}
	print("SHARDTEST ", JSON.stringify(r, "  "))
	get_tree().quit()


func _run_traveltest() -> void:
	terrain.finish_all_tiles()
	await _wait(0.3)
	_m4_clear_beetles()
	var r := {}
	money = 1000
	_build_outpost("outpost")
	story_progress = 16      # next: "The Glass Outpost", from the Salt Flats outpost
	# Fast travel from home to the outpost.
	_m5_put_truck(BASE_POS, PI)
	await _wait(0.5)
	r["options_at_home"] = _travel_options().map(func(t): return t["name"])
	_fast_travel("outpost")
	await _wait(0.5)
	r["after_travel_at"] = _station_here().get("name", "(nowhere)")
	r["travel_cost_paid"] = 1000 - money
	# Haul the kit to the glass outpost site.
	offers = _make_offers()
	r["outpost_story_offer"] = offers[0].get("title", "(none)")
	_on_contract_picked(0)
	r["cargo"] = cargo.type_id if cargo else "(none)"
	r["travel_refused_with_job"] = not _travel_options()[0]["ok"]
	await _m4_deliver_now()
	r["glass_outpost_built"] = _station("glass")["built"]
	# Fast travel to the new outpost: its board sends you around the Glass Desert.
	_m5_put_truck(BASE_POS, PI)
	await _wait(0.5)
	_fast_travel("glass")
	await _wait(0.5)
	r["now_at"] = _station_here().get("name", "(nowhere)")
	offers = _make_offers()
	r["glass_story_offer"] = offers[0].get("title", "(none)")
	var dests := []
	for o in offers:
		dests.append(Contracts.spot_name(int(o["dest"])))
	r["glass_offer_destinations"] = dests
	r["glass_pays_more"] = offers[1]["pay"] > 100
	# Rescue from out in the Glass Desert goes to the nearest base: this one.
	_m5_put_truck(DELIVERY_SPOTS[13], PI)
	await _wait(0.5)
	_rescue()
	await _wait(0.5)
	r["rescued_to"] = _station_here().get("name", "(nowhere)")
	print("TRAVELTEST ", JSON.stringify(r, "  "))
	get_tree().quit()


# ---------------------------------------------------------------------------
# Milestone 7 tests (the Drift). Run with  godot -- --gravitytest  etc.
# ---------------------------------------------------------------------------

## Somewhere in the Drift where `pred` holds (scanned every 2 m).
func _m7_find(pred: Callable) -> Vector3:
	for z in range(-212, -170, 2):
		for x in range(-200, 200, 2):
			if pred.call(float(x), float(z)):
				return Vector3(x, 0, z)
	return Vector3.INF


## A point in the middle of a wide, strong river, away from any pad.
func _m7_river() -> Vector3:
	return _m7_find(func(x, z):
		if terrain.get_flow(x, z) < 0.95:
			return false
		var fv := terrain.get_flow_velocity(x, z).normalized()
		var side := Vector3(-fv.z, 0, fv.x)
		for k in [-1.2, 1.2]:
			if terrain.get_flow(x + side.x * k, z + side.z * k) < 0.7:
				return false
		for k in [-4.0, 4.0]:
			if terrain.get_flow(x + fv.x * k, z + fv.z * k) < 0.7:
				return false
		return Vector3(x, 0, z).distance_to(DRIFT_POS) > 14.0)


func _m7_up() -> float:
	return car.global_basis.y.y


func _run_gravitytest() -> void:
	terrain.finish_all_tiles()
	await _wait(0.3)
	_m4_clear_beetles()
	var r := {}
	money = 1000
	r["gravity_home"] = terrain.gravity_at(BASE_POS.x, BASE_POS.z)
	r["gravity_drift"] = terrain.gravity_at(DRIFT_POS.x, DRIFT_POS.z)
	# 1. Drop the truck from 2 m: how long until a wheel touches?
	for trial in [["home", BASE_POS], ["drift", DRIFT_POS]]:
		terrain.ensure_active_at(trial[1].x, trial[1].z)
		car.place_at(_on_ground(trial[1]) + Vector3(0, 2.0, 0), PI)
		var t := 0.0
		var touched := false
		while t < 5.0 and not touched:
			await get_tree().physics_frame
			t += 1.0 / Engine.physics_ticks_per_second
			for w in car.wheels:
				touched = touched or w.is_in_contact()
		r[trial[0] + "_fall_s"] = snappedf(t, 0.01)
		await _wait(1.0)
	# 2. Grip at speed, with and without wings: drive a slalom on the
	# station's flat pad area and count how often all four wheels touch.
	var flat := _m7_find(func(x, z): return terrain.get_flow(x, z) < 0.01 and terrain.get_flow(x + 12, z) < 0.01 \
			and absf(terrain.get_height(x, z) - terrain.get_height(x + 12, z)) < 0.4 \
			and absf(terrain.get_height(x, z) - terrain.get_height(x + 6, z + 3)) < 0.4)
	r["flat_spot"] = str(flat)
	for trial in [["no_wing", {}], ["two_wings", {"C0": "wing", "C1": "wing"}]]:
		build = trial[1]
		_rebuild_car()
		await _m6_put(flat, PI / 2.0)
		var frames := 0
		var all_down := 0
		var t := 0.0
		car.throttle_input = 1.0
		while t < 5.0:
			await get_tree().physics_frame
			t += 1.0 / Engine.physics_ticks_per_second
			car.steer_input = sin(t * 2.5)       # weave left and right
			frames += 1
			var down := 0
			for w in car.wheels:
				down += 1 if w.is_in_contact() else 0
			all_down += 1 if down == 4 else 0
		car.throttle_input = 0.0
		car.steer_input = 0.0
		r[trial[0] + "_all_wheels_down_pct"] = int(100.0 * all_down / frames)
		r[trial[0] + "_still_upright"] = _m7_up() > 0.5
	# 3. Knocked on its side: does it get back up?
	for trial in [["drift_no_gyro", DRIFT_POS, {}], ["drift_gyro", DRIFT_POS, {"U0": "gyro"}],
			["home_gyro", BASE_POS, {"U0": "gyro"}]]:
		build = trial[2]
		_rebuild_car()
		var at: Vector3 = trial[1] + Vector3(6, 0, 0)
		terrain.ensure_active_at(at.x, at.z)
		car.global_transform = Transform3D(Basis(Vector3.BACK, 1.75), _on_ground(at) + Vector3(0, 0.7, 0))
		car.linear_velocity = Vector3.ZERO
		car.angular_velocity = Vector3.ZERO
		car.reset_physics_interpolation()
		await _wait(5.0)
		r[trial[0] + "_up_after_5s"] = snappedf(_m7_up(), 0.01)
	build = {}
	print("GRAVITYTEST ", JSON.stringify(r, "  "))
	get_tree().quit()


func _run_flowtest() -> void:
	terrain.finish_all_tiles()
	await _wait(0.3)
	_m4_clear_beetles()
	var r := {}
	var river := _m7_river()
	r["river_spot"] = str(river)
	var still := _m7_find(func(x, z): return terrain.get_flow(x, z) < 0.01 and terrain.get_flow(x + 8, z) < 0.01 \
			and terrain.get_flow(x - 8, z) < 0.01 and terrain.get_flow(x, z + 8) < 0.01 and terrain.get_flow(x, z - 8) < 0.01)
	var fv := terrain.get_flow_velocity(river.x, river.z)
	r["flow_speed"] = snappedf(fv.length(), 0.01)
	_m5_put_truck(DRIFT_POS + Vector3(30, 0, 0), PI)       # out of the way
	await _wait(0.3)
	# 1. A crate dropped in a river floats away; on still sand it stays.
	for trial in [["crate_in_river", river], ["crate_on_still_sand", still]]:
		_start_contract({"cargo": "crate", "dest": 20, "pay": 50, "distance": 0.0})
		terrain.ensure_active_at(trial[1].x, trial[1].z)
		_drop_cargo_at(trial[1])
		await _wait(0.6)
		var p0 := cargo.global_position
		await _wait(5.0)
		r[trial[0] + "_moved_m"] = snappedf(Vector2(cargo.global_position.x - p0.x, cargo.global_position.z - p0.z).length(), 0.01)
	# 2. A parked truck in a river gets carried along.
	await _m6_put(river, atan2(fv.x, fv.z) + PI / 2.0)        # side-on to the flow
	var c0 := car.global_position
	await _wait(5.0)
	r["parked_truck_carried_m"] = snappedf(Vector2(car.global_position.x - c0.x, car.global_position.z - c0.z).length(), 0.01)
	# 3. Slow wheels sink, fast ones skim (driving downstream).
	for trial in [["slow", 1.0], ["fast", 5.0]]:
		await _m6_put(river - fv.normalized() * 3.0, atan2(fv.x, fv.z))
		if trial[1] > 3.0:
			car.linear_velocity = car.global_basis.z * trial[1]
		var deepest := 0.0
		var t := 0.0
		while t < 2.5:
			await _m6_cruise(trial[1], 0.1)
			t += 0.1
			for w in car.wheels:
				if terrain.get_flow(w.global_position.x, w.global_position.z) > 0.5:   # only in the river
					deepest = maxf(deepest, terrain.get_sink(w.global_position.x, w.global_position.z))
		car.throttle_input = 0.0
		r[trial[0] + "_deepest_sink_cm"] = snappedf(deepest * 100.0, 0.1)
	# 4. A river fills its holes back in; still sand doesn't. (The truck
	# parks nearby: tiles far from the truck switch off and stop flowing.)
	for trial in [["river", river + Vector3(0, 0, 0)], ["still", still]]:
		var p: Vector3 = trial[1]
		var away := Vector3(-fv.normalized().z, 0, fv.normalized().x) * 8.0
		_m5_put_truck(p + away, PI)
		await _wait(0.3)
		var h0 := terrain.get_height(p.x, p.z)
		for k in 20:
			terrain.press(p, 0.4, 0.05, 0.3)
		var dug := h0 - terrain.get_height(p.x, p.z)
		await _wait(2.0)
		r[trial[0] + "_hole_cm_at_start"] = snappedf(dug * 100.0, 0.1)
		r[trial[0] + "_hole_cm_after_2s"] = snappedf((h0 - terrain.get_height(p.x, p.z)) * 100.0, 0.1)
	print("FLOWTEST ", JSON.stringify(r, "  "))
	get_tree().quit()


func _run_raytest() -> void:
	terrain.finish_all_tiles()
	await _wait(0.3)
	_m4_clear_beetles()
	_update_drift(0.0)          # places the rays
	var r := {}
	r["rays_placed"] = rays.size()
	if rays.is_empty():
		print("RAYTEST ", JSON.stringify(r))
		get_tree().quit()
		return
	var ray := rays[0]
	var events := []
	ray.struck.connect(func(): events.append("struck"))
	ray.hunting.connect(func(): events.append("hunting"))
	for trial in [["slow_plain", 1.2, {}], ["slow_gyro", 1.2, {"U0": "gyro"}], ["fast_plain", 5.5, {}]]:
		build = trial[2]
		_rebuild_car()
		# Start upstream of the ray, following the river's bends back.
		var start := ray.home
		var back := 6.0 if trial[1] < 3.0 else 14.0
		var walked := 0.0
		while walked < back:
			var f := terrain.get_flow_velocity(start.x, start.z)
			if f.length() < 0.3:
				break
			start -= f.normalized() * 0.5
			walked += 0.5
		var fv := terrain.get_flow_velocity(start.x, start.z).normalized()
		ray.global_position = ray.home + Vector3(0, 0, 40)   # out of the way while we set up
		ray._set_state(DriftRay.State.REST)
		await _m6_put(start, atan2(fv.x, fv.z))   # heading downstream, at the ray
		if trial[1] > 3.0:
			car.linear_velocity = car.global_basis.z * trial[1]
		ray.global_position = ray.home
		ray._set_state(DriftRay.State.GLIDE)
		ray._dir = -1.0                       # swimming upstream, towards the truck
		events.clear()
		var lowest_up := 1.0
		var t := 0.0
		var t_strike := -1.0
		while t < 9.0:
			if t_strike < 0.0 or t - t_strike < 1.5:
				await _m6_cruise(trial[1], 0.1)
			else:
				await _wait(0.1)
			t += 0.1
			lowest_up = minf(lowest_up, _m7_up())
			if "struck" in events and t_strike < 0.0:
				t_strike = t
			if t_strike > 0.0 and t - t_strike > 5.0:
				break
		car.throttle_input = 0.0
		r[trial[0] + "_events"] = events.duplicate()
		r[trial[0] + "_lowest_up"] = snappedf(lowest_up, 0.01)
		r[trial[0] + "_up_at_end"] = snappedf(_m7_up(), 0.01)
	build = {}
	print("RAYTEST ", JSON.stringify(r, "  "))
	get_tree().quit()


func _run_drifttest() -> void:
	terrain.finish_all_tiles()
	await _wait(0.3)
	_m4_clear_beetles()
	var r := {}
	money = 2000
	_build_outpost("outpost")
	_build_outpost("glass")
	story_progress = 22      # next: "Drift Station", from the glass outpost
	_m5_put_truck(GLASS_OUTPOST_POS, PI)
	await _wait(0.5)
	offers = _make_offers()
	r["glass_story_offer"] = offers[0].get("title", "(none)")
	_on_contract_picked(0)
	r["cargo"] = cargo.type_id if cargo else "(none)"
	await _m4_deliver_now()
	r["drift_station_built"] = _station("drift")["built"]
	_m5_put_truck(BASE_POS, PI)
	await _wait(0.5)
	r["travel_options_at_home"] = _travel_options().map(func(t): return t["name"])
	_fast_travel("drift")
	await _wait(0.5)
	r["now_at"] = _station_here().get("name", "(nowhere)")
	r["gravity_here"] = snappedf(car.gravity_scale, 0.01)
	var cargos := {}
	for k in 6:
		for o in _make_offers():
			if not o.has("story"):
				cargos[o["cargo"]] = true
	r["random_cargo_seen"] = cargos.keys()
	offers = _make_offers()
	r["drift_story_offer"] = offers[0].get("title", "(none)")
	var dests := []
	for o in offers:
		dests.append(Contracts.spot_name(int(o["dest"])))
	r["drift_offer_destinations"] = dests
	story_progress = 27
	day_night.skip_to(0.5)
	offers = _make_offers()
	r["final_offer"] = offers[0].get("title", "(none)") + " to " + Contracts.spot_name(int(offers[0]["dest"]))
	# The orb: light, bouncy, rolls.
	_on_contract_picked(0)
	r["orb_mass"] = cargo.mass
	await _m4_deliver_now()
	r["story_done"] = story_progress
	r["final_message"] = message.text.left(60)
	print("DRIFTTEST ", JSON.stringify(r, "  "))
	get_tree().quit()


# ---------------------------------------------------------------------------
# Release test: controller, menus, settings, achievements.
# Run with  godot --headless --path . -- --controllertest
# ---------------------------------------------------------------------------

func _pad_axis(axis: int, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	Input.parse_input_event(e)


func _pad_button(button: int, pressed: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = pressed
	Input.parse_input_event(e)


## Run the driving controls for a while (tests skip the normal input path).
func _ct_drive(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		_drive_input(1.0 / Engine.physics_ticks_per_second)


func _run_controllertest() -> void:
	terrain.finish_all_tiles()
	await _wait(0.3)
	_m4_clear_beetles()
	var r := {}
	money = 500
	_m5_put_truck(BASE_POS + Vector3(0, 0, -8), PI)
	await _wait(0.5)
	# 1. Analog driving: right trigger, left stick, A.
	_pad_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_pad_axis(JOY_AXIS_LEFT_X, -1.0)
	await _ct_drive(0.2)
	r["using_pad_after_input"] = GameInput.using_pad
	r["RT_throttle"] = snappedf(car.throttle_input, 0.01)
	r["stick_left_steer"] = snappedf(car.steer_input, 0.01)
	_pad_axis(JOY_AXIS_TRIGGER_RIGHT, 0.5)
	await _ct_drive(0.1)
	r["half_trigger_throttle"] = snappedf(car.throttle_input, 0.01)
	_pad_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	_pad_axis(JOY_AXIS_LEFT_X, 0.0)
	_pad_button(JOY_BUTTON_A, true)
	await _ct_drive(0.1)
	r["A_brake"] = car.brake_input
	_pad_button(JOY_BUTTON_A, false)
	await _ct_drive(0.1)
	# 2. Hold Y to flip: a short tap does nothing, a 0.5 s hold resets.
	car.global_transform = Transform3D(Basis(Vector3.BACK, PI * 0.9), car.global_position + Vector3(0, 0.5, 0))
	await _wait(0.8)
	_pad_button(JOY_BUTTON_Y, true)
	await _ct_drive(0.2)
	_pad_button(JOY_BUTTON_Y, false)
	await _ct_drive(0.1)
	r["Y_tap_flipped"] = car.global_basis.y.y > 0.5
	_pad_button(JOY_BUTTON_Y, true)
	await _ct_drive(0.7)
	_pad_button(JOY_BUTTON_Y, false)
	await _ct_drive(0.3)
	r["Y_hold_flipped"] = car.global_basis.y.y > 0.5
	# 3. Prompts follow the device.
	r["prompt_brake_pad"] = GameInput.prompt("brake")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await get_tree().process_frame     # (queued input arrives a frame later)
	await get_tree().process_frame
	r["prompt_brake_keyboard"] = GameInput.prompt("brake")
	r["start_is_pause"] = InputMap.event_is_action(_ev_button(JOY_BUTTON_START), "pause")
	# 4. The workshop on a pad.
	_m5_put_truck(BASE_POS, PI)
	await _wait(0.6)
	_pad_axis(JOY_AXIS_LEFT_X, 0.0)
	_pad_button(JOY_BUTTON_B, false)
	GameInput.using_pad = true
	_open_workshop()
	await _wait(0.3)
	var before := workshop.selected
	_pad_button(JOY_BUTTON_RIGHT_SHOULDER, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_pad_button(JOY_BUTTON_RIGHT_SHOULDER, false)
	await get_tree().process_frame
	r["RB_changed_part"] = before + " -> " + workshop.selected
	workshop.selected = "ballast"
	workshop._cursor = "L1"
	_pad_button(JOY_BUTTON_A, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_pad_button(JOY_BUTTON_A, false)
	await _wait(0.2)
	r["A_placed"] = build.get("L1", "(nothing)")
	_pad_button(JOY_BUTTON_DPAD_RIGHT, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_pad_button(JOY_BUTTON_DPAD_RIGHT, false)
	await get_tree().process_frame
	r["dpad_moved_cursor"] = workshop._cursor != "L1"
	workshop._cursor = "L1"
	_pad_button(JOY_BUTTON_X, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_pad_button(JOY_BUTTON_X, false)
	await _wait(0.2)
	r["X_removed"] = not build.has("L1")
	var bev := _ev_button(JOY_BUTTON_B)
	bev.pressed = true
	Input.parse_input_event(bev)
	await get_tree().process_frame
	await get_tree().process_frame
	bev = bev.duplicate()
	bev.pressed = false
	Input.parse_input_event(bev)
	await get_tree().process_frame
	r["B_left_workshop"] = not workshop.active
	# 5. Menus put the focus on a button (so the pad works at once).
	_open_menu()
	await get_tree().process_frame
	await get_tree().process_frame
	var f := get_viewport().gui_get_focus_owner()
	r["base_menu_focus"] = f.get_class() if f else "(none)"
	_close_menu()
	var tm := TitleMenu.new()
	tm.has_save = true
	add_child(tm)
	await get_tree().process_frame
	await get_tree().process_frame
	f = get_viewport().gui_get_focus_owner()
	r["title_focus"] = (f as Button).text if f is Button else "(none)"
	tm.queue_free()
	# 6. Settings survive a reload.
	var old: float = Settings.get_value("rumble")
	Settings.set_value("rumble", 0.25)
	Settings.load_settings()
	r["settings_saved_and_loaded"] = is_equal_approx(Settings.get_value("rumble"), 0.25)
	Settings.set_value("rumble", old)
	# 7. Achievements: unlock, remembered after a reload (in a test file).
	Achievements.path = "user://test_achievements.json"
	Achievements.enabled = true
	Achievements.reload()
	Achievements.unlock("ACH_FAST_TRAVEL")
	Achievements.add("pristine", 10, 10, "ACH_PRISTINE_10")
	Achievements.reload()
	r["achievements_remembered"] = Achievements.is_unlocked("ACH_FAST_TRAVEL") and Achievements.is_unlocked("ACH_PRISTINE_10")
	r["steam_running"] = SteamService.running
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Achievements.path))
	Achievements.enabled = false
	print("CONTROLLERTEST ", JSON.stringify(r, "  "))
	get_tree().quit()


func _ev_button(button: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	return e
