extends Node
# ── مدیریت پسماند، بازیافت و اقتصاد چرخه‌ای ──
# جمع‌آوری زباله، تفکیک از مبدأ، بازیافت، انرژی از زباله
# و کاهش دفن. این سیستم به بهداشت، کاهش آلودگی و حتی
# تولید انرژی/درآمد کمک می‌کند. پیوند: محیط‌زیست، انرژی، رفاه.

signal recycling_rate_changed(rate: float)

var collection: float = 0.40
var separation: float = 0.15
var recycling: float = 0.20
var waste_to_energy: float = 0.05
var landfill_reduction: float = 0.0
var last_tick: int = 0

func reset():
	collection = 0.40
	separation = 0.15
	recycling = 0.20
	waste_to_energy = 0.05
	landfill_reduction = 0.0

func _ensure(state: Dictionary):
	if not state.has("waste_policy"):
		state["waste_policy"] = {
			"collection": collection,
			"separation": separation,
			"recycling": recycling,
			"waste_to_energy": waste_to_energy,
			"landfill_reduction": landfill_reduction,
			"recycling_rate": 0.0,
			"last_tick": last_tick,
		}

func get_policy(state: Dictionary) -> Dictionary:
	_ensure(state)
	return state["waste_policy"]

func expand_collection(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["waste_policy"]
	p["collection"] = clampf(float(p["collection"]) + 0.10, 0.0, 1.0)
	state["waste_policy"] = p
	return {"success": true}

func source_separation(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["waste_policy"]
	p["separation"] = clampf(float(p["separation"]) + 0.12, 0.0, 1.0)
	state["waste_policy"] = p
	return {"success": true}

func build_recycling(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["waste_policy"]
	p["recycling"] = clampf(float(p["recycling"]) + 0.12, 0.0, 1.0)
	state["waste_policy"] = p
	return {"success": true}

func build_wte(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["waste_policy"]
	p["waste_to_energy"] = clampf(float(p["waste_to_energy"]) + 0.10, 0.0, 1.0)
	state["waste_policy"] = p
	return {"success": true}

func reduce_landfill(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["waste_policy"]
	p["landfill_reduction"] = clampf(float(p["landfill_reduction"]) + 0.10, 0.0, 1.0)
	state["waste_policy"] = p
	return {"success": true}

func simulate(state: Dictionary, tick: int) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["waste_policy"]
	var economy: Dictionary = state.get("economy", {})
	var gdp: float = float(economy.get("gdp", 0.0))
	var env: Dictionary = state.get("environment", {})
	var energy: Dictionary = state.get("energy_policy", {})
	var health: Dictionary = state.get("health", {})

	var collect: float = float(p["collection"])
	var separate: float = float(p["separation"])
	var recycle: float = float(p["recycling"])
	var wte: float = float(p["waste_to_energy"])
	var landfill_lvl: float = float(p["landfill_reduction"])

	# نرخ بازیافت کلی
	var recycling_rate: float = clampf(
		collect * (separate * 0.4 + recycle * 0.5 + wte * 0.1),
		0.0, 0.95
	)
	p["recycling_rate"] = recycling_rate
	p["last_tick"] = tick

	# کاهش دفن زباله
	var landfill_cut: float = clampf(
		recycling_rate * 0.6 + landfill_lvl * 0.3 + wte * 0.1, 0.0, 0.9
	)

	# اثر زیست‌محیطی: کاهش آلودگی
	if not env.is_empty():
		env["pollution"] = clampf(
			float(env.get("pollution", 0.5)) - recycling_rate * 0.003, 0.0, 1.0
		)
		state["environment"] = env

	# انرژی از زباله
	if wte > 0.0 and gdp > 0.0:
		var energy_boost: float = gdp * wte * 0.001
		if energy.has("energy_security"):
			energy["energy_security"] = clampf(
				float(energy["energy_security"]) + wte * 0.002, 0.0, 1.0
			)
			state["energy_policy"] = energy
		if economy.has("gdp"):
			economy["gdp"] = gdp + energy_boost * 0.3
			state["economy"] = economy

	# درآمد بازیافت (مواد اولیه ثانویه)
	if recycling_rate > 0.2 and gdp > 0.0:
		var recycle_rev: float = gdp * recycling_rate * 0.001
		economy["gdp"] = float(economy.get("gdp", gdp)) + recycle_rev
		state["economy"] = economy

	# بهبود سلامت عمومی (کاهش زباله‌های روباز)
	if not health.is_empty():
		health["quality"] = clampf(
			float(health.get("quality", 0.5)) + collect * 0.0008, 0.0, 1.0
		)
		state["health"] = health

	emit_signal("recycling_rate_changed", recycling_rate)
	state["waste_policy"] = p
	return state

func simulate_month(state: Dictionary, tick: int) -> Dictionary:
	return simulate(state, tick)

func get_summary(state: Dictionary) -> Dictionary:
	var p = get_policy(state)
	return {
		"collection": p["collection"],
		"separation": p["separation"],
		"recycling": p["recycling"],
		"waste_to_energy": p["waste_to_energy"],
		"recycling_rate": p["recycling_rate"],
		"landfill_reduction": p["landfill_reduction"],
	}
