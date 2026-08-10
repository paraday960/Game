extends BaseAI
# هوش پژوهش: انتخاب فناوری در دسترس بر اساس شکاف شاخه و بحران‌های کشور

func decide(state: Dictionary, tick: int) -> Array:
	var tech = state["technology"]
	if tech.get("in_progress", null) != null:
		return []
	var available = TechnologyManager.get_available(state)
	if available.is_empty():
		return []
	var best_id = ""
	var best_score = -INF
	for candidate in available:
		var branch = str(candidate.get("branch", ""))
		var branch_level = float(tech.get("branches", {}).get(branch, 0.0))
		var score = 1.0 - branch_level
		if branch == "انرژی_پاک" and state.get("resources", {}).get("energy_crisis", false): score += 0.8
		if branch == "پزشکی" and float(state.get("health", {}).get("quality", 0.6)) < 0.55: score += 0.6
		if branch == "نظامی" and float(state.get("military", {}).get("readiness", 0.7)) < 0.55: score += 0.5
		if branch == "دیجیتال" and float(state.get("intelligence", {}).get("cyber_readiness", 0.5)) < 0.6: score += 0.5
		score -= float(candidate.get("cost", 1.0)) * 0.01
		if score > best_score:
			best_score = score
			best_id = str(candidate.get("id", ""))
	return [GameCommand.create_research_start(best_id)] if best_id != "" else []
