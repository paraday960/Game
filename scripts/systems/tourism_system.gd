extends BaseSystem
# ۳.۳۰ گردشگری و خدمات - پیاده‌سازی کامل

func compute(state: Dictionary, tick: int) -> Dictionary:
	var tourism = state.get("tourism", {})
	var economy = state.get("economy", {})
	var culture = state.get("culture", {})
	var environment = state.get("environment", {})
	var security = state.get("security", {})
	var infra = state.get("infrastructure", {})
	var heritage = state.get("heritage", {})

	tourism["visitors"] = tourism.get("visitors", 5_000_000)
	tourism["revenue"] = tourism.get("revenue", 5_000_000_000.0)
	tourism["infrastructure"] = tourism.get("infrastructure", 0.55)
	tourism["service_quality"] = tourism.get("service_quality", 0.60)
	tourism["safety"] = tourism.get("safety", security.get("public_security",0.70))
	tourism["cultural_attraction"] = tourism.get("cultural_attraction", culture.get("cultural_output",0.5))
	tourism["natural_attraction"] = tourism.get("natural_attraction", environment.get("forest_coverage",0.30) + 0.3)
	tourism["visa_openness"] = tourism.get("visa_openness", 0.50)
	tourism["marketing"] = tourism.get("marketing", 0.50)
	tourism["seasonality"] = tourism.get("seasonality", 0.30)

	var events = []

	# گردشگری = f(زیرساخت، امنیت، فرهنگ، طبیعت، قیمت، روادید)
	# (بازرسی سایه‌نویسی) مدل تقاضای غنیِ این بلوک (میراث/روادید/بازاریابی/نرخ ارز)
	# هر روز محاسبه و بی‌درنگ توسط لایهٔ انتهایی بازنویسی می‌شد و کاملاً مرده بود؛
	# کانال‌هایش به هدفِ لایهٔ انتهایی منتقل شد — مالکیت یکتای visitors/revenue.
	# فصلی بودن تقاضا — در هدف لایهٔ انتهایی ضرب می‌شود
	var seasonal_factor = 1.0 + sin(float(tick) / 365.0 * 6.28 * 2.0) * tourism["seasonality"]

	# کیفیت خدمات
	tourism["service_quality"] = clamp(tourism["service_quality"] + (tourism["infrastructure"] - 0.5) * 0.001, 0.1, 0.95)

	# زیرساخت گردشگری با بودجه
	var tourism_budget_share = 0.02
	var tourism_budget = economy.get("government_spend_base",0.0) * tourism_budget_share
	tourism["infrastructure"] = clamp(tourism["infrastructure"] + (tourism_budget / 2_000_000_000.0 - 0.5) * 0.001, 0.1, 0.95)

	# ایمنی
	tourism["safety"] = security.get("public_security",0.70) * 0.7 + tourism["safety"] * 0.3

	# جذابیت فرهنگی و طبیعی
	tourism["cultural_attraction"] = culture.get("cultural_output",0.5) * 0.6 + heritage.get("preservation",0.65) * 0.4 if heritage else culture.get("cultural_output",0.5)
	tourism["natural_attraction"] = environment.get("forest_coverage",0.30) * 0.5 + environment.get("air_quality",0.6) * 0.3 + environment.get("protected_areas",0.12) * 2.0 * 0.2
	tourism["natural_attraction"] = clamp(tourism["natural_attraction"], 0.1, 0.95)

	# روادید با دیپلماسی
	var diplomacy = state.get("diplomacy",{})
	tourism["visa_openness"] = clamp(tourism["visa_openness"] + (diplomacy.get("soft_power",35.0)/100.0 - 0.5) * 0.001, 0.1, 0.90)

	# بازاریابی
	tourism["marketing"] = clamp(tourism["marketing"] + Deterministic.next_range(-0.0025, 0.0025), 0.1, 0.95)

	# اثر بر اقتصاد
	# واحد cadence (بازرسی ۱۴۰۵ — دور یازدهم): سیستم هفتگی ۵ بار در ماه می‌دود؛
	# سهم سالانهٔ درآمد گردشگری در GDP باید با ضریب ۶/۳۶۵ در هر اجرا بیاید،
	# نه ۱/۳۶۵ (قبل: فقط ٪۱۶ مقدار طراحی‌شده اعمال می‌شد).
	economy["gdp"] += tourism["revenue"] * 0.1 * 6.0 / 365.0
	state["economy"] = economy

	# اشتغال گردشگری
	var tourism_jobs = tourism["visitors"] / 100.0  # هر 100 گردشگر یک شغل
	state["welfare"]["tourism_jobs"] = tourism_jobs if state.has("welfare") else tourism_jobs

	# حلقه بازخورد: گردشگری → فرهنگ و درآمد؛ ناامنی → کاهش
	if tourism["safety"] < 0.4:
		tourism["visitors"] *= 0.95
		events.append({"type": "tourism_safety_crisis", "message": "ناامنی گردشگری - کاهش بازدیدکنندگان", "safety": tourism["safety"]})

	# رویدادها
	if tourism["visitors"] > 10_000_000 and Deterministic.chance(0.01):
		events.append({"type": "tourism_boom", "message": "رونق گردشگری - رکورد بازدیدکنندگان!", "visitors": tourism["visitors"]})

	if tourism["natural_attraction"] > 0.7 and Deterministic.chance(0.008):
		events.append({"type": "eco_tourism_growth", "message": "رشد گردشگری طبیعت - پارک‌های ملی پرطرفدار"})

	if tourism["service_quality"] < 0.4 and Deterministic.chance(0.01):
		events.append({"type": "tourism_service_crisis", "message": "بحران کیفیت خدمات گردشگری - نارضایتی"})

	if Deterministic.chance(0.006):
		events.append({"type": "cultural_festival_tourism", "message": "جشنواره فرهنگی - جذب گردشگر خارجی"})

	state["tourism"] = tourism
	
	# ── لایه واقع‌گرایانه اختصاصی گردشگری (جایگزین قالب خودکار تکراری) — بخش ۳.۳۰ ──
	# جذابیت مقصد: امنیت عمومی + طبیعت پاک + زیرساخت؛ تقاضا به‌آرامی به سمت جذابیت می‌گراید
	var appeal_t: float = float(security.get("public_security", 0.60)) * 0.40 + (1.0 - float(environment.get("pollution", 0.45))) * 0.25 + float(infra.get("quality", 0.55)) * 0.35
	# کانال‌های بیدارشدهٔ مدل مردهٔ قدیمی: میراث فرهنگی، گشودگی روادید، بازاریابی، جاذبه‌ها، نرخ ارز
	appeal_t += float(heritage.get("sites", 20)) / 50.0 * 0.06 + float(tourism["visa_openness"]) * 0.06 + float(tourism["marketing"]) * 0.05
	appeal_t += (float(tourism["cultural_attraction"]) + float(tourism["natural_attraction"]) - 1.0) * 0.05
	appeal_t += (1.0 / maxf(float(state.get("central_bank", {}).get("exchange_rate", 1.0)), 0.2) - 1.0) * 0.04  # ارز ارزان‌تر برای گردشگر
	# اتصال هوایی/دریایی/زمینی کشور (بازرسی کلید یتیم ۱۴۰۵): امتیازهای map_network قبلاً
	# بدون هیچ مصرفی نوشته می‌شدند؛ گردشگر به مقصدِ ناaccessible نمی‌رسد.
	var net_t: Dictionary = state.get("map_network", {})
	var conn_t: float = (float(net_t.get("air_connectivity", 0.5)) + float(net_t.get("sea_connectivity", 0.5)) + float(net_t.get("land_connectivity", 0.5))) / 3.0
	appeal_t += (conn_t - 0.5) * 0.05
	appeal_t = clampf(appeal_t, 0.05, 1.30)
	var visitors_target: float = (2_000_000.0 + appeal_t * 18_000_000.0) * seasonal_factor
	tourism["visitors"] = clampf(float(tourism.get("visitors", 5_000_000.0)) * 0.9995 + visitors_target * 0.0005, 0.0, 25_000_000.0)

	# درآمد: بازدیدکننده × هزینهٔ متوسطِ وابسته به کیفیت خدمات، با بازگشت آرام
	# (بازرسی: بازنویسی قبلی با نرخ ثابت ۹۰۰ هم AR درآمد و هم کانال کیفیت خدمات را می‌کشت)
	var avg_spending_t: float = 800.0 + float(tourism["service_quality"]) * 400.0
	tourism["revenue"] = float(tourism.get("revenue", 5_000_000_000.0)) * 0.9995 + float(tourism["visitors"]) * avg_spending_t * 0.0005
	if float(security.get("public_security", 0.60)) < 0.30 and Deterministic.chance(0.005):
		events.append({"type": "tourism_collapse", "message": "فروریزش گردشگری - ناامنی مقاصد را خالی کرد", "visitors": tourism["visitors"]})
	state["tourism"] = tourism

	return {"success": true, "state": state, "events": events}
