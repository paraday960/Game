extends BaseSystem
# ۳.۶۲ خانواده‌ها و خانوارها - درآمد، پس‌انداز، بدهی، مسکن، اندازه، تاب‌آوری، سبک زندگی

func compute(state: Dictionary, tick: int) -> Dictionary:
	var hh = state.get("households_detail_full", {})
	hh["count"] = hh.get("count", 25000000)
	hh["avg_size"] = hh.get("avg_size", 3.2)
	hh["income_avg"] = hh.get("income_avg", state.get("economy", {}).get("gdp_per_capita", 5000.0)*0.8)
	hh["income_median"] = hh.get("income_median", hh["income_avg"]*0.72)
	hh["savings_rate"] = hh.get("savings_rate", 0.15)
	hh["debt_ratio"] = hh.get("debt_ratio", 0.20)
	hh["debt_absolute"] = hh.get("debt_absolute", hh["income_avg"]*0.5)
	hh["housing_own"] = hh.get("housing_own", 0.70)
	hh["housing_rent_burden"] = hh.get("housing_rent_burden", 0.30)
	hh["food_share"] = hh.get("food_share", 0.35)
	hh["energy_share"] = hh.get("energy_share", 0.12)
	hh["resilience"] = hh.get("resilience", 0.55)
	hh["female_headed"] = hh.get("female_headed", 0.18)
	hh["urban_households"] = hh.get("urban_households", int(hh["count"]*0.75))

	var events = []
	var econ = state.get("economy", {})
	var pop = state.get("population", {})
	var welfare = state.get("welfare", {})
	var family = state.get("family", {})
	var infra = state.get("infrastructure", {})

	var inflation = econ.get("inflation", 0.08)
	var growth = econ.get("growth_rate", 0.02)
	var unemployment = econ.get("unemployment", 0.08)
	var gini = welfare.get("gini", 0.38)
	var poverty = welfare.get("poverty", 0.15)

	# درآمد خانوار - رشد GDP اما با بیکاری و تورم تعدیل
	var income_growth = growth*0.8 - inflation*0.3 - unemployment*0.2
	hh["income_avg"] *= (1.0 + income_growth/365.0)
	hh["income_avg"] = max(hh["income_avg"], 500.0)
	hh["income_median"] = hh["income_avg"] * (0.85 - gini*0.4)

	# اندازه خانوار - شهرنشینی اندازه را کوچک می‌کند
	var urban_ratio = pop.get("urban_ratio", 0.75)
	var fertility = family.get("fertility", 1.8) if family else 1.8
	var size_target = 2.0 + fertility*0.6 + (1.0 - urban_ratio)*0.8
	hh["avg_size"] = clamp(hh["avg_size"]*0.998 + size_target*0.002, 2.0, 5.5)
	hh["count"] = int(pop.get("total",85_000_000.0) / max(hh["avg_size"],1.0))

	# سهم غذا - قانون انگل: درآمد پایین سهم غذا بالا
	hh["food_share"] = clamp(0.60 - (hh["income_avg"]/10000.0)*0.15, 0.15, 0.60)
	hh["energy_share"] = clamp(0.08 + inflation*0.2, 0.05, 0.30)

	# پس‌انداز = درآمد - هزینه‌های الزامی - بدهی
	var obligatory = hh["food_share"] + hh["energy_share"] + hh["housing_rent_burden"]
	var saving_target = 1.0 - obligatory - hh["debt_ratio"]*0.1
	saving_target = clamp(saving_target, -0.10, 0.40)
	hh["savings_rate"] = clamp(hh["savings_rate"]*0.97 + saving_target*0.03 + Deterministic.next_range(-0.002,0.002), -0.05, 0.50)

	# بدهی - نرخ بهره و بیکاری
	var interest = econ.get("central_bank",{}).get("interest_rate",0.15) if econ.has("central_bank") else state.get("central_bank",{}).get("interest_rate",0.15)
	hh["debt_ratio"] = clamp(hh["debt_ratio"] + (interest - 0.10)*0.0008 + unemployment*0.0005 + Deterministic.next_range(-0.0003,0.0006), 0.02, 0.85)
	hh["debt_absolute"] = hh["income_avg"] * hh["debt_ratio"]

	# مسکن - مالکیت با پس‌انداز
	var housing_target = 0.40 + hh["savings_rate"]*0.6 + (1.0 - hh["housing_rent_burden"])*0.2
	hh["housing_own"] = clamp(hh["housing_own"]*0.996 + housing_target*0.004, 0.30, 0.90)
	hh["housing_rent_burden"] = clamp(hh["housing_rent_burden"] + inflation*0.0005 - growth*0.0003, 0.10, 0.60)

	# تاب‌آوری = پس‌انداز + اشتغال + مسکن
	var resilience_target = hh["savings_rate"]*0.4 + (1.0-unemployment)*0.3 + hh["housing_own"]*0.2 + 0.1
	hh["resilience"] = clamp(hh["resilience"]*0.97 + resilience_target*0.03, 0.05, 0.95)

	# خانوار زن‌سرپرست
	hh["female_headed"] = clamp(hh["female_headed"] + 0.00003, 0.10, 0.35)
	hh["urban_households"] = int(hh["count"] * urban_ratio)

	# رویدادها
	if hh["debt_ratio"] > 0.65 and Deterministic.chance(0.013):
		events.append({"type":"household_debt_crisis","debt": hh["debt_ratio"], "message":"بحران بدهی خانوارها - اقساط ۶۵٪ درآمد"})

	if hh["housing_rent_burden"] > 0.50 and Deterministic.chance(0.011):
		events.append({"type":"housing_affordability_crisis","burden": hh["housing_rent_burden"], "message":"بحران مسکن - اجاره نیمی از حقوق را می‌بلعد"})

	if hh["resilience"] < 0.25 and Deterministic.chance(0.012):
		events.append({"type":"household_fragility","resilience": hh["resilience"], "message":"شکنندگی معیشت - خانوارها یک شوک تا خط فقر فاصله دارند"})

	if hh["savings_rate"] < 0.0 and tick % 30 == 0:
		events.append({"type":"negative_saving","saving": hh["savings_rate"], "message":"پس‌انداز منفی - خانوارها از ذخیره می‌خورند"})

	if hh["food_share"] > 0.50 and Deterministic.chance(0.009):
		events.append({"type":"food_share_warning","share": hh["food_share"], "message":"فشار خوراک - ۵۰٪ درآمد صرف غذا می‌شود"})

	state["households_detail_full"] = hh
	
	# ── لایه واقع‌گرایانه اختصاصی خانوار (جایگزین قالب خودکار تکراری) — بخش ۳.۶۲ ──
	# سالمندی خانوارها را کوچک‌تر می‌کند
	var aging_h: float = float(state.get("population", {}).get("aging_index", 0.20))
	hh["avg_size"] = clampf(float(hh.get("avg_size", 3.2)) - aging_h * 0.0002, 2.0, 5.5)
	# فشار بدهی خانوار از نرخ بهره و بار اجاره
	var rate_h: float = float(state.get("central_bank", {}).get("interest_rate", 0.15))
	hh["debt_ratio"] = clampf(float(hh.get("debt_ratio", 0.20)) + (rate_h - 0.12) * 0.0004 + (float(hh.get("housing_rent_burden", 0.30)) - 0.30) * 0.0003, 0.02, 0.90)
	# پس‌انداز با تورم فرو می‌ریزد
	var infl_h: float = float(state.get("economy", {}).get("inflation", 0.08))
	hh["savings_rate"] = clampf(float(hh.get("savings_rate", 0.15)) - (infl_h - 0.06) * 0.0003, 0.02, 0.40)
	if float(hh.get("debt_ratio", 0.20)) > 0.60 and Deterministic.chance(0.004):
		events.append({"type": "household_debt_stress", "message": "تنش بدهی خانوارها - اقساط سنگین بر سفره خانوار فشار آورده است", "debt": hh["debt_ratio"]})
	state["households_detail_full"] = hh

	return {"success":true,"state":state,"events":events}
