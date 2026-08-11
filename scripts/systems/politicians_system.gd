extends BaseSystem
# ۳.۵۶ سیاست‌مداران - احزاب، جناح‌ها، ایدئولوژی، قطبی‌شدن، پوپولیسم، اعتماد، شفافیت مالی

func compute(state: Dictionary, tick: int) -> Dictionary:
	var pols = state.get("politicians_detail", {})
	pols["parties"] = pols.get("parties", 5)
	pols["factions"] = pols.get("factions", 8)
	pols["ideology_diversity"] = pols.get("ideology_diversity", 0.60)
	pols["polarization"] = pols.get("polarization", 0.40)
	pols["populism"] = pols.get("populism", 0.30)
	pols["trust_politicians"] = pols.get("trust_politicians", 0.40)
	pols["corruption_perceived"] = pols.get("corruption_perceived", state.get("politics", {}).get("corruption", 0.30))
	pols["campaign_finance"] = pols.get("campaign_finance", 100_000_000.0)
	pols["youth_wing"] = pols.get("youth_wing", 0.35)
	pols["women_share"] = pols.get("women_share", 0.15)
	pols["debates_per_month"] = pols.get("debates_per_month", 4.0)
	pols["coalition_stability"] = pols.get("coalition_stability", 0.60)

	var events = []
	var politics = state.get("politics", {})
	var culture = state.get("culture", {})
	var media = culture # افکار عمومی
	var edu = state.get("education", {})
	var judicial = state.get("judicial", {})

	var tension = politics.get("tension", 0.35)
	var stability = politics.get("stability", 0.60)
	var trust = politics.get("trust", 0.55)
	var corruption = politics.get("corruption", 0.30)

	# تنوع ایدئولوژیک - آموزش و آزادی رسانه
	var media_free = culture.get("media_freedom", 0.5)
	pols["ideology_diversity"] = clamp(pols["ideology_diversity"]*0.996 + (media_free*0.4 + edu.get("quality",0.55)*0.3 + 0.3)*0.004, 0.2, 0.95)

	# قطبی‌شدن - تنش + نابرابری - انسجام
	var welfare_gini = state.get("welfare", {}).get("gini", 0.38)
	var cohesion = culture.get("cohesion", 0.65)
	var pol_target = tension*0.4 + welfare_gini*0.3 + (1.0-cohesion)*0.2 + pols["populism"]*0.1
	pols["polarization"] = clamp(pols["polarization"]*0.993 + pol_target*0.007, 0.05, 0.95)

	# پوپولیسم - نارضایتی + نابرابری + بیکاری
	var happiness = state.get("population", {}).get("happiness", 0.6)
	var unemployment = state.get("economy", {}).get("unemployment", 0.08)
	var populism_target = (1.0 - happiness)*0.4 + welfare_gini*0.2 + unemployment*0.2 + (1.0-trust)*0.2
	pols["populism"] = clamp(pols["populism"]*0.992 + populism_target*0.008, 0.05, 0.85)

	# اعتماد به سیاست‌مداران - شفافیت و فساد
	var transparency = state.get("elections", {}).get("transparency", 0.55)
	var trust_target = trust*0.4 + transparency*0.3 + (1.0 - corruption)*0.2 + (1.0 - pols["polarization"])*0.1
	pols["trust_politicians"] = clamp(pols["trust_politicians"]*0.97 + trust_target*0.03, 0.05, 0.90)

	pols["corruption_perceived"] = clamp(corruption*0.6 + (1.0 - judicial.get("rule_of_law",0.60))*0.3 + pols["polarization"]*0.1, 0.05, 0.85)

	# تامین مالی کارزار - ثروت و فساد
	pols["campaign_finance"] *= (1.0 + state.get("economy", {}).get("growth_rate",0.02)/365.0 + corruption*0.0005)

	# جوانان و زنان
	pols["youth_wing"] = clamp(pols["youth_wing"] + state.get("sports_youth", {}).get("participation",0.40)*0.0002, 0.1, 0.70)
	pols["women_share"] = clamp(pols["women_share"] + state.get("family", {}).get("gender_equality",0.45)*0.00015, 0.05, 0.50)

	# مناظرات
	pols["debates_per_month"] = clamp(2.0 + pols["ideology_diversity"]*4.0 + media_free*2.0, 1.0, 12.0)

	# پایداری ائتلاف - قطبی‌شدن معکوس
	pols["coalition_stability"] = clamp(1.0 - pols["polarization"]*0.6 + stability*0.4, 0.1, 0.95)

	# تعدد احزاب - قطبی‌شدن بالا انشعاب
	if tick % 180 == 0 and pols["polarization"] > 0.65 and Deterministic.chance(0.15):
		pols["parties"] += 1
		pols["factions"] += 2

	# رویدادها
	if pols["polarization"] > 0.72 and Deterministic.chance(0.015):
		events.append({"type":"polarization_crisis","polarization": pols["polarization"], "message":"قطبی‌شدن شدید - پارلمان قفل شد، لوایح رای نمی‌آورد"})

	if pols["populism"] > 0.65 and Deterministic.chance(0.012):
		events.append({"type":"populist_wave","populism": pols["populism"], "message":"موج پوپولیستی - شعارهای تند و وعده یارانه سه برابری"})

	if pols["trust_politicians"] < 0.25 and Deterministic.chance(0.011):
		events.append({"type":"trust_politicians_crisis","trust": pols["trust_politicians"], "message":"بی‌اعتمادی به سیاست‌مداران - مشارکت افت کرد"})

	if pols["corruption_perceived"] > 0.65 and Deterministic.chance(0.010):
		events.append({"type":"political_corruption_scandal","corruption": pols["corruption_perceived"], "message":"پرونده فساد نماینده مجلس - افشای رانت ۲ همتی"})

	state["politicians_detail"] = pols
	return {"success":true,"state":state,"events":events}
