extends Node
# ────────────────────────────────────────────────────────────────────────────
# هوش مصنوعی و اتوماسیون صنعتی — عمق انقلاب صنعتی چهارم
# پذیرش هوش مصنوعی، رباتیک، اتوماسیون خط تولید و مهارت‌آموزی نیروی کار.
# AI بهره‌وری را بالا می‌برد اما مشاغل ساده را جابه‌جا می‌کند؛ بدون مهارت‌آموزی
# بیکاری بالا می‌رود. پیوند: فناوری، صنعت، آموزش، اشتغال، پژوهش.
#
# state["ai_policy"] = {
#   "adoption":0..1, "robotics":0..1, "reskilling":0..1,
#   "data_infra":0..1, "last_program":turn,
#   "productivity":0..1, "job_displacement":0..1 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("ai_policy"):
		state["ai_policy"] = {
			"adoption": 0.10, "robotics": 0.10, "reskilling": 0.20,
			"data_infra": 0.20, "last_program": -99,
			"productivity": 0.15, "job_displacement": 0.0,
			"ai_exports": 0.0, "ethics": 0.40
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var ap: Dictionary = state["ai_policy"]
	var econ: Dictionary = state.get("economy", {})
	var tech: Dictionary = state.get("technology", {})
	var higher_ed: Dictionary = state.get("higher_ed_policy", {})

	var adoption: float = float(ap.get("adoption", 0.10))
	var robotics: float = float(ap.get("robotics", 0.10))
	var reskill: float = float(ap.get("reskilling", 0.20))
	var data_infra: float = float(ap.get("data_infra", 0.20))

	var digital_level: float = clampf(float(tech.get("branch_levels", {}).get("دیجیتال", 0)) / 30.0, 0.0, 1.0)

	var productivity: float = clampf(
		0.10 + adoption * 0.40 + robotics * 0.25 + digital_level * 0.20 + data_infra * 0.10, 0.05, 0.98)
	ap["productivity"] = productivity

	var displacement: float = clampf(
		(robotics * 0.40 + adoption * 0.30) - reskill * 0.50, 0.0, 0.85)
	ap["job_displacement"] = displacement

	var research_innov: float = float(state.get("research_policy", {}).get("innovation_index", 0.20))
	ap["ai_exports"] = clampf(adoption * 0.30 + research_innov * 0.30 + digital_level * 0.20, 0.0, 0.90)

	var gdp: float = float(econ.get("gdp", 1.0))
	# ممیزی GDP (۱۴۰۵): اثر مداوم از کانال مالک-یکتای sector_boosts (نرخ سالانه؛ ماهانه: ×۱۲)
	var ai_boosts: Dictionary = econ.get("sector_boosts", {})
	ai_boosts["هوش مصنوعی و رباتیک"] = productivity * 0.0008 * 12.0
	econ["sector_boosts"] = ai_boosts
	econ["unemployment"] = clampf(float(econ.get("unemployment", 0.08)) + displacement * 0.002 - reskill * 0.001, 0.02, 0.40)
	state["economy"] = econ

	if tech.has("research_rate"):
		tech["research_rate"] = float(tech.get("research_rate", 10.0)) * (1.0 + adoption * 0.003)
		state["technology"] = tech

	if not higher_ed.is_empty():
		higher_ed["quality"] = clampf(float(higher_ed.get("quality", 0.35)) + adoption * 0.0005, 0.0, 1.0)
		state["higher_ed_policy"] = higher_ed

	if displacement > 0.50 and reskill < 0.35 and Deterministic.chance(0.04):
		# اثر واقعی اعتراض به اتوماسیون: توقف خطوط و تنش اجتماعی
		econ["gdp"] = float(econ.get("gdp", gdp)) * (1.0 - 0.0003)
		state["economy"] = econ
		var pol2: Dictionary = state.get("politics", {})
		pol2["stability"] = clampf(float(pol2.get("stability", 0.60)) - 0.015, 0.05, 1.0)
		state["politics"] = pol2
		events.append({"type": "automation_protest", "message": "🤖 اعتراض به اتوماسیون؛ مشاغل بدون مهارت‌آموزی حذف شدند"})
	elif productivity > 0.60 and Deterministic.chance(0.025):
		var sb_ai: Dictionary = state.get("economy", {}).get("sector_boosts", {})
		sb_ai["هوش مصنوعی و رباتیک"] = float(sb_ai.get("هوش مصنوعی و رباتیک", 0.0)) + 0.0004 * 12.0
		state["economy"]["sector_boosts"] = sb_ai
		events.append({"type": "ai_boom", "message": "🧠 بهره‌وری صنعتی با هوش مصنوعی جهش کرد"})

	state["ai_policy"] = ap
	return {"state": state, "events": events}

func adopt_ai(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var ap: Dictionary = state["ai_policy"]
	if turn - int(ap.get("last_program", -99)) < 5:
		return {"success": false, "reason": "برنامه پذیرش AI هر ۵ نوبت یک بار", "state": state, "events": []}
	var tech_level: float = float(state.get("technology", {}).get("branch_levels", {}).get("دیجیتال", 0))
	if tech_level < 6:
		return {"success": false, "reason": "به فناوری دیجیتال سطح ۶ نیاز است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.004
	ap["last_program"] = turn
	ap["adoption"] = clampf(float(ap.get("adoption", 0.10)) + 0.15, 0.0, 1.0)
	state["economy"] = econ
	state["ai_policy"] = ap
	return {"success": true, "state": state,
		"events": [{"type": "ai_adopt", "message": "🤖 برنامه پذیرش هوش مصنوعی در صنعت آغاز شد"}]}

func industrial_robotics(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var ap: Dictionary = state["ai_policy"]
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.005
	ap["robotics"] = clampf(float(ap.get("robotics", 0.10)) + 0.15, 0.0, 1.0)
	state["economy"] = econ
	state["ai_policy"] = ap
	return {"success": true, "state": state,
		"events": [{"type": "robotics", "message": "🦾 رباتیک صنعتی در خط تولید مستقر شد"}]}

func reskilling_program(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var ap: Dictionary = state["ai_policy"]
	ap["reskilling"] = clampf(float(ap.get("reskilling", 0.20)) + 0.15, 0.0, 1.0)
	if state.has("education"):
		var edu: Dictionary = state["education"]
		edu["quality"] = clampf(float(edu.get("quality", 0.55)) + 0.01, 0.0, 1.0)
		state["education"] = edu
	state["ai_policy"] = ap
	return {"success": true, "state": state,
		"events": [{"type": "reskill", "message": "🎓 برنامه مهارت‌آموزی نیروی کار برای عصر دیجیتال آغاز شد"}]}

func data_infrastructure(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var ap: Dictionary = state["ai_policy"]
	var tech_level: float = float(state.get("technology", {}).get("branch_levels", {}).get("دیجیتال", 0))
	if tech_level < 5:
		return {"success": false, "reason": "به فناوری دیجیتال سطح ۵ نیاز است", "state": state, "events": []}
	ap["data_infra"] = clampf(float(ap.get("data_infra", 0.20)) + 0.15, 0.0, 1.0)
	state["ai_policy"] = ap
	return {"success": true, "state": state,
		"events": [{"type": "data_infra", "message": "🛰️ زیرساخت داده و ابر ملی توسعه یافت"}]}
