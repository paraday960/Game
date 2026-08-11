extends Node
# هماهنگ‌کننده‌ی ۶۵ هوش تخصصی: تحلیل، اولویت‌بندی، توضیح و فرمان پیشنهادی

const GameCommandClass = preload("res://scripts/core/command.gd")

var agents: Dictionary = {}
var last_recommendations: Array = []

func _ready():
	reload_agents()

func reload_agents():
	agents.clear()
	var directory = DirAccess.open("res://scripts/ai/")
	if directory == null:
		push_error("پوشه هوش‌های تخصصی قابل خواندن نیست")
		return
	var files = directory.get_files()
	files.sort()
	for filename in files:
		if not filename.ends_with("_ai.gd") or filename in ["base_ai.gd", "ai_advisor.gd"]:
			continue
		var script = load("res://scripts/ai/" + filename)
		if script == null:
			continue
		var agent = script.new()
		var key = filename.trim_suffix("_ai.gd")
		agents[key] = agent

func analyze(state: Dictionary, tick: int = 0) -> Array:
	var recommendations: Array = []
	for key in agents.keys():
		var agent = agents[key]
		if not agent.has_method("diagnose"):
			continue
		var diagnosis = agent.diagnose(state)
		if not diagnosis is Dictionary or diagnosis.is_empty():
			continue
		diagnosis["tick"] = tick
		recommendations.append(diagnosis)
	recommendations.sort_custom(func(a, b): return float(a.get("urgency", 0.0)) > float(b.get("urgency", 0.0)))
	last_recommendations = recommendations
	return recommendations

func get_top_recommendations(state: Dictionary, tick: int = 0, limit: int = 6) -> Array:
	var all = analyze(state, tick)
	var urgent: Array = []
	for item in all:
		if float(item.get("urgency", 0.0)) > 0.05:
			urgent.append(item)
		if urgent.size() >= limit:
			break
	return urgent

func build_autonomous_commands(state: Dictionary, tick: int = 0, limit: int = 1) -> Array:
	# برای کشور غیرِبازیکن: در هر تیک فقط بهترین فرمان از هر نوع انتخاب می‌شود.
	var commands: Array = []
	var used_types: Dictionary = {}
	for item in get_top_recommendations(state, tick, agents.size()):
		if not item.has("command"):
			continue
		var cmd = GameCommandClass.from_dict(item["command"])
		if used_types.has(cmd.type):
			continue
		commands.append(cmd)
		used_types[cmd.type] = true
		if commands.size() >= limit:
			break
	return commands

func get_health_summary(state: Dictionary, tick: int = 0) -> Dictionary:
	var all = analyze(state, tick)
	var total_health = 0.0
	var critical = 0
	for item in all:
		total_health += float(item.get("health", 0.0))
		if float(item.get("urgency", 0.0)) >= 0.65:
			critical += 1
	return {
		"agents": agents.size(),
		"analyzed": all.size(),
		"health": total_health / max(all.size(), 1),
		"critical": critical
	}


# --- لایه عمیق اضافی - تحلیل آینده، ریسک، هم‌افزایی ---
func _deep_future_risk_analysis(state: Dictionary) -> float:
	var diag = call("diagnose", state) if has_method("diagnose") else {}
	var health = float(diag.get("health",0.5)) if not diag.is_empty() else 0.5
	var urgency = float(diag.get("urgency",0.0)) if not diag.is_empty() else 0.0
	return health*0.4 + urgency*0.6

func _deep_build_preventive_command(state: Dictionary):
	var diag = call("diagnose", state) if has_method("diagnose") else {}
	var budget_key = str(diag.get("budget_key","ذخیره")) if not diag.is_empty() else "ذخیره"
	return call("build_budget_command", state, budget_key) if has_method("build_budget_command") else null

func _deep_evaluate_with_trend(state: Dictionary) -> Dictionary:
	var base = call("evaluate", state) if has_method("evaluate") else 0.5
	var trend = Deterministic.next_range(-0.02, 0.02)
	return {"base": base, "trend": trend, "adjusted": clamp(base + trend, 0.0, 1.0)}

func get_detailed_diagnosis(state: Dictionary) -> Dictionary:
	var d = call("diagnose", state) if has_method("diagnose") else {}
	var detailed = d.duplicate(true) if d is Dictionary else {}
	detailed["timestamp"] = state.get("tick",0)
	detailed["deep_analysis"] = _deep_future_risk_analysis(state)
	return detailed

func build_comprehensive_plan(state: Dictionary, tick: int) -> Array:
	var cmds = call("decide", state, tick) if has_method("decide") else []
	# افزودن تحلیل پیشگیرانه
	var risk = _deep_future_risk_analysis(state)
	if risk > 0.60 and cmds.size() < 2:
		var preventive = _deep_build_preventive_command(state)
		if preventive != null:
			cmds.append(preventive)
	return cmds.slice(0, 3)

# --- لایه عمیق اضافی - تحلیل آینده، ریسک، هم‌افزایی ---