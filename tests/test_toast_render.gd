extends SceneTree
# تست دائمی رندر toast (رفع کادر خالی — بازرسی ۱۴۰۵)
# صحنهٔ واقعی main.tscn لود می‌شود؛ پنل باید حداقل عرض واقعی داشته باشد،
# لیبل متن کامل را نگه دارد (بدون overrun/clip که متن را «...» می‌کرد)،
# فونت فارسی لود شود و متن داخل پنل باشد.
func _init():
	await process_frame
	await process_frame
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame
	scene._toast("✅ نام رهبر به «بهرام کیانی» تغییر کرد")
	await process_frame
	await process_frame
	await process_frame
	var stack = scene.toast_stack
	var fails: Array = []
	if stack == null or not is_instance_valid(stack) or stack.get_child_count() == 0:
		printerr("TOAST FAIL: پنل ساخته نشد")
		quit(1)
		return
	var panel: Control = stack.get_child(0)
	var label: Label = panel.get_child(0)
	if panel.size.x < 300.0:
		fails.append("پنل خیلی باریک است: %.0fpx" % panel.size.x)
	if label.text.is_empty():
		fails.append("متن لیبل خالی است")
	if label.size.x < 300.0:
		fails.append("لیبل خیلی باریک است: %.0fpx" % label.size.x)
	var font: FontFile = label.get_theme_font("font") as FontFile
	if font == null:
		fails.append("فونت فارسی لود نشده")
	var text_w: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	if text_w > label.size.x + 5.0 and label.size.x < 400.0:
		fails.append("متن (%.0fpx) از لیبل (%.0fpx) بیرون می‌زند" % [text_w, label.size.x])
	if fails.is_empty():
		print("=== TOAST RENDER OK: panel=%.0fx%.0f label=%.0fx%.0f text=%dpx ===" % [
			panel.size.x, panel.size.y, label.size.x, label.size.y, int(text_w)])
		quit(0)
	else:
		for f in fails:
			printerr("TOAST FAIL: " + f)
		quit(1)
