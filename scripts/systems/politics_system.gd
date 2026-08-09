extends BaseSystem
# سیستم سیاست داخلی و ثبات - ۳.۱۲

func compute(state: Dictionary, tick: int) -> Dictionary:
	var pol = state["politics"]
	var pop = state["population"]
	var econ = state["economy"]
	var welfare = state["welfare"]
	var judicial = state["judicial"]
	var culture = state["culture"]

	var events = []

	# ثبات سیاسی = f(رضایت، فساد، نابرابری، امنیت، مشروعیت، رویدادها) - ۳.۱۲.۳
	var base_stability = 0.6
	var happiness_effect = (pop["happiness"] - 0.5) * 0.5
	var corruption_effect = -pol["corruption"] * 0.4
	var inequality_effect = -welfare["gini"] * 0.3
	var trust_effect = (pol["trust"] - 0.5) * 0.3
	var econ_effect = 0.0
	if econ["unemployment"] > 0.12:
		econ_effect -= 0.1
	if econ["inflation"] > 0.12:
		econ_effect -= 0.1

	var new_stability = base_stability + happiness_effect + corruption_effect + inequality_effect + trust_effect + econ_effect
	new_stability = clamp(new_stability, 0.05, 0.95)
	pol["stability"] = pol["stability"] * 0.97 + new_stability * 0.03

	# اعتماد عمومی = f(شفافیت، نتایج اقتصادی، فساد، امنیت)
	var trust = 0.5
	trust += (pol["stability"] - 0.5) * 0.3
	trust += (1.0 - pol["corruption"]) * 0.3
	trust += (pop["satisfaction"] - 0.5) * 0.2
	trust += (judicial["rule_of_law"] - 0.5) * 0.2
	pol["trust"] = clamp(pol["trust"] * 0.98 + trust * 0.02, 0.05, 0.95)

	# تنش اجتماعی = f(نارضایتی، فساد، نابرابری، بیکاری، سرکوب)
	var tension = 0.3
	tension += (1.0 - pop["happiness"]) * 0.4
	tension += pol["corruption"] * 0.2
	tension += welfare["gini"] * 0.2
	tension += econ["unemployment"] * 0.3
	pol["tension"] = clamp(pol["tension"] * 0.97 + tension * 0.03, 0.0, 1.0)

	# فساد پویا
	if pol["stability"] < 0.4 and Deterministic.chance(0.02):
		pol["corruption"] += 0.01
		events.append({"type": "corruption_increase", "level": pol["corruption"]})
	elif pol["stability"] > 0.7 and pol["trust"] > 0.6 and Deterministic.chance(0.02):
		pol["corruption"] -= 0.005
	pol["corruption"] = clamp(pol["corruption"], 0.0, 0.90)

	# مشروعیت
	var legitimacy = 0.5
	legitimacy += pol["trust"] * 0.3
	legitimacy += (1.0 - pol["corruption"]) * 0.2
	legitimacy += pol["stability"] * 0.2
	legitimacy += culture["cohesion"] * 0.1
	pol["legitimacy"] = clamp(legitimacy, 0.05, 0.95)

	# رویدادهای سیاسی - ۳.۱۲.۵ - آستانه شورش تنش > 80٪
	if pol["tension"] > 0.8 and Deterministic.chance(0.1):
		events.append({"type": "protest", "tension": pol["tension"], "message": "اعتراضات گسترده خیابانی"})
		pol["stability"] -= 0.05
		pop["happiness"] -= 0.05

	if pol["stability"] < 0.3 and Deterministic.chance(0.02):
		events.append({"type": "coup_risk", "stability": pol["stability"], "message": "خطر کودتا!"})

	if tick % (4 * 365) == 0:
		events.append({"type": "election", "message": "زمان انتخابات فرا رسید - بخش ۳.۶۵"})
		# شبیه‌سازی نتیجه انتخابات
		var result = (pop["happiness"] + pol["trust"]) / 2.0
		if result > 0.6:
			events.append({"type": "election_win", "result": "پیروزی جناح حاکم"})
		else:
			events.append({"type": "election_loss", "result": "شکست در انتخابات"})

	state["politics"] = pol
	return {"success": true, "state": state, "events": events}
