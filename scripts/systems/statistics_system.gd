extends BaseSystem
# ۳.۳۴ آمار، ثبت احوال و سرشماری - پیاده‌سازی کامل

func compute(state: Dictionary, tick: int) -> Dictionary:
	var stats = state.get("statistics", {})
	var pop = state.get("population", {})
	var economy = state.get("economy", {})

	stats["accuracy"] = stats.get("accuracy", 0.75)
	stats["coverage"] = stats.get("coverage", 0.85)
	stats["digital"] = stats.get("digital", 0.60)
	stats["census_last"] = stats.get("census_last", 2020)
	stats["birth_registry"] = stats.get("birth_registry", 0.90)
	stats["death_registry"] = stats.get("death_registry", 0.88)
	stats["marriage_registry"] = stats.get("marriage_registry", 0.85)
	stats["company_registry"] = stats.get("company_registry", 0.70)
	stats["property_registry"] = stats.get("property_registry", 0.65)
	stats["id_coverage"] = stats.get("id_coverage", 0.92)
	stats["data_transparency"] = stats.get("data_transparency", 0.60)

	var events = []

	var digital_branch = state.get("technology",{}).get("branches",{}).get("دیجیتال",0.20)

	# دقت آمار = f(پوشش، دیجیتال، بودجه، فساد)
	var infra_q = state.get("infrastructure",{}).get("quality",0.55)
	var corruption = state.get("politics",{}).get("corruption",0.30)
	var accuracy_target = 0.6 + stats["coverage"] * 0.2 + stats["digital"] * 0.15 + infra_q * 0.1 - corruption * 0.2
	stats["accuracy"] = clamp(stats["accuracy"] * 0.99 + accuracy_target * 0.01, 0.3, 0.98)

	# پوشش
	stats["coverage"] = clamp(stats["coverage"] + (stats["digital"] - 0.5) * 0.001, 0.5, 0.99)

	# دیجیتال‌سازی
	stats["digital"] = clamp(stats["digital"] + digital_branch * 0.001 + 0.0005, 0.1, 0.95)

	# ثبت احوال
	stats["birth_registry"] = clamp(stats["birth_registry"] + (stats["digital"] - 0.5) * 0.001, 0.6, 0.99)
	stats["death_registry"] = clamp(stats["death_registry"] + (stats["digital"] - 0.5) * 0.001, 0.6, 0.99)
	stats["marriage_registry"] = clamp(stats["marriage_registry"] + stats["digital"] * 0.0005, 0.5, 0.98)

	# ثبت شرکت و ملک
	stats["company_registry"] = clamp(stats["company_registry"] + digital_branch * 0.001, 0.3, 0.95)
	stats["property_registry"] = clamp(stats["property_registry"] + digital_branch * 0.0008, 0.3, 0.90)

	# پوشش کارت ملی / شناسه
	stats["id_coverage"] = clamp(stats["id_coverage"] + stats["digital"] * 0.0005, 0.7, 0.99)

	# شفافیت داده
	var media_freedom = state.get("culture",{}).get("media_freedom",0.5)
	stats["data_transparency"] = clamp(stats["data_transparency"] * 0.995 + (media_freedom * 0.5 + stats["accuracy"] * 0.3) * 0.005, 0.2, 0.95)

	# سرشماری دوره‌ای
	if tick % (365 * 5) == 0:  # هر ۵ سال
		stats["census_last"] = state.get("clock",{}).get("year",2027)
		events.append({"type": "census_conducted", "message": "سرشماری سراسری انجام شد - دقت آمار افزایش یافت", "year": stats["census_last"]})
		stats["accuracy"] += 0.05
		stats["coverage"] += 0.02

	# اثر بر سایر سیستم‌ها: دقت آمار پایین → تصمیم اشتباه → کاهش کارآمدی
	if stats["accuracy"] < 0.5:
		state["economy"]["growth_rate"] = state.get("economy",{}).get("growth_rate",0.02) - 0.001
		events.append({"type": "poor_statistics", "message": "آمار نادقیق - برنامه‌ریزی اشتباه و هدررفت منابع", "accuracy": stats["accuracy"]})

	# حلقه: هویت ← دسترسی ← مشارکت ← ثبت
	if stats["id_coverage"] > 0.9:
		state["population"]["happiness"] = clamp(state.get("population",{}).get("happiness",0.6) + 0.0002, 0.05, 0.95)

	# رویدادها
	if stats["digital"] > 0.7 and Deterministic.chance(0.006):
		events.append({"type": "digital_registry_success", "message": "تحول دیجیتال ثبت - سامانه هوشمند ثبت احوال"})

	if stats["property_registry"] < 0.5 and Deterministic.chance(0.008):
		events.append({"type": "land_registry_crisis", "message": "بحران ثبت ملک - دعاوی زمین و معاملات غیررسمی"})

	if stats["id_coverage"] < 0.8 and Deterministic.chance(0.01):
		events.append({"type": "id_coverage_crisis", "message": "پوشش پایین کارت ملی - محرومیت از خدمات"})

	state["statistics"] = stats
	
		# ── لایه واقع‌گرایانه اختصاصی آمار و ثبت احوال (جایگزین قالب خودکار) — بخش ۳.۳۴ ──
	# سرشماری پنج‌سالانه: علاوه بر ثبت تاریخ، جهش دقت آمار و رویداد خبری دارد (هزینه نمادین دولتی)
	if tick > 0 and tick % (365 * 5) == 0:
		stats["accuracy"] = clampf(float(stats.get("accuracy", 0.75)) + 0.03, 0.30, 0.98)
		events.append({"type": "census_conducted", "message": "سرشماری عمومی نفوس و مسکن انجام شد - به‌روزرسانی پایگاه داده ملی"})
	# ریسک خطای سیاست‌گذاری: حاصل‌ضرب دقت و پوشش پایین یعنی دولت عملاً کور تصمیم می‌گیرد
	stats["policy_error_risk"] = clampf(1.0 - float(stats.get("accuracy", 0.75)) * float(stats.get("coverage", 0.85)), 0.0, 0.90)
	if float(stats["policy_error_risk"]) > 0.45 and Deterministic.chance(0.004):
		events.append({"type": "policy_misjudgment", "message": "تردید جدی در آمار رسمی - خطر تصمیم‌گیری بر مبنای داده‌های نادرست"})
	# برآورد اقتصاد غیررسمی از خلأ ثبت شرکت‌ها و املاک — ملاک محاسبات مالیاتی
	stats["informal_economy_estimate"] = clampf((1.0 - float(stats.get("company_registry", 0.70))) * 0.35 + (1.0 - float(stats.get("property_registry", 0.65))) * 0.15, 0.03, 0.60)
	# شکاف ثبت وفات → آمار بهداشتی مخدوش و شیوع پنهان
	if float(stats.get("death_registry", 0.88)) < 0.75 and Deterministic.chance(0.004):
		events.append({"type": "unregistered_deaths", "message": "بخشی از مرگ‌ومیر کشور ثبت نمی‌شود - آمار بهداشتی ناقص است"})
	# شفافیت پایین داده → رانت اطلاعاتی و بدبینی عمومی
	if float(stats.get("data_transparency", 0.60)) < 0.35 and Deterministic.chance(0.003):
		events.append({"type": "data_opacity", "message": "توقف انتشار آمارهای کلیدی - نگرانی عمومی درباره شفافیت داده‌ها"})
	state["statistics"] = stats

	return {"success": true, "state": state, "events": events}
