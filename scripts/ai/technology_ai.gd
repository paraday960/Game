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


# --- لایه عمیق اضافی - تحلیل آینده، ریسک، هم‌افزایی ---
func _deep_future_risk_analysis(state: Dictionary) -> float:
	var diag = diagnose(state) if has_method("diagnose") else {}
	var health = float(diag.get("health",0.5)) if not diag.is_empty() else 0.5
	var urgency = float(diag.get("urgency",0.0)) if not diag.is_empty() else 0.0
	return health*0.4 + urgency*0.6

func _deep_build_preventive_command(state: Dictionary):
	var diag = diagnose(state) if has_method("diagnose") else {}
	var budget_key = str(diag.get("budget_key","ذخیره")) if not diag.is_empty() else "ذخیره"
	return build_budget_command(state, budget_key) if has_method("build_budget_command") else null

func _deep_evaluate_with_trend(state: Dictionary) -> Dictionary:
	var base = evaluate(state) if has_method("evaluate") else 0.5
	var trend = Deterministic.next_range(-0.02, 0.02)
	return {"base": base, "trend": trend, "adjusted": clamp(base + trend, 0.0, 1.0)}

func get_detailed_diagnosis(state: Dictionary) -> Dictionary:
	var d = diagnose(state) if has_method("diagnose") else {}
	var detailed = d.duplicate(true) if d is Dictionary else {}
	detailed["timestamp"] = state.get("tick",0)
	detailed["deep_analysis"] = _deep_future_risk_analysis(state)
	return detailed

func build_comprehensive_plan(state: Dictionary, tick: int) -> Array:
	var cmds = decide(state, tick) if has_method("decide") else []
	# افزودن تحلیل پیشگیرانه
	var risk = _deep_future_risk_analysis(state)
	if risk > 0.60 and cmds.size() < 2:
		var preventive = _deep_build_preventive_command(state)
		if preventive != null:
			cmds.append(preventive)
	return cmds.slice(0, 3)

# --- لایه عمیق اضافی - تحلیل آینده، ریسک، هم‌افزایی ---
func _deep_future_risk_analysis(state: Dictionary) -> float:
	var diag = diagnose(state) if has_method("diagnose") else {}
	var health = float(diag.get("health",0.5)) if not diag.is_empty() else 0.5
	var urgency = float(diag.get("urgency",0.0)) if not diag.is_empty() else 0.0
	return health*0.4 + urgency*0.6

func _deep_build_preventive_command(state: Dictionary):
	var diag = diagnose(state) if has_method("diagnose") else {}
	var budget_key = str(diag.get("budget_key","ذخیره")) if not diag.is_empty() else "ذخیره"
	return build_budget_command(state, budget_key) if has_method("build_budget_command") else null

func _deep_evaluate_with_trend(state: Dictionary) -> Dictionary:
	var base = evaluate(state) if has_method("evaluate") else 0.5
	var trend = Deterministic.next_range(-0.02, 0.02)
	return {"base": base, "trend": trend, "adjusted": clamp(base + trend, 0.0, 1.0)}

func get_detailed_diagnosis(state: Dictionary) -> Dictionary:
	var d = diagnose(state) if has_method("diagnose") else {}
	var detailed = d.duplicate(true) if d is Dictionary else {}
	detailed["timestamp"] = state.get("tick",0)
	detailed["deep_analysis"] = _deep_future_risk_analysis(state)
	return detailed

func build_comprehensive_plan(state: Dictionary, tick: int) -> Array:
	var cmds = decide(state, tick) if has_method("decide") else []
	# افزودن تحلیل پیشگیرانه
	var risk = _deep_future_risk_analysis(state)
	if risk > 0.60 and cmds.size() < 2:
		var preventive = _deep_build_preventive_command(state)
		if preventive != null:
			cmds.append(preventive)
	return cmds.slice(0, 3)


# --- لایه عمیق اضافی - تحلیل آینده، ریسک، هم‌افزایی ---
func _deep_future_risk_analysis(state: Dictionary) -> float:
	var diag = diagnose(state) if has_method("diagnose") else {}
	var health = float(diag.get("health",0.5)) if not diag.is_empty() else 0.5
	var urgency = float(diag.get("urgency",0.0)) if not diag.is_empty() else 0.0
	return health*0.4 + urgency*0.6

func _deep_build_preventive_command(state: Dictionary):
	var diag = diagnose(state) if has_method("diagnose") else {}
	var budget_key = str(diag.get("budget_key","ذخیره")) if not diag.is_empty() else "ذخیره"
	return build_budget_command(state, budget_key) if has_method("build_budget_command") else null

func _deep_evaluate_with_trend(state: Dictionary) -> Dictionary:
	var base = evaluate(state) if has_method("evaluate") else 0.5
	var trend = Deterministic.next_range(-0.02, 0.02)
	return {"base": base, "trend": trend, "adjusted": clamp(base + trend, 0.0, 1.0)}

func get_detailed_diagnosis(state: Dictionary) -> Dictionary:
	var d = diagnose(state) if has_method("diagnose") else {}
	var detailed = d.duplicate(true) if d is Dictionary else {}
	detailed["timestamp"] = state.get("tick",0)
	detailed["deep_analysis"] = _deep_future_risk_analysis(state)
	return detailed

func build_comprehensive_plan(state: Dictionary, tick: int) -> Array:
	var cmds = decide(state, tick) if has_method("decide") else []
	# افزودن تحلیل پیشگیرانه
	var risk = _deep_future_risk_analysis(state)
	if risk > 0.60 and cmds.size() < 2:
		var preventive = _deep_build_preventive_command(state)
		if preventive != null:
			cmds.append(preventive)
	return cmds.slice(0, 3)


# --- لایه عمیق اضافی - تحلیل آینده، ریسک، هم‌افزایی ---
func _deep_future_risk_analysis(state: Dictionary) -> float:
	var diag = diagnose(state) if has_method("diagnose") else {}
	var health = float(diag.get("health",0.5)) if not diag.is_empty() else 0.5
	var urgency = float(diag.get("urgency",0.0)) if not diag.is_empty() else 0.0
	return health*0.4 + urgency*0.6

func _deep_build_preventive_command(state: Dictionary):
	var diag = diagnose(state) if has_method("diagnose") else {}
	var budget_key = str(diag.get("budget_key","ذخیره")) if not diag.is_empty() else "ذخیره"
	return build_budget_command(state, budget_key) if has_method("build_budget_command") else null

func _deep_evaluate_with_trend(state: Dictionary) -> Dictionary:
	var base = evaluate(state) if has_method("evaluate") else 0.5
	var trend = Deterministic.next_range(-0.02, 0.02)
	return {"base": base, "trend": trend, "adjusted": clamp(base + trend, 0.0, 1.0)}

func get_detailed_diagnosis(state: Dictionary) -> Dictionary:
	var d = diagnose(state) if has_method("diagnose") else {}
	var detailed = d.duplicate(true) if d is Dictionary else {}
	detailed["timestamp"] = state.get("tick",0)
	detailed["deep_analysis"] = _deep_future_risk_analysis(state)
	return detailed

func build_comprehensive_plan(state: Dictionary, tick: int) -> Array:
	var cmds = decide(state, tick) if has_method("decide") else []
	# افزودن تحلیل پیشگیرانه
	var risk = _deep_future_risk_analysis(state)
	if risk > 0.60 and cmds.size() < 2:
		var preventive = _deep_build_preventive_command(state)
		if preventive != null:
			cmds.append(preventive)
	return cmds.slice(0, 3)


# --- لایه عمیق اضافی - تحلیل آینده، ریسک، هم‌افزایی ---
func _deep_future_risk_analysis(state: Dictionary) -> float:
	var diag = diagnose(state) if has_method("diagnose") else {}
	var health = float(diag.get("health",0.5)) if not diag.is_empty() else 0.5
	var urgency = float(diag.get("urgency",0.0)) if not diag.is_empty() else 0.0
	return health*0.4 + urgency*0.6

func _deep_build_preventive_command(state: Dictionary):
	var diag = diagnose(state) if has_method("diagnose") else {}
	var budget_key = str(diag.get("budget_key","ذخیره")) if not diag.is_empty() else "ذخیره"
	return build_budget_command(state, budget_key) if has_method("build_budget_command") else null

func _deep_evaluate_with_trend(state: Dictionary) -> Dictionary:
	var base = evaluate(state) if has_method("evaluate") else 0.5
	var trend = Deterministic.next_range(-0.02, 0.02)
	return {"base": base, "trend": trend, "adjusted": clamp(base + trend, 0.0, 1.0)}

func get_detailed_diagnosis(state: Dictionary) -> Dictionary:
	var d = diagnose(state) if has_method("diagnose") else {}
	var detailed = d.duplicate(true) if d is Dictionary else {}
	detailed["timestamp"] = state.get("tick",0)
	detailed["deep_analysis"] = _deep_future_risk_analysis(state)
	return detailed

func build_comprehensive_plan(state: Dictionary, tick: int) -> Array:
	var cmds = decide(state, tick) if has_method("decide") else []
	# افزودن تحلیل پیشگیرانه
	var risk = _deep_future_risk_analysis(state)
	if risk > 0.60 and cmds.size() < 2:
		var preventive = _deep_build_preventive_command(state)
		if preventive != null:
			cmds.append(preventive)
	return cmds.slice(0, 3)

