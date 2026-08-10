extends Control
# UI اصلی بازی - فارسی ۱۰۰٪ (قانون ۶) - چندتب تعاملی
# همه‌ی اعداد با ارقام فارسی، همه‌ی فرمان‌ها از طریق موتور اتمی (۳.۶)

const GameCommandClass = preload("res://scripts/core/command.gd")
const WorldMapClass = preload("res://scripts/ui/world_map.gd")
const PersianFont = preload("res://assets/fonts/Vazirmatn-Regular.ttf")

# ---------- وضعیت UI ----------
var auto_tick: bool = false
var tick_timer: float = 0.0
var current_tab: String = "dashboard"
var current_state: Dictionary = {}
var selected_system: String = "economy"
var selected_world_country: String = ""
var country_select_option: OptionButton

# ---------- ارجاع‌های گره ----------
var content: VBoxContainer
var engagement_lbl: Label
var date_lbl: Label
var header_title: Label
var tab_buttons: Dictionary = {}
var event_list: VBoxContainer
var toast_lbl: Label
var network_address_edit: LineEdit
var network_port_spin: SpinBox
var network_status_lbl: Label

# مقادیر میانی فرمان‌های تعاملی
var tax_slider: HSlider
var tax_value_lbl: Label
var budget_sliders: Dictionary = {}

# نام‌های فارسی سیستم‌ها
const SYSTEM_FA := {
	"resources": "منابع و انرژی", "economy": "اقتصاد و بودجه", "population": "جمعیت و دموگرافی",
	"politics": "سیاست و ثبات", "military": "ارتش و دفاع", "diplomacy": "دیپلماسی",
	"infrastructure": "زیرساخت", "technology": "علم و فناوری", "judicial": "قضایی",
	"security": "امنیت داخلی", "health": "بهداشت و سلامت", "education": "آموزش",
	"welfare": "رفاه اجتماعی", "culture": "فرهنگ و رسانه", "intelligence": "اطلاعات و امنیت ملی",
	"environment": "محیط‌زیست", "central_bank": "بانک مرکزی", "administration": "تقسیمات کشوری",
	"agriculture": "کشاورزی", "industry": "صنعت و معدن", "trade": "تجارت خارجی",
	"tourism": "گردشگری", "ethnicity": "قومیت و مذهب", "stock_market": "بورس",
	"statistics": "آمار ملی", "emergency": "مدیریت بحران", "sports_youth": "ورزش و جوانان",
	"veterans": "ایثارگران", "family": "خانواده", "fisheries": "صیادی",
	"heritage": "میراث فرهنگی", "space": "برنامه فضایی", "elections": "انتخابات",
	"settlements": "سکونتگاه‌ها", "transport_roads": "راه‌ها", "hospitality": "مهمان‌پذیری",
	"retail": "تجارت خرد", "fuel_stations": "سوخت و انرژی", "urban_facilities": "تأسیسات شهری",
	"physical": "اماکن فیزیکی", "people": "لایه آدم‌ها", "public_services": "خدمات عمومی",
	"industry_sites": "سایت‌های صنعتی", "financial_services": "خدمات مالی",
	"public_religious": "اماکن عمومی و مذهبی", "government_buildings": "نهادهای دولتی",
	"public_transport": "حمل‌ونقل عمومی", "citizens_detail": "شهروندان",
	"workforce_detail": "نیروی کار", "officials": "دولتمردان", "politicians_detail": "سیاست‌مداران",
	"public_employees": "کارکنان عمومی", "private_sector": "بخش خصوصی",
	"elites_detail": "نخبگان", "security_forces_detail": "نیروهای امنیتی",
	"religious_leaders": "رهبران مذهبی", "households_detail_full": "خانوارها",
	"political_career": "مسیر شغلی سیاسی", "migration_detail": "مهاجرت",
	"prison": "زندان", "human_states": "حالات انسانی", "international_orgs": "سازمان‌های بین‌المللی",
	"foreign_affairs": "امور خارجی", "interdependency": "اثرگذاری متقابل", "quantitative": "دقیق‌سازی کمی"
}

const SYSTEM_STATE_ALIASES = {
	"settlements": "settlements_detail", "transport_roads": "transport_detail",
	"public_services": "public_services_detail", "industry_sites": "industry_sites_detail",
	"citizens_detail": "citizens_detail", "workforce_detail": "workforce_detail",
	"officials": "officials", "politicians_detail": "politicians_detail",
	"elites_detail": "elites_detail", "security_forces_detail": "security_forces_detail",
	"households_detail_full": "households_detail_full", "migration_detail": "migration_detail",
	"quantitative": "quantitative"
}
const SYSTEM_AI_ALIASES = {
	"citizens_detail": "citizens", "workforce_detail": "workforce_jobs",
	"officials": "officials_managers", "politicians_detail": "politicians",
	"elites_detail": "elites", "security_forces_detail": "security_forces",
	"households_detail_full": "households", "migration_detail": "migration",
	"quantitative": "quantitative_temporal", "retail": "retail",
	"transport_roads": "transport_roads", "public_services": "public_services",
	"industry_sites": "industry_sites"
}
const METRIC_WORD_FA = {
	"total":"کل", "count":"تعداد", "rate":"نرخ", "quality":"کیفیت", "coverage":"پوشش",
	"efficiency":"کارآمدی", "stability":"پایداری", "happiness":"شادی", "satisfaction":"رضایت",
	"trust":"اعتماد", "power":"قدرت", "readiness":"آمادگی", "budget":"بودجه", "share":"سهم",
	"growth":"رشد", "inflation":"تورم", "unemployment":"بیکاری", "debt":"بدهی", "gdp":"تولید داخلی",
	"population":"جمعیت", "health":"سلامت", "education":"آموزش", "water":"آب", "air":"هوا",
	"food":"غذا", "security":"امنیت", "public":"عمومی", "cyber":"سایبری", "pollution":"آلودگی",
	"carbon":"کربن", "green":"سبز", "energy":"انرژی", "infrastructure":"زیرساخت",
	"output":"خروجی", "production":"تولید", "productivity":"بهره‌وری", "capacity":"ظرفیت",
	"index":"شاخص", "revenue":"درآمد", "exports":"صادرات", "imports":"واردات", "balance":"تراز",
	"preparedness":"آمادگی", "response":"واکنش", "time":"زمان", "participation":"مشارکت",
	"facilities":"تأسیسات", "preservation":"حفاظت", "level":"سطح", "tension":"تنش",
	"diversity":"تنوع", "integration":"ادغام", "accuracy":"دقت", "digital":"دیجیتال",
	"risk":"ریسک", "access":"دسترسی", "cost":"هزینه", "price":"قیمت", "employment":"اشتغال",
	"income":"درآمد", "avg":"میانگین", "national":"ملی", "social":"اجتماعی", "military":"نظامی",
	"research":"پژوهش", "technology":"فناوری", "industry":"صنعت", "trade":"تجارت",
	"foreign":"خارجی", "local":"محلی", "government":"دولت", "market":"بازار", "human":"انسانی",
	"life":"زندگی", "expectancy":"امید", "crime":"جرم", "poverty":"فقر", "welfare":"رفاه",
	"spending":"هزینه‌کرد", "personnel":"پرسنل", "influence":"نفوذ", "soft":"نرم",
	"score":"امتیاز", "ratio":"نسبت", "reserve":"ذخیره", "reserves":"ذخایر", "value":"مقدار"
}

const TABS := [
	["dashboard", "🏠 داشبورد"],
	["economy", "💰 اقتصاد"],
	["population", "👥 جمعیت"],
	["military", "🪖 ارتش"],
	["world", "🌍 جهان"],
	["systems", "🏛️ سامانه‌ها"]
]

func _ready():
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	var app_theme = Theme.new()
	app_theme.default_font = PersianFont
	app_theme.default_font_size = 18
	theme = app_theme
	current_state = GameState.get_state_copy()
	_build_chrome()
	_switch_tab("dashboard")
	_refresh_header()
	GameEngine.tick_completed.connect(_on_tick_completed)
	GameEngine.tick_failed.connect(_on_tick_failed)
	P2PManager.state_snapshot_received.connect(_on_network_state_snapshot)
	P2PManager.network_status_changed.connect(_on_network_status_changed)
	P2PManager.network_error.connect(_on_network_error)
	print("رابط کاربری اصلی لود شد - شبیه‌ساز کشور")

# ============================================================
# قاب کلی: هدر + تب‌بار + محتوا + فوتر
# ============================================================
func _build_chrome():
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.08, 0.15)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24
	root.offset_right = -24
	root.offset_top = 24
	root.offset_bottom = -24
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	# --- هدر ---
	var header = VBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	root.add_child(header)

	header_title = Label.new()
	header_title.text = "🎮 شبیه‌ساز کشور — ۲۰۲۷"
	header_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_title.add_theme_font_size_override("font_size", 30)
	header.add_child(header_title)

	date_lbl = Label.new()
	date_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	date_lbl.add_theme_font_size_override("font_size", 18)
	date_lbl.modulate = Color(0.85, 0.85, 0.9)
	header.add_child(date_lbl)

	engagement_lbl = Label.new()
	engagement_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	engagement_lbl.add_theme_font_size_override("font_size", 16)
	engagement_lbl.modulate = Color(1.0, 0.85, 0.4)
	header.add_child(engagement_lbl)

	# --- تب‌بار ---
	var tabs_hbox = HBoxContainer.new()
	tabs_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs_hbox.add_theme_constant_override("separation", 8)
	root.add_child(tabs_hbox)

	for tab_def in TABS:
		var key = tab_def[0]
		var btn = Button.new()
		btn.text = tab_def[1]
		btn.custom_minimum_size = Vector2(150, 56)
		btn.add_theme_font_size_override("font_size", 17)
		btn.pressed.connect(FeedbackManager.play_click)
		btn.pressed.connect(_switch_tab.bind(key))
		tabs_hbox.add_child(btn)
		tab_buttons[key] = btn

	# --- محتوای تب (اسکرول) ---
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)

	# --- اعلان لحظه‌ای (Toast) ---
	toast_lbl = Label.new()
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.add_theme_font_size_override("font_size", 16)
	toast_lbl.modulate = Color(0.5, 1.0, 0.6)
	root.add_child(toast_lbl)

	# --- رویدادهای اخیر ---
	var ev_title = Label.new()
	ev_title.text = "📜 آخرین رویدادها"
	ev_title.add_theme_font_size_override("font_size", 18)
	root.add_child(ev_title)

	event_list = VBoxContainer.new()
	event_list.add_theme_constant_override("separation", 2)
	root.add_child(event_list)
	_render_events()

	# --- فوتر: کنترل‌ها ---
	var footer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 10)
	root.add_child(footer)

	_mk_btn(footer, "▶️ گام بعدی (۱ روز)", Vector2(220, 64), _on_next_tick_pressed)
	_mk_btn(footer, "⏸️ خودکار: خاموش", Vector2(190, 64), _on_auto_pressed, "AutoBtn")
	_mk_btn(footer, "💾 ذخیره", Vector2(120, 64), _on_save_pressed)
	_mk_btn(footer, "📂 بارگذاری", Vector2(130, 64), _on_load_pressed)
	_mk_btn(footer, "🔊 صدا", Vector2(110, 64), _on_sound_pressed, "SoundBtn")

func _mk_btn(parent, text, minsize, handler, node_name = ""):
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = minsize
	btn.add_theme_font_size_override("font_size", 17)
	btn.pressed.connect(FeedbackManager.play_click)
	btn.pressed.connect(handler)
	if node_name != "":
		btn.name = node_name
	parent.add_child(btn)
	return btn

# ============================================================
# سربرگ (تاریخ + امتیاز)
# ============================================================
func _refresh_header():
	var st = GameState.state
	var clock = st.get("clock", {})
	if header_title != null:
		header_title.text = "🎮 شبیه‌ساز کشور — %s" % str(st.get("country", {}).get("name", "کشور شما"))
	date_lbl.text = "📅 %s/%s/%s — %s" % [
		PersianFormatter.to_persian_digits(str(clock.get("year", 2027))),
		PersianFormatter.to_persian_digits("%02d" % clock.get("month", 1)),
		PersianFormatter.to_persian_digits("%02d" % clock.get("day", 1)),
		clock.get("season", "بهار")
	]
	var progression = st.get("progression", {})
	engagement_lbl.text = "🔥 روز %s | استریک %s | شتاب ×%s | %s\n⭐ امتیاز %s | 🏆 سطح %s | تجربه %s" % [
		PersianFormatter.to_persian_digits(str(st.get("tick", 0))),
		PersianFormatter.to_persian_digits(str(progression.get("streak", 0))),
		PersianFormatter.to_persian_digits(str(progression.get("combo", 1))),
		str(progression.get("stage", "دولت نوپا")),
		PersianFormatter.format_number(int(st.get("score", 0))),
		PersianFormatter.to_persian_digits(str(st.get("level", 1))),
		PersianFormatter.to_persian_digits("%.0f" % st.get("xp", 0.0))
	]

# ============================================================
# سوییچ تب
# ============================================================
func _switch_tab(tab_key: String):
	current_tab = tab_key
	for k in tab_buttons.keys():
		if k == tab_key:
			tab_buttons[k].modulate = Color(1.0, 0.9, 0.5)
		else:
			tab_buttons[k].modulate = Color(1, 1, 1)
	for c in content.get_children():
		c.queue_free()

	match tab_key:
		"dashboard": _build_dashboard()
		"economy": _build_economy()
		"population": _build_population()
		"military": _build_military()
		"world": _build_world()
		"systems": _build_systems()

# ============================================================
# ابزارهای ساخت سریع
# ============================================================
func _card(title: String) -> VBoxContainer:
	var panel = PanelContainer.new()
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	var t = Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 20)
	vbox.add_child(t)
	content.add_child(panel)
	return vbox

func _row(parent, key: String, value: String, value_color = null):
	var h = HBoxContainer.new()
	parent.add_child(h)
	var kl = Label.new()
	kl.text = key
	kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kl.add_theme_font_size_override("font_size", 16)
	h.add_child(kl)
	var vl = Label.new()
	vl.text = value
	vl.add_theme_font_size_override("font_size", 16)
	if value_color != null:
		vl.modulate = value_color
	h.add_child(vl)

func _bar(parent, title: String, ratio: float):
	var h = HBoxContainer.new()
	parent.add_child(h)
	var lbl = Label.new()
	lbl.text = title
	lbl.custom_minimum_size = Vector2(170, 0)
	lbl.add_theme_font_size_override("font_size", 15)
	h.add_child(lbl)
	var bar = ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = clamp(ratio * 100.0, 0, 100)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 26)
	bar.show_percentage = false
	h.add_child(bar)
	var pct = Label.new()
	pct.text = PersianFormatter.to_persian_digits("%d٪" % int(ratio * 100.0))
	pct.custom_minimum_size = Vector2(70, 0)
	pct.add_theme_font_size_override("font_size", 15)
	pct.modulate = _color_for(ratio)
	h.add_child(pct)

func _color_for(ratio: float) -> Color:
	if ratio >= 0.65:
		return Color(0.4, 1.0, 0.5)
	elif ratio >= 0.4:
		return Color(1.0, 0.85, 0.3)
	return Color(1.0, 0.45, 0.45)

func _fmt_pct(v) -> String:
	return PersianFormatter.to_persian_digits("%.0f٪" % (float(v) * 100.0))

# ============================================================
# تب داشبورد
# ============================================================
func _build_dashboard():
	var st = GameState.state
	var econ = st.get("economy", {})
	var pop = st.get("population", {})
	var pol = st.get("politics", {})
	var res = st.get("resources", {})
	var ind = st.get("indicators", {})

	# هشدار بحران‌ها
	var crises = _active_crises(st)
	if crises.size() > 0:
		var warn = _card("⚠️ هشدارهای فوری")
		for c in crises:
			var l = Label.new()
			l.text = "• " + c
			l.add_theme_font_size_override("font_size", 16)
			l.modulate = Color(1.0, 0.5, 0.5)
			warn.add_child(l)

	# رویدادهای راهبردی که منتظر تصمیم بازیکن‌اند.
	var pending_decisions: Array = st.get("pending_decisions", [])
	if not pending_decisions.is_empty():
		var decisions_card = _card("⚖️ تصمیم‌های فوری (%s)" % PersianFormatter.to_persian_digits(str(pending_decisions.size())))
		for i in range(min(pending_decisions.size(), 3)):
			_add_pending_decision(decisions_card, pending_decisions[i])

	# شورای هوش‌های تخصصی: مهم‌ترین مسئله‌ها را با دلیل و اقدام قابل اجرا پیشنهاد می‌دهد.
	var recommendations = AIAdvisor.get_top_recommendations(st, st.get("tick", 0), 4)
	var advisor_card = _card("🧠 شورای هوشمند کشور")
	if recommendations.is_empty():
		var calm = Label.new()
		calm.text = "در حال حاضر هشدار مهمی از سوی سامانه‌های تخصصی ثبت نشده است."
		calm.modulate = Color(0.5, 1.0, 0.65)
		advisor_card.add_child(calm)
	else:
		for recommendation in recommendations:
			_add_ai_recommendation(advisor_card, recommendation)

	var c1 = _card("📊 شاخص‌های کلان")
	_bar(c1, "شادی مردم", ind.get("happiness", 0.6))
	_bar(c1, "ثبات کشور", ind.get("stability", 0.6))
	_bar(c1, "رضایت عمومی", pop.get("satisfaction", 0.6))
	_bar(c1, "توسعه انسانی (HDI)", ind.get("hdi", 0.75))

	var c2 = _card("💵 وضعیت اقتصادی")
	_row(c2, "تولید ناخالص داخلی", PersianFormatter.format_money(econ.get("gdp", 0)))
	_row(c2, "تورم", _fmt_pct(econ.get("inflation", 0)), _color_for(1.0 - econ.get("inflation", 0) * 2.0))
	_row(c2, "بیکاری", _fmt_pct(econ.get("unemployment", 0)), _color_for(1.0 - econ.get("unemployment", 0) * 5.0))
	_row(c2, "نرخ مالیات", _fmt_pct(econ.get("tax_rate", 0.2)))

	var c3 = _card("📦 منابع حیاتی")
	var inv = res.get("inventory", {})
	for rname in ["غذا", "آب", "برق", "نفت"]:
		if inv.has(rname):
			var cap = res.get("capacity", {}).get(rname, 150.0)
			_bar(c3, rname, inv[rname] / cap)

	var c4 = _card("🏅 قدرت و اعتبار")
	_row(c4, "شاخص قدرت", PersianFormatter.format_number(int(ind.get("power_score", 0))))
	_row(c4, "سطح رهبری", PersianFormatter.to_persian_digits(str(st.get("level", 1))))

	var progress = st.get("progression", {})
	var c5 = _card("🏆 پیشرفت و دستاوردها")
	_row(c5, "مرحله کشور", str(progress.get("stage", "دولت نوپا")))
	_row(c5, "بهترین استریک", "%s روز" % PersianFormatter.to_persian_digits(str(progress.get("best_streak", 0))))
	_row(c5, "امتیاز میراث", PersianFormatter.to_persian_digits(str(progress.get("legacy_score", 0))))
	var achievements: Array = progress.get("achievements", [])
	_row(c5, "دستاوردهای بازشده", "%s از %s" % [
		PersianFormatter.to_persian_digits(str(achievements.size())),
		PersianFormatter.to_persian_digits("10")])
	if achievements.is_empty():
		var first_hint = Label.new()
		first_hint.text = "نخستین روز را کامل کنید تا اولین دستاورد باز شود."
		first_hint.modulate = Color(0.75, 0.8, 0.9)
		c5.add_child(first_hint)
	else:
		for i in range(max(0, achievements.size() - 3), achievements.size()):
			var achievement = achievements[i]
			var badge = Label.new()
			badge.text = "🏅 %s — %s" % [achievement.get("title", "دستاورد"), achievement.get("description", "")]
			badge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			badge.modulate = Color(1.0, 0.83, 0.35)
			c5.add_child(badge)

func _add_pending_decision(parent: VBoxContainer, decision: Dictionary):
	var panel = PanelContainer.new()
	parent.add_child(panel)
	var body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	panel.add_child(body)
	var title = Label.new()
	title.text = "🔔 " + str(decision.get("title", "تصمیم فوری"))
	title.add_theme_font_size_override("font_size", 18)
	title.modulate = Color(1.0, 0.82, 0.35)
	body.add_child(title)
	var description = Label.new()
	description.text = str(decision.get("description", ""))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(description)
	var remaining = max(0, int(decision.get("expires_tick", GameState.tick)) - GameState.tick)
	var deadline = Label.new()
	deadline.text = "مهلت تصمیم: %s روز" % PersianFormatter.to_persian_digits(str(remaining))
	deadline.modulate = Color(1.0, 0.65, 0.45)
	body.add_child(deadline)
	for choice in decision.get("choices", []):
		var choice_row = HBoxContainer.new()
		body.add_child(choice_row)
		var button = Button.new()
		button.text = str(choice.get("text", "انتخاب"))
		button.custom_minimum_size = Vector2(220, 48)
		button.pressed.connect(_on_decision_choice.bind(
			str(decision.get("id", "")), str(choice.get("id", "")), str(choice.get("text", ""))))
		choice_row.add_child(button)
		var consequence = Label.new()
		consequence.text = str(choice.get("consequence", ""))
		consequence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		consequence.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		consequence.modulate = Color(0.78, 0.82, 0.9)
		choice_row.add_child(consequence)

func _on_decision_choice(decision_id: String, choice_id: String, choice_title: String):
	var cmd = GameCommandClass.create_decision_resolve(decision_id, choice_id)
	if _run_tick_with([cmd]):
		_toast("⚖️ گزینه «%s» اجرا شد" % choice_title)
		_switch_tab("dashboard")

func _add_ai_recommendation(parent: VBoxContainer, recommendation: Dictionary):
	var box = HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	parent.add_child(box)
	var urgency = float(recommendation.get("urgency", 0.0))
	var text_box = VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(text_box)
	var title = Label.new()
	title.text = "⚠️ " + str(recommendation.get("title", "پیشنهاد تخصصی"))
	title.add_theme_font_size_override("font_size", 16)
	title.modulate = _color_for(1.0 - urgency)
	text_box.add_child(title)
	var reason = Label.new()
	reason.text = str(recommendation.get("reason", ""))
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason.modulate = Color(0.82, 0.85, 0.92)
	text_box.add_child(reason)
	if recommendation.has("command"):
		var apply = Button.new()
		apply.text = "اجرای پیشنهاد"
		apply.custom_minimum_size = Vector2(145, 48)
		apply.pressed.connect(_on_apply_ai_recommendation.bind(
			recommendation["command"], str(recommendation.get("title", "پیشنهاد"))))
		box.add_child(apply)

func _on_apply_ai_recommendation(command_data: Dictionary, title: String):
	var cmd = GameCommandClass.from_dict(command_data)
	# فراداده در زمان اجرا و مطابق نسخه جاری توسط موتور تکمیل می‌شود.
	cmd.tick = 0
	cmd.version = 0
	if _run_tick_with([cmd]):
		_toast("🧠 پیشنهاد «%s» اجرا شد" % title)
		_switch_tab("dashboard")

func _active_crises(st: Dictionary) -> Array:
	var out = []
	var res = st.get("resources", {})
	var econ = st.get("economy", {})
	var pop = st.get("population", {})
	var pol = st.get("politics", {})
	if res.get("food_crisis", false):
		out.append("بحران غذایی — ذخیره غذا رو به اتمام است")
	if res.get("energy_crisis", false):
		out.append("بحران انرژی — برق در آستانه خاموشی است")
	if econ.get("inflation", 0) > 0.25:
		out.append("تورم بالا — قیمت‌ها کنترل‌شده نیست")
	if econ.get("debt_to_gdp", 0) > 1.2:
		out.append("بحران بدهی — بدهی دولت از GDP گذشت")
	if pop.get("happiness", 1) < 0.35:
		out.append("نارضایتی عمومی — خطر اعتراض")
	if pol.get("tension", 0) > 0.7:
		out.append("تنش سیاسی شدید — ثبات در خطر است")
	return out

# ============================================================
# تب اقتصاد — تعاملی (مالیات + بودجه)
# ============================================================
func _build_economy():
	var st = GameState.state
	var econ = st.get("economy", {})

	# --- مالیات ---
	var c1 = _card("🧾 نرخ مالیات (تصمیم شما)")
	var h = HBoxContainer.new()
	c1.add_child(h)
	tax_slider = HSlider.new()
	tax_slider.min_value = 5
	tax_slider.max_value = 45
	tax_slider.step = 1
	tax_slider.value = econ.get("tax_rate", 0.2) * 100.0
	tax_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tax_slider.value_changed.connect(_on_tax_slider_changed)
	h.add_child(tax_slider)
	tax_value_lbl = Label.new()
	tax_value_lbl.text = _fmt_pct(econ.get("tax_rate", 0.2))
	tax_value_lbl.custom_minimum_size = Vector2(80, 0)
	h.add_child(tax_value_lbl)
	var apply_tax = _mk_btn(c1, "✅ اعمال مالیات جدید (۱ روز می‌گذرد)", Vector2(280, 52), _on_apply_tax)
	apply_tax.add_theme_font_size_override("font_size", 16)

	# --- بودجه ---
	var allocs = econ.get("budget_allocations", {})
	var c2 = _card("💼 تخصیص بودجه — جمع باید ۱۰۰٪ باشد")
	budget_sliders.clear()
	for k in allocs.keys():
		var row = HBoxContainer.new()
		c2.add_child(row)
		var kl = Label.new()
		kl.text = str(k)
		kl.custom_minimum_size = Vector2(110, 0)
		kl.add_theme_font_size_override("font_size", 15)
		row.add_child(kl)
		var s = HSlider.new()
		s.min_value = 1
		s.max_value = 40
		s.step = 1
		s.value = allocs[k] * 100.0
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.value_changed.connect(_on_budget_slider_changed.bind(k))
		row.add_child(s)
		var vl = Label.new()
		vl.text = _fmt_pct(allocs[k])
		vl.custom_minimum_size = Vector2(70, 0)
		vl.name = "BudgetVal_" + str(k)
		row.add_child(vl)
		budget_sliders[k] = s
	_mk_btn(c2, "✅ اعمال بودجه (۱ روز می‌گذرد)", Vector2(280, 52), _on_apply_budget)

	# --- آمار مالی ---
	var c3 = _card("📈 آمار مالی")
	_row(c3, "درآمد دولت", PersianFormatter.format_money(econ.get("government_revenue", 0)))
	_row(c3, "هزینه دولت", PersianFormatter.format_money(econ.get("government_spending", 0)))
	_row(c3, "تراز بودجه", PersianFormatter.format_money(econ.get("deficit", 0)),
		_color_for(0.5 + sign(-econ.get("deficit", 0)) * 0.5))
	_row(c3, "بدهی ملی", PersianFormatter.format_money(econ.get("national_debt", 0)))
	_bar(c3, "نسبت بدهی به GDP", clamp(econ.get("debt_to_gdp", 0) / 2.0, 0, 1))

# ============================================================
# تب جمعیت
# ============================================================
func _build_population():
	var st = GameState.state
	var pop = st.get("population", {})

	var c1 = _card("👥 جمعیت")
	_row(c1, "جمعیت کل", PersianFormatter.format_large(pop.get("total", 0)) + " نفر")
	_row(c1, "نرخ رشد روزانه", PersianFormatter.to_persian_digits("%.4f٪" % (pop.get("growth_rate", 0) * 100)))
	_row(c1, "تولد (سالانه در هزار)", PersianFormatter.to_persian_digits("%.1f" % pop.get("birth_rate", 0)))
	_row(c1, "مرگ (سالانه در هزار)", PersianFormatter.to_persian_digits("%.1f" % pop.get("death_rate", 0)))
	_row(c1, "مهاجرت خالص", PersianFormatter.to_persian_digits(str(int(pop.get("migration_net", 0)))))

	var c2 = _card("😊 احوال مردم")
	_bar(c2, "شادی", pop.get("happiness", 0.6))
	_bar(c2, "رضایت", pop.get("satisfaction", 0.6))
	_bar(c2, "شهرنشینی", pop.get("urban_ratio", 0.75))

	var c3 = _card("📊 ساختار سنی")
	var ages = pop.get("age_structure", {})
	for a in ages.keys():
		_bar(c3, str(a), ages[a])

	var welfare = st.get("welfare", {})
	var c4 = _card("🛟 رفاه")
	_bar(c4, "فقر (کمتر بهتر)", 1.0 - welfare.get("poverty", 0.15))
	_bar(c4, "نابرابری معکوس", 1.0 - welfare.get("gini", 0.38))

# ============================================================
# تب ارتش
# ============================================================
func _build_military():
	var st = GameState.state
	var mil = st.get("military", {})

	var c1 = _card("🪖 ارتش و دفاع")
	_row(c1, "قدرت نظامی", PersianFormatter.format_number(int(mil.get("power", 0))))
	_row(c1, "پرسنل", PersianFormatter.format_large(mil.get("personnel", 0)) + " نفر")
	_bar(c1, "آمادگی رزمی", mil.get("readiness", 0.7))
	_bar(c1, "بازدارندگی", mil.get("deterrence", 60) / 100.0)
	_bar(c1, "سهم بودجه", mil.get("budget_share", 0.08) * 3.0)

	var c2 = _card("⚔️ نیروها")
	var branches = mil.get("branches", {})
	for b in branches.keys():
		_bar(c2, str(b), branches[b])

	var intel = st.get("intelligence", {})
	var c3 = _card("🕵️ اطلاعات")
	_bar(c3, "قدرت اطلاعاتی", intel.get("power", 50) / 100.0)
	_bar(c3, "آمادگی سایبری", intel.get("cyber_readiness", 0.5))

# ============================================================
# تب جهان — دیپلماسی تعاملی
# ============================================================
func _build_world():
	var st = GameState.state
	var dip = st.get("diplomacy", {})
	var rel: Dictionary = dip.get("relations", {})
	var world: Dictionary = st.get("world", {})
	var player_id = str(world.get("player_country", WorldManager.default_country))
	if selected_world_country == "" or not rel.has(selected_world_country):
		selected_world_country = str(rel.keys()[0]) if not rel.is_empty() else ""

	if int(st.get("tick", 0)) == 0:
		var setup = _card("🏳️ انتخاب کشور پیش از شروع")
		var setup_hint = Label.new()
		setup_hint.text = "کشور، جمعیت، اقتصاد، قدرت نظامی، فناوری و روابط آغازین را تعیین می‌کند. پس از نخستین روز قابل تغییر نیست."
		setup_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		setup.add_child(setup_hint)
		country_select_option = OptionButton.new()
		var selected_index = 0
		for country_id in WorldManager.get_country_ids():
			var profile = WorldManager.get_country(country_id)
			country_select_option.add_item("%s — %s" % [profile.get("name_fa", country_id), profile.get("capital_fa", "")])
			country_select_option.set_item_metadata(country_select_option.item_count - 1, country_id)
			if country_id == player_id:
				selected_index = country_select_option.item_count - 1
		country_select_option.select(selected_index)
		setup.add_child(country_select_option)
		_mk_btn(setup, "شروع بازی با کشور انتخابی", Vector2(280, 52), _on_country_start_selected)

	var player_profile = WorldManager.get_country(player_id)
	var identity = _card("🏛️ کشور شما: %s" % str(player_profile.get("name_fa", "")))
	_row(identity, "پایتخت", str(player_profile.get("capital_fa", "")))
	_row(identity, "واحد پول", str(player_profile.get("currency_fa", "")))
	_row(identity, "جمعیت پایه", PersianFormatter.format_large(float(player_profile.get("population", 0))) + " نفر")
	_row(identity, "تولید داخلی پایه", PersianFormatter.format_money(float(player_profile.get("gdp", 0))))

	var map_card = _card("🗺️ نقشه تعاملی ۱۶ کشور")
	var map_countries: Dictionary = world.get("countries", {}).duplicate(true)
	for war_target in world.get("wars", {}).keys():
		if map_countries.has(war_target):
			map_countries[war_target]["at_war"] = true
	var world_map = WorldMapClass.new()
	world_map.selected_code = selected_world_country
	world_map.set_world(map_countries, rel, player_id)
	world_map.country_selected.connect(_on_map_country_selected)
	map_card.add_child(world_map)

	var overview = _card("🌍 موقعیت بین‌المللی")
	_row(overview, "امتیاز اقدام دیپلماتیک", PersianFormatter.to_persian_digits("%.1f از 5" % dip.get("action_points", 0.0)))
	_row(overview, "نفوذ جهانی", PersianFormatter.format_number(int(dip.get("influence", 0))))
	_bar(overview, "قدرت نرم", dip.get("soft_power", 35) / 100.0)
	_row(overview, "جنگ‌های فعال", PersianFormatter.to_persian_digits(str(world.get("wars", {}).size())))

	if selected_world_country != "":
		_build_selected_country_card(st, selected_world_country)

	var directory = _card("🤝 فهرست روابط")
	var relation_grid = GridContainer.new()
	relation_grid.columns = 2
	directory.add_child(relation_grid)
	for country in rel.keys():
		var rv = float(rel[country])
		var relation_button = Button.new()
		relation_button.text = "%s — %s (%s)" % [
			_fa_country(country), PersianFormatter.to_persian_digits("%.0f" % rv), _relation_word(rv)]
		relation_button.modulate = _color_for(rv / 100.0)
		relation_button.pressed.connect(FeedbackManager.play_click)
		relation_button.pressed.connect(_on_map_country_selected.bind(country))
		relation_grid.add_child(relation_button)

	var sanctions = dip.get("sanctions", [])
	var treaties = dip.get("treaties", [])
	var records = _card("📜 پیمان‌ها و تحریم‌ها")
	if sanctions.is_empty() and treaties.is_empty():
		var none = Label.new()
		none.text = "هنوز پیمان یا تحریمی ثبت نشده است."
		records.add_child(none)
	for sanction in sanctions:
		var sanction_label = Label.new()
		if sanction is Dictionary:
			var direction = "اعمال‌شده توسط شما" if sanction.get("by", "") == "player" else "اعمال‌شده علیه شما"
			sanction_label.text = "🚫 %s — %s" % [_fa_country(str(sanction.get("target", ""))), direction]
		else:
			sanction_label.text = "🚫 تحریم خارجی"
		sanction_label.modulate = Color(1.0, 0.5, 0.5)
		records.add_child(sanction_label)
	for treaty in treaties:
		var treaty_label = Label.new()
		if treaty is Dictionary:
			treaty_label.text = "🤝 اتحاد با %s" % _fa_country(str(treaty.get("target", "")))
		else:
			treaty_label.text = "🤝 " + str(treaty)
		records.add_child(treaty_label)

	var network = _card("🌐 چندنفره مستقیم و رایگان")
	var hint = Label.new()
	hint.text = "یک بازیکن میزبان می‌شود؛ دیگران با IP مستقیم یا IP شبکه محلی متصل می‌شوند. پردازش مرجع روی میزبان است."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(0.78, 0.82, 0.9)
	network.add_child(hint)
	network_status_lbl = Label.new()
	network.add_child(network_status_lbl)
	var connection_row = HBoxContainer.new()
	network.add_child(connection_row)
	network_address_edit = LineEdit.new()
	network_address_edit.placeholder_text = "نشانی میزبان؛ نمونه: ۱۹۲.۱۶۸.۱.۱۰"
	network_address_edit.text = "127.0.0.1"
	network_address_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	connection_row.add_child(network_address_edit)
	network_port_spin = SpinBox.new()
	network_port_spin.min_value = 1024
	network_port_spin.max_value = 65535
	network_port_spin.value = P2PManager.DEFAULT_PORT
	network_port_spin.custom_minimum_size = Vector2(150, 0)
	connection_row.add_child(network_port_spin)
	var network_buttons = HBoxContainer.new()
	network_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	network.add_child(network_buttons)
	_mk_btn(network_buttons, "میزبانی بازی", Vector2(155, 48), _on_host_network)
	_mk_btn(network_buttons, "اتصال به میزبان", Vector2(175, 48), _on_join_network)
	_mk_btn(network_buttons, "بازکردن خودکار پورت", Vector2(190, 48), _on_enable_upnp)
	_mk_btn(network_buttons, "قطع اتصال", Vector2(145, 48), _on_disconnect_network)
	_refresh_network_status()

func _build_selected_country_card(state: Dictionary, target: String):
	var profile = state.get("world", {}).get("countries", {}).get(target, WorldManager.get_country(target))
	var relation = float(state.get("diplomacy", {}).get("relations", {}).get(target, 50.0))
	var card = _card("🎯 کشور انتخابی: %s" % _fa_country(target))
	_row(card, "رابطه", "%s — %s" % [PersianFormatter.to_persian_digits("%.0f" % relation), _relation_word(relation)], _color_for(relation / 100.0))
	_row(card, "تولید داخلی", PersianFormatter.format_money(float(profile.get("gdp", 0.0))))
	_row(card, "قدرت نظامی", PersianFormatter.to_persian_digits("%.1f" % profile.get("military_power", 0.0)))
	_bar(card, "سطح فناوری", float(profile.get("tech_level", 0.0)))
	var wars: Dictionary = state.get("world", {}).get("wars", {})
	if wars.has(target):
		var war = wars[target]
		var progress = float(war.get("progress", 0.0))
		_row(card, "پیشروی جنگ", PersianFormatter.to_persian_digits("%+.1f" % progress), _color_for((progress + 100.0) / 200.0))
		_row(card, "تلفات نیروهای شما", PersianFormatter.format_large(float(war.get("player_losses", 0))))
		_row(card, "تلفات دشمن", PersianFormatter.format_large(float(war.get("enemy_losses", 0))))
	var action_grid = GridContainer.new()
	action_grid.columns = 3
	card.add_child(action_grid)
	var actions = [
		["improve_relations", "بهبود روابط"], ["trade_agreement", "توافق تجاری"],
		["form_alliance", "تشکیل اتحاد"], ["sanction", "اعمال تحریم"],
		["lift_sanction", "لغو تحریم"], ["declare_war", "اعلام جنگ"],
		["offer_peace", "پیشنهاد صلح"]
	]
	for action_def in actions:
		var check = WorldManager.can_action(state, target, action_def[0])
		var button = Button.new()
		button.text = action_def[1]
		button.custom_minimum_size = Vector2(180, 48)
		button.disabled = not check.valid
		button.tooltip_text = "" if check.valid else str(check.reason)
		if action_def[0] == "declare_war":
			button.modulate = Color(1.0, 0.55, 0.55)
		button.pressed.connect(FeedbackManager.play_click)
		button.pressed.connect(_on_world_action.bind(target, action_def[0], action_def[1]))
		action_grid.add_child(button)

func _on_country_start_selected():
	if country_select_option == null or country_select_option.item_count == 0:
		return
	var country_id = str(country_select_option.get_item_metadata(country_select_option.selected))
	var cmd = GameCommandClass.create_country_select(country_id)
	if _run_tick_with([cmd]):
		selected_world_country = ""
		_toast("🏳️ بازی با کشور %s آغاز شد" % WorldManager.get_country_name(country_id))
		_switch_tab("world")

func _on_map_country_selected(code: String):
	selected_world_country = code
	var relation = GameState.state.get("diplomacy", {}).get("relations", {}).get(code, 0)
	_toast("🗺️ %s — رابطه: %s (%s)" % [
		_fa_country(code), _relation_word(relation), PersianFormatter.to_persian_digits("%.0f" % relation)])
	_switch_tab("world")

func _on_world_action(country: String, action: String, action_title: String):
	var cmd = GameCommandClass.create_diplomacy_action(country, action)
	if _run_tick_with([cmd]):
		_toast("🌍 «%s» درباره %s اجرا شد" % [action_title, _fa_country(country)])
		_switch_tab("world")

func _fa_country(code: String) -> String:
	return WorldManager.get_country_name(code)

func _relation_word(v) -> String:
	if v >= 75: return "متحد"
	if v >= 55: return "دوستانه"
	if v >= 35: return "خنثی"
	if v >= 15: return "متشنج"
	return "متخاصم"

func _on_host_network():
	var result = P2PManager.host_game(int(network_port_spin.value))
	if result.success:
		_toast("🌐 میزبان چندنفره فعال شد؛ پورت " + PersianFormatter.to_persian_digits(str(result.port)))
	else:
		_toast("⚠️ " + str(result.reason))
	_refresh_network_status()

func _on_join_network():
	var result = P2PManager.join_game(network_address_edit.text, int(network_port_spin.value))
	if result.success:
		_toast("🌐 درخواست اتصال ارسال شد")
	else:
		_toast("⚠️ " + str(result.reason))
	_refresh_network_status()

func _on_enable_upnp():
	_toast("در حال بررسی روتر برای بازکردن خودکار پورت…")
	var result = P2PManager.try_upnp_port_mapping()
	if result.success:
		_toast("✅ پورت خودکار باز شد: %s:%s" % [
			str(result.external_address), PersianFormatter.to_persian_digits(str(result.port))])
	else:
		_toast("⚠️ " + str(result.reason))
	_refresh_network_status()

func _on_disconnect_network():
	P2PManager.disconnect_game()
	_toast("اتصال بسته شد؛ بازی در حالت تک‌نفره است")
	_refresh_network_status()

func _refresh_network_status():
	if network_status_lbl == null or not is_instance_valid(network_status_lbl):
		return
	var status = P2PManager.get_status()
	var mode_text = "تک‌نفره"
	if status.mode == "host":
		mode_text = "میزبان"
	elif status.mode == "client":
		mode_text = "متصل‌شونده"
	network_status_lbl.text = "وضعیت: %s | بازیکنان: %s | پورت: %s" % [
		mode_text,
		PersianFormatter.to_persian_digits(str(status.peers)),
		PersianFormatter.to_persian_digits(str(status.port if status.port > 0 else P2PManager.DEFAULT_PORT))
	]
	if status.get("upnp_mapped", false):
		network_status_lbl.text += " | نشانی عمومی: %s" % str(status.get("external_address", ""))

func _on_network_status_changed(_status: Dictionary):
	_refresh_network_status()

func _on_network_error(message: String):
	_toast("⚠️ شبکه: " + message)
	_refresh_network_status()

func _on_network_state_snapshot(state: Dictionary, version: int, tick: int):
	if version <= GameState.version:
		return
	GameState.set_state(state, version, tick)
	_refresh_header()
	_render_events()
	_switch_tab(current_tab)
	_toast("🌐 وضعیت روز %s از میزبان همگام شد" % PersianFormatter.to_persian_digits(str(tick)))

# ============================================================
# تب سامانه‌ها — نمای کلی ۶۵ سیستم
# ============================================================
func _build_systems():
	var c1 = _card("🏛️ مرکز پایش ۶۵ سامانه")
	var ai_summary = AIAdvisor.get_health_summary(GameState.state, GameState.tick)
	_row(c1, "هوش‌های تخصصی فعال", PersianFormatter.to_persian_digits(str(ai_summary.get("agents", 0))))
	_bar(c1, "سلامت میانگین سامانه‌ها", ai_summary.get("health", 0.0))
	_row(c1, "هشدارهای بحرانی", PersianFormatter.to_persian_digits(str(ai_summary.get("critical", 0))),
		_color_for(1.0 - min(float(ai_summary.get("critical", 0)) / 10.0, 1.0)))

	_build_system_detail(selected_system)

	var directory = _card("📚 انتخاب سامانه برای مشاهده جزئیات")
	var diagnoses: Array = AIAdvisor.analyze(GameState.state, GameState.tick)
	var health_by_ai: Dictionary = {}
	for diagnosis in diagnoses:
		health_by_ai[str(diagnosis.get("system", ""))] = float(diagnosis.get("health", 0.5))
	var grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	directory.add_child(grid)
	for sys_name in GameEngine.system_order:
		if not GameEngine.systems.has(sys_name):
			continue
		var ai_key = SYSTEM_AI_ALIASES.get(sys_name, sys_name)
		var health = float(health_by_ai.get(ai_key, 0.5))
		var button = Button.new()
		button.text = ("◀ " if sys_name == selected_system else "") + SYSTEM_FA.get(sys_name, "سامانه تخصصی")
		button.custom_minimum_size = Vector2(0, 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.modulate = _color_for(health)
		button.pressed.connect(_on_system_selected.bind(sys_name))
		grid.add_child(button)

func _on_system_selected(system_name: String):
	selected_system = system_name
	_switch_tab("systems")

func _build_system_detail(system_name: String):
	var title = SYSTEM_FA.get(system_name, "سامانه تخصصی")
	var detail = _card("🔎 جزئیات «%s»" % title)
	var ai_key = SYSTEM_AI_ALIASES.get(system_name, system_name)
	var agent = AIAdvisor.agents.get(ai_key, null)
	if agent != null and agent.has_method("diagnose"):
		var diagnosis: Dictionary = agent.diagnose(GameState.state)
		if not diagnosis.is_empty():
			_bar(detail, "سلامت سامانه", diagnosis.get("health", 0.5))
			var explanation = Label.new()
			explanation.text = str(diagnosis.get("reason", ""))
			explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			explanation.modulate = _color_for(1.0 - float(diagnosis.get("urgency", 0.0)))
			detail.add_child(explanation)
	var state_key = SYSTEM_STATE_ALIASES.get(system_name, system_name)
	var data = GameState.state.get(state_key, {})
	if not data is Dictionary or data.is_empty():
		var unavailable = Label.new()
		unavailable.text = "داده تفصیلی این سامانه پس از نخستین گام شبیه‌سازی آماده می‌شود."
		detail.add_child(unavailable)
		return
	var shown = 0
	for key in data.keys():
		if shown >= 18:
			break
		var value = data[key]
		if value is Dictionary:
			var section = Label.new()
			section.text = "▸ " + _metric_name_fa(str(key))
			section.add_theme_font_size_override("font_size", 17)
			section.modulate = Color(0.55, 0.82, 1.0)
			detail.add_child(section)
			for nested_key in value.keys():
				if shown >= 18:
					break
				if not value[nested_key] is Dictionary:
					_row(detail, _metric_name_fa(str(nested_key)), _format_metric_value(value[nested_key], str(nested_key)))
					shown += 1
		elif value is Array:
			_row(detail, _metric_name_fa(str(key)), "%s مورد" % PersianFormatter.to_persian_digits(str(value.size())))
			shown += 1
		else:
			_row(detail, _metric_name_fa(str(key)), _format_metric_value(value, str(key)))
			shown += 1
	if data.size() > shown:
		var more = Label.new()
		more.text = "و %s شاخص تکمیلی دیگر" % PersianFormatter.to_persian_digits(str(max(0, data.size() - shown)))
		more.modulate = Color(0.7, 0.72, 0.8)
		detail.add_child(more)

func _metric_name_fa(key: String) -> String:
	var clean = key.replace("_", " ")
	# کلیدهایی که از ابتدا فارسی‌اند بدون تغییر نمایش داده می‌شوند.
	for i in range(clean.length()):
		if clean.unicode_at(i) > 127:
			return clean
	var translated: Array = []
	for token in clean.split(" "):
		translated.append(METRIC_WORD_FA.get(token.to_lower(), "شاخص"))
	return " ".join(translated)

func _format_metric_value(value, key: String) -> String:
	if value is bool:
		return "بله" if value else "خیر"
	if value == null:
		return "ثبت نشده"
	if value is int or value is float:
		var number = float(value)
		var lower = key.to_lower()
		var money_words = ["gdp", "revenue", "debt", "spending", "cost", "fund", "income", "balance", "exports", "imports"]
		for word in money_words:
			if lower.contains(word):
				return PersianFormatter.format_money(number)
		if number >= 0.0 and number <= 1.0:
			return PersianFormatter.format_percent(number)
		if abs(number) >= 10000.0:
			return PersianFormatter.format_large(number)
		return PersianFormatter.to_persian_digits("%.2f" % number)
	return PersianFormatter.to_persian_digits(str(value).replace("_", " "))

# ============================================================
# رویدادها
# ============================================================
func _render_events():
	for c in event_list.get_children():
		c.queue_free()
	var last = EventLog.get_last(6)
	last.reverse()
	for e in last:
		var l = Label.new()
		l.text = "• " + _event_text_fa(e)
		l.add_theme_font_size_override("font_size", 14)
		l.modulate = Color(0.85, 0.88, 0.95)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		event_list.add_child(l)

func _event_text_fa(event: Dictionary) -> String:
	var event_type = str(event.get("type", ""))
	var data: Dictionary = event.get("data", {})
	if event_type == "system_event":
		var detail: Dictionary = data.get("event", {})
		if detail.has("message"):
			return str(detail["message"])
		var system_name = SYSTEM_FA.get(str(data.get("system", "")), "یکی از سامانه‌ها")
		return "رویداد تازه در سامانه «%s» ثبت شد" % system_name
	if data.has("message"):
		return str(data["message"])
	if data.has("reason"):
		return str(data["reason"])
	var translations = {
		"tick_success": "محاسبات روز با موفقیت انجام شد",
		"tick_rollback": "محاسبات روز بازگردانی شد",
		"tick_failed_validation": "یک فرمان نامعتبر رد شد",
		"command_applied": "تصمیم جدید دولت اعمال شد",
		"save": "بازی ذخیره شد",
		"load": "بازی بارگذاری شد"
	}
	return translations.get(event_type, "یک رویداد جدید ثبت شد")

func _toast(msg: String):
	toast_lbl.text = msg
	await get_tree().create_timer(2.5).timeout
	toast_lbl.text = ""

# ============================================================
# تعامل‌ها
# ============================================================
func _on_tax_slider_changed(v: float):
	tax_value_lbl.text = PersianFormatter.to_persian_digits("%d٪" % int(v))

func _on_budget_slider_changed(v: float, key):
	var lbl = content.find_child("BudgetVal_" + str(key), true, false)
	if lbl:
		lbl.text = PersianFormatter.to_persian_digits("%d٪" % int(v))

func _on_apply_tax():
	var rate = tax_slider.value / 100.0
	var cmd = GameCommandClass.create_tax_set(rate)
	var ok = _run_tick_with([cmd])
	if ok:
		_toast("🧾 مالیات جدید اعمال شد: " + PersianFormatter.to_persian_digits("%d٪" % int(tax_slider.value)))
		_switch_tab("economy")

func _on_apply_budget():
	# نرمال‌سازی به ۱۰۰٪
	var raw = {}
	var total = 0.0
	for k in budget_sliders.keys():
		raw[k] = budget_sliders[k].value
		total += raw[k]
	if total <= 0:
		return
	var allocs = {}
	for k in raw.keys():
		allocs[k] = raw[k] / total
	var cmd = GameCommandClass.create_budget_allocate(allocs)
	var ok = _run_tick_with([cmd])
	if ok:
		_toast("💼 بودجه‌ی جدید اعمال شد")
		_switch_tab("economy")

# ============================================================
# کنترل‌های فوتر
# ============================================================
func _on_next_tick_pressed():
	_run_tick_with([])

func _on_auto_pressed():
	auto_tick = !auto_tick
	var btn = find_child("AutoBtn", true, false)
	if btn:
		btn.text = "▶️ خودکار: روشن" if auto_tick else "⏸️ خودکار: خاموش"

func _on_sound_pressed():
	var is_muted = FeedbackManager.toggle_mute()
	var btn = find_child("SoundBtn", true, false)
	if btn:
		btn.text = "🔇 صدا" if is_muted else "🔊 صدا"
	if not is_muted:
		FeedbackManager.play_success()

func _on_save_pressed():
	if P2PManager.is_network_active() and not P2PManager.is_host:
		_toast("⚠️ فقط میزبان می‌تواند بازی چندنفره را ذخیره کند")
		return
	var result = SaveManager.save_game()
	if result.success:
		_toast("💾 بازی با بررسی صحت و نسخه پشتیبان ذخیره شد")
	else:
		_toast("⚠️ " + str(result.get("reason", "ذخیره ناموفق بود")))

func _on_load_pressed():
	if P2PManager.is_network_active() and not P2PManager.is_host:
		_toast("⚠️ فقط میزبان می‌تواند ذخیره چندنفره را بارگذاری کند")
		return
	var result = SaveManager.load_game()
	if not result.success:
		_toast("⚠️ " + str(result.get("reason", "بارگذاری ناموفق بود")))
		return
	var migration_note = " — ذخیره قدیمی ارتقا یافت" if result.get("migrated", false) else ""
	_toast("📂 بازی بارگذاری شد — روز %s%s" % [
		PersianFormatter.to_persian_digits(str(GameState.tick)), migration_note])
	_refresh_header()
	_render_events()
	_switch_tab(current_tab)

# ============================================================
# هسته تیک
# ============================================================
func _run_tick_with(player_cmds: Array) -> bool:
	# کلاینت فقط فرمان را می‌فرستد؛ محاسبه و Commit منحصراً روی میزبان انجام می‌شود.
	if P2PManager.is_network_active() and not P2PManager.can_advance_tick():
		if player_cmds.is_empty():
			_toast("⏳ فقط میزبان می‌تواند روز بعد را اجرا کند")
			return true
		for cmd in player_cmds:
			if not P2PManager.send_command(cmd):
				return false
		_toast("📡 تصمیم برای تأیید به میزبان ارسال شد")
		return true

	var cmds: Array = []
	cmds.append_array(P2PManager.get_pending_commands())
	cmds.append_array(player_cmds)
	cmds.append(GameCommandClass.create_next_tick())

	var result = GameEngine.tick(GameState.state, GameState.version, GameState.tick, cmds)
	if result.success:
		GameState.set_state(result.state, result.version, result.tick)
		P2PManager.broadcast_state(result.state, result.version, result.tick)
		_refresh_header()
		_render_events()
		# بازخورد دیداری و صوتی رویه‌ای (۳.۲۳۴)
		_engagement_pulse()
		FeedbackManager.play_success()
		return true
	else:
		FeedbackManager.play_alert()
		_toast("⚠️ " + str(result.get("reason", "خطا")))
		return false

func _engagement_pulse():
	var tw = create_tween()
	tw.tween_property(engagement_lbl, "scale", Vector2(1.15, 1.15), 0.1)
	tw.tween_property(engagement_lbl, "scale", Vector2(1.0, 1.0), 0.15)

func _process(delta):
	if auto_tick:
		tick_timer += delta
		if tick_timer > 1.0:
			tick_timer = 0.0
			_run_tick_with([])

func _on_tick_completed(new_state, events):
	current_state = new_state.duplicate(true)
	for event in events:
		if str(event.get("type", "")) == "achievement_unlocked":
			FeedbackManager.play_achievement()
			break

func _on_tick_failed(reason):
	print("خطای تیک: %s" % reason)
