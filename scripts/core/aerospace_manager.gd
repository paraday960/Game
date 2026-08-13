extends Node
# ── هوافضا، ماهواره و صنعت فضایی ──
# پرتاب ماهواره، سنجش از دور، مخابرات فضایی و فناوری
# ماهواره‌ای. به نظارت زمینی، مخابرات، پیش‌بینی آب‌وهوا و
# قدرت نرم کمک می‌کند. پیوند: فناوری، دفاع، ارتباطات.

signal satellite_count_changed(count: int)

var launch_capacity: float = 0.05
var satellite_manufacturing: float = 0.10
var remote_sensing: float = 0.05
var space_telecom: float = 0.05
var r_and_d: float = 0.10
var satellites_in_orbit: int = 0
var last_tick: int = 0

func reset():
	launch_capacity = 0.05
	satellite_manufacturing = 0.10
	remote_sensing = 0.05
	space_telecom = 0.05
	r_and_d = 0.10
	satellites_in_orbit = 0

func _ensure(state: Dictionary):
	if not state.has("space_policy"):
		state["space_policy"] = {
			"launch": launch_capacity,
			"manufacturing": satellite_manufacturing,
			"remote_sensing": remote_sensing,
			"telecom": space_telecom,
			"rnd": r_and_d,
			"satellites": satellites_in_orbit,
			"last_tick": last_tick,
		}

func get_policy(state: Dictionary) -> Dictionary:
	_ensure(state)
	return state["space_policy"]

func expand_launch(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["space_policy"]
	var tech: float = float(state.get("technology", {}).get("branches", {}).get("aerospace", 0.0)) if state.get("technology",{}).get("branches",{}).has("aerospace") else float(state.get("ai_policy",{}).get("adoption",0.1))
	if tech < 0.25:
		return {"success": false, "reason": "به فناوری فضایی بالاتری نیاز است"}
	p["launch"] = clampf(float(p["launch"]) + 0.10, 0.0, 1.0)
	state["space_policy"] = p
	return {"success": true}

func build_satellite_factory(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["space_policy"]
	p["manufacturing"] = clampf(float(p["manufacturing"]) + 0.12, 0.0, 1.0)
	state["space_policy"] = p
	return {"success": true}

func invest_remote_sensing(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["space_policy"]
	p["remote_sensing"] = clampf(float(p["remote_sensing"]) + 0.12, 0.0, 1.0)
	state["space_policy"] = p
	return {"success": true}

func invest_space_telecom(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["space_policy"]
	p["telecom"] = clampf(float(p["telecom"]) + 0.12, 0.0, 1.0)
	state["space_policy"] = p
	return {"success": true}

func invest_rnd(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["space_policy"]
	p["rnd"] = clampf(float(p["rnd"]) + 0.12, 0.0, 1.0)
	state["space_policy"] = p
	return {"success": true}

func simulate(state: Dictionary, tick: int) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["space_policy"]
	var economy: Dictionary = state.get("economy", {})
	var gdp: float = float(economy.get("gdp", 0.0))
	var military: Dictionary = state.get("military", {})
	var research: float = float(state.get("research_policy", {}).get("innovation_index", 0.3))

	var launch: float = float(p["launch"])
	var mfg: float = float(p["manufacturing"])
	var sensing: float = float(p["remote_sensing"])
	var telecom: float = float(p["telecom"])
	var rnd: float = float(p["rnd"])

	# توان پرتاب و ساخت، احتمال پرتاب موفق را تعیین می‌کند
	var launch_prob: float = clampf(launch * 0.5 + mfg * 0.3 + rnd * 0.2, 0.0, 0.95)
	# هر ۳ نوبت یک بار شانس پرتاب
	var fmod: int = tick % 3
	if fmod == 0 and launch_prob > 0.15 and randf() < launch_prob * 0.4:
		satellites_in_orbit += 1
	var sat_count: int = satellites_in_orbit
	p["satellites"] = sat_count
	p["last_tick"] = tick

	if gdp > 0.0:
		# درآمد از سرویس‌های ماهواره‌ای (مخابرات + سنجش)
		var space_gdp: float = gdp * (sat_count * 0.0004 + telecom * 0.003 + sensing * 0.002)
		economy["gdp"] = gdp + space_gdp
		economy["foreign_reserves"] = float(economy.get("foreign_reserves", 0.0)) + gdp * (telecom * 0.001)
		state["economy"] = economy

	# کمک به دفاع و اطلاعات
	if not military.is_empty():
		military["intelligence"] = clampf(float(military.get("intelligence", 0.5)) + sensing * 0.003, 0.0, 1.0)
		military["equipment_quality"] = clampf(float(military.get("equipment_quality", 0.4)) + rnd * 0.001, 0.0, 1.0)
		state["military"] = military

	# قدرت نرم و تحقیق
	if state.has("diplomacy") and state["diplomacy"] is Dictionary:
		var dip: Dictionary = state["diplomacy"]
		dip["soft_power"] = clampf(float(dip.get("soft_power", 35.0)) + sat_count * 0.05, 0.0, 100.0)
		state["diplomacy"] = dip

	emit_signal("satellite_count_changed", sat_count)
	state["space_policy"] = p
	return state

func simulate_month(state: Dictionary, tick: int) -> Dictionary:
	return simulate(state, tick)

func get_summary(state: Dictionary) -> Dictionary:
	var p = get_policy(state)
	return {
		"launch": p["launch"],
		"manufacturing": p["manufacturing"],
		"remote_sensing": p["remote_sensing"],
		"telecom": p["telecom"],
		"rnd": p["rnd"],
		"satellites": p["satellites"],
	}
