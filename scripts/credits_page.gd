class_name CreditsPage
extends VBoxContainer
## Credits, plus the licence notices the game must show. Godot is MIT
## licensed: the licence text has to be included with the game, and so do
## the notices of the libraries inside Godot. Both come straight from the
## engine, so they're always right for the version you ship.
## Put your own credits (and any bought assets) in CREDITS below.

signal back

const CREDITS := """SAND ROVER

Design, code and art: (your name here)
Made with the Godot Engine (godotengine.org)
3D models built with Blender (blender.org)
Fonts: Rubik and Rubik Mono One, copyright 2015 The Rubik Project Authors
(SIL Open Font License 1.1, licence text below)

Thanks for playing!"""


var _scroll: ScrollContainer


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	add_child(UIKit.label("CREDITS", 30, UIKit.ACCENT))
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(900, 460)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var text := Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 860
	text.add_theme_font_size_override("font_size", 16)
	text.text = CREDITS + "\n\n" + licence_text() + "\n\nFONT LICENCE (Rubik, Rubik Mono One)\n\n" \
			+ FileAccess.get_file_as_string("res://fonts/OFL_Rubik.txt")
	_scroll.add_child(text)
	add_child(UIKit.label("D-pad / arrows: scroll", 14, Color(1, 1, 1, 0.6)))
	add_child(UIKit.button("Back", func(): back.emit(), 18))


## The full licence notices: Godot's own licence, then every third-party
## part of the engine, then the full text of each licence used.
static func licence_text() -> String:
	var out := "GODOT ENGINE LICENCE\n\n" + Engine.get_license_text() + "\n\nTHIRD-PARTY NOTICES\n"
	for info in Engine.get_copyright_info():
		out += "\n" + str(info["name"]) + "\n"
		for part in info["parts"]:
			for c in part["copyright"]:
				out += "  (c) " + str(c) + "\n"
			out += "  Licence: " + str(part["license"]) + "\n"
	out += "\nLICENCE TEXTS\n"
	var licences: Dictionary = Engine.get_license_info()
	for name in licences:
		out += "\n" + str(name) + "\n" + str(licences[name]) + "\n"
	return out


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var dir := Input.get_axis("ui_up", "ui_down")
	if absf(dir) > 0.1:
		_scroll.scroll_vertical += int(dir * 900.0 * delta)


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back.emit()
