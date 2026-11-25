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

	# --- Garage: one row per slot, one button per part.
	var head := HBoxContainer.new()
	var g := _label("GARAGE", 20)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(g)
	var ws := Button.new()
	ws.text = "Workshop: build onto your truck  [N]"
	ws.add_theme_font_size_override("font_size", 15)
	ws.pressed.connect(workshop_pressed.emit)
	head.add_child(ws)
	_garage_box.add_child(head)
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
