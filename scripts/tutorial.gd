class_name Tutorial
extends CanvasLayer
## Old Pip walks you through your first contract ("First Day"), one tip at a
## time, in a panel at the bottom of the screen. Every step waits for you to
## actually DO the thing (squeeze the throttle gently, steer, brake, find the
## firm ground...). Nothing ever blocks driving.
##
## The script below was decided in a design review. To change what Pip says
## or when, edit STEPS and _check(). Hold Tab (or View on a pad) to skip; the
## "Tutorial tips" option turns him off; Pause > "Replay First Day" repeats it.
##
## Also: one-off tips the FIRST time something happens in any contract
## (a beetle rearing, ants marching on your cargo, your cargo falling off).

signal finished

## id, what Pip says. {action} becomes that button's name (keyboard or pad).
const STEPS := [
	["throttle", "Easy on the trigger, kid. Squeeze {accelerate} gently."],
	["steer_brake", "Steer with {steer}. Brake with {brake}. Try both."],
	["hardpan", "See the pale cracked ground? That's hardpan. Get on it."],
	["soft", "Soft sand now. Floor it and you dig a hole. Stay smooth."],
	["ridge", "Mind that ridge. My toolbox ain't strapped down."],
	["point_c", "That's point C. Stop inside the ring."],
	["done", "Not bad for a first day. Come back to base, I've got real work."],
]
const DIGGING := "You're digging! Let off, then ease back on {accelerate}."
const RELOAD := "Told you. Park close and press {load_crate} to load it back."
const WRONG_WAY := "Wrong way, kid. Follow the marker."
const TIPS := {
	"beetle": "Beetle's rearing up. It's about to charge. Move sideways!",
	"ants": "Ants! They're after your cargo. Get back to it, quick.",
	"dropped": "Your cargo's off! Park close and press {load_crate} to load it back.",
}

const RIDGE_DISTANCE := 12.0      # m from base along the route to C

var main: Node
var active := false
var step := 0
var steps_done: Array[String] = []   # (the test reads this)
var _t := 0.0             # seconds in this step (for the 20 s reminder)
var _hold := 0.0          # seconds holding the skip button
var _speed_time := 0.0
var _steer_time := 0.0
var _braked := false
var _hard_time := 0.0
var _soft_m := 0.0        # metres driven smoothly on soft sand (counted all along)
var _digging := false
var _reloading := false
var _wrong_way_said := false
var _passed_ridge := false
var _ridge_a := Vector3.ZERO
var _ridge_b := Vector3.ZERO
var _hardpan_spot := Vector3.INF
var _arrow: MeshInstance3D
var _tip_time := 0.0
var _panel: PanelContainer
var _text: Label
var _tick: Label
var _skip_hint: Label
var _last_pos := Vector3.INF


func _ready() -> void:
	layer = 6
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.085, 0.07, 0.88)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	style.border_color = Color(0.74, 0.2, 0.12)
	style.border_width_left = 5
	_panel.add_theme_stylebox_override("panel", style)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -400
	_panel.offset_right = 400
	_panel.offset_top = -132
	_panel.offset_bottom = -24
	add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var name_tag := UIKit.label("OLD PIP", 16, Color(0.95, 0.45, 0.3))
	name_tag.add_theme_font_override("font", UIKit.BOLD_FONT)
	row.add_child(name_tag)
	_tick = UIKit.label("", 18, Color(0.5, 1.0, 0.5))
	_tick.add_theme_font_override("font", UIKit.BOLD_FONT)
	row.add_child(_tick)
	_text = UIKit.label("", 20)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = 760
	box.add_child(_text)
	_skip_hint = UIKit.label("", 13, Color(1, 1, 1, 0.55))
	box.add_child(_skip_hint)
	visible = false


# ---------------------------------------------------------------------------
# Starting and stopping
# ---------------------------------------------------------------------------

## The First Day contract has just started at base.
func start() -> void:
	active = true
	step = 0
	steps_done.clear()
	_soft_m = 0.0
	_passed_ridge = false
	_wrong_way_said = false
	_reloading = false
	# The ridge across the route, 12 m out from base towards point C.
	var base: Vector3 = main.BASE_POS
	var c: Vector3 = main.DELIVERY_SPOTS[2]
	var dir := Vector3(c.x - base.x, 0, c.z - base.z).normalized()
	var mid := base + dir * RIDGE_DISTANCE
	var across := Vector3(-dir.z, 0, dir.x)
	_ridge_a = mid - across * 3.0
	_ridge_b = mid + across * 3.0
	main.terrain.raise_ridge(_ridge_a, _ridge_b, 0.25, 0.8)
	_show_step()


func stop(save := true) -> void:
	active = false
	visible = false
	_clear_arrow()
	if save:
		main.tutorial_done = true
		main._save_game()
	finished.emit()


## Hold Tab / View for a second: no more tips this time.
func _check_skip(delta: float) -> void:
	if Input.is_action_pressed("skip_tips"):
		_hold += delta
		if _hold >= 1.0:
			_hold = 0.0
			stop()
			main.show_message("Pip's tips off. (Options > Tutorial tips turns them back on.)")
	else:
		_hold = 0.0


# ---------------------------------------------------------------------------
# Every physics step
# ---------------------------------------------------------------------------

func update(delta: float) -> void:
	if not active:
		_update_tip(delta)
		return
	_check_skip(delta)
	if not active:
		return
	var car: RCCar = main.car
	var pos := car.global_position
	var speed := car.linear_velocity.length()
	_t += delta
	_track(delta, car, pos, speed)
	# Cargo off the truck? Teach reloading first (it's the urgent thing).
	if main._crate_dropped() and not _reloading:
		_reloading = true
		if not "dropped" in main.tips_seen:
			main.tips_seen.append("dropped")    # (taught now: no tip later)
		_say(RELOAD)
	elif _reloading:
		if main._crate_on_truck():
			_reloading = false
			_flash_tick()
			_show_step()
		return
	if step >= STEPS.size():
		return
	var id: String = STEPS[step][0]
	if _check(id, car, pos, speed):
		_complete()
	elif _t > 20.0:
		_t = 0.0
		_show_step()      # say it again, once in a while
	# Wandering off?
	var c: Vector3 = main.DELIVERY_SPOTS[2]
	if not _wrong_way_said and pos.distance_to(main.BASE_POS) > 60.0 and pos.distance_to(c) > 60.0:
		_wrong_way_said = true
		_say(WRONG_WAY)


## Things counted all the time, so a step you've already done is skipped.
func _track(delta: float, car: RCCar, pos: Vector3, speed: float) -> void:
	var soft := 0
	var hard := 0
	var on_pad: bool = pos.distance_to(main.BASE_POS) < main.BASE_RADIUS + 3.0
	for w in car.wheels:
		if w.is_in_contact():
			var h: float = main.terrain.get_hardness(w.global_position.x, w.global_position.z)
			soft += 1 if h < 0.33 else 0
			# (The base's concrete pad is firm too, but it isn't hardpan.)
			hard += 1 if h > 0.66 and not on_pad else 0
	if _last_pos != Vector3.INF and soft >= 2 and car.get_spin_amount() < 0.5:
		_soft_m += Vector2(pos.x - _last_pos.x, pos.z - _last_pos.z).length()
	_last_pos = pos
	_hard_time = _hard_time + delta if hard >= 3 else 0.0
	# Past the ridge? (Further along the route than it is.)
	var base: Vector3 = main.BASE_POS
	var c: Vector3 = main.DELIVERY_SPOTS[2]
	var dir := Vector3(c.x - base.x, 0, c.z - base.z).normalized()
	if Vector3(pos.x - base.x, 0, pos.z - base.z).dot(dir) > RIDGE_DISTANCE + 1.5:
		_passed_ridge = true
	# Digging in soft sand: Pip shouts (once per dig).
	if STEPS[mini(step, STEPS.size() - 1)][0] == "soft":
		if car.get_spin_amount() > 0.5 and speed < 0.5:
			if not _digging:
				_digging = true
				_say(DIGGING)
		elif _digging and speed > 1.5:
			_digging = false
			_show_step()


func _check(id: String, car: RCCar, pos: Vector3, speed: float) -> bool:
	match id:
		"throttle":
			_speed_time = _speed_time + get_physics_process_delta_time() if speed > 2.0 else 0.0
			return _speed_time >= 1.0
		"steer_brake":
			if absf(car.steer_input) > 0.5:
				_steer_time += get_physics_process_delta_time()
			if car.brake_input > 0.5 and speed > 1.0:
				_braked = true
			return _steer_time >= 0.5 and _braked
		"hardpan":
			return _hard_time >= 1.5
		"soft":
			return _soft_m >= 4.0
		"ridge":
			return _passed_ridge
		"point_c":
			return false          # finished by the delivery itself
		"done":
			return _t > 5.0
	return false


func _complete() -> void:
	steps_done.append(STEPS[step][0])
	_flash_tick()
	main.sfx.play("click", null, -8.0, 1.4)
	step += 1
	if step >= STEPS.size():
		stop()
		return
	# Steps already taken care of are skipped.
	while step < STEPS.size():
		var id: String = STEPS[step][0]
		if (id == "soft" and _soft_m >= 4.0) or (id == "ridge" and _passed_ridge):
			steps_done.append(id)
			step += 1
		elif id == "point_c" and main.car.global_position.distance_to(main.DELIVERY_SPOTS[2]) > 10.0:
			break
		else:
			break
	_show_step()


## The delivery is in: everything left is done, Pip says well done.
func on_delivered() -> void:
	if not active:
		return
	for k in range(step, STEPS.size() - 1):
		steps_done.append(STEPS[k][0])
	step = STEPS.size() - 1
	_reloading = false
	_t = 0.0
	_show_step()


func _show_step() -> void:
	_t = 0.0
	_clear_arrow()
	if step >= STEPS.size():
		return
	_say(STEPS[step][1])
	if STEPS[step][0] == "hardpan":
		_point_at_hardpan()


# ---------------------------------------------------------------------------
# Showing Pip's lines
# ---------------------------------------------------------------------------

func _say(line: String) -> void:
	_text.text = fill(line)
	_skip_hint.text = "Hold %s to skip Pip's tips" % ("View" if GameInput.using_pad else "Tab")
	if not visible:
		visible = true
		_panel.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_panel, "modulate:a", 1.0, 0.25)
	main.sfx.play("click", null, -6.0, 0.55)    # a little radio blip


## Replace {action} with the button's name for your keyboard or pad.
static func fill(line: String) -> String:
	var steer := "Left stick" if GameInput.using_pad else "%s / %s" % [GameInput.prompt("steer_left"), GameInput.prompt("steer_right")]
	line = line.replace("{steer}", steer)
	for a in ["accelerate", "brake", "load_crate"]:
		line = line.replace("{%s}" % a, GameInput.prompt(a))
	return line


func _flash_tick() -> void:
	_tick.text = "✓"
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback(func(): _tick.text = "")


## A bobbing arrow over the nearest patch of hardpan.
func _point_at_hardpan() -> void:
	var car_pos: Vector3 = main.car.global_position
	var best := Vector3.INF
	# The best firm patch: close, and on the way to point C if possible.
	var c: Vector3 = main.DELIVERY_SPOTS[2]
	var best_score := INF
	for r in range(4, 40, 2):
		for k in 24:
			var a := k * TAU / 24.0
			var p := car_pos + Vector3(cos(a), 0, sin(a)) * r
			if p.distance_to(main.BASE_POS) < main.BASE_RADIUS + 4.0:
				continue          # not the base pad
			# Firm under the whole truck, not just one spot.
			var firm := true
			for off in [Vector2.ZERO, Vector2(1.1, 1.1), Vector2(-1.1, 1.1), Vector2(1.1, -1.1), Vector2(-1.1, -1.1)]:
				if main.terrain.get_hardness(p.x + off.x, p.z + off.y) < 0.75:
					firm = false
					break
			var score := r + p.distance_to(c) * 0.6
			if firm and score < best_score:
				best_score = score
				best = p
	_hardpan_spot = best
	if best == Vector3.INF:
		return
	_arrow = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.18
	cone.bottom_radius = 0.0
	cone.height = 0.4
	_arrow.mesh = cone
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.75, 0.3)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.6, 0.2)
	m.emission_energy_multiplier = 1.5
	_arrow.material_override = m
	main.add_child(_arrow)
	var ground: Vector3 = main._on_ground(best)
	_arrow.global_position = ground + Vector3(0, 0.6, 0)
	var tw := _arrow.create_tween().set_loops()
	tw.tween_property(_arrow, "position:y", ground.y + 0.9, 0.5)
	tw.tween_property(_arrow, "position:y", ground.y + 0.6, 0.5)


func _clear_arrow() -> void:
	if _arrow and is_instance_valid(_arrow):
		_arrow.queue_free()
	_arrow = null


# ---------------------------------------------------------------------------
# One-off tips (any contract, the first time each thing happens)
# ---------------------------------------------------------------------------

func tip(id: String) -> void:
	if active or not Settings.get_value("tutorial_tips") or id in main.tips_seen:
		return
	main.tips_seen.append(id)
	main._save_game()
	_say(TIPS[id])
	_tip_time = 6.0


func _update_tip(delta: float) -> void:
	if _tip_time > 0.0:
		_tip_time -= delta
		if _tip_time <= 0.0:
			visible = false
