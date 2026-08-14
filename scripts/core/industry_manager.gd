extends Node
# ────────────────────────────────────────────────────────────────────────────
# سیاست صنعتی — عمق اقتصاد تولید
# راهبرد صنعتی (متنوع/فناوری‌محور/سنگین/صادرات‌محور)، سهم شرکت‌های دولتی،
# مناطق آزاد و «صنعت برگزیده». خصوصی‌سازی کارآمدی می‌آورد ولی ناآرامی کارگری
# و واکنش جناح‌ها؛ ملی‌سازی اشتغال و ثبات می‌آورد ولی فساد و ناکارآمدی.
#
# state["industry_policy"] = { "strategy":"diversified", "soe_share":0..1,
#   "free_zones":0..1, "winner":"", "privatized":0, "nationalized":0 }
# ────────────────────────────────────────────────────────────────────────────

const STRATEGIES := {
	"diversified": {"name_fa": "متنوع", "growth": 0.002, "employment": 0.001, "export": 0.0},
	"high_tech": {"name_fa": "فناوری‌محور", "growth": 0.004, "employment": 0.000, "export": 0.002, "requires_tech": true},
	"heavy": {"name_fa": "سنگین", "growth": 0.002, "employment": 0.002, "export": 0.0, "requires_energy": true},
	"export": {"name_fa": "صادرات‌محور", "growth": 0.003, "employment": 0.001, "export": 0.003}
}
const WINNERS := [
	{"id": "electronics", "name_fa": "الکترونیک"},
	{"id": "automotive", "name_fa": "خودروسازی"},
	{"id": "petrochemicals", "name_fa": "پتروشیمی"},
	{"id": "pharma", "name_fa": "داروسازی"}
]

func ensure(state: Dictionary) -> Dictionary:
	if not state.has("industry_policy"):
		state["industry_policy"] = {
			"strategy": "diversified", "soe_share": 0.3, "free_zones": 0.0,
			"winner": "", "privatized": 0, "nationalized": 0
		}
	return state

# ── شبیه‌سازی ماهانه ──
func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var ind: Dictionary = state["industry_policy"]
	var econ: Dictionary = state.get("economy", {})
	var pol: Dictionary = state.get("politics", {})
	var tech: Dictionary = state.get("technology", {})
	var strategy := str(ind.get("strategy", "diversified"))
	var soe := float(ind.get("soe_share", 0.3))
	var free_zones := float(ind.get("free_zones", 0.0))
	var info: Dictionary = STRATEGIES.get(strategy, STRATEGIES["diversified"])

	# الزامات راهبرد
	if strategy == "high_tech" and float(tech.get("branches", {}).get("صنعت", 0.2)) < 0.35:
		info = STRATEGIES["diversified"]
	if strategy == "heavy" and float(econ.get("energy_cost", 1.0)) > 1.3:
		info = STRATEGIES["diversified"]

	# اثر راهبرد
	econ["industrial_growth_bonus"] = float(info.get("growth", 0.0))
	# بازرسی تراز پرداخت‌ها: اهرم صادراتی به مخزن واقعی trade وصل شد (econ.exports خواننده نداشت)
	var trade_d: Dictionary = state.get("trade", {})
	trade_d["exports"] = float(trade_d.get("exports", 80.0e9)) * (1.0 + float(info.get("export", 0.0)))
	state["trade"] = trade_d
	# شرکت‌های دولتی: اشتغال و ثبات ولی ناکارآمدی و فساد
	econ["soe_employment"] = soe * 0.1
	econ["gdp"] = float(econ.get("gdp", 1.0)) * (1.0 - soe * 0.001)
	pol["corruption"] = clampf(float(pol.get("corruption", 0.3)) + soe * 0.001, 0.0, 1.0)
	# مناطق آزاد: سرمایه‌گذاری خارجی
	econ["foreign_investment"] = float(econ.get("foreign_investment", 1.0)) * (1.0 + free_zones * 0.004)
	# صنعت برگزیده: اگر راهبرد با آن هم‌خوان باشد رشد می‌کند
	var winner := str(ind.get("winner", ""))
	if winner != "":
		var winner_bonus := 0.0015
		if (strategy == "high_tech" and winner in ["electronics", "pharma"]) or (strategy == "heavy" and winner in ["automotive", "petrochemicals"]):
			winner_bonus = 0.003
		econ["gdp"] = float(econ.get("gdp", 1.0)) * (1.0 + winner_bonus)
	state["economy"] = econ
	state["politics"] = pol
	state["industry_policy"] = ind
	return {"state": state, "events": events}

# ── اقدامات بازیکن ──
func set_strategy(state: Dictionary, strategy: String) -> Dictionary:
	state = ensure(state)
	if not STRATEGIES.has(strategy):
		return {"success": false, "reason": "راهبرد نامعتبر", "state": state, "events": []}
	var ind: Dictionary = state["industry_policy"]
	ind["strategy"] = strategy
	state["industry_policy"] = ind
	return {"success": true, "state": state,
		"events": [{"type": "industrial_strategy", "message": "🏭 راهبرد صنعتی به «%s» تغییر کرد" % STRATEGIES[strategy]["name_fa"]}]}

func pick_winner(state: Dictionary, winner_id: String) -> Dictionary:
	state = ensure(state)
	var found := false
	for w in WINNERS:
		if str(w["id"]) == winner_id:
			found = true
			break
	if not found:
		return {"success": false, "reason": "صنعت نامعتبر", "state": state, "events": []}
	var ind: Dictionary = state["industry_policy"]
	ind["winner"] = winner_id
	state["industry_policy"] = ind
	return {"success": true, "state": state,
		"events": [{"type": "pick_winner", "message": "🎯 «%s» به عنوان صنعت برگزیده ملی انتخاب شد" % _winner_name(winner_id)}]}

func _winner_name(winner_id: String) -> String:
	for w in WINNERS:
		if str(w["id"]) == winner_id:
			return str(w["name_fa"])
	return winner_id

func privatize(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var ind: Dictionary = state["industry_policy"]
	var soe := float(ind.get("soe_share", 0.3))
	if soe < 0.1:
		return {"success": false, "reason": "شرکت دولتی قابل توجهی باقی نمانده", "state": state, "events": []}
	ind["soe_share"] = clampf(soe - 0.12, 0.0, 1.0)
	ind["privatized"] = int(ind.get("privatized", 0)) + 1
	state["industry_policy"] = ind
	var econ: Dictionary = state.get("economy", {})
	econ["foreign_reserves"] = float(econ.get("foreign_reserves", 0.0)) + float(econ.get("gdp", 1.0)) * 0.003
	state["economy"] = econ
	# واکنش‌ها: کارگران (از طریق سیستم کار) و نخبگان
	var factions: Dictionary = state.get("factions", {})
	if factions.has("نخبگان اقتصادی"):
		var f: Dictionary = factions["نخبگان اقتصادی"]
		f["loyalty"] = clampf(float(f.get("loyalty", 50.0)) + 3.0, 0.0, 100.0)
		factions["نخبگان اقتصادی"] = f
		state["factions"] = factions
	state["labor"] = state.get("labor", {})
	return {"success": true, "state": state,
		"events": [{"type": "privatization", "message": "🏭 خصوصی‌سازی: شرکت‌های دولتی واگذار شدند؛ کارآمدی و درآمد بالا رفت ولی کارگران نگران‌اند"}]}

func nationalize(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var ind: Dictionary = state["industry_policy"]
	var soe := float(ind.get("soe_share", 0.3))
	if soe > 0.85:
		return {"success": false, "reason": "اقتصاد تقریباً کاملاً دولتی است", "state": state, "events": []}
	ind["soe_share"] = clampf(soe + 0.12, 0.0, 1.0)
	ind["nationalized"] = int(ind.get("nationalized", 0)) + 1
	state["industry_policy"] = ind
	var factions: Dictionary = state.get("factions", {})
	if factions.has("نخبگان اقتصادی"):
		var f: Dictionary = factions["نخبگان اقتصادی"]
		f["loyalty"] = clampf(float(f.get("loyalty", 50.0)) - 5.0, 0.0, 100.0)
		factions["نخبگان اقتصادی"] = f
		state["factions"] = factions
	state["politics"]["stability"] = clampf(float(state["politics"].get("stability", 0.6)) + 0.01, 0.05, 1.0)
	return {"success": true, "state": state,
		"events": [{"type": "nationalization", "message": "🏭 ملی‌سازی: صنایع کلیدی دولتی شدند؛ اشتغال و کنترل دولت بالا رفت ولی نخبگان ناخرسندند"}]}

func create_free_zone(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var ind: Dictionary = state["industry_policy"]
	var free_zones := float(ind.get("free_zones", 0.0))
	if free_zones > 0.8:
		return {"success": false, "reason": "ظرفیت مناطق آزاد تکمیل است", "state": state, "events": []}
	ind["free_zones"] = clampf(free_zones + 0.2, 0.0, 1.0)
	state["industry_policy"] = ind
	var econ: Dictionary = state.get("economy", {})
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * 0.002
	state["economy"] = econ
	return {"success": true, "state": state,
		"events": [{"type": "free_zone", "message": "🏙️ منطقه آزاد تجاری جدید افتتاح شد؛ سرمایه‌گذاری خارجی جذب می‌شود"}]}
