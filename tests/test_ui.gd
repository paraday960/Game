extends SceneTree
# تست دود UI: اجرای صحنه اصلی + چند کلیک شبیه‌سازی‌شده

func _init():
	await process_frame
	await process_frame
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	# چک: آیا ساختار UI ساخته شد؟
	var fails = []
	if scene.content == null:
		fails.append("content null")
	if scene.content.get_child_count() < 3:
		fails.append("داشبورد خالی است: %d کارت" % scene.content.get_child_count())
	# سوییچ به همه تب‌ها
	for tab in ["economy", "population", "military", "world", "systems", "dashboard"]:
		scene._switch_tab(tab)
		await process_frame
		if scene.content.get_child_count() == 0:
			fails.append("تب %s خالی است" % tab)
		print("  ✓ tab %s: %d cards" % [tab, scene.content.get_child_count()])
	# تست اجرای تیک از UI
	var t0 = Engine.get_main_loop().root.get_node("GameState").tick if root.has_node("GameState") else -1
	var ok = scene._run_tick_with([])
	if not ok:
		fails.append("تیک UI شکست خورد")
	print("UI tick: %s" % ("OK" if ok else "FAIL"))
	# تست فرمان مالیات از طریق UI
	var cmd = load("res://scripts/core/command.gd").create_tax_set(0.30)
	ok = scene._run_tick_with([cmd])
	print("UI tax cmd: %s" % ("OK" if ok else "FAIL"))
	if not ok:
		fails.append("فرمان مالیات UI شکست خورد")
	# دیپلماسی
	cmd = load("res://scripts/core/command.gd").create_diplomacy_action("همسایه_شرقی", "improve_relations")
	ok = scene._run_tick_with([cmd])
	print("UI diplomacy cmd: %s" % ("OK" if ok else "FAIL"))
	if not ok:
		fails.append("فرمان دیپلماسی UI شکست خورد")
	print("")
	if fails.size() == 0:
		print("=== ✅ UI SMOKE TEST PASSED ===")
	else:
		print("=== ❌ UI ISSUES: %s ===" % str(fails))
	quit()
