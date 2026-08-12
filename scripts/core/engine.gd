extends Node
# موتور شبیه‌سازی اتمی - بخش ۳.۶ و ۳.۷ - مهم‌ترین اصل معماری

# preload مستقیم - بدون وابستگی به کش کلاس سراسری (سازگار با import سرد و CI)
const GameCommandClass = preload("res://scripts/core/command.gd")
const VersioningClass = preload("res://scripts/core/versioning.gd")
const DecisionManagerClass = preload("res://scripts/core/decision_manager.gd")
const ProgressionManagerClass = preload("res://scripts/core/progression_manager.gd")

const SUPPORTED_COMMANDS = [
	"next_tick", "tax_set", "budget_allocate", "monetary_policy", "tariff_set", "research_start", "diplomacy",
	"country_select", "policy_change", "municipal_action", "military_program", "military_doctrine", "national_project", "cabinet_change", "law_change", "intelligence_operation", "decision_resolve",
	"trade_route_attack", "chokepoint_action", "map_operation", "battle_plan", "construction", "map_building"
]
const MAX_COMMAND_RECEIPTS = 512

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

	return {
		"success": true,
		"state": snapshot,
		"version": snapshot["version"],
		"tick": snapshot_tick
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

		var receipt_key = VersioningClass.make_idempotent_key(cmd.type, cmd.tick, cmd.player_id)
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
			receipts.append(VersioningClass.make_idempotent_key(cmd.type, cmd.tick, cmd.player_id))
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
	if cmd.type == "budget_allocate":
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
	elif cmd.type == "research_start":
		var tech_id = cmd.payload.get("tech_id", "")
		snapshot["technology"]["in_progress"] = tech_id
	elif cmd.type == "diplomacy":
		var world_result = WorldManager.apply_action(
			snapshot, str(cmd.payload.get("target", "")), str(cmd.payload.get("action", "")), cmd.tick)
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
		var cabinet_result = CabinetManager.appoint(snapshot, ministry_id, str(cmd.payload.get("candidate_id", "")), cmd.tick) if str(cmd.payload.get("action", "appoint")) == "appoint" else CabinetManager.dismiss(snapshot, ministry_id, cmd.tick)
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
