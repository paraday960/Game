extends BaseSystem
# ۳.۲۹ تجارت خارجی و گمرک — مالکیت یکتای صادرات/واردات/تراز (بازرسی تراز پرداخت‌ها)
#
# مدل: «سهم هدف از GDP + بازگشت تدریجی» — صادرات و واردات به‌جای رشد مکانیکی
# انباشتگر، هر روز ۰٫۳٪ (τ≈۱۱ ماه) به سمت هدفی حرکت می‌کنند که از GDP و سیاست‌ها
# تعیین می‌شود؛ در نتیجه با رشد اقتصاد هم‌مقیاس‌اند و تراز در بلندمدت منفجر نمی‌شود.
# اهرم‌های بازیکن (تعرفه، کاهش ارزش، مأموریت تجاری) و شوک‌ها (تحریم، محاصره، جنگ)
# از این کانال اثر واقعی می‌گذارند.
# (پیش از بازرسی سه نویسندهٔ هم‌پوشان — بلوک AR همین‌جا، لایهٔ رقابت‌پذیری انتهایی و
#  بخش تجارت economy_system — هر روز با ضربه‌های متفاوت exports/imports را می‌نوشتند؛
#  بلوک اول این سیستم کاملاً محاسبه و دور ریخته می‌شد و اثر تحریم pow هم مرده بود.)

func compute(state: Dictionary, tick: int) -> Dictionary:
	var trade = state.get("trade", {})
	var econ = state.get("economy", {})
	var diplomacy = state.get("diplomacy", {})
	var industry = state.get("industry", {})
	var agriculture = state.get("agriculture", {})
	var mil = state.get("military", {})

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

	var gdp = econ.get("gdp", 500_000_000_000.0)
	var central_bank_rate = state.get("central_bank",{}).get("exchange_rate",1.0)

	# تحریم‌های ورودی (فقط اعمال‌شده علیه بازیکن؛ تحریم‌هایی که خود بازیکن صادر کرده بی‌اثر)
	var incoming_sanctions := 0
	for sanction in diplomacy.get("sanctions", []):
		if not sanction is Dictionary or sanction.get("by", "foreign") != "player":
			incoming_sanctions += 1

	# وضعیت محاصره/جنگ (برای هر دو سمت تراز)
	var blockaded: bool = bool(mil.get("logistics_detail", {}).get("is_blockaded", false))
	var war_economy_t: float = float(mil.get("mobilization", {}).get("war_economy", 0.0))

	# ── صادرات: سهم هدف از GDP ← رقابت‌پذیری + نرخ ارز + تنوع صادراتی − تحریم − محاصره ──
	# محاصرهٔ دریایی صادرات را سخت‌تر از واردات می‌زند (نفت/کالا راهی برای خروج ندارد)
	var comps: float = float(industry.get("advanced", 0.15)) * 0.5 + float(trade["customs_efficiency"]) * 0.3 - float(econ.get("inflation", 0.08)) * 0.5
	var fx_bonus: float = (float(central_bank_rate) - 1.0) * 0.5  # ارز ضعیف‌تر → کالای صادراتی ارزان‌تر و رقابتی‌تر
	# لجستیک و اتصال شبکه (بازرسی کلید یتیم ۱۴۰۵): قبلاً transit_manager و map_layer_manager
	# و blue_economy_manager مستقیم و بی‌بازخوان روی سطح exports می‌نوشتند (نویسندهٔ سرکش)؛
	# حالا مالکیت یکتای سطح با همین سیستم است و اثر لجستیک/بنادر/اختلال مسیرها از «کانال هدف» عبور می‌کند.
	var freight_t: float = float(state.get("transit_policy", {}).get("freight", 0.30))
	var net_t: Dictionary = state.get("map_network", {})
	var conn_t: float = (float(net_t.get("air_connectivity", 0.5)) + float(net_t.get("sea_connectivity", 0.5)) + float(net_t.get("land_connectivity", 0.5))) / 3.0
	var disrupted_t: float = minf(float(net_t.get("disrupted_routes", 0)), 3.0)
	var blue_t: Dictionary = state.get("blue_economy_policy", {})
	var port_t: float = (float(blue_t.get("port_capacity", 0.40)) + float(blue_t.get("merchant_fleet", 0.30))) / 2.0
	var logistics_t: float = freight_t * 0.45 + conn_t * 0.35 + port_t * 0.20
	# دسترسی پایدار به بازار (مأموریت تجاری / رأی کریدور سازمان‌ها) — به‌جای ضربهٔ یک‌بارهٔ سطح
	var market_access_t: float = minf(float(trade.get("market_access_bonus", 0.0)), 0.02)
	var export_share_t: float = clamp(0.13 + comps * 0.03 + fx_bonus * 0.02 + float(trade["export_diversity"]) * 0.02 + logistics_t * 0.015 + market_access_t - disrupted_t * 0.004 - incoming_sanctions * 0.008 - (0.07 if blockaded else 0.0), 0.06, 0.25)
	trade["export_share_target"] = export_share_t
	trade["exports"] = maxf(float(trade["exports"]) * 0.997 + gdp * export_share_t * 0.003, 1_000_000_000.0)

	# ── واردات: سهم هدف ← تعرفه (اهرم بازیکن)، محاصرهٔ دریایی، اقتصاد جنگی، پوشش تولید داخل ──
	# بازخورد ذخایر ارزی (بازرسی تراز پرداخت‌ها): پوشش واردات زیر ~۳ ماه یعنی کشور
	# توان تأمین ارز واردات را ندارد → واردات فشرده می‌شود (حلقهٔ منفیِ بحران ارزی:
	# واردات کمتر → تراز بهتر → ذخایر بازسازی می‌شود).
	var reserves_t: float = float(state.get("economy", {}).get("foreign_reserves", 60_000_000_000.0))
	var import_cover: float = reserves_t / maxf(float(trade.get("imports", 70_000_000_000.0)) / 12.0, 1.0)
	trade["import_cover_months"] = import_cover
	var cover_pen: float = clampf((3.0 - import_cover) * 0.008, 0.0, 0.03)
	var domestic_coverage: float = (float(industry.get("output", 100.0)) + float(agriculture.get("production", 100.0))) / 200.0
	# حساسیت واردات به نرخ ارز (بازرسی کلید یتیم ۱۴۰۵): ارز ضعیف (rate>۱) واردات را گران
	# و فشرده می‌کند؛ تا پیش از این devalue فقط سطح را یک‌باره می‌شکست و اثر پایدار نداشت.
	var fx_import_t: float = (1.0 - float(central_bank_rate)) * 0.015
	var import_share_t: float = clamp(0.16 - float(trade["tariff_rate"]) * 0.25 - (0.05 if blockaded else 0.0) - cover_pen + war_economy_t * 0.02 + (1.0 - domestic_coverage) * 0.04 + fx_import_t, 0.05, 0.30)
	trade["import_share_target"] = import_share_t
	trade["imports"] = maxf(float(trade["imports"]) * 0.997 + gdp * import_share_t * 0.003, 1_000_000_000.0)

	# ── تراز تجاری ──
	trade["balance"] = float(trade["exports"]) - float(trade["imports"])
	trade["trade_deficit"] = maxf(-float(trade["balance"]), 0.0)

	# آمار درآمد گمرکی (نرخ ماهانه) — واریز واقعی به خزانه در economy_system لحاظ می‌شود
	trade["customs_revenue"] = float(trade["imports"]) * float(trade["tariff_rate"]) * float(trade["customs_efficiency"]) / 12.0

	# تعرفه - سیاست تجاری (حلقهٔ منفی واقع‌گرایانه: کسری مزمن → تعرفه → واردات کمتر)
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

	# اطلاع‌رسانی اثر تحریم (اثر واقعی از طریق جریمهٔ سهم صادرات اعمال شد؛ اینجا فقط خبر)
	if incoming_sanctions > 0 and Deterministic.chance(0.008):
		events.append({"type": "sanction_trade_effect", "message": "تحریم‌های خارجی تجارت را محدود کرد", "balance": trade["balance"], "sanctions": incoming_sanctions})

	# رویدادها
	if trade["import_dependency"] > 0.7 and Deterministic.chance(0.01):
		events.append({"type": "import_dependency_crisis", "message": "وابستگی شدید به واردات - آسیب‌پذیری در تحریم", "dependency": trade["import_dependency"]})

	if trade["balance"] < -30_000_000_000.0 and Deterministic.chance(0.015):
		events.append({"type": "trade_deficit_crisis", "message": "کسری تجاری بحرانی - فشار بر ارز و بدهی", "balance": trade["balance"]})

	if trade["export_diversity"] > 0.7 and Deterministic.chance(0.008):
		events.append({"type": "export_diversification_success", "message": "تنوع صادرات موفق - کاهش وابستگی به نفت"})

	state["trade"] = trade

	return {"success": true, "state": state, "events": events}
