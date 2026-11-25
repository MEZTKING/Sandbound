extends Node
## The one place that talks to Steam.
##
## Steam support comes from the free GodotSteam plugin (GDExtension version,
## from the Godot Asset Library or godotsteam.com). Without it, or when the
## game isn't started from Steam, everything here quietly does nothing, so
## the game always works.
##
## When testing outside Steam, put steam_appid.txt (containing your App ID;
## 480 is Valve's test app "Spacewar") next to the game executable. Never
## ship that file.

var steam: Object = null        # the GodotSteam singleton, if installed
var running := false            # Steam started and logged in


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Engine.has_singleton("Steam"):
		return
	steam = Engine.get_singleton("Steam")
	var result = steam.call("steamInitEx", false)
	# GodotSteam returns a Dictionary: {"status": 0 = OK, "verbal": "..."}.
	running = typeof(result) == TYPE_DICTIONARY and int(result.get("status", 1)) == 0
	print("Steam: ", "running" if running else "not available (%s)" % str(result))


func _process(_delta: float) -> void:
	if running:
		steam.call("run_callbacks")    # Steam needs this every frame


func unlock_achievement(api_name: String) -> void:
	if not running:
		return
	steam.call("setAchievement", api_name)
	steam.call("storeStats")


func is_on_steam_deck() -> bool:
	return running and bool(steam.call("isSteamRunningOnSteamDeck"))
