extends Node
# موتور رویدادها و بحران‌ها - آیتم ۴ رودمپ
# هر نوبت ماهانه، ریسک‌های کشور را به‌صورت دترمینستیک ارزیابی می‌کند و بحران‌ها را با چرخه‌ی
# حیات کامل (فعال‌شدن ← اثر ماهانه ماندگار ← پایان و فرسایش ← دوره تامین مجدد) مدیریت می‌کند.
# بحران‌های فعال در events_active ذخیره می‌شوند (قبلاً این کلید تعریف شده ولی بلااستفاده بود).
# نوع رویدادها با قالب‌های DecisionManager سازگار است، پس هر بحران به‌صورت خودکار به یک
# تصمیم چندگزینه‌ای فارسی برای بازیکن تبدیل می‌شود و انقضای آن پیامد پیش‌فرض دارد.

const MAX_ACTIVE_CRISES = 4
const COOLDOWN_DAYS = 120

# تعریف داده‌محور بحران‌ها؛ ترتیب ثابت آرایه برای قطعی‌بودن ترتیب ارزیابی (و در نتیجه
# مصرف یکسان اعداد دترمینستیک در همه دستگاه‌ها) حیاتی است.
# trigger_mode: «all» همه شرط‌ها باید برقرار باشند، «any» برقراری هرکدام کافی است.
# chance: شانس ماهانه وقوع پس از برقرار بودن شرط‌ها (در هر نوبت یک‌بار).
# immediate_effects: اثر یک‌باره هنگام وقوع | persist_effects: اثر ماهانه در طول فعال‌بودن.
const CRISES = [
	{
		"type": "mass_protest",
		"title": "اعتراضات گسترده",
		"severity": 3,
		"trigger_mode": "any",
		"trigger": [
			{"path": "population.happiness", "op": "<", "value": 0.40},
			{"path": "politics.tension", "op": ">", "value": 0.55}
		],
		"chance": 0.35,
		"duration_days": 90,
		"persist_effects": [
			{"path": "politics.stability", "op": "add", "value": -0.01, "min": 0.0, "max": 1.0},
			{"path": "population.happiness", "op": "add", "value": -0.005, "min": 0.05, "max": 0.95}
		]
	},
	{
		"type": "debt_crisis",
		"title": "بحران بدهی دولت",
		"severity": 3,
		"trigger": [{"path": "economy.debt_to_gdp", "op": ">", "value": 1.3}],
		"chance": 0.40,
		"duration_days": 180,
		"persist_effects": [
			{"path": "economy.growth_rate", "op": "add", "value": -0.001, "min": -0.05, "max": 0.08},
			{"path": "stock_market.investor_confidence", "op": "add", "value": -0.01, "min": 0.0, "max": 1.0}
		]
	},
	{
		"type": "epidemic_outbreak",
		"title": "شیوع بیماری واگیردار",
		"severity": 3,
		"trigger": [{"path": "health.quality", "op": "<", "value": 0.45}],
		"chance": 0.25,
		"duration_days": 120,
		"persist_effects": [
			{"path": "health.quality", "op": "add", "value": -0.003, "min": 0.0, "max": 1.0},
			{"path": "population.happiness", "op": "add", "value": -0.004, "min": 0.05, "max": 0.95}
		]
	},
	{
		"type": "border_tension",
		"title": "تنش مرزی",
		"severity": 2,
		"trigger_mode": "any",
		"trigger": [
			{"path": "military.readiness", "op": "<", "value": 0.40},
			{"path": "diplomacy.influence", "op": "<", "value": 22.0}
		],
		"chance": 0.30,
		"duration_days": 90,
		"persist_effects": [
			{"path": "politics.tension", "op": "add", "value": 0.005, "min": 0.0, "max": 1.0},
			{"path": "military.readiness", "op": "add", "value": -0.002, "min": 0.1, "max": 1.0}
		]
	},
	{
		"type": "cyber_attack",
		"title": "حمله سایبری به زیرساخت‌ها",
		"severity": 2,
		"trigger": [{"path": "intelligence.cyber_readiness", "op": "<", "value": 0.45}],
		"chance": 0.20,
		"duration_days": 60,
		"persist_effects": [
			{"path": "statistics.digital", "op": "add", "value": -0.002, "min": 0.0, "max": 1.0},
			{"path": "administration.efficiency", "op": "add", "value": -0.002, "min": 0.0, "max": 1.0}
		]
	},
	{
		"type": "natural_disaster",
		"title": "بلای طبیعی بزرگ",
		"severity": 3,
		"trigger": [{"path": "emergency.preparedness", "op": "<", "value": 0.35}],
		"chance": 0.12,
		"duration_days": 45,
		"immediate_effects": [
			{"path": "infrastructure.quality", "op": "add", "value": -0.02, "min": 0.0, "max": 1.0},
			{"path": "economy.national_debt", "op": "add", "value": 3000000000.0, "min": 0.0}
		],
		"persist_effects": [
			{"path": "population.happiness", "op": "add", "value": -0.003, "min": 0.05, "max": 0.95}
		]
	},
	{
		"type": "trade_deficit_crisis",
		"title": "کسری شدید تجاری",
		"severity": 2,
		"trigger": [{"path": "trade.balance", "op": "<", "value": 0.0}],
		"chance": 0.30,
		"duration_days": 120,
		"persist_effects": [
			{"path": "central_bank.exchange_rate", "op": "mul", "value": 1.004, "min": 0.01},
			{"path": "stock_market.growth", "op": "add", "value": -0.001, "min": -0.5, "max": 0.5}
		]
	},
	{
		"type": "housing_crisis",
		"title": "بحران مسکن",
		"severity": 2,
		"trigger": [{"path": "physical.housing_shortage", "op": ">", "value": 0.20}],
		"chance": 0.30,
		"duration_days": 180,
		"persist_effects": [
			{"path": "population.happiness", "op": "add", "value": -0.003, "min": 0.05, "max": 0.95},
			{"path": "welfare.poverty", "op": "add", "value": 0.002, "min": 0.0, "max": 1.0}
		]
	},
	{
		"type": "brain_drain",
		"title": "موج مهاجرت نخبگان",
		"severity": 2,
		"trigger": [{"path": "elites_detail.brain_drain", "op": ">", "value": 0.25}],
		"chance": 0.25,
		"duration_days": 150,
		"persist_effects": [
			{"path": "technology.research_rate", "op": "add", "value": -0.05, "min": 0.0}
		]
	},
	{
		"type": "drought",
		"title": "خشکسالی گسترده",
		"severity": 2,
		"trigger_mode": "any",
		"trigger": [
			{"path": "resources.inventory.غذا", "op": "<", "value": 40.0},
			{"path": "agriculture.food_security", "op": "<", "value": 0.60}
		],
		"chance": 0.30,
		"duration_days": 120,
		"persist_effects": [
			{"path": "agriculture.food_security", "op": "add", "value": -0.004, "min": 0.0, "max": 1.0},
			{"path": "welfare.poverty", "op": "add", "value": 0.002, "min": 0.0, "max": 1.0}
		]
	}
]

# اعتبارسنجی ایستا: نوع هر بحران باید قالب تصمیم فارسی متناظر در DecisionManager داشته باشد.
func is_valid() -> bool:
	for definition in CRISES:
		if not DecisionManager.TEMPLATES.has(str(definition.get("type", ""))):
			return false
	return true

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state["events_active"] = state.get("events_active", [])
	state["crisis_cooldowns"] = state.get("crisis_cooldowns", {})
	var events: Array = []
	var current_day = TimeManager.get_total_days(state)

	# ۱) چرخه‌ی حیات بحران‌های فعال: اثر ماهانه، سپس پایان و ثبت دوره تامین مجدد
	var kept: Array = []
	for crisis in state["events_active"]:
		if str(crisis.get("status", "active")) != "active":
			continue
		if current_day >= int(crisis.get("expires_day", current_day + 1)):
			state["crisis_cooldowns"][str(crisis.get("type", ""))] = current_day + COOLDOWN_DAYS
			events.append({
				"type": "crisis_resolved",
				"title": str(crisis.get("title", "")),
				"severity": int(crisis.get("severity", 1)),
				"message": "بحران «%s» پایان یافت" % str(crisis.get("title", ""))
			})
			continue
		for effect in crisis.get("persist_effects", []):
			_apply_path_effect(state, effect)
		kept.append(crisis)

	# ۲) ارزیابی دترمینستیک ریسک‌های تازه به ترتیب ثابت تعریف
	var active_types: Dictionary = {}
	for crisis in kept:
		active_types[str(crisis.get("type", ""))] = true
	var active_count = kept.size()
	for definition in CRISES:
		if active_count >= MAX_ACTIVE_CRISES:
			break
		var crisis_type = str(definition["type"])
		if active_types.has(crisis_type):
			continue
		if float(state["crisis_cooldowns"].get(crisis_type, -1.0)) > current_day:
			continue
		if not _triggered(state, definition):
			continue
		if not Deterministic.chance(float(definition["chance"])):
			continue

		for effect in definition.get("immediate_effects", []):
			_apply_path_effect(state, effect)
		var entry = {
			"instance_id": "%s_%d" % [crisis_type, turn],
			"type": crisis_type,
			"title": str(definition["title"]),
			"severity": int(definition["severity"]),
			"status": "active",
			"started_tick": turn,
			"started_day": current_day,
			"expires_day": current_day + int(definition["duration_days"]),
			"persist_effects": definition.get("persist_effects", []).duplicate(true)
		}
		kept.append(entry)
		active_types[crisis_type] = true
		active_count += 1
		# نوع رویداد عمداً با قالب DecisionManager یکی است تا تصمیم چندگزینه‌ای ساخته شود.
		events.append({
			"type": crisis_type,
			"title": entry["title"],
			"severity": entry["severity"],
			"crisis": true,
			"message": "بحران «%s» آغاز شد؛ تصمیم فوری لازم است" % entry["title"]
		})

	state["events_active"] = kept
	return {"state": state, "events": events}

func _triggered(state: Dictionary, definition: Dictionary) -> bool:
	var mode = str(definition.get("trigger_mode", "all"))
	var conditions: Array = definition.get("trigger", [])
	if conditions.is_empty():
		return false
	for condition in conditions:
		var value = _read_path(state, str(condition.get("path", "")))
		if not (value is int or value is float):
			if mode == "all":
				return false
			continue
		var hit = float(value) > float(condition["value"]) if str(condition.get("op", ">")) == ">" else float(value) < float(condition["value"])
		if mode == "any" and hit:
			return true
		if mode == "all" and not hit:
			return false
	return mode == "all"

func _read_path(source: Dictionary, path: String):
	var current = source
	for part in path.split("."):
		if not current is Dictionary or not current.has(part):
			return null
		current = current[part]
	return current

# اعمال اثر عددی روی مسیر state با همان قرارداد DecisionManager (add/mul/set + min/max)
func _apply_path_effect(state: Dictionary, effect: Dictionary):
	var parts = str(effect.get("path", "")).split(".")
	var current = state
	for i in range(parts.size() - 1):
		if not current is Dictionary or not current.has(parts[i]):
			return
		current = current[parts[i]]
	var key = parts[-1]
	if not current is Dictionary or not current.has(key):
		return
	if not (current[key] is int or current[key] is float):
		return
	var new_value = float(current[key])
	match str(effect.get("op", "add")):
		"mul": new_value *= float(effect.get("value", 1.0))
		"set": new_value = float(effect.get("value", new_value))
		_: new_value += float(effect.get("value", 0.0))
	if effect.has("min"):
		new_value = max(new_value, float(effect["min"]))
	if effect.has("max"):
		new_value = min(new_value, float(effect["max"]))
	current[key] = new_value


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_event_crisis_manager(data) -> Dictionary:
	if not data is Dictionary:
		return {"valid": false, "reason": "داده دیکشنری نیست"}
	if data.is_empty():
		return {"valid": false, "reason": "داده خالی"}
	# بررسی NaN/Inf
	for k in data.keys():
		var v = data[k]
		if v is float and (is_nan(v) or is_inf(v)):
			return {"valid": false, "reason": "عدد نامتناهی در %s" % str(k)}
	return {"valid": true, "reason": ""}

func _deep_cache_event_crisis_manager_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_event_crisis_manager"):
		set_meta("cache_event_crisis_manager", {})
	var cache = get_meta("cache_event_crisis_manager")
	return cache.get(key, null)

func _deep_cache_event_crisis_manager_set(key: String, value):
	if not has_meta("cache_event_crisis_manager"):
		set_meta("cache_event_crisis_manager", {})
	var cache = get_meta("cache_event_crisis_manager")
	cache[key] = value
	set_meta("cache_event_crisis_manager", cache)

func _deep_log_event_crisis_manager(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_event_crisis_manager(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_event_crisis_manager(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("event_crisis_manager"):
		state["event_crisis_manager"] = {}
	return state

func _deep_deterministic_event_crisis_manager_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_event_crisis_manager(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("event_crisis_manager_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_event_crisis_manager(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("event_crisis_manager", {}).duplicate(true) if state.has("event_crisis_manager") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data

