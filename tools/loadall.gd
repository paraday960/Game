extends SceneTree

var frames := 0

func _process(_delta) -> bool:
	frames += 1
	if frames == 2:
		var paths: Array = []
		_scan("res://scripts", paths)
		paths.sort()
		print("LOADALL: %d scripts" % paths.size())
		for p in paths:
			load(p)
		print("LOADALL: scan done")
	if frames >= 8:
		return true
	return false

func _scan(dir_path: String, out: Array):
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var fn := d.get_next()
	while fn != "":
		if d.current_is_dir():
			_scan(dir_path.path_join(fn), out)
		elif fn.ends_with(".gd"):
			out.append(dir_path.path_join(fn))
		fn = d.get_next()
	d.list_dir_end()
