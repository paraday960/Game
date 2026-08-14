extends Node
# ── صنعت دفاعی و تسلیحات بومی ──
# تولید تجهیزات نظامی داخلی، تحقیق دفاعی، خودکفایی تسلیحاتی
# و صادرات دفاعی. کاهش وابستگی به واردات اسلحه، بازدارندگی
# و درآمد ارزی. پیوند: نظامی، صنعت، پژوهش، روابط خارجی.

signal defense_industry_changed(self_sufficiency: float)

var production: float = 0.15
var r_and_d: float = 0.10
var maintenance: float = 0.30
var exports: float = 0.0
var self_sufficiency: float = 0.20
var personnel_training: float = 0.20
var last_tick: int = 0

const MIN_VAL := 0.0
const MAX_VAL := 1.0

func reset():
	production = 0.15
	r_and_d = 0.10
	maintenance = 0.30
	exports = 0.0
	self_sufficiency = 0.20
	personnel_training = 0.20

func _ensure(state: Dictionary):
	if not state.has("defense_industry_policy"):
		state["defense_industry_policy"] = {
			"production": production,
			"r_and_d": r_and_d,
			"maintenance": maintenance,
			"exports": exports,
			"self_suff": self_sufficiency,
			"training": personnel_training,
			"last_tick": last_tick,
		}

func get_policy(state: Dictionary) -> Dictionary:
	_ensure(state)
	return state["defense_industry_policy"]

func expand_production(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["defense_industry_policy"]
	# به صنعت پایه و فولاد نیاز دارد
	var steel: float = float(state.get("basic_industry_policy", {}).get("steel", 0.2))
	if steel < 0.25:
		return {"success": false, "reason": "به صنعت فولاد قوی‌تری نیاز است"}
	p["production"] = clampf(float(p["production"]) + 0.12, MIN_VAL, MAX_VAL)
	state["defense_industry_policy"] = p
	return {"success": true}

func invest_rnd(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["defense_industry_policy"]
	p["r_and_d"] = clampf(float(p["r_and_d"]) + 0.12, MIN_VAL, MAX_VAL)
	state["defense_industry_policy"] = p
	return {"success": true}

func improve_maintenance(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["defense_industry_policy"]
	p["maintenance"] = clampf(float(p["maintenance"]) + 0.12, MIN_VAL, MAX_VAL)
	state["defense_industry_policy"] = p
	return {"success": true}

func train_personnel(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["defense_industry_policy"]
	p["training"] = clampf(float(p["training"]) + 0.12, MIN_VAL, MAX_VAL)
	state["defense_industry_policy"] = p
	return {"success": true}

func allow_exports(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["defense_industry_policy"]
	if float(p["self_suff"]) < 0.50:
		return {"success": false, "reason": "ابتدا باید به خودکفایی بالاتری برسید"}
	p["exports"] = clampf(float(p["exports"]) + 0.12, MIN_VAL, MAX_VAL)
	state["defense_industry_policy"] = p
	return {"success": true}

func simulate(state: Dictionary, tick: int) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["defense_industry_policy"]
	var economy: Dictionary = state.get("economy", {})
	var gdp: float = float(economy.get("gdp", 0.0))
	var military: Dictionary = state.get("military", {})
	var research: float = float(state.get("research_policy", {}).get("innovation_index", 0.3))

	var prod: float = float(p["production"])
	var rnd: float = float(p["r_and_d"])
	var maint: float = float(p["maintenance"])
	var train: float = float(p["training"])
	var export_lvl: float = float(p["exports"])

	# خودکفایی تابع تولید + تحقیق + آموزش
	var target_self: float = clampf(
		prod * 0.40 + rnd * 0.25 + train * 0.15 + maint * 0.10 + research * 0.10,
		MIN_VAL, MAX_VAL
	)
	var current: float = float(p["self_suff"])
	var new_self: float = lerpf(current, target_self, 0.08)
	p["self_suff"] = new_self
	p["last_tick"] = tick

	# تولید داخلی تجهیزات دفاعی - اثر سطحی همگرا (۲۰٪ در ماه) به‌جای جمعِ بی‌پایان روی GDP
	if gdp > 0.0:
		var boost_target: float = gdp * (prod * 0.006 + rnd * 0.002)
		var boost_prev: float = float(p.get("_gdp_boost", 0.0))
		var boost_delta: float = (boost_target - boost_prev) * 0.20
		economy["gdp"] = gdp + boost_delta
		p["_gdp_boost"] = boost_prev + boost_delta
		# درآمد صادرات دفاعی → کانال reserve_inflows (بازرسی ۱۴۰۵؛ مالک مخزن: بانک مرکزی)
		var di_infl: Dictionary = economy.get("reserve_inflows", {})
		di_infl["صادرات دفاعی"] = (gdp * export_lvl * 0.003) if (export_lvl > 0.0 and new_self > 0.50) else 0.0
		economy["reserve_inflows"] = di_infl
		state["economy"] = economy

	# اثر نظامی: آمادگی و قدرت
	if not military.is_empty():
		military["readiness"] = clampf(float(military.get("readiness", 0.5)) + new_self * 0.003, 0.0, 1.0)
		military["equipment_quality"] = clampf(float(military.get("equipment_quality", 0.4)) + rnd * 0.002, 0.0, 1.0)
		# کاهش وابستگی واردات تسلیحات
		military["import_dependency"] = clampf(float(military.get("import_dependency", 0.6)) - new_self * 0.003, 0.0, 1.0)
		state["military"] = military

	emit_signal("defense_industry_changed", new_self)
	state["defense_industry_policy"] = p
	return state

func simulate_month(state: Dictionary, tick: int) -> Dictionary:
	# قرارداد مشترک چرخه ماهانه موتور: خروجی همیشه {state, events} است؛
	# simulate خام state را برمی‌گرداند (سازگار با تست‌ها) پس اینجا بسته‌بندی می‌شود.
	return {"state": simulate(state, tick), "events": []}

func get_summary(state: Dictionary) -> Dictionary:
	var p = get_policy(state)
	return {
		"production": p["production"],
		"r_and_d": p["r_and_d"],
		"maintenance": p["maintenance"],
		"exports": p["exports"],
		"self_suff": p["self_suff"],
		"training": p["training"],
	}
