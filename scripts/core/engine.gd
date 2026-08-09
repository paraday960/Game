extends Node
# موتور شبیه‌سازی اتمی - بخش ۳.۶ و ۳.۷ - مهم‌ترین اصل معماری

signal tick_completed(new_state, events)
signal tick_failed(reason)

# ترتیب سیستم‌ها برای اجرای دترمینستیک
var system_order = [
	"resources",
	"economy",
	"population",
	"politics",
	"military",
	"diplomacy",
	"infrastructure",
	"technology",
	"health",
	"education",
	"welfare",
	"environment",
	"trade",
	"central_bank"
]

# سیستم‌های لود شده
var systems: Dictionary = {}

func _ready():
	# لود سیستم‌ها
	systems["resources"] = load("res://scripts/systems/resources_system.gd").new()
	systems["economy"] = load("res://scripts/systems/economy_system.gd").new()
	systems["population"] = load("res://scripts/systems/population_system.gd").new()
	systems["politics"] = load("res://scripts/systems/politics_system.gd").new()
	systems["military"] = load("res://scripts/systems/military_system.gd").new()
	systems["diplomacy"] = load("res://scripts/systems/diplomacy_system.gd").new()
	systems["infrastructure"] = load("res://scripts/systems/infrastructure_system.gd").new()
	systems["technology"] = load("res://scripts/systems/technology_system.gd").new()
	# برای سایر سیستم‌ها stub استفاده می‌کنیم - بعدا تکمیل
	print("موتور شبیه‌سازی با %d سیستم لود شد" % systems.size())

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
