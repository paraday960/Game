extends Control
# UI اصلی بازی - فارسی ۱۰۰٪ - قانون ۶

const GameCommandClass = preload("res://scripts/core/command.gd")

var current_state: Dictionary
var tick_timer: float = 0.0
var auto_tick: bool = false

@onready var dashboard_ui = null

func _ready():
	# اتصال به GameState
	if GameState:
		current_state = GameState.get_state_copy()
	else:
		current_state = {}

	# ساخت UI به صورت کدی - برای سادگی و عدم وابستگی به ادیتور
	_create_ui()

	_update_ui()

	# اتصال سیگنال موتور
	if GameEngine:
		GameEngine.tick_completed.connect(_on_tick_completed)
		GameEngine.tick_failed.connect(_on_tick_failed)

	if P2PManager:
		P2PManager.host_game()

	print("رابط کاربری اصلی لود شد - شبیه‌ساز کشور")

func _create_ui():
	# پس‌زمینه
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.08, 0.15)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 20
	vbox.offset_right = -20
	vbox.offset_top = 20
	vbox.offset_bottom = -20
	add_child(vbox)

	# عنوان
	var title = Label.new()
	title.text = "🎮 شبیه‌ساز کشور - نسخه ۱.۰ (۲۰۲۷)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "رهبر مطلق کشور - قابل برکناری نیستید"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.modulate = Color(0.8, 0.8, 0.8)
	vbox.add_child(subtitle)

	# تب‌بار ساده
	var tab_bar = HBoxContainer.new()
	tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(tab_bar)

	var tabs = ["داشبورد", "اقتصاد", "جمعیت", "ارتش", "نقشه جهان"]
	for t in tabs:
		var btn = Button.new()
		btn.text = t
		btn.custom_minimum_size = Vector2(120, 40)
		tab_bar.add_child(btn)
		if t == "داشبورد":
			btn.pressed.connect(_on_dashboard_pressed)

	# اسکرول برای محتوا
	var scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var content = VBoxContainer.new()
	content.name = "Content"
	scroll.add_child(content)

	# داشبورد شاخص‌ها
	var indicators_label = Label.new()
	indicators_label.text = "📊 شاخص‌های کلان کشور"
	indicators_label.add_theme_font_size_override("font_size", 22)
	content.add_child(indicators_label)

	var grid = GridContainer.new()
	grid.name = "IndicatorsGrid"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(grid)

	for i in range(8):
		var lbl = Label.new()
		lbl.name = "Indicator_%d" % i
		lbl.text = "در حال بارگذاری..."
		lbl.add_theme_font_size_override("font_size", 18)
		grid.add_child(lbl)

	# بودجه
	var budget_label = Label.new()
	budget_label.text = "\n💰 تخصیص بودجه (۱۰۰٪)"
	budget_label.add_theme_font_size_override("font_size", 20)
	content.add_child(budget_label)

	var budget_grid = GridContainer.new()
	budget_grid.name = "BudgetGrid"
	budget_grid.columns = 2
	content.add_child(budget_grid)

	# دکمه‌ها
	var btn_container = HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_container)

	var next_btn = Button.new()
	next_btn.name = "NextTickBtn"
	next_btn.text = "▶️ گام بعدی (یک روز)"
	next_btn.custom_minimum_size = Vector2(200, 60)
	next_btn.pressed.connect(_on_next_tick_pressed)
	btn_container.add_child(next_btn)

	var auto_btn = Button.new()
	auto_btn.name = "AutoBtn"
	auto_btn.text = "⏸️ خودکار: خاموش"
	auto_btn.custom_minimum_size = Vector2(180, 60)
	auto_btn.pressed.connect(_on_auto_pressed)
	btn_container.add_child(auto_btn)

	var save_btn = Button.new()
	save_btn.text = "💾 ذخیره"
	save_btn.custom_minimum_size = Vector2(100, 60)
	save_btn.pressed.connect(_on_save_pressed)
	btn_container.add_child(save_btn)

	var load_btn = Button.new()
	load_btn.text = "📂 بارگذاری"
	load_btn.custom_minimum_size = Vector2(120, 60)
	load_btn.pressed.connect(_on_load_pressed)
	btn_container.add_child(load_btn)

	# لاگ رویدادها
	var event_label = Label.new()
	event_label.text = "\n📜 رویدادها"
	event_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(event_label)

	var event_list = VBoxContainer.new()
	event_list.name = "EventList"
	vbox.add_child(event_list)

	# نشانگرهای جذابیت - لایه اعتیادآور ۳.۲۲۷-۳.۲۳۴
	var engagement = Label.new()
	engagement.name = "Engagement"
	engagement.text = "🔥 استریک: ۰ روز | امتیاز: ۰ | سطح: ۱"
	engagement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	engagement.add_theme_font_size_override("font_size", 16)
	vbox.add_child(engagement)

func _update_ui():
	if not GameState:
		return
	current_state = GameState.state

	var content = get_node_or_null("VBoxContainer/Scroll/Content") if has_node("VBoxContainer/Scroll/Content") else null
	if not content:
		# ساختار ممکن است متفاوت باشد، جستجو
		content = find_child("Content", true, false)
		if not content:
			return

	var grid = content.find_child("IndicatorsGrid", true, false)
	if grid:
		var fmt = PersianFormatter
		if fmt == null:
			fmt = self  # fallback

		var econ = current_state.get("economy", {})
		var pop = current_state.get("population", {})
		var pol = current_state.get("politics", {})
		var mil = current_state.get("military", {})
		var ind = current_state.get("indicators", {})
		var res = current_state.get("resources", {})

		var texts = []
		texts.append("تولید ناخالص: %s" % fmt.format_money(econ.get("gdp",0)) if fmt.has_method("format_money") else "GDP: %s" % str(econ.get("gdp",0)))
		texts.append("جمعیت: %s نفر | رضایت: %.0f٪" % [fmt.format_large(pop.get("total",0)) if fmt.has_method("format_large") else str(pop.get("total",0)), pop.get("happiness",0)*100])
		texts.append("ثبات: %.0f٪ | اعتماد: %.0f٪ | فساد: %.0f٪" % [pol.get("stability",0)*100, pol.get("trust",0)*100, pol.get("corruption",0)*100])
		texts.append("قدرت نظامی: %s | آمادگی: %.0f٪" % [fmt.format_number(int(mil.get("power",0))) if fmt.has_method("format_number") else str(mil.get("power",0)), mil.get("readiness",0)*100])
		texts.append("ذخیره غذا: %.0f | آب: %.0f | برق: %.0f" % [res.get("inventory",{}).get("غذا",0), res.get("inventory",{}).get("آب",0), res.get("inventory",{}).get("برق",0)])
		texts.append("تورم: %.1f٪ | بیکاری: %.1f٪ | بدهی/GDP: %.0f٪" % [econ.get("inflation",0)*100, econ.get("unemployment",0)*100, econ.get("debt_to_gdp",0)*100])
		texts.append("شاخص قدرت: %s | شادی: %.0f٪" % [fmt.format_number(int(ind.get("power_score",0))) if fmt.has_method("format_number") else str(ind.get("power_score",0)), ind.get("happiness",0)*100])
		texts.append("امتیاز کل: %s | سطح: %s" % [fmt.format_number(int(current_state.get("score",0))) if fmt.has_method("format_number") else str(current_state.get("score",0)), fmt.to_persian_digits(str(current_state.get("level",1))) if fmt.has_method("to_persian_digits") else str(current_state.get("level",1))])

		for i in range(min(grid.get_child_count(), texts.size())):
			grid.get_child(i).text = texts[i]

	# بودجه
	var budget_grid = content.find_child("BudgetGrid", true, false)
	if budget_grid and budget_grid.get_child_count() == 0:
		var allocs = current_state.get("economy",{}).get("budget_allocations",{})
		for k in allocs.keys():
			var lbl = Label.new()
			lbl.text = "%s: %.0f٪" % [k, allocs[k]*100]
			budget_grid.add_child(lbl)
	elif budget_grid:
		var allocs = current_state.get("economy",{}).get("budget_allocations",{})
		var idx=0
		for k in allocs.keys():
			if idx < budget_grid.get_child_count():
				budget_grid.get_child(idx).text = "%s: %.0f٪" % [k, allocs[k]*100]
			idx+=1

	# رویدادها
	var event_list = find_child("EventList", true, false)
	if event_list and EventLog:
		# پاک کردن قبلی
		for child in event_list.get_children():
			child.queue_free()
		var last_events = EventLog.get_last(5)
		for e in last_events:
			var lbl = Label.new()
			lbl.text = "• [%s] %s" % [e.get("type",""), str(e.get("data",{}))]
			lbl.add_theme_font_size_override("font_size", 14)
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			event_list.add_child(lbl)

	# جذابیت
	var engagement = find_child("Engagement", true, false)
	if engagement and current_state.has("tick"):
		var days = current_state.get("tick",0)
		var clock = current_state.get("clock", {})
		var date_str = "%s/%s/%s (%s)" % [
			PersianFormatter.to_persian_digits(str(clock.get("year", 2027))),
			PersianFormatter.to_persian_digits("%02d" % clock.get("month", 1)),
			PersianFormatter.to_persian_digits("%02d" % clock.get("day", 1)),
			clock.get("season", "بهار")
		]
		engagement.text = "📅 %s | 🔥 استریک: %s روز | ⭐ امتیاز: %s | 🏆 سطح: %s" % [
			date_str,
			PersianFormatter.to_persian_digits(str(days)) if PersianFormatter else str(days),
			PersianFormatter.format_number(int(current_state.get("score",0))) if PersianFormatter else str(current_state.get("score",0)),
			PersianFormatter.to_persian_digits(str(current_state.get("level",1))) if PersianFormatter else str(current_state.get("level",1))
		]

func _on_next_tick_pressed():
	_do_tick()

func _on_auto_pressed():
	auto_tick = !auto_tick
	var btn = find_child("AutoBtn", true, false)
	if btn:
		btn.text = "▶️ خودکار: روشن" if auto_tick else "⏸️ خودکار: خاموش"

func _on_dashboard_pressed():
	_update_ui()

func _on_save_pressed():
	if GameState:
		var json = JSON.stringify(GameState.state)
		var file = FileAccess.open("user://savegame.json", FileAccess.WRITE)
		if file:
			file.store_string(json)
			file.close()
			print("بازی ذخیره شد")
			if EventLog:
				EventLog.log_event("save", {"tick": GameState.tick}, GameState.tick, GameState.version)

func _do_tick():
	if not GameState or not GameEngine:
		return

	var cmds: Array = []
	if P2PManager:
		cmds = P2PManager.get_pending_commands()

	# فرمان تیک بعدی
	cmds.append(GameCommandClass.create_next_tick())

	var result = GameEngine.tick(GameState.state, GameState.version, GameState.tick, cmds)
	if result.success:
		GameState.set_state(result.state, result.version, result.tick)
		_update_ui()
		# افکت جذابیت - ۳.۲۳۴
		var next_btn = find_child("NextTickBtn", true, false)
		if next_btn:
			# انیمیشن کوچک
			var tween = create_tween()
			tween.tween_property(next_btn, "scale", Vector2(1.1, 1.1), 0.1)
			tween.tween_property(next_btn, "scale", Vector2(1.0, 1.0), 0.1)
	else:
		print("تیک شکست خورد: %s" % result.reason)

func _on_tick_completed(new_state, events):
	# بازخورد خوشایند - ۳.۲۳۴
	pass

func _on_tick_failed(reason):
	print("خطای تیک: %s" % reason)

func _process(delta):
	if auto_tick:
		tick_timer += delta
		if tick_timer > 1.0:  # هر ثانیه یک تیک
			tick_timer = 0.0
			_do_tick()


func _on_load_pressed():
	# بارگذاری بازی ذخیره‌شده
	if not FileAccess.file_exists("user://savegame.json"):
		print("فایل ذخیره‌ای یافت نشد")
		return
	var file = FileAccess.open("user://savegame.json", FileAccess.READ)
	if not file:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary and parsed.has("economy") and parsed.has("population"):
		GameState.set_state(parsed, parsed.get("version", 0), parsed.get("tick", 0))
		_update_ui()
		print("بازی بارگذاری شد - روز %d" % parsed.get("tick", 0))
		if EventLog:
			EventLog.log_event("load", {"tick": parsed.get("tick", 0)}, parsed.get("tick", 0), parsed.get("version", 0))
	else:
		print("فایل ذخیره خراب است")
