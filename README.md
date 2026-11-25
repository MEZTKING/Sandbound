# Sand Rover: prototype 5 ("Ring 1 and outposts")

A tiny RC truck on deformable sand. Pick a delivery contract at base, fit
your truck with parts, haul the cargo across soft dunes and firm hardpan,
dodge dung beetles, don't leave your cargo near an ant nest, get paid,
come home, upgrade, repeat.

- **Milestone 1, "Sand feel"** (done): *is driving on sand fun by itself?*
- **Milestone 2, "The loop"** (done): *do I want "one more run"?*
- **Milestone 3, "Building"** (done): *do different builds solve problems differently?*
- **Milestone 4, "Ring 0 complete"** (done): *is the first hour good enough to show strangers?*
- **Milestone 5, "Ring 1 and outposts"** (this version): *does weirder feel exciting, not just harder?*

## Run it

1. Download **Godot 4.7** (the standard version, not .NET): https://godotengine.org/download
2. Open Godot, click **Import**, select this folder's `project.godot`.
3. Press **F5** (or the play button at the top right).

| Key | Action |
|---|---|
| W / S (or arrows) | Drive forward / reverse |
| A / D | Steer |
| Space | Brake |
| R | Flip the truck upright |
| E | Load a dropped crate back on (park next to it first) |
| C | Ask the crew for a replacement cargo ($10) |
| B | Base menu: contracts and garage (only at base) |
| N | Workshop: build onto your truck (only at base) |
| F | Winch: fire the sand anchor / let go (if you built one) |
| P | Fit a spare wheel over a flat tyre (if you built one) |
| F1 | Controls (also on the title screen) |
| M | Map |
| Enter | Start (title screen) |
| H | Rescue: the crew tows you home ($25) |
| F3 | Show/hide performance stats |
| G | Graphics: high (all effects) / low |
| T | Tilt-shift blur on/off (the "miniature world" look) |
| V | Toggle V-Sync (off = see your real maximum FPS) |

**The loop:**

1. **At base, pick a contract** (keys 1-3 or click): a cargo, a destination
   (lettered A-F, floating letters show where) and the pay. Longer trips and
   trickier cargo pay more. Trickier cargo unlocks as you deliver:

   | Cargo | What's tricky |
   |---|---|
   | Crate | Nothing. Don't drop it. |
   | Water barrel | Tough but round: if it tips over, it rolls away. |
   | Egg crate | 3x as fragile. Every bump costs you. |
   | Engine block | 22 kg: your truck sinks and struggles. |
   | Ice block | Melts ~1% a second and slides around like crazy. |

2. **Fit parts in the garage** (click to buy, click again later to swap; the
   crew runs out and bolts them on). Every part solves one problem and costs
   you something:

   | Slot | Options |
   |---|---|
   | Tyres | Standard / **Balloon** (float on soft sand, slidy, pop easily) / **Paddle** (huge grip, dig holes if spun) / **Solid** (shards can't puncture them; heavy, sink, less grip) |
   | Motor | Standard / **Torque** (climbs, slow, thirsty) / **Sprint** (fast on firm ground, bogs in soft sand) |
   | Battery | Standard / **Big** (≈2x range, heavy) / **Solar** (recharges while you drive) |
   | Cargo bed | Flat / **Tall walls** / **Cage** (nothing falls out, heavy) |

3. **Drive it there** and let it settle inside the glowing ring. Pay drops
   with the cargo's condition.
4. **Come home** to recharge (the base charges your battery) and pick the next job.

**Build onto your truck (N at base).** The truck has 19 sockets: 3 on each
side, 3 front, 3 back, 2 on the cab roof, 4 underneath, and one over the bed.
Click a socket to bolt on the selected part, right-click to take it off (it
goes back in your parts box). Green markers show where the part fits; the
red ball is the centre of mass.

| Part | $ | What it does | The catch |
|---|---|---|---|
| Ballast weight | 15 | 12 kg of iron | Low = stable, one side = you lean, high = top-heavy |
| Bumper | 25 | Beetle rams on that side hit 35% softer (2 = 70%) | Weight |
| Battery cell | 35 | +45% range | 6 kg, wherever you put it |
| Solar tile | 40 | Trickle-charges the battery (roof only) | Tiny |
| Winch + sand anchor | 70 | **F** fires an anchor 8 m into the sand and reels you in | Drains battery fast while reeling |
| Cargo net | 45 | Straps cargo down with a real joint | Snaps in a hard crash |
| Hitch + trailer | 120 | Cargo rides on a trailer, low and safe | It drags in soft sand: top speed 6.5 to 4.4 m/s |
| Headlight | 20 | Lights up at dusk | A little battery |
| Buzzer | 40 | Zaps clamped scorpions off | 1.5 kg of metal |
| Sandbag | 8 | 10 kg ballast with **no metal** | Bulky |
| Spare wheel | 30 | **P** swaps a flat tyre (restocked at any base) | 4 kg, back or roof |
| Gyro stabiliser | 90 | Pushes the truck back upright (rights you from your side in the Drift) | 5 kg, uses battery while working |
| Downforce wing | 50 | Pushes down harder the faster you go: grip at speed | A little drag |

Measured by `--buildtest`: ballast all down the left leans the truck 4.3°;
two bumpers halve a beetle's shove (3.5 to 1.7 m/s); after spinning in
place for 2.5 s a truck moved 3.2 m on throttle alone and 26 m with the
winch (since the milestone 4 driving fixes the wheels dig in less); a hard shove threw the cargo
off without a net and not with one; the trailer joint never slipped more than
1 cm through turns.

**Builds are files.** Save 1-3 / Load 1-3 in the workshop write small JSON
files ("Open builds folder" shows them). Send one to a friend, they drop it
in their builds folder and load it: any parts they don't own are bought.

**The Drift (milestone 7):**

- **The world is 448 m across** (7 x 7 tiles). Past the Glass Desert lies
  **Ring 3, the Drift**: tall pale-lilac dunes where things weigh **40%** of
  normal. Measured: a 2 m drop takes 0.87 s instead of 0.55 s. Low gravity
  means less grip, long jumps and easy flips, and cargo floats off the bed
  on bumps unless it's netted or caged.
- **Sand rivers** wind through it, and they **flow like water** (2.2 m/s,
  you can see the ripples moving). Anything in one is carried downstream: a
  dropped crate drifts ~3 m in 5 s, a parked truck about 1 m. Slow wheels
  sink (20 cm), fast ones skim (6 cm). Rivers also refill: a hole dug in one
  is gone in 2 seconds; tracks wash away.
- **Drift rays** swim in the rivers with only a fin showing. Wade in slowly
  and one comes for you, slides under the truck and **flips up**: in this
  gravity you land on your roof. Cross rivers faster than **3 m/s** and they
  can't catch you.
- **New parts:** the **Gyro stabiliser** (roof or underneath) turns the truck
  back upright: tipped onto its side in the Drift, it's back on its wheels in
  under 5 s every time; without one it's luck (in testing it stayed on its
  side in one run and rocked back in another). The **Downforce wing** (roof or back)
  pushes down at speed: weaving at full throttle in the Drift, two wings more
  than double the time all four wheels touch the ground (9% to 21%).
- **The Signal Orb:** a new cargo, light (1.5 kg) and round. It rolls and,
  in low gravity, bounces.
- **Drift Station**, the third outpost (story job 23 hauls its kit from the
  Glass Outpost): the best pay (+150%), orbs on the board, and fast travel.
- **The hull** is half-buried by point R, lights blinking: you can drive up
  to it now.
- **Six final story jobs**, ending with "Homecoming": carry an orb from the
  Drift all the way back to the Home Dunes, through every ring.

**The Glass Desert (milestone 6):**

- **A bigger world again:** 320 m across (5 x 5 tiles). Outside the Salt
  Flats is **Ring 2, the Glass Desert**: dark, iron-rich sand, and big flat
  **glass sheets** where lightning melted it.
- **Glass is slippery.** Tyres keep only ~12% of their grip on it (balloon
  tyres a bit more, paddles less). It's flat and fast, but brake early:
  measured, a truck at 4 m/s slides 1.6 m on glass vs 0.6 m on sand. Glass
  never dents and takes no tyre tracks.
- **Shards.** The sparkly rubble around every sheet **punctures tyres** if
  you drive over it fast. Creep across (under ~1 m/s) and you're fine, or
  fit **Solid tyres**. A flat drops that corner, grips and drags badly.
  Build a **Spare wheel** and press **P**, or limp to any base: the crew
  patches flats ($5 each) and restocks your spares.
- **Lodestones**, the big black rocks with purple veins, **pull on metal**.
  The truck's frame and motor are ~18 kg of metal; iron **ballast** adds 12
  kg each, winch/hitch/buzzer a little. The engine block cargo is 22 kg of
  iron. Measured driving past at 6 m: a plain truck drifts 14 cm towards it,
  one with three iron ballasts 43 cm. Get within ~2.5 m with lots of iron
  and you're **stuck to the rock** (winch out!). New **Sandbags** are ballast
  with no metal. The HUD shows your metal and the pull on you.
- **Magnet storms** roll through every couple of minutes (a purple haze):
  for 25 seconds the lodestones pull ~2-3x harder, in surges.
- **The Glass Outpost:** story job 17 sends a second **Outpost Kit** from
  the Salt Flats outpost to the site in the Glass Desert. Built, it has the
  best-paying board (+90%), and...
- **Fast travel:** at any base, the menu shows **Travel** buttons to your
  other built bases ($15, the crew shuttle). Not while you have a job.
- **Six more story jobs**, out to the edge of the world at point R.
- **Every build part is a real model now** (winch, bumpers, battery cells,
  solar tiles, headlights, buzzers, hitch, sandbags, spare wheel), and all
  models got the **material upgrade** described under "Making the models look
  professional".

**The Salt Flats (milestone 5):**

- **A bigger world:** 192 m across. Your Home Dunes in the middle, the
  **Salt Flats** all around them. Press **M** for the map.
- **Salt crust** is firm and fast, but it **cracks under weight**: your
  wheels drop into the soft sand underneath. Thick **white** crust holds a
  normal truck, even with the engine block on board. Thin **grey** crust
  breaks under almost anything. Speed helps a little (less time on each spot),
  heavy builds and heavy cargo make it worse. Read the colours!
- **Scorpions** hide under the crust near the routes. Drive close and one
  darts out and **clamps a wheel**, locking it (you slew and crawl). Floor it
  for ~2 seconds to shake it off, or build a **Buzzer** (new part, sides /
  front / back): it zaps them off in under a second.
- **The outpost:** after "The Signal", story job 11 asks you to haul an
  **Outpost Kit** (14 kg: watch the grey crust) to the site north of base.
  Deliver it and the crew builds the **Salt Flats Outpost**: charging, its own
  contract board (Salt Flats jobs, +40% pay), the workshop, and the nearest
  rescue point when you're out there.
- **Five more story jobs** from the outpost, ending at the edge of the flats
  where the sand has turned to glass.

**Ring 0 comes alive (milestone 4):**

- **Day and night.** A full day lasts 8 minutes (the clock is on the HUD).
  Dusk turns the sky orange, night is dark blue under a dim moon. Solar only
  charges in daylight. **Headlights** (a new build part, front or roof)
  switch on by themselves at dusk and use a little battery. The base lamp
  guides you home. At base you can wait until morning or night.
- **The hawk** hunts by day from a dead tree at the edge of the map. Leave
  cargo unsecured and it circles overhead (a screech, a message), dives
  (watch for its shadow), grabs it and flies off, then drops it from about
  2 m somewhere in the dunes. That costs condition, and maybe it lands next
  to an ant nest. It can't take cargo strapped down with the **net**, cargo
  in the **cage**, or anything over 8.5 kg (the barrel and the engine).
- **Wind gusts** every minute or so: sand streams past, the haze thickens,
  the truck gets shoved sideways (about a metre while driving), and your
  tyre tracks slowly smooth away.
- **The story:** ten handmade contracts (in gold on the board) from Old Pip,
  Cook Maru, Lune and the Dig Team. Some have twists: a **deadline** (late =
  half pay and try again), a **minimum condition** (below it the client
  refuses), or **night only**. The tenth one ends Ring 0 and points at the
  Salt Flats.
- **Sound** for everything: engine, sand crunch, wind, winch, thuds,
  beetles, the hawk, the crew cheering when you come home, and delivery chimes.
- **A title screen and F1 help** instead of a wall of controls on the HUD.
  Performance stats moved to F3.

**Driving feel fixes from playtesting:** the throttle now eases in like an
RC trigger (full power from a standstill used to dig a 20-30 cm hole every
time you set off, which is how a truck got stuck on the first hill). Wheels
only count as "spinning in place" after half a second of going nowhere. The
motor drag-brakes when you let off, so a parked truck doesn't roll away. And
beetles leave you alone within 14 m of base.

**Read the ground.** Soft dune sand (crests and slopes) swallows wheels and
slows you down. **Hardpan**, the pale cracked crust in the flats between dunes,
is firm and fast. The HUD shows which you're on. Routes through the flats are
longer but quicker.

**The battery** drains with throttle. Flat = 15% power, a slow crawl home. Or
press **H** and pay $25 to be towed.

**Things to try:** floor it from a standstill on a dune (the wheels dig in and
you get stuck; rock back and forth to escape). Drive the same path twice (your
ruts get darker and deeper). Take a dune crest fast (watch the crate).

**Drop the crate** and it's a real problem, not a reset. It punches a dent
into the sand and throws up dust. Hard knocks damage it: its band turns from
blue to red, and a damaged crate pays less (a 2 m fall = about 63%). At 0%
it's smashed and you go back to base for another. An orange marker shows
where it is: drive next to it, stop, and press **E** to load it back. You can
also shove it into the delivery ring with the truck. That counts too.

**Ants** live in three nests (the little mounds with a hole). Leave cargo
lying in the sand within 12 m of a nest for 4 seconds and a column of ants
marches out, surrounds it and hauls it home. If it reaches the nest, it's
gone and the contract fails. Drive up close and they scatter for a few
seconds: that's your chance to park and press **E**.

**Dung beetles** live in three spots in the dunes. When you come within 10 m
one turns to face you, **rears up** (that's your warning), then charges in a
straight line. Steer out of the way, or it shoves you sideways and spills
your crate. They leave you alone near base.

## How the code is laid out

| File | What it does | Read it to learn |
|---|---|---|
| `scripts/main.gd` | Builds the world, delivery loop, camera, HUD | Godot basics: nodes, `_ready`, `_process`, input |
| `scripts/sand_terrain.gd` | **The sand.** Height grid, pressing, sliding, chunked meshes | Heightfields, procedural meshes, optimisation |
| `scripts/rc_car.gd` | The truck, and how wheels dig and get stuck | Vehicle physics, forces |
| `scripts/cargo.gd` | Every cargo type: condition, impacts, melting | Rigid bodies, detecting collisions, data tables |
| `scripts/parts.gd` | Every garage part and its stats | **Data-driven design**: add a part = add an entry |
| `scripts/contracts.gd` | Makes delivery jobs and prices them | Random generation with rules |
| `scripts/base_menu.gd` | The base menu (contracts + garage) | UI built from Control nodes, signals |
| `scripts/ant_colony.gd` | Ant nests that steal cargo | A state machine for a whole swarm, MultiMesh |
| `scripts/build_parts.gd` | Sockets on the truck + buildable parts | Data tables, building a rotation from a direction |
| `scripts/workshop.gd` | Build mode: orbit camera, socket picking, build files | Mouse picking (`unproject_position`), JSON files |
| `scripts/trailer.gd` | The trailer and its hitch **joint** | `Generic6DOFJoint3D`, joint limits |
| `scripts/day_night.gd` | Sun, moon, sky colours, light levels | Driving many things from one number |
| `scripts/weather.gd` | Wind gusts | Forces, particles, smoothing a value over time |
| `scripts/hawk.gd` | The hawk | A flying state machine without physics (code steering) |
| `scripts/story.gd` | The 10 story contracts | Writing content as data: edit the words freely |
| `scripts/sfx.gd` | Plays sounds, 3D and 2D | AudioStreamPlayer3D, pooling, loops |
| `scripts/screens.gd` | Title and help screens | Simple UI |
| `scripts/sand_tile.gd` | One 64 m tile of sand (what `sand_terrain.gd` used to be) | Background threads, level of detail |
| `scripts/sand_terrain.gd` | The whole world: tiles streamed around you | Streaming, hysteresis, keeping seams matched |
| `scripts/scorpion.gd` | Scorpions | Another state machine; pinning one wheel |
| `scripts/drift_ray.gd` | Drift rays | A state machine that only lives in rivers; off-centre impulses |
| `scripts/map_overlay.gd` | The M map, painted from the terrain | Images from code, drawing UI |
| `scripts/models.gd` | Loads the Blender models, swaps in the palette | glTF import, materials |
| `tools/blender/make_models.py` | **Builds every model in Blender** | Blender Python (bpy) |
| `models/*.glb` + `models/source/*.blend` | The models, and the Blender file to edit | |
| `textures/models/palette.png` | **The colour palette every model uses** | Paint it! |
| `textures/models/palette_material.png` | Roughness / metal / glow for each palette square | PBR materials |
| `shaders/model.gdshader` | How every model is drawn: palette, shine, corner shading, dust | Shaders, PBR, triplanar mapping |
| `sounds/*.wav` | **Placeholder sounds: replace them with yours** | Same file name = the game uses yours |
| `scripts/sand_tracks.gd` | Fine tyre tracks drawn on the GPU | SubViewports, render targets |
| `scripts/sand_dust.gd` | Wheel spray and dust bursts | GPU particles |
| `scripts/dung_beetle.gd` | The first enemy | **State machines** (how all game AI starts), impulses |
| `scripts/crew_crowd.gd` | 300 crew in one draw call, animated on the GPU | MultiMesh, shaders |
| `scripts/tiny_figure.gd` | One little person from simple shapes | Building meshes in code |
| `shaders/sand.gdshader` | How the sand is drawn from your textures | Shaders, world-space UVs, height to bumps |
| `materials/sand_material.tres` | The sand's textures and sliders | Double-click it in Godot to tweak |
| `textures/sand/*.png` | **Your hand-painted sand textures** | See "Painting the sand textures" |
| `tools/sand_preview.tscn` | Live preview of the sand while you paint | `@tool` scripts that run in the editor |
| `tools/beauty_shots.tscn` | Six fixed camera shots saved as PNGs (F6) | Comparing art changes |
| `tools/_bench.gd`, `tools/_bench_world.gd` | Timings for the sand and for making the world | Measure before you optimise |

Start with `main.gd`, then `rc_car.gd`, then `sand_terrain.gd`. The comments
explain the *why*, not just the *what*.

## How the sand works (in 4 lines)

1. The ground is a grid of heights, 257 x 257 points, 25 cm apart. Each
   point also stores a **hardness** (0 = soft dune sand, 1 = hardpan), which
   changes how much wheels sink, dig, grip and drag.
2. Each physics tick, every wheel touching the sand **presses** a circle down
   and piles ~60% of that sand into a ridge around it. Spinning wheels press
   much faster and deeper: that's digging.
3. Anywhere sand is steeper than ~35 degrees, it **slides** to its neighbours
   until it's stable. Only "awake" chunks (where something just happened)
   are checked; a chunk where nothing moved goes to sleep.
4. On top of that, a **track map** (a 4096 x 4096 image, 1.6 cm per pixel)
   holds the fine detail: tyre tread prints, beetle feet, crate dents. It
   lives only on the graphics card. Wheels "stamp" a small tread image into
   it every 6.4 cm (exactly one tread bar), so the pattern lines up into a
   continuous track.
5. Drawing: the heights are copied into a texture (max 30 times a second)
   and the sand shader lifts flat grid meshes to match, so digging never
   rebuilds a mesh. The physics collision is updated 30 times a second.

## Performance (measured, Godot 4.7)

| Part | Cost |
|---|---|
| Wheel pressing (4 wheels) | ~0.05 ms per physics step |
| Sand sliding | ~0.3 ms per physics step while lots of sand is sliding |
| Collision update | ~0.3 ms, 30 times a second |
| Drawing the dug sand | one texture upload (264 KB), up to 30 times a second |
| Whole physics step (incl. Godot's engine) | ~3 ms average at 60 steps/s (budget: 16.7 ms) |
| Making the world (49 tiles) | drivable in ~0.65 s; all tiles ~7 s the first time, **0.2 s** after that (cached) |

### The speed-up pass (after milestone 7)

Measured first, then fixed the biggest costs (`tools/_bench.gd` and
`tools/_bench_world.gd` print the numbers: run them with
`godot --headless --path . -s tools/_bench.gd`):

1. **Tile generation was 4x slower than it needed to be.** Every one of a
   tile's 66,000 points checked all ~30 flattened pads. Now each tile only
   checks the pads near it (0.77 s to 0.27 s a tile), and skips noise for
   rings that can't show at that spot.
2. **The home tile waited in a queue.** Tiles are now generated nearest
   first, so you can drive after 0.65 s instead of 4.3 s. And they use all
   the worker threads ("low priority" jobs only got one).
3. **A disk cache.** Finished tiles are saved in `user://tile_cache` (23 MB)
   and loaded next time: the whole world in 0.2 s. The cache's name includes
   a fingerprint of `sand_tile.gd`, so if you change how the sand is made,
   the old cache is ignored and deleted automatically.
4. **The GPU shapes the sand now.** Before, digging rebuilt meshes in
   GDScript: 0.58 ms per 4 m chunk, up to 12 a frame = 7 ms spikes. Now the
   sand is drawn with flat grids and the heights live in a texture; the sand
   shader's `vertex()` lifts each point. Digging = one native texture
   upload. Mesh work while driving fell from 707 ms to 15 ms over the same
   test drive (47x less).

Tried and **not** done, because measuring said no: sampling the noise
coarsely and interpolating (in GDScript, interpolating costs as much as the
noise call it replaces: 11.2 vs 11.5 ms per tile) and rewriting the sand
sliding (0.3 ms a step is already well inside the budget). Moving code to
C++ (GDExtension) stays the next step only if a future feature needs it.

### Reading the HUD

- **Frame** = how long the whole last frame took. **Physics** = how much of
  that was physics. At 60 FPS a frame is 16.7 ms.
- If Frame is much bigger than Physics, **drawing** is the slow part: your
  GPU (check the GPU line) or too many **Draw calls** (each separate thing
  drawn; a few hundred is fine on a gaming GPU, heavy on integrated graphics).
- If Physics is big, the game logic is the slow part: the **Sand** line shows
  how many chunks are sliding / waiting to be redrawn.

There are three self-tests. Each drives the game by itself and prints numbers
(run from this folder; `godot` = path to your Godot program):

```bash
godot --headless --path . -- --autotest
```

```bash
godot --headless --path . -- --soaktest
```

```bash
godot --headless --path . -- --beetletest
```

```bash
godot --headless --path . -- --droptest
```

```bash
godot --headless --path . -- --anttest
```

```bash
godot --headless --path . -- --looptest
```

`--anttest` leaves a crate by a nest (the ants must steal it, ~16 s), then
drops another and drives up while they haul it (they must scatter, and E must
save it). `--looptest` plays the whole loop by code: buy parts, check paddle
tyres dig deeper than balloons, drain the battery, get rescued, recharge,
take a contract, deliver, get paid.

```bash
godot --headless --path . -- --buildtest
```

`--buildtest` compares builds: lopsided vs even, bumpers vs none, winch vs
none, net vs none, trailer vs none, plus the workshop's money and build files.
It's written as a coroutine with `await`, so it reads like a script.

```bash
godot --headless --path . -- --daytest
```

```bash
godot --headless --path . -- --windtest
```

```bash
godot --headless --path . -- --hawktest
```

```bash
godot --headless --path . -- --storytest
```

```bash
godot --headless --path . -- --worldtest
```

```bash
godot --headless --path . -- --crusttest
```

```bash
godot --headless --path . -- --scorpiontest
```

```bash
godot --headless --path . -- --outposttest
```

Milestone 7:

```bash
godot --headless --path . -- --gravitytest
```

```bash
godot --headless --path . -- --flowtest
```

```bash
godot --headless --path . -- --raytest
```

```bash
godot --headless --path . -- --drifttest
```

`--gravitytest`: fall times at home vs the Drift; wheel contact with and
without wings; the gyro righting a truck on its side (Drift and home).
`--flowtest`: crate and truck carried by a river; slow vs fast sinking;
river holes refilling. `--raytest`: a slow truck flipped by a ray, with a
gyro it stays up, a fast one isn't even hunted. `--drifttest`: the third
kit, Drift Station, fast travel, orbs, and the finale.

Milestone 6:

```bash
godot --headless --path . -- --glasstest
```

```bash
godot --headless --path . -- --magnettest
```

```bash
godot --headless --path . -- --shardtest
```

```bash
godot --headless --path . -- --traveltest
```

`--glasstest`: braking from 4 m/s slides 1.6 m on glass vs 0.6 m on sand;
glass doesn't dent, sand does. `--magnettest`: drift past a lodestone for a
plain truck, iron ballast and sandbags; a light truck drives off the rock, an
iron-heavy one stays stuck; storms. `--shardtest`: fast over rubble = flats,
slow or solid tyres = none; the spare (P); the crew patches the rest at base.
`--traveltest`: fast travel, hauling the second kit, the Glass Outpost's
board, rescue to the nearest base.

`--worldtest`: all 25 tiles generate, the edges between tiles match exactly
(also after pressing ruts across one), tiles switch on and off as the truck
moves, and the truck drives across a tile border without falling through.
`--crusttest`: a light truck breaks thin crust but not thick; a heavy load on
thick crust. `--scorpiontest`: clamped, then shaken off (~2 s), then zapped
by a buzzer (~0.6 s). `--outposttest`: deliver the kit, the outpost is built
and works (contracts, charging, rescue).

`--daytest`: noon vs midnight (daylight, solar gain, headlights, base lamp,
night-only jobs). `--windtest`: crosswind drift while driving (calm about
0.1 m, gust about 1.3 m), and a parked truck plus loose crate in a gust (they
must stay put). `--hawktest`: an unsecured crate gets grabbed and dropped,
a netted one and a heavy engine foil it. `--storytest`: story progress, a
refused damaged delivery, a late one at half pay, and the ending.

`--droptest` drops the crate from 2 m and checks the dent, the damage and
loading it back with E. `--autotest` is a 10-second drive that checks the sand deforms. `--soaktest`
drives the delivery route for 90 seconds and prints the cost every 5 seconds:
**it must stay flat**. `--beetletest` parks the truck next to a beetle and
checks it notices, charges and rams.

### The slowdown bug (and why the soak test exists)

The first version slowed down over time until the game froze. Two bugs worked
together: sliding sand never quite stopped moving (each step only halved the
difference), and all moving sand was tracked as ONE rectangle, which grew
along your entire route. After 20 seconds it covered nearly half the map and
was re-checked 240 times a second. Physics went from 3.5 ms to over 30 ms per
step. Once a step takes longer than the 8.3 ms budget, Godot runs *extra*
steps to catch up, which makes it even slower: FPS falls toward zero.

The fix: track sliding per chunk, put chunks to sleep when they're stable
(within 1 mm), and cap how many chunks slide per step. Lesson: **a short test
can't catch problems that grow over time.** Run the soak test after big changes.

### Part 2: stuck at 7 FPS (the "spiral of death")

Even after that fix, FPS could drop to ~7 and never come back. Physics runs at
a fixed rate; when a frame is slow, Godot runs extra physics steps to catch
up. Those extra steps make the next frame slower too, so it needs even more
catch-up steps... until it hits the limit (8 steps per frame) and stays
there forever. Reproduced here with a slow renderer: exactly 8.0 steps every
frame, 7–10 FPS, even though one step only costs 1.5 ms.

Fixes (`project.godot` and `main.gd`):

- Physics at **60** steps/s instead of 120: half the work, double the budget.
- At most **4** catch-up steps per frame: a slow moment becomes brief slow
  motion instead of a permanent lock.
- **Physics interpolation** on, so 60 steps/s still looks smooth on fast
  screens (the camera follows the *interpolated* car position).
- The sand **doesn't cast shadows** and the sun uses 2 shadow splits instead
  of 4. That roughly halved draw calls (from 250–660 to 100–280).

Lesson learned already: **Jolt** (Godot's other physics engine) is normally
faster, but it rebuilds the entire sand collision shape on every update and
was 5x slower here. So the project uses Godot Physics. Measure before you
assume.

## Your first exercises (learn by changing things)

Do these in order. Each is small. Run the game after every change.

1. **Tune the feel.** Open `rc_car.gd` and change
   `engine_power`, `sand_grip`, `dig_rate`, `sand_drag`. What makes it fun?
2. **Change the sand.** In `sand_terrain.gd`, change `repose_slope` (0.3 =
   runny sand, 1.2 = sticky sand). Change `noise_seed` for a new desert.
3. **Pay for good driving.** In `main.gd`, `_complete_delivery()` always pays
   $50. Make it pay less if the crate took a long time or got bumped.
4. **Add a second cargo type.** Copy `cargo.gd` to `barrel.gd` and use a
   `CylinderShape3D` so it rolls. Pick randomly in `_load_cargo()`.
5. **Tune the beetle.** In `dung_beetle.gd`, try `ram_impulse` = 100
   (harmless shove), 140 (spills cargo, the default), 180 (rolls trucks).
   Then make the truck wider in `rc_car.gd` (wheel x positions) and see if
   it survives 180. That's the "every enemy has a build answer" idea.
6. **Add a build part.** In `build_parts.gd`, add a "headlight" (small, bright,
   any front socket) and give it a `SpotLight3D` in `_add_build_parts`. Or
   in `parts.gd`, add a 4th tyre (say "racing slicks":
   grip 2.6 on hardpan, terrible in soft sand). You'll need one new number in
   `rc_car.gd` to make grip depend on hardness. The garage shows it
   automatically.
7. **Give the beetle its dung ball.** A `RigidBody3D` with a `SphereShape3D`
   that the beetle pushes around while it's in WANDER. Roll it into the
   truck's path for a second hazard.
8. **Add a new state.** Make beetles FLEE when you drive straight at them
   faster than 4 m/s. You only need a new `State`, a rule to enter it, and
   a rule to leave it.

## Graphics: high vs low (G key)

**High** (default on desktop graphics cards, the Forward+ renderer): light
bouncing off the sky and sand, ambient occlusion (soft contact shadows),
screen-space indirect light, volumetric desert haze, soft sun shadows, AgX
colour (bright sand without blowing out), glow for sand glints, tilt-shift
blur, and a 4096 track map. **Low**: plain fog, fixed ambient light, simple
shadows, 2048 track map. On an RX 7900 XTX, High should be no problem.

## Screen tearing

Tearing = the picture splits into horizontal slices that don't line up, when
the camera moves fast. Check these in order:

1. **Don't run the game inside the editor.** If the game window's title says
   "(DEBUG)" and has Input / 2D / 3D buttons along the top, Godot is
   *embedding* it in the editor, and that window often tears or stutters on
   Windows. In the editor's **Game** tab, untick **Embed Game on Next Play**
   (in the menu next to the play controls), then press F5 again. The game
   opens in its own normal window. (Or export it and run the .exe.)
2. **Press V** to cycle V-Sync: On, Mailbox, Adaptive, Off. The message shows
   which mode is really active. On and Mailbox should never tear.
3. **AMD driver settings** (AMD Software: Adrenalin > Gaming > Graphics):
   set *Wait for Vertical Refresh* to "Off, unless application specifies"
   (so the game's V-Sync is used), and try turning *Enhanced Sync* off.
   If your monitor has FreeSync, make sure it's on in both Adrenalin and the
   monitor's menu.
4. **Try Direct3D 12 instead of Vulkan:** Project > Project Settings >
   (Advanced Settings on) > Rendering > Rendering Device > Driver.windows =
   `d3d12`, then restart. D3D12 windows go through Windows' own compositor,
   which syncs to the screen.

## Is it using my graphics card?

The HUD prints the GPU Godot picked (also printed in the Output panel at
startup). If it names your **integrated** graphics (e.g. "Intel UHD", "AMD
Radeon Graphics") instead of your gaming card, and you're on a laptop:

- **Windows:** Settings > System > Display > Graphics > add the Godot `.exe`
  > Options > **High performance**. Restart Godot.
- **NVIDIA:** NVIDIA Control Panel > Manage 3D settings > Program Settings >
  add Godot > "High-performance NVIDIA processor".
- Laptop **plugged in**, not on battery saver.

If it says `opengl3` / `gl_compatibility`, Godot couldn't start Vulkan:
update your graphics drivers.

**Low GPU usage is normal for this prototype.** The scene is simple, so the
card is barely working; the game's cost is on the CPU (physics and the sand
code). With V-Sync on, FPS is also capped at your screen's refresh rate.
Press V to turn it off and see the real maximum.

## Painting the sand textures

Every pixel of the sand comes from PNGs in `textures/` that you paint
(the sand ones are in `textures/sand/`).
The ones there now are generated placeholders: paint over them or replace them.

| File | What to paint | Tips |
|---|---|---|
| `sand_color.png` | Loose sand colour: grains, specks | Don't paint big shadows or highlights; the lighting adds those. Slightly darker ripple troughs look real. |
| `sand_height.png` | Wind ripples, in grey. White = high | Soft gradients = soft ripples. Use the full black-to-white range; the real height is a slider. |
| `packed_color.png` | Sand pressed flat by wheels | Darker, smoother and browner than loose sand. |
| `packed_height.png` | Bumps in packed sand | Keep it calm; mostly mid-grey. |
| `hardpan_color.png` | The firm, cracked crust between dunes | Plates and cracks. Tiles every 3 m. |
| `hardpan_height.png` | Crust bumps: dark lines = cracks | |
| `variation.png` | Huge soft blotches over the whole desert | Mid-grey (128) = no change. This hides the repeating tile. |
| `stamps/tyre_tread.png` | Your tyre's print. RED = pressed down, GREEN = sand pushed up at the sides | The image's height = 3 tread bars, 6.4 cm apart. Keep that spacing or the pattern won't line up. |
| `stamps/beetle_feet.png` | Beetle footprints (same red/green rule) | |
| `stamps/crate.png` | The dent a falling crate leaves | |
| `particles/dust_puff.png` | One puff of dust. White, shape in the alpha | It's tinted sand-coloured in code (`sand_dust.gd`). |
| `decals/base_pad.png` | The base landing pad, projected onto the sand | Transparent outside the pad. |
| `decals/delivery_ring.png` | The glowing delivery ring | Black = no glow. |

**The rules:**

1. **Tileable.** Each texture repeats, so the right edge must flow into the
   left, and the top into the bottom. **Krita** (free): press **W** for
   Wrap Around mode and paint across the edges. **GIMP**: Filters > Map >
   Tile Seamless. **Aseprite** (for a pixel-art look): View > Tiled Mode.
2. **Square, power-of-two sizes:** 256, 512 (current) or 1024 px.
   Bigger isn't better: the tile only covers 1.5 m.
3. **Save over the same file name** as PNG.

**Your workflow:**

1. Open `tools/sand_preview.tscn` in Godot. It shows a 4 m patch of sand
   with two tyre ruts, drawn with the real shader.
2. Put your paint program next to Godot. Paint, save the PNG, click back on
   Godot: it re-imports and the preview updates.
3. Double-click `materials/sand_material.tres` to change the shader's
   sliders: tile size, ripple height, tint, how soft the rut edges are...
4. Press F5 to see it in the game.

Models (truck, crew, beetles) will work the same way later: a small,
hand-painted **palette texture** that every model shares.

## Saving

Money, deliveries and your parts save automatically (after each delivery,
purchase and rescue) to `save.json` in Godot's user folder: in the editor,
**Project > Open User Data Folder**. Delete it to start over.

## Why bolted parts aren't on joints

The pitch said "real physics joints". Bolting every part on with its own
joint is the classic way physics vehicles get wobbly and explode, especially
in a beginner's first engine work. So:

- **Bolted parts** join the truck's body: their collision shapes are added
  to it and their mass moves its centre of mass (`_add_build_parts` in
  `rc_car.gd`). Stable, cheap, and still physically honest: a heavy side
  really leans and tips.
- **Things that move** get a real joint: the **trailer** swivels on a
  `Generic6DOFJoint3D` with limits (yaw 80°, pitch 35°, roll 20°).
- **The cargo net** is a joint too (fully locked), deleted when a crash is
  hard enough to "snap" it.

When you later want parts that break off or flop around (antennas, a crane
arm), give *those* their own body and joint, one at a time.

## The models (Blender)

Every model (truck, tyres, the tiny crew, beetle, ant, hawk, scorpion, all
six cargo types, trailer, the hawk's tree, the radio mast) is built by
`tools/blender/make_models.py`, a Python script for Blender. Three ways to
change them:

1. **Recolour:** paint `textures/models/palette.png`. It's an 8 x 8 grid of
   colour squares, and every part of every model is mapped onto the middle of
   one square (`tools/blender/palette.py` lists which is which). Repaint a
   square and everything using it changes. The last two rows are spare.
2. **Model by hand:** open `models/source/sand_rover_models.blend` in
   Blender (free, blender.org). Each model is in its own collection. Edit it,
   then select that collection's objects and File > Export > glTF 2.0, as
   .glb, over the file in `models/` with the same name. Keep the object
   names the game looks for (`leg_L0`..`leg_R2` on the beetle, `wing_L`,
   `wing_R` on the hawk, `claw_L`, `claw_R`, `tail` on the scorpion), and keep
   models facing **-Y** in Blender (that's "forward" in the game).
3. **Change the script and rebuild everything:**

```bash
cd tools/blender
```

```bash
blender -b --python make_models.py -- ../../models
```

(Without the `-- ../../models` part it still writes to the game's `models/`
folder, wherever you run it from.) One trap that caught me: in the script,
`box()` sizes are in **Blender's** axes (width, depth, height), while
positions go through `G()`, which takes the game's (x, up, forward).

The physics shapes don't change when you change a model (they're still the
simple boxes in the code), so a bigger beetle still bumps like the old one
until you change its collision shape too.

## Making the models look professional

The models started as flat colours: every part one colour, all equally
shiny, no shading in corners. That's what makes 3D look like a toy. Three
upgrades now run automatically (to compare, set `ao_strength`, `dust_amount`
and `grime_amount` to 0 on the material in `models.gd`):

1. **Real materials (PBR).** A second palette image,
   `textures/models/palette_material.png`, has the same 8 x 8 squares, but
   stores how each colour *behaves*: red = roughness (0 = mirror, 1 = chalk),
   green = metalness, blue = glow. So metal parts reflect the sky, rubber is
   matte, the truck paint has a glossy coat, LEDs glow. The values are in
   `tools/blender/palette.py` (`MATERIALS`); change one and run
   `python3 palette.py ../../textures/models/palette.png ../../textures/models/palette_material.png ../../textures/models/grime.png`
   from `tools/blender/`.
2. **Baked ambient occlusion (AO).** `make_models.py` shoots rays from every
   corner of every model to see how hidden it is, and stores that in the
   vertex colours. The shader darkens hidden spots: where parts meet, under
   the cab, between the beetle's legs. It's the single biggest "looks real"
   trick, and it costs nothing while the game runs.
3. **Desert wear.** `shaders/model.gdshader` dusts every upward-facing surface
   with sand (thicker in sheltered spots) and adds blotchy grime, so nothing
   looks factory-new. Sliders: `dust_amount`, `grime_amount`, `ao_strength`.

**Going further** (this is where it becomes *your* art):

- **Bevel more.** Real objects never have razor-sharp edges; a bevel catches
  a highlight. In `make_models.py` raise `bevel=` on boxes, or add a Bevel
  modifier in Blender.
- **Paint real textures** for the hero models (the truck first): in Blender,
  UV-unwrap the model (U > Smart UV Project), then Texture Paint, or export
  to **Substance Painter** / **ArmorPaint** (free) / **Krita**. Paint colour,
  roughness and a normal map (scratches, rivets, panel lines). Then give the
  model its own material instead of the palette one in `models.gd`.
- **Fewer, better colours.** Pro-looking games use a tight palette: a few
  muted colours plus one or two bright accents. Repaint `palette.png` with
  colours picked from one reference photo of a real desert and real RC
  trucks; slightly desaturated colours look more expensive than pure ones.
- **Light matters as much as textures.** Try the G key (high graphics), the
  sun angle and colour in `day_night.gd`, and the environment in `main.gd`
  (`_build_environment`: SSAO, glow, fog).

## The art pass (after milestone 7)

Decided with an art-direction review, and applied to every model:

- **The truck:** bevelled edges with "weighted normals" (big faces stay
  flat, edges shade round and catch a highlight), a narrower cab that leans
  back so the windscreen rakes, a sloped bonnet, wheel arches, a skid plate,
  red bed walls with a dark rail and ribs, finer tyre treads.
- **Landing pads** are real models: concrete slabs with seams, crisp painted
  rings, a kerb and four lamps (the flat painted decal looked cheapest).
- **The crew** wear three muted colours instead of bright confetti, have
  20% bigger heads and hats so they read from far away, and stand in groups
  around tents, toolboxes and crates instead of evenly spread.
- **Creatures:** the beetle got a glossy teal shell, a wing-case seam and
  side horns; scorpions are amber (they used to vanish on the sand); drift
  rays are deep indigo.
- **A tighter palette:** two strong accents (the truck's vermilion and the
  cyan glow of the Drift), everything else slightly muted.
- **Light:** a lower sun (max ~40 degrees: long shadows show every ripple),
  stronger ambient occlusion and bounce light, a soft glow, thinner haze
  with "aerial perspective", and each ring tints the haze its own colour.
  Tilt-shift is gentler (60%) and fades out at speed and on the map.
- **Ground:** smaller hardpan cracks that fade out in the distance, calmer
  colour noise on the dark and lilac sand, and sand rivers with moving
  streaks and a pale foam edge.

**Beauty shots:** open `tools/beauty_shots.tscn` and press F6. Six fixed
cameras (base, truck, Salt Flats, Glass Desert, the Drift, the hull) save
PNGs to `user://beauty_shots`. Take a set before and after any art change.

## Sounds

All in `sounds/` as WAV files, made by a little synthesiser script as
placeholders. Record or design your own (Audacity, sfxr/jsfxr, Bfxr, a
microphone and some sand) and save over the same name. Loops (`*_loop.wav`)
must start and end smoothly so they repeat without a click.

## What comes next (milestone 8 ideas)

The first desert is complete, story and all. Good next steps:

- **Your art pass:** the art pass above set a direction; now make it yours:
  repaint `palette.png`, paint the sand textures in your style, and use the
  beauty shots to compare.
- **Engine work:** after the speed-up pass the sand is cheap; the next
  limit is generating a much bigger world for the first time (~7 s for 49
  tiles on this machine). C++ (GDExtension) for `generate_data()` is the
  next lesson when the world grows again.
- **A second desert** past the beacon's call, with its own rules. Or open it
  up: a sandbox mode where you set gravity, flow and hazards yourself.
- **Sharing builds:** builds are already files; a "challenge" file that says
  "deliver X from A to B with only these parts" would make a great community
  feature.
