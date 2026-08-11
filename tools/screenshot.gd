extends SceneTree

var frames := 0
var target := 45
var out_path := "user://shot.png"
var tab := "map"
var open_drawer := false
var start_game := false
var focus_iran := false
var scene_inst: Control

func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tab="): tab = arg.get_slice("=", 1)
		elif arg.begins_with("--out="): out_path = arg.get_slice("=", 1)
		elif arg == "--drawer": open_drawer = true
		elif arg == "--start": start_game = true; target = 130
		elif arg == "--focus": focus_iran = true
	var packed = load("res://scenes/main.tscn")
	scene_inst = packed.instantiate()
	root.add_child(scene_inst)

func _process(_delta) -> bool:
	frames += 1
	if frames == 10 and tab != "" and tab != "map" and not start_game:
		scene_inst._switch_tab(tab)
	if frames == 14 and start_game:
		scene_inst._on_country_start_selected()
	if frames == 110 and start_game:
		scene_inst._switch_tab("map" if (tab == "" or tab == "map") else tab)
	if frames == 118 and focus_iran and is_instance_valid(scene_inst.current_unified_map):
		scene_inst.current_unified_map.focus_country("IRN")
	if frames == 20 and open_drawer:
		scene_inst._open_drawer()
	if frames >= target:
		var img = root.get_texture().get_image()
		if img == null: return true
		img.save_png(out_path)
		print("SHOT_SAVED: ", out_path)
		return true
	return false
