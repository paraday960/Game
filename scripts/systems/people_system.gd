extends BaseSystem
# لایه آدم‌ها - بخش ۳.۵۳ تا ۳.۶۲ - 10 دسته افراد

func compute(state: Dictionary, tick: int) -> Dictionary:
	var people = state.get("people", {})
	var pop = state.get("population", {})
	var economy = state.get("economy", {})

	people["total_sample"] = people.get("total_sample", 1000)
	people["households"] = people.get("households", 25_000_000)
	people["households_details"] = people.get("households_details", {
		"میانگین_اندازه": 3.2,
		"درآمد_میانگین": 5000.0,
		"دارای_مسکن": 0.70,
		"دارای_خودرو": 0.40
	})
	people["workforce"] = people.get("workforce", {
		"کشاورز": 0.20,
		"کارگر_صنعتی": 0.25,
		"کارمند": 0.30,
		"خدمات": 0.20,
		"بیکار": 0.05
	})
	var leaders = people.get("leaders", {})
	if not leaders is Dictionary:
		leaders = {}
	leaders["وزرا"] = leaders.get("وزرا", 20)
	leaders["نمایندگان"] = leaders.get("نمایندگان", 290)
	leaders["مدیران_ارشد"] = leaders.get("مدیران_ارشد", 5000)
	var country_id = str(state.get("country", {}).get("id", WorldManager.default_country))
	leaders["استانداران"] = max(1, CountryGeographyManager.get_unit_count(country_id))
	leaders["شهرداران"] = max(leaders["استانداران"], int(state.get("administration", {}).get("municipalities", 1)))
	people["leaders"] = leaders
	people["elites"] = people.get("elites", {
		"نخبه_علمی": 10000,
		"کارآفرین": 50000,
		"هنرمند": 20000,
		"ورزشکار": 5000,
		"روحانی": 30000
	})
	people["security_forces"] = people.get("security_forces", {
		"ارتش": 500000,
		"پلیس": 200000,
		"اطلاعات": 30000,
		"مرزبان": 50000
	})
	people["emotions"] = people.get("emotions", {
		"خوشبختی_میانگین": pop.get("happiness",0.6),
		"اعتماد": state.get("politics",{}).get("trust",0.55),
		"امید": 0.60,
		"ترس": state.get("politics",{}).get("tension",0.35),
		"خشم": 0.20
	})

	var events = []

	# رشد خانوارها با جمعیت
	people["households"] = pop.get("total",85_000_000) / people["households_details"]["میانگین_اندازه"]

	# درآمد خانوار با GDP سرانه
	var gdp_per_capita = economy.get("gdp_per_capita",5000.0)
	people["households_details"]["درآمد_میانگین"] = people["households_details"]["درآمد_میانگین"] * 0.99 + gdp_per_capita * 0.8 * 0.01

	# ترکیب نیروی کار با اقتصاد و فناوری
	var tech_industry = state.get("technology",{}).get("branches",{}).get("صنعت",0.20)
	var tech_digital = state.get("technology",{}).get("branches",{}).get("دیجیتال",0.20)
	
	var workforce = people["workforce"]
	# انتقال از کشاورزی به صنعت و خدمات با فناوری
	if tech_industry > 0.3:
		workforce["کشاورز"] -= 0.0002
		workforce["کارگر_صنعتی"] += 0.0001
		workforce["خدمات"] += 0.0001
	if tech_digital > 0.4:
		workforce["کارمند"] += 0.0001
		workforce["خدمات"] += 0.0001

	var unemployment = economy.get("unemployment",0.08)
	workforce["بیکار"] = unemployment
	# نرمالایز
	var sum_work = 0.0
	for v in workforce.values():
		sum_work += v
	for k in workforce.keys():
		workforce[k] = clamp(workforce[k] / sum_work, 0.01, 0.60)
	people["workforce"] = workforce

	# احساسات و عواطف - بخش ۳.۶۶
	var happiness = pop.get("happiness",0.6)
	var trust = state.get("politics",{}).get("trust",0.55)
	var tension = state.get("politics",{}).get("tension",0.35)
	var security_feel = state.get("security",{}).get("feeling_security",0.70)

	var emotions = people["emotions"]
	emotions["خوشبختی_میانگین"] = happiness
	emotions["اعتماد"] = trust
	emotions["امید"] = clamp(0.5 + happiness * 0.2 + (economy.get("growth_rate",0.02) * 10.0) * 0.2 + education_quality(state) * 0.1, 0.1, 0.95)
	emotions["ترس"] = clamp(tension * 0.6 + (1.0 - security_feel) * 0.4, 0.05, 0.85)
	emotions["خشم"] = clamp((1.0 - happiness) * 0.5 + tension * 0.3 + (state.get("ethnicity",{}).get("discrimination",0.2)) * 0.2, 0.05, 0.80)
	emotions["غرور_ملی"] = clamp(state.get("culture",{}).get("cohesion",0.65) * 0.5 + state.get("indicators",{}).get("power_score",55.0)/100.0 * 0.3 + state.get("sports_youth",{}).get("sports_achievements",50.0)/100.0 * 0.2, 0.1, 0.95)
	people["emotions"] = emotions

	# نخبگان - فرار مغزها
	var brain_drain_risk = (1.0 - happiness) * 0.3
	brain_drain_risk += 0.2 if economy.get("gdp_per_capita", 5000.0) < 3000.0 else 0.0
	brain_drain_risk += 0.2 if state.get("politics", {}).get("stability", 0.6) < 0.4 else 0.0
	if brain_drain_risk > 0.5 and Deterministic.chance(0.01):
		events.append({"type": "brain_drain", "message": "فرار مغزها - مهاجرت نخبگان علمی و کارآفرینان", "risk": brain_drain_risk})
		people["elites"]["نخبه_علمی"] -= 100
		state["technology"]["research_rate"] = state.get("technology",{}).get("research_rate",10.0) - 0.5

	# دولتمردان و مدیران - فساد
	if state.get("politics",{}).get("corruption",0.30) > 0.5 and Deterministic.chance(0.01):
		events.append({"type": "elite_corruption", "message": "افشای فساد در بین مدیران ارشد - بحران اعتماد"})

	# حلقه: رضایت → بهره‌وری → اقتصاد → رفاه
	var productivity_boost = happiness * 0.1 + emotions["امید"] * 0.05 - emotions["ترس"] * 0.05 - emotions["خشم"] * 0.05
	# بازرسی ۱۴۰۵: نویسهٔ نمایشی growth_rate حذف شد (مالکیت یکتا: economy_system)؛
	# اثر واقعی بهره‌وری احساسی از کانال sector_boosts (نرخ سالانه؛ روزانه ×۳۶۰)
	var pp_boosts: Dictionary = economy.get("sector_boosts", {})
	pp_boosts["بهره‌وری انسانی"] = productivity_boost * 0.0001 * 360.0
	economy["sector_boosts"] = pp_boosts
	state["economy"] = economy

	# رویدادهای انسانی
	if emotions["خشم"] > 0.6 and Deterministic.chance(0.015):
		events.append({"type": "public_anger", "message": "خشم عمومی بالا - خطر اعتراضات گسترده", "anger": emotions["خشم"]})

	if emotions["امید"] > 0.8 and Deterministic.chance(0.01):
		events.append({"type": "hope_rising", "message": "امید و نشاط اجتماعی بالا - افزایش مشارکت و بهره‌وری"})

	if people["households_details"]["دارای_مسکن"] < 0.5 and Deterministic.chance(0.01):
		events.append({"type": "housing_grievance", "message": "نارضایتی از مسکن - جوانان خانه‌دار نمی‌شوند"})

	state["people"] = people
	
	# ── لایه واقع‌گرایانه اختصاصی لایه آدم‌ها (جایگزین قالب خودکار) — همگام‌سازی آینه با منابع معتبر ──
	# این لایه «آینه» است: مقادیرش باید از سیستم‌های مرجع دورهای بازرسی خوانده شود، نه تکرار ثابت
	var hh = people.get("households_details", {})
	hh["میانگین_اندازه"] = float(state.get("family", {}).get("avg_household_size", 3.3))
	hh["دارای_مسکن"] = clampf(0.85 - float(state.get("physical", {}).get("housing_shortage", 0.10)) * 0.8, 0.20, 0.95)
	people["households_details"] = hh
	# شمار رهبران از سیستم دولتمردان واقعی (دور ۱۳/۱۶)
	var ld = people.get("leaders", {})
	ld["وزرا"] = int(state.get("officials", {}).get("ministers", 20))
	ld["مدیران_ارشد"] = int(state.get("officials", {}).get("senior_managers", 5000))
	people["leaders"] = ld
	# نخبگان از جمعیت واقعی نخبگان که فرار مغزها (دور ۱۳) تحلیل می‌برد
	var el = people.get("elites", {})
	el["نخبه_علمی"] = int(state.get("elites_detail", {}).get("scientific", 10000))
	el["هنرمند"] = int(state.get("elites_detail", {}).get("artistic", 15000))
	el["ورزشکار"] = int(state.get("sports_youth", {}).get("clubs", 1200)) * 3
	el["روحانی"] = int(state.get("religious_leaders", {}).get("count", 30000))
	people["elites"] = el
	# نیروهای امنیتی از شمار واقعی (دور ۱۱)
	var sf_p = people.get("security_forces", {})
	sf_p["ارتش"] = int(state.get("security_forces_detail", {}).get("army", 500000))
	sf_p["پلیس"] = int(state.get("security_forces_detail", {}).get("police", 200000))
	sf_p["مرزبان"] = int(state.get("security_forces_detail", {}).get("border", 50000))
	people["security_forces"] = sf_p
	# احساسات آینه از حالات انسانی به‌روزشده این تیک
	var em_p = people.get("emotions", {})
	em_p["خشم"] = float(state.get("human_states", {}).get("anger", 0.20))
	em_p["ترس"] = float(state.get("human_states", {}).get("fear", 0.35))
	people["emotions"] = em_p
	if float(hh.get("میانگین_اندازه", 3.3)) < 2.6 and Deterministic.chance(0.004):
		events.append({"type": "household_shrinkage", "message": "کوچک‌شدن خانوارها - نسل تک‌فرزندی‌ها مستقل شدند", "size": hh["میانگین_اندازه"]})
	state["people"] = people

	return {"success": true, "state": state, "events": events}

func education_quality(state: Dictionary) -> float:
	return state.get("education",{}).get("quality",0.55)
