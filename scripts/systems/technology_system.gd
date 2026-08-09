extends BaseSystem
# علم و فناوری - ۳.۱۶

func compute(state: Dictionary, tick: int) -> Dictionary:
	var tech = state["technology"]
	var econ = state["economy"]
	var edu = state["education"]
	var pop = state["population"]
	var infra = state["infrastructure"]

	var events = []

	var budget = econ["budget_allocations"].get("فناوری", 0.04) * econ["government_spending"]

	# نرخ تحقیق = f(بودجه R&D، دانشمندان، مؤسسات، آموزش، زیرساخت دیجیتال) ۳.۱۶.۳
	var base_rate = 10.0  # نقطه در سال ۳.۱۶.۴
	var budget_factor = (budget / max(econ["government_spending"] * 0.04, 1.0))
	var edu_factor = edu["quality"] * 1.5
	var infra_factor = infra["quality"] * 0.5 + 0.5

	tech["research_rate"] = base_rate * budget_factor * edu_factor * infra_factor
	tech["research_points"] += tech["research_rate"] / 365.0

	# پیشرفت فناوری
	if tech["in_progress"] != null:
		var cost = 100.0  # هزینه هر فناوری
		if tech["research_points"] >= cost:
			tech["research_points"] -= cost
			if not tech["unlocked"].has(tech["in_progress"]):
				tech["unlocked"].append(tech["in_progress"])
				events.append({"type": "tech_unlocked", "tech": tech["in_progress"], "message": "فناوری %s باز شد!" % tech["in_progress"]})
				# افزایش شاخه مربوطه
				for branch in tech["branches"].keys():
					if tech["in_progress"].contains(branch) or branch in tech["in_progress"]:
						tech["branches"][branch] = clamp(tech["branches"][branch] + 0.05, 0.0, 1.0)
			tech["in_progress"] = null
		# پیشرفت جزئی
		elif Deterministic.chance(0.01):
			events.append({"type": "research_progress", "points": tech["research_points"], "tech": tech["in_progress"]})

	# اگر تحقیقی در جریان نیست، یکی انتخاب کن
	if tech["in_progress"] == null and Deterministic.chance(0.02):
		var options = ["صنعت_پیشرفته", "انرژی_خورشیدی", "هوش_مصنوعی", "پزشکی_نوین", "موشکی", "دیجیتال", "فضا"]
		var available = []
		for opt in options:
			if not tech["unlocked"].has(opt):
				available.append(opt)
		if available.size() > 0:
			tech["in_progress"] = Deterministic.shuffle_array(available)[0]

	# بلوغ و اشاعه - فناوری با گذر زمان سرایت می‌کند ۳.۱۶.۶
	for branch in tech["branches"].keys():
		tech["branches"][branch] += 0.0001  # رشد خودکار کم
		tech["branches"][branch] = clamp(tech["branches"][branch], 0.0, 1.0)

	state["technology"] = tech
	return {"success": true, "state": state, "events": events}
