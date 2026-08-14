extends Node
# ────────────────────────────────────────────────────────────────────────────
# تحول جمعیتی و پنجره جمعیت — عمق بلندمدت نسل‌ها
# ساختار سنی کشور، سالمندی، پنجره جمعیت، باروری، سن ازدواج و صندوق بازنشستگی
# را شبیه‌سازی می‌کند. پنجره جمعیت (سهم بالای جمعیت فعال) موتور رشد است؛ با
# سالخوردگی، مصرف پس‌انداز افت، بهره‌وری کم و فشار صندوق رشد می‌کند.
# پیوند: جمعیت، رفاه، آموزش، مسکن، بهداشت، اقتصاد، خانواده.
#
# state["demographic_policy"] = {
#   "fertility_incentive":0..1, "childcare":0..1, "elderly_care":0..1,
#   "retraining":0..1, "last_pro_natal":turn, "last_pension":turn,
#   "window":0..1, "aging_index":0..1, "pension_fund":0..1 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("demographic_policy"):
		state["demographic_policy"] = {
			"fertility_incentive": 0.20, "childcare": 0.25, "elderly_care": 0.20,
			"retraining": 0.15, "last_pro_natal": -99, "last_pension": -99,
			"window": 0.55, "aging_index": 0.25, "pension_fund": 0.55,
			"dependency_ratio": 0.45, "median_age": 31.0
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var dp: Dictionary = state["demographic_policy"]
	var pop: Dictionary = state.get("population", {})
	var econ: Dictionary = state.get("economy", {})
	var welfare: Dictionary = state.get("welfare", {})
	var family: Dictionary = state.get("family_policy", state.get("family", {}))
	var edu: Dictionary = state.get("education", {})

	var incentive := float(dp.get("fertility_incentive", 0.20))
	var childcare := float(dp.get("childcare", 0.25))
	var elderly_care := float(dp.get("elderly_care", 0.20))
	var retraining := float(dp.get("retraining", 0.15))

	var age: Dictionary = pop.get("age_structure", {"کودک": 0.25, "جوان": 0.35, "بزرگسال": 0.30, "سالمند": 0.10})
	var working_age := float(age.get("جوان", 0.35)) + float(age.get("بزرگسال", 0.30))
	var children := float(age.get("کودک", 0.25))
	var elderly := float(age.get("سالمند", 0.10))

	# گذار جمعیتی: به‌تدریج سهم سالمند بالا و کودک پایین می‌آید
	var shift := 0.00020 + (1.0 - incentive) * 0.00025
	children = clampf(children - shift, 0.10, 0.40)
	elderly = clampf(elderly + shift * 0.8, 0.05, 0.40)
	working_age = 1.0 - children - elderly
	age["کودک"] = children
	age["سالمند"] = elderly
	age["جوان"] = working_age * 0.55
	age["بزرگسال"] = working_age * 0.45
	pop["age_structure"] = age

	# میانگین سن از سهم سالمندان
	var median_age := 28.0 + elderly * 25.0
	dp["median_age"] = median_age

	# پنجره جمعیت: وقتی جمعیت فعال بالاست و وابستگی پایین
	var dependency := (children + elderly) / maxf(working_age, 0.1)
	var window := clampf(1.0 - abs(dependency - 0.45) * 1.5, 0.0, 1.0)
	dp["window"] = window
	dp["dependency_ratio"] = dependency
	pop["dependency_ratio"] = dependency

	# شاخص سالخوردگی
	var aging := clampf(elderly * 2.2, 0.05, 1.0)
	dp["aging_index"] = aging

	# پنجره جمعیت → بهره‌وری و پس‌انداز؛ سالخوردگی → فشار
	var gdp_growth := window * 0.0008 - aging * 0.0004 + retraining * 0.0003
	# ممیزی GDP (۱۴۰۵): اثر مداوم از کانال مالک-یکتای sector_boosts (نرخ سالانه؛ ماهانه: ×۱۲) (سایت قبلی با ماسک gdp_ از پویش‌ها مخفی مانده بود)
	var dg_boosts: Dictionary = econ.get("sector_boosts", {})
	dg_boosts["پنجرهٔ جمعیت"] = gdp_growth * 12.0
	econ["sector_boosts"] = dg_boosts
	var gdp := float(econ["gdp"])
	econ["savings_rate"] = clampf(0.25 + window * 0.10 - aging * 0.15, 0.05, 0.55)
	state["economy"] = econ

	# صندوق بازنشستگی: شاغلان پول می‌دهند، سالمندان می‌گیرند
	var fund := 0.5 + (working_age - elderly * 1.5) * 0.6 - (1.0 - elderly_care) * 0.2
	fund = clampf(fund, 0.0, 1.0)
	dp["pension_fund"] = fund
	# فشار صندوق → کسری بودجه
	if fund < 0.30:
		econ["national_debt"] = float(econ.get("national_debt", 0.0)) + gdp * (0.30 - fund) * 0.002
		state["economy"] = econ
		welfare["pension_pressure"] = 1.0 - fund
		state["welfare"] = welfare

	# باروری و جمعیت: مشوق + مهدکودک
	var fertility := 1.5 + incentive * 0.6 + childcare * 0.5 + (1.0 - median_age / 50.0) * 0.3
	fertility = clampf(fertility, 0.8, 3.2)
	if family.has("fertility"):
		family["fertility"] = fertility
		state["family"] = family
	# birth_rate و growth_rate متعلق به population_system است (روزانه و از مدل کامل جمعیت)؛
	# بازنویسی ماهانه این مدیر هر بار فقط یک روز دوام می‌آورد و نوسان مصنوعی می‌ساخت — حذف شد.
	# خروجی معنادار این مدیر: family.fertility (خط ۹۲ بالا)
	state["population"] = pop

	# رضایت جوانان/سالمندان
	state["media"]["groups"]["جوانان"]["approval"] = clampf(
		float(state["media"]["groups"]["جوانان"].get("approval", 45.0)) + (childcare + retraining - 0.5) * 0.2, 5.0, 100.0)
	state["media"]["groups"]["بازنشستگان"]["approval"] = clampf(
		float(state["media"]["groups"]["بازنشستگان"].get("approval", 52.0)) + (elderly_care + fund - 0.7) * 0.3, 5.0, 100.0)

	# آموزش بازنشسته/شاغل به بهره‌وری کمک می‌کند
	edu["quality"] = clampf(float(edu.get("quality", 0.55)) + retraining * 0.0005, 0.1, 1.0)
	state["education"] = edu

	# رویدادها
	if window > 0.80 and Deterministic.chance(0.030):
		events.append({"type": "demographic_dividend", "message": "📊 پنجره جمعیت کامل است؛ نیروی کار جوان و پس‌انداز بالا رشد اقتصادی را تقویت می‌کند"})
	elif fund < 0.25 and Deterministic.chance(0.050):
		pop["happiness"] = clampf(float(pop.get("happiness", 0.60)) - 0.008, 0.05, 1.0)
		state["population"] = pop
		events.append({"type": "pension_alarm", "message": "⚠️ صندوق بازنشستگی در آستانه ورشکستگی! اصلاح سن بازنشستگی یا افزایش سهم بیمه لازم است"})
	elif aging > 0.60 and Deterministic.chance(0.030):
		events.append({"type": "aging_society", "message": "👴 جامعه سالخورده می‌شود؛ فشار به درمان و صندوق افزایش می‌یابد"})
	elif fertility > 2.6 and Deterministic.chance(0.020):
		events.append({"type": "baby_boom", "message": "👶 سیاست‌های جمعیتی جواب داد؛ نرخ تولد بالا رفت و موج آینده نیروی کار شکل گرفت"})

	state["demographic_policy"] = dp
	return {"state": state, "events": events}

# ── بسته حمایت از فرزندآوری ──
func pro_natal_package(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var dp: Dictionary = state["demographic_policy"]
	if turn - int(dp.get("last_pro_natal", -99)) < 5:
		return {"success": false, "reason": "بسته حمایت از فرزندآوری هر ۵ نوبت یک بار", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.004
	dp["last_pro_natal"] = turn
	dp["fertility_incentive"] = clampf(float(dp.get("fertility_incentive", 0.20)) + 0.13, 0.0, 1.0)
	state["economy"] = econ
	state["demographic_policy"] = dp
	return {"success": true, "state": state,
		"events": [{"type": "pro_natal", "message": "👶 بسته حمایت از فرزندآوری اعلام شد؛ وام، یارانه و مرخصی زایمان افزایش یافت"}]}

# ── توسعه مهدکودک و مراقبت کودک ──
func expand_childcare(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var dp: Dictionary = state["demographic_policy"]
	if float(dp.get("childcare", 0.25)) >= 0.95:
		return {"success": false, "reason": "پوشش مهدکودک در سقف است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.003
	dp["childcare"] = clampf(float(dp.get("childcare", 0.25)) + 0.15, 0.0, 1.0)
	state["population"]["happiness"] = clampf(state["population"].get("happiness", 0.60) + 0.003, 0.05, 1.0)
	state["economy"] = econ
	state["demographic_policy"] = dp
	return {"success": true, "state": state,
		"events": [{"type": "childcare", "message": "🧸 مهدکودک‌ها و مراکز مراقبت کودک گسترش یافت؛ زنان راحت‌تر وارد بازار کار می‌شوند"}]}

# ── مراقبت سالمندان و بیمه سالمندی ──
func expand_elderly_care(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var dp: Dictionary = state["demographic_policy"]
	if float(dp.get("elderly_care", 0.20)) >= 0.95:
		return {"success": false, "reason": "پوشش مراقبت سالمندان در سقف است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.004
	dp["elderly_care"] = clampf(float(dp.get("elderly_care", 0.20)) + 0.15, 0.0, 1.0)
	dp["pension_fund"] = clampf(float(dp.get("pension_fund", 0.55)) + 0.05, 0.0, 1.0)
	state["economy"] = econ
	state["demographic_policy"] = dp
	return {"success": true, "state": state,
		"events": [{"type": "elderly_care", "message": "👴 مراکز نگهداری و بیمه سالمندی توسعه یافت؛ فشار سالخوردگی مدیریت شد"}]}

# ── بازآموزی نیروی کار ──
func retraining_program(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var dp: Dictionary = state["demographic_policy"]
	if float(dp.get("retraining", 0.15)) >= 0.95:
		return {"success": false, "reason": "برنامه بازآموزی در سقف است", "state": state, "events": []}
	dp["retraining"] = clampf(float(dp.get("retraining", 0.15)) + 0.15, 0.0, 1.0)
	state["economy"]["unemployment"] = clampf(state["economy"].get("unemployment", 0.08) - 0.005, 0.02, 0.30)
	state["education"]["quality"] = clampf(state["education"].get("quality", 0.55) + 0.01, 0.1, 1.0)
	state["demographic_policy"] = dp
	return {"success": true, "state": state,
		"events": [{"type": "retraining", "message": "🎓 بازآموزی مهارتی برای میانسالان و بیکاران برگزار شد؛ تطبیق با فناوری جدید بهتر شد"}]}
