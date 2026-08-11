extends BaseSystem
# سیستم اقتصاد و بودجه - بخش ۳.۱۰

func compute(state: Dictionary, tick: int) -> Dictionary:
	var econ = state["economy"]
	var pop = state["population"]
	var pol = state["politics"]
	var resources = state["resources"]
	var infra = state["infrastructure"]
	var tech = state["technology"]
	var trade = state["trade"]
	var central_bank = state["central_bank"]

	var events = []

	# الف) GDP - فرمول پایه ۳.۱۰.۳
	# GDP رشد = GDP × (نرخ رشد) که نرخ رشد = f(زیرساخت، سرمایه‌گذاری، نیروی کار، فناوری، ثبات)
	var growth_base = econ["growth_rate"]
	var infra_effect = (infra["quality"] - 0.5) * 0.02
	var workforce_effect = (pop["happiness"] - 0.5) * 0.02 + (pop["participation_rate"] - 0.65) * 0.01
	var tech_effect = tech["branches"]["صنعت"] * 0.02
	var stability_effect = (pol["stability"] - 0.5) * 0.03
	var energy_penalty = -0.02 if resources["energy_crisis"] else 0.0
	var food_penalty = -0.015 if resources["food_crisis"] else 0.0

	var real_growth = growth_base + infra_effect + workforce_effect + tech_effect + stability_effect + energy_penalty + food_penalty
	real_growth = clamp(real_growth, -0.05, 0.08)  # بین -۵٪ تا ۸٪

	var old_gdp = econ["gdp"]
	econ["gdp"] *= (1.0 + real_growth / 365.0)  # رشد روزانه (تیک روزانه فرض)
	econ["gdp_per_capita"] = econ["gdp"] / max(pop["total"], 1.0)

	# ب) درآمد دولت - ۳.۱۰.۳
	# درآمد مالیاتی = نرخ مالیات × GDP (ساده‌سازی ماهانه)
	var monthly_gdp = econ["gdp"] / 12.0
	econ["government_revenue"] = econ["tax_rate"] * monthly_gdp + resources["inventory"]["نفت"] * 100_000_000.0  # درآمد منابع
	# اثر فساد
	var corruption_loss = pol["corruption"] * 0.05
	econ["government_revenue"] *= (1.0 - corruption_loss)

	# ج) هزینه دولت
	var total_budget = 0.0
	for allocation in econ["budget_allocations"].values():
		total_budget += allocation
	# هزینه کل تقریبا برابر درآمد اگر کسری کنترل شده
	var spending = econ["government_revenue"] * 0.95
	if econ["budget_allocations"].has("ذخیره"):
		spending *= (1.0 - econ["budget_allocations"]["ذخیره"])
	econ["government_spending"] = spending

	# د) کسری/مازاد و بدهی
	# درآمد و هزینه در مقیاس «ماهانه» تعریف شده‌اند؛ بدهی باید متناسبِ روزانه تغییر کند
	# و مازاد واقعی نیز بدهی را کم کند (قبلاً مازاد هرگز بدهی را نمی‌کاست).
	var days_in_month = max(float(BalanceConfig.get_value("simulation.days_per_month", 30)), 1.0)
	var surplus = econ["government_revenue"] - econ["government_spending"]
	# قرارداد واحد در کل پروژه: deficit مثبت یعنی کسری، صفر یعنی تراز یا مازاد
	econ["deficit"] = max(-surplus, 0.0)
	var interest = econ["national_debt"] * float(BalanceConfig.get_value("economy.debt_interest", 0.03)) / 365.0
	econ["national_debt"] = max(econ["national_debt"] - surplus / days_in_month + interest, 0.0)
	econ["debt_to_gdp"] = econ["national_debt"] / max(econ["gdp"], 1.0)

	# قانون سقف بدهی - ۲۰۰٪ GDP
	if econ["debt_to_gdp"] > float(BalanceConfig.get_value("economy.debt_ceiling", 2.0)):
		events.append({"type": "debt_crisis", "debt_ratio": econ["debt_to_gdp"]})
		# بحران اعتباری
		pol["stability"] -= 0.01
		pol["trust"] -= 0.02

	# ه) تورم و بیکاری
	# تورم با چاپ پول و کسری بالا می‌رود
	var money_supply_effect = central_bank["money_supply"] - 1.0
	var demand_pull = real_growth * 0.5
	# این تغییرات در مقیاس ماهانه تعریف شده‌اند؛ در هر روز داخلی ماه باید به نرخ روزانه اعمال شوند
	# (قبلاً روزانه اعمال می‌شدند و تورم در چند روز به سقف/کف محدوده می‌چسبید).
	econ["inflation"] += (money_supply_effect * 0.01 + demand_pull * 0.01 - 0.001) / days_in_month
	econ["inflation"] = clamp(econ["inflation"], -0.02, 0.30)

	# منحنی فیلیپس ساده - اثر ماهانه تقسیم بر روزهای ماه
	if econ["unemployment"] < 0.05:
		econ["inflation"] += 0.005 / days_in_month
	elif econ["unemployment"] > 0.10:
		econ["inflation"] -= 0.003 / days_in_month

	# بیکاری - چرخه کار در مقیاس ماهانه است و روزانه اعمال می‌شود
	econ["unemployment"] += (-real_growth * 0.5 + Deterministic.next_range(-0.0005, 0.0005)) / days_in_month
	econ["unemployment"] = clamp(econ["unemployment"], 0.02, 0.35)

	# و) تجارت
	trade["exports"] *= (1.0 + real_growth * 0.3 / 365.0)
	trade["imports"] *= (1.0 + (pop["total"] / 85_000_000.0 -1.0) * 0.1 /365.0)
	trade["balance"] = trade["exports"] - trade["imports"]

	# رویدادهای اقتصادی - ۳.۱۰.۵
	if Deterministic.chance(0.01):
		if econ["inflation"] > 0.15:
			events.append({"type": "hyperinflation_risk", "inflation": econ["inflation"]})
		if econ["unemployment"] > 0.15:
			events.append({"type": "unemployment_crisis", "rate": econ["unemployment"]})
		if econ["debt_to_gdp"] > 1.0:
			events.append({"type": "debt_warning", "ratio": econ["debt_to_gdp"]})

	state["economy"] = econ
	state["trade"] = trade

	return {"success": true, "state": state, "events": events}
