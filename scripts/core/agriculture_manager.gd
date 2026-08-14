extends Node
# ────────────────────────────────────────────────────────────────────────────
# کشاورزی و امنیت غذایی — عمق اقتصاد روستا
# ذخیره راهبردی غلات (تلاش با قیمت گندم)، یارانه کود (تولید/آلودگی)، تنوع
# کشت (تاب‌آوری اقلیمی)، آبیاری هوشمند (آب). پیوند: بازار کالا، روستاییان.
#
# state["agriculture"] = { "grain_reserve":0..1, "fertilizer_subsidy":0..1,
#   "crop_diversity":0..1, "smart_irrigation":0..1, "harvests":0 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("agri_policy"):
		state["agri_policy"] = {"grain_reserve": 0.3, "fertilizer_subsidy": 0.4, "crop_diversity": 0.3, "smart_irrigation": 0.2, "harvests": 0}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var ag: Dictionary = state["agri_policy"]
	var econ: Dictionary = state.get("economy", {})
	var com: Dictionary = state.get("commodities", {})
	var resources: Dictionary = state.get("resources", {})
	var wheat := float(com.get("prices", {}).get("گندم", 260.0))
	var grain := float(ag.get("grain_reserve", 0.3))
	var fertilizer := float(ag.get("fertilizer_subsidy", 0.4))
	var diversity := float(ag.get("crop_diversity", 0.3))
	var irrigation := float(ag.get("smart_irrigation", 0.2))
	var water := float(resources.get("inventory", {}).get("آب", 90.0))

	# ذخیره راهبردی: در قیمت بالای گندم، ذخیره ارزشمند می‌شود (تورم خوراک را مهار می‌کند)
	var food_shock := (wheat - 260.0) / 260.0
	if grain > 0.6:
		food_shock *= 0.5
	# تنوع کشت: تاب‌آوری در برابر خشکسالی
	var drought_risk := 0.1 - diversity * 0.05
	if Deterministic.chance(drought_risk):
		var loss := 0.005 - diversity * 0.004
		econ["gdp"] = float(econ.get("gdp", 1.0)) * (1.0 - loss)
		events.append({"type": "crop_failure", "message": "🌾 خشکسالی به کشت آسیب زد؛ تنوع پایین، خسارت را بزرگ کرد"})
	# اثرها
	econ["inflation"] = clampf(float(econ.get("inflation", 0.08)) + food_shock * 0.01 - grain * 0.002, 0.0, 1.5)
	# ممیزی GDP (۱۴۰۵): اثر مداوم نهاده‌های کشاورزی از کانال مالک-یکتای sector_boosts (نرخ سالانه؛ ×۱۲)
	var ag_boosts: Dictionary = econ.get("sector_boosts", {})
	ag_boosts["کشاورزی"] = (fertilizer * 0.001 + irrigation * 0.001) * 12.0
	econ["sector_boosts"] = ag_boosts
	# آب: آبیاری هوشمند مصرف را بهینه می‌کند
	resources["inventory"]["آب"] = clampf(water - 0.2 + irrigation * 0.5, 10.0, 100.0)
	state["resources"] = resources
	# روستاییان
	state["media"]["groups"]["روستاییان"]["approval"] = clampf(float(state["media"]["groups"]["روستاییان"].get("approval", 60.0)) + fertilizer * 0.3 + irrigation * 0.2, 5.0, 100.0)
	state["agri_policy"] = ag
	state["economy"] = econ
	return {"state": state, "events": events}

func build_grain_reserve(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var ag: Dictionary = state["agri_policy"]
	if float(ag.get("grain_reserve", 0.3)) >= 0.95:
		return {"success": false, "reason": "ظرفیت ذخیره راهبردی کامل است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * 0.002
	state["economy"] = econ
	ag["grain_reserve"] = clampf(float(ag.get("grain_reserve", 0.3)) + 0.15, 0.0, 1.0)
	state["agri_policy"] = ag
	return {"success": true, "state": state,
		"events": [{"type": "grain_reserve", "message": "🌾 سیلوهای راهبردی غلات تکمیل شد؛ تورم خوراک در شوک‌های قیمتی مهار می‌شود"}]}

func fertilizer_subsidy(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var ag: Dictionary = state["agri_policy"]
	if float(ag.get("fertilizer_subsidy", 0.4)) >= 0.95:
		return {"success": false, "reason": "یارانه کود حداکثری است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * 0.003
	state["economy"] = econ
	ag["fertilizer_subsidy"] = clampf(float(ag.get("fertilizer_subsidy", 0.4)) + 0.15, 0.0, 1.0)
	state["agri_policy"] = ag
	return {"success": true, "state": state,
		"events": [{"type": "fertilizer", "message": "🧪 یارانه کود کشاورزی افزایش یافت؛ تولید بالا می‌رود ولی محیط زیست آسیب می‌بیند"}]}

func crop_diversification(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var ag: Dictionary = state["agri_policy"]
	if float(ag.get("crop_diversity", 0.3)) >= 0.95:
		return {"success": false, "reason": "تنوع کشت حداکثری است", "state": state, "events": []}
	ag["crop_diversity"] = clampf(float(ag.get("crop_diversity", 0.3)) + 0.15, 0.0, 1.0)
	state["agri_policy"] = ag
	return {"success": true, "state": state,
		"events": [{"type": "crop_diversity", "message": "🌱 کشت‌های جایگزین و مقاوم معرفی شد؛ تاب‌آوری اقلیمی روستاها بالا رفت"}]}

func smart_irrigation(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var ag: Dictionary = state["agri_policy"]
	if float(ag.get("smart_irrigation", 0.2)) >= 0.95:
		return {"success": false, "reason": "آبیاری هوشمند کامل است", "state": state, "events": []}
	var tech: Dictionary = state.get("technology", {})
	if float(tech.get("branch_levels", {}).get("صنعت", 0)) < 8:
		return {"success": false, "reason": "فناوری صنعت کافی نیست (سطح ۸+)", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * 0.003
	state["economy"] = econ
	ag["smart_irrigation"] = clampf(float(ag.get("smart_irrigation", 0.2)) + 0.2, 0.0, 1.0)
	state["agri_policy"] = ag
	return {"success": true, "state": state,
		"events": [{"type": "smart_irrigation", "message": "💧 شبکه آبیاری هوشمند و قطره‌ای راه‌اندازی شد؛ مصرف آب ۳۰٪ کاهش یافت"}]}
