extends SceneTree
## Benchmarks the sand hot paths (run: godot --headless -s tools/_bench.gd).
func _initialize():
	var pads: Array[Vector3] = []
	var main_script = load("res://scripts/main.gd")
	for sp in main_script.DELIVERY_SPOTS:
		pads.append(Vector3(sp.x, sp.z, 2.2))
	for b in [main_script.BASE_POS, main_script.OUTPOST_POS, main_script.GLASS_OUTPOST_POS, main_script.DRIFT_POS]:
		pads.append(Vector3(b.x, b.z, 4.0))
	var tile := SandTile.new()
	tile.flat_pads = pads
	tile.origin = Vector2(0, -192)
	tile.coord = Vector2i(0, -3)
	tile.world_half = 224.0
	tile.material = load("res://materials/sand_material.tres").duplicate()
	var t0 := Time.get_ticks_usec()
	tile.generate_data()
	print("BENCH generate_data_ms=", (Time.get_ticks_usec() - t0) / 1000.0)
	root.add_child(tile)
	await process_frame          # let _ready run
	tile.activate()
	# Send dug heights to the GPU (what happens up to 30 times a second while digging).
	var t1 := Time.get_ticks_usec()
	for k in 100:
		tile._heights_dirty = true
		tile._upload()
	print("BENCH upload_ms_each=", (Time.get_ticks_usec() - t1) / 1000.0 / 100.0)
	# Press 200 wheel prints and settle.
	var t2 := Time.get_ticks_usec()
	for k in 200:
		tile.press(Vector3(-10 + k * 0.1, 0, -192 + sin(k * 0.3)), 0.3, 0.02, 0.15)
	print("BENCH press_us_each=", (Time.get_ticks_usec() - t2) / 200.0)
	var t3 := Time.get_ticks_usec()
	for k in 60:
		tile._settle()
	print("BENCH settle_ms_per_tick=", (Time.get_ticks_usec() - t3) / 1000.0 / 60.0)
	var check := 0.0
	for k in range(0, tile.heights.size(), 97):
		check += tile.heights[k]
	print("BENCH checksum=", snappedf(check, 0.001))
	quit()


## Run with:  godot --headless --path . -s tools/_bench.gd
