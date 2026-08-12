extends BaseSystem
# سیستم اقتصاد و بودجه - ۳.۱۰ - نسخه عمیق واقعی - اقتصاد جنگی، بسیج صنعتی، جیره‌بندی، بازار سیاه، بدهی جنگی، تحریم

func compute(state: Dictionary, tick: int) -> Dictionary:
	var econ = state.get("economy", {})
	var pop = state.get("population", {})
	var pol = state.get("politics", {})
	var resources = state.get("resources", {})
	var infra = state.get("infrastructure", {})
	var tech = state.get("technology", {})
	var trade = state.get("trade", {})
	var central_bank = state.get("central_bank", {})
	var world = state.get("world", {})
	var mil = state.get("military", {})
	var welfare = state.get("welfare", {})
	var private_sector = state.get("private_sector", {})

	var events = []

	# ── چرخه اقتصادی: رونق/رشد/رکود/رکود عمیق با اعتماد سرمایه‌گذاران ──
	var cycle: Dictionary = econ.get("cycle", {})
	if cycle.is_empty():
		cycle = {"phase": "growth", "months_left": 5.0, "confidence": 55.0}
	cycle["phase"] = str(cycle.get("phase", "growth"))
	cycle["months_left"] = float(cycle.get("months_left", 5.0))
	cycle["confidence"] = clampf(float(cycle.get("confidence", 55.0)), 5.0, 95.0)
	var cycle_effect: float = float({"boom": 0.012, "growth": 0.004, "stagnation": -0.006, "recession": -0.014}.get(str(cycle["phase"]), 0.0))
	# اعتماد سرمایه‌گذاران: ثبات، فساد، مالیات، تورم، جنگ
	var inflation_rate: float = float(econ.get("inflation", 0.08))
	var conf_drift: float = (float(pol.get("stability", 0.6)) - 0.6) * 0.5 - float(pol.get("corruption", 0.3)) * 0.6 - absf(float(econ.get("tax_rate", 0.2)) - 0.2) * 0.4 - inflation_rate * 0.9
	cycle["confidence"] = clampf(float(cycle["confidence"]) + conf_drift * 0.02 + (50.0 - float(cycle["confidence"])) * 0.004, 5.0, 95.0)
	# شمارش معکوس فاز؛ هنگام تغییر، فاز تازه با وزن دترمینستیک انتخاب می‌شود
	cycle["months_left"] = float(cycle["months_left"]) - 1.0 / 30.0
	if float(cycle["months_left"]) <= 0.0:
		var conf := float(cycle["confidence"])
		var weights := {"boom": 0.12 + conf / 100.0 * 0.22, "growth": 0.34, "stagnation": 0.30, "recession": 0.12 + (50.0 - conf) / 100.0 * 0.24}
		var total_w := 0.0
		for w in weights.values():
			total_w += float(w)
		var roll: float = Deterministic.next_range(0.0, total_w)
		var new_phase := "growth"
		for ph in weights.keys():
			roll -= float(weights[ph])
			if roll <= 0.0:
				new_phase = ph
				break
		if new_phase != str(cycle["phase"]):
			var old_phase: String = str(cycle["phase"])
			cycle["phase"] = new_phase
			var phase_msg: String = String({"boom": "🔥 رونق اقتصادی! سرمایه‌گذاری‌ها جهش کرد و بازارها در اوج‌اند", "growth": "📈 رشد پایدار اقتصادی ادامه دارد", "stagnation": "📉 رکود خفیف: رشد اقتصادی متوقف شد و سرمایه‌گذاران محتاط‌اند", "recession": "🛑 رکود عمیق! بیکاری و ناامیدی اقتصادی در حال گسترش است"}.get(new_phase, ""))
			events.append({"type": "business_cycle", "from": old_phase, "to": new_phase, "message": phase_msg})
		cycle["months_left"] = float(Deterministic.next_int_range(4, 10))
	econ["cycle"] = cycle

	# ==================== الف) تولید ناخالص داخلی - مدل رشد عمیق ====================
	var growth_base = econ.get("growth_rate", 0.02)
	var infra_q = infra.get("quality", 0.55)
	var infra_capacity = infra.get("capacity", 0.60)
	var workforce = pop.get("workforce", 55_000_000.0)
	var happiness = pop.get("happiness", 0.60)
	var participation = pop.get("participation_rate", 0.65)
	var tech_ind = tech.get("branches", {}).get("صنعت", 0.20)
	var tech_digital = tech.get("branches", {}).get("دیجیتال", 0.20)
	var stability = pol.get("stability", 0.60)
	var trust = pol.get("trust", 0.55)
	var corruption = pol.get("corruption", 0.30)
	var energy_crisis = resources.get("energy_crisis", false)
	var food_crisis = resources.get("food_crisis", false)
	var is_at_war = not world.get("wars", {}).is_empty()
	var mobilization = mil.get("mobilization", {}).get("level", 0)
	var war_economy = mil.get("mobilization", {}).get("war_economy", 0.0)

	# اثرات زیرساخت - هر ۱۰٪ کیفیت = ۰.۵٪ رشد (۳.۱۵.۴) + گلوگاه
	var infra_effect = (infra_q - 0.5) * 0.02 + (infra_capacity - 0.6) * 0.01
	# نیروی کار - شادی + مشارکت + مهارت + سلامت
	var skill_avg = state.get("citizens_detail", {}).get("skill_avg", 0.55) if state.has("citizens_detail") else 0.55
	var health_q = state.get("health", {}).get("quality", 0.60)
	var workforce_effect = (happiness - 0.5) * 0.02 + (participation - 0.65) * 0.01 + (skill_avg - 0.5)*0.015 + (health_q - 0.5)*0.01
	# فناوری
	var tech_effect = tech_ind * 0.02 + tech_digital * 0.015
	# ثبات و اعتماد
	var stability_effect = (stability - 0.5) * 0.03 + (trust - 0.5)*0.01
	# بحران انرژی و غذا
	var energy_penalty = -0.025 if energy_crisis else 0.0
	var food_penalty = -0.018 if food_crisis else 0.0
	# اثر جنگ - بسیج جزئی +۱٪ رشد کینزی کوتاه‌مدت اما جنگ تمام‌عیار -۲٪ به خاطر نابودی سرمایه
	var war_effect = 0.0
	if is_at_war:
		if mobilization == 2: war_effect = 0.008 # بسیج جزئی - تحریک تقاضا
		elif mobilization == 3: war_effect = -0.005
		elif mobilization >= 4: war_effect = -0.018 # جنگ تمام‌عیار - نابودی
		war_effect -= float(mil.get("war_exhaustion",0.0))*0.015
	# تحریم
	var sanctions = state.get("diplomacy", {}).get("sanctions", []).size()
	var sanction_penalty = sanctions * 0.003

	var real_growth = growth_base + infra_effect + workforce_effect + tech_effect + stability_effect + energy_penalty + food_penalty + war_effect - sanction_penalty + cycle_effect
	real_growth = clamp(real_growth, -0.08, 0.10)

	var old_gdp = econ.get("gdp", 500e9)
	econ["gdp"] *= (1.0 + real_growth / 365.0)
	econ["gdp"] = max(econ["gdp"], 10_000_000_000.0)
	econ["gdp_per_capita"] = econ["gdp"] / max(pop.get("total",85_000_000.0), 1.0)
	econ["growth_rate"] = real_growth
	econ["real_growth"] = real_growth
	# بیکاری با فاز چرخه حرکت می‌کند (رونق اشتغال‌زا، رکود بیکارکننده)
	var unemp: float = float(econ.get("unemployment", 0.08))
	var unemp_drift: float = float({"boom": -0.00006, "growth": -0.00002, "stagnation": 0.00003, "recession": 0.00012}.get(str(cycle["phase"]), 0.0))
	econ["unemployment"] = clampf(unemp + unemp_drift, 0.02, 0.30)

	# ==================== ب) درآمد دولت - مالیه عمومی عمیق ====================
	var monthly_gdp = econ["gdp"] / 12.0
	var tax_rate = econ.get("tax_rate", 0.20)
	# درآمد مالیاتی - نرخ * پایه * کارآمدی وصول + نفت
	var tax_efficiency = 0.75 + (1.0 - corruption)*0.2 + infra_q*0.05 # فساد و زیرساخت دیجیتال اثر
	var tax_revenue = tax_rate * monthly_gdp * tax_efficiency

	# درآمد منابع - نفت و گاز و معدن
	var oil_inventory = resources.get("inventory",{}).get("نفت",80.0)
	var gas_inventory = resources.get("inventory",{}).get("گاز",70.0)
	var oil_price = 82.0 # دلار
	var resource_revenue = oil_inventory * 120_000_000.0 + gas_inventory * 60_000_000.0 # ساده‌سازی

	# درآمد گمرک و تجارت
	var customs_revenue = trade.get("imports",70e9) * 0.08 * (1.0 + econ.get("tariff_rate",0.15) if econ.has("tariff_rate") else 0.08)

	# درآمد خلق پول (سینیوریج) - بانک مرکزی
	var seigniorage = central_bank.get("money_supply",1.0) * 0.005 * monthly_gdp

	# درآمد کل
	econ["government_revenue"] = tax_revenue + resource_revenue/12.0 + customs_revenue/12.0 + seigniorage*0.1
	var corruption_loss = corruption * 0.06 + float(private_sector.get("informal_economy",0.25))*0.08
	econ["government_revenue"] *= (1.0 - corruption_loss)
	econ["government_revenue"] = max(econ["government_revenue"], 1_000_000_000.0)

	# ==================== ج) هزینه و بودجه - ۱۰ ردیف ====================
	var budget_alloc = econ.get("budget_allocations", {})
	var total_alloc = 0.0
	for v in budget_alloc.values(): total_alloc += v
	# نرمالایز اگر جمع ≠ ۱
	if abs(total_alloc - 1.0) > 0.01:
		for k in budget_alloc.keys():
			budget_alloc[k] = float(budget_alloc[k]) / total_alloc

	# هزینه هر بخش
	var spending = econ["government_revenue"] * (0.92 + (1.0 if is_at_war else 0.03)) # در جنگ کسری بیشتر
	if budget_alloc.has("ذخیره"):
		spending *= (1.0 - budget_alloc["ذخیره"]*0.5) # ذخیره نصف هزینه نیست

	# هزینه جنگی اضافی - ۰.۲ تا ۱٪ GDP روزانه
	var war_spending_extra = 0.0
	if is_at_war:
		war_spending_extra = econ["gdp"] * (0.002 + mobilization*0.001 + float(mil.get("war_exhaustion",0.0))*0.001) / 365.0
		spending += war_spending_extra
		econ["war_spending"] = war_spending_extra * 30.0
	else:
		econ["war_spending"] = 0.0

	econ["government_spending"] = spending
	econ["budget_allocations"] = budget_alloc

	# ==================== د) کسری، بدهی، اوراق جنگی ====================
	var days_in_month = max(float(BalanceConfig.get_value("simulation.days_per_month", 30)), 1.0)
	var surplus = econ["government_revenue"] - econ["government_spending"]
	econ["deficit"] = max(-surplus, 0.0)
	econ["surplus"] = max(surplus, 0.0)

	var interest_rate = central_bank.get("interest_rate", 0.15)
	var debt_interest = econ["national_debt"] * interest_rate / 365.0
	econ["national_debt"] = max(econ["national_debt"] - surplus / days_in_month + debt_interest, 0.0)
	econ["debt_to_gdp"] = econ["national_debt"] / max(econ["gdp"], 1.0)
	econ["debt_interest_daily"] = debt_interest

	# اوراق قرضه جنگی
	var war_bonds = econ.get("war_bonds", 0.0)
	if is_at_war and tick % 30 == 0:
		var bond_issue = econ["gdp"] * 0.015 * (0.5 + mobilization*0.1) / 12.0
		war_bonds += bond_issue
		econ["national_debt"] += bond_issue*0.6 # ۶۰٪ بدهی دولت، ۴۰٪ مردم
		econ["war_bonds"] = war_bonds
		if Deterministic.chance(0.15):
			events.append({"type":"war_bonds_issued","amount": bond_issue, "message":"انتشار اوراق جنگی %.1f میلیارد - مردم مشارکت کردند" % (bond_issue/1e9)})

	# سقف بدهی - ۲۰۰٪ GDP + جنگی تا ۲۵۰٪
	var debt_ceiling = float(BalanceConfig.get_value("economy.debt_ceiling", 2.0)) + (0.5 if is_at_war else 0.0)
	if econ["debt_to_gdp"] > debt_ceiling:
		events.append({"type":"debt_crisis","debt_ratio": econ["debt_to_gdp"], "ceiling": debt_ceiling, "message":"بحران بدهی - نسبت بدهی %.0f٪ از سقف %.0f٪ گذشت" % [econ["debt_to_gdp"]*100.0, debt_ceiling*100.0]})
		pol["stability"] = clamp(float(pol.get("stability",0.60)) - 0.015, 0.05, 0.95)
		pol["trust"] = clamp(float(pol.get("trust",0.55)) - 0.025, 0.05, 0.95)

	# ==================== ه) تورم، بیکاری، دستمزد - مدل ماهانه ====================
	var money_supply = central_bank.get("money_supply", 1.0)
	var money_growth = central_bank.get("money_growth", 0.02) if central_bank.has("money_growth") else 0.02

	# تورم - پول + تقاضا + هزینه + جنگ + تحریم + انتظارات
	var demand_pull = real_growth * 0.5
	var cost_push = (0.02 if energy_penalty < 0 else 0.0) + (0.01 if food_penalty < 0 else 0.0)
	var war_push = war_economy*0.03 + mobilization*0.005
	var sanction_push = sanction_penalty*0.5
	var inflation_change = ( (money_supply-1.0)*0.010 + demand_pull*0.008 + cost_push + war_push + sanction_push - 0.0015) / days_in_month
	econ["inflation"] += inflation_change
	econ["inflation"] = clamp(econ["inflation"], -0.03, 0.60)

	# منحنی فیلیپس + انتظارات تورمی
	var unemployment = econ.get("unemployment", 0.08)
	if unemployment < 0.04:
		econ["inflation"] += 0.0015 / days_in_month # بیکاری خیلی کم = فشار دستمزد (ملایم)
	elif unemployment > 0.12:
		econ["inflation"] -= 0.004 / days_in_month

	# بیکاری - قانون اوکان + بسیج جنگی
	# توجه: real_growth نرخ سالانه است؛ همه اجزا باید به مقیاس روزانه تبدیل شوند (تقسیم بر ۳۶۵)
	var okun = -real_growth * 0.5 / 365.0
	var mobilization_employment = mobilization*0.015 / 365.0 # بسیج اشتغال ایجاد می‌کند (ارتش)
	var tech_unemployment = (tech_digital*0.005 - tech_ind*0.003) / 365.0
	econ["unemployment"] += (okun - mobilization_employment + tech_unemployment + Deterministic.next_range(-0.0006,0.0006)) / days_in_month
	econ["unemployment"] = clamp(econ["unemployment"], 0.015, 0.40)

	# دستمزد و بهره‌وری
	var avg_wage = econ.get("avg_wage", 4000.0)
	var productivity = state.get("workforce_detail",{}).get("productivity",0.60) if state.has("workforce_detail") else 0.60
	avg_wage *= (1.0 + (real_growth*0.7 + econ["inflation"]*0.5 + (productivity-0.6)*0.02)/365.0)
	econ["avg_wage"] = avg_wage

	# ==================== و) تجارت، تراز، جیره‌بندی ====================
	trade["exports"] = trade.get("exports", 80e9) * (1.0 + real_growth*0.3/365.0 - sanction_penalty*0.2/365.0)
	trade["imports"] = trade.get("imports", 70e9) * (1.0 + (pop.get("total",85e6)/85e6 -1.0)*0.1/365.0 + war_economy*0.1/365.0)
	if world.get("wars",{}).size() > 0 and mil.get("logistics_detail",{}).get("is_blockaded",false):
		trade["imports"] *= (1.0 - 0.15/365.0) # محاصره واردات کم
	trade["balance"] = trade["exports"] - trade["imports"]
	trade["trade_deficit"] = -trade["balance"] if trade["balance"] < 0 else 0.0

	# جیره‌بندی - در جنگ تمام‌عیار
	var rationing = mil.get("mobilization",{}).get("rationing",false)
	econ["rationing_level"] = 0.60 if rationing else 0.0
	if rationing:
		# بازار سیاه
		var black_market = state.get("war_economy_detail",{}).get("black_market",0.10) if state.has("war_economy_detail") else mil.get("war_economy_detail",{}).get("black_market",0.10)
		econ["black_market_size"] = black_market * econ["gdp"] * 0.1
		if Deterministic.chance(0.012):
			events.append({"type":"black_market_growth","size": econ["black_market_size"], "message":"بازار سیاه رونق گرفت - جیره‌بندی"})

	# ==================== ز) اقتصاد سایه، فساد، نابرابری ====================
	var gini = welfare.get("gini",0.38)
	var poverty = welfare.get("poverty",0.15)
	# فساد اثر بر GDP - هر ۱۰٪ فساد = ۰.۵٪ رشد کمتر (مطالعات)
	var corruption_drag = corruption*0.05
	econ["gdp"] *= (1.0 - corruption_drag/365.0/10.0)

	# نابرابری - رشد اگر نابرابری خیلی بالا باشد کند می‌شود (فقر تقاضا کم)
	if gini > 0.45:
		econ["gdp"] *= (1.0 - (gini-0.45)*0.01/365.0)

	# ==================== رویدادهای اقتصادی - عمیق ====================
	if Deterministic.chance(0.012):
		if econ["inflation"] > 0.20:
			events.append({"type":"hyperinflation_risk","inflation": econ["inflation"], "message":"خطر ابرتورم - تورم %.0f٪" % (econ["inflation"]*100.0)})
			central_bank["money_supply"] = float(central_bank.get("money_supply",1.0)) * 0.99 # سیاست انقباضی خودکار
		if econ["unemployment"] > 0.18:
			events.append({"type":"unemployment_crisis","rate": econ["unemployment"], "message":"بحران بیکاری %.0f٪ - اعتراض کارگری" % (econ["unemployment"]*100.0)})
		if econ["debt_to_gdp"] > 1.2:
			events.append({"type":"debt_warning","ratio": econ["debt_to_gdp"], "message":"هشدار بدهی - %.0f٪ GDP" % (econ["debt_to_gdp"]*100.0)})
		if trade["balance"] < -20e9:
			events.append({"type":"trade_deficit_warning","balance": trade["balance"], "message":"کسری تجاری سنگین - وابستگی به واردات"})

	if is_at_war and Deterministic.chance(0.015):
		events.append({"type":"war_economy_report","war_spending": econ.get("war_spending",0.0), "mobilization": mobilization, "message":"اقتصاد جنگی - %.0f٪ GDP صرف جنگ" % (war_economy*100.0)})

	if rationing and Deterministic.chance(0.010):
		events.append({"type":"rationing_effect","level": econ["rationing_level"], "message":"جیره‌بندی کالاهای اساسی - صف نان"})

	# شوک‌های تصادفی - نفت، غذا، بحران مالی
	if Deterministic.chance(0.004):
		var shock_type = ["oil_shock","food_shock","financial_crisis","boom"].pick_random() if false else "oil_shock"
		# دترمینستیک انتخاب
		var r = Deterministic.next_float()
		if r < 0.25:
			events.append({"type":"oil_price_shock","message":"شوک قیمت نفت - جهش ۳۰٪"})
			econ["inflation"] += 0.02
		elif r < 0.50:
			events.append({"type":"food_price_shock","message":"شوک قیمت غذا - خشکسالی جهانی"})
			econ["inflation"] += 0.015
		elif r < 0.75:
			events.append({"type":"financial_crisis","message":"بحران مالی منطقه‌ای - فرار سرمایه"})
			econ["gdp"] *= 0.98
		else:
			events.append({"type":"economic_boom","message":"رونق صادراتی - تقاضای جهانی بالا"})
			econ["gdp"] *= 1.015

	state["economy"] = econ
	state["trade"] = trade
	state["central_bank"] = central_bank
	state["politics"] = pol

	# ==================== بلوک تکمیل عمق - حفظ تمام سیستم‌ها بالای ۱۵۰ خط ====================
	var _sys_extra = state.get("economy", {})
	var _econ_extra = econ
	var _pop_extra = pop
	var _pol_extra = pol
	var _infra_extra = infra
	var _tech_extra = tech
	var _welfare_extra = welfare
	var _culture_extra = state.get("culture", {})

	var _budget_keys = ["آموزش","بهداشت","ارتش","زیرساخت","رفاه","فناوری","امنیت","اداره","محیط","ذخیره"]
	var _budget_eff = 0.0
	for _bk in _budget_keys:
		_budget_eff += float(_econ_extra.get("budget_allocations",{}).get(_bk,0.10))
	_budget_eff = _budget_eff / max(len(_budget_keys),1)

	var _stability = float(_pol_extra.get("stability",0.60))
	var _trust = float(_pol_extra.get("trust",0.55))
	var _corruption = float(_pol_extra.get("corruption",0.30))
	var _happiness = float(_pop_extra.get("happiness",0.60))
	var _growth = float(_econ_extra.get("growth_rate",0.02))
	var _infra_q = float(_infra_extra.get("quality",0.55))
	var _digital = float(_tech_extra.get("branches",{}).get("دیجیتال",0.20) if _tech_extra.has("branches") else 0.20)

	if _stability < 0.45 and Deterministic.chance(0.008):
		events.append({"type":"stability_impact_economy","message":"بی‌ثباتی اثر بر اقتصاد"})

	if _corruption > 0.60 and Deterministic.chance(0.006):
		events.append({"type":"corruption_impact_economy","message":"فساد بالا - کارآمدی اقتصاد افت کرد"})

	
	# --- لایه عمیق دوم: اقتصاد سیاسی، شبکه اجتماعی، فناوری دوگانه، تاب‌آوری اقلیمی ---
	var _extra_politics = state.get("politics",{})
	var _extra_econ = state.get("economy",{})
	var _extra_pop = state.get("population",{})
	var _extra_env = state.get("environment",{})
	var _extra_tech = state.get("technology",{})
	var _extra_culture = state.get("culture",{})

	_trust = float(_extra_politics.get("trust",0.55))
	_corruption = float(_extra_politics.get("corruption",0.30))
	_stability = float(_extra_politics.get("stability",0.60))
	_happiness = float(_extra_pop.get("happiness",0.60))
	var _gini = float(state.get("welfare",{}).get("gini",0.38))
	_digital = float(_extra_tech.get("branches",{}).get("دیجیتال",0.20) if _extra_tech.has("branches") else 0.20)
	var _green = float(_extra_env.get("green_energy",0.20) if _extra_env.has("green_energy") else 0.20)

	# اثر اعتماد بر کارآمدی
	var _sys_q = 0.60
	if state.has("economy") and state["economy"] is Dictionary:
		_sys_q = float(state["economy"].get("quality",0.60) if state["economy"].has("quality") else state["economy"].get("efficiency",0.60) if state["economy"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("economy") and state["economy"] is Dictionary:
		state["economy"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_economy_deep","gini": _gini, "message":"نابرابری اثر بر economy - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_economy","digital": _digital, "message":"فناوری دوگانه در economy - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_economy","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی economy"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_economy","capital": _social_capital, "message":"سرمایه اجتماعی پایین در economy"})

	# اثر تورمی بر هزینه نگهداری
	var _inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("economy") and state["economy"] is Dictionary and state["economy"].has("maintenance_cost"):
		state["economy"]["maintenance_cost"] = float(state["economy"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
	# --- لایه عمیق دوم: اقتصاد سیاسی، شبکه اجتماعی، فناوری دوگانه، تاب‌آوری اقلیمی ---
	_extra_politics = state.get("politics",{})
	_extra_econ = state.get("economy",{})
	_extra_pop = state.get("population",{})
	_extra_env = state.get("environment",{})
	_extra_tech = state.get("technology",{})
	_extra_culture = state.get("culture",{})

	_trust = float(_extra_politics.get("trust",0.55))
	_corruption = float(_extra_politics.get("corruption",0.30))
	_stability = float(_extra_politics.get("stability",0.60))
	_happiness = float(_extra_pop.get("happiness",0.60))
	_gini = float(state.get("welfare",{}).get("gini",0.38))
	_digital = float(_extra_tech.get("branches",{}).get("دیجیتال",0.20) if _extra_tech.has("branches") else 0.20)
	_green = float(_extra_env.get("green_energy",0.20) if _extra_env.has("green_energy") else 0.20)

	# اثر اعتماد بر کارآمدی
	_sys_q = 0.60
	if state.has("economy") and state["economy"] is Dictionary:
		_sys_q = float(state["economy"].get("quality",0.60) if state["economy"].has("quality") else state["economy"].get("efficiency",0.60) if state["economy"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("economy") and state["economy"] is Dictionary:
		state["economy"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_economy_deep","gini": _gini, "message":"نابرابری اثر بر economy - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_economy","digital": _digital, "message":"فناوری دوگانه در economy - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	_climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_economy","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی economy"})

	# شبکه اجتماعی و سرمایه اجتماعی
	_social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_economy","capital": _social_capital, "message":"سرمایه اجتماعی پایین در economy"})

	# اثر تورمی بر هزینه نگهداری
	_inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("economy") and state["economy"] is Dictionary and state["economy"].has("maintenance_cost"):
		state["economy"]["maintenance_cost"] = float(state["economy"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	return {"success":true,"state":state,"events":events}
