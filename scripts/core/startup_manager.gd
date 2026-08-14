extends Node
# ────────────────────────────────────────────────────────────────────────────
# کسب‌وکارهای نوپا و زیست‌بوم فناوری — عمق اقتصاد دانش‌بنیان
# شتاب‌دهنده‌ها، مراکز رشد، تأمین مالی خطرپذیر (VC) و فرار مغزها معکوس.
# شرکت‌های دانش‌بنیان بهره‌وری، صادرات فناوری و اشتغال جوانان را بالا می‌برند
# اما نرخ شکست بالایی دارند. پیوند: فناوری، آموزش، سرمایه‌گذاری، پژوهش.
#
# state["startup_policy"] = {
#   "accelerators":0..1, "vc_funding":0..1, "incubators":0..1,
#   "regulatory_sandbox":0..1, "last_fund":turn,
#   "startups":0, "unicorns":0, "innovation_rate":0..1 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("startup_policy"):
		state["startup_policy"] = {
			"accelerators": 0.20, "vc_funding": 0.15, "incubators": 0.25,
			"regulatory_sandbox": 0.10, "last_fund": -99,
			"startups": 100, "unicorns": 0, "innovation_rate": 0.20,
			"failure_rate": 0.50, "tech_exports": 0.10
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var sp: Dictionary = state["startup_policy"]
	var tech: Dictionary = state.get("technology", {})
	var research: Dictionary = state.get("research_policy", {})
	var edu: Dictionary = state.get("education", {})
	var econ: Dictionary = state.get("economy", {})
	var digital: Dictionary = state.get("digital_policy", {})
	var gdp: float = float(econ.get("gdp", 1.0))

	var accelerators: float = float(sp.get("accelerators", 0.20))
	var vc: float = float(sp.get("vc_funding", 0.15))
	var incubators: float = float(sp.get("incubators", 0.25))
	var sandbox: float = float(sp.get("regulatory_sandbox", 0.10))
	var digital_level: float = float(digital.get("internet_coverage", 0.5))
	var innovation_research: float = float(research.get("innovation_index", 0.30))

	# نرخ نوآوری: زیرساخت + تأمین مالی + تحقیق + مقررات
	var innovation: float = clampf(
		0.05 + accelerators * 0.20 + vc * 0.20 + incubators * 0.15 +
		sandbox * 0.15 + digital_level * 0.15 + innovation_research * 0.15,
		0.05, 0.98)
	sp["innovation_rate"] = innovation

	# تعداد استارتاپ‌ها از نرخ نوآوری و آموزش
	var edu_quality: float = float(edu.get("quality", 0.55))
	var new_startups: int = int(innovation * 80.0 + edu_quality * 30.0)
	var failures: int = int(float(sp.get("startups", 100)) * (0.6 - vc * 0.2 - incubators * 0.1))
	var current: int = int(sp.get("startups", 100))
	current = maxi(50, current + new_startups - failures)
	sp["startups"] = current
	sp["failure_rate"] = clampf(0.60 - vc * 0.20 - incubators * 0.10, 0.10, 0.80)

	# یونیکورن‌ها به‌ندرت و با تأمین مالی بالا
	if vc > 0.5 and innovation > 0.5 and Deterministic.chance(0.015):
		sp["unicorns"] = int(sp.get("unicorns", 0)) + 1

	# صادرات فناوری
	var tech_export: float = clampf(innovation * 0.4 + vc * 0.2 + float(sp.get("unicorns", 0)) * 0.05, 0.0, 0.95)
	sp["tech_exports"] = tech_export
	# ممیزی ذخایر (۱۴۰۵): ورودی ماهانه به کانال reserve_inflows (مالک: بانک مرکزی)
	var su_infl: Dictionary = econ.get("reserve_inflows", {})
	su_infl["صادرات فناوری استارتاپی"] = gdp * tech_export * 0.0005
	econ["reserve_inflows"] = su_infl

	# اثر اقتصادی: بهره‌وری و اشتغال
	# ممیزی GDP (۱۴۰۵): اثر مداوم از کانال مالک-یکتای sector_boosts (نرخ سالانه؛ ماهانه: ×۱۲)
	var su_boosts: Dictionary = econ.get("sector_boosts", {})
	su_boosts["اکوسیستم استارتاپ"] = (innovation * 0.0008 + tech_export * 0.0003) * 12.0
	econ["sector_boosts"] = su_boosts
	econ["unemployment"] = clampf(float(econ.get("unemployment", 0.08)) - innovation * 0.0003, 0.02, 0.30)
	state["economy"] = econ

	# فناوری اصلی: سرعت پژوهش
	if tech.has("branch_levels") and tech["branch_levels"].has("دیجیتال"):
		tech["research_rate"] = float(tech.get("research_rate", 10.0)) * (1.0 + innovation * 0.002)
		state["technology"] = tech

	# رویدادها
	if innovation > 0.70 and Deterministic.chance(0.03):
		events.append({"type": "startup_boom", "message": "🚀 زیست‌بوم استارتاپی منفجر شد؛ شرکت‌های دانش‌بنیان صادرات فناوری را جهش دادند"})
	elif failures > new_startups and Deterministic.chance(0.04):
		events.append({"type": "startup_winter", "message": "❄️ زمستان استارتاپی! کمبود نقدینگی و ریسک‌گریزی شرکت‌ها را تعطیل کرد"})
	elif int(sp.get("unicorns", 0)) > 0 and Deterministic.chance(0.02):
		events.append({"type": "unicorn", "message": "🦄 یک شرکت ملی به ارزش یک میلیارد دلار رسید؛ اعتبار فناوری کشور بالا رفت"})

	state["startup_policy"] = sp
	return {"state": state, "events": events}

# ── صندوق خطرپذیر دولتی ──
func fund_vc(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["startup_policy"]
	if turn - int(sp.get("last_fund", -99)) < 6:
		return {"success": false, "reason": "صندوق خطرپذیر هر ۶ نوبت یک بار", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.003
	sp["last_fund"] = turn
	sp["vc_funding"] = clampf(float(sp.get("vc_funding", 0.15)) + 0.15, 0.0, 1.0)
	state["economy"] = econ
	state["startup_policy"] = sp
	return {"success": true, "state": state,
		"events": [{"type": "vc_fund", "message": "💰 صندوق خطرپذیر دولتی شرکت‌های نوپا را تأمین مالی کرد"}]}

# ── شتاب‌دهنده و مرکز رشد ──
func build_accelerator(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["startup_policy"]
	if float(sp.get("accelerators", 0.20)) >= 0.95:
		return {"success": false, "reason": "شتاب‌دهنده‌ها در سقف هستند", "state": state, "events": []}
	sp["accelerators"] = clampf(float(sp.get("accelerators", 0.20)) + 0.15, 0.0, 1.0)
	sp["incubators"] = clampf(float(sp.get("incubators", 0.25)) + 0.05, 0.0, 1.0)
	state["startup_policy"] = sp
	return {"success": true, "state": state,
		"events": [{"type": "accelerator", "message": "🚀 مراکز شتاب‌دهی و رشد توسعه یافتند"}]}

# ── سندباکس مقرراتی ──
func regulatory_sandbox(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["startup_policy"]
	var tech_level: float = float(state.get("technology", {}).get("branch_levels", {}).get("دیجیتال", 0))
	if tech_level < 4:
		return {"success": false, "reason": "به فناوری دیجیتال سطح ۴ نیاز است", "state": state, "events": []}
	if float(sp.get("regulatory_sandbox", 0.10)) >= 0.95:
		return {"success": false, "reason": "سندباکس مقرراتی در سقف است", "state": state, "events": []}
	sp["regulatory_sandbox"] = clampf(float(sp.get("regulatory_sandbox", 0.10)) + 0.15, 0.0, 1.0)
	state["startup_policy"] = sp
	return {"success": true, "state": state,
		"events": [{"type": "sandbox", "message": "📜 سندباکس مقرراتی برای نوآوری باز شد؛ استارتاپ‌ها مقررات دست‌وپاگیر را دور می‌زنند"}]}

# ── معکوس‌سازی فرار مغزها ──
func reverse_brain_drain(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["startup_policy"]
	var research: Dictionary = state.get("research_policy", {})
	if not research.is_empty():
		research["brain_drain"] = clampf(float(research.get("brain_drain", 0.28)) - 0.05, 0.05, 0.80)
		state["research_policy"] = research
	sp["innovation_rate"] = clampf(float(sp.get("innovation_rate", 0.20)) + 0.05, 0.0, 1.0)
	state["population"]["migration_net"] = int(float(state["population"].get("migration_net", 10000)) + 5000)
	state["startup_policy"] = sp
	return {"success": true, "state": state,
		"events": [{"type": "reverse_drain", "message": "🧑‍💻 برنامه بازگشت نخبگان فناوری اجرا شد؛ مغزهای مهاجر به اکوسیستم پیوستند"}]}
