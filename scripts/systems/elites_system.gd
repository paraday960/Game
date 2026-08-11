extends BaseSystem
# ۳.۵۹ نخبگان - علمی، اقتصادی، فرهنگی، هنری، سیاسی، ورزشی - نفوذ، فرار مغزها، بازگشت

func compute(state: Dictionary, tick: int) -> Dictionary:
	var elites = state.get("elites_detail", {})
	elites["scientific"] = elites.get("scientific", 10000)
	elites["economic"] = elites.get("economic", 50000)
	elites["cultural"] = elites.get("cultural", 20000)
	elites["artistic"] = elites.get("artistic", 15000)
	elites["political_elite"] = elites.get("political_elite", 5000)
	elites["sports_elite"] = elites.get("sports_elite", 3000)
	elites["influence"] = elites.get("influence", 0.60)
	elites["brain_drain"] = elites.get("brain_drain", 0.15)
	elites["return_rate"] = elites.get("return_rate", 0.10)
	elites["satisfaction"] = elites.get("satisfaction", 0.55)
	elites["funding"] = elites.get("funding", 500_000_000.0)
	elites["publications"] = elites.get("publications", 12000)
	elites["patents"] = elites.get("patents", 800)
	elites["network_strength"] = elites.get("network_strength", 0.50)

	var events = []
	var pop_hap = state.get("population", {}).get("happiness", 0.6)
	var gdp_pc = state.get("economy", {}).get("gdp_per_capita", 5000.0)
	var edu = state.get("education", {})
	var tech = state.get("technology", {})
	var pol = state.get("politics", {})
	var culture = state.get("culture", {})

	var stability = pol.get("stability", 0.60)
	var trust = pol.get("trust", 0.55)
	var corruption = pol.get("corruption", 0.30)

	# رضایت نخبگان = ثبات + آزادی + بودجه پژوهش + درآمد
	var research_budget = state.get("economy", {}).get("budget_allocations", {}).get("فناوری", 0.04)
	var satisfaction_target = stability*0.25 + culture.get("media_freedom",0.5)*0.20 + research_budget*2.0*0.20 + (gdp_pc/8000.0)*0.15 + trust*0.20
	elites["satisfaction"] = clamp(elites["satisfaction"]*0.97 + satisfaction_target*0.03, 0.1, 0.95)

	# فرار مغزها = نارضایتی + فساد + محدودیت + اقتصاد ضعیف
	var drain_target = (1.0 - elites["satisfaction"])*0.40 + corruption*0.20 + (1.0 - culture.get("media_freedom",0.5))*0.15 + max(0.0, (5000.0 - gdp_pc)/5000.0)*0.25
	elites["brain_drain"] = clamp(elites["brain_drain"]*0.992 + drain_target*0.008, 0.02, 0.65)

	# نرخ بازگشت - رضایت + رشد
	var return_target = elites["satisfaction"]*0.5 + state.get("economy", {}).get("growth_rate",0.02)*10.0*0.3 + 0.2
	elites["return_rate"] = clamp(elites["return_rate"]*0.995 + return_target*0.005, 0.02, 0.50)

	# نفوذ - تعداد و کیفیت
	var total_elites = elites["scientific"] + elites["economic"] + elites["cultural"] + elites["artistic"] + elites["political_elite"]
	elites["influence"] = clamp(total_elites/100000.0*0.5 + elites["satisfaction"]*0.3 + edu.get("quality",0.55)*0.2, 0.1, 0.95)

	# تامین مالی - GDP
	elites["funding"] *= (1.0 + state.get("economy", {}).get("growth_rate",0.02)*0.5/365.0)
	if tick % 90 == 0 and research_budget > 0.05:
		elites["funding"] += 20_000_000.0

	# انتشارات و پتنت - آموزش و فناوری
	var research_rate = tech.get("research_rate",10.0)
	elites["publications"] = int(elites["scientific"] * 1.2 + research_rate*100.0)
	elites["patents"] = int(elites["scientific"]*0.08 + tech.get("branches",{}).get("صنعت",0.20)*500.0)
	elites["patents"] = max(elites["patents"], 100)

	# شبکه نخبگان - فناوری دیجیتال
	elites["network_strength"] = clamp(elites["network_strength"]*0.995 + state.get("technology",{}).get("branches",{}).get("دیجیتال",0.20)*0.002 + elites["satisfaction"]*0.001, 0.1, 0.95)

	# پویایی تعداد - رشد آموزش
	if tick % 180 == 0:
		if edu.get("quality",0.55) > 0.60:
			elites["scientific"] += Deterministic.next_int_range(100, 300)
			elites["cultural"] += Deterministic.next_int_range(50, 150)
		# فرار مغزها
		var drain_loss = int(elites["scientific"] * elites["brain_drain"] * 0.01)
		elites["scientific"] = max(elites["scientific"] - drain_loss, 2000)
		# بازگشت
		var return_gain = int(drain_loss * elites["return_rate"])
		elites["scientific"] += return_gain

	# رویدادها
	if elites["brain_drain"] > 0.32 and Deterministic.chance(0.015):
		events.append({"type":"brain_drain_elites","drain": elites["brain_drain"], "message":"موج مهاجرت نخبگان - %d دانشمند امسال رفتند" % int(10000*elites["brain_drain"] )})
		elites["scientific"] -= 30

	if elites["satisfaction"] < 0.35 and Deterministic.chance(0.012):
		events.append({"type":"elite_dissatisfaction","satisfaction": elites["satisfaction"], "message":"نارضایتی نخبگان - نامه سرگشاده ۲۰۰ استاد دانشگاه"})

	if elites["patents"] > 1500 and Deterministic.chance(0.008):
		events.append({"type":"patent_boom","patents": elites["patents"], "message":"جهش ثبت اختراع - %d پتنت امسال" % elites["patents"]})

	if elites["return_rate"] > 0.35 and Deterministic.chance(0.010):
		events.append({"type":"brain_gain","return_rate": elites["return_rate"], "message":"موج بازگشت نخبگان - ۵۰۰ متخصص از خارج برگشتند"})

	state["elites_detail"] = elites
	return {"success":true,"state":state,"events":events}
