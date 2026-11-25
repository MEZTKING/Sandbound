extends Node
## Beauty shots: six fixed cameras that save PNGs, so every art change can be
## compared before and after. Open tools/beauty_shots.tscn and press F6
## (Run Current Scene). The pictures go to the folder printed in the Output
## panel (user://beauty_shots), or to a folder given on the command line:
##   godot --path . res://tools/beauty_shots.tscn -- /some/folder
##
## The same six views every time: home base, the truck up close, the Salt
## Flats outpost, the Glass Desert, a Drift sand river, and the hull.

var m
var out := "user://beauty_shots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	m = load("res://main.tscn").instantiate()
	add_child(m)
	await _wait(0.5)
	if m.title_screen:
		m.title_screen.visible = false
	m._close_menu()
	m._m4test = "beauty"                  # (stops input handling and save files)
	Achievements.enabled = false          # building outposts here mustn't unlock anything
	m.message.visible = false             # no pop-up messages in the pictures
	m.terrain.finish_all_tiles()
	m.day_night.paused = true
	m.day_night.skip_to(0.36)             # mid-morning: low, warm sun
	m.weather._timer = 1e9
	m.hawk._cooldown = 1e9
	m._storm_timer = 1e9
	m.hud.visible = false
	m.set_process(false)                  # we aim the camera ourselves
	m._update_drift(0.0)
	for id in ["outpost", "glass", "drift"]:
		m._build_outpost(id)
	m.build = {"F1": "winch", "F0": "bumper", "F2": "bumper", "C0": "headlight", "C1": "wing",
		"B0": "spare", "U0": "gyro", "N": "net"}
	m._rebuild_car()
	await _wait(1.5)
	m.car.hold(true)
	# Stills: stop the game's world update (it would switch off full detail
	# away from the truck).
	m.set_physics_process(false)
	var base: Vector3 = m._on_ground(m.BASE_POS)
	var cp: Vector3 = m.car.global_position
	await _shot("1_base.png", base + Vector3(5.5, 3.2, 6.0), base + Vector3(0, 0.3, 0))
	await _shot("2_truck.png", cp + Vector3(1.6, 0.8, -1.7), cp + Vector3(0, 0.1, 0))
	var op: Vector3 = m._on_ground(m.OUTPOST_POS)
	await _shot("3_salt_flats.png", op + Vector3(10, 4, 12), op + Vector3(0, 0.5, 0))
	var gp: Vector3 = m._on_ground(m.GLASS_OUTPOST_POS + Vector3(-20, 0, 8))
	await _shot("4_glass_desert.png", gp + Vector3(6, 3, 8), gp + Vector3(-10, 0, -10))
	var river: Vector3 = m._m7_find(func(x, z): return m.terrain.get_flow(x, z) > 0.95 and absf(z) < 196 and absf(x) < 180)
	var rp: Vector3 = m._on_ground(river)
	var inward := Vector3(-rp.x, 0, -rp.z).normalized()
	await _shot("5_drift_river.png", rp - inward * 7.0 + Vector3(0, 3.5, 0), rp + inward * 4.0)
	var hull: Vector3 = m._on_ground(m.HULL_POS)
	await _shot("6_hull.png", hull + Vector3(14, 5, 10), hull + Vector3(0, 1.0, 0))
	print("Beauty shots saved in: ", ProjectSettings.globalize_path(out))
	get_tree().quit()


func _shot(file: String, at: Vector3, look: Vector3) -> void:
	m.terrain.ensure_active_at(look.x, look.z)   # full detail where we look
	m.camera.global_position = at
	m.camera.look_at(look)
	await _wait(1.2)
	await get_tree().process_frame
	m.get_viewport().get_texture().get_image().save_png(out + "/" + file)
	print("SHOT ", file)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
