extends Node
## Achievements: unlocked here, remembered in user://achievements.json, and
## sent to Steam when Steam is running (SteamService). The same API names go
## into the Steamworks partner site (see steam/achievements.csv).
##
##   Achievements.unlock("ACH_FIRST_DELIVERY")
##   Achievements.add("pristine", 1, 10, "ACH_PRISTINE_10")   # a counter

signal unlocked(id: String, title: String)

var path := "user://achievements.json"   ## (tests point this somewhere else)

## id -> [title, description]
const LIST := {
	"ACH_FIRST_DELIVERY": ["Signed For", "Complete your first delivery."],
	"ACH_RING_SALT": ["Salt of the Earth", "Reach the Salt Flats."],
	"ACH_RING_GLASS": ["Handle With Care", "Reach the Glass Desert."],
	"ACH_RING_DRIFT": ["Light Load", "Reach the Drift."],
	"ACH_STORY_DONE": ["End of the Line", "Complete all 28 story contracts."],
	"ACH_OUTPOSTS_ALL": ["Supply Chain", "Build all three outposts."],
	"ACH_FAST_TRAVEL": ["Shortcut", "Use fast travel for the first time."],
	"ACH_PRISTINE_10": ["Not a Scratch", "Deliver 10 cargoes in perfect condition."],
	"ACH_BARELY": ["Technically Delivered", "Deliver cargo at under 10% condition."],
	"ACH_HAWK_ROBBED": ["Air Mail", "Have a hawk steal your cargo."],
	"ACH_ANT_RECOVER": ["Finders Keepers", "Reload cargo you dropped before the ants take it, 5 times."],
	"ACH_SCORPION_FLAT": ["Three Wheels Good", "Complete a delivery with a flat or clamped wheel."],
	"ACH_NO_RESCUE_RING": ["Self-Sufficient", "Complete every Glass Desert story contract without a rescue tow."],
	"ACH_FULL_BUILD": ["Bolted On", "Fill all 19 sockets on one truck."],
	"ACH_DRIFT_AIR": ["Low Gravity, High Hopes", "Stay airborne for 5 seconds in the Drift."],
}

var done := {}          # id -> true
var counters := {}      # name -> int
var enabled := true     # tests switch this off so they don't touch your real file


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()


func is_unlocked(id: String) -> bool:
	return done.has(id)


func unlock(id: String) -> void:
	if not enabled or done.has(id) or not LIST.has(id):
		return
	done[id] = true
	_save()
	SteamService.unlock_achievement(id)
	unlocked.emit(id, LIST[id][0])


## Count something up; unlock `id` when it reaches `target`.
func add(counter: String, amount: int, target: int, id: String) -> void:
	if not enabled:
		return
	counters[counter] = int(counters.get(counter, 0)) + amount
	_save()
	if counters[counter] >= target:
		unlock(id)


## Forget everything and read `path` again (tests).
func reload() -> void:
	done.clear()
	counters.clear()
	_load()


func _load() -> void:
	if not FileAccess.file_exists(path):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(d) == TYPE_DICTIONARY:
		for id in d.get("done", []):
			done[str(id)] = true
		counters = d.get("counters", {})


func _save() -> void:
	SaveIO.write_json(path, {"done": done.keys(), "counters": counters})
