extends Node
# موتور شبیه‌سازی اتمی - بخش ۳.۶ و ۳.۷ - مهم‌ترین اصل معماری

# preload مستقیم - بدون وابستگی به کش کلاس سراسری (سازگار با import سرد و CI)
const GameCommandClass = preload("res://scripts/core/command.gd")
const NpcTurnManagerClass = preload("res://scripts/core/npc_turn_manager.gd")
const VersioningClass = preload("res://scripts/core/versioning.gd")
const DecisionManagerClass = preload("res://scripts/core/decision_manager.gd")
const ProgressionManagerClass = preload("res://scripts/core/progression_manager.gd")

const SUPPORTED_COMMANDS = [
	"next_tick", "tax_set", "budget_allocate", "monetary_policy", "tariff_set", "research_start", "diplomacy",
	"country_select", "policy_change", "municipal_action", "military_program", "military_doctrine", "national_project", "cabinet_change", "law_change", "intelligence_operation", "decision_resolve",
	"trade_route_attack", "chokepoint_action", "map_operation", "battle_plan", "construction", "map_building",
	"assassinate", "leader_hidden", "leader_name", "faction_action", "faction_deal", "set_war_goal",
	"general_recruit", "general_assign", "media_policy", "media_campaign",
	"commodity_trade", "org_toggle", "org_vote",
	"snap_election", "campaign_promise", "forex_intervene", "forex_devalue",
	"capital_control", "governor_appoint", "crisis_stance", "rivalry_action", "shadow_action",
	"court_action", "energy_action", "industry_action", "succession_action", "labor_action",
	"epidemic_action", "arms_action", "cyber_action", "migration_action", "culture_action",
	"education_action", "agriculture_action", "tourism_action", "urban_action", "security_action",
	"infra_action", "climate_action", "welfare_action", "space_action", "trade_policy_action",
	"banking_action", "fdi_action", "ambassador_action", "digital_action", "sports_action",
	"dilemma_resolve", "stock_action", "veterans_action", "heritage_action",
	"transport_action", "retail_action", "ethnicity_action",
	"water_action", "research_action", "civic_action",
	"diaspora_action", "civil_defense_action", "blue_economy_action",
	"creative_action", "demographic_action", "watershed_action",
	"prison_action", "statistics_action", "mining_action",
	"waste_action", "insurance_action", "rural_action",
	"judicial_reform_action", "election_action", "fuel_action",
	"housing_action", "startup_action", "sme_action",
	"supply_action", "care_action", "science_action",
	"downstream_action", "higher_ed_action", "food_chain_action",
	"pharma_action", "ip_action", "transit_action",
	"disaster_action", "livestock_action", "textile_action",
	"basic_industry_action", "nation_brand_action", "ai_action",
	"tax_action", "ev_action", "health_tourism_action",
	"defense_industry_action", "knowledge_economy_action", "waste_mgmt_action",
	"aerospace_action", "petrochemical_action", "pro_sports_action", "mega_event",
	"aviation_action", "postal_action", "standards_action"
]
const MAX_COMMAND_RECEIPTS = 512

# ── هزینه اقدامات عمرانی/سیاستی (واقع‌گرایی) ──
# سهم از GDP سالانه که با هر اقدام موفق به بدهی ملی افزوده می‌شود (تأمین مالی بدهی‌محور)؛
# بهره و سقف بدهی توسط سیستم اقتصاد (۳.۱۰) پیامدسازی می‌شود. نرخ‌گذاری قانونی (مالیات) رایگان است.
const ACTION_COST_SHARES = {
	"aviation_action": {"airports": 0.006, "fleet": 0.004, "safety": 0.0008, "hub": 0.005, "cargo": 0.002},
	"postal_action": {"network": 0.004, "sorting": 0.002, "lastmile": 0.003, "ecommerce": 0.0010, "tracking": 0.0006},
	"standards_action": {"metrology": 0.0012, "labs": 0.0020, "accreditation": 0.0008, "surveillance": 0.0004, "export_gate": 0.0008},
	"aerospace_action": {"launch": 0.008, "factory": 0.006, "sensing": 0.003, "telecom": 0.003, "rnd": 0.002},
	"petrochemical_action": {"feedstock": 0.002, "plants": 0.006, "downstream": 0.004, "catalyst": 0.002, "exports": 0.001},
	"pro_sports_action": {"leagues": 0.0015, "infrastructure": 0.004, "events": 0.0008, "academy": 0.002, "exports": 0.0006},
	"defense_industry_action": {"production": 0.005, "rnd": 0.003, "maintenance": 0.001, "training": 0.001, "exports": 0.0005},
	"knowledge_economy_action": {"park": 0.004, "incubator": 0.002, "startup": 0.0015, "commercialize": 0.001, "vc": 0.0008},
	"waste_mgmt_action": {"collection": 0.003, "separation": 0.001, "recycling": 0.003, "wte": 0.004, "landfill": 0.002},
	"ev_action": {"battery": 0.005, "research": 0.002, "production": 0.004, "charging": 0.003, "recycling": 0.0015},
	"health_tourism_action": {"hospital": 0.005, "quality": 0.001, "wellness": 0.002, "visa": 0.0002, "accreditation": 0.0008, "marketing": 0.0006},
	"tax_action": {"compliance": 0.0010, "digital": 0.0015, "bracket": 0.0002},
}

# ── سطح‌بندی هزینه اقدام‌های بدون نرخ صریح (بازرسی مقیاس اثرات) ──
# خانواده‌ای که در ACTION_COST_SHARES سطر ندارد (یا مدیرش چیزی شارژ نکرده است)، بر
# اساس ماهیت برنامه در یکی از چهار سطح می‌افتد؛ مقادیر = سهم از تولید ناخالص سالانه:
const ACTION_FALLBACK_FAMILY = {
	"ambassador_action": "symbolic", "succession_action": "symbolic",
	"rivalry_action": "symbolic", "court_action": "symbolic",
	"digital_action": "admin", "statistics_action": "admin", "judicial_reform_action": "admin",
	"election_action": "admin", "civic_action": "admin", "stock_action": "admin",
	"banking_action": "admin", "insurance_action": "admin", "trade_policy_action": "admin",
	"fdi_action": "admin", "shadow_action": "admin", "ip_action": "admin",
	"agriculture_action": "capital", "arms_action": "capital", "basic_industry_action": "capital",
	"blue_economy_action": "capital", "civil_defense_action": "capital", "climate_action": "capital",
	"disaster_action": "capital", "education_action": "capital", "energy_action": "capital",
	"fuel_action": "capital", "higher_ed_action": "capital", "housing_action": "capital",
	"industry_action": "capital", "infra_action": "capital", "mining_action": "capital",
	"prison_action": "capital", "space_action": "capital", "transit_action": "capital",
	"transport_action": "capital", "urban_action": "capital", "waste_action": "capital",
	"water_action": "capital", "watershed_action": "capital",
}
const ACTION_FALLBACK_TIERS = {
	"symbolic": 0.0002,
	"admin": 0.0005,
	"standard": 0.0012,
	"capital": 0.0030,
}
const ACTION_TIER_FA = {
	"symbolic": ["اقدام نمادین", "۰.۰۲٪"],
	"admin": ["برنامه اداری", "۰.۰۵٪"],
	"standard": ["برنامه ملی", "۰.۱۲٪"],
	"capital": ["طرح سرمایه‌ای", "۰.۳۰٪"],
}

signal tick_completed(new_state, events)
signal tick_failed(reason)
signal tick_progress(day, total_days, phase)

# ترتیب سیستم‌ها برای اجرای دترمینستیک - 33 سیستم اصلی
var system_order = [
	"resources",      # 3.9
	"economy",        # 3.10
	"population",     # 3.11
	"politics",       # 3.12
	"military",       # 3.13
	"diplomacy",      # 3.14
	"infrastructure", # 3.15
	"technology",     # 3.16
	"judicial",       # 3.17 - دسته اول 3تایی
	"security",       # 3.18
	"health",         # 3.19
	"education",      # 3.20
	"welfare",        # 3.21
	"culture",        # 3.22
	"intelligence",   # 3.23
	"environment",    # 3.24
	"central_bank",   # 3.25
	"administration", # 3.26
	"agriculture",    # 3.27
	"industry",       # 3.28
	"trade",          # 3.29
	"tourism",        # 3.30
	"ethnicity",      # 3.31
	"stock_market",   # 3.33
	"statistics",     # 3.34
	"emergency",      # 3.35
	"sports_youth",   # 3.36
	"veterans",       # 3.37
	"family",         # 3.38
	"fisheries",      # 3.39
	"heritage",       # 3.40
	"space",          # 3.41
	"elections",      # 3.65
	"settlements",    # 3.42 تفصیلی
	"transport_roads",# 3.43 تفصیلی
	"hospitality",    # 3.44
	"retail",         # 3.45
	"fuel_stations",  # 3.46
	"urban_facilities", # 3.47
	"physical",       # 3.42-3.52 لایه تجمیعی فیزیکی
	"public_services",   # 3.48
	"industry_sites",    # 3.49
	"financial_services",# 3.50
	"public_religious",  # 3.51
	"government_buildings", # 3.52
	"public_transport",  # 3.70
	"people",            # 3.53-3.62 لایه تجمیعی انسانی
	"citizens_detail",   # 3.53
	"workforce_detail",  # 3.54
	"officials",         # 3.55
	"politicians_detail",# 3.56
	"public_employees",  # 3.57
	"private_sector",    # 3.58
	"elites_detail",     # 3.59
	"security_forces_detail", # 3.60
	"religious_leaders", # 3.61
	"households_detail_full", # 3.62
	"political_career",  # 3.72
	"migration_detail",  # 3.69
	"prison",            # 3.67
	"human_states",      # 3.66
	"international_orgs",# 3.68
	"foreign_affairs",   # 3.71
	"interdependency",   # 3.63 مدل اثرگذاری متقابل
	"quantitative",      # 3.64 دقیق‌سازی کمّی و زمانی
	"trade_route_warfare", # 3.80 جنگ مسیرهای تجاری - نقشه‌محور
	"map_advanced"       # 3.90 عملیات پیشرفته نقشه‌محور - طرح نبرد و ساخت‌وساز
]

# بهینه‌سازی حرفه‌ای: سیستم‌های حیاتی روزانه، بقیه هفتگی/ماهانه - ۶۰٪ افزایش کارایی
# روزانه: ۲۵ سیستم حیاتی برای جنگ و اقتصاد
const DAILY_SYSTEMS = [
	"resources", "economy", "population", "politics", "military", "diplomacy",
	"infrastructure", "security", "health", "trade", "intelligence",
	"central_bank", "administration", "industry", "emergency",
	"public_services", "security_forces_detail", "interdependency",
	"trade_route_warfare", "map_advanced", "people", "citizens_detail",
	"workforce_detail", "human_states", "quantitative"
]
# هفتگی: ۲۰ سیستم مهم اما نه حیاتی - هر ۷ روز
const WEEKLY_SYSTEMS = [
	"technology", "judicial", "education", "welfare", "culture",
	"environment", "agriculture", "tourism", "ethnicity", "stock_market",
	"settlements", "transport_roads", "fuel_stations", "urban_facilities",
	"physical", "government_buildings", "officials", "public_employees",
	"private_sector", "migration_detail"
]
# ماهانه: ۲۲ سیستم کم‌اهمیت - فقط روز ۱ و ۱۵ ماه
const MONTHLY_SYSTEMS = [
	"statistics", "sports_youth", "veterans", "family", "fisheries",
	"heritage", "space", "elections", "hospitality", "retail",
	"industry_sites", "financial_services", "public_religious",
	"public_transport", "politicians_detail", "elites_detail",
	"religious_leaders", "households_detail_full", "political_career",
	"prison", "international_orgs", "foreign_affairs"
]

# سیستم‌های لود شده
var systems: Dictionary = {}

func _ready():
	# لود سیستم‌های پیاده‌سازی شده
	systems["resources"] = load("res://scripts/systems/resources_system.gd").new()
	systems["economy"] = load("res://scripts/systems/economy_system.gd").new()
	systems["population"] = load("res://scripts/systems/population_system.gd").new()
	systems["politics"] = load("res://scripts/systems/politics_system.gd").new()
	systems["military"] = load("res://scripts/systems/military_system.gd").new()
	systems["diplomacy"] = load("res://scripts/systems/diplomacy_system.gd").new()
	systems["infrastructure"] = load("res://scripts/systems/infrastructure_system.gd").new()
	systems["technology"] = load("res://scripts/systems/technology_system.gd").new()
	systems["judicial"] = load("res://scripts/systems/judicial_system.gd").new()
	systems["security"] = load("res://scripts/systems/security_system.gd").new()
	systems["health"] = load("res://scripts/systems/health_system.gd").new()
	systems["education"] = load("res://scripts/systems/education_system.gd").new()
	systems["welfare"] = load("res://scripts/systems/welfare_system.gd").new()
	systems["environment"] = load("res://scripts/systems/environment_system.gd").new()
	systems["culture"] = load("res://scripts/systems/culture_system.gd").new()
	systems["intelligence"] = load("res://scripts/systems/intelligence_system.gd").new()
	systems["trade_route_warfare"] = load("res://scripts/systems/trade_route_warfare_system.gd").new()
	systems["map_advanced"] = load("res://scripts/systems/map_advanced_system.gd").new()
	systems["central_bank"] = load("res://scripts/systems/central_bank_system.gd").new()
	systems["trade"] = load("res://scripts/systems/trade_system.gd").new()
	systems["tourism"] = load("res://scripts/systems/tourism_system.gd").new()
	systems["stock_market"] = load("res://scripts/systems/stock_market_system.gd").new()
	systems["agriculture"] = load("res://scripts/systems/agriculture_system.gd").new()
	systems["industry"] = load("res://scripts/systems/industry_system.gd").new()
	# بارگذاری همه لایه‌های تکمیلی و نام‌های نگاشت‌شده
	_load_remaining_systems()
	_validate_system_coverage()
	print("موتور شبیه‌سازی با %d سیستم لود شد" % systems.size())

func _validate_system_coverage():
	# شفافیت (قانون ۴): هر سیستمی که در system_order است باید پیاده‌سازی واقعی داشته باشد؛
	# اگر نه، هشدار صریح می‌گیریم تا سیستم بی‌صدا اجرا نشود.
	for sys_name in system_order:
		if not systems.has(sys_name):
			push_warning("هشدار: سیستم «%s» در system_order است اما هیچ پیاده‌سازی‌ای بارگذاری نشده — این سیستم در شبیه‌سازی اجرا نمی‌شود!" % sys_name)

func _load_remaining_systems():
	var remaining = ["administration", "ethnicity", "statistics", "emergency", "sports_youth", "veterans", "family", "fisheries", "heritage", "space", "elections", "physical", "people"]
	for name in remaining:
		var path = "res://scripts/systems/%s_system.gd" % name
		if ResourceLoader.exists(path):
			systems[name] = load(path).new()
		else:
			# محافظ سازگاری: نبود یک افزونه نباید کل پروژه را در شروع متوقف کند،
			# اما بی‌صدایی خطرناک است؛ هشدار ثبت می‌شود تا سیستم ناقص دیده شود.
			push_warning("هشدار: سیستم «%s» پیاده‌سازی ندارد (%s) — به‌جای آن base_system بارگذاری شد و این سیستم در شبیه‌سازی غیرفعال است!" % [name, path])
			systems[name] = load("res://scripts/systems/base_system.gd").new()

	# لود سیستم‌های لایه فیزیکی و انسانی (با نام متفاوت)
	if ResourceLoader.exists("res://scripts/systems/physical_system.gd"):
		systems["physical"] = load("res://scripts/systems/physical_system.gd").new()
	if ResourceLoader.exists("res://scripts/systems/people_system.gd"):
		systems["people"] = load("res://scripts/systems/people_system.gd").new()
	if ResourceLoader.exists("res://scripts/systems/settlements_system.gd"):
		systems["settlements"] = load("res://scripts/systems/settlements_system.gd").new()
	if ResourceLoader.exists("res://scripts/systems/transport_roads_system.gd"):
		systems["transport_roads"] = load("res://scripts/systems/transport_roads_system.gd").new()

	if ResourceLoader.exists("res://scripts/systems/retail_market_system.gd"):
		systems["retail"] = load("res://scripts/systems/retail_market_system.gd").new()
	if ResourceLoader.exists("res://scripts/systems/fuel_stations_system.gd"):
		systems["fuel_stations"] = load("res://scripts/systems/fuel_stations_system.gd").new()
	if ResourceLoader.exists("res://scripts/systems/public_services_system.gd"):
		systems["public_services"] = load("res://scripts/systems/public_services_system.gd").new()
	if ResourceLoader.exists("res://scripts/systems/industry_sites_system.gd"):
		systems["industry_sites"] = load("res://scripts/systems/industry_sites_system.gd").new()
	if ResourceLoader.exists("res://scripts/systems/public_religious_system.gd"):
		systems["public_religious"] = load("res://scripts/systems/public_religious_system.gd").new()
	if ResourceLoader.exists("res://scripts/systems/government_buildings_system.gd"):
		systems["government_buildings"] = load("res://scripts/systems/government_buildings_system.gd").new()
	if ResourceLoader.exists("res://scripts/systems/citizens_system.gd"):
		systems["citizens_detail"] = load("res://scripts/systems/citizens_system.gd").new()
	if ResourceLoader.exists("res://scripts/systems/financial_services_system.gd"):
		systems["financial_services"] = load("res://scripts/systems/financial_services_system.gd").new()
	if ResourceLoader.exists("res://scripts/systems/urban_facilities_system.gd"):
		systems["urban_facilities"] = load("res://scripts/systems/urban_facilities_system.gd").new()

	if ResourceLoader.exists("res://scripts/systems/workforce_jobs_system.gd"):
		systems["workforce_detail"] = load("res://scripts/systems/workforce_jobs_system.gd").new()
	if ResourceLoader.exists("res://scripts/systems/officials_managers_system.gd"):
		systems["officials"] = load("res://scripts/systems/officials_managers_system.gd").new()
	if ResourceLoader.exists("res://scripts/systems/politicians_system.gd"):
		systems["politicians_detail"] = load("res://scripts/systems/politicians_system.gd").new()
	if ResourceLoader.exists("res://scripts/systems/public_employees_system.gd"):
		systems["public_employees"] = load("res://scripts/systems/public_employees_system.gd").new()
	if ResourceLoader.exists("res://scripts/systems/private_sector_system.gd"):
		systems["private_sector"] = load("res://scripts/systems/private_sector_system.gd").new()
	if ResourceLoader.exists("res://scripts/systems/elites_system.gd"):
		systems["elites_detail"] = load("res://scripts/systems/elites_system.gd").new()
	if ResourceLoader.exists("res://scripts/systems/security_forces_system.gd"):
		systems["security_forces_detail"] = load("res://scripts/systems/security_forces_system.gd").new()
	if ResourceLoader.exists("res://scripts/systems/religious_leaders_system.gd"):
		systems["religious_leaders"] = load("res://scripts/systems/religious_leaders_system.gd").new()
	if ResourceLoader.exists("res://scripts/systems/households_system.gd"):
		systems["households_detail_full"] = load("res://scripts/systems/households_system.gd").new()
	if ResourceLoader.exists("res://scripts/systems/interdependency_system.gd"):
		systems["interdependency"] = load("res://scripts/systems/interdependency_system.gd").new()
	if ResourceLoader.exists("res://scripts/systems/quantitative_temporal_system.gd"):
		systems["quantitative"] = load("res://scripts/systems/quantitative_temporal_system.gd").new()
	if ResourceLoader.exists("res://scripts/systems/human_states_system.gd"):
		systems["human_states"] = load("res://scripts/systems/human_states_system.gd").new()
	if ResourceLoader.exists("res://scripts/systems/prison_system.gd"):
		systems["prison"] = load("res://scripts/systems/prison_system.gd").new()
	if ResourceLoader.exists("res://scripts/systems/international_orgs_system.gd"):
		systems["international_orgs"] = load("res://scripts/systems/international_orgs_system.gd").new()
	if ResourceLoader.exists("res://scripts/systems/migration_system.gd"):
		systems["migration_detail"] = load("res://scripts/systems/migration_system.gd").new()
	if ResourceLoader.exists("res://scripts/systems/public_transport_system.gd"):
		systems["public_transport"] = load("res://scripts/systems/public_transport_system.gd").new()
	if ResourceLoader.exists("res://scripts/systems/foreign_affairs_system.gd"):
		systems["foreign_affairs"] = load("res://scripts/systems/foreign_affairs_system.gd").new()
	if ResourceLoader.exists("res://scripts/systems/political_career_system.gd"):
		systems["political_career"] = load("res://scripts/systems/political_career_system.gd").new()
	if ResourceLoader.exists("res://scripts/systems/hospitality_system.gd"):
		systems["hospitality"] = load("res://scripts/systems/hospitality_system.gd").new()

# تابع اصلی تیک - اجرای اتمی (همگام)
func tick(current_state: Dictionary, current_version: int, current_tick: int, commands: Array) -> Dictionary:
	var prep = _tick_setup(current_state, current_version, current_tick, commands)
	if not prep.success:
		return prep
	var compute_result = _compute_all_systems(prep.snapshot, prep.snapshot_tick)
	return _tick_finish(prep, current_state, commands, compute_result)

# نسخه غیرمسدودکننده؛ بین روزهای محاسبه فریم رها می‌شود تا رابط کاربری زنده بماند.
# منطق با مسیر همگام کاملاً مشترک است تا برابری دترمینستیک (تست one-way-byte-equality) حفظ شود.
func tick_async(current_state: Dictionary, current_version: int, current_tick: int, commands: Array) -> Dictionary:
	var prep = _tick_setup(current_state, current_version, current_tick, commands)
	if not prep.success:
		return prep
	emit_signal("tick_progress", 0, int(prep.snapshot.get("time", {}).get("days_in_month", 30)), "آماده‌سازی")
	var compute_result = await _compute_all_systems_async(prep.snapshot, prep.snapshot_tick)
	return _tick_finish(prep, current_state, commands, compute_result)

# مرحله ۱ و ۲ تیک: فراداده، اعتبارسنجی، آغاز تراکنش، Snapshot و اعمال فرمان‌ها
func _tick_setup(current_state: Dictionary, current_version: int, current_tick: int, commands: Array) -> Dictionary:
	_prepare_command_metadata(commands, current_tick + 1, current_version + 1)
	var validation = _validate_commands(commands, current_state, current_tick + 1, current_version + 1)
	if not validation.valid:
		EventLog.log_event("tick_failed_validation", {"reason": validation.reason}, current_tick, current_version)
		emit_signal("tick_failed", validation.reason)
		return _tick_failure(validation.reason, current_state, current_version, current_tick)

	# تمام رویدادهای محاسبه نیز بخشی از تراکنش‌اند؛ Rollback نباید رد کاذب باقی بگذارد.
	if not EventLog.begin_transaction():
		var tx_reason = "تراکنش رویداد دیگری هنوز باز است"
		emit_signal("tick_failed", tx_reason)
		return _tick_failure(tx_reason, current_state, current_version, current_tick)

	var snapshot = current_state.duplicate(true)
	var snapshot_tick = current_tick + 1

	# ست seed برای دترمینستیک بودن
	var seed_val = snapshot.get("seed", 12345) + snapshot_tick
	Deterministic.set_seed(seed_val)
	snapshot["seed"] = seed_val

	# اعمال فرمان‌ها روی snapshot
	for cmd in commands:
		snapshot = _apply_command_to_snapshot(snapshot, cmd)

	# نوبت ماهانه آغاز می‌شود و روزهای داخلی آن در موتور اجرا خواهند شد.
	snapshot = TimeManager.begin_turn(snapshot, snapshot_tick)

	# فاز تصمیم‌گیری نوبت: هر کشور غیربازیکن تصمیم‌های این نوبت را می‌گیرد و ثبت می‌کند؛
	# اجرای تصمیم‌ها در پایان همان نوبت (simulate_npc_month) انجام می‌شود.
	snapshot = NpcTurnManagerClass.plan_npc_turn(snapshot, snapshot_tick).state

	return {
		"success": true, "snapshot": snapshot,
		"current_version": current_version, "current_tick": current_tick,
		"snapshot_tick": snapshot_tick
	}

# مرحله ۴ و ۵ تیک: Rollback یا Commit اتمی (مشترک بین همگام و ناهمگام)
func _tick_finish(prep: Dictionary, current_state: Dictionary, commands: Array, compute_result: Dictionary) -> Dictionary:
	var current_version = int(prep.current_version)
	var current_tick = int(prep.current_tick)
	var snapshot_tick = int(prep.snapshot_tick)
	if not compute_result.success:
		# Rollback - نه وضعیت و نه رویدادهای میانی اعمال نمی‌شوند.
		EventLog.rollback_transaction()
		EventLog.log_event("tick_rollback", {"reason": compute_result.reason, "tick": snapshot_tick}, current_tick, current_version)
		emit_signal("tick_failed", compute_result.reason)
		return _tick_failure(compute_result.reason, current_state, current_version, current_tick)

	var snapshot = compute_result.state
	# برخی رویدادها به تصمیم چندگزینه‌ای تبدیل می‌شوند؛ انقضا نیز پیامد پیش‌فرض دارد.
	snapshot = DecisionManagerClass.update_pending(snapshot, compute_result.get("events", []), snapshot_tick)

	# Commit - اعمال اتمی نتیجه
	snapshot["version"] = current_version + 1
	snapshot["tick"] = snapshot_tick
	snapshot["seed"] = Deterministic.get_state()
	_record_command_receipts(snapshot, commands)
	snapshot = AuditManager.record_turn(current_state, snapshot, commands)

	# لاگ رویداد موفق و انتشار یک‌جای تمام رویدادهای تراکنش
	EventLog.log_event("tick_success", {
		"tick": snapshot_tick,
		"version": snapshot["version"],
		"commands_count": commands.size(),
		"chain_hash": snapshot.get("audit", {}).get("chain_head", ""),
		"gdp_change": snapshot["economy"]["gdp"] - current_state["economy"]["gdp"] if current_state.has("economy") else 0
	}, snapshot_tick, snapshot["version"])
	EventLog.commit_transaction()

	emit_signal("tick_completed", snapshot, EventLog.get_last(5))

	# رویدادهای این تیک (شامل جشن‌ها) به UI برمی‌گردند؛ جشن‌ها در state ذخیره
	# نمی‌شوند تا دترمینیسم state حفظ شود.
	var tick_events: Array = []
	for ev in compute_result.get("events", []):
		if ev is Dictionary and str(ev.get("type", "")) == "celebration":
			tick_events.append(ev)

	return {
		"success": true,
		"state": snapshot,
		"version": snapshot["version"],
		"tick": snapshot_tick,
		"events": tick_events
	}

func _tick_failure(reason: String, state: Dictionary, version: int, turn: int) -> Dictionary:
	return {"success": false, "reason": reason, "state": state, "version": version, "tick": turn}

func _prepare_command_metadata(commands: Array, expected_tick: int, expected_version: int):
	for cmd in commands:
		if cmd is GameCommandClass:
			if cmd.tick == 0:
				cmd.tick = expected_tick
			if cmd.version == 0:
				cmd.version = expected_version

func _validate_commands(commands: Array, state: Dictionary, expected_tick: int, expected_version: int) -> Dictionary:
	var seen: Dictionary = {}
	var receipts: Array = state.get("command_receipts", [])
	for cmd in commands:
		if not cmd is GameCommandClass:
			return {"valid": false, "reason": "ساختار فرمان معتبر نیست"}
		if not SUPPORTED_COMMANDS.has(cmd.type):
			return {"valid": false, "reason": "نوع فرمان پشتیبانی نمی‌شود: %s" % cmd.type}
		if not cmd.payload is Dictionary:
			return {"valid": false, "reason": "داده فرمان باید ساختار کلید-مقدار باشد"}
		if cmd.tick != expected_tick or cmd.version != expected_version:
			return {"valid": false, "reason": "فرمان متعلق به تیک یا نسخه دیگری است"}

		var receipt_key = VersioningClass.make_idempotent_key(cmd.type, cmd.tick, cmd.player_id, cmd.payload)
		if seen.has(receipt_key) or receipts.has(receipt_key):
			return {"valid": false, "reason": "فرمان تکراری دریافت شد"}
		seen[receipt_key] = true

		if cmd.type == "tax_set":
			var rate = cmd.payload.get("rate", null)
			if not _is_finite_number(rate) or float(rate) < 0.0 or float(rate) > 0.9:
				return {"valid": false, "reason": "نرخ مالیات باید عددی بین صفر تا نود درصد باشد"}
		elif cmd.type == "monetary_policy":
			var mode = str(cmd.payload.get("mode", "")); var value = cmd.payload.get("value", 0.0)
			if not ["independent", "manual_rate", "inflation_target"].has(mode):
				return {"valid": false, "reason": "حالت سیاست پولی نامعتبر است"}
			if not _is_finite_number(value) or (mode == "manual_rate" and (float(value) < 0.0 or float(value) > 0.50)) or (mode == "inflation_target" and (float(value) < 0.0 or float(value) > 0.30)):
				return {"valid": false, "reason": "مقدار سیاست پولی خارج از محدوده است"}
		elif cmd.type == "tariff_set":
			var tariff = cmd.payload.get("rate", null)
			if not _is_finite_number(tariff) or float(tariff) < 0.0 or float(tariff) > 0.60:
				return {"valid": false, "reason": "تعرفه باید بین صفر تا شصت درصد باشد"}
		elif cmd.type == "budget_allocate":
			var allocs = cmd.payload.get("allocations", null)
			if not allocs is Dictionary or allocs.is_empty():
				return {"valid": false, "reason": "تخصیص بودجه خالی یا نامعتبر است"}
			var allowed_keys: Array = state.get("economy", {}).get("budget_allocations", {}).keys()
			if allocs.size() != allowed_keys.size():
				return {"valid": false, "reason": "همه ردیف‌های بودجه باید ارسال شوند"}
			var total = 0.0
			for key in allocs.keys():
				if not allowed_keys.has(key):
					return {"valid": false, "reason": "ردیف بودجه ناشناخته است: %s" % str(key)}
				var value = allocs[key]
				if not _is_finite_number(value) or float(value) < 0.0 or float(value) > 1.0:
					return {"valid": false, "reason": "سهم بودجه «%s» نامعتبر است" % str(key)}
				total += float(value)
			if abs(total - 1.0) > 0.001:
				return {"valid": false, "reason": "مجموع بودجه باید دقیقاً ۱۰۰٪ باشد، اکنون %.1f٪ است" % (total * 100.0)}
		elif cmd.type == "faction_action":
			var faction_name = str(cmd.payload.get("faction", ""))
			if not FactionManager.FACTIONS.has(faction_name):
				return {"valid": false, "reason": "جناح نامعتبر است"}
			if not str(cmd.payload.get("action", "")) in ["appease", "confront", "ally"]:
				return {"valid": false, "reason": "اقدام جناحی نامعتبر است"}
			var faction_check = FactionManager.can_action(state, faction_name, str(cmd.payload.get("action", "")))
			if not faction_check.valid:
				return {"valid": false, "reason": faction_check.reason}
		elif cmd.type == "faction_deal":
			var fd_faction = str(cmd.payload.get("faction", ""))
			var fd_check = FactionManager.can_deal(state, fd_faction, str(cmd.payload.get("deal_id", "")))
			if not fd_check.valid:
				return {"valid": false, "reason": fd_check.reason}
		elif cmd.type == "set_war_goal":
			var wg_target = str(cmd.payload.get("target", ""))
			var wg_goal = str(cmd.payload.get("goal", ""))
			if not WorldManager.countries.has(wg_target) or not state.get("world", {}).get("wars", {}).has(wg_target):
				return {"valid": false, "reason": "جنگ فعالی با این کشور وجود ندارد"}
			if not wg_goal in ["reparations", "annexation", "humiliation", "liberation"]:
				return {"valid": false, "reason": "هدف جنگی نامعتبر است"}
		elif cmd.type == "general_assign":
			var ga_id = str(cmd.payload.get("commander_id", ""))
			if not state.get("generals", {}).get("commanders", {}).has(ga_id):
				return {"valid": false, "reason": "فرمانده نامعتبر است"}
		elif cmd.type == "media_policy":
			if not str(cmd.payload.get("policy", "")) in ["free", "state", "populist"]:
				return {"valid": false, "reason": "سیاست رسانه‌ای نامعتبر است"}
		elif cmd.type == "media_campaign":
			if not MediaManager.GROUPS.has(str(cmd.payload.get("target_group", ""))):
				return {"valid": false, "reason": "گروه جمعیتی نامعتبر است"}
			if not str(cmd.payload.get("style", "")) in ["honest", "emotional", "smear"]:
				return {"valid": false, "reason": "سبک کمپین نامعتبر است"}
			var camp_check = MediaManager.can_campaign(state)
			if not camp_check.valid:
				return {"valid": false, "reason": camp_check.reason}
		elif cmd.type == "commodity_trade":
			if not CommodityManager.COMMODITIES.has(str(cmd.payload.get("commodity", ""))):
				return {"valid": false, "reason": "کالا نامعتبر است"}
			if not _is_finite_number(cmd.payload.get("amount", 0.0)) or float(cmd.payload.get("amount", 0.0)) <= 0.0:
				return {"valid": false, "reason": "مقدار نامعتبر است"}
		elif cmd.type == "org_toggle":
			if not OrgManager.ORGS.has(str(cmd.payload.get("org", ""))):
				return {"valid": false, "reason": "سازمان نامعتبر است"}
		elif cmd.type == "org_vote":
			if not str(cmd.payload.get("decision", "")) in ["yes", "no"]:
				return {"valid": false, "reason": "رأی نامعتبر است"}
		elif cmd.type == "campaign_promise":
			if not ParliamentManager.PROMISES.has(str(cmd.payload.get("promise_id", ""))):
				return {"valid": false, "reason": "وعده نامعتبر است"}
			var promise_check = ParliamentManager.can_promise(state, str(cmd.payload.get("promise_id", "")))
			if not promise_check.valid:
				return {"valid": false, "reason": promise_check.reason}
		elif cmd.type == "forex_intervene":
			if not _is_finite_number(cmd.payload.get("amount_billion", 0.0)) or float(cmd.payload.get("amount_billion", 0.0)) <= 0.0:
				return {"valid": false, "reason": "مبلغ نامعتبر است"}
		elif cmd.type == "forex_devalue":
			if not _is_finite_number(cmd.payload.get("percent", 0.0)) or float(cmd.payload.get("percent", 0.0)) <= 0.0 or float(cmd.payload.get("percent", 0.0)) > 20.0:
				return {"valid": false, "reason": "درصد نامعتبر است (۱ تا ۲۰)"}
		elif cmd.type == "governor_appoint":
			if not state.get("governors", {}).get("provinces", {}).has(str(cmd.payload.get("province_code", ""))):
				return {"valid": false, "reason": "استان نامعتبر است"}
			if not FactionManager.FACTIONS.has(str(cmd.payload.get("faction", ""))):
				return {"valid": false, "reason": "جناح نامعتبر است"}
		elif cmd.type == "crisis_stance":
			if not str(cmd.payload.get("stance", "")) in ["west", "east", "neutral"]:
				return {"valid": false, "reason": "موضع نامعتبر است"}
		elif cmd.type == "rivalry_action":
			if not str(cmd.payload.get("action", "")) in ["de_escalate", "escalate"]:
				return {"valid": false, "reason": "اقدام نامعتبر است"}
		elif cmd.type == "shadow_action":
			if not str(cmd.payload.get("action", "")) in ["crackdown", "amnesty", "cover", "investigate", "ignore"]:
				return {"valid": false, "reason": "اقدام نامعتبر است"}
		elif cmd.type == "court_action":
			if not str(cmd.payload.get("action", "")) in ["fund", "press", "reform", "free", "mediate"]:
				return {"valid": false, "reason": "اقدام قضایی نامعتبر است"}
			if str(cmd.payload.get("action", "")) in ["free", "mediate"] and state.get("judiciary", {}).get("pending_ruling", {}).is_empty():
				return {"valid": false, "reason": "پرونده‌ای در انتظار حکم نیست"}
		elif cmd.type == "energy_action":
			if not str(cmd.payload.get("action", "")) in ["renewable", "nuclear", "subsidy", "climate"]:
				return {"valid": false, "reason": "اقدام انرژی نامعتبر است"}
		elif cmd.type == "industry_action":
			if not str(cmd.payload.get("action", "")) in ["strategy", "winner", "privatize", "nationalize", "free_zone"]:
				return {"valid": false, "reason": "اقدام صنعتی نامعتبر است"}
			if str(cmd.payload.get("action", "")) == "strategy" and not IndustryManager.STRATEGIES.has(str(cmd.payload.get("value", ""))):
				return {"valid": false, "reason": "راهبرد نامعتبر است"}
		elif cmd.type == "succession_action":
			if not str(cmd.payload.get("action", "")) in ["train"]:
				return {"valid": false, "reason": "اقدام جانشینی نامعتبر است"}
		elif cmd.type == "labor_action":
			if not str(cmd.payload.get("action", "")) in ["free", "minimum_up", "wage_control", "negotiate", "suppress"]:
				return {"valid": false, "reason": "اقدام کارگری نامعتبر است"}
		elif cmd.type == "epidemic_action":
			if not str(cmd.payload.get("action", "")) in ["lockdown0", "lockdown1", "lockdown2", "vaccine", "hospitals"]:
				return {"valid": false, "reason": "اقدام بهداشتی نامعتبر است"}
		elif cmd.type == "arms_action":
			if not str(cmd.payload.get("action", "")) in ["invest", "sell", "transfer"]:
				return {"valid": false, "reason": "اقدام تسلیحاتی نامعتبر است"}
			if str(cmd.payload.get("action", "")) == "sell" and not WorldManager.countries.has(str(cmd.payload.get("target", ""))):
				return {"valid": false, "reason": "خریدار نامعتبر است"}
		elif cmd.type == "cyber_action":
			if not str(cmd.payload.get("action", "")) in ["firewall", "attack"]:
				return {"valid": false, "reason": "اقدام سایبری نامعتبر است"}
			if str(cmd.payload.get("action", "")) == "attack" and not WorldManager.countries.has(str(cmd.payload.get("target", ""))):
				return {"valid": false, "reason": "هدف نامعتبر است"}
			if str(cmd.payload.get("action", "")) == "attack" and not str(cmd.payload.get("kind", "")) in ["economy", "infrastructure", "information"]:
				return {"valid": false, "reason": "نوع حمله نامعتبر است"}
		elif cmd.type == "migration_action":
			if not str(cmd.payload.get("action", "")) in ["open", "restricted", "skilled", "integrate", "brain"]:
				return {"valid": false, "reason": "اقدام مهاجرتی نامعتبر است"}
		elif cmd.type == "culture_action":
			if not str(cmd.payload.get("action", "")) in ["heritage", "exchange", "festival", "sports", "film"]:
				return {"valid": false, "reason": "اقدام فرهنگی نامعتبر است"}
		elif cmd.type == "education_action":
			if not str(cmd.payload.get("action", "")) in ["vocational", "university", "scholarship", "digital"]:
				return {"valid": false, "reason": "اقدام آموزشی نامعتبر است"}
		elif cmd.type == "agriculture_action":
			if not str(cmd.payload.get("action", "")) in ["grain", "fertilizer", "diversity", "irrigation"]:
				return {"valid": false, "reason": "اقدام کشاورزی نامعتبر است"}
		elif cmd.type == "tourism_action":
			if not str(cmd.payload.get("action", "")) in ["visa", "hospitality", "campaign", "health"]:
				return {"valid": false, "reason": "اقدام گردشگری نامعتبر است"}
			if str(cmd.payload.get("action", "")) == "visa" and not str(cmd.payload.get("value", "")) in ["open", "moderate", "strict"]:
				return {"valid": false, "reason": "سیاست ویزا نامعتبر است"}
		elif cmd.type == "urban_action":
			if not str(cmd.payload.get("action", "")) in ["housing", "transit", "smart", "density"]:
				return {"valid": false, "reason": "اقدام شهری نامعتبر است"}
		elif cmd.type == "security_action":
			if not str(cmd.payload.get("action", "")) in ["civil", "surveillance", "tough", "smuggling", "community", "modern"]:
				return {"valid": false, "reason": "اقدام امنیتی نامعتبر است"}
		elif cmd.type == "infra_action":
			if not str(cmd.payload.get("action", "")) in ["maintenance", "focus_roads", "focus_power", "focus_water", "focus_telecom"]:
				return {"valid": false, "reason": "اقدام زیرساختی نامعتبر است"}
			if str(cmd.payload.get("action", "")) == "maintenance" and (not _is_finite_number(cmd.payload.get("value", 0.0)) or float(cmd.payload.get("value", 0.0)) < 0.0 or float(cmd.payload.get("value", 0.0)) > 1.0):
				return {"valid": false, "reason": "سهم نگهداری نامعتبر است"}
		elif cmd.type == "climate_action":
			if not str(cmd.payload.get("action", "")) in ["carbon", "reforest", "disaster", "greencity"]:
				return {"valid": false, "reason": "اقدام اقلیمی نامعتبر است"}
			if str(cmd.payload.get("action", "")) == "carbon" and (not _is_finite_number(cmd.payload.get("value", 0.0)) or float(cmd.payload.get("value", 0.0)) < 0.0 or float(cmd.payload.get("value", 0.0)) > 1.0):
				return {"valid": false, "reason": "مالیات کربن نامعتبر است"}
		elif cmd.type == "welfare_action":
			if not str(cmd.payload.get("action", "")) in ["pension", "benefit", "child", "health"]:
				return {"valid": false, "reason": "اقدام رفاهی نامعتبر است"}
		elif cmd.type == "space_action":
			if not str(cmd.payload.get("action", "")) in ["agency", "comm", "obs", "launcher"]:
				return {"valid": false, "reason": "اقدام فضایی نامعتبر است"}
		elif cmd.type == "trade_policy_action":
			if not str(cmd.payload.get("action", "")) in ["diversify", "imports", "mission", "supply"]:
				return {"valid": false, "reason": "اقدام تجاری نامعتبر است"}
		elif cmd.type == "banking_action":
			if not str(cmd.payload.get("action", "")) in ["reserve", "supervision", "bailout", "market"]:
				return {"valid": false, "reason": "اقدام بانکی نامعتبر است"}
		elif cmd.type == "fdi_action":
			if not str(cmd.payload.get("action", "")) in ["zone", "ip", "restrictions", "diplomacy"]:
				return {"valid": false, "reason": "اقدام سرمایه‌گذاری نامعتبر است"}
		elif cmd.type == "ambassador_action":
			if not str(cmd.payload.get("action", "")) in ["send", "recall", "negotiate"]:
				return {"valid": false, "reason": "اقدام دیپلماتیک نامعتبر است"}
			if not AmbassadorManager.KEY_COUNTRIES.has(str(cmd.payload.get("country", ""))):
				return {"valid": false, "reason": "کشور در فهرست سفارت‌ها نیست"}
		elif cmd.type == "digital_action":
			if not str(cmd.payload.get("action", "")) in ["internet", "egovernment", "cbdc", "privacy"]:
				return {"valid": false, "reason": "اقدام دیجیتال نامعتبر است"}
		elif cmd.type == "sports_action":
			if not str(cmd.payload.get("action", "")) in ["grassroots", "league", "doping", "host"]:
				return {"valid": false, "reason": "اقدام ورزشی نامعتبر است"}
		elif cmd.type == "stock_action":
			if not str(cmd.payload.get("action", "")) in ["ipo", "support", "capgains", "watchdog"]:
				return {"valid": false, "reason": "اقدام بورسی نامعتبر است"}
		elif cmd.type == "veterans_action":
			if not str(cmd.payload.get("action", "")) in ["pension", "employment", "clinic", "parade"]:
				return {"valid": false, "reason": "اقدام ایثارگری نامعتبر است"}
		elif cmd.type == "heritage_action":
			if not str(cmd.payload.get("action", "")) in ["restore", "register", "festival", "antiquities"]:
				return {"valid": false, "reason": "اقدام میراثی نامعتبر است"}
		elif cmd.type == "transport_action":
			if not str(cmd.payload.get("action", "")) in ["metro", "brt", "subsidy", "fleet"]:
				return {"valid": false, "reason": "اقدام حمل‌ونقلی نامعتبر است"}
		elif cmd.type == "retail_action":
			if not str(cmd.payload.get("action", "")) in ["price", "protect", "ecommerce", "bazaar"]:
				return {"valid": false, "reason": "اقدام بازار نامعتبر است"}
		elif cmd.type == "ethnicity_action":
			if not str(cmd.payload.get("action", "")) in ["equal", "autonomy", "dialogue", "festival"]:
				return {"valid": false, "reason": "اقدام قومی نامعتبر است"}
		elif cmd.type == "water_action":
			if not str(cmd.payload.get("action", "")) in ["dam", "desal", "leakage", "irrigation"]:
				return {"valid": false, "reason": "اقدام آبی نامعتبر است"}
		elif cmd.type == "research_action":
			if not str(cmd.payload.get("action", "")) in ["university", "center", "transfer", "talent"]:
				return {"valid": false, "reason": "اقدام پژوهشی نامعتبر است"}
		elif cmd.type == "civic_action":
			if not str(cmd.payload.get("action", "")) in ["opendata", "councils", "budget", "ngos"]:
				return {"valid": false, "reason": "اقدام مدنی نامعتبر است"}
		elif cmd.type == "diaspora_action":
			if not str(cmd.payload.get("action", "")) in ["summit", "networks", "diplomacy", "return"]:
				return {"valid": false, "reason": "اقدام دیاسپورا نامعتبر است"}
		elif cmd.type == "civil_defense_action":
			if not str(cmd.payload.get("action", "")) in ["hardening", "redundancy", "shelters", "stockpile"]:
				return {"valid": false, "reason": "اقدام پدافند غیرعامل نامعتبر است"}
		elif cmd.type == "blue_economy_action":
			if not str(cmd.payload.get("action", "")) in ["port", "fleet", "fishery", "patrol"]:
				return {"valid": false, "reason": "اقدام اقتصاد دریایی نامعتبر است"}
		elif cmd.type == "creative_action":
			if not str(cmd.payload.get("action", "")) in ["funding", "education", "platform", "export"]:
				return {"valid": false, "reason": "اقدام اقتصاد خلاق نامعتبر است"}
		elif cmd.type == "demographic_action":
			if not str(cmd.payload.get("action", "")) in ["pronatal", "childcare", "elderly", "retraining"]:
				return {"valid": false, "reason": "اقدام جمعیتی نامعتبر است"}
		elif cmd.type == "watershed_action":
			if not str(cmd.payload.get("action", "")) in ["restore", "forest", "dust", "wetlands"]:
				return {"valid": false, "reason": "اقدام آبخیزداری نامعتبر است"}
		elif cmd.type == "prison_action":
			if not str(cmd.payload.get("action", "")) in ["approach", "capacity", "education", "amnesty"]:
				return {"valid": false, "reason": "اقدام زندان نامعتبر است"}
			if str(cmd.payload.get("action", "")) == "approach" and not str(cmd.payload.get("approach", "")) in ["punitive", "balanced", "rehab"]:
				return {"valid": false, "reason": "رویکرد کیفری نامعتبر است"}
		elif cmd.type == "statistics_action":
			if not str(cmd.payload.get("action", "")) in ["census", "infra", "independence", "opendata"]:
				return {"valid": false, "reason": "اقدام آماری نامعتبر است"}
		elif cmd.type == "mining_action":
			if not str(cmd.payload.get("action", "")) in ["mine", "refinery", "safety", "formalize"]:
				return {"valid": false, "reason": "اقدام معدنی نامعتبر است"}
		elif cmd.type == "waste_action":
			if not str(cmd.payload.get("action", "")) in ["collection", "recycling", "landfill", "circular"]:
				return {"valid": false, "reason": "اقدام پسماند نامعتبر است"}
		elif cmd.type == "insurance_action":
			if not str(cmd.payload.get("action", "")) in ["universal", "health", "agri", "regulation"]:
				return {"valid": false, "reason": "اقدام بیمه‌ای نامعتبر است"}
		elif cmd.type == "rural_action":
			if not str(cmd.payload.get("action", "")) in ["roads", "internet", "processing", "nomads"]:
				return {"valid": false, "reason": "اقدام روستایی نامعتبر است"}
		elif cmd.type == "judicial_reform_action":
			if not str(cmd.payload.get("action", "")) in ["digital", "specialized", "mediation", "legalaid"]:
				return {"valid": false, "reason": "اقدام اصلاح قضایی نامعتبر است"}
		elif cmd.type == "election_action":
			if not str(cmd.payload.get("action", "")) in ["hold", "monitoring", "access", "pluralism"]:
				return {"valid": false, "reason": "اقدام انتخاباتی نامعتبر است"}
		elif cmd.type == "fuel_action":
			if not str(cmd.payload.get("action", "")) in ["reform", "charging", "emission", "fleet"]:
				return {"valid": false, "reason": "اقدام سوخت نامعتبر است"}
		elif cmd.type == "housing_action":
			if not str(cmd.payload.get("action", "")) in ["social", "mortgage", "renewal", "regulate"]:
				return {"valid": false, "reason": "اقدام مسکن نامعتبر است"}
		elif cmd.type == "startup_action":
			if not str(cmd.payload.get("action", "")) in ["fund", "accelerator", "sandbox", "braindrain"]:
				return {"valid": false, "reason": "اقدام استارتاپ نامعتبر است"}
		elif cmd.type == "sme_action":
			if not str(cmd.payload.get("action", "")) in ["redtape", "microcredit", "supplychain", "formalize"]:
				return {"valid": false, "reason": "اقدام SME نامعتبر است"}
		elif cmd.type == "supply_action":
			if not str(cmd.payload.get("action", "")) in ["reserve", "diversify", "domestic", "rotation"]:
				return {"valid": false, "reason": "اقدام زنجیره تأمین نامعتبر است"}
		elif cmd.type == "care_action":
			if not str(cmd.payload.get("action", "")) in ["eldercare", "childcare", "homecare", "leave"]:
				return {"valid": false, "reason": "اقدام مراقبت نامعتبر است"}
		elif cmd.type == "science_action":
			if not str(cmd.payload.get("action", "")) in ["agreement", "lab", "scholarship", "consortium"]:
				return {"valid": false, "reason": "اقدام علمی نامعتبر است"}
		elif cmd.type == "downstream_action":
			if not str(cmd.payload.get("action", "")) in ["refining", "petrochem", "selfsuff", "valuechain"]:
				return {"valid": false, "reason": "اقدام پتروشیمی نامعتبر است"}
		elif cmd.type == "higher_ed_action":
			if not str(cmd.payload.get("action", "")) in ["funding", "research", "faculty", "international"]:
				return {"valid": false, "reason": "اقدام آموزش عالی نامعتبر است"}
		elif cmd.type == "food_chain_action":
			if not str(cmd.payload.get("action", "")) in ["storage", "processing", "logistics", "safety"]:
				return {"valid": false, "reason": "اقدام زنجیره غذا نامعتبر است"}
		elif cmd.type == "pharma_action":
			if not str(cmd.payload.get("action", "")) in ["plant", "generic", "stockpile", "vaccine"]:
				return {"valid": false, "reason": "اقدام دارو نامعتبر است"}
		elif cmd.type == "ip_action":
			if not str(cmd.payload.get("action", "")) in ["patent", "copyright", "transfer", "park"]:
				return {"valid": false, "reason": "اقدام مالکیت فکری نامعتبر است"}
		elif cmd.type == "transit_action":
			if not str(cmd.payload.get("action", "")) in ["corridor", "customs", "rail", "freezone"]:
				return {"valid": false, "reason": "اقدام ترانزیت نامعتبر است"}
		elif cmd.type == "disaster_action":
			if not str(cmd.payload.get("action", "")) in ["warning", "shelter", "response", "relief"]:
				return {"valid": false, "reason": "اقدام بحران نامعتبر است"}
		elif cmd.type == "livestock_action":
			if not str(cmd.payload.get("action", "")) in ["industrial", "vaccine", "feed", "breeding"]:
				return {"valid": false, "reason": "اقدام دام نامعتبر است"}
		elif cmd.type == "textile_action":
			if not str(cmd.payload.get("action", "")) in ["mills", "cotton", "apparel", "branding"]:
				return {"valid": false, "reason": "اقدام نساجی نامعتبر است"}
		elif cmd.type == "basic_industry_action":
			if not str(cmd.payload.get("action", "")) in ["steel", "cement", "integration", "efficiency"]:
				return {"valid": false, "reason": "اقدام صنایع بنیادی نامعتبر است"}
		elif cmd.type == "nation_brand_action":
			if not str(cmd.payload.get("action", "")) in ["branding", "event", "heritage", "exports"]:
				return {"valid": false, "reason": "اقدام برند ملی نامعتبر است"}
		elif cmd.type == "ai_action":
			if not str(cmd.payload.get("action", "")) in ["adopt", "robotics", "reskill", "datainfra"]:
				return {"valid": false, "reason": "اقدام هوش مصنوعی نامعتبر است"}
		elif cmd.type == "tax_action":
			if not str(cmd.payload.get("action", "")) in ["income", "corporate", "vat", "wealth", "compliance", "digital", "bracket"]:
				return {"valid": false, "reason": "اقدام مالیاتی نامعتبر است"}
		elif cmd.type == "ev_action":
			if not str(cmd.payload.get("action", "")) in ["battery", "research", "production", "charging", "recycling"]:
				return {"valid": false, "reason": "اقدام خودرو/باطری نامعتبر است"}
		elif cmd.type == "health_tourism_action":
			if not str(cmd.payload.get("action", "")) in ["hospital", "quality", "wellness", "visa", "accreditation", "marketing"]:
				return {"valid": false, "reason": "اقدام گردشگری سلامت نامعتبر است"}
		elif cmd.type == "defense_industry_action":
			if not str(cmd.payload.get("action", "")) in ["production", "rnd", "maintenance", "training", "exports"]:
				return {"valid": false, "reason": "اقدام صنعت دفاعی نامعتبر است"}
		elif cmd.type == "knowledge_economy_action":
			if not str(cmd.payload.get("action", "")) in ["park", "incubator", "startup", "commercialize", "vc"]:
				return {"valid": false, "reason": "اقدام اقتصاد دانش نامعتبر است"}
		elif cmd.type == "waste_mgmt_action":
			if not str(cmd.payload.get("action", "")) in ["collection", "separation", "recycling", "wte", "landfill"]:
				return {"valid": false, "reason": "اقدام پسماند نامعتبر است"}
		elif cmd.type == "aerospace_action":
			if not str(cmd.payload.get("action", "")) in ["launch", "factory", "sensing", "telecom", "rnd"]:
				return {"valid": false, "reason": "اقدام هوافضا نامعتبر است"}
		elif cmd.type == "petrochemical_action":
			if not str(cmd.payload.get("action", "")) in ["feedstock", "plants", "downstream", "catalyst", "exports"]:
				return {"valid": false, "reason": "اقدام پتروشیمی نامعتبر است"}
		elif cmd.type == "pro_sports_action":
			if not str(cmd.payload.get("action", "")) in ["leagues", "infrastructure", "events", "academy", "exports"]:
				return {"valid": false, "reason": "اقدام اقتصاد ورزش نامعتبر است"}
		elif cmd.type == "mega_event":
			var me_action := str(cmd.payload.get("action", ""))
			if me_action != "bid":
				return {"valid": false, "reason": "اقدام رویداد جهانی نامعتبر است"}
			if not MegaEventManager.get_event_ids().has(str(cmd.payload.get("event_id", ""))):
				return {"valid": false, "reason": "رویداد جهانی نامعتبر است"}
		elif cmd.type == "aviation_action":
			if not str(cmd.payload.get("action", "")) in ["airports", "fleet", "safety", "hub", "cargo"]:
				return {"valid": false, "reason": "اقدام هوانوردی نامعتبر است"}
		elif cmd.type == "postal_action":
			if not str(cmd.payload.get("action", "")) in ["network", "sorting", "lastmile", "ecommerce", "tracking"]:
				return {"valid": false, "reason": "اقدام پست و لجستیک نامعتبر است"}
		elif cmd.type == "standards_action":
			if not str(cmd.payload.get("action", "")) in ["metrology", "labs", "accreditation", "surveillance", "export_gate"]:
				return {"valid": false, "reason": "اقدام استاندارد و کیفیت نامعتبر است"}
		elif cmd.type == "dilemma_resolve":
			if not str(cmd.payload.get("choice", "")) in ["a", "b"]:
				return {"valid": false, "reason": "انتخاب معضل نامعتبر است"}
			if state.get("dilemmas", {}).get("active", {}).is_empty():
				return {"valid": false, "reason": "معضل فعالی نیست"}
		elif cmd.type == "assassinate":
			var target_a = str(cmd.payload.get("target", ""))
			if not WorldManager.countries.has(target_a):
				return {"valid": false, "reason": "کشور هدف ترور نامعتبر است"}
		elif cmd.type == "leader_hidden":
			if not (cmd.payload.get("hidden", false) is bool):
				return {"valid": false, "reason": "مقدار وضعیت رهبر نامعتبر است"}
		elif cmd.type == "leader_name":
			var name_check: String = str(cmd.payload.get("name", "")).strip_edges()
			if name_check.length() < 2 or name_check.length() > 30:
				return {"valid": false, "reason": "نام رهبر باید بین ۲ تا ۳۰ نویسه باشد"}
		elif cmd.type == "research_start":
			var tech_id = str(cmd.payload.get("tech_id", ""))
			var technology_check = TechnologyManager.can_start(state, tech_id)
			if not technology_check.valid:
				return {"valid": false, "reason": technology_check.reason}
		elif cmd.type == "diplomacy":
			var target = str(cmd.payload.get("target", ""))
			var action = str(cmd.payload.get("action", ""))
			var diplomacy_check = WorldManager.can_action(state, target, action)
			if not diplomacy_check.valid:
				return {"valid": false, "reason": diplomacy_check.reason}
		elif cmd.type == "country_select":
			var country_id = str(cmd.payload.get("country_id", ""))
			var scenario_id = str(cmd.payload.get("scenario_id", ScenarioManager.default_scenario))
			var country_check = WorldManager.can_select_country(state, country_id)
			if not country_check.valid:
				return {"valid": false, "reason": country_check.reason}
			var scenario_check = ScenarioManager.can_select(state, scenario_id)
			if not scenario_check.valid:
				return {"valid": false, "reason": scenario_check.reason}
		elif cmd.type == "policy_change":
			var policy_id = str(cmd.payload.get("policy_id", ""))
			var enabled = bool(cmd.payload.get("enabled", false))
			var policy_check = PolicyManager.can_change(state, policy_id, enabled)
			if not policy_check.valid:
				return {"valid": false, "reason": policy_check.reason}
		elif cmd.type == "municipal_action":
			var municipal_check = SeasonalManager.can_action(state, str(cmd.payload.get("action", "")))
			if not municipal_check.valid:
				return {"valid": false, "reason": municipal_check.reason}
		elif cmd.type == "military_program":
			var program_check = MilitaryManager.can_start(state, str(cmd.payload.get("program_id", "")))
			if not program_check.valid:
				return {"valid": false, "reason": program_check.reason}
		elif cmd.type == "military_doctrine":
			var doctrine = str(cmd.payload.get("doctrine", ""))
			if not MilitaryManager.DOCTRINES.has(doctrine):
				return {"valid": false, "reason": "دکترین نظامی معتبر نیست"}
			if str(state.get("military_development", {}).get("doctrine", "balanced")) == doctrine:
				return {"valid": false, "reason": "این دکترین از قبل فعال است"}
		elif cmd.type == "national_project":
			var project_id = str(cmd.payload.get("project_id", ""))
			var project_action = str(cmd.payload.get("action", "start"))
			if not ["start", "cancel"].has(project_action):
				return {"valid": false, "reason": "اقدام پروژه ملی نامعتبر است"}
			var project_check = NationalProjectManager.can_start(state, project_id) if project_action == "start" else NationalProjectManager.can_cancel(state, project_id)
			if not project_check.valid:
				return {"valid": false, "reason": project_check.reason}
		elif cmd.type == "cabinet_change":
			var ministry_id = str(cmd.payload.get("ministry_id", ""))
			var cabinet_action = str(cmd.payload.get("action", "appoint"))
			if cabinet_action == "appoint":
				var cabinet_check = CabinetManager.can_appoint(state, ministry_id, str(cmd.payload.get("candidate_id", "")))
				if not cabinet_check.valid:
					return {"valid": false, "reason": cabinet_check.reason}
			elif cabinet_action == "dismiss":
				if not state.get("cabinet", {}).get("active", {}).has(ministry_id):
					return {"valid": false, "reason": "وزیر فعالی برای برکناری وجود ندارد"}
			elif cabinet_action == "mission":
				var mission_check = CabinetManager.can_mission(state, ministry_id)
				if not mission_check.valid:
					return {"valid": false, "reason": mission_check.reason}
			elif cabinet_action == "mediate":
				if state.get("cabinet", {}).get("disputes", []).is_empty():
					return {"valid": false, "reason": "درگیری فعالی در کابینه نیست"}
			else:
				return {"valid": false, "reason": "اقدام کابینه نامعتبر است"}
		elif cmd.type == "law_change":
			var law_id = str(cmd.payload.get("law_id", ""))
			var law_action = str(cmd.payload.get("action", "enact"))
			if law_action == "enact":
				var law_check = LawManager.can_enact(state, law_id)
				if not law_check.valid: return {"valid":false,"reason":law_check.reason}
			elif law_action == "repeal":
				if not state.get("legislation", {}).get("enacted", {}).has(law_id): return {"valid":false,"reason":"این قانون برقرار نیست"}
			else:
				return {"valid":false,"reason":"اقدام قانون‌گذاری نامعتبر است"}
		elif cmd.type == "intelligence_operation":
			var intel_action = str(cmd.payload.get("action","start"))
			if intel_action == "start":
				var intel_check = IntelligenceOperationManager.can_start(state,str(cmd.payload.get("operation_id","")),str(cmd.payload.get("target","")))
				if not intel_check.valid:return {"valid":false,"reason":intel_check.reason}
			elif intel_action == "cancel":
				if not state.get("intelligence_operations",{}).get("active",{}).has(str(cmd.payload.get("operation_key",""))):return {"valid":false,"reason":"عملیات فعال یافت نشد"}
			else:return {"valid":false,"reason":"اقدام اطلاعاتی نامعتبر است"}
		elif cmd.type == "decision_resolve":
			var decision_id = cmd.payload.get("decision_id", "")
			var choice_id = cmd.payload.get("choice_id", "")
			if not decision_id is String or not choice_id is String:
				return {"valid": false, "reason": "شناسه تصمیم یا گزینه نامعتبر است"}
			if not DecisionManagerClass.validate_choice(state, decision_id, choice_id):
				return {"valid": false, "reason": "تصمیم یا گزینه انتخابی دیگر معتبر نیست"}
		elif cmd.type == "trade_route_attack":
			var route_id = str(cmd.payload.get("route_id", ""))
			var route_type = str(cmd.payload.get("route_type", ""))
			var operation = str(cmd.payload.get("operation", ""))
			if route_id.is_empty() and route_type.is_empty():
				return {"valid": false, "reason": "شناسه مسیر تجاری نامعتبر است"}
			if not ["raid","blockade","sabotage","cyber","drone_strike","protect","escort","mine"].has(operation):
				return {"valid": false, "reason": "نوع عملیات مسیر تجاری نامعتبر است"}
			if float(state.get("military",{}).get("readiness",0.6)) < 0.35:
				return {"valid": false, "reason": "آمادگی نظامی کم - حداقل ۳۵٪ لازم است"}
		elif cmd.type == "chokepoint_action":
			var chokepoint_id = str(cmd.payload.get("chokepoint_id", ""))
			var action = str(cmd.payload.get("action", ""))
			if chokepoint_id.is_empty():
				return {"valid": false, "reason": "شناسه گلوگاه نامعتبر است"}
			if not ["blockade","mine","secure","patrol","sabotage"].has(action):
				return {"valid": false, "reason": "اقدام گلوگاه نامعتبر است"}
		elif cmd.type == "map_operation":
			var op_type = str(cmd.payload.get("operation_type", ""))
			var target = str(cmd.payload.get("target_country", ""))
			if op_type.is_empty():
				return {"valid": false, "reason": "نوع عملیات نقشه‌محور نامشخص است"}
			if not ["airstrike","naval_blockade","sabotage_infrastructure","drone_swarm","cyber_attack","propaganda","humanitarian","fortify","airfield","depot","radar","factory","bunker","sabotage","drone_recon","special_ops","blockade"].has(op_type):
				return {"valid": false, "reason": "عملیات نقشه‌محور نامعتبر است"}
			if target.is_empty() and op_type not in ["fortify","airfield","depot","radar","factory","bunker"]:
				return {"valid": false, "reason": "کشور هدف عملیات نقشه مشخص نیست"}
		elif cmd.type == "battle_plan":
			var plan_type = str(cmd.payload.get("plan_type",""))
			if not ["offensive","defensive","encirclement","breakthrough","pincer","amphibious","airborne"].has(plan_type):
				return {"valid": false, "reason": "نوع طرح نبرد نامعتبر است"}
			if float(state.get("military",{}).get("readiness",0.6)) < 0.30:
				return {"valid": false, "reason": "آمادگی نظامی کم برای طرح نبرد"}
		elif cmd.type == "construction":
			var build_type = str(cmd.payload.get("build_type",""))
			if not ["road","rail","fort","depot","airfield","radar","port","bunker","factory","air_defense"].has(build_type):
				return {"valid": false, "reason": "نوع ساخت‌وساز نقشه نامعتبر است"}
		elif cmd.type == "map_building":
			var building_type = str(cmd.payload.get("building_type",""))
			if not ["fort","airfield","depot","radar","factory","bunker","air_defense","port","silo","barracks"].has(building_type):
				return {"valid": false, "reason": "نوع ساختمان نقشه نامعتبر است"}
	return {"valid": true, "reason": ""}

func _record_command_receipts(snapshot: Dictionary, commands: Array):
	var receipts: Array = snapshot.get("command_receipts", []).duplicate()
	for cmd in commands:
		if cmd is GameCommandClass:
			receipts.append(VersioningClass.make_idempotent_key(cmd.type, cmd.tick, cmd.player_id, cmd.payload))
	while receipts.size() > MAX_COMMAND_RECEIPTS:
		receipts.pop_front()
	snapshot["command_receipts"] = receipts

func _is_finite_number(value) -> bool:
	if not (value is int or value is float):
		return false
	if value is float:
		return not is_nan(value) and not is_inf(value)
	return true

func _apply_command_to_snapshot(snapshot: Dictionary, cmd) -> Dictionary:
	if not cmd is GameCommandClass:
		return snapshot
	# بازرسی اقدامات ۲ — وضعیت مالی پیش از اجرا برای تشخیص اقدامات بدون شارژ
	var _econ_before: Dictionary = snapshot.get("economy", {})
	var _extra_before: float = float(_econ_before.get("extra_spending_daily", 0.0))
	var _debt_before: float = float(_econ_before.get("national_debt", 0.0))
	if cmd.type == "next_tick":
		# نشانگر پایان نوبت — بدون اثر مستقیم؛ شبیه‌سازی روز در ادامه انجام می‌شود
		pass
	elif cmd.type == "budget_allocate":
		var allocs = cmd.payload.get("allocations", {})
		for k in allocs.keys():
			if snapshot["economy"]["budget_allocations"].has(k):
				snapshot["economy"]["budget_allocations"][k] = allocs[k]
	elif cmd.type == "tax_set":
		snapshot["economy"]["tax_rate"] = cmd.payload.get("rate", 0.2)
	elif cmd.type == "monetary_policy":
		var mode = str(cmd.payload.get("mode", "independent")); var value = float(cmd.payload.get("value", 0.0))
		snapshot["central_bank"]["policy_mode"] = mode
		if mode == "manual_rate":
			snapshot["central_bank"]["manual_rate"] = value
			snapshot["central_bank"]["independence"] = clamp(float(snapshot["central_bank"].get("independence", 0.7)) - 0.03, 0.1, 0.95)
			snapshot["politics"]["trust"] = clamp(float(snapshot["politics"].get("trust", 0.5)) - 0.005, 0.0, 1.0)
		elif mode == "inflation_target": snapshot["central_bank"]["inflation_target"] = value
	elif cmd.type == "tariff_set":
		snapshot["trade"]["tariff_rate"] = float(cmd.payload.get("rate", 0.15))
		snapshot["diplomacy"]["influence"] = clamp(float(snapshot["diplomacy"].get("influence", 40.0)) - abs(float(snapshot["trade"]["tariff_rate"]) - 0.15) * 2.0, 0.0, 100.0)
	elif cmd.type == "faction_action":
		var faction_result = FactionManager.apply_action(snapshot, str(cmd.payload.get("faction", "")), str(cmd.payload.get("action", "")))
		snapshot = faction_result.state
		for ev in faction_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("faction_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "faction_deal":
		var fd_result = FactionManager.make_deal(snapshot, str(cmd.payload.get("faction", "")), str(cmd.payload.get("deal_id", "")), cmd.tick)
		snapshot = fd_result.state
		for fd_ev in fd_result.get("events", []):
			if fd_ev is Dictionary:
				EventLog.log_event("faction_event", fd_ev, cmd.tick, cmd.version)
	elif cmd.type == "set_war_goal":
		var wg_target2 = str(cmd.payload.get("target", ""))
		if snapshot.get("world", {}).get("wars", {}).has(wg_target2):
			snapshot["world"]["wars"][wg_target2]["goal"] = str(cmd.payload.get("goal", "reparations"))
			EventLog.log_event("war_goal", {"message": "هدف جنگ با %s به «%s» تغییر کرد" % [WorldManager.get_country_name(wg_target2), WorldManager.get_war_goal_name(str(cmd.payload.get("goal", "reparations")))]}, cmd.tick, cmd.version)
	elif cmd.type == "general_recruit":
		var gr_result = GeneralsManager.recruit(snapshot, cmd.tick)
		snapshot = gr_result.state
		for ev in gr_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("military_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "general_assign":
		var ga_result = GeneralsManager.assign(snapshot, str(cmd.payload.get("commander_id", "")), str(cmd.payload.get("war_target", "")))
		snapshot = ga_result.state
		for ev in ga_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("military_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "media_policy":
		var mp_result = MediaManager.set_policy(snapshot, str(cmd.payload.get("policy", "free")), cmd.tick)
		snapshot = mp_result.state
		for ev in mp_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("media_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "media_campaign":
		var mc_result = MediaManager.start_campaign(snapshot, str(cmd.payload.get("target_group", "")), str(cmd.payload.get("style", "honest")))
		snapshot = mc_result.state
		for ev in mc_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("media_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "commodity_trade":
		var ct_result = CommodityManager.trade(snapshot, str(cmd.payload.get("commodity", "")), float(cmd.payload.get("amount", 0.0)))
		snapshot = ct_result.state
		for ev in ct_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("trade_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "org_toggle":
		var ot_result = OrgManager.toggle(snapshot, str(cmd.payload.get("org", "")), cmd.tick)
		snapshot = ot_result.state
		for ev in ot_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("diplomacy_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "org_vote":
		var ov_result = OrgManager.resolve_vote(snapshot, str(cmd.payload.get("decision", "yes")), cmd.tick)
		snapshot = ov_result.state
		for ev in ov_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("diplomacy_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "snap_election":
		var se_result = ParliamentManager.snap_election(snapshot, cmd.tick)
		snapshot = se_result.state
		for ev in se_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("election_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "campaign_promise":
		var cp_result = ParliamentManager.add_promise(snapshot, str(cmd.payload.get("promise_id", "")))
		snapshot = cp_result.state
		for ev in cp_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("election_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "forex_intervene":
		var fi_result = ForexManager.intervene(snapshot, float(cmd.payload.get("amount_billion", 0.0)))
		snapshot = fi_result.state
		for ev in fi_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("economic_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "forex_devalue":
		var fd_result = ForexManager.devalue(snapshot, float(cmd.payload.get("percent", 0.0)))
		snapshot = fd_result.state
		for ev in fd_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("economic_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "capital_control":
		var cc_result = ForexManager.toggle_capital_control(snapshot)
		snapshot = cc_result.state
		for ev in cc_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("economic_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "governor_appoint":
		var ga_result = GovernorsManager.appoint(snapshot, str(cmd.payload.get("province_code", "")), str(cmd.payload.get("faction", "")))
		snapshot = ga_result.state
		for ev in ga_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("governor_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "crisis_stance":
		var cs_result = RivalryManager.resolve_crisis(snapshot, str(cmd.payload.get("stance", "neutral")))
		snapshot = cs_result.state
		for ev in cs_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("diplomacy_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "rivalry_action":
		var ra_result: Dictionary = RivalryManager.de_escalate(snapshot) if str(cmd.payload.get("action", "")) == "de_escalate" else RivalryManager.escalate(snapshot)
		snapshot = ra_result.state
		for ev in ra_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("diplomacy_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "shadow_action":
		var action := str(cmd.payload.get("action", ""))
		var sh_result: Dictionary
		match action:
			"crackdown": sh_result = ShadowManager.crackdown(snapshot)
			"amnesty": sh_result = ShadowManager.amnesty(snapshot)
			"cover": sh_result = ShadowManager.handle_scandal(snapshot, "cover")
			"investigate": sh_result = ShadowManager.handle_scandal(snapshot, "investigate")
			_: sh_result = ShadowManager.handle_scandal(snapshot, "ignore")
		snapshot = sh_result.state
		for ev in sh_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("corruption_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "court_action":
		var court_act := str(cmd.payload.get("action", ""))
		var court_result: Dictionary
		match court_act:
			"fund": court_result = JudiciaryManager.fund_courts(snapshot)
			"press": court_result = JudiciaryManager.press_court(snapshot)
			"reform": court_result = JudiciaryManager.judicial_reform(snapshot)
			"free": court_result = JudiciaryManager.respond_ruling(snapshot, "free")
			_: court_result = JudiciaryManager.respond_ruling(snapshot, "mediate")
		snapshot = court_result.state
		for ev in court_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("judiciary_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "energy_action":
		var energy_act := str(cmd.payload.get("action", ""))
		var energy_result: Dictionary
		match energy_act:
			"renewable": energy_result = EnergyManager.invest_renewable(snapshot)
			"nuclear": energy_result = EnergyManager.invest_nuclear(snapshot)
			"subsidy": energy_result = EnergyManager.reform_subsidies(snapshot)
			_: energy_result = EnergyManager.climate_pledge(snapshot)
		snapshot = energy_result.state
		for ev in energy_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("energy_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "industry_action":
		var ind_act := str(cmd.payload.get("action", ""))
		var ind_result: Dictionary
		match ind_act:
			"strategy": ind_result = IndustryManager.set_strategy(snapshot, str(cmd.payload.get("value", "diversified")))
			"winner": ind_result = IndustryManager.pick_winner(snapshot, str(cmd.payload.get("value", "")))
			"privatize": ind_result = IndustryManager.privatize(snapshot)
			"nationalize": ind_result = IndustryManager.nationalize(snapshot)
			_: ind_result = IndustryManager.create_free_zone(snapshot)
		snapshot = ind_result.state
		for ev in ind_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("industry_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "succession_action":
		var suc_result = SuccessionManager.train_heir(snapshot)
		snapshot = suc_result.state
		for ev in suc_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("succession_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "labor_action":
		var lab_act := str(cmd.payload.get("action", ""))
		var lab_result: Dictionary
		match lab_act:
			"negotiate": lab_result = LaborManager.negotiate(snapshot)
			"suppress": lab_result = LaborManager.suppress(snapshot)
			_: lab_result = LaborManager.set_wage_policy(snapshot, lab_act)
		snapshot = lab_result.state
		for ev in lab_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("labor_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "epidemic_action":
		var ep_act := str(cmd.payload.get("action", ""))
		var ep_result: Dictionary
		match ep_act:
			"lockdown0": ep_result = EpidemicManager.set_lockdown(snapshot, 0)
			"lockdown1": ep_result = EpidemicManager.set_lockdown(snapshot, 1)
			"lockdown2": ep_result = EpidemicManager.set_lockdown(snapshot, 2)
			"vaccine": ep_result = EpidemicManager.vaccination_campaign(snapshot)
			_: ep_result = EpidemicManager.emergency_hospitals(snapshot)
		snapshot = ep_result.state
		for ev in ep_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("health_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "arms_action":
		var arms_act := str(cmd.payload.get("action", ""))
		var arms_result: Dictionary
		match arms_act:
			"invest": arms_result = ArmsManager.invest_capacity(snapshot)
			"sell": arms_result = ArmsManager.sell_weapons(snapshot, str(cmd.payload.get("target", "")), float(cmd.payload.get("amount", 0.0)))
			_: arms_result = ArmsManager.transfer_to_army(snapshot, float(cmd.payload.get("amount", 0.0)))
		snapshot = arms_result.state
		for ev in arms_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("military_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "cyber_action":
		var cy_act := str(cmd.payload.get("action", ""))
		var cy_result: Dictionary
		if cy_act == "firewall":
			cy_result = CyberManager.build_firewall(snapshot)
		else:
			cy_result = CyberManager.cyber_attack(snapshot, str(cmd.payload.get("target", "")), str(cmd.payload.get("kind", "economy")))
		snapshot = cy_result.state
		for ev in cy_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("cyber_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "migration_action":
		var mig_act := str(cmd.payload.get("action", ""))
		var mig_result: Dictionary
		match mig_act:
			"integrate": mig_result = MigrationManager.integration_program(snapshot)
			"brain": mig_result = MigrationManager.stem_brain_drain(snapshot)
			_: mig_result = MigrationManager.set_policy(snapshot, mig_act)
		snapshot = mig_result.state
		for ev in mig_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("population_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "culture_action":
		var cul_act := str(cmd.payload.get("action", ""))
		var cul_result: Dictionary
		match cul_act:
			"heritage": cul_result = CultureManager.invest_heritage(snapshot)
			"exchange": cul_result = CultureManager.cultural_exchange(snapshot)
			_: cul_result = CultureManager.host_event(snapshot, cul_act, cmd.tick)
		snapshot = cul_result.state
		for ev in cul_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("culture_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "education_action":
		var edu_act := str(cmd.payload.get("action", ""))
		var edu_result: Dictionary
		match edu_act:
			"vocational": edu_result = EducationManager.vocational_program(snapshot)
			"university": edu_result = EducationManager.university_reform(snapshot)
			"scholarship": edu_result = EducationManager.scholarship_program(snapshot)
			_: edu_result = EducationManager.digital_education(snapshot)
		snapshot = edu_result.state
		for ev in edu_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("education_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "agriculture_action":
		var ag_act := str(cmd.payload.get("action", ""))
		var ag_result: Dictionary
		match ag_act:
			"grain": ag_result = AgricultureManager.build_grain_reserve(snapshot)
			"fertilizer": ag_result = AgricultureManager.fertilizer_subsidy(snapshot)
			"diversity": ag_result = AgricultureManager.crop_diversification(snapshot)
			_: ag_result = AgricultureManager.smart_irrigation(snapshot)
		snapshot = ag_result.state
		for ev in ag_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("agriculture_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "tourism_action":
		var tour_act := str(cmd.payload.get("action", ""))
		var tour_result: Dictionary
		match tour_act:
			"visa": tour_result = TourismManager.visa_policy(snapshot, str(cmd.payload.get("value", "moderate")))
			"hospitality": tour_result = TourismManager.invest_hospitality(snapshot)
			"campaign": tour_result = TourismManager.destination_campaign(snapshot)
			_: tour_result = TourismManager.health_tourism(snapshot)
		snapshot = tour_result.state
		for ev in tour_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("tourism_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "urban_action":
		var urban_act := str(cmd.payload.get("action", ""))
		var urban_result: Dictionary
		match urban_act:
			"housing": urban_result = UrbanManager.social_housing(snapshot)
			"transit": urban_result = UrbanManager.public_transit(snapshot)
			"smart": urban_result = UrbanManager.smart_city(snapshot)
			_: urban_result = UrbanManager.density_control(snapshot)
		snapshot = urban_result.state
		for ev in urban_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("urban_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "security_action":
		var sec_act := str(cmd.payload.get("action", ""))
		var sec_result: Dictionary
		match sec_act:
			"civil": sec_result = SecurityManager.police_mode(snapshot, "civil")
			"surveillance": sec_result = SecurityManager.police_mode(snapshot, "surveillance")
			"tough": sec_result = SecurityManager.police_mode(snapshot, "tough")
			"smuggling": sec_result = SecurityManager.anti_smuggling(snapshot)
			"community": sec_result = SecurityManager.community_police(snapshot)
			_: sec_result = SecurityManager.police_modernization(snapshot)
		snapshot = sec_result.state
		for ev in sec_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("security_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "infra_action":
		var infra_act := str(cmd.payload.get("action", ""))
		var infra_result: Dictionary
		if infra_act == "maintenance":
			infra_result = InfrastructureManager.set_maintenance(snapshot, float(cmd.payload.get("value", 0.4)))
		else:
			infra_result = InfrastructureManager.set_focus(snapshot, infra_act.replace("focus_", ""))
		snapshot = infra_result.state
		for ev in infra_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("infrastructure_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "climate_action":
		var climate_act := str(cmd.payload.get("action", ""))
		var climate_result: Dictionary
		match climate_act:
			"carbon": climate_result = ClimateManager.set_carbon_tax(snapshot, float(cmd.payload.get("value", 0.1)))
			"reforest": climate_result = ClimateManager.reforest(snapshot)
			"disaster": climate_result = ClimateManager.disaster_preparedness(snapshot)
			_: climate_result = ClimateManager.green_city_plan(snapshot)
		snapshot = climate_result.state
		for ev in climate_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("climate_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "welfare_action":
		var welfare_act := str(cmd.payload.get("action", ""))
		var welfare_result: Dictionary
		match welfare_act:
			"pension": welfare_result = WelfareManager.set_pension_age(snapshot, int(cmd.payload.get("value", 65)), cmd.tick)
			"benefit": welfare_result = WelfareManager.set_benefit(snapshot, float(cmd.payload.get("value", 0.4)))
			"child": welfare_result = WelfareManager.child_allowance(snapshot)
			_: welfare_result = WelfareManager.expand_health_coverage(snapshot)
		snapshot = welfare_result.state
		for ev in welfare_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("welfare_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "space_action":
		var space_act := str(cmd.payload.get("action", ""))
		var space_result: Dictionary
		match space_act:
			"agency": space_result = SpaceManager.expand_agency(snapshot)
			"comm": space_result = SpaceManager.comm_satellite(snapshot)
			"obs": space_result = SpaceManager.observation_satellite(snapshot)
			_: space_result = SpaceManager.launch_vehicle(snapshot)
		snapshot = space_result.state
		for ev in space_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("space_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "trade_policy_action":
		var trade_act := str(cmd.payload.get("action", ""))
		var trade_result: Dictionary
		match trade_act:
			"diversify": trade_result = TradePolicyManager.export_diversification(snapshot)
			"imports": trade_result = TradePolicyManager.strategic_imports(snapshot)
			"mission": trade_result = TradePolicyManager.trade_mission(snapshot)
			_: trade_result = TradePolicyManager.supply_chain_security(snapshot)
		snapshot = trade_result.state
		for ev in trade_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("trade_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "banking_action":
		var bank_act := str(cmd.payload.get("action", ""))
		var bank_result: Dictionary
		match bank_act:
			"reserve": bank_result = BankingManager.set_reserve(snapshot, float(cmd.payload.get("value", 0.12)))
			"supervision": bank_result = BankingManager.strengthen_supervision(snapshot)
			"bailout": bank_result = BankingManager.bailout(snapshot)
			_: bank_result = BankingManager.support_market(snapshot)
		snapshot = bank_result.state
		for ev in bank_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("banking_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "fdi_action":
		var fdi_act := str(cmd.payload.get("action", ""))
		var fdi_result: Dictionary
		match fdi_act:
			"zone": fdi_result = FdiManager.special_zone(snapshot)
			"ip": fdi_result = FdiManager.ip_protection(snapshot)
			"restrictions": fdi_result = FdiManager.fdi_restrictions(snapshot, float(cmd.payload.get("value", 0.3)))
			_: fdi_result = FdiManager.fdi_diplomacy(snapshot)
		snapshot = fdi_result.state
		for ev in fdi_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("fdi_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "ambassador_action":
		var amb_act := str(cmd.payload.get("action", ""))
		var amb_country := str(cmd.payload.get("country", ""))
		var amb_result: Dictionary
		match amb_act:
			"send": amb_result = AmbassadorManager.send_ambassador(snapshot, amb_country)
			"recall": amb_result = AmbassadorManager.recall_ambassador(snapshot, amb_country)
			_: amb_result = AmbassadorManager.diplomatic_negotiation(snapshot, amb_country)
		snapshot = amb_result.state
		for ev in amb_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("diplomacy_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "digital_action":
		var dig_act := str(cmd.payload.get("action", ""))
		var dig_result: Dictionary
		match dig_act:
			"internet": dig_result = DigitalManager.expand_internet(snapshot)
			"egovernment": dig_result = DigitalManager.e_government(snapshot)
			"cbdc": dig_result = DigitalManager.cbdc_launch(snapshot)
			_: dig_result = DigitalManager.privacy_law(snapshot)
		snapshot = dig_result.state
		for ev in dig_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("digital_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "sports_action":
		var sport_act := str(cmd.payload.get("action", ""))
		var sport_result: Dictionary
		match sport_act:
			"grassroots": sport_result = SportsManager.grassroots_sports(snapshot)
			"league": sport_result = SportsManager.pro_league_invest(snapshot)
			"doping": sport_result = SportsManager.anti_doping(snapshot)
			_: sport_result = SportsManager.host_major_event(snapshot, cmd.tick)
		snapshot = sport_result.state
		for ev in sport_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("sports_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "dilemma_resolve":
		var dilemma_result = DilemmaManager.resolve(snapshot, str(cmd.payload.get("choice", "a")))
		snapshot = dilemma_result.state
		for ev in dilemma_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("dilemma_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "stock_action":
		var stock_act := str(cmd.payload.get("action", ""))
		var stock_result: Dictionary
		match stock_act:
			"ipo": stock_result = StockMarketManager.ipo(snapshot)
			"support": stock_result = StockMarketManager.support_market(snapshot, cmd.tick)
			"capgains": stock_result = StockMarketManager.capgains_tax(snapshot)
			_: stock_result = StockMarketManager.watchdog(snapshot)
		snapshot = stock_result.state
		for ev in stock_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("stock_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "veterans_action":
		var vet_act := str(cmd.payload.get("action", ""))
		var vet_result: Dictionary
		match vet_act:
			"pension": vet_result = VeteransManager.raise_pension(snapshot)
			"employment": vet_result = VeteransManager.employment_plan(snapshot)
			"clinic": vet_result = VeteransManager.veterans_clinic(snapshot)
			_: vet_result = VeteransManager.veterans_parade(snapshot, cmd.tick)
		snapshot = vet_result.state
		for ev in vet_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("veterans_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "heritage_action":
		var her_act := str(cmd.payload.get("action", ""))
		var her_result: Dictionary
		match her_act:
			"restore": her_result = HeritageManager.restore_sites(snapshot)
			"register": her_result = HeritageManager.register_unesco(snapshot)
			"festival": her_result = HeritageManager.heritage_festival(snapshot, cmd.tick)
			_: her_result = HeritageManager.antiquities_crackdown(snapshot, cmd.tick)
		snapshot = her_result.state
		for ev in her_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("heritage_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "transport_action":
		var trans_act := str(cmd.payload.get("action", ""))
		var trans_result: Dictionary
		match trans_act:
			"metro": trans_result = TransportManager.build_metro(snapshot, cmd.tick)
			"brt": trans_result = TransportManager.build_brt(snapshot, cmd.tick)
			"subsidy": trans_result = TransportManager.raise_subsidy(snapshot)
			_: trans_result = TransportManager.modernize_fleet(snapshot, cmd.tick)
		snapshot = trans_result.state
		for ev in trans_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("transport_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "retail_action":
		var ret_act := str(cmd.payload.get("action", ""))
		var ret_result: Dictionary
		match ret_act:
			"price": ret_result = RetailManager.toggle_price_control(snapshot)
			"protect": ret_result = RetailManager.consumer_protection(snapshot)
			"ecommerce": ret_result = RetailManager.boost_ecommerce(snapshot)
			_: ret_result = RetailManager.renovate_bazaars(snapshot, cmd.tick)
		snapshot = ret_result.state
		for ev in ret_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("retail_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "ethnicity_action":
		var eth_act := str(cmd.payload.get("action", ""))
		var eth_result: Dictionary
		match eth_act:
			"equal": eth_result = EthnicityManager.equal_opportunities(snapshot)
			"autonomy": eth_result = EthnicityManager.cultural_autonomy(snapshot)
			"dialogue": eth_result = EthnicityManager.national_dialogue(snapshot, cmd.tick)
			_: eth_result = EthnicityManager.ethnic_festival(snapshot, cmd.tick)
		snapshot = eth_result.state
		for ev in eth_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("ethnicity_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "water_action":
		var water_act := str(cmd.payload.get("action", ""))
		var water_result: Dictionary
		match water_act:
			"dam": water_result = WaterManager.build_dam(snapshot, cmd.tick)
			"desal": water_result = WaterManager.build_desalination(snapshot, cmd.tick)
			"leakage": water_result = WaterManager.reduce_leakage(snapshot)
			_: water_result = WaterManager.irrigation_upgrade(snapshot)
		snapshot = water_result.state
		for ev in water_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("water_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "research_action":
		var research_act := str(cmd.payload.get("action", ""))
		var research_result: Dictionary
		match research_act:
			"university": research_result = ResearchManager.fund_universities(snapshot)
			"center": research_result = ResearchManager.build_research_center(snapshot, cmd.tick)
			"transfer": research_result = ResearchManager.tech_transfer_program(snapshot)
			_: research_result = ResearchManager.retain_talent(snapshot, cmd.tick)
		snapshot = research_result.state
		for ev in research_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("research_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "civic_action":
		var civic_act := str(cmd.payload.get("action", ""))
		var civic_result: Dictionary
		match civic_act:
			"opendata": civic_result = CivicManager.open_data(snapshot)
			"councils": civic_result = CivicManager.empower_councils(snapshot)
			"budget": civic_result = CivicManager.participatory_budget(snapshot, cmd.tick)
			_: civic_result = CivicManager.protect_ngos(snapshot)
		snapshot = civic_result.state
		for ev in civic_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("civic_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "diaspora_action":
		var diaspora_act := str(cmd.payload.get("action", ""))
		var diaspora_result: Dictionary
		match diaspora_act:
			"summit": diaspora_result = DiasporaManager.hold_summit(snapshot, cmd.tick)
			"networks": diaspora_result = DiasporaManager.build_networks(snapshot)
			"diplomacy": diaspora_result = DiasporaManager.public_diplomacy(snapshot)
			_: diaspora_result = DiasporaManager.return_talent(snapshot)
		snapshot = diaspora_result.state
		for ev in diaspora_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("diaspora_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "civil_defense_action":
		var cd_act := str(cmd.payload.get("action", ""))
		var cd_result: Dictionary
		match cd_act:
			"hardening": cd_result = CivilDefenseManager.harden_targets(snapshot, cmd.tick)
			"redundancy": cd_result = CivilDefenseManager.build_redundancy(snapshot)
			"shelters": cd_result = CivilDefenseManager.build_shelters(snapshot)
			_: cd_result = CivilDefenseManager.strategic_stockpile(snapshot)
		snapshot = cd_result.state
		for ev in cd_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("civil_defense_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "blue_economy_action":
		var blue_act := str(cmd.payload.get("action", ""))
		var blue_result: Dictionary
		match blue_act:
			"port": blue_result = BlueEconomyManager.expand_port(snapshot, cmd.tick)
			"fleet": blue_result = BlueEconomyManager.expand_fleet(snapshot, cmd.tick)
			"fishery": blue_result = BlueEconomyManager.sustainable_fisheries(snapshot)
			_: blue_result = BlueEconomyManager.coast_guard_patrol(snapshot, cmd.tick)
		snapshot = blue_result.state
		for ev in blue_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("blue_economy_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "creative_action":
		var creative_act := str(cmd.payload.get("action", ""))
		var creative_result: Dictionary
		match creative_act:
			"funding": creative_result = CreativeManager.increase_funding(snapshot)
			"education": creative_result = CreativeManager.creative_education(snapshot)
			"platform": creative_result = CreativeManager.build_platform(snapshot)
			_: creative_result = CreativeManager.cultural_export(snapshot, cmd.tick)
		snapshot = creative_result.state
		for ev in creative_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("creative_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "demographic_action":
		var demo_act := str(cmd.payload.get("action", ""))
		var demo_result: Dictionary
		match demo_act:
			"pronatal": demo_result = DemographicManager.pro_natal_package(snapshot, cmd.tick)
			"childcare": demo_result = DemographicManager.expand_childcare(snapshot)
			"elderly": demo_result = DemographicManager.expand_elderly_care(snapshot)
			_: demo_result = DemographicManager.retraining_program(snapshot)
		snapshot = demo_result.state
		for ev in demo_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("demographic_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "watershed_action":
		var water_shed_act := str(cmd.payload.get("action", ""))
		var water_shed_result: Dictionary
		match water_shed_act:
			"restore": water_shed_result = WatershedManager.restore_watershed(snapshot, cmd.tick)
			"forest": water_shed_result = WatershedManager.reforest_land(snapshot)
			"dust": water_shed_result = WatershedManager.control_dust(snapshot)
			_: water_shed_result = WatershedManager.restore_wetlands(snapshot)
		snapshot = water_shed_result.state
		for ev in water_shed_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("watershed_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "prison_action":
		var prison_act := str(cmd.payload.get("action", ""))
		var prison_result: Dictionary
		match prison_act:
			"approach": prison_result = PrisonManager.set_approach(snapshot, str(cmd.payload.get("approach", "balanced")))
			"capacity": prison_result = PrisonManager.expand_capacity(snapshot, cmd.tick)
			"education": prison_result = PrisonManager.education_program(snapshot)
			_: prison_result = PrisonManager.amnesty_program(snapshot, cmd.tick)
		snapshot = prison_result.state
		for ev in prison_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("prison_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "statistics_action":
		var stats_act := str(cmd.payload.get("action", ""))
		var stats_result: Dictionary
		match stats_act:
			"census": stats_result = StatisticsManager.run_census(snapshot, cmd.tick)
			"infra": stats_result = StatisticsManager.build_data_infra(snapshot)
			"independence": stats_result = StatisticsManager.guarantee_independence(snapshot)
			_: stats_result = StatisticsManager.open_data_initiative(snapshot)
		snapshot = stats_result.state
		for ev in stats_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("statistics_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "mining_action":
		var mining_act := str(cmd.payload.get("action", ""))
		var mining_result: Dictionary
		match mining_act:
			"mine": mining_result = MiningManager.develop_mine(snapshot, cmd.tick)
			"refinery": mining_result = MiningManager.build_refinery(snapshot, cmd.tick)
			"safety": mining_result = MiningManager.improve_safety(snapshot)
			_: mining_result = MiningManager.formalize_mines(snapshot)
		snapshot = mining_result.state
		for ev in mining_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("mining_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "waste_action":
		var waste_act := str(cmd.payload.get("action", ""))
		var waste_result: Dictionary
		match waste_act:
			"collection": waste_result = WasteManager.expand_collection(snapshot)
			"recycling": waste_result = WasteManager.build_recycling(snapshot, cmd.tick)
			"landfill": waste_result = WasteManager.build_sanitary_landfill(snapshot)
			_: waste_result = WasteManager.circular_economy(snapshot, cmd.tick)
		snapshot = waste_result.state
		for ev in waste_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("waste_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "insurance_action":
		var ins_act := str(cmd.payload.get("action", ""))
		var ins_result: Dictionary
		match ins_act:
			"universal": ins_result = InsuranceManager.universal_scheme(snapshot, cmd.tick)
			"health": ins_result = InsuranceManager.expand_health(snapshot)
			"agri": ins_result = InsuranceManager.expand_agri(snapshot)
			_: ins_result = InsuranceManager.strengthen_regulation(snapshot)
		snapshot = ins_result.state
		for ev in ins_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("insurance_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "rural_action":
		var rural_act := str(cmd.payload.get("action", ""))
		var rural_result: Dictionary
		match rural_act:
			"roads": rural_result = RuralManager.build_rural_roads(snapshot, cmd.tick)
			"internet": rural_result = RuralManager.expand_rural_internet(snapshot)
			"processing": rural_result = RuralManager.build_agro_processing(snapshot)
			_: rural_result = RuralManager.support_nomads(snapshot)
		snapshot = rural_result.state
		for ev in rural_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("rural_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "judicial_reform_action":
		var jr_act := str(cmd.payload.get("action", ""))
		var jr_result: Dictionary
		match jr_act:
			"digital": jr_result = JudicialReformManager.digitalize_courts(snapshot, cmd.tick)
			"specialized": jr_result = JudicialReformManager.specialized_courts(snapshot)
			"mediation": jr_result = JudicialReformManager.mediation_program(snapshot)
			_: jr_result = JudicialReformManager.legal_aid(snapshot)
		snapshot = jr_result.state
		for ev in jr_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("judicial_reform_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "election_action":
		var el_act := str(cmd.payload.get("action", ""))
		var el_result: Dictionary
		match el_act:
			"hold": el_result = ElectionManager.hold_election(snapshot, cmd.tick)
			"monitoring": el_result = ElectionManager.strengthen_monitoring(snapshot)
			"access": el_result = ElectionManager.improve_voter_access(snapshot)
			_: el_result = ElectionManager.party_pluralism(snapshot)
		snapshot = el_result.state
		for ev in el_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("election_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "fuel_action":
		var fuel_act := str(cmd.payload.get("action", ""))
		var fuel_result: Dictionary
		match fuel_act:
			"reform": fuel_result = FuelTransitionManager.reform_subsidy(snapshot, cmd.tick)
			"charging": fuel_result = FuelTransitionManager.build_charging(snapshot)
			"emission": fuel_result = FuelTransitionManager.emission_standard(snapshot)
			_: fuel_result = FuelTransitionManager.electrify_public_fleet(snapshot)
		snapshot = fuel_result.state
		for ev in fuel_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("fuel_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "housing_action":
		var housing_act := str(cmd.payload.get("action", ""))
		var housing_result: Dictionary
		match housing_act:
			"social": housing_result = HousingManager.build_social_housing(snapshot, cmd.tick)
			"mortgage": housing_result = HousingManager.mortgage_policy(snapshot)
			"renewal": housing_result = HousingManager.urban_renewal(snapshot)
			_: housing_result = HousingManager.regulate_market(snapshot)
		snapshot = housing_result.state
		for ev in housing_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("housing_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "startup_action":
		var startup_act := str(cmd.payload.get("action", ""))
		var startup_result: Dictionary
		match startup_act:
			"fund": startup_result = StartupManager.fund_vc(snapshot, cmd.tick)
			"accelerator": startup_result = StartupManager.build_accelerator(snapshot)
			"sandbox": startup_result = StartupManager.regulatory_sandbox(snapshot)
			_: startup_result = StartupManager.reverse_brain_drain(snapshot)
		snapshot = startup_result.state
		for ev in startup_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("startup_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "sme_action":
		var sme_act := str(cmd.payload.get("action", ""))
		var sme_result: Dictionary
		match sme_act:
			"redtape": sme_result = SmeManager.cut_red_tape(snapshot)
			"microcredit": sme_result = SmeManager.micro_credit_fund(snapshot, cmd.tick)
			"supplychain": sme_result = SmeManager.supply_chain_finance(snapshot)
			_: sme_result = SmeManager.formalize_businesses(snapshot)
		snapshot = sme_result.state
		for ev in sme_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("sme_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "supply_action":
		var supply_act := str(cmd.payload.get("action", ""))
		var supply_result: Dictionary
		match supply_act:
			"reserve": supply_result = SupplyChainManager.build_reserve(snapshot, cmd.tick)
			"diversify": supply_result = SupplyChainManager.diversify_suppliers(snapshot)
			"domestic": supply_result = SupplyChainManager.build_domestic_capacity(snapshot)
			_: supply_result = SupplyChainManager.rotate_stockpile(snapshot)
		snapshot = supply_result.state
		for ev in supply_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("supply_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "care_action":
		var care_act := str(cmd.payload.get("action", ""))
		var care_result: Dictionary
		match care_act:
			"eldercare": care_result = CareEconomyManager.eldercare_program(snapshot)
			"childcare": care_result = CareEconomyManager.childcare_expansion(snapshot)
			"homecare": care_result = CareEconomyManager.home_care_program(snapshot)
			_: care_result = CareEconomyManager.paid_parental_leave(snapshot)
		snapshot = care_result.state
		for ev in care_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("care_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "science_action":
		var science_act := str(cmd.payload.get("action", ""))
		var science_result: Dictionary
		match science_act:
			"agreement": science_result = ScienceDiplomacyManager.science_agreement(snapshot, cmd.tick)
			"lab": science_result = ScienceDiplomacyManager.joint_lab(snapshot)
			"scholarship": science_result = ScienceDiplomacyManager.scholarship_program(snapshot)
			_: science_result = ScienceDiplomacyManager.tech_consortium(snapshot)
		snapshot = science_result.state
		for ev in science_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("science_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "downstream_action":
		var ds_act := str(cmd.payload.get("action", ""))
		var ds_result: Dictionary
		match ds_act:
			"refining": ds_result = DownstreamEnergyManager.expand_refining(snapshot, cmd.tick)
			"petrochem": ds_result = DownstreamEnergyManager.expand_petrochemical(snapshot)
			"selfsuff": ds_result = DownstreamEnergyManager.self_sufficiency_drive(snapshot)
			_: ds_result = DownstreamEnergyManager.upgrade_value_chain(snapshot)
		snapshot = ds_result.state
		for ev in ds_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("downstream_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "higher_ed_action":
		var he_act := str(cmd.payload.get("action", ""))
		var he_result: Dictionary
		match he_act:
			"funding": he_result = HigherEducationManager.increase_funding(snapshot, cmd.tick)
			"research": he_result = HigherEducationManager.research_grant(snapshot)
			"faculty": he_result = HigherEducationManager.faculty_development(snapshot)
			_: he_result = HigherEducationManager.internationalize(snapshot)
		snapshot = he_result.state
		for ev in he_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("higher_ed_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "food_chain_action":
		var fc_act := str(cmd.payload.get("action", ""))
		var fc_result: Dictionary
		match fc_act:
			"storage": fc_result = FoodValueChainManager.build_storage(snapshot, cmd.tick)
			"processing": fc_result = FoodValueChainManager.expand_processing(snapshot)
			"logistics": fc_result = FoodValueChainManager.improve_logistics(snapshot)
			_: fc_result = FoodValueChainManager.enforce_safety(snapshot)
		snapshot = fc_result.state
		for ev in fc_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("food_chain_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "pharma_action":
		var ph_act := str(cmd.payload.get("action", ""))
		var ph_result: Dictionary
		match ph_act:
			"plant": ph_result = PharmaManager.build_plant(snapshot, cmd.tick)
			"generic": ph_result = PharmaManager.expand_generic(snapshot)
			"stockpile": ph_result = PharmaManager.stockpile_drugs(snapshot)
			_: ph_result = PharmaManager.vaccine_program(snapshot)
		snapshot = ph_result.state
		for ev in ph_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("pharma_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "ip_action":
		var ip_act := str(cmd.payload.get("action", ""))
		var ip_result: Dictionary
		match ip_act:
			"patent": ip_result = IntellectualPropertyManager.patent_reform(snapshot, cmd.tick)
			"copyright": ip_result = IntellectualPropertyManager.strengthen_copyright(snapshot)
			"transfer": ip_result = IntellectualPropertyManager.tech_transfer_office(snapshot)
			_: ip_result = IntellectualPropertyManager.science_park(snapshot)
		snapshot = ip_result.state
		for ev in ip_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("ip_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "transit_action":
		var tr_act := str(cmd.payload.get("action", ""))
		var tr_result: Dictionary
		match tr_act:
			"corridor": tr_result = TransitManager.expand_corridor(snapshot, cmd.tick)
			"customs": tr_result = TransitManager.customs_reform(snapshot)
			"rail": tr_result = TransitManager.rail_freight(snapshot)
			_: tr_result = TransitManager.free_zone(snapshot)
		snapshot = tr_result.state
		for ev in tr_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("transit_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "disaster_action":
		var dis_act := str(cmd.payload.get("action", ""))
		var dis_result: Dictionary
		match dis_act:
			"warning": dis_result = DisasterManager.build_early_warning(snapshot, cmd.tick)
			"shelter": dis_result = DisasterManager.build_shelters(snapshot)
			"response": dis_result = DisasterManager.train_response(snapshot, cmd.tick)
			_: dis_result = DisasterManager.relief_aid(snapshot)
		snapshot = dis_result.state
		for ev in dis_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("disaster_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "livestock_action":
		var live_act := str(cmd.payload.get("action", ""))
		var live_result: Dictionary
		match live_act:
			"industrial": live_result = LivestockManager.expand_industrial(snapshot, cmd.tick)
			"vaccine": live_result = LivestockManager.vaccination(snapshot)
			"feed": live_result = LivestockManager.improve_feed(snapshot)
			_: live_result = LivestockManager.breeding_program(snapshot)
		snapshot = live_result.state
		for ev in live_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("livestock_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "textile_action":
		var tex_act := str(cmd.payload.get("action", ""))
		var tex_result: Dictionary
		match tex_act:
			"mills": tex_result = TextileManager.expand_mills(snapshot, cmd.tick)
			"cotton": tex_result = TextileManager.cotton_supply(snapshot)
			"apparel": tex_result = TextileManager.apparel_parks(snapshot)
			_: tex_result = TextileManager.branding(snapshot)
		snapshot = tex_result.state
		for ev in tex_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("textile_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "basic_industry_action":
		var bi_act := str(cmd.payload.get("action", ""))
		var bi_result: Dictionary
		match bi_act:
			"steel": bi_result = BasicIndustryManager.expand_steel(snapshot, cmd.tick)
			"cement": bi_result = BasicIndustryManager.expand_cement(snapshot)
			"integration": bi_result = BasicIndustryManager.integrate_chain(snapshot)
			_: bi_result = BasicIndustryManager.efficiency_program(snapshot)
		snapshot = bi_result.state
		for ev in bi_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("basic_industry_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "nation_brand_action":
		var nb_act := str(cmd.payload.get("action", ""))
		var nb_result: Dictionary
		match nb_act:
			"branding": nb_result = NationBrandManager.brand_campaign(snapshot, cmd.tick)
			"event": nb_result = NationBrandManager.host_event(snapshot)
			"heritage": nb_result = NationBrandManager.promote_heritage(snapshot)
			_: nb_result = NationBrandManager.cultural_export(snapshot)
		snapshot = nb_result.state
		for ev in nb_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("nation_brand_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "ai_action":
		var ai_act := str(cmd.payload.get("action", ""))
		var ai_result: Dictionary
		match ai_act:
			"adopt": ai_result = AiIndustryManager.adopt_ai(snapshot, cmd.tick)
			"robotics": ai_result = AiIndustryManager.industrial_robotics(snapshot)
			"reskill": ai_result = AiIndustryManager.reskilling_program(snapshot)
			_: ai_result = AiIndustryManager.data_infrastructure(snapshot)
		snapshot = ai_result.state
		for ev in ai_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("ai_event", ev, cmd.tick, cmd.version)

	elif cmd.type == "defense_industry_action":
		var di_act := str(cmd.payload.get("action", ""))
		var di_result: Dictionary
		match di_act:
			"production": di_result = DefenseIndustryManager.expand_production(snapshot)
			"rnd": di_result = DefenseIndustryManager.invest_rnd(snapshot)
			"maintenance": di_result = DefenseIndustryManager.improve_maintenance(snapshot)
			"training": di_result = DefenseIndustryManager.train_personnel(snapshot)
			_: di_result = DefenseIndustryManager.allow_exports(snapshot)
		if di_result.get("success", false):
			snapshot = DefenseIndustryManager.simulate(snapshot, cmd.tick)
			snapshot = _charge_action_cost(snapshot, str(cmd.type), di_act)
	elif cmd.type == "knowledge_economy_action":
		var ke_act := str(cmd.payload.get("action", ""))
		var ke_result: Dictionary
		match ke_act:
			"park": ke_result = KnowledgeEconomyManager.build_tech_park(snapshot)
			"incubator": ke_result = KnowledgeEconomyManager.expand_incubator(snapshot)
			"startup": ke_result = KnowledgeEconomyManager.support_startups(snapshot)
			"commercialize": ke_result = KnowledgeEconomyManager.commercialize_research(snapshot)
			_: ke_result = KnowledgeEconomyManager.attract_vc(snapshot)
		if ke_result.get("success", false):
			snapshot = KnowledgeEconomyManager.simulate(snapshot, cmd.tick)
			snapshot = _charge_action_cost(snapshot, str(cmd.type), ke_act)
	elif cmd.type == "waste_mgmt_action":
		var wm_act := str(cmd.payload.get("action", ""))
		var wm_result: Dictionary
		match wm_act:
			"collection": wm_result = WasteManagementManager.expand_collection(snapshot)
			"separation": wm_result = WasteManagementManager.source_separation(snapshot)
			"recycling": wm_result = WasteManagementManager.build_recycling(snapshot)
			"wte": wm_result = WasteManagementManager.build_wte(snapshot)
			_: wm_result = WasteManagementManager.reduce_landfill(snapshot)
		if wm_result.get("success", false):
			snapshot = WasteManagementManager.simulate(snapshot, cmd.tick)
			snapshot = _charge_action_cost(snapshot, str(cmd.type), wm_act)
	elif cmd.type == "aerospace_action":
		var as_act := str(cmd.payload.get("action", ""))
		var as_result: Dictionary
		match as_act:
			"launch": as_result = AerospaceManager.expand_launch(snapshot)
			"factory": as_result = AerospaceManager.build_satellite_factory(snapshot)
			"sensing": as_result = AerospaceManager.invest_remote_sensing(snapshot)
			"telecom": as_result = AerospaceManager.invest_space_telecom(snapshot)
			_: as_result = AerospaceManager.invest_rnd(snapshot)
		if as_result.get("success", false):
			snapshot = AerospaceManager.simulate(snapshot, cmd.tick)
			snapshot = _charge_action_cost(snapshot, str(cmd.type), as_act)
	elif cmd.type == "petrochemical_action":
		var pe_act := str(cmd.payload.get("action", ""))
		var pe_result: Dictionary
		match pe_act:
			"feedstock": pe_result = PetrochemicalManager.secure_feedstock(snapshot)
			"plants": pe_result = PetrochemicalManager.build_plants(snapshot)
			"downstream": pe_result = PetrochemicalManager.expand_downstream(snapshot)
			"catalyst": pe_result = PetrochemicalManager.invest_catalyst(snapshot)
			_: pe_result = PetrochemicalManager.boost_exports(snapshot)
		if pe_result.get("success", false):
			snapshot = PetrochemicalManager.simulate(snapshot, cmd.tick)
			snapshot = _charge_action_cost(snapshot, str(cmd.type), pe_act)
	elif cmd.type == "mega_event":
		var me_result := MegaEventManager.bid(snapshot, str(cmd.payload.get("event_id", "")), cmd.tick)
		snapshot = me_result.state
		for me_ev in me_result.get("events", []):
			if me_ev is Dictionary:
				EventLog.log_event("mega_event", me_ev, cmd.tick, cmd.version)
	elif cmd.type == "pro_sports_action":
		var ps_act := str(cmd.payload.get("action", ""))
		var ps_result: Dictionary
		match ps_act:
			"leagues": ps_result = ProSportsManager.develop_leagues(snapshot)
			"infrastructure": ps_result = ProSportsManager.build_infrastructure(snapshot)
			"events": ps_result = ProSportsManager.host_events(snapshot)
			"academy": ps_result = ProSportsManager.develop_academy(snapshot)
			_: ps_result = ProSportsManager.boost_exports(snapshot)
		if ps_result.get("success", false):
			snapshot = ProSportsManager.simulate(snapshot, cmd.tick)
			snapshot = _charge_action_cost(snapshot, str(cmd.type), ps_act)
	elif cmd.type == "aviation_action":
		var av_act := str(cmd.payload.get("action", ""))
		var av_result: Dictionary
		match av_act:
			"airports": av_result = AviationManager.expand_airports(snapshot)
			"fleet": av_result = AviationManager.expand_fleet(snapshot)
			"safety": av_result = AviationManager.improve_safety(snapshot)
			"hub": av_result = AviationManager.develop_hub(snapshot)
			_: av_result = AviationManager.develop_cargo(snapshot)
		if av_result.get("success", false):
			snapshot = AviationManager.simulate(snapshot, cmd.tick)
			snapshot = _charge_action_cost(snapshot, str(cmd.type), av_act)
	elif cmd.type == "postal_action":
		var po_act := str(cmd.payload.get("action", ""))
		var po_result: Dictionary
		match po_act:
			"network": po_result = PostalManager.expand_network(snapshot)
			"sorting": po_result = PostalManager.mechanize_sorting(snapshot)
			"lastmile": po_result = PostalManager.improve_lastmile(snapshot)
			"ecommerce": po_result = PostalManager.boost_ecommerce(snapshot)
			_: po_result = PostalManager.improve_tracking(snapshot)
		if po_result.get("success", false):
			snapshot = PostalManager.simulate(snapshot, cmd.tick)
			snapshot = _charge_action_cost(snapshot, str(cmd.type), po_act)
	elif cmd.type == "standards_action":
		var st_act := str(cmd.payload.get("action", ""))
		var st_result: Dictionary
		match st_act:
			"metrology": st_result = StandardsManager.invest_metrology(snapshot)
			"labs": st_result = StandardsManager.accredit_labs(snapshot)
			"accreditation": st_result = StandardsManager.expand_accreditation(snapshot)
			"surveillance": st_result = StandardsManager.improve_surveillance(snapshot)
			_: st_result = StandardsManager.strengthen_export_gate(snapshot)
		if st_result.get("success", false):
			snapshot = StandardsManager.simulate(snapshot, cmd.tick)
			snapshot = _charge_action_cost(snapshot, str(cmd.type), st_act)
	elif cmd.type == "tax_action":
		# عمق ۱۸ - دیسپچ اجرایی مالیات (قبلاً فقط اعتبارسنجی می‌شد و اجرا نمی‌شد!)
		var tx_act := str(cmd.payload.get("action", ""))
		var tx_result: Dictionary
		match tx_act:
			"compliance": tx_result = TaxManager.improve_compliance(snapshot)
			"digital": tx_result = TaxManager.deploy_digital_invoicing(snapshot)
			"bracket": tx_result = TaxManager.add_bracket(snapshot)
			_: tx_result = TaxManager.set_rate(snapshot, tx_act, float(cmd.payload.get("value", 0.2)))
		if tx_result.get("success", false):
			snapshot = TaxManager.simulate(snapshot, cmd.tick)
			snapshot = _charge_action_cost(snapshot, str(cmd.type), tx_act)
	elif cmd.type == "ev_action":
		# عمق ۱۸ - دیسپچ اجرایی خودرو/باطری (قبلاً اجرا نمی‌شد)
		var ev_act := str(cmd.payload.get("action", ""))
		var ecar_result: Dictionary
		match ev_act:
			"battery": ecar_result = EvIndustryManager.build_battery_factory(snapshot)
			"research": ecar_result = EvIndustryManager.invest_battery_research(snapshot)
			"production": ecar_result = EvIndustryManager.expand_ev_production(snapshot)
			"charging": ecar_result = EvIndustryManager.build_charging_network(snapshot)
			_: ecar_result = EvIndustryManager.expand_recycling(snapshot)
		if ecar_result.get("success", false):
			snapshot = EvIndustryManager.simulate(snapshot, cmd.tick)
			snapshot = _charge_action_cost(snapshot, str(cmd.type), ev_act)
	elif cmd.type == "health_tourism_action":
		# عمق ۱۸ - دیسپچ اجرایی گردشگری سلامت (قبلاً اجرا نمی‌شد)
		var ht_act := str(cmd.payload.get("action", ""))
		var ht_result: Dictionary
		match ht_act:
			"hospital": ht_result = HealthTourismManager.build_international_hospital(snapshot)
			"quality": ht_result = HealthTourismManager.improve_quality(snapshot)
			"wellness": ht_result = HealthTourismManager.develop_wellness(snapshot)
			"visa": ht_result = HealthTourismManager.facilitate_visa(snapshot)
			"accreditation": ht_result = HealthTourismManager.international_accreditation(snapshot)
			_: ht_result = HealthTourismManager.marketing_campaign(snapshot)
		if ht_result.get("success", false):
			snapshot = HealthTourismManager.simulate(snapshot, cmd.tick)
			snapshot = _charge_action_cost(snapshot, str(cmd.type), ht_act)
	elif cmd.type == "assassinate":
		var a_target = str(cmd.payload.get("target", ""))
		var a_result = LeaderManager.attempt_assassination(snapshot, a_target, cmd.tick)
		snapshot = a_result.state
		for ev in a_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("world_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "leader_hidden":
		var hide_result = LeaderManager.set_hidden(snapshot, bool(cmd.payload.get("hidden", false)), cmd.tick)
		snapshot = hide_result.state
		for ev in hide_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("world_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "leader_name":
		var name_result = LeaderManager.set_leader_name(snapshot, str(cmd.payload.get("name", "")))
		snapshot = name_result.state
		for ev in name_result.get("events", []):
			if ev is Dictionary:
				EventLog.log_event("world_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "research_start":
		var tech_id = cmd.payload.get("tech_id", "")
		snapshot["technology"]["in_progress"] = tech_id
	elif cmd.type == "diplomacy":
		var world_result = WorldManager.apply_action(
			snapshot, str(cmd.payload.get("target", "")), str(cmd.payload.get("action", "")), cmd.tick,
			str(cmd.payload.get("goal", "reparations")))
		if world_result.success:
			snapshot = world_result.state
			for event in world_result.events:
				EventLog.log_event("world_event", event, cmd.tick, cmd.version)
	elif cmd.type == "country_select":
		var country_id = str(cmd.payload.get("country_id", ""))
		var scenario_id = str(cmd.payload.get("scenario_id", ScenarioManager.default_scenario))
		snapshot = WorldManager.apply_country_profile(snapshot, country_id)
		snapshot = TimeManager.reset(snapshot)
		snapshot = SeasonalManager.reset_for_country(snapshot, country_id)
		snapshot = MilitaryManager.reset(snapshot)
		snapshot = NationalProjectManager.reset(snapshot)
		snapshot = CabinetManager.reset(snapshot)
		snapshot = LawManager.reset(snapshot)
		snapshot = IntelligenceOperationManager.reset(snapshot)
		snapshot = MapLayerManager.update_network_metrics(snapshot)
		snapshot = ScenarioManager.apply_scenario(snapshot, scenario_id, snapshot.get("tick", 0))
		snapshot = PolicyManager.reset(snapshot)
		snapshot = AnalyticsManager.reset(snapshot)
		CelebrationManager.reset_tracking(snapshot)
		EventLog.log_event("country_selected", {
			"message": "کشور %s و سناریوی «%s» برای آغاز بازی انتخاب شدند" % [
				WorldManager.get_country_name(country_id), ScenarioManager.get_scenario_name(scenario_id)],
			"country_id": country_id,
			"scenario_id": scenario_id
		}, cmd.tick, cmd.version)
	elif cmd.type == "policy_change":
		var policy_result = PolicyManager.apply_change(
			snapshot, str(cmd.payload.get("policy_id", "")), bool(cmd.payload.get("enabled", false)), cmd.tick)
		if policy_result.success:
			snapshot = policy_result.state
			for policy_event in policy_result.events:
				EventLog.log_event("policy_event", policy_event, cmd.tick, cmd.version)
	elif cmd.type == "municipal_action":
		var municipal_result = SeasonalManager.apply_action(snapshot, str(cmd.payload.get("action", "")), cmd.tick)
		if municipal_result.success:
			snapshot = municipal_result.state
			for municipal_event in municipal_result.events:
				EventLog.log_event("municipal_event", municipal_event, cmd.tick, cmd.version)
	elif cmd.type == "military_program":
		var program_result = MilitaryManager.start_program(snapshot, str(cmd.payload.get("program_id", "")), cmd.tick)
		if program_result.success:
			snapshot = program_result.state
			for program_event in program_result.events:
				EventLog.log_event("military_event", program_event, cmd.tick, cmd.version)
	elif cmd.type == "military_doctrine":
		var doctrine_result = MilitaryManager.set_doctrine(snapshot, str(cmd.payload.get("doctrine", "")), cmd.tick)
		if doctrine_result.success:
			snapshot = doctrine_result.state
			for doctrine_event in doctrine_result.events:
				EventLog.log_event("military_event", doctrine_event, cmd.tick, cmd.version)
	elif cmd.type == "national_project":
		var project_id = str(cmd.payload.get("project_id", ""))
		var project_result = NationalProjectManager.start_project(snapshot, project_id, cmd.tick) if str(cmd.payload.get("action", "start")) == "start" else NationalProjectManager.cancel_project(snapshot, project_id, cmd.tick)
		if project_result.success:
			snapshot = project_result.state
			for project_event in project_result.events:
				EventLog.log_event("national_project_event", project_event, cmd.tick, cmd.version)
	elif cmd.type == "cabinet_change":
		var ministry_id = str(cmd.payload.get("ministry_id", ""))
		var cabinet_result: Dictionary
		match str(cmd.payload.get("action", "appoint")):
			"mission": cabinet_result = CabinetManager.assign_mission(snapshot, ministry_id, cmd.tick)
			"mediate": cabinet_result = CabinetManager.mediate_dispute(snapshot, cmd.tick)
			"dismiss": cabinet_result = CabinetManager.dismiss(snapshot, ministry_id, cmd.tick)
			_: cabinet_result = CabinetManager.appoint(snapshot, ministry_id, str(cmd.payload.get("candidate_id", "")), cmd.tick)
		if cabinet_result.success:
			snapshot = cabinet_result.state
			for cabinet_event in cabinet_result.events:
				EventLog.log_event("cabinet_event", cabinet_event, cmd.tick, cmd.version)
	elif cmd.type == "law_change":
		var law_id = str(cmd.payload.get("law_id", ""))
		var law_result = LawManager.enact(snapshot, law_id, cmd.tick) if str(cmd.payload.get("action", "enact")) == "enact" else LawManager.repeal(snapshot, law_id, cmd.tick)
		if law_result.success:
			snapshot = law_result.state
			for law_event in law_result.events: EventLog.log_event("law_event", law_event, cmd.tick, cmd.version)
	elif cmd.type == "intelligence_operation":
		var intel_result = IntelligenceOperationManager.start(snapshot,str(cmd.payload.get("operation_id","")),str(cmd.payload.get("target","")),cmd.tick) if str(cmd.payload.get("action","start"))=="start" else IntelligenceOperationManager.cancel(snapshot,str(cmd.payload.get("operation_key","")),cmd.tick)
		if intel_result.success:
			snapshot=intel_result.state
			for intel_event in intel_result.events:EventLog.log_event("intelligence_operation_event",intel_event,cmd.tick,cmd.version)
	elif cmd.type == "decision_resolve":
		var decision_result = DecisionManagerClass.resolve_decision(
			snapshot, cmd.payload.get("decision_id", ""), cmd.payload.get("choice_id", ""))
		if decision_result.success:
			EventLog.log_event("decision_resolved", {
				"message": "تصمیم «%s» با گزینه «%s» اجرا شد" % [
					decision_result.decision.get("title", ""), decision_result.choice.get("text", "")],
				"decision_id": cmd.payload.get("decision_id", ""),
				"choice_id": cmd.payload.get("choice_id", "")
			}, cmd.tick, cmd.version)
	elif cmd.type == "trade_route_attack":
		var route_id = str(cmd.payload.get("route_id", ""))
		var route_type = str(cmd.payload.get("route_type", "trade"))
		var operation = str(cmd.payload.get("operation", "raid"))
		var from_c = str(cmd.payload.get("from_country", ""))
		var to_c = str(cmd.payload.get("to_country", ""))
		# سیستم جنگ مسیرهای تجاری را صدا بزن
		if systems.has("trade_route_warfare"):
			var result = systems["trade_route_warfare"].apply_attack(snapshot, route_id, route_type, operation, from_c, to_c, cmd.tick)
			if result.success:
				snapshot = result.state
				for ev in result.events:
					EventLog.log_event("trade_route_event", ev, cmd.tick, cmd.version)
		else:
			# fallback ساده اگر سیستم جدید هنوز لود نشده
			snapshot = _apply_trade_route_attack_simple(snapshot, route_id, route_type, operation, from_c, to_c, cmd.tick)
	elif cmd.type == "chokepoint_action":
		var chokepoint_id = str(cmd.payload.get("chokepoint_id", ""))
		var action = str(cmd.payload.get("action", "blockade"))
		if systems.has("trade_route_warfare"):
			var result = systems["trade_route_warfare"].apply_chokepoint(snapshot, chokepoint_id, action, cmd.tick)
			if result.success:
				snapshot = result.state
				for ev in result.events:
					EventLog.log_event("chokepoint_event", ev, cmd.tick, cmd.version)
		else:
			snapshot = _apply_chokepoint_simple(snapshot, chokepoint_id, action, cmd.tick)
	elif cmd.type == "map_operation":
		var target_country = str(cmd.payload.get("target_country", ""))
		var op_type = str(cmd.payload.get("operation_type", ""))
		if systems.has("trade_route_warfare"):
			var result = systems["trade_route_warfare"].apply_map_operation(snapshot, target_country, op_type, cmd.payload, cmd.tick)
			if result.success:
				snapshot = result.state
				for ev in result.events:
					EventLog.log_event("map_operation_event", ev, cmd.tick, cmd.version)
		elif systems.has("map_advanced"):
			var result = systems["map_advanced"].apply_map_operation(snapshot, target_country, op_type, cmd.payload, cmd.tick)
			if result.success:
				snapshot = result.state
				for ev in result.events:
					EventLog.log_event("map_operation_event", ev, cmd.tick, cmd.version)
	elif cmd.type == "battle_plan":
		var from_c = str(cmd.payload.get("from_country",""))
		var to_c = str(cmd.payload.get("to_country",""))
		var plan_type = str(cmd.payload.get("plan_type","offensive"))
		if systems.has("map_advanced"):
			var result = systems["map_advanced"].apply_battle_plan(snapshot, from_c, str(cmd.payload.get("from_unit","")), to_c, str(cmd.payload.get("to_unit","")), plan_type, float(cmd.payload.get("from_lat",0.0)), float(cmd.payload.get("from_lon",0.0)), float(cmd.payload.get("to_lat",0.0)), float(cmd.payload.get("to_lon",0.0)), cmd.tick)
			if result.success:
				snapshot = result.state
				for ev in result.events:
					EventLog.log_event("battle_plan_event", ev, cmd.tick, cmd.version)
		else:
			snapshot = _apply_battle_plan_simple(snapshot, from_c, to_c, plan_type, cmd.tick)
	elif cmd.type == "construction":
		var from_c = str(cmd.payload.get("from_country",""))
		var to_c = str(cmd.payload.get("to_country",""))
		var build_type = str(cmd.payload.get("build_type","road"))
		if systems.has("map_advanced"):
			var result = systems["map_advanced"].apply_construction(snapshot, from_c, str(cmd.payload.get("from_unit","")), to_c, str(cmd.payload.get("to_unit","")), build_type, float(cmd.payload.get("from_lat",0.0)), float(cmd.payload.get("from_lon",0.0)), float(cmd.payload.get("to_lat",0.0)), float(cmd.payload.get("to_lon",0.0)), cmd.tick)
			if result.success:
				snapshot = result.state
				for ev in result.events:
					EventLog.log_event("construction_event", ev, cmd.tick, cmd.version)
		else:
			snapshot = _apply_construction_simple(snapshot, from_c, to_c, build_type, cmd.tick)
	elif cmd.type == "map_building":
		var building_type = str(cmd.payload.get("building_type","fort"))
		var country_id = str(cmd.payload.get("country_id",""))
		var unit_id = str(cmd.payload.get("unit_id",""))
		if systems.has("map_advanced"):
			var result = systems["map_advanced"].apply_building(snapshot, building_type, country_id, unit_id, float(cmd.payload.get("lat",0.0)), float(cmd.payload.get("lon",0.0)), cmd.tick)
			if result.success:
				snapshot = result.state
				for ev in result.events:
					EventLog.log_event("map_building_event", ev, cmd.tick, cmd.version)
	# بازرسی اقدامات ۲ — هر اقدام «_action» که از مسیر مدیرش هم هیچ شارژی نگذرانده،
	# هزینه سطح‌بندی‌شده‌اش (نمادین/اداری/استاندارد/سرمایه‌ای) به بدهی دولت می‌گیرد؛ رایگان نیست!
	var _final_type: String = str(cmd.type)
	if _final_type.ends_with("_action"):
		var _econ_after: Dictionary = snapshot.get("economy", {})
		var _extra_after: float = float(_econ_after.get("extra_spending_daily", 0.0))
		var _debt_after: float = float(_econ_after.get("national_debt", 0.0))
		var _gdp_final: float = float(_econ_after.get("gdp", 0.0))
		if absf(_extra_after - _extra_before) < 1.0 and absf(_debt_after - _debt_before) < 1.0 and _gdp_final > 0.0:
			var _tier: String = str(ACTION_FALLBACK_FAMILY.get(_final_type, "standard"))
			var _share: float = float(ACTION_FALLBACK_TIERS[_tier])
			_econ_after["national_debt"] = _debt_after + _gdp_final * _share
			snapshot["economy"] = _econ_after
			var _tier_fa: Array = ACTION_TIER_FA[_tier]
			EventLog.log_event("action_cost", {"message": "اعتبار اجرای %s از محل بدهی دولت تأمین شد (%s تولید ناخالص سالانه)" % [str(_tier_fa[0]), str(_tier_fa[1])], "command": _final_type}, cmd.tick, cmd.version)
	# تمام انواع فرمان در همان تراکنش و با فراداده نسخه مقصد ثبت می‌شوند.
	EventLog.log_event("command_applied", cmd.to_dict(), cmd.tick, cmd.version)

# === Fallback ساده برای حملات مسیر تجاری اگر سیستم جدید لود نشده باشد ===
	return snapshot

func _apply_trade_route_attack_simple(snapshot: Dictionary, route_id: String, route_type: String, operation: String, from_c: String, to_c: String, tick: int) -> Dictionary:
	var trade_warfare = snapshot.get("trade_route_warfare", {})
	trade_warfare["attacks"] = trade_warfare.get("attacks", [])
	trade_warfare["attacks"].append({"route_id": route_id, "route_type": route_type, "operation": operation, "from": from_c, "to": to_c, "tick": tick, "status": "active"})
	snapshot["trade_route_warfare"] = trade_warfare
	# اثر اقتصادی ساده
	var trade = snapshot.get("trade", {})
	if operation in ["blockade","raid","sabotage","mine"]:
		trade["exports"] = float(trade.get("exports", 80e9)) * 0.98
		trade["imports"] = float(trade.get("imports", 70e9)) * 0.99
		snapshot["trade"] = trade
		snapshot["economy"]["gdp"] = float(snapshot["economy"].get("gdp", 500e9)) * 0.9995
	return snapshot

func _apply_chokepoint_simple(snapshot: Dictionary, chokepoint_id: String, action: String, tick: int) -> Dictionary:
	var trade_warfare = snapshot.get("trade_route_warfare", {})
	trade_warfare["chokepoints"] = trade_warfare.get("chokepoints", {})
	trade_warfare["chokepoints"][chokepoint_id] = {"action": action, "tick": tick, "level": 0.5}
	snapshot["trade_route_warfare"] = trade_warfare
	if action == "blockade":
		snapshot["economy"]["gdp"] = float(snapshot["economy"].get("gdp", 500e9)) * 0.998
	return snapshot

func _apply_battle_plan_simple(snapshot: Dictionary, from_c: String, to_c: String, plan_type: String, tick: int) -> Dictionary:
	var map_adv = snapshot.get("map_advanced", {})
	map_adv["battle_plans"] = map_adv.get("battle_plans", [])
	map_adv["battle_plans"].append({"from_country": from_c, "to_country": to_c, "plan_type": plan_type, "tick": tick, "status": "planned", "progress": 0.0})
	snapshot["map_advanced"] = map_adv
	return snapshot

func _apply_construction_simple(snapshot: Dictionary, from_c: String, to_c: String, build_type: String, tick: int) -> Dictionary:
	var map_adv = snapshot.get("map_advanced", {})
	map_adv["constructions"] = map_adv.get("constructions", [])
	map_adv["constructions"].append({"from_country": from_c, "to_country": to_c, "build_type": build_type, "tick": tick, "progress": 0.0, "status": "building"})
	snapshot["map_advanced"] = map_adv
	snapshot["economy"]["national_debt"] = float(snapshot["economy"].get("national_debt", 0.0)) + 0.5e9
	return snapshot

func _compute_all_systems(snapshot: Dictionary, turn: int) -> Dictionary:
	# هر فرمان بازیکن یک ماه است؛ معادلات و هوش سیستم‌ها در روزهای داخلی ماه اجرا می‌شوند.
	var generated_events: Array = []
	var open_result = _month_open(snapshot, turn)
	snapshot = open_result.state
	generated_events.append_array(open_result.events)

	var days = int(snapshot.get("time", {}).get("days_in_month", 30))
	for day in range(1, days + 1):
		var day_result = _month_day(snapshot, turn, day, generated_events)
		if not day_result.success:
			return day_result
		snapshot = day_result.state

	return _month_close(snapshot, turn, generated_events)

func _compute_all_systems_async(snapshot: Dictionary, turn: int) -> Dictionary:
	# نسخه فریم‌رهاکننده؛ منطق با نسخه همگام مشترک است تا نتیجه بایت‌به‌بایت برابر بماند.
	var generated_events: Array = []
	var open_result = _month_open(snapshot, turn)
	snapshot = open_result.state
	generated_events.append_array(open_result.events)

	var days = int(snapshot.get("time", {}).get("days_in_month", 30))
	for day in range(1, days + 1):
		var day_result = _month_day(snapshot, turn, day, generated_events)
		if not day_result.success:
			return day_result
		snapshot = day_result.state
		emit_signal("tick_progress", day, days, "شبیه‌سازی روز %d از %d" % [day, days])
		await get_tree().process_frame

	return _month_close(snapshot, turn, generated_events)

# آغاز ماه: شبیه‌سازی فصلی و اقلیمی پیش از روزهای شبیه‌سازی
func _month_open(snapshot: Dictionary, turn: int) -> Dictionary:
	var generated_events: Array = []
	snapshot = LeaderManager.ensure(snapshot)
	snapshot = FactionManager.ensure(snapshot)
	snapshot = GeneralsManager.ensure(snapshot)
	snapshot = MediaManager.ensure(snapshot)
	snapshot = CommodityManager.ensure(snapshot)
	snapshot = OrgManager.ensure(snapshot)
	snapshot = ParliamentManager.ensure(snapshot)
	snapshot = ForexManager.ensure(snapshot)
	snapshot = GovernorsManager.ensure(snapshot)
	snapshot = RivalryManager.ensure(snapshot)
	snapshot = ShadowManager.ensure(snapshot)
	snapshot = JudiciaryManager.ensure(snapshot)
	snapshot = EnergyManager.ensure(snapshot)
	snapshot = IndustryManager.ensure(snapshot)
	snapshot = SuccessionManager.ensure(snapshot)
	snapshot = LaborManager.ensure(snapshot)
	snapshot = EpidemicManager.ensure(snapshot)
	snapshot = ArmsManager.ensure(snapshot)
	snapshot = CyberManager.ensure(snapshot)
	snapshot = MigrationManager.ensure(snapshot)
	snapshot = CultureManager.ensure(snapshot)
	snapshot = EducationManager.ensure(snapshot)
	snapshot = AgricultureManager.ensure(snapshot)
	snapshot = TourismManager.ensure(snapshot)
	snapshot = UrbanManager.ensure(snapshot)
	snapshot = SecurityManager.ensure(snapshot)
	snapshot = InfrastructureManager.ensure(snapshot)
	snapshot = ClimateManager.ensure(snapshot)
	snapshot = WelfareManager.ensure(snapshot)
	snapshot = SpaceManager.ensure(snapshot)
	snapshot = TradePolicyManager.ensure(snapshot)
	snapshot = BankingManager.ensure(snapshot)
	snapshot = FdiManager.ensure(snapshot)
	snapshot = AmbassadorManager.ensure(snapshot)
	snapshot = DigitalManager.ensure(snapshot)
	snapshot = SportsManager.ensure(snapshot)
	snapshot = DilemmaManager.ensure(snapshot)
	snapshot = StockMarketManager.ensure(snapshot)
	snapshot = VeteransManager.ensure(snapshot)
	snapshot = HeritageManager.ensure(snapshot)
	snapshot = TransportManager.ensure(snapshot)
	snapshot = RetailManager.ensure(snapshot)
	snapshot = EthnicityManager.ensure(snapshot)
	snapshot = WaterManager.ensure(snapshot)
	snapshot = ResearchManager.ensure(snapshot)
	snapshot = CivicManager.ensure(snapshot)
	snapshot = DiasporaManager.ensure(snapshot)
	snapshot = CivilDefenseManager.ensure(snapshot)
	snapshot = BlueEconomyManager.ensure(snapshot)
	snapshot = CreativeManager.ensure(snapshot)
	snapshot = DemographicManager.ensure(snapshot)
	snapshot = WatershedManager.ensure(snapshot)
	snapshot = PrisonManager.ensure(snapshot)
	snapshot = StatisticsManager.ensure(snapshot)
	snapshot = MiningManager.ensure(snapshot)
	snapshot = WasteManager.ensure(snapshot)
	snapshot = InsuranceManager.ensure(snapshot)
	snapshot = RuralManager.ensure(snapshot)
	snapshot = JudicialReformManager.ensure(snapshot)
	snapshot = ElectionManager.ensure(snapshot)
	snapshot = FuelTransitionManager.ensure(snapshot)
	snapshot = HousingManager.ensure(snapshot)
	snapshot = StartupManager.ensure(snapshot)
	snapshot = SmeManager.ensure(snapshot)
	snapshot = SupplyChainManager.ensure(snapshot)
	snapshot = CareEconomyManager.ensure(snapshot)
	snapshot = ScienceDiplomacyManager.ensure(snapshot)
	snapshot = DownstreamEnergyManager.ensure(snapshot)
	snapshot = HigherEducationManager.ensure(snapshot)
	snapshot = FoodValueChainManager.ensure(snapshot)
	snapshot = PharmaManager.ensure(snapshot)
	snapshot = IntellectualPropertyManager.ensure(snapshot)
	snapshot = TransitManager.ensure(snapshot)
	snapshot = DisasterManager.ensure(snapshot)
	snapshot = LivestockManager.ensure(snapshot)
	snapshot = TextileManager.ensure(snapshot)
	snapshot = BasicIndustryManager.ensure(snapshot)
	snapshot = NationBrandManager.ensure(snapshot)
	snapshot = AiIndustryManager.ensure(snapshot)
	snapshot = TechnologyManager.migrate_state(snapshot)
	var seasonal_result = SeasonalManager.simulate_month(snapshot, turn)
	snapshot = seasonal_result.state
	_collect_events(seasonal_result, "seasonal", snapshot, turn, generated_events, "seasonal_event")
	return {"state": snapshot, "events": generated_events}

# یک روز شبیه‌سازی: سیستم‌های روزانه + سیاست‌ها؛ رویدادها در generated_events جمع می‌شوند.
func _month_day(snapshot: Dictionary, turn: int, day: int, generated_events: Array) -> Dictionary:
	snapshot = TimeManager.set_simulation_day(snapshot, day)
	var simulation_day = TimeManager.get_total_days(snapshot) + 1
	var daily_result = _compute_daily_systems(snapshot, turn, simulation_day)
	if not daily_result.success:
		return daily_result
	snapshot = daily_result.state
	generated_events.append_array(daily_result.events)

	var policy_simulation = PolicyManager.simulate(snapshot, simulation_day)
	snapshot = policy_simulation.state
	for policy_event in policy_simulation.events:
		var wrapped_policy = {"system":"policies", "event":policy_event.duplicate(true), "simulation_day":simulation_day}
		generated_events.append(wrapped_policy)
		EventLog.log_event("policy_event", policy_event, turn, snapshot.get("version", 0))
	snapshot = TimeManager.finish_simulation_day(snapshot)
	return {"success": true, "state": snapshot, "events": generated_events}

# پایان ماه: مدیران ماهانه، شاخص‌ها، پیشرفت، سناریو، تحلیل و گزارش؛ سپس بررسی سلامت.
func _month_close(snapshot: Dictionary, turn: int, generated_events: Array) -> Dictionary:
	var military_result = MilitaryManager.simulate_month(snapshot, turn)
	snapshot = military_result.state
	_collect_events(military_result, "military_development", snapshot, turn, generated_events, "military_event")

	var national_result = NationalProjectManager.simulate_month(snapshot, turn)
	snapshot = national_result.state
	_collect_events(national_result, "national_projects", snapshot, turn, generated_events, "national_project_event")

	var cabinet_result = CabinetManager.simulate_month(snapshot, turn)
	snapshot = cabinet_result.state
	_collect_events(cabinet_result, "cabinet", snapshot, turn, generated_events, "cabinet_event")

	var law_result = LawManager.simulate_month(snapshot, turn)
	snapshot = law_result.state
	_collect_events(law_result, "legislation", snapshot, turn, generated_events, "law_event")

	var intelligence_result = IntelligenceOperationManager.simulate_month(snapshot, turn)
	snapshot = intelligence_result.state
	_collect_events(intelligence_result, "intelligence_operations", snapshot, turn, generated_events, "intelligence_operation_event")

	# موتور رویدادها و بحران‌ها (رودمپ ۴): ارزیابی ریسک‌های ماهانه، چرخه‌ی حیات بحران‌ها
	# و تولید رویدادهایی که DecisionManager خودکار به تصمیم چندگزینه‌ای فارسی تبدیل می‌کند.
	var crisis_result = EventCrisisManager.simulate_month(snapshot, turn)
	snapshot = crisis_result.state
	_collect_events(crisis_result, "crisis", snapshot, turn, generated_events, "crisis_event")

	# هوش سیاست خارجی کشورها (رودمپ ۵): موضع‌گیری ماهانه، پیشنهادهای ورودی و واکنش‌ها
	var foreign_result = ForeignAIManager.simulate_month(snapshot, turn)
	snapshot = foreign_result.state
	_collect_events(foreign_result, "foreign_policy", snapshot, turn, generated_events, "foreign_event")

	# تحریریه خبری: دسته‌بندی حساس/غیرحساس و انتشار اخبار ماهانه (حساس فقط کشور خود بازیکن)
	var news_result = NewsManager.simulate_month(snapshot, turn)
	snapshot = news_result.state
	_collect_events(news_result, "newsroom", snapshot, turn, generated_events, "news_event")

	# مأموریت‌های ماهانه + بازار جهانی منابع (World Empire style)
	var mission_result = MissionManager.simulate_month(snapshot, turn)
	snapshot = mission_result.state
	var market_result = MarketManager.simulate_month(snapshot, turn)
	snapshot = market_result.state

	snapshot = MapLayerManager.update_network_metrics(snapshot)

	# شاخص، پیشرفت، سناریو و تحلیل فقط یک‌بار در پایان نوبت ماهانه محاسبه می‌شوند.
	snapshot = _compute_indicators(snapshot)
	var progression_result = ProgressionManagerClass.update(snapshot, turn)
	snapshot = progression_result.state
	for achievement in progression_result.unlocked:
		EventLog.log_event("achievement_unlocked", {
			"message": "دستاورد «%s» باز شد" % achievement.get("title", ""),
			"achievement": achievement
		}, turn, snapshot.get("version", 0))

	var scenario_result = ScenarioManager.update(snapshot, turn)
	snapshot = scenario_result.state
	_collect_events(scenario_result, "scenario", snapshot, turn, generated_events, "scenario_event")

	# رویدادهای ویژه فصلی (بازار نفت، موج فناوری و...) — دترمینستیک از seed
	var special_result = SpecialEventManager.simulate_month(snapshot, turn)
	snapshot = special_result.state

	# لحظه‌های هیجان‌انگیز: تشخیص دستاورد/مرحله/رکورد برای جشن UI
	# (بعد از به‌روزرسانی progression تا دستاوردها/مرحله دیده شوند؛
	# از طریق events تا دترمینیسم state حفظ شود)
	var celebrations: Array = CelebrationManager.detect_celebrations(snapshot)
	for celebration in celebrations:
		generated_events.append({"type": "celebration", "celebration": celebration})

	# فرماندهان ارتش: تجربه و ارتقا از نبردهای این ماه
	var generals_result = GeneralsManager.simulate_month(snapshot, turn)
	snapshot = generals_result.state
	_collect_events(generals_result, "generals", snapshot, turn, generated_events, "military_event")
	# رسانه و افکار عمومی: رضایت گروه‌ها، کمپین‌ها و اثر بر جامعه
	var media_result = MediaManager.simulate_month(snapshot, turn)
	snapshot = media_result.state
	_collect_events(media_result, "media", snapshot, turn, generated_events, "media_event")
	# بازار جهانی کالا: قیمت‌ها، شوک‌ها و درآمد نفتی
	var commodity_result = CommodityManager.simulate_month(snapshot, turn)
	snapshot = commodity_result.state
	_collect_events(commodity_result, "commodities", snapshot, turn, generated_events, "trade_event")
	# بازار مالی جهانی (عمق‌بخشی ۱۱): شاخص سهام جهانی، دلار و ریسک جهانی
	var global_market_result = GlobalMarketManager.simulate_month(snapshot, turn)
	snapshot = global_market_result.state
	_collect_events(global_market_result, "global_market", snapshot, turn, generated_events, "global_market_event")
	# سازمان‌های بین‌المللی: عضویت، هزینه‌ها و قطعنامه‌ها
	var org_result = OrgManager.simulate_month(snapshot, turn)
	snapshot = org_result.state
	_collect_events(org_result, "intl_orgs", snapshot, turn, generated_events, "diplomacy_event")
	# مجلس و انتخابات: پشتیبانی، ماندات، برگزاری انتخابات دوره‌ای
	var parliament_result = ParliamentManager.simulate_month(snapshot, turn)
	snapshot = parliament_result.state
	_collect_events(parliament_result, "parliament", snapshot, turn, generated_events, "election_event")
	# سیاست ارزی: مداخلات، بازار سیاه و بحران ذخایر
	var forex_result = ForexManager.simulate_month(snapshot, turn)
	snapshot = forex_result.state
	_collect_events(forex_result, "forex", snapshot, turn, generated_events, "economic_event")
	# استانداران و سیاست استانی: رضایت، فساد و ناآرامی استان‌ها
	var governors_result = GovernorsManager.simulate_month(snapshot, turn)
	snapshot = governors_result.state
	_collect_events(governors_result, "governors", snapshot, turn, generated_events, "governor_event")
	# رقابت قدرت‌های بزرگ: تنش بلوکی، مسابقه تسلیحاتی و بحران‌های منطقه‌ای
	var rivalry_result = RivalryManager.simulate_month(snapshot, turn)
	snapshot = rivalry_result.state
	_collect_events(rivalry_result, "rivalry", snapshot, turn, generated_events, "diplomacy_event")
	# اقتصاد سایه و فساد: رشد سایه، رسوایی‌ها و اثر بر درآمد
	var shadow_result = ShadowManager.simulate_month(snapshot, turn)
	snapshot = shadow_result.state
	_collect_events(shadow_result, "shadow", snapshot, turn, generated_events, "corruption_event")
	# قوه قضائیه: استقلال، تراکم پرونده و پرونده‌های بزرگ
	var judiciary_result = JudiciaryManager.simulate_month(snapshot, turn)
	snapshot = judiciary_result.state
	_collect_events(judiciary_result, "judiciary", snapshot, turn, generated_events, "judiciary_event")
	# سیاست انرژی و اقلیم: سبد انرژی، امنیت، یارانه و خاموشی‌ها
	var energy_result = EnergyManager.simulate_month(snapshot, turn)
	snapshot = energy_result.state
	_collect_events(energy_result, "energy", snapshot, turn, generated_events, "energy_event")
	# سیاست صنعتی: راهبرد، شرکت‌های دولتی و مناطق آزاد
	var industry_result = IndustryManager.simulate_month(snapshot, turn)
	snapshot = industry_result.state
	_collect_events(industry_result, "industry", snapshot, turn, generated_events, "industry_event")
	# جانشینی رهبر: بحران‌ها و آماده‌سازی وارث
	var succession_result = SuccessionManager.simulate_month(snapshot, turn)
	snapshot = succession_result.state
	_collect_events(succession_result, "succession", snapshot, turn, generated_events, "succession_event")
	# اتحادیه‌های کارگری: دستمزد، اعتصاب و مذاکره
	var labor_result = LaborManager.simulate_month(snapshot, turn)
	snapshot = labor_result.state
	_collect_events(labor_result, "labor", snapshot, turn, generated_events, "labor_event")
	# بهداشت عمومی و پاندمی: شیوع، قرنطینه و واکسن
	var epidemic_result = EpidemicManager.simulate_month(snapshot, turn)
	snapshot = epidemic_result.state
	_collect_events(epidemic_result, "epidemic", snapshot, turn, generated_events, "health_event")
	# صنایع دفاعی: تولید، تحریم و صادرات تسلیحات
	var arms_result = ArmsManager.simulate_month(snapshot, turn)
	snapshot = arms_result.state
	_collect_events(arms_result, "arms", snapshot, turn, generated_events, "military_event")
	# جنگ سایبری: حملات دشمن و دفاع فایروال
	var cyber_result = CyberManager.simulate_month(snapshot, turn)
	snapshot = cyber_result.state
	_collect_events(cyber_result, "cyber", snapshot, turn, generated_events, "cyber_event")
	# سیاست مهاجرت: جریان جمعیت، پناهندگان و فرار مغزها
	var migration_result = MigrationManager.simulate_month(snapshot, turn)
	snapshot = migration_result.state
	_collect_events(migration_result, "migration", snapshot, turn, generated_events, "population_event")
	# فرهنگ و قدرت نرم: میراث، رویدادها و نفوذ جهانی
	var culture_result = CultureManager.simulate_month(snapshot, turn)
	snapshot = culture_result.state
	_collect_events(culture_result, "culture", snapshot, turn, generated_events, "culture_event")
	# سیاست آموزش: فنی، دانشگاه، بورس و دیجیتال
	var education_result = EducationManager.simulate_month(snapshot, turn)
	snapshot = education_result.state
	_collect_events(education_result, "education", snapshot, turn, generated_events, "education_event")
	# کشاورزی و امنیت غذایی: ذخیره غلات، کود و آبیاری
	var agriculture_result = AgricultureManager.simulate_month(snapshot, turn)
	snapshot = agriculture_result.state
	_collect_events(agriculture_result, "agriculture", snapshot, turn, generated_events, "agriculture_event")
	# گردشگری: ویزا، مهمان‌پذیری و جاذبه
	var tourism_result = TourismManager.simulate_month(snapshot, turn)
	snapshot = tourism_result.state
	_collect_events(tourism_result, "tourism", snapshot, turn, generated_events, "tourism_event")
	# شهرسازی: مسکن، حمل‌ونقل، شهر هوشمند
	var urban_result = UrbanManager.simulate_month(snapshot, turn)
	snapshot = urban_result.state
	_collect_events(urban_result, "urban", snapshot, turn, generated_events, "urban_event")
	# امنیت داخلی: جرم، پلیس و آزادی مدنی
	var security_result = SecurityManager.simulate_month(snapshot, turn)
	snapshot = security_result.state
	_collect_events(security_result, "security", snapshot, turn, generated_events, "security_event")
	# زیرساخت: نگهداری، پوسیدگی و اولویت توسعه
	var infra_result = InfrastructureManager.simulate_month(snapshot, turn)
	snapshot = infra_result.state
	_collect_events(infra_result, "infrastructure", snapshot, turn, generated_events, "infrastructure_event")
	# اقلیم و محیط زیست: آلودگی، بلایا و مالیات کربن
	var climate_result = ClimateManager.simulate_month(snapshot, turn)
	snapshot = climate_result.state
	_collect_events(climate_result, "climate", snapshot, turn, generated_events, "climate_event")
	# رفاه و تأمین اجتماعی: صندوق بازنشستگی و بیمه‌ها
	var welfare_result = WelfareManager.simulate_month(snapshot, turn)
	snapshot = welfare_result.state
	_collect_events(welfare_result, "welfare", snapshot, turn, generated_events, "welfare_event")
	# برنامه فضایی: آژانس، پرتاب‌ها و ماهواره‌ها
	var space_result = SpaceManager.simulate_month(snapshot, turn)
	snapshot = space_result.state
	_collect_events(space_result, "space", snapshot, turn, generated_events, "space_event")
	# تجارت راهبردی: تنوع صادرات و زنجیره تأمین
	var trade_policy_result = TradePolicyManager.simulate_month(snapshot, turn)
	snapshot = trade_policy_result.state
	_collect_events(trade_policy_result, "trade_policy", snapshot, turn, generated_events, "trade_event")
	# بانکداری و بازار سرمایه: ذخیره، سهام و بحران بانکی
	var banking_result = BankingManager.simulate_month(snapshot, turn)
	snapshot = banking_result.state
	_collect_events(banking_result, "banking", snapshot, turn, generated_events, "banking_event")
	# سرمایه‌گذاری خارجی: جذب و مناطق ویژه
	var fdi_result = FdiManager.simulate_month(snapshot, turn)
	snapshot = fdi_result.state
	_collect_events(fdi_result, "fdi", snapshot, turn, generated_events, "fdi_event")
	# سفیران و دیپلماسی: روابط دوجانبه
	var ambassador_result = AmbassadorManager.simulate_month(snapshot, turn)
	snapshot = ambassador_result.state
	_collect_events(ambassador_result, "diplomacy_policy", snapshot, turn, generated_events, "diplomacy_event")
	# اقتصاد دیجیتال: پوشش اینترنت و CBDC
	var digital_result = DigitalManager.simulate_month(snapshot, turn)
	snapshot = digital_result.state
	_collect_events(digital_result, "digital", snapshot, turn, generated_events, "digital_event")
	# ورزش و سلامت عمومی
	var sports_result = SportsManager.simulate_month(snapshot, turn)
	snapshot = sports_result.state
	_collect_events(sports_result, "sports", snapshot, turn, generated_events, "sports_event")
	# معضلات راهبردی: ظهور و انقضای انتخاب‌های دشوار
	var dilemma_result = DilemmaManager.simulate_month(snapshot, turn)
	snapshot = dilemma_result.state
	_collect_events(dilemma_result, "dilemmas", snapshot, turn, generated_events, "dilemma_event")
	# بورس اوراق بهادار: شاخص، حباب، سقوط و درآمد مالیات عایدی
	var stock_result = StockMarketManager.simulate_month(snapshot, turn)
	snapshot = stock_result.state
	_collect_events(stock_result, "stock_market", snapshot, turn, generated_events, "stock_event")
	# بنیاد ایثارگران: پویایی شمار، هزینه مستمری و رضایت کهنه‌سربازان
	var veterans_result = VeteransManager.simulate_month(snapshot, turn)
	snapshot = veterans_result.state
	_collect_events(veterans_result, "veterans", snapshot, turn, generated_events, "veterans_event")
	# میراث فرهنگی: فرسایش، بلایا و درآمد گردشگری تاریخی
	var heritage_result = HeritageManager.simulate_month(snapshot, turn)
	snapshot = heritage_result.state
	_collect_events(heritage_result, "heritage", snapshot, turn, generated_events, "heritage_event")
	# حمل‌ونقل عمومی: رضایت، هزینه یارانه، آلودگی و اعتصاب
	var transport_result = TransportManager.simulate_month(snapshot, turn)
	snapshot = transport_result.state
	_collect_events(transport_result, "transport", snapshot, turn, generated_events, "transport_event")
	# بازار مصرف: اعتماد مصرف‌کننده، سطح قیمت و اعتراضات گرانی
	var retail_result = RetailManager.simulate_month(snapshot, turn)
	snapshot = retail_result.state
	_collect_events(retail_result, "retail", snapshot, turn, generated_events, "retail_event")
	# همبستگی قومی: تنش هویتی، نمایندگی و بحران‌های قومی
	var ethnicity_result = EthnicityManager.simulate_month(snapshot, turn)
	snapshot = ethnicity_result.state
	_collect_events(ethnicity_result, "ethnicity", snapshot, turn, generated_events, "ethnicity_event")
	# امنیت آبی: سدها، نشت، آب‌شیرین‌کن، خشکسالی، فرونشست و امنیت غذایی
	var water_result = WaterManager.simulate_month(snapshot, turn)
	snapshot = water_result.state
	_collect_events(water_result, "water", snapshot, turn, generated_events, "water_event")
	# پژوهش ملی: دانشگاه، مراکز تحقیق، اختراع، فرار مغزها و بهره‌وری
	var research_result = ResearchManager.simulate_month(snapshot, turn)
	snapshot = research_result.state
	_collect_events(research_result, "research", snapshot, turn, generated_events, "research_event")
	# مشارکت مدنی: شفافیت، شوراها، سمن‌ها، سرمایه اجتماعی و اعتراض فروخورده
	var civic_result = CivicManager.simulate_month(snapshot, turn)
	snapshot = civic_result.state
	_collect_events(civic_result, "civic", snapshot, turn, generated_events, "civic_event")
	# دیاسپورا: حواله ارزی، لابی، شبکه نخبگان و قدرت نرم
	var diaspora_result = DiasporaManager.simulate_month(snapshot, turn)
	snapshot = diaspora_result.state
	_collect_events(diaspora_result, "diaspora", snapshot, turn, generated_events, "diaspora_event")
	# پدافند غیرعامل: سخت‌سازی هدف‌ها، افزونگی، پناهگاه و ذخیره راهبردی
	var civil_defense_result = CivilDefenseManager.simulate_month(snapshot, turn)
	snapshot = civil_defense_result.state
	_collect_events(civil_defense_result, "civil_defense", snapshot, turn, generated_events, "civil_defense_event")
	# اقتصاد دریایی: بندر، ناوگان تجاری، شیلات پایدار و گشت ساحلی
	var blue_economy_result = BlueEconomyManager.simulate_month(snapshot, turn)
	snapshot = blue_economy_result.state
	_collect_events(blue_economy_result, "blue_economy", snapshot, turn, generated_events, "blue_economy_event")
	# اقتصاد خلاق: سینما، موسیقی، بازی، صنایع فرهنگی و صادرات فرهنگی
	var creative_result = CreativeManager.simulate_month(snapshot, turn)
	snapshot = creative_result.state
	_collect_events(creative_result, "creative", snapshot, turn, generated_events, "creative_event")
	# تحول جمعیتی: پنجره جمعیت، سالخوردگی، صندوق بازنشستگی و باروری
	var demographic_result = DemographicManager.simulate_month(snapshot, turn)
	snapshot = demographic_result.state
	_collect_events(demographic_result, "demographic", snapshot, turn, generated_events, "demographic_event")
	# آبخیزداری: فرسایش، بیابان‌زایی، ریزگرد، تا‌لاب‌ها و امنیت خاک
	var watershed_result = WatershedManager.simulate_month(snapshot, turn)
	snapshot = watershed_result.state
	_collect_events(watershed_result, "watershed", snapshot, turn, generated_events, "watershed_event")
	# زندان: ازدحام، بازاجتماعی‌سازی، عفو، خشونت و بازگشت به جرم
	var prison_result = PrisonManager.simulate_month(snapshot, turn)
	snapshot = prison_result.state
	_collect_events(prison_result, "prison", snapshot, turn, generated_events, "prison_event")
	# آمار ملی: دقت داده، استقلال مرکز آمار، داده باز و خطای سیاست‌گذاری
	var stats_result = StatisticsManager.simulate_month(snapshot, turn)
	snapshot = stats_result.state
	_collect_events(stats_result, "statistics", snapshot, turn, generated_events, "statistics_event")
	# معدن: اکتشاف، فرآوری، ایمنی، خام‌فروشی و آلودگی معادن
	var mining_result = MiningManager.simulate_month(snapshot, turn)
	snapshot = mining_result.state
	_collect_events(mining_result, "mining", snapshot, turn, generated_events, "mining_event")
	# پسماند: جمع‌آوری، بازیافت، دفن بهداشتی و اقتصاد چرخه‌ای
	var waste_result = WasteManager.simulate_month(snapshot, turn)
	snapshot = waste_result.state
	_collect_events(waste_result, "waste", snapshot, turn, generated_events, "waste_event")
	# بیمه: نفوذ، توانگری، بیمه درمان/کشاورزی/سپرده و جذب خسارت بحران
	var insurance_result = InsuranceManager.simulate_month(snapshot, turn)
	snapshot = insurance_result.state
	_collect_events(insurance_result, "insurance", snapshot, turn, generated_events, "insurance_event")
	# روستایی: راه، اینترنت، صنایع تبدیلی، عشایر و جلوگیری از مهاجرت بی‌رویه
	var rural_result = RuralManager.simulate_month(snapshot, turn)
	snapshot = rural_result.state
	_collect_events(rural_result, "rural", snapshot, turn, generated_events, "rural_event")
	# اصلاح قضایی: دیجیتال، تخصصی، میانجی‌گری و اطاله دادرسی
	var jr_result = JudicialReformManager.simulate_month(snapshot, turn)
	snapshot = jr_result.state
	_collect_events(jr_result, "judicial_reform", snapshot, turn, generated_events, "judicial_reform_event")
	# انتخابات: مشروعیت، مشارکت، نظارت، تکثر و فشار مخالفان
	var el_result = ElectionManager.simulate_month(snapshot, turn)
	snapshot = el_result.state
	_collect_events(el_result, "election", snapshot, turn, generated_events, "election_event")
	# سوخت و گذار انرژی: یارانه، ایستگاه شارژ، استاندارد و ناوگان برقی
	var fuel_result = FuelTransitionManager.simulate_month(snapshot, turn)
	snapshot = fuel_result.state
	_collect_events(fuel_result, "fuel", snapshot, turn, generated_events, "fuel_event")
	var housing_result = HousingManager.simulate_month(snapshot, turn)
	snapshot = housing_result.state
	_collect_events(housing_result, "housing", snapshot, turn, generated_events, "housing_event")
	var startup_result = StartupManager.simulate_month(snapshot, turn)
	snapshot = startup_result.state
	_collect_events(startup_result, "startup", snapshot, turn, generated_events, "startup_event")
	var sme_result = SmeManager.simulate_month(snapshot, turn)
	snapshot = sme_result.state
	_collect_events(sme_result, "sme", snapshot, turn, generated_events, "sme_event")
	var supply_result = SupplyChainManager.simulate_month(snapshot, turn)
	snapshot = supply_result.state
	_collect_events(supply_result, "supply", snapshot, turn, generated_events, "supply_event")
	var care_result = CareEconomyManager.simulate_month(snapshot, turn)
	snapshot = care_result.state
	_collect_events(care_result, "care", snapshot, turn, generated_events, "care_event")
	var science_result = ScienceDiplomacyManager.simulate_month(snapshot, turn)
	snapshot = science_result.state
	_collect_events(science_result, "science", snapshot, turn, generated_events, "science_event")
	var downstream_result = DownstreamEnergyManager.simulate_month(snapshot, turn)
	snapshot = downstream_result.state
	_collect_events(downstream_result, "downstream", snapshot, turn, generated_events, "downstream_event")
	var higher_ed_result = HigherEducationManager.simulate_month(snapshot, turn)
	snapshot = higher_ed_result.state
	_collect_events(higher_ed_result, "higher_ed", snapshot, turn, generated_events, "higher_ed_event")
	var food_chain_result = FoodValueChainManager.simulate_month(snapshot, turn)
	snapshot = food_chain_result.state
	_collect_events(food_chain_result, "food_chain", snapshot, turn, generated_events, "food_chain_event")
	var pharma_result = PharmaManager.simulate_month(snapshot, turn)
	snapshot = pharma_result.state
	_collect_events(pharma_result, "pharma", snapshot, turn, generated_events, "pharma_event")
	var ip_result = IntellectualPropertyManager.simulate_month(snapshot, turn)
	snapshot = ip_result.state
	_collect_events(ip_result, "ip", snapshot, turn, generated_events, "ip_event")
	var transit_result = TransitManager.simulate_month(snapshot, turn)
	snapshot = transit_result.state
	_collect_events(transit_result, "transit", snapshot, turn, generated_events, "transit_event")
	var disaster_result = DisasterManager.simulate_month(snapshot, turn)
	snapshot = disaster_result.state
	_collect_events(disaster_result, "disaster", snapshot, turn, generated_events, "disaster_event")
	var livestock_result = LivestockManager.simulate_month(snapshot, turn)
	snapshot = livestock_result.state
	_collect_events(livestock_result, "livestock", snapshot, turn, generated_events, "livestock_event")
	var textile_result = TextileManager.simulate_month(snapshot, turn)
	snapshot = textile_result.state
	_collect_events(textile_result, "textile", snapshot, turn, generated_events, "textile_event")
	var basic_industry_result = BasicIndustryManager.simulate_month(snapshot, turn)
	snapshot = basic_industry_result.state
	_collect_events(basic_industry_result, "basic_industry", snapshot, turn, generated_events, "basic_industry_event")
	var nation_brand_result = NationBrandManager.simulate_month(snapshot, turn)
	snapshot = nation_brand_result.state
	_collect_events(nation_brand_result, "nation_brand", snapshot, turn, generated_events, "nation_brand_event")
	var ai_result = AiIndustryManager.simulate_month(snapshot, turn)
	snapshot = ai_result.state
	_collect_events(ai_result, "ai", snapshot, turn, generated_events, "ai_event")
	var tax_result = TaxManager.simulate_month(snapshot, turn)
	snapshot = tax_result.state
	_collect_events(tax_result, "tax", snapshot, turn, generated_events, "tax_event")
	var ev_result = EvIndustryManager.simulate_month(snapshot, turn)
	snapshot = ev_result.state
	_collect_events(ev_result, "ev_industry", snapshot, turn, generated_events, "ev_industry_event")
	var health_tourism_result = HealthTourismManager.simulate_month(snapshot, turn)
	snapshot = health_tourism_result.state
	_collect_events(health_tourism_result, "health_tourism", snapshot, turn, generated_events, "health_tourism_event")
	var defense_industry_result = DefenseIndustryManager.simulate_month(snapshot, turn)
	snapshot = defense_industry_result.state
	_collect_events(defense_industry_result, "defense_industry", snapshot, turn, generated_events, "defense_industry_event")
	var knowledge_economy_result = KnowledgeEconomyManager.simulate_month(snapshot, turn)
	snapshot = knowledge_economy_result.state
	_collect_events(knowledge_economy_result, "knowledge_economy", snapshot, turn, generated_events, "knowledge_economy_event")
	var waste_mgmt_result = WasteManagementManager.simulate_month(snapshot, turn)
	snapshot = waste_mgmt_result.state
	_collect_events(waste_mgmt_result, "waste_mgmt", snapshot, turn, generated_events, "waste_mgmt_event")
	var aerospace_result = AerospaceManager.simulate_month(snapshot, turn)
	snapshot = aerospace_result.state
	_collect_events(aerospace_result, "aerospace", snapshot, turn, generated_events, "aerospace_event")
	var petrochemical_result = PetrochemicalManager.simulate_month(snapshot, turn)
	snapshot = petrochemical_result.state
	_collect_events(petrochemical_result, "petrochemical", snapshot, turn, generated_events, "petrochemical_event")
	var pro_sports_result = ProSportsManager.simulate_month(snapshot, turn)
	snapshot = pro_sports_result.state
	_collect_events(pro_sports_result, "pro_sports", snapshot, turn, generated_events, "pro_sports_event")
	var mega_event_result = MegaEventManager.simulate_month(snapshot, turn)
	snapshot = mega_event_result.state
	_collect_events(mega_event_result, "mega_event", snapshot, turn, generated_events, "mega_event")
	var aviation_result = AviationManager.simulate_month(snapshot, turn)
	snapshot = aviation_result.state
	_collect_events(aviation_result, "aviation", snapshot, turn, generated_events, "aviation_event")
	var postal_result = PostalManager.simulate_month(snapshot, turn)
	snapshot = postal_result.state
	_collect_events(postal_result, "postal", snapshot, turn, generated_events, "postal_event")
	var standards_result = StandardsManager.simulate_month(snapshot, turn)
	snapshot = standards_result.state
	_collect_events(standards_result, "standards", snapshot, turn, generated_events, "standards_event")
	# فراکسیون‌های سیاسی: جابه‌جایی وفاداری/نفوذ، بحران‌ها و اثر نفوذ بر کشور
	var faction_result = FactionManager.simulate_month(snapshot, turn)
	snapshot = faction_result.state
	_collect_events(faction_result, "factions", snapshot, turn, generated_events, "faction_event")
	# رهبر: محبوبیت جهانی، شورش‌ها، پیشروی/حل کودتا و تلاش دشمنان برای ترور
	var leader_result = LeaderManager.simulate_month(snapshot, turn)
	snapshot = leader_result.state
	_collect_events(leader_result, "leadership", snapshot, turn, generated_events, "leadership_event")
	var npc_assassination = LeaderManager.npc_assassination_attempt(snapshot, turn)
	snapshot = npc_assassination.state
	_collect_events(npc_assassination, "leadership", snapshot, turn, generated_events, "leadership_event")
	# پیروزی: سه شاخه اصلی در سطح ۳۰ → عصر طلایی
	var victory_result = TechnologyManager.check_victory(snapshot, turn)
	snapshot = victory_result.state
	if victory_result.achieved:
		generated_events.append({"type": "victory", "message": "🏆 سه شاخه فناوری به سطح ۳۰ رسید؛ کشور وارد عصر طلایی شد!"})
		EventLog.log_event("victory", {"message": "عصر طلایی — سه شاخه فناوری در سطح ۳۰"}, turn, snapshot.get("version", 0))
	snapshot = AnalyticsManager.update(snapshot, turn)
	snapshot = ReportManager.build(snapshot, generated_events, turn)
	EventLog.log_event("monthly_summary", {
		"message": ReportManager.summary_message(snapshot["monthly_report"]),
		"report": snapshot["monthly_report"].duplicate(true)
	}, turn, snapshot.get("version", 0))
	snapshot = TimeManager.finish_turn(snapshot)

	var integrity = _check_integrity(snapshot)
	if not integrity.valid:
		return {"success": false, "reason": integrity.reason, "state": snapshot}
	return {"success": true, "state": snapshot, "events": generated_events}

# ثبت یکسان رویدادهای مدیران ماهانه در گزارش و EventLog (قبلاً در چهار نقطه تکرار می‌شد).
func _collect_events(block: Dictionary, system_name: String, snapshot: Dictionary, turn: int, generated_events: Array, log_type: String):
	for evt in block.get("events", []):
		var wrapped = {"system": system_name, "event": evt.duplicate(true), "simulation_day": TimeManager.get_total_days(snapshot)}
		generated_events.append(wrapped)
		EventLog.log_event(log_type, evt, turn, snapshot.get("version", 0))

# شارژ هزینه اقدام عمرانی روی بدهی ملی (فقط پس از موفقیت اقدام فراخوانده می‌شود)
func _charge_action_cost(snapshot: Dictionary, cmd_type: String, action: String) -> Dictionary:
	var share: float = float(ACTION_COST_SHARES.get(cmd_type, {}).get(action, 0.0))
	if share <= 0.0:
		return snapshot
	var econ: Dictionary = snapshot.get("economy", {})
	if econ.is_empty():
		return snapshot
	var gdp: float = float(econ.get("gdp", 0.0))
	if gdp <= 0.0:
		return snapshot
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + gdp * share
	snapshot["economy"] = econ
	return snapshot

func _compute_daily_systems(snapshot: Dictionary, turn: int, simulation_day: int) -> Dictionary:
	var generated_events: Array = []
	# بهینه‌سازی حرفه‌ای: فقط سیستم‌های حیاتی روزانه، هفتگی هر ۷ روز، ماهانه روز ۱ و ۱۵
	var day_of_month = simulation_day % 30
	if day_of_month == 0:
		day_of_month = 30

	for sys_name in system_order:
		if not systems.has(sys_name):
			continue
		# طبقه‌بندی بهینه‌سازی
		if MONTHLY_SYSTEMS.has(sys_name):
			# ماهانه: فقط روز ۱ و ۱۵
			if day_of_month != 1 and day_of_month != 15:
				continue
		elif WEEKLY_SYSTEMS.has(sys_name):
			# هفتگی: هر ۷ روز (۱,۸,۱۵,۲۲,۲۹)
			if day_of_month % 7 != 1:
				continue
		# DAILY_SYSTEMS: هر روز - بدون شرط

		var sys = systems[sys_name]
		var result = sys.compute(snapshot, simulation_day)
		if not result.success:
			return {"success": false, "reason": "خطا در سیستم %s در روز %d: %s" % [sys_name, simulation_day, result.reason], "state": snapshot, "events": generated_events}
		snapshot = result.state
		if result.has("events"):
			for e in result.events:
				var wrapped = {"system":sys_name, "event":e.duplicate(true), "simulation_day":simulation_day}
				generated_events.append(wrapped)
				EventLog.log_event("system_event", wrapped, turn, snapshot.get("version", 0))
	return {"success": true, "state": snapshot, "events": generated_events}

func _compute_indicators(state: Dictionary) -> Dictionary:
	# HDI، قدرت، خوشبختی و...
	var happiness = 0.0
	happiness += state["population"]["happiness"] * 0.3
	happiness += state["economy"].get("growth_rate", 0.02) * 5.0
	happiness += state["politics"]["stability"] * 0.2
	happiness += state["health"]["quality"] * 0.2
	happiness += state["education"]["quality"] * 0.1
	state["indicators"]["happiness"] = clamp(happiness, 0.0, 1.0)

	var stability = 0.0
	stability += state["politics"]["stability"] * 0.4
	stability += state["population"]["satisfaction"] * 0.3
	stability += (1.0 - state["politics"]["tension"]) * 0.3
	state["indicators"]["stability"] = clamp(stability, 0.0, 1.0)

	var power = 0.0
	power += state["military"]["power"] * 0.3
	power += (state["economy"]["gdp"] / 1_000_000_000_000.0) * 20.0  # GDP تریلیون
	power += state["technology"]["branches"]["نظامی"] * 30.0
	power += state["diplomacy"]["influence"] * 0.2
	state["indicators"]["power_score"] = clamp(power, 0.0, 100.0)

	# امتیاز کل
	var score = 0.0
	score += state["indicators"]["happiness"] * 30
	score += state["indicators"]["stability"] * 20
	score += state["indicators"]["power_score"] * 0.5
	score += state["economy"]["gdp_per_capita"] / 1000.0
	state["score"] = score

	return state

func _check_integrity(state: Dictionary) -> Dictionary:
	# کل ساختار حیاتی و تمام اعداد بررسی می‌شوند؛ NaN/Inf در JSON و Lockstep خطرناک‌اند.
	for key in ["economy", "population", "politics", "resources", "indicators", "clock"]:
		if not state.has(key) or not state[key] is Dictionary:
			return {"valid": false, "reason": "بخش حیاتی وضعیت گم شده یا نامعتبر است: %s" % key}
	var invalid_path = _find_non_finite(state, "state")
	if invalid_path != "":
		return {"valid": false, "reason": "عدد نامتناهی یا تعریف‌نشده در %s" % invalid_path}
	if float(state["economy"].get("gdp", -1.0)) < 0.0:
		return {"valid": false, "reason": "GDP منفی شد"}
	if float(state["population"].get("total", 0.0)) <= 0.0:
		return {"valid": false, "reason": "جمعیت صفر یا منفی"}
	var tax_rate = float(state["economy"].get("tax_rate", -1.0))
	if tax_rate < 0.0 or tax_rate > 1.0:
		return {"valid": false, "reason": "نرخ مالیات نامعتبر"}
	for res in state["resources"].get("inventory", {}).keys():
		if float(state["resources"]["inventory"][res]) < 0.0:
			return {"valid": false, "reason": "موجودی منفی برای منبع %s" % str(res)}
	return {"valid": true, "reason": ""}

func _find_non_finite(value, path: String) -> String:
	if value is float and (is_nan(value) or is_inf(value)):
		return path
	if value is Dictionary:
		for key in value.keys():
			var found = _find_non_finite(value[key], "%s.%s" % [path, str(key)])
			if found != "":
				return found
	elif value is Array:
		for i in range(value.size()):
			var found = _find_non_finite(value[i], "%s[%d]" % [path, i])
			if found != "":
				return found
	return ""
