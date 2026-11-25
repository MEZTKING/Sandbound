class_name CrewFitting
extends Node3D
## The crew fitting a part you bought in the garage: the nearest crew step
## out of the crowd, fetch the part from the parts pile, carry it to the
## truck (1.8 s), bolt it on with three ratchet clicks and sparks (1.2 s),
## then the part pops into place and they wander back into the crowd.
##
## 2 crew for a normal part, 4 for a heavy one. Several purchases queue up a
## second apart. Nothing blocks driving: closing the menu or touching the
## throttle finishes every fit at once (finish_all).

signal fitted(job: int)

const CARRY_S := 1.8
const BOLT_S := 1.2

var main: Node            # main.gd: for sounds and ground heights
var _jobs := {}           # job id -> {crew: [[index, figure]], crowd, box, tween}
var _next_id := 1


## Start a fit. Returns a job id; `fitted(job)` is emitted when the part is on.
func fit(crowd: CrewCrowd, pile: Vector3, truck: Vector3, count: int, delay: float) -> int:
	var job := _next_id
	_next_id += 1
	var crew := []
	for b in crowd.borrow(pile, count):
		var fig := TinyFigure.make(b[2], 0.3)
		add_child(fig)
		fig.global_position = b[1]
		crew.append([b[0], fig, b[1]])
	var box := Models.make("crate")
	box.scale = Vector3.ONE * 0.45
	box.visible = false
	add_child(box)
	_jobs[job] = {"crew": crew, "crowd": crowd, "box": box}
	var tw := create_tween()
	_jobs[job]["tween"] = tw
	tw.tween_interval(delay)
	# 1. Run to the parts pile (0.6 s), pick the part up.
	tw.tween_callback(func(): _walk_all(job, pile, 0.5, 0.6))
	tw.tween_interval(0.6)
	tw.tween_callback(func():
		box.visible = true
		box.global_position = pile + Vector3(0, 0.36, 0)
		main.sfx.play("click", pile, -6.0, 0.8))
	# 2. Carry it to the truck, held above their heads (1.2 s).
	tw.tween_callback(func():
		_walk_all(job, truck, 0.75, CARRY_S - 0.6)
		var bt := box.create_tween()
		bt.tween_property(box, "global_position", _ground(truck) + Vector3(0, 0.55, 0), CARRY_S - 0.6))
	tw.tween_interval(CARRY_S - 0.6)
	# 3. Bolt it on: three ratchet clicks, sparks, hops.
	tw.tween_callback(func(): box.visible = false)
	for click in 3:
		tw.tween_callback(func():
			main.sfx.play("ratchet", truck, -2.0, 1.0 + click * 0.08)
			_sparks(truck + Vector3(randf_range(-0.4, 0.4), 0.1, randf_range(-0.6, 0.6)))
			for c in crew:
				var f: Node3D = c[1]
				var h := f.create_tween()
				h.tween_property(f, "position:y", f.position.y + 0.1, 0.12)
				h.tween_property(f, "position:y", f.position.y, 0.12))
		tw.tween_interval(BOLT_S / 3.0)
	# 4. Done: the part pops in, the crew go home.
	tw.tween_callback(func():
		fitted.emit(job)
		_send_home(job))
	return job


func is_busy() -> bool:
	return not _jobs.is_empty()


## Finish everything now: crew vanish back into the crowd. (The caller
## fits the parts itself.)
func finish_all() -> void:
	for job in _jobs.keys():
		var j: Dictionary = _jobs[job]
		if j.has("tween") and j["tween"].is_valid():
			j["tween"].kill()
		_cleanup(job)


func _send_home(job: int) -> void:
	var j: Dictionary = _jobs[job]
	var tw := create_tween().set_parallel(true)
	for c in j["crew"]:
		var f: Node3D = c[1]
		_face(f, c[2])
		tw.tween_property(f, "global_position", c[2], 1.0)
	tw.chain().tween_callback(func(): _cleanup(job))


func _cleanup(job: int) -> void:
	if not _jobs.has(job):
		return
	var j: Dictionary = _jobs[job]
	for c in j["crew"]:
		j["crowd"].give_back(c[0])
		if is_instance_valid(c[1]):
			c[1].queue_free()
	if is_instance_valid(j["box"]):
		j["box"].queue_free()
	_jobs.erase(job)


## Everyone in a job walks to spots around `target` (radius r) in `secs`.
func _walk_all(job: int, target: Vector3, r: float, secs: float) -> void:
	var crew: Array = _jobs[job]["crew"]
	for k in crew.size():
		var f: Node3D = crew[k][1]
		var a := k * TAU / crew.size() + 0.4
		var spot := _ground(target + Vector3(cos(a), 0, sin(a)) * r)
		_face(f, spot)
		var t := f.create_tween()
		t.tween_property(f, "global_position", spot, secs)


func _face(f: Node3D, toward: Vector3) -> void:
	var d := toward - f.global_position
	d.y = 0.0
	if d.length() > 0.01:
		f.look_at(f.global_position + d, Vector3.UP, true)


func _ground(p: Vector3) -> Vector3:
	return main._on_ground(p)


## A quick shower of sparks (tiny glowing bits that fall).
func _sparks(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 14
	p.lifetime = 0.35
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.2
	p.gravity = Vector3(0, -9.8, 0)
	var m := SphereMesh.new()
	m.radius = 0.008
	m.height = 0.016
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.8, 0.3)
	m.material = mat
	p.mesh = m
	add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(0.6).timeout.connect(p.queue_free)
