extends Node
# ── اقتصاد دانش‌بنیان و پارک فناوری ──
# پارک‌های علم و فناوری، مراکز رشد، شرکت‌های دانش‌بنیان و
# تجاری‌سازی پژوهش. این لایه پل بین دانشگاه/پژوهش و صنعت است؛
# نوآوری را به محصول و درآمد تبدیل می‌کند. پیوند: آموزش، پژوهش، صنعت.

signal knowledge_businesses_changed(count: int)

var tech_parks: float = 0.10
var incubators: float = 0.15
var startups: float = 0.10
var commercialization: float = 0.15
var venture_capital: float = 0.05
var knowledge_businesses: int = 0
var patent_commercialization: float = 0.0
var last_tick: int = 0

func reset():
	tech_parks = 0.10
	incubators = 0.15
	startups = 0.10
	commercialization = 0.15
	venture_capital = 0.05
	knowledge_businesses = 0
	patent_commercialization = 0.0

func _ensure(state: Dictionary):
	if not state.has("knowledge_economy_policy"):
		state["knowledge_economy_policy"] = {
			"tech_parks": tech_parks,
			"incubators": incubators,
			"startups": startups,
			"commercialization": commercialization,
			"venture_capital": venture_capital,
			"businesses": knowledge_businesses,
			"patent_commercial": patent_commercialization,
			"last_tick": last_tick,
		}

func get_policy(state: Dictionary) -> Dictionary:
	_ensure(state)
	return state["knowledge_economy_policy"]

func build_tech_park(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["knowledge_economy_policy"]
	p["tech_parks"] = clampf(float(p["tech_parks"]) + 0.12, 0.0, 1.0)
	state["knowledge_economy_policy"] = p
	return {"success": true}

func expand_incubator(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["knowledge_economy_policy"]
	p["incubators"] = clampf(float(p["incubators"]) + 0.12, 0.0, 1.0)
	state["knowledge_economy_policy"] = p
	return {"success": true}

func support_startups(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["knowledge_economy_policy"]
	p["startups"] = clampf(float(p["startups"]) + 0.12, 0.0, 1.0)
	state["knowledge_economy_policy"] = p
	return {"success": true}

func commercialize_research(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["knowledge_economy_policy"]
	var higher_ed: float = float(state.get("higher_ed_policy", {}).get("quality", 0.3))
	if higher_ed < 0.30:
		return {"success": false, "reason": "ابتدا کیفیت دانشگاه‌ها را ارتقا دهید"}
	p["commercialization"] = clampf(float(p["commercialization"]) + 0.12, 0.0, 1.0)
	state["knowledge_economy_policy"] = p
	return {"success": true}

func attract_vc(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["knowledge_economy_policy"]
	p["venture_capital"] = clampf(float(p["venture_capital"]) + 0.12, 0.0, 1.0)
	state["knowledge_economy_policy"] = p
	return {"success": true}

func simulate(state: Dictionary, tick: int) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["knowledge_economy_policy"]
	var economy: Dictionary = state.get("economy", {})
	var gdp: float = float(economy.get("gdp", 0.0))
	var research: Dictionary = state.get("research_policy", {})
	var higher_ed: Dictionary = state.get("higher_ed_policy", {})
	var ip: Dictionary = state.get("ip_policy", {})

	var parks: float = float(p["tech_parks"])
	var incub: float = float(p["incubators"])
	var startup_lvl: float = float(p["startups"])
	var commerc: float = float(p["commercialization"])
	var vc: float = float(p["venture_capital"])

	var research_innov: float = float(research.get("innovation_index", 0.3))
	var uni_quality: float = float(higher_ed.get("quality", 0.3))
	var patents: float = float(ip.get("patents", 0.25))

	# شاخص اقتصاد دانش
	var knowledge_index: float = clampf(
		parks * 0.25 + incub * 0.20 + startup_lvl * 0.20 +
		commerc * 0.15 + vc * 0.10 + research_innov * 0.10,
		0.0, 1.0
	)

	# تعداد شرکت‌های دانش‌بنیان
	var target_businesses: int = int(knowledge_index * 5000.0 + uni_quality * 2000.0)
	var current_b: int = int(p["businesses"])
	var new_businesses: int = int(lerp(float(current_b), float(target_businesses), 0.10))
	p["businesses"] = new_businesses

	# تجاری‌سازی پتنت‌ها
	var patent_comm: float = clampf(commerc * 0.4 + patents * 0.3 + vc * 0.2, 0.0, 1.0)
	p["patent_commercial"] = patent_comm
	p["last_tick"] = tick

	if gdp > 0.0:
		# سهم اقتصاد دانش از GDP
		var knowledge_gdp: float = gdp * knowledge_index * 0.008
		economy["gdp"] = gdp + knowledge_gdp
		# صادرات دانش‌بنیان
		if patent_comm > 0.3:
			economy["foreign_reserves"] = float(economy.get("foreign_reserves", 0.0)) + gdp * patent_comm * 0.001
		state["economy"] = economy

	# تقویت تحقیق و نوآوری
	if not research.is_empty():
		research["innovation_index"] = clampf(research_innov + knowledge_index * 0.002, 0.0, 1.0)
		state["research_policy"] = research

	emit_signal("knowledge_businesses_changed", new_businesses)
	state["knowledge_economy_policy"] = p
	return state

func simulate_month(state: Dictionary, tick: int) -> Dictionary:
	# قرارداد مشترک چرخه ماهانه موتور: خروجی همیشه {state, events} است؛
	# simulate خام state را برمی‌گرداند (سازگار با تست‌ها) پس اینجا بسته‌بندی می‌شود.
	return {"state": simulate(state, tick), "events": []}

func get_summary(state: Dictionary) -> Dictionary:
	var p = get_policy(state)
	return {
		"tech_parks": p["tech_parks"],
		"incubators": p["incubators"],
		"startups": p["startups"],
		"commercialization": p["commercialization"],
		"venture_capital": p["venture_capital"],
		"businesses": p["businesses"],
		"patent_commercial": p["patent_commercial"],
	}
