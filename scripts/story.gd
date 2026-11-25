class_name Story
extends RefCounted
## Ten handmade contracts that tell the story of Ring 0, the Home Dunes.
##
## (Since then: six more for each of Ring 1, the Salt Flats, Ring 2, the
## Glass Desert, and Ring 3, the Drift. Each starts at a base: "from" =
## "home", "outpost", "glass" or "drift".)
##
## One is always on the contract board (in gold), next to two random jobs.
## Finish it and the next one appears. Each can have a TWIST:
##   deadline:      seconds to deliver it. Late = half pay, and the story
##                  doesn't move on (try again).
##   min_condition: the client refuses it below this condition (%).
##   night:         only offered at night.
##
## Edit freely: change the words, add contracts, invent new twists.
## (Destinations: 0-5 = A-F, 6-11 = G-L, 12 = the outpost site,
##  13-18 = M-R, 19 = the glass outpost site, 20-25 = S-X, 26 = the drift
##  station site.)

const CONTRACTS := [
	{
		"title": "First Day",
		"client": "Old Pip, the crew boss",
		"text": "Welcome to the crew, kid. My toolbox is still out at the dig. Bring it in one piece.",
		"cargo": "crate", "dest": 2, "pay": 45,
	},
	{
		"title": "Eggs for Breakfast",
		"client": "Cook Maru",
		"text": "Two dozen beetle-proof eggs for the diggers. Beetle-proof, not driver-proof.",
		"cargo": "eggs", "dest": 1, "pay": 95, "min_condition": 60,
	},
	{
		"title": "Thirsty Work",
		"client": "The Dig Team",
		"text": "Our water ran out an hour ago. It's a barrel. It rolls. You'll see.",
		"cargo": "barrel", "dest": 0, "pay": 75,
	},
	{
		"title": "Night Shift",
		"client": "Pip's cousin Lune",
		"text": "I only work nights: too hot in the day. Bring my lunch box. Bring a headlight.",
		"cargo": "crate", "dest": 3, "pay": 90, "night": true,
	},
	{
		"title": "Race the Sun",
		"client": "Cook Maru",
		"text": "Ice for the cold store. You've got about a minute before it's a puddle.",
		"cargo": "ice", "dest": 4, "pay": 150, "deadline": 70,
	},
	{
		"title": "Heavy Metal",
		"client": "The Dig Team",
		"text": "The digger's engine died. Here's the new one. It is VERY heavy. Mind the soft sand.",
		"cargo": "engine", "dest": 5, "pay": 130,
	},
	{
		"title": "Hawk Season",
		"client": "Old Pip",
		"text": "The hawks are hunting. Strap your load down, or they'll have it for dinner.",
		"cargo": "crate", "dest": 0, "pay": 110, "min_condition": 70,
	},
	{
		"title": "Through Beetle Country",
		"client": "Cook Maru",
		"text": "More eggs. The short way goes past the beetles. Bumpers, maybe?",
		"cargo": "eggs", "dest": 3, "pay": 140, "min_condition": 50,
	},
	{
		"title": "Double Time",
		"client": "The Dig Team",
		"text": "They hit water! Need another barrel, fast, before the hole collapses.",
		"cargo": "barrel", "dest": 4, "pay": 135, "deadline": 75,
	},
	{
		"title": "The Signal",
		"client": "Old Pip",
		"text": "Something past the salt flats keeps beeping, every night. Take this receiver to the old mast at F and listen.",
		"cargo": "crate", "dest": 5, "pay": 220, "night": true,
		"ending": "The receiver crackles... a voice, far away, speaking no language you know. Then a map, drawn in the static: white flats, and a camp marked in the middle of them. Pip: \"We'll need an outpost out there.\"",
	},
	# --- Ring 1: the Salt Flats -------------------------------------------
	{
		"title": "The Outpost",
		"client": "Old Pip",
		"text": "Whatever's beeping is out on the Salt Flats. Take the outpost kit to the site north of here. It's heavy: the thin grey crust won't hold you.",
		"cargo": "kit", "dest": 12, "pay": 160,
	},
	{
		"title": "Salt Run",
		"client": "Lune, now at the outpost",
		"text": "The outpost needs supplies. White crust is fast and firm. The grey stuff isn't.",
		"cargo": "crate", "dest": 6, "pay": 120, "from": "outpost",
	},
	{
		"title": "Heavy Going",
		"client": "The Dig Team",
		"text": "The digger is coming out here too. That engine is heavy: stick to thick white crust or you'll break through.",
		"cargo": "engine", "dest": 7, "pay": 200, "min_condition": 50, "from": "outpost",
	},
	{
		"title": "Scorpion Alley",
		"client": "Cook Maru",
		"text": "Eggs for the outpost. The scorpions down that way love tyres. A buzzer might help.",
		"cargo": "eggs", "dest": 8, "pay": 190, "min_condition": 60, "from": "outpost",
	},
	{
		"title": "Race the Mirage",
		"client": "Cook Maru",
		"text": "Ice, out on the hottest flat in the world. You have about a minute and a quarter.",
		"cargo": "ice", "dest": 9, "pay": 230, "deadline": 75, "from": "outpost",
	},
	{
		"title": "The Glass Edge",
		"client": "Old Pip",
		"text": "The beeping is loudest at the far edge of the flats, at night. Take the receiver to point L and listen.",
		"cargo": "crate", "dest": 11, "pay": 300, "night": true, "from": "outpost",
		"ending": "The receiver screams, then goes quiet. Past the edge of the flats, under the moon, the sand has melted into glass, and something out there is blinking back. Pip: \"We're going to need another outpost.\"",
	},
	# --- Ring 2: the Glass Desert -----------------------------------------
	{
		"title": "The Glass Outpost",
		"client": "Old Pip",
		"text": "Another kit, to the site north of here, in the Glass Desert. The broken glass round the sheets eats tyres: go SLOW over the shards, or fit solid tyres. Buy a spare.",
		"cargo": "kit", "dest": 19, "pay": 260, "from": "outpost",
	},
	{
		"title": "Shard Country",
		"client": "Lune, now at the glass outpost",
		"text": "Supplies to point M. Glass sheets are fast but slippery as ice. The sparkly rubble around them is the dangerous bit.",
		"cargo": "crate", "dest": 13, "pay": 220, "from": "glass",
	},
	{
		"title": "Iron Sand",
		"client": "The Dig Team",
		"text": "The digger engine again, to point N. It's solid iron, and the black rocks out here are LODESTONES: they'll drag it, and you, right off course. Swap your iron ballast for sandbags.",
		"cargo": "engine", "dest": 14, "pay": 320, "min_condition": 40, "from": "glass",
	},
	{
		"title": "Ice on Glass",
		"client": "Cook Maru",
		"text": "Ice for the outpost cold store, out at point O. Ice slides. Glass is slippery. Good luck.",
		"cargo": "ice", "dest": 15, "pay": 330, "deadline": 85, "from": "glass",
	},
	{
		"title": "Egg Hunt",
		"client": "Cook Maru",
		"text": "Eggs to point Q, far out past the sheets. A magnet storm is forecast: the lodestones pull twice as hard when one hits.",
		"cargo": "eggs", "dest": 17, "pay": 340, "min_condition": 55, "from": "glass",
	},
	{
		"title": "The Source",
		"client": "Old Pip",
		"text": "The blinking comes from point R, at the edge of the world. Take the receiver there at night. We have to know.",
		"cargo": "crate", "dest": 18, "pay": 480, "night": true, "from": "glass",
		"ending": "Under the glass by R, something enormous is buried: a curved metal hull, its lights blinking slowly in the dark. The receiver says one word, over and over, in a voice that sounds almost like Pip's: \"Drift.\" Far to the north, past the glass, the sand has started to FLOW.",
	},
	# --- Ring 3: the Drift ------------------------------------------------
	{
		"title": "Drift Station",
		"client": "Old Pip",
		"text": "One more outpost, past the glass where the sand flows. Things weigh less than half out there: strap the kit down (net or cage), or it floats off your bed on the first bump.",
		"cargo": "kit", "dest": 26, "pay": 380, "from": "glass",
	},
	{
		"title": "Lightweight",
		"client": "Lune, now at Drift Station",
		"text": "Supplies to point S. Out here your truck weighs 40% of what it should: less grip, big jumps, easy flips. A wing on the roof pushes you down at speed.",
		"cargo": "crate", "dest": 20, "pay": 300, "from": "drift",
	},
	{
		"title": "River Crossing",
		"client": "The Dig Team",
		"text": "Water for the dig at T, across the sand rivers. They flow like water: they carry you downstream and swallow slow wheels. Cross FAST, or float over on balloon tyres.",
		"cargo": "barrel", "dest": 21, "pay": 340, "from": "drift",
	},
	{
		"title": "Ray Country",
		"client": "Cook Maru",
		"text": "Eggs for the crew at U. Something lives in those rivers: drift rays. They flip anything that wades in slowly. Speed, or a gyro to land the right way up.",
		"cargo": "eggs", "dest": 22, "pay": 380, "min_condition": 50, "from": "drift",
	},
	{
		"title": "The First Orb",
		"client": "Old Pip",
		"text": "We pulled a glowing orb out of the hull. Get it to the listening post at V. It's light and round, and in this gravity it bounces like a balloon. Net it down.",
		"cargo": "orb", "dest": 23, "pay": 420, "min_condition": 60, "from": "drift",
	},
	{
		"title": "Homecoming",
		"client": "Old Pip",
		"text": "Last one, kid. Take an orb all the way home, to point E in the Home Dunes. Every ring, every trick you've learned. Pip will be waiting.",
		"cargo": "orb", "dest": 4, "pay": 900, "min_condition": 40, "from": "drift",
		"ending": "You set the orb down at E. It rises, hums, and every light on the hull at R blinks at once, far away. The crew go quiet. Pip: \"It's a beacon. It's calling something home.\" THE END... of the first desert. Thanks for playing.",
	},
]



## The next story contract as a board offer, or {} if the story is done or
## it can't be offered right now (night-only jobs in the day).
## `station` is "home" or "outpost": each story job starts at one of them.
static func next_offer(progress: int, spots: Array[Vector3], base: Vector3, night: bool, station := "home") -> Dictionary:
	if progress >= CONTRACTS.size():
		return {}
	var c: Dictionary = CONTRACTS[progress]
	if c.get("night", false) and not night:
		return {}
	if c.get("from", "home") != station:
		return {}
	var offer := c.duplicate()
	offer["story"] = progress
	offer["distance"] = Vector2(spots[c["dest"]].x - base.x, spots[c["dest"]].z - base.z).length()
	return offer


static func twist_text(c: Dictionary) -> String:
	var bits: Array[String] = []
	if c.has("deadline"):
		bits.append("within %d s" % c["deadline"])
	if c.has("min_condition"):
		bits.append("at least %d%% condition" % c["min_condition"])
	if c.get("night", false):
		bits.append("night job")
	return ", ".join(bits)
