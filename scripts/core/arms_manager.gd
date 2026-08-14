extends Node
# ────────────────────────────────────────────────────────────────────────────
# صنایع دفاعی و صادرات تسلیحات — عمق اقتصاد نظامی
# ظرفیت صنایع دفاعی با سرمایه‌گذاری ساخته می‌شود؛ هر ماه تجهیزات تولید و در
# انبار جمع می‌شود. بازیکن تسلیحات را به کشورهای دوست/درگیر می‌فروشد (ذخایر
# ارزی + نفوذ) یا به ارتش خود منتقل می‌کند. تحریم تسلیحاتی رویداد شانسی است
# و تنش جهانی تقاضا را بالا می‌برد.
#
# state["arms"] = { "capacity":0..100, "stock":0..1000, "embargo":false,
#   "exports":0, "history":[] }
# ────────────────────────────────────────────────────────────────────────────

func ensure(state: Dictionary) -> Dictionary:
	if not state.has("arms_industry"):
		state["arms_industry"] = {"capacity": 20.0, "stock": 50.0, "embargo": false, "exports": 0, "history": []}
	return state

# ── شبیه‌سازی ماهانه ──
func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var arms: Dictionary = state["arms_industry"]
	var econ: Dictionary = state.get("economy", {})
	var tech: Dictionary = state.get("technology", {})
	var riv: Dictionary = state.get("rivalry", {})
	var capacity := float(arms.get("capacity", 20.0))
	var stock := float(arms.get("stock", 50.0))
	var embargo := bool(arms.get("embargo", false))

	# تولید: ظرفیت × فناوری صنعت × مسابقه تسلیحاتی
	var industry_level := float(tech.get("branch_levels", {}).get("صنعت", 0))
	var arms_race := float(riv.get("arms_race", 0.3))
	var production := capacity * (0.5 + industry_level * 0.02) * (1.0 + arms_race * 0.5)
	stock += production
	arms["stock"] = stock

	# هزینه نگهداری ظرفیت (بازرسی ۱۴۰۵ — دور هشتم): هزینهٔ مداوم ماهانه به کانال
	# policy_costs می‌رود تا در بودجه/کسری دیده شود، نه شارژ خاموش بدهی.
	econ["defense_industry_cost"] = capacity * 0.0001
	var ar_costs: Dictionary = econ.get("policy_costs", {})
	ar_costs["نگهداری صنایع دفاعی"] = float(econ.get("gdp", 1.0)) * capacity * 0.00002
	econ["policy_costs"] = ar_costs

	# تحریم تسلیحاتی: تنش بالا یا روابط بد با غرب
	if not embargo and Deterministic.chance(0.012):
		arms["embargo"] = true
		events.append({"type": "arms_embargo", "message": "🚫 تحریم تسلیحاتی! واردات قطعات حیاتی قطع شد و تولید ۳۰٪ کاهش می‌یابد"})
	elif embargo and Deterministic.chance(0.06):
		arms["embargo"] = false
		events.append({"type": "arms_embargo_lifted", "message": "✅ تحریم تسلیحاتی لغو شد"})
	if embargo:
		production *= 0.7
		arms["stock"] = float(arms.get("stock", 50.0)) - production * 0.3

	# تقاضای جهانی: جنگ‌های NPC و تنش
	var demand := float(state.get("world", {}).get("npc_wars", {}).size()) * 0.5 + arms_race * 0.5
	arms["demand"] = demand

	# تاریخچه
	var history: Array = arms.get("history", [])
	history.append({"turn": turn, "stock": stock, "capacity": capacity})
	while history.size() > 40:
		history.pop_front()
	arms["history"] = history
	state["arms_industry"] = arms
	state["economy"] = econ
	return {"state": state, "events": events}

# ── اقدامات بازیکن ──
func invest_capacity(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var arms: Dictionary = state["arms_industry"]
	if float(arms.get("capacity", 20.0)) >= 100.0:
		return {"success": false, "reason": "ظرفیت صنایع دفاعی حداکثری است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * 0.004
	state["economy"] = econ
	arms["capacity"] = clampf(float(arms.get("capacity", 20.0)) + 15.0, 0.0, 100.0)
	state["arms_industry"] = arms
	return {"success": true, "state": state,
		"events": [{"type": "arms_capacity", "message": "🏭 خط تولید جدید در صنایع دفاعی افتتاح شد؛ تولید ماهانه بالا رفت"}]}

func sell_weapons(state: Dictionary, buyer: String, amount: float) -> Dictionary:
	state = ensure(state)
	var arms: Dictionary = state["arms_industry"]
	var stock := float(arms.get("stock", 50.0))
	if amount <= 0.0 or amount > stock:
		return {"success": false, "reason": "انبار کافی نیست", "state": state, "events": []}
	if not WorldManager.countries.has(buyer):
		return {"success": false, "reason": "خریدار نامعتبر", "state": state, "events": []}
	if bool(arms.get("embargo", false)):
		return {"success": false, "reason": "تحریم تسلیحاتی مانع فروش است", "state": state, "events": []}
	var relations: Dictionary = state.get("diplomacy", {}).get("relations", {})
	var rel := float(relations.get(buyer, 50.0))
	var at_war: bool = state.get("world", {}).get("wars", {}).has(buyer)
	if rel < 30.0 and not at_war:
		return {"success": false, "reason": "رابطه کافی برای قرارداد تسلیحاتی نیست", "state": state, "events": []}
	# قیمت: واحد × قیمت پایه × تقاضا
	var demand := float(arms.get("demand", 0.5))
	var price := amount * 0.5e9 * (0.8 + demand * 0.6)
	arms["stock"] = stock - amount
	arms["exports"] = int(arms.get("exports", 0)) + 1
	state["arms_industry"] = arms
	var econ: Dictionary = state.get("economy", {})
	econ["foreign_reserves"] = float(econ.get("foreign_reserves", 0.0)) + price
	state["economy"] = econ
	# نفوذ + و رابطه با خریدار +
	state["diplomacy"]["influence"] = clampf(float(state["diplomacy"].get("influence", 40.0)) + 1.0, 0.0, 100.0)
	if relations.has(buyer):
		relations[buyer] = clampf(rel + 3.0, 0.0, 100.0)
		state["diplomacy"]["relations"] = relations
	# فروش به کشور درگیر، تنش را بالا می‌برد
	if at_war:
		state["rivalry"]["tension"] = clampf(float(state.get("rivalry", {}).get("tension", 40.0)) + 2.0, 0.0, 100.0)
	return {"success": true, "state": state,
		"events": [{"type": "arms_sale", "message": "🔫 قرارداد تسلیحاتی با %s: %s واحد تجهیزات به ارزش %s" % [
			WorldManager.get_country_name(buyer), PersianFormatter.to_persian_digits(str(int(amount))), PersianFormatter.format_money(price)]}]}

func transfer_to_army(state: Dictionary, amount: float) -> Dictionary:
	state = ensure(state)
	var arms: Dictionary = state["arms_industry"]
	var stock := float(arms.get("stock", 50.0))
	if amount <= 0.0 or amount > stock:
		return {"success": false, "reason": "انبار کافی نیست", "state": state, "events": []}
	arms["stock"] = stock - amount
	state["arms_industry"] = arms
	state["military"]["power"] = float(state["military"].get("power", 50.0)) * (1.0 + amount / 500.0)
	state["military"]["readiness"] = clampf(float(state["military"].get("readiness", 0.6)) + amount / 2000.0, 0.1, 1.0)
	return {"success": true, "state": state,
		"events": [{"type": "arms_transfer", "message": "🪖 %s واحد تجهیزات به ارتش منتقل شد؛ قدرت رزمی و آمادگی بالا رفت" % PersianFormatter.to_persian_digits(str(int(amount)))}]}
