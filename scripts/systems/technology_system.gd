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

	# پیشرفت فناوری انتخاب‌شده توسط بازیکن/AI
	if tech["in_progress"] != null:
		var current_id = str(tech["in_progress"])
		var cost = TechnologyManager.get_cost(current_id)
		if tech["research_points"] >= cost:
			tech["research_points"] -= cost
			state["technology"] = tech
			state = TechnologyManager.apply_unlock(state, current_id)
			tech = state["technology"]
			events.append({
				"type": "tech_unlocked", "tech": current_id,
				"message": "فناوری «%s» تکمیل شد و اثرهای آن اعمال گردید" % TechnologyManager.get_technology_name(current_id)
			})
			tech["in_progress"] = null
		elif tick % 30 == 0:
			events.append({
				"type": "research_progress", "points": tech["research_points"], "tech": current_id,
				"message": "گزارش پیشرفت پژوهش «%s» منتشر شد" % TechnologyManager.get_technology_name(current_id)
			})

	# بلوغ و اشاعه - فناوری با گذر زمان سرایت می‌کند ۳.۱۶.۶
	for branch in tech["branches"].keys():
		tech["branches"][branch] += 0.0001  # رشد خودکار کم
		tech["branches"][branch] = clamp(tech["branches"][branch], 0.0, 1.0)

	state["technology"] = tech
	return {"success": true, "state": state, "events": events}
