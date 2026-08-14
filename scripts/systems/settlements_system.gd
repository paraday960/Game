extends BaseSystem
# ۳.۴۲ سکونتگاه‌ها - شهر بزرگ، متوسط، کوچک، شهرک، روستا، تراکم، گسترش بی‌رویه، کیفیت مسکن، زیرساخت محلی

func compute(state: Dictionary, tick: int) -> Dictionary:
	var settlements = state.get("settlements_detail", {})
	var pop = state.get("population", {})
	var infra = state.get("infrastructure", {})
	var econ = state.get("economy", {})
	var env = state.get("environment", {})

	settlements["total"] = settlements.get("total", 1200)
	settlements["cities_large"] = settlements.get("cities_large", 50)
	settlements["cities_medium"] = settlements.get("cities_medium", 200)
	settlements["cities_small"] = settlements.get("cities_small", 350)
	settlements["towns"] = settlements.get("towns", 400)
	settlements["villages"] = settlements.get("villages", 10000)
	settlements["urban_pop"] = settlements.get("urban_pop", pop.get("total",85_000_000) * 0.75)
	settlements["rural_pop"] = settlements.get("rural_pop", pop.get("total",85_000_000) * 0.25)
	settlements["density"] = settlements.get("density", 50.0)
	settlements["sprawl"] = settlements.get("sprawl", 0.30)
	settlements["housing_quality"] = settlements.get("housing_quality", 0.60)
	settlements["slum_ratio"] = settlements.get("slum_ratio", 0.15)
	settlements["green_space_ratio"] = settlements.get("green_space_ratio", 0.20)
	settlements["service_access"] = settlements.get("service_access", 0.70)
	settlements["migration_urban"] = settlements.get("migration_urban", 100000.0)
	settlements["new_houses_per_year"] = settlements.get("new_houses_per_year", 300000)

	var events = []

	var pop_growth = pop.get("growth_rate",0.012)
	var urbanization_rate = 0.012 # ۱.۲٪ سالانه شهرنشینی
	var gdp_pc = econ.get("gdp_per_capita",5000.0)
	var infra_coverage = infra.get("coverage",0.70)

	# رشد شهری
	var urban_pop = settlements["urban_pop"]
	var rural_pop = settlements["rural_pop"]
	var total_pop = pop.get("total",85_000_000.0)

	# مهاجرت روستا به شهر - جذابیت شهری
	# توسعهٔ روستایی (rural_policy: جاده/اینترنت/اعتبار/فرآوری) کشش مهاجرت را کم می‌کند —
	# قبلاً rural_manager ماهانه urban_ratio را بازنویسی می‌کرد و مهاجرت روزانهٔ این سیستم را
	# پاک می‌گشت (shadow-write)؛ حالا اهرم‌ها داخل همین مدل اثر می‌گذارند.
	var rural_policy: Dictionary = state.get("rural_policy", {})
	var rural_stay: float = clampf((float(rural_policy.get("rural_roads", 0.40)) + float(rural_policy.get("rural_internet", 0.25)) + float(rural_policy.get("micro_credit", 0.25)) + float(rural_policy.get("agro_processing", 0.20))) * 0.10, 0.0, 0.45)
	# بازخورد ظرفیت (تعمیق سکونتگاه‌ها): با نزدیک‌شدن تراکم به هدف، جاذبهٔ شهر خودبه‌خود
	# می‌افتد — شهرها بی‌نهایت جمعیت نمی‌بلعند و فشار به شهرسازی/مسکن می‌رسد
	var est_urban_area: float = settlements["cities_large"]*250.0 + settlements["cities_medium"]*80.0 + settlements["cities_small"]*25.0
	var density_target: float = 7000.0 + float(settlements.get("housing_quality", 0.6)) * 6000.0
	settlements["crowding"] = clampf((urban_pop / max(est_urban_area, 1.0)) / max(density_target, 1.0), 0.0, 1.5)
	var capacity_factor: float = clampf(1.6 - float(settlements["crowding"]), 0.15, 1.6)
	var urban_attraction = ((gdp_pc/5000.0)*0.3 + infra["quality"]*0.3 + settlements["service_access"]*0.2 + 0.2) * (1.0 - rural_stay) * capacity_factor
	settlements["migration_urban"] = total_pop * urbanization_rate / 365.0 * urban_attraction
	urban_pop += settlements["migration_urban"]
	# بازرسی واقع‌گرایی ۱۴۰۵: سقف شهرنشینی ۰٫۹۰ → ۰٫۹۵. در افق ۳۰+ ساله کشور روی
	# سقف ۹۰٫ می‌چسبید، درحالی که اقتصادهای شهریِ بالغ (هلند ~۹۳٪، ژاپن ~۹۲٪،
	# بلژیک ~۹۸٪) بالاترند؛ بازخورد تراکم (crowding) پیش از سقف جریان را کند می‌کند.
	urban_pop = clampf(urban_pop, total_pop*0.05, total_pop*0.95)
	rural_pop = max(total_pop - urban_pop, total_pop*0.05)

	settlements["urban_pop"] = urban_pop
	settlements["rural_pop"] = rural_pop
	pop["total"] = total_pop
	pop["urban_ratio"] = clampf(urban_pop / max(total_pop,1.0), 0.0, 0.95)

	# تراکم - جمعیت شهری / مساحت مصنوعی شهری (مساحت از بلوک ظرفیت بالا محاسبه شده)
	settlements["density"] = urban_pop / max(est_urban_area,1.0)

	# گسترش بی‌رویه = رشد شهری سریع بدون زیرساخت
	var sprawl_pressure = (urban_pop/85_000_000.0 - infra_coverage)*0.5 + (settlements["migration_urban"]/100000.0)*0.3
	settlements["sprawl"] = clamp(settlements["sprawl"]*0.996 + sprawl_pressure*0.004, 0.0, 0.90)

	# کیفیت مسکن - درآمد + مصالح + تراکم معکوس
	var housing_shortage = state.get("physical",{}).get("housing_shortage",0.10) if state.has("physical") else 0.10
	settlements["housing_quality"] = clamp(settlements["housing_quality"]*0.994 + (0.15 - housing_shortage)*0.003 + gdp_pc/10000.0*0.003 + (1.0 - settlements["slum_ratio"])*0.002, 0.2, 0.96)

	# حاشیه‌نشینی - نابرابری + بیکاری + گسترش
	var poverty = state.get("welfare",{}).get("poverty",0.15)
	var unemployment = econ.get("unemployment",0.08)
	settlements["slum_ratio"] = clamp(settlements["slum_ratio"]*0.997 + (poverty*0.3 + unemployment*0.3 + settlements["sprawl"]*0.2)*0.003, 0.02, 0.50)

	# فضای سبز - محیط‌زیست
	settlements["green_space_ratio"] = clamp(env.get("forest_coverage",0.30) if env.has("forest_coverage") else 0.30*0.5 + (1.0 - settlements["sprawl"])*0.3 + 0.2, 0.05, 0.60)

	# دسترسی به خدمات - زیرساخت
	settlements["service_access"] = clamp(infra["quality"]*0.4 + infra_coverage*0.3 + settlements["housing_quality"]*0.2 + 0.10, 0.2, 0.98)

	# ساخت مسکن جدید — از نرخ واقعی روزانهٔ سیستم فیزیکی خوانده می‌شود (×۳۶۵)
	# قبلاً فرمول موازی ~۱۰۰هزار/سال مستقل از تولید واقعی (~۲۹هزار/سال) گزارش می‌کرد
	var construction = float(state.get("physical",{}).get("housing_build_daily", 80.0)) * 365.0
	settlements["new_houses_per_year"] = int(construction)
	if tick % 180 == 0:
		settlements["new_houses_per_year"] = int(construction * (0.8 + Deterministic.next_range(0.0,0.4)))

	# تعداد سکونتگاه‌ها با رشد جمعیت
	if tick % 365 == 0:
		if settlements["urban_pop"] > settlements["cities_large"]*1500000.0*1.2:
			settlements["cities_large"] += 1
			settlements["cities_medium"] += 2
			settlements["cities_small"] += 3
			events.append({"type":"new_city","message":"شهر بزرگ جدید تاسیس شد - مهاجرت و رشد جمعیت"})
		if settlements["rural_pop"] < 10_000_000 and settlements["villages"] > 5000:
			# خالی شدن روستاها
			settlements["villages"] -= Deterministic.next_int_range(20, 100)
			events.append({"type":"village_abandonment","villages": settlements["villages"], "message":"خالی شدن روستاها - مهاجرت به شهرها"})

	# اثر بر زیرساخت و محیط
	infra["coverage"] = clamp(infra_coverage + settlements["sprawl"]*-0.00015 + 0.00025, 0.2, 0.98)
	var forest = env.get("forest_coverage",0.30) if env.has("forest_coverage") else 0.30
	forest = clamp(forest - settlements["sprawl"]*0.00005, 0.05, 0.70)
	if env.has("forest_coverage"):
		env["forest_coverage"] = forest

	state["infrastructure"] = infra
	state["environment"] = env
	state["population"] = pop

	# رویدادها
	if float(settlements.get("crowding", 0.0)) > 1.2 and Deterministic.chance(0.012):
		events.append({"type":"urban_crowding","crowding": settlements["crowding"], "message":"شهرهای بزرگ از ظرفیت تراکم گذشتند — اجاره سنگین می‌شود و مهاجرت کند می‌گردد"})

	if settlements["sprawl"] > 0.62 and Deterministic.chance(0.015):
		events.append({"type":"urban_sprawl_crisis","sprawl": settlements["sprawl"], "message":"گسترش بی‌رویه شهری - تخریب باغات و ترافیک سنگین"})

	if housing_shortage > 0.35 and Deterministic.chance(0.014):
		events.append({"type":"housing_shortage_protest","shortage": housing_shortage, "message":"بحران مسکن - جوانان قادر به خانه‌دار شدن نیستند - تجمع مقابل وزارت مسکن"})

	if settlements["slum_ratio"] > 0.30 and Deterministic.chance(0.012):
		events.append({"type":"slum_expansion","slum": settlements["slum_ratio"], "message":"گسترش حاشیه‌نشینی - %d٪ جمعیت در سکونتگاه غیررسمی" % int(settlements["slum_ratio"]*100.0)})

	if settlements["service_access"] < 0.45 and Deterministic.chance(0.011):
		events.append({"type":"service_access_crisis","access": settlements["service_access"], "message":"دسترسی پایین به خدمات شهری در حاشیه‌ها"})

	if settlements["density"] > 8000.0 and Deterministic.chance(0.010):
		events.append({"type":"overcrowding","density": settlements["density"], "message":"تراکم بحرانی - هر کیلومتر %d نفر" % int(settlements["density"])})

	state["settlements_detail"] = settlements
	
	# ── لایه واقع‌گرایانه اختصاصی سکونتگاه‌ها (جایگزین قالب خودکار) — بخش ۳.۴۲ ──
	# حاشیه‌نشینی: وقتی ورودی مهاجران روزانه از ظرفیت پذیرش مسکن جدید بیشتر است، حاشیه رشد می‌کند
	var daily_houses = float(settlements.get("new_houses_per_year", 300000)) / 365.0 * 3.3
	var daily_migrants = float(settlements.get("migration_urban", 100000.0))
	var housing_gap = (daily_migrants - daily_houses) / maxf(daily_migrants, 1.0)
	settlements["slum_ratio"] = clampf(float(settlements.get("slum_ratio", 0.15)) + housing_gap * 0.0008, 0.03, 0.55)
	# گسترش بی‌رویه: تراکم پایین خودتقویه‌شونده است — پراکنده‌روی هزینه خدمات را بالا می‌برد
	var density_gap = maxf((60.0 - float(settlements.get("density", 50.0))) / 60.0, -0.5)
	settlements["sprawl"] = clampf(float(settlements.get("sprawl", 0.30)) + density_gap * 0.0004, 0.05, 0.80)
	settlements["green_space_ratio"] = clampf(float(settlements.get("green_space_ratio", 0.20)) - float(settlements.get("sprawl", 0.30)) * 0.0001, 0.03, 0.45)
	# خالی شدن روستاها: مهاجرت مداوم روستا به شهر تدریجاً سکونتگاه‌های کوچک را متروکه می‌کند
	if float(settlements.get("rural_pop", 20_000_000)) / maxf(float(total_pop), 1.0) < 0.18:
		settlements["villages"] = maxi(int(settlements.get("villages", 10000)) - (1 if Deterministic.chance(0.02) else 0), 4000)
	# کیفیت مسکن: فرسودگی طبیعی در برابر تکمیل ساخت‌وساز
	var housing_growth = float(settlements.get("new_houses_per_year", 300000)) / maxf(float(settlements.get("urban_pop", 60_000_000)) / 3.3, 1.0)
	settlements["housing_quality"] = clampf(float(settlements.get("housing_quality", 0.60)) - 0.00008 + housing_growth * 2.0, 0.15, 0.95)
	if float(settlements.get("slum_ratio", 0.15)) > 0.30 and Deterministic.chance(0.005):
		events.append({"type": "slum_expansion", "message": "گسترش حاشیه‌نشینی - سکونتگاه‌های غیررسمی پایتخت را در می‌نوردد", "slum": settlements["slum_ratio"]})
	if housing_gap > 0.4 and Deterministic.chance(0.004):
		events.append({"type": "housing_shortage_city", "message": "کمبود حاد مسکن در شهرها - اجاره‌بها سر به فلک کشیده"})
	state["settlements_detail"] = settlements

	return {"success":true,"state":state,"events":events}
