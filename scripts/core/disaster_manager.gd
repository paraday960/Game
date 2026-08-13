extends Node
# ────────────────────────────────────────────────────────────────────────────
# مدیریت بحران و آمادگی حوادث — عمق تاب‌آوری ملی
# هشدار زودهنگام، پناهگاه/اسکان اضطراری، تیم‌های واکنش سریع و ذخیره امدادی.
# زلزله/سیل/خشکسالی بدون آمادگی خسارت جانی و اقتصادی هنگفت می‌زند.
# پیوند: پدافند غیرعامل، اقلیم، بهداشت، تأسیسات شهری، اقتصاد.
#
# state["disaster_policy"] = {
#   "early_warning":0..1, "shelter":0..1, "response":0..1,
#   "relief_stock":0..1, "last_drill":turn,
#   "preparedness":0..1, "risk":0..1, "casualty_risk":0..1 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("disaster_policy"):
		state["disaster_policy"] = {
			"early_warning": 0.30, "shelter": 0.25, "response": 0.35,
			"relief_stock": 0.30, "last_drill": -99,
			"preparedness": 0.30, "risk": 0.45, "casualty_risk": 0.50,
			"recovery_speed": 0.35, "drills": 0
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var dp: Dictionary = state["disaster_policy"]
	var econ: Dictionary = state.get("economy", {})
	var env: Dictionary = state.get("environment", {})
	var health: Dictionary = state.get("health", {})
	var civil: Dictionary = state.get("civil_defense_policy", {})
	var climate: Dictionary = state.get("climate_policy", {})

	var early: float = float(dp.get("early_warning", 0.30))
	var shelter: float = float(dp.get("shelter", 0.25))
	var response: float = float(dp.get("response", 0.35))
	var relief: float = float(dp.get("relief_stock", 0.30))

	# شاخص آمادگی
	var prepared: float = clampf(
		0.15 + early * 0.25 + shelter * 0.25 + response * 0.25 + relief * 0.25, 0.05, 0.98)
	dp["preparedness"] = prepared

	# ریسک پایه: آلودگی/فرسایش/تغییر اقلیم
	var disaster_risk: float = clampf(
		0.30 + float(env.get("pollution", 0.45)) * 0.15 +
		float(climate.get("disaster_readiness", 0.3)) * 0.10 - prepared * 0.35, 0.05, 0.95)
	dp["risk"] = disaster_risk
	dp["casualty_risk"] = clampf(0.70 - prepared * 0.55, 0.05, 0.95)
	dp["recovery_speed"] = clampf(0.20 + response * 0.50 + relief * 0.25, 0.05, 0.98)

	# هزینه آمادگی
	var gdp: float = float(econ.get("gdp", 1.0))
	econ["government_spending"] = float(econ.get("government_spending", 0.0)) + gdp * 0.0015
	state["economy"] = econ

	# پدافند غیرعامل هم به آمادگی کمک می‌کند
	if not civil.is_empty():
		dp["preparedness"] = clampf(prepared + float(civil.get("strategic_stock", 0)) * 0.05, 0.0, 1.0)

	# رویدادها (هرچند ماه یک بار، ریسک-محور)
	if disaster_risk > 0.55 and Deterministic.chance(0.04):
		var dmg: float = gdp * (0.005 + disaster_risk * 0.01) * (1.0 - prepared)
		econ["gdp"] = float(econ.get("gdp", gdp)) - dmg
		if not health.is_empty():
			health["quality"] = clampf(float(health.get("quality", 0.60)) - 0.003, 0.1, 1.0)
			state["health"] = health
		state["economy"] = econ
		events.append({"type": "disaster_strike", "message": "🌪️ یک حادثه طبیعی خسارت زد؛ آمادگی پایین تلفات را بیشتر کرد"})
	elif prepared > 0.65 and Deterministic.chance(0.025):
		events.append({"type": "drill_success", "message": "🚨 مانور بحران موفقیت‌آمیز بود؛ تاب‌آوری ملی بالا رفت"})

	state["disaster_policy"] = dp
	return {"state": state, "events": events}

func build_early_warning(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var dp: Dictionary = state["disaster_policy"]
	var tech: float = float(state.get("technology", {}).get("branch_levels", {}).get("دیجیتال", 0))
	if tech < 3:
		return {"success": false, "reason": "به فناوری دیجیتال سطح ۳ نیاز است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["government_spending"] = float(econ.get("government_spending", 0.0)) + float(econ.get("gdp", 1.0)) * 0.003
	dp["early_warning"] = clampf(float(dp.get("early_warning", 0.30)) + 0.15, 0.0, 1.0)
	state["economy"] = econ
	state["disaster_policy"] = dp
	return {"success": true, "state": state,
		"events": [{"type": "warning", "message": "📡 سامانه هشدار زودهنگام زلزله/سیل راه‌اندازی شد"}]}

func build_shelters(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var dp: Dictionary = state["disaster_policy"]
	var econ: Dictionary = state.get("economy", {})
	econ["government_spending"] = float(econ.get("government_spending", 0.0)) + float(econ.get("gdp", 1.0)) * 0.004
	dp["shelter"] = clampf(float(dp.get("shelter", 0.25)) + 0.15, 0.0, 1.0)
	state["economy"] = econ
	state["disaster_policy"] = dp
	return {"success": true, "state": state,
		"events": [{"type": "shelter", "message": "🏠 پناهگاه و اسکان اضطراری توسعه یافت"}]}

func train_response(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var dp: Dictionary = state["disaster_policy"]
	if turn - int(dp.get("last_drill", -99)) < 4:
		return {"success": false, "reason": "مانور سراسری هر ۴ نوبت یک بار", "state": state, "events": []}
	dp["last_drill"] = turn
	dp["response"] = clampf(float(dp.get("response", 0.35)) + 0.15, 0.0, 1.0)
	dp["drills"] = int(dp.get("drills", 0)) + 1
	state["disaster_policy"] = dp
	return {"success": true, "state": state,
		"events": [{"type": "response", "message": "🚑 تیم‌های واکنش سریع آموزش دیدند و مانور برگزار شد"}]}

func relief_aid(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var dp: Dictionary = state["disaster_policy"]
	var econ: Dictionary = state.get("economy", {})
	econ["government_spending"] = float(econ.get("government_spending", 0.0)) + float(econ.get("gdp", 1.0)) * 0.002
	dp["relief_stock"] = clampf(float(dp.get("relief_stock", 0.30)) + 0.15, 0.0, 1.0)
	state["economy"] = econ
	state["disaster_policy"] = dp
	return {"success": true, "state": state,
		"events": [{"type": "relief", "message": "📦 ذخیره امدادی (غذا/دارو/چادر) تقویت شد"}]}
