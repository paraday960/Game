extends Node
# اقلیم، آب‌وهوا و خدمات شهری ماهانه با اثر متقابل بر همه سامانه‌های کشور

const MUNICIPAL_ACTIONS = [
	"buy_snowplows", "stock_road_salt", "winter_training",
	"improve_drainage", "cooling_centers", "road_maintenance"
]

func reset_for_country(state: Dictionary, country_id: String) -> Dictionary:
	var profile = WorldManager.get_country(country_id)
	var population = float(profile.get("population", state.get("population", {}).get("total", 1.0)))
	var target_plows = max(5, int(population / 50_000.0))
	var capacity = float(profile.get("municipal_capacity", 0.5))
	var snow_factor = float(profile.get("snow_factor", 0.2))
	state["municipal_services"] = {
		"snowplows": int(target_plows * capacity * max(snow_factor, 0.10)),
		"target_snowplows": target_plows,
		"snowplow_readiness": clamp(0.45 + capacity * 0.45, 0.35, 0.95),
		"road_salt_days": 5.0 + 25.0 * snow_factor * capacity,
		"drainage": float(profile.get("drainage_base", capacity)),
		"heating_readiness": float(profile.get("heating_capacity", 0.5)),
		"heat_readiness": float(profile.get("cooling_capacity", 0.5)),
		"emergency_crews": max(20, int(population / 500_000.0 * capacity)),
		"roads_blocked": 0.0,
		"investment_capacity": 3.0,
		"last_investment_tick": -1
	}
	state["weather"] = {
		"climate": str(profile.get("climate_fa", "معتدل")),
		"current": {},
		"history": []
	}
	return state

func ensure_state(state: Dictionary) -> Dictionary:
	if not state.has("municipal_services") or not state["municipal_services"] is Dictionary:
		state = reset_for_country(state, str(state.get("country", {}).get("id", WorldManager.default_country)))
	return state

func can_action(state: Dictionary, action: String) -> Dictionary:
	if not MUNICIPAL_ACTIONS.has(action):
		return {"valid": false, "reason": "اقدام خدمات شهری شناخته‌شده نیست"}
	state = ensure_state(state.duplicate(true))
	if float(state["municipal_services"].get("investment_capacity", 0.0)) < 1.0:
		return {"valid": false, "reason": "ظرفیت سرمایه‌گذاری شهرداری کافی نیست؛ ماه بعد دوباره تلاش کنید"}
	return {"valid": true, "reason": ""}

func apply_action(state: Dictionary, action: String, turn: int) -> Dictionary:
	var check = can_action(state, action)
	if not check.valid:
		return {"success": false, "reason": check.reason, "state": state, "events": []}
	state = ensure_state(state)
	var municipal: Dictionary = state["municipal_services"]
	var gdp = max(float(state.get("economy", {}).get("gdp", 1.0)), 1.0)
	var cost = 0.0
	var message = ""
	match action:
		"buy_snowplows":
			var batch = max(10, int(float(state.get("population", {}).get("total", 1.0)) / 1_000_000.0))
			municipal["snowplows"] = int(municipal.get("snowplows", 0)) + batch
			cost = gdp * 0.002
			message = "%s ماشین برف‌روبی خریداری شد" % str(batch)
		"stock_road_salt":
			municipal["road_salt_days"] = min(60.0, float(municipal.get("road_salt_days", 0.0)) + 15.0)
			cost = gdp * 0.0005
			message = "ذخیره نمک و شن جاده برای ۱۵ روز افزایش یافت"
		"winter_training":
			municipal["snowplow_readiness"] = clamp(float(municipal.get("snowplow_readiness", 0.5)) + 0.10, 0.0, 1.0)
			municipal["heating_readiness"] = clamp(float(municipal.get("heating_readiness", 0.5)) + 0.05, 0.0, 1.0)
			cost = gdp * 0.001
			message = "رزمایش زمستانی شهرداری و امداد انجام شد"
		"improve_drainage":
			municipal["drainage"] = clamp(float(municipal.get("drainage", 0.5)) + 0.06, 0.0, 1.0)
			cost = gdp * 0.003
			message = "ظرفیت زهکشی و هدایت آب‌های سطحی افزایش یافت"
		"cooling_centers":
			municipal["heat_readiness"] = clamp(float(municipal.get("heat_readiness", 0.5)) + 0.09, 0.0, 1.0)
			cost = gdp * 0.0015
			message = "مراکز خنک‌کننده و پناه گرمایی راه‌اندازی شد"
		"road_maintenance":
			state["infrastructure"]["quality"] = clamp(float(state["infrastructure"].get("quality", 0.5)) + 0.015, 0.0, 1.0)
			if state.has("transport_detail"):
				state["transport_detail"]["roads_quality"] = clamp(float(state["transport_detail"].get("roads_quality", 0.5)) + 0.025, 0.0, 1.0)
			cost = gdp * 0.0025
			message = "عملیات نگهداری پیشگیرانه راه‌ها اجرا شد"
	municipal["investment_capacity"] = max(0.0, float(municipal["investment_capacity"]) - 1.0)
	municipal["last_investment_tick"] = turn
	state["economy"]["national_debt"] = float(state["economy"].get("national_debt", 0.0)) + cost
	state["municipal_services"] = municipal
	return {
		"success": true, "state": state,
		"events": [{"type":"municipal_investment", "message":message, "action":action, "cost":cost}]
	}

func simulate_month(state: Dictionary, turn: int, forced: Dictionary = {}) -> Dictionary:
	state = ensure_state(state)
	var country_id = str(state.get("country", {}).get("id", WorldManager.default_country))
	var profile = WorldManager.get_country(country_id)
	var season = str(state.get("time", {}).get("season", "بهار"))
	var municipal: Dictionary = state["municipal_services"]
	municipal["roads_blocked"] = 0.0
	municipal["investment_capacity"] = min(3.0, float(municipal.get("investment_capacity", 0.0)) + 0.50)
	municipal["snowplow_readiness"] = clamp(float(municipal.get("snowplow_readiness", 0.6)) - 0.005, 0.25, 0.98)

	var snow_factor = float(profile.get("snow_factor", 0.2))
	var flood_factor = float(profile.get("flood_factor", 0.4))
	var heat_factor = float(profile.get("heat_factor", 0.5))
	var severity = float(forced.get("severity", Deterministic.next_range(0.25, 0.95)))
	var temperature = _base_temperature(season, snow_factor, heat_factor) + Deterministic.next_range(-4.0, 4.0)
	var precipitation = (20.0 + flood_factor * 90.0) * Deterministic.next_range(0.55, 1.45)
	var events: Array = []
	var condition = "پایدار"
	var hazard = "none"

	var force_snow = bool(forced.get("force_snow", false))
	var force_flood = bool(forced.get("force_flood", false))
	var force_heat = bool(forced.get("force_heat", false))
	if season == "زمستان" and snow_factor > 0.05 and (force_snow or (temperature <= 4.0 and Deterministic.chance(0.20 + snow_factor * 0.65))):
		hazard = "snow"
		condition = "برف و یخبندان"
		var snow_result = _apply_snow(state, municipal, profile, severity, max(5.0, severity * 70.0 * snow_factor))
		state = snow_result.state
		municipal = state["municipal_services"]
		events.append_array(snow_result.events)
	elif (season == "بهار" or season == "پاییز") and (force_flood or Deterministic.chance(0.08 + flood_factor * 0.42)):
		hazard = "flood"
		condition = "بارش شدید و سیلاب"
		var flood_result = _apply_flood(state, municipal, severity * flood_factor)
		state = flood_result.state
		events.append_array(flood_result.events)
	elif season == "تابستان" and (force_heat or Deterministic.chance(0.12 + heat_factor * 0.55)):
		hazard = "heatwave"
		condition = "موج گرما"
		temperature += 5.0 + severity * 8.0
		var heat_result = _apply_heatwave(state, municipal, severity * heat_factor)
		state = heat_result.state
		events.append_array(heat_result.events)
	else:
		_apply_normal_season(state, season, precipitation, heat_factor)
		events.append({"type":"seasonal_normal", "message":"شرایط %s بدون بحران عمده سپری شد" % season})

	state["municipal_services"] = municipal
	var current_weather = {
		"turn":turn, "year":state["clock"]["year"], "month":state["clock"]["month"],
		"month_name":state["time"]["month_name"], "season":season,
		"condition":condition, "hazard":hazard, "severity":severity,
		"temperature_c":temperature, "precipitation_mm":precipitation,
		"roads_blocked":float(municipal.get("roads_blocked", 0.0))
	}
	var weather: Dictionary = state["weather"]
	weather["climate"] = str(profile.get("climate_fa", "معتدل"))
	weather["current"] = current_weather
	var history: Array = weather.get("history", [])
	history.append(current_weather.duplicate(true))
	while history.size() > 36:
		history.pop_front()
	weather["history"] = history
	state["weather"] = weather
	return {"state":state, "events":events}

func _apply_snow(state: Dictionary, municipal: Dictionary, profile: Dictionary, severity: float, snow_cm: float) -> Dictionary:
	var population = max(float(state.get("population", {}).get("total", 1.0)), 1.0)
	var required_plows = max(1.0, population / 50_000.0 * max(severity, 0.25))
	var equipment = clamp(float(municipal.get("snowplows", 0)) / required_plows, 0.0, 1.2)
	var salt = clamp(float(municipal.get("road_salt_days", 0.0)) / 15.0, 0.0, 1.0)
	var administration = float(state.get("administration", {}).get("efficiency", 0.55))
	var response = clamp(equipment * 0.45 + float(municipal.get("snowplow_readiness", 0.5)) * 0.25 + salt * 0.15 + administration * 0.15, 0.0, 1.0)
	var blocked = clamp(severity * (1.15 - response), 0.0, 0.95)
	municipal["roads_blocked"] = blocked
	municipal["road_salt_days"] = max(0.0, float(municipal.get("road_salt_days", 0.0)) - severity * 9.0)
	municipal["snow_depth_cm"] = snow_cm
	state["municipal_services"] = municipal
	var events: Array = []
	# گرمایش و برق در زمستان مصرف بیشتری دارند.
	state["resources"]["inventory"]["برق"] = max(0.0, float(state["resources"]["inventory"].get("برق", 0.0)) - severity * 8.0)
	state["resources"]["inventory"]["گاز"] = max(0.0, float(state["resources"]["inventory"].get("گاز", 0.0)) - severity * 7.0)
	if blocked > 0.18:
		state["infrastructure"]["quality"] = clamp(float(state["infrastructure"].get("quality", 0.5)) - blocked * 0.008, 0.0, 1.0)
		if state.has("transport_detail"):
			state["transport_detail"]["roads_quality"] = clamp(float(state["transport_detail"].get("roads_quality", 0.5)) - blocked * 0.020, 0.0, 1.0)
			state["transport_detail"]["logistics_efficiency"] = clamp(float(state["transport_detail"].get("logistics_efficiency", 0.5)) - blocked * 0.030, 0.0, 1.0)
		state["population"]["happiness"] = clamp(float(state["population"].get("happiness", 0.5)) - blocked * 0.020, 0.05, 0.95)
		state["politics"]["tension"] = clamp(float(state["politics"].get("tension", 0.3)) + blocked * 0.035, 0.0, 1.0)
		state["economy"]["gdp"] *= 1.0 - blocked * 0.0025
		state["emergency"]["response_time"] = float(state["emergency"].get("response_time", 10.0)) + blocked * 2.5
		events.append({
			"type":"snow_transport_crisis", "severity":blocked, "snow_cm":snow_cm,
			"message":"برف %s سانتی‌متری و کمبود برف‌روب، %s٪ راه‌ها را مسدود کرد" % [str(int(snow_cm)), str(int(blocked * 100.0))]
		})
		if blocked > 0.50:
			state["population"]["happiness"] = clamp(float(state["population"]["happiness"]) - 0.025, 0.05, 0.95)
			state["politics"]["tension"] = clamp(float(state["politics"]["tension"]) + 0.05, 0.0, 1.0)
			events.append({"type":"winter_service_protest", "severity":blocked, "message":"اعتراضات به ناتوانی شهرداری در بازگشایی مسیرهای برفی شکل گرفت"})
	else:
		events.append({"type":"snow_cleared", "severity":severity, "message":"ناوگان برف‌روبی مسیرهای زمستانی را به‌موقع باز نگه داشت"})
	if float(state["resources"]["inventory"].get("برق", 0.0)) < 12.0 or float(state["resources"]["inventory"].get("گاز", 0.0)) < 10.0:
		var heat_gap = 1.0 - float(municipal.get("heating_readiness", profile.get("heating_capacity", 0.5)))
		state["health"]["quality"] = clamp(float(state["health"].get("quality", 0.5)) - 0.02 * heat_gap, 0.0, 1.0)
		events.append({"type":"heating_crisis", "severity":heat_gap, "message":"کمبود انرژی و آمادگی گرمایشی، خانه‌ها را در سرمای زمستان تحت فشار گذاشت"})
	return {"state":state, "events":events}

func _apply_flood(state: Dictionary, municipal: Dictionary, raw_severity: float) -> Dictionary:
	var drainage = float(municipal.get("drainage", 0.5))
	var severity = clamp(raw_severity * (1.15 - drainage), 0.0, 0.95)
	municipal["roads_blocked"] = severity * 0.65
	state["municipal_services"] = municipal
	state["infrastructure"]["quality"] = clamp(float(state["infrastructure"].get("quality", 0.5)) - severity * 0.018, 0.0, 1.0)
	state["agriculture"]["production"] = max(0.0, float(state["agriculture"].get("production", 100.0)) * (1.0 - severity * 0.04))
	state["emergency"]["response_time"] = float(state["emergency"].get("response_time", 10.0)) + severity * 3.0
	state["population"]["happiness"] = clamp(float(state["population"].get("happiness", 0.5)) - severity * 0.018, 0.05, 0.95)
	return {"state":state, "events":[{
		"type":"urban_flood", "severity":severity,
		"message":"زهکشی ناکافی باعث آب‌گرفتگی %s٪ شبکه راه‌ها شد" % str(int(severity * 65.0))
	}]}

func _apply_heatwave(state: Dictionary, municipal: Dictionary, raw_severity: float) -> Dictionary:
	var readiness = float(municipal.get("heat_readiness", 0.5))
	var severity = clamp(raw_severity * (1.12 - readiness * 0.65), 0.0, 0.95)
	state["resources"]["inventory"]["برق"] = max(0.0, float(state["resources"]["inventory"].get("برق", 0.0)) - severity * 10.0)
	state["resources"]["inventory"]["آب"] = max(0.0, float(state["resources"]["inventory"].get("آب", 0.0)) - severity * 8.0)
	state["health"]["quality"] = clamp(float(state["health"].get("quality", 0.5)) - severity * 0.016, 0.0, 1.0)
	state["environment"]["air_quality"] = clamp(float(state["environment"].get("air_quality", 0.5)) - severity * 0.018, 0.0, 1.0)
	state["population"]["happiness"] = clamp(float(state["population"].get("happiness", 0.5)) - severity * 0.016, 0.05, 0.95)
	return {"state":state, "events":[{
		"type":"heatwave_crisis", "severity":severity,
		"message":"موج گرما مصرف آب و برق را افزایش داد؛ آمادگی شهری اثر بحران را به %s٪ رساند" % str(int(severity * 100.0))
	}]}

func _apply_normal_season(state: Dictionary, season: String, precipitation: float, heat_factor: float):
	if season == "بهار" and precipitation >= 35.0 and precipitation <= 100.0:
		state["agriculture"]["production"] = float(state["agriculture"].get("production", 100.0)) * 1.005
	if season == "پاییز":
		state["resources"]["inventory"]["غذا"] = min(float(state["resources"]["capacity"].get("غذا", 150.0)), float(state["resources"]["inventory"].get("غذا", 0.0)) + 3.0)
	if season == "تابستان" and heat_factor > 0.65:
		state["resources"]["inventory"]["آب"] = max(0.0, float(state["resources"]["inventory"].get("آب", 0.0)) - 2.0)

func _base_temperature(season: String, snow_factor: float, heat_factor: float) -> float:
	match season:
		"زمستان": return 12.0 - snow_factor * 25.0 + heat_factor * 4.0
		"تابستان": return 22.0 + heat_factor * 17.0 - snow_factor * 3.0
		"بهار": return 15.0 + heat_factor * 7.0 - snow_factor * 4.0
		_: return 13.0 + heat_factor * 6.0 - snow_factor * 3.0


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_seasonal_manager(data) -> Dictionary:
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

func _deep_cache_seasonal_manager_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_seasonal_manager"):
		set_meta("cache_seasonal_manager", {})
	var cache = get_meta("cache_seasonal_manager")
	return cache.get(key, null)

func _deep_cache_seasonal_manager_set(key: String, value):
	if not has_meta("cache_seasonal_manager"):
		set_meta("cache_seasonal_manager", {})
	var cache = get_meta("cache_seasonal_manager")
	cache[key] = value
	set_meta("cache_seasonal_manager", cache)

func _deep_log_seasonal_manager(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_seasonal_manager(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_seasonal_manager(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("seasonal_manager"):
		state["seasonal_manager"] = {}
	return state

func _deep_deterministic_seasonal_manager_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_seasonal_manager(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("seasonal_manager_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_seasonal_manager(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("seasonal_manager", {}).duplicate(true) if state.has("seasonal_manager") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---
