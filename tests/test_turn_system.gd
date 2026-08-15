extends SceneTree
# تست سیستم نوبتی: هر کشور در آغاز نوبت تصمیم می‌گیرد، تصمیم‌ها با «پایان نوبت»
# یکجا اجرا می‌شوند و همه پردازش‌ها نوبت‌به‌نوبت است.

func _init():
	await process_frame
	await process_frame
	var fails: Array = []
	var GameStateNode = root.get_node("GameState")
	var GameEngineNode = root.get_node("GameEngine")
	var WorldManagerNode = root.get_node("WorldManager")
	var CommandScript = load("res://scripts/core/command.gd")

	# ── ۱) آغاز بازی با انتخاب کشور ──
	var start = GameEngineNode.tick(GameStateNode.state, GameStateNode.version, GameStateNode.tick,
		[CommandScript.create_country_select("IRN", "balanced")])
	if not start.success:
		fails.append("شروع بازی شکست خورد")
	GameStateNode.set_state(start.state, start.version, start.tick)

	# ── ۲) چند تصمیم مختلف در یک نوبت؛ همه باید در همان یک تیک اجرا شوند ──
	var commands: Array = [
		CommandScript.create_tax_set(0.28),
		CommandScript.create_tariff_set(0.20),
		CommandScript.create_monetary_policy("inflation_target", 0.12),
	]
	var before_tax = float(GameStateNode.state["economy"].get("tax_rate", 0.0))
	var before_tariff = float(GameStateNode.state["trade"].get("tariff_rate", 0.0))
	var r1 = GameEngineNode.tick(GameStateNode.state, GameStateNode.version, GameStateNode.tick, commands)
	if not r1.success:
		fails.append("تیک پایان نوبت با چند تصمیم شکست خورد: " + str(r1.get("reason", "")))
	else:
		GameStateNode.set_state(r1.state, r1.version, r1.tick)
		var after_tax = float(GameStateNode.state["economy"].get("tax_rate", 0.0))
		var after_tariff = float(GameStateNode.state["trade"].get("tariff_rate", 0.0))
		if abs(after_tax - 0.28) > 0.0001:
			fails.append("مالیات پس از پایان نوبت اعمال نشد (%s → %s)" % [before_tax, after_tax])
		if abs(after_tariff - 0.20) > 0.0001:
			fails.append("تعرفه پس از پایان نوبت اعمال نشد")
		# هر سه تصمیم باید در receipts همان نوبت ثبت شده باشند.
		# قالب جدید کلید idempotent شامل payload است (عمق‌بخشی ۱۵): چهار آرگومان.
		var receipts: Array = GameStateNode.state.get("command_receipts", [])
		var expected: Array = []
		for cmd in commands:
			expected.append(load("res://scripts/core/versioning.gd").make_idempotent_key(cmd.type, cmd.tick, cmd.player_id, cmd.payload))
		for e in expected:
			if not receipts.has(e):
				fails.append("رسید تصمیم ثبت نشد: " + str(e))
	print("✓ چند تصمیم در یک نوبت: یک تیک + اعمال یکجا + رسید")

	# ── ۳) فاز تصمیم‌گیری NPC: هر کشور غیربازیکن در هر نوبت تصمیم دارد ──
	var world: Dictionary = GameStateNode.state.get("world", {})
	var plans: Dictionary = world.get("npc_turn_plans", {})
	var turn_key := str(GameStateNode.tick)
	if not plans.has(turn_key):
		fails.append("تصمیم‌های نوبت %s ثبت نشدند" % turn_key)
	else:
		var turn_plans: Array = plans[turn_key]
		var npc_count := 0
		for cid in world.get("countries", {}).keys():
			if cid != str(world.get("player_country", "")):
				npc_count += 1
		var valid := 0
		for plan in turn_plans:
			if plan is Array and plan.size() >= 2 and str(plan[0]) != "" and str(plan[1]) != "" and str(plan[1]) != "sq":
				valid += 1
		if valid != turn_plans.size():
			fails.append("ساختار تصمیم‌های NPC ناقص است")
		print("✓ تصمیم‌گیری هر کشور: %d تصمیم برجسته از %d کشور برای نوبت %s" % [turn_plans.size(), npc_count, turn_key])

	# ── ۴) دترمینیسم: دو اجرای یکسان از یک state باید تصمیم‌های یکسان بدهند ──
	var state_a = GameStateNode.state.duplicate(true)
	var run_a = GameEngineNode.tick(state_a, GameStateNode.version, GameStateNode.tick, [])
	var state_b = GameStateNode.state.duplicate(true)
	var run_b = GameEngineNode.tick(state_b, GameStateNode.version, GameStateNode.tick, [])
	if JSON.stringify(run_a.state.get("world", {}).get("npc_turn_plans", {})) != JSON.stringify(run_b.state.get("world", {}).get("npc_turn_plans", {})):
		fails.append("تصمیم‌های NPC دترمینستیک نیستند")
	else:
		print("✓ دترمینیسم تصمیم‌های NPC: یکسان در دو اجرا")

	# ── ۵) اجرای تصمیم‌ها در پایان نوبت: تصمیم جنگ → جنگ واقعی ──
	var executed_wars := 0
	var planned_wars := 0
	for plan in plans.get(turn_key, []):
		if plan is Array and plan.size() >= 2 and str(plan[1]) == "war":
			planned_wars += 1
	# نوبت بعد را اجرا می‌کنیم تا تصمیم‌های نوبت جاری در simulate_npc_month اعمال شوند
	var r2 = GameEngineNode.tick(GameStateNode.state, GameStateNode.version, GameStateNode.tick, [])
	if not r2.success:
		fails.append("تیک بعدی شکست خورد")
	else:
		GameStateNode.set_state(r2.state, r2.version, r2.tick)
		var world2: Dictionary = GameStateNode.state.get("world", {})
		var wars2: Dictionary = world2.get("npc_wars", {})
		for plan in plans.get(turn_key, []):
			if plan is Array and plan.size() >= 4 and str(plan[1]) == "war" and str(plan[3]) != "":
				if not wars2.has(str(plan[3])):
					fails.append("جنگ برنامه‌ریزی‌شده اجرا نشد: " + str(plan))
				else:
					executed_wars += 1
		# رویدادهای جنگ از فاز اجرا باید به tick_events رسیده باشند
		var war_events := 0
		for ev in r2.get("events", []):
			if str(ev.get("type", "")) == "npc_war_started":
				war_events += 1
		print("✓ اجرای تصمیم‌ها: %d/%d جنگ برنامه‌ریزی‌شده در پایان نوبت اجرا شد (رویدادها: %d)" % [executed_wars, planned_wars, war_events])

	# ── ۶) نوبت‌به‌نوبت بودن: تیک‌ها فقط با end-turn جلو می‌روند و plans هر نوبت جدا هستند ──
	var tick_before: int = GameStateNode.tick
	var r3 = GameEngineNode.tick(GameStateNode.state, GameStateNode.version, GameStateNode.tick, [])
	GameStateNode.set_state(r3.state, r3.version, r3.tick)
	if GameStateNode.tick != tick_before + 1:
		fails.append("نوبت به‌درستی یکی جلو نرفت")
	var plans3: Dictionary = GameStateNode.state.get("world", {}).get("npc_turn_plans", {})
	if not plans3.has(str(GameStateNode.tick)) or plans3.has(str(tick_before + 1)) == false:
		fails.append("برنامه نوبت جدید ثبت نشد")
	print("✓ پردازش نوبت‌به‌نوبت: تیک %s → %s" % [tick_before, GameStateNode.tick])

	# ── ۷) رابط: صف تصمیم‌ها + پایان نوبت + گزارش ──
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene._queue_decision(CommandScript.create_tax_set(0.25), "🧾 مالیات: ۲۵٪")
	scene._queue_decision(CommandScript.create_tariff_set(0.15), "🚢 تعرفه: ۱۵٪")
	if scene.queued_commands.size() != 2:
		fails.append("صف تصمیم‌ها پر نشد")
	if not str(scene.queue_btn.text).contains("۲"):
		fails.append("شمارنده صف تصمیم به‌روز نشد: " + str(scene.queue_btn.text))
	# جایگزینی تصمیم هم‌خانواده
	scene._queue_decision(CommandScript.create_tax_set(0.30), "🧾 مالیات: ۳۰٪")
	if scene.queued_commands.size() != 2:
		fails.append("جایگزینی تصمیم هم‌خانواده کار نکرد")
	# پنل بازبینی
	scene._on_queue_pressed()
	await process_frame
	if scene.queue_panel == null or not scene.queue_panel.visible:
		fails.append("پنل بازبینی تصمیم‌ها باز نشد")
	scene._on_queue_pressed()
	# حذف یک تصمیم
	scene._remove_queued_decision(0)
	if scene.queued_commands.size() != 1:
		fails.append("حذف تصمیم از صف کار نکرد")
	# پایان نوبت از UI
	var tick_ui_before = root.get_node("GameState").tick
	scene._on_next_tick_pressed()
	await create_timer(3.0).timeout
	if root.get_node("GameState").tick != tick_ui_before + 1:
		fails.append("پایان نوبت از UI نوبت را جلو نبرد")
	if scene.queued_commands.size() != 0:
		fails.append("صف تصمیم پس از پایان نوبت خالی نشد")
	if scene.turn_report_overlay == null or not is_instance_valid(scene.turn_report_overlay):
		fails.append("گزارش نوبت نمایش داده نشد")
	else:
		print("✓ گزارش نوبت پس از پایان نوبت نمایش داده شد")
	print("✓ صف تصمیم UI: ثبت، جایگزینی، حذف، پایان نوبت، گزارش")

	print("")
	if fails.size() == 0:
		print("=== ✅ TURN SYSTEM TEST PASSED ===")
	else:
		for f in fails:
			print("❌ " + f)
		print("=== ❌ TURN SYSTEM FAILED: %d ===" % fails.size())
	quit(fails.size())
