extends SceneTree
# تست غیرفعال‌سازی دکمه‌های یک‌بارمصرف/یک‌باردرنوبت:
#  - بعد از کلیک (ثبت در صف تصمیم‌ها) دکمه غیرفعال می‌شود
#  - بعد از حذف تصمیم از صف دوباره فعال می‌شود
#  - بعد از پایان نوبت (اجرای تصمیم‌ها) دکمه بر اساس state جدید ساخته می‌شود

func _init():
	await process_frame
	await process_frame
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await create_timer(1.5).timeout
	scene._on_country_start_selected()
	await create_timer(6.0).timeout
	var fails: Array = []

	# ── ۱) پیدا کردن و کلیک روی یک دکمه عملیاتی در هر تب ──
	var tabs := ["laws", "government", "economy", "military", "technology", "dashboard"]
	var tested := 0
	for tab in tabs:
		scene._switch_tab(tab)
		await create_timer(0.9).timeout
		var found: Button = null
		var key := ""
		var stack: Array = [scene]
		while stack.size() > 0 and found == null:
			var c = stack.pop_back()
			if c is Button and c.has_meta("cmd_key") and not c.disabled:
				found = c
				key = str(c.get_meta("cmd_key"))
				break
			for ch in c.get_children():
				stack.append(ch)
		if found == null:
			continue
		var before: int = scene.queued_commands.size()
		found.pressed.emit()
		await create_timer(0.5).timeout
		if scene.queued_commands.size() != before + 1:
			fails.append("تب %s: کلیک تصمیمی به صف اضافه نکرد" % tab)
			continue
		# دکمه بازسازی‌شده با همان کلید باید غیرفعال باشد
		var found2: Button = null
		stack = [scene]
		while stack.size() > 0 and found2 == null:
			var c = stack.pop_back()
			if c is Button and c.has_meta("cmd_key") and str(c.get_meta("cmd_key")) == key:
				found2 = c
				break
			for ch in c.get_children():
				stack.append(ch)
		if found2 != null and not found2.disabled:
			fails.append("تب %s: دکمه «%s» بعد از کلیک غیرفعال نشد" % [tab, str(found2.text).substr(0, 30)])
		else:
			tested += 1
		# حذف از صف → فعال
		scene._remove_queued_decision(scene.queued_commands.size() - 1)
		await create_timer(0.4).timeout
	print("✓ %d دکمه در %d تب: کلیک → غیرفعال، حذف → فعال" % [tested, tabs.size()])
	if tested == 0:
		fails.append("هیچ دکمه عملیاتی قابل تستی یافت نشد")

	# ── ۲) پایان نوبت: صف خالی و دکمه‌ها بر اساس state جدید ──
	var before_tick: int = root.get_node("GameState").tick
	scene._on_next_tick_pressed()
	await create_timer(10.0).timeout
	if root.get_node("GameState").tick != before_tick + 1:
		fails.append("پایان نوبت اجرا نشد")
	if scene.queued_commands.size() != 0:
		fails.append("صف بعد از پایان نوبت خالی نشد")
	# دکمه‌های غیرفعالِ صف باید آزاد شوند (در تب جدید)
	scene._switch_tab("laws")
	await create_timer(0.9).timeout
	var locked_count := 0
	var stack2: Array = [scene]
	while stack2.size() > 0:
		var c = stack2.pop_back()
		if c is Button and c.has_meta("cmd_key") and c.disabled:
			# فقط دکمه‌هایی که «طبیعی» غیرفعال‌اند (state واقعی) مجازند
			var natural: bool = bool(c.get_meta("natural_disabled", false))
			if not natural:
				locked_count += 1
		for ch in c.get_children():
			stack2.append(ch)
	if locked_count > 0:
		fails.append("%d دکمه پس از پایان نوبت بی‌دلیل قفل ماند" % locked_count)
	else:
		print("✓ پس از پایان نوبت هیچ دکمه‌ای بی‌دلیل قفل نیست")

	print("")
	if fails.is_empty():
		print("=== ✅ ONCE-BUTTONS TEST PASSED ===")
	else:
		for f in fails:
			print("❌ " + f)
		print("=== ❌ FAILED: %d ===" % fails.size())
	quit(fails.size())
