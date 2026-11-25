class_name PauseMenu
extends CanvasLayer
## The pause menu (Esc / Menu button): Resume, Options, Controls, Return to
## Title, Quit to Desktop. While it's open the game is paused: Godot stops
## every node except ones set to keep running (this menu, the autoloads).

signal resumed
signal return_to_title
signal quit_game

var _pages := {}
var _confirm_box: VBoxContainer
var _confirm_label: Label
var _confirm_action := Callable()


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var center := UIKit.backdrop(self, 0.6)
	var panel := UIKit.panel(Vector2(560, 0))
	center.add_child(panel)
	var stack := VBoxContainer.new()
	panel.add_child(stack)
	# Main page
	var main_page := VBoxContainer.new()
	main_page.add_theme_constant_override("separation", 10)
	main_page.add_child(UIKit.label("PAUSED", 34, UIKit.ACCENT))
	main_page.add_child(UIKit.button("Resume", close))
	main_page.add_child(UIKit.button("Options", func(): _show("options")))
	main_page.add_child(UIKit.button("Controls", func(): _show("controls")))
	main_page.add_child(UIKit.button("Return to Title", func():
		_ask("Return to the title screen? (Your progress is saved.)", func(): return_to_title.emit())))
	main_page.add_child(UIKit.button("Quit to Desktop", func():
		_ask("Quit to the desktop? (Your progress is saved.)", func(): quit_game.emit())))
	stack.add_child(main_page)
	_pages["main"] = main_page
	# Options
	var opts := OptionsMenu.new()
	opts.back.connect(func(): _show("main"))
	stack.add_child(opts)
	_pages["options"] = opts
	# Controls
	var ctl := VBoxContainer.new()
	ctl.add_theme_constant_override("separation", 10)
	ctl.add_child(UIKit.label("CONTROLS", 30, UIKit.ACCENT))
	var text := UIKit.label(Screens.controls_text(), 15)
	ctl.add_child(text)
	ctl.add_child(UIKit.button("Back", func(): _show("main"), 18))
	stack.add_child(ctl)
	_pages["controls"] = ctl
	ctl.visibility_changed.connect(func(): text.text = Screens.controls_text())
	# Are you sure?
	_confirm_box = VBoxContainer.new()
	_confirm_box.add_theme_constant_override("separation", 10)
	_confirm_label = UIKit.label("", 20)
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_confirm_label.custom_minimum_size.x = 480
	_confirm_box.add_child(_confirm_label)
	_confirm_box.add_child(UIKit.button("Yes", func(): _confirm_action.call()))
	_confirm_box.add_child(UIKit.button("No", func(): _show("main")))
	stack.add_child(_confirm_box)
	_pages["confirm"] = _confirm_box
	_show("main")


func open() -> void:
	visible = true
	get_tree().paused = true
	_show("main")


func close() -> void:
	visible = false
	get_tree().paused = false
	resumed.emit()


func _show(page: String) -> void:
	for p in _pages:
		_pages[p].visible = p == page
	UIKit.focus_first(_pages[page])


func _ask(question: String, action: Callable) -> void:
	_confirm_label.text = question
	_confirm_action = action
	_show("confirm")


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause") or (event.is_action_pressed("ui_cancel") and _pages["main"].visible):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("ui_cancel") and (_pages["controls"].visible or _pages["confirm"].visible):
		get_viewport().set_input_as_handled()
		_show("main")
