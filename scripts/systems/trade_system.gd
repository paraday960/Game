extends BaseSystem
# ۳.۲۹ تجارت خارجی و گمرک - پیاده‌سازی کامل

func compute(state: Dictionary, tick: int) -> Dictionary:
	var trade = state.get("trade", {})
	var econ = state.get("economy", {})
	var diplomacy = state.get("diplomacy", {})
	var industry = state.get("industry", {})
	var agriculture = state.get("agriculture", {})
	var resources = state.get("resources", {})

	trade["exports"] = trade.get("exports", 80_000_000_000.0)
	trade["imports"] = trade.get("imports", 70_000_000_000.0)
	trade["balance"] = trade.get("balance", 10_000_000_000.0)
	trade["tariff_rate"] = trade.get("tariff_rate", 0.15)
	trade["customs_efficiency"] = trade.get("customs_efficiency", 0.60)
	trade["trade_partners"] = trade.get("trade_partners", 20)
	trade["export_diversity"] = trade.get("export_diversity", 0.55)
	trade["import_dependency"] = trade.get("import_dependency", 0.40)
	trade["customs_revenue"] = trade.get("customs_revenue", 5_000_000_000.0)
	trade["trade_agreements"] = trade.get("trade_agreements", 5)
	trade["wto_compliance"] = trade.get("wto_compliance", 0.60)

	var events = []

	# تراز تجاری = صادرات - واردات
	var gdp = econ.get("gdp", 500_000_000_000.0)
	var infra_q = state.get("infrastructure",{}).get("quality",0.55)
	var central_bank_rate = state.get("central_bank",{}).get("exchange_rate",1.0)

	# صادرات = f(تولید صنعتی، کشاورزی، منابع، نرخ ارز، روابط، تعرفه خارجی)
	var industrial_export = industry.get("output",100.0) * 500_000_000.0
	var agri_export = agriculture.get("production",100.0) * 200_000_000.0
	var resource_export = resources.get("inventory",{}).get("نفت",80.0) * 300_000_000.0
	var exchange_effect = 1.0 / central_bank_rate  # ارز ضعیف‌تر → صادرات بیشتر
	var diplomacy_effect = diplomacy.get("influence",40.0) / 100.0 + 0.5
	var export_base = (industrial_export + agri_export + resource_export) * exchange_effect * diplomacy_effect * infra_q
	trade["exports"] = trade["exports"] * 0.995 + export_base * 0.005

	# واردات = f(مصرف، تولید داخلی، نرخ ارز، تعرفه)
	var consumption = pop_total(state) / 85_000_000.0 * 50_000_000_000.0
	var domestic_coverage = (industry.get("output",100.0) + agriculture.get("production",100.0)) / 200.0
	var import_demand = consumption * (1.5 - domestic_coverage)
	var tariff_effect = 1.0 - trade["tariff_rate"] * 0.5
	import_demand *= tariff_effect / exchange_effect
	trade["imports"] = trade["imports"] * 0.995 + import_demand * 0.005

	# تراز
	trade["balance"] = trade["exports"] - trade["imports"]

	# درآمد گمرک = واردات × نرخ تعرفه × کارآمدی
	trade["customs_revenue"] = trade["imports"] * trade["tariff_rate"] * trade["customs_efficiency"] / 12.0

	# تعرفه - سیاست تجاری
	# اگر کسری تجاری شدید، افزایش تعرفه پیشنهاد می‌شود
	if trade["balance"] < -20_000_000_000.0 and Deterministic.chance(0.01):
		trade["tariff_rate"] = clamp(trade["tariff_rate"] + 0.01, 0.05, 0.50)
		events.append({"type": "tariff_increase", "message": "افزایش تعرفه برای حمایت از تولید داخل و کاهش کسری", "tariff": trade["tariff_rate"]})
	elif trade["balance"] > 30_000_000_000.0 and Deterministic.chance(0.005):
		trade["tariff_rate"] = clamp(trade["tariff_rate"] - 0.005, 0.05, 0.50)

	# کارآمدی گمرک
	var corruption = state.get("politics",{}).get("corruption",0.30)
	trade["customs_efficiency"] = clamp(trade["customs_efficiency"] + (0.7 - corruption) * 0.001 - 0.0002, 0.2, 0.95)

	# تنوع صادرات
	var diversity = (industry.get("advanced",0.15) + industry.get("light",0.35)) * 0.5 + trade["trade_agreements"] / 20.0 * 0.3
	trade["export_diversity"] = clamp(trade["export_diversity"] * 0.99 + diversity * 0.01, 0.1, 0.95)

	# وابستگی واردات
	var dependency = 1.0 - (industry.get("output",100.0) / 150.0) * 0.5 - agriculture.get("self_sufficiency",0.8) * 0.3
	trade["import_dependency"] = clamp(trade["import_dependency"] * 0.99 + dependency * 0.01, 0.1, 0.85)

	# توافقنامه‌ها
	if diplomacy.get("influence",40.0) > 60.0 and Deterministic.chance(0.005):
		trade["trade_agreements"] += 1
		events.append({"type": "trade_agreement_signed", "message": "توافقنامه تجارت آزاد جدید امضا شد", "agreements": trade["trade_agreements"]})

	# انطباق WTO
	trade["wto_compliance"] = clamp(trade["wto_compliance"] + Deterministic.next_range(-0.002, 0.003), 0.2, 0.95)

	# اثر بر اقتصاد
	econ["government_revenue"] = econ.get("government_revenue",0.0) + trade["customs_revenue"]
	state["economy"] = econ

	# اثر دیپلماسی: تحریم
	if diplomacy.get("sanctions",[]).size() > 0:
		trade["exports"] *= 0.95
		trade["imports"] *= 0.90
		events.append({"type": "sanction_trade_effect", "message": "تحریم‌ها تجارت را محدود کرد", "balance": trade["balance"]})

	# رویدادها
	if trade["import_dependency"] > 0.7 and Deterministic.chance(0.01):
		events.append({"type": "import_dependency_crisis", "message": "وابستگی شدید به واردات - آسیب‌پذیری در تحریم", "dependency": trade["import_dependency"]})

	if trade["balance"] < -30_000_000_000.0 and Deterministic.chance(0.015):
		events.append({"type": "trade_deficit_crisis", "message": "کسری تجاری بحرانی - فشار بر ارز و بدهی", "balance": trade["balance"]})

	if trade["export_diversity"] > 0.7 and Deterministic.chance(0.008):
		events.append({"type": "export_diversification_success", "message": "تنوع صادرات موفق - کاهش وابستگی به نفت"})

	state["trade"] = trade
	return {"success": true, "state": state, "events": events}

func pop_total(state: Dictionary) -> float:
	return state.get("population",{}).get("total",85_000_000)
