extends Node
# ────────────────────────────────────────────────────────────────────────────
# سازمان‌های بین‌المللی — عمق دیپلماسی چندجانبه
# سه سازمان (سازمان ملل، اوپک، اتحادیه منطقه‌ای) عضویت دارند؛ هر عضویت هزینه
# سالانه و منافع دارد (نفوذ، تجارت، ثبات). هر چند نوبت قطعنامه/تصمیم مطرح
# می‌شود که بازیکن می‌تواند تأیید/وتو کند با هزینه و پیامد.
#
# state["intl_orgs"] = {
#   "memberships": { "سازمان ملل": true, "اوپک": false, "اتحادیه منطقه‌ای": true },
#   "next_vote_turn": 5, "pending_vote": {id, title, yes_effect, no_effect, expires}
#   "votes_history": [...]
# }
# ────────────────────────────────────────────────────────────────────────────

const ORGS := ["سازمان ملل", "اوپک", "اتحادیه منطقه‌ای"]
const ORG_INFO := {
	"سازمان ملل": {"cost": 0.8e9, "benefit": "نفوذ +، ثبات +، ریسک تحریم −"},
	"اوپک": {"cost": 0.2e9, "benefit": "درآمد نفتی +، نفوذ در بازار انرژی"},
	"اتحادیه منطقه‌ای": {"cost": 0.5e9, "benefit": "تجارت +، جابجایی آزاد، ثبات منطقه"}
}

func ensure(state: Dictionary) -> Dictionary:
	if not state.has("intl_orgs"):
		state["intl_orgs"] = {
			"memberships": {"سازمان ملل": true, "اوپک": false, "اتحادیه منطقه‌ای": true},
			"next_vote_turn": 4,
			"pending_vote": {},
			"votes_history": []
		}
	return state

func can_toggle(state: Dictionary, org: String) -> Dictionary:
	state = ensure(state)
	if not ORGS.has(org):
		return {"valid": false, "reason": "سازمان نامعتبر"}
	var memberships: Dictionary = state["intl_orgs"].get("memberships", {})
	var joining := not bool(memberships.get(org, false))
	if joining:
		var foreign := float(state.get("economy", {}).get("foreign_reserves", 0.0))
		if foreign < float(ORG_INFO[org]["cost"]) * 2.0:
			return {"valid": false, "reason": "ذخایر ارزی برای هزینه ورود کافی نیست"}
	return {"valid": true, "reason": ""}

func toggle(state: Dictionary, org: String, turn: int) -> Dictionary:
	state = ensure(state)
	var check := can_toggle(state, org)
	if not check.valid:
		return {"success": false, "reason": check.reason, "state": state, "events": []}
	var intl: Dictionary = state["intl_orgs"]
	var memberships: Dictionary = intl.get("memberships", {})
	var joining := not bool(memberships.get(org, false))
	memberships[org] = joining
	intl["memberships"] = memberships
	var econ: Dictionary = state.get("economy", {})
	if joining:
		econ["foreign_reserves"] = maxf(0.0, float(econ.get("foreign_reserves", 0.0)) - float(ORG_INFO[org]["cost"]) * 2.0)
		econ["org_dues"] = float(econ.get("org_dues", 0.0)) + float(ORG_INFO[org]["cost"])
	else:
		econ["org_dues"] = maxf(0.0, float(econ.get("org_dues", 0.0)) - float(ORG_INFO[org]["cost"]))
	state["economy"] = econ
	state["intl_orgs"] = intl
	return {"success": true, "state": state,
		"events": [{"type": "org_membership", "message": "🏛️ عضویت کشور در «%s» %s" % [org, "برقرار شد" if joining else "پایان یافت"]}]}

# ── قطعنامه: هر ۴-۷ نوبت یک رأی ──
func _generate_resolution(state: Dictionary, turn: int) -> Dictionary:
	var resolutions := [
		{"id": "sanction_pariah", "title": "تحریم‌های بین‌المللی علیه کشور متجاوز", "yes_effect": "نفوذ +۳، روابط با متحدان +",
		 "no_effect": "نفوذ −۲، ریسک انزوا"},
		{"id": "climate_pact", "title": "پیمان اقلیمی: سقف انتشار کربن", "yes_effect": "محبوبیت جهانی +۵، هزینه انرژی +",
		 "no_effect": "محبوبیت −۳، اقتصاد کربنی آزاد"},
		{"id": "humanitarian_aid", "title": "کمک بشردوستانه به کشور جنگ‌زده", "yes_effect": "محبوبیت +۴، هزینه ذخایر −",
		 "no_effect": "بدون هزینه ولی محبوبیت −۲"},
		{"id": "trade_corridor", "title": "کریدور تجاری منطقه‌ای جدید", "yes_effect": "تجارت +، درآمد گمرکی +",
		 "no_effect": "از دست دادن فرصت"},
	]
	return resolutions[Deterministic.next_int_range(0, resolutions.size() - 1)]

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var intl: Dictionary = state["intl_orgs"]
	var memberships: Dictionary = intl.get("memberships", {})
	var econ: Dictionary = state.get("economy", {})
	var leader: Dictionary = state.get("leader", {})
	var diplomacy: Dictionary = state.get("diplomacy", {})

	# هزینه عضویت سالانه (۱۲ نوبت)
	var dues := 0.0
	for org in ORGS:
		if bool(memberships.get(org, false)):
			dues += float(ORG_INFO[org]["cost"])
	econ["org_dues"] = dues / 12.0
	# منافع
	if bool(memberships.get("سازمان ملل", false)):
		diplomacy["influence"] = clampf(float(diplomacy.get("influence", 40.0)) + 0.3, 0.0, 100.0)
	if bool(memberships.get("اتحادیه منطقه‌ای", false)):
		econ["trade_exports_bonus"] = 0.003
		pol_stability_bump(state, 0.0005)
	if bool(memberships.get("اوپک", false)):
		var oil_income := float(econ.get("oil_income", 0.0))
		econ["oil_income"] = oil_income * 1.10

	# قطعنامه
	if int(intl.get("next_vote_turn", 0)) <= turn:
		intl["pending_vote"] = _generate_resolution(state, turn)
		intl["next_vote_turn"] = turn + Deterministic.next_int_range(4, 8)
		var pending: Dictionary = intl.get("pending_vote", {})
		events.append({"type": "org_vote", "message": "🗳️ قطعنامه مطرح شد: «%s» — تأیید یا وتو؟" % pending.get("title", "")})
	state["intl_orgs"] = intl
	state["economy"] = econ
	state["diplomacy"] = diplomacy
	state["leader"] = leader
	return {"state": state, "events": events}

func pol_stability_bump(state: Dictionary, amount: float):
	var pol: Dictionary = state.get("politics", {})
	pol["stability"] = clampf(float(pol.get("stability", 0.6)) + amount, 0.05, 1.0)
	state["politics"] = pol

# ── رأی به قطعنامه ──
func resolve_vote(state: Dictionary, decision: String, turn: int) -> Dictionary:
	state = ensure(state)
	var intl: Dictionary = state["intl_orgs"]
	var pending: Dictionary = intl.get("pending_vote", {})
	if pending.is_empty():
		return {"success": false, "reason": "قطعنامه‌ای در انتظار رأی نیست", "state": state, "events": []}
	if not ["yes", "no"].has(decision):
		return {"success": false, "reason": "رأی نامعتبر", "state": state, "events": []}
	var events: Array = []
	var leader: Dictionary = state.get("leader", {})
	var diplomacy: Dictionary = state.get("diplomacy", {})
	var econ: Dictionary = state.get("economy", {})
	if decision == "yes":
		match str(pending.get("id", "")):
			"sanction_pariah":
				diplomacy["influence"] = clampf(float(diplomacy.get("influence", 40.0)) + 3.0, 0.0, 100.0)
				leader["popularity_world"] = clampf(float(leader.get("popularity_world", 50.0)) + 2.0, 0.0, 100.0)
			"climate_pact":
				leader["popularity_world"] = clampf(float(leader.get("popularity_world", 50.0)) + 5.0, 0.0, 100.0)
				econ["energy_cost"] = float(econ.get("energy_cost", 1.0)) * 1.02
			"humanitarian_aid":
				econ["foreign_reserves"] = maxf(0.0, float(econ.get("foreign_reserves", 0.0)) - 1.0e9)
				leader["popularity_world"] = clampf(float(leader.get("popularity_world", 50.0)) + 4.0, 0.0, 100.0)
			"trade_corridor":
				# دسترسی پایدار به بازار (بازرسی کلید یتیم ۱۴۰۵): ضربهٔ یک‌بارهٔ سطح ×۱٫۰۳ در
				# مدل بازگشت‌به‌هدف محو می‌شد؛ حالا سهم هدف صادرات پایدار جابه‌جا می‌شود.
				var trade_d: Dictionary = state.get("trade", {})
				trade_d["market_access_bonus"] = clampf(float(trade_d.get("market_access_bonus", 0.0)) + 0.008, 0.0, 0.02)
				state["trade"] = trade_d
				diplomacy["influence"] = clampf(float(diplomacy.get("influence", 40.0)) + 2.0, 0.0, 100.0)
		events.append({"type": "org_vote_yes", "message": "🗳️ کشور به «%s» رأی مثبت داد" % pending.get("title", "")})
	else:
		match str(pending.get("id", "")):
			"sanction_pariah":
				diplomacy["influence"] = clampf(float(diplomacy.get("influence", 40.0)) - 2.0, 0.0, 100.0)
			"climate_pact":
				leader["popularity_world"] = clampf(float(leader.get("popularity_world", 50.0)) - 3.0, 0.0, 100.0)
			"humanitarian_aid":
				leader["popularity_world"] = clampf(float(leader.get("popularity_world", 50.0)) - 2.0, 0.0, 100.0)
			"trade_corridor":
				diplomacy["influence"] = clampf(float(diplomacy.get("influence", 40.0)) - 1.0, 0.0, 100.0)
		events.append({"type": "org_vote_no", "message": "🗳️ کشور به «%s» رأی منفی (وتو) داد" % pending.get("title", "")})
	# ثبت رأی
	var history: Array = intl.get("votes_history", [])
	history.append({"id": pending.get("id", ""), "decision": decision, "turn": turn})
	while history.size() > 30:
		history.pop_front()
	intl["votes_history"] = history
	intl["pending_vote"] = {}
	state["intl_orgs"] = intl
	state["leader"] = leader
	state["diplomacy"] = diplomacy
	state["economy"] = econ
	return {"success": true, "state": state, "events": events}
