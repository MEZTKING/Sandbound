class_name Screens
extends RefCounted
## The F1 help screen and the controls text (the title screen is TitleMenu).

## The controls, for whichever device you're using (keyboard or controller).
static func controls_text() -> String:
	if GameInput.using_pad:
		return """DRIVING (controller)
  RT / LT        accelerate / reverse         Left stick     steer
  A              brake                        hold Y         flip the truck upright
  X              load dropped cargo           RB             winch (if built)
  hold LB        rescue tow ($25)             D-pad Up       replacement cargo ($10)
  D-pad Right    fit a spare wheel            D-pad Down     workshop (at a base)
  D-pad Left     this help                    View           map
  B              base menu (at a base)        Menu           pause / options
  Right stick    look around                  R3             camera behind the truck

WORKSHOP (controller)
  D-pad / left stick: pick a socket     A: bolt on     X: remove
  LB / RB: choose part    Y: save / load builds    LT / RT: zoom    B: done"""
	return """DRIVING (keyboard)
  W / S   drive forward / reverse          A / D   steer
  Space   brake                            R       flip the truck upright
  F       winch: fire the sand anchor / let go (if you built one)
  P       fit a spare wheel over a flat tyre (if you built one)
  Right mouse button (hold)  look around

CARGO
  E       load dropped cargo back on (park next to it first)
  C       ask the crew for a replacement ($10)
  H       rescue: the crew tows you home ($25)

AT A BASE
  B       contracts and garage             N       workshop: build onto your truck

GENERAL
  M       map        F1     this help      Esc    pause / options
  G       graphics quality                 T      tilt-shift blur
  V       V-Sync                           F12    screenshot"""


const TIPS := """TIPS
  Pale cracked crust (hardpan) is firm and fast. Dune sand is soft: don't spin your wheels.
  Beetles rear up before they charge: steer away. Ants steal cargo left near their nests.
  Hawks dive for loose cargo by day: strap it down with a cargo net, or use the cage.
  Glass Desert: glass is slippery, shard rubble pops tyres (go SLOW), lodestones pull metal.
  The Drift: low gravity, sand rivers carry you off, drift rays flip slow trucks (cross FAST)."""


static func make_help() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 21
	layer.visible = false
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var box := VBoxContainer.new()
	center.add_child(box)
	box.add_child(_label("CONTROLS", 34, Color(1, 0.85, 0.55)))
	var text := _label("", 17, Color.WHITE)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(text)
	var close := _label("", 16, Color(1, 1, 1, 0.7))
	box.add_child(close)
	# Rewrite the text whenever it's shown or you switch keyboard <-> pad.
	var refresh := func():
		text.text = controls_text() + "\n\n" + TIPS
		close.text = "%s to close" % GameInput.prompt("help")
	layer.visibility_changed.connect(refresh)
	GameInput.device_changed.connect(func(_p): refresh.call())
	refresh.call()
	return layer


static func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	return l
