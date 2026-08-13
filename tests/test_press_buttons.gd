extends SceneTree
# تست تهاجمی: فشار تکتک دکمه‌های همه تب‌ها + ۶۷ صفحه سامانه‌ها
# و تشخیص: ۱) پیام خالی/تقریباً خالی ۲) خطای اسکریپت هنگام کلیک

func _init():
	await process_frame
	await process_frame
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var empty_toasts: Array = []
	var pressed := 0
	var skipped := 0
	var skip_words := ["پایان نوبت", "بازی جدید", "خودکار"]
	var tabs := ["map", "dashboard", "news", "missions", "government", "laws", "economy", "projects", "technology", "population", "military", "network", "systems"]

	for tab in tabs:
		scene._switch_tab(tab)
		await process_frame
		await process_frame
		var buttons: Array = scene.content.find_children("*", "Button", true, false)
		for btn in buttons:
			if not is_instance_valid(btn) or not btn.visible or btn.disabled:
				continue
			var label_text := str(btn.text)
			var skip := false
			for w in skip_words:
				if label_text.contains(w):
					skip = true
					break
			if skip:
				skipped += 1
				continue
			var before: String = str(scene.toast_lbl.text) if is_instance_valid(scene.toast_lbl) else ""
			print("PRESS [%s]: %s" % [tab, label_text])
			btn.emit_signal("pressed")
			await process_frame
			await process_frame
			if is_instance_valid(scene.toast_lbl):
				var after: String = str(scene.toast_lbl.text)
				if after != before:
					pressed += 1
					var stripped := after.strip_edges()
					if stripped.length() <= 4:
						empty_toasts.append("[%s] «%s» → پیام خالی: «%s»" % [tab, label_text, after])

	# صفحات تفصیلی ۶۷ سامانه (شامل صفحات مالیات، پسماند، خودروی برقی و...)
	var engine = root.get_node("GameEngine")
	for system_name in engine.system_order:
		scene.selected_system = system_name
		scene._switch_tab("systems")
		await process_frame
		await process_frame
		var buttons: Array = scene.content.find_children("*", "Button", true, false)
		for btn in buttons:
			if not is_instance_valid(btn) or not btn.visible or btn.disabled:
				continue
			var label_text := str(btn.text)
			var skip := false
			for w in skip_words:
				if label_text.contains(w):
					skip = true
					break
			if skip:
				skipped += 1
				continue
			var before: String = str(scene.toast_lbl.text) if is_instance_valid(scene.toast_lbl) else ""
			print("PRESS [sys:%s]: %s" % [system_name, label_text])
			btn.emit_signal("pressed")
			await process_frame
			await process_frame
			if is_instance_valid(scene.toast_lbl):
				var after: String = str(scene.toast_lbl.text)
				if after != before:
					pressed += 1
					var stripped := after.strip_edges()
					if stripped.length() <= 4:
						empty_toasts.append("[sys:%s] «%s» → پیام خالی: «%s»" % [system_name, label_text, after])

	scene._switch_tab("dashboard")
	await process_frame
	print("")
	print("=== PRESS TEST: %d دکمه فشار داده شد (toast دار)، %d رد شد، %d پیام خالی ===" % [pressed, skipped, empty_toasts.size()])
	for e in empty_toasts:
		print("  ⚠ " + e)
	if empty_toasts.is_empty():
		print("=== ✅ NO EMPTY TOASTS ===")
	quit(0 if empty_toasts.is_empty() else 1)
