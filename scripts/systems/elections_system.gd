extends BaseSystem
# ۳.۶۵ رأی‌گیری و انتخابات - سیستم کامل + ۳.۱۲ انتخابات سیاسی

func compute(state: Dictionary, tick: int) -> Dictionary:
	var elections = state.get("elections", {})
	var politics = state.get("politics", {})
	var pop = state.get("population", {})
	var culture = state.get("culture", {})

	elections["participation"] = elections.get("participation", 0.60)
	elections["transparency"] = elections.get("transparency", 0.55)
	elections["party_system"] = elections.get("party_system", 0.60)
	elections["campaign_cost"] = elections.get("campaign_cost", 0.40)
	elections["voter_turnout"] = elections.get("voter_turnout", elections["participation"])
	elections["last_election_year"] = elections.get("last_election_year", 2024)
	elections["next_election_year"] = elections.get("next_election_year", 2028)
	elections["ruling_party_support"] = elections.get("ruling_party_support", 0.55)
	elections["opposition_support"] = elections.get("opposition_support", 0.45)
	elections["fraud_risk"] = elections.get("fraud_risk", 0.15)

	var events = []

	var year = state.get("clock",{}).get("year",2027)
	# اگرچه بازیکن رهبر مطلق و غیرقابل برکناری است (قانون بازی)، اما انتخابات برای نهادهای دیگر برگزار می‌شود
	# این سیستم مشارکت و مشروعیت را می‌سازد - بخش ۳.۶۵

	# فرمول‌ها - ۳.۶۵
	# مشارکت = f(رضایت، اعتماد، اهمیت انتخابات، دسترسی)
	var happiness = pop.get("happiness",0.6)
	var trust = politics.get("trust",0.55)
	var media_freedom = culture.get("media_freedom",0.5)
	var id_coverage = state.get("statistics",{}).get("id_coverage",0.92) if state.has("statistics") else 0.92

	var participation_target = 0.4 + happiness * 0.2 + trust * 0.2 + media_freedom * 0.1 + id_coverage * 0.1 - politics.get("tension",0.35) * 0.1
	elections["participation"] = clamp(elections["participation"] * 0.99 + participation_target * 0.01, 0.1, 0.95)
	elections["voter_turnout"] = elections["participation"]

	# شفافیت انتخابات = f(نظارت، قانون، رسانه آزاد، فساد کم)
	var rule_of_law = state.get("judicial",{}).get("rule_of_law",0.60)
	var transparency_target = 0.5 + rule_of_law * 0.2 + media_freedom * 0.2 + (1.0 - politics.get("corruption",0.30)) * 0.2 - elections["fraud_risk"] * 0.3
	elections["transparency"] = clamp(elections["transparency"] * 0.99 + transparency_target * 0.01, 0.1, 0.95)

	# ریسک تقلب
	var fraud_target = 0.2 + politics.get("corruption",0.30) * 0.3 - rule_of_law * 0.2 - elections["transparency"] * 0.2
	elections["fraud_risk"] = clamp(elections["fraud_risk"] * 0.98 + fraud_target * 0.02, 0.02, 0.60)

	# حمایت از حزب حاکم = f(عملکرد دولت، اقتصاد شخصی، رسانه، هم‌گروهی) - ۳.۶۵.۳
	var econ_performance = state.get("economy",{}).get("growth_rate",0.02) * 10.0 + (0.08 - state.get("economy",{}).get("unemployment",0.08)) * 2.0
	var personal_econ = pop.get("happiness",0.6) * 0.5
	var media_impact = culture.get("public_opinion",0.60) * 0.2
	var ruling_support = 0.5 + econ_performance * 0.1 + personal_econ * 0.2 + media_impact * 0.1 + (happiness - 0.5) * 0.2
	elections["ruling_party_support"] = clamp(elections["ruling_party_support"] * 0.99 + ruling_support * 0.01, 0.1, 0.90)
	elections["opposition_support"] = 1.0 - elections["ruling_party_support"]

	# نظام حزبی
	elections["party_system"] = clamp(elections["party_system"] + Deterministic.next_range(-0.001, 0.002), 0.2, 0.90)

	# هزینه کمپین
	elections["campaign_cost"] = clamp(elections["campaign_cost"] + Deterministic.next_range(-0.002, 0.003), 0.1, 0.90)

	# انتخابات - هر ۴ سال (قانون سیاسی)
	if year >= elections["next_election_year"]:
		elections["last_election_year"] = year
		elections["next_election_year"] = year + 4

		# نتیجه انتخابات - با دترمینستیک
		var result = elections["ruling_party_support"]
		var fraud_boost = elections["fraud_risk"] * 0.1 if Deterministic.chance(0.3) else 0.0
		result += fraud_boost

		if result > 0.55:
			events.append({"type": "election_ruling_win", "message": "پیروزی جناح حاکم در انتخابات %s با %.0f٪ آرا - مشروعیت افزایش یافت!" % [str(year), result*100], "support": result, "transparency": elections["transparency"]})
			politics["legitimacy"] = clamp(politics.get("legitimacy",0.58) + 0.03, 0.1, 0.95)
			politics["stability"] = clamp(politics.get("stability",0.6) + 0.02, 0.05, 0.95)
		elif result < 0.45:
			events.append({"type": "election_opposition_win", "message": "شکست جناح حاکم در انتخابات %s - اپوزیسیون %.0f٪ آرا - چالش مشروعیت!" % [str(year), (1.0-result)*100], "support": result})
			politics["legitimacy"] = clamp(politics.get("legitimacy",0.58) - 0.02, 0.1, 0.95)
			politics["tension"] = clamp(politics.get("tension",0.35) + 0.03, 0.0, 1.0)
		else:
			events.append({"type": "election_tie", "message": "انتخابات %s بسیار نزدیک - %.0f٪ vs %.0f٪ - ائتلاف!" % [str(year), result*100, (1.0-result)*100]})

		# اگر تقلب بالا، بحران
		if elections["fraud_risk"] > 0.4 and Deterministic.chance(0.5):
			events.append({"type": "election_fraud_allegation", "message": "اتهام تقلب انتخاباتی! اعتراضات و بحران مشروعیت", "fraud_risk": elections["fraud_risk"]})
			politics["tension"] += 0.08
			politics["trust"] -= 0.05

		state["politics"] = politics

	# مشارکت پایین = بحران
	if elections["participation"] < 0.35 and Deterministic.chance(0.01):
		events.append({"type": "low_turnout_crisis", "message": "مشارکت پایین انتخاباتی - بحران مشروعیت و بی‌اعتمادی", "turnout": elections["participation"]})

	# حلقه بازخورد: انتخابات آزاد → مشروعیت → ثبات
	if elections["transparency"] > 0.7 and elections["participation"] > 0.6:
		politics["legitimacy"] = clamp(politics.get("legitimacy",0.58) + 0.0005, 0.1, 0.95)
		state["politics"] = politics

	state["elections"] = elections
	return {"success": true, "state": state, "events": events}
