extends BaseSystem
# ۳.۳۳ بازار سرمایه و بورس - پیاده‌سازی کامل

func compute(state: Dictionary, tick: int) -> Dictionary:
	var stock = state.get("stock_market", {})
	var econ = state.get("economy", {})
	var politics = state.get("politics", {})
	var tech = state.get("technology", {})
	var central_bank = state.get("central_bank", {})
	var culture = state.get("culture", {})

	stock["index"] = stock.get("index", 1000.0)
	stock["market_cap"] = stock.get("market_cap", econ.get("gdp",500_000_000_000.0) * 0.4)
	stock["volume"] = stock.get("volume", 1_000_000_000.0)
	stock["volatility"] = stock.get("volatility", 0.15)
	stock["investor_confidence"] = stock.get("investor_confidence", 0.60)
	stock["foreign_investment"] = stock.get("foreign_investment", 10_000_000_000.0)
	stock["listed_companies"] = stock.get("listed_companies", 400)
	stock["pe_ratio"] = stock.get("pe_ratio", 8.5)
	stock["regulation"] = stock.get("regulation", 0.60)
	stock["transparency"] = stock.get("transparency", 0.55)

	var events = []

	var growth = econ.get("growth_rate",0.02)
	var inflation = econ.get("inflation",0.08)
	var interest_rate = central_bank.get("interest_rate",0.15)
	var stability = politics.get("stability",0.6)
	var corruption = politics.get("corruption",0.30)

	# شاخص بورس = f(سود شرکت‌ها، نرخ بهره، اعتماد، رشد)
	var earnings_growth = growth * 1.5
	var interest_effect = (0.15 - interest_rate) * 0.5  # نرخ پایین → بورس بالا
	var confidence_effect = (stock["investor_confidence"] - 0.5) * 0.2
	var stability_effect = (stability - 0.5) * 0.3

	var daily_return = earnings_growth / 365.0 + interest_effect / 365.0 + confidence_effect * 0.001 + stability_effect * 0.001 + Deterministic.next_range(-0.015, 0.015)
	# نوسان
	daily_return += Deterministic.next_range(-stock["volatility"], stock["volatility"]) * 0.1

	stock["index"] = max(10.0, stock["index"] * (1.0 + daily_return))

	# ارزش بازار
	stock["market_cap"] = stock["index"] * 500_000_000.0  # ساده‌سازی
	stock["market_cap"] = clamp(stock["market_cap"], 10_000_000_000.0, 2_000_000_000_000.0)

	# حجم معاملات
	stock["volume"] = stock["market_cap"] * 0.01 * (1.0 + stock["volatility"])

	# اعتماد سرمایه‌گذار = f(ثبات، شفافیت، رشد، قانون)
	var confidence = 0.5 + stability * 0.2 + stock["transparency"] * 0.2 + growth * 5.0 - corruption * 0.2 - inflation * 0.5
	stock["investor_confidence"] = clamp(stock["investor_confidence"] * 0.99 + confidence * 0.01, 0.05, 0.95)

	# نوسان = f(تورم، بی‌ثباتی، نرخ بهره)
	var vol = 0.10 + abs(inflation - 0.05) * 0.5 + (1.0 - stability) * 0.2 + abs(interest_rate - 0.10) * 0.3
	stock["volatility"] = clamp(stock["volatility"] * 0.98 + vol * 0.02, 0.05, 0.60)

	# سرمایه‌گذاری خارجی
	var fdi_target = stock["investor_confidence"] * 20_000_000_000.0 * stability
	stock["foreign_investment"] = stock["foreign_investment"] * 0.999 + fdi_target * 0.001

	# نسبت قیمت به سود
	var pe = 8.0 + growth * 100.0 - interest_rate * 20.0 + stock["investor_confidence"] * 5.0
	stock["pe_ratio"] = clamp(stock["pe_ratio"] * 0.99 + pe * 0.01, 3.0, 30.0)

	# مقررات و شفافیت
	var regulation_target = 0.6 + (1.0 - corruption) * 0.2 + stock["transparency"] * 0.1
	stock["regulation"] = clamp(stock["regulation"] * 0.999 + regulation_target * 0.001, 0.2, 0.95)
	stock["transparency"] = clamp(stock["transparency"] + Deterministic.next_range(-0.0015, 0.0015), 0.2, 0.95)

	# شرکت‌های فهرست شده
	if stock["investor_confidence"] > 0.7 and Deterministic.chance(0.005):
		stock["listed_companies"] += 1

	# اثر بر اقتصاد
	econ["gdp"] += stock["foreign_investment"] * 0.01 / 365.0
	state["economy"] = econ

	# رویدادها
	if stock["volatility"] > 0.4 and Deterministic.chance(0.015):
		events.append({"type": "stock_crash_risk", "message": "نوسان شدید بورس - ریسک سقوط!", "volatility": stock["volatility"], "index": stock["index"]})
		stock["investor_confidence"] -= 0.05

	if stock["index"] < 500.0 and Deterministic.chance(0.01):
		events.append({"type": "bear_market", "message": "بازار خرسی - افت شدید بورس و خروج سرمایه", "index": stock["index"]})

	if stock["index"] > 3000.0 and Deterministic.chance(0.01):
		events.append({"type": "bull_market", "message": "بازار گاوی - رونق بورس و ورود سرمایه!", "index": stock["index"]})

	if stock["transparency"] < 0.4 and Deterministic.chance(0.01):
		events.append({"type": "market_manipulation_scandal", "message": "افشای دستکاری بازار - بحران اعتماد"})

	if Deterministic.chance(0.008):
		events.append({"type": "ipo_success", "message": "عرضه اولیه موفق - افزایش ارزش بازار"})

	state["stock_market"] = stock
	
	# ── لایه واقع‌گرایانه اختصاصی بورس (جایگزین قالب خودکار تکراری) — بخش ۳.۳۳ ──
	# هشدار حباب دارایی: نسبت قیمت به درآمد بالا + هیجان سرمایه‌گذار
	var pe_s: float = float(stock.get("pe_ratio", 8.5))
	if pe_s > 20.0 and float(stock.get("investor_confidence", 0.60)) > 0.75 and Deterministic.chance(0.004):
		events.append({"type": "bubble_risk", "message": "هشدار حباب بورس - ارزش‌گذاری‌ها از بنیادها فاصله گرفت", "pe": pe_s})
	# سرمایه خارجی با ثبات سیاسی و نرخ بهره واقعی (کری ترید) جذب/فراری می‌شود
	var real_rate_s: float = float(central_bank.get("interest_rate", 0.15)) - float(econ.get("inflation", 0.08))
	var flow_s: float = (float(politics.get("stability", 0.60)) - 0.5) * 0.0004 + clampf(real_rate_s, -0.1, 0.15) * 0.0008
	stock["foreign_investment"] = maxf(float(stock.get("foreign_investment", 10_000_000_000.0)) * (1.0 + flow_s), 0.0)
	if real_rate_s < -0.05 and Deterministic.chance(0.004):
		events.append({"type": "capital_flight", "message": "خروج سرمایه خارجی - نرخ بهره واقعی منفی سرمایه را فراری داد", "real_rate": real_rate_s})
	state["stock_market"] = stock

	return {"success": true, "state": state, "events": events}
