extends Node
# ────────────────────────────────────────────────────────────────────────────
# فراکسیون‌های سیاسی — عمق سیاست داخلی
# هر جناح (ارتش، روحانیت، نخبگان اقتصادی، تکنوکرات‌ها، پوپولیست‌ها، رسانه) دو
# شاخص دارد: «نفوذ» (قدرت تأثیرگذاری) و «وفاداری» (به دولت).
#  - سیاست‌ها/بودجه/قوانین هر ماه وفاداری و نفوذ را جابه‌جا می‌کنند.
#  - وفاداری پایین → بحران جناحی (تهدید کودتا، اعتراض، فرار سرمایه، ...).
#  - نفوذ بالا → جناح بر سیاست اثر می‌گذارد (فساد، قدرت نظامی، ثبات...).
#  - بازیکن می‌تواند آشتی، رویارویی یا هم‌پیمانی (انتصاب از جناح) انجام دهد.
#
# state["factions"] = { "ارتش": {"power":0..100, "loyalty":0..100}, ... }
# ────────────────────────────────────────────────────────────────────────────

const FACTIONS := ["ارتش", "روحانیت", "نخبگان اقتصادی", "تکنوکرات‌ها", "پوپولیست‌ها", "رسانه"]
const CRISIS_THRESHOLD := 22.0

func ensure(state: Dictionary) -> Dictionary:
	if not state.has("factions"):
		state["factions"] = {
			"ارتش": {"power": 55.0, "loyalty": 62.0},
			"روحانیت": {"power": 45.0, "loyalty": 60.0},
			"نخبگان اقتصادی": {"power": 55.0, "loyalty": 55.0},
			"تکنوکرات‌ها": {"power": 35.0, "loyalty": 65.0},
			"پوپولیست‌ها": {"power": 30.0, "loyalty": 55.0},
			"رسانه": {"power": 40.0, "loyalty": 60.0}
		}
	return state

# ────────────────────────────────────────────────────────────────────────────
# شبیه‌سازی ماهانه: جابه‌جایی وفاداری/نفوذ + بحران‌ها + اثر نفوذ بر کشور
# ────────────────────────────────────────────────────────────────────────────
func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var factions: Dictionary = state["factions"]
	var events: Array = []
	var econ: Dictionary = state.get("economy", {})
	var pol: Dictionary = state.get("politics", {})
	var pop: Dictionary = state.get("population", {})
	var mil: Dictionary = state.get("military", {})
	var tech: Dictionary = state.get("technology", {})
	var welfare: Dictionary = state.get("welfare", {})
	var budget: Dictionary = econ.get("budget_allocations", {})
	var laws: Array = state.get("laws", {}).get("active", [])
	var world: Dictionary = state.get("world", {})
	var at_war: bool = not world.get("wars", {}).is_empty()
	var tax := float(econ.get("tax_rate", 0.2))
	var corruption := float(pol.get("corruption", 0.3))
	var stability := float(pol.get("stability", 0.6))
	var happiness := float(pop.get("happiness", 0.6))
	var unemployment := float(econ.get("unemployment", 0.08))
	var gini := float(welfare.get("gini", 0.38))
	var tech_level := float(tech.get("tech_level", 0.3))
	var war_exhaustion := float(mil.get("war_exhaustion", 0.0))

	# ── جابه‌جایی وفاداری بر اساس سیاست‌های دولت ──
	var army: Dictionary = factions["ارتش"]
	army["loyalty"] = float(army["loyalty"]) + float(budget.get("دفاع", 0.08)) * 12.0
	if at_war:
		army["loyalty"] += 1.0
		army["power"] += 1.0
	army["loyalty"] -= war_exhaustion * 6.0

	var clergy: Dictionary = factions["روحانیت"]
	for law_id in laws:
		if law_id in ["civil_liberties", "freedom_of_information", "digital_privacy"]:
			clergy["loyalty"] -= 0.6
		elif law_id in ["family_support_law", "education_right"]:
			clergy["loyalty"] += 0.4
	if happiness < 0.5:
		clergy["power"] += 0.5

	var elites: Dictionary = factions["نخبگان اقتصادی"]
	elites["loyalty"] -= absf(tax - 0.20) * 40.0
	elites["loyalty"] -= corruption * 2.0
	if stability > 0.65:
		elites["loyalty"] += 1.0
	elites["power"] += corruption * 2.0

	var technocrats: Dictionary = factions["تکنوکرات‌ها"]
	technocrats["loyalty"] += float(budget.get("فناوری", 0.04)) * 18.0
	technocrats["loyalty"] += float(budget.get("آموزش", 0.06)) * 10.0
	technocrats["power"] += tech_level * 2.0

	var populists: Dictionary = factions["پوپولیست‌ها"]
	populists["loyalty"] -= unemployment * 25.0
	if happiness < 0.45:
		populists["loyalty"] -= 2.0
		populists["power"] += 1.2
	populists["power"] += maxf(0.0, gini - 0.35) * 8.0

	var media: Dictionary = factions["رسانه"]
	if laws.has("freedom_of_information"):
		media["power"] += 0.8
		media["loyalty"] -= 0.5
	else:
		media["loyalty"] += 0.5
	media["power"] += (0.5 - corruption) * 1.0

	# بازگشت تدریجی به نقطه تعادل
	for fid in FACTIONS:
		var f: Dictionary = factions[fid]
		f["loyalty"] = clampf(float(f["loyalty"]) + (50.0 - float(f["loyalty"])) * 0.02, 0.0, 100.0)
		f["power"] = clampf(float(f["power"]) + (40.0 - float(f["power"])) * 0.01, 5.0, 95.0)

	# ── بحران‌های جناحی (وفاداری بسیار پایین) ──
	for fid in FACTIONS:
		var f: Dictionary = factions[fid]
		if float(f["loyalty"]) < CRISIS_THRESHOLD and Deterministic.chance(0.22):
			var crisis := _faction_crisis(state, fid, f)
			state = crisis.state
			events.append_array(crisis.events)
			f = factions[fid]

	# ── اثر نفوذ جناح‌ها بر کشور ──
	var elites_power := float(elites["power"]) / 100.0
	pol["corruption"] = clampf(float(pol.get("corruption", 0.3)) + (elites_power - 0.5) * 0.004, 0.0, 1.0)
	var army_power := float(army["power"]) / 100.0
	mil["power"] = maxf(5.0, float(mil.get("power", 50.0)) * (0.98 + army_power * 0.05))
	var populist_power := float(populists["power"]) / 100.0
	if populist_power > 0.55:
		pol["stability"] = clampf(float(pol.get("stability", 0.6)) - (populist_power - 0.55) * 0.02, 0.05, 1.0)
	var clergy_power := float(clergy["power"]) / 100.0
	if clergy_power > 0.60:
		pol["tension"] = clampf(float(pol.get("tension", 0.3)) + (clergy_power - 0.60) * 0.01, 0.0, 1.0)

	state["factions"] = factions
	state["politics"] = pol
	state["military"] = mil
	return {"state": state, "events": events}

func _faction_crisis(state: Dictionary, fid: String, f: Dictionary) -> Dictionary:
	var events: Array = []
	var pol: Dictionary = state.get("politics", {})
	var pop: Dictionary = state.get("population", {})
	var econ: Dictionary = state.get("economy", {})
	match fid:
		"ارتش":
			pol["stability"] = clampf(float(pol.get("stability", 0.6)) - 0.05, 0.05, 1.0)
			f["loyalty"] = clampf(float(f["loyalty"]) - 5.0, 0.0, 100.0)
			events.append({"type": "faction_crisis", "faction": fid,
				"message": "⚠️ نارضایتی ارتش به تهدید کودتا رسید! ستاد ارتش خواستار اختیارات بیشتر شد و ثبات ملی آسیب دید."})
		"پوپولیست‌ها":
			pol["stability"] = clampf(float(pol.get("stability", 0.6)) - 0.04, 0.05, 1.0)
			pop["happiness"] = clampf(float(pop.get("happiness", 0.6)) - 0.02, 0.05, 1.0)
			events.append({"type": "faction_crisis", "faction": fid,
				"message": "⚠️ اعتراضات خیابانی پوپولیست‌ها به خشونت کشیده شد؛ شادی مردم و ثبات کاهش یافت."})
		"نخبگان اقتصادی":
			econ["gdp"] = float(econ.get("gdp", 1.0)) * 0.995
			econ["foreign_reserves"] = maxf(0.0, float(econ.get("foreign_reserves", 0.0)) * 0.99)
			events.append({"type": "faction_crisis", "faction": fid,
				"message": "⚠️ فرار سرمایه! نخبگان اقتصادی به دلیل بی‌اعتمادی، سرمایه‌های خود را از کشور خارج کردند."})
		"روحانیت":
			pol["stability"] = clampf(float(pol.get("stability", 0.6)) - 0.03, 0.05, 1.0)
			pol["tension"] = clampf(float(pol.get("tension", 0.3)) + 0.05, 0.0, 1.0)
			events.append({"type": "faction_crisis", "faction": fid,
				"message": "⚠️ ناآرامی مذهبی: روحانیت علیه سیاست‌های دولت موضع گرفت و تنش اجتماعی بالا رفت."})
		"تکنوکرات‌ها":
			var tech: Dictionary = state.get("technology", {})
			tech["researchers"] = maxf(1000.0, float(tech.get("researchers", 50000.0)) * 0.99)
			state["technology"] = tech
			events.append({"type": "faction_crisis", "faction": fid,
				"message": "⚠️ مهاجرت نخبگان علمی: تکنوکرات‌ها از دولت ناامید شدند و پژوهشگران کشور را ترک کردند."})
		"رسانه":
			pol["trust"] = clampf(float(pol.get("trust", 0.55)) - 0.02, 0.05, 1.0)
			pol["corruption"] = clampf(float(pol.get("corruption", 0.3)) + 0.01, 0.0, 1.0)
			events.append({"type": "faction_crisis", "faction": fid,
				"message": "⚠️ جنجال رسانه‌ای: افشاگری‌های رسانه‌ها اعتماد عمومی به دولت را خدشه‌دار کرد."})
	state["politics"] = pol
	state["population"] = pop
	state["economy"] = econ
	return {"state": state, "events": events}

# ────────────────────────────────────────────────────────────────────────────
# اقدامات بازیکن بر جناح‌ها (فرمان faction_action)
# ────────────────────────────────────────────────────────────────────────────
func can_action(state: Dictionary, faction: String, action: String) -> Dictionary:
	if not FACTIONS.has(faction):
		return {"valid": false, "reason": "جناح نامعتبر است"}
	var capital := float(state.get("policies", {}).get("political_capital", 0.0))
	var cost: float = float({"appease": 1.0, "confront": 0.0, "ally": 1.5}.get(action, 0.0))
	if capital < float(cost):
		return {"valid": false, "reason": "سرمایه سیاسی کافی نیست"}
	return {"valid": true, "reason": ""}

func apply_action(state: Dictionary, faction: String, action: String) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var check := can_action(state, faction, action)
	if not check.valid:
		return {"success": false, "reason": check.reason, "state": state, "events": events}
	var factions: Dictionary = state["factions"]
	var f: Dictionary = factions[faction]
	var policies: Dictionary = state.get("policies", {})
	match action:
		"appease":
			policies["political_capital"] = float(policies.get("political_capital", 0.0)) - 1.0
			f["loyalty"] = clampf(float(f["loyalty"]) + 14.0, 0.0, 100.0)
			f["power"] = clampf(float(f["power"]) + 2.0, 5.0, 95.0)
			events.append({"type": "faction_action", "faction": faction,
				"message": "دولت با «%s» آشتی کرد؛ وفاداری جناح بالا رفت اما نفوذش هم بیشتر شد" % faction})
		"confront":
			policies["political_capital"] = float(policies.get("political_capital", 0.0)) + 0.5
			f["loyalty"] = clampf(float(f["loyalty"]) - 18.0, 0.0, 100.0)
			f["power"] = clampf(float(f["power"]) - 5.0, 5.0, 95.0)
			events.append({"type": "faction_action", "faction": faction,
				"message": "دولت با «%s» رویارو شد؛ نفوذ جناح کاهش یافت اما خطر بی‌وفایی بالا رفت" % faction})
		"ally":
			policies["political_capital"] = float(policies.get("political_capital", 0.0)) - 1.5
			f["loyalty"] = clampf(float(f["loyalty"]) + 16.0, 0.0, 100.0)
			f["power"] = clampf(float(f["power"]) + 3.0, 5.0, 95.0)
			var cabinet: Dictionary = state.get("cabinet", {})
			cabinet["cohesion"] = clampf(float(cabinet.get("cohesion", 0.65)) + 0.02, 0.0, 1.0)
			state["cabinet"] = cabinet
			events.append({"type": "faction_action", "faction": faction,
				"message": "نماینده «%s» به دولت پیوست؛ انسجام کابینه و وفاداری جناح بالا رفت" % faction})
	state["factions"] = factions
	state["policies"] = policies
	return {"success": true, "state": state, "events": events}
