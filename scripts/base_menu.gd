class_name BaseMenu
extends CanvasLayer
## The menu at base: pick a contract (left) and fit parts in the garage (right).
##
## It only SHOWS things and reports clicks (signals). The game (main.gd)
## owns the money, parts and contracts, and calls refresh() to update it.
## Keeping UI and game logic apart like this makes both easier to change.

signal contract_picked(index: int)
signal part_clicked(slot: String, id: String)
signal workshop_pressed
signal wait_pressed(until: float)
signal travel_pressed(station_id: String)
signal paint_changed(paint: Dictionary)
signal tuning_changed(id: String, value: float)

var _garage_tab := "parts"      # parts / paint / tuning
var _state := {}

var _contract_box: VBoxContainer
var _garage_box: VBoxContainer
var _money_label: Label
var _info_label: Label
var _offer_count := 0


func _ready() -> void:
	layer = 10
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1180, 600)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.08, 0.94)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	panel.add_child(outer)

	var title_row := HBoxContainer.new()
	outer.add_child(title_row)
	var title := _label("BASE", 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	_money_label = _label("", 22)
	title_row.add_child(_money_label)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(columns)

	_contract_box = VBoxContainer.new()
	_contract_box.custom_minimum_size.x = 420
	_contract_box.add_theme_constant_override("separation", 8)
	columns.add_child(_contract_box)

	_garage_box = VBoxContainer.new()
	_garage_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_garage_box.add_theme_constant_override("separation", 6)
	columns.add_child(_garage_box)

	_info_label = _label("Hover over a part to read about it.", 15)
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info_label.custom_minimum_size.y = 44
	_info_label.modulate = Color(1, 0.9, 0.7)
	outer.add_child(_info_label)
	_footer = _label("", 14)
	outer.add_child(_footer)
	GameInput.device_changed.connect(func(_p): _update_footer())
	_update_footer()


var _footer: Label


func _update_footer() -> void:
	if GameInput.using_pad:
		_footer.text = "D-pad: move   A: choose   LB / RB: contracts / garage   B: close"
	else:
		_footer.text = "[1] [2] [3] pick a contract      click a part to buy or fit it      [B] or [Esc] close"


## Rebuild the menu from the game's current state.
##   state = {money, offers, job_text, fitted: {slot: id}, owned: {slot: [ids]}}
func refresh(state: Dictionary) -> void:
	_money_label.text = "$%d" % state["money"]
	for c in _contract_box.get_children():
		c.queue_free()
	for c in _garage_box.get_children():
		c.queue_free()

	# --- Contracts
	_contract_box.add_child(_label("CONTRACTS", 20))
	var offers: Array = state["offers"]
	_offer_count = offers.size()
	if offers.is_empty():
		var job := _label(state["job_text"], 16)
		job.autowrap_mode = TextServer.AUTOWRAP_WORD
		_contract_box.add_child(job)
	for i in offers.size():
		var b := Button.new()
		b.text = "[%d]  %s" % [i + 1, Contracts.describe(offers[i])]
		if offers[i].has("story"):
			b.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD
		b.custom_minimum_size = Vector2(420, 70)
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(contract_picked.emit.bind(i))
		UIKit.style_focus(b)
		_contract_box.add_child(b)

	if state.get("story_note", "") != "":
		var note := _label(state["story_note"], 14)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD
		note.modulate = Color(1.0, 0.85, 0.4)
		_contract_box.add_child(note)
	var waits := HBoxContainer.new()
	for w in [["Wait until morning", 0.27], ["Wait until night", 0.8]]:
		var wb := Button.new()
		wb.text = w[0]
		wb.add_theme_font_size_override("font_size", 14)
		wb.pressed.connect(wait_pressed.emit.bind(w[1]))
		waits.add_child(wb)
	_contract_box.add_child(waits)
	# Fast travel to the other bases you've built (no cargo: it's a crew shuttle).
	var trips: Array = state.get("travel", [])
	if not trips.is_empty():
		var tr := HBoxContainer.new()
		tr.add_child(_label("Travel:", 14))
		for t in trips:
			var tb := Button.new()
			tb.text = "%s ($%d)" % [t["name"], t["cost"]]
			tb.disabled = not t["ok"]
			tb.tooltip_text = t.get("why", "")
			tb.add_theme_font_size_override("font_size", 14)
			tb.pressed.connect(travel_pressed.emit.bind(t["id"]))
			tr.add_child(tb)
		_contract_box.add_child(tr)

	# --- Garage: three tabs.
	_state = state
	var head := HBoxContainer.new()
	var g := _label("GARAGE", 20)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(g)
	var ws := Button.new()
	ws.text = "Workshop: build onto your truck"
	ws.add_theme_font_size_override("font_size", 15)
	ws.pressed.connect(workshop_pressed.emit)
	UIKit.style_focus(ws)
	head.add_child(ws)
	_garage_box.add_child(head)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	_garage_box.add_child(tabs)
	for t in [["parts", "Parts"], ["paint", "Paint"], ["tuning", "Tuning"]]:
		var tb := Button.new()
		tb.text = t[1]
		tb.toggle_mode = true
		tb.button_pressed = _garage_tab == t[0]
		tb.add_theme_font_size_override("font_size", 15)
		tb.custom_minimum_size = Vector2(110, 34)
		UIKit.style_focus(tb)
		var tab_id: String = t[0]
		tb.pressed.connect(func():
			_garage_tab = tab_id
			refresh(_state)
			_focus_garage.call_deferred())
		tabs.add_child(tb)
	match _garage_tab:
		"parts":
			_build_parts_tab(state)
		"paint":
			_build_paint_tab(state)
		"tuning":
			_build_tuning_tab(state)
	# Put the controller's focus on the first contract (or the garage).
	_focus_after_refresh.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# LB / RB: jump between the contracts column and the garage.
	if event.is_action_pressed("menu_tab_next"):
		UIKit.focus_first(_garage_box)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("menu_tab_prev"):
		UIKit.focus_first(_contract_box)
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode
	if key >= KEY_1 and key <= KEY_3 and key - KEY_1 < _offer_count:
		contract_picked.emit(key - KEY_1)
		get_viewport().set_input_as_handled()


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	return l


func _focus_after_refresh() -> void:
	if not visible:
		return
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null or not is_ancestor_of(focused):
		UIKit.focus_first(_contract_box)


func _focus_garage() -> void:
	UIKit.focus_first(_garage_box)


# --- Parts: one row per slot, one button per part.
func _build_parts_tab(state: Dictionary) -> void:
	var fitted: Dictionary = state["fitted"]
	var owned: Dictionary = state["owned"]
	for slot in Parts.SLOTS:
		_garage_box.add_child(_label(Parts.SLOT_NAMES[slot], 15))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_garage_box.add_child(row)
		for id in Parts.CATALOGUE[slot]:
			var part := Parts.get_part(slot, id)
			var b := Button.new()
			var status: String
			if fitted[slot] == id:
				status = "FITTED"
				b.disabled = true
			elif id in owned[slot]:
				status = "owned: fit"
			else:
				status = "$%d" % part["price"]
				b.disabled = part["price"] > state["money"]
			b.text = "%s\n%s" % [part["name"], status]
			b.custom_minimum_size = Vector2(160, 52)
			b.add_theme_font_size_override("font_size", 14)
			b.pressed.connect(part_clicked.emit.bind(slot, id))
			b.mouse_entered.connect(func(): _info_label.text = "%s: %s" % [part["name"], part["desc"]])
			b.focus_entered.connect(func(): _info_label.text = "%s: %s" % [part["name"], part["desc"]])
			UIKit.style_focus(b)
			row.add_child(b)


# --- Paint: body colour, trim colour, decal (and its number). Free.
func _build_paint_tab(state: Dictionary) -> void:
	var paint: Dictionary = state["paint"].duplicate()
	for which in [["body", "Body colour"], ["trim", "Trim and decal colour"]]:
		_garage_box.add_child(_label(which[1], 15))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_garage_box.add_child(row)
		for k in PaintJob.COLORS.size():
			var sw := Button.new()
			sw.toggle_mode = true
			sw.button_pressed = int(paint[which[0]]) == k
			sw.custom_minimum_size = Vector2(44, 40)
			sw.tooltip_text = PaintJob.COLORS[k][0]
			var style := StyleBoxFlat.new()
			style.bg_color = PaintJob.COLORS[k][1]
			style.set_corner_radius_all(6)
			style.set_border_width_all(3 if sw.button_pressed else 0)
			style.border_color = Color.WHITE
			for st in ["normal", "hover", "pressed", "hover_pressed"]:
				sw.add_theme_stylebox_override(st, style)
			UIKit.style_focus(sw)
			var key: String = which[0]
			var name: String = PaintJob.COLORS[k][0]
			sw.focus_entered.connect(func(): _info_label.text = name)
			sw.mouse_entered.connect(func(): _info_label.text = name)
			sw.pressed.connect(func():
				paint[key] = k
				_set_paint(paint))
			row.add_child(sw)
	_garage_box.add_child(_label("Decal", 15))
	var drow := HFlowContainer.new()
	drow.add_theme_constant_override("h_separation", 4)
	_garage_box.add_child(drow)
	for id in PaintJob.DECALS:
		var b := Button.new()
		b.text = PaintJob.DECALS[id]
		b.toggle_mode = true
		b.button_pressed = paint["decal"] == id
		b.add_theme_font_size_override("font_size", 14)
		UIKit.style_focus(b)
		b.pressed.connect(func():
			paint["decal"] = id
			_set_paint(paint))
		drow.add_child(b)
	if paint["decal"] == "race_number":
		var nrow := HBoxContainer.new()
		nrow.add_child(_label("Number:  ", 15))
		for step in [-10, -1]:
			nrow.add_child(_num_button(paint, step))
		var n := _label(str(int(paint["number"])), 20)
		n.custom_minimum_size.x = 44
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nrow.add_child(n)
		for step in [1, 10]:
			nrow.add_child(_num_button(paint, step))
		_garage_box.add_child(nrow)
	_info_label.text = "Paint is free: try anything."


func _num_button(paint: Dictionary, step: int) -> Button:
	var b := Button.new()
	b.text = ("%+d" % step)
	b.add_theme_font_size_override("font_size", 14)
	b.custom_minimum_size = Vector2(44, 32)
	UIKit.style_focus(b)
	b.pressed.connect(func():
		paint["number"] = posmod(int(paint["number"]) + step, 100)
		_set_paint(paint))
	return b


func _set_paint(paint: Dictionary) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var path := _garage_box.get_path_to(focused) if focused and _garage_box.is_ancestor_of(focused) else NodePath()
	paint_changed.emit(paint.duplicate())
	_state["paint"] = paint.duplicate()
	refresh(_state)
	# Keep the controller's focus where it was.
	if not path.is_empty():
		_restore_focus.call_deferred(path)


func _restore_focus(path: NodePath) -> void:
	var n := _garage_box.get_node_or_null(path)
	if n is Control:
		(n as Control).grab_focus()


# --- Tuning: four sliders with real trade-offs (unlocked after contract 3).
func _build_tuning_tab(state: Dictionary) -> void:
	if not state.get("tuning_unlocked", false):
		var l := _label("Pip's Toolkit unlocks after story contract 3.\nUntil then, the truck stays as the factory made it.", 16)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		_garage_box.add_child(l)
		return
	var tuning: Dictionary = state["tuning"]
	for id in Tuning.SLIDERS:
		var def: Array = Tuning.SLIDERS[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name := _label(def[0], 15)
		name.custom_minimum_size.x = 180
		row.add_child(name)
		var sl := HSlider.new()
		sl.min_value = def[1]
		sl.max_value = def[3]
		sl.step = def[4]
		sl.value = Tuning.value(tuning, id)
		sl.custom_minimum_size = Vector2(240, 30)
		UIKit.style_focus(sl)
		var shown := _label("", 15)
		shown.custom_minimum_size.x = 64
		var show := func(): shown.text = ("%.2f" % sl.value) if def[4] < 1.0 else str(int(sl.value))
		show.call()
		var desc: String = def[5]
		sl.focus_entered.connect(func(): _info_label.text = desc)
		sl.mouse_entered.connect(func(): _info_label.text = desc)
		var slider_id: String = id
		sl.value_changed.connect(func(v):
			show.call()
			tuning_changed.emit(slider_id, v))
		row.add_child(sl)
		row.add_child(shown)
		var reset := Button.new()
		reset.text = "Reset"
		reset.add_theme_font_size_override("font_size", 13)
		UIKit.style_focus(reset)
		reset.pressed.connect(func(): sl.value = def[2])
		row.add_child(reset)
		_garage_box.add_child(row)
	_info_label.text = "Every setting has a downside: tune for the job."
