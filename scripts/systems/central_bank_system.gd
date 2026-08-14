extends BaseSystem
# ۳.۲۵ بانک مرکزی و سیاست پولی - پیاده‌سازی کامل

func compute(state: Dictionary, tick: int) -> Dictionary:
	var cb = state.get("central_bank", {})
	var economy = state.get("economy", {})
	var trade = state.get("trade", {})
	var politics = state.get("politics", {})

	cb["interest_rate"] = cb.get("interest_rate", 0.15)
	cb["money_supply"] = cb.get("money_supply", 1.0)
	cb["inflation_target"] = cb.get("inflation_target", 0.05)
	cb["exchange_rate"] = cb.get("exchange_rate", 1.0)
	cb["foreign_reserves"] = cb.get("foreign_reserves", 50_000_000_000.0)
	cb["bank_stability"] = cb.get("bank_stability", 0.70)
	cb["credit_growth"] = cb.get("credit_growth", 0.10)
	cb["independence"] = cb.get("independence", 0.70)

	var events = []

	# فرمول‌ها - ۳.۲۵.۳
	var inflation = economy.get("inflation", 0.08)
	var unemployment = economy.get("unemployment", 0.08)
	var growth = economy.get("growth_rate", 0.02)
	var debt_to_gdp = economy.get("debt_to_gdp", 0.4)

	# سیاست پولی = f(نرخ بهره، عرضه پول)
	# قاعده تیلور ساده: نرخ بهره = تورم + 0.5*(تورم-هدف) + 0.5*(رشد-رشد بالقوه)
	var inflation_gap = inflation - cb["inflation_target"]
	var growth_gap = growth - 0.025
	var taylor_rate = cb["inflation_target"] + inflation + 0.5 * inflation_gap + 0.5 * growth_gap
	taylor_rate = clamp(taylor_rate, 0.01, 0.60)

	# بانک مرکزی استقلال دارد اما تحت فشار سیاسی
	var political_pressure = (1.0 - cb["independence"]) * 0.02
	if politics.get("stability",0.6) < 0.4:
		political_pressure -= 0.01  # دولت می‌خواهد نرخ کم برای رشد

	# حالت مستقل از قاعده تیلور پیروی می‌کند؛ مداخله مستقیم سریع‌تر اما استقلال را فرسوده می‌کند.
	cb["policy_mode"] = cb.get("policy_mode", "independent")
	cb["manual_rate"] = cb.get("manual_rate", cb["interest_rate"])
	if cb["policy_mode"] == "manual_rate":
		cb["interest_rate"] = clamp(cb["interest_rate"] * 0.98 + float(cb["manual_rate"]) * 0.02, 0.0, 0.50)
		cb["independence"] = clamp(float(cb["independence"]) - 0.0002, 0.1, 0.95)
	else:
		cb["interest_rate"] = clamp(cb["interest_rate"] * 0.98 + (taylor_rate + political_pressure) * 0.02, 0.01, 0.60)

	# عرضه پول و نقدینگی
	# نرخ بهره بالا → عرضه کم، رشد کم؛ پایین → رشد اما ریسک تورم
	var money_change = (0.15 - cb["interest_rate"]) * 0.01 + growth_gap * 0.005
	cb["money_supply"] = clamp(cb["money_supply"] + money_change * 0.01, 0.5, 1.8)

	# تورم هدف با نرخ بهره کنترل می‌شود
	# تورم = f(عرضه پول، تقاضا، انتظارات)
	var money_effect = (cb["money_supply"] - 1.0) * 0.03
	var demand_effect = growth * 0.35
	# اثر نرخ بهره بر تورم (با تاخیر): نرخ بالاتر از ۸٪ تورم را مهار می‌کند
	var rate_effect = (0.08 - cb["interest_rate"]) * 0.12
	economy["inflation"] = clamp(inflation + (money_effect + demand_effect + rate_effect - 0.01) * 0.001, -0.02, 0.50)
	state["economy"] = economy

	# نرخ ارز = f(تراز تجاری، تورم نسبی، نرخ بهره، ذخایر)
	var trade_balance = trade.get("balance", 10_000_000_000.0) if trade else 10_000_000_000.0
	# لنگر مقیاس: ۲۰٪ تولید ناخالص (در نقطه شروع = همان ۱۰۰ میلیارد دلار قدیم)
	var trade_anchor: float = max(float(economy.get("gdp", 500e9)) * 0.2, 1.0e9)
	var trade_effect = trade_balance / trade_anchor * 0.02
	var inflation_diff = inflation - 0.03  # تورم جهانی فرض ۳٪
	var interest_diff = cb["interest_rate"] - 0.05
	var exchange_change = -trade_effect * 0.01 - inflation_diff * 0.02 + interest_diff * 0.03
	cb["exchange_rate"] = clamp(cb["exchange_rate"] + exchange_change * 0.01, 0.2, 5.0)

	# ذخایر ارزی
	cb["foreign_reserves"] += trade_balance / 365.0 * 0.3  # 30٪ تراز به ذخایر
	cb["foreign_reserves"] = max(cb["foreign_reserves"], 1_000_000_000.0)

	# پایداری بانکی = f(بدهی، رشد اعتباری، نرخ بهره)
	var credit_risk = abs(cb["credit_growth"] - 0.10) * 2.0 + debt_to_gdp * 0.2 + abs(cb["interest_rate"] - 0.10) * 0.5
	var bank_stability = 0.8 - credit_risk * 0.1 + cb["independence"] * 0.1
	cb["bank_stability"] = clamp(cb["bank_stability"] * 0.99 + bank_stability * 0.01, 0.1, 0.95)

	# رشد اعتباری
	cb["credit_growth"] = clamp(cb["credit_growth"] + Deterministic.next_range(-0.002, 0.003) + (0.10 - cb["interest_rate"]) * 0.01, -0.10, 0.40)

	# استقلال بانک مرکزی
	if politics.get("stability",0.6) > 0.7 and politics.get("trust",0.55) > 0.6:
		cb["independence"] += 0.0005
	elif politics.get("stability",0.6) < 0.4:
		cb["independence"] -= 0.001
	cb["independence"] = clamp(cb["independence"], 0.1, 0.95)

	# رویدادها
	if cb["bank_stability"] < 0.4 and Deterministic.chance(0.015):
		events.append({"type": "banking_crisis", "message": "بحران بانکی - ناپایداری مالی!", "stability": cb["bank_stability"]})
		economy["growth_rate"] = economy.get("growth_rate",0.02) - 0.01
		state["economy"] = economy

	if inflation > 0.20 and Deterministic.chance(0.02):
		events.append({"type": "hyperinflation_warning", "message": "هشدار ابرتورم - تورم %s٪" % str(int(inflation*100)), "inflation": inflation})
		cb["interest_rate"] += 0.02

	if cb["foreign_reserves"] < 10_000_000_000.0 and Deterministic.chance(0.01):
		events.append({"type": "reserve_crisis", "message": "بحران ذخایر ارزی - فشار بر نرخ ارز", "reserves": cb["foreign_reserves"]})
		cb["exchange_rate"] *= 1.05

	if Deterministic.chance(0.005):
		events.append({"type": "monetary_policy_success", "message": "سیاست پولی موفق - تورم در محدوده هدف", "rate": cb["interest_rate"]})

	state["central_bank"] = cb
	
	# ── لایه واقع‌گرایانه اختصاصی بانک مرکزی (جایگزین قالب خودکار تکراری) — بخش ۳.۲۵ ──
	# قاعده تیلور: نرخ بهره متناسب با انحراف تورم از هدف و رشد تنظیم می‌شود
	var infl_gap: float = float(economy.get("inflation", 0.08)) - float(cb.get("inflation_target", 0.05))
	var taylor_rate: float = clampf(0.02 + float(cb.get("inflation_target", 0.05)) + infl_gap * 0.8 - float(economy.get("growth_rate", 0.02)) * 0.3, 0.01, 0.60)
	# بانک مستقل‌تر سریع‌تر به قاعده نزدیک می‌شود؛ مماشات دولتی نرخ را ناکارآمد نگه می‌دارد
	var w_cb: float = 0.004 * float(cb.get("independence", 0.70)) + 0.001
	cb["interest_rate"] = clampf(float(cb.get("interest_rate", 0.15)) * (1.0 - w_cb) + taylor_rate * w_cb, 0.01, 0.60)
	# نرخ بهره واقعی منفی = لنگرگریز انتظارات تورمی
	if float(cb.get("interest_rate", 0.15)) < float(economy.get("inflation", 0.08)) and Deterministic.chance(0.006):
		events.append({"type": "inflation_unanchored", "message": "لنگرگریز انتظارات تورمی - نرخ بهره واقعی منفی است", "rate": cb["interest_rate"]})
	state["central_bank"] = cb

	return {"success": true, "state": state, "events": events}
