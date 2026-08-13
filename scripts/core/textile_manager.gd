extends Node
# ────────────────────────────────────────────────────────────────────────────
# صنعت نساجی و پوشاک — عمق زنجیره نساجی
# پنبه/الیاف، ریسندگی، پوشاک و صادرات. نساجی صنعتی کاربَر است و اشتغال
# انبوه (به‌ویژه زنان) ایجاد می‌کند. برندسازی و صادرات ارزش افزوده می‌سازد.
# پیوند: کشاورزی (پنبه)، SME، آموزش، تجارت، زنجیره تأمین.
#
# state["textile_policy"] = {
#   "raw_material":0..1, "spinning":0..1, "apparel":0..1,
#   "branding":0..1, "last_mill":turn,
#   "output":0..1, "export_share":0..1, "employment":0 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("textile_policy"):
		state["textile_policy"] = {
			"raw_material": 0.35, "spinning": 0.30, "apparel": 0.40,
			"branding": 0.20, "last_mill": -99,
			"output": 0.35, "export_share": 0.20, "employment": 500000,
			"value_added": 0.30, "import_dep": 0.45
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var tp: Dictionary = state["textile_policy"]
	var econ: Dictionary = state.get("economy", {})
	var agri: Dictionary = state.get("agriculture", {})
	var trade: Dictionary = state.get("trade", {})
	var sme: Dictionary = state.get("sme_policy", {})
	var welfare: Dictionary = state.get("welfare", {})

	var raw: float = float(tp.get("raw_material", 0.35))
	var spinning: float = float(tp.get("spinning", 0.30))
	var apparel: float = float(tp.get("apparel", 0.40))
	var branding: float = float(tp.get("branding", 0.20))

	# تولید کل زنجیره
	var output: float = clampf(
		0.15 + raw * 0.25 + spinning * 0.30 + apparel * 0.25 + branding * 0.10, 0.05, 0.95)
	tp["output"] = output

	# ارزش افزوده: پوشاک و برندسازی بالا
	var va: float = clampf(0.20 + apparel * 0.35 + branding * 0.30 + spinning * 0.15, 0.10, 0.95)
	tp["value_added"] = va

	# وابستگی واردات (الیاف/ماشین‌آلات)
	var import_dep: float = clampf(0.70 - raw * 0.30 - spinning * 0.20, 0.15, 0.95)
	tp["import_dep"] = import_dep

	# اشتغال انبوه
	var jobs: int = int(300000.0 + output * 1_200_000.0 + apparel * 300000.0)
	tp["employment"] = jobs

	# سهم صادرات
	var export_share: float = clampf(0.05 + branding * 0.35 + apparel * 0.25 + output * 0.10, 0.02, 0.90)
	tp["export_share"] = export_share

	# اثر اقتصادی
	var gdp: float = float(econ.get("gdp", 1.0))
	econ["gdp"] = gdp * (1.0 + output * 0.0006 + va * 0.0003)
	econ["unemployment"] = clampf(float(econ.get("unemployment", 0.08)) - output * 0.0005, 0.02, 0.30)
	state["economy"] = econ

	# مشارکت زنان (پوشاک کاربَر برای زنان)
	if state.has("care_policy"):
		var care: Dictionary = state["care_policy"]
		care["female_lfp"] = clampf(float(care.get("female_lfp", 0.35)) + apparel * 0.0008, 0.1, 0.85)
		state["care_policy"] = care

	# اگر کشاورزی (پنبه) ضعیف باشد، ماده اولیه آسیب می‌بیند
	# (شبیه‌سازی ساده از طریق امنیت غذایی)

	# رویدادها
	if export_share > 0.55 and Deterministic.chance(0.03):
		events.append({"type": "textile_export", "message": "👗 صادرات پوشاک رشد کرد؛ اشتغال و ارزآوری بالا رفت"})
	elif import_dep > 0.70 and Deterministic.chance(0.04):
		events.append({"type": "raw_shortage", "message": "🧵 کمبود الیاف و پارچه، کارخانه‌ها را زیر ظرفیت برد"})
	elif output > 0.65 and Deterministic.chance(0.02):
		events.append({"type": "textile_jobs", "message": "🧶 توسعه نساجی هزاران شغل ایجاد کرد"})

	state["textile_policy"] = tp
	return {"state": state, "events": events}

func expand_mills(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var tp: Dictionary = state["textile_policy"]
	if turn - int(tp.get("last_mill", -99)) < 5:
		return {"success": false, "reason": "پروژه کارخانه هر ۵ نوبت یک بار", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.005
	tp["last_mill"] = turn
	tp["spinning"] = clampf(float(tp.get("spinning", 0.30)) + 0.15, 0.0, 1.0)
	state["economy"] = econ
	state["textile_policy"] = tp
	return {"success": true, "state": state,
		"events": [{"type": "mills", "message": "🏭 کارخانه‌های ریسندگی و بافندگی توسعه یافت"}]}

func cotton_supply(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var tp: Dictionary = state["textile_policy"]
	tp["raw_material"] = clampf(float(tp.get("raw_material", 0.35)) + 0.15, 0.0, 1.0)
	if state.has("agriculture"):
		state["agriculture"]["yield"] = clampf(state["agriculture"].get("yield", 0.70) + 0.01, 0.2, 1.6)
	state["textile_policy"] = tp
	return {"success": true, "state": state,
		"events": [{"type": "cotton", "message": "🌾 کشت پنبه و تامین الیاف داخلی افزایش یافت"}]}

func apparel_parks(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var tp: Dictionary = state["textile_policy"]
	tp["apparel"] = clampf(float(tp.get("apparel", 0.40)) + 0.15, 0.0, 1.0)
	state["textile_policy"] = tp
	return {"success": true, "state": state,
		"events": [{"type": "apparel", "message": "👕 شهرک پوشاک و تولید صنعتی پوشاک راه‌اندازی شد"}]}

func branding(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var tp: Dictionary = state["textile_policy"]
	var tech: float = float(state.get("technology", {}).get("branch_levels", {}).get("دیجیتال", 0))
	if tech < 3:
		return {"success": false, "reason": "به فناوری دیجیتال سطح ۳ برای برندسازی آنلاین نیاز است", "state": state, "events": []}
	tp["branding"] = clampf(float(tp.get("branding", 0.20)) + 0.15, 0.0, 1.0)
	state["textile_policy"] = tp
	return {"success": true, "state": state,
		"events": [{"type": "branding", "message": "🏷️ برندسازی و صادرات آنلاین پوشاک تقویت شد"}]}
