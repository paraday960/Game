extends Node
# ────────────────────────────────────────────────────────────────────────────
# استانداران و سیاست استانی — عمق جغرافیایی
# ۵ استان کلیدی کشور (به‌لحاظ وزن جمعیتی) هرکدام استاندار دارند که از جناح‌ها
# انتخاب می‌شود (پیوند با سیستم فراکسیون‌ها). استاندار کارآمد → رضایت استانی و
# توسعه؛ استاندار فاسد → رسوایی و ناآرامی. بازیکن انتصاب/برکناری می‌کند.
#
# state["governors"] = { "provinces": { code: {name_fa, governor, faction, competence,
#   corruption, approval, unrest, appointments} }, "scandal_queue": [] }
# ────────────────────────────────────────────────────────────────────────────

const MAX_PROVINCES := 5
const GOVERNOR_NAMES := ["استاندار امیری", "استاندار نادری", "استاندار رضایی", "استاندار کریمی", "استاندار صادقی", "استاندار موسوی", "استاندار حسینی", "استاندار قاسمی"]

func ensure(state: Dictionary) -> Dictionary:
	if not state.has("governors"):
		var provinces := _pick_provinces(state)
		var provs: Dictionary = {}
		for i in range(provinces.size()):
			var code := str(provinces[i])
			provs[code] = {
				"name_fa": _province_name(state, code),
				"governor": GOVERNOR_NAMES[i % GOVERNOR_NAMES.size()],
				"faction": ["ارتش", "تکنوکرات‌ها", "نخبگان اقتصادی", "روحانیت", "پوپولیست‌ها"][i % 5],
				"competence": 0.55 + float(i) * 0.03,
				"corruption": 0.25 + float(i) * 0.04,
				"approval": 55.0,
				"unrest": 0.0,
				"appointments": 0
			}
		state["governors"] = {"provinces": provs, "scandal_queue": []}
	return state

func _pick_provinces(state: Dictionary) -> Array:
	var player_id := str(state.get("world", {}).get("player_country", WorldManager.default_country))
	var units: Array = CountryGeographyManager.get_units(player_id)
	var sorted_units := units.duplicate()
	sorted_units.sort_custom(func(a, b): return float(a.get("area_weight", 0.0)) > float(b.get("area_weight", 0.0)))
	var out: Array = []
	for unit in sorted_units:
		if out.size() >= MAX_PROVINCES:
			break
		out.append(str(unit.get("id", "")))
	return out

func _province_name(state: Dictionary, code: String) -> String:
	var player_id := str(state.get("world", {}).get("player_country", WorldManager.default_country))
	var units: Array = CountryGeographyManager.get_units(player_id)
	for unit in units:
		if str(unit.get("id", "")) == code:
			return str(unit.get("name_fa", code))
	return code

# ── انتصاب استاندار از جناح (هزینه سرمایه سیاسی؛ وفاداری جناح را بالا می‌برد) ──
func can_appoint(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var capital := float(state.get("policies", {}).get("political_capital", 0.0))
	if capital < 1.0:
		return {"valid": false, "reason": "سرمایه سیاسی کافی نیست (۱ واحد)"}
	return {"valid": true, "reason": ""}

func appoint(state: Dictionary, province_code: String, faction: String) -> Dictionary:
	state = ensure(state)
	var check := can_appoint(state)
	if not check.valid:
		return {"success": false, "reason": check.reason, "state": state, "events": []}
	var governors: Dictionary = state["governors"]
	var provs: Dictionary = governors.get("provinces", {})
	if not provs.has(province_code):
		return {"success": false, "reason": "استان نامعتبر", "state": state, "events": []}
	var prov: Dictionary = provs[province_code]
	prov["governor"] = GOVERNOR_NAMES[Deterministic.next_int_range(0, GOVERNOR_NAMES.size() - 1)]
	prov["faction"] = faction
	prov["competence"] = 0.5 + Deterministic.next_range(0.1, 0.4)
	prov["corruption"] = Deterministic.next_range(0.15, 0.4)
	prov["appointments"] = int(prov.get("appointments", 0)) + 1
	provs[province_code] = prov
	governors["provinces"] = provs
	state["governors"] = governors
	var policies: Dictionary = state.get("policies", {})
	policies["political_capital"] = float(policies.get("political_capital", 0.0)) - 1.0
	state["policies"] = policies
	# پیوند با فراکسیون‌ها: وفاداری جناح استاندار بالا می‌رود
	var factions: Dictionary = state.get("factions", {})
	if factions.has(faction):
		var f: Dictionary = factions[faction]
		f["loyalty"] = clampf(float(f.get("loyalty", 50.0)) + 2.0, 0.0, 100.0)
		factions[faction] = f
		state["factions"] = factions
	return {"success": true, "state": state,
		"events": [{"type": "governor_appointed", "message": "🏛️ استاندار جدید «%s» (از جناح %s) منصوب شد" % [prov["name_fa"], faction]}]}

# ── شبیه‌سازی ماهانه ──
func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var governors: Dictionary = state["governors"]
	var provs: Dictionary = governors.get("provinces", {})
	var econ: Dictionary = state.get("economy", {})
	var pol: Dictionary = state.get("politics", {})
	var unemployment := float(econ.get("unemployment", 0.08))
	var corruption_national := float(pol.get("corruption", 0.3))

	for code in provs.keys():
		var prov: Dictionary = provs[code]
		var competence := float(prov.get("competence", 0.5))
		var corruption := float(prov.get("corruption", 0.3))
		var approval := float(prov.get("approval", 55.0))
		var unrest := float(prov.get("unrest", 0.0))
		# رضایت استانی: شاخص‌ها + شایستگی استاندار − فساد او
		var drift := (0.5 - unemployment * 1.5 - corruption_national * 0.5 + competence * 0.3 - corruption * 0.8) * 0.8
		prov["approval"] = clampf(approval + drift, 5.0, 100.0)
		# ناآرامی با رضایت پایین و فساد بالا
		var unrest_drift := (45.0 - float(prov["approval"])) * 0.01 + corruption * 0.2
		prov["unrest"] = clampf(unrest + unrest_drift, 0.0, 1.0)
		# رسوایی استاندار فاسد
		var scandal_roll := corruption * 0.06
		if Deterministic.chance(scandal_roll):
			prov["unrest"] = clampf(float(prov["unrest"]) + 0.2, 0.0, 1.0)
			prov["approval"] = clampf(float(prov["approval"]) - 8.0, 5.0, 100.0)
			events.append({"type": "governor_scandal", "province": code,
				"message": "🚨 رسوایی فساد «%s» در استان %s افشا شد؛ ناآرامی بالا گرفت" % [prov["governor"], prov["name_fa"]]})
		# ناآرامی بالا → کاهش ثبات ملی و تولید
		if unrest > 0.6:
			pol["stability"] = clampf(float(pol.get("stability", 0.6)) - 0.01, 0.05, 1.0)
			econ["gdp"] = float(econ.get("gdp", 1.0)) * 0.999
		provs[code] = prov
	governors["provinces"] = provs
	state["governors"] = governors
	state["politics"] = pol
	state["economy"] = econ
	return {"state": state, "events": events}
