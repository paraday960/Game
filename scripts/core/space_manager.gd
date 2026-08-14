extends Node
# ────────────────────────────────────────────────────────────────────────────
# برنامه فضایی — عمق فناوری و پرستیژ
# آژانس فضایی، ماهواره (ارتباطات/سنجش از دور)، پرتاب‌گر، ایستگاه فضایی.
# پیوند: شاخه «فضا»، قدرت نرم، رقابت قدرت‌ها (مسابقه فضایی)، فناوری.
#
# state["space_policy"] = { "agency":0..1, "satellites_comm":0..1, "satellites_obs":0..1,
#   "launcher":0..1, "station":false, "launches":0, "failures":0 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("space_policy"):
		state["space_policy"] = {"agency": 0.2, "satellites_comm": 0.0, "satellites_obs": 0.0, "launcher": 0.0, "station": false, "launches": 0, "failures": 0}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var sp: Dictionary = state["space_policy"]
	var tech: Dictionary = state.get("technology", {})
	var econ: Dictionary = state.get("economy", {})
	var space_level := float(tech.get("branch_levels", {}).get("فضا", 0))
	var agency := float(sp.get("agency", 0.2))

	# آژانس: هزینه نگهداری + پیشرفت دانش فضایی (بازرسی ۱۴۰۵ — دور هشتم):
	# هزینهٔ مداوم ماهانه به کانال policy_costs می‌رود (مجاری بودجه)، نه شارژ خاموش بدهی.
	econ["space_cost"] = agency * 0.002
	var sp_costs: Dictionary = econ.get("policy_costs", {})
	sp_costs["برنامه فضایی (آژانس)"] = float(econ.get("gdp", 1.0)) * agency * 0.001
	econ["policy_costs"] = sp_costs
	# اثر فناوری فضا
	tech["research_rate"] = float(tech.get("research_rate", 20.0)) * (1.0 + agency * 0.005)
	state["technology"] = tech
	# رویدادهای شانسی: پرتاب موفق/شکست بر اساس فناوری
	if agency > 0.3 and Deterministic.chance(0.05):
		var success := Deterministic.chance(clampf(0.5 + space_level * 0.02, 0.5, 0.95))
		if success:
			sp["launches"] = int(sp.get("launches", 0)) + 1
			state["culture_policy"]["soft_power"] = clampf(float(state["culture_policy"].get("soft_power", 40.0)) + 1.5, 5.0, 100.0)
			state["leader"]["popularity_world"] = clampf(float(state["leader"].get("popularity_world", 50.0)) + 0.5, 0.0, 100.0)
			events.append({"type": "space_launch", "message": "🚀 پرتاب موفق ماهواره! کشور در مدار — افتخار ملی و اعتبار جهانی"})
		else:
			sp["failures"] = int(sp.get("failures", 0)) + 1
			econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * 0.002
			events.append({"type": "space_failure", "message": "💥 شکست پرتاب فضایی؛ بودجه سوزانده شد و انتقادها بالا گرفت"})
	# ماهواره‌ها: ارتباطات → مخابرات؛ سنجش → کشاورزی/اقلیم
	if float(sp.get("satellites_comm", 0.0)) > 0.3:
		state["infrastructure"]["telecom"] = clampf(float(state["infrastructure"].get("telecom", 0.7)) + 0.002, 0.1, 1.0)
	if float(sp.get("satellites_obs", 0.0)) > 0.3:
		state["agri_policy"]["crop_diversity"] = clampf(float(state["agri_policy"].get("crop_diversity", 0.3)) + 0.001, 0.0, 1.0)
		state["climate_policy"]["disaster_readiness"] = clampf(float(state["climate_policy"].get("disaster_readiness", 0.3)) + 0.001, 0.0, 1.0)
	state["space_policy"] = sp
	state["economy"] = econ
	return {"state": state, "events": events}

func expand_agency(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["space_policy"]
	if float(sp.get("agency", 0.2)) >= 0.95:
		return {"success": false, "reason": "آژانس فضایی حداکثری است", "state": state, "events": []}
	state["economy"]["national_debt"] = float(state["economy"].get("national_debt", 0.0)) + float(state["economy"].get("gdp", 1.0)) * 0.004
	sp["agency"] = clampf(float(sp.get("agency", 0.2)) + 0.15, 0.0, 1.0)
	state["space_policy"] = sp
	return {"success": true, "state": state,
		"events": [{"type": "space_agency", "message": "🛰️ آژانس فضایی ملی گسترش یافت؛ دانشمندان و مهندسان فضایی جذب شدند"}]}

func comm_satellite(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["space_policy"]
	if float(sp.get("satellites_comm", 0.0)) >= 0.9:
		return {"success": false, "reason": "شبکه ماهواره ارتباطی کامل است", "state": state, "events": []}
	var tech: Dictionary = state.get("technology", {})
	if float(tech.get("branch_levels", {}).get("فضا", 0)) < 6:
		return {"success": false, "reason": "شاخه فضا برای ماهواره کافی نیست (۶+)", "state": state, "events": []}
	state["economy"]["national_debt"] = float(state["economy"].get("national_debt", 0.0)) + float(state["economy"].get("gdp", 1.0)) * 0.005
	sp["satellites_comm"] = clampf(float(sp.get("satellites_comm", 0.0)) + 0.3, 0.0, 1.0)
	state["space_policy"] = sp
	return {"success": true, "state": state,
		"events": [{"type": "comm_satellite", "message": "📡 ماهواره ارتباطی در مدار قرار گرفت؛ اینترنت و مخابرات روستاها متحول شد"}]}

func observation_satellite(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["space_policy"]
	if float(sp.get("satellites_obs", 0.0)) >= 0.9:
		return {"success": false, "reason": "شبکه سنجش از دور کامل است", "state": state, "events": []}
	var tech: Dictionary = state.get("technology", {})
	if float(tech.get("branch_levels", {}).get("فضا", 0)) < 8:
		return {"success": false, "reason": "شاخه فضا برای سنجش کافی نیست (۸+)", "state": state, "events": []}
	state["economy"]["national_debt"] = float(state["economy"].get("national_debt", 0.0)) + float(state["economy"].get("gdp", 1.0)) * 0.005
	sp["satellites_obs"] = clampf(float(sp.get("satellites_obs", 0.0)) + 0.3, 0.0, 1.0)
	state["space_policy"] = sp
	return {"success": true, "state": state,
		"events": [{"type": "obs_satellite", "message": "🛰️ ماهواره سنجش از دور: پایش خشکسالی، سیل و محصولات کشاورزی فعال شد"}]}

func launch_vehicle(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["space_policy"]
	if bool(sp.get("launcher", 0.0)) and float(sp.get("launcher", 0.0)) >= 1.0:
		return {"success": false, "reason": "پرتاب‌گر بومی کامل است", "state": state, "events": []}
	var tech: Dictionary = state.get("technology", {})
	if float(tech.get("branch_levels", {}).get("فضا", 0)) < 12:
		return {"success": false, "reason": "شاخه فضا برای پرتاب‌گر کافی نیست (۱۲+)", "state": state, "events": []}
	state["economy"]["national_debt"] = float(state["economy"].get("national_debt", 0.0)) + float(state["economy"].get("gdp", 1.0)) * 0.008
	sp["launcher"] = 1.0
	state["space_policy"] = sp
	# استقلال پرتاب: هزینه پرتاب‌ها کمتر
	state["economy"]["space_cost"] = float(state["economy"].get("space_cost", 0.0)) * 0.5
	return {"success": true, "state": state,
		"events": [{"type": "launch_vehicle", "message": "🚀 پرتاب‌گر بومی رونمایی شد! کشور به باشگاه کشورهای دارای فناوری پرتاب پیوست"}]}
