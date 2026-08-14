extends BaseSystem
# علم و فناوری - ۳.۱۶ - نرخ پژوهش، امتیاز پژوهش، درخت فناوری، شاخه‌ها، بلوغ، سرایت، همکاری

func compute(state: Dictionary, tick: int) -> Dictionary:
	var tech = state.get("technology", {})
	tech["research_points"] = tech.get("research_points", 0.0)
	tech["research_rate"] = tech.get("research_rate", 10.0)
	tech["tree_version"] = tech.get("tree_version", "1.0.0")
	tech["unlocked"] = tech.get("unlocked", ["industry_basic", "agriculture_basic"])
	tech["in_progress"] = tech.get("in_progress", null)
	tech["branches"] = tech.get("branches", {"صنعت":0.20,"انرژی_پاک":0.15,"پزشکی":0.10,"نظامی":0.15,"دیجیتال":0.20,"فضا":0.05})
	# سیستم سطوح ۳۰: مقادیر float سازگاری از سطوح تازه‌سازی می‌شوند
	if tech.has("branch_levels") and tech["branch_levels"] is Dictionary:
		var levels: Dictionary = tech["branch_levels"]
		for branch in ["صنعت","انرژی_پاک","پزشکی","نظامی","دیجیتال","فضا"]:
			if levels.has(branch):
				tech["branches"][branch] = float(clampi(int(levels[branch]),0,30)) / 30.0
	tech["tech_level"] = tech.get("tech_level", 0.15)
	tech["innovation_index"] = tech.get("innovation_index", 0.40)
	tech["researchers"] = tech.get("researchers", 50000)
	tech["labs"] = tech.get("labs", 200)
	tech["universities_research"] = tech.get("universities_research", 80)
	tech["patents_tech"] = tech.get("patents_tech", 800)
	tech["spillover"] = tech.get("spillover", 0.10)
	tech["international_collab"] = tech.get("international_collab", 0.40)

	var events = []
	var econ = state.get("economy", {})
	var edu = state.get("education", {})
	var pop = state.get("population", {})
	var infra = state.get("infrastructure", {})
	var elites = state.get("elites_detail", {})

	var budget = econ.get("budget_allocations", {}).get("فناوری", 0.04) * econ.get("government_spending", 95e9)
	var gdp = econ.get("gdp", 500e9)

	# نرخ تحقیق = f(بودجه R&D، دانشمندان، دانشگاه، آموزش، زیرساخت دیجیتال)
	# (پایه بالاتر برای بالانس «قابل اتمام در ~۱ ساعت»: سطوح ۳۰ شاخه‌های اصلی)
	var base_rate = 26.0
	var budget_factor = (budget / max(econ.get("government_spending",95e9)*0.04, 1.0))
	budget_factor = clamp(budget_factor, 0.2, 3.0)
	var edu_factor = edu.get("quality",0.55)*1.5 + edu.get("literacy",0.85)*0.5
	var infra_factor = infra.get("quality",0.55)*0.5 + infra.get("telecom",0.70)*0.5
	var researcher_factor = tech["researchers"]/50000.0
	var lab_factor = tech["labs"]/200.0*0.5 + 0.5

	# ظرفیت پژوهش نخبگان (دور ۱۳): نخبه کم/زیاد = تحقیق کند/تند (۰.۸× تا ۱.۲۵×)
	var elite_factor = 0.70 + float(tech.get("elite_research_capacity", 0.50)) * 0.55
	tech["research_rate"] = base_rate * budget_factor * edu_factor * infra_factor * researcher_factor * lab_factor * elite_factor
	tech["research_rate"] = clamp(tech["research_rate"], 2.0, 260.0)

	tech["research_points"] += tech["research_rate"] / 365.0

	# تعداد پژوهشگران - آموزش و بودجه
	if tick % 90 == 0:
		if edu.get("quality",0.55) > 0.60 and budget_factor > 1.0:
			tech["researchers"] += Deterministic.next_int_range(200, 800)
			tech["labs"] += Deterministic.next_int_range(1, 5)
		# مهاجرت نخبگان اثر
		var brain_drain = elites.get("brain_drain",0.15) if elites else 0.15
		tech["researchers"] = int(tech["researchers"] * (1.0 - brain_drain*0.002))

	# سطح فناوری کل
	var branch_sum = 0.0
	for v in tech["branches"].values():
		branch_sum += v
	tech["tech_level"] = branch_sum / max(float(tech["branches"].size()),1.0)

	# شاخص نوآوری
	tech["innovation_index"] = clamp(tech["tech_level"]*0.5 + tech["research_rate"]/50.0*0.3 + tech["patents_tech"]/5000.0*0.2, 0.05, 0.95)

	# پیشرفت پژوهش جاری
	if tech["in_progress"] != null:
		var current_id = str(tech["in_progress"])
		var cost = TechnologyManager.get_cost(current_id)
		if tech["research_points"] >= cost:
			tech["research_points"] -= cost
			state["technology"] = tech # برای apply_unlock
			state = TechnologyManager.apply_unlock(state, current_id)
			tech = state["technology"]
			events.append({
				"type":"tech_unlocked","tech": current_id,
				"message":"فناوری «%s» تکمیل شد - جهش فناوری" % TechnologyManager.get_technology_name(current_id)
			})
			tech["in_progress"] = null
			tech["patents_tech"] += Deterministic.next_int_range(20, 80)
			tech["tech_level"] += 0.02
		elif tick % 30 == 0:
			var progress = tech["research_points"]/max(cost,1.0)*100.0
			events.append({
				"type":"research_progress","points": tech["research_points"], "tech": current_id, "progress": progress,
				"message":"پیشرفت پژوهش «%s» - %.0f٪" % [TechnologyManager.get_technology_name(current_id), progress]
			})

	# بلوغ و اشاعه - سرریز فناوری به شاخه‌ها
	for branch in tech["branches"].keys():
		var spill = tech["spillover"] * 0.0001 + tech["tech_level"]*0.00005
		tech["branches"][branch] += spill + Deterministic.next_range(0.0,0.0002)
		tech["branches"][branch] = clamp(tech["branches"][branch], 0.0, 1.0)

	# سرریز بین‌المللی - همکاری
	tech["international_collab"] = clamp(tech["international_collab"] + state.get("diplomacy",{}).get("influence",40.0)/100.0*0.0003, 0.1, 0.90)
	tech["spillover"] = clamp(tech["spillover"] + tech["international_collab"]*0.0004, 0.02, 0.50)

	# پتنت - رشد با نوآوری
	if tick % 60 == 0:
		tech["patents_tech"] += int(tech["research_rate"]*0.5)

	# انتخاب خودکار فناوری اگر خالی - AI داخلی
	if tech["in_progress"] == null and tick % 90 == 0 and Deterministic.chance(0.3):
		var candidates = TechnologyManager.get_available(state)
		if candidates.size() > 0:
			tech["in_progress"] = candidates[Deterministic.next_int_range(0, candidates.size()-1)]

	# رویدادهای فناوری
	if tech["research_rate"] < 3.0 and Deterministic.chance(0.012):
		events.append({"type":"research_stagnation","rate": tech["research_rate"], "message":"رکود پژوهش - بودجه ناکافی"})

	if tech["innovation_index"] > 0.65 and Deterministic.chance(0.008):
		events.append({"type":"innovation_breakthrough","innovation": tech["innovation_index"], "message":"جهش نوآوری - خوشه فناوری شکل گرفت"})

	if tech["tech_level"] > 0.70 and tick % 365 == 0 and Deterministic.chance(0.05):
		events.append({"type":"tech_milestone","level": tech["tech_level"], "message":"سطح فناوری ۷۰٪ - کشور در زمره قدرت‌های نوظهور فناوری"})

	state["technology"] = tech
	
	# ── لایه واقع‌گرایانه اختصاصی فناوری (جایگزین قالب خودکار تکراری) — بخش ۳.۱۶ ──
	# هم‌افزایی شاخه‌ها: دیجیتال کاتالیزور است و بقیه را به‌سوی خود می‌کشد (اثر شبکه‌ای نوآوری)
	var branches: Dictionary = tech.get("branches", {})
	var digital: float = float(branches.get("دیجیتال", 0.20))
	for b_name in branches.keys():
		if b_name != "دیجیتال":
			branches[b_name] = clampf(float(branches[b_name]) + (digital - float(branches[b_name])) * 0.0002, 0.0, 1.0)
	tech["branches"] = branches
	# فرار مغزها: بیکاری بالا و بودجه فناوری پایین ذخیره پژوهش را تحلیل می‌برد
	var brain_drain: float = float(state.get("economy", {}).get("unemployment", 0.08)) * 0.5 - float(state.get("economy", {}).get("budget_allocations", {}).get("فناوری", 0.04))
	tech["research_points"] = maxf(float(tech.get("research_points", 0.0)) - brain_drain * 0.02, 0.0)
	state["technology"] = tech

	return {"success":true,"state":state,"events":events}
