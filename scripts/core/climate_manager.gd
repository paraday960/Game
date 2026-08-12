extends Node
# ────────────────────────────────────────────────────────────────────────────
# اقلیم و محیط زیست — عمق پایداری
# آلودگی (هوا/صنعت/کربن)، بلایای طبیعی (سیل/زلزله/خشکسالی با عوامل جغرافیایی)،
# مالیات کربن، جنگل‌کاری و آمادگی بلایا. پیوند: انرژی، کشاورزی، بهداشت،
# فرهنگ (تصویر سبز)، سازمان‌ها (رأی پیمان اقلیمی)، فساد.
#
# state["climate_policy"] = { "carbon_tax":0..1, "reforestation":0..1,
#   "disaster_readiness":0..1, "pollution":0..1, "disasters_handled":0 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("climate_policy"):
		state["climate_policy"] = {"carbon_tax": 0.1, "reforestation": 0.2, "disaster_readiness": 0.3, "pollution": 0.5, "disasters_handled": 0}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var cp: Dictionary = state["climate_policy"]
	var econ: Dictionary = state.get("economy", {})
	var env: Dictionary = state.get("environment", {})
	var resources: Dictionary = state.get("resources", {})
	var pop: Dictionary = state.get("population", {})
	var carbon := float(cp.get("carbon_tax", 0.1))
	var reforest := float(cp.get("reforestation", 0.2))
	var readiness := float(cp.get("disaster_readiness", 0.3))
	var pollution := float(cp.get("pollution", 0.5))
	var industrial := float(state.get("industry_policy", {}).get("soe_share", 0.3))
	var fossil := float(state.get("energy_policy", {}).get("mix", {}).get("fossil", 0.7))

	# آلودگی: صنعت + فسیلی − مالیات کربن − جنگل‌کاری
	pollution = clampf(pollution + industrial * 0.02 + fossil * 0.015 - carbon * 0.03 - reforest * 0.02, 0.05, 0.95)
	cp["pollution"] = pollution
	env["pollution_level"] = pollution
	state["environment"] = env

	# مالیات کربن: درآمد + فشار صنعت (نخبگان ناراضی، فناوری سبز تشویق)
	econ["carbon_revenue"] = carbon * 0.001
	econ["national_debt"] = maxf(0.0, float(econ.get("national_debt", 0.0)) - float(econ.get("gdp", 1.0)) * carbon * 0.0005)
	var factions: Dictionary = state.get("factions", {})
	if factions.has("نخبگان اقتصادی"):
		var f: Dictionary = factions["نخبگان اقتصادی"]
		f["loyalty"] = clampf(float(f.get("loyalty", 50.0)) - carbon * 0.5, 0.0, 100.0)
		factions["نخبگان اقتصادی"] = f
		state["factions"] = factions
	# آلودگی بالا → سلامت و رضایت
	if pollution > 0.7:
		state["health"]["quality"] = clampf(float(state["health"].get("quality", 0.6)) - 0.002, 0.1, 1.0)
		pop["happiness"] = clampf(float(pop.get("happiness", 0.6)) - 0.005, 0.05, 1.0)

	# بلایای طبیعی: عوامل جغرافیایی کشور + آمادگی
	var flood := float(state.get("country", {}).get("flood_factor", 0.3)) * (1.0 - readiness)
	var quake := float(state.get("country", {}).get("heat_factor", 0.2)) * (1.0 - readiness) * 0.5
	var drought_risk := (1.0 - float(resources.get("inventory", {}).get("آب", 90.0)) / 100.0) * (1.0 - readiness)
	if Deterministic.chance(clampf(flood * 0.1, 0.01, 0.12)):
		var loss := 0.006 * (1.0 - readiness)
		econ["gdp"] = float(econ.get("gdp", 1.0)) * (1.0 - loss)
		cp["disasters_handled"] = int(cp.get("disasters_handled", 0)) + 1
		events.append({"type": "flood_disaster", "message": "🌊 سیل ویرانگر! آمادگی پایین خسارت را بزرگ کرد" if readiness < 0.4 else "🌊 سیل رخ داد ولی آمادگی بالا خسارت را مهار کرد"})
	if Deterministic.chance(clampf(quake * 0.08, 0.005, 0.08)):
		econ["gdp"] = float(econ.get("gdp", 1.0)) * 0.995
		cp["disasters_handled"] = int(cp.get("disasters_handled", 0)) + 1
		events.append({"type": "quake_disaster", "message": "🏚️ زمین‌لرزه آسیب زد؛ زیرساخت‌ها نیازمند بازسازی‌اند"})

	state["climate_policy"] = cp
	state["economy"] = econ
	state["population"] = pop
	return {"state": state, "events": events}

func set_carbon_tax(state: Dictionary, level: float) -> Dictionary:
	state = ensure(state)
	if level < 0.0 or level > 1.0:
		return {"success": false, "reason": "سطح نامعتبر", "state": state, "events": []}
	var cp: Dictionary = state["climate_policy"]
	cp["carbon_tax"] = level
	state["climate_policy"] = cp
	# فناوری سبز را تشویق می‌کند
	state["technology"]["branches"]["انرژی_پاک"] = clampf(float(state["technology"]["branches"].get("انرژی_پاک", 0.15)) + level * 0.01, 0.0, 1.0)
	return {"success": true, "state": state,
		"events": [{"type": "carbon_tax", "message": "🏭 مالیات کربن به %s٪ تنظیم شد؛ آلودگی کم‌تر و درآمد سبز بیشتر" % PersianFormatter.to_persian_digits(str(int(level * 100.0)))}]}

func reforest(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var cp: Dictionary = state["climate_policy"]
	if float(cp.get("reforestation", 0.2)) >= 0.95:
		return {"success": false, "reason": "جنگل‌کاری حداکثری است", "state": state, "events": []}
	state["economy"]["national_debt"] = float(state["economy"].get("national_debt", 0.0)) + float(state["economy"].get("gdp", 1.0)) * 0.002
	cp["reforestation"] = clampf(float(cp.get("reforestation", 0.2)) + 0.15, 0.0, 1.0)
	state["climate_policy"] = cp
	return {"success": true, "state": state,
		"events": [{"type": "reforest", "message": "🌳 طرح ملی جنگل‌کاری و احیای مراتع گسترش یافت؛ ریه‌های زمین بازگشتند"}]}

func disaster_preparedness(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var cp: Dictionary = state["climate_policy"]
	if float(cp.get("disaster_readiness", 0.3)) >= 0.95:
		return {"success": false, "reason": "آمادگی بلایا حداکثری است", "state": state, "events": []}
	state["economy"]["national_debt"] = float(state["economy"].get("national_debt", 0.0)) + float(state["economy"].get("gdp", 1.0)) * 0.003
	cp["disaster_readiness"] = clampf(float(cp.get("disaster_readiness", 0.3)) + 0.2, 0.0, 1.0)
	state["climate_policy"] = cp
	return {"success": true, "state": state,
		"events": [{"type": "disaster_prep", "message": "🚨 سامانه هشدار سیل/زلزله، بیمه بلایا و ذخیره امدادی راه‌اندازی شد؛ خسارت بلایا مهار می‌شود"}]}

func green_city_plan(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var cp: Dictionary = state["climate_policy"]
	var econ: Dictionary = state.get("economy", {})
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * 0.003
	state["economy"] = econ
	cp["pollution"] = clampf(float(cp.get("pollution", 0.5)) - 0.1, 0.05, 0.95)
	state["climate_policy"] = cp
	# تصویر سبز: قدرت نرم و محبوبیت
	state["culture_policy"]["soft_power"] = clampf(float(state["culture_policy"].get("soft_power", 40.0)) + 2.0, 5.0, 100.0)
	state["leader"]["popularity_world"] = clampf(float(state["leader"].get("popularity_world", 50.0)) + 1.0, 0.0, 100.0)
	return {"success": true, "state": state,
		"events": [{"type": "green_city", "message": "🌿 طرح «شهر سبز»: فضای سبز شهری، حمل‌ونقل پاک و ساختمان سبز — جهان تحسین کرد"}]}
