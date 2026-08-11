extends Control
# UI اصلی بازی - فارسی ۱۰۰٪ (قانون ۶) - چندتب تعاملی
# همه‌ی اعداد با ارقام فارسی، همه‌ی فرمان‌ها از طریق موتور اتمی (۳.۶)

const GameCommandClass = preload("res://scripts/core/command.gd")
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
var map_overlays: Dictionary = {"wars":true,"alliances":true,"trade":true,"air":false,"sea":false,"land":false,"cities":true,"transport":true,"intelligence":false}
var map_advanced_mode: String = "select" # select, battle_plan, build_road, build_rail, build_fort, build_depot, build_airfield, build_radar
var map_advanced_start_country: String = ""
var map_advanced_start_unit: String = ""
var map_camera_center := Vector2(0.5, 0.5)
var map_zoom := 1.0
var selected_country_unit: String = ""
var selected_map_route: Dictionary = {}
var current_unified_map: Control
var country_select_option: OptionButton
var scenario_select_option: OptionButton
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
var ticker_panel: PanelContainer
var time_dock: PanelContainer

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
	["map", "نقشه فرماندهی"],
	["dashboard", "داشبورد"],
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
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	app_theme = _build_professional_theme()
	theme = app_theme
	SettingsManager.settings_changed.connect(_on_setting_changed)
	current_state = GameState.get_state_copy()
	_build_chrome()
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
	print("رابط کاربری اصلی لود شد - شبیه‌ساز کشور")

func _notification(what:int):
	if what!=NOTIFICATION_WM_GO_BACK_REQUEST:return
	if is_instance_valid(command_palette) and command_palette.visible:command_palette.close_palette();return
	if drawer_open:_close_drawer();return
	if simulation_busy:get_tree().quit();return
	if current_tab!="map":_switch_tab("map")
	else:get_tree().quit()

# ============================================================
# قاب کلی: هدر + تب‌بار + محتوا + فوتر
# ============================================================
func _build_chrome():
	background_rect = CommandBackgroundClass.new()
	background_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background_rect)

	chrome_root = VBoxContainer.new()
	var root = chrome_root
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 16
	root.offset_right = -16
	root.offset_top = 12
	root.offset_bottom = -12
	root.add_theme_constant_override("separation", 8)
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

	# محتوای اصلی؛ نقشه و پنل‌های مدیریتی از همین فضای مشترک استفاده می‌کنند.
	content_scroll = TouchScrollClass.new(); content_scroll.allow_vertical=true;content_scroll.allow_horizontal=false;content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; root.add_child(content_scroll)
	content = VBoxContainer.new(); content.size_flags_horizontal = Control.SIZE_EXPAND_FILL; content.add_theme_constant_override("separation", 10); content_scroll.add_child(content)

	# Label پنهان فقط برای سازگاری تست/کد قدیمی؛ اعلان واقعی در ToastStack نمایش داده می‌شود.
	toast_lbl = Label.new(); toast_lbl.hide(); add_child(toast_lbl)

	# تیکر رخدادهای زنده؛ لمس آن میز فرمان را باز می‌کند.
	ticker_panel = PanelContainer.new(); ticker_panel.theme_type_variation = "TickerPanel"; ticker_panel.mouse_filter = Control.MOUSE_FILTER_STOP; ticker_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND; ticker_panel.tooltip_text = "مشاهده کامل در میز فرمان"; ticker_panel.gui_input.connect(_on_ticker_input); root.add_child(ticker_panel)
	var event_box = HBoxContainer.new(); event_box.add_theme_constant_override("separation",9); ticker_panel.add_child(event_box)
	var ev_title = Label.new(); ev_title.text = "⚡ رخدادها"; ev_title.custom_minimum_size = Vector2(125,0); ev_title.modulate = ACCENT_GOLD; ev_title.add_theme_font_size_override("font_size",20); event_box.add_child(ev_title)
	event_list = VBoxContainer.new(); event_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; event_list.add_theme_constant_override("separation",1); event_box.add_child(event_list); _render_events()

	# ── داک زمان (سبک HOI4): اقدام اصلی رهبر + جریان خودکار ──
	time_dock = PanelContainer.new(); time_dock.theme_type_variation = "TimeDockPanel"; root.add_child(time_dock)
	var time_row = HBoxContainer.new(); time_row.alignment = BoxContainer.ALIGNMENT_CENTER; time_row.add_theme_constant_override("separation",9); time_dock.add_child(time_row)
	_mk_btn(time_row, "▶ ماه بعد", Vector2(215,54), _on_next_tick_pressed, "PrimaryAction")
	_mk_btn(time_row, "خودکار: خاموش", Vector2(170,54), _on_auto_pressed, "AutoBtn")
	_mk_btn(time_row, "⚡ " + SettingsManager.get_speed_label(), Vector2(106,54), _on_speed_pressed, "SpeedBtn")

	# ── ناوبری پایانی ثابت: پنج بخش اصلی همیشه در دسترس ──
	var nav_panel = PanelContainer.new(); nav_panel.theme_type_variation = "NavBarPanel"; root.add_child(nav_panel)
	nav_row = HBoxContainer.new(); nav_row.add_theme_constant_override("separation", 3); nav_panel.add_child(nav_row)
	for nav_def in [["map","◉","نقشه"],["dashboard","▦","میز فرمان"],["government","♜","دولت"],["economy","◈","اقتصاد"],["more","☰","بیشتر"]]:
		_make_nav_item(nav_row, str(nav_def[0]), str(nav_def[1]), str(nav_def[2]))

	toast_stack = ToastStackClass.new(); toast_stack.anchor_left=0.48;toast_stack.anchor_right=0.98;toast_stack.anchor_top=0.10;toast_stack.anchor_bottom=0.42;toast_stack.offset_left=0;toast_stack.offset_right=0;toast_stack.offset_top=0;toast_stack.offset_bottom=0;add_child(toast_stack)
	command_palette = CommandPaletteClass.new(); command_palette.item_chosen.connect(_on_palette_item_chosen); add_child(command_palette); command_palette.set_entries(_build_command_entries())
	_build_drawer()
	_build_simulation_overlay()

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
	for tile_def in [["laws","⚖","قوانین"],["projects","⚒","توسعه"],["technology","⚛","فناوری"],["population","☺","جامعه"],["military","⚔","دفاع"],["network","◍","چندنفره"],["systems","⚙","سامانه‌ها"]]:
		_make_drawer_tile(tiles, str(tile_def[0]), str(tile_def[1]), str(tile_def[2]))
	var sep = HSeparator.new(); box.add_child(sep)
	var sys = HBoxContainer.new(); sys.alignment = BoxContainer.ALIGNMENT_CENTER; sys.add_theme_constant_override("separation", 8); box.add_child(sys)
	_mk_btn(sys, "▼ ذخیره", Vector2(150,52), _on_save_pressed)
	_mk_btn(sys, "▲ بارگذاری", Vector2(162,52), _on_load_pressed)
	_mk_btn(sys, "✕ صدا" if FeedbackManager.muted else "♪ صدا", Vector2(132,52), _on_sound_pressed, "SoundBtn")

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
	var hint=Label.new();hint.text="محاسبات روزبه‌روز انجام می‌شود تا رابط گوشی پاسخ‌گو بماند.";hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;hint.modulate=Color(0.62,0.75,0.81);box.add_child(hint)
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
	var topbar_sb = _style_box(Color(0.018,0.040,0.063,0.97) if not high_contrast else Color(0.010,0.024,0.040,1.0), ACCENT_GOLD if not high_contrast else Color(0.95,0.88,0.60,1.0), 14, 0, 13)
	topbar_sb.set_border_width(SIDE_BOTTOM, 3)
	topbar_sb.set_corner_radius(CORNER_BOTTOM_LEFT, 0); topbar_sb.set_corner_radius(CORNER_BOTTOM_RIGHT, 0)
	result.set_stylebox("panel", "TopBarPanel", topbar_sb)
	result.set_stylebox("panel", "CommandPanel", _style_box(Color(0.012,0.027,0.039,1.0) if high_contrast else Color(0.026,0.060,0.090,0.98), Color(0.45,0.94,0.94,1.0) if high_contrast else Color(0.24,0.58,0.66,0.80), 12, 1 if not high_contrast else 2, padding))
	result.set_stylebox("panel", "EmblemChip", _style_box(Color(0.84,0.64,0.22,0.12), Color(0.85,0.66,0.25,0.55), 12, 1, 7))
	result.set_stylebox("panel", "StatusChip", _style_box(Color(0.052,0.100,0.148,0.95), Color(0.21,0.40,0.52,0.88), 12, 1, 9))
	result.set_stylebox("panel", "KpiCard", _style_box(Color(0.042,0.088,0.132,0.96), Color(0.22,0.42,0.54,0.92), 14, 1, 13))
	result.set_stylebox("panel", "HeroCard", _style_box(Color(0.048,0.096,0.142,0.98), Color(0.80,0.63,0.26,0.95), 18, 2, 22))
	result.set_stylebox("panel", "TickerPanel", _style_box(Color(0.026,0.056,0.084,0.95), Color(0.20,0.37,0.48,0.72), 10, 1, 8))
	result.set_stylebox("panel", "TimeDockPanel", _style_box(Color(0.022,0.048,0.075,0.88), Color(0.20,0.36,0.47,0.55), 16, 1, 8))
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
		result.append({"kind":"system","id":str(system_id),"title":str(SYSTEM_FA.get(system_id,"سامانه")),"group":"سامانه","keywords":str(system_id),"description":"بازکردن پایش و جزئیات سامانه"})
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
	if generation!=page_generation or bool(SettingsManager.get_value("reduce_motion",false)):return
	var delay=0.0
	for child in content.get_children():
		if not child is Control or child.is_queued_for_deletion():continue
		child.modulate.a=0.0
		var tween=create_tween();tween.tween_interval(delay);tween.tween_property(child,"modulate:a",1.0,0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		delay=min(0.12,delay+0.018)

func _unhandled_key_input(event:InputEvent):
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

	match tab_key:
		"map": _build_unified_map()
		"dashboard": _build_dashboard()
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

	_build_settings_card()
	_build_save_slots_card()

# ── چهار شاخص کلیدی کشور در صدر میز فرمان (سبک نوار قدرت HOI4) ──
func _build_command_kpis(st: Dictionary):
	var econ = st.get("economy", {})
	var ind = st.get("indicators", {})
	var growth = float(econ.get("growth_rate", 0.0))
	var growth_icon = "▲" if growth >= 0.0 else "▼"
	var growth_color = ACCENT_GREEN if growth >= 0.0 else ACCENT_RED
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	content.add_child(grid)
	_kpi_card(grid, "◈", "تولید ناخالص", PersianFormatter.format_money(float(econ.get("gdp", 0.0))), "%s %s رشد" % [growth_icon, _fmt_pct(absf(growth))], ACCENT_GREEN if growth >= 0.0 else ACCENT_RED, "economy")
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
		grid.add_child(button)

func _on_municipal_action(action: String, title: String):
	var command = GameCommandClass.create_municipal_action(action)
	if _run_tick_with([command]):
		_toast("🏙️ اقدام شهرداری «%s» اجرا شد" % title)
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
		repeal.pressed.connect(FeedbackManager.play_click); repeal.pressed.connect(_on_law_change.bind(str(law_id),"repeal")); box.add_child(repeal)

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
		enact.pressed.connect(FeedbackManager.play_click); enact.pressed.connect(_on_law_change.bind(str(law_id),"enact")); row.add_child(enact)

func _on_law_change(law_id: String, action: String):
	if _run_tick_with([GameCommandClass.create_law_change(law_id,action)]):
		_toast("⚖️ قانون «%s» %s" % [LawManager.get_law_name(law_id),"تصویب شد" if action=="enact" else "لغو شد"]); _switch_tab("laws")

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
	var hint = Label.new(); hint.text = "وزیر کارآمد خروجی وزارتخانه را بهتر می‌کند؛ پاکدستی پایین خطر رسوایی دارد و وفاداری بیشتر انسجام کابینه را حفظ می‌کند. هر انتصاب سرمایه سیاسی مصرف می‌کند."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; hint.modulate = Color(0.75, 0.82, 0.92); summary.add_child(hint)

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
			dismiss.pressed.connect(FeedbackManager.play_click); dismiss.pressed.connect(_on_cabinet_dismiss.bind(str(ministry_id))); card.add_child(dismiss)
		var candidates_title = Label.new(); candidates_title.text = "نامزدهای معرفی‌شده"; candidates_title.add_theme_font_size_override("font_size", 16); card.add_child(candidates_title)
		for candidate in ministry.get("candidates", []):
			var candidate_id = str(candidate.get("id", ""))
			var row = HBoxContainer.new(); card.add_child(row)
			var info = Label.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.text = PersianFormatter.to_persian_digits("%s | شایستگی %.0f٪ | پاکدستی %.0f٪ | وفاداری %.0f٪" % [candidate.get("name_fa", ""), float(candidate.get("competence", 0.0)) * 100.0, float(candidate.get("integrity", 0.0)) * 100.0, float(candidate.get("loyalty", 0.0)) * 100.0]); row.add_child(info)
			var check = CabinetManager.can_appoint(state, ministry_id, candidate_id)
			var appoint = Button.new(); appoint.text = "انتصاب"; appoint.disabled = not check.valid; appoint.tooltip_text = "" if check.valid else str(check.reason)
			appoint.pressed.connect(FeedbackManager.play_click); appoint.pressed.connect(_on_cabinet_appoint.bind(str(ministry_id), candidate_id, str(candidate.get("name_fa", "نامزد")))); row.add_child(appoint)

func _on_cabinet_appoint(ministry_id: String, candidate_id: String, candidate_name: String):
	if _run_tick_with([GameCommandClass.create_cabinet_appointment(ministry_id, candidate_id)]):
		_toast("👔 %s به کابینه منصوب شد" % candidate_name); _switch_tab("government")

func _on_cabinet_dismiss(ministry_id: String):
	if _run_tick_with([GameCommandClass.create_cabinet_dismissal(ministry_id)]):
		_toast("⛔ وزیر برکنار شد؛ وزارتخانه تا انتصاب بعدی جریمه عملکرد دارد"); _switch_tab("government")

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
	var apply_tax = _mk_btn(c1, "✅ اعمال مالیات جدید (یک ماه می‌گذرد)", Vector2(280, 52), _on_apply_tax)
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
	_mk_btn(c2, "✅ اعمال بودجه (یک ماه می‌گذرد)", Vector2(280, 52), _on_apply_budget)

	# --- آمار مالی ---
	var c3 = _card("📈 آمار مالی")
	_row(c3, "درآمد دولت", PersianFormatter.format_money(econ.get("government_revenue", 0)))
	_row(c3, "هزینه دولت", PersianFormatter.format_money(econ.get("government_spending", 0)))
	_row(c3, "تراز بودجه", PersianFormatter.format_money(econ.get("deficit", 0)),
		_color_for(0.5 + sign(-econ.get("deficit", 0)) * 0.5))
	_row(c3, "بدهی ملی", PersianFormatter.format_money(econ.get("national_debt", 0)))
	_bar(c3, "نسبت بدهی به GDP", clamp(econ.get("debt_to_gdp", 0) / 2.0, 0, 1))

	var cb: Dictionary = st.get("central_bank", {})
	var trade: Dictionary = st.get("trade", {})
	var macro = _card("🏦 سیاست پولی و تجاری")
	_row(macro, "حالت بانک مرکزی", {"independent":"مستقل/قاعده تیلور", "manual_rate":"نرخ دستوری", "inflation_target":"هدف‌گذاری تورم"}.get(str(cb.get("policy_mode", "independent")), "مستقل"))
	_row(macro, "نرخ بهره فعلی", PersianFormatter.format_percent(float(cb.get("interest_rate", 0.15))))
	interest_slider = HSlider.new(); interest_slider.min_value = 0; interest_slider.max_value = 40; interest_slider.step = 0.5; interest_slider.value = float(cb.get("manual_rate", cb.get("interest_rate", 0.15))) * 100.0; macro.add_child(interest_slider)
	_mk_btn(macro, "اعمال نرخ بهره دستوری", Vector2(250, 46), _on_apply_manual_rate)
	inflation_target_slider = HSlider.new(); inflation_target_slider.min_value = 0; inflation_target_slider.max_value = 20; inflation_target_slider.step = 0.5; inflation_target_slider.value = float(cb.get("inflation_target", 0.05)) * 100.0; macro.add_child(inflation_target_slider)
	_mk_btn(macro, "اعمال هدف تورم", Vector2(220, 46), _on_apply_inflation_target)
	_mk_btn(macro, "بازگرداندن استقلال بانک مرکزی", Vector2(280, 46), _on_restore_central_bank_independence)
	_row(macro, "تعرفه فعلی", PersianFormatter.format_percent(float(trade.get("tariff_rate", 0.15))))
	tariff_slider = HSlider.new(); tariff_slider.min_value = 0; tariff_slider.max_value = 60; tariff_slider.step = 1; tariff_slider.value = float(trade.get("tariff_rate", 0.15)) * 100.0; macro.add_child(tariff_slider)
	_mk_btn(macro, "اعمال تعرفه گمرکی", Vector2(220, 46), _on_apply_tariff)
	_build_policy_center()

func _on_apply_manual_rate():
	var rate = float(interest_slider.value) / 100.0
	if _run_tick_with([GameCommandClass.create_monetary_policy("manual_rate", rate)]):
		_toast("🏦 نرخ بهره دستوری %s اعمال شد" % PersianFormatter.format_percent(rate)); _switch_tab("economy")

func _on_apply_inflation_target():
	var target = float(inflation_target_slider.value) / 100.0
	if _run_tick_with([GameCommandClass.create_monetary_policy("inflation_target", target)]):
		_toast("🎯 هدف تورم %s ثبت شد" % PersianFormatter.format_percent(target)); _switch_tab("economy")

func _on_restore_central_bank_independence():
	if _run_tick_with([GameCommandClass.create_monetary_policy("independent", 0.0)]):
		_toast("🏦 بانک مرکزی به قاعده مستقل بازگشت"); _switch_tab("economy")

func _on_apply_tariff():
	var rate = float(tariff_slider.value) / 100.0
	if _run_tick_with([GameCommandClass.create_tariff_set(rate)]):
		_toast("🚢 تعرفه گمرکی %s اعمال شد" % PersianFormatter.format_percent(rate)); _switch_tab("economy")

func _build_policy_center():
	var policy_state: Dictionary = GameState.state.get("policies", {})
	var active: Dictionary = policy_state.get("active", {})
	var capital = float(policy_state.get("political_capital", 0.0))
	var card = _card("📜 مرکز سیاست‌گذاری عمومی")
	_bar(card, "سرمایه سیاسی", capital / max(float(BalanceConfig.get_value("politics.policy_capital_max", 5.0)), 1.0))
	_row(card, "سیاست‌های فعال", PersianFormatter.to_persian_digits(str(active.size())))
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
		row.add_child(button)

func _on_policy_change(policy_id: String, enabled: bool, policy_name: String):
	var command = GameCommandClass.create_policy_change(policy_id, enabled)
	if _run_tick_with([command]):
		_toast("📜 سیاست «%s» %s" % [policy_name, "فعال شد" if enabled else "لغو شد"])
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
		cancel.pressed.connect(FeedbackManager.play_click); cancel.pressed.connect(_on_cancel_national_project.bind(str(project_id))); box.add_child(cancel)

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
		start.pressed.connect(FeedbackManager.play_click); start.pressed.connect(_on_start_national_project.bind(str(project_id), str(definition.get("name_fa", "پروژه")))); row.add_child(start)

func _on_start_national_project(project_id: String, title: String):
	if _run_tick_with([GameCommandClass.create_national_project(project_id)]):
		_toast("🏗️ پروژه «%s» آغاز شد" % title); _switch_tab("projects")

func _on_cancel_national_project(project_id: String):
	if _run_tick_with([GameCommandClass.create_project_cancel(project_id)]):
		_toast("⛔ پروژه «%s» لغو شد" % NationalProjectManager.get_project_name(project_id)); _switch_tab("projects")

# ============================================================
# تب فناوری — درخت پژوهش داده‌محور
# ============================================================
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
		start_button.disabled = current != null

	var unlocked_card = _card("✅ فناوری‌های تکمیل‌شده")
	var unlocked_names: Array = []
	for id in tech.get("unlocked", []):
		unlocked_names.append(TechnologyManager.get_technology_name(str(id)))
	var unlocked_label = Label.new()
	unlocked_label.text = " • ".join(unlocked_names)
	unlocked_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	unlocked_card.add_child(unlocked_label)

func _on_start_research(technology_id: String, technology_name: String):
	var cmd = GameCommandClass.create_research_start(technology_id)
	if _run_tick_with([cmd]):
		_toast("🔬 پژوهش «%s» آغاز شد" % technology_name)
		_switch_tab("technology")

# ============================================================
# تب جمعیت
# ============================================================
func _build_population():
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

	var development: Dictionary = st.get("military_development", {})
	var doctrine_card = _card("🧭 دکترین نظامی")
	_row(doctrine_card, "دکترین فعال", MilitaryManager.get_doctrine_name(str(development.get("doctrine", "balanced"))))
	var doctrine_grid = GridContainer.new(); doctrine_grid.columns = 3; doctrine_card.add_child(doctrine_grid)
	for doctrine_id in MilitaryManager.DOCTRINES.keys():
		var doctrine_button = Button.new(); doctrine_button.text = MilitaryManager.get_doctrine_name(doctrine_id)
		doctrine_button.disabled = str(development.get("doctrine", "balanced")) == doctrine_id
		doctrine_button.pressed.connect(FeedbackManager.play_click)
		doctrine_button.pressed.connect(_on_military_doctrine.bind(str(doctrine_id)))
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
		var cancel = Button.new(); cancel.text = "لغو"; cancel.pressed.connect(FeedbackManager.play_click); cancel.pressed.connect(_on_intelligence_cancel.bind(str(operation_key))); active_row.add_child(cancel)
	for operation_id in IntelligenceOperationManager.get_operation_ids():
		var operation = IntelligenceOperationManager.get_operation(operation_id)
		var operation_target = target if operation.get("scope", "domestic") == "foreign" else ""
		var op_row = HBoxContainer.new(); operations_card.add_child(op_row)
		var op_info = VBoxContainer.new(); op_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; op_row.add_child(op_info)
		var op_title = Label.new(); op_title.text = "%s — %s" % [operation.get("name_fa", operation_id), "خارجی" if operation.get("scope", "domestic") == "foreign" else "داخلی"]; op_title.add_theme_font_size_override("font_size", 16); op_info.add_child(op_title)
		var op_desc = Label.new(); op_desc.text = PersianFormatter.to_persian_digits("%s | مدت %s ماه | خطر افشا %.0f٪" % [operation.get("description", ""), str(operation.get("duration_months", 1)), float(operation.get("detection_risk", 0.0)) * 100.0]); op_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; op_desc.modulate = Color(0.72, 0.78, 0.88); op_info.add_child(op_desc)
		var op_check = IntelligenceOperationManager.can_start(st, operation_id, operation_target)
		var op_start = Button.new(); op_start.text = "آغاز"; op_start.disabled = not op_check.valid; op_start.tooltip_text = "" if op_check.valid else str(op_check.reason); op_start.pressed.connect(FeedbackManager.play_click); op_start.pressed.connect(_on_intelligence_start.bind(str(operation_id), operation_target)); op_row.add_child(op_start)
	var reports: Array = operations_state.get("reports", [])
	for i in range(max(0, reports.size() - 4), reports.size()):
		var report = reports[i]
		_row(operations_card, "گزارش: %s" % WorldManager.get_country_name(str(report.get("target", ""))), "کیفیت %s٪" % PersianFormatter.to_persian_digits(str(int(float(report.get("quality", 0.0)) * 100.0))))

func _on_intelligence_start(operation_id: String, target: String):
	if _run_tick_with([GameCommandClass.create_intelligence_operation(operation_id, target)]):
		_toast("🕶️ عملیات «%s» آغاز شد" % IntelligenceOperationManager.get_operation_name(operation_id)); _switch_tab("military")

func _on_intelligence_cancel(operation_key: String):
	if _run_tick_with([GameCommandClass.create_intelligence_cancel(operation_key)]):
		_toast("⛔ عملیات اطلاعاتی لغو شد"); _switch_tab("military")

func _on_military_doctrine(doctrine_id: String):
	if _run_tick_with([GameCommandClass.create_military_doctrine(doctrine_id)]):
		_toast("🪖 دکترین «%s» فعال شد" % MilitaryManager.get_doctrine_name(doctrine_id)); _switch_tab("military")

func _on_military_program(program_id: String, title: String):
	if _run_tick_with([GameCommandClass.create_military_program(program_id)]):
		_toast("🏗️ برنامه «%s» آغاز شد" % title); _switch_tab("military")

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
	var direct = _card("اتصال مستقیم و همکارانه")
	var direct_grid = GridContainer.new(); direct_grid.columns = 4; direct.add_child(direct_grid)
	_mk_btn(direct_grid,"میزبانی",Vector2(150,48),_on_host_network,"PrimaryAction")
	_mk_btn(direct_grid,"اتصال",Vector2(150,48),_on_join_network)
	_mk_btn(direct_grid,"بازکردن پورت",Vector2(165,48),_on_enable_upnp)
	_mk_btn(direct_grid,"قطع اتصال",Vector2(150,48),_on_disconnect_network)
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
	var state = GameState.state
	var diplomacy = state.get("diplomacy", {})
	var relations: Dictionary = diplomacy.get("relations", {})
	var world: Dictionary = state.get("world", {})
	var player_id = str(world.get("player_country", WorldManager.default_country))
	if selected_world_country == "" or not WorldManager.countries.has(selected_world_country): selected_world_country = player_id

	if int(state.get("tick", 0)) == 0:
		var setup = _hero_card()
		# بنر سینمایی «زمین در شب» — هنر بازی در نخستین نگاه.
		var banner_clip = Control.new(); banner_clip.clip_contents = true; banner_clip.custom_minimum_size = Vector2(0, 315); banner_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL; banner_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var banner = TextureRect.new(); banner.texture = HeroBannerArt; banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; banner.set_anchors_preset(Control.PRESET_FULL_RECT); banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		banner_clip.add_child(banner); setup.add_child(banner_clip)
		# نشان طلایی عقاب و کره — امضای بصری بازی.
		var emblem_box = CenterContainer.new(); emblem_box.mouse_filter = Control.MOUSE_FILTER_IGNORE; setup.add_child(emblem_box)
		var emblem_art = TextureRect.new(); emblem_art.texture = EmblemArt; emblem_art.custom_minimum_size = Vector2(252, 150); emblem_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; emblem_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT; emblem_art.mouse_filter = Control.MOUSE_FILTER_IGNORE; emblem_box.add_child(emblem_art)
		var hero_title = Label.new(); hero_title.text = "شبیه‌ساز کشور"; hero_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; hero_title.add_theme_font_size_override("font_size", 46); setup.add_child(hero_title)
		var hero_sub = Label.new(); hero_sub.text = "فرماندهی یک ملت واقعی؛ ۱۹۵ کشور، ۶۵ سامانه زنده و تصمیم‌های ماهانه شما. کشور و سناریو را برگزینید؛ پس از اجرای نخستین ماه، کشور قابل تغییر نیست."; hero_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; hero_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; hero_sub.modulate = TEXT_MUTED; setup.add_child(hero_sub)
		var row_country = _chooser_row(setup, "⚑ کشور")
		country_select_option = OptionButton.new(); country_select_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var selected_index = 0
		for country_id in WorldManager.get_country_ids():
			var profile = WorldManager.get_country(country_id); country_select_option.add_item("%s · %s" % [profile.get("name_fa", country_id), profile.get("capital_fa", "")]); country_select_option.set_item_metadata(country_select_option.item_count - 1, country_id)
			if country_id == player_id: selected_index = country_select_option.item_count - 1
		country_select_option.select(selected_index); row_country.add_child(country_select_option)
		var row_scenario = _chooser_row(setup, "☆ سناریو")
		scenario_select_option = OptionButton.new(); scenario_select_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var active_scenario = str(state.get("scenario", {}).get("id", ScenarioManager.default_scenario)); var scenario_index = 0
		for scenario_id in ScenarioManager.get_scenario_ids():
			var definition = ScenarioManager.get_scenario(scenario_id); scenario_select_option.add_item("%s · %s" % [definition.get("name_fa", scenario_id), definition.get("difficulty_fa", "")]); scenario_select_option.set_item_metadata(scenario_select_option.item_count - 1, scenario_id)
			if scenario_id == active_scenario: scenario_index = scenario_select_option.item_count - 1
		scenario_select_option.select(scenario_index); scenario_select_option.item_selected.connect(_on_scenario_option_changed); row_scenario.add_child(scenario_select_option)
		scenario_description_lbl = Label.new(); scenario_description_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; scenario_description_lbl.modulate = TEXT_MUTED; scenario_description_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; setup.add_child(scenario_description_lbl); _on_scenario_option_changed(scenario_index)
		var start_button = _mk_btn(setup, "⚑ شروع فرماندهی", Vector2(340,62), _on_country_start_selected, "PrimaryAction"); start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; start_button.add_theme_font_size_override("font_size", 27)
		_pulse_control(start_button)

	var controls = _card("◉ لنزها و لایه‌های نقشه")
	# چیپ‌های لنز (تک‌انتخابی) — جابه‌جایی سریع نگاه تحلیلی روی نقشه.
	map_control_flow = HFlowContainer.new(); map_control_flow.add_theme_constant_override("h_separation",7); map_control_flow.add_theme_constant_override("v_separation",6); controls.add_child(map_control_flow)
	var lens_defs = [
		["political","سیاسی"],
		["relations","روابط"],
		["population","جمعیت"],
		["economy","اقتصاد"],
		["infrastructure","زیرساخت"],
		["satisfaction","رضایت"],
		["security","امنیت"],
		["weather","اقلیم"],
		["resources","منابع"],
		["military","نظامی"],
		# گروه اقتصادی
		["agriculture","کشاورزی"],
		["industry","صنعت"],
		["trade_layer","تجارت"],
		["tourism","گردشگری"],
		["central_bank","بانک مرکزی"],
		["stock_market","بورس"],
		["retail","خرده‌فروشی"],
		["fuel_stations","سوخت"],
		# گروه اجتماعی
		["health","بهداشت"],
		["education","آموزش"],
		["welfare","رفاه"],
		["family","خانواده"],
		["sports_youth","ورزش"],
		["ethnicity","قومیت"],
		["culture","فرهنگ"],
		# گروه سیاسی و امنیتی
		["judicial","قضایی"],
		["intelligence","اطلاعات"],
		["administration","اداره"],
		["elections","انتخابات"],
		["politics","سیاست"],
		["statistics","آمار"],
		["emergency","بحران"],
		# گروه زیرساخت و محیط
		["environment","محیط‌زیست"],
		["urban_facilities","تاسیسات شهری"],
		["public_services","خدمات عمومی"],
		["transport_roads","راه‌ها"],
		["settlements","سکونتگاه‌ها"],
		# گروه نظامی پیشرفته
		["military_power","قدرت نظامی"],
		["trade_route_warfare","جنگ تجاری"]
	]
	for lens in lens_defs:
		var chip = Button.new(); chip.text = lens[1]; chip.toggle_mode = true; chip.custom_minimum_size = Vector2(0,50); chip.add_theme_font_size_override("font_size",21)
		chip.theme_type_variation = "LensChipActive" if lens[0] == map_base_layer else "LensChip"
		chip.set_meta("lens_layer", lens[0]); chip.set_pressed_no_signal(lens[0] == map_base_layer)
		chip.pressed.connect(FeedbackManager.play_click); chip.pressed.connect(_on_map_lens_chip.bind(str(lens[0])))
		map_control_flow.add_child(chip)
	var overlay_caption = Label.new(); overlay_caption.text = "لایه‌های اطلاعاتی روی نقشه"; overlay_caption.add_theme_font_size_override("font_size", 19); overlay_caption.modulate = TEXT_FAINT; controls.add_child(overlay_caption)
	# پیل‌های لایه (چندانتخابی) با چراغ وضعیت طلایی.
	map_overlay_grid = GridContainer.new(); map_overlay_grid.columns = 5; map_overlay_grid.add_theme_constant_override("h_separation",7); map_overlay_grid.add_theme_constant_override("v_separation",6); controls.add_child(map_overlay_grid)
	var overlay_defs = [["wars","جنگ"],["alliances","اتحاد"],["trade","تجارت"],["air","پرواز"],["sea","دریا"],["land","زمین"],["cities","شهرها"],["transport","راه و ریل"],["intelligence","اطلاعاتی"]]
	for definition in overlay_defs:
		var pill = Button.new(); pill.text = definition[1]; pill.toggle_mode = true; pill.custom_minimum_size = Vector2(0,46); pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL; pill.add_theme_font_size_override("font_size",19)
		pill.theme_type_variation = "PillToggle"
		pill.button_pressed = bool(map_overlays.get(definition[0],false))
		pill.toggled.connect(_on_unified_overlay_toggled.bind(str(definition[0])))
		map_overlay_grid.add_child(pill)
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

	var map_countries: Dictionary = world.get("countries", {}).duplicate(true)
	for war_target in world.get("wars", {}).keys():
		if map_countries.has(war_target): map_countries[war_target]["at_war"] = true
	for npc_war in world.get("npc_wars", {}).values():
		for participant in [str(npc_war.get("a", "")), str(npc_war.get("b", ""))]:
			if map_countries.has(participant): map_countries[participant]["at_war"] = true
	var map_card = _card("◈ نقشه پیوسته جهان تا شهر")
	map_wrap = Control.new(); map_wrap.custom_minimum_size = Vector2(0, 860); map_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL; map_wrap.mouse_filter = Control.MOUSE_FILTER_PASS; map_card.add_child(map_wrap)
	current_unified_map = UnifiedMapClass.new(); current_unified_map.selected_country = selected_world_country; current_unified_map.selected_unit = selected_country_unit
	current_unified_map.configure(map_countries, relations, player_id, world, state, map_base_layer, map_overlays, map_camera_center, map_zoom)
	current_unified_map.country_selected.connect(_on_unified_country_selected); current_unified_map.unit_selected.connect(_on_unified_unit_selected); current_unified_map.route_selected.connect(_on_unified_route_selected); current_unified_map.view_changed.connect(_on_unified_view_changed)
	map_wrap.add_child(current_unified_map)
	current_unified_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	# ستون شناور دوربین روی نقشه — دسترسی سریع بدون ترک نمای راهبردی.
	var fab_col = VBoxContainer.new(); fab_col.add_theme_constant_override("separation", 10)
	fab_col.anchor_left = 0.0; fab_col.anchor_right = 0.0; fab_col.anchor_top = 0.5; fab_col.anchor_bottom = 0.5
	fab_col.offset_left = 14; fab_col.offset_right = 76; fab_col.offset_top = -160; fab_col.offset_bottom = 160
	fab_col.mouse_filter = Control.MOUSE_FILTER_PASS
	map_wrap.add_child(fab_col)
	for fab_def in [["✚","in","بزرگ‌نمایی"],["−","out","کوچک‌نمایی"],["⌂","home","نمای کشور من"],["⊙","selected","نمای کشور انتخابی"],["◐","world","نمای جهان"]]:
		var fab = Button.new(); fab.text = str(fab_def[0]); fab.tooltip_text = str(fab_def[2]); fab.custom_minimum_size = Vector2(62,62); fab.add_theme_font_size_override("font_size", 27); fab.theme_type_variation = "MapFab"
		fab.pressed.connect(FeedbackManager.play_click); fab.pressed.connect(_on_map_camera_command.bind(str(fab_def[1]))); fab_col.add_child(fab)
	map_context_host=VBoxContainer.new();map_context_host.add_theme_constant_override("separation",10);content.add_child(map_context_host)
	_refresh_map_context_panel()
	call_deferred("_apply_responsive_layout")

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
		var check = SeasonalManager.can_action(state, action[0]); var button = Button.new(); button.text = action[1]; button.custom_minimum_size = Vector2(190,46); button.disabled = not check.valid; button.tooltip_text = "" if check.valid else str(check.reason); button.pressed.connect(FeedbackManager.play_click); button.pressed.connect(_on_map_municipal_action.bind(str(action[0]),str(action[1]))); action_grid.add_child(button)
	var open_row = HBoxContainer.new(); action_card.add_child(open_row)
	_mk_btn(open_row, "مرکز پروژه‌های ملی", Vector2(220,46), _switch_tab.bind("projects"))
	_mk_btn(open_row, "مدیریت دفاع", Vector2(180,46), _switch_tab.bind("military"))
	_mk_btn(open_row, "اقتصاد و بودجه", Vector2(190,46), _switch_tab.bind("economy"))

func _on_unified_layer_selected(index: int, selector: OptionButton):
	if index < 0 or index >= selector.item_count: return
	map_base_layer = str(selector.get_item_metadata(index))
	if is_instance_valid(current_unified_map): current_unified_map.set_base_layer(map_base_layer)

# ردیف برچسب‌دار انتخاب‌گرها در کارت قهرمان آغاز بازی.
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

			if cmd != null and _run_tick_with([cmd]):
				_toast("🗺️ %s از %s به %s اجرا شد" % [mode, WorldManager.get_country_name(from_c), WorldManager.get_country_name(to_c)])
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

			if cmd != null and _run_tick_with([cmd]):
				_toast("🗺️ %s از %s به %s" % [mode, from_c, to_c])
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
	if _run_tick_with([GameCommandClass.create_municipal_action(action)]):
		_toast("اقدام نقشه اجرا شد · " + title); _switch_tab("map")

func _on_trade_route_attack(route_id: String, route_type: String, operation: String, from_c: String, to_c: String, title: String):
	var cmd = GameCommandClass.create_trade_route_attack(route_id, route_type, operation, from_c, to_c)
	if _run_tick_with([cmd]):
		_toast("⚔️ %s بر مسیر %s → %s اجرا شد" % [title, from_c, to_c])
		_switch_tab("map")
	else:
		_toast("⚠️ عملیات مسیر تجاری ممکن نشد")

func _on_chokepoint_attack(chokepoint_id: String, action: String, title: String):
	var cmd = GameCommandClass.create_chokepoint_action(chokepoint_id, action)
	if _run_tick_with([cmd]):
		_toast("🌊 عملیات %s در %s اجرا شد" % [action, title])
		_switch_tab("map")

func _on_map_operation(target_country: String, operation_type: String, title: String):
	var cmd = GameCommandClass.create_map_operation(target_country, operation_type, {})
	if _run_tick_with([cmd]):
		_toast("🗺️ %s روی %s اجرا شد" % [title, _fa_country(target_country)])
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
	_bar(card, "زیرساخت منطقه", float(metrics.get("infrastructure", 0.0)))
	_bar(card, "رضایت منطقه", float(metrics.get("satisfaction", 0.0)))
	_bar(card, "امنیت منطقه", float(metrics.get("security", 0.0)))
	_bar(card, "ظرفیت منابع", float(metrics.get("resource_score", 0.0)))
	_bar(card, "اهمیت نظامی", float(metrics.get("military_score", 0.0)))
	_bar(card, "ریسک اقلیمی", float(metrics.get("weather_risk", 0.0)))

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
		["declare_war", "اعلام جنگ"], ["offer_peace", "پیشنهاد صلح"]
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
		action_grid.add_child(button)

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
	if _run_tick_with([cmd]):
		_toast("🌍 «%s» درباره %s اجرا شد" % [action_title, _fa_country(country)])
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
	_toast("🌐 وضعیت نوبت ماهانه %s از میزبان همگام شد" % PersianFormatter.to_persian_digits(str(tick)))

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
	var last = EventLog.get_last(2)
	last.reverse()
	for e in last:
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
		btn.text = "▶ خودکار: روشن" if auto_tick else "خودکار: خاموش"

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
		_toast("تصمیم برای تأیید به میزبان ارسال شد")
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
	if result.success:
		GameState.set_state(result.state,result.version,result.tick)
		if not P2PManager.is_network_active() or P2PManager.is_host:SaveManager.maybe_autosave(result.tick)
		P2PManager.broadcast_state(result.state,result.version,result.tick)
		_refresh_header();_render_events();_engagement_pulse();FeedbackManager.play_success()
		if refresh_page:_switch_tab(current_tab)
		return true
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
			_run_tick_with([])

func _on_tick_completed(new_state, events):
	current_state = new_state.duplicate(true)
	for event in events:
		if str(event.get("type", "")) == "achievement_unlocked":
			FeedbackManager.play_achievement()
			break

func _on_tick_failed(reason):
	print("خطای تیک: %s" % reason)
