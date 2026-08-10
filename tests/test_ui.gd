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
	for tab in ["map", "government", "laws", "economy", "projects", "technology", "population", "military", "network", "systems", "dashboard"]:
		scene._switch_tab(tab)
		await process_frame
		if scene.content.get_child_count() == 0:
			fails.append("تب %s خالی است" % tab)
		print("  ✓ tab %s: %d cards" % [tab, scene.content.get_child_count()])
	# نقشه واحد باید از جهان تا کشور/استان زوم پیوسته و لایه‌های قابل تعویض داشته باشد.
	scene._switch_tab("map")
	await process_frame
	await process_frame
	var unified_map = scene.current_unified_map
	if unified_map == null:
		fails.append("نقشه فرماندهی یکپارچه ساخته نشد")
	else:
		var focus_count = 0
		var world_manager = root.get_node("WorldManager")
		for country_id in world_manager.get_country_ids():
			unified_map.focus_country(str(country_id))
			if not is_finite(unified_map.zoom_level) or unified_map.zoom_level < 1.0:
				fails.append("فوکوس نقشه کشور %s نامعتبر است" % country_id); break
			focus_count += 1
		unified_map.focus_country("IRN")
		await process_frame
		if focus_count != 195: fails.append("فوکوس نقشه هر ۱۹۵ کشور کامل نشد")
		if unified_map.zoom_level < unified_map.ADMIN_ZOOM:
			fails.append("زوم کشور تقسیمات اداری را فعال نکرد")
		if unified_map._unit_screen_records.is_empty():
			fails.append("مرزهای Admin-1 در زوم کشور رسم نشد")
		unified_map.focus_world(); await process_frame
		var iran_profile = world_manager.get_country("IRN")
		var iran_point = unified_map._geo_point(float(iran_profile.get("lon",0)),float(iran_profile.get("lat",0)))
		if unified_map._country_at(iran_point) != "IRN": fails.append("انتخاب کشور روی نقشه واحد شکست خورد")
		unified_map.focus_country("IRN"); await process_frame
		for layer in ["political","relations","population","economy","infrastructure","satisfaction","security","weather","resources","military"]:
			unified_map.set_base_layer(layer)
			await process_frame
		unified_map.focus_world(); unified_map.zoom_in(); unified_map.zoom_out()
		print("  ✓ unified map: continuous world/country zoom + 10 lenses")
	# بازکردن صفحه جزئیات تک‌تک ۶۵ سامانه
	var engine = root.get_node("GameEngine")
	var inspected = 0
	for system_name in engine.system_order:
		scene.selected_system = system_name
		scene._switch_tab("systems")
		await process_frame
		if scene.content.get_child_count() < 3:
			fails.append("جزئیات سامانه %s ساخته نشد" % system_name)
			break
		inspected += 1
	print("System inspector: %d pages" % inspected)
	scene._switch_tab("dashboard")
	await process_frame
	# کنترل قطع/وصل افکت صوتی باید در حالت headless نیز امن باشد.
	scene._on_sound_pressed()
	scene._on_sound_pressed()
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
	cmd = load("res://scripts/core/command.gd").create_diplomacy_action("TUR", "improve_relations")
	ok = scene._run_tick_with([cmd])
	print("UI diplomacy cmd: %s" % ("OK" if ok else "FAIL"))
	if not ok:
		fails.append("فرمان دیپلماسی UI شکست خورد")
	print("")
	if fails.size() == 0:
		print("=== ✅ UI SMOKE TEST PASSED ===")
	else:
		print("=== ❌ UI ISSUES: %s ===" % str(fails))
	quit(0 if fails.size() == 0 else 1)
