class_name SandTerrain
extends Node3D
## The whole desert: a grid of SandTiles, streamed in and out around you.
##
## 7 x 7 tiles of 64 m = 448 m across. Rings by distance from the centre:
##   Ring 0, the Home Dunes:   the middle (out to ~35 m)
##   Ring 1, the Salt Flats:   ~35 to ~93 m
##   Ring 2, the Glass Desert: ~93 to ~167 m
##   Ring 3, the Drift:        ~167 m to the edge (low gravity, sand rivers)
## (the ground blends from one ring to the next).
##
## Everything else in the game talks to THIS object exactly like it used to
## talk to the single old terrain (get_height, press, tracks.stamp...). It
## finds the right tile and passes the call on. That's why making the world
## bigger barely changed the truck, beetles, ants or hawk.
##
## Streaming, step by step:
##   1. At start every tile's heights are generated on BACKGROUND THREADS
##      (WorkerThreadPool). We only wait for the middle one; the rest pop in
##      as they finish, without freezing the game.
##   2. Tiles near something that matters (the truck, loose cargo, the home
##      dunes where the beetles and ants live) are ACTIVE: full detail,
##      collision, tyre tracks. The rest are cheap low-detail meshes.
##   3. Hysteresis: activate within 20 m, deactivate beyond 30 m, so a tile
##      doesn't flick on and off as you drive along its edge.

const TILES_PER_SIDE := 7
const TILE_SIZE := 64.0
const SAND_RENDER_LAYER := SandTile.SAND_RENDER_LAYER

## Activate tiles this close (collision is instant; the detailed mesh takes a
## few frames, so 20 m of warning is plenty even at full speed).
@export var activate_distance: float = 20.0
@export var deactivate_distance: float = 30.0
@export var track_resolution: int = 4096
@export var noise_seed: int = 1337
## Save generated tiles in user://tile_cache and load them next time (much
## faster). The cache knows when the generator code changed: see
## SandTile.cache_key().
@export var use_cache: bool = true
## The look of the sand. Each tile gets its own copy (each has its own track
## map), so change shader settings through set_shader_parameter() below.
@export var sand_material: ShaderMaterial = preload("res://materials/sand_material.tres")

var flat_pads: Array[Vector3] = []
var mounds: Array[Vector3] = []
var tiles := {}                     # Vector2i -> SandTile
var tracks := TrackRouter.new()
## Points that keep tiles active (the game sets these: truck, cargo...).
var focus_points: Array[Vector3] = []
var _tasks := {}                    # Vector2i -> WorkerThreadPool task id
var cell_size := 0.25

# Combined profiling (for the HUD and tests).
var prof_press_us: int:
	get: return _sum("prof_press_us")
var prof_settle_us: int:
	get: return _sum("prof_settle_us")
var prof_collision_us: int:
	get: return _sum("prof_collision_us")
var prof_mesh_us: int:
	get: return _sum("prof_mesh_us")
var prof_mesh_rebuilds: int:
	get: return _sum("prof_mesh_rebuilds")


func _ready() -> void:
	tracks.world = self
	var half := TILES_PER_SIDE * TILE_SIZE * 0.5
	var r := TILES_PER_SIDE / 2
	# Nearest tiles first: the thread pool works through jobs in order, so
	# the home tile (which we wait for) and its neighbours come out first.
	var order: Array[Vector2i] = []
	for tz in range(-r, r + 1):
		for tx in range(-r, r + 1):
			order.append(Vector2i(tx, tz))
	order.sort_custom(func(a: Vector2i, b: Vector2i): return a.length_squared() < b.length_squared())
	var cache_key := SandTile.cache_key(noise_seed, flat_pads, mounds)
	if use_cache:
		_prune_cache(cache_key)
	for c in order:
		var t := SandTile.new()
		t.coord = c
		t.origin = Vector2(c) * TILE_SIZE
		t.world_half = half
		t.noise_seed = noise_seed
		t.flat_pads = flat_pads
		t.mounds = mounds
		t.track_resolution = track_resolution
		t.material = sand_material.duplicate()
		t.cache_file = cache_key + "_%d_%d.tile" % [c.x, c.y] if use_cache else ""
		tiles[t.coord] = t
		# Generate (or load from the cache) on a background thread.
		# high_priority = true: "low priority" jobs only get a share of the
		# worker threads (one, on a 4-core CPU), which made the world take
		# 7.7 s instead of ~3.
		_tasks[t.coord] = WorkerThreadPool.add_task(t.generate_data, true, "sand tile %s" % t.coord)
	# The home tile is needed right now: wait for just that one.
	_finish_tile(Vector2i.ZERO, true)
	tiles[Vector2i.ZERO].activate()
	# Finish its chunks immediately too (no pop-in at the start).
	while not tiles[Vector2i.ZERO].is_fully_built():
		tiles[Vector2i.ZERO]._process(0.0)


## Delete cached tiles from older versions of the world (anything not named
## with the current key), so the cache never grows past one world (~23 MB).
func _prune_cache(key: String) -> void:
	var dir := DirAccess.open(SandTile.CACHE_DIR)
	if dir == null:
		return
	for f in dir.get_files():
		if not f.begins_with(key):
			dir.remove(f)


## When a tile's thread is done, put the tile into the scene.
func _finish_tile(c: Vector2i, wait: bool) -> bool:
	if not _tasks.has(c):
		return tiles[c].is_inside_tree()
	if not wait and not WorkerThreadPool.is_task_completed(_tasks[c]):
		return false
	WorkerThreadPool.wait_for_task_completion(_tasks[c])
	_tasks.erase(c)
	add_child(tiles[c])
	return true


## Quitting while tiles are still generating: wait for those threads to
## finish and free the tiles that never made it into the scene. (Without this
## the game hung on exit if you quit in the first few seconds.)
func _exit_tree() -> void:
	# Shared meshes live in a static cache. Statics are cleared AFTER Godot
	# has shut its renderer down, and freeing a mesh then crashed the game on
	# exit now and then. Empty the cache while the renderer still exists.
	SandTile._grids.clear()
	for c in _tasks:
		tiles[c].cancelled = true
	for c in _tasks:
		WorkerThreadPool.wait_for_task_completion(_tasks[c])
	_tasks.clear()
	for c in tiles:
		var t: SandTile = tiles[c]
		if not t.is_inside_tree():
			t.free()
	tiles.clear()


## Wait for every tile (tests use this so results don't depend on timing).
func finish_all_tiles() -> void:
	for c in tiles:
		_finish_tile(c, true)


func _process(_delta: float) -> void:
	# Pop in tiles whose threads have finished.
	for c in _tasks.keys():
		_finish_tile(c, false)
	# Activate / deactivate around the focus points.
	for c in tiles:
		var t: SandTile = tiles[c]
		if not t.is_inside_tree():
			continue
		var d := _distance_to_focus(t)
		if c == Vector2i.ZERO or d < activate_distance:
			t.activate()
		elif d > deactivate_distance:
			t.deactivate()


func _distance_to_focus(t: SandTile) -> float:
	var best := INF
	var h := TILE_SIZE * 0.5
	for p in focus_points:
		# Distance from the point to the tile's square (0 if inside).
		var dx := maxf(absf(p.x - t.origin.x) - h, 0.0)
		var dz := maxf(absf(p.z - t.origin.y) - h, 0.0)
		best = minf(best, Vector2(dx, dz).length())
	return best


func tile_at(x: float, z: float) -> SandTile:
	var c := Vector2i(roundi(x / TILE_SIZE), roundi(z / TILE_SIZE))
	var t: SandTile = tiles.get(c)
	if t == null or not t.data_ready:
		return null
	return t


## Make sure there's solid ground (collision) at a point right now.
## Teleports (rescue, tests) call this before moving the truck somewhere new.
func ensure_active_at(x: float, z: float) -> void:
	var c := Vector2i(roundi(x / TILE_SIZE), roundi(z / TILE_SIZE))
	if tiles.has(c):
		_finish_tile(c, true)
		tiles[c].activate()


func half_extent() -> float:
	return TILES_PER_SIDE * TILE_SIZE * 0.5


# ---------------------------------------------------------------------------
# The same questions the old single terrain answered
# ---------------------------------------------------------------------------

func get_height(x: float, z: float) -> float:
	var t := tile_at(x, z)
	return t.get_height(x, z) if t else 0.0


func get_hardness(x: float, z: float) -> float:
	var t := tile_at(x, z)
	return t.get_hardness(x, z) if t else 0.5


func get_crust(x: float, z: float) -> float:
	var t := tile_at(x, z)
	return t.get_crust(x, z) if t else 0.0


func get_sink(x: float, z: float) -> float:
	var t := tile_at(x, z)
	return t.get_sink(x, z) if t else 0.0


## 0 = Home Dunes, 1 = Salt Flats, 2 = Glass Desert, 3 = the Drift.
func ring_at(x: float, z: float) -> int:
	var d := maxf(absf(x), absf(z))
	if d > (SandTile.RING3_START + SandTile.RING3_END) * 0.5:
		return 3
	return 2 if d > (SandTile.RING2_START + SandTile.RING2_END) * 0.5 else (1 if d > 36.0 else 0)


## How strong gravity is here: 1 = normal, 0.4 deep in the Drift.
const DRIFT_GRAVITY := 0.4
func gravity_at(x: float, z: float) -> float:
	var d := maxf(absf(x), absf(z))
	return lerpf(1.0, DRIFT_GRAVITY, smoothstep(SandTile.RING3_START, SandTile.RING3_END, d))


## 0 = still sand, 1 = the middle of a sand river.
func get_flow(x: float, z: float) -> float:
	var t := tile_at(x, z)
	return t.get_flow(x, z) if t else 0.0


func get_flow_velocity(x: float, z: float) -> Vector3:
	var t := tile_at(x, z)
	return t.get_flow_velocity(x, z) if t else Vector3.ZERO


## 0 = no glass, ~0.5 = shard rubble, 1 = solid glass sheet.
func get_glass(x: float, z: float) -> float:
	var t := tile_at(x, z)
	return t.get_glass(x, z) if t else 0.0


## Press every active tile under the footprint, then make sure the edges
## two tiles share still match exactly (no cracks between tiles).
func press(center: Vector3, radius: float, amount: float, max_depth: float) -> void:
	var touched: Array[SandTile] = []
	for c in tiles:
		var t: SandTile = tiles[c]
		if t.active and t.contains(center.x, center.z, radius * 2.0):
			if t.press(center, radius, amount, max_depth).has_area():
				touched.append(t)
	if touched.size() > 1:
		_match_seams(touched)


## Salt crust breaks under a heavy wheel. Returns true if any broke.
func break_crust(center: Vector3, radius: float, drop_m: float) -> bool:
	var broke := false
	var touched: Array[SandTile] = []
	for c in tiles:
		var t: SandTile = tiles[c]
		if t.active and t.contains(center.x, center.z, radius):
			if t.break_crust(center, radius, drop_m):
				broke = true
				touched.append(t)
	if touched.size() > 1:
		_match_seams(touched)
	return broke


## Where two tiles meet, both have a copy of the same row of points. After
## pressing, average the two copies so the meshes line up perfectly.
func _match_seams(touched: Array[SandTile]) -> void:
	for a in touched:
		for b in touched:
			if a == b or a.coord > b.coord:
				continue
			var d := b.coord - a.coord
			var last := a.cells_per_side
			if d == Vector2i(1, 0):        # b is to the right of a
				for j in a.verts_per_side:
					_avg(a, a.idx(last, j), b, b.idx(0, j))
				a.touch(last - 1, 0, last, last)
				b.touch(0, 0, 1, last)
			elif d == Vector2i(0, 1):      # b is below a
				for i in a.verts_per_side:
					_avg(a, a.idx(i, last), b, b.idx(i, 0))
				a.touch(0, last - 1, last, last)
				b.touch(0, 0, last, 1)


func _avg(a: SandTile, ka: int, b: SandTile, kb: int) -> void:
	if a.heights[ka] != b.heights[kb]:
		var m := (a.heights[ka] + b.heights[kb]) * 0.5
		a.heights[ka] = m
		b.heights[kb] = m


## Shader settings go to every tile's copy of the material.
func set_shader_parameter(param: StringName, value: Variant) -> void:
	sand_material.set_shader_parameter(param, value)
	for c in tiles:
		tiles[c].material.set_shader_parameter(param, value)


func get_shader_parameter(param: StringName) -> Variant:
	return sand_material.get_shader_parameter(param)


func debug_stats() -> String:
	var sliding := 0
	var dirty := 0
	var active := 0
	for c in tiles:
		var t: SandTile = tiles[c]
		if t.active:
			active += 1
			var s := t.debug_stats()
			sliding += s.x
			dirty += s.y
	return "tiles_active=%d/%d sliding_chunks=%d dirty_chunks=%d" % [active, tiles.size(), sliding, dirty]


func _sum(prop: String) -> int:
	var total := 0
	for c in tiles:
		total += int(tiles[c].get(prop))
	return total


## Passes tyre-print stamps to whichever active tile(s) they land on.
class TrackRouter extends RefCounted:
	var world: SandTerrain

	func stamp(tex: Texture2D, world_pos: Vector3, forward: Vector3, size_m: Vector2, strength: float) -> void:
		var margin := maxf(size_m.x, size_m.y)
		for c in world.tiles:
			var t: SandTile = world.tiles[c]
			if t.active and t.tracks and t.contains(world_pos.x, world_pos.z, margin):
				t.tracks.stamp(tex, world_pos - Vector3(t.origin.x, 0, t.origin.y), forward, size_m, strength)

	func fade(amount: float) -> void:
		for c in world.tiles:
			var t: SandTile = world.tiles[c]
			if t.active and t.tracks:
				t.tracks.fade(amount)
