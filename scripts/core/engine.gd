extends Node
# موتور شبیه‌سازی اتمی - بخش ۳.۶ و ۳.۷ - مهم‌ترین اصل معماری

# preload مستقیم - بدون وابستگی به کش کلاس سراسری (سازگار با import سرد و CI)
const GameCommandClass = preload("res://scripts/core/command.gd")
const VersioningClass = preload("res://scripts/core/versioning.gd")
const DecisionManagerClass = preload("res://scripts/core/decision_manager.gd")
const ProgressionManagerClass = preload("res://scripts/core/progression_manager.gd")

const SUPPORTED_COMMANDS = [
	"next_tick", "tax_set", "budget_allocate", "research_start", "diplomacy", "decision_resolve"
]
const DIPLOMACY_ACTIONS = ["improve_relations", "negotiate_sanctions"]
const MAX_COMMAND_RECEIPTS = 512

signal tick_completed(new_state, events)
signal tick_failed(reason)

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
	"quantitative"       # 3.64 دقیق‌سازی کمّی و زمانی
]

# نام فصل‌ها بر اساس ماه
const SEASONS = {
	1: "بهار", 2: "بهار", 3: "بهار",
	4: "تابستان", 5: "تابستان", 6: "تابستان",
	7: "پاییز", 8: "پاییز", 9: "پاییز",
	10: "زمستان", 11: "زمستان", 12: "زمستان"
}

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
	systems["central_bank"] = load("res://scripts/systems/central_bank_system.gd").new()
	systems["trade"] = load("res://scripts/systems/trade_system.gd").new()
	systems["tourism"] = load("res://scripts/systems/tourism_system.gd").new()
	systems["stock_market"] = load("res://scripts/systems/stock_market_system.gd").new()
	systems["agriculture"] = load("res://scripts/systems/agriculture_system.gd").new()
	systems["industry"] = load("res://scripts/systems/industry_system.gd").new()
	# باقی سیستم‌ها در دسته‌های بعدی تکمیل می‌شوند - فعلا fallback
	_load_remaining_systems()
	print("موتور شبیه‌سازی با %d سیستم لود شد" % systems.size())

func _load_remaining_systems():
	var remaining = ["administration", "ethnicity", "statistics", "emergency", "sports_youth", "veterans", "family", "fisheries", "heritage", "space", "elections", "physical", "people"]
	for name in remaining:
		var path = "res://scripts/systems/%s_system.gd" % name
		if ResourceLoader.exists(path):
			systems[name] = load(path).new()
		else:
			# stub عمومی
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

# پیشروی ساعت بازی - هر تیک یک روز (ماه ۳۰ روز)
func _advance_clock(state: Dictionary) -> Dictionary:
	var clock = state.get("clock", {"year": 2027, "month": 1, "day": 1, "hour": 0, "season": "بهار"})
	var days_per_month = int(BalanceConfig.get_value("simulation.days_per_month", 30))
	var months_per_year = int(BalanceConfig.get_value("simulation.months_per_year", 12))
	clock["day"] = int(clock.get("day", 1)) + 1
	if clock["day"] > days_per_month:
		clock["day"] = 1
		clock["month"] = int(clock.get("month", 1)) + 1
		if clock["month"] > months_per_year:
			clock["month"] = 1
			clock["year"] = clock.get("year", 2027) + 1
	clock["season"] = SEASONS.get(clock["month"], "بهار")
	state["clock"] = clock
	return state

# تابع اصلی تیک - اجرای اتمی
func tick(current_state: Dictionary, current_version: int, current_tick: int, commands: Array) -> Dictionary:
	# ۱. تکمیل فراداده و اعتبارسنجی ورودی‌ها
	_prepare_command_metadata(commands, current_tick + 1, current_version + 1)
	var validation = _validate_commands(commands, current_state, current_tick + 1, current_version + 1)
	if not validation.valid:
		EventLog.log_event("tick_failed_validation", {"reason": validation.reason}, current_tick, current_version)
		emit_signal("tick_failed", validation.reason)
		return {"success": false, "reason": validation.reason, "state": current_state, "version": current_version, "tick": current_tick}

	# تمام رویدادهای محاسبه نیز بخشی از تراکنش‌اند؛ Rollback نباید رد کاذب باقی بگذارد.
	if not EventLog.begin_transaction():
		var tx_reason = "تراکنش رویداد دیگری هنوز باز است"
		emit_signal("tick_failed", tx_reason)
		return {"success": false, "reason": tx_reason, "state": current_state, "version": current_version, "tick": current_tick}

	# ۲. محاسبه روی Snapshot (کپی)
	var snapshot = current_state.duplicate(true)
	var snapshot_version = current_version
	var snapshot_tick = current_tick + 1
	
	# ست seed برای دترمینستیک بودن
	var seed_val = snapshot.get("seed", 12345) + snapshot_tick
	Deterministic.set_seed(seed_val)
	snapshot["seed"] = seed_val

	# اعمال فرمان‌ها روی snapshot
	for cmd in commands:
		_apply_command_to_snapshot(snapshot, cmd)

	# پیشروی ساعت - هر تیک یک روز
	snapshot = _advance_clock(snapshot)

	# ۳. اجرای همه معادلات و هوش سیستم‌ها به‌صورت اتمی
	var compute_result = _compute_all_systems(snapshot, snapshot_tick)
	if not compute_result.success:
		# ۴. Rollback - نه وضعیت و نه رویدادهای میانی اعمال نمی‌شوند.
		EventLog.rollback_transaction()
		EventLog.log_event("tick_rollback", {"reason": compute_result.reason, "tick": snapshot_tick}, current_tick, current_version)
		emit_signal("tick_failed", compute_result.reason)
		return {"success": false, "reason": compute_result.reason, "state": current_state, "version": current_version, "tick": current_tick}

	snapshot = compute_result.state
	# برخی رویدادها به تصمیم چندگزینه‌ای تبدیل می‌شوند؛ انقضا نیز پیامد پیش‌فرض دارد.
	snapshot = DecisionManagerClass.update_pending(snapshot, compute_result.get("events", []), snapshot_tick)

	# ۵. Commit - اعمال اتمی نتیجه
	snapshot["version"] = snapshot_version + 1
	snapshot["tick"] = snapshot_tick
	snapshot["seed"] = Deterministic.get_state()
	_record_command_receipts(snapshot, commands)

	# لاگ رویداد موفق و انتشار یک‌جای تمام رویدادهای تراکنش
	EventLog.log_event("tick_success", {
		"tick": snapshot_tick,
		"version": snapshot["version"],
		"commands_count": commands.size(),
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
			var tech_id = cmd.payload.get("tech_id", "")
			if not tech_id is String or tech_id.strip_edges().is_empty():
				return {"valid": false, "reason": "فناوری پژوهشی مشخص نشده است"}
		elif cmd.type == "diplomacy":
			var target = cmd.payload.get("target", "")
			var action = cmd.payload.get("action", "")
			if not state.get("diplomacy", {}).get("relations", {}).has(target):
				return {"valid": false, "reason": "کشور هدف در روابط دیپلماتیک وجود ندارد"}
			if not DIPLOMACY_ACTIONS.has(action):
				return {"valid": false, "reason": "اقدام دیپلماتیک شناخته‌شده نیست"}
		elif cmd.type == "decision_resolve":
			var decision_id = cmd.payload.get("decision_id", "")
			var choice_id = cmd.payload.get("choice_id", "")
			if not decision_id is String or not choice_id is String:
				return {"valid": false, "reason": "شناسه تصمیم یا گزینه نامعتبر است"}
			if not DecisionManagerClass.validate_choice(state, decision_id, choice_id):
				return {"valid": false, "reason": "تصمیم یا گزینه انتخابی دیگر معتبر نیست"}
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

func _apply_command_to_snapshot(snapshot: Dictionary, cmd):
	if not cmd is GameCommandClass:
		return
	if cmd.type == "budget_allocate":
		var allocs = cmd.payload.get("allocations", {})
		for k in allocs.keys():
			if snapshot["economy"]["budget_allocations"].has(k):
				snapshot["economy"]["budget_allocations"][k] = allocs[k]
	elif cmd.type == "tax_set":
		snapshot["economy"]["tax_rate"] = cmd.payload.get("rate", 0.2)
	elif cmd.type == "research_start":
		var tech_id = cmd.payload.get("tech_id", "")
		snapshot["technology"]["in_progress"] = tech_id
	elif cmd.type == "diplomacy":
		var target = cmd.payload.get("target", "")
		var action = cmd.payload.get("action", "")
		if snapshot["diplomacy"]["relations"].has(target):
			if action == "improve_relations":
				snapshot["diplomacy"]["relations"][target] = clamp(snapshot["diplomacy"]["relations"][target] + 5, -100, 100)
			elif action == "negotiate_sanctions" and snapshot["diplomacy"]["sanctions"].size() > 0:
				snapshot["diplomacy"]["sanctions"].pop_back()
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
	# تمام انواع فرمان در همان تراکنش و با فراداده نسخه مقصد ثبت می‌شوند.
	EventLog.log_event("command_applied", cmd.to_dict(), cmd.tick, cmd.version)

func _compute_all_systems(snapshot: Dictionary, tick: int) -> Dictionary:
	# ترتیب دترمینستیک بسیار مهم است برای عدم Desync در چندنفره
	var generated_events: Array = []
	for sys_name in system_order:
		if systems.has(sys_name):
			var sys = systems[sys_name]
			var result = sys.compute(snapshot, tick)
			if not result.success:
				return {"success": false, "reason": "خطا در سیستم %s: %s" % [sys_name, result.reason], "state": snapshot}
			snapshot = result.state
			# هر سیستم می‌تواند رویداد تولید کند
			if result.has("events"):
				for e in result.events:
					var wrapped = {"system": sys_name, "event": e.duplicate(true)}
					generated_events.append(wrapped)
					EventLog.log_event("system_event", wrapped, tick, snapshot.get("version", 0))

	# محاسبه شاخص‌های کلان و لایه پیشرفت در انتها
	snapshot = _compute_indicators(snapshot)
	var progression_result = ProgressionManagerClass.update(snapshot, tick)
	snapshot = progression_result.state
	for achievement in progression_result.unlocked:
		EventLog.log_event("achievement_unlocked", {
			"message": "دستاورد «%s» باز شد" % achievement.get("title", ""),
			"achievement": achievement
		}, tick, snapshot.get("version", 0))

	# بررسی ثبات کلی - هیچ عدد منفی غیرمجاز
	var integrity = _check_integrity(snapshot)
	if not integrity.valid:
		return {"success": false, "reason": integrity.reason, "state": snapshot}

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
