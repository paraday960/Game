extends Control
# UI اصلی بازی - فارسی ۱۰۰٪ (قانون ۶) - چندتب تعاملی
# همه‌ی اعداد با ارقام فارسی، همه‌ی فرمان‌ها از طریق موتور اتمی (۳.۶)

const GameCommandClass = preload("res://scripts/core/command.gd")
const NpcTurnManagerClass = preload("res://scripts/core/npc_turn_manager.gd")
const UnifiedMapClass = preload("res://scripts/ui/unified_map.gd")
const CommandBackgroundClass = preload("res://scripts/ui/command_background.gd")
const CommandPaletteClass = preload("res://scripts/ui/command_palette.gd")
const ToastStackClass = preload("res://scripts/ui/toast_stack.gd")
const TouchScrollClass = preload("res://scripts/ui/touch_scroll_container.gd")
const TrendChartClass = preload("res://scripts/ui/trend_chart.gd")
const PersianFont = preload("res://assets/fonts/Vazirmatn-Regular.ttf")
const EmblemArt = preload("res://assets/art/emblem_sigil.png")
const HeroBannerArt = preload("res://assets/art/hero_world_banner.jpg")

# ---------- وضعیت UI ----------
var auto_tick: bool = false
var tick_timer: float = 0.0
var toast_generation: int = 0
var pending_delete_slot: int = 0
var new_game_confirmation: bool = false
var rewind_confirmation: bool = false
var current_tab: String = "map"
var current_state: Dictionary = {}
var selected_system: String = "economy"
var selected_world_country: String = ""
var map_base_layer: String = "political"
var map_overlays: Dictionary = {"wars":true,"alliances":true,"trade":true,"air":false,"sea":false,"land":false,"cities":true,"transport":true,"intelligence":false,"supply":true,"battle_plans":true,"constructions":true}
var map_advanced_mode: String = "select" # select, battle_plan, build_road, build_rail, build_fort, build_depot, build_airfield, build_radar
var map_advanced_start_country: String = ""
var map_advanced_start_unit: String = ""
var _comparison_unit_a: String = ""
var _comparison_unit_b: String = ""
var _comparison_country_a: String = ""
var _comparison_country_b: String = ""
var map_camera_center := Vector2(0.5, 0.5)
var map_zoom := 1.0
var selected_country_unit: String = ""
var selected_map_route: Dictionary = {}
var current_unified_map: Control
var country_select_option: OptionButton
var country_picker_btn: Button
var country_picker_overlay: Control
var scenario_select_option: OptionButton
var scenario_picker_btn: Button
var scenario_picker_overlay: Control
var scenario_description_lbl: Label
var app_theme: Theme
var background_rect: Control
var gdp_status_lbl: Label
var approval_status_lbl: Label
var stability_status_lbl: Label
var alert_status_lbl: Label
var chrome_root: VBoxContainer
var status_grid: GridContainer
var content_scroll: ScrollContainer
var map_context_host: VBoxContainer
var map_overlay_grid: GridContainer
var map_control_flow: HFlowContainer
var command_palette: Control
var toast_stack: VBoxContainer
var simulation_overlay: Control
var simulation_progress: ProgressBar
var simulation_status_lbl: Label
var simulation_busy := false
var page_generation := 0

# ---------- ارجاع‌های گره ----------
var content: VBoxContainer
var engagement_lbl: Label
var date_lbl: Label
var header_title: Label
var tab_buttons: Dictionary = {}
var event_list: VBoxContainer
var toast_lbl: Label
var network_address_edit: LineEdit
var network_player_name_edit: LineEdit
var network_port_spin: SpinBox
var network_status_lbl: Label
var campaign_lobby_lbl: Label
var turn_waiting_dialog: AcceptDialog
var turn_waiting_list: VBoxContainer
var chat_panel: PanelContainer
var chat_log: RichTextLabel
var chat_input: LineEdit
var chat_dock_btn: Button
var tax_vat_slider: HSlider
var ev_charge_bar: ProgressBar
var ht_quality_bar: ProgressBar
var defense_industry_bar: ProgressBar
var knowledge_businesses_lbl: Label
var recycling_rate_lbl: Label

# ── سیستم طراحی «اتاق فرمان» — الهام از HOI4 / EU4 / Power & Revolution ──
const ACCENT_GOLD = Color(0.93, 0.74, 0.33)
const ACCENT_TEAL = Color(0.24, 0.86, 0.80)
const ACCENT_BLUE = Color(0.42, 0.68, 1.00)
const ACCENT_GREEN = Color(0.38, 0.87, 0.56)
const ACCENT_RED = Color(0.97, 0.42, 0.37)
const ACCENT_ORANGE = Color(0.99, 0.68, 0.26)
const TEXT_MAIN = Color(0.91, 0.95, 0.98)
const TEXT_MUTED = Color(0.61, 0.73, 0.81)
const TEXT_FAINT = Color(0.45, 0.57, 0.67)

var nav_row: HBoxContainer
var drawer_overlay: Control
var drawer_sheet: PanelContainer
var drawer_open := false
var map_wrap: Control
var map_veil: ColorRect
var map_fab_col: VBoxContainer
var top_spacer: Control
var hero_overlay: Control
var map_mode := false
var ticker_panel: PanelContainer
var time_dock: PanelContainer

# ── صف تصمیم‌های نوبت: همه تصمیم‌های بازیکن ثبت می‌شوند و با «پایان نوبت» یکجا اجرا می‌شوند ──
var queued_commands: Array = []
var queued_labels: Array = []
var queue_btn: Button
var queue_panel: Control
var queue_panel_visible := false
var turn_report_overlay: Control
var _show_report_after_tick := false
var _last_turn_labels: Array = []
var _report_open := false
var remote_code_edit: LineEdit
var remote_code_lbl: Label
var remote_upnp_lbl: Label

# مقادیر میانی فرمان‌های تعاملی
var tax_slider: HSlider
var tax_value_lbl: Label
var interest_slider: HSlider
var inflation_target_slider: HSlider
var tariff_slider: HSlider
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

# ================= معماری اطلاعاتی یکپارچه (۸ حوزه اصلی) =================
# همه اطلاعات نمایشی (سامانه‌ها، لنزهای نقشه، جست‌وجو) از همین ساختار پیروی می‌کنند
# تا نمایش و دسترسی در کل بازی منطقی، منسجم و سریع باشد.
const SYSTEM_GROUPS := [
	["🏛️ حاکمیت و سیاست", [
		"politics", "judicial", "elections", "administration", "statistics", "prison", "political_career", "quantitative"]],
	["💰 اقتصاد و دارایی", [
		"economy", "central_bank", "stock_market", "trade", "tourism", "hospitality", "retail",
		"financial_services", "industry", "agriculture", "fisheries", "fuel_stations"]],
	["👥 جامعه و رفاه", [
		"population", "health", "education", "welfare", "family", "sports_youth", "ethnicity",
		"culture", "veterans", "migration_detail", "households_detail_full", "human_states"]],
	["🏗️ زیرساخت و توسعه", [
		"infrastructure", "technology", "space", "settlements", "transport_roads", "urban_facilities",
		"public_services", "industry_sites", "government_buildings", "public_transport", "heritage", "physical"]],
	["🛡️ دفاع و امنیت", [
		"military", "security", "intelligence", "security_forces_detail", "trade_route_warfare", "map_advanced"]],
	["🌍 دیپلماسی و بین‌الملل", [
		"diplomacy", "international_orgs", "foreign_affairs", "interdependency"]],
	["🌱 محیط‌زیست و منابع", [
		"environment", "resources", "emergency"]],
	["👤 مردم و نهادها", [
		"people", "citizens_detail", "workforce_detail", "officials", "politicians_detail",
		"public_employees", "private_sector", "elites_detail", "religious_leaders", "public_religious"]]
]

# نگاشت سریع: نام سامانه ← نام حوزه (برای فرمان‌پالت و فیلترها)
const SYSTEM_DOMAIN := {
	"politics":"🏛️ حاکمیت", "judicial":"🏛️ حاکمیت", "elections":"🏛️ حاکمیت", "administration":"🏛️ حاکمیت",
	"statistics":"🏛️ حاکمیت", "prison":"🏛️ حاکمیت", "political_career":"🏛️ حاکمیت", "quantitative":"🏛️ حاکمیت",
	"economy":"💰 اقتصاد", "central_bank":"💰 اقتصاد", "stock_market":"💰 اقتصاد", "trade":"💰 اقتصاد",
	"tourism":"💰 اقتصاد", "hospitality":"💰 اقتصاد", "retail":"💰 اقتصاد", "financial_services":"💰 اقتصاد",
	"industry":"💰 اقتصاد", "agriculture":"💰 اقتصاد", "fisheries":"💰 اقتصاد", "fuel_stations":"💰 اقتصاد",
	"population":"👥 جامعه", "health":"👥 جامعه", "education":"👥 جامعه", "welfare":"👥 جامعه",
	"family":"👥 جامعه", "sports_youth":"👥 جامعه", "ethnicity":"👥 جامعه", "culture":"👥 جامعه",
	"veterans":"👥 جامعه", "migration_detail":"👥 جامعه", "households_detail_full":"👥 جامعه", "human_states":"👥 جامعه",
	"infrastructure":"🏗️ زیرساخت", "technology":"🏗️ زیرساخت", "space":"🏗️ زیرساخت", "settlements":"🏗️ زیرساخت",
	"transport_roads":"🏗️ زیرساخت", "urban_facilities":"🏗️ زیرساخت", "public_services":"🏗️ زیرساخت",
	"industry_sites":"🏗️ زیرساخت", "government_buildings":"🏗️ زیرساخت", "public_transport":"🏗️ زیرساخت",
	"heritage":"🏗️ زیرساخت", "physical":"🏗️ زیرساخت",
	"military":"🛡️ دفاع", "security":"🛡️ دفاع", "intelligence":"🛡️ دفاع", "security_forces_detail":"🛡️ دفاع",
	"trade_route_warfare":"🛡️ دفاع", "map_advanced":"🛡️ دفاع",
	"diplomacy":"🌍 دیپلماسی", "international_orgs":"🌍 دیپلماسی", "foreign_affairs":"🌍 دیپلماسی", "interdependency":"🌍 دیپلماسی",
	"environment":"🌱 محیط", "resources":"🌱 محیط", "emergency":"🌱 محیط",
	"people":"👤 مردم", "citizens_detail":"👤 مردم", "workforce_detail":"👤 مردم", "officials":"👤 مردم",
	"politicians_detail":"👤 مردم", "public_employees":"👤 مردم", "private_sector":"👤 مردم",
	"elites_detail":"👤 مردم", "religious_leaders":"👤 مردم", "public_religious":"👤 مردم"
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
	"score":"امتیاز", "ratio":"نسبت", "reserve":"ذخیره", "reserves":"ذخایر", "value":"مقدار",
	"economy":"اقتصاد", "policy":"سیاست", "private":"خصوصی", "investment":"سرمایه‌گذاری",
	"informal":"غیررسمی", "tax":"مالیات", "daily":"روزانه", "household":"خانوار",
	"female":"زنان", "workforce":"نیروی کار", "size":"اندازه", "service":"خدمت",
	"months":"ماه", "error":"خطا", "estimate":"برآورد", "elite":"نخبگان",
	"lifestyle":"سبک زندگی", "fitness":"تناسب", "charity":"خیریه", "contribution":"مشارکت",
	"reliability":"پایداری", "ethnic":"قومی", "unrest":"ناآرامی", "extremism":"افراطی‌گرایی",
	"bureaucracy":"بوروکراسی", "burden":"بار", "aid":"کمک خارجی", "inflow":"ورود",
	"continuity":"تداوم", "appeal":"جاذبه", "overstaffing":"اضافه‌استخدام",
	"wage":"حقوق", "arrears":"معوقه"
}

# ترجمه دقیق کلیدهای ترکیبی که معنای واحدی دارند (ترجیح بر ترجمه تکه‌به‌تکه)
const METRIC_EXACT_FA := {
	"ethnic_unrest_risk": "ریسک ناآرامی قومی", "extremism_risk": "ریسک افراطی‌گرایی",
	"charity_contribution": "مشارکت خیریه‌ها", "power_reliability": "پایداری شبکه برق",
	"lifestyle_fitness": "تناسب سبک زندگی", "elite_research_capacity": "ظرفیت پژوهش نخبگان",
	"policy_error_risk": "ریسک خطای سیاست", "informal_economy_estimate": "برآورد اقتصاد غیررسمی",
	"avg_household_size": "بعد خانوار", "female_workforce": "اشتغال زنان",
	"bureaucracy_burden": "بار بوروکراسی", "aid_inflow_daily": "کمک خارجی روزانه",
	"policy_continuity": "تداوم سیاستگذاری", "service_appeal": "جاذبه خدمت",
	"overstaffing": "اضافه‌استخدام", "wage_arrears_months": "معوقه حقوق (ماه)",
	"private_investment": "سرمایه‌گذاری خصوصی", "informal_tax_loss_daily": "فرار مالیاتی روزانه",
	"demographic_stage_announced": "مرحله گذار جمعیتی اعلام‌شده", "prev_absorption": "جذب شوک ثبت‌شده قبلی"
}

const TABS := [
	["map", "نقشه فرماندهی"],
	["dashboard", "داشبورد"],
	["news", "📰 اخبار"],
	["missions", "🎯 مأموریت‌ها"],
	["government", "دولت"],
	["laws", "قوانین"],
	["economy", "اقتصاد"],
	["projects", "توسعه"],
	["technology", "فناوری"],
	["population", "جامعه"],
	["military", "دفاع"],
	["network", "چندنفره"],
	["systems", "سامانه‌ها"]
]

func _ready():
	# ⏰ پیشرفت آفلاین: اگر بازیکن ساعاتی نبوده، پاداش غیبت بده
	call_deferred("_check_offline_progress")
	# ثبت لحظه خروج هنگام بستن بازی
	get_tree().auto_accept_quit = true
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	app_theme = _build_professional_theme()
	theme = app_theme
	SettingsManager.settings_changed.connect(_on_setting_changed)
	current_state = GameState.get_state_copy()
	_build_chrome()
	# افکت لمسی دکمه‌های ثابت (کروم) — ناوبری، کشو، هدر
	call_deferred("_wire_press_fx", self)
	# لایه جشن: بنر + کاغذرنگی برای لحظه‌های مهم (روی همه‌چیز)
	celebration_layer = load("res://scripts/ui/celebration_layer.gd").new()
	celebration_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	celebration_layer.z_index = 400
	celebration_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(celebration_layer)
	resized.connect(_apply_responsive_layout)
	call_deferred("_apply_responsive_layout")
	_switch_tab("map")
	_refresh_header()
	GameEngine.tick_completed.connect(_on_tick_completed)
	GameEngine.tick_failed.connect(_on_tick_failed)
	GameEngine.tick_progress.connect(_on_tick_progress)
	P2PManager.state_snapshot_received.connect(_on_network_state_snapshot)
	P2PManager.campaign_lobby_received.connect(_on_campaign_lobby)
	P2PManager.network_status_changed.connect(_on_network_status_changed)
	P2PManager.network_error.connect(_on_network_error)
	P2PManager.turn_finished_changed.connect(_on_turn_finished_changed)
	P2PManager.chat_received.connect(_on_chat_received)
	_build_multiplayer_overlays()
	print("رابط کاربری اصلی لود شد - شبیه‌ساز کشور")

func _notification(what:int):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		OfflineProgressManager.note_exit()
	if what!=NOTIFICATION_WM_GO_BACK_REQUEST:return
	if is_instance_valid(command_palette) and command_palette.visible:command_palette.close_palette();return
	if drawer_open:_close_drawer();return
	if simulation_busy:get_tree().quit();return
	if current_tab!="map":_switch_tab("map")
	else:get_tree().quit()

# ============================================================
# قاب کلی: هدر + تب‌بار + محتوا + فوتر
# ============================================================
# ⏰ پاداش بازگشت از غیبت (آفلاین)
func _check_offline_progress():
	var result = OfflineProgressManager.claim_offline(GameState.state)
	if result.get("success", false):
		var state: Dictionary = result.get("state", {})
		GameState.set_state(state, int(state.get("version", 0)), int(state.get("tick", 0)))
		var hours: float = float(result.get("hours", 0.0))
		var bonus: float = float(result.get("bonus", 0.0))
		_toast("⏰ شما %s ساعت نبودید؛ بازده کشور جمع شد و %s به ذخایر ارزی اضافه شد!" % [
			PersianFormatter.to_persian_digits("%.1f" % hours), PersianFormatter.format_money(bonus)])
		FeedbackManager.play_success()

func _build_chrome():
	background_rect = CommandBackgroundClass.new()
	background_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background_rect)

	# ── لایه جغرافیایی دائمی: نقشه جهان پشت همه پنل‌ها زنده است (سبک HOI4) ──
	map_wrap = Control.new()
	map_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_wrap.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(map_wrap)
	_build_persistent_world_map()
	# پرده نیمه‌تیره: وقتی پنل مدیریتی باز است، جهان پشت آن می‌خوابد.
	map_veil = ColorRect.new()
	map_veil.color = Color(0.004, 0.010, 0.020, 0.66)
	map_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_veil.visible = false
	add_child(map_veil)

	chrome_root = VBoxContainer.new()
	var root = chrome_root
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 16
	root.offset_right = -16
	root.offset_top = 12
	root.offset_bottom = -12
	root.add_theme_constant_override("separation", 8)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# ── نوار بالایی: هویت کشور + تاریخ + جستجوی فرمان ──
	var top_bar = PanelContainer.new()
	top_bar.theme_type_variation = "TopBarPanel"
	root.add_child(top_bar)
	var top_row = HBoxContainer.new(); top_row.add_theme_constant_override("separation", 12); top_bar.add_child(top_row)
	var emblem_panel = PanelContainer.new(); emblem_panel.theme_type_variation = "EmblemChip"; top_row.add_child(emblem_panel)
	var emblem = Label.new(); emblem.text = "❖"; emblem.add_theme_font_size_override("font_size", 36); emblem.modulate = ACCENT_GOLD; emblem_panel.add_child(emblem)
	var identity_col = VBoxContainer.new(); identity_col.add_theme_constant_override("separation", 0); identity_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top_row.add_child(identity_col)
	header_title = Label.new()
	header_title.text = "مرکز فرماندهی ملی"
	header_title.add_theme_font_size_override("font_size", 29)
	identity_col.add_child(header_title)
	date_lbl = Label.new(); date_lbl.add_theme_font_size_override("font_size", 20); date_lbl.modulate = TEXT_MUTED; identity_col.add_child(date_lbl)
	var quick_command = Button.new(); quick_command.text = "⌕ جستجو"; quick_command.tooltip_text = "جست‌وجوی همه بخش‌ها، سامانه‌ها و کشورها (Ctrl+K)"; quick_command.custom_minimum_size=Vector2(150,58); quick_command.add_theme_font_size_override("font_size",22);quick_command.pressed.connect(_open_command_palette); top_row.add_child(quick_command)

	# ── نوار شاخص‌های حیاتی: چهار KPI که همیشه باید دیده شوند ──
	status_grid = GridContainer.new(); status_grid.columns = 4; status_grid.add_theme_constant_override("h_separation", 7); status_grid.add_theme_constant_override("v_separation",6); root.add_child(status_grid)
	gdp_status_lbl = _status_chip(status_grid, "◈ اقتصاد", ACCENT_GREEN,"economy")
	approval_status_lbl = _status_chip(status_grid, "♥ رضایت", ACCENT_BLUE,"population")
	stability_status_lbl = _status_chip(status_grid, "⚖ ثبات", ACCENT_ORANGE,"government")
	alert_status_lbl = _status_chip(status_grid, "⚠ هشدارها", ACCENT_RED,"dashboard")
	engagement_lbl = Label.new(); engagement_lbl.add_theme_font_size_override("font_size", 17); engagement_lbl.modulate = TEXT_FAINT; engagement_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; root.add_child(engagement_lbl)

	# ناوبری اصلی در انتهای صفحه ساخته می‌شود (سبک HOI4: ۵ بخش ثابت + کشوی بیشتر).

	# فضای نقشه‌محور: در حالت نقشه این Spacer باز می‌شود تا جهان دیده شود و پنل‌ها به پایین بچسبند.
	top_spacer = Control.new()
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_spacer.visible = false
	root.add_child(top_spacer)

	# محتوای اصلی؛ نقشه و پنل‌های مدیریتی از همین فضای مشترک استفاده می‌کنند.
	content_scroll = TouchScrollClass.new(); content_scroll.allow_vertical=true;content_scroll.allow_horizontal=false;content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; content_scroll.clip_contents = true; root.add_child(content_scroll)
	content = VBoxContainer.new(); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL; content.add_theme_constant_override("separation", 10); content_scroll.add_child(content)

	# Label پنهان فقط برای سازگاری تست/کد قدیمی؛ اعلان واقعی در ToastStack نمایش داده می‌شود.
	toast_lbl = Label.new(); toast_lbl.hide(); add_child(toast_lbl)

	# تیکر رخدادهای زنده؛ لمس آن میز فرمان را باز می‌کند.
	ticker_panel = PanelContainer.new(); ticker_panel.theme_type_variation = "TickerPanel"; ticker_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE; ticker_panel.tooltip_text = "مشاهده کامل در میز فرمان"; root.add_child(ticker_panel)
	var event_box = HBoxContainer.new(); event_box.add_theme_constant_override("separation",9); ticker_panel.add_child(event_box)
	var ev_title = Label.new(); ev_title.text = "⚡ رخدادها"; ev_title.custom_minimum_size = Vector2(125,0); ev_title.modulate = ACCENT_GOLD; ev_title.add_theme_font_size_override("font_size",20); event_box.add_child(ev_title)
	event_list = VBoxContainer.new(); event_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; event_list.add_theme_constant_override("separation",1); event_box.add_child(event_list); _render_events()

	# ── داک زمان (سبک HOI4): اقدام اصلی رهبر + جریان خودکار ──
	time_dock = PanelContainer.new(); time_dock.theme_type_variation = "TimeDockPanel"; time_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(time_dock)
	var time_row = HBoxContainer.new(); time_row.alignment = BoxContainer.ALIGNMENT_CENTER; time_row.add_theme_constant_override("separation",9); time_dock.add_child(time_row)
	queue_btn = _mk_btn(time_row, "☑ تصمیم‌ها: ۰", Vector2(172,54), _on_queue_pressed, "QueueBtn")
	_mk_btn(time_row, "▶ پایان نوبت", Vector2(218,54), _on_next_tick_pressed, "PrimaryAction")
	_mk_btn(time_row, "خودکار: خاموش", Vector2(166,54), _on_auto_pressed, "AutoBtn")
	_mk_btn(time_row, "⚡ " + SettingsManager.get_speed_label(), Vector2(104,54), _on_speed_pressed, "SpeedBtn")

	# ── ناوبری پایانی ثابت: پنج بخش اصلی همیشه در دسترس ──
	var nav_panel = PanelContainer.new(); nav_panel.theme_type_variation = "NavBarPanel"; nav_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(nav_panel)
	nav_row = HBoxContainer.new(); nav_row.add_theme_constant_override("separation", 3); nav_panel.add_child(nav_row)
	for nav_def in [["map","◉","نقشه"],["dashboard","▦","میز فرمان"],["government","♜","دولت"],["economy","◈","اقتصاد"],["more","☰","بیشتر"]]:
		_make_nav_item(nav_row, str(nav_def[0]), str(nav_def[1]), str(nav_def[2]))

	toast_stack = ToastStackClass.new(); toast_stack.anchor_left=0.48;toast_stack.anchor_right=0.98;toast_stack.anchor_top=0.10;toast_stack.anchor_bottom=0.42;toast_stack.offset_left=0;toast_stack.offset_right=0;toast_stack.offset_top=0;toast_stack.offset_bottom=0;add_child(toast_stack)
	command_palette = CommandPaletteClass.new(); command_palette.item_chosen.connect(_on_palette_item_chosen); add_child(command_palette); command_palette.set_entries(_build_command_entries())
	_build_drawer()
	_build_simulation_overlay()

# ============================================================
# نقشه دائمی تمام‌صفحه — پایه جغرافیایی زیر همه پنل‌ها (سبک HOI4/EU4)
# ============================================================
func _build_persistent_world_map():
	var state = GameState.state
	var world: Dictionary = state.get("world", {})
	var player_id = str(world.get("player_country", WorldManager.default_country))
	if selected_world_country == "" or not WorldManager.countries.has(selected_world_country):
		selected_world_country = player_id
	current_unified_map = UnifiedMapClass.new()
	current_unified_map.selected_country = selected_world_country
	current_unified_map.selected_unit = selected_country_unit
	current_unified_map.country_selected.connect(_on_unified_country_selected)
	current_unified_map.unit_selected.connect(_on_unified_unit_selected)
	current_unified_map.route_selected.connect(_on_unified_route_selected)
	current_unified_map.view_changed.connect(_on_unified_view_changed)
	map_wrap.add_child(current_unified_map)
	current_unified_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not map_wrap.resized.is_connected(_on_map_wrap_resized):
		map_wrap.resized.connect(_on_map_wrap_resized)
	call_deferred("_on_map_wrap_resized")
	_sync_world_map()
	# ستون شناور دوربین — لبه‌ی در دسترس شست (موقعیت در _on_map_wrap_resized).
	map_fab_col = VBoxContainer.new()
	# حالت راست‌به‌چپِ سراسری، position را نسبت به لبه راست آینه می‌کند؛
	# با LTR، ستون شناور دوربین دقیقاً با offset (18, …) از لبه چپ می‌ماند و از قاب گوشی بیرون نمی‌زند.
	map_fab_col.layout_direction = Control.LAYOUT_DIRECTION_LTR
	map_fab_col.add_theme_constant_override("separation", 10)
	map_fab_col.mouse_filter = Control.MOUSE_FILTER_PASS
	map_wrap.add_child(map_fab_col)
	for fab_def in [["✚","in","بزرگ‌نمایی"],["−","out","کوچک‌نمایی"],["⌂","home","نمای کشور من"],["⊙","selected","نمای کشور انتخابی"],["◐","world","نمای جهان"]]:
		var fab = Button.new(); fab.text = str(fab_def[0]); fab.tooltip_text = str(fab_def[2]); fab.custom_minimum_size = Vector2(64,64); fab.add_theme_font_size_override("font_size", 27); fab.theme_type_variation = "MapFab"
		fab.pressed.connect(FeedbackManager.play_click); fab.pressed.connect(_on_map_camera_command.bind(str(fab_def[1]))); map_fab_col.add_child(fab)

# والد غیر Container است؛ ابعاد نقشه و ستون شناور را دستی هم‌گام می‌کنیم.
func _on_map_wrap_resized():
	if is_instance_valid(current_unified_map):
		current_unified_map.size = map_wrap.size
	if is_instance_valid(map_fab_col):
		map_fab_col.position = Vector2(18, max(0.0, map_wrap.size.y * 0.5 - 168.0))

# تازه‌سازی داده نقشه پس از هر تغییر State — بدون بازسازی گره نقشه.
func _sync_world_map():
	if not is_instance_valid(current_unified_map):
		return
	var state = GameState.state
	var world: Dictionary = state.get("world", {})
	var player_id = str(world.get("player_country", WorldManager.default_country))
	if selected_world_country == "" or not WorldManager.countries.has(selected_world_country):
		selected_world_country = player_id
	var map_countries: Dictionary = world.get("countries", {}).duplicate(true)
	for war_target in world.get("wars", {}).keys():
		if map_countries.has(war_target): map_countries[war_target]["at_war"] = true
	for npc_war in world.get("npc_wars", {}).values():
		for participant in [str(npc_war.get("a", "")), str(npc_war.get("b", ""))]:
			if map_countries.has(participant): map_countries[participant]["at_war"] = true
	current_unified_map.selected_country = selected_world_country
	current_unified_map.configure(map_countries, state.get("diplomacy", {}).get("relations", {}), player_id, world, state, map_base_layer, map_overlays, map_camera_center, map_zoom)

# حالت نقشه: پرده می‌خوابد، پنل‌ها به برگه پایین تبدیل می‌شوند و نقشه تعاملی است.
func _set_map_mode(active: bool):
	map_mode = active
	if is_instance_valid(map_veil): map_veil.visible = not active
	if is_instance_valid(map_fab_col): map_fab_col.visible = active
	if is_instance_valid(top_spacer):
		top_spacer.visible = active
		top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if is_instance_valid(content_scroll):
		content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if is_instance_valid(content):
		content.alignment = BoxContainer.ALIGNMENT_END if active else BoxContainer.ALIGNMENT_BEGIN
	if is_instance_valid(current_unified_map):
		current_unified_map.mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
		if is_instance_valid(current_unified_map.fx_layer): current_unified_map.fx_layer.visible = active
	if is_instance_valid(hero_overlay):
		hero_overlay.queue_free()
		hero_overlay = null
		if is_instance_valid(content_scroll): content_scroll.visible = true

# ============================================================
# ناوبری پایانی و کشوی «بیشتر» — الگوی HOI4 روی موبایل
# ============================================================
func _make_nav_item(parent: Control, key: String, icon: String, label: String) -> Button:
	var btn = Button.new()
	btn.text = "%s\n%s" % [icon, label]
	btn.custom_minimum_size = Vector2(0, 86)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 19)
	btn.theme_type_variation = "NavButton"
	btn.pressed.connect(FeedbackManager.play_click)
	if key == "more":
		btn.pressed.connect(_toggle_drawer)
	else:
		btn.pressed.connect(_switch_tab.bind(key))
	parent.add_child(btn)
	tab_buttons[key] = btn
	return btn

func _make_drawer_tile(parent: Control, key: String, icon: String, label: String) -> Button:
	var btn = Button.new()
	btn.text = "%s\n%s" % [icon, label]
	btn.custom_minimum_size = Vector2(0, 96)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 21)
	btn.theme_type_variation = "DrawerTile"
	btn.pressed.connect(FeedbackManager.play_click)
	btn.pressed.connect(_on_drawer_tab.bind(key))
	parent.add_child(btn)
	tab_buttons[key] = btn
	return btn

func _build_drawer():
	drawer_overlay = ColorRect.new()
	drawer_overlay.color = Color(0.0, 0.0, 0.0, 0.58)
	drawer_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	drawer_overlay.z_index = 240
	drawer_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	drawer_overlay.gui_input.connect(_on_drawer_backdrop_input)
	drawer_overlay.visible = false
	add_child(drawer_overlay)
	drawer_sheet = PanelContainer.new()
	drawer_sheet.theme_type_variation = "SheetPanel"
	drawer_sheet.set_meta("ignore_tooltips", true)
	drawer_sheet.anchor_left = 0.02; drawer_sheet.anchor_right = 0.98
	drawer_sheet.anchor_top = 0.72; drawer_sheet.anchor_bottom = 0.992
	drawer_sheet.offset_left = 0; drawer_sheet.offset_right = 0; drawer_sheet.offset_top = 0; drawer_sheet.offset_bottom = 0
	drawer_overlay.add_child(drawer_sheet)
	var box = VBoxContainer.new(); box.add_theme_constant_override("separation", 10); drawer_sheet.add_child(box)
	var head = HBoxContainer.new(); head.add_theme_constant_override("separation", 8); box.add_child(head)
	var title = Label.new(); title.text = "☰ منوی بیشتر"; title.add_theme_font_size_override("font_size", 27); title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(title)
	var close_btn = Button.new(); close_btn.text = "✕"; close_btn.custom_minimum_size = Vector2(64, 54); close_btn.add_theme_font_size_override("font_size", 24); close_btn.theme_type_variation = "GhostButton"; close_btn.pressed.connect(FeedbackManager.play_click); close_btn.pressed.connect(_close_drawer); head.add_child(close_btn)
	var tiles = GridContainer.new(); tiles.columns = 4; tiles.add_theme_constant_override("h_separation", 7); tiles.add_theme_constant_override("v_separation", 7); box.add_child(tiles)
	for tile_def in [["news","📰","اخبار"],["missions","🎯","مأموریت‌ها"],["laws","⚖","قوانین"],["projects","⚒","توسعه"],["technology","⚛","فناوری"],["population","☺","جامعه"],["military","⚔","دفاع"],["network","◍","چندنفره"],["systems","⚙","سامانه‌ها"]]:
		_make_drawer_tile(tiles, str(tile_def[0]), str(tile_def[1]), str(tile_def[2]))
	var sep = HSeparator.new(); box.add_child(sep)
	var sys = HBoxContainer.new(); sys.alignment = BoxContainer.ALIGNMENT_CENTER; sys.add_theme_constant_override("separation", 8); box.add_child(sys)
	_mk_btn(sys, "▼ ذخیره", Vector2(150,52), _on_save_pressed)
	_mk_btn(sys, "▲ بارگذاری", Vector2(162,52), _on_load_pressed)
	_mk_btn(sys, "✕ صدا" if FeedbackManager.muted else "♪ صدا", Vector2(132,52), _on_sound_pressed, "SoundBtn")
	_mk_btn(sys, "🎵 موزیک" if AmbientMusic.is_enabled() else "🎵✕ موزیک", Vector2(150,52), _on_music_pressed, "MusicBtn")

func _on_drawer_backdrop_input(event: InputEvent):
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_close_drawer()

func _toggle_drawer():
	if drawer_open: _close_drawer()
	else: _open_drawer()

func _open_drawer():
	if not is_instance_valid(drawer_overlay): return
	drawer_open = true
	drawer_overlay.visible = true
	_update_nav_states()
	if not bool(SettingsManager.get_value("reduce_motion", false)):
		drawer_overlay.modulate.a = 0.0
		create_tween().tween_property(drawer_overlay, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _close_drawer():
	drawer_open = false
	if is_instance_valid(drawer_overlay): drawer_overlay.visible = false
	_update_nav_states()

func _on_drawer_tab(key: String):
	_close_drawer()
	_switch_tab(key)

func _update_nav_states():
	var overflow_tabs = ["laws","projects","technology","population","military","network","systems"]
	for key in tab_buttons.keys():
		if not is_instance_valid(tab_buttons[key]): continue
		if key in overflow_tabs:
			tab_buttons[key].theme_type_variation = "DrawerTileActive" if key == current_tab else "DrawerTile"
		else:
			var active = key == current_tab or (key == "more" and (drawer_open or current_tab in overflow_tabs))
			tab_buttons[key].theme_type_variation = "NavButtonActive" if active else "NavButton"

func _on_ticker_input(event: InputEvent):
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		FeedbackManager.play_click(); _switch_tab("dashboard")

func _build_simulation_overlay():
	simulation_overlay=ColorRect.new();simulation_overlay.set_anchors_preset(Control.PRESET_FULL_RECT);simulation_overlay.color=Color(0.0,0.01,0.018,0.88);simulation_overlay.mouse_filter=Control.MOUSE_FILTER_STOP;simulation_overlay.z_index=300;add_child(simulation_overlay)
	var panel=PanelContainer.new();panel.set_anchors_preset(Control.PRESET_CENTER);panel.anchor_left=0.12;panel.anchor_right=0.88;panel.anchor_top=0.36;panel.anchor_bottom=0.64;panel.offset_left=0;panel.offset_right=0;panel.offset_top=0;panel.offset_bottom=0;panel.theme_type_variation="CommandPanel";simulation_overlay.add_child(panel)
	var box=VBoxContainer.new();box.alignment=BoxContainer.ALIGNMENT_CENTER;box.add_theme_constant_override("separation",18);panel.add_child(box)
	var title=Label.new();title.text="در حال شبیه‌سازی ماه";title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size",34);box.add_child(title)
	simulation_status_lbl=Label.new();simulation_status_lbl.text="آماده‌سازی…";simulation_status_lbl.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;simulation_status_lbl.add_theme_font_size_override("font_size",25);simulation_status_lbl.modulate=Color(0.68,0.86,0.91);box.add_child(simulation_status_lbl)
	simulation_progress=ProgressBar.new();simulation_progress.min_value=0;simulation_progress.max_value=30;simulation_progress.value=0;simulation_progress.show_percentage=false;simulation_progress.custom_minimum_size=Vector2(0,46);box.add_child(simulation_progress)
	var hint=Label.new();hint.text="محاسبات روزبه‌روز انجام می‌شود تا رابط گوشی پاسخ‌گو بماند.";hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;hint.custom_minimum_size=Vector2(540,0);hint.modulate=Color(0.62,0.75,0.81);box.add_child(hint)
	simulation_overlay.hide()

func _set_simulation_busy(active:bool):
	simulation_busy=active
	if not is_instance_valid(simulation_overlay):return
	simulation_overlay.visible=active
	if active:
		simulation_progress.value=0;simulation_status_lbl.text="آماده‌سازی…"

func _on_tick_progress(day:int,total_days:int,phase:String):
	if not simulation_busy:return
	simulation_progress.max_value=max(1,total_days);simulation_progress.value=day;simulation_status_lbl.text=phase

func _build_professional_theme() -> Theme:
	# سیستم طراحی «اتاق فرمان»: نیلیِ شب + طلایی حکومتی + لهجه فیروزه‌ای.
	var result = Theme.new()
	var compact = str(SettingsManager.get_value("ui_density","comfortable")) == "compact"
	var high_contrast = bool(SettingsManager.get_value("high_contrast",false))
	var padding = 14 if compact else 18
	var button_padding = 10 if compact else 14
	result.default_font = PersianFont
	result.default_font_size = int((24.0 if compact else 28.0) * float(SettingsManager.get_value("text_scale", 1.0)))
	result.set_color("font_color", "Label", Color.WHITE if high_contrast else TEXT_MAIN)
	result.set_color("font_shadow_color", "Label", Color(0.0,0.0,0.0,0.40))
	result.set_constant("shadow_offset_x", "Label", 1); result.set_constant("shadow_offset_y", "Label", 1)
	var panel_border = Color(0.50,0.80,0.94,0.95) if high_contrast else Color(0.19,0.35,0.46,0.92)
	result.set_stylebox("panel", "PanelContainer", _style_box(Color(0.014,0.030,0.047,0.99) if high_contrast else Color(0.034,0.070,0.108,0.97), panel_border, 13, 1 if not high_contrast else 2, padding))
	# نوار بالایی با خط طلایی حکومتی زیرین
	var topbar_sb = _style_box_gradient(
		Color(0.035,0.070,0.100,0.98) if not high_contrast else Color(0.012,0.028,0.045,1.0),
		Color(0.012,0.030,0.050,0.98),
		ACCENT_GOLD if not high_contrast else Color(0.95,0.88,0.60,1.0), 14, 0, 13)
	topbar_sb.set_border_width(SIDE_BOTTOM, 3)
	topbar_sb.set_corner_radius(CORNER_BOTTOM_LEFT, 0); topbar_sb.set_corner_radius(CORNER_BOTTOM_RIGHT, 0)
	result.set_stylebox("panel", "TopBarPanel", topbar_sb)
	result.set_stylebox("panel", "CommandPanel", _style_box_gradient(
		Color(0.045,0.090,0.130,0.99) if not high_contrast else Color(0.020,0.040,0.060,1.0),
		Color(0.014,0.032,0.050,0.99),
		Color(0.45,0.94,0.94,1.0) if high_contrast else Color(0.30,0.66,0.74,0.85),
		12, 1 if not high_contrast else 2, padding))
	result.set_stylebox("panel", "EmblemChip", _style_box(Color(0.84,0.64,0.22,0.12), Color(0.85,0.66,0.25,0.55), 12, 1, 7))
	result.set_stylebox("panel", "StatusChip", _style_box_gradient(
		Color(0.070,0.125,0.170,0.96), Color(0.030,0.062,0.095,0.96),
		Color(0.24,0.44,0.56,0.90), 12, 1, 9))
	result.set_stylebox("panel", "KpiCard", _style_box_gradient(
		Color(0.060,0.110,0.155,0.97), Color(0.020,0.045,0.070,0.97),
		Color(0.26,0.48,0.60,0.92), 14, 1, 13))
	result.set_stylebox("panel", "HeroCard", _style_box_gradient(
		Color(0.070,0.120,0.165,0.99), Color(0.020,0.042,0.066,0.99),
		Color(0.85,0.68,0.30,0.95), 18, 2, 22))
	result.set_stylebox("panel", "TickerPanel", _style_box(Color(0.026,0.056,0.084,0.95), Color(0.20,0.37,0.48,0.72), 10, 1, 8))
	result.set_stylebox("panel", "TimeDockPanel", _style_box_gradient(
		Color(0.040,0.075,0.105,0.92), Color(0.016,0.036,0.058,0.92),
		Color(0.24,0.42,0.54,0.60), 16, 1, 8))
	# ناوبری پایانی: شناور روی لبه، آیتم فعال با خط طلایی بالایی
	result.set_stylebox("panel", "NavBarPanel", _style_box(Color(0.018,0.042,0.066,0.99), Color(0.24,0.42,0.55,0.90), 16, 1, 6))
	result.set_stylebox("normal", "NavButton", _style_box(Color(0.0,0.0,0.0,0.0), Color(0.0,0.0,0.0,0.0), 8, 0, 4))
	result.set_stylebox("hover", "NavButton", _style_box(Color(0.07,0.12,0.17,0.80), Color(0.0,0.0,0.0,0.0), 8, 0, 4))
	result.set_stylebox("pressed", "NavButton", _style_box(Color(0.10,0.16,0.21,0.95), Color(0.0,0.0,0.0,0.0), 8, 0, 4))
	result.set_color("font_color", "NavButton", TEXT_FAINT); result.set_color("font_hover_color", "NavButton", TEXT_MAIN); result.set_color("font_pressed_color", "NavButton", ACCENT_GOLD)
	var nav_active_sb = _style_box(Color(0.10,0.14,0.18,0.55), ACCENT_GOLD, 8, 0, 4)
	nav_active_sb.set_border_width(SIDE_BOTTOM, 3)
	nav_active_sb.set_corner_radius(CORNER_BOTTOM_LEFT, 0); nav_active_sb.set_corner_radius(CORNER_BOTTOM_RIGHT, 0)
	result.set_stylebox("normal", "NavButtonActive", nav_active_sb)
	result.set_stylebox("hover", "NavButtonActive", nav_active_sb); result.set_stylebox("pressed", "NavButtonActive", nav_active_sb)
	result.set_color("font_color", "NavButtonActive", ACCENT_GOLD); result.set_color("font_hover_color", "NavButtonActive", Color(1.0,0.86,0.50)); result.set_color("font_pressed_color", "NavButtonActive", ACCENT_GOLD)
	# کشوی بیشتر و کاشی‌های بخش‌ها
	result.set_stylebox("panel", "SheetPanel", _style_box(Color(0.026,0.060,0.092,0.995), Color(0.45,0.62,0.74,0.95), 18, 2, 16))
	result.set_stylebox("normal", "DrawerTile", _style_box(Color(0.048,0.098,0.148,0.96), Color(0.21,0.40,0.52,0.75), 14, 1, 9))
	result.set_stylebox("hover", "DrawerTile", _style_box(Color(0.072,0.136,0.196,0.98), ACCENT_TEAL, 14, 1, 9))
	result.set_stylebox("pressed", "DrawerTile", _style_box(Color(0.10,0.18,0.24,1.0), Color(0.55,0.95,0.90,1.0), 14, 2, 9))
	result.set_color("font_color", "DrawerTile", TEXT_MAIN); result.set_color("font_hover_color", "DrawerTile", Color.WHITE); result.set_color("font_pressed_color", "DrawerTile", Color.WHITE)
	result.set_stylebox("normal", "DrawerTileActive", _style_box(Color(0.16,0.13,0.07,0.98), ACCENT_GOLD, 14, 2, 9))
	result.set_stylebox("hover", "DrawerTileActive", _style_box(Color(0.18,0.15,0.08,0.98), ACCENT_GOLD, 14, 2, 9))
	result.set_stylebox("pressed", "DrawerTileActive", _style_box(Color(0.14,0.11,0.06,1.0), ACCENT_GOLD, 14, 2, 9))
	result.set_color("font_color", "DrawerTileActive", Color(1.0,0.88,0.55)); result.set_color("font_hover_color", "DrawerTileActive", Color.WHITE); result.set_color("font_pressed_color", "DrawerTileActive", Color.WHITE)
	# دکمه‌های عمومی: تخت، هم‌تراز با نقشه تاریک، لبه فیروزه‌ای هنگام تعامل
	var button_normal = _style_box(Color(0.054,0.108,0.158,0.98), Color(0.24,0.45,0.58,0.88), 10, 1, button_padding)
	var button_hover = _style_box(Color(0.080,0.158,0.216,0.99), ACCENT_TEAL, 10, 1, button_padding)
	var button_pressed = _style_box(Color(0.096,0.212,0.252,1.0), Color(0.52,0.96,0.90,1.0), 10, 2, button_padding)
	var button_disabled = _style_box(Color(0.033,0.064,0.093,0.90), Color(0.14,0.24,0.32,0.60), 10, 1, button_padding)
	for kind in ["Button", "OptionButton"]:
		result.set_stylebox("normal", kind, button_normal); result.set_stylebox("hover", kind, button_hover); result.set_stylebox("pressed", kind, button_pressed); result.set_stylebox("focus", kind, button_hover); result.set_stylebox("disabled", kind, button_disabled)
		result.set_color("font_color", kind, Color(0.88,0.94,0.97)); result.set_color("font_hover_color", kind, Color.WHITE); result.set_color("font_pressed_color", kind, Color.WHITE); result.set_color("font_disabled_color", kind, Color(0.42,0.52,0.60))
		result.set_color("font_shadow_color", kind, Color(0.0,0.0,0.0,0.55))
		result.set_constant("shadow_offset_x", kind, 1)
		result.set_constant("shadow_offset_y", kind, 2)
	# اقدام اصلی: طلایی حکومتی پررنگ با متن سیر
	result.set_stylebox("normal", "PrimaryButton", _style_box(Color(0.78,0.58,0.20,1.0), Color(0.98,0.82,0.44,1.0), 12, 2, 12))
	result.set_stylebox("hover", "PrimaryButton", _style_box(Color(0.92,0.71,0.29,1.0), Color(1.0,0.90,0.58,1.0), 12, 2, 12))
	result.set_stylebox("pressed", "PrimaryButton", _style_box(Color(0.64,0.46,0.14,1.0), Color.WHITE, 12, 2, 12))
	result.set_color("font_color", "PrimaryButton", Color(0.07,0.11,0.15)); result.set_color("font_hover_color", "PrimaryButton", Color(0.02,0.05,0.08)); result.set_color("font_pressed_color", "PrimaryButton", Color(0.0,0.02,0.04))
	# دکمه خطر (جنگ و…) و دکمه موفقیت (پذیرش پیشنهاد و…)
	result.set_stylebox("normal", "DangerButton", _style_box(Color(0.30,0.10,0.09,0.98), Color(0.85,0.36,0.30,0.95), 10, 1, button_padding))
	result.set_stylebox("hover", "DangerButton", _style_box(Color(0.40,0.13,0.11,1.0), Color(1.0,0.50,0.42,1.0), 10, 1, button_padding))
	result.set_stylebox("pressed", "DangerButton", _style_box(Color(0.24,0.07,0.06,1.0), Color(1.0,0.62,0.55,1.0), 10, 2, button_padding))
	result.set_color("font_color", "DangerButton", Color(1.0,0.82,0.78)); result.set_color("font_hover_color", "DangerButton", Color.WHITE); result.set_color("font_pressed_color", "DangerButton", Color.WHITE)
	result.set_stylebox("normal", "SuccessButton", _style_box(Color(0.08,0.22,0.13,0.98), Color(0.30,0.75,0.46,0.95), 10, 1, button_padding))
	result.set_stylebox("hover", "SuccessButton", _style_box(Color(0.11,0.30,0.17,1.0), Color(0.42,0.90,0.56,1.0), 10, 1, button_padding))
	result.set_stylebox("pressed", "SuccessButton", _style_box(Color(0.06,0.17,0.10,1.0), Color(0.55,1.0,0.68,1.0), 10, 2, button_padding))
	result.set_color("font_color", "SuccessButton", Color(0.78,1.0,0.85)); result.set_color("font_hover_color", "SuccessButton", Color.WHITE); result.set_color("font_pressed_color", "SuccessButton", Color.WHITE)
	result.set_stylebox("normal", "GhostButton", _style_box(Color(0.0,0.0,0.0,0.0), Color(0.30,0.46,0.57,0.60), 10, 1, button_padding))
	result.set_stylebox("hover", "GhostButton", _style_box(Color(0.07,0.12,0.17,0.80), Color(0.40,0.62,0.74,0.90), 10, 1, button_padding))
	result.set_stylebox("pressed", "GhostButton", _style_box(Color(0.10,0.16,0.21,0.95), Color(0.50,0.72,0.84,1.0), 10, 1, button_padding))
	result.set_color("font_color", "GhostButton", TEXT_MUTED); result.set_color("font_hover_color", "GhostButton", TEXT_MAIN); result.set_color("font_pressed_color", "GhostButton", TEXT_MAIN)
	# چیپ‌های لنز نقشه و پیل‌های لایه (حالت فعال/غیرفعال مشخص)
	result.set_stylebox("normal", "LensChip", _style_box(Color(0.040,0.082,0.122,0.92), Color(0.22,0.40,0.52,0.75), 20, 1, 9))
	result.set_stylebox("hover", "LensChip", _style_box(Color(0.064,0.126,0.182,0.95), Color(0.35,0.60,0.72,0.95), 20, 1, 9))
	result.set_stylebox("pressed", "LensChip", _style_box(Color(0.072,0.180,0.192,0.98), ACCENT_TEAL, 20, 2, 9))
	result.set_color("font_color", "LensChip", TEXT_MUTED); result.set_color("font_hover_color", "LensChip", TEXT_MAIN); result.set_color("font_pressed_color", "LensChip", Color(0.62,0.98,0.92))
	result.set_stylebox("normal", "LensChipActive", _style_box(Color(0.072,0.180,0.192,0.98), ACCENT_TEAL, 20, 2, 9))
	result.set_stylebox("hover", "LensChipActive", _style_box(Color(0.088,0.212,0.226,0.98), Color(0.55,0.95,0.90,1.0), 20, 2, 9))
	result.set_stylebox("pressed", "LensChipActive", _style_box(Color(0.058,0.150,0.162,0.98), ACCENT_TEAL, 20, 2, 9))
	result.set_color("font_color", "LensChipActive", Color(0.62,0.98,0.92)); result.set_color("font_hover_color", "LensChipActive", Color.WHITE); result.set_color("font_pressed_color", "LensChipActive", Color(0.62,0.98,0.92))
	result.set_stylebox("normal", "PillToggle", _style_box(Color(0.034,0.070,0.105,0.88), Color(0.19,0.34,0.45,0.65), 18, 1, 8))
	result.set_stylebox("hover", "PillToggle", _style_box(Color(0.056,0.110,0.162,0.94), Color(0.34,0.58,0.70,0.92), 18, 1, 8))
	result.set_stylebox("pressed", "PillToggle", _style_box(Color(0.142,0.112,0.046,0.98), ACCENT_GOLD, 18, 2, 8))
	result.set_color("font_color", "PillToggle", TEXT_FAINT); result.set_color("font_hover_color", "PillToggle", TEXT_MAIN); result.set_color("font_pressed_color", "PillToggle", Color(1.0,0.88,0.55))
	# دکمه‌های شناور دوربین روی نقشه
	result.set_stylebox("normal", "MapFab", _style_box(Color(0.024,0.056,0.088,0.90), Color(0.30,0.52,0.64,0.85), 12, 1, 4))
	result.set_stylebox("hover", "MapFab", _style_box(Color(0.10,0.18,0.24,0.96), ACCENT_TEAL, 12, 1, 4))
	result.set_stylebox("pressed", "MapFab", _style_box(Color(0.072,0.180,0.192,1.0), Color(0.55,0.95,0.90,1.0), 12, 2, 4))
	result.set_color("font_color", "MapFab", TEXT_MAIN); result.set_color("font_hover_color", "MapFab", Color.WHITE); result.set_color("font_pressed_color", "MapFab", Color.WHITE)
	result.set_stylebox("background", "ProgressBar", _style_box(Color(0.014,0.032,0.050,0.95), Color(0.14,0.28,0.38,0.90), 7, 1, 2))
	result.set_stylebox("fill", "ProgressBar", _style_box(Color(0.16,0.72,0.68,0.98), Color(0.36,0.92,0.86,0.95), 7, 0, 2))
	result.set_stylebox("normal", "LineEdit", _style_box(Color(0.012,0.034,0.052,0.98), Color(0.20,0.40,0.50,0.88), 9, 1, 9))
	result.set_stylebox("focus", "LineEdit", _style_box(Color(0.018,0.054,0.073,1.0), Color(0.31,0.87,0.87,1.0), 9, 2, 9))
	result.set_color("font_color", "LineEdit", Color(0.91,0.96,0.98)); result.set_color("font_placeholder_color", "LineEdit", Color(0.45,0.59,0.65))
	result.set_stylebox("separator", "HSeparator", _style_box(Color(0.20,0.34,0.45,0.0), Color(0.20,0.34,0.45,0.65), 0, 1, 1))
	result.set_stylebox("panel", "TooltipPanel", _style_box(Color(0.008,0.026,0.040,0.99),Color(0.78,0.62,0.28,0.92),8,1,10))
	result.set_color("font_color","TooltipLabel",Color(0.95,0.98,1.0))
	return result

func _style_box(background: Color, border: Color, radius: int, width: int, padding: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new(); style.bg_color = background; style.border_color = border
	style.set_border_width_all(width); style.set_corner_radius_all(radius)
	style.content_margin_left = padding; style.content_margin_right = padding; style.content_margin_top = padding; style.content_margin_bottom = padding
	style.shadow_color = Color(0.0,0.0,0.0,0.30); style.shadow_size = 5; style.shadow_offset = Vector2(0,2)
	return style

# نسخه عمقی پنل — هایلایت لبه بالا + سایه عمیق (حس برجستگی و شیشه‌ای، بدون گرادیان)
func _style_box_gradient(top: Color, bottom: Color, border: Color, radius: int, width: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = top
	style.border_color = border
	style.set_border_width_all(width)
	# عمق: سایه عمیق + لبه‌های برجسته (Godot 4.7 فقط border_color کلی دارد)
	style.border_width_left = maxi(1, width)
	style.border_width_right = maxi(1, width)
	style.border_width_top = maxi(1, width + 1)
	style.border_width_bottom = maxi(1, width + 2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding; style.content_margin_right = padding
	style.content_margin_top = padding; style.content_margin_bottom = padding
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.40)
	style.shadow_size = 9
	style.shadow_offset = Vector2(0, 4)
	return style

func _status_chip(parent: Control, title_text: String, accent: Color, target_tab:String) -> Label:
	var panel = PanelContainer.new(); panel.theme_type_variation = "StatusChip"; panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL;panel.mouse_filter=Control.MOUSE_FILTER_STOP;panel.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND;panel.tooltip_text="بازکردن "+title_text;panel.gui_input.connect(_on_status_chip_input.bind(target_tab)); parent.add_child(panel)
	var box = VBoxContainer.new(); box.add_theme_constant_override("separation",2); panel.add_child(box)
	box.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var title_row = HBoxContainer.new(); title_row.add_theme_constant_override("separation",7); title_row.mouse_filter=Control.MOUSE_FILTER_IGNORE; box.add_child(title_row)
	var dot = ColorRect.new(); dot.color = accent; dot.custom_minimum_size = Vector2(9,9); dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER; dot.mouse_filter=Control.MOUSE_FILTER_IGNORE; title_row.add_child(dot)
	var title = Label.new(); title.text = title_text; title.add_theme_font_size_override("font_size",18); title.modulate = TEXT_MUTED; title_row.add_child(title)
	var value = Label.new(); value.text = "—"; value.add_theme_font_size_override("font_size",24); value.modulate = accent;value.mouse_filter=Control.MOUSE_FILTER_IGNORE;value.clip_text=true;value.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; box.add_child(value)
	title.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return value

func _on_status_chip_input(event:InputEvent,target_tab:String):
	if (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):FeedbackManager.play_click();_switch_tab(target_tab)

func _build_command_entries() -> Array:
	var result:Array=[]
	for tab in TABS:
		result.append({"kind":"tab","id":str(tab[0]),"title":str(tab[1]),"group":"بخش","keywords":"مدیریت صفحه مرکز"})
	for system_id in GameEngine.system_order:
		result.append({"kind":"system","id":str(system_id),"title":str(SYSTEM_FA.get(system_id,"سامانه")),"group":str(SYSTEM_DOMAIN.get(system_id,"سامانه")),"keywords":str(system_id),"description":"بازکردن پایش و جزئیات سامانه"})
	for country_id in WorldManager.get_country_ids():
		var profile=WorldManager.get_country(str(country_id));result.append({"kind":"country","id":str(country_id),"title":str(profile.get("name_fa",country_id)),"group":"کشور","keywords":"%s %s %s"%[country_id,profile.get("capital_fa",""),profile.get("subregion","")],"description":"انتخاب و فوکوس روی نقشه"})
	return result

func _open_command_palette(initial_query:String=""):
	if is_instance_valid(command_palette):
		command_palette.open_palette(initial_query)

func _on_palette_item_chosen(kind:String,id:String):
	match kind:
		"tab": _switch_tab(id)
		"system": selected_system=id;_switch_tab("systems")
		"country":
			selected_world_country=id;selected_country_unit="";selected_map_route={};_switch_tab("map");call_deferred("_focus_palette_country",id)

func _focus_palette_country(country_id:String):
	if is_instance_valid(current_unified_map):current_unified_map.focus_country(country_id)

func _apply_responsive_layout():
	if not is_instance_valid(chrome_root):return
	var narrow=size.x<1200.0 or float(SettingsManager.get_value("text_scale",1.0))>1.10
	var margin=8.0 if narrow else 16.0
	chrome_root.offset_left=margin;chrome_root.offset_right=-margin;chrome_root.offset_top=8.0 if narrow else 12.0;chrome_root.offset_bottom=-8.0 if narrow else -12.0
	if is_instance_valid(status_grid):status_grid.columns=2 if narrow else 4
	if is_instance_valid(toast_stack):
		toast_stack.anchor_left=0.06 if narrow else 0.48;toast_stack.anchor_right=0.94 if narrow else 0.98;toast_stack.anchor_top=0.08;toast_stack.anchor_bottom=0.42
	if is_instance_valid(map_overlay_grid):map_overlay_grid.columns=3 if narrow else 5
	if is_instance_valid(map_wrap):map_wrap.custom_minimum_size.y=720.0 if narrow else 860.0

func _apply_tooltip_preferences():
	var enabled=bool(SettingsManager.get_value("tooltips_enabled",true));_apply_tooltip_recursive(self,enabled)

func _apply_tooltip_recursive(node:Node,enabled:bool):
	if node is Control:
		if enabled and node.has_meta("saved_tooltip"):node.tooltip_text=str(node.get_meta("saved_tooltip"));node.remove_meta("saved_tooltip")
		elif not enabled and node.tooltip_text!="":node.set_meta("saved_tooltip",node.tooltip_text);node.tooltip_text=""
	for child in node.get_children():_apply_tooltip_recursive(child,enabled)

func _animate_page_in(generation:int):
	await get_tree().process_frame
	if generation!=page_generation:return
	_wire_press_fx(content)
	if bool(SettingsManager.get_value("reduce_motion",false)):return
	var delay=0.0
	for child in content.get_children():
		if not child is Control or child.is_queued_for_deletion():continue
		child.modulate.a=0.0
		child.pivot_offset=child.size*0.5
		child.scale=Vector2(0.965,0.965)
		var tween=create_tween();tween.tween_interval(delay)
		tween.tween_property(child,"modulate:a",1.0,0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(child,"scale",Vector2.ONE,0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		delay=min(0.12,delay+0.016)

# افکت لمسی دکمه‌ها: کوچک‌شدن نرم هنگام لمس (حس فیزیکی بازی)
func _wire_press_fx(root_node: Node):
	if bool(SettingsManager.get_value("reduce_motion", false)):
		return
	for child in root_node.get_children():
		if child is Button and not child.has_meta("press_fx"):
			var btn: Button = child
			btn.set_meta("press_fx", true)
			btn.pivot_offset = btn.size * 0.5
			btn.button_down.connect(func():
				if is_instance_valid(btn):
					btn.pivot_offset = btn.size * 0.5
					var tw := create_tween()
					tw.tween_property(btn, "scale", Vector2(0.93, 0.93), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT))
			btn.button_up.connect(func():
				if is_instance_valid(btn):
					var tw := create_tween()
					tw.tween_property(btn, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
			btn.focus_exited.connect(func():
				if is_instance_valid(btn):
					btn.scale = Vector2.ONE)
		_wire_press_fx(child)

func _unhandled_key_input(event:InputEvent):
	# تا مُدال قهرمان آغاز روی صحنه است، میان‌برها مسدودند (رفتار مُدال).
	if is_instance_valid(hero_overlay):
		return
	if not event is InputEventKey or not event.pressed or event.echo:return
	if (event.ctrl_pressed and event.keycode==KEY_K) or event.keycode==KEY_F1:
		_open_command_palette();get_viewport().set_input_as_handled();return
	if event.alt_pressed:
		var index=-1
		if event.keycode>=KEY_1 and event.keycode<=KEY_9:index=event.keycode-KEY_1
		elif event.keycode==KEY_0:index=9
		if index>=0 and index<TABS.size():_switch_tab(str(TABS[index][0]));get_viewport().set_input_as_handled()

func _mk_btn(parent, text, minsize, handler, node_name = ""):
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(minsize.x,max(62.0,float(minsize.y)))
	btn.add_theme_font_size_override("font_size", 25)
	btn.pressed.connect(FeedbackManager.play_click)
	btn.pressed.connect(handler)
	if node_name != "":
		btn.name = node_name
	if node_name == "PrimaryAction":
		btn.theme_type_variation = "PrimaryButton"
	parent.add_child(btn)
	return btn

# ============================================================
# سربرگ (تاریخ + امتیاز)
# ============================================================
func _refresh_header():
	var st = GameState.state
	var clock = st.get("clock", {})
	if header_title != null:
		header_title.text = "فرماندهی %s" % str(st.get("country", {}).get("name", "کشور شما"))
	var time = st.get("time", {})
	if date_lbl != null:
		date_lbl.text = "%s %s · %s" % [str(time.get("month_name", TimeManager.month_name(int(clock.get("month", 1))))), PersianFormatter.to_persian_digits(str(clock.get("year", 2027))), str(time.get("season", clock.get("season", "بهار")))]
	var economy = st.get("economy", {})
	var population = st.get("population", {})
	var politics = st.get("politics", {})
	if gdp_status_lbl != null:
		gdp_status_lbl.text = PersianFormatter.format_money(float(economy.get("gdp", 0.0))) + " · " + _signed_percent(float(economy.get("growth_rate", 0.0)))
	if approval_status_lbl != null:
		approval_status_lbl.text = _fmt_pct(float(population.get("happiness", population.get("satisfaction", 0.0))))
	if stability_status_lbl != null:
		stability_status_lbl.text = _fmt_pct(float(politics.get("stability", 0.0)))
	if alert_status_lbl != null:
		var alert_count = _active_crises(st).size() + st.get("pending_decisions", []).size()
		alert_status_lbl.text = ("وضعیت پایدار" if alert_count == 0 else PersianFormatter.to_persian_digits(str(alert_count)) + " مورد فعال")
	var progression = st.get("progression", {})
	if engagement_lbl != null:
		engagement_lbl.text = "نوبت %s  ·  %s  ·  سطح %s  ·  امتیاز %s  ·  استریک %s ماه" % [PersianFormatter.to_persian_digits(str(st.get("tick", 0))), str(progression.get("stage", "دولت نوپا")), PersianFormatter.to_persian_digits(str(st.get("level", 1))), PersianFormatter.format_number(int(st.get("score", 0))), PersianFormatter.to_persian_digits(str(progression.get("streak", 0)))]
	# نقشه دائمی پشت‌صحنه با جدیدترین State تازه می‌ماند.
	call_deferred("_sync_world_map")

# ============================================================
# سوییچ تب
# ============================================================
func _switch_tab(tab_key: String):
	if tab_key in ["world", "country_map"]:
		tab_key = "map"
	if drawer_open:
		drawer_open = false
		if is_instance_valid(drawer_overlay): drawer_overlay.visible = false
	current_tab = tab_key
	page_generation += 1
	if is_instance_valid(content_scroll):content_scroll.scroll_vertical=0
	_update_nav_states()
	for c in content.get_children():
		c.queue_free()
	_set_map_mode(tab_key == "map")

	match tab_key:
		"map": _build_unified_map()
		"dashboard": _build_dashboard()
		"news": _build_news()
		"missions": _build_missions()
		"government": _build_government()
		"laws": _build_laws()
		"economy": _build_economy()
		"projects": _build_national_projects()
		"technology": _build_technology()
		"population": _build_population()
		"military": _build_military()
		"network": _build_network_panel()
		"systems": _build_systems()
	call_deferred("_animate_page_in",page_generation)
	call_deferred("_apply_tooltip_preferences")

# ============================================================
# ابزارهای ساخت سریع
# ============================================================
func _card(title: String, parent_override = null) -> VBoxContainer:
	var panel = PanelContainer.new(); panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vbox = VBoxContainer.new(); vbox.add_theme_constant_override("separation", 5 if str(SettingsManager.get_value("ui_density","comfortable"))=="compact" else 7); panel.add_child(vbox)
	var head = HBoxContainer.new(); head.add_theme_constant_override("separation",9); head.mouse_filter = Control.MOUSE_FILTER_IGNORE; vbox.add_child(head)
	var marker = ColorRect.new(); marker.color = Color(0.55,0.80,1.0,0.95) if bool(SettingsManager.get_value("colorblind_palette",false)) else ACCENT_GOLD; marker.custom_minimum_size = Vector2(6,30); marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER; marker.mouse_filter = Control.MOUSE_FILTER_IGNORE; head.add_child(marker)
	var t = Label.new(); t.text = title; t.add_theme_font_size_override("font_size", 25 if str(SettingsManager.get_value("ui_density","comfortable"))=="compact" else 29); t.modulate = TEXT_MAIN; head.add_child(t)
	var accent = ColorRect.new(); accent.color = Color(0.19,0.34,0.45,0.65); accent.custom_minimum_size = Vector2(0,1); accent.mouse_filter = Control.MOUSE_FILTER_IGNORE; vbox.add_child(accent)
	var target = parent_override if parent_override != null and is_instance_valid(parent_override) else content
	target.add_child(panel)
	return vbox

func _hero_card(parent_override = null) -> VBoxContainer:
	var panel = PanelContainer.new(); panel.theme_type_variation = "HeroCard"; panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vbox = VBoxContainer.new(); vbox.add_theme_constant_override("separation", 13); panel.add_child(vbox)
	var target = parent_override if parent_override != null and is_instance_valid(parent_override) else content
	target.add_child(panel)
	return vbox

func _row(parent, key: String, value: String, value_color = null):
	var h = HBoxContainer.new()
	parent.add_child(h)
	var kl = Label.new()
	kl.text = key
	kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kl.add_theme_font_size_override("font_size", 23)
	kl.modulate = TEXT_MUTED
	h.add_child(kl)
	var vl = Label.new()
	vl.text = value
	vl.add_theme_font_size_override("font_size", 23)
	vl.modulate = value_color if value_color != null else TEXT_MAIN
	h.add_child(vl)

# پیل وضعیت رنگی — سبک نشان‌های HOI4 برای موضع کشورها و هشدارها.
func _pill(parent, text: String, color: Color) -> PanelContainer:
	var p = PanelContainer.new()
	var sb = _style_box(Color(color.r, color.g, color.b, 0.16), Color(color.r, color.g, color.b, 0.85), 14, 1, 5)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	var l = Label.new(); l.text = text; l.add_theme_font_size_override("font_size", 20); l.modulate = color; l.mouse_filter = Control.MOUSE_FILTER_IGNORE; p.add_child(l)
	return p

func _bar(parent, title: String, ratio: float):
	var h = HBoxContainer.new()
	parent.add_child(h)
	var lbl = Label.new()
	lbl.text = title
	lbl.custom_minimum_size = Vector2(240, 0)
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.modulate = TEXT_MUTED
	h.add_child(lbl)
	var bar = ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = clamp(ratio * 100.0, 0, 100)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 28)
	bar.show_percentage = false
	var bar_color = _color_for(ratio)
	bar.add_theme_stylebox_override("fill", _style_box(Color(bar_color.r, bar_color.g, bar_color.b, 0.95), bar_color.lightened(0.3), 7, 0, 2))
	h.add_child(bar)
	var pct = Label.new()
	pct.text = PersianFormatter.to_persian_digits("%d٪" % int(ratio * 100.0))
	pct.custom_minimum_size = Vector2(92, 0)
	pct.add_theme_font_size_override("font_size", 22)
	pct.modulate = bar_color
	h.add_child(pct)

# کارت شاخص کلیدی — نمای ارزش‌ها با پیکان روند؛ لمس به بخش مربوط می‌رود.
func _kpi_card(parent, icon: String, label: String, value: String, sub: String, accent: Color, target_tab: String):
	var panel = PanelContainer.new(); panel.theme_type_variation = "KpiCard"; panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP; panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.tooltip_text = "بازکردن بخش مرتبط"; panel.gui_input.connect(_on_status_chip_input.bind(target_tab))
	parent.add_child(panel)
	var box = VBoxContainer.new(); box.add_theme_constant_override("separation", 3); box.mouse_filter = Control.MOUSE_FILTER_IGNORE; panel.add_child(box)
	var head = HBoxContainer.new(); head.add_theme_constant_override("separation", 8); head.mouse_filter = Control.MOUSE_FILTER_IGNORE; box.add_child(head)
	var ic = Label.new(); ic.text = icon; ic.add_theme_font_size_override("font_size", 24); ic.modulate = accent; head.add_child(ic)
	var ttl = Label.new(); ttl.text = label; ttl.add_theme_font_size_override("font_size", 19); ttl.modulate = TEXT_MUTED; head.add_child(ttl)
	var val = Label.new(); val.text = value; val.add_theme_font_size_override("font_size", 30); val.modulate = accent; box.add_child(val)
	if sub != "":
		var s = Label.new(); s.text = sub; s.add_theme_font_size_override("font_size", 17); s.modulate = TEXT_FAINT; box.add_child(s)

func _color_for(ratio: float) -> Color:
	if bool(SettingsManager.get_value("colorblind_palette",false)):
		if ratio>=0.65:return Color(0.25,0.72,1.0)
		elif ratio>=0.4:return Color(1.0,0.78,0.22)
		return Color(0.92,0.34,0.82)
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
# سرتیتر بخش در داشبورد — برای گروه‌بندی منطقی کارت‌ها (معماری اطلاعاتی ۸ حوزه)
func _dashboard_section(title: String) -> Label:
	var lbl = Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.modulate = Color(1.0, 0.81, 0.30, 0.95)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(lbl)
	return lbl

# ============================================================
# تب 📰 اخبار — تحریریه بین‌المللی
# اطلاعات به دو دسته 🔒 حساس و 🌐 عمومی تقسیم شده‌اند:
#  - کشور خود بازیکن: حساس + عمومی
#  - کشورهای دیگر: فقط عمومی (اسرار دیگران محرمانه است)
# ============================================================
func _build_news():
	var state = GameState.state
	var items: Array = NewsManager.get_visible_news(state)
	var counts: Dictionary = NewsManager.count_items(state)
	var clock: Dictionary = state.get("clock", {})
	var year: int = int(clock.get("year", 2027))
	var month_n: int = int(clock.get("month", 1))
	var month_fa: String = TimeManager.month_name(month_n)

	# ── سربرگ تحریریه ──
	var masthead = _card("📰 تحریریه خبری")
	var top_row = HBoxContainer.new(); top_row.add_theme_constant_override("separation", 10); masthead.add_child(top_row)
	var date_lbl = Label.new()
	date_lbl.text = "🗓 %s %s" % [month_fa, PersianFormatter.to_persian_digits(str(year))]
	date_lbl.add_theme_font_size_override("font_size", 20); date_lbl.modulate = TEXT_MUTED
	date_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(date_lbl)
	var count_lbl = Label.new()
	count_lbl.text = "%s خبر | 🔒 %s حساس" % [PersianFormatter.to_persian_digits(str(counts.get("total", 0))), PersianFormatter.to_persian_digits(str(counts.get("sensitive", 0)))]
	count_lbl.add_theme_font_size_override("font_size", 18); count_lbl.modulate = ACCENT_GOLD
	top_row.add_child(count_lbl)

	# ── فیلترها (HFlow: در صفحات باریک به خط بعد می‌شکنند) ──
	var filter_row = HFlowContainer.new(); filter_row.add_theme_constant_override("h_separation", 6); filter_row.add_theme_constant_override("v_separation", 6); masthead.add_child(filter_row)
	for filter_def in [["all", "🌐 همه"], ["domestic", "🏛 داخلی"], ["international", "🌍 بین‌المللی"]]:
		var fbtn = Button.new(); fbtn.text = str(filter_def[1]); fbtn.toggle_mode = true
		fbtn.button_pressed = news_filter_mode == str(filter_def[0])
		fbtn.custom_minimum_size = Vector2(0, 42); fbtn.add_theme_font_size_override("font_size", 17)
		fbtn.theme_type_variation = "LensChipActive" if news_filter_mode == str(filter_def[0]) else "LensChip"
		fbtn.pressed.connect(_on_news_filter.bind(str(filter_def[0])))
		filter_row.add_child(fbtn)
	var sens_btn = Button.new(); sens_btn.text = "🔒 فقط حساس"; sens_btn.toggle_mode = true
	sens_btn.button_pressed = news_sensitive_only
	sens_btn.custom_minimum_size = Vector2(0, 42); sens_btn.add_theme_font_size_override("font_size", 17)
	sens_btn.theme_type_variation = "LensChipActive" if news_sensitive_only else "LensChip"
	sens_btn.pressed.connect(_on_news_sensitive_toggle)
	filter_row.add_child(sens_btn)

	var legend = Label.new()
	legend.text = "🔒 حساس = اطلاعات محرمانهٔ کشور خودتان · 🌐 عمومی = اطلاعات رسمی منتشرشده (اسرار کشورهای دیگر محرمانه است)"
	legend.add_theme_font_size_override("font_size", 15); legend.modulate = TEXT_FAINT
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	masthead.add_child(legend)

	# ── فهرست اخبار ──
	var shown := 0
	for item in items:
		var is_player: bool = bool(item.get("is_player", false))
		var is_sensitive: bool = str(item.get("sensitivity", "non_sensitive")) == "sensitive"
		if news_filter_mode == "domestic" and not is_player:
			continue
		if news_filter_mode == "international" and is_player:
			continue
		if news_sensitive_only and not is_sensitive:
			continue
		_add_news_card(item)
		shown += 1
	if shown == 0:
		var empty = Label.new()
		empty.text = "خبری برای نمایش نیست. پس از پایان نوبت اخبار جدید منتشر می‌شود."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 19)
		empty.modulate = TEXT_FAINT
		content.add_child(empty)

func _on_news_filter(mode: String):
	news_filter_mode = mode
	_switch_tab("news")

func _on_news_sensitive_toggle():
	news_sensitive_only = not news_sensitive_only
	_switch_tab("news")

# کارت هر خبر — سبک خبر حرفه‌ای
func _add_news_card(item: Dictionary):
	var card = PanelContainer.new()
	card.theme_type_variation = "CommandPanel"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(card)
	var box = VBoxContainer.new(); box.add_theme_constant_override("separation", 6); card.add_child(box)

	# ردیف فراداده: آیکون · تاریخ · کشور · دسته · نشان حساسیت
	var meta = HBoxContainer.new(); meta.add_theme_constant_override("separation", 10); box.add_child(meta)
	var icon = Label.new(); icon.text = str(item.get("icon", "📰")); icon.add_theme_font_size_override("font_size", 22); meta.add_child(icon)
	var date_l = Label.new()
	date_l.text = "%s %s" % [str(item.get("month_fa", "")), PersianFormatter.to_persian_digits(str(item.get("year", 0)))]
	date_l.add_theme_font_size_override("font_size", 15); date_l.modulate = TEXT_FAINT
	meta.add_child(date_l)
	var country_l = Label.new()
	country_l.text = str(item.get("country_fa", ""))
	country_l.add_theme_font_size_override("font_size", 16); country_l.modulate = ACCENT_TEAL
	meta.add_child(country_l)
	var cat_l = Label.new()
	cat_l.text = str(item.get("category_fa", ""))
	cat_l.add_theme_font_size_override("font_size", 15); cat_l.modulate = Color(0.72, 0.78, 0.85)
	meta.add_child(cat_l)
	var spacer = Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; meta.add_child(spacer)
	var is_player: bool = bool(item.get("is_player", false))
	var is_sensitive: bool = str(item.get("sensitivity", "non_sensitive")) == "sensitive"
	var sens_l = Label.new()
	if is_sensitive:
		sens_l.text = "🔒 حساس"
		sens_l.modulate = Color(1.0, 0.52, 0.47)
	else:
		sens_l.text = "🌐 عمومی"
		sens_l.modulate = Color(0.50, 0.92, 0.66)
	sens_l.add_theme_font_size_override("font_size", 15)
	meta.add_child(sens_l)
	if is_player and not is_sensitive:
		var home_l = Label.new()
		home_l.text = "🏛 کشور شما"
		home_l.add_theme_font_size_override("font_size", 14)
		home_l.modulate = Color(1.0, 0.81, 0.30)
		meta.add_child(home_l)

	# تیتر
	var headline = Label.new()
	headline.text = str(item.get("headline", ""))
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	headline.add_theme_font_size_override("font_size", 23)
	headline.modulate = Color(0.96, 0.975, 0.99)
	box.add_child(headline)
	# متن خبر
	var body = Label.new()
	body.text = str(item.get("body", ""))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 18)
	body.modulate = TEXT_MUTED
	box.add_child(body)

# ============================================================
# تب 🎯 مأموریت‌ها + 🏆 رتبه‌بندی جهانی + 🛒 بازار منابع (World Empire style)
# ============================================================
func _build_missions():
	var state = GameState.state

	# ── 🏆 رتبه‌بندی جهانی ──
	var rank_card = _card("🏆 رتبه‌بندی جهانی")
	var ranking: Dictionary = RankingManager.compute_rankings(state)
	var player_rank: int = int(ranking.get("player_rank", 0))
	var total: int = int(ranking.get("total", 195))
	var rank_lbl = Label.new()
	rank_lbl.text = "رتبه کشور شما: %s از %s کشور" % [PersianFormatter.to_persian_digits(str(player_rank)), PersianFormatter.to_persian_digits(str(total))]
	rank_lbl.add_theme_font_size_override("font_size", 24)
	rank_lbl.modulate = ACCENT_GOLD if player_rank <= 20 else TEXT_MAIN
	rank_card.add_child(rank_lbl)
	# برترین‌ها + اطراف رتبه بازیکن
	var top_codes: Array = ranking.get("ranked", [])
	var shown := 0
	for entry in top_codes:
		if shown >= 12:
			break
		var is_me: bool = bool(entry.get("is_player", false))
		var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 8); rank_card.add_child(row)
		var rank_n = Label.new()
		rank_n.text = PersianFormatter.to_persian_digits(str(entry.get("rank", 0)))
		rank_n.custom_minimum_size = Vector2(50, 0)
		rank_n.add_theme_font_size_override("font_size", 19)
		rank_n.modulate = ACCENT_GOLD if int(entry.get("rank", 0)) <= 3 else TEXT_MUTED
		row.add_child(rank_n)
		var name_l = Label.new()
		name_l.text = str(entry.get("name_fa", ""))
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.add_theme_font_size_override("font_size", 19)
		name_l.modulate = Color(1.0, 0.81, 0.30) if is_me else TEXT_MAIN
		row.add_child(name_l)
		var score_l = Label.new()
		score_l.text = PersianFormatter.to_persian_digits("%.0f" % float(entry.get("score", 0)))
		score_l.add_theme_font_size_override("font_size", 17)
		score_l.modulate = TEXT_MUTED
		row.add_child(score_l)
		shown += 1

	# ── 🎯 مأموریت‌های ماهانه ──
	var mission_card = _card("🎯 مأموریت‌های ماه")
	var missions: Array = state.get("missions", [])
	if missions.is_empty():
		var empty = Label.new()
		empty.text = "مأموریت‌ها پس از نخستین گام ماهانه فعال می‌شوند."
		empty.modulate = TEXT_FAINT
		mission_card.add_child(empty)
	for i in range(missions.size()):
		var m: Dictionary = missions[i]
		var done: bool = bool(m.get("done", false))
		var claimed: bool = bool(m.get("claimed", false))
		var card = PanelContainer.new()
		card.theme_type_variation = "CommandPanel"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mission_card.add_child(card)
		var box = VBoxContainer.new(); box.add_theme_constant_override("separation", 6); card.add_child(box)
		var head = HBoxContainer.new(); head.add_theme_constant_override("separation", 8); box.add_child(head)
		var icon = Label.new(); icon.text = str(m.get("icon", "🎯")); icon.add_theme_font_size_override("font_size", 22); head.add_child(icon)
		var title = Label.new()
		title.text = str(m.get("title", "")) + (" ✅" if done else "")
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.add_theme_font_size_override("font_size", 21)
		title.modulate = Color(0.55, 1.0, 0.7) if done else TEXT_MAIN
		head.add_child(title)
		var reward_l = Label.new()
		reward_l.text = "اعتبار +%s · سرمایه +%s" % [PersianFormatter.to_persian_digits(str(int(m.get("reward_prestige", 8)))), PersianFormatter.to_persian_digits("%.0f" % (float(m.get("reward_capital", 0.15)) * 100.0))]
		reward_l.add_theme_font_size_override("font_size", 15)
		reward_l.modulate = ACCENT_GOLD
		head.add_child(reward_l)
		var desc = Label.new()
		desc.text = str(m.get("desc", ""))
		desc.add_theme_font_size_override("font_size", 16)
		desc.modulate = TEXT_MUTED
		box.add_child(desc)
		_bar(box, "پیشرفت", float(m.get("progress", 0.0)))
		if done and not claimed:
			var claim_btn = Button.new()
			claim_btn.text = "🎁 دریافت پاداش"
			claim_btn.theme_type_variation = "SuccessButton"
			claim_btn.custom_minimum_size = Vector2(0, 46)
			claim_btn.pressed.connect(_on_claim_mission.bind(i))
			box.add_child(claim_btn)
		elif claimed:
			var got = Label.new()
			got.text = "🎁 پاداش دریافت شد"
			got.add_theme_font_size_override("font_size", 15)
			got.modulate = Color(0.55, 1.0, 0.7)
			box.add_child(got)

	# ── 🛒 بازار جهانی منابع ──
	var market_card = _card("🛒 بازار جهانی منابع")
	var econ = state.get("economy", {})
	var reserves = float(econ.get("foreign_reserves", 50e9))
	var res_row = HBoxContainer.new(); market_card.add_child(res_row)
	var res_lbl = Label.new()
	res_lbl.text = "ذخایر ارزی: %s" % PersianFormatter.format_money(reserves)
	res_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_lbl.add_theme_font_size_override("font_size", 18)
	res_lbl.modulate = ACCENT_TEAL
	res_row.add_child(res_lbl)
	var prices: Dictionary = state.get("market", {}).get("prices", {})
	var inv: Dictionary = state.get("resources", {}).get("inventory", {})
	for r in ["نفت", "گاز", "غذا", "آهن", "مس", "مواد_صنعتی"]:
		var price = float(prices.get(r, 1.0))
		var have = float(inv.get(r, 0.0))
		var card2 = PanelContainer.new()
		card2.theme_type_variation = "CommandPanel"
		market_card.add_child(card2)
		var box2 = VBoxContainer.new(); box2.add_theme_constant_override("separation", 5); card2.add_child(box2)
		var title2 = Label.new()
		title2.text = "%s · %s / واحد" % [r, PersianFormatter.to_persian_digits("%.1f" % price)]
		title2.add_theme_font_size_override("font_size", 18)
		title2.modulate = TEXT_MAIN
		box2.add_child(title2)
		var stock = Label.new()
		stock.text = "ذخیره: %s" % PersianFormatter.to_persian_digits("%.0f" % have)
		stock.add_theme_font_size_override("font_size", 15)
		stock.modulate = TEXT_MUTED
		box2.add_child(stock)
		var btns = HBoxContainer.new(); btns.add_theme_constant_override("separation", 6); box2.add_child(btns)
		var buy_btn = Button.new(); buy_btn.text = "خرید ۱۰"; buy_btn.custom_minimum_size = Vector2(0, 40)
		buy_btn.pressed.connect(_on_market.bind(r, "buy", 10.0))
		btns.add_child(buy_btn)
		var sell_btn = Button.new(); sell_btn.text = "فروش ۱۰"; sell_btn.custom_minimum_size = Vector2(0, 40)
		sell_btn.pressed.connect(_on_market.bind(r, "sell", 10.0))
		btns.add_child(sell_btn)

func _on_claim_mission(index: int):
	var result = MissionManager.claim_reward(GameState.state, index)
	if result.get("success", false):
		var m: Dictionary = result.get("mission", {})
		GameState.set_state(result.state, int(result.state.get("version", 0)), int(result.state.get("tick", 0)))
		_toast("🎁 پاداش مأموریت «%s» دریافت شد!" % str(m.get("title", "")))
		_switch_tab("missions")
	else:
		_toast("⚠️ " + str(result.get("reason", "خطا")))

func _on_market(resource: String, action: String, amount: float):
	var result: Dictionary
	if action == "buy":
		result = MarketManager.buy(GameState.state, resource, amount)
	else:
		result = MarketManager.sell(GameState.state, resource, amount)
	if result.get("success", false):
		GameState.set_state(result.state, int(result.state.get("version", 0)), int(result.state.get("tick", 0)))
		_toast("🛒 " + str(result.get("message", "انجام شد")))
		_switch_tab("missions")
	else:
		_toast("⚠️ " + str(result.get("reason", "خطا")))

# 🎁 پاداش روزانه (استریک ورود)
# ── کارت رهبر: محبوبیت جهانی، وضعیت پنهان/آشکار، کودتا و پیروزی ──
func _build_leader_card(st: Dictionary):
	var leader: Dictionary = st.get("leader", {})
	if leader.is_empty():
		return
	# حالت ژنرال وفادار: بنر ویژه
	if str(leader.get("mode", "leader")) == "general":
		var rebel_card = _card("⚔️ ژنرال وفادار — کودتای سراسری")
		var rebellion: Dictionary = leader.get("rebellion", {})
		if bool(rebellion.get("failed", false)):
			var fail_lbl = Label.new()
			match str(leader.get("country_status", "")):
				"annexed":
					fail_lbl.text = "کودتا نافرجام ماند؛ کشور هم‌مرزِ برنده، سراسر خاک را ضمیمه خود کرد و توانایی‌های کشور به او منتقل شد."
				"puppet":
					fail_lbl.text = "کودتا نافرجام ماند؛ برنده بدون مرز مشترک، حاکم دست‌نشانده گماشت و کشور عملاً زیر سلطه اوست."
				_:
					fail_lbl.text = "کودتا نافرجام ماند و کشور در هرج‌ومرج فرو رفت."
			fail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			fail_lbl.add_theme_font_size_override("font_size", 20)
			fail_lbl.modulate = Color(1.0, 0.55, 0.5)
			rebel_card.add_child(fail_lbl)
		else:
			var total := int(rebellion.get("total", 1))
			var controlled := int(rebellion.get("progress", 1))
			var deadline := int(rebellion.get("deadline_turn", 0))
			var turns_left: int = max(0, deadline - int(st.get("tick", 0)))
			_row(rebel_card, "استان پایگاه کودتا", str(rebellion.get("base_province", "—")))
			_row(rebel_card, "استان‌های تحت کنترل", "%s از %s" % [
				PersianFormatter.to_persian_digits(str(controlled)),
				PersianFormatter.to_persian_digits(str(total))])
			_row(rebel_card, "نوبت‌های باقی‌مانده برای تصاحب کامل", PersianFormatter.to_persian_digits(str(turns_left)))
			_bar(rebel_card, "پیشروی کودتا", float(controlled) / max(total, 1))
			_row(rebel_card, "محبوبیت رهبر پیشین (اثر بر وفاداری ارتش)", PersianFormatter.to_persian_digits("%.0f / ۱۰۰" % clampf(float(rebellion.get("popularity", 50.0)), 0.0, 100.0)), _color_for(clampf(float(rebellion.get("popularity", 50.0)), 0.0, 100.0) / 100.0))
			var hint = Label.new()
			hint.text = "هر نوبت با «پایان نوبت» ژنرال به پیشروی ادامه می‌دهد؛ در ۷ نوبت باید سراسر کشور را تصاحب کند. محبوبیت رهبر پیشین و رضایت مردم، وفاداری ارتش به کودتا را تعیین می‌کنند."
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hint.add_theme_font_size_override("font_size", 18)
			hint.modulate = TEXT_MUTED
			rebel_card.add_child(hint)
	# پیروزی: عصر طلایی
	var victory: Dictionary = st.get("victory", {})
	if bool(victory.get("achieved", false)):
		var win_card = _card("🏆 عصر طلایی کشور!")
		var win_lbl = Label.new()
		win_lbl.text = "سه شاخه فناوری به سطح ۳۰ رسید؛ کشور وارد عصر طلایی شد. می‌توانید به گسترش ادامه دهید."
		win_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		win_lbl.add_theme_font_size_override("font_size", 20)
		win_lbl.modulate = ACCENT_GOLD
		win_card.add_child(win_lbl)
	# کارت اصلی رهبر
	var card = _card("👤 رهبر کشور")
	var hidden := bool(leader.get("hidden", false))
	_row(card, "وضعیت", "🛡 پنهان (مکان امن)" if hidden else "☀ آشکار (در برابر مردم)")
	var pop := clampf(float(leader.get("popularity_world", 50.0)), 0.0, 100.0)
	_row(card, "محبوبیت جهانی", PersianFormatter.to_persian_digits("%.0f / ۱۰۰" % pop), _color_for(pop / 100.0))
	_bar(card, "محبوبیت جهانی", pop / 100.0)
	# ویژگی‌های رهبر (از کنش‌های بزرگ به دست می‌آیند)
	var traits: Array = leader.get("traits", [])
	if not traits.is_empty():
		var traits_row = HBoxContainer.new(); traits_row.add_theme_constant_override("separation", 6); card.add_child(traits_row)
		var traits_lbl = Label.new(); traits_lbl.text = "ویژگی‌ها:"; traits_lbl.add_theme_font_size_override("font_size", 17); traits_lbl.modulate = TEXT_MUTED; traits_row.add_child(traits_lbl)
		for trait_id in traits:
			var info: Dictionary = LeaderManager.TRAIT_INFO.get(str(trait_id), {"name": str(trait_id), "desc": ""})
			var chip = Button.new(); chip.text = str(info.get("name", str(trait_id)))
			chip.disabled = true; chip.custom_minimum_size = Vector2(0, 40)
			chip.add_theme_font_size_override("font_size", 15); chip.tooltip_text = str(info.get("desc", ""))
			chip.theme_type_variation = "LensChip"
			traits_row.add_child(chip)
	var hint = Label.new()
	hint.text = "جنگ تجاوزکارانه، تحریم و ترور محبوبیت را می‌سوزاند؛ صلح، تجارت و رشد آن را بالا می‌برد. رهبر محبوبِ ترورشده، شهرهایی را به شورش می‌کشاند."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 17)
	hint.modulate = TEXT_FAINT
	card.add_child(hint)
	# دکمه پنهان/آشکار — فقط در جنگ
	var at_war := false
	for war_key in st.get("world", {}).get("wars", {}).keys():
		if str(war_key).split("|").has(str(st.get("world", {}).get("player_country", ""))):
			at_war = true
			break
	if at_war and str(leader.get("mode", "leader")) == "leader":
		var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 8); card.add_child(row)
		var toggle = Button.new()
		toggle.text = "🛡 پنهان کردن رهبر" if not hidden else "☀ آشکار کردن رهبر"
		toggle.custom_minimum_size = Vector2(0, 50)
		toggle.add_theme_font_size_override("font_size", 19)
		toggle.pressed.connect(FeedbackManager.play_click)
		toggle.pressed.connect(_on_leader_hidden_toggle.bind(not hidden))
		_mark_decision_button(toggle, "leader_hidden:" + ("true" if hidden else "false"))
		row.add_child(toggle)
		var why = Label.new()
		why.text = "پنهان: امن‌تر در برابر ترور ولی افت روحیه و محبوبیت — آشکار: محبوب‌تر ولی آسیب‌پذیرتر"
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		why.add_theme_font_size_override("font_size", 16)
		why.modulate = TEXT_FAINT
		why.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(why)

func _on_leader_hidden_toggle(hidden: bool):
	var cmd = GameCommandClass.create_leader_hidden(hidden)
	if _queue_decision(cmd, "🛡 پنهان‌سازی رهبر" if hidden else "☀ آشکار شدن رهبر"):
		_toast("وضعیت رهبر ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("dashboard")

# ── معضلات راهبردی: انتخاب بین دو بدی با پیامد واقعی ──
func _build_dilemma_card(st: Dictionary):
	var dm: Dictionary = st.get("dilemmas", {})
	if dm.is_empty():
		return
	var active: Dictionary = dm.get("active", {})
	if active.is_empty():
		return
	var card = _card("🤔 معضل راهبردی — «%s»" % str(active.get("title", "")))
	var desc = Label.new()
	desc.text = str(active.get("desc", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 17)
	card.add_child(desc)
	var hint = Label.new()
	hint.text = "هیچ گزینه‌ای رایگان نیست؛ معضل یعنی انتخاب بین دو بدی. تا ۵ نوبت فرصت دارید."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = ACCENT_ORANGE
	card.add_child(hint)
	for ch: String in ["a", "b"]:
		var opt: Dictionary = active.get("option_" + ch, {})
		var btn = Button.new()
		btn.text = str(opt.get("label", "انتخاب"))
		btn.custom_minimum_size = Vector2(0, 50)
		btn.add_theme_font_size_override("font_size", 17)
		btn.pressed.connect(FeedbackManager.play_click)
		btn.pressed.connect(_on_dilemma.bind(ch))
		_mark_decision_button(btn, "dilemma:" + ch)
		card.add_child(btn)
		var eff = Label.new()
		eff.text = "🔻 " + str(opt.get("effect", ""))
		eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		eff.add_theme_font_size_override("font_size", 13); eff.modulate = TEXT_MUTED
		card.add_child(eff)

func _on_dilemma(choice: String):
	var cmd = GameCommandClass.create_dilemma_resolve(choice)
	if _queue_decision(cmd, "🤔 حل معضل راهبردی" + (" (گزینه الف)" if choice == "a" else " (گزینه ب)")):
		_toast("انتخاب شما ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("dashboard")

func _build_daily_reward_card(state: Dictionary):
	var status: Dictionary = DailyRewardManager.get_status()
	var can_claim: bool = bool(status.get("can_claim", false))
	var streak: int = int(status.get("streak", 0))
	var day_index: int = int(status.get("day_index", 0))
	var card = _card("🎁 پاداش روزانه")
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 8); card.add_child(row)
	var streak_lbl = Label.new()
	streak_lbl.text = "🔥 استریک: %s روز" % PersianFormatter.to_persian_digits(str(streak))
	streak_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	streak_lbl.add_theme_font_size_override("font_size", 19)
	streak_lbl.modulate = ACCENT_GOLD
	row.add_child(streak_lbl)
	var today_lbl = Label.new()
	today_lbl.text = "روز %s از ۷" % PersianFormatter.to_persian_digits(str(day_index + 1))
	today_lbl.add_theme_font_size_override("font_size", 17)
	today_lbl.modulate = TEXT_MUTED
	row.add_child(today_lbl)
	# نوار ۷ روزه
	var days_row = HBoxContainer.new(); days_row.add_theme_constant_override("separation", 4); card.add_child(days_row)
	for d in range(7):
		var day_box = PanelContainer.new()
		day_box.theme_type_variation = "LensChipActive" if d == day_index else "LensChip"
		day_box.custom_minimum_size = Vector2(0, 44)
		day_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		days_row.add_child(day_box)
		var day_lbl = Label.new()
		day_lbl.text = "روز %s" % PersianFormatter.to_persian_digits(str(d + 1))
		day_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		day_lbl.add_theme_font_size_override("font_size", 15)
		day_box.add_child(day_lbl)
	var reward: Dictionary = status.get("reward", {})
	var reward_lbl = Label.new()
	reward_lbl.text = "پاداش امروز: " + str(reward.get("label", ""))
	reward_lbl.add_theme_font_size_override("font_size", 17)
	reward_lbl.modulate = Color(0.92, 0.85, 0.60)
	card.add_child(reward_lbl)
	if can_claim:
		var claim_btn = Button.new()
		claim_btn.text = "🎁 دریافت پاداش امروز"
		claim_btn.theme_type_variation = "SuccessButton"
		claim_btn.custom_minimum_size = Vector2(0, 50)
		claim_btn.pressed.connect(_on_claim_daily_reward)
		card.add_child(claim_btn)
	else:
		var done_lbl = Label.new()
		done_lbl.text = "✅ پاداش امروز دریافت شد — فردا دوباره بیا!"
		done_lbl.add_theme_font_size_override("font_size", 16)
		done_lbl.modulate = Color(0.5, 1.0, 0.65)
		card.add_child(done_lbl)

func _on_claim_daily_reward():
	var result = DailyRewardManager.claim(GameState.state)
	if result.get("success", false):
		var state: Dictionary = result.get("state", {})
		GameState.set_state(state, int(state.get("version", 0)), int(state.get("tick", 0)))
		var reward: Dictionary = result.get("reward", {})
		_toast("🎁 پاداش روز %s دریافت شد: %s" % [PersianFormatter.to_persian_digits(str(result.get("day_index", 0) + 1)), str(reward.get("label", ""))])
		FeedbackManager.play_celebration()
		_switch_tab("dashboard")
	else:
		_toast("⚠️ " + str(result.get("reason", "خطا")))

# 🎯 رویداد ویژه فصلی
func _build_special_event_card(state: Dictionary):
	var events: Array = state.get("special_events", [])
	if events.is_empty():
		return
	var event: Dictionary = events[0]
	var card = _card("%s رویداد ویژه فصل" % str(event.get("icon", "🎯")))
	var title = Label.new()
	title.text = str(event.get("title", ""))
	title.add_theme_font_size_override("font_size", 22)
	title.modulate = Color(1.0, 0.81, 0.30)
	card.add_child(title)
	var desc = Label.new()
	desc.text = str(event.get("desc", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 17)
	desc.modulate = TEXT_MUTED
	card.add_child(desc)
	var until: int = int(event.get("until_tick", 0))
	var tick: int = int(state.get("tick", 0))
	var remaining_months: int = maxi(1, (until - tick) / 30)
	var time_lbl = Label.new()
	time_lbl.text = "⏳ %s ماه تا پایان رویداد" % PersianFormatter.to_persian_digits(str(remaining_months))
	time_lbl.add_theme_font_size_override("font_size", 15)
	time_lbl.modulate = ACCENT_TEAL
	card.add_child(time_lbl)

func _build_dashboard():
	var st = GameState.state
	var econ = st.get("economy", {})
	var pop = st.get("population", {})
	var pol = st.get("politics", {})
	var res = st.get("resources", {})
	var ind = st.get("indicators", {})

	if not bool(SettingsManager.get_value("tutorial_dismissed", false)) and int(st.get("tick", 0)) < 7:
		_build_onboarding_card(st)
	_build_command_kpis(st)
	_build_dilemma_card(st)
	_build_leader_card(st)
	_build_daily_reward_card(st)
	_build_special_event_card(st)
	_build_weather_and_municipal_card(st)
	_build_monthly_report_card(st)
	_build_timeline_card(st)

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

	_build_scenario_status_card(st)
	_build_analytics_card(st)

	# شورای هوش‌های تخصصی: مهم‌ترین مسئله‌ها را با دلیل و اقدام قابل اجرا پیشنهاد می‌دهد.
	var recommendations = AIAdvisor.get_top_recommendations(st, st.get("tick", 0), 4)
	var advisor_card = _card("🧠 شورای هوشمند کشور")
	# مشاوران با شخصیت و لحن مخصوص (مثل مشاوران بازی‌های موفق)
	var advisor_profiles = [
		{"name": "مشاور اقتصادی", "icon": "💰", "tone": "اقتصاد زبان مادری من است؛ عددها دروغ نمی‌گویند."},
		{"name": "مشاور نظامی", "icon": "🛡️", "tone": "قدرت، بهترین زبان دیپلماسی است."},
		{"name": "مشاور اجتماعی", "icon": "👥", "tone": "مردم راضی، ارتشی شکست‌ناپذیرند."},
		{"name": "مشاور اطلاعاتی", "icon": "🕵️", "tone": "هر تصمیمی که می‌گیرید، دشمنان شما هم می‌بینند."}
	]
	if recommendations.is_empty():
		var calm = Label.new()
		calm.text = "در حال حاضر هشدار مهمی از سوی سامانه‌های تخصصی ثبت نشده است."
		calm.modulate = Color(0.5, 1.0, 0.65)
		advisor_card.add_child(calm)
	else:
		var advisor_idx := 0
		for recommendation in recommendations:
			var prof: Dictionary = advisor_profiles[advisor_idx % advisor_profiles.size()]
			advisor_idx += 1
			# ردیف مشاور با شخصیت
			var prof_row = HBoxContainer.new(); prof_row.add_theme_constant_override("separation", 8); advisor_card.add_child(prof_row)
			var prof_icon = Label.new(); prof_icon.text = str(prof.get("icon", "🧠")); prof_icon.add_theme_font_size_override("font_size", 20); prof_row.add_child(prof_icon)
			var prof_name = Label.new()
			prof_name.text = "%s:" % str(prof.get("name", "مشاور"))
			prof_name.add_theme_font_size_override("font_size", 17)
			prof_name.modulate = ACCENT_TEAL
			prof_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			prof_row.add_child(prof_name)
			var prof_tone = Label.new()
			prof_tone.text = "«%s»" % str(prof.get("tone", ""))
			prof_tone.add_theme_font_size_override("font_size", 15)
			prof_tone.modulate = TEXT_FAINT
			prof_tone.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			advisor_card.add_child(prof_tone)
			_add_ai_recommendation(advisor_card, recommendation)
	# تالار افتخارات: میراث و مقایسه‌های سرگرم‌کننده
	var hall = _card("🏆 تالار افتخارات")
	var prog = st.get("progression", {})
	_row(hall, "بالاترین امتیاز", PersianFormatter.to_persian_digits("%.0f" % float(prog.get("high_score", 0))))
	_row(hall, "امتیاز میراث", PersianFormatter.to_persian_digits(str(prog.get("legacy_score", 0))))
	_row(hall, "بهترین استریک", "%s روز" % PersianFormatter.to_persian_digits(str(prog.get("best_streak", 0))))
	_row(hall, "مرحله کشور", str(prog.get("stage", "دولت نوپا")))
	# مقایسه‌های سرگرم‌کننده با دنیای واقعی
	var pop_total = float(st.get("population", {}).get("total", 0.0))
	var gdp_total = float(st.get("economy", {}).get("gdp", 0.0))
	var fun_rows: Array = []
	if pop_total > 0.0:
		if pop_total > 1_410_000_000.0:
			fun_rows.append("جمعیت کشور شما از چین هم بیشتر است! 🌏")
		elif pop_total > 1_400_000_000.0:
			fun_rows.append("جمعیت شما تقریباً با هند برابری می‌کند! 🌏")
		elif pop_total > 340_000_000.0:
			fun_rows.append("جمعیت کشور شما از آمریکا بیشتر است! 🇺🇸")
		elif pop_total > 85_000_000.0:
			fun_rows.append("جمعیت شما از آلمان، فرانسه و ایتالیا روی‌هم بیشتر است! 🇪🇺")
		elif pop_total > 60_000_000.0:
			fun_rows.append("جمعیت شما از بریتانیا و فرانسه بیشتر است! 🇬🇧")
		elif pop_total > 30_000_000.0:
			fun_rows.append("جمعیت شما از کانادا بیشتر است! 🍁")
	if gdp_total > 0.0:
		if gdp_total > 27_000_000_000_000.0:
			fun_rows.append("اقتصاد شما از آمریکا بزرگ‌تر است! اقتصاد جهان از شما حساب می‌برد 🌎")
		elif gdp_total > 18_000_000_000_000.0:
			fun_rows.append("اقتصاد شما از چین جلو زده است! 🇨🇳")
		elif gdp_total > 4_500_000_000_000.0:
			fun_rows.append("اقتصاد شما از آلمان بزرگ‌تر است! 🇩🇪")
		elif gdp_total > 3_000_000_000_000.0:
			fun_rows.append("اقتصاد شما از بریتانیا بزرگ‌تر است! 🇬🇧")
		elif gdp_total > 2_000_000_000_000.0:
			fun_rows.append("اقتصاد شما از ایتالیا و کانادا بزرگ‌تر است! 🍁")
	if fun_rows.is_empty():
		fun_rows.append("کشور شما تازه راه افتاده؛ با رشد اقتصاد و جمعیت، رکوردهای جهانی در انتظار شماست! 🚀")
	for fun in fun_rows:
		var fun_lbl = Label.new()
		fun_lbl.text = "✨ " + fun
		fun_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fun_lbl.add_theme_font_size_override("font_size", 17)
		fun_lbl.modulate = Color(0.92, 0.85, 0.60)
		hall.add_child(fun_lbl)

	_dashboard_section("🏛️ وضعیت کلان کشور")
	var c1 = _card("📊 شاخص‌های کلان")
	_bar(c1, "شادی مردم", ind.get("happiness", 0.6))
	_bar(c1, "ثبات کشور", ind.get("stability", 0.6))
	_bar(c1, "رضایت عمومی", pop.get("satisfaction", 0.6))
	_bar(c1, "توسعه انسانی (HDI)", ind.get("hdi", 0.75))

	_dashboard_section("💰 اقتصاد و دارایی")
	var c2 = _card("💵 وضعیت اقتصادی")
	_row(c2, "تولید ناخالص داخلی", PersianFormatter.format_money(econ.get("gdp", 0)))
	_row(c2, "تورم", _fmt_pct(econ.get("inflation", 0)), _color_for(1.0 - econ.get("inflation", 0) * 2.0))
	_row(c2, "بیکاری", _fmt_pct(econ.get("unemployment", 0)), _color_for(1.0 - econ.get("unemployment", 0) * 5.0))
	_row(c2, "نرخ مالیات", _fmt_pct(econ.get("tax_rate", 0.2)))

	_dashboard_section("🌱 منابع و انرژی")
	var c3 = _card("📦 منابع حیاتی")
	var inv = res.get("inventory", {})
	for rname in ["غذا", "آب", "برق", "نفت"]:
		if inv.has(rname):
			var cap = res.get("capacity", {}).get(rname, 150.0)
			_bar(c3, rname, inv[rname] / cap)

	_dashboard_section("🛡️ قدرت و راهبرد")
	var c4 = _card("🏅 قدرت و اعتبار")
	_row(c4, "شاخص قدرت", PersianFormatter.format_number(int(ind.get("power_score", 0))))
	_row(c4, "سطح رهبری", PersianFormatter.to_persian_digits(str(st.get("level", 1))))

	var progress = st.get("progression", {})
	_dashboard_section("🏆 پیشرفت و میراث")
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

	_build_settings_card()
	_build_save_slots_card()

# ── چهار شاخص کلیدی کشور در صدر میز فرمان (سبک نوار قدرت HOI4) ──
func _build_command_kpis(st: Dictionary):
	var econ = st.get("economy", {})
	var ind = st.get("indicators", {})
	# رشد واقعی (پس از شوک‌های انرژی/غذا/جنگ/تحریم)؛ بازگشت به رشد هموارشده اگر هنوز محاسبه نشده
	var growth = float(econ.get("real_growth", econ.get("growth_rate", 0.0)))
	var growth_icon = "▲" if growth >= 0.0 else "▼"
	var growth_color = ACCENT_GREEN if growth >= 0.0 else ACCENT_RED
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	content.add_child(grid)
	_kpi_card(grid, "◈", "تولید ناخالص", PersianFormatter.format_money(float(econ.get("gdp", 0.0))), "%s %s رشد واقعی" % [growth_icon, _fmt_pct(absf(growth))], ACCENT_GREEN if growth >= 0.0 else ACCENT_RED, "economy")
	var happy = float(ind.get("happiness", st.get("population", {}).get("happiness", 0.6)))
	_kpi_card(grid, "♥", "شادی مردم", _fmt_pct(happy), _health_word(happy), _color_for(happy), "population")
	var stab = float(ind.get("stability", st.get("politics", {}).get("stability", 0.6)))
	_kpi_card(grid, "⚖", "ثبات کشور", _fmt_pct(stab), _health_word(stab), _color_for(stab), "government")
	_kpi_card(grid, "★", "قدرت ملی", PersianFormatter.format_number(int(ind.get("power_score", 0))), "سطح %s" % PersianFormatter.to_persian_digits(str(st.get("level", 1))), ACCENT_GOLD, "systems")

# تپش ملایم تناوبی برای دکمه‌های کلیدی — حرکت ظریف سبک رابط بازی‌های استراتژیک.
func _pulse_control(ctrl: Control):
	if bool(SettingsManager.get_value("reduce_motion", false)) or not is_instance_valid(ctrl):
		return
	var tween = ctrl.create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(ctrl, "modulate:a", 0.84, 0.95)
	tween.tween_property(ctrl, "modulate:a", 1.0, 0.95)

func _health_word(ratio: float) -> String:
	if ratio >= 0.75: return "عالی"
	if ratio >= 0.55: return "مطلوب"
	if ratio >= 0.35: return "نیازمند توجه"
	return "بحرانی"

func _build_onboarding_card(state: Dictionary):
	var card = _card("🧭 راهنمای شروع سریع")
	var steps = [
		["۱", "کشور و سناریوی پیروزی را در نقشه فرماندهی انتخاب کنید.", int(state.get("tick", 0)) > 0],
		["۲", "مالیات، بودجه و سیاست‌های عمومی را در تب اقتصاد تنظیم کنید.", abs(float(state.get("economy", {}).get("tax_rate", 0.20)) - 0.20) > 0.001],
		["۳", "یک پروژه را در درخت فناوری آغاز کنید.", state.get("technology", {}).get("in_progress", null) != null],
		["۴", "داشبورد، هشدارها و اهداف سناریو را هر ماه بررسی کنید.", state.get("analytics", {}).get("history", []).size() >= 2]
	]
	for step in steps:
		var label = Label.new()
		label.text = "%s %s. %s" % ["✅" if step[2] else "◻️", step[0], step[1]]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.modulate = Color(0.55, 1.0, 0.65) if step[2] else Color(0.88, 0.90, 0.96)
		card.add_child(label)
	var shortcuts = HBoxContainer.new()
	shortcuts.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(shortcuts)
	_mk_btn(shortcuts, "رفتن به نقشه", Vector2(145, 44), _switch_tab.bind("map"))
	_mk_btn(shortcuts, "رفتن به اقتصاد", Vector2(155, 44), _switch_tab.bind("economy"))
	_mk_btn(shortcuts, "رفتن به فناوری", Vector2(155, 44), _switch_tab.bind("technology"))
	_mk_btn(shortcuts, "پنهان‌کردن راهنما", Vector2(180, 44), _on_dismiss_tutorial)

func _on_dismiss_tutorial():
	SettingsManager.set_value("tutorial_dismissed", true)
	_switch_tab("dashboard")

func _build_timeline_card(state: Dictionary):
	var audit: Dictionary = state.get("audit", {})
	if audit.is_empty():
		return
	var check = AuditManager.verify_chain(state)
	var card = _card("🧾 خط زمانی و حسابرسی")
	_row(card, "سلامت زنجیره فرمان", "معتبر" if check.valid else "خراب", Color(0.4, 1.0, 0.55) if check.valid else Color(1.0, 0.45, 0.45))
	_row(card, "نوبت‌های ثبت‌شده", PersianFormatter.to_persian_digits(str(audit.get("records", []).size())))
	_row(card, "Snapshotهای قابل بازگشت", PersianFormatter.to_persian_digits(str(max(0, audit.get("snapshots", []).size() - 1))))
	var hash_label = Label.new(); hash_label.text = "هش زنجیره: " + str(audit.get("chain_head", "")).left(16) + "…"; hash_label.modulate = Color(0.68, 0.75, 0.85); card.add_child(hash_label)
	var rewind = Button.new(); rewind.text = "تأیید بازگشت یک ماه" if rewind_confirmation else "بازگشت به ماه قبل"
	rewind.disabled = not AuditManager.can_rewind(state, 1)
	rewind.tooltip_text = "وضعیت ماه فعلی کنار گذاشته می‌شود؛ Saveهای دیسک حذف نمی‌شوند."
	rewind.pressed.connect(FeedbackManager.play_click); rewind.pressed.connect(_on_rewind_month); card.add_child(rewind)

func _on_rewind_month():
	if P2PManager.is_network_active() and not P2PManager.is_host:
		_toast("⚠️ فقط میزبان می‌تواند خط زمانی را بازگرداند")
		return
	if not rewind_confirmation:
		rewind_confirmation = true
		_toast("⚠️ برای بازگشت یک ماه، دوباره دکمه خط زمانی را بزنید")
		_switch_tab("dashboard")
		return
	rewind_confirmation = false
	var current_version = GameState.version
	var result = AuditManager.rewind(GameState.state, 1)
	if not result.success:
		_toast("⚠️ " + str(result.reason))
		return
	var restored: Dictionary = result.state
	var target_turn = int(result.target_turn)
	GameState.set_state(restored, current_version + 1, target_turn)
	EventLog.truncate_after_tick(target_turn)
	EventLog.log_event("timeline_rewind", {"message":"خط زمانی یک ماه به عقب بازگردانده شد","target_turn":target_turn}, target_turn, current_version + 1)
	SaveManager.maybe_autosave(target_turn)
	P2PManager.broadcast_state(GameState.state, GameState.version, GameState.tick)
	_refresh_header(); _render_events(); _toast("⏪ بازی به ماه قبل بازگشت"); _switch_tab("dashboard")

func _build_monthly_report_card(state: Dictionary):
	var report: Dictionary = state.get("monthly_report", {})
	if report.is_empty():
		return
	var card = _card("📰 گزارش مدیریتی %s" % str(report.get("month_name", "ماه گذشته")))
	_row(card, "رویدادهای پردازش‌شده", PersianFormatter.to_persian_digits(str(report.get("total_events", 0))))
	_row(card, "تغییر GDP", _signed_percent(float(report.get("gdp_change", 0.0))), _color_for(0.75 if float(report.get("gdp_change", 0.0)) >= 0.0 else 0.2))
	_row(card, "تغییر شادی", _signed_percent(float(report.get("happiness_change", 0.0))), _color_for(0.75 if float(report.get("happiness_change", 0.0)) >= 0.0 else 0.2))
	_row(card, "تغییر ثبات", _signed_percent(float(report.get("stability_change", 0.0))), _color_for(0.75 if float(report.get("stability_change", 0.0)) >= 0.0 else 0.2))
	var shown = 0
	for item in report.get("important", []):
		if shown >= 6:
			break
		var label = Label.new()
		var repeat_text = " (×%s)" % PersianFormatter.to_persian_digits(str(item.get("count", 1))) if int(item.get("count", 1)) > 1 else ""
		label.text = "• %s%s" % [PersianFormatter.to_persian_digits(str(item.get("message", ""))), repeat_text]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.modulate = Color(1.0, 0.55, 0.50) if int(item.get("priority", 0)) >= 3 else Color(0.82, 0.87, 0.95)
		card.add_child(label)
		shown += 1

func _build_weather_and_municipal_card(state: Dictionary):
	var weather: Dictionary = state.get("weather", {})
	var current: Dictionary = weather.get("current", {})
	var municipal: Dictionary = state.get("municipal_services", {})
	var season = str(state.get("time", {}).get("season", "بهار"))
	var card = _card("🌦️ اقلیم و آمادگی شهرداری — %s" % season)
	_row(card, "اقلیم کشور", str(weather.get("climate", "ثبت نشده")))
	if current.is_empty():
		var forecast = Label.new()
		forecast.text = "گزارش آب‌وهوا پس از پایان نخستین ماه منتشر می‌شود؛ اکنون زمان آماده‌سازی است."
		forecast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		forecast.modulate = Color(0.75, 0.82, 0.92)
		card.add_child(forecast)
	else:
		_row(card, "وضعیت ماه گذشته", str(current.get("condition", "پایدار")))
		_row(card, "میانگین دما", "%s درجه" % PersianFormatter.to_persian_digits("%.1f" % current.get("temperature_c", 0.0)))
		_row(card, "بارش", "%s میلی‌متر" % PersianFormatter.to_persian_digits("%.0f" % current.get("precipitation_mm", 0.0)))
		_bar(card, "راه‌های قابل عبور", 1.0 - float(current.get("roads_blocked", 0.0)))
	var target_plows = max(1.0, float(municipal.get("target_snowplows", 1)))
	_row(card, "ضخامت برف", "%s سانتی‌متر" % PersianFormatter.to_persian_digits("%.0f" % float(municipal.get("snow_depth_cm", 0.0))))
	_bar(card, "پوشش ناوگان برف‌روبی", float(municipal.get("snowplows", 0)) / target_plows)
	_bar(card, "آمادگی عملیات زمستانی", float(municipal.get("snowplow_readiness", 0.5)))
	_bar(card, "ذخیره نمک جاده", float(municipal.get("road_salt_days", 0.0)) / 30.0)
	_bar(card, "ظرفیت زهکشی", float(municipal.get("drainage", 0.5)))
	_bar(card, "آمادگی موج گرما", float(municipal.get("heat_readiness", 0.5)))
	_bar(card, "ظرفیت سرمایه‌گذاری شهرداری", float(municipal.get("investment_capacity", 0.0)) / 3.0)
	var actions = [
		["buy_snowplows", "خرید برف‌روب"], ["stock_road_salt", "ذخیره نمک جاده"],
		["winter_training", "رزمایش زمستانی"], ["improve_drainage", "تقویت زهکشی"],
		["cooling_centers", "مراکز خنک‌کننده"], ["road_maintenance", "نگهداری راه‌ها"]
	]
	var grid = GridContainer.new()
	grid.columns = 3
	card.add_child(grid)
	for action_def in actions:
		var check = SeasonalManager.can_action(state, action_def[0])
		var button = Button.new()
		button.text = action_def[1]
		button.custom_minimum_size = Vector2(190, 46)
		button.disabled = not check.valid
		button.tooltip_text = "" if check.valid else str(check.reason)
		button.pressed.connect(FeedbackManager.play_click)
		button.pressed.connect(_on_municipal_action.bind(str(action_def[0]), str(action_def[1])))
		_mark_decision_button(button, "muni:" + str(action_def[0]))
		grid.add_child(button)

func _on_municipal_action(action: String, title: String):
	var command = GameCommandClass.create_municipal_action(action)
	if _queue_decision(command, "🏙️ اقدام شهرداری: " + title):
		_toast("🏙️ اقدام شهرداری «%s» ثبت شد — با پایان نوبت اجرا می‌شود" % title)
		_switch_tab("dashboard")

func _build_settings_card():
	var card = _card("تنظیمات تجربه و دسترس‌پذیری")
	var description=Label.new();description.text="ظاهر، حرکت، رنگ، لمس و بازخورد را بدون اثر روی State کمپین شخصی‌سازی کنید.";description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;description.modulate=Color(0.66,0.78,0.84);card.add_child(description)
	var grid = GridContainer.new(); grid.columns = 2; card.add_child(grid)
	_mk_btn(grid, "سرعت خودکار: %s" % SettingsManager.get_speed_label(), Vector2(220, 48), _on_speed_pressed)
	_mk_btn(grid, "اندازه متن: %s٪" % PersianFormatter.to_persian_digits(str(int(float(SettingsManager.get_value("text_scale", 1.0)) * 100.0))), Vector2(220, 48), _on_text_scale_pressed)
	_mk_btn(grid, "تراکم رابط: %s" % SettingsManager.get_ui_density_label(), Vector2(220,48), _on_density_pressed)
	_mk_btn(grid, "کنتراست بالا: %s" % _on_off(SettingsManager.get_value("high_contrast", false)), Vector2(220, 48), _on_contrast_pressed)
	_mk_btn(grid, "پالت کوررنگی: %s" % _on_off(SettingsManager.get_value("colorblind_palette", false)), Vector2(220,48), _on_colorblind_pressed)
	_mk_btn(grid, "کاهش حرکت: %s" % _on_off(SettingsManager.get_value("reduce_motion", false)), Vector2(220, 48), _on_reduce_motion_pressed)
	_mk_btn(grid, "بازخورد لرزشی: %s" % _on_off(SettingsManager.get_value("haptics_enabled", true)), Vector2(220,48), _on_haptics_pressed)
	_mk_btn(grid, "راهنمای لمسی: %s" % _on_off(SettingsManager.get_value("tooltips_enabled", true)), Vector2(220,48), _on_tooltips_pressed)
	_mk_btn(grid, "فرمان سریع (Ctrl+K)", Vector2(220,48), _open_command_palette)
	_mk_btn(grid, "نمایش دوباره راهنما", Vector2(220, 48), _on_show_tutorial)
	_mk_btn(grid, "بازنشانی تنظیمات", Vector2(220,48), _on_reset_settings)
	_mk_btn(grid, "تأیید بازی جدید" if new_game_confirmation else "آغاز بازی جدید", Vector2(220, 48), _on_new_game_pressed)

func _on_new_game_pressed():
	if not new_game_confirmation:
		new_game_confirmation = true
		_toast("⚠️ بازی ذخیره‌نشده از بین می‌رود؛ برای تأیید دوباره «بازی جدید» را بزنید")
		_switch_tab("dashboard")
		return
	new_game_confirmation = false
	auto_tick = false
	P2PManager.disconnect_game()
	EventLog.clear()
	GameState.init_default_state()
	selected_world_country = ""
	selected_country_unit = ""
	selected_system = "economy"
	current_state = GameState.get_state_copy()
	_refresh_header()
	_render_events()
	map_camera_center = Vector2(0.5,0.5); map_zoom = 1.0
	_toast("بازی جدید آماده است؛ کشور و سناریو را روی نقشه انتخاب کنید")
	_switch_tab("map")

func _on_speed_pressed():
	SettingsManager.cycle_speed()
	var speed_button = find_child("SpeedBtn", true, false)
	if speed_button:
		speed_button.text = "⚡ %s" % SettingsManager.get_speed_label()
	if current_tab == "dashboard":
		_switch_tab("dashboard")

func _on_text_scale_pressed():
	SettingsManager.cycle_text_scale()
	_switch_tab("dashboard")

func _on_density_pressed():
	SettingsManager.cycle_ui_density();_switch_tab("dashboard")

func _on_colorblind_pressed():
	SettingsManager.toggle("colorblind_palette");_switch_tab("dashboard")

func _on_haptics_pressed():
	var enabled=SettingsManager.toggle("haptics_enabled")
	if enabled:FeedbackManager.play_success()
	_switch_tab("dashboard")

func _on_tooltips_pressed():
	SettingsManager.toggle("tooltips_enabled");_switch_tab("dashboard")

func _on_reset_settings():
	SettingsManager.reset_defaults();_toast("تنظیمات تجربه به حالت استاندارد بازگشت");_switch_tab("dashboard")

func _on_off(value)->String:
	return "روشن" if bool(value) else "خاموش"

func _on_contrast_pressed():
	SettingsManager.toggle("high_contrast")
	_switch_tab("dashboard")

func _on_reduce_motion_pressed():
	SettingsManager.toggle("reduce_motion")
	_switch_tab("dashboard")

func _on_show_tutorial():
	SettingsManager.set_value("tutorial_dismissed", false)
	_switch_tab("dashboard")

func _on_setting_changed(key: String, value):
	if key in ["text_scale","ui_density","high_contrast","colorblind_palette"]:
		app_theme=_build_professional_theme();theme=app_theme;call_deferred("_apply_responsive_layout")
	if key == "high_contrast" and background_rect != null:
		background_rect.modulate = Color(0.68,0.78,0.86) if bool(value) else Color.WHITE
		background_rect.queue_redraw()
	if key=="tooltips_enabled":call_deferred("_apply_tooltip_preferences")
	if key in ["colorblind_palette","tooltips_enabled"] and is_instance_valid(current_unified_map):current_unified_map.queue_redraw()

func _background_color() -> Color:
	return Color(0.005, 0.008, 0.015) if bool(SettingsManager.get_value("high_contrast", false)) else Color(0.05, 0.08, 0.15)

func _build_analytics_card(state: Dictionary):
	var card = _card("📈 روند ماهانه کشور")
	var history = AnalyticsManager.get_history(state, 12)
	if history.size() < 2:
		var hint = Label.new()
		hint.text = "پس از نخستین نوبت، تغییرات ماهانه و نمودار یک‌ساله در این بخش نمایش داده می‌شود."
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.modulate = Color(0.75, 0.8, 0.9)
		card.add_child(hint)
	else:
		var gdp_change = AnalyticsManager.get_change(state, "gdp", true)
		var happiness_change = AnalyticsManager.get_change(state, "happiness")
		var stability_change = AnalyticsManager.get_change(state, "stability")
		var inflation_change = AnalyticsManager.get_change(state, "inflation")
		_row(card, "رشد تولید در ماه گذشته", _signed_percent(gdp_change), _color_for(0.75 if gdp_change >= 0.0 else 0.2))
		_row(card, "تغییر شادی", _signed_percent(happiness_change), _color_for(0.75 if happiness_change >= 0.0 else 0.2))
		_row(card, "تغییر ثبات", _signed_percent(stability_change), _color_for(0.75 if stability_change >= 0.0 else 0.2))
		_row(card, "تغییر تورم", _signed_percent(inflation_change), _color_for(0.75 if inflation_change <= 0.0 else 0.2))
	var chart = TrendChartClass.new()
	chart.set_history(history)
	card.add_child(chart)

func _signed_percent(value: float) -> String:
	return PersianFormatter.to_persian_digits("%+.2f٪" % (value * 100.0))

func _build_scenario_status_card(state: Dictionary):
	var scenario: Dictionary = state.get("scenario", {})
	if scenario.is_empty():
		return
	var status = str(scenario.get("status", "active"))
	var status_text = "در جریان"
	var status_color = Color(0.55, 0.82, 1.0)
	if status == "won":
		status_text = "پیروز شدید"
		status_color = Color(0.4, 1.0, 0.55)
	elif status == "expired":
		status_text = "مهلت پایان یافت"
		status_color = Color(1.0, 0.48, 0.48)
	var card = _card("🎯 سناریو: %s" % str(scenario.get("name", "")))
	_row(card, "وضعیت", status_text, status_color)
	_row(card, "درجه دشواری", str(scenario.get("difficulty", "معمولی")))
	if status == "active":
		_row(card, "مهلت باقی‌مانده", "%s روز" % PersianFormatter.to_persian_digits(str(ScenarioManager.days_remaining(state))))
	_bar(card, "پیشرفت کل", float(scenario.get("progress", 0.0)))
	var description = Label.new()
	description.text = str(scenario.get("description", ""))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.modulate = Color(0.78, 0.82, 0.92)
	card.add_child(description)
	for objective in scenario.get("objectives", []):
		var complete = bool(objective.get("completed", false))
		var title = ("✅ " if complete else "◻️ ") + str(objective.get("title_fa", "هدف"))
		var value_text = "%s از %s" % [
			_format_scenario_value(objective, objective.get("current")),
			_format_scenario_value(objective, objective.get("target"))
		]
		_row(card, title, value_text, _color_for(float(objective.get("progress", 0.0))))

func _format_scenario_value(objective: Dictionary, value) -> String:
	if str(objective.get("mode", "")) == "contains":
		return TechnologyManager.get_technology_name(str(value)) if value is String else ("تکمیل" if objective.get("completed", false) else "در انتظار")
	if not (value is int or value is float):
		return "ثبت نشده"
	var path = str(objective.get("path", ""))
	var number = float(value)
	if path.contains("gdp") or path.contains("exports") or path.contains("imports"):
		return PersianFormatter.format_money(number)
	if path.contains("count") or path.contains("alliances") or path.contains("wars") or path.contains("unlocked_count"):
		return PersianFormatter.to_persian_digits(str(int(number)))
	if number >= 0.0 and number <= 1.5 and not path.contains("power_score") and not path.contains("influence"):
		return PersianFormatter.format_percent(number)
	return PersianFormatter.to_persian_digits("%.1f" % number)

func _build_save_slots_card():
	var card = _card("💾 جایگاه‌های ذخیره")
	var autosave = SaveManager.get_autosave_metadata()
	var autosave_text = "هنوز ساخته نشده"
	if autosave.get("valid", false):
		autosave_text = "%s — %s %s" % [autosave.get("country_name", ""), TimeManager.month_name(int(autosave.get("month", 1))), PersianFormatter.to_persian_digits(str(autosave.get("year", 2027)))]
	_row(card, "ذخیره خودکار پایان هر ماه", autosave_text)
	for metadata in SaveManager.list_slots():
		var row = HBoxContainer.new()
		card.add_child(row)
		var slot = int(metadata.get("slot", 0))
		var info = Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if metadata.get("valid", false):
			info.text = "جایگاه %s: %s — %s %s" % [
				PersianFormatter.to_persian_digits(str(slot)), metadata.get("country_name", ""),
				TimeManager.month_name(int(metadata.get("month", 1))),
				PersianFormatter.to_persian_digits(str(metadata.get("year", 2027)))]
		else:
			info.text = "جایگاه %s: خالی" % PersianFormatter.to_persian_digits(str(slot))
		row.add_child(info)
		var save_button = Button.new()
		save_button.text = "ذخیره"
		save_button.pressed.connect(FeedbackManager.play_click)
		save_button.pressed.connect(_on_save_slot.bind(slot))
		row.add_child(save_button)
		var load_button = Button.new()
		load_button.text = "بارگذاری"
		load_button.disabled = not metadata.get("valid", false)
		load_button.pressed.connect(FeedbackManager.play_click)
		load_button.pressed.connect(_on_load_slot.bind(slot))
		row.add_child(load_button)
		var delete_button = Button.new()
		delete_button.text = "تأیید حذف" if pending_delete_slot == slot else "حذف"
		delete_button.disabled = not metadata.get("exists", false)
		delete_button.modulate = Color(1.0, 0.58, 0.55)
		delete_button.pressed.connect(FeedbackManager.play_click)
		delete_button.pressed.connect(_on_delete_slot.bind(slot))
		row.add_child(delete_button)

func _on_save_slot(slot: int):
	if P2PManager.is_network_active() and not P2PManager.is_host:
		_toast("⚠️ فقط میزبان می‌تواند ذخیره کند")
		return
	var result = SaveManager.save_slot(slot)
	if result.success:
		_toast("💾 بازی در جایگاه %s ذخیره شد" % PersianFormatter.to_persian_digits(str(slot)))
		_switch_tab("dashboard")
	else:
		_toast("⚠️ " + str(result.get("reason", "ذخیره ناموفق")))

func _on_load_slot(slot: int):
	if P2PManager.is_network_active() and not P2PManager.is_host:
		_toast("⚠️ فقط میزبان می‌تواند بارگذاری کند")
		return
	var result = SaveManager.load_slot(slot)
	if result.success:
		_refresh_header()
		_render_events()
		var recovery_note = " — از نسخه پشتیبان بازیابی شد" if result.get("recovered_from_backup", false) else ""
		_toast("📂 جایگاه %s بارگذاری شد%s" % [PersianFormatter.to_persian_digits(str(slot)), recovery_note])
		_switch_tab("dashboard")
	else:
		_toast("⚠️ " + str(result.get("reason", "بارگذاری ناموفق")))

func _on_delete_slot(slot: int):
	if P2PManager.is_network_active() and not P2PManager.is_host:
		_toast("⚠️ فقط میزبان می‌تواند ذخیره را حذف کند")
		return
	if pending_delete_slot != slot:
		pending_delete_slot = slot
		_toast("⚠️ برای حذف دائمی جایگاه %s دوباره دکمه حذف را بزنید" % PersianFormatter.to_persian_digits(str(slot)))
		_switch_tab("dashboard")
		return
	if SaveManager.delete_slot(slot):
		pending_delete_slot = 0
		_toast("🗑️ جایگاه %s حذف شد" % PersianFormatter.to_persian_digits(str(slot)))
		_switch_tab("dashboard")
	else:
		_toast("⚠️ حذف جایگاه ناموفق بود")

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
	var remaining = max(0, int(decision.get("expires_day", TimeManager.get_total_days(GameState.state))) - TimeManager.get_total_days(GameState.state))
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
		_mark_decision_button(button, "dec:" + str(decision.get("id", "")))
		choice_row.add_child(button)
		var consequence = Label.new()
		consequence.text = str(choice.get("consequence", ""))
		consequence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		consequence.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		consequence.modulate = Color(0.78, 0.82, 0.9)
		choice_row.add_child(consequence)

func _on_decision_choice(decision_id: String, choice_id: String, choice_title: String):
	var cmd = GameCommandClass.create_decision_resolve(decision_id, choice_id)
	if _queue_decision(cmd, "⚖️ تصمیم فوری: " + choice_title):
		_toast("⚖️ گزینه «%s» ثبت شد — با پایان نوبت اجرا می‌شود" % choice_title)
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
		var ai_cmd = GameCommandClass.from_dict(recommendation["command"])
		_mark_decision_button(apply, _command_queue_key(ai_cmd))
		box.add_child(apply)

func _on_apply_ai_recommendation(command_data: Dictionary, title: String):
	var cmd = GameCommandClass.from_dict(command_data)
	# فراداده در زمان اجرا و مطابق نسخه جاری توسط موتور تکمیل می‌شود.
	cmd.tick = 0
	cmd.version = 0
	if _queue_decision(cmd, "🧠 پیشنهاد هوش مصنوعی: " + title):
		_toast("🧠 پیشنهاد «%s» ثبت شد — با پایان نوبت اجرا می‌شود" % title)
		_switch_tab("dashboard")

func _active_crises(st: Dictionary) -> Array:
	var out = []
	var res = st.get("resources", {})
	var econ = st.get("economy", {})
	var pop = st.get("population", {})
	var pol = st.get("politics", {})
	# بحران‌های فعال موتور رویداد (رودمپ ۴) با چرخه‌ی حیات و شدت، در هشدار داشبورد دیده می‌شوند.
	for crisis in st.get("events_active", []):
		if str(crisis.get("status", "active")) != "active":
			continue
		var level = "بحرانی" if int(crisis.get("severity", 1)) >= 3 else "هشدار"
		out.append("%s «%s» — تصمیم فوری لازم است" % [level, str(crisis.get("title", "بحران"))])
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
	var blocked = float(st.get("municipal_services", {}).get("roads_blocked", 0.0))
	if blocked > 0.20:
		out.append("انسداد راه‌ها — %s٪ مسیرها به‌دلیل شرایط جوی مختل‌اند" % PersianFormatter.to_persian_digits(str(int(blocked * 100.0))))
	var hazard = str(st.get("weather", {}).get("current", {}).get("hazard", "none"))
	if hazard == "heatwave":
		out.append("موج گرما — مصرف آب و برق و خطر سلامت افزایش یافته است")
	elif hazard == "flood":
		out.append("سیلاب شهری — زهکشی و خدمات اضطراری زیر فشار هستند")
	return out

# ============================================================
# تب قوانین — تصویب، اجرا، حمایت و نظارت قضایی
# ============================================================
# ── فراکسیون‌های سیاسی: نفوذ و وفاداری + آشتی/رویارویی/هم‌پیمانی ──
func _build_factions_card(state: Dictionary):
	var factions: Dictionary = state.get("factions", {})
	if factions.is_empty():
		return
	var card = _card("🏛️ فراکسیون‌های سیاسی — نفوذ و وفاداری")
	var hint = Label.new()
	hint.text = "وفاداری پایین بحران می‌آفریند (کودتا، اعتراض، فرار سرمایه)؛ نفوذ بالا اثر واقعی بر کشور دارد (فساد، ارتش، ثبات). آشتی وفاداری را بالا می‌برد ولی نفوذ را هم؛ رویارویی نفوذ را می‌شکند ولی خطرناک است."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 16)
	hint.modulate = TEXT_FAINT
	card.add_child(hint)
	for fid in FactionManager.FACTIONS:
		var f: Dictionary = factions.get(fid, {})
		if f.is_empty():
			continue
		var loyalty := clampf(float(f.get("loyalty", 50.0)), 0.0, 100.0)
		var power := clampf(float(f.get("power", 40.0)), 0.0, 100.0)
		var panel = PanelContainer.new(); panel.add_theme_stylebox_override("panel", null)
		card.add_child(panel)
		var box = VBoxContainer.new(); box.add_theme_constant_override("separation", 4); panel.add_child(box)
		var head = HBoxContainer.new(); head.add_theme_constant_override("separation", 8); box.add_child(head)
		var title = Label.new()
		var status := "🔴 " if loyalty < 22.0 else ("🟠 " if loyalty < 40.0 else ("🟢 " if loyalty > 70.0 else "🔵 "))
		title.text = "%s%s — %s" % [status, fid, _faction_status_fa(loyalty)]
		title.add_theme_font_size_override("font_size", 19)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(title)
		var pow_lbl = Label.new()
		pow_lbl.text = "نفوذ %s" % PersianFormatter.to_persian_digits(str(int(power)))
		pow_lbl.add_theme_font_size_override("font_size", 16)
		pow_lbl.modulate = TEXT_MUTED
		head.add_child(pow_lbl)
		var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 10); box.add_child(row)
		var loyalty_col = VBoxContainer.new(); loyalty_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL; loyalty_col.add_theme_constant_override("separation", 2); row.add_child(loyalty_col)
		var l_lbl = Label.new(); l_lbl.text = "وفاداری"; l_lbl.add_theme_font_size_override("font_size", 14); l_lbl.modulate = TEXT_MUTED; loyalty_col.add_child(l_lbl)
		var l_bar = ProgressBar.new(); l_bar.max_value = 100.0; l_bar.value = loyalty; l_bar.show_percentage = false; l_bar.custom_minimum_size = Vector2(0, 10); loyalty_col.add_child(l_bar)
		var btn_row = HBoxContainer.new(); btn_row.add_theme_constant_override("separation", 5); box.add_child(btn_row)
		for act in [["appease", "🤝 آشتی (۱)"], ["confront", "⚔ رویارویی"], ["ally", "👥 هم‌پیمانی (۱.۵)"]]:
			var btn = Button.new(); btn.text = act[1]; btn.custom_minimum_size = Vector2(0, 38)
			btn.add_theme_font_size_override("font_size", 15)
			btn.pressed.connect(FeedbackManager.play_click)
			btn.pressed.connect(_on_faction_action.bind(fid, act[0], act[1]))
			_mark_decision_button(btn, "fac:" + fid + ":" + act[0])
			btn_row.add_child(btn)

func _faction_status_fa(loyalty: float) -> String:
	if loyalty < 22.0:
		return "بحرانی"
	if loyalty < 40.0:
		return "ناراضی"
	if loyalty > 70.0:
		return "وفادار"
	return "متوازن"

func _on_faction_action(faction: String, action: String, label: String):
	var cmd = GameCommandClass.create_faction_action(faction, action)
	if _queue_decision(cmd, "🏛️ " + label + " با «" + faction + "»"):
		_toast("اقدام بر «%s» ثبت شد — با پایان نوبت اعمال می‌شود" % faction)
		_switch_tab("government")

# ── مجلس و انتخابات: وعده‌ها، پشتیبانی، ماندات، انتخابات زودهنگام ──
func _build_parliament_card(st: Dictionary):
	var par: Dictionary = st.get("parliament", {})
	if par.is_empty():
		return
	var card = _card("🗳️ مجلس و انتخابات")
	var next_election: int = int(par.get("next_election_turn", 0))
	var turns_left: int = max(0, next_election - int(st.get("tick", 0)))
	var support: float = clampf(float(par.get("support", 0.5)), 0.0, 1.0)
	var mandate: float = clampf(float(par.get("mandate", 0.5)), 0.0, 1.0)
	_row(card, "انتخابات بعدی", "%s نوبت دیگر" % PersianFormatter.to_persian_digits(str(turns_left)))
	_row(card, "پشتیبانی مردمی", PersianFormatter.to_persian_digits("%.0f٪" % (support * 100.0)), _color_for(support))
	_bar(card, "ماندات دولت (قدرت تصویب)", mandate)
	var last: Dictionary = par.get("last_result", {})
	if not last.is_empty():
		_row(card, "نتیجه انتخابات گذشته", "پیروزی با %s٪" % PersianFormatter.to_persian_digits(str(int(float(last.get("support", 0.5)) * 100.0))) if bool(last.get("won", false)) else "اقلیت مجلس")
	# وعده‌ها (۶ نوبت آخر قبل از انتخابات)
	var promises: Array = par.get("promises", [])
	if turns_left <= 6 and turns_left > 0:
		var promise_lbl = Label.new()
		promise_lbl.text = "📣 دوره وعده‌ها! (حداکثر ۲ وعده — %s انتخاب شده)"
		promise_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		promise_lbl.add_theme_font_size_override("font_size", 17); promise_lbl.modulate = ACCENT_GOLD
		card.add_child(promise_lbl)
		for pid in ParliamentManager.PROMISES.keys():
			var info: Dictionary = ParliamentManager.PROMISES[pid]
			var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 8); card.add_child(row)
			var info_col = VBoxContainer.new(); info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL; info_col.add_theme_constant_override("separation", 2); row.add_child(info_col)
			var name = Label.new(); name.text = str(info.get("name_fa", pid)) + (" ✔" if promises.has(pid) else "")
			name.add_theme_font_size_override("font_size", 17); info_col.add_child(name)
			var eff = Label.new(); eff.text = str(info.get("effect", "")); eff.add_theme_font_size_override("font_size", 13); eff.modulate = TEXT_FAINT; info_col.add_child(eff)
			var btn = Button.new(); btn.text = "انتخاب"; btn.custom_minimum_size = Vector2(90, 40)
			btn.disabled = promises.has(pid) or promises.size() >= 2
			btn.add_theme_font_size_override("font_size", 15)
			btn.pressed.connect(FeedbackManager.play_click)
			btn.pressed.connect(_on_promise.bind(pid))
			_mark_decision_button(btn, "promise:" + pid)
			row.add_child(btn)
	# انتخابات زودهنگام
	var snap_check = ParliamentManager.can_snap(st, int(st.get("tick", 0)))
	var snap_btn = Button.new(); snap_btn.text = "⚡ انتخابات زودهنگام (ریسک)"
	snap_btn.custom_minimum_size = Vector2(0, 46); snap_btn.add_theme_font_size_override("font_size", 16)
	snap_btn.disabled = not snap_check.valid
	snap_btn.tooltip_text = "" if snap_check.valid else str(snap_check.reason)
	snap_btn.pressed.connect(FeedbackManager.play_click)
	snap_btn.pressed.connect(_on_snap_election)
	_mark_decision_button(snap_btn, "snap_election")
	card.add_child(snap_btn)
	var hint = Label.new()
	hint.text = "ماندات قوی سیاست‌ها را ارزان می‌کند؛ ماندات ضعیف یعنی فشار ائتلاف‌ها. وعده‌ها رأی می‌آورند ولی بعد از انتخابات باید اجرا شوند!"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 15); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_promise(promise_id: String):
	var cmd = GameCommandClass.create_campaign_promise(promise_id)
	if _queue_decision(cmd, "📣 وعده: " + str(ParliamentManager.PROMISES.get(promise_id, {}).get("name_fa", promise_id))):
		_toast("وعده انتخاباتی ثبت شد — با پایان نوبت اعلام می‌شود")
		_switch_tab("government")

func _on_snap_election():
	var check = ParliamentManager.can_snap(GameState.state, int(GameState.state.get("tick", 0)))
	if not check.valid:
		_toast("⚠️ " + str(check.reason))
		return
	var cmd = GameCommandClass.create_snap_election()
	if _queue_decision(cmd, "⚡ انتخابات زودهنگام"):
		_toast("انتخابات زودهنگام ثبت شد — با پایان نوبت اعلام می‌شود")
		_switch_tab("government")

# ── استانداران و سیاست استانی: انتصاب از جناح‌ها، رضایت و ناآرامی ──
func _build_governors_card(st: Dictionary):
	var governors: Dictionary = st.get("governors", {})
	if governors.is_empty():
		return
	var provs: Dictionary = governors.get("provinces", {})
	var card = _card("🏛️ استانداران — سیاست استانی")
	var hint = Label.new()
	hint.text = "استاندار از جناح‌ها انتخاب می‌شود (وفاداری آن جناح بالا می‌رود). شایستگی بالا رضایت می‌سازد؛ فساد رسوایی و ناآرامی می‌آورد."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 15); hint.modulate = TEXT_FAINT
	card.add_child(hint)
	for code in provs.keys():
		var prov: Dictionary = provs[code]
		var approval := clampf(float(prov.get("approval", 55.0)), 0.0, 100.0)
		var unrest := clampf(float(prov.get("unrest", 0.0)), 0.0, 1.0)
		var panel = PanelContainer.new(); card.add_child(panel)
		var box = VBoxContainer.new(); box.add_theme_constant_override("separation", 3); panel.add_child(box)
		var head = HBoxContainer.new(); head.add_theme_constant_override("separation", 8); box.add_child(head)
		var title = Label.new()
		title.text = "%s — %s (جناح %s)" % [str(prov.get("name_fa", code)), str(prov.get("governor", "؟")), str(prov.get("faction", "؟"))]
		title.add_theme_font_size_override("font_size", 17); title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(title)
		var unrest_lbl = Label.new()
		unrest_lbl.text = ("🔴 ناآرامی" if unrest > 0.6 else ("🟠 تنش" if unrest > 0.35 else "🟢 آرام"))
		unrest_lbl.add_theme_font_size_override("font_size", 14)
		head.add_child(unrest_lbl)
		var stats = Label.new()
		stats.text = "رضایت %s | شایستگی %s | فساد %s" % [
			PersianFormatter.to_persian_digits(str(int(approval))),
			PersianFormatter.to_persian_digits(str(int(float(prov.get("competence", 0.5)) * 100.0))),
			PersianFormatter.to_persian_digits(str(int(float(prov.get("corruption", 0.3)) * 100.0)))]
		stats.add_theme_font_size_override("font_size", 14); stats.modulate = TEXT_MUTED
		box.add_child(stats)
		var appoint_row = HBoxContainer.new(); appoint_row.add_theme_constant_override("separation", 5); box.add_child(appoint_row)
		for fid in ["تکنوکرات‌ها", "نخبگان اقتصادی", "ارتش", "روحانیت"]:
			var btn = Button.new(); btn.text = "استاندار از " + fid
			btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 13)
			btn.disabled = not GovernorsManager.can_appoint(st).valid
			btn.pressed.connect(FeedbackManager.play_click)
			btn.pressed.connect(_on_governor_appoint.bind(code, fid))
			_mark_decision_button(btn, "gov:" + code + ":" + fid)
			appoint_row.add_child(btn)

func _on_governor_appoint(province_code: String, faction: String):
	var check = GovernorsManager.can_appoint(GameState.state)
	if not check.valid:
		_toast("⚠️ " + str(check.reason))
		return
	var cmd = GameCommandClass.create_governor_appoint(province_code, faction)
	if _queue_decision(cmd, "🏛️ انتصاب استاندار (جناح " + faction + ")"):
		_toast("انتصاب استاندار ثبت شد — با پایان نوبت انجام می‌شود")
		_switch_tab("government")

# ── قوه قضائیه: استقلال، تراکم پرونده و پرونده‌های بزرگ ──
func _build_judiciary_card(st: Dictionary):
	var jud: Dictionary = st.get("judiciary", {})
	if jud.is_empty():
		return
	var independence := clampf(float(jud.get("independence", 0.55)), 0.0, 1.0)
	var backlog := clampf(float(jud.get("backlog", 0.4)), 0.0, 1.0)
	var card = _card("⚖️ قوه قضائیه")
	_row(card, "استقلال قضایی", PersianFormatter.to_persian_digits("%.0f٪" % (independence * 100.0)), _color_for(independence))
	_bar(card, "استقلال قضایی", independence)
	_row(card, "تراکم پرونده", PersianFormatter.to_persian_digits("%.0f٪" % (backlog * 100.0)), _color_for(1.0 - backlog))
	_row(card, "احکام صادره", PersianFormatter.to_persian_digits(str(jud.get("verdicts", 0))))
	var ruling: Dictionary = jud.get("pending_ruling", {})
	if not ruling.is_empty():
		var case_lbl = Label.new()
		case_lbl.text = "🚨 " + str(ruling.get("title", "")) + " — " + str(ruling.get("desc", ""))
		case_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		case_lbl.add_theme_font_size_override("font_size", 17); case_lbl.modulate = ACCENT_RED
		card.add_child(case_lbl)
		var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 6); card.add_child(row)
		for act in [["free", "⚖️ حکم آزاد قضایی"], ["mediate", "🤝 میانجیگری"]]:
			var btn = Button.new(); btn.text = act[1]
			btn.custom_minimum_size = Vector2(0, 42); btn.add_theme_font_size_override("font_size", 14)
			btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_court.bind(act[0]))
			_mark_decision_button(btn, "court:" + act[0])
			row.add_child(btn)
		var press_btn = Button.new(); press_btn.text = "📉 فشار به دادگاه"
		press_btn.custom_minimum_size = Vector2(0, 42); press_btn.add_theme_font_size_override("font_size", 14)
		press_btn.pressed.connect(FeedbackManager.play_click); press_btn.pressed.connect(_on_court.bind("press"))
		_mark_decision_button(press_btn, "court:press")
		row.add_child(press_btn)
	var act_row = HBoxContainer.new(); act_row.add_theme_constant_override("separation", 6); card.add_child(act_row)
	var fund_btn = Button.new(); fund_btn.text = "💰 بودجه دادگاه‌ها"
	fund_btn.custom_minimum_size = Vector2(0, 42); fund_btn.add_theme_font_size_override("font_size", 14)
	fund_btn.pressed.connect(FeedbackManager.play_click); fund_btn.pressed.connect(_on_court.bind("fund"))
	_mark_decision_button(fund_btn, "court:fund")
	act_row.add_child(fund_btn)
	var reform_btn = Button.new(); reform_btn.text = "🔧 اصلاحات قضایی (۲)"
	reform_btn.custom_minimum_size = Vector2(0, 42); reform_btn.add_theme_font_size_override("font_size", 14)
	reform_btn.disabled = float(st.get("policies", {}).get("political_capital", 0.0)) < 2.0
	reform_btn.pressed.connect(FeedbackManager.play_click); reform_btn.pressed.connect(_on_court.bind("reform"))
	_mark_decision_button(reform_btn, "court:reform")
	act_row.add_child(reform_btn)
	var hint = Label.new()
	hint.text = "استقلال بالا فساد را می‌خشکاند و اعتماد می‌سازد؛ تراکم پرونده دادگستری را فلج می‌کند. پرونده‌های بزرگ را قضایی حل کنید یا با هزینه استقلال، سیاسی!"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 15); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_court(action: String):
	var cmd = GameCommandClass.create_court_action(action)
	var labels := {"fund": "بودجه دادگاه‌ها", "press": "فشار به دادگاه", "reform": "اصلاحات قضایی", "free": "حکم آزاد قضایی", "mediate": "میانجیگری"}
	if _queue_decision(cmd, "⚖️ " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("government")

# ── جانشینی رهبر: تربیت وارث و بحران‌های جانشینی ──
func _build_succession_card(st: Dictionary):
	var suc: Dictionary = st.get("succession", {})
	if suc.is_empty():
		return
	var card = _card("👑 جانشینی رهبر")
	var summary := SuccessionManager.get_heir_summary(st)
	var heir_lbl = Label.new(); heir_lbl.text = summary
	heir_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heir_lbl.add_theme_font_size_override("font_size", 17)
	card.add_child(heir_lbl)
	var approval := clampf(float(suc.get("heir_approval", 0.0)), 0.0, 1.0)
	_bar(card, "آمادگی وارث", approval)
	var crisis: Dictionary = suc.get("crisis", {})
	if not crisis.is_empty():
		var crisis_lbl = Label.new()
		crisis_lbl.text = "⚠️ بحران جانشینی: " + str(crisis.get("reason", "")) + (" — وارث آماده است" if suc.get("heir", "") != "" else " — وارثی نیست! جناح‌ها می‌جنگند")
		crisis_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		crisis_lbl.add_theme_font_size_override("font_size", 16); crisis_lbl.modulate = ACCENT_RED
		card.add_child(crisis_lbl)
	var train_btn = Button.new(); train_btn.text = "🎓 تربیت وارث (۱ سرمایه سیاسی)"
	train_btn.custom_minimum_size = Vector2(0, 44); train_btn.add_theme_font_size_override("font_size", 15)
	train_btn.disabled = float(st.get("policies", {}).get("political_capital", 0.0)) < 1.0 or approval >= 0.8
	train_btn.pressed.connect(FeedbackManager.play_click); train_btn.pressed.connect(_on_succession)
	_mark_decision_button(train_btn, "succession:train")
	card.add_child(train_btn)
	var hint = Label.new()
	hint.text = "وارث تربیت‌شده بحران‌های جانشینی را آرام می‌کند و اگر رهبر سقوط کند، کشور را با ویژگی خودش ادامه می‌دهد. بدون وارث، جناح‌ها و حتی کودتای قصر در راه‌اند!"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_succession():
	var check = SuccessionManager.train_heir(GameState.state)
	if not check.success:
		_toast("⚠️ " + str(check.reason))
		return
	var cmd = GameCommandClass.create_succession_action("train")
	if _queue_decision(cmd, "👑 تربیت وارث"):
		_toast("تربیت وارث ثبت شد — با پایان نوبت انجام می‌شود")
		_switch_tab("government")

# ── سیاست آموزش: فنی، دانشگاه، بورس، دیجیتال ──
func _build_education_card(st: Dictionary):
	var ed: Dictionary = st.get("education_policy", {})
	if ed.is_empty():
		return
	var card = _card("🎓 سیاست آموزش")
	_bar(card, "آموزش فنی‌وحرفه‌ای", float(ed.get("vocational", 0.3)))
	_bar(card, "استقلال دانشگاه", float(ed.get("university_autonomy", 0.4)))
	_bar(card, "پوشش بورس تحصیلی", float(ed.get("scholarships", 0.2)))
	_bar(card, "آموزش دیجیتال", float(ed.get("digital_learning", 0.2)))
	var act_row = HBoxContainer.new(); act_row.add_theme_constant_override("separation", 5); card.add_child(act_row)
	for act in [["vocational", "🔧 فنی‌وحرفه‌ای"], ["university", "🎓 استقلال دانشگاه (۱)"], ["scholarship", "🎓 بورس تحصیلی"], ["digital", "💻 آموزش دیجیتال"]]:
		var btn = Button.new(); btn.text = act[1]
		btn.custom_minimum_size = Vector2(0, 40); btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_education.bind(act[0]))
		_mark_decision_button(btn, "edu:" + act[0])
		act_row.add_child(btn)
	var hint = Label.new()
	hint.text = "فنی‌وحرفه‌ای بیکاری را می‌کاهد؛ استقلال دانشگاه نوآوری می‌آورد ولی سرمایه سیاسی می‌خواهد؛ بورس فرار مغزها را مهار و جوانان را خوشحال می‌کند؛ دیجیتال نیازمند فناوری است."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_education(action: String):
	var cmd = GameCommandClass.create_education_action(action)
	var labels := {"vocational": "آموزش فنی‌وحرفه‌ای", "university": "اصلاحات دانشگاهی", "scholarship": "بورس تحصیلی", "digital": "آموزش دیجیتال"}
	if _queue_decision(cmd, "🎓 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("government")

# ── امنیت داخلی: نظم و آزادی ──
func _build_security_card(st: Dictionary):
	var sp: Dictionary = st.get("security_policy", {})
	if sp.is_empty():
		return
	var crime := clampf(float(sp.get("crime", 0.35)), 0.0, 1.0)
	var card = _card("👮 امنیت داخلی")
	_row(card, "سطح جرم", PersianFormatter.to_persian_digits("%.0f٪" % (crime * 100.0)), _color_for(1.0 - crime))
	_bar(card, "سطح جرم", crime)
	var mode := str(sp.get("mode", "civil"))
	var mode_names := {"civil": "آزادی‌محور", "surveillance": "نظارتی", "tough": "سختگیرانه"}
	_row(card, "سیاست پلیس", str(mode_names.get(mode, mode)))
	var sec_live: Dictionary = st.get("security", {})
	var eth_risk := clampf(float(sec_live.get("ethnic_unrest_risk", 0.07)), 0.0, 1.0)
	var ext_risk := clampf(float(sec_live.get("extremism_risk", 0.11)), 0.0, 1.0)
	_row(card, "ریسک ناآرامی قومی", PersianFormatter.to_persian_digits("%.0f٪" % (eth_risk * 100.0)), _color_for(1.0 - eth_risk))
	_row(card, "ریسک افراطی‌گرایی", PersianFormatter.to_persian_digits("%.0f٪" % (ext_risk * 100.0)), _color_for(1.0 - ext_risk))
	var act_row = HBoxContainer.new(); act_row.add_theme_constant_override("separation", 4); card.add_child(act_row)
	for m in [["civil", "🕊️ آزادی‌محور"], ["surveillance", "📹 نظارتی"], ["tough", "🚨 سختگیرانه"]]:
		var btn = Button.new(); btn.text = m[1]
		btn.custom_minimum_size = Vector2(0, 36); btn.add_theme_font_size_override("font_size", 11)
		btn.toggle_mode = true; btn.button_pressed = mode == m[0]
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_security.bind(m[0]))
		_mark_decision_button(btn, "sec:" + m[0])
		act_row.add_child(btn)
	var act_row2 = HBoxContainer.new(); act_row2.add_theme_constant_override("separation", 4); card.add_child(act_row2)
	for act in [["smuggling", "🚔 مبارزه با قاچاق"], ["community", "👮 پلیس محله"], ["modern", "💻 پلیس هوشمند"]]:
		var btn = Button.new(); btn.text = act[1]
		btn.custom_minimum_size = Vector2(0, 36); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_security.bind(act[0]))
		_mark_decision_button(btn, "sec:" + act[0])
		act_row2.add_child(btn)
	var hint = Label.new()
	hint.text = "سیاست سختگیرانه جرم را می‌کاهد ولی آزادی مدنی، اعتماد رسانه و استقلال قضایی را می‌آزارد. مبارزه با قاچاق اقتصاد سایه را هم می‌خشکاند."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_security(action: String):
	var cmd = GameCommandClass.create_security_action(action)
	var labels := {"civil": "پلیس آزادی‌محور", "surveillance": "پلیس نظارتی", "tough": "پلیس سختگیرانه", "smuggling": "مبارزه با قاچاق", "community": "پلیس محله", "modern": "نوسازی پلیس"}
	if _queue_decision(cmd, "👮 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("government")

func _build_laws():
	var state = GameState.state
	var legislation: Dictionary = state.get("legislation", {})
	var enacted: Dictionary = legislation.get("enacted", {})
	var summary = _card("⚖️ نظام قانون‌گذاری ملی")
	_row(summary, "قوانین برقرار", PersianFormatter.to_persian_digits(str(enacted.size())))
	_bar(summary, "حمایت متوسط عمومی", float(legislation.get("average_support", 0.60)))
	_row(summary, "چالش‌های قضایی", PersianFormatter.to_persian_digits(str(legislation.get("legal_challenges", 0))))
	_bar(summary, "سرمایه سیاسی", float(state.get("policies", {}).get("political_capital", 0.0)) / max(float(BalanceConfig.get_value("politics.policy_capital_max", 5.0)),1.0))
	var hint = Label.new(); hint.text = "قانون پس از تصویب به‌تدریج توسط دولت و قوه قضاییه اجرا می‌شود. فساد، ضعف اداری، مخالفت عمومی و چالش قضایی سرعت اجرا را کاهش می‌دهند."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; hint.modulate = Color(0.75,0.82,0.92); summary.add_child(hint)

	var active_card = _card("📜 قوانین در حال اجرا")
	if enacted.is_empty():
		var empty = Label.new(); empty.text = "هنوز قانون ملی جدیدی تصویب نشده است."; active_card.add_child(empty)
	for law_id in enacted.keys():
		var record: Dictionary = enacted[law_id]
		var panel = PanelContainer.new(); active_card.add_child(panel)
		var box = VBoxContainer.new(); panel.add_child(box)
		var title = Label.new(); title.text = LawManager.get_law_name(law_id); title.add_theme_font_size_override("font_size",18); box.add_child(title)
		_bar(box,"پیشرفت اجرا",float(record.get("implementation",0.0)))
		_bar(box,"حمایت عمومی",float(record.get("support",0.5)))
		_row(box,"چالش قضایی",PersianFormatter.to_persian_digits(str(record.get("challenges",0))))
		var repeal = Button.new(); repeal.text = "لغو قانون"; repeal.modulate = Color(1.0,0.58,0.55)
		repeal.pressed.connect(FeedbackManager.play_click); repeal.pressed.connect(_on_law_change.bind(str(law_id),"repeal")); _mark_decision_button(repeal, "law:" + str(law_id) + ":repeal"); box.add_child(repeal)

	var available = _card("📚 لوایح قابل تصویب")
	for law_id in LawManager.get_law_ids():
		if enacted.has(law_id): continue
		var definition = LawManager.get_law(law_id)
		var row = HBoxContainer.new(); available.add_child(row)
		var info = VBoxContainer.new(); info.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(info)
		var title = Label.new(); title.text = "%s — %s" % [definition.get("name_fa",law_id),definition.get("category_fa","")]; title.add_theme_font_size_override("font_size",17); info.add_child(title)
		var desc = Label.new(); desc.text = PersianFormatter.to_persian_digits("%s\nحمایت پایه %.0f٪ | مناقشه‌برانگیزی %.0f٪ | هزینه سیاسی %.1f" % [definition.get("description",""),float(definition.get("public_support",0.5))*100.0,float(definition.get("controversy",0.5))*100.0,float(definition.get("political_cost",1.0))]); desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; desc.modulate=Color(0.72,0.78,0.88); info.add_child(desc)
		var check = LawManager.can_enact(state,law_id)
		var enact = Button.new(); enact.text="تصویب"; enact.disabled=not check.valid; enact.tooltip_text="" if check.valid else str(check.reason)
		enact.pressed.connect(FeedbackManager.play_click); enact.pressed.connect(_on_law_change.bind(str(law_id),"enact")); _mark_decision_button(enact, "law:" + str(law_id) + ":enact"); row.add_child(enact)

func _on_law_change(law_id: String, action: String):
	if _queue_decision(GameCommandClass.create_law_change(law_id,action), "⚖️ قانون «" + LawManager.get_law_name(law_id) + "» " + ("تصویب" if action == "enact" else "لغو")):
		_toast("⚖️ قانون «%s» %s — با پایان نوبت اجرا می‌شود" % [LawManager.get_law_name(law_id), "تصویب" if action == "enact" else "لغو"]); _switch_tab("laws")

# ============================================================
# تب دولت — وزیران، شایستگی، فساد و انسجام کابینه
# ============================================================
func _build_government():
	var state = GameState.state
	var cabinet: Dictionary = state.get("cabinet", {})
	var active: Dictionary = cabinet.get("active", {})
	var performance: Dictionary = cabinet.get("performance", {})
	var summary = _card("👔 هیئت دولت")
	_bar(summary, "انسجام کابینه", float(cabinet.get("cohesion", 0.65)))
	_bar(summary, "سرمایه سیاسی انتصاب", float(state.get("policies", {}).get("political_capital", 0.0)) / max(float(BalanceConfig.get_value("politics.policy_capital_max", 5.0)), 1.0))
	_row(summary, "رسوایی‌های ثبت‌شده", PersianFormatter.to_persian_digits(str(cabinet.get("scandal_count", 0))), _color_for(0.75 if int(cabinet.get("scandal_count", 0)) == 0 else 0.25))
	_bar(summary, "بار بوروکراسی", float(state.get("government_buildings", {}).get("bureaucracy_burden", 0.40)))
	_bar(summary, "تداوم سیاستگذاری", float(state.get("political_career", {}).get("policy_continuity", 0.60)))
	var emp_live: Dictionary = state.get("public_employees", {})
	if not emp_live.is_empty():
		_bar(summary, "اضافه‌استخدام دولت", float(emp_live.get("overstaffing", 0.0)))
		var arrears := clampf(float(emp_live.get("wage_arrears_months", 0.0)), 0.0, 12.0)
		_row(summary, "معوقه حقوق کارکنان", PersianFormatter.to_persian_digits("%.1f ماه" % arrears), _color_for(1.0 - arrears / 12.0))
	var hint = Label.new(); hint.text = "وزیر کارآمد خروجی وزارتخانه را بهتر می‌کند؛ پاکدستی پایین خطر رسوایی دارد و وفاداری بیشتر انسجام کابینه را حفظ می‌کند. هر انتصاب سرمایه سیاسی مصرف می‌کند."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; hint.modulate = Color(0.75, 0.82, 0.92); summary.add_child(hint)
	_build_parliament_card(state)
	_build_judiciary_card(state)
	_build_judicial_reform_card(state)
	_build_election_card(state)
	_build_succession_card(state)
	_build_education_card(state)
	_build_security_card(state)
	_build_prison_card(state)
	_build_disaster_card(state)
	_build_statistics_card(state)
	_build_factions_card(state)
	_build_governors_card(state)
	_build_ethnicity_card(state)
	_build_civic_card(state)
	_build_diaspora_card(state)

	for ministry_id in CabinetManager.get_ministry_ids():
		var ministry = CabinetManager.get_ministry(ministry_id)
		var card = _card("🏛️ %s" % str(ministry.get("name_fa", ministry_id)))
		var current_id = str(active.get(ministry_id, {}).get("candidate_id", ""))
		if current_id.is_empty():
			var vacant = Label.new(); vacant.text = "⚠️ این وزارتخانه بدون وزیر است و جریمه عملکرد دارد."; vacant.modulate = Color(1.0, 0.55, 0.5); card.add_child(vacant)
		else:
			var current = CabinetManager.get_candidate(current_id)
			_row(card, "وزیر فعلی", str(current.get("name_fa", current_id)))
			_bar(card, "عملکرد این ماه", float(performance.get(ministry_id, 0.50)))
			_bar(card, "شایستگی", float(current.get("competence", 0.5)))
			_bar(card, "پاکدستی", float(current.get("integrity", 0.5)))
			_bar(card, "وفاداری", float(current.get("loyalty", 0.5)))
			var dismiss = Button.new(); dismiss.text = "برکناری وزیر"; dismiss.modulate = Color(1.0, 0.58, 0.55)
			dismiss.pressed.connect(FeedbackManager.play_click); dismiss.pressed.connect(_on_cabinet_dismiss.bind(str(ministry_id))); _mark_decision_button(dismiss, "cabx:" + str(ministry_id)); card.add_child(dismiss)
		var candidates_title = Label.new(); candidates_title.text = "نامزدهای معرفی‌شده"; candidates_title.add_theme_font_size_override("font_size", 16); card.add_child(candidates_title)
		for candidate in ministry.get("candidates", []):
			var candidate_id = str(candidate.get("id", ""))
			var row = HBoxContainer.new(); card.add_child(row)
			var info = Label.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.text = PersianFormatter.to_persian_digits("%s | شایستگی %.0f٪ | پاکدستی %.0f٪ | وفاداری %.0f٪" % [candidate.get("name_fa", ""), float(candidate.get("competence", 0.0)) * 100.0, float(candidate.get("integrity", 0.0)) * 100.0, float(candidate.get("loyalty", 0.0)) * 100.0]); row.add_child(info)
			var check = CabinetManager.can_appoint(state, ministry_id, candidate_id)
			var appoint = Button.new(); appoint.text = "انتصاب"; appoint.disabled = not check.valid; appoint.tooltip_text = "" if check.valid else str(check.reason)
			appoint.pressed.connect(FeedbackManager.play_click); appoint.pressed.connect(_on_cabinet_appoint.bind(str(ministry_id), candidate_id, str(candidate.get("name_fa", "نامزد")))); _mark_decision_button(appoint, "cab:" + str(ministry_id)); row.add_child(appoint)

func _on_cabinet_appoint(ministry_id: String, candidate_id: String, candidate_name: String):
	if _queue_decision(GameCommandClass.create_cabinet_appointment(ministry_id, candidate_id), "👔 انتصاب وزیر: " + candidate_name):
		_toast("👔 %s با پایان نوبت به کابینه منصوب می‌شود" % candidate_name); _switch_tab("government")

func _on_cabinet_dismiss(ministry_id: String):
	if _queue_decision(GameCommandClass.create_cabinet_dismissal(ministry_id), "⛔ برکناری وزیر"):
		_toast("⛔ برکناری وزیر ثبت شد — با پایان نوبت اجرا می‌شود"); _switch_tab("government")

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
	var apply_tax = _mk_btn(c1, "✅ اعمال مالیات جدید (یک ماه می‌گذرد)", Vector2(280, 52), _on_apply_tax); _mark_decision_button(apply_tax, "tax")
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
	var apply_budget = _mk_btn(c2, "✅ اعمال بودجه (یک ماه می‌گذرد)", Vector2(280, 52), _on_apply_budget); _mark_decision_button(apply_budget, "budget")

	# --- آمار مالی ---
	var c3 = _card("📈 آمار مالی")
	_row(c3, "درآمد دولت", PersianFormatter.format_money(econ.get("government_revenue", 0)))
	_row(c3, "هزینه دولت", PersianFormatter.format_money(econ.get("government_spending", 0)))
	_row(c3, "تراز بودجه", PersianFormatter.format_money(econ.get("deficit", 0)),
		_color_for(0.5 + sign(-econ.get("deficit", 0)) * 0.5))
	_row(c3, "بدهی ملی", PersianFormatter.format_money(econ.get("national_debt", 0)))
	_bar(c3, "نسبت بدهی به GDP", clamp(econ.get("debt_to_gdp", 0) / 2.0, 0, 1))
	_row(c3, "سرمایه‌گذاری خصوصی", PersianFormatter.to_persian_digits("%.0f٪ از GDP" % (float(econ.get("private_investment", 0.15)) * 100.0)))
	var aid_month := float(econ.get("aid_inflow_daily", 0.0)) * 30.0
	if aid_month > 0.0:
		_row(c3, "کمک خارجی ماهانه", PersianFormatter.format_money(aid_month))
	# کانال‌های بودجهٔ بازرسی ۱۴۰۵ — هزینهٔ سیاست‌های فعال و استهلاک برنامه‌های یک‌بارمصرف
	var pol_month: float = float(econ.get("policy_spending_monthly", 0.0))
	if pol_month != 0.0:
		_row(c3, "هزینهٔ ماهانهٔ سیاست‌های فعال", PersianFormatter.format_money(pol_month))
	var oneoff_month: float = float(econ.get("oneoff_spending_monthly", 0.0))
	if oneoff_month > 0.0:
		_row(c3, "برنامه‌های در‌حال‌اجرا (سهم ماه)", PersianFormatter.format_money(oneoff_month))
	# کانال مالک-یکتای GDP (ممیزی نویسندگان ۱۴۰۵): اثر مداوم بخش‌ها فقط از این کانال
	# با سقف تکی/کلی می‌گذرد؛ این‌جا جمع نرخ سالانه و برترین سهم‌دهنده نشان داده می‌شود
	var boost_total_ui: float = float(econ.get("sector_boosts_total", 0.0))
	if boost_total_ui != 0.0:
		_row(c3, "رشد کانال بخش‌ها", PersianFormatter.to_persian_digits("%+.1f٪ در سال" % (boost_total_ui * 100.0)),
			_color_for(clampf(0.5 + boost_total_ui * 5.0, 0.0, 1.0)))
	var boost_top_key := ""
	var boost_top_val := 0.0
	for bk in econ.get("sector_boosts", {}).keys():
		var bv_ui: float = float(econ["sector_boosts"][bk])
		if absf(bv_ui) > absf(boost_top_val):
			boost_top_val = bv_ui
			boost_top_key = str(bk)
	if boost_top_key != "":
		_row(c3, "برترین اثر بخشی", "%s (%s)" % [boost_top_key, PersianFormatter.to_persian_digits("%+.1f٪" % (boost_top_val * 100.0))],
			_color_for(clampf(0.5 + boost_top_val * 5.0, 0.0, 1.0)))

	var cb: Dictionary = st.get("central_bank", {})
	var trade: Dictionary = st.get("trade", {})
	var macro = _card("🏦 سیاست پولی و تجاری")
	_row(macro, "حالت بانک مرکزی", {"independent":"مستقل/قاعده تیلور", "manual_rate":"نرخ دستوری", "inflation_target":"هدف‌گذاری تورم"}.get(str(cb.get("policy_mode", "independent")), "مستقل"))
	_row(macro, "نرخ بهره فعلی", PersianFormatter.format_percent(float(cb.get("interest_rate", 0.15))))
	interest_slider = HSlider.new(); interest_slider.min_value = 0; interest_slider.max_value = 40; interest_slider.step = 0.5; interest_slider.value = float(cb.get("manual_rate", cb.get("interest_rate", 0.15))) * 100.0; macro.add_child(interest_slider)
	_mark_decision_button(_mk_btn(macro, "اعمال نرخ بهره دستوری", Vector2(250, 46), _on_apply_manual_rate), "money:manual_rate")
	inflation_target_slider = HSlider.new(); inflation_target_slider.min_value = 0; inflation_target_slider.max_value = 20; inflation_target_slider.step = 0.5; inflation_target_slider.value = float(cb.get("inflation_target", 0.05)) * 100.0; macro.add_child(inflation_target_slider)
	_mark_decision_button(_mk_btn(macro, "اعمال هدف تورم", Vector2(220, 46), _on_apply_inflation_target), "money:inflation_target")
	_mark_decision_button(_mk_btn(macro, "بازگرداندن استقلال بانک مرکزی", Vector2(280, 46), _on_restore_central_bank_independence), "money:independent")
	_row(macro, "تعرفه فعلی", PersianFormatter.format_percent(float(trade.get("tariff_rate", 0.15))))
	tariff_slider = HSlider.new(); tariff_slider.min_value = 0; tariff_slider.max_value = 60; tariff_slider.step = 1; tariff_slider.value = float(trade.get("tariff_rate", 0.15)) * 100.0; macro.add_child(tariff_slider)
	_mark_decision_button(_mk_btn(macro, "اعمال تعرفه گمرکی", Vector2(220, 46), _on_apply_tariff), "tariff")
	_build_cycle_card(st)
	_build_banking_card(st)
	_build_stock_card(st)
	_build_infrastructure_card(st)
	_build_transport_card(st)
	_build_water_card(st)
	_build_watershed_card(st)
	_build_waste_card(st)
	_build_climate_card(st)
	_build_commodities_card(st)
	_build_forex_card(st)
	_build_energy_card(st)
	_build_fuel_card(st)
	_build_downstream_card(st)
	_build_industry_card(st)
	_build_mining_card(st)
	_build_basic_industry_card(st)
	_build_sme_card(st)
	_build_transit_card(st)
	_build_agriculture_card(st)
	_build_food_chain_card(st)
	_build_livestock_card(st)
	_build_tourism_card(st)
	_build_retail_card(st)
	_build_creative_card(st)
	_build_nation_brand_card(st)
	_build_health_tourism_card(st)
	_build_waste_management_card(st)
	_build_pro_sports_card(st)
	_build_supply_card(st)
	_build_textile_card(st)
	_build_tax_card(st)
	_build_ev_card(st)
	_build_aviation_card(st)
	_build_postal_card(st)
	_build_standards_card(st)
	_build_trade_policy_card(st)
	_build_fdi_card(st)
	_build_shadow_card(st)
	_build_policy_center()

func _on_apply_manual_rate():
	var rate = float(interest_slider.value) / 100.0
	if _queue_decision(GameCommandClass.create_monetary_policy("manual_rate", rate), "🏦 نرخ بهره دستوری: " + PersianFormatter.format_percent(rate)):
		_toast("🏦 نرخ بهره دستوری %s ثبت شد — با پایان نوبت اعمال می‌شود" % PersianFormatter.format_percent(rate)); _switch_tab("economy")

func _on_apply_inflation_target():
	var target = float(inflation_target_slider.value) / 100.0
	if _queue_decision(GameCommandClass.create_monetary_policy("inflation_target", target), "🎯 هدف تورم: " + PersianFormatter.format_percent(target)):
		_toast("🎯 هدف تورم %s ثبت شد — با پایان نوبت اعمال می‌شود" % PersianFormatter.format_percent(target)); _switch_tab("economy")

func _on_restore_central_bank_independence():
	if _queue_decision(GameCommandClass.create_monetary_policy("independent", 0.0), "🏦 بازگشت استقلال بانک مرکزی"):
		_toast("🏦 بازگشت استقلال بانک مرکزی ثبت شد — با پایان نوبت اعمال می‌شود"); _switch_tab("economy")

func _on_apply_tariff():
	var rate = float(tariff_slider.value) / 100.0
	if _queue_decision(GameCommandClass.create_tariff_set(rate), "🚢 تعرفه گمرکی: " + PersianFormatter.format_percent(rate)):
		_toast("🚢 تعرفه گمرکی %s ثبت شد — با پایان نوبت اعمال می‌شود" % PersianFormatter.format_percent(rate)); _switch_tab("economy")

# ── چرخه اقتصادی: رونق/رشد/رکود/رکود عمیق + اعتماد سرمایه‌گذاران ──
func _build_cycle_card(st: Dictionary):
	var cycle: Dictionary = st.get("economy", {}).get("cycle", {})
	if cycle.is_empty():
		return
	var phase: String = str(cycle.get("phase", "growth"))
	var phase_fa: String = String({"boom": "🔥 رونق", "growth": "📈 رشد", "stagnation": "📉 رکود خفیف", "recession": "🛑 رکود عمیق"}.get(phase, phase))
	var card = _card("🔄 چرخه اقتصادی — " + phase_fa)
	var confidence: float = clampf(float(cycle.get("confidence", 55.0)), 0.0, 100.0)
	_bar(card, "اعتماد سرمایه‌گذاران", confidence / 100.0)
	_row(card, "مدت باقی‌مانده فاز", "~%s ماه" % PersianFormatter.to_persian_digits(str(max(1, int(ceil(float(cycle.get("months_left", 1.0))))))))
	var effect: String = String({"boom": "+۱.۲٪ رشد", "growth": "+۰.۴٪ رشد", "stagnation": "−۰.۶٪ رشد", "recession": "−۱.۴٪ رشد و بیکاری فزاینده"}.get(phase, ""))
	var eff_lbl = Label.new(); eff_lbl.text = "اثر فاز: " + effect
	eff_lbl.add_theme_font_size_override("font_size", 17); eff_lbl.modulate = TEXT_MUTED; card.add_child(eff_lbl)
	var hint = Label.new()
	hint.text = "ثبات، فساد پایین، مالیات متعادل و تورم کنترل‌شده اعتماد سرمایه‌گذاران را می‌سازند و شانس رونق را بالا می‌برند."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 16); hint.modulate = TEXT_FAINT; card.add_child(hint)

# ── بازار جهانی کالا: قیمت‌ها، ذخایر راهبردی و فروش ──
func _build_commodities_card(st: Dictionary):
	var com: Dictionary = st.get("commodities", {})
	if com.is_empty():
		return
	var prices: Dictionary = com.get("prices", {})
	var reserves: Dictionary = com.get("reserves", {})
	var card = _card("📦 بازار جهانی کالا")
	var shock := str(com.get("shock", ""))
	if shock != "":
		var shock_lbl = Label.new()
		shock_lbl.text = "⚠️ شوک بازار فعال: " + {"oil_boom": "جهش نفت", "oil_crash": "سقوط نفت", "drought": "خشکسالی جهانی", "mineral_strike": "اعتصاب معدن", "gas_dispute": "اختلاف گازی"}.get(shock, shock)
		shock_lbl.add_theme_font_size_override("font_size", 17); shock_lbl.modulate = ACCENT_ORANGE
		card.add_child(shock_lbl)
	for cid in CommodityManager.COMMODITIES:
		var price := float(prices.get(cid, 0.0))
		var reserve := float(reserves.get(cid, 0.0))
		var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 8); card.add_child(row)
		var info = VBoxContainer.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; info.add_theme_constant_override("separation", 2); row.add_child(info)
		var name = Label.new(); name.text = "%s — قیمت جهانی %s | ذخیره %s واحد" % [cid, PersianFormatter.format_money(price), PersianFormatter.to_persian_digits(str(int(reserve)))]
		name.add_theme_font_size_override("font_size", 17); info.add_child(name)
		# روند قیمت: مقایسه با ماه قبل
		var history: Array = com.get("history", [])
		if history.size() >= 2:
			var prev: Dictionary = history[history.size() - 2]
			var prev_price := float(prev.get("prices", {}).get(cid, price))
			var trend := price - prev_price
			var trend_lbl = Label.new()
			trend_lbl.text = ("▲+" if trend >= 0.0 else "▼") + PersianFormatter.to_persian_digits("%.1f" % absf(trend))
			trend_lbl.add_theme_font_size_override("font_size", 14)
			trend_lbl.modulate = Color(0.4, 0.9, 0.55) if trend >= 0.0 else Color(1.0, 0.4, 0.4)
			info.add_child(trend_lbl)
		# دکمه فروش ۱۰٪ ذخیره
		var sell_btn = Button.new(); sell_btn.text = "فروش ۱۰٪"
		sell_btn.custom_minimum_size = Vector2(110, 40); sell_btn.add_theme_font_size_override("font_size", 15)
		sell_btn.disabled = reserve < 10.0
		sell_btn.pressed.connect(FeedbackManager.play_click)
		sell_btn.pressed.connect(_on_commodity_sell.bind(cid))
		_mark_decision_button(sell_btn, "com_sell:" + cid)
		row.add_child(sell_btn)
	var hint = Label.new()
	hint.text = "قیمت کالاها هر نوبت با عرضه/تقاضا، جنگ‌ها و شوک‌ها نوسان می‌کند. فروش در قیمت بالا ذخایر ارزی می‌سازد؛ درآمد نفتی نیز هر ماه خودکار به ذخایر اضافه می‌شود."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 15); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_commodity_sell(commodity: String):
	var com: Dictionary = GameState.state.get("commodities", {})
	var reserve := float(com.get("reserves", {}).get(commodity, 0.0))
	var amount := reserve * 0.10
	var check = CommodityManager.can_trade(GameState.state, commodity, amount)
	if not check.valid:
		_toast("⚠️ " + str(check.reason))
		return
	var cmd = GameCommandClass.create_commodity_trade(commodity, amount)
	if _queue_decision(cmd, "📦 فروش ۱۰٪ " + commodity):
		_toast("فروش %s ثبت شد — با پایان نوبت انجام می‌شود" % commodity)
		_switch_tab("economy")

# ── سیاست ارزی: نرخ ارز، مداخله، کاهش ارزش، کنترل سرمایه ──
func _build_forex_card(st: Dictionary):
	var forex: Dictionary = st.get("forex", {})
	if forex.is_empty():
		return
	var rate := float(st.get("central_bank", {}).get("exchange_rate", 1.0))
	var card = _card("💱 سیاست ارزی")
	_row(card, "نرخ ارز", PersianFormatter.to_persian_digits("%.2f" % rate))
	# بازرسی تراز پرداخت‌ها: ذخایر حالا مخزن مرجع واحد است که تراز تجاری تغذیه می‌کند
	var econ_fx: Dictionary = st.get("economy", {})
	var reserves_v := float(econ_fx.get("foreign_reserves", 0.0))
	var res_gdp_ratio := reserves_v / maxf(float(econ_fx.get("gdp", 1.0)), 1.0)
	_row(card, "ذخایر ارزی", PersianFormatter.format_money(reserves_v), _color_for(clampf(res_gdp_ratio / 0.15, 0.0, 1.0)))
	# کانال ورودی بخشی ذخایر (بازرسی ارزی ۱۴۰۵): حواله‌ها، ترانزیت هاب، گردشگری سلامت،
	# صادرات فناوری و محصولات پالایشی — تسویهٔ روزانه فقط توسط بانک مرکزی (مالکیت یکتا).
	# جمع کانال علامت‌دار نمایش داده می‌شود: مثبت=ورود ارز، منفی=خروج/فرار سرمایه.
	var inflow_m: float = float(econ_fx.get("reserve_inflows_monthly", 0.0))
	if inflow_m != 0.0:
		var inflow_label := "ورودی بخشی ذخایر (ماهانه)" if inflow_m > 0.0 else "خروج بخشی ذخایر (ماهانه)"
		_row(card, inflow_label, PersianFormatter.format_money(inflow_m), _color_for(0.7 if inflow_m > 0.0 else 0.15))
	_row(card, "صرف بازار سیاه", PersianFormatter.to_persian_digits("%.0f٪" % (float(forex.get("black_premium", 0.05)) * 100.0)), _color_for(1.0 - clampf(float(forex.get("black_premium", 0.05)) * 5.0, 0.0, 1.0)))
	_row(card, "کنترل سرمایه", "فعال" if bool(forex.get("capital_control", false)) else "غیرفعال")
	var inter := clampf(float(forex.get("intervention", 0.0)), 0.0, 1.0)
	_bar(card, "سطح مداخله بانک مرکزی", inter)
	# بازرسی ارزی: صرف باقی‌ماندهٔ مداخله (محوشونده) — حمایت مصنوعی موقت است
	var prem_v := float(forex.get("intervention_premium", 0.0))
	if prem_v < -0.001:
		_row(card, "حمایت باقی‌مانده از نرخ", PersianFormatter.to_persian_digits("٪%.1f" % (-prem_v * 100.0)) + " (در حال محو)", _color_for(0.5))
	var btn_row = HBoxContainer.new(); btn_row.add_theme_constant_override("separation", 6); card.add_child(btn_row)
	var int_btn = Button.new(); int_btn.text = "💪 مداخله (۲ میلیارد)"
	int_btn.custom_minimum_size = Vector2(0, 44); int_btn.add_theme_font_size_override("font_size", 15)
	int_btn.disabled = not ForexManager.can_intervene(st).valid
	int_btn.pressed.connect(FeedbackManager.play_click); int_btn.pressed.connect(_on_forex.bind("intervene"))
	_mark_decision_button(int_btn, "forex:intervene")
	btn_row.add_child(int_btn)
	var dev_btn = Button.new(); dev_btn.text = "📉 کاهش ارزش ۱۰٪"
	dev_btn.custom_minimum_size = Vector2(0, 44); dev_btn.add_theme_font_size_override("font_size", 15)
	dev_btn.pressed.connect(FeedbackManager.play_click); dev_btn.pressed.connect(_on_forex.bind("devalue"))
	_mark_decision_button(dev_btn, "forex:devalue")
	btn_row.add_child(dev_btn)
	var cc_btn = Button.new(); cc_btn.text = "🔒 کنترل سرمایه"
	cc_btn.custom_minimum_size = Vector2(0, 44); cc_btn.add_theme_font_size_override("font_size", 15)
	cc_btn.pressed.connect(FeedbackManager.play_click); cc_btn.pressed.connect(_on_forex.bind("control"))
	_mark_decision_button(cc_btn, "forex:control")
	btn_row.add_child(cc_btn)
	var hint = Label.new()
	hint.text = "مداخله ارز را تقویت می‌کند ولی ذخایر می‌سوزاند؛ کاهش ارزش صادرات را می‌برد ولی تورم می‌آورد؛ کنترل سرمایه فرار ارز را مهار می‌کند ولی سرمایه‌گذاری خارجی را می‌ترساند."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_forex(action: String):
	var cmd: GameCommandClass
	var label := ""
	match action:
		"intervene":
			cmd = GameCommandClass.create_forex_intervene(10.0)
			label = "مداخله ارزی (۱۰ میلیارد)"
		"devalue":
			cmd = GameCommandClass.create_forex_devalue(10.0)
			label = "کاهش ارزش ۱۰٪"
		_:
			cmd = GameCommandClass.create_capital_control()
			label = "تغییر کنترل سرمایه"
	if _queue_decision(cmd, "💱 " + label):
		_toast(label + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("economy")

# ── اقتصاد سایه و فساد: سرکوب/عفو + رسیدگی به رسوایی‌ها ──
func _build_shadow_card(st: Dictionary):
	var shadow: Dictionary = st.get("shadow", {})
	if shadow.is_empty():
		return
	var size := clampf(float(shadow.get("size", 0.18)), 0.0, 1.0)
	var card = _card("🕳️ اقتصاد سایه و فساد")
	_row(card, "اندازه اقتصاد سایه", PersianFormatter.to_persian_digits("%.0f٪ از GDP" % (size * 100.0)), _color_for(1.0 - size))
	var tax_loss_month := float(st.get("economy", {}).get("informal_tax_loss_daily", 0.0)) * 30.0
	if tax_loss_month > 0.0:
		_row(card, "فرار مالیاتی ماهانه", PersianFormatter.format_money(tax_loss_month))
	var scandal: Dictionary = shadow.get("scandal", {})
	if not scandal.is_empty():
		var scandal_lbl = Label.new()
		scandal_lbl.text = "🚨 رسوایی «" + str(scandal.get("id", "")) + "» — تصمیم بگیرید:"
		scandal_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		scandal_lbl.add_theme_font_size_override("font_size", 17); scandal_lbl.modulate = ACCENT_RED
		card.add_child(scandal_lbl)
		var s_row = HBoxContainer.new(); s_row.add_theme_constant_override("separation", 5); card.add_child(s_row)
		for act in [["cover", "🕶️ پوشش (۱)"], ["investigate", "⚖️ تحقیق"], ["ignore", "🤷 نادیده"]]:
			var btn = Button.new(); btn.text = act[1]
			btn.custom_minimum_size = Vector2(0, 40); btn.add_theme_font_size_override("font_size", 14)
			btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_shadow.bind(act[0]))
			_mark_decision_button(btn, "shadow:" + act[0])
			s_row.add_child(btn)
	var a_row = HBoxContainer.new(); a_row.add_theme_constant_override("separation", 5); card.add_child(a_row)
	var crack_btn = Button.new(); crack_btn.text = "🚔 سرکوب سایه"
	crack_btn.custom_minimum_size = Vector2(0, 42); crack_btn.add_theme_font_size_override("font_size", 15)
	crack_btn.disabled = size < 0.08
	crack_btn.pressed.connect(FeedbackManager.play_click); crack_btn.pressed.connect(_on_shadow.bind("crackdown"))
	_mark_decision_button(crack_btn, "shadow:crackdown")
	a_row.add_child(crack_btn)
	var amn_btn = Button.new(); amn_btn.text = "🤝 عفو مالیاتی"
	amn_btn.custom_minimum_size = Vector2(0, 42); amn_btn.add_theme_font_size_override("font_size", 15)
	amn_btn.disabled = size < 0.10
	amn_btn.pressed.connect(FeedbackManager.play_click); amn_btn.pressed.connect(_on_shadow.bind("amnesty"))
	_mark_decision_button(amn_btn, "shadow:amnesty")
	a_row.add_child(amn_btn)
	var hint = Label.new()
	hint.text = "سایه با مالیات بالا و فساد رشد می‌کند؛ بیکاری را جذب می‌کند ولی درآمد مالیاتی را می‌دزدد. سرکوب ناآرامی می‌آورد؛ عفو سرمایه برمی‌گرداند."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_shadow(action: String):
	var cmd = GameCommandClass.create_shadow_action(action)
	var labels := {"crackdown": "سرکوب سایه", "amnesty": "عفو مالیاتی", "cover": "پوشش رسوایی", "investigate": "تحقیق رسوایی", "ignore": "نادیده‌گرفتن رسوایی"}
	if _queue_decision(cmd, "🕳️ " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("economy")

# ── سیاست انرژی و اقلیم: سبد انرژی، امنیت، یارانه ──
func _build_energy_card(st: Dictionary):
	var en: Dictionary = st.get("energy_policy", {})
	if en.is_empty():
		return
	var mix: Dictionary = en.get("mix", {})
	var card = _card("⚡ سیاست انرژی و اقلیم")
	_row(card, "امنیت انرژی", PersianFormatter.to_persian_digits("%.0f٪" % (float(en.get("security", 0.6)) * 100.0)), _color_for(float(en.get("security", 0.6))))
	_row(card, "ریسک خاموشی", PersianFormatter.to_persian_digits("%.0f٪" % (float(en.get("blackout_risk", 0.1)) * 100.0)), _color_for(1.0 - float(en.get("blackout_risk", 0.1))))
	var p_rel := clampf(float(st.get("economy", {}).get("power_reliability", 0.75)), 0.0, 1.0)
	_row(card, "پایداری شبکه برق", PersianFormatter.to_persian_digits("%.0f٪" % (p_rel * 100.0)), _color_for(p_rel))
	_row(card, "انتشار کربن", PersianFormatter.to_persian_digits("%.0f٪" % (float(en.get("emissions", 0.7)) * 100.0)), _color_for(1.0 - float(en.get("emissions", 0.7))))
	_bar(card, "سهم فسیلی", float(mix.get("fossil", 0.7)))
	_bar(card, "سهم تجدیدپذیر", float(mix.get("renewable", 0.1)))
	_bar(card, "سهم هسته‌ای", float(mix.get("nuclear", 0.05)))
	_row(card, "یارانه انرژی", PersianFormatter.to_persian_digits("%.0f٪" % (float(en.get("subsidies", 0.45)) * 100.0)))
	var act_row = HBoxContainer.new(); act_row.add_theme_constant_override("separation", 5); card.add_child(act_row)
	for act in [["renewable", "🌱 سرمایه سبز"], ["nuclear", "☢️ هسته‌ای"], ["subsidy", "⚡ اصلاح یارانه"], ["climate", "🌍 تعهد اقلیمی"]]:
		var btn = Button.new(); btn.text = act[1]
		btn.custom_minimum_size = Vector2(0, 40); btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_energy.bind(act[0]))
		_mark_decision_button(btn, "energy:" + act[0])
		act_row.add_child(btn)
	var hint = Label.new()
	hint.text = "تنوع سبد امنیت می‌سازد؛ یارانه رضایت می‌خرد ولی بودجه و شبکه را می‌سوزاند. فناوری «انرژی پاک» سرمایه‌گذاری سبز را ارزان می‌کند و قیمت نفت بر هزینه‌ها اثر دارد."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_energy(action: String):
	var cmd = GameCommandClass.create_energy_action(action)
	var labels := {"renewable": "سرمایه‌گذاری سبز", "nuclear": "نیروگاه هسته‌ای", "subsidy": "اصلاح یارانه انرژی", "climate": "تعهد اقلیمی"}
	if _queue_decision(cmd, "⚡ " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("economy")

# ── سیاست صنعتی: راهبرد، شرکت‌های دولتی، صنعت برگزیده، مناطق آزاد ──
func _build_industry_card(st: Dictionary):
	var ind: Dictionary = st.get("industry_policy", {})
	if ind.is_empty():
		return
	var strategy := str(ind.get("strategy", "diversified"))
	var soe := clampf(float(ind.get("soe_share", 0.3)), 0.0, 1.0)
	var card = _card("🏭 سیاست صنعتی")
	_row(card, "راهبرد فعال", str(IndustryManager.STRATEGIES.get(strategy, {}).get("name_fa", strategy)))
	_bar(card, "سهم شرکت‌های دولتی", soe)
	_row(card, "مناطق آزاد", PersianFormatter.to_persian_digits("%.0f٪" % (float(ind.get("free_zones", 0.0)) * 100.0)))
	var winner := str(ind.get("winner", ""))
	_row(card, "صنعت برگزیده", IndustryManager._winner_name(winner) if winner != "" else "—")
	_row(card, "تاریخچه ملی‌کردن / خصوصی‌سازی", "%s / %s" % [PersianFormatter.to_persian_digits(str(ind.get("nationalized", 0))), PersianFormatter.to_persian_digits(str(ind.get("privatized", 0)))])
	var strat_row = HBoxContainer.new(); strat_row.add_theme_constant_override("separation", 5); card.add_child(strat_row)
	var strat_lbl = Label.new(); strat_lbl.text = "راهبرد:"; strat_lbl.add_theme_font_size_override("font_size", 15); strat_lbl.modulate = TEXT_MUTED; strat_row.add_child(strat_lbl)
	for sid in ["diversified", "high_tech", "heavy", "export"]:
		var info: Dictionary = IndustryManager.STRATEGIES.get(sid, {})
		var btn = Button.new(); btn.text = str(info.get("name_fa", sid))
		btn.custom_minimum_size = Vector2(0, 38); btn.add_theme_font_size_override("font_size", 13)
		btn.toggle_mode = true; btn.button_pressed = strategy == sid
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_industry.bind("strategy", sid))
		_mark_decision_button(btn, "industry:strategy:" + sid)
		strat_row.add_child(btn)
	# صنعت برگزیده
	var win_row = HBoxContainer.new(); win_row.add_theme_constant_override("separation", 5); card.add_child(win_row)
	var win_lbl = Label.new(); win_lbl.text = "برگزیده:"; win_lbl.add_theme_font_size_override("font_size", 15); win_lbl.modulate = TEXT_MUTED; win_row.add_child(win_lbl)
	for w in IndustryManager.WINNERS:
		var btn = Button.new(); btn.text = str(w.get("name_fa", ""))
		btn.custom_minimum_size = Vector2(0, 36); btn.add_theme_font_size_override("font_size", 12)
		btn.toggle_mode = true; btn.button_pressed = winner == str(w.get("id", ""))
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_industry.bind("winner", str(w.get("id", ""))))
		_mark_decision_button(btn, "industry:winner:" + str(w.get("id", "")))
		win_row.add_child(btn)
	var act_row = HBoxContainer.new(); act_row.add_theme_constant_override("separation", 5); card.add_child(act_row)
	for act in [["privatize", "🏷️ خصوصی‌سازی"], ["nationalize", "🏛️ ملی‌سازی"], ["free_zone", "🏙️ منطقه آزاد"]]:
		var btn = Button.new(); btn.text = act[1]
		btn.custom_minimum_size = Vector2(0, 40); btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_industry.bind(act[0], ""))
		_mark_decision_button(btn, "industry:" + act[0])
		act_row.add_child(btn)
	var hint = Label.new()
	hint.text = "راهبرد فناوری‌محور نیازمند صنعت بالاست؛ سنگین به انرژی ارزان. خصوصی‌سازی کارآمدی می‌آورد ولی کارگران و نخبگان واکنش نشان می‌دهند؛ ملی‌سازی برعکس."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_industry(action: String, value: String):
	var cmd = GameCommandClass.create_industry_action(action, value)
	var labels := {"strategy": "تغییر راهبرد صنعتی", "winner": "انتخاب صنعت برگزیده", "privatize": "خصوصی‌سازی", "nationalize": "ملی‌سازی", "free_zone": "منطقه آزاد"}
	if _queue_decision(cmd, "🏭 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("economy")

# ── کشاورزی و امنیت غذایی ──
func _build_agriculture_card(st: Dictionary):
	var ag: Dictionary = st.get("agri_policy", {})
	if ag.is_empty():
		return
	var card = _card("🌾 کشاورزی و امنیت غذایی")
	_bar(card, "ذخیره راهبردی غلات", float(ag.get("grain_reserve", 0.3)))
	_bar(card, "یارانه کود", float(ag.get("fertilizer_subsidy", 0.4)))
	_bar(card, "تنوع کشت", float(ag.get("crop_diversity", 0.3)))
	_bar(card, "آبیاری هوشمند", float(ag.get("smart_irrigation", 0.2)))
	var act_row = HBoxContainer.new(); act_row.add_theme_constant_override("separation", 5); card.add_child(act_row)
	for act in [["grain", "🌾 ذخیره غلات"], ["fertilizer", "🧪 یارانه کود"], ["diversity", "🌱 تنوع کشت"], ["irrigation", "💧 آبیاری هوشمند"]]:
		var btn = Button.new(); btn.text = act[1]
		btn.custom_minimum_size = Vector2(0, 40); btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_agriculture.bind(act[0]))
		_mark_decision_button(btn, "agri:" + act[0])
		act_row.add_child(btn)
	var hint = Label.new()
	hint.text = "ذخیره غلات تورم خوراک را در شوک‌های قیمت گندم مهار می‌کند؛ تنوع کشت تاب‌آوری خشکسالی می‌آورد؛ آبیاری هوشمند آب را نجات می‌دهد و نیازمند صنعت ۸+ است."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_agriculture(action: String):
	var cmd = GameCommandClass.create_agriculture_action(action)
	var labels := {"grain": "ذخیره راهبردی غلات", "fertilizer": "یارانه کود", "diversity": "تنوع کشت", "irrigation": "آبیاری هوشمند"}
	if _queue_decision(cmd, "🌾 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("economy")

# ── گردشگری: ویزا، مهمان‌پذیری، کمپین، سلامت ──
func _build_tourism_card(st: Dictionary):
	var tp: Dictionary = st.get("tourism_policy", {})
	if tp.is_empty():
		return
	var tourism: Dictionary = st.get("tourism", {})
	var card = _card("✈️ گردشگری")
	_row(card, "بازدیدکنندگان", PersianFormatter.format_large(tourism.get("visitors", 0)) + " نفر")
	_row(card, "درآمد سالانه", PersianFormatter.format_money(tourism.get("revenue", 0.0)))
	var visa := str(tp.get("visa", "moderate"))
	var visa_names := {"open": "تسهیل کامل", "moderate": "متوسط", "strict": "سختگیرانه"}
	_row(card, "سیاست ویزا", str(visa_names.get(visa, visa)))
	_bar(card, "مهمان‌پذیری", float(tp.get("hospitality", 0.4)))
	var act_row = HBoxContainer.new(); act_row.add_theme_constant_override("separation", 4); card.add_child(act_row)
	for v in [["open", "🛂 ویزا باز"], ["moderate", "🛂 متوسط"], ["strict", "🛂 سخت"]]:
		var btn = Button.new(); btn.text = v[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.toggle_mode = true; btn.button_pressed = visa == v[0]
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_tourism.bind("visa", v[0]))
		_mark_decision_button(btn, "tour:visa:" + v[0])
		act_row.add_child(btn)
	var act_row2 = HBoxContainer.new(); act_row2.add_theme_constant_override("separation", 4); card.add_child(act_row2)
	for act in [["hospitality", "🏨 مهمان‌پذیری"], ["campaign", "📣 کمپین مقصد"], ["health", "🏥 گردشگری سلامت"]]:
		var btn = Button.new(); btn.text = act[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_tourism.bind(act[0], ""))
		_mark_decision_button(btn, "tour:" + act[0])
		act_row2.add_child(btn)
	var hint = Label.new()
	hint.text = "جاذبه از قدرت نرم، امنیت و ارز ارزان می‌آید؛ ویزای باز تعداد را می‌برد ولی امنیت را به چالش می‌کشد. گردشگری سلامت نیازمند بهداشت ۷۰٪+ است."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_tourism(action: String, value: String):
	var cmd = GameCommandClass.create_tourism_action(action, value)
	var labels := {"visa": "تغییر سیاست ویزا", "hospitality": "سرمایه مهمان‌پذیری", "campaign": "کمپین مقصد", "health": "گردشگری سلامت"}
	if _queue_decision(cmd, "✈️ " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("economy")

# ── زیرساخت: نگهداری و اولویت توسعه ──
func _build_infrastructure_card(st: Dictionary):
	var ip: Dictionary = st.get("infra_policy", {})
	if ip.is_empty():
		return
	var infra: Dictionary = st.get("infrastructure", {})
	var card = _card("🏗️ زیرساخت و نگهداری")
	_row(card, "کیفیت کلی", PersianFormatter.to_persian_digits("%.0f٪" % (float(infra.get("quality", 0.6)) * 100.0)))
	_bar(card, "پوسیدگی زیرساخت", float(ip.get("decay", 0.3)))
	_row(card, "سهم نگهداری", PersianFormatter.to_persian_digits("%.0f٪" % (float(ip.get("maintenance", 0.4)) * 100.0)))
	var focus := str(ip.get("focus", "roads"))
	var focus_names := {"roads": "جاده و حمل‌ونقل", "power": "شبکه برق", "water": "آب و فاضلاب", "telecom": "مخابرات"}
	_row(card, "اولویت توسعه", str(focus_names.get(focus, focus)))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for m in [[0.2, "🟢 کم (۲۰٪)"], [0.5, "🟡 متوسط (۵۰٪)"], [0.8, "🔴 زیاد (۸۰٪)"]]:
		var btn = Button.new(); btn.text = m[1]
		btn.custom_minimum_size = Vector2(0, 36); btn.add_theme_font_size_override("font_size", 11)
		btn.toggle_mode = true; btn.button_pressed = absf(float(ip.get("maintenance", 0.4)) - m[0]) < 0.05
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_infra.bind("maintenance", m[0]))
		_mark_decision_button(btn, "infra:maintenance:" + str(m[0]))
		row.add_child(btn)
	var row2 = HBoxContainer.new(); row2.add_theme_constant_override("separation", 4); card.add_child(row2)
	for f in [["focus_roads", "🛣️ جاده"], ["focus_power", "⚡ برق"], ["focus_water", "💧 آب"], ["focus_telecom", "📡 مخابرات"]]:
		var btn = Button.new(); btn.text = f[1]
		btn.custom_minimum_size = Vector2(0, 36); btn.add_theme_font_size_override("font_size", 11)
		btn.toggle_mode = true; btn.button_pressed = focus == f[0].replace("focus_", "")
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_infra.bind(f[0], 0.0))
		_mark_decision_button(btn, "infra:" + f[0])
		row2.add_child(btn)
	var hint = Label.new()
	hint.text = "بی‌توجهی به نگهداری، زیرساخت را می‌پوساند (خاموشی و تصادفات). نگهداری خوب اقتصاد را روان می‌کند ولی بدهی می‌آورد؛ اولویت، بخش هدف را سریع‌تر رشد می‌دهد."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_infra(action: String, value: float):
	var cmd = GameCommandClass.create_infra_action(action, value)
	var labels := {"maintenance": "تنظیم نگهداری", "focus_roads": "اولویت جاده", "focus_power": "اولویت برق", "focus_water": "اولویت آب", "focus_telecom": "اولویت مخابرات"}
	if _queue_decision(cmd, "🏗️ " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("economy")

# ── اقلیم و محیط زیست ──
func _build_climate_card(st: Dictionary):
	var cp: Dictionary = st.get("climate_policy", {})
	if cp.is_empty():
		return
	var env: Dictionary = st.get("environment", {})
	var card = _card("🌍 اقلیم و محیط زیست")
	_row(card, "آلودگی", PersianFormatter.to_persian_digits("%.0f٪" % (float(cp.get("pollution", 0.5)) * 100.0)), _color_for(1.0 - float(cp.get("pollution", 0.5))))
	_bar(card, "آلودگی", float(cp.get("pollution", 0.5)))
	_row(card, "کیفیت هوا", PersianFormatter.to_persian_digits("%.0f٪" % (float(env.get("air_quality", 0.5)) * 100.0)))
	_bar(card, "مالیات کربن", float(cp.get("carbon_tax", 0.1)))
	_bar(card, "جنگل‌کاری", float(cp.get("reforestation", 0.2)))
	_bar(card, "آمادگی بلایا", float(cp.get("disaster_readiness", 0.3)))
	_row(card, "بلایای مدیریت‌شده", PersianFormatter.to_persian_digits(str(cp.get("disasters_handled", 0))))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for c in [[0.0, "🏭 بدون کربن"], [0.3, "🟡 کربن ۳۰٪"], [0.6, "🟢 کربن ۶۰٪"]]:
		var btn = Button.new(); btn.text = c[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.toggle_mode = true; btn.button_pressed = absf(float(cp.get("carbon_tax", 0.1)) - c[0]) < 0.05
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_climate.bind("carbon", c[0]))
		_mark_decision_button(btn, "climate:carbon:" + str(c[0]))
		row.add_child(btn)
	var row2 = HBoxContainer.new(); row2.add_theme_constant_override("separation", 4); card.add_child(row2)
	for a in [["reforest", "🌳 جنگل‌کاری"], ["disaster", "🚨 آمادگی بلایا"], ["greencity", "🌿 شهر سبز"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_climate.bind(a[0], 0.0))
		_mark_decision_button(btn, "climate:" + a[0])
		row2.add_child(btn)
	var hint = Label.new()
	hint.text = "مالیات کربن درآمد و فناوری سبز می‌آورد ولی نخبگان صنعتی را می‌رنجاند؛ آلودگی سلامت را می‌خورد؛ آمادگی بلایا خسارت سیل/زلزله را مهار می‌کند."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_climate(action: String, value: float):
	var cmd = GameCommandClass.create_climate_action(action, value)
	var labels := {"carbon": "تنظیم مالیات کربن", "reforest": "جنگل‌کاری", "disaster": "آمادگی بلایا", "greencity": "شهر سبز"}
	if _queue_decision(cmd, "🌍 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("economy")

# ── تجارت راهبردی و زنجیره تأمین ──
func _build_trade_policy_card(st: Dictionary):
	var tp: Dictionary = st.get("trade_policy", {})
	if tp.is_empty():
		return
	var trade: Dictionary = st.get("trade", {})
	var card = _card("📦 تجارت راهبردی")
	_row(card, "سهم نفت از صادرات", PersianFormatter.to_persian_digits("%.0f٪" % (float(trade.get("oil_export_share", 0.6)) * 100.0)), _color_for(1.0 - float(trade.get("oil_export_share", 0.6))))
	_bar(card, "تنوع صادرات", float(tp.get("export_diversity", 0.3)))
	_bar(card, "ذخیره راهبردی واردات", float(tp.get("strategic_imports", 0.2)))
	_bar(card, "امنیت زنجیره تأمین", float(tp.get("supply_security", 0.3)))
	_row(card, "مأموریت‌های تجاری", PersianFormatter.to_persian_digits(str(tp.get("trade_missions", 0))))
	# دسترسی پایدار به بازار (مأموریت‌ها/کریدورها/راهبرد صادرات‌محور) — سهم هدف صادرات
	var access_v := float(trade.get("market_access_bonus", 0.0))
	if access_v > 0.0005:
		_row(card, "دسترسی پایدار به بازار", PersianFormatter.to_persian_digits("+%.1f٪ از GDP" % (access_v * 100.0)))
	# بازرسی تراز پرداخت‌ها: این اعداد حالا واقعاً زنده‌اند (مدل سهم هدف از GDP)
	var exports_v := float(trade.get("exports", 0.0))
	var imports_v := float(trade.get("imports", 0.0))
	var balance_v := exports_v - imports_v
	_row(card, "صادرات سالانه", PersianFormatter.format_money(exports_v))
	_row(card, "واردات سالانه", PersianFormatter.format_money(imports_v))
	_row(card, "تراز تجاری", PersianFormatter.format_money(balance_v), _color_for(0.5 + signf(balance_v) * 0.5))
	_row(card, "درآمد گمرکی ماهانه", PersianFormatter.format_money(float(trade.get("customs_revenue", 0.0))))
	# بازخورد بحران ارزی: پوشش واردات با ذخایر (زیر ۳ ماه → واردات خودکار فشرده می‌شود)
	var cover_v := float(trade.get("import_cover_months", 12.0))
	_row(card, "پوشش واردات با ذخایر", PersianFormatter.to_persian_digits("%.1f ماه" % cover_v), _color_for(clampf(cover_v / 6.0, 0.0, 1.0)))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["diversify", "📦 تنوع صادرات"], ["imports", "📦 ذخیره واردات"], ["mission", "🤝 مأموریت (۱)"], ["supply", "🔗 زنجیره امن"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 36); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_trade_policy.bind(a[0]))
		_mark_decision_button(btn, "trade_pol:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "وابستگی به نفت، درآمد را با نوسان قیمت می‌لرزاند؛ تنوع صادرات آن را مهار می‌کند. ذخیره راهبردی و زنجیره امن، شوک‌های عرضه و تحریم را بی‌اثر می‌کنند."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_trade_policy(action: String):
	var cmd = GameCommandClass.create_trade_policy_action(action)
	var labels := {"diversify": "تنوع صادرات", "imports": "ذخیره راهبردی", "mission": "مأموریت تجاری", "supply": "امنیت زنجیره"}
	if _queue_decision(cmd, "📦 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("economy")

# ── بانکداری و بازار سرمایه ──
func _build_banking_card(st: Dictionary):
	var bk: Dictionary = st.get("banking", {})
	if bk.is_empty():
		return
	var card = _card("🏦 بانکداری و بازار سرمایه")
	_row(card, "شاخص سهام", PersianFormatter.to_persian_digits("%.0f" % float(bk.get("stock_index", 55.0))), _color_for(float(bk.get("stock_index", 55.0)) / 100.0))
	_bar(card, "سلامت بانک‌ها", float(bk.get("bank_health", 0.7)))
	_row(card, "ذخیره قانونی", PersianFormatter.to_persian_digits("%.0f٪" % (float(bk.get("reserve_ratio", 0.12)) * 100.0)))
	_bar(card, "نظارت بانکی", float(bk.get("supervision", 0.5)))
	var crisis: Dictionary = bk.get("crisis", {})
	if not crisis.is_empty():
		var crisis_lbl = Label.new()
		crisis_lbl.text = "🚨 بحران بانکی فعال! سپرده‌گذاران فرار می‌کنند — نجات دهید یا صبر کنید؟"
		crisis_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		crisis_lbl.add_theme_font_size_override("font_size", 16); crisis_lbl.modulate = ACCENT_RED
		card.add_child(crisis_lbl)
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for r in [[0.08, "🟢 ذخیره ۸٪"], [0.12, "🟡 ذخیره ۱۲٪"], [0.2, "🔴 ذخیره ۲۰٪"]]:
		var btn = Button.new(); btn.text = r[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.toggle_mode = true; btn.button_pressed = absf(float(bk.get("reserve_ratio", 0.12)) - r[0]) < 0.01
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_banking.bind("reserve", r[0]))
		_mark_decision_button(btn, "bank:reserve:" + str(r[0]))
		row.add_child(btn)
	var row2 = HBoxContainer.new(); row2.add_theme_constant_override("separation", 4); card.add_child(row2)
	for a in [["supervision", "🔍 تقویت نظارت"], ["market", "📈 صندوق بازار"], ["bailout", "💸 نجات بانک‌ها"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_banking.bind(a[0], 0.0))
		_mark_decision_button(btn, "bank:" + a[0])
		row2.add_child(btn)
	var hint = Label.new()
	hint.text = "ذخیره پایین اعتبار می‌دهد ولی خطر بحران؛ ذخیره بالا امن ولی کم‌رونق. سلامت بانک‌ها از تورم، بازار سیاه و اقتصاد سایه می‌خورد. نجات بانک‌ها بدهی سنگین و خشم مردم می‌آورد."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_banking(action: String, value: float):
	var cmd = GameCommandClass.create_banking_action(action, value)
	var labels := {"reserve": "تنظیم ذخیره قانونی", "supervision": "تقویت نظارت بانکی", "market": "حمایت از بازار سهام", "bailout": "نجات بانک‌ها"}
	if _queue_decision(cmd, "🏦 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("economy")

# ── سرمایه‌گذاری خارجی (FDI) ──
func _build_fdi_card(st: Dictionary):
	var fdi: Dictionary = st.get("fdi_policy", {})
	if fdi.is_empty():
		return
	var card = _card("🏢 سرمایه‌گذاری خارجی (FDI)")
	_bar(card, "جریان سرمایه خارجی", float(fdi.get("inflow", 0.25)))
	_bar(card, "مناطق ویژه اقتصادی", float(fdi.get("special_zones", 0.2)))
	_bar(card, "حفاظت مالکیت فکری", float(fdi.get("ip_protection", 0.4)))
	_bar(card, "محدودیت ورود", float(fdi.get("restrictions", 0.3)))
	_row(card, "شرکت‌های خارجی", PersianFormatter.to_persian_digits(str(fdi.get("companies", 0))))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for r in [[0.0, "🟢 باز"], [0.5, "🟡 محدود"], [1.0, "🔴 بسته"]]:
		var btn = Button.new(); btn.text = r[1]
		btn.custom_minimum_size = Vector2(0, 32); btn.add_theme_font_size_override("font_size", 11)
		btn.toggle_mode = true; btn.button_pressed = absf(float(fdi.get("restrictions", 0.3)) - r[0]) < 0.05
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_fdi.bind("restrictions", r[0]))
		_mark_decision_button(btn, "fdi:restrictions:" + str(r[0]))
		row.add_child(btn)
	var row2 = HBoxContainer.new(); row2.add_theme_constant_override("separation", 4); card.add_child(row2)
	for a in [["zone", "🏙️ منطقه ویژه"], ["ip", "📜 مالکیت فکری"], ["diplomacy", "🤝 هیئت اقتصادی (۱)"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_fdi.bind(a[0], 0.0))
		_mark_decision_button(btn, "fdi:" + a[0])
		row2.add_child(btn)
	var hint = Label.new()
	hint.text = "ثبات، زیرساخت و حفاظت مالکیت فکری سرمایه می‌آورند؛ فساد، تحریم و محدودیت آن را می‌رانند. FDI اشتغال، فناوری و رشد می‌آورد."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_fdi(action: String, value: float):
	var cmd = GameCommandClass.create_fdi_action(action, value)
	var labels := {"zone": "منطقه ویژه اقتصادی", "ip": "حفاظت مالکیت فکری", "restrictions": "تنظیم محدودیت ورود", "diplomacy": "هیئت اقتصادی"}
	if _queue_decision(cmd, "🏢 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("economy")

func _build_policy_center():
	var policy_state: Dictionary = GameState.state.get("policies", {})
	var active: Dictionary = policy_state.get("active", {})
	var capital = float(policy_state.get("political_capital", 0.0))
	var card = _card("📜 مرکز سیاست‌گذاری عمومی")
	_bar(card, "سرمایه سیاسی", capital / max(float(BalanceConfig.get_value("politics.policy_capital_max", 5.0)), 1.0))
	_row(card, "سیاست‌های فعال", PersianFormatter.to_persian_digits(str(active.size())))
	# هزینهٔ ماهانهٔ سیاست‌های فعال — از کانال بودجه (بازرسی ۱۴۰۵: قبلاً مستقیم به بدهی می‌رفت)
	var policy_monthly: float = float(GameState.state.get("economy", {}).get("policy_spending_monthly", 0.0))
	_row(card, "هزینهٔ ماهانهٔ سیاست‌ها", PersianFormatter.format_money(policy_monthly), _color_for(0.5 - clampf(policy_monthly / 2_000_000_000.0, -0.5, 0.5)))
	var hint = Label.new()
	hint.text = "سیاست‌ها هر روز اثر دارند، سرمایه سیاسی مصرف می‌کنند و با لغو متوقف می‌شوند. راهبردهای متعارض هم‌زمان فعال نمی‌شوند."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(0.76, 0.81, 0.90)
	card.add_child(hint)
	for policy_id in PolicyManager.get_policy_ids():
		var definition = PolicyManager.get_policy(policy_id)
		var enabled = active.has(policy_id)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card.add_child(row)
		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var title = Label.new()
		title.text = "%s %s — %s" % ["✅" if enabled else "◻️", definition.get("name_fa", policy_id), definition.get("category_fa", "")]
		var pol_cost: float = float(definition.get("daily_cost", 0.0)) * 30.0
		if pol_cost != 0.0:
			title.text += "  ·  هزینه: %s/ماه" % PersianFormatter.format_money(abs(pol_cost))
			if pol_cost < 0.0:
				title.text = title.text.replace("هزینه:", "صرفه‌جویی:")
		title.add_theme_font_size_override("font_size", 16)
		title.modulate = Color(0.45, 1.0, 0.6) if enabled else Color.WHITE
		info.add_child(title)
		var description = Label.new()
		description.text = str(definition.get("description", ""))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.modulate = Color(0.72, 0.77, 0.86)
		info.add_child(description)
		var check = PolicyManager.can_change(GameState.state, policy_id, not enabled)
		var button = Button.new()
		button.text = "لغو" if enabled else "فعال‌سازی (%s سرمایه)" % PersianFormatter.to_persian_digits("%.1f" % definition.get("political_cost", 1.0))
		button.custom_minimum_size = Vector2(180, 48)
		button.disabled = not check.valid
		button.tooltip_text = "" if check.valid else str(check.reason)
		button.pressed.connect(FeedbackManager.play_click)
		button.pressed.connect(_on_policy_change.bind(policy_id, not enabled, str(definition.get("name_fa", "سیاست"))))
		_mark_decision_button(button, "policy:" + str(policy_id))
		row.add_child(button)

func _on_policy_change(policy_id: String, enabled: bool, policy_name: String):
	var command = GameCommandClass.create_policy_change(policy_id, enabled)
	if _queue_decision(command, "📜 سیاست «" + policy_name + "» " + ("فعال" if enabled else "لغو")):
		_toast("📜 سیاست «%s» %s — با پایان نوبت اجرا می‌شود" % [policy_name, "فعال" if enabled else "لغو"])
		_switch_tab("economy")

# ============================================================
# تب پروژه‌های ملی — ساخت، تأخیر، هزینه و بهره‌برداری
# ============================================================
func _build_national_projects():
	var state = GameState.state
	var project_state: Dictionary = state.get("national_projects", {})
	var summary = _card("🏗️ سبد پروژه‌های ملی")
	_row(summary, "پروژه‌های فعال", PersianFormatter.to_persian_digits(str(project_state.get("active", {}).size())))
	_row(summary, "پروژه‌های تکمیل‌شده", PersianFormatter.to_persian_digits(str(project_state.get("completed", []).size())))
	_row(summary, "کل هزینه انجام‌شده", PersianFormatter.format_money(float(project_state.get("total_spent", 0.0))))
	_row(summary, "اضافه‌هزینه ناشی از فساد/بحران", PersianFormatter.format_money(float(project_state.get("total_overrun", 0.0))), _color_for(0.25))
	var note = Label.new(); note.text = "کارآمدی دولت، فساد، جنگ و آب‌وهوای شدید سرعت و هزینه ساخت را تغییر می‌دهند. حداکثر سه پروژه هم‌زمان مجاز است."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; note.modulate = Color(0.75, 0.82, 0.92); summary.add_child(note)

	var active_card = _card("🚧 کارگاه‌های فعال")
	var active: Dictionary = project_state.get("active", {})
	if active.is_empty():
		var empty = Label.new(); empty.text = "پروژه‌ای در حال ساخت نیست."; active_card.add_child(empty)
	for project_id in active.keys():
		var record: Dictionary = active[project_id]
		var panel = PanelContainer.new(); active_card.add_child(panel)
		var box = VBoxContainer.new(); panel.add_child(box)
		var title = Label.new(); title.text = NationalProjectManager.get_project_name(project_id); title.add_theme_font_size_override("font_size", 18); box.add_child(title)
		_bar(box, "پیشرفت", float(record.get("progress", 0.0)))
		_row(box, "زمان سپری‌شده", "%s ماه" % PersianFormatter.to_persian_digits(str(record.get("elapsed_months", 0))))
		_row(box, "تأخیر ثبت‌شده", "%s ماه" % PersianFormatter.to_persian_digits(str(record.get("delay_months", 0))))
		_row(box, "هزینه تا امروز", PersianFormatter.format_money(float(record.get("spent", 0.0))))
		_row(box, "اضافه‌هزینه", PersianFormatter.format_money(float(record.get("overrun", 0.0))), _color_for(0.25))
		var cancel = Button.new(); cancel.text = "لغو پروژه"; cancel.modulate = Color(1.0, 0.58, 0.55)
		cancel.pressed.connect(FeedbackManager.play_click); cancel.pressed.connect(_on_cancel_national_project.bind(str(project_id))); _mark_decision_button(cancel, "projx:" + str(project_id)); box.add_child(cancel)

	var available_card = _card("📋 طرح‌های قابل آغاز")
	for project_id in NationalProjectManager.get_project_ids():
		if project_state.get("active", {}).has(project_id) or project_state.get("completed", []).has(project_id):
			continue
		var definition = NationalProjectManager.get_project(project_id)
		var row = HBoxContainer.new(); available_card.add_child(row)
		var info = VBoxContainer.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(info)
		var title = Label.new(); title.text = "%s — %s" % [definition.get("name_fa", project_id), definition.get("category_fa", "")]; title.add_theme_font_size_override("font_size", 17); info.add_child(title)
		var desc = Label.new(); desc.text = PersianFormatter.to_persian_digits("%s\nمدت پایه: %s ماه | بودجه پایه: %.1f٪ تولید داخلی" % [definition.get("description", ""), str(definition.get("duration_months", 1)), float(definition.get("cost_gdp_ratio", 0.0)) * 100.0]); desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; desc.modulate = Color(0.72, 0.78, 0.88); info.add_child(desc)
		var check = NationalProjectManager.can_start(state, project_id)
		var start = Button.new(); start.text = "آغاز ساخت"; start.custom_minimum_size = Vector2(125, 48); start.disabled = not check.valid; start.tooltip_text = "" if check.valid else str(check.reason)
		start.pressed.connect(FeedbackManager.play_click); start.pressed.connect(_on_start_national_project.bind(str(project_id), str(definition.get("name_fa", "پروژه")))); _mark_decision_button(start, "proj:" + str(project_id)); row.add_child(start)

func _on_start_national_project(project_id: String, title: String):
	if _queue_decision(GameCommandClass.create_national_project(project_id), "🏗️ آغاز پروژه: " + title):
		_toast("🏗️ پروژه «%s» ثبت شد — با پایان نوبت آغاز می‌شود" % title); _switch_tab("projects")

func _on_cancel_national_project(project_id: String):
	if _queue_decision(GameCommandClass.create_project_cancel(project_id), "⛔ لغو پروژه: " + NationalProjectManager.get_project_name(project_id)):
		_toast("⛔ پروژه «%s» لغو ثبت شد — با پایان نوبت اجرا می‌شود" % NationalProjectManager.get_project_name(project_id)); _switch_tab("projects")

# ============================================================
# تب فناوری — درخت پژوهش داده‌محور
# ============================================================
# ── ترور رهبران دشمن: نیازمند فناوری، توازن با ضداطلاعات حریف، عواقب جهانی ──
func _build_assassination_card(st: Dictionary, parent: VBoxContainer):
	var unlocked: bool = st.get("technology", {}).get("unlocked", []).has("assassination_ops")
	if not unlocked:
		var locked = Label.new()
		locked.text = "☠ عملیات ترور پس از باز کردن فناوری «عملیات ترور هدفمند» (شاخه نظامی، سطح بالا) فعال می‌شود."
		locked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		locked.add_theme_font_size_override("font_size", 17)
		locked.modulate = TEXT_MUTED
		parent.add_child(locked)
		return
	var world: Dictionary = st.get("world", {})
	var player_id := str(world.get("player_country", WorldManager.default_country))
	var relations: Dictionary = st.get("diplomacy", {}).get("relations", {})
	var targets: Array = []
	for war_key in world.get("wars", {}).keys():
		var pair := str(war_key).split("|")
		if pair.size() == 2:
			for p in pair:
				if p != player_id and not targets.has(p):
					targets.append(p)
	for key in relations.keys():
		var pair := str(key).split("|")
		if pair.size() != 2 or not pair.has(player_id):
			continue
		var other := pair[0] if pair[0] != player_id else pair[1]
		if float(relations[key]) <= 35.0 and not targets.has(other):
			targets.append(other)
	if targets.is_empty():
		var none = Label.new()
		none.text = "☠ عملیات ترور آماده است؛ اما دشمنی (جنگ یا روابط بسیار خصمانه) در کار نیست."
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.add_theme_font_size_override("font_size", 17)
		none.modulate = TEXT_MUTED
		parent.add_child(none)
		return
	var head = Label.new()
	head.text = "☠ ترور رهبران دشمن"
	head.add_theme_font_size_override("font_size", 20)
	head.modulate = ACCENT_RED
	parent.add_child(head)
	for target in targets:
		var chance: float = LeaderManager.assassination_chance(st, str(target))
		var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 8); parent.add_child(row)
		var info = VBoxContainer.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; info.add_theme_constant_override("separation", 2); row.add_child(info)
		var lbl = Label.new()
		lbl.text = "%s — شانس موفقیت %s٪" % [WorldManager.get_country_name(str(target)), PersianFormatter.to_persian_digits(str(int(chance * 100.0)))]
		lbl.add_theme_font_size_override("font_size", 18)
		info.add_child(lbl)
		var sub = Label.new()
		sub.text = "ضداطلاعات قوی‌تر حریف، شانس را به صفر می‌رساند و ترورِ ناموفق روابط را نابود می‌کند."
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.add_theme_font_size_override("font_size", 14)
		sub.modulate = TEXT_FAINT
		info.add_child(sub)
		var btn = Button.new(); btn.text = "ترور"; btn.custom_minimum_size = Vector2(110, 48)
		btn.add_theme_font_size_override("font_size", 18); btn.theme_type_variation = "DangerButton" if chance >= 0.5 else ""
		btn.pressed.connect(FeedbackManager.play_click)
		btn.pressed.connect(_on_assassinate.bind(str(target)))
		_mark_decision_button(btn, "assassinate:" + str(target))
		row.add_child(btn)

func _on_assassinate(target: String):
	var cmd = GameCommandClass.create_assassinate(target)
	if _queue_decision(cmd, "☠ ترور رهبر " + WorldManager.get_country_name(target)):
		_toast("☠ عملیات ترور «%s» ثبت شد — با پایان نوبت اجرا می‌شود" % WorldManager.get_country_name(target))
		_switch_tab("military")

# ── اهداف جنگی: هر جنگ هدفی دارد که نتیجه‌اش را متفاوت می‌کند ──
func _build_orgs_card_outer(st: Dictionary):
	_build_orgs_card(st)

# ── رقابت قدرت‌های بزرگ: تنش بلوکی، مسابقه تسلیحاتی و بحران منطقه‌ای ──
func _build_rivalry_card(st: Dictionary):
	var riv: Dictionary = st.get("rivalry", {})
	if riv.is_empty():
		return
	var tension := clampf(float(riv.get("tension", 40.0)), 0.0, 100.0)
	var arms := clampf(float(riv.get("arms_race", 0.3)), 0.0, 1.0)
	var card = _card("🌍 رقابت قدرت‌های بزرگ")
	_row(card, "تنش بلوکی (غرب ↔ اوراسیا)", PersianFormatter.to_persian_digits(str(int(tension))), _color_for(tension / 100.0))
	_bar(card, "مسابقه تسلیحاتی جهان", arms)
	var crisis: Dictionary = riv.get("crisis", {})
	if not crisis.is_empty():
		var crisis_lbl = Label.new()
		crisis_lbl.text = "🚨 بحران: " + str(crisis.get("title", "")) + " — " + str(crisis.get("desc", ""))
		crisis_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		crisis_lbl.add_theme_font_size_override("font_size", 17); crisis_lbl.modulate = ACCENT_RED
		card.add_child(crisis_lbl)
		var stance_row = HBoxContainer.new(); stance_row.add_theme_constant_override("separation", 6); card.add_child(stance_row)
		for stance in [["west", "🌐 جانب غرب"], ["east", "🛡️ جانب اوراسیا"], ["neutral", "🕊️ بی‌طرفی"]]:
			var btn = Button.new(); btn.text = stance[1]
			btn.custom_minimum_size = Vector2(0, 42); btn.add_theme_font_size_override("font_size", 14)
			btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_crisis_stance.bind(stance[0]))
			_mark_decision_button(btn, "crisis:" + stance[0])
			stance_row.add_child(btn)
	else:
		var calm = Label.new(); calm.text = "جهان نسبتاً آرام است — بحران منطقه‌ای ممکن است هر لحظه رخ دهد."
		calm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		calm.add_theme_font_size_override("font_size", 15); calm.modulate = TEXT_MUTED
		card.add_child(calm)
	var action_row = HBoxContainer.new(); action_row.add_theme_constant_override("separation", 6); card.add_child(action_row)
	var de_btn = Button.new(); de_btn.text = "🕊️ تنش‌زدایی"
	de_btn.custom_minimum_size = Vector2(0, 42); de_btn.add_theme_font_size_override("font_size", 14)
	de_btn.pressed.connect(FeedbackManager.play_click); de_btn.pressed.connect(_on_rivalry.bind("de_escalate"))
	_mark_decision_button(de_btn, "rivalry:de")
	action_row.add_child(de_btn)
	var es_btn = Button.new(); es_btn.text = "⚔️ تشدید + تقویت ارتش"
	es_btn.custom_minimum_size = Vector2(0, 42); es_btn.add_theme_font_size_override("font_size", 14)
	es_btn.pressed.connect(FeedbackManager.play_click); es_btn.pressed.connect(_on_rivalry.bind("escalate"))
	_mark_decision_button(es_btn, "rivalry:es")
	action_row.add_child(es_btn)
	var hint = Label.new()
	hint.text = "تنش بالا جهان را خطرناک‌تر می‌کند (جنگ‌های NPC شدیدتر). تنش‌زدایی نفوذ دیپلماتیک می‌آورد؛ تشدید ارتش را تقویت می‌کند ولی خطرناک است."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_crisis_stance(stance: String):
	var cmd = GameCommandClass.create_crisis_stance(stance)
	if _queue_decision(cmd, "🌍 موضع‌گیری در بحران: " + {"west": "جانب غرب", "east": "جانب اوراسیا", "neutral": "بی‌طرفی"}.get(stance, stance)):
		_toast("موضع‌گیری ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("map")

func _on_rivalry(action: String):
	var cmd = GameCommandClass.create_rivalry_action(action)
	var label := "تنش‌زدایی" if action == "de_escalate" else "تشدید تنش"
	if _queue_decision(cmd, "🌍 " + label):
		_toast(label + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("map")

# ── سفیران و دیپلماسی دوجانبه ──
func _build_ambassador_card(st: Dictionary):
	var dp: Dictionary = st.get("diplomacy_policy", {})
	if dp.is_empty():
		return
	var ambassadors: Dictionary = dp.get("ambassadors", {})
	var relations: Dictionary = st.get("diplomacy", {}).get("relations", {})
	var card = _card("🤝 سفیران و دیپلماسی")
	_row(card, "تصویر دیپلماتیک", PersianFormatter.to_persian_digits("%.0f / ۱۰۰" % float(dp.get("image", 50.0))), _color_for(float(dp.get("image", 50.0)) / 100.0))
	for cid in AmbassadorManager.KEY_COUNTRIES:
		var level := float(ambassadors.get(cid, 0.0))
		var rel := float(relations.get(cid, 50.0))
		var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 6); card.add_child(row)
		var info = VBoxContainer.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; info.add_theme_constant_override("separation", 1); row.add_child(info)
		var name = Label.new()
		name.text = ("✔ " if level > 0.0 else "○ ") + WorldManager.get_country_name(cid) + " — روابط " + PersianFormatter.to_persian_digits(str(int(rel)))
		name.add_theme_font_size_override("font_size", 15)
		info.add_child(name)
		if level > 0.0:
			var rec_btn = Button.new(); rec_btn.text = "فراخوانی"
			rec_btn.custom_minimum_size = Vector2(90, 30); rec_btn.add_theme_font_size_override("font_size", 11)
			rec_btn.pressed.connect(FeedbackManager.play_click); rec_btn.pressed.connect(_on_ambassador.bind("recall", cid))
			_mark_decision_button(rec_btn, "amb:recall:" + cid)
			row.add_child(rec_btn)
		else:
			var send_btn = Button.new(); send_btn.text = "اعزام (۰.۵)"
			send_btn.custom_minimum_size = Vector2(90, 30); send_btn.add_theme_font_size_override("font_size", 11)
			send_btn.disabled = float(st.get("policies", {}).get("political_capital", 0.0)) < 0.5
			send_btn.pressed.connect(FeedbackManager.play_click); send_btn.pressed.connect(_on_ambassador.bind("send", cid))
			_mark_decision_button(send_btn, "amb:send:" + cid)
			row.add_child(send_btn)
		var neg_btn = Button.new(); neg_btn.text = "مذاکره (۱)"
		neg_btn.custom_minimum_size = Vector2(90, 30); neg_btn.add_theme_font_size_override("font_size", 11)
		neg_btn.disabled = float(st.get("policies", {}).get("political_capital", 0.0)) < 1.0
		neg_btn.pressed.connect(FeedbackManager.play_click); neg_btn.pressed.connect(_on_ambassador.bind("negotiate", cid))
		_mark_decision_button(neg_btn, "amb:neg:" + cid)
		row.add_child(neg_btn)
	var hint = Label.new()
	hint.text = "سفیران روابط را روزبه‌روز تقویت می‌کنند؛ در روابط بسیار بد ممکن است اخراج شوند. مذاکره سطح بالا روابط را یک‌جا جهش می‌دهد."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_ambassador(action: String, country: String):
	var cmd = GameCommandClass.create_ambassador_action(action, country)
	var labels := {"send": "اعزام سفیر", "recall": "فراخوانی سفیر", "negotiate": "مذاکره سطح بالا"}
	if _queue_decision(cmd, "🤝 " + labels.get(action, action) + " با " + WorldManager.get_country_name(country)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("map")

func _build_war_goals_card(st: Dictionary):
	var world: Dictionary = st.get("world", {})
	var wars: Dictionary = world.get("wars", {})
	if wars.is_empty():
		return
	var card = _card("🎯 اهداف جنگی — نتیجه جنگ به هدف بستگی دارد")
	for target in wars.keys():
		var war: Dictionary = wars[target]
		var goal := str(war.get("goal", "reparations"))
		var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 8); card.add_child(row)
		var info = VBoxContainer.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; info.add_theme_constant_override("separation", 2); row.add_child(info)
		var title = Label.new()
		title.text = "⚔ جنگ با %s — هدف: %s" % [WorldManager.get_country_name(str(target)), WorldManager.get_war_goal_name(goal)]
		title.add_theme_font_size_override("font_size", 19)
		info.add_child(title)
		var desc = Label.new()
		desc.text = {"reparations": "پیروزی: غرامت سنگین از دشمن • شکست: پرداخت غرامت", "annexation": "پیروزی: الحاق خاک یا حاکم دست‌نشانده • جنگ طاقت‌فرسا و کاهنده محبوبیت", "humiliation": "پیروزی: تحقیر دشمن و نفوذ بسیار • شکست: از دست رفتن نفوذ", "liberation": "پیروزی: محبوبیت جهانی و اعتبار • بدون غنیمت مالی"}.get(goal, "")
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 14)
		desc.modulate = TEXT_FAINT
		info.add_child(desc)
		var goal_btn = Button.new(); goal_btn.text = "تغییر هدف"; goal_btn.custom_minimum_size = Vector2(120, 44)
		goal_btn.add_theme_font_size_override("font_size", 16)
		goal_btn.pressed.connect(FeedbackManager.play_click)
		goal_btn.pressed.connect(_on_cycle_war_goal.bind(str(target)))
		_mark_decision_button(goal_btn, "wargoal:" + str(target))
		row.add_child(goal_btn)

var _war_goal_cycle := {}

func _on_cycle_war_goal(target: String):
	var goals: Array = ["reparations", "annexation", "humiliation", "liberation"]
	var current: int = int(_war_goal_cycle.get(target, 0))
	var next_goal: String = goals[(current + 1) % goals.size()]
	_war_goal_cycle[target] = (current + 1) % goals.size()
	var cmd = GameCommandClass.create_set_war_goal(target, next_goal)
	if _queue_decision(cmd, "🎯 هدف جنگ با " + WorldManager.get_country_name(target) + ": " + WorldManager.get_war_goal_name(next_goal)):
		_toast("هدف جنگ با %s به «%s» تغییر کرد — با پایان نوبت اعمال می‌شود" % [WorldManager.get_country_name(target), WorldManager.get_war_goal_name(next_goal)])
		_switch_tab("military")

# ── فرماندهان ارتش: استخدام، گماردن به جبهه، تجربه و ارتقا ──
func _build_generals_card(st: Dictionary):
	var generals: Dictionary = st.get("generals", {})
	if generals.is_empty():
		return
	var commanders: Dictionary = generals.get("commanders", {})
	var card = _card("🪖 فرماندهان ارتش")
	# دکمه استخدام
	var recruit_check = GeneralsManager.can_recruit(st)
	var recruit_row = HBoxContainer.new(); recruit_row.add_theme_constant_override("separation", 8); card.add_child(recruit_row)
	var recruit_btn = Button.new()
	recruit_btn.text = "➕ استخدام فرمانده (۱ سرمایه سیاسی)"
	recruit_btn.custom_minimum_size = Vector2(300, 48)
	recruit_btn.add_theme_font_size_override("font_size", 18)
	recruit_btn.disabled = not recruit_check.valid
	recruit_btn.tooltip_text = "" if recruit_check.valid else str(recruit_check.reason)
	recruit_btn.pressed.connect(FeedbackManager.play_click)
	recruit_btn.pressed.connect(_on_general_recruit)
	_mark_decision_button(recruit_btn, "general_recruit")
	recruit_row.add_child(recruit_btn)
	var cap_lbl = Label.new()
	cap_lbl.text = "%s / %s" % [PersianFormatter.to_persian_digits(str(commanders.size())), PersianFormatter.to_persian_digits(str(GeneralsManager.MAX_COMMANDERS))]
	cap_lbl.add_theme_font_size_override("font_size", 16); cap_lbl.modulate = TEXT_MUTED
	recruit_row.add_child(cap_lbl)
	if commanders.is_empty():
		var empty = Label.new()
		empty.text = "هنوز فرمانده‌ای ندارید؛ در جنگ‌ها فرمانده منصوب، نیروی جبهه را به‌طور محسوس تقویت می‌کند."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 17); empty.modulate = TEXT_MUTED
		card.add_child(empty)
		return
	for cid in commanders.keys():
		var commander: Dictionary = commanders[cid]
		var panel = PanelContainer.new(); card.add_child(panel)
		var box = VBoxContainer.new(); box.add_theme_constant_override("separation", 4); panel.add_child(box)
		var head = HBoxContainer.new(); head.add_theme_constant_override("separation", 8); box.add_child(head)
		var title = Label.new()
		title.text = "%s — سطح %s (%s)" % [str(commander.get("name_fa", "فرمانده")),
			PersianFormatter.to_persian_digits(str(commander.get("level", 1))),
			GeneralsManager.get_trait_fa(str(commander.get("trait", "offensive")))]
		title.add_theme_font_size_override("font_size", 18); title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.tooltip_text = GeneralsManager.get_trait_desc(str(commander.get("trait", "offensive")))
		head.add_child(title)
		var assigned := str(commander.get("assigned_war", ""))
		var status = Label.new()
		status.text = "⚔ " + WorldManager.get_country_name(assigned) if assigned != "" else "— آماده"
		status.add_theme_font_size_override("font_size", 15)
		status.modulate = ACCENT_GOLD if assigned != "" else TEXT_MUTED
		head.add_child(status)
		var stats = Label.new()
		stats.text = "نبردها: %s | پیروزی‌ها: %s | تجربه: %s" % [
			PersianFormatter.to_persian_digits(str(commander.get("battles", 0))),
			PersianFormatter.to_persian_digits(str(commander.get("wins", 0))),
			PersianFormatter.to_persian_digits("%.0f" % float(commander.get("experience", 0.0)))]
		stats.add_theme_font_size_override("font_size", 15); stats.modulate = TEXT_MUTED
		box.add_child(stats)
		# گماردن: لیست جنگ‌ها
		var wars: Dictionary = st.get("world", {}).get("wars", {})
		if not wars.is_empty():
			var assign_row = HBoxContainer.new(); assign_row.add_theme_constant_override("separation", 6); box.add_child(assign_row)
			var unassign_btn = Button.new(); unassign_btn.text = "برکناری"
			unassign_btn.custom_minimum_size = Vector2(110, 36); unassign_btn.add_theme_font_size_override("font_size", 14)
			unassign_btn.disabled = assigned == ""
			unassign_btn.pressed.connect(FeedbackManager.play_click)
			unassign_btn.pressed.connect(_on_general_assign.bind(cid, ""))
			_mark_decision_button(unassign_btn, "gen_assign:" + cid + ":")
			assign_row.add_child(unassign_btn)
			for target in wars.keys():
				if target == str(st.get("world", {}).get("player_country", "")):
					continue
				var assign_btn = Button.new()
				assign_btn.text = "گماردن به %s" % WorldManager.get_country_name(str(target))
				assign_btn.custom_minimum_size = Vector2(0, 36); assign_btn.add_theme_font_size_override("font_size", 14)
				assign_btn.disabled = assigned == str(target)
				assign_btn.pressed.connect(FeedbackManager.play_click)
				assign_btn.pressed.connect(_on_general_assign.bind(cid, str(target)))
				_mark_decision_button(assign_btn, "gen_assign:" + cid + ":" + str(target))
				assign_row.add_child(assign_btn)

func _on_general_recruit():
	var cmd = GameCommandClass.create_general_recruit()
	if _queue_decision(cmd, "➕ استخدام فرمانده جدید"):
		_toast("استخدام فرمانده ثبت شد — با پایان نوبت انجام می‌شود")
		_switch_tab("military")

func _on_general_assign(commander_id: String, war_target: String):
	var cmd = GameCommandClass.create_general_assign(commander_id, war_target)
	var label := "برکناری فرمانده از جبهه" if war_target == "" else "گماردن فرمانده به " + WorldManager.get_country_name(war_target)
	if _queue_decision(cmd, "🪖 " + label):
		_toast(label + " ثبت شد — با پایان نوبت انجام می‌شود")
		_switch_tab("military")

# ── رسانه و افکار عمومی: رضایت گروه‌های جمعیتی + کمپین‌ها ──
func _build_media_card(st: Dictionary):
	var media: Dictionary = st.get("media", {})
	if media.is_empty():
		return
	var groups: Dictionary = media.get("groups", {})
	var card = _card("📺 رسانه و افکار عمومی")
	var overall := MediaManager.overall_approval(st)
	_row(card, "شاخص افکار عمومی", PersianFormatter.to_persian_digits("%.0f / ۱۰۰" % overall), _color_for(overall / 100.0))
	_bar(card, "اعتماد به رسانه‌ها", float(media.get("trust", 0.55)))
	var policy := str(media.get("policy", "free"))
	var policy_names := {"free": "آزاد", "state": "دولتی", "populist": "پوپولیستی"}
	var policy_row = HBoxContainer.new(); policy_row.add_theme_constant_override("separation", 6); card.add_child(policy_row)
	var pol_lbl = Label.new(); pol_lbl.text = "سیاست رسانه‌ای:"; pol_lbl.add_theme_font_size_override("font_size", 17); pol_lbl.modulate = TEXT_MUTED; policy_row.add_child(pol_lbl)
	for pkey in ["free", "state", "populist"]:
		var btn = Button.new(); btn.text = str(policy_names.get(pkey, pkey)); btn.toggle_mode = true
		btn.button_pressed = policy == pkey
		btn.custom_minimum_size = Vector2(120, 40); btn.add_theme_font_size_override("font_size", 15)
		btn.theme_type_variation = "LensChipActive" if policy == pkey else "LensChip"
		btn.pressed.connect(FeedbackManager.play_click)
		btn.pressed.connect(_on_media_policy.bind(pkey))
		_mark_decision_button(btn, "media_policy:" + pkey)
		policy_row.add_child(btn)
	# گروه‌ها
	for gid in groups.keys():
		var g: Dictionary = groups[gid]
		var approval := clampf(float(g.get("approval", 50.0)), 0.0, 100.0)
		var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 10); card.add_child(row)
		var col = VBoxContainer.new(); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL; col.add_theme_constant_override("separation", 2); row.add_child(col)
		var lbl = Label.new(); lbl.text = "%s — رضایت %s" % [gid, PersianFormatter.to_persian_digits(str(int(approval)))]
		lbl.add_theme_font_size_override("font_size", 16); col.add_child(lbl)
		var bar = ProgressBar.new(); bar.max_value = 100.0; bar.value = approval; bar.show_percentage = false; bar.custom_minimum_size = Vector2(0, 10); col.add_child(bar)
		# دکمه کمپین
		var camp_btn = Button.new(); camp_btn.text = "📣 کمپین"
		camp_btn.custom_minimum_size = Vector2(100, 38); camp_btn.add_theme_font_size_override("font_size", 14)
		camp_btn.pressed.connect(FeedbackManager.play_click)
		camp_btn.pressed.connect(_on_media_campaign.bind(gid))
		_mark_decision_button(camp_btn, "media_camp:" + gid)
		row.add_child(camp_btn)
	# کمپین فعال
	var campaign: Dictionary = media.get("campaign", {})
	if int(campaign.get("turns_left", 0)) > 0:
		var active = Label.new()
		var styles := {"honest": "صادقانه", "emotional": "احساسی", "smear": "تخریبی"}
		active.text = "📣 کمپین %s برای «%s» — %s نوبت باقی‌مانده" % [
			styles.get(str(campaign.get("style", "")), str(campaign.get("style", ""))),
			str(campaign.get("target", "")), PersianFormatter.to_persian_digits(str(campaign.get("turns_left", 0)))]
		active.add_theme_font_size_override("font_size", 16); active.modulate = ACCENT_GOLD
		card.add_child(active)

func _on_media_policy(policy: String):
	var cmd = GameCommandClass.create_media_policy(policy)
	if _queue_decision(cmd, "📺 سیاست رسانه‌ای: " + {"free": "آزاد", "state": "دولتی", "populist": "پوپولیستی"}.get(policy, policy)):
		_toast("سیاست رسانه‌ای ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("population")

func _on_media_campaign(target_group: String):
	var check = MediaManager.can_campaign(GameState.state)
	if not check.valid:
		_toast("⚠️ " + str(check.reason))
		return
	var style: String = ["honest", "emotional", "smear"][int(randi() % 3)]
	var cmd = GameCommandClass.create_media_campaign(target_group, style)
	var styles := {"honest": "صادقانه", "emotional": "احساسی", "smear": "تخریبی"}
	if _queue_decision(cmd, "📣 کمپین " + styles.get(style, style) + " برای «" + target_group + "»"):
		_toast("کمپین رسانه‌ای ثبت شد — با پایان نوبت آغاز می‌شود")
		_switch_tab("population")

# ── سازمان‌های بین‌المللی: عضویت، قطعنامه‌ها و رأی‌گیری ──
func _build_orgs_card(st: Dictionary):
	var intl: Dictionary = st.get("intl_orgs", {})
	if intl.is_empty():
		return
	var memberships: Dictionary = intl.get("memberships", {})
	var card = _card("🏛️ سازمان‌های بین‌المللی")
	for org in OrgManager.ORGS:
		var info: Dictionary = OrgManager.ORG_INFO.get(org, {})
		var member := bool(memberships.get(org, false))
		var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 8); card.add_child(row)
		var col = VBoxContainer.new(); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL; col.add_theme_constant_override("separation", 2); row.add_child(col)
		var name = Label.new(); name.text = ("✔ " if member else "○ ") + org + (" (عضو)" if member else "")
		name.add_theme_font_size_override("font_size", 18)
		name.modulate = ACCENT_GREEN if member else TEXT_MUTED
		col.add_child(name)
		var benefit = Label.new(); benefit.text = str(info.get("benefit", "")) + " • هزینه سالانه " + PersianFormatter.format_money(float(info.get("cost", 0.0)))
		benefit.add_theme_font_size_override("font_size", 14); benefit.modulate = TEXT_FAINT
		col.add_child(benefit)
		var btn = Button.new()
		btn.text = "خروج" if member else "پیوستن"
		btn.custom_minimum_size = Vector2(100, 40); btn.add_theme_font_size_override("font_size", 15)
		btn.pressed.connect(FeedbackManager.play_click)
		btn.pressed.connect(_on_org_toggle.bind(org))
		_mark_decision_button(btn, "org_toggle:" + org)
		row.add_child(btn)
	# قطعنامه در انتظار
	var pending: Dictionary = intl.get("pending_vote", {})
	if not pending.is_empty():
		var vote_card = _card("🗳️ قطعنامه در انتظار رأی")
		var title = Label.new(); title.text = str(pending.get("title", ""))
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.add_theme_font_size_override("font_size", 19); title.modulate = ACCENT_GOLD
		vote_card.add_child(title)
		var effects = Label.new(); effects.text = "تأیید: %s | وتو: %s" % [pending.get("yes_effect", ""), pending.get("no_effect", "")]
		effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		effects.add_theme_font_size_override("font_size", 15); effects.modulate = TEXT_MUTED
		vote_card.add_child(effects)
		var vote_row = HBoxContainer.new(); vote_row.add_theme_constant_override("separation", 8); vote_card.add_child(vote_row)
		var yes_btn = Button.new(); yes_btn.text = "✔ تأیید"; yes_btn.custom_minimum_size = Vector2(150, 44)
		yes_btn.pressed.connect(FeedbackManager.play_click); yes_btn.pressed.connect(_on_org_vote.bind("yes"))
		_mark_decision_button(yes_btn, "org_vote:yes")
		vote_row.add_child(yes_btn)
		var no_btn = Button.new(); no_btn.text = "✖ وتو"; no_btn.custom_minimum_size = Vector2(150, 44)
		no_btn.pressed.connect(FeedbackManager.play_click); no_btn.pressed.connect(_on_org_vote.bind("no"))
		_mark_decision_button(no_btn, "org_vote:no")
		vote_row.add_child(no_btn)

func _on_org_toggle(org: String):
	var cmd = GameCommandClass.create_org_toggle(org)
	if _queue_decision(cmd, "🏛️ تغییر عضویت «" + org + "»"):
		_toast("تغییر عضویت «%s» ثبت شد — با پایان نوبت اعمال می‌شود" % org)
		_switch_tab("map")

func _on_org_vote(decision: String):
	var intl: Dictionary = GameState.state.get("intl_orgs", {})
	var pending: Dictionary = intl.get("pending_vote", {})
	if pending.is_empty():
		_toast("قطعنامه‌ای در انتظار رأی نیست")
		return
	var cmd = GameCommandClass.create_org_vote(decision)
	if _queue_decision(cmd, "🗳️ رأی «" + ("تأیید" if decision == "yes" else "وتو") + "» به قطعنامه"):
		_toast("رأی شما ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("map")

# ── اتحادیه‌های کارگری و سیاست دستمزد ──
func _build_labor_card(st: Dictionary):
	var lab: Dictionary = st.get("labor", {})
	if lab.is_empty():
		return
	var unions := clampf(float(lab.get("unions_power", 0.4)), 0.0, 1.0)
	var risk := clampf(float(lab.get("strike_risk", 0.2)), 0.0, 1.0)
	var policy := str(lab.get("wage_policy", "free"))
	var card = _card("✊ اتحادیه‌های کارگری")
	_bar(card, "قدرت اتحادیه‌ها", unions)
	_row(card, "ریسک اعتصاب", PersianFormatter.to_persian_digits("%.0f٪" % (risk * 100.0)), _color_for(1.0 - risk))
	var policy_names := {"free": "آزاد", "minimum_up": "افزایش حداقل دستمزد", "wage_control": "کنترل دستمزد"}
	_row(card, "سیاست دستمزدی", str(policy_names.get(policy, policy)))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 5); card.add_child(row)
	for act in [["free", "آزاد"], ["minimum_up", "افزایش حداقل"], ["wage_control", "کنترل"]]:
		var btn = Button.new(); btn.text = act[1]
		btn.custom_minimum_size = Vector2(0, 36); btn.add_theme_font_size_override("font_size", 13)
		btn.toggle_mode = true; btn.button_pressed = policy == act[0]
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_labor.bind(act[0]))
		_mark_decision_button(btn, "labor:" + act[0])
		row.add_child(btn)
	var act_row = HBoxContainer.new(); act_row.add_theme_constant_override("separation", 5); card.add_child(act_row)
	var neg_btn = Button.new(); neg_btn.text = "🤝 مذاکره (۱)"
	neg_btn.custom_minimum_size = Vector2(0, 40); neg_btn.add_theme_font_size_override("font_size", 14)
	neg_btn.disabled = float(st.get("policies", {}).get("political_capital", 0.0)) < 1.0
	neg_btn.pressed.connect(FeedbackManager.play_click); neg_btn.pressed.connect(_on_labor.bind("negotiate"))
	_mark_decision_button(neg_btn, "labor:negotiate")
	act_row.add_child(neg_btn)
	var sup_btn = Button.new(); sup_btn.text = "🚨 سرکوب"
	sup_btn.custom_minimum_size = Vector2(0, 40); sup_btn.add_theme_font_size_override("font_size", 14)
	sup_btn.pressed.connect(FeedbackManager.play_click); sup_btn.pressed.connect(_on_labor.bind("suppress"))
	_mark_decision_button(sup_btn, "labor:suppress")
	act_row.add_child(sup_btn)
	var hint = Label.new()
	hint.text = "افزایش حداقل دستمزد رضایت می‌خرد ولی تورم می‌آورد؛ کنترل دستمزد سرمایه‌گذار را می‌آورد ولی کارگر را می‌رنجاند. اعتصاب سراسری تولید را می‌شکند!"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_labor(action: String):
	var cmd = GameCommandClass.create_labor_action(action)
	var labels := {"free": "دستمزد آزاد", "minimum_up": "افزایش حداقل دستمزد", "wage_control": "کنترل دستمزد", "negotiate": "مذاکره با اتحادیه", "suppress": "سرکوب اعتصاب"}
	if _queue_decision(cmd, "✊ " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("population")

# ── بهداشت عمومی و پاندمی: قرنطینه، واکسن، بیمارستان ──
func _build_epidemic_card(st: Dictionary):
	var ep: Dictionary = st.get("epidemic", {})
	if ep.is_empty():
		return
	var status: String = str(ep.get("status", "normal"))
	var status_fa: String = String({"normal": "🟢 عادی", "outbreak": "🟠 شکست کنترل", "pandemic": "🔴 همه‌گیری"}.get(status, status))
	var spread: float = clampf(float(ep.get("spread", 0.0)), 0.0, 1.0)
	var card = _card("🦠 بهداشت عمومی و پاندمی — " + status_fa)
	_row(card, "شدت شیوع", PersianFormatter.to_persian_digits("%.0f٪" % (spread * 100.0)), _color_for(1.0 - spread))
	_bar(card, "شدت شیوع", spread)
	_row(card, "تلفات کل", PersianFormatter.to_persian_digits(str(ep.get("deaths", 0))))
	_row(card, "پوشش واکسیناسیون", PersianFormatter.to_persian_digits("%.0f٪" % (float(ep.get("vaccinated", 0.0)) * 100.0)))
	_row(card, "ظرفیت بیمارستانی", PersianFormatter.to_persian_digits("%.0f٪" % (float(ep.get("hospital_bonus", 0.0)) * 100.0)))
	var life_fit := clampf(float(st.get("health", {}).get("lifestyle_fitness", 0.50)), 0.0, 1.0)
	_row(card, "تناسب سبک زندگی", PersianFormatter.to_persian_digits("%.0f٪" % (life_fit * 100.0)), _color_for(life_fit))
	var lockdown := int(ep.get("lockdown", 0))
	var lock_names := ["—", "سبک", "سنگین"]
	_row(card, "قرنطینه", str(lock_names[lockdown]) if lockdown < 3 else "؟")
	# دکمه‌ها
	var lock_row = HBoxContainer.new(); lock_row.add_theme_constant_override("separation", 5); card.add_child(lock_row)
	for lv in [[0, "🟢 لغو"], [1, "🟡 سبک"], [2, "🔴 سنگین"]]:
		var btn = Button.new(); btn.text = "قرنطینه " + lv[1]
		btn.custom_minimum_size = Vector2(0, 40); btn.add_theme_font_size_override("font_size", 13)
		btn.toggle_mode = true; btn.button_pressed = lockdown == lv[0]
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_epidemic.bind("lockdown" + str(lv[0])))
		_mark_decision_button(btn, "epi:lockdown" + str(lv[0]))
		lock_row.add_child(btn)
	var act_row = HBoxContainer.new(); act_row.add_theme_constant_override("separation", 5); card.add_child(act_row)
	var vac_btn = Button.new(); vac_btn.text = "💉 کمپین واکسن"
	vac_btn.custom_minimum_size = Vector2(0, 40); vac_btn.add_theme_font_size_override("font_size", 13)
	vac_btn.disabled = float(st.get("technology", {}).get("branch_levels", {}).get("پزشکی", 0)) < 10
	vac_btn.tooltip_text = "" if not vac_btn.disabled else "فناوری پزشکی سطح ۱۰+ لازم است"
	vac_btn.pressed.connect(FeedbackManager.play_click); vac_btn.pressed.connect(_on_epidemic.bind("vaccine"))
	_mark_decision_button(vac_btn, "epi:vaccine")
	act_row.add_child(vac_btn)
	var hos_btn = Button.new(); hos_btn.text = "🏥 بیمارستان اضطراری"
	hos_btn.custom_minimum_size = Vector2(0, 40); hos_btn.add_theme_font_size_override("font_size", 13)
	hos_btn.pressed.connect(FeedbackManager.play_click); hos_btn.pressed.connect(_on_epidemic.bind("hospitals"))
	_mark_decision_button(hos_btn, "epi:hospitals")
	act_row.add_child(hos_btn)
	var hint = Label.new()
	hint.text = "قرنطینه سنگین شیوع را می‌میراند ولی اقتصاد و رضایت را می‌شکند. واکسن نیازمند فناوری پزشکی است؛ فناوری بالا حتی واکسن خودکار می‌سازد!"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_epidemic(action: String):
	var cmd = GameCommandClass.create_epidemic_action(action)
	var labels := {"lockdown0": "لغو قرنطینه", "lockdown1": "قرنطینه سبک", "lockdown2": "قرنطینه سنگین", "vaccine": "کمپین واکسن", "hospitals": "بیمارستان اضطراری"}
	if _queue_decision(cmd, "🦠 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("population")

# ── سیاست مهاجرت و جمعیت ──
func _build_migration_card(st: Dictionary):
	var mig: Dictionary = st.get("migration", {})
	if mig.is_empty():
		return
	var policy := str(mig.get("policy", "restricted"))
	var card = _card("🌍 سیاست مهاجرت و جمعیت")
	_row(card, "جریان خالص مهاجرت", PersianFormatter.to_persian_digits("%+.2f٪" % (float(mig.get("net", 0.0)) * 100.0)))
	_row(card, "فشار پناهندگان", PersianFormatter.to_persian_digits("%.0f٪" % (float(mig.get("refugees", 0.0)) * 100.0)), _color_for(1.0 - float(mig.get("refugees", 0.0))))
	_bar(card, "فرار مغزها", float(mig.get("brain_drain", 0.25)))
	_bar(card, "ادغام پناهندگان", float(mig.get("integration", 0.0)))
	var policy_names := {"open": "باز", "restricted": "محدود", "skilled": "مهارت‌محور"}
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 5); card.add_child(row)
	var lbl = Label.new(); lbl.text = "سیاست:"; lbl.add_theme_font_size_override("font_size", 15); lbl.modulate = TEXT_MUTED; row.add_child(lbl)
	for pkey in ["open", "restricted", "skilled"]:
		var btn = Button.new(); btn.text = str(policy_names.get(pkey, pkey))
		btn.custom_minimum_size = Vector2(0, 38); btn.add_theme_font_size_override("font_size", 13)
		btn.toggle_mode = true; btn.button_pressed = policy == pkey
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_migration.bind(pkey))
		_mark_decision_button(btn, "mig:" + pkey)
		row.add_child(btn)
	var act_row = HBoxContainer.new(); act_row.add_theme_constant_override("separation", 5); card.add_child(act_row)
	var int_btn = Button.new(); int_btn.text = "🤝 برنامه ادغام"
	int_btn.custom_minimum_size = Vector2(0, 40); int_btn.add_theme_font_size_override("font_size", 13)
	int_btn.pressed.connect(FeedbackManager.play_click); int_btn.pressed.connect(_on_migration.bind("integrate"))
	_mark_decision_button(int_btn, "mig:integrate")
	act_row.add_child(int_btn)
	var brain_btn = Button.new(); brain_btn.text = "🎓 مهار فرار مغزها"
	brain_btn.custom_minimum_size = Vector2(0, 40); brain_btn.add_theme_font_size_override("font_size", 13)
	brain_btn.pressed.connect(FeedbackManager.play_click); brain_btn.pressed.connect(_on_migration.bind("brain"))
	_mark_decision_button(brain_btn, "mig:brain")
	act_row.add_child(brain_btn)
	var hint = Label.new()
	hint.text = "مهاجرت نیروی کار و جمعیت جوان می‌آورد ولی پناهندگان هزینه رفاه و تنش پوپولیستی دارند. فرار مغزها پژوهش را می‌خورد؛ مهارش با بودجه علم ممکن است."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_migration(action: String):
	var cmd = GameCommandClass.create_migration_action(action)
	var labels := {"open": "مهاجرت باز", "restricted": "مهاجرت محدود", "skilled": "مهاجرت مهارت‌محور", "integrate": "برنامه ادغام", "brain": "مهار فرار مغزها"}
	if _queue_decision(cmd, "🌍 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("population")

# ── فرهنگ و قدرت نرم ──
func _build_culture_card(st: Dictionary):
	var cul: Dictionary = st.get("culture_policy", {})
	if cul.is_empty():
		return
	var soft := clampf(float(cul.get("soft_power", 40.0)), 0.0, 100.0)
	var card = _card("🎭 فرهنگ و قدرت نرم")
	_row(card, "قدرت نرم", PersianFormatter.to_persian_digits("%.0f / ۱۰۰" % soft), _color_for(soft / 100.0))
	_bar(card, "قدرت نرم", soft / 100.0)
	_row(card, "سرمایه میراثی", PersianFormatter.to_persian_digits("%.0f٪" % float(cul.get("heritage", 35.0))))
	_row(card, "رویدادهای میزبانی‌شده", PersianFormatter.to_persian_digits(str(cul.get("events_hosted", 0))))
	var act_row = HBoxContainer.new(); act_row.add_theme_constant_override("separation", 5); card.add_child(act_row)
	var her_btn = Button.new(); her_btn.text = "🏛️ سرمایه میراث"
	her_btn.custom_minimum_size = Vector2(0, 40); her_btn.add_theme_font_size_override("font_size", 13)
	her_btn.pressed.connect(FeedbackManager.play_click); her_btn.pressed.connect(_on_culture.bind("heritage"))
	_mark_decision_button(her_btn, "cul:heritage")
	act_row.add_child(her_btn)
	var exc_btn = Button.new(); exc_btn.text = "🌐 تبادل فرهنگی"
	exc_btn.custom_minimum_size = Vector2(0, 40); exc_btn.add_theme_font_size_override("font_size", 13)
	exc_btn.pressed.connect(FeedbackManager.play_click); exc_btn.pressed.connect(_on_culture.bind("exchange"))
	_mark_decision_button(exc_btn, "cul:exchange")
	act_row.add_child(exc_btn)
	var ev_row = HBoxContainer.new(); ev_row.add_theme_constant_override("separation", 5); card.add_child(ev_row)
	var ev_lbl = Label.new(); ev_lbl.text = "رویداد جهانی:"; ev_lbl.add_theme_font_size_override("font_size", 14); ev_lbl.modulate = TEXT_MUTED; ev_row.add_child(ev_lbl)
	for ev in [["festival", "🎉 جشنواره"], ["sports", "🏅 ورزشی"], ["film", "🎬 سینما"]]:
		var btn = Button.new(); btn.text = ev[1]
		btn.custom_minimum_size = Vector2(0, 38); btn.add_theme_font_size_override("font_size", 12)
		btn.disabled = int(st.get("tick", 0)) - int(cul.get("last_event", 0)) < 12
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_culture.bind(ev[0]))
		_mark_decision_button(btn, "cul:" + ev[0])
		ev_row.add_child(btn)
	var hint = Label.new()
	hint.text = "قدرت نرم گردشگری، محبوبیت رهبر و نفوذ دیپلماتیک را می‌سازد و از میراث، رسانه و محبوبیت تغذیه می‌شود. رویدادهای جهانی هر ۱۲ نوبت یک بار."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_culture(action: String):
	var cmd = GameCommandClass.create_culture_action(action, action)
	var labels := {"heritage": "سرمایه‌گذاری میراث", "exchange": "تبادل فرهنگی", "festival": "جشنواره جهانی", "sports": "رویداد ورزشی", "film": "جشنواره فیلم"}
	if _queue_decision(cmd, "🎭 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("population")

# ── صنایع دفاعی و صادرات تسلیحات ──
func _build_arms_card(st: Dictionary):
	var arms: Dictionary = st.get("arms_industry", {})
	if arms.is_empty():
		return
	var stock := float(arms.get("stock", 50.0))
	var capacity := float(arms.get("capacity", 20.0))
	var card = _card("🔫 صنایع دفاعی و صادرات تسلیحات")
	_row(card, "ظرفیت تولید", PersianFormatter.to_persian_digits("%.0f" % capacity))
	_row(card, "انبار تجهیزات", PersianFormatter.to_persian_digits("%.0f واحد" % stock))
	_row(card, "تحریم تسلیحاتی", "فعال 🚫" if bool(arms.get("embargo", false)) else "غیرفعال", Color(1.0, 0.4, 0.4) if bool(arms.get("embargo", false)) else Color(0.4, 0.9, 0.55))
	var act_row = HBoxContainer.new(); act_row.add_theme_constant_override("separation", 5); card.add_child(act_row)
	var inv_btn = Button.new(); inv_btn.text = "🏭 توسعه ظرفیت"
	inv_btn.custom_minimum_size = Vector2(0, 40); inv_btn.add_theme_font_size_override("font_size", 13)
	inv_btn.disabled = capacity >= 100.0
	inv_btn.pressed.connect(FeedbackManager.play_click); inv_btn.pressed.connect(_on_arms.bind("invest", "", 0.0))
	_mark_decision_button(inv_btn, "arms:invest")
	act_row.add_child(inv_btn)
	var tr_btn = Button.new(); tr_btn.text = "🪖 به ارتش (۱۰)"
	tr_btn.custom_minimum_size = Vector2(0, 40); tr_btn.add_theme_font_size_override("font_size", 13)
	tr_btn.disabled = stock < 10.0
	tr_btn.pressed.connect(FeedbackManager.play_click); tr_btn.pressed.connect(_on_arms.bind("transfer", "", 10.0))
	_mark_decision_button(tr_btn, "arms:transfer")
	act_row.add_child(tr_btn)
	# خریداران پیشنهادی: روابط خوب یا درگیر
	var relations: Dictionary = st.get("diplomacy", {}).get("relations", {})
	var candidates: Array = []
	var player_id := str(st.get("world", {}).get("player_country", ""))
	for cid in relations.keys():
		if cid == player_id or candidates.size() >= 3:
			continue
		if float(relations[cid]) >= 35.0 or st.get("world", {}).get("wars", {}).has(cid):
			candidates.append(cid)
	if not candidates.is_empty():
		var sell_lbl = Label.new(); sell_lbl.text = "قرارداد فروش (هر کشور ۱۰ واحد):"
		sell_lbl.add_theme_font_size_override("font_size", 14); sell_lbl.modulate = TEXT_MUTED
		card.add_child(sell_lbl)
		var sell_row = HBoxContainer.new(); sell_row.add_theme_constant_override("separation", 5); card.add_child(sell_row)
		for cid in candidates:
			var btn = Button.new(); btn.text = WorldManager.get_country_name(str(cid))
			btn.custom_minimum_size = Vector2(0, 38); btn.add_theme_font_size_override("font_size", 12)
			btn.disabled = stock < 10.0 or bool(arms.get("embargo", false))
			btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_arms.bind("sell", str(cid), 10.0))
			_mark_decision_button(btn, "arms:sell:" + str(cid))
			sell_row.add_child(btn)
	var hint = Label.new()
	hint.text = "تولید هر ماه به انبار می‌رود؛ فروش به دوستان و درگیران ذخایر ارزی و نفوذ می‌آورد ولی تنش را بالا می‌برد. تحریم تسلیحاتی فروش را می‌بندد."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_arms(action: String, target: String, amount: float):
	var cmd = GameCommandClass.create_arms_action(action, target, amount)
	var labels := {"invest": "توسعه صنایع دفاعی", "sell": "فروش تسلیحات", "transfer": "انتقال به ارتش"}
	if _queue_decision(cmd, "🔫 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("military")

# ── جنگ سایبری: فایروال و حملات ──
func _build_cyber_card(st: Dictionary):
	var cy: Dictionary = st.get("cyber", {})
	if cy.is_empty():
		return
	var offense := CyberManager.offense_level(st)
	var defense := CyberManager.defense_level(st)
	# latch: حملهٔ سایبری هر ۳ نوبت یک‌بار (cyber_manager.cyber_attack)
	var _turn_now: int = int(st.get("time", {}).get("turn", 0))
	var _atk_left: int = maxi(0, 3 - (_turn_now - int(cy.get("last_attack", -99))))
	var card = _card("💻 جنگ سایبری")
	_row(card, "توان تهاجمی", PersianFormatter.to_persian_digits("%.0f" % offense))
	_row(card, "توان دفاعی", PersianFormatter.to_persian_digits("%.0f" % defense))
	_bar(card, "فایروال", float(cy.get("firewall", 0.4)))
	_row(card, "حملات دفع‌شده", PersianFormatter.to_persian_digits(str(cy.get("defended", 0))))
	var act_row = HBoxContainer.new(); act_row.add_theme_constant_override("separation", 5); card.add_child(act_row)
	var fw_btn = Button.new(); fw_btn.text = "🛡️ ارتقای فایروال"
	fw_btn.custom_minimum_size = Vector2(0, 40); fw_btn.add_theme_font_size_override("font_size", 13)
	fw_btn.disabled = float(cy.get("firewall", 0.4)) >= 0.95
	fw_btn.pressed.connect(FeedbackManager.play_click); fw_btn.pressed.connect(_on_cyber.bind("firewall", "", ""))
	_mark_decision_button(fw_btn, "cyber:firewall")
	act_row.add_child(fw_btn)
	if _atk_left > 0:
		_row(card, "⏳ آماده‌سازی حملهٔ بعدی", PersianFormatter.to_persian_digits(str(_atk_left)) + " نوبت دیگر")
	# اهداف حمله
	var world: Dictionary = st.get("world", {})
	var relations: Dictionary = st.get("diplomacy", {}).get("relations", {})
	var targets: Array = []
	for cid in relations.keys():
		if float(relations[cid]) <= 45.0 or world.get("wars", {}).has(cid):
			if not targets.has(cid):
				targets.append(cid)
	if not targets.is_empty():
		var atk_lbl = Label.new(); atk_lbl.text = "حمله به دشمن (نوع):"
		atk_lbl.add_theme_font_size_override("font_size", 14); atk_lbl.modulate = TEXT_MUTED
		card.add_child(atk_lbl)
		for cid in targets:
			var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
			var name = Label.new(); name.text = WorldManager.get_country_name(str(cid))
			name.add_theme_font_size_override("font_size", 14); name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name)
			for kind in [["economy", "اقتصاد"], ["infrastructure", "زیرساخت"], ["information", "اطلاعات"]]:
				var btn = Button.new(); btn.text = kind[1]
				btn.custom_minimum_size = Vector2(0, 32); btn.add_theme_font_size_override("font_size", 11)
				btn.disabled = offense < 25.0 or _atk_left > 0
				btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_cyber.bind("attack", str(cid), kind[0]))
				_mark_decision_button(btn, "cyber:atk:" + str(cid) + ":" + kind[0])
				row.add_child(btn)
	var hint = Label.new()
	hint.text = "حمله موفق اقتصاد/زیرساخت/اطلاعات دشمن را می‌فرساید ولی ریسک افشا دارد (روابط −۲۰ و حتی جنگ). فایروال حملات دشمن در تنش بالا را دفع می‌کند."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_cyber(action: String, target: String, kind: String):
	var cmd = GameCommandClass.create_cyber_action(action, target, kind)
	var label := "ارتقای فایروال" if action == "firewall" else "حمله سایبری به " + WorldManager.get_country_name(target)
	if _queue_decision(cmd, "💻 " + label):
		_toast(label + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("military")

# ── شهرسازی و مسکن ──
func _build_urban_card(st: Dictionary):
	var up: Dictionary = st.get("urban_policy", {})
	if up.is_empty():
		return
	var card = _card("🏙️ شهرسازی و مسکن")
	_bar(card, "مسکن اجتماعی", float(up.get("social_housing", 0.25)))
	_bar(card, "حمل‌ونقل عمومی", float(up.get("public_transit", 0.4)))
	_bar(card, "شهر هوشمند", float(up.get("smart_city", 0.15)))
	_bar(card, "کنترل تراکم", float(up.get("density_control", 0.3)))
	_row(card, "ترافیک", PersianFormatter.to_persian_digits("%.0f٪" % (float(up.get("traffic", 0.45)) * 100.0)), _color_for(1.0 - float(up.get("traffic", 0.45))))
	_row(card, "شاخص هزینه مسکن", PersianFormatter.to_persian_digits("%.0f٪" % (float(up.get("housing_cost", 0.6)) * 100.0)), _color_for(1.0 - float(up.get("housing_cost", 0.6))))
	var act_row = HBoxContainer.new(); act_row.add_theme_constant_override("separation", 4); card.add_child(act_row)
	for act in [["housing", "🏘️ مسکن اجتماعی"], ["transit", "🚇 حمل‌ونقل"], ["smart", "💡 شهر هوشمند"], ["density", "🏗️ کنترل تراکم"]]:
		var btn = Button.new(); btn.text = act[1]
		btn.custom_minimum_size = Vector2(0, 38); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_urban.bind(act[0]))
		_mark_decision_button(btn, "urban:" + act[0])
		act_row.add_child(btn)
	var hint = Label.new()
	hint.text = "مسکن اجتماعی هزینه مسکن را می‌کاهد؛ حمل‌ونقل ترافیک و آلودگی را؛ شهر هوشمند نیازمند دیجیتال ۱۰+ است؛ کنترل تراکم کیفیت می‌آورد ولی زمین را گران می‌کند."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_urban(action: String):
	var cmd = GameCommandClass.create_urban_action(action)
	var labels := {"housing": "مسکن اجتماعی", "transit": "حمل‌ونقل عمومی", "smart": "شهر هوشمند", "density": "کنترل تراکم"}
	if _queue_decision(cmd, "🏙️ " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("population")

# ── رفاه و تأمین اجتماعی ──
func _build_welfare_card(st: Dictionary):
	var wp: Dictionary = st.get("welfare_policy", {})
	if wp.is_empty():
		return
	var welfare: Dictionary = st.get("welfare", {})
	var card = _card("👵 رفاه و تأمین اجتماعی")
	# latch: اصلاح سن بازنشستگی هر ۱۲ نوبت یک‌بار (welfare_manager.set_pension_age)
	var _turn_now: int = int(st.get("time", {}).get("turn", 0))
	var _pen_left: int = maxi(0, 12 - (_turn_now - int(wp.get("last_pension", -99))))
	_row(card, "سن بازنشستگی", PersianFormatter.to_persian_digits(str(int(wp.get("pension_age", 65)))) + " سال" + ("" if _pen_left <= 0 else " · ⏳ " + PersianFormatter.to_persian_digits(str(_pen_left)) + " نوبت تا اصلاح"))
	_bar(card, "فشار صندوق بازنشستگی", float(welfare.get("pension_pressure", 0.3)))
	_bar(card, "بیمه بیکاری", float(wp.get("unemployment_benefit", 0.4)))
	_bar(card, "یارانه فرزند", float(wp.get("child_allowance", 0.2)))
	_bar(card, "پوشش بیمه سلامت", float(wp.get("health_coverage", 0.6)))
	_row(card, "مشارکت خیریه‌های مذهبی", PersianFormatter.to_persian_digits("%.0f٪" % (float(welfare.get("charity_contribution", 0.08)) * 100.0)))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for p in [[60, "👵 ۶۰"], [65, "👴 ۶۵"], [70, "🧓 ۷۰"]]:
		var btn = Button.new(); btn.text = p[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.toggle_mode = true; btn.button_pressed = int(wp.get("pension_age", 65)) == p[0]
		btn.disabled = _pen_left > 0
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_welfare.bind("pension", p[0]))
		_mark_decision_button(btn, "welfare:pension:" + str(p[0]))
		row.add_child(btn)
	var row2 = HBoxContainer.new(); row2.add_theme_constant_override("separation", 4); card.add_child(row2)
	for b in [[0.2, "💰 بیمه ۲۰٪"], [0.5, "💰 بیمه ۵۰٪"], [0.8, "💰 بیمه ۸۰٪"]]:
		var btn = Button.new(); btn.text = b[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.toggle_mode = true; btn.button_pressed = absf(float(wp.get("unemployment_benefit", 0.4)) - b[0]) < 0.05
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_welfare.bind("benefit", b[0]))
		_mark_decision_button(btn, "welfare:benefit:" + str(b[0]))
		row2.add_child(btn)
	var row3 = HBoxContainer.new(); row3.add_theme_constant_override("separation", 4); card.add_child(row3)
	for a in [["child", "👶 یارانه فرزند"], ["health", "🏥 بیمه سلامت"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_welfare.bind(a[0], 0.0))
		_mark_decision_button(btn, "welfare:" + a[0])
		row3.add_child(btn)
	var hint = Label.new()
	hint.text = "افزایش سن بازنشستگی صندوق را نجات می‌دهد ولی بازنشستگان و کارگران می‌شورند؛ بیمه بیکاری رفاه می‌آورد ولی بدهی و تنبلی؛ یارانه فرزند جمعیت جوان می‌کند."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_welfare(action: String, value: float):
	var cmd = GameCommandClass.create_welfare_action(action, value)
	var labels := {"pension": "تغییر سن بازنشستگی", "benefit": "تنظیم بیمه بیکاری", "child": "یارانه فرزند", "health": "توسعه بیمه سلامت"}
	if _queue_decision(cmd, "👵 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("population")

# ── برنامه فضایی: آژانس، ماهواره، پرتاب‌گر ──
func _build_space_card(st: Dictionary):
	var sp: Dictionary = st.get("space_policy", {})
	var spc: Dictionary = st.get("space", {})
	if sp.is_empty():
		return
	var card = _card("🚀 برنامه فضایی")
	_bar(card, "آژانس فضایی", float(sp.get("agency", 0.2)))
	_bar(card, "ماهواره ارتباطی", float(sp.get("satellites_comm", 0.0)))
	_bar(card, "ماهواره سنجش", float(sp.get("satellites_obs", 0.0)))
	_row(card, "پرتاب‌گر بومی", "✔ در مدار" if bool(sp.get("launcher", 0.0)) else "—")
	_row(card, "پرتاب‌ها / شکست‌ها", "%s / %s" % [PersianFormatter.to_persian_digits(str(sp.get("launches", 0))), PersianFormatter.to_persian_digits(str(sp.get("failures", 0)))])
	_row(card, "درآمد پرتاب‌های تجاری", PersianFormatter.format_money(float(spc.get("launch_revenue", 0.0))))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["agency", "🛰️ توسعه آژانس"], ["comm", "📡 ماهواره ارتباطی"], ["obs", "🛰️ ماهواره سنجش"], ["launcher", "🚀 پرتاب‌گر بومی"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 36); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_space.bind(a[0]))
		_mark_decision_button(btn, "space:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "فضا پرستیژ و قدرت نرم می‌آورد؛ ماهواره ارتباطی مخابرات و ماهواره سنجش، کشاورزی و آمادگی بلایا را تقویت می‌کند. پرتاب‌گر نیازمند شاخه فضا ۱۲+ است."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_space(action: String):
	var cmd = GameCommandClass.create_space_action(action)
	var labels := {"agency": "توسعه آژانس فضایی", "comm": "ماهواره ارتباطی", "obs": "ماهواره سنجش", "launcher": "پرتاب‌گر بومی"}
	if _queue_decision(cmd, "🚀 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("technology")

# ── اقتصاد دیجیتال: اینترنت، دولت الکترونیک، CBDC ──
func _build_digital_card(st: Dictionary):
	var dp: Dictionary = st.get("digital_policy", {})
	if dp.is_empty():
		return
	var card = _card("💻 اقتصاد دیجیتال")
	_bar(card, "پوشش اینترنت", float(dp.get("internet_coverage", 0.5)))
	_bar(card, "دولت الکترونیک", float(dp.get("egovernment", 0.3)))
	_bar(card, "ارز دیجیتال ملی (CBDC)", float(dp.get("cbdc", 0.0)))
	_bar(card, "حفاظت حریم خصوصی", float(dp.get("privacy", 0.5)))
	_row(card, "سهم اقتصاد دیجیتال", PersianFormatter.to_persian_digits("%.0f٪" % (float(dp.get("digital_gdp", 0.0)) * 100.0)))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["internet", "📡 گسترش اینترنت"], ["egovernment", "🏛️ دولت الکترونیک"], ["cbdc", "💳 ارز دیجیتال"], ["privacy", "🔒 حریم خصوصی"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_digital.bind(a[0]))
		_mark_decision_button(btn, "digital:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "دولت الکترونیک فساد را می‌خشکاند (دیجیتال ۸+)؛ CBDC اقتصاد سایه را می‌خورد (دیجیتال ۱۲+) ولی سطح حمله سایبری را بالا می‌برد؛ حریم خصوصی اعتماد می‌سازد."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_digital(action: String):
	var cmd = GameCommandClass.create_digital_action(action)
	var labels := {"internet": "گسترش اینترنت", "egovernment": "دولت الکترونیک", "cbdc": "ارز دیجیتال ملی", "privacy": "قانون حریم خصوصی"}
	if _queue_decision(cmd, "💻 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("technology")

# ── ورزش و سلامت عمومی ──
func _build_stock_card(st: Dictionary):
	var sm: Dictionary = st.get("stock_market", {})
	var sp: Dictionary = st.get("stock_policy", {})
	if sp.is_empty():
		return
	var card = _card("📈 بورس اوراق بهادار")
	_row(card, "شاخص کل", PersianFormatter.to_persian_digits("%.0f" % float(sm.get("index", 1000.0))))
	_bar(card, "اعتماد سرمایه‌گذار", float(sm.get("investor_confidence", 0.6)))
	var bubble := float(sp.get("bubble", 0.0))
	var bubble_row = HBoxContainer.new(); bubble_row.add_theme_constant_override("separation", 4); card.add_child(bubble_row)
	var bl = Label.new(); bl.text = "حباب قیمتی"; bl.custom_minimum_size = Vector2(150, 0); bl.add_theme_font_size_override("font_size", 13); bubble_row.add_child(bl)
	var bp = ProgressBar.new(); bp.min_value = 0.0; bp.max_value = 1.0; bp.value = bubble; bp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bp.show_percentage = false
	var bubble_color := Color(0.25, 0.75, 0.35) if bubble < 0.35 else (Color(0.9, 0.7, 0.2) if bubble < 0.55 else Color(0.9, 0.3, 0.25))
	bp.add_theme_stylebox_override("fill", _solid_style(bubble_color))
	bubble_row.add_child(bp)
	_row(card, "شرکت‌های پذیرفته‌شده", PersianFormatter.to_persian_digits(str(sm.get("listed_companies", 0))))
	_row(card, "عرضه‌های اولیه انجام‌شده", PersianFormatter.to_persian_digits(str(sp.get("ipos", 0))))
	_row(card, "سیاست مالیاتی", "مالیات بر عایدی فعال" if str(sp.get("policy", "none")) == "capgains" else "بدون مالیات عایدی")
	_row(card, "نهاد ناظر", PersianFormatter.format_percent(float(sp.get("watchdog", 0.0))))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["ipo", "🏦 عرضه اولیه"], ["support", "🛡️ حمایت از بازار"], ["capgains", "🧾 مالیات عایدی"], ["watchdog", "🔍 تقویت ناظر"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_stock.bind(a[0]))
		_mark_decision_button(btn, "stock:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "شاخص با رشد و ثبات صعود می‌کند؛ حباب زیاد یعنی سقوط نزدیک است. حمایت با ذخایر ارزی هر ۶ نوبت؛ عرضه اولیه خزانه را پر می‌کند؛ ناظر قوی فساد و دستکاری را کم می‌کند."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _build_veterans_card(st: Dictionary):
	var vt: Dictionary = st.get("veterans", {})
	var vp: Dictionary = st.get("veterans_policy", {})
	if vp.is_empty():
		return
	var card = _card("🎖️ بنیاد ایثارگران و کهنه‌سربازان")
	_row(card, "شمار کهنه‌سربازان", PersianFormatter.to_persian_digits(_compact_number(float(vt.get("count", 0)))))
	_bar(card, "رضایت ایثارگران", float(vp.get("satisfaction", 0.6)))
	_bar(card, "سطح مستمری", float(vp.get("pension_level", 0.5)))
	_bar(card, "طرح اشتغال", float(vp.get("employment_program", 0.4)))
	_bar(card, "پوشش درمانی", float(vt.get("health_care", 0.65)))
	_bar(card, "جاذبه خدمت نظامی", float(vt.get("service_appeal", 0.68)))
	_row(card, "بیمارستان تخصصی", "فعال 🟢" if bool(vp.get("clinic", false)) else "غیرفعال ⚪")
	_row(card, "مراسم بزرگداشت", PersianFormatter.to_persian_digits(str(vp.get("parades", 0))))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["pension", "💵 افزایش مستمری"], ["employment", "👷 طرح اشتغال"], ["clinic", "🏥 بیمارستان"], ["parade", "🎖️ بزرگداشت"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_veterans.bind(a[0]))
		_mark_decision_button(btn, "veterans:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "در جنگ، شمار جانبازان می‌شکفد. اگر مستمری و اشتغال ناکافی باشد رضایت می‌ریزد و ثبات آسیب می‌بیند؛ بزرگداشت هر ۱۲ نوبت محبوبیت و همبستگی می‌آورد."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _build_heritage_card(st: Dictionary):
	var hr: Dictionary = st.get("heritage", {})
	var hp: Dictionary = st.get("heritage_policy", {})
	if hp.is_empty():
		return
	var card = _card("🏛️ میراث فرهنگی و گردشگری تاریخی")
	_row(card, "محوطه‌های تاریخی", PersianFormatter.to_persian_digits(str(hr.get("sites", 0))))
	_bar(card, "حفاظت از میراث", float(hr.get("preservation", 0.6)))
	_row(card, "ثبت جهانی (یونسکو)", PersianFormatter.to_persian_digits(str(hr.get("unesco_sites", 0))))
	_bar(card, "گردشگری فرهنگی", float(hr.get("cultural_tourism", 0.5)))
	_row(card, "درآمد سالانه میراث", PersianFormatter.format_money(float(hr.get("annual_income", 0.0))))
	_row(card, "مرمت‌های انجام‌شده", PersianFormatter.to_persian_digits(str(hp.get("restored", 0))))
	_row(card, "جشنواره‌های برگزارشده", PersianFormatter.to_persian_digits(str(hp.get("festivals", 0))))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["restore", "🧱 مرمت محوطه‌ها"], ["register", "🌍 ثبت جهانی"], ["festival", "🎭 جشنواره"], ["antiquities", "🚔 ضد قاچاق"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_heritage.bind(a[0]))
		_mark_decision_button(btn, "heritage:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "میراث درآمد گردشگری و قدرت نرم می‌آورد؛ فرسایش و بلایا آن را تهدید می‌کند. ثبت جهانی تا ۶ محوطه، قدرت نرم را جهش می‌دهد؛ جشنواره هر ۱۲ نوبت."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_stock(action: String):
	var cmd = GameCommandClass.create_stock_action(action)
	var labels := {"ipo": "عرضه اولیه سهام", "support": "حمایت از بازار", "capgains": "سیاست مالیات عایدی", "watchdog": "تقویت نهاد ناظر"}
	if _queue_decision(cmd, "📈 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("economy")

func _on_veterans(action: String):
	var cmd = GameCommandClass.create_veterans_action(action)
	var labels := {"pension": "افزایش مستمری ایثارگران", "employment": "طرح اشتغال جانبازان", "clinic": "بیمارستان تخصصی", "parade": "مراسم بزرگداشت"}
	if _queue_decision(cmd, "🎖️ " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("population")

func _on_heritage(action: String):
	var cmd = GameCommandClass.create_heritage_action(action)
	var labels := {"restore": "مرمت محوطه‌های تاریخی", "register": "پرونده ثبت جهانی", "festival": "جشنواره بین‌المللی میراث", "antiquities": "عملیات ضد قاچاق آثار"}
	if _queue_decision(cmd, "🏛️ " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("population")

func _solid_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(4)
	return sb

func _compact_number(value: float) -> String:
	if value >= 1.0e9:
		return "%.1f میلیارد" % (value / 1.0e9)
	if value >= 1.0e6:
		return "%.1f میلیون" % (value / 1.0e6)
	if value >= 1.0e3:
		return "%.1f هزار" % (value / 1.0e3)
	return str(int(value))

func _build_transport_card(st: Dictionary):
	var pt: Dictionary = st.get("public_transport", {})
	var tp: Dictionary = st.get("transport_policy", {})
	if tp.is_empty():
		return
	var card = _card("🚇 حمل‌ونقل عمومی")
	_bar(card, "پوشش شبکه", float(pt.get("coverage", 0.6)))
	_bar(card, "رضایت مسافران", float(pt.get("satisfaction", 0.55)))
	_bar(card, "قیمت‌مناسب بودن کرایه", float(pt.get("affordability", 0.7)))
	_bar(card, "وقت‌شناسی", float(pt.get("punctuality", 0.75)))
	_row(card, "خطوط مترو", PersianFormatter.to_persian_digits(str(pt.get("metro_lines", 0))))
	_row(card, "خطوط BRT", PersianFormatter.to_persian_digits(str(pt.get("brt_lines", 0))))
	_row(card, "سن ناوگان (سال)", PersianFormatter.to_persian_digits("%.1f" % float(pt.get("fleet_age", 7.0))))
	_bar(card, "برقی‌سازی", float(pt.get("electrification", 0.15)))
	_bar(card, "سطح یارانه کرایه", float(tp.get("subsidy_level", 0.5)))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["metro", "🚇 خط مترو"], ["brt", "🚌 خط BRT"], ["subsidy", "💸 یارانه کرایه"], ["fleet", "🔋 ناوگان برقی"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_transport.bind(a[0]))
		_mark_decision_button(btn, "transport:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "مترو هر ۸ نوبت، ناوگان هر ۶ نوبت و BRT هر ۴ نوبت. یارانه کرایه هزینه ماهانه دارد؛ رضایت پایین → اعتصاب و بی‌ثباتی."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _build_retail_card(st: Dictionary):
	var retail: Dictionary = st.get("retail", {})
	var rp: Dictionary = st.get("retail_policy", {})
	if rp.is_empty():
		return
	var card = _card("🛒 بازار مصرف و خرده‌فروشی")
	_bar(card, "اعتماد مصرف‌کننده", float(rp.get("confidence", 0.6)))
	_row(card, "سطح قیمت مصرف‌کننده", PersianFormatter.to_persian_digits("%.2f" % float(retail.get("price_level", 1.0))))
	_bar(card, "رقابت بازار", float(retail.get("competition", 0.6)))
	_bar(card, "سهم تجارت الکترونیک", float(retail.get("e_commerce_share", 0.15)))
	_row(card, "تنظیم قیمت کالاهای اساسی", "فعال 🔴" if bool(rp.get("price_control", false)) else "غیرفعال ⚪")
	_bar(card, "حمایت از مصرف‌کننده", float(rp.get("consumer_protection", 0.4)))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["price", "🏷️ تنظیم قیمت"], ["protect", "🛡️ حمایت مصرف‌کننده"], ["ecommerce", "🛒 تجارت الکترونیک"], ["bazaar", "🏪 نوسازی بازار"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_retail.bind(a[0]))
		_mark_decision_button(btn, "retail:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "تجارت الکترونیک به شاخه دیجیتال سطح ۶ نیاز دارد؛ تنظیم قیمت ارزانی می‌آورد ولی بازار سیاه می‌بالد؛ نوسازی بازار هر ۱۰ نوبت."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _build_ethnicity_card(st: Dictionary):
	var eth: Dictionary = st.get("ethnicity", {})
	var ep: Dictionary = st.get("ethnicity_policy", {})
	if ep.is_empty():
		return
	var card = _card("🕊️ همبستگی قومی")
	_bar(card, "تنش هویتی", float(eth.get("tension", 0.3)))
	_bar(card, "ادغام ملی", float(eth.get("integration", 0.55)))
	_bar(card, "تبعیض", float(eth.get("discrimination", 0.2)))
	_bar(card, "حقوق فرهنگی", float(eth.get("cultural_rights", 0.6)))
	_bar(card, "فرصت‌های برابر", float(ep.get("equal_programs", 0.4)))
	_bar(card, "نمایندگی در دولت", float(ep.get("representation", 0.4)))
	_row(card, "گفت‌وگوهای برگزارشده", PersianFormatter.to_persian_digits(str(ep.get("dialogues", 0))))
	var groups: Array = eth.get("groups", [])
	if not groups.is_empty():
		var gtxt := ""
		for g in groups:
			if g is Dictionary:
				gtxt += "%s %d٪  " % [str(g.get("name", "")), int(roundf(float(g.get("happiness", 0.5)) * 100.0))]
		var gl = Label.new(); gl.text = "رضایت اقوام: " + gtxt
		gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; gl.add_theme_font_size_override("font_size", 13); gl.modulate = TEXT_FAINT
		card.add_child(gl)
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["equal", "⚖️ فرصت‌های برابر"], ["autonomy", "🏳️ خودمختاری فرهنگی"], ["dialogue", "🤝 گفت‌وگوی ملی"], ["festival", "🎊 جشنواره اقوام"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_ethnicity.bind(a[0]))
		_mark_decision_button(btn, "ethnicity:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "تنش بالا → بحران هویتی و جدایی‌طلبی. گفت‌وگو هر ۴ نوبت، جشنواره اقوام هر ۱۲ نوبت؛ خودمختاری فرهنگی پوپولیست‌ها را ناراضی می‌کند."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _build_water_card(st: Dictionary):
	var wp: Dictionary = st.get("water_policy", {})
	var wi: Dictionary = st.get("water_infrastructure", {})
	if wp.is_empty():
		return
	var card = _card("💧 امنیت آبی")
	_bar(card, "تنش آبی", float(wi.get("stress_index", 0.45)))
	_bar(card, "ذخیره سدها و مخازن", clampf(float(wi.get("storage_bcm", 35.0)) / 100.0, 0.0, 1.0))
	_bar(card, "سهم آب‌شیرین‌کن", float(wp.get("desalination", 0.05)))
	_bar(card, "بازده آبیاری", float(wp.get("irrigation_efficiency", 0.35)))
	_bar(card, "هدررفت شبکه", float(wp.get("leakage", 0.28)))
	_bar(card, "بازچرخانی پساب", float(wi.get("wastewater_reuse", 0.12)))
	_bar(card, "تراز سفره زیرزمینی", float(wp.get("aquifer", 0.70)))
	_row(card, "ظرفیت ذخیره (میلیارد مترمکعب)", PersianFormatter.to_persian_digits("%.1f" % float(wi.get("storage_bcm", 35.0))))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["dam", "🛢️ سد جدید"], ["desal", "🌊 آب‌شیرین‌کن"], ["leakage", "🔧 کاهش هدررفت"], ["irrigation", "🌱 آبیاری نوین"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_water.bind(a[0]))
		_mark_decision_button(btn, "water:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "سد هر ۱۲ نوبت و آب‌شیرین‌کن هر ۹ نوبت و نیازمند انرژی پاک سطح ۵ است. خشکسالی، نشت شبکه و برداشت بی‌رویه → بحران آب، فرونشست و ناامنی غذایی."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_water(action: String):
	var cmd = GameCommandClass.create_water_action(action)
	var labels := {"dam": "ساخت سد و مخزن", "desal": "توسعه آب‌شیرین‌کن", "leakage": "نوسازی شبکه آبرسانی", "irrigation": "گسترش آبیاری نوین"}
	if _queue_decision(cmd, "💧 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("economy")

func _build_research_card(st: Dictionary):
	var rp: Dictionary = st.get("research_policy", {})
	if rp.is_empty():
		return
	var card = _card("🔬 پژوهش و نوآوری ملی")
	_bar(card, "شاخص نوآوری", float(rp.get("innovation_index", 0.35)))
	_bar(card, "بودجه دانشگاه‌ها", float(rp.get("university_funding", 0.45)))
	_bar(card, "مراکز تحقیقات راهبردی", float(rp.get("rnd_centers", 0.25)))
	_bar(card, "انتقال فناوری", float(rp.get("tech_transfer", 0.20)))
	_bar(card, "تجاری‌سازی", float(rp.get("commercialization", 0.30)))
	_bar(card, "فرار مغزها", float(rp.get("brain_drain", 0.28)))
	_bar(card, "ظرفیت پژوهش نخبگان", float(st.get("technology", {}).get("elite_research_capacity", 0.65)))
	_row(card, "مقاله‌های علمی", PersianFormatter.to_persian_digits(str(rp.get("papers", 0))))
	_row(card, "اختراع‌های ثبت‌شده", PersianFormatter.to_persian_digits(str(rp.get("patents", 0))))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["university", "🎓 بودجه دانشگاه"], ["center", "🏛️ پژوهشگاه"], ["transfer", "🤝 انتقال فناوری"], ["talent", "🧲 بازگشت نخبگان"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_research.bind(a[0]))
		_mark_decision_button(btn, "research:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "علم بنیادی بلندمدت است ولی نوآوری می‌سازد. مرکز پژوهشی هر ۸ نوبت، بسته نخبگان هر ۶ نوبت. فرار مغزها رشد و کیفیت آموزش را تخلیه می‌کند."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_research(action: String):
	var cmd = GameCommandClass.create_research_action(action)
	var labels := {"university": "افزایش بودجه دانشگاه‌ها", "center": "احداث پژوهشگاه راهبردی", "transfer": "برنامه انتقال فناوری", "talent": "بسته ماندگاری نخبگان"}
	if _queue_decision(cmd, "🔬 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("technology")

func _build_civic_card(st: Dictionary):
	var cp: Dictionary = st.get("civic_policy", {})
	if cp.is_empty():
		return
	var card = _card("🤝 مشارکت مدنی و سرمایه اجتماعی")
	_bar(card, "سرمایه اجتماعی", float(cp.get("social_capital", 0.50)))
	_bar(card, "شفافیت و داده باز", float(cp.get("transparency", 0.45)))
	_bar(card, "قدرت شوراهای محلی", float(cp.get("local_councils", 0.35)))
	_bar(card, "بودجه‌ریزی مشارکتی", float(cp.get("participatory_budget", 0.20)))
	_bar(card, "فضای سازمان‌های مردم‌نهاد", float(cp.get("ngo_space", 0.40)))
	_bar(card, "دیده‌بان مدنی", float(cp.get("watchdog", 0.25)))
	_row(card, "اعتراض فروخورده", PersianFormatter.to_persian_digits(str(cp.get("protests_under", 0))))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["opendata", "📂 داده باز"], ["councils", "🏘️ شوراهای محلی"], ["budget", "🗳️ بودجه مشارکتی"], ["ngos", "🕊️ حمایت از سمن‌ها"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_civic.bind(a[0]))
		_mark_decision_button(btn, "civic:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "مشارکت مدنی اعتماد و کارآمدی می‌سازد و فشارها را پیش از انفجار تخلیه می‌کند. مجمع بودجه مشارکتی هر ۵ نوبت؛ سرکوب سمن‌ها اعتراض زیرزمینی انبار می‌کند."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_civic(action: String):
	var cmd = GameCommandClass.create_civic_action(action)
	var labels := {"opendata": "قانون دسترسی آزاد به اطلاعات", "councils": "تقویت شوراهای محلی", "budget": "بودجه‌ریزی مشارکتی", "ngos": "حمایت از سازمان‌های مردم‌نهاد"}
	if _queue_decision(cmd, "🤝 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("government")

func _build_diaspora_card(st: Dictionary):
	var dp: Dictionary = st.get("diaspora_policy", {})
	if dp.is_empty():
		return
	var card = _card("🌍 دیاسپورا و دیپلماسی عمومی")
	_bar(card, "اعتماد شبکه مهاجران", float(dp.get("trust", 0.45)))
	_bar(card, "تعامل رسمی", float(dp.get("engagement", 0.35)))
	_bar(card, "شبکه‌های تخصصی", float(dp.get("networks", 0.25)))
	_bar(card, "دیپلماسی عمومی", float(dp.get("public_diplomacy", 0.20)))
	_bar(card, "انگیزه بازگشت", float(dp.get("return_incentive", 0.15)))
	_row(card, "حواله سالانه (میلیارد)", PersianFormatter.to_persian_digits("%.1f" % float(dp.get("remittance_b", 12.0))))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["summit", "🌐 اجلاس دیاسپورا"], ["networks", "🔗 شبکه تخصصی"], ["diplomacy", "📡 دیپلماسی عمومی"], ["return", "🧳 بازگشت نخبگان"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_diaspora.bind(a[0]))
		_mark_decision_button(btn, "diaspora:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "اجلاس هر ۸ نوبت. تعامل بالا حواله ارزی، لابی، قدرت نرم و سرمایه‌گذاری می‌آورد؛ فساد و بی‌ثباتی اعتماد دیاسپورا را می‌شکند."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_diaspora(action: String):
	var cmd = GameCommandClass.create_diaspora_action(action)
	var labels := {"summit": "اجلاس جهانی دیاسپورا", "networks": "توسعه شبکه‌های تخصصی", "diplomacy": "تقویت دیپلماسی عمومی", "return": "بسته بازگشت نخبگان"}
	if _queue_decision(cmd, "🌍 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("government")

func _build_civil_defense_card(st: Dictionary):
	var cd: Dictionary = st.get("civil_defense_policy", {})
	if cd.is_empty():
		return
	var card = _card("🛡️ پدافند غیرعامل و تاب‌آوری")
	_bar(card, "شاخص تاب‌آوری", float(cd.get("resilience_index", 0.30)))
	_bar(card, "حفاظت غیرنظامیان", float(cd.get("civilian_protection", 0.30)))
	_bar(card, "سخت‌سازی هدف‌ها", float(cd.get("hardening", 0.25)))
	_bar(card, "افزونگی زیرساخت", float(cd.get("redundancy", 0.20)))
	_bar(card, "پوشش پناهگاه", float(cd.get("shelters", 0.20)))
	_bar(card, "ذخیره راهبردی", float(cd.get("strategic_stock", 0.30)))
	_row(card, "مهار خسارت حمله/بحران", PersianFormatter.to_persian_digits("%.0f٪" % (float(cd.get("damage_mitigation", 0.30)) * 100.0)), _color_for(float(cd.get("damage_mitigation", 0.30))))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["hardening", "🏗️ سخت‌سازی"], ["redundancy", "🔀 افزونگی"], ["shelters", "🏚️ پناهگاه"], ["stockpile", "📦 ذخیره راهبردی"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_civil_defense.bind(a[0]))
		_mark_decision_button(btn, "civil_defense:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "سخت‌سازی هر ۶ نوبت. پدافند به جای حمله، خسارت حمله، بحران و اختلال آبشاری را کم می‌کند و بازدارندگی را بالا می‌برد."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_civil_defense(action: String):
	var cmd = GameCommandClass.create_civil_defense_action(action)
	var labels := {"hardening": "سخت‌سازی هدف‌های حیاتی", "redundancy": "افزونگی زیرساخت", "shelters": "توسعه پناهگاه", "stockpile": "ذخیره راهبردی"}
	if _queue_decision(cmd, "🛡️ " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("military")

func _build_blue_economy_card(st: Dictionary):
	var be: Dictionary = st.get("blue_economy_policy", {})
	if be.is_empty():
		return
	var card = _card("⚓ اقتصاد دریایی و شیلات")
	_bar(card, "ظرفیت بنادر", float(be.get("port_capacity", 0.40)))
	_bar(card, "ناوگان تجاری", float(be.get("merchant_fleet", 0.30)))
	_bar(card, "کشتیرانی و کشتی‌سازی", float(be.get("shipbuilding", 0.20)))
	_bar(card, "شیلات پایدار", float(be.get("sustainable_fisheries", 0.35)))
	_bar(card, "گشت دریایی", float(be.get("coast_guard", 0.30)))
	_row(card, "سهم اقتصاد دریا", PersianFormatter.format_percent(float(be.get("blue_gdp", 0.0)) / max(float(st.get("economy", {}).get("gdp", 1.0)), 1.0)))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["port", "⚓ توسعه بندر"], ["fleet", "🚢 ناوگان تجاری"], ["fishery", "🐟 شیلات پایدار"], ["patrol", "🛥️ گشت دریایی"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_blue_economy.bind(a[0]))
		_mark_decision_button(btn, "blue_economy:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "بندر هر ۸، ناوگان هر ۱۰ و گشت فشرده هر ۴ نوبت. صید بی‌رویه ذخایر را می‌خشکاند؛ گشت قاچاق سوخت را می‌کاهد."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_blue_economy(action: String):
	var cmd = GameCommandClass.create_blue_economy_action(action)
	var labels := {"port": "توسعه ظرفیت بندر", "fleet": "توسعه ناوگان تجاری", "fishery": "مدیریت پایدار شیلات", "patrol": "گشت دریایی"}
	if _queue_decision(cmd, "⚓ " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("military")

func _build_creative_card(st: Dictionary):
	var cp: Dictionary = st.get("creative_policy", {})
	if cp.is_empty():
		return
	var card = _card("🎬 اقتصاد خلاق و صنایع فرهنگی")
	_bar(card, "شاخص خلاقیت", float(cp.get("creative_index", 0.30)))
	_bar(card, "صندوق حمایت", float(cp.get("funding", 0.25)))
	_bar(card, "آموزش هنری", float(cp.get("education", 0.25)))
	_bar(card, "پلتفرم توزیع", float(cp.get("platform", 0.15)))
	_bar(card, "صادرات فرهنگی", float(cp.get("export", 0.15)))
	_bar(card, "دزدی دریایی", float(cp.get("piracy", 0.45)))
	_row(card, "اشتغال خلاق", PersianFormatter.to_persian_digits(str(int(cp.get("jobs", 0)))))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["funding", "💰 صندوق"], ["education", "🎓 آموزش"], ["platform", "📱 پلتفرم"], ["export", "🌍 جشنواره"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_creative.bind(a[0]))
		_mark_decision_button(btn, "creative:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "پلتفرم به دیجیتال ۸ نیاز دارد. اقتصاد خلاق اشتغال جوانان و قدرت نرم می‌سازد؛ جشنواره هر ۶ نوبت."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_creative(action: String):
	var cmd = GameCommandClass.create_creative_action(action)
	var labels := {"funding": "صندوق تولید فرهنگی", "education": "آموزش هنر و خلاقیت", "platform": "سکوی توزیع فرهنگی", "export": "جشنواره و صادرات فرهنگی"}
	if _queue_decision(cmd, "🎬 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("economy")

func _build_demographic_card(st: Dictionary):
	var dp: Dictionary = st.get("demographic_policy", {})
	if dp.is_empty():
		return
	var card = _card("📊 تحول جمعیتی و پنجره جمعیت")
	_bar(card, "پنجره جمعیت", float(dp.get("window", 0.55)))
	_bar(card, "شاخص سالخوردگی", float(dp.get("aging_index", 0.25)))
	_bar(card, "سلامت صندوق بازنشستگی", float(dp.get("pension_fund", 0.55)))
	_bar(card, "مشوق فرزندآوری", float(dp.get("fertility_incentive", 0.20)))
	_bar(card, "پوشش مهدکودک", float(dp.get("childcare", 0.25)))
	_bar(card, "مراقبت سالمندی", float(dp.get("elderly_care", 0.20)))
	_bar(card, "بازآموزی نیروی کار", float(dp.get("retraining", 0.15)))
	_row(card, "میانگین سن", PersianFormatter.to_persian_digits("%.1f" % float(dp.get("median_age", 31.0))))
	var fam: Dictionary = st.get("family", {})
	_row(card, "بعد خانوار", PersianFormatter.to_persian_digits("%.1f نفر" % float(fam.get("avg_household_size", 3.0))))
	_bar(card, "اشتغال زنان", float(fam.get("female_workforce", 0.53)))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["pronatal", "👶 مشوق تولد"], ["childcare", "🧸 مهدکودک"], ["elderly", "👴 سالمندی"], ["retraining", "🎓 بازآموزی"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_demographic.bind(a[0]))
		_mark_decision_button(btn, "demographic:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "پنجره جمعیت موتور رشد است؛ با سالخوردگی صندوق زیر فشار می‌رود. مشوق فرزندآوری هر ۵ نوبت."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_demographic(action: String):
	var cmd = GameCommandClass.create_demographic_action(action)
	var labels := {"pronatal": "بسته حمایت از فرزندآوری", "childcare": "توسعه مهدکودک", "elderly": "مراقبت سالمندان", "retraining": "بازآموزی نیروی کار"}
	if _queue_decision(cmd, "📊 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("population")

func _build_watershed_card(st: Dictionary):
	var wp: Dictionary = st.get("watershed_policy", {})
	if wp.is_empty():
		return
	var card = _card("⛰️ آبخیزداری و مقابله با بیابان‌زایی")
	_bar(card, "سلامت خاک", float(wp.get("soil_health", 0.55)))
	_bar(card, "فرسایش خاک", float(wp.get("erosion_rate", 0.35)))
	_bar(card, "پوشش جنگلی", float(wp.get("forest_cover", 0.20)))
	_bar(card, "بیابان‌زایی", float(wp.get("desertification", 0.45)))
	_bar(card, "شدت ریزگرد", float(wp.get("dust", 0.40)))
	_bar(card, "احیای آبخیز", float(wp.get("restoration", 0.20)))
	_bar(card, "مقابله با ریزگرد", float(wp.get("dust_control", 0.20)))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["restore", "⛰️ آبخیزداری"], ["forest", "🌲 جنگل‌کاری"], ["dust", "💨 ضد ریزگرد"], ["wetlands", "🦩 تا‌لاب"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_watershed.bind(a[0]))
		_mark_decision_button(btn, "watershed:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "آبخیزداری هر ۶ نوبت. فرسایش خاک محصول را می‌کاهد، ریزگرد سلامت و حمل‌ونقل را تخریب می‌کند."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_watershed(action: String):
	var cmd = GameCommandClass.create_watershed_action(action)
	var labels := {"restore": "احیای آبخیز و پخش سیلاب", "forest": "جنگل‌کاری و احیای مرتع", "dust": "مقابله با کانون ریزگرد", "wetlands": "احیای تا‌لاب‌ها"}
	if _queue_decision(cmd, "⛰️ " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("economy")

func _build_prison_card(st: Dictionary):
	var pp: Dictionary = st.get("prison_policy", {})
	var prison: Dictionary = st.get("prison", {})
	if pp.is_empty():
		return
	var card = _card("🔐 زندان و سیاست کیفری")
	var approach_names := {"punitive": "سخت‌گیرانه", "balanced": "متعادل", "rehab": "بازپرورانه"}
	var approach_name: String = str(approach_names.get(str(pp.get("approach", "balanced")), "متعادل"))
	_row(card, "رویکرد", approach_name)
	_bar(card, "ازدحام زندان", clampf(float(prison.get("overcrowding", 0.8)) / 2.0, 0.0, 1.0))
	_bar(card, "بازاجتماعی‌سازی", float(prison.get("rehabilitation", 0.4)))
	_bar(card, "بازگشت به جرم", float(prison.get("recidivism", 0.35)))
	_bar(card, "شرایط زندان", float(prison.get("conditions", 0.55)))
	_bar(card, "آموزش در زندان", float(pp.get("education", 0.30)))
	_bar(card, "آزادی مشروط", float(pp.get("parole", 0.30)))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["punitive", "⚖️ سخت‌گیرانه"], ["rehab", "🌱 بازپرورانه"], ["capacity", "🏗️ ظرفیت"], ["amnesty", "🕊️ عفو"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		if a[0] in ["punitive", "rehab"]:
			btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_prison_approach.bind(a[0]))
			_mark_decision_button(btn, "prison:approach:" + a[0])
		else:
			var act_id = "capacity" if a[0] == "capacity" else "amnesty"
			btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_prison.bind(act_id))
			_mark_decision_button(btn, "prison:" + act_id)
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "رویکرد سختگیرانه جمعیت و هزینه را بالا می‌برد؛ بازپروری بازگشت به جرم را کم می‌کند."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)
	var edu_btn = _mk_btn(card, "📚 برنامه آموزشی زندان", Vector2(180, 38), _on_prison.bind("education"))
	_mark_decision_button(edu_btn, "prison:education")

func _on_prison(action: String):
	var cmd = GameCommandClass.create_prison_action(action)
	var labels := {"capacity": "توسعه ظرفیت زندان", "education": "آموزش در زندان", "amnesty": "عفو و آزادی مشروط"}
	if _queue_decision(cmd, "🔐 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("government")

func _on_prison_approach(approach: String):
	var cmd = GameCommandClass.create_prison_approach(approach)
	var labels := {"punitive": "سیاست کیفری سخت‌گیرانه", "rehab": "سیاست کیفری بازپرورانه"}
	if _queue_decision(cmd, "🔐 " + labels.get(approach, approach)):
		_toast(labels.get(approach, approach) + " ثبت شد")
		_switch_tab("government")

func _build_statistics_card(st: Dictionary):
	var sp: Dictionary = st.get("statistics_policy", {})
	if sp.is_empty():
		return
	var card = _card("📊 آمار ملی و حاکمیت داده")
	_bar(card, "دقت آمار", float(sp.get("accuracy", 0.75)))
	_bar(card, "اعتماد به داده", float(sp.get("trust_in_data", 0.55)))
	_bar(card, "استقلال مرکز آمار", float(sp.get("independence", 0.55)))
	_bar(card, "زیرساخت داده", float(sp.get("data_infrastructure", 0.40)))
	_bar(card, "پوشش کد ملی", float(sp.get("id_coverage", 0.85)))
	_bar(card, "کم‌گمارشی", float(sp.get("underreporting", 0.20)))
	var stats_live: Dictionary = st.get("statistics", {})
	var p_err := clampf(float(stats_live.get("policy_error_risk", 0.36)), 0.0, 1.0)
	_row(card, "ریسک خطای سیاست", PersianFormatter.to_persian_digits("%.0f٪" % (p_err * 100.0)), _color_for(1.0 - p_err))
	_row(card, "برآورد اقتصاد غیررسمی", PersianFormatter.to_persian_digits("%.0f٪ از GDP" % (float(stats_live.get("informal_economy_estimate", 0.16)) * 100.0)))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["census", "📋 سرشماری"], ["infra", "🗄️ پایگاه داده"], ["independence", "📜 استقلال"], ["opendata", "🔓 داده باز"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_statistics.bind(a[0]))
		_mark_decision_button(btn, "stats:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "سرشماری هر ۱۰ نوبت. آمار دقیق خطای سیاست را کم می‌کند؛ دستکاری آمار اعتماد را می‌شکند."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_statistics(action: String):
	var cmd = GameCommandClass.create_statistics_action(action)
	var labels := {"census": "اجرای سرشماری ملی", "infra": "تقویت زیرساخت داده", "independence": "تضمین استقلال آمار", "opendata": "درگاه داده باز"}
	if _queue_decision(cmd, "📊 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("government")

func _build_mining_card(st: Dictionary):
	var mp: Dictionary = st.get("mining_policy", {})
	if mp.is_empty():
		return
	var card = _card("⛏️ معدن و صنایع استخراجی")
	_bar(card, "ذخایر معدنی", float(mp.get("reserves", 0.65)))
	_bar(card, "سطح تولید", float(mp.get("output", 0.0)))
	_bar(card, "فرآوری داخل", float(mp.get("processing", 0.25)))
	_bar(card, "ایمنی معادن", float(mp.get("safety", 0.40)))
	_bar(card, "ساماندهی معادن", float(mp.get("formalization", 0.35)))
	_bar(card, "ریسک حادثه", float(mp.get("accident_risk", 0.30)))
	_row(card, "سهم خام‌فروشی", PersianFormatter.format_percent(float(mp.get("raw_export_share", 0.70))))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["mine", "⛏️ توسعه معدن"], ["refinery", "🏭 فرآوری"], ["safety", "🦺 ایمنی"], ["formalize", "📋 ساماندهی"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_mining.bind(a[0]))
		_mark_decision_button(btn, "mining:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "فرآوری داخل نیازمند فناوری صنعت ۶+ است؛ ارزش افزوده می‌سازد و خام‌فروشی را کم می‌کند."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_mining(action: String):
	var cmd = GameCommandClass.create_mining_action(action)
	var labels := {"mine": "اکتشاف و توسعه معدن", "refinery": "احداث واحد فرآوری", "safety": "ارتقای ایمنی معادن", "formalize": "ساماندهی معادن کوچک"}
	if _queue_decision(cmd, "⛏️ " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("economy")

func _build_waste_card(st: Dictionary):
	var wp: Dictionary = st.get("waste_policy", {})
	if wp.is_empty():
		return
	var card = _card("♻️ پسماند و اقتصاد چرخه‌ای")
	_bar(card, "جمع‌آوری پسماند", float(wp.get("collection", 0.65)))
	_bar(card, "نرخ بازیافت", float(wp.get("recycling_rate", 0.15)))
	_bar(card, "دفن بهداشتی", float(wp.get("sanitary_landfill", 0.30)))
	_bar(card, "بازیابی انرژی", float(wp.get("wte", 0.05)))
	_bar(card, "اقتصاد چرخه‌ای", float(wp.get("circular", 0.15)))
	_bar(card, "رهاسازی غیرقانونی", float(wp.get("illegal_dumping", 0.35)))
	_row(card, "وابستگی به دفن", PersianFormatter.format_percent(float(wp.get("landfill_dependency", 0.75))))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["collection", "🚛 جمع‌آوری"], ["recycling", "♻️ بازیافت"], ["landfill", "🏞️ دفن بهداشتی"], ["circular", "🔄 چرخه‌ای"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_waste.bind(a[0]))
		_mark_decision_button(btn, "waste:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "کارخانه بازیافت هر ۶ نوبت. اقتصاد چرخه‌ای نیازمند صنعت ۶+ است؛ زباله رهاشده بیماری و آلودگی می‌سازد."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_waste(action: String):
	var cmd = GameCommandClass.create_waste_action(action)
	var labels := {"collection": "توسعه جمع‌آوری مکانیزه", "recycling": "احداث کارخانه بازیافت", "landfill": "دفن بهداشتی و زباله‌سوز", "circular": "برنامه اقتصاد چرخه‌ای"}
	if _queue_decision(cmd, "♻️ " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("economy")

func _build_insurance_card(st: Dictionary):
	var ip: Dictionary = st.get("insurance_policy", {})
	if ip.is_empty():
		return
	var card = _card("🛡️ صنعت بیمه و حفاظت مالی")
	_bar(card, "ضریب نفوذ بیمه", float(ip.get("penetration", 0.30)))
	_bar(card, "توانگری مالی", float(ip.get("solvency", 0.70)))
	_bar(card, "بیمه درمان تکمیلی", float(ip.get("health_insurance", 0.45)))
	_bar(card, "بیمه کشاورزی", float(ip.get("agri_insurance", 0.15)))
	_bar(card, "بیمه سپرده بانکی", float(ip.get("deposit_insurance", 0.40)))
	_bar(card, "نظارت و اتکایی", float(ip.get("regulation", 0.50)))
	_bar(card, "ریسک ورشکستگی", float(ip.get("default_risk", 0.15)))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["universal", "📋 فراگیر"], ["health", "🏥 درمان"], ["agri", "🌾 کشاورزی"], ["regulation", "⚖️ نظارت"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_insurance.bind(a[0]))
		_mark_decision_button(btn, "insurance:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "طرح فراگیر هر ۸ نوبت. بیمه قوی خسارت بحران را جذب می‌کند؛ نظارت ضعیف حباب و ورشکستگی می‌آورد."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_insurance(action: String):
	var cmd = GameCommandClass.create_insurance_action(action)
	var labels := {"universal": "طرح بیمه فراگیر", "health": "گسترش بیمه درمان", "agri": "بیمه کشاورزی", "regulation": "تقویت مقررات بیمه"}
	if _queue_decision(cmd, "🛡️ " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("population")

func _build_rural_card(st: Dictionary):
	var rp: Dictionary = st.get("rural_policy", {})
	if rp.is_empty():
		return
	var card = _card("🌾 توسعه روستایی و عشایری")
	_bar(card, "راه روستایی", float(rp.get("rural_roads", 0.40)))
	_bar(card, "اینترنت روستایی", float(rp.get("rural_internet", 0.25)))
	_bar(card, "صنایع تبدیلی", float(rp.get("agro_processing", 0.20)))
	_bar(card, "درآمد روستایی", float(rp.get("rural_income", 0.40)))
	_bar(card, "امنیت غذایی سرزمینی", float(rp.get("food_sovereignty", 0.50)))
	_bar(card, "مهاجرت بی‌رویه", float(rp.get("depopulation", 0.40)))
	_bar(card, "خدمات عشایری", float(rp.get("nomadic_services", 0.30)))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["roads", "🛣️ راه"], ["internet", "📡 اینترنت"], ["processing", "🏭 تبدیلی"], ["nomads", "🐑 عشایر"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_rural.bind(a[0]))
		_mark_decision_button(btn, "rural:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "راه روستایی هر ۵ نوبت. اینترنت به دیجیتال ۴ نیاز دارد. مهاجرت بی‌رویه حاشیه‌نشینی و فقر شهری را زیاد می‌کند."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_rural(action: String):
	var cmd = GameCommandClass.create_rural_action(action)
	var labels := {"roads": "توسعه راه روستایی", "internet": "اینترنت روستایی", "processing": "صنایع تبدیلی کشاورزی", "nomads": "خدمات عشایری و وام خرد"}
	if _queue_decision(cmd, "🌾 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("population")

func _build_judicial_reform_card(st: Dictionary):
	var jrp: Dictionary = st.get("judicial_reform_policy", {})
	if jrp.is_empty():
		return
	var card = _card("⚖️ اصلاحات قضایی و عدالت ترمیمی")
	_bar(card, "سرعت رسیدگی", float(jrp.get("case_resolution", 0.45)))
	_bar(card, "دادگاه الکترونیک", float(jrp.get("digital_courts", 0.20)))
	_bar(card, "دادگاه‌های تخصصی", float(jrp.get("specialized_courts", 0.20)))
	_bar(card, "میانجی‌گری", float(jrp.get("mediation", 0.20)))
	_bar(card, "معاضدت حقوقی", float(jrp.get("legal_aid", 0.25)))
	_row(card, "هزینه اطاله دادرسی", PersianFormatter.format_percent(float(jrp.get("cost_of_delay", 0.30))))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["digital", "💻 دیجیتال"], ["specialized", "🏛️ تخصصی"], ["mediation", "🤝 میانجی"], ["legalaid", "🧑‍⚖️ معاضدت"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_judicial_reform.bind(a[0]))
		_mark_decision_button(btn, "jr:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "دیجیتال‌سازی به فناوری دیجیتال ۴+ نیاز دارد. اطاله دادرسی هزینه اقتصادی و بی‌اعتمادی می‌سازد."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_judicial_reform(action: String):
	var cmd = GameCommandClass.create_judicial_reform_action(action)
	var labels := {"digital": "دیجیتالی کردن دادگاه‌ها", "specialized": "دادگاه‌های تخصصی", "mediation": "میانجی‌گری و عدالت ترمیمی", "legalaid": "معاضدت حقوقی"}
	if _queue_decision(cmd, "⚖️ " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("government")

func _build_election_card(st: Dictionary):
	var ep: Dictionary = st.get("election_policy", {})
	if ep.is_empty():
		return
	var card = _card("🗳️ انتخابات و رقابت سیاسی")
	_bar(card, "مشروعیت", float(ep.get("legitimacy", 0.60)))
	_bar(card, "مشارکت", float(ep.get("turnout", 0.60)))
	_bar(card, "انصاف انتخابات", float(ep.get("fairness", 0.55)))
	_bar(card, "دسترسی رأی‌دهندگان", float(ep.get("voter_access", 0.60)))
	_bar(card, "تکثر احزاب", float(ep.get("party_pluralism", 0.50)))
	_bar(card, "فشار مخالفان", float(ep.get("opposition_pressure", 0.30)))
	_row(card, "نوبت تا انتخابات", PersianFormatter.to_persian_digits(str(ep.get("next_election_turn", 48))))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["hold", "🗳️ برگزاری"], ["monitoring", "🔍 نظارت"], ["access", "🚻 دسترسی"], ["pluralism", "🏛️ تکثر"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_election.bind(a[0]))
		_mark_decision_button(btn, "election:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "برگزاری انتخابات تنها در زمان مقرر ممکن است. انتخابات منصفانه مشروعیت می‌سازد."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_election(action: String):
	var cmd = GameCommandClass.create_election_action(action)
	var labels := {"hold": "برگزاری انتخابات", "monitoring": "تقویت نظارت انتخابات", "access": "بهبود دسترسی به صندوق", "pluralism": "تکثر احزاب"}
	if _queue_decision(cmd, "🗳️ " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("government")

func _build_fuel_card(st: Dictionary):
	var fp: Dictionary = st.get("fuel_policy", {})
	if fp.is_empty():
		return
	var card = _card("⛽ سوخت و گذار انرژی حمل‌ونقل")
	_bar(card, "یارانه سوخت", float(fp.get("subsidy", 0.65)))
	_bar(card, "ایستگاه شارژ برقی", float(fp.get("ev_charging", 0.10)))
	_bar(card, "استاندارد آلایندگی", float(fp.get("emission_standard", 0.25)))
	_bar(card, "ناوگان عمومی برقی", float(fp.get("public_fleet", 0.20)))
	_bar(card, "قاچاق سوخت", float(fp.get("smuggling", 0.30)))
	_bar(card, "سهم خودروی برقی", float(fp.get("ev_share", 0.02)))
	_row(card, "تقاضای سوخت", PersianFormatter.format_percent(float(fp.get("fuel_demand", 0.70))))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["reform", "💰 اصلاح یارانه"], ["charging", "⚡ شارژ برقی"], ["emission", "🚗 استاندارد"], ["fleet", "🚍 ناوگان برقی"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_fuel.bind(a[0]))
		_mark_decision_button(btn, "fuel:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "اصلاح یارانه هر ۱۰ نوبت. ایستگاه شارژ به انرژی پاک ۴+ نیاز دارد."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_fuel(action: String):
	var cmd = GameCommandClass.create_fuel_action(action)
	var labels := {"reform": "اصلاح یارانه سوخت", "charging": "توسعه ایستگاه شارژ", "emission": "استاندارد آلایندگی", "fleet": "ناوگان عمومی برقی"}
	if _queue_decision(cmd, "⛽ " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("economy")

func _build_housing_card(st: Dictionary):
	var hp: Dictionary = st.get("housing_policy", {})
	if hp.is_empty():
		return
	var card = _card("🏠 بازار مسکن")
	_bar(card, "شاخص قیمت مسکن", float(hp.get("price_index", 0.50)))
	_bar(card, "حباب", float(hp.get("bubble", 0.25)))
	_bar(card, "بار اجاره", float(hp.get("rent_burden", 0.35)))
	_bar(card, "مسکن اجتماعی", float(hp.get("social_supply", 0.20)))
	_bar(card, "دسترسی وام", float(hp.get("mortgage_access", 0.35)))
	_bar(card, "نوسازی بافت فرسوده", float(hp.get("renewal", 0.15)))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["social", "🏘️ اجتماعی"], ["mortgage", "🏦 وام"], ["renewal", "🏚️ نوسازی"], ["regulate", "📊 تنظیم"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_housing.bind(a[0]))
		_mark_decision_button(btn, "housing:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "مسکن اجتماعی هر ۵ نوبت. وام آسان حباب می‌سازد."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_housing(action: String):
	var cmd = GameCommandClass.create_housing_action(action)
	var labels := {"social": "ساخت مسکن اجتماعی", "mortgage": "تسهیل وام مسکن", "renewal": "نوسازی بافت فرسوده", "regulate": "مالیات بر عایدی مسکن"}
	if _queue_decision(cmd, "🏠 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد")
		_switch_tab("population")

func _build_startup_card(st: Dictionary):
	var sp: Dictionary = st.get("startup_policy", {})
	if sp.is_empty():
		return
	var card = _card("🚀 کسب‌وکارهای نوپا")
	_bar(card, "نرخ نوآوری", float(sp.get("innovation_rate", 0.20)))
	_bar(card, "صندوق خطرپذیر", float(sp.get("vc_funding", 0.15)))
	_bar(card, "شتاب‌دهنده‌ها", float(sp.get("accelerators", 0.20)))
	_bar(card, "سندباکس مقرراتی", float(sp.get("regulatory_sandbox", 0.10)))
	_bar(card, "نرخ شکست", float(sp.get("failure_rate", 0.50)))
	_row(card, "شرکت‌های فعال", PersianFormatter.to_persian_digits(str(sp.get("startups", 0))))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["fund", "💰 صندوق"], ["accelerator", "🚀 شتاب‌دهنده"], ["sandbox", "📜 سندباکس"], ["braindrain", "🧠 بازگشت"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_startup.bind(a[0]))
		_mark_decision_button(btn, "startup:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "صندوق هر ۶ نوبت. سندباکس به دیجیتال ۴+ نیاز دارد."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_startup(action: String):
	var cmd = GameCommandClass.create_startup_action(action)
	var labels := {"fund": "صندوق خطرپذیر دولتی", "accelerator": "ایجاد شتاب‌دهنده", "sandbox": "سندباکس مقرراتی", "braindrain": "بازگشت نخبگان فناوری"}
	if _queue_decision(cmd, "🚀 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد")
		_switch_tab("technology")

func _build_sme_card(st: Dictionary):
	var sp: Dictionary = st.get("sme_policy", {})
	if sp.is_empty():
		return
	var card = _card("🏪 بنگاه‌های کوچک و متوسط")
	_bar(card, "سهولت کسب‌وکار", float(sp.get("ease_business", 0.35)))
	_bar(card, "وام خرد", float(sp.get("micro_credit", 0.30)))
	_bar(card, "زنجیره تأمین", float(sp.get("supply_chain", 0.25)))
	_bar(card, "رسمی‌سازی", float(sp.get("formalization", 0.30)))
	_bar(card, "شکاف اعتباری", float(sp.get("credit_gap", 0.45)))
	_bar(card, "بهره‌وری", float(sp.get("productivity", 0.35)))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["redtape", "📝 مقررات‌زدایی"], ["microcredit", "🏦 وام خرد"], ["supplychain", "🔗 زنجیره"], ["formalize", "🧾 رسمی‌سازی"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_sme.bind(a[0]))
		_mark_decision_button(btn, "sme:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "وام خرد هر ۵ نوبت. SMEها بزرگ‌ترین کارفرما هستند."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_sme(action: String):
	var cmd = GameCommandClass.create_sme_action(action)
	var labels := {"redtape": "مقررات‌زدایی کسب‌وکار", "microcredit": "صندوق وام خرد", "supplychain": "تأمین مالی زنجیره", "formalize": "تسهیل رسمی‌سازی"}
	if _queue_decision(cmd, "🏪 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد")
		_switch_tab("economy")

func _build_supply_card(st: Dictionary):
	var sp: Dictionary = st.get("supply_policy", {})
	if sp.is_empty():
		return
	var card = _card("🚢 زنجیره تأمین و تدارکات")
	_bar(card, "ذخایر راهبردی", float(sp.get("strategic_reserve", 0.35)))
	_bar(card, "تنوع تأمین‌کننده", float(sp.get("diversification", 0.40)))
	_bar(card, "ظرفیت داخلی", float(sp.get("domestic_capacity", 0.40)))
	_bar(card, "اختلال زنجیره", float(sp.get("disruption", 0.20)))
	_bar(card, "شاخص لجستیک", float(sp.get("logistics_index", 0.45)))
	_row(card, "موجودی (روز)", PersianFormatter.to_persian_digits("%.0f" % float(sp.get("inventory_days", 60.0))))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["reserve", "🏭 ذخیره"], ["diversify", "🌐 تنوع"], ["domestic", "🏗️ داخلی"], ["rotation", "🔄 گردش"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_supply.bind(a[0]))
		_mark_decision_button(btn, "supply:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "تقویت ذخایر هر ۵ نوبت. اختلال زنجیره تورم و کاهش تولید می‌آورد."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_supply(action: String):
	var cmd = GameCommandClass.create_supply_action(action)
	var labels := {"reserve": "تقویت ذخایر راهبردی", "diversify": "تنوع تأمین‌کنندگان", "domestic": "تولید داخلی کلیدی", "rotation": "گردش موجودی"}
	if _queue_decision(cmd, "🚢 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد")
		_switch_tab("economy")

func _build_care_card(st: Dictionary):
	var cp: Dictionary = st.get("care_policy", {})
	if cp.is_empty():
		return
	var card = _card("💗 اقتصاد مراقبت")
	_bar(card, "بار مراقبت", float(cp.get("care_burden", 0.55)))
	_bar(card, "سالمند care", float(cp.get("eldercare", 0.25)))
	_bar(card, "مهدکودک", float(cp.get("childcare", 0.25)))
	_bar(card, "مراقبت در منزل", float(cp.get("home_care", 0.20)))
	_bar(card, "مشارکت زنان", float(cp.get("female_lfp", 0.35)))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["eldercare", "🏥 سالمندان"], ["childcare", "🧸 مهدکودک"], ["homecare", "🏠 منزل"], ["leave", "🤱 مرخصی"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_care.bind(a[0]))
		_mark_decision_button(btn, "care:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "خدمات مراقبت رسمی بار زنان را کم و مشارکت نیروی کار را بالا می‌برد."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_care(action: String):
	var cmd = GameCommandClass.create_care_action(action)
	var labels := {"eldercare": "مراکز سالمندان", "childcare": "توسعه مهدکودک", "homecare": "مراقبت در منزل", "leave": "مرخصی زایمان"}
	if _queue_decision(cmd, "💗 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد")
		_switch_tab("population")

func _build_science_card(st: Dictionary):
	var sp: Dictionary = st.get("science_policy", {})
	if sp.is_empty():
		return
	var card = _card("🔬 دیپلماسی علمی")
	_bar(card, "جریان دانش", float(sp.get("knowledge_flow", 0.20)))
	_bar(card, "آزمایشگاه مشترک", float(sp.get("joint_labs", 0.15)))
	_bar(card, "بورس بین‌المللی", float(sp.get("scholarships", 0.25)))
	_bar(card, "کنسرسیوم فناوری", float(sp.get("tech_consortium", 0.10)))
	_bar(card, "جذب نخبگان", float(sp.get("brain_gain", 0.15)))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["agreement", "📜 توافق"], ["lab", "🔬 آزمایشگاه"], ["scholarship", "🎓 بورس"], ["consortium", "🌐 کنسرسیوم"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_science.bind(a[0]))
		_mark_decision_button(btn, "science:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "توافق علمی هر ۶ نوبت. آزمایشگاه مشترک به دیجیتال ۴+ نیاز دارد."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_science(action: String):
	var cmd = GameCommandClass.create_science_action(action)
	var labels := {"agreement": "توافق علمی دوجانبه", "lab": "آزمایشگاه مشترک", "scholarship": "برنامه بورس", "consortium": "کنسرسیوم فناوری"}
	if _queue_decision(cmd, "🔬 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد")
		_switch_tab("technology")

func _build_downstream_card(st: Dictionary):
	var dp: Dictionary = st.get("downstream_policy", {})
	if dp.is_empty():
		return
	var card = _card("🧪 پتروشیمی و پالایش")
	_bar(card, "ظرفیت پالایش", float(dp.get("refining_capacity", 0.40)))
	_bar(card, "پتروشیمی", float(dp.get("petrochemical", 0.30)))
	_bar(card, "خودکفایی سوخت", float(dp.get("fuel_security", 0.45)))
	_bar(card, "ارزش‌افزوده", float(dp.get("value_added", 0.25)))
	_bar(card, "امنیت سوخت", float(dp.get("fuel_security", 0.45)))
	_row(card, "سهم خام‌فروشی", PersianFormatter.format_percent(float(dp.get("raw_export_share", 0.65))))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["refining", "🏗️ پالایش"], ["petrochem", "🧪 پتروشیمی"], ["selfsuff", "⛽ خودکفایی"], ["valuechain", "⬆️ ارزش‌افزوده"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_downstream.bind(a[0]))
		_mark_decision_button(btn, "downstream:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "پالایش هر ۶ نوبت؛ نیازمند صنعت ۴+. پتروشیمی خام‌فروشی را کم می‌کند."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_downstream(action: String):
	var cmd = GameCommandClass.create_downstream_action(action)
	var labels := {"refining": "توسعه پالایشگاه", "petrochem": "توسعه پتروشیمی", "selfsuff": "خودکفایی سوخت", "valuechain": "ارتقای زنجیره ارزش"}
	if _queue_decision(cmd, "🧪 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد")
		_switch_tab("economy")

func _build_higher_ed_card(st: Dictionary):
	var hp: Dictionary = st.get("higher_ed_policy", {})
	if hp.is_empty():
		return
	var card = _card("🎓 آموزش عالی و دانشگاه")
	_bar(card, "کیفیت دانشگاه", float(hp.get("quality", 0.35)))
	_bar(card, "تحقیقات دانشگاهی", float(hp.get("research", 0.25)))
	_bar(card, "هیئت علمی", float(hp.get("faculty", 0.30)))
	_bar(card, "بین‌المللی", float(hp.get("international", 0.15)))
	_bar(card, "رتبه جهانی", float(hp.get("ranking", 0.20)))
	_row(card, "فارغ‌التحصیلان", PersianFormatter.to_persian_digits(str(hp.get("graduates", 0))))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["funding", "💰 بودجه"], ["research", "🔬 گرنت"], ["faculty", "👨‍🏫 اساتید"], ["international", "🌐 تبادل"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_higher_ed.bind(a[0]))
		_mark_decision_button(btn, "highered:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "افزایش بودجه هر ۵ نوبت. دانشگاه قوی بهره‌وری و نوآوری را بالا می‌برد."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_higher_ed(action: String):
	var cmd = GameCommandClass.create_higher_ed_action(action)
	var labels := {"funding": "افزایش بودجه دانشگاه", "research": "گرنت پژوهشی", "faculty": "جذب هیئت علمی", "international": "بین‌المللی‌سازی"}
	if _queue_decision(cmd, "🎓 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد")
		_switch_tab("technology")

func _build_food_chain_card(st: Dictionary):
	var fp: Dictionary = st.get("food_chain_policy", {})
	if fp.is_empty():
		return
	var card = _card("🌾 زنجیره ارزش غذا")
	_bar(card, "امنیت غذایی", float(fp.get("food_security", 0.55)))
	_bar(card, "سردخانه", float(fp.get("storage", 0.25)))
	_bar(card, "صنایع تبدیلی", float(fp.get("processing", 0.20)))
	_bar(card, "لجستیک", float(fp.get("logistics", 0.30)))
	_bar(card, "ایمنی غذا", float(fp.get("safety", 0.40)))
	_bar(card, "ضایعات غذا", float(fp.get("waste", 0.35)))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["storage", "🧊 سردخانه"], ["processing", "🏭 تبدیلی"], ["logistics", "🚚 لجستیک"], ["safety", "🔍 ایمنی"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_food_chain.bind(a[0]))
		_mark_decision_button(btn, "foodchain:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "سردخانه هر ۵ نوبت. کاهش ضایعات غذا تورم خوراک را کم می‌کند."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_food_chain(action: String):
	var cmd = GameCommandClass.create_food_chain_action(action)
	var labels := {"storage": "ساخت سردخانه", "processing": "صنایع تبدیلی", "logistics": "لجستیک غذا", "safety": "نظارت ایمنی غذا"}
	if _queue_decision(cmd, "🌾 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد")
		_switch_tab("economy")

func _build_pharma_card(st: Dictionary):
	var pp: Dictionary = st.get("pharma_policy", {})
	if pp.is_empty():
		return
	var card = _card("💊 دارو و صنعت سلامت")
	_bar(card, "امنیت دارو", float(pp.get("drug_security", 0.40)))
	_bar(card, "تولید داخلی", float(pp.get("local_production", 0.35)))
	_bar(card, "داروی ژنریک", float(pp.get("generic", 0.40)))
	_bar(card, "ذخیره دارو", float(pp.get("stockpile", 0.30)))
	_bar(card, "واکسن", float(pp.get("vaccine", 0.20)))
	_row(card, "وابستگی واردات", PersianFormatter.format_percent(float(pp.get("import_dep", 0.65))))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["plant", "🏭 کارخانه"], ["generic", "💊 ژنریک"], ["stockpile", "📦 ذخیره"], ["vaccine", "💉 واکسن"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_pharma.bind(a[0]))
		_mark_decision_button(btn, "pharma:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "کارخانه هر ۶ نوبت؛ نیازمند فناوری ۴+. تولید داخلی وابستگی و قیمت دارو را کم می‌کند."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_pharma(action: String):
	var cmd = GameCommandClass.create_pharma_action(action)
	var labels := {"plant": "احداث کارخانه دارو", "generic": "توسعه داروی ژنریک", "stockpile": "ذخیره راهبردی دارو", "vaccine": "برنامه واکسن"}
	if _queue_decision(cmd, "💊 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد")
		_switch_tab("population")

func _build_ip_card(st: Dictionary):
	var ip: Dictionary = st.get("ip_policy", {})
	if ip.is_empty():
		return
	var card = _card("©️ مالکیت فکری")
	_bar(card, "شاخص نوآوری", float(ip.get("innovation_index", 0.25)))
	_bar(card, "ثبت اختراع", float(ip.get("patents", 0.25)))
	_bar(card, "کپی‌رایت", float(ip.get("copyright", 0.30)))
	_bar(card, "انتقال فناوری", float(ip.get("tech_transfer", 0.20)))
	_bar(card, "اجرای قانون", float(ip.get("enforcement", 0.30)))
	_row(card, "اختراعات ثبت‌شده", PersianFormatter.to_persian_digits(str(ip.get("patent_count", 0))))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["patent", "📜 ثبت اختراع"], ["copyright", "©️ کپی‌رایت"], ["transfer", "🤝 انتقال"], ["park", "🔬 پارک علم"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_ip.bind(a[0]))
		_mark_decision_button(btn, "ip:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "اصلاح ثبت اختراع هر ۵ نوبت. IP قوی سرمایه‌گذاری و تجاری‌سازی دانش را جذب می‌کند."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_ip(action: String):
	var cmd = GameCommandClass.create_ip_action(action)
	var labels := {"patent": "اصلاح نظام ثبت اختراع", "copyright": "تقویت کپی‌رایت", "transfer": "دفتر انتقال فناوری", "park": "پارک علم و فناوری"}
	if _queue_decision(cmd, "©️ " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد")
		_switch_tab("technology")

func _build_transit_card(st: Dictionary):
	var tp: Dictionary = st.get("transit_policy", {})
	if tp.is_empty():
		return
	var card = _card("🚛 لجستیک و ترانزیت")
	_bar(card, "کریدورهای ترانزیتی", float(tp.get("corridors", 0.25)))
	_bar(card, "گمرک هوشمند", float(tp.get("customs", 0.30)))
	_bar(card, "ریلی باری", float(tp.get("rail", 0.25)))
	_bar(card, "مناطق آزاد", float(tp.get("free_zones", 0.20)))
	_bar(card, "بار ترانزیتی", float(tp.get("freight", 0.30)))
	_row(card, "تأخیر مرزی", PersianFormatter.format_percent(float(tp.get("border_delay", 0.50))))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["corridor", "🛣️ کریدور"], ["customs", "🛃 گمرک"], ["rail", "🚂 ریل"], ["freezone", "🏭 منطقه آزاد"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_transit.bind(a[0]))
		_mark_decision_button(btn, "transit:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "کریدور هر ۶ نوبت. گمرک هوشمند به دیجیتال ۴+ نیاز دارد. ترانزیت درآمد ارزی پایدار می‌سازد."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_transit(action: String):
	var cmd = GameCommandClass.create_transit_action(action)
	var labels := {"corridor": "توسعه کریدور ترانزیتی", "customs": "اصلاح گمرک", "rail": "توسعه ریلی باری", "freezone": "گسترش منطقه آزاد"}
	if _queue_decision(cmd, "🚛 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد")
		_switch_tab("economy")

func _build_disaster_card(st: Dictionary):
	var dp: Dictionary = st.get("disaster_policy", {})
	if dp.is_empty():
		return
	var card = _card("🚨 مدیریت بحران")
	_bar(card, "آمادگی", float(dp.get("preparedness", 0.30)))
	_bar(card, "هشدار زودهنگام", float(dp.get("early_warning", 0.30)))
	_bar(card, "پناهگاه", float(dp.get("shelter", 0.25)))
	_bar(card, "واکنش سریع", float(dp.get("response", 0.35)))
	_bar(card, "ذخیره امدادی", float(dp.get("relief_stock", 0.30)))
	_bar(card, "ریسک حادثه", float(dp.get("risk", 0.45)))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["warning", "📡 هشدار"], ["shelter", "🏠 پناهگاه"], ["response", "🚑 واکنش"], ["relief", "📦 امداد"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_disaster.bind(a[0]))
		_mark_decision_button(btn, "disaster:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "مانور سراسری هر ۴ نوبت. آمادگی بالا خسارت حادثه را کم می‌کند."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_disaster(action: String):
	var cmd = GameCommandClass.create_disaster_action(action)
	var labels := {"warning": "سامانه هشدار زودهنگام", "shelter": "پناهگاه اضطراری", "response": "مانور واکنش سریع", "relief": "ذخیره امدادی"}
	if _queue_decision(cmd, "🚨 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد")
		_switch_tab("government")

func _build_livestock_card(st: Dictionary):
	var lp: Dictionary = st.get("livestock_policy", {})
	if lp.is_empty():
		return
	var card = _card("🐄 دامپروری و پروتئین")
	_bar(card, "امنیت پروتئین", float(lp.get("protein_security", 0.55)))
	_bar(card, "گله دام", float(lp.get("herd_size", 0.50)))
	_bar(card, "تولید شیر", float(lp.get("milk_production", 0.45)))
	_bar(card, "تولید گوشت", float(lp.get("meat_production", 0.40)))
	_bar(card, "واکسیناسیون", float(lp.get("vaccination", 0.45)))
	_bar(card, "خودکفایی", float(lp.get("self_suff", 0.65)))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["industrial", "🏭 صنعتی"], ["vaccine", "💉 واکسن"], ["feed", "🌾 علوفه"], ["breeding", "🐂 اصلاح نژاد"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_livestock.bind(a[0]))
		_mark_decision_button(btn, "livestock:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "دامداری صنعتی هر ۵ نوبت. خشکسالی و ریزگرد به دام لطمه می‌زند."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_livestock(action: String):
	var cmd = GameCommandClass.create_livestock_action(action)
	var labels := {"industrial": "دامداری صنعتی", "vaccine": "واکسیناسیون دام", "feed": "بهبود علوفه", "breeding": "اصلاح نژاد"}
	if _queue_decision(cmd, "🐄 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد")
		_switch_tab("economy")

func _build_textile_card(st: Dictionary):
	var tp: Dictionary = st.get("textile_policy", {})
	if tp.is_empty():
		return
	var card = _card("🧵 نساجی و پوشاک")
	_bar(card, "تولید", float(tp.get("output", 0.35)))
	_bar(card, "ریسندگی", float(tp.get("spinning", 0.30)))
	_bar(card, "پوشاک", float(tp.get("apparel", 0.40)))
	_bar(card, "برندسازی", float(tp.get("branding", 0.20)))
	_bar(card, "ارزش افزوده", float(tp.get("value_added", 0.30)))
	_row(card, "اشتغال", PersianFormatter.to_persian_digits(str(tp.get("employment", 0))))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["mills", "🏭 کارخانه"], ["cotton", "🌾 پنبه"], ["apparel", "👕 پوشاک"], ["branding", "🏷️ برند"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_textile.bind(a[0]))
		_mark_decision_button(btn, "textile:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "کارخانه هر ۵ نوبت. برندسازی به دیجیتال ۳+ نیاز دارد. نساجی اشتغال انبوه می‌سازد."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_textile(action: String):
	var cmd = GameCommandClass.create_textile_action(action)
	var labels := {"mills": "توسعه کارخانه نساجی", "cotton": "تامین پنبه", "apparel": "شهرک پوشاک", "branding": "برندسازی پوشاک"}
	if _queue_decision(cmd, "🧵 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد")
		_switch_tab("economy")

func _build_basic_industry_card(st: Dictionary):
	var bp: Dictionary = st.get("basic_industry_policy", {})
	if bp.is_empty():
		return
	var card = _card("🔩 صنایع بنیادی")
	_bar(card, "تولید", float(bp.get("output", 0.35)))
	_bar(card, "فولاد", float(bp.get("steel", 0.35)))
	_bar(card, "سیمان", float(bp.get("cement", 0.40)))
	_bar(card, "یکپارچگی زنجیره", float(bp.get("integration", 0.25)))
	_bar(card, "خودکفایی مصالح", float(bp.get("self_sufficiency", 0.60)))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["steel", "🔩 فولاد"], ["cement", "🏭 سیمان"], ["integration", "🔗 یکپارچه"], ["efficiency", "⚡ بهره‌وری"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_basic_industry.bind(a[0]))
		_mark_decision_button(btn, "basicind:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "فولاد هر ۶ نوبت؛ نیازمند صنعت ۴+. صنایع بنیادی ستون ساخت‌وساز هستند."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_basic_industry(action: String):
	var cmd = GameCommandClass.create_basic_industry_action(action)
	var labels := {"steel": "توسعه فولاد", "cement": "توسعه سیمان", "integration": "یکپارچه‌سازی زنجیره", "efficiency": "بهبود بهره‌وری"}
	if _queue_decision(cmd, "🔩 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد")
		_switch_tab("economy")

func _build_nation_brand_card(st: Dictionary):
	var nb: Dictionary = st.get("nation_brand_policy", {})
	if nb.is_empty():
		return
	var card = _card("🌟 برند ملی")
	_bar(card, "شاخص برند", float(nb.get("brand_index", 0.35)))
	_bar(card, "رویدادهای بین‌المللی", float(nb.get("events", 0.20)))
	_bar(card, "میراث فرهنگی", float(nb.get("heritage", 0.40)))
	_bar(card, "صادرات فرهنگی", float(nb.get("cultural_exports", 0.20)))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["branding", "📢 کمپین"], ["event", "🏟️ رویداد"], ["heritage", "🏛️ میراث"], ["exports", "🎬 صادرات فرهنگی"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_nation_brand.bind(a[0]))
		_mark_decision_button(btn, "nationbrand:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "کمپین برند هر ۵ نوبت. برند قوی گردشگر و سرمایه می‌آورد."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_nation_brand(action: String):
	var cmd = GameCommandClass.create_nation_brand_action(action)
	var labels := {"branding": "کمپین برند ملی", "event": "میزبانی رویداد", "heritage": "معرفی میراث", "exports": "صادرات فرهنگی"}
	if _queue_decision(cmd, "🌟 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد")
		_switch_tab("economy")

func _build_ai_card(st: Dictionary):
	var ap: Dictionary = st.get("ai_policy", {})
	if ap.is_empty():
		return
	var card = _card("🤖 هوش مصنوعی و اتوماسیون")
	_bar(card, "پذیرش AI", float(ap.get("adoption", 0.10)))
	_bar(card, "رباتیک صنعتی", float(ap.get("robotics", 0.10)))
	_bar(card, "بهره‌وری", float(ap.get("productivity", 0.15)))
	_bar(card, "جابه‌جایی شغلی", float(ap.get("job_displacement", 0.0)))
	_bar(card, "مهارت‌آموزی", float(ap.get("reskilling", 0.20)))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["adopt", "🤖 پذیرش"], ["robotics", "🦾 رباتیک"], ["reskill", "🎓 مهارت‌آموزی"], ["datainfra", "🛰️ داده"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_ai.bind(a[0]))
		_mark_decision_button(btn, "ai:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "پذیرش AI نیازمند دیجیتال ۶+ است. بدون مهارت‌آموزی، بیکاری بالا می‌رود."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_ai(action: String):
	var cmd = GameCommandClass.create_ai_action(action)
	var labels := {"adopt": "پذیرش هوش مصنوعی", "robotics": "رباتیک صنعتی", "reskill": "مهارت‌آموزی دیجیتال", "datainfra": "زیرساخت داده"}
	if _queue_decision(cmd, "🤖 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد")
		_switch_tab("technology")

func _build_tax_card(st: Dictionary):
	var tp: Dictionary = TaxManager.get_policy(st)
	var card = _card("💰 نظام مالیاتی")
	_bar(card, "پایبندی مالیاتی", float(tp.get("compliance", 0.65)))
	_row(card, "درآمد مالیاتی ماهانه", PersianFormatter.format_money(float(st.get("budget", {}).get("tax_revenue", 0.0))))
	_bar(card, "صورتحساب دیجیتال", float(tp.get("digital", 0.20)))
	for row in [["income","مالیات بر درآمد"],["corporate","مالیات شرکت"],["vat","مالیات بر ارزش افزوده"],["wealth","مالیات بر ثروت"]]:
		var r = HBoxContainer.new(); r.add_theme_constant_override("separation", 4); card.add_child(r)
		var lbl = Label.new(); lbl.text = row[1]; lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lbl.add_theme_font_size_override("font_size",13); r.add_child(lbl)
		var val = Label.new(); val.text = "%.0f%%" % (float(tp.get("rates",{}).get(row[0],0))*100.0); val.custom_minimum_size = Vector2(50,0); val.add_theme_font_size_override("font_size",13); r.add_child(val)
		var up = Button.new(); up.text = "＋"; up.custom_minimum_size = Vector2(34,30); up.add_theme_font_size_override("font_size",14)
		up.pressed.connect(FeedbackManager.play_click); up.pressed.connect(_on_tax_adjust.bind(row[0], 0.02)); r.add_child(up)
		var down = Button.new(); down.text = "－"; down.custom_minimum_size = Vector2(34,30); down.add_theme_font_size_override("font_size",14)
		down.pressed.connect(FeedbackManager.play_click); down.pressed.connect(_on_tax_adjust.bind(row[0], -0.02)); r.add_child(down)
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	_mark_decision_button(_mk_btn(row, "🧾 صورتحساب دیجیتال", Vector2(0,34), _on_tax_action.bind("digital")), "tax:digital")
	_mark_decision_button(_mk_btn(row, "🔍 بهبود پایبندی", Vector2(0,34), _on_tax_action.bind("compliance")), "tax:compliance")
	_mark_decision_button(_mk_btn(row, "📊 پلکان مالیاتی", Vector2(0,34), _on_tax_action.bind("bracket")), "tax:bracket")
	var hint = Label.new(); hint.text = "افزایش زیاد نرخ، فرار مالیاتی و کاهش فعالیت را در پی دارد."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; hint.add_theme_font_size_override("font_size",14); hint.modulate = TEXT_FAINT; card.add_child(hint)

func _on_tax_adjust(tax_type: String, delta: float):
	var st = GameState.state
	var cur = float(TaxManager.get_policy(st)["rates"].get(tax_type, 0.0))
	var target = clampf(cur + delta, 0.0, 0.45)
	var cmd = GameCommandClass.create_tax_action(tax_type, target)
	if _queue_decision(cmd, "💰 تنظیم %s به %.0f%%" % [tax_type, target*100.0]):
		_toast("نرخ ثبت شد — با پایان نوبت اعمال می‌شود")
		_refresh_once_buttons()

func _on_tax_action(action: String):
	var cmd = GameCommandClass.create_tax_action(action, 0.0)
	var labels := {"digital":"استقرار صورتحساب دیجیتال","compliance":"بهبود پایبندی مالیاتی","bracket":"افزودن پلکان مالیاتی"}
	if _queue_decision(cmd, "💰 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد")
		_switch_tab("economy")

func _build_ev_card(st: Dictionary):
	var ep: Dictionary = EvIndustryManager.get_policy(st)
	var card = _card("🔋 خودرو برقی و باطری")
	_bar(card, "ظرفیت باطری", float(ep.get("battery_capacity",0.15)))
	_bar(card, "تحقیق باطری", float(ep.get("battery_research",0.10)))
	_bar(card, "تولید خودرو", float(ep.get("ev_production",0.05)))
	_bar(card, "ایستگاه شارژ", float(ep.get("charging",0.05)))
	_bar(card, "سهم خودروی برقی", float(ep.get("ev_share",0.02)))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["battery","🔋 باطری"],["research","🔬 تحقیق"],["production","🚗 تولید"],["charging","⚡ شارژ"],["recycling","♻️ بازیافت"]]:
		var b = Button.new(); b.text = a[1]; b.add_theme_font_size_override("font_size",11); b.custom_minimum_size = Vector2(0,34)
		b.pressed.connect(FeedbackManager.play_click); b.pressed.connect(_on_ev.bind(a[0])); _mark_decision_button(b, "ev:"+a[0]); row.add_child(b)

func _on_ev(action: String):
	var cmd = GameCommandClass.create_ev_action(action)
	var labels := {"battery":"ساخت کارخانه باطری","research":"تحقیق باطری","production":"تولید خودرو برقی","charging":"شبکه شارژ","recycling":"بازیافت باطری"}
	if _queue_decision(cmd, "🔋 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد")
		_switch_tab("economy")

func _build_health_tourism_card(st: Dictionary):
	var hp: Dictionary = HealthTourismManager.get_policy(st)
	var card = _card("🏥 گردشگری سلامت")
	_bar(card, "بیمارستان بین‌المللی", float(hp.get("hospitals",0.20)))
	_bar(card, "کیفیت درمان", float(hp.get("quality",0.30)))
	_bar(card, "آب‌درمانی", float(hp.get("wellness",0.15)))
	_bar(card, "اعتباربخشی", float(hp.get("accreditation",0.15)))
	_bar(card, "تسهیل ویزا", float(hp.get("visa",0.20)))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["hospital","🏥 بیمارستان"],["quality","🥇 کیفیت"],["wellness","💆 آب‌درمانی"],["visa","🛂 ویزا"],["accreditation","🏅 اعتباربخشی"],["marketing","📢 بازاریابی"]]:
		var b = Button.new(); b.text = a[1]; b.add_theme_font_size_override("font_size",11); b.custom_minimum_size = Vector2(0,34)
		b.pressed.connect(FeedbackManager.play_click); b.pressed.connect(_on_health_tourism.bind(a[0])); _mark_decision_button(b, "ht:"+a[0]); row.add_child(b)

func _on_health_tourism(action: String):
	var cmd = GameCommandClass.create_health_tourism_action(action)
	var labels := {"hospital":"ساخت بیمارستان بین‌المللی","quality":"ارتقای کیفیت درمان","wellness":"توسعه آب‌درمانی","visa":"تسهیل ویزای درمانی","accreditation":"اعتباربخشی بین‌المللی","marketing":"کمپین گردشگری سلامت"}
	if _queue_decision(cmd, "🏥 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد")
		_switch_tab("society")

func _build_defense_industry_card(st: Dictionary):
	var dp: Dictionary = DefenseIndustryManager.get_policy(st)
	var card = _card("🏭 صنعت دفاعی بومی")
	_bar(card, "تولید", float(dp.get("production",0.15)))
	_bar(card, "تحقیق دفاعی", float(dp.get("r_and_d",0.10)))
	_bar(card, "خودکفایی", float(dp.get("self_suff",0.20)))
	_bar(card, "نگهداری", float(dp.get("maintenance",0.30)))
	_bar(card, "آموزش نیرو", float(dp.get("training",0.20)))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["production","🏭 تولید"],["rnd","🔬 تحقیق"],["maintenance","🔧 نگهداری"],["training","🎓 آموزش"],["exports","📦 صادرات"]]:
		var b = Button.new(); b.text = a[1]; b.add_theme_font_size_override("font_size",11); b.custom_minimum_size = Vector2(0,34)
		b.pressed.connect(FeedbackManager.play_click); b.pressed.connect(_on_defense_industry.bind(a[0])); _mark_decision_button(b, "di:"+a[0]); row.add_child(b)

func _on_defense_industry(action: String):
	var cmd = GameCommandClass.create_defense_industry_action(action)
	var labels := {"production":"گسترش تولید دفاعی","rnd":"تحقیق دفاعی","maintenance":"بهبود نگهداری","training":"آموزش پرسنل","exports":"اجازه صادرات دفاعی"}
	if _queue_decision(cmd, "🏭 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد")
		_switch_tab("military")

func _build_knowledge_economy_card(st: Dictionary):
	var kp: Dictionary = KnowledgeEconomyManager.get_policy(st)
	var card = _card("💡 اقتصاد دانش‌بنیان")
	_bar(card, "پارک فناوری", float(kp.get("tech_parks",0.10)))
	_bar(card, "مراکز رشد", float(kp.get("incubators",0.15)))
	_bar(card, "دانش‌بنیان‌ها", float(kp.get("startups",0.10)))
	_bar(card, "تجاری‌سازی", float(kp.get("commercialization",0.15)))
	_bar(card, "سرمایه خطرپذیر", float(kp.get("venture_capital",0.05)))
	var lbl = Label.new(); lbl.text = "شرکت‌های دانش‌بنیان: " + str(kp.get("businesses",0)); lbl.add_theme_font_size_override("font_size",14); lbl.modulate = ACCENT_GOLD; card.add_child(lbl)
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["park","🏛️ پارک"],["incubator","🌱 مرکز رشد"],["startup","🚀 دانش‌بنیان"],["commercialize","🔬 تجاری‌سازی"],["vc","💵 سرمایه"]]:
		var b = Button.new(); b.text = a[1]; b.add_theme_font_size_override("font_size",11); b.custom_minimum_size = Vector2(0,34)
		b.pressed.connect(FeedbackManager.play_click); b.pressed.connect(_on_knowledge_economy.bind(a[0])); _mark_decision_button(b, "ke:"+a[0]); row.add_child(b)

func _on_knowledge_economy(action: String):
	var cmd = GameCommandClass.create_knowledge_economy_action(action)
	var labels := {"park":"ساخت پارک فناوری","incubator":"توسعه مرکز رشد","startup":"حمایت از دانش‌بنیان‌ها","commercialize":"تجاری‌سازی پژوهش","vc":"جذب سرمایه خطرپذیر"}
	if _queue_decision(cmd, "💡 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد")
		_switch_tab("technology")

func _build_waste_management_card(st: Dictionary):
	var wp: Dictionary = WasteManagementManager.get_policy(st)
	var card = _card("♻️ مدیریت پسماند")
	_bar(card, "جمع‌آوری", float(wp.get("collection",0.40)))
	_bar(card, "تفکیک از مبدأ", float(wp.get("separation",0.15)))
	_bar(card, "بازیافت", float(wp.get("recycling",0.20)))
	_bar(card, "انرژی از زباله", float(wp.get("waste_to_energy",0.05)))
	_bar(card, "نرخ بازیافت", float(wp.get("recycling_rate",0.0)))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["collection","🚛 جمع‌آوری"],["separation","♻️ تفکیک"],["recycling","🔄 بازیافت"],["wte","⚡ انرژی"],["landfill","🗑️ کاهش دفن"]]:
		var b = Button.new(); b.text = a[1]; b.add_theme_font_size_override("font_size",11); b.custom_minimum_size = Vector2(0,34)
		b.pressed.connect(FeedbackManager.play_click); b.pressed.connect(_on_waste_management.bind(a[0])); _mark_decision_button(b, "waste_mgmt:"+a[0]); row.add_child(b)

func _on_waste_management(action: String):
	var cmd = GameCommandClass.create_waste_management_action(action)
	var labels := {"collection":"گسترش جمع‌آوری","separation":"تفکیک از مبدأ","recycling":"ساخت مرکز بازیافت","wte":"نیروگاه زباله‌سوز","landfill":"کاهش دفن زباله"}
	if _queue_decision(cmd, "♻️ " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد")
		_switch_tab("society")

func _build_aerospace_card(st: Dictionary):
	var ap: Dictionary = AerospaceManager.get_policy(st)
	var card = _card("🛰️ هوافضا و ماهواره")
	_bar(card, "توان پرتاب", float(ap.get("launch",0.05)))
	_bar(card, "ساخت ماهواره", float(ap.get("manufacturing",0.10)))
	_bar(card, "سنجش از دور", float(ap.get("remote_sensing",0.05)))
	_bar(card, "مخابرات فضایی", float(ap.get("telecom",0.05)))
	var lbl = Label.new(); lbl.text = "ماهواره‌ها در مدار: " + str(ap.get("satellites",0)); lbl.add_theme_font_size_override("font_size",14); lbl.modulate = ACCENT_GOLD; card.add_child(lbl)
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["launch","🚀 پرتاب"],["factory","🛰️ ساخت"],["sensing","📡 سنجش"],["telecom","📶 مخابرات"],["rnd","🔬 تحقیق"]]:
		var b = Button.new(); b.text = a[1]; b.add_theme_font_size_override("font_size",11); b.custom_minimum_size = Vector2(0,34)
		b.pressed.connect(FeedbackManager.play_click); b.pressed.connect(_on_aerospace.bind(a[0])); _mark_decision_button(b, "as:"+a[0]); row.add_child(b)

func _on_aerospace(action: String):
	var cmd = GameCommandClass.create_aerospace_action(action)
	var labels := {"launch":"گسترش توان پرتاب","factory":"ساخت کارخانه ماهواره","sensing":"سنجش از دور","telecom":"مخابرات فضایی","rnd":"تحقیق هوافضا"}
	if _queue_decision(cmd, "🛰️ " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد")
		_switch_tab("technology")

func _build_petrochemical_card(st: Dictionary):
	var pp: Dictionary = PetrochemicalManager.get_policy(st)
	var card = _card("🧪 پتروشیمی")
	_bar(card, "تأمین خوراک", float(pp.get("feedstock",0.40)))
	_bar(card, "مجتمع‌ها", float(pp.get("plants",0.20)))
	_bar(card, "پایین‌دست", float(pp.get("downstream",0.15)))
	_bar(card, "صادرات", float(pp.get("exports",0.10)))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["feedstock","🛢️ خوراک"],["plants","🏭 مجتمع"],["downstream","🔗 پایین‌دست"],["catalyst","⚗️ کاتالیست"],["exports","📦 صادرات"]]:
		var b = Button.new(); b.text = a[1]; b.add_theme_font_size_override("font_size",11); b.custom_minimum_size = Vector2(0,34)
		b.pressed.connect(FeedbackManager.play_click); b.pressed.connect(_on_petrochemical.bind(a[0])); _mark_decision_button(b, "petro:"+a[0]); row.add_child(b)

func _on_petrochemical(action: String):
	var cmd = GameCommandClass.create_petrochemical_action(action)
	var labels := {"feedstock":"تأمین خوراک پتروشیمی","plants":"احداث مجتمع پتروشیمی","downstream":"توسعه پایین‌دست","catalyst":"تحقیق کاتالیست","exports":"افزایش صادرات"}
	if _queue_decision(cmd, "🧪 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد")
		_switch_tab("economy")

func _build_pro_sports_card(st: Dictionary):
	var sp: Dictionary = ProSportsManager.get_policy(st)
	var card = _card("⚽ اقتصاد ورزش حرفه‌ای")
	_bar(card, "لیگ‌های حرفه‌ای", float(sp.get("leagues",0.20)))
	_bar(card, "زیرساخت", float(sp.get("infrastructure",0.20)))
	_bar(card, "رویدادها", float(sp.get("events",0.10)))
	_bar(card, "آکادمی جوانان", float(sp.get("academy",0.20)))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["leagues","🏆 لیگ"],["infrastructure","🏟️ زیرساخت"],["events","🎟️ رویداد"],["academy","🎓 آکادمی"],["exports","📤 صادرات"]]:
		var b = Button.new(); b.text = a[1]; b.add_theme_font_size_override("font_size",11); b.custom_minimum_size = Vector2(0,34)
		b.pressed.connect(FeedbackManager.play_click); b.pressed.connect(_on_pro_sports.bind(a[0])); _mark_decision_button(b, "psports:"+a[0]); row.add_child(b)

func _on_pro_sports(action: String):
	var cmd = GameCommandClass.create_pro_sports_action(action)
	var labels := {"leagues":"توسعه لیگ‌های حرفه‌ای","infrastructure":"ساخت زیرساخت ورزشی","events":"میزبانی رویداد","academy":"آکادمی جوانان","exports":"صادرات صنعت ورزش"}
	if _queue_decision(cmd, "⚽ " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد")
		_switch_tab("society")

# ── عمق ۲۱: هوانوردی، پست و لجستیک، استاندارد و کیفیت ──
func _build_aviation_card(st: Dictionary):
	var ap: Dictionary = AviationManager.get_policy(st)
	var card = _card("✈️ هوانوردی و خطوط هوایی")
	_bar(card, "ظرفیت فرودگاهی", float(ap.get("airports",0.15)))
	_bar(card, "ناوگان ملی", float(ap.get("fleet",0.10)))
	_bar(card, "ایمنی ناوبری", float(ap.get("safety",0.40)))
	_bar(card, "هاب ترانزیت", float(ap.get("hub",0.05)))
	_bar(card, "بار هوایی", float(ap.get("cargo",0.10)))
	var lbl = Label.new(); lbl.text = "مسافران سالانه: " + str(ap.get("passengers_m",25)) + " میلیون نفر"; lbl.add_theme_font_size_override("font_size",14); lbl.modulate = ACCENT_GOLD; card.add_child(lbl)
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["airports","🛫 فرودگاه"],["fleet","✈️ ناوگان"],["safety","🛡️ ایمنی"],["hub","🌐 هاب"],["cargo","📦 بار"]]:
		var b = Button.new(); b.text = a[1]; b.add_theme_font_size_override("font_size",11); b.custom_minimum_size = Vector2(0,34)
		b.pressed.connect(FeedbackManager.play_click); b.pressed.connect(_on_aviation.bind(a[0])); _mark_decision_button(b, "av:"+a[0]); row.add_child(b)

func _on_aviation(action: String):
	var cmd = GameCommandClass.create_aviation_action(action)
	var labels := {"airports":"توسعه فرودگاه‌ها","fleet":"تقویت ناوگان هوایی ملی","safety":"بهبود ایمنی ناوبری","hub":"توسعه هاب ترانزیت","cargo":"توسعه بار هوایی"}
	if _queue_decision(cmd, "✈️ " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("economy")

func _build_postal_card(st: Dictionary):
	var pp: Dictionary = PostalManager.get_policy(st)
	var card = _card("📮 پست و لجستیک ملی")
	_bar(card, "شبکه توزیع", float(pp.get("network",0.30)))
	_bar(card, "پردازش مکانیزه", float(pp.get("sorting",0.15)))
	_bar(card, "تحویل آخرین مایل", float(pp.get("lastmile",0.20)))
	_bar(card, "تجارت الکترونیک", float(pp.get("ecommerce",0.25)))
	_bar(card, "رهگیری مرسولات", float(pp.get("tracking",0.10)))
	var lbl = Label.new(); lbl.text = "مرسولات سالانه: " + str(pp.get("parcels_m",500)) + " میلیون قطعه"; lbl.add_theme_font_size_override("font_size",14); lbl.modulate = ACCENT_GOLD; card.add_child(lbl)
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["network","🚚 شبکه"],["sorting","⚙️ پردازش"],["lastmile","🏍️ تحویل"],["ecommerce","🛒 آنلاین"],["tracking","📡 رهگیری"]]:
		var b = Button.new(); b.text = a[1]; b.add_theme_font_size_override("font_size",11); b.custom_minimum_size = Vector2(0,34)
		b.pressed.connect(FeedbackManager.play_click); b.pressed.connect(_on_postal.bind(a[0])); _mark_decision_button(b, "post:"+a[0]); row.add_child(b)

func _on_postal(action: String):
	var cmd = GameCommandClass.create_postal_action(action)
	var labels := {"network":"گسترش شبکه توزیع سراسری","sorting":"مکانیزه‌سازی پردازش","lastmile":"بهبود تحویل آخرین مایل","ecommerce":"تسهیل تجارت الکترونیک","tracking":"رهگیری هوشمند مرسولات"}
	if _queue_decision(cmd, "📮 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("economy")

func _build_standards_card(st: Dictionary):
	var sp: Dictionary = StandardsManager.get_policy(st)
	var card = _card("📏 استاندارد و زیرساخت کیفیت")
	_bar(card, "مترولوژی", float(sp.get("metrology",0.20)))
	_bar(card, "آزمایشگاه‌های معتمد", float(sp.get("labs",0.15)))
	_bar(card, "اعتباردهی و گواهی", float(sp.get("accreditation",0.10)))
	_bar(card, "بازرسی بازار", float(sp.get("surveillance",0.25)))
	_bar(card, "دروازه کیفیت صادرات", float(sp.get("export_gate",0.15)))
	var lbl = Label.new(); lbl.text = "بنگاه‌های گواهی‌شده: " + str(sp.get("certified_firms",1200)); lbl.add_theme_font_size_override("font_size",14); lbl.modulate = ACCENT_GOLD; card.add_child(lbl)
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["metrology","⚖️ مترولوژی"],["labs","🔬 آزمایشگاه"],["accreditation","🎖️ اعتبار"],["surveillance","🔍 بازرسی"],["export_gate","🚢 صادرات"]]:
		var b = Button.new(); b.text = a[1]; b.add_theme_font_size_override("font_size",11); b.custom_minimum_size = Vector2(0,34)
		b.pressed.connect(FeedbackManager.play_click); b.pressed.connect(_on_standards.bind(a[0])); _mark_decision_button(b, "std:"+a[0]); row.add_child(b)

func _on_standards(action: String):
	var cmd = GameCommandClass.create_standards_action(action)
	var labels := {"metrology":"سرمایه‌گذاری مترولوژی","labs":"اعتباربخشی آزمایشگاه‌ها","accreditation":"گسترش اعتباردهی ملی","surveillance":"بازرسی و نظارت بر بازار","export_gate":"تقویت دروازه کیفیت صادرات"}
	if _queue_decision(cmd, "📏 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("economy")

func _on_transport(action: String):
	var cmd = GameCommandClass.create_transport_action(action)
	var labels := {"metro": "خط متروی جدید", "brt": "توسعه خطوط BRT", "subsidy": "افزایش یارانه کرایه", "fleet": "نوسازی ناوگان برقی"}
	if _queue_decision(cmd, "🚇 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("economy")

func _on_retail(action: String):
	var cmd = GameCommandClass.create_retail_action(action)
	var labels := {"price": "تغییر سیاست تنظیم قیمت", "protect": "تقویت حمایت از مصرف‌کننده", "ecommerce": "توسعه تجارت الکترونیک", "bazaar": "نوسازی بازارهای سنتی"}
	if _queue_decision(cmd, "🛒 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("economy")

func _on_ethnicity(action: String):
	var cmd = GameCommandClass.create_ethnicity_action(action)
	var labels := {"equal": "برنامه فرصت‌های برابر", "autonomy": "خودمختاری فرهنگی مناطق", "dialogue": "گفت‌وگوی ملی اقوام", "festival": "جشنواره فرهنگ اقوام"}
	if _queue_decision(cmd, "🕊️ " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("government")

func _build_sports_card(st: Dictionary):
	var sp: Dictionary = st.get("sports_policy", {})
	if sp.is_empty():
		return
	var card = _card("🏆 ورزش و سلامت عمومی")
	_bar(card, "ورزش همگانی", float(sp.get("grassroots", 0.3)))
	_bar(card, "لیگ حرفه‌ای", float(sp.get("pro_league", 0.4)))
	_bar(card, "برنامه ضد دوپینگ", float(sp.get("anti_doping", 0.5)))
	_row(card, "رویدادهای میزبانی‌شده", PersianFormatter.to_persian_digits(str(sp.get("hosted", 0))))
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4); card.add_child(row)
	for a in [["grassroots", "🏃 ورزش همگانی"], ["league", "⚽ لیگ حرفه‌ای"], ["doping", "🧪 ضد دوپینگ"], ["host", "🏟️ میزبانی رویداد"]]:
		var btn = Button.new(); btn.text = a[1]
		btn.custom_minimum_size = Vector2(0, 34); btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_sports.bind(a[0]))
		_mark_decision_button(btn, "sports:" + a[0])
		row.add_child(btn)
	var hint = Label.new()
	hint.text = "ورزش همگانی سلامت و بهره‌وری می‌آورد؛ لیگ حرفه‌ای جوانان و اشتغال؛ ضد دوپینگ تصویر جهانی؛ میزبانی رویداد بزرگ (هر ۱۸ نوبت) گردشگری و پرستیژ جهش می‌دهد."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14); hint.modulate = TEXT_FAINT
	card.add_child(hint)

func _on_sports(action: String):
	var cmd = GameCommandClass.create_sports_action(action)
	var labels := {"grassroots": "ورزش همگانی", "league": "توسعه لیگ حرفه‌ای", "doping": "برنامه ضد دوپینگ", "host": "میزبانی رویداد ورزشی"}
	if _queue_decision(cmd, "🏆 " + labels.get(action, action)):
		_toast(labels.get(action, action) + " ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("population")

func _build_technology():
	var state = GameState.state
	var tech: Dictionary = state.get("technology", {})
	var current = tech.get("in_progress", null)
	var status = _card("🔬 مرکز پژوهش ملی")
	_row(status, "امتیاز پژوهش ذخیره", PersianFormatter.to_persian_digits("%.2f" % tech.get("research_points", 0.0)))
	_row(status, "سرعت پژوهش سالانه", PersianFormatter.to_persian_digits("%.2f" % tech.get("research_rate", 0.0)))
	if current == null:
		var idle = Label.new()
		idle.text = "هیچ فناوری در حال پژوهش نیست؛ یک پروژه از فهرست زیر انتخاب کنید."
		idle.modulate = Color(1.0, 0.78, 0.35)
		status.add_child(idle)
	else:
		var current_id = str(current)
		var cost = TechnologyManager.get_cost(current_id)
		_row(status, "پروژه فعال", TechnologyManager.get_technology_name(current_id))
		_bar(status, "پیشرفت", TechnologyManager.progress_ratio(state))
		var remaining = max(0.0, cost - float(tech.get("research_points", 0.0)))
		var days = int(remaining / max(float(tech.get("research_rate", 0.01)), 0.01) * 365.0)
		_row(status, "زمان تقریبی باقی‌مانده", "%s روز" % PersianFormatter.to_persian_digits(str(days)))

	var branches = _card("🧬 بلوغ شاخه‌های فناوری")
	for branch in tech.get("branches", {}).keys():
		_bar(branches, str(branch).replace("_", " "), float(tech["branches"][branch]))

	# ارتقاهای اصلی: هر شاخه ۳۰ سطح دارد (بالانس ~۱ ساعته)؛ متفرقه‌ها سطح کم‌تری دارند
	var upgrades = _card("⬆️ ارتقای شاخه‌های اصلی — حداکثر سطح ۳۰")
	_upgrade_row(upgrades, state, tech, "صنعت", "🏭 صنعت")
	_upgrade_row(upgrades, state, tech, "انرژی_پاک", "🌱 انرژی پاک")
	_upgrade_row(upgrades, state, tech, "پزشکی", "⚕ پزشکی")
	_upgrade_row(upgrades, state, tech, "نظامی", "🪖 نظامی")
	_upgrade_row(upgrades, state, tech, "دیجیتال", "💻 دیجیتال")
	_upgrade_row(upgrades, state, tech, "فضا", "🚀 فضا")
	_build_space_card(state)
	_build_digital_card(state)
	var up_hint = Label.new()
	up_hint.text = "با رسیدن سه شاخه به سطح ۳۰، کشور وارد «عصر طلایی» می‌شود و بازی قابل اتمام است (~۱ ساعت)."
	up_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	up_hint.add_theme_font_size_override("font_size", 17)
	up_hint.modulate = TEXT_FAINT
	upgrades.add_child(up_hint)

	var available = TechnologyManager.get_available(state)
	var projects = _card("🧪 پروژه‌های در دسترس")
	if available.is_empty():
		var done = Label.new()
		done.text = "همه فناوری‌های در دسترس تکمیل شده‌اند یا پژوهشی در حال اجراست."
		projects.add_child(done)
	for technology in available:
		var panel = PanelContainer.new()
		projects.add_child(panel)
		var body = VBoxContainer.new()
		panel.add_child(body)
		var name_label = Label.new()
		name_label.text = "◈ %s — شاخه %s" % [technology.get("name_fa", ""), str(technology.get("branch", "")).replace("_", " ")]
		name_label.add_theme_font_size_override("font_size", 17)
		name_label.modulate = Color(0.55, 0.85, 1.0)
		body.add_child(name_label)
		var description = Label.new()
		description.text = str(technology.get("description", ""))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(description)
		_row(body, "هزینه پژوهش", PersianFormatter.to_persian_digits(str(technology.get("cost", 0))))
		var prerequisite_names: Array = []
		for prerequisite in technology.get("prerequisites", []):
			prerequisite_names.append(TechnologyManager.get_technology_name(str(prerequisite)))
		if not prerequisite_names.is_empty():
			_row(body, "پیش‌نیاز", "، ".join(prerequisite_names))
		var start_button = _mk_btn(body, "آغاز پژوهش", Vector2(180, 46),
			_on_start_research.bind(str(technology.get("id", "")), str(technology.get("name_fa", ""))))
		_mark_decision_button(start_button, "res:" + str(technology.get("id", "")))
		start_button.disabled = current != null

	_build_research_card(state)
	_build_startup_card(state)
	_build_higher_ed_card(state)
	_build_science_card(state)
	_build_ip_card(state)
	_build_ai_card(state)
	_build_aerospace_card(state)

	var unlocked_card = _card("✅ فناوری‌های تکمیل‌شده")
	var unlocked_names: Array = []
	for id in tech.get("unlocked", []):
		unlocked_names.append(TechnologyManager.get_technology_name(str(id)))
	var unlocked_label = Label.new()
	unlocked_label.text = " • ".join(unlocked_names)
	unlocked_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	unlocked_card.add_child(unlocked_label)

func _upgrade_row(parent: VBoxContainer, state: Dictionary, tech: Dictionary, branch: String, label: String):
	var level: int = TechnologyManager.get_branch_level(state, branch)
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 8); parent.add_child(row)
	var info = VBoxContainer.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; info.add_theme_constant_override("separation", 2); row.add_child(info)
	var top = Label.new()
	top.text = "%s — سطح %s / ۳۰" % [label, PersianFormatter.to_persian_digits(str(level))]
	top.add_theme_font_size_override("font_size", 19)
	info.add_child(top)
	var pbar = ProgressBar.new(); pbar.max_value = 30.0; pbar.value = level; pbar.custom_minimum_size = Vector2(0, 12)
	info.add_child(pbar)
	var upgrade = Button.new()
	if level >= 30:
		upgrade.text = "✅ کامل"
		upgrade.disabled = true
	else:
		var cost: float = TechnologyManager.branch_upgrade_cost(level)
		upgrade.text = "ارتقا (%s امتیاز)" % PersianFormatter.to_persian_digits(str(int(cost)))
		upgrade.disabled = float(tech.get("research_points", 0.0)) < cost
		upgrade.tooltip_text = "" if not upgrade.disabled else "امتیاز پژوهش کافی نیست"
	upgrade.custom_minimum_size = Vector2(190, 46)
	upgrade.add_theme_font_size_override("font_size", 18)
	upgrade.pressed.connect(FeedbackManager.play_click)
	upgrade.pressed.connect(_on_upgrade_branch.bind(branch))
	row.add_child(upgrade)

func _on_upgrade_branch(branch: String):
	var result = TechnologyManager.upgrade_branch(GameState.state, branch)
	if result.success:
		var level: int = int(result.level)
		_toast("⬆️ شاخه «%s» به سطح %s رسید" % [branch, PersianFormatter.to_persian_digits(str(level))])
		if level >= 30:
			FeedbackManager.play_achievement()
		_switch_tab("technology")
	else:
		_toast("⚠️ " + str(result.get("reason", "ارتقا ممکن نشد")))

func _on_start_research(technology_id: String, technology_name: String):
	var cmd = GameCommandClass.create_research_start(technology_id)
	if _queue_decision(cmd, "🔬 آغاز پژوهش: " + technology_name):
		_toast("🔬 پژوهش «%s» ثبت شد — با پایان نوبت آغاز می‌شود" % technology_name)
		_switch_tab("technology")

# ============================================================
# تب جمعیت
# ============================================================
func _build_population():
	_build_media_card(GameState.state)
	_build_labor_card(GameState.state)
	_build_epidemic_card(GameState.state)
	_build_pharma_card(GameState.state)
	_build_migration_card(GameState.state)
	_build_demographic_card(GameState.state)
	_build_culture_card(GameState.state)
	_build_urban_card(GameState.state)
	_build_housing_card(GameState.state)
	_build_welfare_card(GameState.state)
	_build_insurance_card(GameState.state)
	_build_care_card(GameState.state)
	_build_rural_card(GameState.state)
	_build_sports_card(GameState.state)
	_build_veterans_card(GameState.state)
	_build_heritage_card(GameState.state)
	
	var st = GameState.state
	var pop = st.get("population", {})

	var c1 = _card("👥 جمعیت")
	_row(c1, "جمعیت کل", PersianFormatter.format_large(pop.get("total", 0)) + " نفر")
	var monthly_growth = pow(1.0 + float(pop.get("growth_rate", 0.0)), float(GameState.state.get("time", {}).get("days_in_month", 30))) - 1.0
	_row(c1, "نرخ رشد ماهانه", PersianFormatter.to_persian_digits("%.3f٪" % (monthly_growth * 100.0)))
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
	_build_assassination_card(st, c3)
	_build_war_goals_card(st)
	_build_cyber_card(st)
	_build_generals_card(st)
	_build_arms_card(st)
	_build_civil_defense_card(st)
	_build_defense_industry_card(st)
	_build_petrochemical_card(st)
	_build_blue_economy_card(st)

	var development: Dictionary = st.get("military_development", {})
	var doctrine_card = _card("🧭 دکترین نظامی")
	_row(doctrine_card, "دکترین فعال", MilitaryManager.get_doctrine_name(str(development.get("doctrine", "balanced"))))
	var doctrine_grid = GridContainer.new(); doctrine_grid.columns = 3; doctrine_card.add_child(doctrine_grid)
	for doctrine_id in MilitaryManager.DOCTRINES.keys():
		var doctrine_button = Button.new(); doctrine_button.text = MilitaryManager.get_doctrine_name(doctrine_id)
		doctrine_button.disabled = str(development.get("doctrine", "balanced")) == doctrine_id
		doctrine_button.pressed.connect(FeedbackManager.play_click)
		doctrine_button.pressed.connect(_on_military_doctrine.bind(str(doctrine_id)))
		_mark_decision_button(doctrine_button, "doc:" + str(doctrine_id))
		doctrine_grid.add_child(doctrine_button)

	var programs_card = _card("🏗️ برنامه‌های توسعه دفاعی")
	var active_programs: Dictionary = development.get("active", {})
	for active_id in active_programs.keys():
		_row(programs_card, "در حال اجرا: %s" % MilitaryManager.get_program_name(active_id), "%s ماه باقی‌مانده" % PersianFormatter.to_persian_digits(str(active_programs[active_id].get("remaining_months", 0))))
	for program_id in MilitaryManager.get_program_ids():
		var definition = MilitaryManager.get_program(program_id)
		var row = HBoxContainer.new(); programs_card.add_child(row)
		var info = VBoxContainer.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(info)
		var title = Label.new(); title.text = str(definition.get("name_fa", program_id)); title.add_theme_font_size_override("font_size", 16); info.add_child(title)
		var desc = Label.new(); desc.text = PersianFormatter.to_persian_digits("%s — مدت %s ماه، هزینه %.2f٪ تولید داخلی" % [definition.get("description", ""), str(definition.get("duration_months", 1)), float(definition.get("cost_gdp_ratio", 0.0)) * 100.0])
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; desc.modulate = Color(0.72, 0.78, 0.88); info.add_child(desc)
		var check = MilitaryManager.can_start(st, program_id)
		var start = Button.new(); start.text = "آغاز"; start.custom_minimum_size = Vector2(100, 44); start.disabled = not check.valid; start.tooltip_text = "" if check.valid else str(check.reason)
		start.pressed.connect(FeedbackManager.play_click); start.pressed.connect(_on_military_program.bind(str(program_id), str(definition.get("name_fa", "برنامه"))))
		_mark_decision_button(start, "milprog:" + str(program_id))
		row.add_child(start)

	var operations_state: Dictionary = st.get("intelligence_operations", {})
	var operations_card = _card("🕶️ عملیات اطلاعاتی")
	_bar(operations_card, "ریسک افشای انباشته", float(operations_state.get("heat", 0.0)))
	_row(operations_card, "ظرفیت عملیاتی", "%s از %s" % [PersianFormatter.to_persian_digits(str(operations_state.get("active", {}).size())), PersianFormatter.to_persian_digits(str(operations_state.get("capacity", 2)))])
	var target = selected_world_country
	if target.is_empty() or target == st.get("country", {}).get("id", ""):
		var relation_keys = st.get("diplomacy", {}).get("relations", {}).keys()
		target = str(relation_keys[0]) if not relation_keys.is_empty() else ""
	_row(operations_card, "هدف خارجی فعلی", WorldManager.get_country_name(target) if not target.is_empty() else "انتخاب نشده")
	for operation_key in operations_state.get("active", {}).keys():
		var record: Dictionary = operations_state["active"][operation_key]
		var active_row = HBoxContainer.new(); operations_card.add_child(active_row)
		var active_label = Label.new(); active_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		active_label.text = "در حال اجرا: %s — %s ماه" % [IntelligenceOperationManager.get_operation_name(str(record.get("operation_id", ""))), PersianFormatter.to_persian_digits(str(record.get("remaining_months", 0)))]
		active_row.add_child(active_label)
		var cancel = Button.new(); cancel.text = "لغو"; cancel.pressed.connect(FeedbackManager.play_click); cancel.pressed.connect(_on_intelligence_cancel.bind(str(operation_key))); _mark_decision_button(cancel, "intelx:" + str(operation_key)); active_row.add_child(cancel)
	for operation_id in IntelligenceOperationManager.get_operation_ids():
		var operation = IntelligenceOperationManager.get_operation(operation_id)
		var operation_target = target if operation.get("scope", "domestic") == "foreign" else ""
		var op_row = HBoxContainer.new(); operations_card.add_child(op_row)
		var op_info = VBoxContainer.new(); op_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; op_row.add_child(op_info)
		var op_title = Label.new(); op_title.text = "%s — %s" % [operation.get("name_fa", operation_id), "خارجی" if operation.get("scope", "domestic") == "foreign" else "داخلی"]; op_title.add_theme_font_size_override("font_size", 16); op_info.add_child(op_title)
		var op_desc = Label.new(); op_desc.text = PersianFormatter.to_persian_digits("%s | مدت %s ماه | خطر افشا %.0f٪" % [operation.get("description", ""), str(operation.get("duration_months", 1)), float(operation.get("detection_risk", 0.0)) * 100.0]); op_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; op_desc.modulate = Color(0.72, 0.78, 0.88); op_info.add_child(op_desc)
		var op_check = IntelligenceOperationManager.can_start(st, operation_id, operation_target)
		var op_start = Button.new(); op_start.text = "آغاز"; op_start.disabled = not op_check.valid; op_start.tooltip_text = "" if op_check.valid else str(op_check.reason); op_start.pressed.connect(FeedbackManager.play_click); op_start.pressed.connect(_on_intelligence_start.bind(str(operation_id), operation_target)); _mark_decision_button(op_start, "intel:" + str(operation_id) + ":" + str(operation_target)); op_row.add_child(op_start)
	var reports: Array = operations_state.get("reports", [])
	for i in range(max(0, reports.size() - 4), reports.size()):
		var report = reports[i]
		_row(operations_card, "گزارش: %s" % WorldManager.get_country_name(str(report.get("target", ""))), "کیفیت %s٪" % PersianFormatter.to_persian_digits(str(int(float(report.get("quality", 0.0)) * 100.0))))

func _on_intelligence_start(operation_id: String, target: String):
	if _queue_decision(GameCommandClass.create_intelligence_operation(operation_id, target), "🕶️ عملیات: " + IntelligenceOperationManager.get_operation_name(operation_id) + " بر " + WorldManager.get_country_name(target)):
		_toast("🕶️ عملیات «%s» ثبت شد — با پایان نوبت آغاز می‌شود" % IntelligenceOperationManager.get_operation_name(operation_id)); _switch_tab("military")

func _on_intelligence_cancel(operation_key: String):
	if _queue_decision(GameCommandClass.create_intelligence_cancel(operation_key), "⛔ لغو عملیات اطلاعاتی"):
		_toast("⛔ لغو عملیات اطلاعاتی ثبت شد — با پایان نوبت اجرا می‌شود"); _switch_tab("military")

func _on_military_doctrine(doctrine_id: String):
	if _queue_decision(GameCommandClass.create_military_doctrine(doctrine_id), "🪖 دکترین: " + MilitaryManager.get_doctrine_name(doctrine_id)):
		_toast("🪖 دکترین «%s» ثبت شد — با پایان نوبت فعال می‌شود" % MilitaryManager.get_doctrine_name(doctrine_id)); _switch_tab("military")

func _on_military_program(program_id: String, title: String):
	if _queue_decision(GameCommandClass.create_military_program(program_id), "🏗️ برنامه نظامی: " + title):
		_toast("🏗️ برنامه «%s» ثبت شد — با پایان نوبت آغاز می‌شود" % title); _switch_tab("military")

# ============================================================
# مرکز چندنفره — جدا از نقشه برای حفظ تمرکز و افشای تدریجی
# ============================================================
func _build_network_panel():
	var state = GameState.state
	var overview = _card("مرکز عملیات چندنفره")
	var hint = Label.new(); hint.text = "میزبان مرجع محاسبات است. حالت همکارانه یک کشور مشترک و حالت رقابتی برای هر بازیکن State و کشور مستقل نگه می‌دارد."; hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; hint.modulate = Color(0.70,0.81,0.87); overview.add_child(hint)
	network_status_lbl = Label.new(); network_status_lbl.add_theme_font_size_override("font_size",17); network_status_lbl.modulate = Color(0.26,0.88,0.88); overview.add_child(network_status_lbl)
	var identity_grid = GridContainer.new(); identity_grid.columns = 2; overview.add_child(identity_grid)
	network_player_name_edit = LineEdit.new(); network_player_name_edit.placeholder_text = "نام بازیکن"; network_player_name_edit.text = "رهبر %s" % str(state.get("country",{}).get("name","کشور")); identity_grid.add_child(network_player_name_edit)
	var address_row = HBoxContainer.new(); identity_grid.add_child(address_row)
	network_address_edit = LineEdit.new(); network_address_edit.placeholder_text = "نشانی میزبان"; network_address_edit.text = "127.0.0.1"; network_address_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL; address_row.add_child(network_address_edit)
	network_port_spin = SpinBox.new(); network_port_spin.min_value = 1024; network_port_spin.max_value = 65535; network_port_spin.value = P2PManager.DEFAULT_PORT; network_port_spin.custom_minimum_size = Vector2(145,44); address_row.add_child(network_port_spin)
	var rand_port_btn = Button.new(); rand_port_btn.text = "🎲 پورت آزاد"; rand_port_btn.custom_minimum_size = Vector2(110, 40)
	rand_port_btn.add_theme_font_size_override("font_size", 14)
	rand_port_btn.tooltip_text = "اگر پورت پیش‌فرض اشغال است، یک پورت تصادفی آزاد انتخاب کنید"
	rand_port_btn.pressed.connect(FeedbackManager.play_click); rand_port_btn.pressed.connect(_on_random_port)
	address_row.add_child(rand_port_btn)
	var direct = _card("اتصال مستقیم و همکارانه")
	var direct_grid = GridContainer.new(); direct_grid.columns = 4; direct.add_child(direct_grid)
	_mk_btn(direct_grid,"میزبانی",Vector2(150,48),_on_host_network,"PrimaryAction")
	_mk_btn(direct_grid,"اتصال",Vector2(150,48),_on_join_network)
	_mk_btn(direct_grid,"بازکردن پورت",Vector2(165,48),_on_enable_upnp)
	_mk_btn(direct_grid,"قطع اتصال",Vector2(150,48),_on_disconnect_network)
	_build_remote_card()
	var campaign = _card("کمپین رقابتی کشورهای مستقل")
	campaign_lobby_lbl = Label.new(); campaign_lobby_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; campaign.add_child(campaign_lobby_lbl)
	var campaign_grid = GridContainer.new(); campaign_grid.columns = 4; campaign.add_child(campaign_grid)
	_mk_btn(campaign_grid,"میزبانی رقابتی",Vector2(170,48),_on_host_competitive,"PrimaryAction")
	_mk_btn(campaign_grid,"اتصال رقابتی",Vector2(170,48),_on_join_competitive)
	_mk_btn(campaign_grid,"آماده‌ام",Vector2(140,48),_on_campaign_ready)
	_mk_btn(campaign_grid,"شروع کمپین",Vector2(150,48),_on_start_campaign)
	var safety = _card("وضعیت شبکه و ایمنی")
	_row(safety,"حداکثر بازیکن انسانی",PersianFormatter.to_persian_digits("۸ کشور"))
	_row(safety,"مرجع State","میزبان")
	_row(safety,"روش اتصال","LAN، IP مستقیم یا UPnP")
	var safety_hint = Label.new(); safety_hint.text = "برای اینترنت عمومی هنوز سرویس کشف/سیگنال بیرونی لازم است؛ خود بازی هیچ سرویس پولی یا سرور اجباری ندارد."; safety_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; safety_hint.modulate = Color(0.64,0.75,0.82); safety.add_child(safety_hint)
	_refresh_network_status(); _on_campaign_lobby(MultiplayerCampaignManager.get_lobby_snapshot())

# ============================================================
# نقشه فرماندهی یکپارچه — جهان، منطقه، کشور، استان و اقدام زمینه‌ای
# ============================================================
func _build_unified_map():
	_sync_world_map()
	if is_instance_valid(current_unified_map):current_unified_map.queue_redraw()
	var state = GameState.state

	# برگه کنترل شناور پایین نقشه — لنزها و لایه‌های تحلیلی.
	var controls = _card("◉ لنزها و لایه‌های نقشه")
	# === جستجوی فارسی نقشه‌محور - حرفه‌ای ===
	var search_row = HBoxContainer.new()
	search_row.add_theme_constant_override("separation", 8)
	controls.add_child(search_row)
	var search_icon = Label.new()
	search_icon.text = "🔍"
	search_icon.add_theme_font_size_override("font_size", 22)
	search_row.add_child(search_icon)
	var search_edit = LineEdit.new()
	search_edit.placeholder_text = "جستجوی کشور/شهر فارسی... مثلا ایران، تهران، اصفهان"
	search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_edit.custom_minimum_size = Vector2(0, 42)
	search_row.add_child(search_edit)
	var search_btn = Button.new()
	search_btn.text = "جستجو"
	search_btn.custom_minimum_size = Vector2(90, 42)
	search_row.add_child(search_btn)
	search_edit.text_submitted.connect(_on_map_search.bind(search_edit))
	search_btn.pressed.connect(_on_map_search.bind(search_edit))
	# چیپ‌های لنز (تک‌انتخابی) — جابه‌جایی سریع نگاه تحلیلی روی نقشه.
	map_control_flow = HFlowContainer.new(); map_control_flow.add_theme_constant_override("h_separation",7); map_control_flow.add_theme_constant_override("v_separation",6); controls.add_child(map_control_flow)
	# لنزها در گروه‌های مفهومی مرتب می‌شوند تا دسترسی منطقی و سریع باشد
	# لنزها هم‌راستا با معماری اطلاعاتی ۸ حوزه (SYSTEM_GROUPS) — نمایش منسجم در کل بازی
	var lens_groups = [
		["🏛️ حاکمیت و سیاست", [
			["political","سیاسی"],["judicial","قضایی"],["administration","اداره"],["elections","انتخابات"],
			["politics","سیاست"],["statistics","آمار"],["emergency","بحران"]]],
		["💰 اقتصاد و دارایی", [
			["economy","اقتصاد"],["resources","منابع"],["agriculture","کشاورزی"],["industry","صنعت"],
			["trade_layer","تجارت"],["tourism","گردشگری"],["central_bank","بانک مرکزی"],["stock_market","بورس"],
			["retail","خرده‌فروشی"],["fuel_stations","سوخت"]]],
		["👥 جامعه و رفاه", [
			["population","جمعیت"],["satisfaction","رضایت"],["health","بهداشت"],["education","آموزش"],
			["welfare","رفاه"],["family","خانواده"],["sports_youth","ورزش"],["ethnicity","قومیت"],["culture","فرهنگ"]]],
		["🏗️ زیرساخت و محیط", [
			["infrastructure","زیرساخت"],["urban_facilities","تاسیسات شهری"],["public_services","خدمات عمومی"],
			["transport_roads","راه‌ها"],["settlements","سکونتگاه‌ها"],["environment","محیط‌زیست"],["weather","اقلیم"]]],
		["🛡️ دفاع و امنیت", [
			["military","نظامی"],["security","امنیت"],["intelligence","اطلاعات"],["military_power","قدرت نظامی"],
			["trade_route_warfare","جنگ تجاری"]]],
		["🌍 دیپلماسی و بین‌الملل", [
			["relations","روابط"]]]
	]
	for group in lens_groups:
		var group_header = Label.new(); group_header.text = str(group[0])
		group_header.add_theme_font_size_override("font_size", 16)
		group_header.modulate = Color(1.0, 0.81, 0.30, 0.9)
		group_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		map_control_flow.add_child(group_header)
		for lens in group[1]:
			var chip = Button.new(); chip.text = lens[1]; chip.toggle_mode = true; chip.custom_minimum_size = Vector2(0,50); chip.add_theme_font_size_override("font_size",21)
			chip.theme_type_variation = "LensChipActive" if lens[0] == map_base_layer else "LensChip"
			chip.set_meta("lens_layer", lens[0]); chip.set_pressed_no_signal(lens[0] == map_base_layer)
			chip.pressed.connect(FeedbackManager.play_click); chip.pressed.connect(_on_map_lens_chip.bind(str(lens[0])))
			map_control_flow.add_child(chip)
	var overlay_caption = Label.new(); overlay_caption.text = "لایه‌های اطلاعاتی روی نقشه"; overlay_caption.add_theme_font_size_override("font_size", 19); overlay_caption.modulate = TEXT_FAINT; controls.add_child(overlay_caption)
	# پیل‌های لایه (چندانتخابی) با چراغ وضعیت طلایی — دسته «اصلی»
	map_overlay_grid = GridContainer.new(); map_overlay_grid.columns = 5; map_overlay_grid.add_theme_constant_override("h_separation",7); map_overlay_grid.add_theme_constant_override("v_separation",6); controls.add_child(map_overlay_grid)
	var overlay_defs = [
		["wars","جنگ"],
		["alliances","اتحاد"],
		["trade","تجارت"],
		["air","پرواز"],
		["sea","دریا"],
		["land","زمین"],
		["cities","شهرها"],
		["transport","راه و ریل"],
		["intelligence","اطلاعاتی"]
	]
	for definition in overlay_defs:
		var pill = Button.new(); pill.text = definition[1]; pill.toggle_mode = true; pill.custom_minimum_size = Vector2(0,46); pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL; pill.add_theme_font_size_override("font_size",19)
		pill.theme_type_variation = "PillToggle"
		pill.button_pressed = bool(map_overlays.get(definition[0],false))
		pill.toggled.connect(_on_unified_overlay_toggled.bind(str(definition[0])))
		map_overlay_grid.add_child(pill)
	# دسته «پیشرفته» — لایه‌های تخصصی نقشه‌محور، با زیرگروه‌های موضوعی
	var advanced_overlay_caption = Label.new(); advanced_overlay_caption.text = "لایه‌های پیشرفته"; advanced_overlay_caption.add_theme_font_size_override("font_size", 17); advanced_overlay_caption.modulate = Color(1.0, 0.81, 0.30, 0.75); controls.add_child(advanced_overlay_caption)
	var overlay_adv_groups = [
		["🛡️ نظامی", [
			["units","یگان‌ها ⚔️"],
			["supply","تدارکات 📦"],
			["battle_plans","طرح نبرد 📋"]]],
		["🏗️ زیرساخت", [
			["constructions","ساخت‌وساز 🏗️"]]],
		["📊 تحلیلی", [
			["resources_detail","معادن و چاه ⛏️"],
			["population_heatmap","تراکم جمعیت 👥"],
			["weather_live","هواشناسی زنده 🌦️"]]]
	]
	for adv_group in overlay_adv_groups:
		var sub_caption = Label.new(); sub_caption.text = str(adv_group[0])
		sub_caption.add_theme_font_size_override("font_size", 15)
		sub_caption.modulate = Color(0.62, 0.80, 0.92, 0.85)
		sub_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		controls.add_child(sub_caption)
		var map_overlay_grid_adv = GridContainer.new(); map_overlay_grid_adv.columns = 5; map_overlay_grid_adv.add_theme_constant_override("h_separation",7); map_overlay_grid_adv.add_theme_constant_override("v_separation",6); controls.add_child(map_overlay_grid_adv)
		for definition in adv_group[1]:
			var pill = Button.new(); pill.text = definition[1]; pill.toggle_mode = true; pill.custom_minimum_size = Vector2(0,46); pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL; pill.add_theme_font_size_override("font_size",19)
			pill.theme_type_variation = "PillToggle"
			pill.button_pressed = bool(map_overlays.get(definition[0],false))
			pill.toggled.connect(_on_unified_overlay_toggled.bind(str(definition[0])))
			map_overlay_grid_adv.add_child(pill)
	var usage = Label.new(); usage.text = "◉ کشیدن جابه‌جا می‌کند · دو انگشت زوم · لمس کشور را انتخاب و دوبار لمس وارد کشور می‌شود؛ با زوم، استان‌ها و شبکه‌ها آشکار می‌گردند."; usage.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; usage.modulate = TEXT_FAINT; usage.add_theme_font_size_override("font_size",19); controls.add_child(usage)

	# === حالت‌های پیشرفته نقشه‌محور - طرح نبرد، ساخت‌وساز ===
	var advanced_caption = Label.new(); advanced_caption.text = "⚔️ حالت‌های پیشرفته نقشه‌محور (HOI4/EU4)"; advanced_caption.add_theme_font_size_override("font_size", 20); advanced_caption.modulate = Color(1.0,0.85,0.4); controls.add_child(advanced_caption)
	var advanced_grid = GridContainer.new(); advanced_grid.columns = 3; advanced_grid.add_theme_constant_override("h_separation",7); advanced_grid.add_theme_constant_override("v_separation",6); controls.add_child(advanced_grid)
	var advanced_modes = [
		["select","🎯 انتخاب","حالت عادی انتخاب کشور/شهر/مسیر"],
		["battle_plan","⚔️ طرح نبرد","کشیدن فلش تهاجمی از خودی به دشمن - HOI4"],
		["build_road","🛣️ ساخت جاده","کلیک دو شهر برای ساخت جاده"],
		["build_rail","🚂 راه‌آهن","کلیک دو شهر برای راه‌آهن"],
		["build_fort","🏰 سنگر","ساخت استحکامات در استان مرزی"],
		["build_depot","📦 انبار","انبار تدارکات - کاهش آسیب تدارکات"],
		["build_airfield","✈️ باند","باند هوایی اضطراری"],
		["build_radar","📡 رادار","ایستگاه رادار شناسایی"]
	]
	for mode_def in advanced_modes:
		var btn = Button.new(); btn.text = mode_def[1]; btn.toggle_mode = true; btn.custom_minimum_size = Vector2(0,48); btn.add_theme_font_size_override("font_size",18)
		btn.tooltip_text = mode_def[2]
		btn.set_meta("advanced_mode", mode_def[0])
		btn.pressed.connect(FeedbackManager.play_click); btn.pressed.connect(_on_advanced_map_mode.bind(mode_def[0]))
		advanced_grid.add_child(btn)
	# نمایش طرح‌های فعال
	var adv_state = state.get("map_advanced", {})
	var plans = adv_state.get("battle_plans", [])
	var constructions = adv_state.get("constructions", [])
	if not plans.is_empty() or not constructions.is_empty():
		var active_info = Label.new()
		active_info.text = "📋 طرح‌های فعال: %d نبرد + %d ساخت‌وساز" % [plans.size(), constructions.size()]
		active_info.modulate = Color(0.6,0.85,1.0)
		controls.add_child(active_info)


	# لایه نقشه دائمی در کروم ساخته می‌شود (نسخه ۸)؛ اینجا فقط برگه شناور است.
	_build_map_intel_card()
	map_context_host=VBoxContainer.new();map_context_host.add_theme_constant_override("separation",10);content.add_child(map_context_host)
	_refresh_map_context_panel()
	call_deferred("_apply_responsive_layout")
	call_deferred("_apply_tooltip_preferences")

	# آغاز فرماندهی: مُدال قهرمان روی نقشه جهانِ زنده، مانند صفحه افتتاح EU4.
	# حین محاسبه ناهمگام نخستین ماه (simulation_busy) قهرمان بازسازی نمی‌شود تا پرده پیشرفت دیده شود.
	if int(GameState.state.get("tick", 0)) == 0 and not simulation_busy:
		_build_hero_overlay()

# مُدال آغاز فرماندهی — کارت قهرمان با بنر هنری روی نقشه جهانِ زنده.
func _build_hero_overlay():
	if is_instance_valid(hero_overlay): hero_overlay.queue_free()
	hero_overlay = ColorRect.new()
	hero_overlay.color = Color(0.002, 0.008, 0.016, 0.42)
	hero_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	hero_overlay.z_index = 180
	hero_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(hero_overlay)
	# تا قهرمان روی صحنه است، برگه برمی‌خيزد تا فقط نقشه جهان زنده دیده شود.
	if is_instance_valid(content_scroll): content_scroll.visible = false
	var scroll_wrap = TouchScrollClass.new(); scroll_wrap.allow_vertical = true; scroll_wrap.allow_horizontal = false; scroll_wrap.set_anchors_preset(Control.PRESET_FULL_RECT); scroll_wrap.mouse_filter = Control.MOUSE_FILTER_STOP; hero_overlay.add_child(scroll_wrap)
	var center = CenterContainer.new(); center.size_flags_horizontal = Control.SIZE_EXPAND_FILL; center.mouse_filter = Control.MOUSE_FILTER_PASS; scroll_wrap.add_child(center)
	var setup = _hero_card(center)
	var panel = setup.get_parent() if setup.get_parent() is PanelContainer else null
	if panel != null: panel.custom_minimum_size = Vector2(min(1000.0, self.size.x - 40.0), 0)
	# بنر سینمایی «زمین در شب» — هنر بازی در نخستین نگاه.
	var banner_clip = Control.new(); banner_clip.clip_contents = true; banner_clip.custom_minimum_size = Vector2(0, 320); banner_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL; banner_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var banner = TextureRect.new(); banner.texture = HeroBannerArt; banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; banner.set_anchors_preset(Control.PRESET_FULL_RECT); banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_clip.add_child(banner); setup.add_child(banner_clip)
	# نشان طلایی عقاب و کره — امضای بصری بازی.
	var emblem_box = CenterContainer.new(); emblem_box.mouse_filter = Control.MOUSE_FILTER_IGNORE; setup.add_child(emblem_box)
	var emblem_art = TextureRect.new(); emblem_art.texture = EmblemArt; emblem_art.custom_minimum_size = Vector2(252, 150); emblem_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; emblem_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT; emblem_art.mouse_filter = Control.MOUSE_FILTER_IGNORE; emblem_box.add_child(emblem_art)
	var hero_title = Label.new(); hero_title.text = "شبیه‌ساز کشور"; hero_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; hero_title.add_theme_font_size_override("font_size", 46); setup.add_child(hero_title)
	var state = GameState.state
	var player_id = str(state.get("world", {}).get("player_country", WorldManager.default_country))
	var hero_sub = Label.new(); hero_sub.text = "فرماندهی یک ملت واقعی؛ ۱۹۵ کشور، ۶۵ سامانه زنده و تصمیم‌های ماهانه شما. کشور و سناریو را برگزینید؛ پس از اجرای نخستین ماه، کشور قابل تغییر نیست."; hero_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; hero_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; hero_sub.modulate = TEXT_MUTED; setup.add_child(hero_sub)
	var row_country = _chooser_row(setup, "⚑ کشور")
	# انتخابگر کشور: دکمه سفارشی لمسی (لیست ۱۹۵ کشور در یک پنل اسکرول‌شونده با جستجو).
	# OptionButton استاندارد گودوت در اندروید با لمس اسکرول نمی‌شود؛ این انتخابگر از
	# TouchScrollClass (اسکرول درگ واقعی) استفاده می‌کند و برای سازگاری، مقدار انتخاب
	# همیشه در country_select_option هم ثبت می‌شود.
	country_select_option = OptionButton.new(); country_select_option.visible = false
	var selected_index = 0
	for country_id in WorldManager.get_country_ids():
		var profile = WorldManager.get_country(country_id); country_select_option.add_item("%s · %s" % [profile.get("name_fa", country_id), profile.get("capital_fa", "")]); country_select_option.set_item_metadata(country_select_option.item_count - 1, country_id)
		if country_id == player_id: selected_index = country_select_option.item_count - 1
	country_select_option.select(selected_index)
	country_picker_btn = Button.new()
	country_picker_btn.text = country_select_option.get_item_text(selected_index)
	country_picker_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	country_picker_btn.custom_minimum_size = Vector2(0, 56)
	country_picker_btn.add_theme_font_size_override("font_size", 22)
	country_picker_btn.tooltip_text = "لمس کنید و لیست کشورها را با کشیدن انگشت بچرخانید"
	country_picker_btn.pressed.connect(_open_country_picker)
	row_country.add_child(country_picker_btn)
	var row_scenario = _chooser_row(setup, "☆ سناریو")
	# انتخابگر سناریو: دکمه سفارشی لمسی (مثل انتخابگر کشور) — OptionButton در اندروید با لمس اسکرول نمی‌شود
	scenario_select_option = OptionButton.new(); scenario_select_option.visible = false
	var active_scenario = str(state.get("scenario", {}).get("id", ScenarioManager.default_scenario)); var scenario_index = 0
	for scenario_id in ScenarioManager.get_scenario_ids():
		var definition = ScenarioManager.get_scenario(scenario_id); scenario_select_option.add_item("%s · %s" % [definition.get("name_fa", scenario_id), definition.get("difficulty_fa", "")]); scenario_select_option.set_item_metadata(scenario_select_option.item_count - 1, scenario_id)
		if scenario_id == active_scenario: scenario_index = scenario_select_option.item_count - 1
	scenario_select_option.select(scenario_index)
	scenario_picker_btn = Button.new()
	scenario_picker_btn.text = scenario_select_option.get_item_text(scenario_index)
	scenario_picker_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scenario_picker_btn.custom_minimum_size = Vector2(0, 56)
	scenario_picker_btn.add_theme_font_size_override("font_size", 22)
	scenario_picker_btn.tooltip_text = "لمس کنید و سناریو را با کشیدن انگشت بچرخانید"
	scenario_picker_btn.pressed.connect(_open_scenario_picker)
	row_scenario.add_child(scenario_picker_btn)
	scenario_description_lbl = Label.new(); scenario_description_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; scenario_description_lbl.modulate = TEXT_MUTED; scenario_description_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; setup.add_child(scenario_description_lbl); _on_scenario_option_changed(scenario_index)
	var start_button = _mk_btn(setup, "⚑ شروع فرماندهی", Vector2(340,62), _on_country_start_selected, "PrimaryAction"); start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; start_button.add_theme_font_size_override("font_size", 27)
	_pulse_control(start_button)
	# ✨ غبار طلایی شناور پشت کارت — فضای سینمایی
	var ambient = load("res://scripts/ui/hero_ambient.gd").new()
	hero_overlay.add_child(ambient)
	hero_overlay.move_child(ambient, 0)
	if not bool(SettingsManager.get_value("reduce_motion", false)):
		hero_overlay.modulate.a = 0.0
		create_tween().tween_property(hero_overlay, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# کارت خلاصه جبهه و دیپلماسی در برگه نقشه — جنگ‌ها، پیشنهادها و پیمان‌ها در یک نگاه.
func _build_map_intel_card():
	var state = GameState.state
	var world: Dictionary = state.get("world", {})
	_build_orgs_card(state)
	_build_rivalry_card(state)
	_build_ambassador_card(state)
	var card = _card("❖ گزارش جبهه و دیپلماسی")
	var wars: Dictionary = world.get("wars", {})
	var offers: Array = world.get("incoming_offers", [])
	var alliances: Array = world.get("alliances", [])
	var sanctions: Array = state.get("diplomacy", {}).get("sanctions", [])
	_row(card, "جنگ‌های جاری", PersianFormatter.to_persian_digits(str(wars.size())) + ("" if wars.is_empty() else " ⚔"), ACCENT_RED if wars.size() > 0 else ACCENT_GREEN)
	_row(card, "پیشنهادهای ورودی", PersianFormatter.to_persian_digits(str(offers.size())), ACCENT_GOLD if offers.size() > 0 else TEXT_MAIN)
	_row(card, "پیمان‌های دفاعی", PersianFormatter.to_persian_digits(str(alliances.size())), ACCENT_BLUE if alliances.size() > 0 else TEXT_MAIN)
	_row(card, "تحریم‌های فعال", PersianFormatter.to_persian_digits(str(sanctions.size())), ACCENT_ORANGE if sanctions.size() > 0 else TEXT_MAIN)
	var hint = Label.new(); hint.text = "◉ برای جزئیات و اقدام، کشوری را روی نقشه لمس کنید."; hint.add_theme_font_size_override("font_size", 19); hint.modulate = TEXT_FAINT; card.add_child(hint)

func _refresh_map_context_panel():
	if not is_instance_valid(map_context_host):return
	for child in map_context_host.get_children():map_context_host.remove_child(child);child.queue_free()
	var state=GameState.state;var player_id=str(state.get("world",{}).get("player_country",WorldManager.default_country))
	if not selected_map_route.is_empty():
		var route_type = str(selected_map_route.get("type",""))
		var is_disrupted = route_type == "trade_disrupted" or float(selected_map_route.get("volume",0.5)) < 0
		var route_card=_card("🗺️ کریدور انتخابی%s" % (" ⚠️ مختل" if is_disrupted else ""),map_context_host)
		_row(route_card,"نوع",_map_overlay_name(route_type))
		_row(route_card,"مسیر",str(selected_map_route.get("label","مسیر راهبردی")))
		_bar(route_card,"ظرفیت نسبی",abs(float(selected_map_route.get("volume",0.5))))
		if is_disrupted:
			_row(route_card,"وضعیت","🚫 مختل شده - حمله فعال",Color(1.0,0.3,0.3))
		# اطلاعات گلوگاه اگر باشد
		if selected_map_route.has("chokepoint") and bool(selected_map_route.get("chokepoint",false)):
			_row(route_card,"گلوگاه","⭐ %s - ۶ گلوگاه جهانی" % str(selected_map_route.get("chokepoint_id","")),Color(1.0,0.78,0.18))
		var route_hint=Label.new()
		route_hint.text="جنگ و اختلال مسیر می‌تواند صادرات، واردات و اتصال ملی را کاهش دهد. روی نقشه کلیک کن و عملیات را انتخاب کن - همه عملیات نقشه‌محور و قابل مشاهده است."
		route_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;route_hint.modulate=Color(0.72,0.81,0.87);route_card.add_child(route_hint)

		# === پنل عملیات نقشه‌محور - حمله به مسیر تجاری ===
		var ops_card = _card("⚔️ عملیات نقشه‌محور - حمله به مسیر",map_context_host)
		var ops_hint = Label.new()
		ops_hint.text="مثل دنیای واقعی: محاصره دریایی، شبیخون، مین‌گذاری، خرابکاری، حمله پهپادی، سایبری، اسکورت محافظتی - همه روی نقشه قابل اجرا و مشاهده است."
		ops_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		ops_hint.modulate=Color(0.85,0.75,0.55)
		ops_card.add_child(ops_hint)

		var ops_grid = GridContainer.new()
		ops_grid.columns = 2
		ops_grid.add_theme_constant_override("h_separation",8)
		ops_grid.add_theme_constant_override("v_separation",8)
		ops_card.add_child(ops_grid)

		# استخراج کشورهای مسیر
		var from_c = str(selected_map_route.get("from_country",""))
		var to_c = str(selected_map_route.get("to_country",""))
		var route_id = str(selected_map_route.get("label", selected_map_route.get("from_country","") + "_" + selected_map_route.get("to_country","")))
		var r_type = route_type if route_type != "trade_disrupted" else "trade"

		# دکمه‌های حمله - بر اساس نوع مسیر
		var attack_ops = []
		if r_type == "trade" or r_type == "trade_disrupted":
			attack_ops = [
				["raid","🏴‍☠️ شبیخون تجاری","حمله سریع به کاروان - غنیمت و اختلال ۱۵ روزه"],
				["blockade","🚫 محاصره","بستن کامل مسیر ۹۰ روزه - نیاز به ناوگان"],
				["sabotage","💣 خرابکاری","انفجار پل/خط لوله - ۳۰ روز"],
				["drone_strike","🛸 پهپاد انتحاری","حمله دقیق پهپادی - کم‌هزینه"],
				["cyber","💻 سایبری","اخلال سیستم ردیابی - ۱۰ روز"],
				["protect","🛡️ اسکورت محافظتی","محافظت از مسیر خودی +۱۰٪ تجارت"]
			]
		elif r_type == "sea":
			attack_ops = [
				["blockade","⚓ محاصره دریایی","ناوگان دریایی مسیر را می‌بندد"],
				["mine","💥 مین‌گذاری","مین دریایی - ۱۸۰ روز خطر"],
				["raid","🏴‍☠️ دزدی دریایی","حمله قایق تندرو"],
				["protect","🛡️ اسکورت دریایی","ناوچه اسکورت"]
			]
		elif r_type == "land":
			attack_ops = [
				["sabotage","💣 خرابکاری زمینی","انفجار ریل/جاده"],
				["raid","🏴‍☠️ کمین","کمین به کاروان زمینی"],
				["blockade","🚧 ایست بازرسی","بستن مرز"],
				["protect","🛡️ گشت مرزی","گشت و حفاظت"]
			]
		elif r_type == "air":
			attack_ops = [
				["cyber","💻 اخلال رادار","اخلال GPS و رادار"],
				["drone_strike","🛸 رهگیری هوایی","پهپاد رهگیر"],
				["protect","🛡️ اسکورت هوایی","جنگنده اسکورت"]
			]
		else:
			attack_ops = [
				["raid","⚔️ حمله","عملیات نظامی"],
				["sabotage","💣 خرابکاری","خرابکاری"],
				["protect","🛡️ حفاظت","حفاظت"]
			]

		for op in attack_ops:
			var op_id = str(op[0])
			var op_title = str(op[1])
			var op_desc = str(op[2])
			var btn = Button.new()
			btn.text = op_title
			btn.custom_minimum_size = Vector2(210, 48)
			btn.tooltip_text = op_desc
			# بررسی امکان اجرا - آمادگی نظامی
			var can_attack = float(state.get("military",{}).get("readiness",0.6)) >= 0.35
			btn.disabled = not can_attack
			if not can_attack:
				btn.tooltip_text += " - آمادگی نظامی کم (حداقل ۳۵٪)"
			btn.pressed.connect(FeedbackManager.play_click)
			btn.pressed.connect(_on_trade_route_attack.bind(route_id, r_type, op_id, from_c, to_c, op_title))
			_mark_decision_button(btn, "tradeatt:" + str(route_id) + ":" + str(r_type))
			ops_grid.add_child(btn)

		# گلوگاه‌های ۶گانه - عملیات ویژه
		if selected_map_route.has("chokepoint_id") or r_type == "sea":
			var choke_card = _card("🌊 گلوگاه‌های جهانی - ۶ نقطه راهبردی",map_context_host)
			var choke_hint = Label.new()
			choke_hint.text="هرمز، سوئز، باب‌المندب، مالاکا، پاناما، جبل‌الطارق - کنترل این تنگه‌ها = کنترل تجارت جهانی. حمله به این نقاط تورم جهانی ایجاد می‌کند."
			choke_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			choke_hint.modulate=Color(0.72,0.81,0.87)
			choke_card.add_child(choke_hint)
			var choke_grid = GridContainer.new()
			choke_grid.columns = 2
			choke_card.add_child(choke_grid)
			var choke_ops = [
				["hormuz","هرمز - ۲۰٪ نفت جهان"],
				["suez","سوئز - ۱۲٪ تجارت"],
				["bab_el_mandeb","باب‌المندب - دریای سرخ"],
				["malacca","مالاکا - آسیا-اروپا"],
				["panama","پاناما - اقیانوس اطلس/آرام"],
				["gibraltar","جبل‌الطارق - مدیترانه"]
			]
			for choke_def in choke_ops:
				var choke_id = choke_def[0]
				var choke_name = choke_def[1]
				var choke_btn = Button.new()
				choke_btn.text = "🚫 محاصره %s" % choke_name
				choke_btn.custom_minimum_size = Vector2(230, 42)
				choke_btn.pressed.connect(FeedbackManager.play_click)
				choke_btn.pressed.connect(_on_chokepoint_attack.bind(choke_id, "blockade", choke_name))
				_mark_decision_button(choke_btn, "choke:" + str(choke_id))
				choke_grid.add_child(choke_btn)

		var route_actions = HBoxContainer.new()
		route_card.add_child(route_actions)
		_mk_btn(route_actions, "🗺️ تمرکز روی مسیر", Vector2(160,40), _on_map_camera_route_focus)
	if selected_world_country==player_id:_build_map_player_context(state,player_id,map_context_host)
	else:_build_selected_country_card(state,selected_world_country,map_context_host)
	if not bool(SettingsManager.get_value("reduce_motion",false)):
		for child in map_context_host.get_children():
			if child is Control:child.modulate.a=0.0;create_tween().tween_property(child,"modulate:a",1.0,0.14)

func _build_map_player_context(state: Dictionary, player_id: String, parent_override=null):
	var profile = WorldManager.get_country(player_id)
	var national = _card("⌂ کشور شما · %s" % str(profile.get("name_fa", player_id)),parent_override)
	_row(national, "پایتخت", str(profile.get("capital_fa", "")))
	_row(national, "جمعیت", PersianFormatter.format_large(float(state.get("population",{}).get("total",0))) + " نفر")
	_row(national, "تولید داخلی", PersianFormatter.format_money(float(state.get("economy",{}).get("gdp",0))))
	_row(national, "تقسیمات اداری", PersianFormatter.to_persian_digits(str(CountryGeographyManager.get_unit_count(player_id))))
	_bar(national, "رضایت", float(state.get("population",{}).get("happiness",0.6)))
	_bar(national, "زیرساخت", float(state.get("infrastructure",{}).get("quality",0.55)))
	_bar(national, "امنیت", float(state.get("security",{}).get("public_security",0.65)))
	if selected_country_unit != "" and not CountryGeographyManager.get_unit(player_id, selected_country_unit).is_empty():
		_build_selected_national_unit(state, player_id, selected_country_unit,parent_override)

	# === پنل نقشه‌محور پیشرفته - جبهه‌ها و تدارکات ===
	var mil = state.get("military", {})
	var warfare = state.get("trade_route_warfare", {})
	var world = state.get("world", {})
	var fronts = mil.get("fronts_detail", {}).get("active_fronts", []) if mil.has("fronts_detail") else []
	var logi = mil.get("logistics_detail", {})

	if not fronts.is_empty() or not world.get("wars", {}).is_empty():
		var front_card = _card("⚔️ جبهه‌های فعال - نقشه‌محور", parent_override)
		_row(front_card, "تعداد جبهه", PersianFormatter.to_persian_digits(str(fronts.size() if not fronts.is_empty() else world.get("wars", {}).size())))
		if not logi.is_empty():
			_bar(front_card, "ذخیره سوخت", float(logi.get("fuel_stock_days", 25.0))/30.0)
			_bar(front_card, "ذخیره مهمات", float(logi.get("ammo_stock_days", 20.0))/20.0)
			_bar(front_card, "آسیب‌پذیری تدارکات", float(logi.get("supply_line_vulnerability", 0.30)))
			_row(front_card, "کاروان‌ها", PersianFormatter.to_persian_digits(str(logi.get("convoy_trucks", 800))))
		var front_hint = Label.new()
		front_hint.text = "خط مقدم روی نقشه با فلش پیشروی/عقب‌نشینی، خط تدارکات نقطه‌چین از پایتخت به جبهه با رنگ سبز/زرد/قرمز بر اساس امنیت - کامیون‌های متحرک روی مسیر دیده می‌شود"
		front_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		front_hint.modulate = Color(0.72,0.81,0.87)
		front_card.add_child(front_hint)

	# پنل مسیرهای تجاری مختل
	if not warfare.get("attacks", []).is_empty() or not warfare.get("chokepoints", {}).is_empty():
		var warfare_card = _card("🚢 جنگ مسیرهای تجاری - زنده روی نقشه", parent_override)
		_row(warfare_card, "حملات فعال", PersianFormatter.to_persian_digits(str(warfare.get("attacks", []).size())))
		_row(warfare_card, "گلوگاه مسدود", PersianFormatter.to_persian_digits(str(warfare.get("chokepoints", {}).size())))
		_bar(warfare_card, "سطح دزدی دریایی", float(warfare.get("piracy_level", 0.10)))
		_bar(warfare_card, "اثر محاصره", float(warfare.get("blockade_effectiveness", 0.0)))
		_row(warfare_card, "خسارت اقتصادی", PersianFormatter.format_money(float(warfare.get("economic_damage", 0.0))))
		var warfare_hint = Label.new()
		warfare_hint.text = "مسیرهای مختل قرمز چشمک‌زن با انفجار وسط، گلوگاه مسدود با ضربان قرمز و 🚫 - روی هر خط کلیک کن و عملیات شبیخون/محاصره/مین/اسکورت اجرا کن"
		warfare_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warfare_hint.modulate = Color(0.95,0.5,0.5)
		warfare_card.add_child(warfare_hint)

	var action_card = _card("◈ اقدام زمینه‌ای از روی نقشه",parent_override)
	var action_hint = Label.new(); action_hint.text = "اقدام‌های پرتکرار همان‌جا که مسئله را می‌بینید اجرا می‌شوند؛ نتیجه همچنان از موتور اتمی عبور می‌کند."; action_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; action_hint.modulate = Color(0.67,0.79,0.85); action_card.add_child(action_hint)
	var action_grid = GridContainer.new(); action_grid.columns = 3; action_card.add_child(action_grid)
	var actions = [["road_maintenance","نگهداری راه‌ها"],["improve_drainage","تقویت زهکشی"],["buy_snowplows","خرید برف‌روب"],["stock_road_salt","ذخیره نمک جاده"],["winter_training","رزمایش زمستانی"],["cooling_centers","مراکز خنک‌کننده"]]
	for action in actions:
		var check = SeasonalManager.can_action(state, action[0]); var button = Button.new(); button.text = action[1]; button.custom_minimum_size = Vector2(190,46); button.disabled = not check.valid; button.tooltip_text = "" if check.valid else str(check.reason); button.pressed.connect(FeedbackManager.play_click); button.pressed.connect(_on_map_municipal_action.bind(str(action[0]),str(action[1]))); _mark_decision_button(button, "muni:" + str(action[0])); action_grid.add_child(button)
	var open_row = HBoxContainer.new(); action_card.add_child(open_row)
	_mk_btn(open_row, "مرکز پروژه‌های ملی", Vector2(220,46), _switch_tab.bind("projects"))
	_mk_btn(open_row, "مدیریت دفاع", Vector2(180,46), _switch_tab.bind("military"))
	_mk_btn(open_row, "اقتصاد و بودجه", Vector2(190,46), _switch_tab.bind("economy"))

func _on_unified_layer_selected(index: int, selector: OptionButton):
	if index < 0 or index >= selector.item_count: return
	map_base_layer = str(selector.get_item_metadata(index))
	if is_instance_valid(current_unified_map): current_unified_map.set_base_layer(map_base_layer)

# ردیف برچسب‌دار انتخاب‌گرها در کارت قهرمان آغاز بازی.
# ─── انتخابگر لمسی کشور (جایگزین OptionButton غیرقابل اسکرول در اندروید) ───
func _open_country_picker():
	if country_picker_overlay != null and is_instance_valid(country_picker_overlay):
		country_picker_overlay.queue_free()
	var overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 500
	add_child(overlay)
	country_picker_overlay = overlay
	# پس‌زمینه تیره (لمس بیرون = بستن)
	var dim = ColorRect.new(); dim.color = Color(0.0, 0.01, 0.02, 0.78); dim.set_anchors_preset(Control.PRESET_FULL_RECT); dim.mouse_filter = Control.MOUSE_FILTER_STOP; overlay.add_child(dim)
	dim.gui_input.connect(func(ev):
		if ev is InputEventScreenTouch and ev.pressed:
			overlay.queue_free())
	# کارت مرکزی
	var card = PanelContainer.new(); card.theme_type_variation = "CommandPanel"
	card.anchor_left = 0.05; card.anchor_right = 0.95; card.anchor_top = 0.06; card.anchor_bottom = 0.94
	card.offset_left = 0; card.offset_right = 0; card.offset_top = 0; card.offset_bottom = 0
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(card)
	var vbox = VBoxContainer.new(); vbox.add_theme_constant_override("separation", 10); card.add_child(vbox)
	# سرتیتر + دکمه بستن
	var head = HBoxContainer.new(); head.add_theme_constant_override("separation", 8); vbox.add_child(head)
	var title = Label.new(); title.text = "🌍 انتخاب کشور"; title.add_theme_font_size_override("font_size", 27); title.modulate = ACCENT_GOLD; title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(title)
	var close_btn = Button.new(); close_btn.text = "✕"; close_btn.custom_minimum_size = Vector2(64, 54); close_btn.add_theme_font_size_override("font_size", 24); close_btn.theme_type_variation = "GhostButton"; head.add_child(close_btn)
	close_btn.pressed.connect(func(): overlay.queue_free())
	# راهنمای لمسی
	var hint = Label.new(); hint.text = "◉ لیست را با کشیدن انگشت اسکرول کنید · با جستجو سریع‌تر پیدا کنید"
	hint.add_theme_font_size_override("font_size", 16); hint.modulate = TEXT_FAINT; vbox.add_child(hint)
	# جستجوی فارسی
	var search = LineEdit.new(); search.placeholder_text = "جستجوی کشور (فارسی یا کد)…"; search.custom_minimum_size = Vector2(0, 48); search.add_theme_font_size_override("font_size", 21); vbox.add_child(search)
	# لیست اسکرول‌شونده لمسی
	var scroll = TouchScrollClass.new(); scroll.allow_vertical = true; scroll.allow_horizontal = false
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	vbox.add_child(scroll)
	var list = VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation", 4); scroll.add_child(list)
	# پر کردن لیست با فیلتر جستجو
	var rebuild := func(query: String):
		for child in list.get_children():
			child.queue_free()
		var q := query.strip_edges()
		var shown := 0
		for country_id in WorldManager.get_country_ids():
			var profile = WorldManager.get_country(country_id)
			var name := str(profile.get("name_fa", country_id))
			var capital := str(profile.get("capital_fa", ""))
			if q != "" and q not in name and q not in capital and q.to_upper() not in str(country_id):
				continue
			var item = Button.new()
			item.text = "▸ %s · %s" % [name, capital]
			item.custom_minimum_size = Vector2(0, 54)
			item.alignment = HORIZONTAL_ALIGNMENT_LEFT
			item.add_theme_font_size_override("font_size", 21)
			item.pressed.connect(_on_country_picked.bind(str(country_id), overlay))
			list.add_child(item)
			shown += 1
		if shown == 0:
			var empty = Label.new(); empty.text = "کشوری با این نام یافت نشد"; empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; empty.modulate = TEXT_FAINT; empty.add_theme_font_size_override("font_size", 19); list.add_child(empty)
	rebuild.call("")
	search.text_changed.connect(rebuild)
	search.grab_focus()

func _on_country_picked(country_code: String, overlay: Control):
	# هماهنگ‌سازی با OptionButton داخلی برای سازگاری کامل با کد شروع بازی
	for i in range(country_select_option.item_count):
		if str(country_select_option.get_item_metadata(i)) == country_code:
			country_select_option.select(i)
			if is_instance_valid(country_picker_btn):
				country_picker_btn.text = country_select_option.get_item_text(i)
			break
	if is_instance_valid(overlay):
		overlay.queue_free()
	FeedbackManager.play_click()

func _chooser_row(parent, caption: String) -> HBoxContainer:
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 10); parent.add_child(row)
	var cap = Label.new(); cap.text = caption; cap.custom_minimum_size = Vector2(150,0); cap.add_theme_font_size_override("font_size", 23); cap.modulate = TEXT_MUTED; cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER; row.add_child(cap)
	return row

# چیپ‌های لنز نقشه: کلیک، حالت فعال را بین چیپ‌ها پخش می‌کند و صفحه بازسازی نمی‌شود.
func _on_map_lens_chip(layer: String):
	map_base_layer = layer
	if is_instance_valid(current_unified_map): current_unified_map.set_base_layer(layer)
	if is_instance_valid(map_control_flow):
		for chip in map_control_flow.get_children():
			if chip is Button and chip.has_meta("lens_layer"):
				var on = str(chip.get_meta("lens_layer")) == layer
				chip.theme_type_variation = "LensChipActive" if on else "LensChip"
				chip.set_pressed_no_signal(on)

func _on_advanced_map_mode(mode: String):
	map_advanced_mode = mode
	map_advanced_start_country = ""
	map_advanced_start_unit = ""
	# بازخورد به کاربر
	var mode_names = {
		"select":"🎯 حالت انتخاب",
		"battle_plan":"⚔️ طرح نبرد - مبدا خودی، مقصد دشمن را انتخاب کن",
		"build_road":"🛣️ ساخت جاده - دو شهر را انتخاب کن",
		"build_rail":"🚂 راه‌آهن - دو شهر",
		"build_fort":"🏰 استحکامات - استان مرزی خودی",
		"build_depot":"📦 انبار - استان خودی",
		"build_airfield":"✈️ باند - استان خودی",
		"build_radar":"📡 رادار - استان خودی"
	}
	_toast(mode_names.get(mode, mode))
	# ویژوال برای حالت فعال - همه دکمه‌ها را به‌روز کن
	if is_instance_valid(map_control_flow):
		for child in map_control_flow.get_parent().get_parent().get_children():
			if child is GridContainer:
				for btn in child.get_children():
					if btn is Button and btn.has_meta("advanced_mode"):
						var is_active = str(btn.get_meta("advanced_mode")) == mode
						btn.theme_type_variation = "LensChipActive" if is_active else "LensChip"
						btn.set_pressed_no_signal(is_active)

func _on_map_search(edit: LineEdit):
	var query = str(edit.text).strip_edges()
	if query.is_empty():
		_toast("🔍 نام کشور یا شهر فارسی را وارد کن")
		return
	# جستجوی کشورها - فارسی
	var found_country = ""
	var found_city = {}
	var found_unit = {}
	var lower_query = query.to_lower()

	# جستجوی کشور
	for code in WorldManager.get_country_ids():
		var name_fa = WorldManager.get_country_name(code)
		if lower_query in name_fa.to_lower() or lower_query in code.to_lower():
			found_country = code
			break

	# جستجوی شهر اگر کشور پیدا نشد یا همراه کشور
	if found_country == "":
		# جستجوی تمام شهرها
		for code in WorldManager.get_country_ids():
			var cities = CountryGeographyManager.get_cities(code)
			for city in cities:
				var city_name = str(city.get("name_fa",""))
				if lower_query in city_name.to_lower():
					found_country = code
					found_city = city
					break
			if found_country != "":
				break

	# اگر هنوز پیدا نشد، جستجوی استان
	if found_country == "":
		for code in WorldManager.get_country_ids():
			var units = CountryGeographyManager.get_units(code)
			for unit in units:
				var unit_name = str(unit.get("name_fa",""))
				if lower_query in unit_name.to_lower():
					found_country = code
					found_unit = unit
					break
			if found_country != "":
				break

	if found_country == "":
		_toast("❌ '%s' پیدا نشد - نام فارسی کشور/شهر/استان را وارد کن (مثلا ایران، تهران، اصفهان)" % query)
		return

	# تمرکز روی کشور/شهر پیدا شده
	selected_world_country = found_country
	if not found_city.is_empty():
		selected_country_unit = str(found_city.get("unit_id",""))
		_toast("✅ شهر پیدا شد: %s در %s" % [str(found_city.get("name_fa","")), WorldManager.get_country_name(found_country)])
	elif not found_unit.is_empty():
		selected_country_unit = str(found_unit.get("id",""))
		_toast("✅ استان پیدا شد: %s در %s" % [str(found_unit.get("name_fa","")), WorldManager.get_country_name(found_country)])
	else:
		selected_country_unit = ""
		_toast("✅ کشور پیدا شد: %s" % WorldManager.get_country_name(found_country))

	if is_instance_valid(current_unified_map):
		current_unified_map.focus_country(found_country)

	# اگر شهر پیدا شد، زوم بیشتر
	if not found_city.is_empty() and is_instance_valid(current_unified_map):
		# زوم به شهر - کمی بیشتر
		current_unified_map.zoom_level = clamp(current_unified_map.zoom_level * 1.8, 5.0, 20.0)

	call_deferred("_refresh_unified_map_context")
	# مقایسه دو استان - اگر قبلا یکی انتخاب شده بود
	if not found_unit.is_empty() and not _comparison_unit_a.is_empty() and _comparison_unit_b.is_empty():
		_comparison_unit_b = str(found_unit.get("id",""))
		_toast("📊 مقایسه فعال: %s vs %s" % [_comparison_unit_a, _comparison_unit_b])
		call_deferred("_show_comparison_panel")

func _show_comparison_panel():
	# نمایش مقایسه دو استان - ۳۳ سیستم کنار هم
	if _comparison_unit_a.is_empty() or _comparison_unit_b.is_empty():
		return
	var state = GameState.state
	var country_a = _comparison_country_a if not _comparison_country_a.is_empty() else selected_world_country
	var country_b = _comparison_country_b if not _comparison_country_b.is_empty() else selected_world_country
	var metrics_a = CountryGeographyManager.get_unit_metrics(country_a, _comparison_unit_a, state)
	var metrics_b = CountryGeographyManager.get_unit_metrics(country_b, _comparison_unit_b, state)
	if metrics_a.is_empty() or metrics_b.is_empty():
		_toast("❌ مقایسه ممکن نیست - استان‌ها از کشورهای مختلف")
		return

	var compare_card = _card("📊 مقایسه دو استان - نقشه‌محور", map_context_host)
	var header = HBoxContainer.new()
	compare_card.add_child(header)
	var col_a = VBoxContainer.new(); col_a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col_b = VBoxContainer.new(); col_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(col_a)
	header.add_child(col_b)

	var title_a = Label.new(); title_a.text = "A: %s" % metrics_a.get("name_fa",""); title_a.modulate = Color(0.4,0.85,1.0); col_a.add_child(title_a)
	var title_b = Label.new(); title_b.text = "B: %s" % metrics_b.get("name_fa",""); title_b.modulate = Color(1.0,0.85,0.4); col_b.add_child(title_b)

	var systems_to_compare = ["population","gdp","infrastructure","satisfaction","security","agriculture","industry","health","education","military_score"]
	for sys_key in systems_to_compare:
		var row = HBoxContainer.new()
		compare_card.add_child(row)
		var label = Label.new(); label.text = sys_key; label.custom_minimum_size = Vector2(110,0); row.add_child(label)
		var val_a = float(metrics_a.get(sys_key,0.5))
		var val_b = float(metrics_b.get(sys_key,0.5))
		var bar_a = ProgressBar.new(); bar_a.max_value = 1.0; bar_a.value = val_a; bar_a.custom_minimum_size = Vector2(140,14); row.add_child(bar_a)
		var bar_b = ProgressBar.new(); bar_b.max_value = 1.0; bar_b.value = val_b; bar_b.custom_minimum_size = Vector2(140,14); row.add_child(bar_b)
		var diff = val_a - val_b
		var diff_label = Label.new(); diff_label.text = "%+.0f%%" % (diff*100.0); diff_label.modulate = Color(0.2,0.85,0.4) if diff>0 else Color(0.95,0.25,0.25) if diff<0 else Color(0.7,0.7,0.7); row.add_child(diff_label)

	var clear_btn = Button.new(); clear_btn.text = "❌ پاک کردن مقایسه"; clear_btn.pressed.connect(_on_clear_comparison); compare_card.add_child(clear_btn)

func _on_clear_comparison():
	_comparison_unit_a = ""
	_comparison_unit_b = ""
	_comparison_country_a = ""
	_comparison_country_b = ""
	_toast("📊 مقایسه پاک شد")
	call_deferred("_refresh_unified_map_context")

func _on_set_comparison_a(country_code: String, unit_id: String, name_fa: String):
	_comparison_country_a = country_code
	_comparison_unit_a = unit_id
	_toast("📊 A انتخاب شد: %s - حالا استان دوم را برای مقایسه انتخاب کن" % name_fa)
	if not _comparison_unit_b.is_empty():
		call_deferred("_show_comparison_panel")
	else:
		call_deferred("_refresh_unified_map_context")

func _on_set_comparison_b(country_code: String, unit_id: String, name_fa: String):
	_comparison_country_b = country_code
	_comparison_unit_b = unit_id
	_toast("📊 B انتخاب شد: %s" % name_fa)
	if not _comparison_unit_a.is_empty():
		call_deferred("_show_comparison_panel")
	else:
		_toast("اول A را انتخاب کن")
		call_deferred("_refresh_unified_map_context")

func _on_unified_overlay_toggled(pressed: bool, layer: String):
	map_overlays[layer] = pressed
	if is_instance_valid(current_unified_map): current_unified_map.set_overlay(layer, pressed)

func _on_map_camera_command(command: String):
	if not is_instance_valid(current_unified_map): return
	match command:
		"in": current_unified_map.zoom_in()
		"out": current_unified_map.zoom_out()
		"home": current_unified_map.focus_player()
		"selected": current_unified_map.focus_selected()
		"world": current_unified_map.focus_world()

func _on_unified_view_changed(center: Vector2, zoom: float):
	map_camera_center = center; map_zoom = zoom

func _on_unified_country_selected(code: String):
	# حالت‌های پیشرفته نقشه‌محور - طرح نبرد و ساخت‌وساز با دو کلیک
	if map_advanced_mode != "select":
		if map_advanced_start_country == "":
			# کلیک اول - مبدا
			map_advanced_start_country = code
			map_advanced_start_unit = ""
			_toast("🎯 مبدا %s انتخاب شد - حالا مقصد را انتخاب کن (%s)" % [WorldManager.get_country_name(code), map_advanced_mode])
			call_deferred("_refresh_unified_map_context")
			return
		else:
			# کلیک دوم - مقصد و اجرای عملیات
			var from_c = map_advanced_start_country
			var to_c = code
			var mode = map_advanced_mode
			map_advanced_start_country = ""
			map_advanced_start_unit = ""

			var cmd = null
			if mode == "battle_plan":
				cmd = GameCommandClass.create_battle_plan(from_c, "", to_c, "", "offensive")
			elif mode.begins_with("build_"):
				var build_type = mode.replace("build_", "")
				cmd = GameCommandClass.create_construction(from_c, "", to_c, "", build_type)
			else:
				cmd = GameCommandClass.create_map_operation(to_c, mode, {})

			if cmd != null and _queue_decision(cmd, "🗺️ " + str(mode) + " از " + WorldManager.get_country_name(from_c) + " به " + WorldManager.get_country_name(to_c)):
				_toast("🗺️ «%s» از %s به %s ثبت شد — با پایان نوبت اجرا می‌شود" % [mode, WorldManager.get_country_name(from_c), WorldManager.get_country_name(to_c)])
				map_advanced_mode = "select"
				_switch_tab("map")
				return
			else:
				_toast("⚠️ عملیات نقشه‌محور ممکن نشد")
				map_advanced_mode = "select"

	selected_world_country = code; selected_country_unit = ""; selected_map_route = {}
	_toast("کشور انتخابی · " + WorldManager.get_country_name(code)); call_deferred("_refresh_unified_map_context")

func _on_unified_unit_selected(code: String, unit_id: String):
	# حالت پیشرفته - استان به استان
	if map_advanced_mode != "select":
		if map_advanced_start_country == "":
			map_advanced_start_country = code
			map_advanced_start_unit = unit_id
			var unit = CountryGeographyManager.get_unit(code, unit_id)
			_toast("🎯 مبدا %s - %s انتخاب شد - مقصد را انتخاب کن" % [WorldManager.get_country_name(code), str(unit.get("name_fa",""))])
			call_deferred("_refresh_unified_map_context")
			return
		else:
			var from_c = map_advanced_start_country
			var from_u = map_advanced_start_unit
			var to_c = code
			var to_u = unit_id
			var mode = map_advanced_mode
			map_advanced_start_country = ""
			map_advanced_start_unit = ""

			var cmd = null
			if mode == "battle_plan":
				# تعیین نوع طرح بر اساس فاصله و وضعیت
				var plan_type = "offensive"
				if from_c == to_c:
					plan_type = "defensive"
				elif WorldManager.get_country(to_c).get("military_power",0) > 80:
					plan_type = "encirclement"
				cmd = GameCommandClass.create_battle_plan(from_c, from_u, to_c, to_u, plan_type)
			elif mode.begins_with("build_"):
				var build_type = mode.replace("build_", "")
				cmd = GameCommandClass.create_construction(from_c, from_u, to_c, to_u, build_type)
			else:
				cmd = GameCommandClass.create_map_building(mode.replace("build_",""), code, unit_id)

			if cmd != null and _queue_decision(cmd, "🗺️ " + str(mode) + " از " + str(from_c) + " به " + str(to_c)):
				_toast("🗺️ «%s» از %s به %s ثبت شد — با پایان نوبت اجرا می‌شود" % [mode, from_c, to_c])
				map_advanced_mode = "select"
				_switch_tab("map")
				return
			else:
				_toast("⚠️ عملیات ممکن نشد")
				map_advanced_mode = "select"

	selected_world_country = code; selected_country_unit = unit_id; selected_map_route = {}
	var unit = CountryGeographyManager.get_unit(code, unit_id); _toast("ناحیه انتخابی · " + str(unit.get("name_fa", ""))); call_deferred("_refresh_unified_map_context")

func _on_unified_route_selected(route: Dictionary):
	selected_map_route = route.duplicate(true); call_deferred("_refresh_unified_map_context")

func _refresh_unified_map_context():
	if current_tab=="map":_refresh_map_context_panel()

func _on_map_municipal_action(action: String, title: String):
	if _queue_decision(GameCommandClass.create_municipal_action(action), "🏙️ اقدام نقشه: " + title):
		_toast("اقدام نقشه «%s» ثبت شد — با پایان نوبت اجرا می‌شود" % title); _switch_tab("map")

func _on_trade_route_attack(route_id: String, route_type: String, operation: String, from_c: String, to_c: String, title: String):
	var cmd = GameCommandClass.create_trade_route_attack(route_id, route_type, operation, from_c, to_c)
	if _queue_decision(cmd, "⚔️ " + title + " بر مسیر " + from_c + " → " + to_c):
		_toast("⚔️ %s بر مسیر %s → %s ثبت شد — با پایان نوبت اجرا می‌شود" % [title, from_c, to_c])
		_switch_tab("map")
	else:
		_toast("⚠️ عملیات مسیر تجاری ممکن نشد")

func _on_chokepoint_attack(chokepoint_id: String, action: String, title: String):
	var cmd = GameCommandClass.create_chokepoint_action(chokepoint_id, action)
	if _queue_decision(cmd, "🌊 عملیات " + action + " در " + title):
		_toast("🌊 عملیات %s در %s ثبت شد — با پایان نوبت اجرا می‌شود" % [action, title])
		_switch_tab("map")

func _on_map_operation(target_country: String, operation_type: String, title: String):
	var cmd = GameCommandClass.create_map_operation(target_country, operation_type, {})
	if _queue_decision(cmd, "🗺️ " + title + " روی " + _fa_country(target_country)):
		_toast("🗺️ %s روی %s ثبت شد — با پایان نوبت اجرا می‌شود" % [title, _fa_country(target_country)])
		_switch_tab("map")
	else:
		_toast("⚠️ عملیات نقشه‌محور ممکن نشد")

func _on_map_camera_route_focus():
	if is_instance_valid(current_unified_map) and not selected_map_route.is_empty():
		var from_lat = float(selected_map_route.get("from_lat", 0.0))
		var from_lon = float(selected_map_route.get("from_lon", 0.0))
		var to_lat = float(selected_map_route.get("to_lat", 0.0))
		var to_lon = float(selected_map_route.get("to_lon", 0.0))
		var center_lat = (from_lat + to_lat) / 2.0
		var center_lon = (from_lon + to_lon) / 2.0
		# تبدیل به نقطه نقشه
		current_unified_map.focus_world() # ساده‌سازی - بعدا focus به مسیر
		_toast("🗺️ تمرکز روی مسیر %s" % str(selected_map_route.get("label","")))

func _map_overlay_name(layer: String) -> String:
	return {"wars":"جنگ","alliances":"اتحاد","trade":"تجارت","air":"هوایی","sea":"دریایی","land":"زمینی"}.get(layer,"راهبردی")

# ============================================================
# کارت‌های زمینه‌ای نقشه؛ بدون بازسازی خود نقشه به‌روزرسانی می‌شوند.
# ============================================================
func _build_selected_national_unit(state: Dictionary, code: String, unit_id: String, parent_override=null):
	var metrics = CountryGeographyManager.get_unit_metrics(code, unit_id, state)
	if metrics.is_empty(): return
	var title = "📍 %s %s" % [metrics.get("type_fa", "ناحیه"), metrics.get("name_fa", "")]
	if metrics.get("capital", false): title += " — ناحیه پایتخت"
	var card = _card(title,parent_override)
	_row(card, "جمعیت برآوردی", PersianFormatter.format_large(float(metrics.get("population", 0))) + " نفر")
	_row(card, "سهم از جمعیت کشور", _fmt_pct(float(metrics.get("population_share", 0.0))))
	_row(card, "تولید داخلی برآوردی", PersianFormatter.format_money(float(metrics.get("gdp", 0))))
	_row(card, "GDP سرانه برآوردی", PersianFormatter.format_money(float(metrics.get("gdp_per_capita", 0))))
	_row(card, "مساحت برآوردی", PersianFormatter.format_large(float(metrics.get("area_km2", 0))) + " کیلومتر مربع")
	_row(card, "راه‌های برآوردی", PersianFormatter.format_large(float(metrics.get("roads_km", 0))) + " کیلومتر")

	# === ۳۳ سیستم - گروه‌بندی نقشه‌محور عمیق ===
	var econ_group = _card("💵 اقتصاد منطقه - نقشه‌محور", parent_override)
	_bar(econ_group, "کشاورزی", float(metrics.get("agriculture", 0.5)))
	_bar(econ_group, "صنعت", float(metrics.get("industry", 0.5)))
	_bar(econ_group, "تجارت", float(metrics.get("trade", 0.5)))
	_bar(econ_group, "گردشگری", float(metrics.get("tourism", 0.5)))
	_bar(econ_group, "بانک مرکزی", float(metrics.get("central_bank", 0.5)))
	_bar(econ_group, "بورس", float(metrics.get("stock_market", 0.5)))
	_bar(econ_group, "خرده‌فروشی", float(metrics.get("retail", 0.5)))
	_bar(econ_group, "سوخت", float(metrics.get("fuel_stations", 0.5)))

	var social_group = _card("👥 اجتماع منطقه", parent_override)
	_bar(social_group, "بهداشت", float(metrics.get("health", 0.5)))
	_bar(social_group, "آموزش", float(metrics.get("education", 0.5)))
	_bar(social_group, "رفاه", float(metrics.get("welfare", 0.5)))
	_bar(social_group, "خانواده", float(metrics.get("family", 0.5)))
	_bar(social_group, "ورزش جوانان", float(metrics.get("sports_youth", 0.5)))
	_bar(social_group, "قومیت (انسجام)", float(metrics.get("ethnicity", 0.5)))
	_bar(social_group, "فرهنگ", float(metrics.get("culture", 0.5)))

	var infra_group = _card("🏗️ زیرساخت منطقه", parent_override)
	_bar(infra_group, "زیرساخت", float(metrics.get("infrastructure", 0.0)))
	_bar(infra_group, "تاسیسات شهری", float(metrics.get("urban_facilities", 0.5)))
	_bar(infra_group, "خدمات عمومی", float(metrics.get("public_services", 0.5)))
	_bar(infra_group, "راه‌ها", float(metrics.get("transport_roads", 0.5)))
	_bar(infra_group, "سکونتگاه", float(metrics.get("settlements", 0.5)))
	_bar(infra_group, "محیط‌زیست", float(metrics.get("environment", 0.5)))
	_bar(infra_group, "صیادی", float(metrics.get("fisheries", 0.5)))
	_bar(infra_group, "میراث", float(metrics.get("heritage", 0.5)))

	var political_group = _card("🏛️ سیاست و امنیت منطقه", parent_override)
	_bar(political_group, "قضایی", float(metrics.get("judicial", 0.5)))
	_bar(political_group, "اطلاعات", float(metrics.get("intelligence", 0.5)))
	_bar(political_group, "اداره", float(metrics.get("administration", 0.5)))
	_bar(political_group, "انتخابات", float(metrics.get("elections", 0.5)))
	_bar(political_group, "ثبات سیاسی", float(metrics.get("politics", 0.5)))
	_bar(political_group, "آمار", float(metrics.get("statistics", 0.5)))
	_bar(political_group, "بحران", float(metrics.get("emergency", 0.5)))
	_bar(political_group, "رضایت", float(metrics.get("satisfaction", 0.0)))
	_bar(political_group, "امنیت", float(metrics.get("security", 0.0)))
	_bar(political_group, "نظامی", float(metrics.get("military_score", 0.0)))
	_bar(political_group, "فضا", float(metrics.get("space", 0.1)))
	_bar(political_group, "ایثارگران", float(metrics.get("veterans", 0.5)))

	# === عملیات نقشه‌محور روی استان/شهر ===
	var player_id = str(state.get("world",{}).get("player_country",""))
	var is_own = code == player_id
	var city_ops_card = _card("🗺️ عملیات نقشه‌محور - %s" % metrics.get("name_fa","ناحیه"), parent_override)
	var city_hint = Label.new()
	city_hint.text = "مثل دنیای واقعی: روی نقشه استان/شهر را انتخاب کن و عملیات بساز - استحکامات، پایگاه، جاده، فرودگاه"
	city_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	city_hint.modulate = Color(0.72,0.81,0.87)
	city_ops_card.add_child(city_hint)
	var city_grid = GridContainer.new()
	city_grid.columns = 2
	city_ops_card.add_child(city_grid)

	var city_ops = []
	if is_own:
		city_ops = [
			["fortify","🏰 استحکام‌سازی","ساخت سنگر و استحکامات - دفاع +۲۰٪"],
			["airfield","✈️ باند هوایی","ساخت باند فرودگاه اضطراری"],
			["depot","📦 انبار تدارکات","انبار سوخت و مهمات - تدارکات +۱۵٪"],
			["radar","📡 ایستگاه رادار","پوشش شناسایی +۲۰٪"],
			["factory","🏭 کارخانه","تولید محلی +"],
			["bunker","🛡️ پناهگاه","پناهگاه غیرنظامی - کاهش تلفات"]
		]
	else:
		city_ops = [
			["sabotage","💣 خرابکاری","انفجار پل/خط آهن در خاک دشمن"],
			["airstrike","✈️ بمباران","حمله هوایی به زیرساخت"],
			["drone_recon","🛸 شناسایی پهپادی","جمع‌آوری اطلاعات"],
			["psyops","📢 تبلیغات","پخش اعلامیه و جنگ روانی"],
			["special_ops","🎯 عملیات ویژه","کماندویی - ترور/گروگان"],
			["blockade","🚧 محاصره منطقه‌ای","بستن راه‌های منطقه"]
		]

	for op in city_ops:
		var btn = Button.new()
		btn.text = op[1]
		btn.tooltip_text = op[2]
		btn.custom_minimum_size = Vector2(200, 44)
		btn.pressed.connect(FeedbackManager.play_click)
		btn.pressed.connect(_on_map_operation.bind(code, op[0], op[1]))
		city_grid.add_child(btn)

	# دکمه مقایسه - نقشه‌محور پیشرفته
	var compare_row = HBoxContainer.new()
	city_ops_card.add_child(compare_row)
	var compare_btn_a = Button.new()
	compare_btn_a.text = "📊 انتخاب برای مقایسه A"
	compare_btn_a.custom_minimum_size = Vector2(180, 40)
	compare_btn_a.pressed.connect(_on_set_comparison_a.bind(code, unit_id, metrics.get("name_fa","")))
	compare_row.add_child(compare_btn_a)
	var compare_btn_b = Button.new()
	compare_btn_b.text = "📊 مقایسه با B"
	compare_btn_b.custom_minimum_size = Vector2(180, 40)
	compare_btn_b.pressed.connect(_on_set_comparison_b.bind(code, unit_id, metrics.get("name_fa","")))
	compare_row.add_child(compare_btn_b)

func _build_selected_country_card(state: Dictionary, target: String, parent_override=null):
	var profile = state.get("world", {}).get("countries", {}).get(target, WorldManager.get_country(target))
	var relation = float(state.get("diplomacy", {}).get("relations", {}).get(target, 50.0))
	var card = _card("◉ کشور انتخابی: %s" % _fa_country(target),parent_override)
	# نشان موضع رابطه، هم‌خط با سیستم نشان‌های HOI4
	var stance_row = HBoxContainer.new(); stance_row.add_theme_constant_override("separation", 9); card.add_child(stance_row)
	_pill(stance_row, _relation_word(relation), _color_for(relation / 100.0))
	var rel_lbl = Label.new(); rel_lbl.text = "امتیاز رابطه %s" % PersianFormatter.to_persian_digits("%.0f" % relation); rel_lbl.add_theme_font_size_override("font_size", 21); rel_lbl.modulate = TEXT_MUTED; rel_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER; stance_row.add_child(rel_lbl)
	var wars_now: Dictionary = state.get("world", {}).get("wars", {})
	if wars_now.has(target):
		_pill(stance_row, "در جنگ", ACCENT_RED)
	_row(card, "پایتخت", str(profile.get("capital_fa","")))
	_row(card, "منطقه", "%s / %s" % [_fa_geo_name(str(profile.get("region",""))),_fa_geo_name(str(profile.get("subregion","")))])
	_row(card, "جمعیت", PersianFormatter.format_large(float(profile.get("population",0)))+" نفر")
	_row(card, "تولید داخلی", PersianFormatter.format_money(float(profile.get("gdp", 0.0))))
	_row(card, "مساحت", PersianFormatter.format_large(float(profile.get("area_km2",0)))+" کیلومتر مربع")
	_row(card, "همسایگان زمینی", PersianFormatter.to_persian_digits(str(profile.get("borders",[]).size())))
	var air_count=0;var sea_count=0
	for route in MapLayerManager.get_static_routes("air"):
		if route.from_country==target or route.to_country==target:air_count+=1
	for route in MapLayerManager.get_static_routes("sea"):
		if route.from_country==target or route.to_country==target:sea_count+=1
	_row(card,"مسیرهای هوایی راهبردی",PersianFormatter.to_persian_digits(str(air_count)))
	_row(card,"مسیرهای دریایی راهبردی",PersianFormatter.to_persian_digits(str(sea_count)))
	_row(card, "قدرت نظامی", PersianFormatter.to_persian_digits("%.1f" % profile.get("military_power", 0.0)))
	_bar(card, "سطح فناوری", float(profile.get("tech_level", 0.0)))
	var wars: Dictionary = state.get("world", {}).get("wars", {})
	if wars.has(target):
		var war = wars[target]
		var progress = float(war.get("progress", 0.0))
		_row(card, "پیشروی جنگ", PersianFormatter.to_persian_digits("%+.1f" % progress), _color_for((progress + 100.0) / 200.0))
		_row(card, "تلفات نیروهای شما", PersianFormatter.format_large(float(war.get("player_losses", 0))))
		_row(card, "تلفات دشمن", PersianFormatter.format_large(float(war.get("enemy_losses", 0))))
	# پیشنهادهای ورودی از این کشور (رودمپ ۵): پاسخ مستقیم با پذیرش یا رد
	var incoming_offer = WorldManager.find_offer(state.get("world", {}), target)
	if not incoming_offer.is_empty():
		var offer_box = Label.new()
		offer_box.text = "📨 %s — %s" % [str(incoming_offer.get("offer_text", "پیشنهاد")), str(incoming_offer.get("message", ""))]
		offer_box.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		offer_box.modulate = Color(0.55, 0.85, 1.0)
		card.add_child(offer_box)
		var offer_buttons = HFlowContainer.new()
		offer_buttons.add_theme_constant_override("h_separation", 8)
		card.add_child(offer_buttons)
		for reply_def in [["accept_offer", "✓ پذیرفتن پیشنهاد"], ["reject_offer", "✕ رد پیشنهاد"]]:
			var reply_check = WorldManager.can_action(state, target, reply_def[0])
			var reply_button = Button.new()
			reply_button.text = reply_def[1]
			reply_button.theme_type_variation = "SuccessButton" if reply_def[0] == "accept_offer" else "DangerButton"
			reply_button.custom_minimum_size = Vector2(210, 50)
			reply_button.disabled = not reply_check.valid
			reply_button.tooltip_text = "" if reply_check.valid else str(reply_check.reason)
			reply_button.pressed.connect(FeedbackManager.play_click)
			reply_button.pressed.connect(_on_world_action.bind(target, reply_def[0], reply_def[1]))
			_mark_decision_button(reply_button, "dip:" + str(target) + ":" + str(reply_def[0]))
			offer_buttons.add_child(reply_button)
	# === بخش نقشه‌محور: اطلاعات جبهه و تدارکات ===
	if wars.has(target):
		var war = wars[target]
		var progress = float(war.get("progress", 0.0))
		var force_ratio = float(war.get("force_ratio", 1.0)) if war.has("force_ratio") else 1.0
		var air_sup = float(war.get("air_superiority", 0.5)) if war.has("air_superiority") else 0.5
		var daily_prog = float(war.get("daily_progress", 0.0)) if war.has("daily_progress") else 0.0
		var war_card = _card("⚔️ جبهه جنگ - نقشه‌محور", parent_override)
		_row(war_card, "پیشروی", "%+.1f%%" % progress, _color_for((progress + 100.0) / 200.0))
		_bar(war_card, "نسبت قوا", clamp(force_ratio/2.0, 0.0, 1.0))
		_bar(war_card, "برتری هوایی", air_sup)
		_row(war_card, "پیشروی روزانه", "%+.2f km" % daily_prog)
		# اطلاعات تدارکات از سیستم نظامی
		var mil_detail = state.get("military", {}).get("logistics_detail", {})
		if not mil_detail.is_empty():
			_bar(war_card, "ذخیره سوخت", float(mil_detail.get("fuel_stock_days", 25.0))/30.0)
			_bar(war_card, "ذخیره مهمات", float(mil_detail.get("ammo_stock_days", 20.0))/20.0)
			_bar(war_card, "آسیب‌پذیری تدارکات", float(mil_detail.get("supply_line_vulnerability", 0.30)))
			_row(war_card, "کاروان‌ها", PersianFormatter.to_persian_digits(str(mil_detail.get("convoy_trucks", 800))))
		# جبهه‌های تفصیلی
		var fronts = state.get("military", {}).get("fronts_detail", {}).get("active_fronts", []) if state.get("military",{}).has("fronts_detail") else []
		for front in fronts:
			if str(front.get("target","")) == target:
				_row(war_card, "زمین", str(front.get("terrain","دشت")))
				_row(war_card, "هوا", str(front.get("weather","آفتابی")))
				_bar(war_card, "تدارکات جبهه", float(front.get("supply_status",0.5)))
				break

		# عملیات نقشه‌محور روی کشور دشمن
		var map_ops_card = _card("🗺️ عملیات نقشه‌محور روی %s" % _fa_country(target), parent_override)
		var map_hint = Label.new()
		map_hint.text = "مثل دنیای واقعی: حمله هوایی، محاصره دریایی، خرابکاری زیرساخت، پهپاد swarm، سایبری، تبلیغات - همه با کلیک روی نقشه"
		map_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		map_hint.modulate = Color(0.72,0.81,0.87)
		map_ops_card.add_child(map_hint)
		var map_ops_grid = GridContainer.new()
		map_ops_grid.columns = 2
		map_ops_card.add_child(map_ops_grid)
		var map_ops = [
			["airstrike","✈️ حمله هوایی","بمباران تاسیسات - هزینه ۱.۵ میلیارد"],
			["naval_blockade","⚓ محاصره دریایی","بستن بنادر - اثر بر تجارت"],
			["sabotage_infrastructure","💣 خرابکاری زیرساخت","انفجار پل/خط لوله"],
			["drone_swarm","🛸 پهپاد انبوه","۲۰ فروند پهپاد انتحاری"],
			["cyber_attack","💻 حمله سایبری","اخلال شبکه برق"],
			["propaganda","📢 جنگ روانی","تضعیف روحیه دشمن"],
			["humanitarian","🎁 کمک بشردوستانه","نفوذ نرم +۲"]
		]
		for op in map_ops:
			var btn = Button.new()
			btn.text = op[1]
			btn.tooltip_text = op[2]
			btn.custom_minimum_size = Vector2(210, 48)
			var can_op = float(state.get("military",{}).get("readiness",0.6)) >= 0.40
			btn.disabled = not can_op
			if not can_op:
				btn.tooltip_text += " - آمادگی کم"
			if op[0] == "airstrike" or op[0] == "drone_swarm":
				btn.theme_type_variation = "DangerButton"
			elif op[0] == "humanitarian":
				btn.theme_type_variation = "SuccessButton"
			btn.pressed.connect(FeedbackManager.play_click)
			btn.pressed.connect(_on_map_operation.bind(target, op[0], op[1]))
			map_ops_grid.add_child(btn)

	var action_grid = GridContainer.new()
	action_grid.columns = 3
	card.add_child(action_grid)
	var actions = [
		["improve_relations", "بهبود روابط"], ["trade_agreement", "توافق تجاری"],
		["end_trade_agreement", "پایان توافق تجاری"], ["form_alliance", "تشکیل اتحاد"],
		["leave_alliance", "خروج از اتحاد"], ["sanction", "اعمال تحریم"],
		["lift_sanction", "لغو تحریم"], ["negotiate_sanctions", "مذاکره تحریم"],
		["ultimatum", "اولتیماتوم"], ["declare_war", "اعلام جنگ"], ["offer_peace", "پیشنهاد صلح"]
	]
	for action_def in actions:
		var check = WorldManager.can_action(state, target, action_def[0])
		var button = Button.new()
		button.text = action_def[1]
		button.custom_minimum_size = Vector2(180, 48)
		button.disabled = not check.valid
		button.tooltip_text = "" if check.valid else str(check.reason)
		if action_def[0] == "declare_war":
			button.theme_type_variation = "DangerButton"
		elif action_def[0] == "offer_peace":
			button.theme_type_variation = "SuccessButton"
		button.pressed.connect(FeedbackManager.play_click)
		button.pressed.connect(_on_world_action.bind(target, action_def[0], action_def[1]))
		_mark_decision_button(button, "dip:" + str(target) + ":" + str(action_def[0]))
		action_grid.add_child(button)

# ─── انتخابگر لمسی سناریو (جایگزین OptionButton غیرقابل اسکرول در اندروید) ───
func _open_scenario_picker():
	if scenario_picker_overlay != null and is_instance_valid(scenario_picker_overlay):
		scenario_picker_overlay.queue_free()
	var overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 500
	add_child(overlay)
	scenario_picker_overlay = overlay
	var dim = ColorRect.new(); dim.color = Color(0.0, 0.01, 0.02, 0.78); dim.set_anchors_preset(Control.PRESET_FULL_RECT); dim.mouse_filter = Control.MOUSE_FILTER_STOP; overlay.add_child(dim)
	dim.gui_input.connect(func(ev):
		if ev is InputEventScreenTouch and ev.pressed:
			overlay.queue_free())
	var card = PanelContainer.new(); card.theme_type_variation = "CommandPanel"
	card.anchor_left = 0.12; card.anchor_right = 0.88; card.anchor_top = 0.25; card.anchor_bottom = 0.75
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(card)
	var vbox = VBoxContainer.new(); vbox.add_theme_constant_override("separation", 10); card.add_child(vbox)
	var head = HBoxContainer.new(); head.add_theme_constant_override("separation", 8); vbox.add_child(head)
	var title = Label.new(); title.text = "☆ انتخاب سناریو"; title.add_theme_font_size_override("font_size", 26); title.modulate = ACCENT_GOLD; title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(title)
	var close_btn = Button.new(); close_btn.text = "✕"; close_btn.custom_minimum_size = Vector2(60, 50); close_btn.add_theme_font_size_override("font_size", 22); close_btn.theme_type_variation = "GhostButton"; head.add_child(close_btn)
	close_btn.pressed.connect(func(): overlay.queue_free())
	var hint = Label.new(); hint.text = "◉ لیست را با کشیدن انگشت اسکرول کنید"
	hint.add_theme_font_size_override("font_size", 16); hint.modulate = TEXT_FAINT; vbox.add_child(hint)
	var scroll = TouchScrollClass.new(); scroll.allow_vertical = true; scroll.allow_horizontal = false
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	vbox.add_child(scroll)
	var list = VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation", 6); scroll.add_child(list)
	for i in range(scenario_select_option.item_count):
		var scenario_id = str(scenario_select_option.get_item_metadata(i))
		var item = Button.new()
		item.text = "▸ " + scenario_select_option.get_item_text(i)
		item.custom_minimum_size = Vector2(0, 58)
		item.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item.add_theme_font_size_override("font_size", 21)
		item.pressed.connect(_on_scenario_picked.bind(i, overlay))
		list.add_child(item)

func _on_scenario_picked(index: int, overlay: Control):
	if scenario_select_option != null and index >= 0 and index < scenario_select_option.item_count:
		scenario_select_option.select(index)
		if is_instance_valid(scenario_picker_btn):
			scenario_picker_btn.text = scenario_select_option.get_item_text(index)
		_on_scenario_option_changed(index)
	if is_instance_valid(overlay):
		overlay.queue_free()
	FeedbackManager.play_click()

func _on_scenario_option_changed(index: int):
	if scenario_select_option == null or index < 0 or index >= scenario_select_option.item_count:
		return
	var scenario_id = str(scenario_select_option.get_item_metadata(index))
	var definition = ScenarioManager.get_scenario(scenario_id)
	if scenario_description_lbl != null:
		scenario_description_lbl.text = "%s\nمهلت: %s روز | پاداش: %s تجربه" % [
			definition.get("description", ""),
			PersianFormatter.to_persian_digits(str(definition.get("deadline_days", 0))),
			PersianFormatter.to_persian_digits(str(definition.get("reward_xp", 0)))
		]

func _on_country_start_selected():
	if country_select_option == null or country_select_option.item_count == 0:
		return
	var country_id = str(country_select_option.get_item_metadata(country_select_option.selected))
	var scenario_id = ScenarioManager.default_scenario
	if scenario_select_option != null and scenario_select_option.item_count > 0:
		scenario_id = str(scenario_select_option.get_item_metadata(scenario_select_option.selected))
	var cmd = GameCommandClass.create_country_select(country_id, scenario_id)
	if _run_tick_with([cmd]):
		selected_world_country = country_id
		selected_country_unit = ""
		var profile = WorldManager.get_country(country_id); map_camera_center = GeographyManager.normalized_point(float(profile.get("lon",0.0)),float(profile.get("lat",0.0))); map_zoom = 2.2
		_toast("فرماندهی %s با سناریوی «%s» آغاز شد" % [WorldManager.get_country_name(country_id), ScenarioManager.get_scenario_name(scenario_id)])
		_switch_tab("map")

func _on_world_action(country: String, action: String, action_title: String):
	var cmd = GameCommandClass.create_diplomacy_action(country, action)
	if _queue_decision(cmd, "🌍 " + action_title + " درباره " + _fa_country(country)):
		_toast("🌍 «%s» درباره %s ثبت شد — با پایان نوبت اجرا می‌شود" % [action_title, _fa_country(country)])
		_switch_tab("map")

func _fa_geo_name(value:String)->String:
	return {"Africa":"آفریقا","Americas":"قاره آمریکا","Asia":"آسیا","Europe":"اروپا","Oceania":"اقیانوسیه","Northern Africa":"شمال آفریقا","Sub-Saharan Africa":"آفریقای جنوب صحرا","Eastern Africa":"شرق آفریقا","Middle Africa":"مرکز آفریقا","Southern Africa":"جنوب آفریقا","Western Africa":"غرب آفریقا","Northern Europe":"شمال اروپا","Eastern Europe":"شرق اروپا","Southern Europe":"جنوب اروپا","Western Europe":"غرب اروپا","Western Asia":"غرب آسیا","Central Asia":"آسیای مرکزی","Eastern Asia":"شرق آسیا","Southern Asia":"جنوب آسیا","South-Eastern Asia":"جنوب‌شرق آسیا","North America":"آمریکای شمالی","Central America":"آمریکای مرکزی","South America":"آمریکای جنوبی","Caribbean":"کارائیب","Australia and New Zealand":"استرالیا و نیوزیلند","Melanesia":"ملانزی","Micronesia":"میکرونزی","Polynesia":"پلی‌نزی"}.get(value,"پیرامون کشور")

func _fa_country(code: String) -> String:
	return WorldManager.get_country_name(code)

func _relation_word(v) -> String:
	if v >= 75: return "متحد"
	if v >= 55: return "دوستانه"
	if v >= 35: return "خنثی"
	if v >= 15: return "متشنج"
	return "متخاصم"

func _on_host_competitive():
	var country_id=str(GameState.state.get("country",{}).get("id",WorldManager.default_country))
	var result=P2PManager.host_competitive(network_player_name_edit.text,country_id,int(network_port_spin.value))
	_toast("🌐 لابی رقابتی ساخته شد" if result.success else "⚠️ "+str(result.reason));_refresh_network_status()

func _on_join_competitive():
	var country_id=str(GameState.state.get("country",{}).get("id",WorldManager.default_country))
	var result=P2PManager.join_competitive(network_address_edit.text,int(network_port_spin.value),network_player_name_edit.text,country_id)
	_toast("🌐 درخواست ورود رقابتی ارسال شد" if result.success else "⚠️ "+str(result.reason));_refresh_network_status()

func _on_campaign_ready():
	P2PManager.set_campaign_ready(true);_toast("✅ وضعیت آماده ثبت شد")

func _on_start_campaign():
	var result=P2PManager.start_competitive_campaign();_toast("🏁 کمپین چندکشوری آغاز شد" if result.success else "⚠️ "+str(result.reason));_refresh_network_status()

func _on_campaign_lobby(lobby:Dictionary):
	if campaign_lobby_lbl==null or not is_instance_valid(campaign_lobby_lbl):return
	var names:Array=[]
	for player in lobby.get("players",{}).values():names.append("%s: %s %s"%[player.get("name","بازیکن"),WorldManager.get_country_name(str(player.get("country_id",""))),"✅" if player.get("ready",false) else "⏳"])
	campaign_lobby_lbl.text="لابی رقابتی: "+(" | ".join(names) if not names.is_empty() else "غیرفعال")
	_refresh_chat_visibility()

func _on_random_port():
	# پورت تصادفی در بازه امن (شبیه‌سازی چند تلاش برای یافتن پورت آزاد)
	var chosen := P2PManager.DEFAULT_PORT
	for attempt in range(20):
		var candidate := 20000 + (int(Time.get_unix_time_from_system()) * 7 + attempt * 13) % 40000
		var probe = ENetMultiplayerPeer.new()
		if probe.create_server(candidate, 4) == OK:
			probe.close()
			chosen = candidate
			break
	if network_port_spin != null:
		network_port_spin.value = chosen
		_toast("🎲 پورت پیشنهادی: " + PersianFormatter.to_persian_digits(str(chosen)))
	else:
		_toast("🎲 پورت پیشنهادی: " + PersianFormatter.to_persian_digits(str(chosen)))

# ── اتصال رایگان از راه دور (اینترنت): میزبانی راه دور با کد اتصال ──
func _build_remote_card():
	var card = _card("🌐 اتصال رایگان از راه دور (اینترنت)")
	var hint = Label.new()
	hint.text = "بدون سرور و بدون هزینه: با UPnP و کشف آدرس عمومی، دوستانتان حتی از شهر دیگر می‌توانند وصل شوند. اگر روتر اجازه ندهد، از VPN رایگان استفاده کنید (راهنما)."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 15); hint.modulate = TEXT_FAINT
	card.add_child(hint)
	# میزبانی راه دور
	var host_btn = Button.new(); host_btn.text = "🚀 شروع میزبانی راه دور"
	host_btn.custom_minimum_size = Vector2(0, 48); host_btn.add_theme_font_size_override("font_size", 17)
	host_btn.theme_type_variation = "PrimaryButton"
	host_btn.pressed.connect(FeedbackManager.play_click); host_btn.pressed.connect(_on_host_remote)
	card.add_child(host_btn)
	remote_upnp_lbl = Label.new()
	remote_upnp_lbl.add_theme_font_size_override("font_size", 15); remote_upnp_lbl.modulate = TEXT_MUTED
	card.add_child(remote_upnp_lbl)
	remote_code_lbl = Label.new()
	remote_code_lbl.add_theme_font_size_override("font_size", 22); remote_code_lbl.modulate = ACCENT_GOLD
	remote_code_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(remote_code_lbl)
	var sep = HSeparator.new(); card.add_child(sep)
	# اتصال با کد
	var join_lbl = Label.new(); join_lbl.text = "اتصال با کد میزبان:"
	join_lbl.add_theme_font_size_override("font_size", 16); card.add_child(join_lbl)
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 6); card.add_child(row)
	remote_code_edit = LineEdit.new()
	remote_code_edit.placeholder_text = "مثال: 84.32.15.7:23991"
	remote_code_edit.custom_minimum_size = Vector2(0, 46); remote_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(remote_code_edit)
	var join_btn = Button.new(); join_btn.text = "اتصال راه دور"
	join_btn.custom_minimum_size = Vector2(150, 46); join_btn.add_theme_font_size_override("font_size", 15)
	join_btn.pressed.connect(FeedbackManager.play_click); join_btn.pressed.connect(_on_join_remote)
	row.add_child(join_btn)

func _on_host_remote():
	_toast("🌐 در حال آماده‌سازی میزبانی راه دور… (چند ثانیه)")
	if is_instance_valid(remote_upnp_lbl):
		remote_upnp_lbl.text = "در حال جست‌وجوی روتر و آدرس عمومی…"
	var result: Dictionary = await P2PManager.host_remote(int(network_port_spin.value))
	if not result.success:
		_toast("⚠️ " + str(result.reason))
		return
	var pub := str(result.get("public_address", ""))
	if bool(result.get("upnp", false)):
		if is_instance_valid(remote_upnp_lbl):
			remote_upnp_lbl.text = "✅ پورت روی روتر باز شد (UPnP)"
	else:
		if is_instance_valid(remote_upnp_lbl):
			remote_upnp_lbl.text = "⚠️ UPnP فعال نشد؛ اگر اتصال راه دور برقرار نشد، پورت را دستی باز کنید یا VPN بزنید"
	if pub.is_empty():
		if is_instance_valid(remote_code_lbl):
			remote_code_lbl.text = "آدرس عمومی یافت نشد (اینترنت؟)"
		_toast("🌐 میزبانی راه دور شروع شد ولی آدرس عمومی پیدا نشد")
	else:
		if is_instance_valid(remote_code_lbl):
			remote_code_lbl.text = "📋 کد اتصال: " + pub
		_toast("🌐 کد اتصال راه دور آماده است — برای دوستت بفرست")
	_refresh_network_status()

func _on_join_remote():
	_toast("🌐 در حال اتصال راه دور… (چند ثانیه)")
	var result: Dictionary = await P2PManager.join_remote(remote_code_edit.text)
	if result.success:
		_toast("🌐 درخواست اتصال راه دور ارسال شد — چند ثانیه صبر کن")
	else:
		_toast("⚠️ " + str(result.reason))
	_refresh_network_status()

func _on_host_network():
	var result = P2PManager.host_game(int(network_port_spin.value))
	if result.success:
		_toast("🌐 میزبان چندنفره فعال شد؛ پورت " + PersianFormatter.to_persian_digits(str(result.port)) + " — دوستان با همین پورت و نشانی شما وصل شوند")
	else:
		_toast("⚠️ " + str(result.reason))
		_toast("💡 دکمه «پورت آزاد» را بزنید یا پورت دیگری وارد کنید")
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
	_toast("🌐 وضعیت نوبت ماهانه %s از میزبان همگام شد" % PersianFormatter.to_persian_digits(str(tick)))
	_refresh_chat_visibility()
	if turn_waiting_dialog != null and turn_waiting_dialog.visible:
		turn_waiting_dialog.hide()

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

	# ریز کانال مالک-یکتای GDP (ممیزی نویسندگان ۱۴۰۵): همهٔ اثرهای مداومِ غیرصفر
	# بخش‌ها، مرتب‌شده بر حسب اندازهٔ اثر — بازیکن دقیقاً می‌بیند رشد از کجا می‌آید
	var boost_src: Dictionary = GameState.state.get("economy", {}).get("sector_boosts", {})
	var boost_rows: Array = []
	for bk in boost_src.keys():
		var bv: float = float(boost_src[bk])
		if absf(bv) > 0.000001:
			boost_rows.append([str(bk), bv])
	if not boost_rows.is_empty():
		boost_rows.sort_custom(func(a, b): return absf(a[1]) > absf(b[1]))
		var boost_card = _card("🧩 ریز اثر بخش‌ها بر رشد (کانال GDP)")
		_row(boost_card, "جمع کانال", PersianFormatter.to_persian_digits("%+.1f٪ در سال" % (float(GameState.state.get("economy", {}).get("sector_boosts_total", 0.0)) * 100.0)),
			_color_for(clampf(0.5 + float(GameState.state.get("economy", {}).get("sector_boosts_total", 0.0)) * 5.0, 0.0, 1.0)))
		var shown_count: int = 0
		for br in boost_rows:
			if shown_count >= 12:
				break
			_row(boost_card, str(br[0]), PersianFormatter.to_persian_digits("%+.2f٪ در سال" % (float(br[1]) * 100.0)),
				_color_for(clampf(0.5 + float(br[1]) * 5.0, 0.0, 1.0)))
			shown_count += 1
		if boost_rows.size() > shown_count:
			_row(boost_card, "…", PersianFormatter.to_persian_digits("و %d بخش دیگر" % (boost_rows.size() - shown_count)))

	_build_system_detail(selected_system)

	var directory = _card("📚 انتخاب سامانه برای مشاهده جزئیات")
	var diagnoses: Array = AIAdvisor.analyze(GameState.state, GameState.tick)
	var health_by_ai: Dictionary = {}
	for diagnosis in diagnoses:
		health_by_ai[str(diagnosis.get("system", ""))] = float(diagnosis.get("health", 0.5))

	# فیلتر حوزه: دسترسی سریع به گروه‌های موضوعی (معماری اطلاعاتی ۸ حوزه)
	# HFlow: اگر عرض چیپ‌ها از صفحه بیشتر شود، به خط بعد می‌شکنند و قاب گوشی بیرون نمی‌زند.
	var filter_row = HFlowContainer.new(); filter_row.add_theme_constant_override("h_separation", 6); filter_row.add_theme_constant_override("v_separation", 6); directory.add_child(filter_row)
	var all_filter = Button.new(); all_filter.text = "همه"; all_filter.toggle_mode = true
	all_filter.button_pressed = systems_domain_filter == ""
	all_filter.custom_minimum_size = Vector2(0, 40); all_filter.add_theme_font_size_override("font_size", 17)
	all_filter.theme_type_variation = "LensChipActive" if systems_domain_filter == "" else "LensChip"
	all_filter.pressed.connect(_on_system_domain_filter.bind(""))
	filter_row.add_child(all_filter)
	for group_def in SYSTEM_GROUPS:
		var domain_name: String = str(group_def[0])
		var fbtn = Button.new(); fbtn.text = domain_name; fbtn.toggle_mode = true
		fbtn.button_pressed = systems_domain_filter == domain_name
		fbtn.custom_minimum_size = Vector2(0, 40); fbtn.add_theme_font_size_override("font_size", 17)
		fbtn.theme_type_variation = "LensChipActive" if systems_domain_filter == domain_name else "LensChip"
		fbtn.pressed.connect(_on_system_domain_filter.bind(domain_name))
		filter_row.add_child(fbtn)

	# فهرست گروه‌بندی‌شده سامانه‌ها — هر حوزه با سرتیتر و سامانه‌های رنگی (سلامت)
	for group_def in SYSTEM_GROUPS:
		var domain_name: String = str(group_def[0])
		if systems_domain_filter != "" and systems_domain_filter != domain_name:
			continue
		var group_header = Label.new()
		group_header.text = domain_name
		group_header.add_theme_font_size_override("font_size", 18)
		group_header.modulate = Color(1.0, 0.81, 0.30, 0.95)
		group_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		directory.add_child(group_header)
		var grid = GridContainer.new()
		grid.columns = 2
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		directory.add_child(grid)
		for sys_name in group_def[1]:
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

var systems_domain_filter := ""
var news_filter_mode := "all"   # all | domestic | international
var news_sensitive_only := false
var celebration_layer: Control

func _on_system_domain_filter(domain_name: String):
	systems_domain_filter = domain_name
	_switch_tab("systems")

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
	if METRIC_EXACT_FA.has(key):
		return str(METRIC_EXACT_FA[key])
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
# کلمات کلیدی رویدادهای پراهمیت برای فید خبری (بازرسی رویداد-اسپم):
# فید قبلی صرفاً «دو رویداد آخر» را نشان می‌داد — با ~۱۰۰+ رویداد در هر نوبت، دو تای
# دمِ صف عملاً تصادفی (و معمولاً طعم‌دهندهٔ آماری) بودند و بحران‌ها دفن می‌شدند.
const EVENT_IMPORTANT_HINTS := ["crisis", "war", "peace", "treaty", "sanction", "election", "coup", "debt", "disaster", "epidemic", "attack", "assassin", "referendum", "riot", "collapse", "shortage", "blackout", "earthquake", "flood", "launch", "breakthrough", "olympics", "nuclear", "missile", "strike", "unrest", "protest", "bankin", "reserve", "trade_deficit", "hyperinflation", "supply_shock", "energy_crisis", "famine", "default", "resign", "impeach", "sector_boost"]

func _event_is_important(e: Dictionary) -> bool:
	var t := str(e.get("type", ""))
	if t == "law_event" or t == "intelligence_operation_event" or t == "incoming_offer":
		return true
	var d: Dictionary = e.get("data", {})
	var et := t
	if t == "system_event":
		et = str(d.get("event", {}).get("type", ""))
	for h in EVENT_IMPORTANT_HINTS:
		if et.to_lower().contains(h):
			return true
	return false

func _render_events():
	for c in event_list.get_children():
		c.queue_free()
	# فید اهمیت‌محور: از ۶۰ رویداد اخیر، اول مهم‌ها و بعد بقیه — بحران دیگر دفن نمی‌شود
	var last = EventLog.get_last(60)
	last.reverse()
	var chosen: Array = []
	for e in last:
		if _event_is_important(e):
			chosen.append(e)
			if chosen.size() >= 2:
				break
	for e in last:
		if chosen.size() >= 2:
			break
		if not chosen.has(e):
			chosen.append(e)
	for e in chosen:
		var l = Label.new()
		l.text = "• " + PersianFormatter.to_persian_digits(_event_text_fa(e))
		l.add_theme_font_size_override("font_size", 22)
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
	if msg == null or msg.strip_edges() == "":
		return
	toast_generation += 1
	if is_instance_valid(toast_lbl):toast_lbl.text=msg
	var severity="danger" if "⚠" in msg or "خطا" in msg or "ناموفق" in msg else ("success" if "✅" in msg or "شد" in msg or "ذخیره" in msg else "info")
	if is_instance_valid(toast_stack):toast_stack.push_message(msg,severity)

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
	var ok = _queue_decision(cmd, "🧾 مالیات: " + PersianFormatter.to_persian_digits("%d٪" % int(tax_slider.value)) + " — با پایان نوبت اعمال می‌شود")
	if ok:
		_toast("🧾 مالیات %s ثبت شد — با پایان نوبت اعمال می‌شود" % PersianFormatter.to_persian_digits("%d٪" % int(tax_slider.value)))
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
	var ok = _queue_decision(cmd, "💼 بودجه‌ی جدید — با پایان نوبت اعمال می‌شود")
	if ok:
		_toast("💼 بودجه‌ی جدید ثبت شد — با پایان نوبت اعمال می‌شود")
		_switch_tab("economy")

# ============================================================
# کنترل‌های فوتر
# ============================================================
func _on_next_tick_pressed():
	if P2PManager.competitive_mode and MultiplayerCampaignManager.started:
		_finish_multiplayer_turn()
		return
	_show_report_after_tick = true
	_run_tick_with(queued_commands.duplicate())

func _finish_multiplayer_turn():
	var cmds = queued_commands.duplicate()
	if P2PManager.is_host:
		for cmd in cmds:
			MultiplayerCampaignManager.enqueue_command(P2PManager.host_id, cmd)
		_clear_decision_queue()
		MultiplayerCampaignManager.mark_turn_finished(P2PManager.host_id)
		P2PManager._broadcast_turn_finished()
	else:
		for cmd in cmds:
			P2PManager.send_command(cmd)
		_clear_decision_queue()
		P2PManager.mark_turn_finished()
	_show_turn_waiting_dialog(MultiplayerCampaignManager.get_turn_finished_snapshot())

func _show_turn_waiting_dialog(finished_map):
	if turn_waiting_dialog == null: _build_turn_waiting_dialog()
	_populate_turn_waiting(finished_map)
	turn_waiting_dialog.popup_centered(Vector2i(420,380))

func _build_turn_waiting_dialog():
	turn_waiting_dialog = AcceptDialog.new()
	turn_waiting_dialog.title = "⏳ پایان نوبت"
	turn_waiting_dialog.dialog_text = "در انتظار پایان نوبت سایر بازیکنان..."
	turn_waiting_dialog.ok_button_text = "بستن"
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380,250)
	turn_waiting_list = VBoxContainer.new()
	turn_waiting_list.add_theme_constant_override("separation", 8)
	scroll.add_child(turn_waiting_list)
	turn_waiting_dialog.add_child(scroll)
	add_child(turn_waiting_dialog)

func _populate_turn_waiting(finished_map):
	if turn_waiting_list == null: return
	for c in turn_waiting_list.get_children(): c.queue_free()
	var all_done := true
	var ids = finished_map.keys(); ids.sort()
	for cid in ids:
		var info = finished_map[cid]
		var row = HBoxContainer.new()
		var icon = Label.new()
		var is_done = bool(info.get("finished", false))
		icon.text = "✅" if is_done else "⏳"
		icon.add_theme_font_size_override("font_size", 22)
		row.add_child(icon)
		var nl = Label.new()
		nl.text = str(info.get("name","بازیکن"))
		nl.add_theme_font_size_override("font_size", 20)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nl)
		var st = Label.new()
		st.text = "آماده" if is_done else "در حال بازی..."
		st.modulate = ACCENT_GREEN if is_done else TEXT_MUTED
		st.add_theme_font_size_override("font_size", 17)
		row.add_child(st)
		turn_waiting_list.add_child(row)
		if not is_done: all_done = false
	if turn_waiting_dialog != null:
		turn_waiting_dialog.dialog_text = "همه پایان نوبت زدند — در حال اجرا..." if all_done else "در انتظار پایان نوبت سایر بازیکنان..."

func _on_turn_finished_changed(finished_map):
	if turn_waiting_dialog != null and turn_waiting_dialog.visible:
		_populate_turn_waiting(finished_map)
		var all_done := true
		for v in finished_map.values():
			if not bool((v as Dictionary).get("finished", false)):
				all_done = false; break
		if all_done and P2PManager.is_host:
			turn_waiting_dialog.dialog_text = "در حال اجرای نوبت..."
			call_deferred("_run_advance_after_all_finished")

func _run_advance_after_all_finished():
	var result = MultiplayerCampaignManager.advance_month()
	if result.success:
		var cs:Dictionary = result.get("state", {})
		if not cs.is_empty():
			GameState.set_state(cs, int(cs.get("version",0)), int(cs.get("tick",0)))
			SaveManager.maybe_autosave(GameState.tick)
			_refresh_header(); _render_events()
		if turn_waiting_dialog != null:
			turn_waiting_dialog.hide()
		P2PManager._broadcast_campaign_states()
		_engagement_pulse(); FeedbackManager.play_success()
		_show_report_after_tick = true
		if _show_report_after_tick:
			_show_report_after_tick = false
			call_deferred("_show_turn_report")

func _on_chat_received(message):
	if chat_log == null: return
	chat_log.append_text("[b]%s:[/b] %s\n" % [str(message.get("name","بازیکن")), str(message.get("text",""))])
	chat_log.scroll_to_line(chat_log.get_line_count())

func _on_chat_submitted(text):
	if text.strip_edges().is_empty(): return
	if P2PManager.competitive_mode and MultiplayerCampaignManager.started:
		P2PManager.send_chat_message(text)
	chat_input.text = ""

func _toggle_chat():
	if chat_panel != null: chat_panel.visible = not chat_panel.visible

func _build_multiplayer_overlays():
	turn_waiting_dialog = null; turn_waiting_list = null
	chat_panel = PanelContainer.new()
	chat_panel.visible = false
	chat_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	chat_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	chat_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	chat_panel.custom_minimum_size = Vector2(320,360)
	var margin = MarginContainer.new()
	for side in ["margin_left","margin_right","margin_top","margin_bottom"]:
		margin.add_theme_constant_override(side, 8)
	chat_panel.add_child(margin)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	var title = Label.new()
	title.text = "💬 چت بازی"
	title.add_theme_font_size_override("font_size", 18)
	title.modulate = ACCENT_GOLD
	vbox.add_child(title)
	chat_log = RichTextLabel.new()
	chat_log.bbcode_enabled = true
	chat_log.fit_content = false
	chat_log.scroll_active = true
	chat_log.custom_minimum_size = Vector2(300,260)
	chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(chat_log)
	chat_input = LineEdit.new()
	chat_input.placeholder_text = "پیام بنویسید و Enter بزنید..."
	chat_input.add_theme_font_size_override("font_size", 16)
	chat_input.text_submitted.connect(_on_chat_submitted)
	vbox.add_child(chat_input)
	add_child(chat_panel)
	chat_dock_btn = Button.new()
	chat_dock_btn.text = "💬"
	chat_dock_btn.tooltip_text = "چت درون‌بازی"
	chat_dock_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	chat_dock_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	chat_dock_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	chat_dock_btn.position = Vector2(-60,-60)
	chat_dock_btn.custom_minimum_size = Vector2(52,52)
	chat_dock_btn.pressed.connect(_toggle_chat)
	add_child(chat_dock_btn)
	_refresh_chat_visibility()

func _refresh_chat_visibility():
	var in_mp = P2PManager.competitive_mode and MultiplayerCampaignManager.started
	if chat_dock_btn != null: chat_dock_btn.visible = in_mp
	if chat_panel != null and not in_mp: chat_panel.visible = false
	if in_mp and chat_log != null:
		chat_log.clear()
		for msg in MultiplayerCampaignManager.get_recent_chat(50):
			_on_chat_received(msg)

func _on_auto_pressed():
	auto_tick = !auto_tick
	var btn = find_child("AutoBtn", true, false)
	if btn:
		btn.text = "▶ خودکار: روشن" if auto_tick else "خودکار: خاموش"

# ============================================================
# صف تصمیم‌های نوبت — بازی نوبتی: تصمیم‌ها ثبت می‌شوند و با «پایان نوبت» اجرا
# ============================================================
func _command_queue_key(cmd) -> String:
	if not cmd is GameCommandClass:
		return ""
	var p: Dictionary = cmd.payload
	var t := str(cmd.type)
	match t:
		"tax_set": return "tax"
		"budget_allocate": return "budget"
		"monetary_policy": return "money:" + str(p.get("mode", ""))
		"tariff_set": return "tariff"
		"policy_change": return "policy:" + str(p.get("policy_id", ""))
		"law_change": return "law:" + str(p.get("law_id", "")) + ":" + str(p.get("action", ""))
		"cabinet_change":
			return ("cabx:" if str(p.get("action", "")) == "dismiss" else "cab:") + str(p.get("ministry_id", ""))
		"national_project":
			return ("projx:" if str(p.get("action", "")) == "cancel" else "proj:") + str(p.get("project_id", ""))
		"research_start": return "res:" + str(p.get("tech_id", ""))
		"intelligence_operation":
			if str(p.get("action", "")) == "cancel":
				return "intelx:" + str(p.get("operation_key", ""))
			return "intel:" + str(p.get("operation_id", "")) + ":" + str(p.get("target", ""))
		"military_doctrine": return "doc:" + str(p.get("doctrine", ""))
		"military_program": return "milprog:" + str(p.get("program_id", ""))
		"municipal_action": return "muni:" + str(p.get("action", ""))
		"diplomacy": return "dip:" + str(p.get("target", "")) + ":" + str(p.get("action", ""))
		"construction": return "con:" + str(p.get("from_country", "")) + ":" + str(p.get("to_country", "")) + ":" + str(p.get("build_type", ""))
		"battle_plan": return "battle:" + str(p.get("from_country", "")) + ":" + str(p.get("to_country", "")) + ":" + str(p.get("plan_type", ""))
		"map_operation": return "mapop:" + str(p.get("target", "")) + ":" + str(p.get("operation_type", ""))
		"map_building": return "mapbuild:" + str(p.get("building_type", "")) + ":" + str(p.get("unit_id", ""))
		"trade_route_attack": return "tradeatt:" + str(p.get("route_id", "")) + ":" + str(p.get("route_type", ""))
		"chokepoint_action": return "choke:" + str(p.get("chokepoint_id", ""))
		"decision_resolve": return "dec:" + str(p.get("decision_id", ""))
		"faction_action": return "fac:" + str(p.get("faction", "")) + ":" + str(p.get("action", ""))
		"set_war_goal": return "wargoal:" + str(p.get("target", ""))
		"general_recruit": return "general_recruit"
		"general_assign": return "gen_assign:" + str(p.get("commander_id", "")) + ":" + str(p.get("war_target", ""))
		"media_policy": return "media_policy:" + str(p.get("policy", ""))
		"media_campaign": return "media_camp:" + str(p.get("target_group", ""))
		"commodity_trade": return "com_sell:" + str(p.get("commodity", ""))
		"org_toggle": return "org_toggle:" + str(p.get("org", ""))
		"org_vote": return "org_vote:" + str(p.get("decision", ""))
		"snap_election": return "snap_election"
		"campaign_promise": return "promise:" + str(p.get("promise_id", ""))
		"forex_intervene": return "forex:intervene"
		"forex_devalue": return "forex:devalue"
		"capital_control": return "forex:control"
		"governor_appoint": return "gov:" + str(p.get("province_code", "")) + ":" + str(p.get("faction", ""))
		"crisis_stance": return "crisis:" + str(p.get("stance", ""))
		"rivalry_action": return "rivalry:" + ("de" if str(p.get("action", "")) == "de_escalate" else "es")
		"shadow_action": return "shadow:" + str(p.get("action", ""))
		"court_action": return "court:" + str(p.get("action", ""))
		"energy_action": return "energy:" + str(p.get("action", ""))
		"industry_action": return "industry:" + str(p.get("action", "")) + (":" + str(p.get("value", "")) if str(p.get("value", "")) != "" else "")
		"succession_action": return "succession:train"
		"labor_action": return "labor:" + str(p.get("action", ""))
		"epidemic_action": return "epi:" + str(p.get("action", ""))
		"arms_action": return "arms:" + str(p.get("action", "")) + (":" + str(p.get("target", "")) if str(p.get("target", "")) != "" else "")
		"cyber_action": return "cyber:" + str(p.get("action", "")) + (":" + str(p.get("target", "")) + ":" + str(p.get("kind", "")) if str(p.get("action", "")) == "attack" else "")
		"migration_action": return "mig:" + str(p.get("action", ""))
		"culture_action": return "cul:" + str(p.get("action", ""))
		"education_action": return "edu:" + str(p.get("action", ""))
		"agriculture_action": return "agri:" + str(p.get("action", ""))
		"tourism_action": return "tour:" + str(p.get("action", "")) + (":" + str(p.get("value", "")) if str(p.get("action", "")) == "visa" else "")
		"urban_action": return "urban:" + str(p.get("action", ""))
		"security_action": return "sec:" + str(p.get("action", ""))
		"infra_action": return "infra:" + str(p.get("action", "")) + (":" + str(p.get("value", "")) if str(p.get("action", "")) == "maintenance" else "")
		"climate_action": return "climate:" + str(p.get("action", "")) + (":" + str(p.get("value", "")) if str(p.get("action", "")) == "carbon" else "")
		"welfare_action": return "welfare:" + str(p.get("action", "")) + (":" + str(p.get("value", "")) if str(p.get("action", "")) in ["pension", "benefit"] else "")
		"space_action": return "space:" + str(p.get("action", ""))
		"trade_policy_action": return "trade_pol:" + str(p.get("action", ""))
		"banking_action": return "bank:" + str(p.get("action", "")) + (":" + str(p.get("value", "")) if str(p.get("action", "")) == "reserve" else "")
		"fdi_action": return "fdi:" + str(p.get("action", "")) + (":" + str(p.get("value", "")) if str(p.get("action", "")) == "restrictions" else "")
		"ambassador_action": return "amb:" + str(p.get("action", "")) + ":" + str(p.get("country", ""))
		"digital_action": return "digital:" + str(p.get("action", ""))
		"sports_action": return "sports:" + str(p.get("action", ""))
		"dilemma_resolve": return "dilemma:" + str(p.get("choice", ""))
		"stock_action": return "stock:" + str(p.get("action", ""))
		"veterans_action": return "veterans:" + str(p.get("action", ""))
		"heritage_action": return "heritage:" + str(p.get("action", ""))
		"transport_action": return "transport:" + str(p.get("action", ""))
		"retail_action": return "retail:" + str(p.get("action", ""))
		"ethnicity_action": return "ethnicity:" + str(p.get("action", ""))
		"water_action": return "water:" + str(p.get("action", ""))
		"research_action": return "research:" + str(p.get("action", ""))
		"civic_action": return "civic:" + str(p.get("action", ""))
		"diaspora_action": return "diaspora:" + str(p.get("action", ""))
		"civil_defense_action": return "civil_defense:" + str(p.get("action", ""))
		"blue_economy_action": return "blue_economy:" + str(p.get("action", ""))
		"creative_action": return "creative:" + str(p.get("action", ""))
		"demographic_action": return "demographic:" + str(p.get("action", ""))
		"watershed_action": return "watershed:" + str(p.get("action", ""))
		"prison_action": return "prison:" + str(p.get("action", "")) + (":" + str(p.get("approach", "")) if str(p.get("action", "")) == "approach" else "")
		"statistics_action": return "stats:" + str(p.get("action", ""))
		"mining_action": return "mining:" + str(p.get("action", ""))
		"waste_action": return "waste:" + str(p.get("action", ""))
		"insurance_action": return "insurance:" + str(p.get("action", ""))
		"rural_action": return "rural:" + str(p.get("action", ""))
		"judicial_reform_action": return "jr:" + str(p.get("action", ""))
		"election_action": return "election:" + str(p.get("action", ""))
		"fuel_action": return "fuel:" + str(p.get("action", ""))
		"housing_action": return "housing:" + str(p.get("action", ""))
		"startup_action": return "startup:" + str(p.get("action", ""))
		"sme_action": return "sme:" + str(p.get("action", ""))
		"supply_action": return "supply:" + str(p.get("action", ""))
		"care_action": return "care:" + str(p.get("action", ""))
		"science_action": return "science:" + str(p.get("action", ""))
		"downstream_action": return "downstream:" + str(p.get("action", ""))
		"higher_ed_action": return "highered:" + str(p.get("action", ""))
		"food_chain_action": return "foodchain:" + str(p.get("action", ""))
		"pharma_action": return "pharma:" + str(p.get("action", ""))
		"ip_action": return "ip:" + str(p.get("action", ""))
		"transit_action": return "transit:" + str(p.get("action", ""))
		"disaster_action": return "disaster:" + str(p.get("action", ""))
		"livestock_action": return "livestock:" + str(p.get("action", ""))
		"textile_action": return "textile:" + str(p.get("action", ""))
		"basic_industry_action": return "basicind:" + str(p.get("action", ""))
		"nation_brand_action": return "nationbrand:" + str(p.get("action", ""))
		"ai_action": return "ai:" + str(p.get("action", ""))
		"assassinate": return "assassinate:" + str(p.get("target", ""))
		"leader_hidden": return "leader_hidden:" + str(p.get("hidden", false))
		"country_select": return "country_select"
		"next_tick": return "next_tick"
		# عمق ۱۸ تا ۲۰: پیشوندها باید دقیقاً با متای دکمه‌ها (cmd_key) یکسان باشند
		# وگرنه دکمه‌های «یک‌بار در نوبت» بعد از کلیک غیرفعال نمی‌شوند.
		"tax_action": return "tax:" + str(p.get("action", ""))
		"ev_action": return "ev:" + str(p.get("action", ""))
		"health_tourism_action": return "ht:" + str(p.get("action", ""))
		"defense_industry_action": return "di:" + str(p.get("action", ""))
		"knowledge_economy_action": return "ke:" + str(p.get("action", ""))
		"waste_mgmt_action": return "waste_mgmt:" + str(p.get("action", ""))
		"aerospace_action": return "as:" + str(p.get("action", ""))
		"petrochemical_action": return "petro:" + str(p.get("action", ""))
		"pro_sports_action": return "psports:" + str(p.get("action", ""))
		# عمق ۲۱: پیشوندها باید دقیقاً با متای دکمه‌ها (cmd_key) یکسان باشند
		"aviation_action": return "av:" + str(p.get("action", ""))
		"postal_action": return "post:" + str(p.get("action", ""))
		"standards_action": return "std:" + str(p.get("action", ""))
	return t + ":" + JSON.stringify(p)

# ثبت یک تصمیم در صف نوبت؛ تصمیم هم‌خانواده قبلی جایگزین می‌شود
func _queue_decision(cmd, label: String) -> bool:
	if cmd == null or not cmd is GameCommandClass:
		return false
	var key := _command_queue_key(cmd)
	for i in range(queued_commands.size()):
		if _command_queue_key(queued_commands[i]) == key:
			queued_commands[i] = cmd
			queued_labels[i] = label
			_update_queue_chip()
			return true
	queued_commands.append(cmd)
	queued_labels.append(label)
	_update_queue_chip()
	call_deferred("_refresh_once_buttons")
	return true

func _update_queue_chip():
	if is_instance_valid(queue_btn):
		queue_btn.text = "☑ تصمیم‌ها: " + PersianFormatter.to_persian_digits(str(queued_commands.size()))
		queue_btn.theme_type_variation = "PrimaryButton" if queued_commands.size() > 0 else ""

func _clear_decision_queue():
	queued_commands.clear()
	queued_labels.clear()
	_update_queue_chip()
	call_deferred("_refresh_once_buttons")
	if is_instance_valid(queue_panel) and queue_panel.visible:
		_render_queue_panel()

# آیا کلیدی در صف تصمیم‌های این نوبت هست؟
func _queue_has_key(key: String) -> bool:
	for cmd in queued_commands:
		if _command_queue_key(cmd) == key:
			return true
	return false

# ── غیرفعال‌سازی خودکار دکمه‌های «یک‌بار در نوبت» ──
# هر دکمه عملیات که فقط یک بار در نوبت قابل انجام است، هنگام ساخت متادیتای
# cmd_key می‌گیرد؛ پس از کلیک (ثبت در صف) غیرفعال می‌شود و اگر تصمیم از صف
# حذف شد، دوباره فعال می‌گردد.
func _mark_decision_button(btn: Button, cmd_key: String) -> Button:
	btn.set_meta("cmd_key", cmd_key)
	btn.set_meta("natural_disabled", btn.disabled)
	# اگر تصمیم این عملیات در صف نوبت جاری است، دکمه از ابتدا غیرفعال ساخته می‌شود
	# (بعد از کلیک، تب بازسازی می‌شود و دکمه تازه باید غیرفعال باشد)
	if _queue_has_key(cmd_key):
		btn.disabled = true
	return btn

func _refresh_once_buttons():
	if not is_inside_tree():
		return
	_refresh_once_buttons_recursive(self)

func _refresh_once_buttons_recursive(node: Node):
	if node is Button and node.has_meta("cmd_key"):
		var key := str(node.get_meta("cmd_key"))
		var natural: bool = bool(node.get_meta("natural_disabled", false))
		node.disabled = natural or _queue_has_key(key)
	for child in node.get_children():
		_refresh_once_buttons_recursive(child)

func _remove_queued_decision(index: int):
	if index < 0 or index >= queued_commands.size():
		return
	queued_commands.remove_at(index)
	queued_labels.remove_at(index)
	_update_queue_chip()
	call_deferred("_refresh_once_buttons")
	_render_queue_panel()

func _on_queue_pressed():
	if not is_instance_valid(queue_panel):
		_build_queue_panel()
	if queue_panel_visible:
		queue_panel.visible = false
		queue_panel_visible = false
	else:
		_render_queue_panel()
		queue_panel.visible = true
		queue_panel_visible = true
		queue_panel.move_to_front()

func _build_queue_panel():
	queue_panel = Control.new()
	queue_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	queue_panel.z_index = 260
	queue_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	queue_panel.visible = false
	add_child(queue_panel)
	var dim = ColorRect.new(); dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT); dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev):
		if ev is InputEventScreenTouch and ev.pressed:
			_on_queue_pressed())
	queue_panel.add_child(dim)
	var sheet = PanelContainer.new(); sheet.theme_type_variation = "SheetPanel"
	sheet.anchor_left = 0.03; sheet.anchor_right = 0.97; sheet.anchor_top = 0.55; sheet.anchor_bottom = 0.985
	sheet.offset_left = 0; sheet.offset_right = 0; sheet.offset_top = 0; sheet.offset_bottom = 0
	queue_panel.add_child(sheet)
	var box = VBoxContainer.new(); box.add_theme_constant_override("separation", 8); sheet.add_child(box)
	var head = HBoxContainer.new(); head.add_theme_constant_override("separation", 8); box.add_child(head)
	var title = Label.new(); title.text = "☑ تصمیم‌های این نوبت"; title.add_theme_font_size_override("font_size", 26)
	title.modulate = ACCENT_GOLD; title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(title)
	var clear_btn = Button.new(); clear_btn.text = "پاک کردن همه"; clear_btn.theme_type_variation = "GhostButton"
	clear_btn.add_theme_font_size_override("font_size", 18); clear_btn.pressed.connect(_clear_decision_queue)
	clear_btn.pressed.connect(FeedbackManager.play_click); head.add_child(clear_btn)
	var close_btn = Button.new(); close_btn.text = "✕"; close_btn.custom_minimum_size = Vector2(64, 52)
	close_btn.add_theme_font_size_override("font_size", 22); close_btn.theme_type_variation = "GhostButton"
	close_btn.pressed.connect(_on_queue_pressed); close_btn.pressed.connect(FeedbackManager.play_click); head.add_child(close_btn)
	var hint = Label.new(); hint.text = "این تصمیم‌ها هنگام زدن «پایان نوبت» یکجا اجرا می‌شوند."
	hint.add_theme_font_size_override("font_size", 17); hint.modulate = TEXT_FAINT; box.add_child(hint)
	var scroll = TouchScrollClass.new(); scroll.allow_vertical = true; scroll.allow_horizontal = false
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_child(scroll)
	queue_panel.set_meta("scroll", scroll)
	var list = VBoxContainer.new(); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 5); scroll.add_child(list)
	queue_panel.set_meta("list", list)

func _render_queue_panel():
	if not is_instance_valid(queue_panel):
		return
	var list: VBoxContainer = queue_panel.get_meta("list")
	for c in list.get_children():
		c.queue_free()
	if queued_commands.is_empty():
		var empty = Label.new(); empty.text = "هنوز تصمیمی ثبت نکرده‌اید — از بخش‌های بازی تصمیم بگیرید."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; empty.add_theme_font_size_override("font_size", 19)
		empty.modulate = TEXT_MUTED; list.add_child(empty)
		return
	for i in range(queued_commands.size()):
		var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 8); list.add_child(row)
		var lbl = Label.new(); lbl.text = "• " + str(queued_labels[i]); lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 20); lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.custom_minimum_size = Vector2(0, 52); lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(lbl)
		var rm = Button.new(); rm.text = "✕"; rm.custom_minimum_size = Vector2(58, 48)
		rm.add_theme_font_size_override("font_size", 20); rm.theme_type_variation = "GhostButton"
		var idx := i
		rm.pressed.connect(func(): _remove_queued_decision(idx))
		rm.pressed.connect(FeedbackManager.play_click)
		row.add_child(rm)

# ============================================================
# گزارش نوبت — پس از «پایان نوبت» نمایش داده می‌شود
# ============================================================
func _show_turn_report():
	if P2PManager.is_network_active() and not P2PManager.is_host:
		return
	if _report_open:
		return
	_report_open = true
	var st = GameState.state
	var turn = int(st.get("tick", 0))
	var time_d: Dictionary = st.get("time", {})
	var clock: Dictionary = st.get("clock", {})
	var overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 280
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	turn_report_overlay = overlay
	var dim = ColorRect.new(); dim.color = Color(0.0, 0.01, 0.02, 0.80)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT); dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)
	var card = PanelContainer.new(); card.theme_type_variation = "CommandPanel"
	card.anchor_left = 0.04; card.anchor_right = 0.96; card.anchor_top = 0.05; card.anchor_bottom = 0.95
	card.offset_left = 0; card.offset_right = 0; card.offset_top = 0; card.offset_bottom = 0
	overlay.add_child(card)
	var box = VBoxContainer.new(); box.add_theme_constant_override("separation", 9); card.add_child(box)
	var head = HBoxContainer.new(); head.add_theme_constant_override("separation", 8); box.add_child(head)
	var title = Label.new()
	title.text = "📋 گزارش نوبت %s — %s %s" % [
		PersianFormatter.to_persian_digits(str(turn)),
		TimeManager.month_name(int(clock.get("month", 1))),
		PersianFormatter.to_persian_digits(str(clock.get("year", 1404)))]
	title.add_theme_font_size_override("font_size", 28); title.modulate = ACCENT_GOLD
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(title)
	var close_btn = Button.new(); close_btn.text = "ادامه ▶"; close_btn.custom_minimum_size = Vector2(140, 52)
	close_btn.add_theme_font_size_override("font_size", 21); close_btn.theme_type_variation = "PrimaryButton"
	close_btn.pressed.connect(func():
		_report_open = false
		overlay.queue_free())
	head.add_child(close_btn)
	var scroll = TouchScrollClass.new(); scroll.allow_vertical = true; scroll.allow_horizontal = false
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_child(scroll)
	var inner = VBoxContainer.new(); inner.add_theme_constant_override("separation", 8)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(inner)

	# ── ۱) تصمیم‌های شما ──
	var dec_head = Label.new(); dec_head.text = "🎯 تصمیم‌های شما (%s)" % PersianFormatter.to_persian_digits(str(_last_turn_labels.size()))
	dec_head.add_theme_font_size_override("font_size", 23); dec_head.modulate = ACCENT_TEAL; inner.add_child(dec_head)
	if _last_turn_labels.is_empty():
		var none = Label.new(); none.text = "در این نوبت تصمیمی ثبت نکردید — کشور به مسیر جاری ادامه داد."
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; none.add_theme_font_size_override("font_size", 19)
		none.modulate = TEXT_MUTED; inner.add_child(none)
	for lbl_text in _last_turn_labels:
		var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 6); inner.add_child(row)
		var dot = Label.new(); dot.text = "✅"; dot.add_theme_font_size_override("font_size", 20); row.add_child(dot)
		var l = Label.new(); l.text = str(lbl_text); l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 20); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
	inner.add_child(HSeparator.new())

	# ── ۲) شاخص‌های کشور ──
	var idx_head = Label.new(); idx_head.text = "📈 شاخص‌های کشور در این نوبت"
	idx_head.add_theme_font_size_override("font_size", 23); idx_head.modulate = ACCENT_TEAL; inner.add_child(idx_head)
	var report: Dictionary = st.get("monthly_report", {})
	if not report.is_empty():
		_row(inner, "تغییر تولید ناخالص داخلی", _signed_percent(float(report.get("gdp_change", 0.0))), _color_for(0.75 if float(report.get("gdp_change", 0.0)) >= 0.0 else 0.2))
		_row(inner, "تغییر رضایت مردم", _signed_percent(float(report.get("happiness_change", 0.0))), _color_for(0.75 if float(report.get("happiness_change", 0.0)) >= 0.0 else 0.2))
		_row(inner, "تغییر ثبات", _signed_percent(float(report.get("stability_change", 0.0))), _color_for(0.75 if float(report.get("stability_change", 0.0)) >= 0.0 else 0.2))
		_row(inner, "رویدادهای پردازش‌شده", PersianFormatter.to_persian_digits(str(report.get("total_events", 0))))
	else:
		var no = Label.new(); no.text = "گزارش ماهانه پس از نخستین نوبت کامل منتشر می‌شود."
		no.add_theme_font_size_override("font_size", 19); no.modulate = TEXT_MUTED; inner.add_child(no)
	inner.add_child(HSeparator.new())

	# ── ۳) تصمیم‌های کشورهای جهان ──
	var world_head = Label.new(); world_head.text = "🌍 تصمیم‌های کشورهای جهان در این نوبت"
	world_head.add_theme_font_size_override("font_size", 23); world_head.modulate = ACCENT_TEAL; inner.add_child(world_head)
	var world: Dictionary = st.get("world", {})
	var plans: Dictionary = world.get("npc_turn_plans", {})
	var turn_plans: Array = plans.get(str(turn), [])
	var npc_count := 0
	var player_id = str(world.get("player_country", ""))
	for cid in world.get("countries", {}).keys():
		if cid != player_id:
			npc_count += 1
	var shown_world := 0
	for plan in turn_plans:
		if not plan is Array or plan.size() < 2:
			continue
		if shown_world >= 24:
			break
		var cid := str(plan[0])
		var cname := WorldManager.get_country_name(cid) if WorldManager.countries.has(cid) else cid
		var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 6); inner.add_child(row)
		var dot = Label.new(); dot.text = NpcTurnManagerClass.action_icon(str(plan[1])); dot.add_theme_font_size_override("font_size", 19); row.add_child(dot)
		var l = Label.new(); l.text = "%s: %s" % [cname, NpcTurnManagerClass.describe(plan)]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.add_theme_font_size_override("font_size", 19)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(l)
		shown_world += 1
	var decided_lbl = Label.new()
	decided_lbl.text = "✔ هر %s کشور جهان در آغاز نوبت تصمیم گرفت؛ این نوبت %s اقدام برجسته ثبت شد" % [
		PersianFormatter.to_persian_digits(str(npc_count)),
		PersianFormatter.to_persian_digits(str(shown_world))]
	decided_lbl.add_theme_font_size_override("font_size", 17); decided_lbl.modulate = TEXT_FAINT; inner.add_child(decided_lbl)
	if shown_world == 0:
		var calm = Label.new(); calm.text = "جهان در این نوبت آرام بود؛ کشورها به وضع موجود ادامه دادند."
		calm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; calm.add_theme_font_size_override("font_size", 19)
		calm.modulate = TEXT_MUTED; inner.add_child(calm)

func _on_music_pressed():
	var is_on = AmbientMusic.toggle()
	var btn = find_child("MusicBtn", true, false)
	if btn:
		btn.text = "🎵 موزیک" if is_on else "🎵✕ موزیک"
	_toast("🎵 موسیقی محیطی روشن شد" if is_on else "🎵 موسیقی محیطی خاموش شد")

func _on_sound_pressed():
	var is_muted = FeedbackManager.toggle_mute()
	var btn = find_child("SoundBtn", true, false)
	if btn:
		btn.text = "✕ صدا" if is_muted else "♪ صدا"
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
	var recovery_note = " — از نسخه پشتیبان بازیابی شد" if result.get("recovered_from_backup", false) else ""
	_toast("📂 بازی بارگذاری شد — نوبت ماهانه %s%s%s" % [
		PersianFormatter.to_persian_digits(str(GameState.tick)), migration_note, recovery_note])
	_refresh_header()
	_render_events()
	_switch_tab(current_tab)

# ============================================================
# هسته تیک
# ============================================================
func _run_tick_with(player_cmds: Array) -> bool:
	if simulation_busy:
		_toast("شبیه‌سازی ماه قبلی هنوز در حال اجراست")
		return false
	# کلاینت فقط فرمان را می‌فرستد؛ محاسبه و Commit منحصراً روی میزبان انجام می‌شود.
	if P2PManager.is_network_active() and not P2PManager.can_advance_tick():
		if player_cmds.is_empty():
			_toast("فقط میزبان می‌تواند ماه بعد را اجرا کند")
			return true
		for cmd in player_cmds:
			if not P2PManager.send_command(cmd):return false
		_clear_decision_queue()
		_toast("تصمیم‌های این نوبت برای اجرا به میزبان ارسال شد")
		return true

	if P2PManager.competitive_mode and P2PManager.is_host and MultiplayerCampaignManager.started:
		var campaign_result=P2PManager.advance_competitive_month(player_cmds)
		if not campaign_result.success:_toast("خطا: "+str(campaign_result.reason));return false
		var campaign_state:Dictionary=campaign_result.state
		GameState.set_state(campaign_state,int(campaign_state.get("version",0)),int(campaign_state.get("tick",0)))
		SaveManager.maybe_autosave(GameState.tick);_refresh_header();_render_events();_engagement_pulse();FeedbackManager.play_success();return true

	var cmds:Array=[];cmds.append_array(P2PManager.get_pending_commands());cmds.append_array(player_cmds);cmds.append(GameCommandClass.create_next_tick())
	# تست‌های هدلس همان API همگام قطعی را نگه می‌دارند؛ اجرای واقعی UI روزبه‌روز Yield می‌کند.
	if DisplayServer.get_name()=="headless" or OS.has_feature("server"):
		return _finish_tick_result(GameEngine.tick(GameState.state,GameState.version,GameState.tick,cmds),false)
	_set_simulation_busy(true)
	call_deferred("_execute_tick_async",cmds)
	return true

func _execute_tick_async(cmds:Array):
	await get_tree().process_frame
	var result=await GameEngine.tick_async(GameState.state,GameState.version,GameState.tick,cmds)
	var ok=_finish_tick_result(result,true)
	_set_simulation_busy(false)
	if ok:_toast("شبیه‌سازی ماه با موفقیت کامل شد")

func _finish_tick_result(result:Dictionary,refresh_page:bool)->bool:
	if result == null or not result is Dictionary:
		# موتور در مسیر محاسبه شکست خورد و پاسخ معتبر نداد؛ UI نباید قفل بماند.
		_show_report_after_tick = false
		FeedbackManager.play_alert()
		_toast("خطا: موتور شبیه‌سازی پاسخ معتبری برنگرداند — نوبت تغییر نکرد")
		return false
	if result.success:
		GameState.set_state(result.state,result.version,result.tick)
		if not P2PManager.is_network_active() or P2PManager.is_host:SaveManager.maybe_autosave(result.tick)
		P2PManager.broadcast_state(result.state,result.version,result.tick)
		_refresh_header();_render_events();_engagement_pulse();FeedbackManager.play_success()
		# صف تصمیم‌های این نوبت اجرا شد؛ برای گزارش نوبت نگه می‌داریم و صف را خالی می‌کنیم.
		_last_turn_labels = queued_labels.duplicate()
		_clear_decision_queue()
		call_deferred("_refresh_once_buttons")
		if _show_report_after_tick:
			_show_report_after_tick = false
			call_deferred("_show_turn_report")
		# 🎉 لحظه‌های هیجان‌انگیز: جشن دستاورد/مرحله/رکورد (از events می‌آیند)
		var celebrations: Array = []
		for event in result.get("events", []):
			if str(event.get("type", "")) == "celebration":
				celebrations.append(event.get("celebration", {}))
		if celebrations.size() > 0:
			var delay := 0.4
			for celebration in celebrations:
				var c = celebration
				var timer := get_tree().create_timer(delay)
				timer.timeout.connect(func():
					if is_instance_valid(celebration_layer) and celebration_layer.has_method("celebrate"):
						celebration_layer.call("celebrate", c))
				delay += 1.2
		if refresh_page:_switch_tab(current_tab)
		return true
	_show_report_after_tick = false
	FeedbackManager.play_alert();_toast("خطا: "+str(result.get("reason","محاسبه ناموفق بود")))
	return false

func _engagement_pulse():
	if bool(SettingsManager.get_value("reduce_motion", false)):
		return
	var tw = create_tween()
	tw.tween_property(engagement_lbl, "scale", Vector2(1.15, 1.15), 0.1)
	tw.tween_property(engagement_lbl, "scale", Vector2(1.0, 1.0), 0.15)

func _process(delta):
	if auto_tick and not simulation_busy:
		tick_timer += delta
		if tick_timer >= float(SettingsManager.get_value("auto_tick_interval", 1.0)):
			tick_timer = 0.0
			# در حالت خودکار نیز تصمیم‌های ثبت‌شده در همین نوبت اجرا می‌شوند
			_run_tick_with(queued_commands.duplicate())

func _on_tick_completed(new_state, events):
	current_state = new_state.duplicate(true)
	for event in events:
		if str(event.get("type", "")) == "achievement_unlocked":
			FeedbackManager.play_achievement()
			break

func _on_tick_failed(reason):
	print("خطای تیک: %s" % reason)
