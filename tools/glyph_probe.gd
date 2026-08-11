extends SceneTree

func _initialize():
	var bg = ColorRect.new(); bg.color = Color(0.03,0.06,0.1); bg.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(bg)
	var scroll = ScrollContainer.new(); scroll.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(scroll)
	var box = VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(box)
	var font = load("res://assets/fonts/Vazirmatn-Regular.ttf")
	var glyphs = ["◆","●","▲","►","▶","⏸","⏯","★","☆","⚑","⚐","✚","✕","✓","✔","⚠","♦","⬢","⬡","◈","⊕","⊙","◉","▣","▦","▤","☰","⚙","⌂","➜","✈","✉","☀","☁","☂","☾","❄","♪","♫","♥","⚖","⚛","⚔","☠","☣","☮","⊘","⌕","⚲","❖","⛏","⚒","♜","♞","♟","☺","✎","⊗","⭳","⭱","⇄","❂","✥","⌬","⏏","۩","﷼","¤","✦","✧","⚝","⬟","⎔","≋","◍","⎈","❑","❒","◐","◑","⟳","⬤","🗺","🏛","🛡","🌐","💰","🏗","🔬","👥","⚡"]
	var row := ""
	for i in range(glyphs.size()):
		row += glyphs[i] + " "
		if i % 12 == 11:
			var l = Label.new(); l.text = row; l.add_theme_font_override("font", font); l.add_theme_font_size_override("font_size", 42); box.add_child(l); row = ""
	if row != "":
		var l = Label.new(); l.text = row; l.add_theme_font_override("font", font); l.add_theme_font_size_override("font_size", 42); box.add_child(l)

var frames := 0
func _process(_d) -> bool:
	frames += 1
	if frames > 25:
		var img = root.get_texture().get_image(); img.save_png("user://glyphs.png")
		print("SAVED ", ProjectSettings.globalize_path("user://glyphs.png"))
		return true
	return false
