extends Node
# ────────────────────────────────────────────────────────────────────────────
# اتحادیه‌های کارگری و سیاست دستمزد — عمق بازار کار
# قدرت اتحادیه‌ها، سیاست دستمزدی (آزاد/افزایش حداقل/کنترل دستمزد) و ریسک
# اعتصاب. اعتصاب‌ها به GDP و ثبات آسیب می‌زنند؛ مذاکره و سرکوب اهرم‌های بازیکن.
# اتحادیه‌ها با پوپولیست‌ها و رسانه پیوند دارند.
#
# state["labor"] = { "unions_power":0..1, "wage_policy":"free",
#   "strike_risk":0..1, "last_strike":0, "negotiated":0 }
# ────────────────────────────────────────────────────────────────────────────

func ensure(state: Dictionary) -> Dictionary:
	if not state.has("labor"):
		state["labor"] = {
			"unions_power": 0.4, "wage_policy": "free",
			"strike_risk": 0.2, "last_strike": 0, "negotiated": 0
		}
	return state

# ── شبیه‌سازی ماهانه ──
func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var lab: Dictionary = state["labor"]
	var econ: Dictionary = state.get("economy", {})
	var pop: Dictionary = state.get("population", {})
	var pol: Dictionary = state.get("politics", {})
	var factions: Dictionary = state.get("factions", {})
	var unemployment := float(econ.get("unemployment", 0.08))
	var inflation := float(econ.get("inflation", 0.08))
	var happiness := float(pop.get("happiness", 0.6))
	var unions_power := float(lab.get("unions_power", 0.4))
	var wage_policy := str(lab.get("wage_policy", "free"))
	var strike_risk := float(lab.get("strike_risk", 0.2))

	# قدرت اتحادیه‌ها: با پوپولیست‌ها و رسانه آزاد رشد می‌کند
	var populist_power := float(factions.get("پوپولیست‌ها", {}).get("power", 30.0)) / 100.0
	unions_power += (populist_power - 0.4) * 0.01
	unions_power += (float(pop.get("happiness", 0.6)) - 0.5) * 0.005
	lab["unions_power"] = clampf(unions_power, 0.05, 0.95)

	# ریسک اعتصاب: بیکاری + تورم + دستمزدهای راکد
	var risk := unemployment * 1.2 + inflation * 0.8 + (0.5 - happiness) * 0.5
	match wage_policy:
		"minimum_up":
			risk -= 0.08
		"wage_control":
			risk += 0.10
	risk += unions_power * 0.15
	# ممیزی GDP (۱۴۰۵): هزینهٔ فرصت حداقل دستمزد از کانال sector_boosts (بازنویسی ماهانه؛
	# با تعویض سیاست دستمزد خودبه‌خود صفر می‌شود)
	var lb_boosts: Dictionary = econ.get("sector_boosts", {})
	lb_boosts["هزینهٔ حداقل دستمزد"] = -0.0005 * 12.0 if wage_policy == "minimum_up" else 0.0
	econ["sector_boosts"] = lb_boosts
	# latch بازرسی ۱۴۰۵: last_strike از کلید نوشته‌بی‌خوان به مهار واقعی بدل شد —
	# خستگی پس از اعتصاب: تا ۶ نوبت پس از اعتصاب قبلی، ریسک اعتصاب تازه سقف ۰٫۴۵ دارد
	if turn - int(lab.get("last_strike", -99)) < 6:
		risk = minf(risk, 0.45)
	lab["strike_risk"] = clampf(risk, 0.05, 0.95)

	# اثر سیاست دستمزدی
	match wage_policy:
		"minimum_up":
			pop["happiness"] = clampf(happiness + 0.004, 0.05, 1.0)
			econ["inflation"] = clampf(float(econ.get("inflation", 0.08)) + 0.004, 0.0, 1.5)
		"wage_control":
			econ["inflation"] = clampf(float(econ.get("inflation", 0.08)) - 0.003, 0.0, 1.5)
			econ["foreign_investment"] = float(econ.get("foreign_investment", 1.0)) * 1.002
			pop["happiness"] = clampf(happiness - 0.003, 0.05, 1.0)

	# اعتصاب
	if float(lab["strike_risk"]) > 0.6 and Deterministic.chance(0.22):
		econ["gdp"] = float(econ.get("gdp", 1.0)) * 0.992
		pol["stability"] = clampf(float(pol.get("stability", 0.6)) - 0.03, 0.05, 1.0)
		lab["last_strike"] = turn
		lab["strike_risk"] = 0.2
		events.append({"type": "labor_strike", "message": "✊ اعتصاب سراسری کارگران! تولید و ثبات آسیب دید"})
	elif float(lab["strike_risk"]) > 0.45 and Deterministic.chance(0.08):
		# اثر هشداری ناآرامی: فشار اجتماعی پیش از اعتصاب
		pol["stability"] = clampf(float(pol.get("stability", 0.60)) - 0.008, 0.05, 1.0)
		pop["happiness"] = clampf(float(pop.get("happiness", 0.60)) - 0.005, 0.05, 1.0)
		events.append({"type": "labor_unrest", "message": "⚠️ ناآرامی کارگری در حال گسترش است؛ ریسک اعتصاب بالا"})

	state["labor"] = lab
	state["economy"] = econ
	state["population"] = pop
	state["politics"] = pol
	return {"state": state, "events": events}

# ── اقدامات بازیکن ──
func set_wage_policy(state: Dictionary, policy: String) -> Dictionary:
	state = ensure(state)
	if not ["free", "minimum_up", "wage_control"].has(policy):
		return {"success": false, "reason": "سیاست دستمزدی نامعتبر", "state": state, "events": []}
	var lab: Dictionary = state["labor"]
	lab["wage_policy"] = policy
	state["labor"] = lab
	var names := {"free": "آزاد", "minimum_up": "افزایش حداقل دستمزد", "wage_control": "کنترل دستمزد"}
	return {"success": true, "state": state,
		"events": [{"type": "wage_policy", "message": "💰 سیاست دستمزدی به «%s» تغییر کرد" % names[policy]}]}

func negotiate(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var capital := float(state.get("policies", {}).get("political_capital", 0.0))
	if capital < 1.0:
		return {"success": false, "reason": "سرمایه سیاسی کافی نیست (۱ واحد)", "state": state, "events": []}
	state["policies"]["political_capital"] = capital - 1.0
	var lab: Dictionary = state["labor"]
	lab["strike_risk"] = clampf(float(lab.get("strike_risk", 0.2)) - 0.15, 0.05, 0.95)
	lab["negotiated"] = int(lab.get("negotiated", 0)) + 1
	state["labor"] = lab
	state["population"]["happiness"] = clampf(float(state["population"].get("happiness", 0.6)) + 0.01, 0.05, 1.0)
	return {"success": true, "state": state,
		"events": [{"type": "labor_negotiation", "message": "🤝 مذاکره با اتحادیه‌ها موفق بود؛ ریسک اعتصاب کاهش یافت"}]}

func suppress(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var lab: Dictionary = state["labor"]
	lab["strike_risk"] = 0.1
	lab["unions_power"] = clampf(float(lab.get("unions_power", 0.4)) - 0.1, 0.05, 0.95)
	state["labor"] = lab
	state["politics"]["stability"] = clampf(float(state["politics"].get("stability", 0.6)) - 0.03, 0.05, 1.0)
	state["population"]["happiness"] = clampf(float(state["population"].get("happiness", 0.6)) - 0.015, 0.05, 1.0)
	return {"success": true, "state": state,
		"events": [{"type": "labor_suppression", "message": "🚨 سرکوب اعتصاب: اعتراض مهار شد ولی ناآرامی و نارضایتی ریشه‌دار ماند"}]}
