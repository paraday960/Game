extends Node
# ────────────────────────────────────────────────────────────────────────────
# شهرسازی و مسکن — عمق زندگی شهری
# مسکن اجتماعی (هزینه مسکن/رضایت)، حمل‌ونقل عمومی (ترافیک/آلودگی)، شهر
# هوشمند (کارآمدی/فناوری)، کنترل تراکم (قیمت زمین/کیفیت). پیوند: شهرنشینان،
# محیط زیست، آلودگی.
#
# state["urban_policy"] = { "social_housing":0..1, "public_transit":0..1,
#   "smart_city":0..1, "density_control":0..1, "traffic":0..1 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("urban_policy"):
		state["urban_policy"] = {"social_housing": 0.25, "public_transit": 0.4, "smart_city": 0.15, "density_control": 0.3, "traffic": 0.45}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var up: Dictionary = state["urban_policy"]
	var econ: Dictionary = state.get("economy", {})
	var env: Dictionary = state.get("environment", {})
	var pop: Dictionary = state.get("population", {})
	var social := float(up.get("social_housing", 0.25))
	var transit := float(up.get("public_transit", 0.4))
	var smart := float(up.get("smart_city", 0.15))
	var density := float(up.get("density_control", 0.3))
	var traffic := float(up.get("traffic", 0.45))

	# ترافیک: با حمل‌ونقل و شهر هوشمند کاهش می‌یابد؛ با رشد شهری افزایش
	traffic = clampf(traffic + 0.005 - transit * 0.01 - smart * 0.01, 0.05, 0.95)
	up["traffic"] = traffic

	# هزینه مسکن: مسکن اجتماعی قیمت را مهار می‌کند
	var housing_cost := 1.0 - social * 0.4
	up["housing_cost"] = housing_cost
	# رضایت شهرنشینان: مسکن + حمل‌ونقل − ترافیک − تراکم بی‌رویه
	var urban_approval := 50.0 + social * 15.0 + transit * 10.0 - traffic * 15.0 - (1.0 - density) * 5.0
	state["media"]["groups"]["شهرنشینان"]["approval"] = clampf(float(state["media"]["groups"]["شهرنشینان"].get("approval", 55.0)) + (urban_approval - 50.0) * 0.3, 5.0, 100.0)
	# آلودگی هوا: ترافیک و تراکم
	var pollution := traffic * 0.4 + (1.0 - density) * 0.2 - transit * 0.15
	env["air_quality"] = clampf(float(env.get("air_quality", 0.5)) - (pollution - 0.3) * 0.02, 0.05, 1.0)
	state["environment"] = env
	# بهره‌وری: حمل‌ونقل خوب و شهر هوشمند
	econ["gdp"] = float(econ.get("gdp", 1.0)) * (1.0 + transit * 0.001 + smart * 0.0015 - traffic * 0.001)
	state["urban_policy"] = up
	state["economy"] = econ
	return {"state": state, "events": events}

func social_housing(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var up: Dictionary = state["urban_policy"]
	if float(up.get("social_housing", 0.25)) >= 0.9:
		return {"success": false, "reason": "ظرفیت مسکن اجتماعی کامل است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * 0.004
	state["economy"] = econ
	up["social_housing"] = clampf(float(up.get("social_housing", 0.25)) + 0.15, 0.0, 1.0)
	state["urban_policy"] = up
	return {"success": true, "state": state,
		"events": [{"type": "social_housing", "message": "🏘️ طرح مسکن اجتماعی گسترش یافت؛ هزینه مسکن و فشار بر مستأجران کاهش یافت"}]}

func public_transit(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var up: Dictionary = state["urban_policy"]
	if float(up.get("public_transit", 0.4)) >= 0.95:
		return {"success": false, "reason": "شبکه حمل‌ونقل عمومی کامل است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * 0.004
	state["economy"] = econ
	up["public_transit"] = clampf(float(up.get("public_transit", 0.4)) + 0.15, 0.0, 1.0)
	state["urban_policy"] = up
	return {"success": true, "state": state,
		"events": [{"type": "public_transit", "message": "🚇 مترو و اتوبوس‌های برقی توسعه یافت؛ ترافیک و آلودگی کاهش می‌یابد"}]}

func smart_city(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var up: Dictionary = state["urban_policy"]
	if float(up.get("smart_city", 0.15)) >= 0.95:
		return {"success": false, "reason": "شهر هوشمند کامل است", "state": state, "events": []}
	var tech: Dictionary = state.get("technology", {})
	if float(tech.get("branch_levels", {}).get("دیجیتال", 0)) < 10:
		return {"success": false, "reason": "فناوری دیجیتال کافی نیست (سطح ۱۰+)", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * 0.005
	state["economy"] = econ
	up["smart_city"] = clampf(float(up.get("smart_city", 0.15)) + 0.2, 0.0, 1.0)
	state["urban_policy"] = up
	return {"success": true, "state": state,
		"events": [{"type": "smart_city", "message": "🏙️ شهر هوشمند: سنسورها، مدیریت ترافیک هوشمند و خدمات الکترونیک شهری فعال شد"}]}

func density_control(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var up: Dictionary = state["urban_policy"]
	if float(up.get("density_control", 0.3)) >= 0.95:
		return {"success": false, "reason": "کنترل تراکم حداکثری است", "state": state, "events": []}
	up["density_control"] = clampf(float(up.get("density_control", 0.3)) + 0.2, 0.0, 1.0)
	state["urban_policy"] = up
	# محدودیت ساخت → قیمت زمین بالا (نخبگان خوشحال، شهرنشینان ناراضی)
	state["media"]["groups"]["شهرنشینان"]["approval"] = clampf(float(state["media"]["groups"]["شهرنشینان"].get("approval", 55.0)) - 1.0, 5.0, 100.0)
	var factions: Dictionary = state.get("factions", {})
	if factions.has("نخبگان اقتصادی"):
		var f: Dictionary = factions["نخبگان اقتصادی"]
		f["loyalty"] = clampf(float(f.get("loyalty", 50.0)) + 1.0, 0.0, 100.0)
		factions["نخبگان اقتصادی"] = f
		state["factions"] = factions
	return {"success": true, "state": state,
		"events": [{"type": "density_control", "message": "🏗️ سقف تراکم ساختمانی اعمال شد؛ شهر نفس می‌کشد ولی زمین گران‌تر شد"}]}
