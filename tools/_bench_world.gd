extends SceneTree
## How long the whole world takes to make (run: godot --headless --path . -s tools/_bench_world.gd).
func _initialize():
	var main_script = load("res://scripts/main.gd")
	var t := SandTerrain.new()
	for sp in main_script.DELIVERY_SPOTS:
		t.flat_pads.append(Vector3(sp.x, sp.z, 2.2))
	for b in [main_script.BASE_POS, main_script.OUTPOST_POS, main_script.GLASS_OUTPOST_POS, main_script.DRIFT_POS]:
		t.flat_pads.append(Vector3(b.x, b.z, 4.0))
	await process_frame
	var t0 := Time.get_ticks_msec()
	root.add_child(t)      # runs SandTerrain._ready: the home tile, ready to drive on
	print("BENCH drivable_ms=", Time.get_ticks_msec() - t0)
	t.finish_all_tiles()
	print("BENCH all_tiles_ms=", Time.get_ticks_msec() - t0)
	var sum := 0.0
	for c in t.tiles:
		var tile: SandTile = t.tiles[c]
		for k in range(0, tile.heights.size(), 101):
			sum += tile.heights[k] + tile.hardness[k] + tile.crust[k] + tile.glass[k] + tile.flow[k]
	print("BENCH world_checksum=", snappedf(sum, 0.01))
	quit()
