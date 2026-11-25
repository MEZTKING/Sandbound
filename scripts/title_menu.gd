class_name TitleMenu
extends CanvasLayer
## The title screen: Continue (if there's a save) / New Game / Options /
## Credits / Quit. The world is already loaded behind it.

signal continue_game
signal new_game
signal quit_game

var has_save := false
var _pages := {}
var _main: VBoxContainer
var _confirm: VBoxContainer


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var center := UIKit.backdrop(self, 0.45)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var title := UIKit.label("SAND ROVER", 84, Color(1, 0.85, 0.55))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", UIKit.OUTLINE)
	title.add_theme_constant_override("outline_size", 12)
	box.add_child(title)
	var tag := UIKit.label("a tiny courier in a very big desert", 26, Color(1, 1, 1, 0.85))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tag)
	box.add_child(Control.new())
	var holder := CenterContainer.new()
	box.add_child(holder)
	var panel_stack := VBoxContainer.new()
	holder.add_child(panel_stack)
	# Main buttons
	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 10)
	if has_save:
		_main.add_child(UIKit.button("Continue", func(): continue_game.emit()))
	_main.add_child(UIKit.button("New Game", func():
		if has_save:
			_show("confirm")
		else:
			new_game.emit()))
	_main.add_child(UIKit.button("Options", func(): _show("options")))
	_main.add_child(UIKit.button("Credits", func(): _show("credits")))
	_main.add_child(UIKit.button("Quit", func(): quit_game.emit()))
	panel_stack.add_child(_main)
	_pages["main"] = _main
	# Options and credits live in a panel.
	for page_name in ["options", "credits"]:
		var panel := UIKit.panel(Vector2(0, 0))
		var page: Control = OptionsMenu.new() if page_name == "options" else CreditsPage.new()
		page.back.connect(func(): _show("main"))
		panel.add_child(page)
		panel_stack.add_child(panel)
		_pages[page_name] = panel
	# New game over an existing save?
	_confirm = VBoxContainer.new()
	_confirm.add_theme_constant_override("separation", 10)
	var q := UIKit.label("Start a new game? Your saved progress will be lost.", 20)
	_confirm.add_child(q)
	_confirm.add_child(UIKit.button("Yes, start over", func(): new_game.emit()))
	_confirm.add_child(UIKit.button("No", func(): _show("main")))
	panel_stack.add_child(_confirm)
	_pages["confirm"] = _confirm
	var version := UIKit.label("v" + str(ProjectSettings.get_setting("application/config/version", "dev")), 14, Color(1, 1, 1, 0.5))
	add_child(version)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	_show("main")


func _show(page: String) -> void:
	for p in _pages:
		_pages[p].visible = p == page
	UIKit.focus_first(_pages[page])


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and not _pages["main"].visible:
		get_viewport().set_input_as_handled()
		_show("main")
