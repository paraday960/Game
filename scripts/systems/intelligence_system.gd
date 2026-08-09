extends BaseSystem
# ۳.۲۳ اطلاعات و امنیت ملی - پیاده‌سازی کامل

func compute(state: Dictionary, tick: int) -> Dictionary:
	var intel = state.get("intelligence", {})
	var tech = state.get("technology", {})
	var military = state.get("military", {})
	var diplomacy = state.get("diplomacy", {})
	var politics = state.get("politics", {})
	var security = state.get("security", {})

	intel["power"] = intel.get("power", 50.0)
	intel["agencies"] = intel.get("agencies", 3)
	intel["cyber_readiness"] = intel.get("cyber_readiness", 0.50)
	intel["counter_intel"] = intel.get("counter_intel", 0.55)
	intel["foreign_intel"] = intel.get("foreign_intel", 0.50)
	intel["critical_protection"] = intel.get("critical_protection", 0.60)
	intel["threat_assessment"] = intel.get("threat_assessment", 0.55)
	intel["surveillance"] = intel.get("surveillance", 0.50)
	intel["budget_share"] = intel.get("budget_share", 0.02)

	var events = []

	var intel_budget_share = state.get("economy",{}).get("budget_allocations",{}).get("امنیت",0.05) * 0.4  # 40٪ بودجه امنیت برای اطلاعات
	var intel_budget = state.get("economy",{}).get("government_spending",0.0) * intel_budget_share

	# فرمول‌ها - ۳.۲۳.۳
	# قدرت اطلاعات = f(بودجه، نیرو، فناوری، منابع انسانی)
	var tech_factor = tech.get("branches",{}).get("دیجیتال",0.2) * 0.3 + tech.get("branches",{}).get("نظامی",0.15) * 0.2
	var budget_factor = intel_budget / 2_000_000_000.0
	var intel_power = 40.0 + budget_factor * 10.0 + tech_factor * 30.0 + intel["agencies"] * 5.0
	intel["power"] = clamp(intel["power"] * 0.98 + intel_power * 0.02, 10.0, 100.0)

	# امنیت سایبری = f(فناوری، آموزش، زیرساخت)
	var cyber = 0.4
	cyber += tech_factor * 0.4
	cyber += state.get("education",{}).get("quality",0.55) * 0.2
	cyber += state.get("infrastructure",{}).get("quality",0.55) * 0.1
	intel["cyber_readiness"] = clamp(intel["cyber_readiness"] * 0.995 + cyber * 0.005, 0.1, 0.95)

	# اثر ضدجاسوسی = f(کشف نفوذ، حفاظت)
	var counter = 0.5 + intel["power"]/100.0 * 0.3 + intel["cyber_readiness"] * 0.2
	intel["counter_intel"] = clamp(intel["counter_intel"] * 0.99 + counter * 0.01, 0.1, 0.95)

	# اطلاعات خارجی
	intel["foreign_intel"] = clamp(intel["foreign_intel"] + Deterministic.next_range(-0.002, 0.003), 0.1, 0.95)

	# حفاظت زیرساخت حیاتی
	intel["critical_protection"] = clamp(intel["critical_protection"] + (intel["cyber_readiness"] - 0.5) * 0.001, 0.1, 0.95)

	# ارزیابی تهدید
	var threat_level = 0.5
	threat_level += (1.0 - diplomacy.get("relations",{}).values().min() / 100.0 if diplomacy.get("relations",{}).size()>0 else 0) * 0.2
	threat_level += politics.get("tension",0.35) * 0.2
	intel["threat_assessment"] = clamp(threat_level, 0.1, 0.95)

	# نظارت قانونی - توازن امنیت و حقوق
	var oversight = state.get("judicial",{}).get("rule_of_law",0.6) * 0.5 + politics.get("legitimacy",0.58) * 0.3
	intel["oversight"] = clamp(oversight, 0.1, 0.95)

	# ریسک نفوذ = f(فناوری، امنیت، نظارت)
	var infiltration_risk = (1.0 - intel["counter_intel"]) * 0.4 + (1.0 - intel["cyber_readiness"]) * 0.3 + (1.0 - intel["oversight"]) * 0.2
	intel["infiltration_risk"] = clamp(infiltration_risk, 0.0, 0.9)

	# آمادگی ملی = f(اطلاعات، پیشگیری)
	var preparedness = intel["power"]/100.0 * 0.5 + intel["threat_assessment"] * 0.2 + intel["critical_protection"] * 0.3
	intel["national_preparedness"] = clamp(preparedness, 0.1, 0.95)

	# حلقه بازخورد: اطلاعات ← آمادگی؛ نفوذ ← ریسک
	military["power"] = military.get("power",65.0) + (intel["foreign_intel"] - 0.5) * 0.5
	state["military"] = military

	# رویدادها - ۳.۲۳.۵
	if intel["infiltration_risk"] > 0.6 and Deterministic.chance(0.012):
		events.append({"type": "espionage_exposed", "message": "نفوذ و جاسوسی فاش شد! - بحران ضدجاسوسی", "risk": intel["infiltration_risk"]})
		politics["tension"] = politics.get("tension",0.35) + 0.03
		state["politics"] = politics

	if intel["cyber_readiness"] < 0.4 and Deterministic.chance(0.012):
		events.append({"type": "cyber_attack", "message": "حمله سایبری به زیرساخت حیاتی", "readiness": intel["cyber_readiness"]})
		state["infrastructure"]["quality"] = state.get("infrastructure",{}).get("quality",0.55) - 0.01
		intel["critical_protection"] -= 0.05

	if Deterministic.chance(0.008):
		events.append({"type": "intel_success", "message": "عملیات اطلاعاتی موفق - کشف تهدید", "power_boost": 0.02})
		intel["power"] += 1.0

	if Deterministic.chance(0.005):
		events.append({"type": "false_intel", "message": "بحران اطلاعات غلط - تصمیم اشتباه", "effect": -0.02})
		politics["stability"] = politics.get("stability",0.6) - 0.01
		state["politics"] = politics

	state["intelligence"] = intel
	return {"success": true, "state": state, "events": events}
