extends Node
# موتور شبیه‌سازی اتمی - بخش ۳.۶ و ۳.۷ - مهم‌ترین اصل معماری

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
	"retail",         # 3.45 بعدی
	"fuel_stations",  # 3.46
	"urban_facilities"# 3.47
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
	if ResourceLoader.exists("res://scripts/systems/financial_services_system.gd"):
		systems["financial_services"] = load("res://scripts/systems/financial_services_system.gd").new()
	if ResourceLoader.exists("res://scripts/systems/urban_facilities_system.gd"):
		systems["urban_facilities"] = load("res://scripts/systems/urban_facilities_system.gd").new()

	if ResourceLoader.exists("res://scripts/systems/hospitality_system.gd"):
		systems["hospitality"] = load("res://scripts/systems/hospitality_system.gd").new()

# تابع اصلی تیک - اجرای اتمی
func tick(current_state: Dictionary, current_version: int, current_tick: int, commands: Array) -> Dictionary:
	# ۱. اعتبارسنجی ورودی‌ها
	var validation = _validate_commands(commands, current_state)
	if not validation.valid:
		EventLog.log_event("tick_failed_validation", {"reason": validation.reason}, current_tick, current_version)
		emit_signal("tick_failed", validation.reason)
		return {"success": false, "reason": validation.reason, "state": current_state, "version": current_version, "tick": current_tick}

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

	# ۳. اجرای همه معادلات و هوش سیستم‌ها به‌صورت اتمی
	var compute_result = _compute_all_systems(snapshot, snapshot_tick)
	if not compute_result.success:
		# ۴. Rollback - هیچ تغییری اعمال نمی‌شود
		EventLog.log_event("tick_rollback", {"reason": compute_result.reason, "tick": snapshot_tick}, current_tick, current_version)
		emit_signal("tick_failed", compute_result.reason)
		return {"success": false, "reason": compute_result.reason, "state": current_state, "version": current_version, "tick": current_tick}

	snapshot = compute_result.state

	# ۵. Commit - اعمال اتمی نتیجه
	snapshot["version"] = snapshot_version + 1
	snapshot["tick"] = snapshot_tick
	snapshot["seed"] = Deterministic.get_state()

	# لاگ رویداد موفق
	EventLog.log_event("tick_success", {
		"tick": snapshot_tick,
		"version": snapshot["version"],
		"commands_count": commands.size(),
		"gdp_change": snapshot["economy"]["gdp"] - current_state["economy"]["gdp"] if current_state.has("economy") else 0
	}, snapshot_tick, snapshot["version"])

	emit_signal("tick_completed", snapshot, EventLog.get_last(5))

	return {
		"success": true,
		"state": snapshot,
		"version": snapshot["version"],
		"tick": snapshot_tick
	}

func _validate_commands(commands: Array, state: Dictionary) -> Dictionary:
	# هر فرمان باید معتبر باشد
	for cmd in commands:
		if cmd is GameCommand:
			if cmd.type == "tax_set":
				var rate = cmd.payload.get("rate", 0.2)
				if rate < 0.0 or rate > 0.9:
					return {"valid": false, "reason": "نرخ مالیات نامعتبر: %f" % rate}
			elif cmd.type == "budget_allocate":
				var allocs = cmd.payload.get("allocations", {})
				var total = 0.0
				for v in allocs.values():
					total += v
				if abs(total - 1.0) > 0.01:
					return {"valid": false, "reason": "مجموع بودجه باید ۱۰۰٪ باشد، الان %.1f٪ است" % (total*100)}
	# همه معتبر
	return {"valid": true, "reason": ""}

func _apply_command_to_snapshot(snapshot: Dictionary, cmd):
	if cmd is GameCommand:
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
		# لاگ فرمان
		EventLog.log_event("command_applied", cmd.to_dict(), snapshot.get("tick", 0), snapshot.get("version", 0))

func _compute_all_systems(snapshot: Dictionary, tick: int) -> Dictionary:
	# ترتیب دترمینستیک بسیار مهم است برای عدم Desync در چندنفره
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
					EventLog.log_event("system_event", {"system": sys_name, "event": e}, tick, snapshot.get("version", 0))

	# محاسبه شاخص‌های کلان در انتها
	snapshot = _compute_indicators(snapshot)

	# بررسی ثبات کلی - هیچ عدد منفی غیرمجاز
	var integrity = _check_integrity(snapshot)
	if not integrity.valid:
		return {"success": false, "reason": integrity.reason, "state": snapshot}

	return {"success": true, "state": snapshot}

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

	# XP و سطح
	state["xp"] += score * 0.01
	state["level"] = int(state["xp"] / 100.0) + 1

	return state

func _check_integrity(state: Dictionary) -> Dictionary:
	# بررسی ناسازگاری‌ها
	if state["economy"]["gdp"] < 0:
		return {"valid": false, "reason": "GDP منفی شد"}
	if state["population"]["total"] <= 0:
		return {"valid": false, "reason": "جمعیت صفر یا منفی"}
	if state["economy"]["tax_rate"] < 0 or state["economy"]["tax_rate"] > 1:
		return {"valid": false, "reason": "نرخ مالیات نامعتبر"}
	for res in state["resources"]["inventory"].keys():
		if state["resources"]["inventory"][res] < 0:
			# موجودی منفی نباید باشد - بحران است اما 0 می‌شود
			state["resources"]["inventory"][res] = 0
	# همه چک‌ها پاس شد
	return {"valid": true, "reason": ""}
