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
	# قاعدهٔ تیلور استاندارد (بازرسی نرخ واقعی ۱۴۰۵): r = r* + π + ۰٫۵(π−π*) + ۰٫۵(شکاف رشد)
	# پیش از این r* با π* (۵٪) جایگزین شده بود → تعادل نامی ~۱۵٪ یعنی نرخ واقعی ~۱۰٪؛
	# چسبندگی اعتباری غیرواقعی. نرخ خنثای واقعی صریح (۲٪) تعادل واقع‌بینانه می‌دهد.
	var neutral_real: float = float(BalanceConfig.get_value("monetary.neutral_real_rate", 0.02))
	var neutral_nominal: float = float(cb["inflation_target"]) + neutral_real  # لنگر نامی خنثی = π* + r*
	var inflation_gap = inflation - cb["inflation_target"]
	var growth_gap = growth - 0.025
	var taylor_rate = neutral_real + inflation + 0.5 * inflation_gap + 0.5 * growth_gap
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
		# (بازرسی بانک مرکزی) قاعدهٔ تیلور یکتا — پیش‌تر دو قاعدهٔ هم‌پوشان (این‌جا و لایهٔ
		# انتهایی فایل) با سرعت/هدف متفاوت روی یک کلید می‌نشستند: تعادل ~۱٫۶ واحد منحرف و
		# هم‌جویی با آینه شکسته بود؛ حتی نام متغیر دوباره تعریف می‌شد. حالا یک جاذب واحد:
		# سرعت نزدیک‌شدن با استقلال بانک مقیاس می‌شود (مستقل‌تر → واکنش سریع‌تر، τ≈۳۳–۱۰۰ روز).
		var taylor_step: float = 0.010 + float(cb["independence"]) * 0.02
		cb["interest_rate"] = clamp(cb["interest_rate"] * (1.0 - taylor_step) + (taylor_rate + political_pressure) * taylor_step, 0.01, 0.60)

	# عرضه پول و نقدینگی
	# نرخ بهره بالا → عرضه کم، رشد کم؛ پایین → رشد اما ریسک تورم
	# لنگر عرضه: نرخ نامی خنثی (π*+r*) نه ثابت تاریخی ۰٫۱۵ — با تعادل تیلور جدید هم‌بسته است.
	var money_change = (neutral_nominal - cb["interest_rate"]) * 0.01 + growth_gap * 0.005
	cb["money_supply"] = clamp(cb["money_supply"] + money_change * 0.01, 0.5, 1.8)

	# تورم هدف با نرخ بهره کنترل می‌شود
	# تورم = f(عرضه پول، تقاضا، انتظارات)
	var money_effect = (cb["money_supply"] - 1.0) * 0.03
	var demand_effect = growth * 0.35
	# اثر نرخ بهره بر تورم (با تاخیر): نرخ بالاتر از نرخ خنثی تورم را مهار می‌کند؛
	# لنگر ثابت ۰٫۰۸ با تعادل جدید تیلور ناسازگار بود (رقصانش به تورم مثبت).
	var rate_effect = (neutral_nominal - cb["interest_rate"]) * 0.12
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
	# (بازرسی ارزی) زوال صرف مداخله: مداخلهٔ بانک مرکزی برخلاف تغییر ارزش‌گذاری (devalue)
	# دائمی نیست — صرف آن به‌صورت موجودی محوشونده (τ≈۸ ماه) به نرخ برمی‌گردد تا حمایت
	# مصنوعی فقط زمان بخرد، نه سطح بنیادی را برای همیشه جابه‌جا کند.
	var forex_fx: Dictionary = state.get("forex", {})
	var prem: float = float(forex_fx.get("intervention_premium", 0.0))
	if prem != 0.0:
		var prem_fade: float = prem * 0.004
		cb["exchange_rate"] = clamp(float(cb["exchange_rate"]) * (1.0 - prem_fade), 0.2, 5.0)
		forex_fx["intervention_premium"] = prem - prem_fade
		state["forex"] = forex_fx

	# ذخایر ارزی — مخزن مرجع state.economy.foreign_reserves است (بازرسی تراز پرداخت‌ها).
	# پیش‌تر تراز تجاری به cb.foreign_reserves می‌ریخت که نه در UI دیده می‌شد و نه هزینه‌کردهای
	# واقعی (مداخله ارزی، بازار کالا، سازمان‌ها — همگی از economy.foreign_reserves کم می‌کنند)
	# با آن ارتباط داشتند: split-brain؛ بازیکن با کسری تجاری دائم هرگز ذخایرش را خالی نمی‌دید.
	# از این پس هر دو نام یک مخزن واحد را نشان می‌دهند و کسری تجاری واقعاً ذخایر را می‌خورد.
	var reserves_now: float = float(economy.get("foreign_reserves", 60_000_000_000.0))
	reserves_now += trade_balance / 365.0 * 0.3  # 30٪ تراز سالانه به ذخایر
	reserves_now = max(reserves_now, 0.0)
	economy["foreign_reserves"] = reserves_now
	cb["foreign_reserves"] = reserves_now  # آینهٔ سازگاری برای سیوهای قدیمی
	state["economy"] = economy

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
		# بازرسی ۱۴۰۵: نویسهٔ نمایشی growth_rate حذف شد (مالکیت یکتا: economy_system؛
		# اثر واقعی بحران بانکی از کانال اعتبار بانکی/فروکش بحران banking_manager می‌گذرد)
		state["economy"] = economy

	if inflation > 0.20 and Deterministic.chance(0.02):
		events.append({"type": "hyperinflation_warning", "message": "هشدار ابرتورم - تورم %s٪" % str(int(inflation*100)), "inflation": inflation})
		cb["interest_rate"] += 0.02

	if reserves_now < 10_000_000_000.0 and Deterministic.chance(0.01):
		events.append({"type": "reserve_crisis", "message": "بحران ذخایر ارزی - فشار بر نرخ ارز", "reserves": reserves_now})
		cb["exchange_rate"] *= 1.05

	if Deterministic.chance(0.005):
		events.append({"type": "monetary_policy_success", "message": "سیاست پولی موفق - تورم در محدوده هدف", "rate": cb["interest_rate"]})

	state["central_bank"] = cb
	
	# ── رویداد لنگرگریز انتظارات (بخش ۳.۲۵) ──
	# قاعدهٔ تیلور دوم این‌جا بودکه با قاعدهٔ اصلی هم‌پوشانی داشت و در بازرسی حذف/ادغام شد
	# (سرعتِ استقلال‌وابسته حالا در همان جاذب واحد بالاست). فقط رویداد هشدار می‌ماند:
	# نرخ بهره واقعی منفی = لنگرگریز انتظارات تورمی
	if float(cb.get("interest_rate", 0.15)) < float(economy.get("inflation", 0.08)) and Deterministic.chance(0.006):
		events.append({"type": "inflation_unanchored", "message": "لنگرگریز انتظارات تورمی - نرخ بهره واقعی منفی است", "rate": cb["interest_rate"]})
	state["central_bank"] = cb

	return {"success": true, "state": state, "events": events}
