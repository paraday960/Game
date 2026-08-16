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
# معاملات جناح‌ها (عمق‌بخشی ۴۶): بازیکن به جناح قول می‌دهد یک اقدام مشخص را
# انجام دهد؛ اگر به قولش عمل کند، وفاداری و نفوذ پاداش می‌گیرد؛ اگر نشکند،
# وفاداری می‌سوزد و بحران نزدیک‌تر می‌شود (پاسخگویی مثل وعده‌های انتخاباتی).
const DEALS := {
	"ارتش": [
		{"id": "defense_commit", "title_fa": "تعهد بودجهٔ دفاعی", "desc_fa": "سهم دفاع را به ۱۲٪ برسانید",
			"metric": "economy.budget_allocations.ارتش", "direction": "gte", "target": 0.10, "loyalty": 15.0, "power": 2.0},
		{"id": "war_ready", "title_fa": "آمادگی رزمی", "desc_fa": "آمادگی ارتش را به ۷۵٪ برسانید",
			"metric": "military.readiness", "direction": "gte", "target": 0.75, "loyalty": 10.0, "power": 1.5}
	],
	"روحانیت": [
		{"id": "family_law", "title_fa": "قانون حمایت از خانواده", "desc_fa": "قانون حمایت از خانواده را تصویب کنید",
			"metric": "legislation.enacted.family_support_law", "direction": "exists", "target": 1.0, "loyalty": 15.0, "power": 1.5},
		{"id": "moral_stability", "title_fa": "آرامش اجتماعی", "desc_fa": "تنش اجتماعی را زیر ۲۵٪ نگه دارید",
			"metric": "politics.tension", "direction": "lte", "target": 0.30, "loyalty": 10.0, "power": 1.0}
	],
	"نخبگان اقتصادی": [
		{"id": "tax_relief", "title_fa": "کاهش مالیات", "desc_fa": "نرخ مالیات را به ۱۵٪ برسانید",
			"metric": "economy.tax_rate", "direction": "lte", "target": 0.18, "loyalty": 15.0, "power": 2.0},
		{"id": "business_stability", "title_fa": "ثبات برای سرمایه", "desc_fa": "ثبات سیاسی را بالای ۶۵٪ نگه دارید",
			"metric": "politics.stability", "direction": "gte", "target": 0.60, "loyalty": 10.0, "power": 1.5}
	],
	"تکنوکرات‌ها": [
		{"id": "tech_funding", "title_fa": "بودجهٔ فناوری", "desc_fa": "سهم فناوری را به ۸٪ برسانید",
			"metric": "economy.budget_allocations.فناوری", "direction": "gte", "target": 0.06, "loyalty": 15.0, "power": 2.0},
		{"id": "research_boost", "title_fa": "جهش پژوهش", "desc_fa": "نرخ پژوهش را بالای ۱۲ نگه دارید",
			"metric": "technology.research_rate", "direction": "gte", "target": 10.0, "loyalty": 10.0, "power": 1.5}
	],
	"پوپولیست‌ها": [
		{"id": "welfare_boost", "title_fa": "بستهٔ رفاهی", "desc_fa": "سهم رفاه را به ۱۸٪ برسانید",
			"metric": "economy.budget_allocations.رفاه", "direction": "gte", "target": 0.17, "loyalty": 12.0, "power": 1.5},
		{"id": "anti_elite", "title_fa": "مالیات سنگین بر ثروت", "desc_fa": "نرخ مالیات را بالای ۲۵٪ نگه دارید",
			"metric": "economy.tax_rate", "direction": "gte", "target": 0.25, "loyalty": 10.0, "power": 1.5}
	],
	"رسانه": [
		{"id": "press_freedom", "title_fa": "آزادی رسانه", "desc_fa": "قانون آزادی اطلاعات را تصویب کنید",
			"metric": "legislation.enacted.freedom_of_information", "direction": "exists", "target": 1.0, "loyalty": 12.0, "power": 2.0},
		{"id": "transparency", "title_fa": "شفافیت", "desc_fa": "فساد را زیر ۲۰٪ نگه دارید",
			"metric": "politics.corruption", "direction": "lte", "target": 0.25, "loyalty": 10.0, "power": 1.0}
	]
}

func get_deals(faction: String) -> Array:
	return DEALS.get(faction, []).duplicate(true)

func _read_metric(state: Dictionary, path: String) -> float:
	var current: Variant = state
	for part in path.split("."):
		if current is Dictionary and current.has(part):
			current = current[part]
		else:
			return -1.0
	return float(current) if current is float or current is int else -1.0

func _deal_kept(state: Dictionary, deal: Dictionary) -> bool:
	var metric := str(deal.get("metric", ""))
	var direction := str(deal.get("direction", "gte"))
	var target := float(deal.get("target", 0.0))
	var current := _read_metric(state, metric)
	if current < 0.0:
		return false
	match direction:
		"lte": return current <= target
		"exists": return current >= 0.0
	return current >= target

func can_deal(state: Dictionary, faction: String, deal_id: String) -> Dictionary:
	if not FACTIONS.has(faction):
		return {"valid": false, "reason": "جناح نامعتبر است"}
	var found := false
	for deal in get_deals(faction):
		if str(deal.get("id", "")) == deal_id:
			found = true
			break
	if not found:
		return {"valid": false, "reason": "معامله نامعتبر است"}
	state = ensure(state)
	var f: Dictionary = state["factions"].get(faction, {})
	for active in f.get("deals", []):
		if str(active.get("id", "")) == deal_id:
			return {"valid": false, "reason": "این معامله قبلاً ثبت شده"}
	if f.get("deals", []).size() >= 2:
		return {"valid": false, "reason": "حداکثر ۲ معاملهٔ فعال با هر جناح"}
	return {"valid": true, "reason": ""}

func make_deal(state: Dictionary, faction: String, deal_id: String, turn: int) -> Dictionary:
	var check := can_deal(state, faction, deal_id)
	if not check.valid:
		return {"success": false, "reason": check.reason, "state": state, "events": []}
	state = ensure(state)
	var f: Dictionary = state["factions"][faction]
	var deals: Array = f.get("deals", [])
	deals.append({"id": deal_id, "promised_turn": turn})
	f["deals"] = deals
	state["factions"][faction] = f
	var title := ""
	for deal in get_deals(faction):
		if str(deal.get("id", "")) == deal_id:
			title = str(deal.get("title_fa", deal_id))
			break
	return {"success": true, "state": state, "events": [{
		"type": "faction_deal", "faction": faction, "deal_id": deal_id,
		"message": "🤝 «%s» به %s قول داد: «%s»" % [title, faction, title]}]}

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

	# ── پاسخگویی معاملات (عمق‌بخشی ۴۶) ──
	# هر معاملهٔ ثبت‌شده بررسی می‌شود: محقق → پاداش وفاداری/نفوذ؛
	# محقق‌نشده → وفاداری می‌سوزد (شکستن قول به جناح).
	for fid in FACTIONS:
		var f: Dictionary = factions[fid]
		var active_deals: Array = f.get("deals", [])
		if active_deals.is_empty():
			continue
		var remaining: Array = []
		for active in active_deals:
			var deal_def := {}
			for dd in get_deals(fid):
				if str(dd.get("id", "")) == str(active.get("id", "")):
					deal_def = dd
					break
			if deal_def.is_empty():
				continue
			if _deal_kept(state, deal_def):
				f["loyalty"] = clampf(float(f["loyalty"]) + float(deal_def.get("loyalty", 10.0)), 0.0, 100.0)
				f["power"] = clampf(float(f["power"]) + float(deal_def.get("power", 1.0)), 5.0, 95.0)
				events.append({"type": "faction_deal_kept", "faction": fid, "deal_id": str(deal_def.get("id", "")),
					"message": "✅ «%s» به قول خود عمل کرد؛ %s وفادارتر و قدرتمندتر شد" % [str(deal_def.get("title_fa", "معامله")), fid]})
			else:
				f["loyalty"] = clampf(float(f["loyalty"]) - 18.0, 0.0, 100.0)
				events.append({"type": "faction_deal_broken", "faction": fid, "deal_id": str(deal_def.get("id", "")),
					"message": "💔 «%s» قول خود را به %s شکست؛ وفاداری جناح به‌شدت کاهش یافت" % [str(deal_def.get("title_fa", "معامله")), fid]})
				remaining.append(active)  # معاملهٔ شکسته دوباره قابل پیشنهاد می‌شود
		f["deals"] = remaining

	# ── واکنش جناح‌ها به قوانین (گسترش، عمق‌بخشی ۴۶) ──
	var enacted: Dictionary = state.get("legislation", {}).get("enacted", {})
	if enacted.has("investment_code"):
		elites["loyalty"] = clampf(float(elites["loyalty"]) + 2.0, 0.0, 100.0)
	if enacted.has("labor_protection"):
		elites["loyalty"] = clampf(float(elites["loyalty"]) - 1.5, 0.0, 100.0)
	if enacted.has("emergency_powers"):
		army["loyalty"] = clampf(float(army["loyalty"]) + 2.0, 0.0, 100.0)
	if enacted.has("anti_corruption_act"):
		elites["loyalty"] = clampf(float(elites["loyalty"]) - 2.0, 0.0, 100.0)
		media["loyalty"] = clampf(float(media["loyalty"]) + 1.5, 0.0, 100.0)

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
