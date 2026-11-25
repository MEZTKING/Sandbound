class_name SandTile
extends StaticBody3D
## One 64 m x 64 m tile of deformable sand. The world (sand_terrain.gd) is a
## grid of these.
##
## The sand itself is a HEIGHTFIELD: a grid of points that each store a height.
##   * Wheels PRESS the sand down and push a little ridge up around them.
##   * Sand steeper than the "angle of repose" SLIDES downhill (settling).
##   * The grid is cut into CHUNKS, so digging only rebuilds nearby chunks.
##
## STREAMING and LEVEL OF DETAIL (new in milestone 5):
##   1. generate_data() makes the heights. It touches no nodes, so the world
##      runs it on a BACKGROUND THREAD: no stutter while tiles load.
##   2. A tile starts INACTIVE: just one cheap mesh at 1 m detail, no physics.
##   3. When you get close it's ACTIVATED: 0.25 m chunks, collision, and a
##      track map for tyre prints. Far away again, it's DEACTIVATED. The
##      heights are kept (your ruts stay), the expensive parts are freed.
##
## Units note: heights are stored in "cell units" (world height / cell_size),
## so the array can go straight to the physics engine's HeightMapShape3D.

const SAND_RENDER_LAYER := 2
## Drawn in 4 x 4 pieces of 64 x 64 cells (16 m): big enough to be cheap,
## small enough that pieces behind the camera aren't drawn.
const RENDER_CHUNK_CELLS := 64

@export var cells_per_side: int = 256      ## 256 x 0.25 m = 64 m.
@export var cell_size: float = 0.25
@export var chunk_cells: int = 16
@export var repose_slope: float = 0.7      ## Max rise/run before sand slides (~35 degrees).
@export var settle_passes: int = 2
@export var settle_epsilon: float = 0.001
@export var max_settle_chunks_per_tick: int = 24
@export var collision_updates_per_second: float = 30.0
@export var mesh_updates_per_second: float = 30.0

## Where this tile sits: its centre in world x/z, and its grid coordinate.
var origin := Vector2.ZERO
var coord := Vector2i.ZERO
var world_half := 96.0                     ## The world's edge (walls rise there).
var noise_seed := 1337
var flat_pads: Array[Vector3] = []
var mounds: Array[Vector3] = []
var track_resolution := 4096

var verts_per_side: int
var heights := PackedFloat32Array()        # current sand height, cell units
var original := PackedFloat32Array()       # before anything touched it
## 0 = soft dune sand, 1 = hardpan (firm flats between dunes).
var hardness := PackedFloat32Array()
## Salt crust strength (Ring 1): 0 = none, low = thin grey crust that cracks
## easily, 1 = thick white crust that only heavy trucks break.
var crust := PackedFloat32Array()
## Glass (Ring 2): 0 = none, ~0.5 = shard rubble (punctures tyres),
## 1 = a solid glass sheet (smooth, slippery, never dents).
var glass := PackedFloat32Array()
## Where to draw glass shards: (x, z, yaw) in world space, made with the data.
var shard_points := PackedVector3Array()
## Flowing sand (Ring 3): 0 = still, 1 = the middle of a sand river.
var flow := PackedFloat32Array()
## Which way each river point flows (an angle: 0 = +X, PI/2 = +Z).
var flow_dir := PackedFloat32Array()
var has_flow := false                      ## any river on this tile?
var _refill := Rect2i()                    ## river cells dug out, filling back in
## Ring 2 starts (fades in) between these distances from the centre.
const RING2_START := 86.0
const RING2_END := 100.0
## Ring 3, the Drift: low gravity and rivers of sand.
const RING3_START := 160.0
const RING3_END := 174.0
const FLOW_SPEED := 2.2                    ## m/s, the middle of a river
const REFILL_RATE := 1.6                   ## cell units per second a river fills a hole
const GLASS_SHEET := 0.75                  ## glass above this = a solid sheet

var active := false
var data_ready := false
var cancelled := false                    ## set by the world when quitting: stop generating
var cache_file := ""                       ## where to cache this tile ("" = don't)
var loaded_from_cache := false

## Bump this if you change generate_data() in a way the source fingerprint
## can't see (e.g. in an exported game, where the source isn't readable).
const GENERATOR_VERSION := 1
const CACHE_DIR := "user://tile_cache"
var material: ShaderMaterial              # this tile's own copy (its own track map)
var tracks: SandTracks                    # only while active

var _shape: HeightMapShape3D
var _collider: CollisionShape3D
var _far_mesh: MeshInstance3D
var _chunks: Array[MeshInstance3D] = []
var _chunks_per_side: int                 # settling chunks (16 cells)
var _heights_dirty := false               # heights changed: upload them to the GPU
var _collision_dirty := false
var _collision_timer := 0.0
var _mesh_timer := 0.0
var _awake_chunks := {}
# The sand's data, as textures the sand shader reads (see "Drawing" below).
var _height_tex: ImageTexture
var _original_tex: ImageTexture
var _surface_img: Image
var _surface_tex: ImageTexture
var _surface_dirty := false
var _flow_tex: ImageTexture
# Built on the generating thread, turned into textures on the main thread.
var _surface_bytes := PackedByteArray()
var _flow_floats := PackedFloat32Array()

var prof_press_us := 0
var prof_settle_us := 0
var prof_collision_us := 0
var prof_mesh_us := 0
var prof_mesh_rebuilds := 0


# ---------------------------------------------------------------------------
# Coordinates
# ---------------------------------------------------------------------------

func idx(i: int, j: int) -> int:
	return j * verts_per_side + i


## World position -> fractional grid coordinates in this tile.
func world_to_grid(p: Vector3) -> Vector2:
	var half := cells_per_side * 0.5
	return Vector2((p.x - origin.x) / cell_size + half, (p.z - origin.y) / cell_size + half)


func contains(x: float, z: float, margin := 0.0) -> bool:
	var h := cells_per_side * cell_size * 0.5 + margin
	return absf(x - origin.x) <= h and absf(z - origin.y) <= h


func get_height(x: float, z: float) -> float:
	var g := world_to_grid(Vector3(x, 0, z))
	var i := clampi(int(floor(g.x)), 0, cells_per_side - 1)
	var j := clampi(int(floor(g.y)), 0, cells_per_side - 1)
	var fx := clampf(g.x - i, 0.0, 1.0)
	var fz := clampf(g.y - j, 0.0, 1.0)
	var h := lerpf(lerpf(heights[idx(i, j)], heights[idx(i + 1, j)], fx),
			lerpf(heights[idx(i, j + 1)], heights[idx(i + 1, j + 1)], fx), fz)
	return h * cell_size


func _nearest(x: float, z: float) -> int:
	var g := world_to_grid(Vector3(x, 0, z))
	return idx(clampi(roundi(g.x), 0, cells_per_side), clampi(roundi(g.y), 0, cells_per_side))


func get_hardness(x: float, z: float) -> float:
	return hardness[_nearest(x, z)]


func get_crust(x: float, z: float) -> float:
	return crust[_nearest(x, z)]


func get_glass(x: float, z: float) -> float:
	return glass[_nearest(x, z)]


func get_flow(x: float, z: float) -> float:
	return flow[_nearest(x, z)]


## The velocity the sand is flowing at here (m/s, horizontal).
func get_flow_velocity(x: float, z: float) -> Vector3:
	var k := _nearest(x, z)
	if flow[k] <= 0.0:
		return Vector3.ZERO
	return Vector3(cos(flow_dir[k]), 0.0, sin(flow_dir[k])) * FLOW_SPEED * flow[k]


func get_sink(x: float, z: float) -> float:
	var k := _nearest(x, z)
	return maxf(original[k] - heights[k], 0.0) * cell_size


# ---------------------------------------------------------------------------
# Generation (runs on a background thread: no nodes touched in here!)
# ---------------------------------------------------------------------------

## A name for this world's tiles: changes whenever anything that shapes the
## sand changes (seed, pads, mounds, or this script's own source code), so
## an old cache is never used by mistake.
static func cache_key(seed: int, pads: Array[Vector3], mound_list: Array[Vector3]) -> String:
	var src := FileAccess.get_file_as_string("res://scripts/sand_tile.gd")
	return "v%d_%d_%x" % [GENERATOR_VERSION, seed, hash(str(pads) + str(mound_list) + src)]


func _cache_path() -> String:
	return CACHE_DIR + "/" + cache_file


## Load everything generate_data() makes from the cache. False = not cached.
func _load_cache() -> bool:
	if cache_file == "" or not FileAccess.file_exists(_cache_path()):
		return false
	var f := FileAccess.open_compressed(_cache_path(), FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return false
	var d = f.get_var()
	if typeof(d) != TYPE_DICTIONARY or not d.has("original"):
		return false
	original = d["original"]
	heights = original.duplicate()
	hardness = d["hardness"]
	crust = d["crust"]
	glass = d["glass"]
	flow = d["flow"]
	flow_dir = d["flow_dir"]
	shard_points = d["shards"]
	has_flow = d["has_flow"]
	_surface_bytes = d["surface"]
	_flow_floats = d["flow_floats"]
	return original.size() == verts_per_side * verts_per_side


func _save_cache() -> void:
	if cache_file == "" or cancelled:
		return
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	var f := FileAccess.open_compressed(_cache_path(), FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return
	f.store_var({"original": original, "hardness": hardness, "crust": crust, "glass": glass,
		"flow": flow, "flow_dir": flow_dir, "shards": shard_points, "has_flow": has_flow,
		"surface": _surface_bytes, "flow_floats": _flow_floats})


func generate_data() -> void:
	verts_per_side = cells_per_side + 1
	if _load_cache():
		loaded_from_cache = true
		data_ready = true
		return
	var dunes := FastNoiseLite.new()
	dunes.seed = noise_seed
	dunes.frequency = 0.035
	var detail := FastNoiseLite.new()
	detail.seed = noise_seed + 1
	detail.frequency = 0.12
	var firm := FastNoiseLite.new()
	firm.seed = noise_seed + 2
	firm.frequency = 0.05
	var salt_noise := FastNoiseLite.new()
	salt_noise.seed = noise_seed + 3
	salt_noise.frequency = 0.03
	var islands := FastNoiseLite.new()
	islands.seed = noise_seed + 4
	islands.frequency = 0.02
	var glass_noise := FastNoiseLite.new()
	glass_noise.seed = noise_seed + 5
	glass_noise.frequency = 0.035
	var river_noise := FastNoiseLite.new()
	river_noise.seed = noise_seed + 6
	river_noise.frequency = 0.011
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(coord) + noise_seed

	# Only the pads and mounds that can reach this tile. (Checking all ~30
	# pads at every one of the 66,000 points made generating 4x slower:
	# measured 0.77 s vs 0.19 s a tile. The cheapest optimisation is not
	# doing work you don't need.)
	var tile_half := cells_per_side * cell_size * 0.5
	var my_pads: Array[Vector3] = []
	for pad in flat_pads:
		var reach := pad.z + 8.0
		if absf(pad.x - origin.x) < tile_half + reach and absf(pad.y - origin.y) < tile_half + reach:
			my_pads.append(pad)
	var my_mounds: Array[Vector3] = []
	for m in mounds:
		if absf(m.x - origin.x) < tile_half + m.z and absf(m.y - origin.y) < tile_half + m.z:
			my_mounds.append(m)
	var n := verts_per_side * verts_per_side
	heights.resize(n)
	hardness.resize(n)
	crust.resize(n)
	glass.resize(n)
	flow.resize(n)
	flow_dir.resize(n)
	flow.fill(0.0)
	flow_dir.fill(0.0)
	has_flow = false
	shard_points.clear()
	var half := cells_per_side * cell_size * 0.5
	for j in verts_per_side:
		if cancelled:
			return
		for i in verts_per_side:
			# Everything is worked out from WORLD coordinates, so neighbouring
			# tiles agree exactly along their shared edge: no seams.
			var wx := origin.x + i * cell_size - half
			var wz := origin.y + j * cell_size - half
			# How far out we are decides which rings show here. Noise for a
			# ring that can't show is skipped: each noise call costs ~0.17 us,
			# 66,000 times a tile.
			var ring := maxf(absf(wx), absf(wz))
			var t := smoothstep(28.0, 42.0, ring)
			var t2 := smoothstep(RING2_START, RING2_END, ring)
			# --- Ring 0, the Home Dunes (their shapes are reused further out).
			var ridge := 1.0 - absf(dunes.get_noise_2d(wx, wz))
			var dune_h := ridge * ridge * 2.2 + detail.get_noise_2d(wx, wz) * 0.15
			var dune_hard := 0.0
			if t < 1.0:
				dune_hard = smoothstep(0.7, 0.2, dune_h) * smoothstep(-0.25, 0.2, firm.get_noise_2d(wx, wz))
			# --- Ring 1, the Salt Flats: low, flat, crusted, with a few sand islands.
			var island := 0.0
			var flat_h := 0.0
			var crust_v := 0.0
			if t > 0.0 and t2 < 1.0:
				island = smoothstep(0.35, 0.6, islands.get_noise_2d(wx, wz))
				flat_h = 0.35 + detail.get_noise_2d(wx * 0.5, wz * 0.5) * 0.12 + island * dune_h * 0.7
				var s := salt_noise.get_noise_2d(wx, wz)
				crust_v = (1.0 - island) * clampf(0.75 + s * 0.6, 0.15, 1.0)   # thin where s is low
			# --- Blend between the rings.
			var h := lerpf(dune_h, flat_h, t)
			var hard := lerpf(dune_hard, 0.85 * (1.0 - island) + 0.1, t)
			var c := crust_v * t
			# --- Ring 2, the Glass Desert: dark iron-rich sand in low dunes,
			# with flat sheets of glass where lightning melted it, and a rim
			# of broken shards around each sheet.
			var g := 0.0
			if t2 > 0.0:
				var gn := glass_noise.get_noise_2d(wx, wz)
				var sheet := smoothstep(0.24, 0.3, gn)
				var rubble := smoothstep(0.1, 0.17, gn) * (1.0 - sheet)
				var black_h := dune_h * 0.75 + 0.25
				h = lerpf(h, lerpf(black_h, 0.7, sheet), t2)
				hard = lerpf(hard, lerpf(0.3, 1.0, sheet), t2)
				c *= 1.0 - t2
				g = (sheet + rubble * 0.5) * t2
			# --- Ring 3, the Drift: tall smooth dunes (sand piles high when
			# it weighs less) cut by winding RIVERS of flowing sand. A river
			# runs where the river noise crosses zero; it flows ALONG that
			# line (at right angles to the way the noise changes).
			var t3 := smoothstep(RING3_START, RING3_END, ring)
			var f := 0.0
			var fdir := 0.0
			if t3 > 0.0:
				g *= 1.0 - t3
				var rn := river_noise.get_noise_2d(wx, wz)
				var drift_h := dune_h * 1.3 + 0.4
				f = (1.0 - smoothstep(0.02, 0.07, absf(rn))) * t3
				# The valley is wider than the flowing part, so its banks
				# are gentle enough to drive in and out of.
				var valley := 1.0 - smoothstep(0.02, 0.2, absf(rn))
				h = lerpf(h, lerpf(drift_h, 0.2, valley), t3)
				hard = lerpf(hard, 0.15 * (1.0 - f), t3)
				if f > 0.01:
					var gx := river_noise.get_noise_2d(wx + 0.5, wz) - river_noise.get_noise_2d(wx - 0.5, wz)
					var gz := river_noise.get_noise_2d(wx, wz + 0.5) - river_noise.get_noise_2d(wx, wz - 0.5)
					fdir = atan2(gx, -gz)     # along the river
					has_flow = true
			# Flatten pads (base, outposts, delivery points): packed hard, no crust.
			for pad in my_pads:
				# Cheap test first: well outside the pad's square, it can't affect us.
				if absf(wx - pad.x) > pad.z + 8.0 or absf(wz - pad.y) > pad.z + 8.0:
					continue
				var d := Vector2(wx - pad.x, wz - pad.y).length()
				var mask := 1.0 - smoothstep(pad.z, pad.z + 4.0, d)
				h = lerpf(h, lerpf(0.6, 0.4, t), mask)
				hard = maxf(hard, 1.0 - smoothstep(pad.z, pad.z + 1.5, d))
				c *= smoothstep(pad.z, pad.z + 2.0, d)
				g *= smoothstep(pad.z + 1.0, pad.z + 4.0, d)
				f *= smoothstep(pad.z + 2.0, pad.z + 8.0, d)
			# Ant nest mounds.
			for m in my_mounds:
				var d := Vector2(wx - m.x, wz - m.y).length() / m.z
				if d < 1.0:
					h += 0.1 * (1.0 - d * d) * (1.0 - d * d)
					hard *= d
			# Walls only at the very edge of the world.
			var edge := maxf(absf(wx), absf(wz))
			h += smoothstep(world_half - 10.0, world_half, edge) * 3.0
			heights[idx(i, j)] = h / cell_size
			hardness[idx(i, j)] = hard
			crust[idx(i, j)] = c
			glass[idx(i, j)] = g
			flow[idx(i, j)] = f
			flow_dir[idx(i, j)] = fdir
			# Shards: a few on every patch of rubble (every 3rd point, by luck).
			if g > 0.25 and g < GLASS_SHEET * 0.9 and i % 3 == 0 and j % 3 == 0 and rng.randf() < 0.45:
				shard_points.append(Vector3(wx + rng.randf_range(-0.3, 0.3), wz + rng.randf_range(-0.3, 0.3), rng.randf() * TAU))
	original = heights.duplicate()
	# Pack the per-point data for the GPU (still on the background thread).
	_surface_bytes.resize(n * 4)
	_flow_floats.resize(n * 2)
	for k in n:
		_surface_bytes[k * 4] = int(clampf(hardness[k], 0.0, 1.0) * 255.0)
		_surface_bytes[k * 4 + 1] = int(clampf(crust[k], 0.0, 1.0) * 255.0)
		_surface_bytes[k * 4 + 2] = int(clampf(glass[k], 0.0, 1.0) * 255.0)
		_surface_bytes[k * 4 + 3] = 255
		_flow_floats[k * 2] = cos(flow_dir[k]) * flow[k]
		_flow_floats[k * 2 + 1] = sin(flow_dir[k]) * flow[k]
	_save_cache()
	data_ready = true


# ---------------------------------------------------------------------------
# Inactive: one cheap far mesh. Active: chunks + collision + track map.
# ---------------------------------------------------------------------------

func _ready() -> void:
	position = Vector3(origin.x, 0, origin.y)
	set_physics_process(false)
	set_process(false)
	_chunks_per_side = cells_per_side / chunk_cells
	_make_textures()
	_build_far_mesh()
	_build_shards()


# ---------------------------------------------------------------------------
# Drawing: the GPU shapes the sand
# ---------------------------------------------------------------------------
#
# The sand is drawn with FLAT grid meshes. The heights live in a texture,
# one pixel per grid point, and the sand shader's vertex() function lifts
# each grid point to its height. When wheels dig, we don't rebuild any mesh:
# we copy the whole height array into the texture in one native call
# (Image.create_from_data) and the GPU does the rest.
#
# Before (milestone 7) every changed 4 m chunk rebuilt its mesh in GDScript:
# 0.58 ms each, up to 12 a frame while digging = 7 ms spikes. Now an update
# is one upload of 264 KB, whatever you dig.
#
# Textures (all 257 x 257, one pixel per grid point):
#   height_map    current heights (changes as you dig)
#   original_map  heights before anything touched them (for ruts and ridges)
#   surface_map   red = hardness, green = salt crust, blue = glass
#   flow_map      the sand rivers' flow (x, z)

func _make_textures() -> void:
	var size := verts_per_side
	_height_tex = ImageTexture.create_from_image(
			Image.create_from_data(size, size, false, Image.FORMAT_RF, heights.to_byte_array()))
	_original_tex = ImageTexture.create_from_image(
			Image.create_from_data(size, size, false, Image.FORMAT_RF, original.to_byte_array()))
	_surface_img = Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, _surface_bytes)
	_surface_tex = ImageTexture.create_from_image(_surface_img)
	_flow_tex = ImageTexture.create_from_image(
			Image.create_from_data(size, size, false, Image.FORMAT_RGF, _flow_floats.to_byte_array()))
	_surface_bytes = PackedByteArray()     # (the Image has its own copy now)
	_flow_floats = PackedFloat32Array()
	material.set_shader_parameter("height_map", _height_tex)
	material.set_shader_parameter("original_map", _original_tex)
	material.set_shader_parameter("surface_map", _surface_tex)
	material.set_shader_parameter("flow_map", _flow_tex)
	material.set_shader_parameter("tile_origin", origin)
	material.set_shader_parameter("cell_size", cell_size)
	material.set_shader_parameter("half_cells", cells_per_side * 0.5)


## A flat grid: (n x n) squares, `step` cells each, starting at (x0, z0).
## Every tile shares the same few grids (they're identical), see _grid().
static var _grids := {}
func _grid(cells: int, step: int) -> ArrayMesh:
	var key := Vector2i(cells, step)
	if _grids.has(key):
		return _grids[key]
	var n := cells / step + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	verts.resize(n * n)
	norms.resize(n * n)
	for b in n:
		for a in n:
			verts[b * n + a] = Vector3(a * step * cell_size, 0.0, b * step * cell_size)
			norms[b * n + a] = Vector3.UP
	var index := PackedInt32Array()
	for b in n - 1:
		for a in n - 1:
			var v := b * n + a
			index.append_array([v, v + 1, v + n, v + 1, v + n + 1, v + n])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_grids[key] = mesh
	return mesh


## The grid is flat, so Godot would think it's paper-thin and skip drawing it
## when the flat version is out of view. Tell it how tall the sand can get.
func _sand_aabb(size_m: float) -> AABB:
	return AABB(Vector3(0, -3.0, 0), Vector3(size_m, 14.0, size_m))


## Low detail (far away): one grid of 1 m squares over the whole tile.
func _build_far_mesh() -> void:
	_far_mesh = MeshInstance3D.new()
	_far_mesh.mesh = _grid(cells_per_side, 4)
	_far_mesh.material_override = material
	_far_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_far_mesh.layers = 1 | SAND_RENDER_LAYER
	var half := cells_per_side * cell_size * 0.5
	_far_mesh.position = Vector3(-half, 0, -half)
	_far_mesh.custom_aabb = _sand_aabb(cells_per_side * cell_size)
	_far_mesh.set_instance_shader_parameter("lod_step", 4.0)
	add_child(_far_mesh)


## Glass shards on the rubble: one MultiMesh per tile (one draw call).
func _build_shards() -> void:
	if shard_points.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Models.mesh("shards")
	mm.instance_count = shard_points.size()
	for n in shard_points.size():
		var p := shard_points[n]
		var y := get_height(p.x, p.y) - 0.02
		var s := 0.7 + fposmod(p.z * 7.3, 0.6)
		mm.set_instance_transform(n, Transform3D(Basis(Vector3.UP, p.z).scaled(Vector3.ONE * s),
				Vector3(p.x - origin.x, y, p.y - origin.y)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Models.glass_material()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 70.0      # tiny things: don't draw them far away
	add_child(mmi)


func activate() -> void:
	if active or not data_ready:
		return
	active = true
	# Collision first: physics must never find a hole.
	_shape = HeightMapShape3D.new()
	_shape.map_width = verts_per_side
	_shape.map_depth = verts_per_side
	_shape.map_data = heights
	_collider = CollisionShape3D.new()
	_collider.shape = _shape
	_collider.scale = Vector3.ONE * cell_size   # heights are in cell units
	add_child(_collider)
	var pm := PhysicsMaterial.new()
	pm.friction = 1.0
	physics_material_override = pm
	tracks = SandTracks.new()
	add_child(tracks)
	tracks.setup(cells_per_side * cell_size, track_resolution)
	material.set_shader_parameter("track_map", tracks.get_texture())
	material.set_shader_parameter("track_map_size_m", cells_per_side * cell_size)
	material.set_shader_parameter("track_map_origin", origin)
	# Full detail: 4 x 4 pieces of 0.25 m squares (all sharing one grid mesh).
	var per := cells_per_side / RENDER_CHUNK_CELLS
	var piece_m := RENDER_CHUNK_CELLS * cell_size
	var half := cells_per_side * cell_size * 0.5
	for cz in per:
		for cx in per:
			var mi := MeshInstance3D.new()
			mi.mesh = _grid(RENDER_CHUNK_CELLS, 1)
			mi.material_override = material
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.layers = 1 | SAND_RENDER_LAYER
			mi.position = Vector3(cx * piece_m - half, 0, cz * piece_m - half)
			mi.custom_aabb = _sand_aabb(piece_m)
			mi.set_instance_shader_parameter("lod_step", 1.0)
			add_child(mi)
			_chunks.append(mi)
	_far_mesh.visible = false
	set_physics_process(true)
	set_process(true)


func deactivate() -> void:
	if not active:
		return
	active = false
	set_physics_process(false)
	set_process(false)
	for c in _chunks:
		c.queue_free()
	_chunks.clear()
	_awake_chunks.clear()
	_collider.queue_free()
	_collider = null
	_shape = null
	tracks.queue_free()
	tracks = null
	material.set_shader_parameter("track_map", null)
	_upload()                  # the far view keeps your ruts
	_far_mesh.visible = true


func is_fully_built() -> bool:
	return active


# ---------------------------------------------------------------------------
# Per-frame work (only while active)
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_settle()
	if _refill.size != Vector2i.ZERO:
		_refill_rivers(delta)
	var t1 := Time.get_ticks_usec()
	prof_settle_us += t1 - t0
	_collision_timer += delta
	if _collision_dirty and _collision_timer >= 1.0 / collision_updates_per_second:
		_shape.map_data = heights
		_collision_dirty = false
		_collision_timer = 0.0
		prof_collision_us += Time.get_ticks_usec() - t1


func _process(delta: float) -> void:
	_mesh_timer += delta
	if _mesh_timer < 1.0 / mesh_updates_per_second:
		return
	_mesh_timer = 0.0
	_upload()


## Send changed sand data to the GPU.
func _upload() -> void:
	var t0 := Time.get_ticks_usec()
	if _heights_dirty:
		_heights_dirty = false
		_height_tex.update(Image.create_from_data(verts_per_side, verts_per_side, false,
				Image.FORMAT_RF, heights.to_byte_array()))
		prof_mesh_rebuilds += 1
	if _surface_dirty:
		_surface_dirty = false
		_surface_tex.update(_surface_img)
	prof_mesh_us += Time.get_ticks_usec() - t0


func _mark_dirty(_i0: int, _j0: int, _i1: int, _j1: int) -> void:
	_heights_dirty = true
	_collision_dirty = true


## Mark a grid rectangle changed (the world calls this after fixing seams).
func touch(i0: int, j0: int, i1: int, j1: int) -> void:
	if active:
		_mark_dirty(i0, j0, i1, j1)
	else:
		_heights_dirty = true
		_upload()


# ---------------------------------------------------------------------------
# Deformation
# ---------------------------------------------------------------------------

## Press the sand down in a circle (a wheel footprint), piling the pushed-away
## sand in a ring around it. Returns the grid rectangle it touched (or an
## empty Rect2i).
func press(center: Vector3, radius: float, amount: float, max_depth: float) -> Rect2i:
	var t0 := Time.get_ticks_usec()
	var g := world_to_grid(center)
	var r := radius / cell_size
	var ring := r * 1.9
	var push := amount / cell_size
	var depth := max_depth / cell_size
	# The full grid, edges included: neighbouring tiles press their copy of
	# the shared edge too, and the world keeps the two copies matched.
	var i0 := clampi(int(floor(g.x - ring)), 0, cells_per_side)
	var i1 := clampi(int(ceil(g.x + ring)), 0, cells_per_side)
	var j0 := clampi(int(floor(g.y - ring)), 0, cells_per_side)
	var j1 := clampi(int(ceil(g.y + ring)), 0, cells_per_side)
	var removed := 0.0
	var ring_weight := 0.0
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var d := Vector2(i - g.x, j - g.y).length()
			if d < r:
				var w := 1.0 - (d / r) * (d / r)
				var k := idx(i, j)
				if glass[k] > GLASS_SHEET:
					continue   # solid glass: no dent
				var floor_h := original[k] - depth * w
				var new_h := maxf(heights[k] - push * w, floor_h)
				if new_h < heights[k]:
					removed += heights[k] - new_h
					heights[k] = new_h
			elif d < ring:
				ring_weight += 1.0 - absf((d - r) / (ring - r) * 2.0 - 1.0)
	if removed > 0.0 and ring_weight > 0.0:
		var share := removed * 0.6 / ring_weight
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var d := Vector2(i - g.x, j - g.y).length()
				if d >= r and d < ring:
					heights[idx(i, j)] += share * (1.0 - absf((d - r) / (ring - r) * 2.0 - 1.0))
	prof_press_us += Time.get_ticks_usec() - t0
	if removed <= 0.0:
		return Rect2i()
	_mark_dirty(i0, j0, i1, j1)
	_queue_settle(i0, j0, i1, j1)
	var touched := Rect2i(i0, j0, i1 - i0, j1 - j0)
	if has_flow and flow[idx(clampi(int(g.x), 0, cells_per_side), clampi(int(g.y), 0, cells_per_side))] > 0.05:
		_refill = touched if _refill.size == Vector2i.ZERO else _refill.merge(touched)
	return touched


## Break the salt crust in a circle: the crust is gone, the wheel drops
## into the soft sand underneath. Returns true if there was crust to break.
func break_crust(center: Vector3, radius: float, drop_m: float) -> bool:
	var g := world_to_grid(center)
	var r := radius / cell_size
	var i0 := clampi(int(floor(g.x - r)), 0, cells_per_side)
	var i1 := clampi(int(ceil(g.x + r)), 0, cells_per_side)
	var j0 := clampi(int(floor(g.y - r)), 0, cells_per_side)
	var j1 := clampi(int(ceil(g.y + r)), 0, cells_per_side)
	var broke := false
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var d := Vector2(i - g.x, j - g.y).length()
			var k := idx(i, j)
			if d < r and crust[k] > 0.02:
				var w := 1.0 - d / r
				crust[k] = 0.0
				hardness[k] = minf(hardness[k], 0.1)
				_surface_img.set_pixel(i, j, Color(hardness[k], 0.0, glass[k], 1.0))
				_surface_dirty = true
				heights[k] -= drop_m / cell_size * w
				broke = true
	if broke:
		_mark_dirty(i0, j0, i1, j1)
		_queue_settle(i0, j0, i1, j1)
	return broke


# ---------------------------------------------------------------------------
# Settling: sand that is too steep slides downhill (only "awake" chunks).
# ---------------------------------------------------------------------------

func _queue_settle(i0: int, j0: int, i1: int, j1: int) -> void:
	if not active:
		return
	var c0x := clampi((i0 - 1) / chunk_cells, 0, _chunks_per_side - 1)
	var c0z := clampi((j0 - 1) / chunk_cells, 0, _chunks_per_side - 1)
	var c1x := clampi((i1 + 1) / chunk_cells, 0, _chunks_per_side - 1)
	var c1z := clampi((j1 + 1) / chunk_cells, 0, _chunks_per_side - 1)
	for cz in range(c0z, c1z + 1):
		for cx in range(c0x, c1x + 1):
			_awake_chunks[cz * _chunks_per_side + cx] = true


func _settle() -> void:
	if _awake_chunks.is_empty():
		return
	var keys := _awake_chunks.keys()
	_awake_chunks.clear()
	var budget := max_settle_chunks_per_tick
	for key in keys:
		if budget <= 0:
			_awake_chunks[key] = true
			continue
		budget -= 1
		_settle_chunk(key % _chunks_per_side, key / _chunks_per_side)


func _settle_chunk(cx: int, cz: int) -> void:
	var i0 := maxi(cx * chunk_cells, 1)
	var j0 := maxi(cz * chunk_cells, 1)
	var i1 := mini(cx * chunk_cells + chunk_cells - 1, cells_per_side - 1)
	var j1 := mini(cz * chunk_cells + chunk_cells - 1, cells_per_side - 1)
	var max_diff := repose_slope
	var eps := settle_epsilon / cell_size
	var vps := verts_per_side
	var moved_min := Vector2i(1 << 30, 1 << 30)
	var moved_max := Vector2i(-1, -1)
	for _pass in settle_passes:
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var k := j * vps + i
				# Right and down neighbour, written out twice: the hottest loop.
				var n := k + 1
				var diff := heights[k] - heights[n]
				var excess := absf(diff) - max_diff
				if excess > eps:
					var m := excess * 0.4 * signf(diff)
					heights[k] -= m
					heights[n] += m
					moved_min = moved_min.min(Vector2i(i, j))
					moved_max = moved_max.max(Vector2i(i + 1, j))
				n = k + vps
				diff = heights[k] - heights[n]
				excess = absf(diff) - max_diff
				if excess > eps:
					var m := excess * 0.4 * signf(diff)
					heights[k] -= m
					heights[n] += m
					moved_min = moved_min.min(Vector2i(i, j))
					moved_max = moved_max.max(Vector2i(i, j + 1))
	if moved_max.x < 0:
		return
	_mark_dirty(moved_min.x, moved_min.y, moved_max.x, moved_max.y)
	_queue_settle(moved_min.x, moved_min.y, moved_max.x, moved_max.y)


## Rivers flow: holes and ruts dug in them fill back in (and ridges wash
## away), back to the river's own level. Only the dug-out rectangle is checked.
func _refill_rivers(delta: float) -> void:
	var step := REFILL_RATE * delta
	var busy := false
	for j in range(_refill.position.y, _refill.end.y + 1):
		for i in range(_refill.position.x, _refill.end.x + 1):
			var k := idx(i, j)
			var fl := flow[k]
			if fl < 0.05:
				continue
			var diff := original[k] - heights[k]
			if absf(diff) > 0.002:
				heights[k] += clampf(diff, -step * fl, step * fl)
				busy = true
	_mark_dirty(_refill.position.x, _refill.position.y, _refill.end.x, _refill.end.y)
	if not busy:
		_refill = Rect2i()


func debug_stats() -> Vector2i:
	return Vector2i(_awake_chunks.size(), 1 if _heights_dirty else 0)
