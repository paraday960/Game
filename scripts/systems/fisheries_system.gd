extends BaseSystem
# ۳.۳۹ صیادی و منابع دریایی - پیاده‌سازی کامل

func compute(state: Dictionary, tick: int) -> Dictionary:
	var fish = state.get("fisheries", {})
	var resources = state.get("resources", {})
	var economy = state.get("economy", {})
	var environment = state.get("environment", {})
	var diplomacy = state.get("diplomacy", {})

	fish["catch"] = fish.get("catch", 500000.0)  # تن
	fish["fleet_size"] = fish.get("fleet_size", 1000)
	fish["sustainability"] = fish.get("sustainability", 0.60)
	fish["stock_health"] = fish.get("stock_health", 0.65)
	fish["aquaculture"] = fish.get("aquaculture", 0.30)
	fish["illegal_fishing"] = fish.get("illegal_fishing", 0.15)
	fish["maritime_sovereignty"] = fish.get("maritime_sovereignty", 0.70)
	fish["export_value"] = fish.get("export_value", 1_000_000_000.0)
	fish["employment"] = fish.get("employment", 200000)
	fish["protected_marine"] = fish.get("protected_marine", 0.10)

	var events = []

	var fisheries_budget_share = economy.get("budget_allocations",{}).get("محیط",0.03) * 0.3 + 0.01
	var fisheries_budget = economy.get("government_spending",0.0) * fisheries_budget_share

	# صید = f(ناوگان، ذخایر، فناوری، پایداری)
	var fleet_factor = fish["fleet_size"] / 1000.0
	var stock_factor = fish["stock_health"]
	var tech_fish = state.get("technology",{}).get("branches",{}).get("صنعت",0.20) * 0.2
	var sustainability_penalty = 1.0 if fish["sustainability"] > 0.5 else 0.7  # صید بی‌رویه

	var catch_amount = 500000.0 * fleet_factor * stock_factor * (1.0 + tech_fish) * sustainability_penalty
	catch_amount *= (1.0 + fisheries_budget / 5_000_000_000.0 * 0.1)
	fish["catch"] = fish["catch"] * 0.99 + catch_amount * 0.01

	# سلامت ذخایر - کاهش با صید زیاد، افزایش با حفاظت
	var stock_change = (0.6 - fish["catch"] / 800000.0) * 0.01 + fish["protected_marine"] * 0.005 + fish["sustainability"] * 0.002 - fish["illegal_fishing"] * 0.01
	fish["stock_health"] = clamp(fish["stock_health"] + stock_change * 0.01, 0.1, 1.0)

	# پایداری = f(مدیریت، ذخایر، آبزی‌پروری)
	var sustainability_target = 0.5 + fish["stock_health"] * 0.3 + fish["aquaculture"] * 0.1 + fish["protected_marine"] * 0.2 - fish["illegal_fishing"] * 0.3
	fish["sustainability"] = clamp(fish["sustainability"] * 0.99 + sustainability_target * 0.01, 0.1, 0.95)

	# آبزی‌پروری
	fish["aquaculture"] = clamp(fish["aquaculture"] + (fisheries_budget_share - 0.01) * 0.002 + tech_fish * 0.001, 0.05, 0.85)

	# صید غیرقانونی = f(نظارت، حاکمیت دریایی، فساد)
	var enforcement = state.get("security",{}).get("border_control",0.60) * 0.4 + fish["maritime_sovereignty"] * 0.4 + (1.0 - state.get("politics",{}).get("corruption",0.30)) * 0.2
	var illegal_target = 0.3 - enforcement * 0.3
	fish["illegal_fishing"] = clamp(fish["illegal_fishing"] * 0.99 + illegal_target * 0.01, 0.02, 0.50)

	# حاکمیت دریایی = f(نیروی دریایی، دیپلماسی)
	var naval_power = state.get("military",{}).get("branches",{}).get("دریایی",0.15) if state.get("military",{}).has("branches") else 0.15
	fish["maritime_sovereignty"] = clamp(fish["maritime_sovereignty"] * 0.995 + (naval_power * 2.0 + diplomacy.get("influence",40.0)/100.0 * 0.3) * 0.005, 0.2, 0.95)

	# مناطق حفاظت‌شده دریایی
	fish["protected_marine"] = clamp(fish["protected_marine"] + (fisheries_budget_share - 0.015) * 0.001, 0.02, 0.30)

	# ارزش صادرات
	var export_price = 2000.0  # دلار per ton
	fish["export_value"] = fish["catch"] * export_price * 0.3  # 30٪ صادر

	# اشتغال
	fish["employment"] = int(fish["fleet_size"] * 200 + fish["aquaculture"] * 100000.0)

	# ناوگان
	if fisheries_budget_share > 0.015 and Deterministic.chance(0.005):
		fish["fleet_size"] += 5

	# اثر بر منابع - غذا
	resources["inventory"]["غذا"] = clamp(resources.get("inventory",{}).get("غذا",85.0) + fish["catch"] / 100000.0 * 0.1, 0.0, 150.0)
	state["resources"] = resources

	# اثر بر محیط - تنوع زیستی دریایی
	environment["pollution"] = clamp(environment.get("pollution",0.4) + (1.0 - fish["sustainability"]) * 0.0001, 0.0, 1.0)
	state["environment"] = environment

	# حلقه بازخورد: صید ← ذخایر ← پایداری
	if fish["stock_health"] < 0.3:
		fish["catch"] *= 0.95
		events.append({"type": "fish_stock_collapse", "message": "فروپاشی ذخایر ماهی - صید بی‌رویه!", "stock_health": fish["stock_health"]})

	# رویدادها
	if fish["illegal_fishing"] > 0.3 and Deterministic.chance(0.012):
		events.append({"type": "illegal_fishing_crisis", "message": "بحران صید غیرقانونی - قاچاق دریایی", "illegal": fish["illegal_fishing"]})

	if fish["maritime_sovereignty"] < 0.5 and Deterministic.chance(0.01):
		events.append({"type": "maritime_dispute", "message": "تنش حاکمیت دریایی - اختلاف با همسایه بر سر آب‌ها", "sovereignty": fish["maritime_sovereignty"]})

	if fish["aquaculture"] > 0.6 and Deterministic.chance(0.008):
		events.append({"type": "aquaculture_success", "message": "موفقیت آبزی‌پروری - کاهش فشار بر ذخایر طبیعی"})

	if fish["protected_marine"] > 0.2 and Deterministic.chance(0.006):
		events.append({"type": "marine_conservation", "message": "حفاظت دریایی - افزایش تنوع زیستی و گردشگری"})

	state["fisheries"] = fish
	return {"success": true, "state": state, "events": events}
