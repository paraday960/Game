extends BaseSystem
# ۳.۲۲ فرهنگ، رسانه و هویت - پیاده‌سازی کامل

func compute(state: Dictionary, tick: int) -> Dictionary:
	var culture = state.get("culture", {})
	var politics = state.get("politics", {})
	var pop = state.get("population", {})
	var education = state.get("education", {})
	var economy = state.get("economy", {})
	var diplomacy = state.get("diplomacy", {})

	culture["cohesion"] = culture.get("cohesion", 0.65)
	culture["media_freedom"] = culture.get("media_freedom", 0.5)
	culture["media_trust"] = culture.get("media_trust", 0.45)
	culture["identity"] = culture.get("identity", 0.70)
	culture["media_diversity"] = culture.get("media_diversity", 0.55)
	culture["soft_power"] = culture.get("soft_power", diplomacy.get("soft_power",35.0) / 100.0)
	culture["cultural_output"] = culture.get("cultural_output", 0.50)
	culture["public_opinion"] = culture.get("public_opinion", 0.60)
	culture["misinformation_risk"] = culture.get("misinformation_risk", 0.30)
	culture["cultural_heritage"] = culture.get("cultural_heritage", 0.65)

	var events = []

	var culture_budget_share = economy.get("budget_allocations", {}).get("محیط", 0.03)  # فرهنگ از بودجه محیط/اداره
	var culture_budget = economy.get("government_spending",0.0) * 0.03  # 3٪

	# فرمول‌ها - ۳.۲۲.۳
	# افکار عمومی = f(رسانه، رویدادها، سیاست)
	var media_effect = culture["media_trust"] * 0.4 + culture["media_diversity"] * 0.2
	var politics_effect = politics.get("trust",0.55) * 0.2 + politics.get("stability",0.6) * 0.2
	var public_opinion = 0.5 + media_effect * 0.3 + politics_effect * 0.2 + (pop.get("happiness",0.6) - 0.5) * 0.3
	culture["public_opinion"] = clamp(culture["public_opinion"] * 0.98 + public_opinion * 0.02, 0.05, 0.95)

	# انسجام ملی = f(هویت، فرهنگ، عدالت)
	var social_justice = state.get("welfare",{}).get("social_justice",0.6) if state.has("welfare") else 0.6
	var cohesion = 0.5
	cohesion += culture["identity"] * 0.3
	cohesion += culture["cultural_output"] * 0.2
	cohesion += social_justice * 0.2
	cohesion += pop.get("happiness",0.6) * 0.1
	cohesion += (1.0 - state.get("ethnicity",{}).get("tension",0.3)) * 0.1 if state.has("ethnicity") else 0
	culture["cohesion"] = clamp(culture["cohesion"] * 0.99 + cohesion * 0.01, 0.1, 0.95)

	# اثر رسانه = f(اعتماد، دسترسی، کیفیت خبر)
	var media_literacy = education.get("quality",0.55) * 0.7 + culture["media_freedom"] * 0.3
	var media_impact = culture["media_trust"] * 0.5 + media_literacy * 0.3 + culture["media_diversity"] * 0.2
	culture["media_impact"] = clamp(media_impact, 0.05, 0.95)

	# قدرت نرم = f(فرهنگ، رسانه، جذابیت)
	var soft_power = 0.0
	soft_power += culture["cultural_output"] * 30.0
	soft_power += culture["cohesion"] * 20.0
	soft_power += culture["media_impact"] * 15.0
	soft_power += education.get("quality",0.55) * 10.0
	culture["soft_power"] = clamp(soft_power / 100.0, 0.0, 1.0)
	diplomacy["soft_power"] = soft_power
	state["diplomacy"] = diplomacy

	# ریسک اطلاعات نادرست = f(رسانه، آموزش، سواد رسانه‌ای)
	var misinfo = 0.3
	misinfo += (1.0 - culture["media_trust"]) * 0.3
	misinfo += (1.0 - media_literacy) * 0.3
	misinfo += (1.0 - culture["media_freedom"]) * 0.2
	# آزادی زیاد بدون سواد → ریسک بالا
	if culture["media_freedom"] > 0.7 and media_literacy < 0.5:
		misinfo += 0.2
	culture["misinformation_risk"] = clamp(culture["misinformation_risk"] * 0.99 + misinfo * 0.01, 0.0, 0.9)

	# آزادی رسانه پویا
	if politics.get("stability",0.6) < 0.4 and Deterministic.chance(0.01):
		culture["media_freedom"] -= 0.01  # دولت برای کنترل آزادی را کم می‌کند
		events.append({"type": "media_censorship", "message": "افزایش سانسور رسانه به دلیل بی‌ثباتی"})
	elif politics.get("trust",0.55) > 0.7 and Deterministic.chance(0.005):
		culture["media_freedom"] += 0.005
	culture["media_freedom"] = clamp(culture["media_freedom"], 0.05, 0.95)

	# اعتماد به رسانه
	var media_trust_change = (culture["media_diversity"] - 0.5) * 0.002 + (culture["media_freedom"] - 0.5) * 0.001 - culture["misinformation_risk"] * 0.002
	culture["media_trust"] = clamp(culture["media_trust"] + media_trust_change, 0.05, 0.95)

	# تنوع رسانه
	culture["media_diversity"] = clamp(culture["media_diversity"] + Deterministic.next_range(-0.002, 0.003), 0.1, 0.95)

	# تولید فرهنگی
	# نُرم مرجع: ~۰.۶٪ تولید ناخالص سالانه برای فرهنگ — جریمه پنهان −۰.۵ قدیمی حذف شد
	var culture_norm: float = max(float(economy.get("gdp", 1.0)), 1.0) * 0.006 / 12.0
	culture["cultural_output"] = clamp(culture["cultural_output"] + clampf(culture_budget / culture_norm - 1.0, -1.0, 1.0) * 0.0005 + education.get("quality",0.55) * 0.0005, 0.1, 0.95)

	# هویت ملی
	culture["identity"] = clamp(culture["identity"] + (culture["cohesion"] - 0.5) * 0.001, 0.1, 0.95)

	# حلقه بازخورد: رسانه ← افکار عمومی ← سیاست؛ فرهنگ ← هویت ← انسجام
	politics["trust"] = clamp(politics.get("trust",0.55) + (culture["public_opinion"] - 0.5) * 0.001, 0.05, 0.95)
	state["politics"] = politics

	# رویدادها - ۳.۲۲.۵
	if culture["misinformation_risk"] > 0.6 and Deterministic.chance(0.015):
		events.append({"type": "misinformation_crisis", "message": "بحران اطلاعات نادرست - شایعات گسترده", "risk": culture["misinformation_risk"]})
		politics["stability"] -= 0.02
		state["politics"] = politics

	if culture["media_trust"] < 0.3 and Deterministic.chance(0.01):
		events.append({"type": "media_trust_crisis", "message": "بحران اعتماد به رسانه‌ها"})

	if Deterministic.chance(0.008):
		var r = Deterministic.next_float()
		if r < 0.4:
			events.append({"type": "cultural_movement", "message": "جنبش فرهنگی و هنری جدید", "cohesion_boost": 0.02})
			culture["cohesion"] += 0.02
		elif r < 0.7:
			events.append({"type": "media_scandal", "message": "رسوایی رسانه‌ای", "trust_loss": -0.05})
			culture["media_trust"] -= 0.05
		else:
			events.append({"type": "cultural_festival", "message": "جشنواره فرهنگی موفق - افزایش قدرت نرم"})

	state["culture"] = culture
	
	# ── لایه واقع‌گرایانه اختصاصی فرهنگ (جایگزین قالب خودکار تکراری) — بخش ۳.۲۲ ──
	# انسجام اجتماعی: آموزش و اعتماد سازنده؛ نابرابری فرساینده
	var gini_c: float = float(state.get("welfare", {}).get("gini", 0.38))
	var edu_q_c: float = float(education.get("quality", 0.50))
	var trust_c: float = float(politics.get("trust", 0.55))
	var coh_target: float = clampf(0.35 + edu_q_c * 0.25 + trust_c * 0.25 - gini_c * 0.30, 0.10, 0.95)
	culture["cohesion"] = clampf(float(culture.get("cohesion", 0.65)) * 0.998 + coh_target * 0.002, 0.10, 0.95)
	# سرمایه اجتماعی از انسجام و اعتماد
	culture["social_capital"] = clampf(float(culture.get("social_capital", 0.50)) * 0.997 + (float(culture.get("cohesion", 0.65)) * 0.6 + trust_c * 0.4) * 0.003, 0.10, 0.95)
	if float(culture.get("cohesion", 0.65)) < 0.30 and Deterministic.chance(0.005):
		events.append({"type": "cohesion_crisis", "message": "ترک‌خوردگی اجتماعی - گسست اعتماد میان گروه‌های اجتماعی عمیق شد", "cohesion": culture["cohesion"]})
	state["culture"] = culture

	return {"success": true, "state": state, "events": events}
