extends Node
# ────────────────────────────────────────────────────────────────────────────
# توسعه روستایی و عشایری — عمق فراتر از شهر
# مهاجرت روستا-شهر، درآمد روستایی، راه‌های روستایی، صنایع تبدیلی، اینترنت
# روستایی، کوچ عشایر و امنیت غذایی. توسعه روستایی فقر، مهاجرت بی‌رویه و حاشیه‌نشینی
# را می‌کاهد. پیوند: کشاورزی، آبخیزداری، مهاجرت، رفاه، زیرساخت، بهداشت.
#
# state["rural_policy"] = {
#   "rural_roads":0..1, "rural_internet":0..1, "agro_processing":0..1,
#   "nomadic_services":0..1, "micro_credit":0..1,
#   "last_road":turn, "rural_pop_share":0..1, "depopulation":0..1 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("rural_policy"):
		state["rural_policy"] = {
			"rural_roads": 0.40, "rural_internet": 0.25, "agro_processing": 0.20,
			"nomadic_services": 0.30, "micro_credit": 0.25,
			"last_road": -99, "rural_pop_share": 0.25, "depopulation": 0.40,
			"rural_income": 0.40, "food_sovereignty": 0.50
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var rp: Dictionary = state["rural_policy"]
	var pop: Dictionary = state.get("population", {})
	var agri: Dictionary = state.get("agriculture", {})
	var econ: Dictionary = state.get("economy", {})
	var welfare: Dictionary = state.get("welfare", {})
	var infra: Dictionary = state.get("infrastructure", {})
	var digital: Dictionary = state.get("digital_policy", {})
	var env: Dictionary = state.get("environment", {})

	var roads := float(rp.get("rural_roads", 0.40))
	var internet := float(rp.get("rural_internet", 0.25))
	var processing := float(rp.get("agro_processing", 0.20))
	var nomad := float(rp.get("nomadic_services", 0.30))
	var credit := float(rp.get("micro_credit", 0.25))

	# جمعیت روستایی: با مهاجرت به شهر کاهش می‌یابد، با توسعه نگه داشته می‌شود
	var urban := float(pop.get("urban_ratio", 0.75))
	var rural_share := 1.0 - urban
	var pull_to_city := 0.0005 - (roads + internet + credit + processing) * 0.00008
	rural_share = clampf(rural_share - pull_to_city, 0.08, 0.60)
	pop["urban_ratio"] = clampf(1.0 - rural_share, 0.40, 0.92)
	rp["rural_pop_share"] = rural_share

	# depopulation: هرچه سهم جوان کمتر و خدمات کم، مهاجرت بیشتر
	var depop := clampf(0.5 - (roads + internet + credit + processing) * 0.10, 0.05, 0.85)
	rp["depopulation"] = depop
	pop["migration_net"] = int(float(pop.get("migration_net", 10000)) - depop * 8000.0)

	# درآمد روستایی و فقر
	var income := clampf(
		0.20 + roads * 0.15 + processing * 0.25 + credit * 0.15 +
		internet * 0.10 + float(agri.get("yield", 0.70)) * 0.15, 0.05, 0.95)
	rp["rural_income"] = income
	welfare["poverty"] = clampf(float(welfare.get("poverty", 0.15)) - (income - 0.40) * 0.0008, 0.02, 0.80)
	state["welfare"] = welfare

	# صنایع تبدیلی → ارزش افزوده بخش کشاورزی + امنیت غذایی
	agri["yield"] = clampf(float(agri.get("yield", 0.70)) * 0.998 + processing * 0.002, 0.2, 1.5)
	var food_sov := clampf(
		float(agri.get("food_security", 0.85)) * 0.99 +
		(rural_share * 0.3 + processing * 0.3 + roads * 0.2) * 0.01, 0.1, 0.98)
	rp["food_sovereignty"] = food_sov
	state["agriculture"] = agri

	# اقتصاد
	var gdp := float(econ.get("gdp", 1.0))
	econ["gdp"] = gdp * (1.0 + (income - 0.40) * 0.0003 + processing * 0.0002)
	econ["unemployment"] = clampf(float(econ.get("unemployment", 0.08)) - credit * 0.0002 - processing * 0.0002, 0.02, 0.30)
	state["economy"] = econ

	# اینترنت روستایی به پوشش دیجیتال کمک می‌کند
	digital["internet_coverage"] = clampf(float(digital.get("internet_coverage", 0.5)) + internet * 0.0005, 0.0, 1.0)
	state["digital_policy"] = digital

	# اثر جمعیتی: مهاجرت کنترل‌شده رضایت روستایی
	if state["media"]["groups"].has("روستاییان"):
		state["media"]["groups"]["روستاییان"]["approval"] = clampf(
			float(state["media"]["groups"]["روستاییان"].get("approval", 50.0)) + (income - 0.40) * 0.15, 5.0, 100.0)

	# حاشیه‌نشینی و فقر شهری: مهاجرت بی‌رویه
	if depop > 0.60:
		state["welfare"]["poverty"] = clampf(float(state["welfare"].get("poverty", 0.15)) + 0.0005, 0.02, 0.80)
		pop["happiness"] = clampf(float(pop.get("happiness", 0.60)) - 0.002, 0.05, 1.0)
		state["population"] = pop
		state["welfare"] = welfare

	# رویدادها
	if depop > 0.65 and Deterministic.chance(0.05):
		events.append({"type": "rural_depopulation", "message": "🏚️ تخلیه روستاها شتاب گرفت؛ حاشیه‌نشینی در شهرها و کمبود نیروی کشاورز افزایش یافت"})
	elif income > 0.65 and Deterministic.chance(0.03):
		events.append({"type": "rural_revival", "message": "🌾 رونق روستایی! صنایع تبدیلی و وام‌های خرد مهاجرت معکوس را آغاز کردند"})
	elif nomad > 0.55 and Deterministic.chance(0.025):
		events.append({"type": "nomadic_fair", "message": "🐑 خدمات عشایری و نمایشگاه صنایع دستی عشایر گردشگری و رضایت را بالا برد"})

	state["rural_policy"] = rp
	state["population"] = pop
	return {"state": state, "events": events}

# ── راه روستایی و پل ──
func build_rural_roads(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var rp: Dictionary = state["rural_policy"]
	if turn - int(rp.get("last_road", -99)) < 5:
		return {"success": false, "reason": "پروژه راه روستایی هر ۵ نوبت یک بار", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["government_spending"] = float(econ.get("government_spending", 0.0)) + float(econ.get("gdp", 1.0)) * 0.004
	rp["last_road"] = turn
	rp["rural_roads"] = clampf(float(rp.get("rural_roads", 0.40)) + 0.13, 0.0, 1.0)
	state["infrastructure"]["quality"] = clampf(state["infrastructure"].get("quality", 0.55) + 0.005, 0.1, 1.0)
	state["economy"] = econ
	state["rural_policy"] = rp
	return {"success": true, "state": state,
		"events": [{"type": "rural_roads", "message": "🛣️ راه و پل روستایی آسفالت شد؛ دسترسی به بازار و مدرسه بهتر شد"}]}

# ── اینترنت روستایی ──
func expand_rural_internet(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var rp: Dictionary = state["rural_policy"]
	if float(rp.get("rural_internet", 0.25)) >= 0.95:
		return {"success": false, "reason": "اینترنت روستایی در سقف است", "state": state, "events": []}
	var tech := float(state.get("technology", {}).get("branch_levels", {}).get("دیجیتال", 0))
	if tech < 4:
		return {"success": false, "reason": "به فناوری دیجیتال سطح ۴ نیاز است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["government_spending"] = float(econ.get("government_spending", 0.0)) + float(econ.get("gdp", 1.0)) * 0.003
	rp["rural_internet"] = clampf(float(rp.get("rural_internet", 0.25)) + 0.15, 0.0, 1.0)
	state["economy"] = econ
	state["rural_policy"] = rp
	return {"success": true, "state": state,
		"events": [{"type": "rural_internet", "message": "📡 اینترنت پرسرعت به روستاها رسید؛ بازار آنلاین محصولات کشاورزی راه افتاد"}]}

# ── صنایع تبدیلی ──
func build_agro_processing(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var rp: Dictionary = state["rural_policy"]
	if float(rp.get("agro_processing", 0.20)) >= 0.95:
		return {"success": false, "reason": "صنایع تبدیلی در سقف است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["government_spending"] = float(econ.get("government_spending", 0.0)) + float(econ.get("gdp", 1.0)) * 0.004
	rp["agro_processing"] = clampf(float(rp.get("agro_processing", 0.20)) + 0.15, 0.0, 1.0)
	econ["unemployment"] = clampf(float(econ.get("unemployment", 0.08)) - 0.0005, 0.02, 0.30)
	state["economy"] = econ
	state["rural_policy"] = rp
	return {"success": true, "state": state,
		"events": [{"type": "agro_processing", "message": "🏭 کارخانه صنایع تبدیلی کشاورزی در منطقه روستایی افتتاح شد؛ ضایعات کم و ارزش افزوده بیشتر شد"}]}

# ── خدمات عشایری و وام خرد ──
func support_nomads(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var rp: Dictionary = state["rural_policy"]
	if float(rp.get("nomadic_services", 0.30)) >= 0.95:
		return {"success": false, "reason": "خدمات عشایری در سقف است", "state": state, "events": []}
	rp["nomadic_services"] = clampf(float(rp.get("nomadic_services", 0.30)) + 0.15, 0.0, 1.0)
	rp["micro_credit"] = clampf(float(rp.get("micro_credit", 0.25)) + 0.05, 0.0, 1.0)
	state["tourism"]["revenue"] = state["tourism"].get("revenue", 0.0) * 1.005
	state["welfare"]["poverty"] = clampf(state["welfare"].get("poverty", 0.15) - 0.002, 0.02, 0.80)
	state["rural_policy"] = rp
	return {"success": true, "state": state,
		"events": [{"type": "nomad_support", "message": "🐑 خدمات کوچ، بهداشت سیار، آب‌رسانی و وام خرد عشایر گسترش یافت"}]}
