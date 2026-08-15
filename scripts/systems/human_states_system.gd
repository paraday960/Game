extends BaseSystem
# ۳.۶۶ حالات انسانی - شادی، استرس، امید، ترس، خشم، اعتماد، غرور ملی، سلامت روان، همبستگی، فرسودگی

func compute(state: Dictionary, tick: int) -> Dictionary:
	var human = state.get("human_states", {})
	human["happiness_avg"] = human.get("happiness_avg", state.get("population", {}).get("happiness", 0.60))
	human["stress"] = human.get("stress", 0.35)
	human["hope"] = human.get("hope", 0.60)
	human["fear"] = human.get("fear", state.get("politics", {}).get("tension", 0.35))
	human["anger"] = human.get("anger", 0.20)
	human["trust"] = human.get("trust", state.get("politics", {}).get("trust", 0.55))
	human["national_pride"] = human.get("national_pride", state.get("culture", {}).get("cohesion", 0.65))
	human["mental_health"] = human.get("mental_health", state.get("health", {}).get("mental_health", 0.60) if state.get("health", {}).has("mental_health") else 0.60)
	human["solidarity"] = human.get("solidarity", 0.60)
	human["burnout"] = human.get("burnout", 0.25)
	human["loneliness"] = human.get("loneliness", 0.30)
	human["resilience_psy"] = human.get("resilience_psy", 0.55)
	human["optimism_economy"] = human.get("optimism_economy", 0.55)
	human["collective_memory"] = human.get("collective_memory", [])

	var events = []
	var pop = state.get("population", {})
	var pol = state.get("politics", {})
	var econ = state.get("economy", {})
	var culture = state.get("culture", {})
	var security = state.get("security", {})
	var welfare = state.get("welfare", {})
	var health = state.get("health", {})

	var happiness = pop.get("happiness", 0.60)
	var tension = pol.get("tension", 0.35)
	var trust = pol.get("trust", 0.55)
	var unemployment = econ.get("unemployment", 0.08)
	var inflation = econ.get("inflation", 0.08)
	var poverty = welfare.get("poverty", 0.15)

	# میانگین شادی - مستقیم از جمعیت اما با تاخیر
	human["happiness_avg"] = human["happiness_avg"]*0.95 + happiness*0.05

	# استرس = تنش + ناامنی + بیکاری + تورم + فقر
	var stress_target = tension*0.30 + (1.0 - security.get("public_security",0.70))*0.20 + unemployment*0.15 + inflation*0.15 + poverty*0.10 + 0.10
	human["stress"] = clamp(human["stress"]*0.93 + stress_target*0.07, 0.05, 0.95)

	# امید = شادی + رشد + ثبات + آموزش
	var growth = econ.get("growth_rate", 0.02)
	var hope_target = happiness*0.30 + growth*10.0*0.20 + pol.get("stability",0.60)*0.20 + state.get("education",{}).get("quality",0.55)*0.15 + 0.15
	human["hope"] = clamp(human["hope"]*0.94 + hope_target*0.06, 0.05, 0.98)

	# ترس = تنش + ناامنی + بحران غذا/انرژی + فساد
	var food_crisis = state.get("resources",{}).get("food_crisis", false)
	var energy_crisis = state.get("resources",{}).get("energy_crisis", false)
	var fear_target = tension*0.35 + (1.0 - security.get("public_security",0.70))*0.25 + (0.20 if food_crisis else 0.0) + (0.10 if energy_crisis else 0.0) + 0.10
	human["fear"] = clamp(human["fear"]*0.92 + fear_target*0.08, 0.03, 0.95)

	# خشم = ناشادی + تنش + فساد + فقر
	var corruption = pol.get("corruption",0.30)
	var anger_target = (1.0 - happiness)*0.35 + tension*0.25 + corruption*0.20 + poverty*0.15 + 0.05
	human["anger"] = clamp(human["anger"]*0.90 + anger_target*0.10, 0.03, 0.90)

	# اعتماد — اینرسی نرم (بازرسی ۱۴۰۵، عمق‌بخشی ۴۲: خط clobber اولیهٔ اضافی حذف شد)
	human["trust"] = clamp(human["trust"]*0.98 + trust*0.02, 0.05, 0.95)

	# غرور ملی = انسجام + قدرت + موفقیت ورزشی
	var power_score = state.get("indicators",{}).get("power_score",55.0)/100.0
	var sports = state.get("sports_youth",{}).get("participation",0.40) if state.has("sports_youth") else 0.40
	human["national_pride"] = clamp(culture.get("cohesion",0.65)*0.4 + power_score*0.3 + sports*0.15 + 0.15, 0.1, 0.98)

	# سلامت روان - شادی + استرس معکوس + امید
	human["mental_health"] = clamp(human["mental_health"]*0.97 + (happiness*0.4 + (1.0-human["stress"])*0.3 + human["hope"]*0.3)*0.03, 0.1, 0.95)

	# همبستگی - شادی + غرور + ترس معکوس
	human["solidarity"] = clamp(human["solidarity"]*0.97 + (happiness*0.25 + human["national_pride"]*0.35 + (1.0 - human["fear"])*0.20 + human["trust"]*0.20)*0.03, 0.1, 0.95)

	# فرسودگی - استرس + ساعات کار
	human["burnout"] = clamp(human["stress"]*0.5 + unemployment*0.1 + 0.1, 0.05, 0.80)

	# تنهایی - شهرنشینی + فناوری
	var urban = pop.get("urban_ratio",0.75)
	var digital = state.get("technology",{}).get("branches",{}).get("دیجیتال",0.20)
	human["loneliness"] = clamp(urban*0.3 + digital*0.2 + (1.0 - human["solidarity"])*0.3 + 0.2, 0.05, 0.75)

	# تاب‌آوری روانی
	human["resilience_psy"] = clamp(human["solidarity"]*0.3 + human["hope"]*0.3 + human["trust"]*0.2 + human["national_pride"]*0.2, 0.1, 0.95)

	# خوش‌بینی اقتصادی - رشد + تورم معکوس
	human["optimism_economy"] = clamp(growth*10.0*0.4 + (1.0 - inflation)*0.3 + (1.0 - unemployment)*0.3, 0.05, 0.95)

	# حافظه جمعی - رویدادهای مهم
	if tick % 30 == 0 and (human["anger"] > 0.70 or human["national_pride"] > 0.85 or human["fear"] > 0.70):
		if human["collective_memory"].size() < 50:
			human["collective_memory"].append({
				"tick": tick,
				"happiness": human["happiness_avg"],
				"stress": human["stress"],
				"hope": human["hope"],
				"fear": human["fear"],
				"anger": human["anger"],
				"event": "خاطره جمعی ثبت شد - اوج احساسات"
			})
		if human["collective_memory"].size() > 30:
			human["collective_memory"] = human["collective_memory"].slice(-30)

	# رویدادها
	if human["stress"] > 0.72 and Deterministic.chance(0.018):
		events.append({"type":"stress_crisis","stress": human["stress"], "message":"استرس اجتماعی بالا - مردم خسته و عصبی"})

	if human["hope"] < 0.30 and Deterministic.chance(0.015):
		events.append({"type":"hope_crisis","hope": human["hope"], "message":"ناامیدی گسترده - مهاجرت در ذهن جوانان"})

	if human["fear"] > 0.70 and Deterministic.chance(0.012):
		events.append({"type":"fear_wave","fear": human["fear"], "message":"موج ترس - شایعه جنگ و قحطی در شبکه‌های اجتماعی"})

	if human["anger"] > 0.65 and Deterministic.chance(0.013):
		events.append({"type":"anger_wave","anger": human["anger"], "message":"خشم عمومی - اعتراض به گرانی"})

	if human["mental_health"] < 0.35 and Deterministic.chance(0.010):
		events.append({"type":"mental_health_crisis","health": human["mental_health"], "message":"بحران سلامت روان - افسردگی جوانان افزایش یافت"})

	if human["national_pride"] > 0.85 and Deterministic.chance(0.007):
		events.append({"type":"national_pride_peak","pride": human["national_pride"], "message":"غرور ملی در اوج - جشن خیابانی پس از پیروزی تیم ملی"})

	if human["solidarity"] > 0.80 and Deterministic.chance(0.009):
		events.append({"type":"solidarity_wave","solidarity": human["solidarity"], "message":"همبستگی ملی - کمک‌های مردمی سیل‌زده‌ها را نجات داد"})

	state["human_states"] = human
	
	# ── لایه واقع‌گرایانه اختصاصی حالات انسانی (جایگزین قالب خودکار) — بخش ۳.۶۶ ──
	# خشم جمعی: تبعیض قومی (دور ۱۰) + فقر + تورم — سوخت بحران‌های اجتماعی است
	var discrim_h = float(state.get("ethnicity", {}).get("discrimination", 0.20))
	var anger_target2 = float(poverty) * 0.35 + float(inflation) * 0.30 + discrim_h * 0.20 + (1.0 - float(happiness)) * 0.15
	human["anger"] = clampf(float(human.get("anger", 0.20)) * 0.97 + anger_target2 * 0.03, 0.03, 0.92)
	# فرسودگی شغلی: از ساعات کار واقعی هفته (بازار کار دور ۱۴) و اضافه‌کاری
	var hours_h = float(state.get("workforce_detail", {}).get("hours_per_week", 44.0))
	human["burnout"] = clampf(float(human.get("burnout", 0.25)) * 0.995 + (maxf(hours_h - 40.0, 0.0) * 0.012 + float(human.get("stress", 0.35)) * 0.3) * 0.005, 0.05, 0.85)
	# تنهایی: خانوارهای کوچک‌شونده (خانواده دور ۱۰) و سالمندی — هزینه پنهان شهرنشینی
	var hh_size = float(state.get("family", {}).get("avg_household_size", 3.3))
	var loneliness_target = 0.18 + (3.6 - hh_size) * 0.14 + float(pop.get("urban_ratio", 0.75)) * 0.15
	human["loneliness"] = clampf(float(human.get("loneliness", 0.30)) * 0.995 + loneliness_target * 0.005, 0.08, 0.75)
	# غرور ملی: افتخارات ورزشی (دور ۱۱) و جهش‌های فضایی (دور ۱۱) آن را شارژ می‌کند
	var pride_src = float(culture.get("cohesion", 0.65)) * 0.4 + float(state.get("sports_youth", {}).get("sports_achievements", 50.0)) / 150.0 + float(state.get("space", {}).get("level", 0.10)) * 0.3
	human["national_pride"] = clampf(float(human.get("national_pride", 0.65)) * 0.996 + pride_src * 0.004, 0.10, 0.97)
	# تاب‌آوری روانی جامعه: سلامت روان + همبستگی + امید
	human["resilience_psy"] = clampf(float(health.get("mental_health", 0.60)) * 0.4 + float(human.get("solidarity", 0.60)) * 0.3 + float(human.get("hope", 0.60)) * 0.3, 0.10, 0.95)
	if float(human.get("anger", 0.20)) > 0.55 and Deterministic.chance(0.006):
		events.append({"type": "social_anger_wave", "message": "موج خشم اجتماعی در شبکه‌ها - خشم فروخورده در حال جوشیدن است", "anger": human["anger"]})
	if float(human.get("burnout", 0.25)) > 0.55 and Deterministic.chance(0.005):
		events.append({"type": "burnout_epidemic", "message": "همه‌گیری فرسودگی شغلی - نیروی کار خسته و بی‌انگیزه است"})
	if float(human.get("resilience_psy", 0.55)) < 0.35 and Deterministic.chance(0.005):
		events.append({"type": "mental_health_crisis", "message": "بحران سلامت روان جمعی - مراکز مشاوره سرریز مراجعه‌کننده"})
	state["human_states"] = human

	return {"success":true,"state":state,"events":events}
