class_name Sfx
extends Node
## Plays sound effects. All sounds are WAV files in res://sounds/: swap any
## of them for your own (same name) and the game uses yours.
##
##   play("thud", position)     a one-off sound at a place in the world
##   play("chime")              a one-off sound "in your ears" (no position)
##   make_loop("engine", node)  a looping sound attached to something; set
##                              its volume_db / pitch_scale every frame
##
## Sounds at a position get quieter with distance and pan left/right, using
## AudioStreamPlayer3D. A small pool of players is reused so sounds that
## overlap don't cut each other off.

const LOOPS := ["engine_loop", "sand_loop", "wind_loop", "winch_loop"]

var _streams := {}
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _pool_2d: Array[AudioStreamPlayer] = []
var _next_3d := 0
var _next_2d := 0


func _ready() -> void:
	for f in ["engine_loop", "sand_loop", "wind_loop", "winch_loop", "thud", "beetle_hiss",
			"hawk_screech", "cheer", "chime", "fail", "click", "ratchet"]:
		var s: AudioStreamWAV = load("res://sounds/%s.wav" % f)
		if f in LOOPS:
			s = s.duplicate()
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = int(s.get_length() * s.mix_rate)
		_streams[f] = s
	for i in 12:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"            # the Sound effects volume slider
		p.unit_size = 4.0
		p.max_distance = 60.0
		add_child(p)
		_pool_3d.append(p)
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"            # the Sound effects volume slider
		add_child(p)
		_pool_2d.append(p)


## A one-off sound. With a position it's in the world; without, it's in your ears.
func play(sound: String, at: Variant = null, volume_db := 0.0, pitch := 1.0) -> void:
	if not _streams.has(sound):
		return
	if at is Vector3:
		var p := _pool_3d[_next_3d]
		_next_3d = (_next_3d + 1) % _pool_3d.size()
		p.stream = _streams[sound]
		p.global_position = at
		p.volume_db = volume_db
		p.pitch_scale = pitch * randf_range(0.93, 1.07)   # a little variety
		p.play()
	else:
		var p := _pool_2d[_next_2d]
		_next_2d = (_next_2d + 1) % _pool_2d.size()
		p.stream = _streams[sound]
		p.volume_db = volume_db
		p.pitch_scale = pitch
		p.play()


## A looping sound that follows `parent`. Starts silent; you set its volume.
func make_loop(sound: String, parent: Node3D) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = "SFX"            # the Sound effects volume slider
	p.stream = _streams[sound + "_loop"]
	p.unit_size = 4.0
	p.max_distance = 60.0
	p.volume_db = -80.0
	parent.add_child(p)
	p.play()
	return p


## A looping sound with no position (wind is everywhere).
func make_ambient_loop(sound: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"            # the Sound effects volume slider
	p.stream = _streams[sound + "_loop"]
	p.volume_db = -80.0
	add_child(p)
	p.play()
	return p
