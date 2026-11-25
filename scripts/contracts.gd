class_name Contracts
extends RefCounted
## Makes delivery jobs for the contract board at base.
##
## A contract is just a Dictionary:
##   cargo:  which cargo type (see Cargo.TYPES)
##   dest:   index into the delivery spots
##   pay:    full pay if it arrives in perfect condition
##
## Pay = distance x how hard the cargo is (pay_mult), plus a little luck.
## Pay is per metre of straight-line distance, so far jobs pay more.

const PAY_PER_METRE := 1.6
const MIN_PAY := 20


## Three different offers. `level` (number of deliveries so far) unlocks the
## trickier cargo gradually, so new players start with plain crates.
## `dests` = which delivery points (indexes into `spots`) this station sends
## jobs to: the home base sends you around the dunes, the outpost around the
## Salt Flats. Out there everything pays more.
static func make_offers(rng: RandomNumberGenerator, spots: Array[Vector3], base: Vector3, level: int,
		dests: Array[int] = [0, 1, 2, 3, 4, 5], pay_bonus := 1.0, extra_cargo: Array[String] = []) -> Array[Dictionary]:
	var cargo_pool: Array[String] = ["crate", "barrel"]
	if level >= 1:
		cargo_pool.append("eggs")
	if level >= 2:
		cargo_pool.append("engine")
	if level >= 3:
		cargo_pool.append("ice")
	cargo_pool.append_array(extra_cargo)   # (the Drift Station also ships orbs)
	var offers: Array[Dictionary] = []
	var used_dests: Array[int] = []
	for n in 3:
		var dest: int = dests[rng.randi_range(0, dests.size() - 1)]
		while dest in used_dests and used_dests.size() < dests.size():
			dest = dests[rng.randi_range(0, dests.size() - 1)]
		used_dests.append(dest)
		var cargo: String = "crate" if (n == 0 and level == 0) else cargo_pool[rng.randi_range(0, cargo_pool.size() - 1)]
		var dist := Vector2(spots[dest].x - base.x, spots[dest].z - base.z).length()
		var mult: float = Cargo.TYPES[cargo]["pay_mult"]
		var pay := maxi(MIN_PAY, int(dist * PAY_PER_METRE * mult * pay_bonus * rng.randf_range(0.9, 1.15)))
		offers.append({"cargo": cargo, "dest": dest, "pay": pay, "distance": dist})
	return offers


static func describe(c: Dictionary) -> String:
	var t: Dictionary = Cargo.TYPES[c["cargo"]]
	var line := "%s to %s (%d m)  -  $%d" % [t["name"], spot_name(int(c["dest"])),
			int(c["distance"]), c["pay"]]
	if c.has("story"):
		var twist := Story.twist_text(c)
		return "STORY %d/%d: %s\n%s: \"%s\"\n%s%s" % [int(c["story"]) + 1, Story.CONTRACTS.size(),
				c["title"], c["client"], c["text"], line, ("\nTwist: " + twist) if twist != "" else ""]
	return "%s\n%s" % [line, t["desc"]]


## "point A" ... "point X", and the three outpost sites (12, 19, 26).
static func spot_name(i: int) -> String:
	if i == 12:
		return "the outpost site"
	if i == 19:
		return "the glass outpost site"
	if i == 26:
		return "the drift station site"
	return "point " + spot_letter(i)


## The letter on a delivery point: 0-11 = A-L, 13-18 = M-R, 20-25 = S-X
## (12, 19 and 26 are outpost sites).
static func spot_letter(i: int) -> String:
	if i == 12 or i == 19 or i == 26:
		return "#"
	return char(65 + i - (0 if i < 12 else (1 if i < 19 else 2)))
