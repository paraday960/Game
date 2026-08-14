extends BaseSystem
# ۳.۱۸ امنیت داخلی و پلیس - پیاده‌سازی کامل

func compute(state: Dictionary, tick: int) -> Dictionary:
	var security = state.get("security", {})
	var judicial = state.get("judicial", {})
	var politics = state.get("politics", {})
	var pop = state.get("population", {})
	var econ = state.get("economy", {})
	var culture = state.get("culture", {})

	security["public_security"] = security.get("public_security", 0.70)
	security["police_presence"] = security.get("police_presence", 0.5)
	security["prevention"] = security.get("prevention", 0.60)
	security["response"] = security.get("response", 0.65)
	security["cyber"] = security.get("cyber", 0.50)
	security["counter_terror"] = security.get("counter_terror", 0.55)
	security["border_control"] = security.get("border_control", 0.60)
	security["community_trust"] = security.get("community_trust", 0.55)
	security["organized_crime"] = security.get("organized_crime", 0.30)

	var events = []

	# بودجه پلیس
	var police_budget_share = econ.get("budget_allocations", {}).get("امنیت", 0.05)
	var police_budget = econ.get("government_spend_base", 0.0) * police_budget_share

	# فرمول‌ها - ۳.۱۸.۳
	# امنیت عمومی = f(نیروی پلیس، تجهیزات، آموزش، بازدارندگی)
	var deterrence = judicial.get("deterrence", 0.55) if judicial else 0.55
	var police_quality = 0.5 + (police_budget / 5_000_000_000.0) * 0.3 + security["prevention"] * 0.2
	var public_security = 0.5
	public_security += security["police_presence"] * 0.25
	public_security += police_quality * 0.2
	public_security += deterrence * 0.25
	public_security += security["community_trust"] * 0.15
	public_security += security["counter_terror"] * 0.1
	security["public_security"] = clamp(security["public_security"] * 0.97 + public_security * 0.03, 0.05, 0.95)

	# احساس امنیت = f(نرخ جرم، حضور پلیس، رسانه)
	var crime_rate = judicial.get("crime_rate", 50.0) if judicial else 50.0
	var feeling = 0.7
	feeling -= (crime_rate / 200.0) * 0.4
	feeling += security["police_presence"] * 0.3
	feeling += culture.get("cohesion", 0.65) * 0.1 if culture else 0
	security["feeling_security"] = clamp(feeling, 0.05, 0.95)

	# نرخ جرم سازمان‌یافته = f(فساد، کنترل مرز، پلیس)
	var org_crime = 0.3
	org_crime += politics.get("corruption", 0.3) * 0.4
	org_crime += (1.0 - security["border_control"]) * 0.3
	org_crime += (1.0 - security["police_presence"]) * 0.2
	org_crime += (1.0 - deterrence) * 0.2
	security["organized_crime"] = clamp(security["organized_crime"] * 0.98 + org_crime * 0.02, 0.0, 0.9)

	# کنترل اعتراض = f(گفتگو، پلیس، سیاست)
	var protest_control = 0.5
	protest_control += security["police_presence"] * 0.3
	protest_control += politics.get("stability", 0.6) * 0.2
	protest_control += security["community_trust"] * 0.2
	security["protest_control"] = clamp(protest_control, 0.1, 0.95)

	# پیشگیری و واکنش
	security["prevention"] = clamp(security["prevention"] + (police_budget_share - 0.05) * 0.005, 0.1, 0.95)
	security["response"] = clamp(security["response"] + Deterministic.next_range(-0.0025, 0.0025), 0.1, 0.95)

	# امنیت سایبری - رشد با فناوری
	var tech_digital = state.get("technology", {}).get("branches", {}).get("دیجیتال", 0.2)
	security["cyber"] = clamp(security["cyber"] * 0.999 + tech_digital * 0.001 + 0.0002, 0.1, 0.95)

	# ضد تروریسم
	security["counter_terror"] = clamp(security["counter_terror"] + Deterministic.next_range(-0.0015, 0.0015), 0.1, 0.95)

	# کنترل مرز
	security["border_control"] = clamp(security["border_control"] + Deterministic.next_range(-0.001, 0.001), 0.1, 0.95)

	# روابط پلیس-جامعه (اعتماد)
	var trust_change = (pop.get("happiness",0.6) - 0.5) * 0.002 - (crime_rate/200.0 - 0.25) * 0.002
	# خشونت پلیس اگر کنترل زیاد
	if security["police_presence"] > 0.8 and Deterministic.chance(0.01):
		trust_change -= 0.02
		events.append({"type": "police_violence_exposed", "message": "افشای خشونت پلیس - کاهش اعتماد جامعه"})
	security["community_trust"] = clamp(security["community_trust"] + trust_change, 0.05, 0.95)

	# حلقه‌های بازخورد: امنیت → اعتماد/سرمایه؛ سرکوب → نارضایتی
	politics["stability"] = clamp(politics.get("stability",0.6) + (security["public_security"] - 0.5) * 0.001, 0.05, 0.95)
	if security["police_presence"] > 0.7:
		pop["happiness"] = clamp(pop.get("happiness",0.6) - 0.0005, 0.05, 0.95)  # سرکوب زیاد
	state["politics"] = politics
	state["population"] = pop

	# رویدادها - ۳.۱۸.۵
	if security["organized_crime"] > 0.6 and Deterministic.chance(0.015):
		events.append({"type": "organized_crime_wave", "message": "موج جرائم سازمان‌یافته و قاچاق", "level": security["organized_crime"]})

	if security["public_security"] < 0.4 and Deterministic.chance(0.02):
		events.append({"type": "security_crisis", "message": "بحران امنیتی - ناامنی گسترده", "security": security["public_security"]})

	if politics.get("tension",0.35) > 0.7 and Deterministic.chance(0.02):
		events.append({"type": "mass_protest", "message": "تجمعات اعتراضی گسترده - مدیریت پلیس", "tension": politics.get("tension",0)})

	if Deterministic.chance(0.005):
		events.append({"type": "counter_terror_success", "message": "عملیات موفق ضدتروریسم", "effect": 0.05})
		security["counter_terror"] += 0.02

	state["security"] = security
	
	# ── لایه واقع‌گرایانه اختصاصی امنیت داخلی (جایگزین قالب خودکار تکراری) — بخش ۳.۱۸ ──
	# فشار جرم: محرومیت و بیکاری جرم‌زا؛ حضور پلیس و پیشگیری مهارکننده
	var pov_s: float = float(state.get("welfare", {}).get("poverty", 0.15))
	var unemp_s: float = float(state.get("economy", {}).get("unemployment", 0.08))
	var police: float = float(security.get("police_presence", 0.55))
	var prevent: float = float(security.get("prevention", 0.50))
	var crime_pressure: float = (pov_s * 0.6 + unemp_s * 0.4) - (police * 0.5 + prevent * 0.5) * 0.5
	var oc: float = float(security.get("organized_crime", 0.30))
	oc = clampf(oc + crime_pressure * 0.0008, 0.02, 0.90)
	security["organized_crime"] = oc
	# جرم سازمان‌یافته اعتماد محله‌ای را می‌فرساید و امنیت عمومی را پایین می‌آورد (خوردبازخورد)
	security["community_trust"] = clampf(float(security.get("community_trust", 0.55)) * 0.995 + (1.0 - oc) * 0.004 + police * 0.001, 0.05, 0.95)
	security["public_security"] = clampf(float(security.get("public_security", 0.60)) * 0.997 + ((police + prevent) * 0.5 - oc * 0.3) * 0.006, 0.05, 0.95)
	if oc > 0.65 and Deterministic.chance(0.004):
		events.append({"type": "organized_crime_surge", "message": "موج جرم سازمان‌یافته - قاچاق و باندهای اقتصاد زیرزمینی گسترش یافته‌اند", "level": oc})
	if float(security.get("public_security", 0.60)) < 0.30 and Deterministic.chance(0.004):
		events.append({"type": "public_fear", "message": "هراس عمومی از ناامنی - کسب‌وکارها زودتر تعطیل می‌کنند", "level": security["public_security"]})
	state["security"] = security

	return {"success": true, "state": state, "events": events}
