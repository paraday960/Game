extends Node
# ── صنعت باطری، خودرو برقی و گذار انرژی ──
# زنجیره باطری (لیتیم/سلول)، تولید خودروی برقی، ایستگاه شارژ و
# سهم خودروی برقی. این صنعت به کاهش آلودگی و وابستگی به سوخت کمک می‌کند
# اما به برق و مواد اولیه نیاز دارد. پیوند: انرژی، معدن، محیط‌زیست.

signal ev_adoption_changed(share: float)

var battery_capacity: float = 0.15  # ظرفیت تولید باطری (نسبی)
var battery_research: float = 0.10
var ev_production: float = 0.05
var charging_stations: float = 0.05
var ev_share: float = 0.02
var recycling: float = 0.05
var last_tick: int = 0

const BATTERY_MATERIAL_NEED := 0.4  # وابستگی به مواد معدنی
const GRID_NEED := 0.5

func reset():
	battery_capacity = 0.15
	battery_research = 0.10
	ev_production = 0.05
	charging_stations = 0.05
	ev_share = 0.02
	recycling = 0.05

func _ensure(state: Dictionary):
	if not state.has("ev_policy"):
		state["ev_policy"] = {
			"battery_capacity": battery_capacity,
			"battery_research": battery_research,
			"ev_production": ev_production,
			"charging": charging_stations,
			"ev_share": ev_share,
			"recycling": recycling,
			"last_tick": last_tick,
		}

func get_policy(state: Dictionary) -> Dictionary:
	_ensure(state)
	return state["ev_policy"]

func build_battery_factory(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["ev_policy"]
	# نیاز به مواد معدنی و انرژی
	var minerals: float = float(state.get("mining_policy", {}).get("output", 0.2))
	var energy_sec: float = float(state.get("energy_policy", {}).get("energy_security", 0.4))
	if minerals < BATTERY_MATERIAL_NEED * 0.5 or energy_sec < GRID_NEED * 0.5:
		return {"success": false, "reason": "به مواد معدنی و برق پایدار بیشتری نیاز است"}
	p["battery_capacity"] = clampf(float(p["battery_capacity"]) + 0.12, 0.0, 1.0)
	state["ev_policy"] = p
	return {"success": true}

func invest_battery_research(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["ev_policy"]
	p["battery_research"] = clampf(float(p["battery_research"]) + 0.12, 0.0, 1.0)
	state["ev_policy"] = p
	return {"success": true}

func expand_ev_production(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["ev_policy"]
	if float(p["battery_capacity"]) < 0.25:
		return {"success": false, "reason": "ابتدا ظرفیت باطری را افزایش دهید"}
	p["ev_production"] = clampf(float(p["ev_production"]) + 0.12, 0.0, 1.0)
	state["ev_policy"] = p
	return {"success": true}

func build_charging_network(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["ev_policy"]
	var energy_sec: float = float(state.get("energy_policy", {}).get("energy_security", 0.4))
	if energy_sec < 0.3:
		return {"success": false, "reason": "شبکه برق پایدار نیست"}
	p["charging"] = clampf(float(p["charging"]) + 0.12, 0.0, 1.0)
	state["ev_policy"] = p
	return {"success": true}

func expand_recycling(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["ev_policy"]
	p["recycling"] = clampf(float(p["recycling"]) + 0.12, 0.0, 1.0)
	state["ev_policy"] = p
	return {"success": true}

func simulate(state: Dictionary, tick: int) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["ev_policy"]
	var economy: Dictionary = state.get("economy", {})
	var gdp: float = float(economy.get("gdp", 0.0))
	var energy_sec: float = float(state.get("energy_policy", {}).get("energy_security", 0.4))

	# سهم خودروی برقی تابع تولید + شارژ + تحقیق باطری
	var target_share: float = (
		float(p["ev_production"]) * 0.4 +
		float(p["charging"]) * 0.3 +
		float(p["battery_research"]) * 0.2 +
		minf(energy_sec, 1.0) * 0.1
	)
	target_share = clampf(target_share, 0.0, 0.90)
	var current: float = float(p["ev_share"])
	# رشد تدریجی
	var new_share: float = lerp(current, target_share, 0.08)
	p["ev_share"] = new_share
	p["last_tick"] = tick

	# اثر اقتصادی: صنعت باطری و خودرو به GDP
	if gdp > 0.0:
		var industry_gdp: float = gdp * (
			float(p["battery_capacity"]) * 0.004 +
			float(p["ev_production"]) * 0.006 +
			float(p["battery_research"]) * 0.002
		)
		economy["gdp"] = gdp + industry_gdp
		state["economy"] = economy

	# کاهش آلودگی و وابستگی سوخت
	if state.has("environment") and state["environment"] is Dictionary:
		var env: Dictionary = state["environment"]
		env["pollution"] = clampf(float(env.get("pollution", 0.5)) - new_share * 0.004, 0.0, 1.0)
		state["environment"] = env
	if state.has("energy_policy") and state["energy_policy"] is Dictionary:
		var energy: Dictionary = state["energy_policy"]
		# کاهش خام‌فروشی/واردات سوخت
		energy["fuel_import_dep"] = clampf(float(energy.get("fuel_import_dep", 0.5)) - new_share * 0.02, 0.0, 1.0)
		state["energy_policy"] = energy

	emit_signal("ev_adoption_changed", new_share)
	state["ev_policy"] = p
	return state

func get_summary(state: Dictionary) -> Dictionary:
	var p = get_policy(state)
	return {
		"battery_capacity": p["battery_capacity"],
		"battery_research": p["battery_research"],
		"ev_production": p["ev_production"],
		"charging": p["charging"],
		"ev_share": p["ev_share"],
		"recycling": p["recycling"],
	}

# سازگاری با چرخه‌ی ماهانه‌ی GameEngine
func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	return simulate(state, turn)
