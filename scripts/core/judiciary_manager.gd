extends Node
# ────────────────────────────────────────────────────────────────────────────
# قوه قضائیه — عمق حاکمیت قانون
# استقلال قضایی، تراکم پرونده‌ها و پرونده‌های بزرگ (فساد، محیط زیست، رسانه،
# مالیات) که بازیکن باید به آن‌ها پاسخ دهد: حکم آزاد قضایی، فشار به دادگاه
# (کاهش استقلال) یا میانجیگری. استقلال بالا → فساد کمتر و اعتماد بیشتر؛
# تراکم پرونده → ناکارآمدی و بی‌اعتمادی.
#
# state["judiciary"] = { "independence":0..1, "backlog":0..1, "verdicts":0,
#   "pending_ruling": {..} | {} }
# ────────────────────────────────────────────────────────────────────────────

const RULINGS := [
	{"id": "corruption_trial", "title": "پرونده فساد مقام عالی‌رتبه", "desc": "دادگاه شواهد فساد یک مقام نزدیک به دولت را تأیید کرده است"},
	{"id": "environment_ruling", "title": "پرونده آلودگی صنعتی", "desc": "کارخانه بزرگ متهم به آلودگی رودخانه‌هاست و باید تعطیل یا جریمه شود"},
	{"id": "tax_dispute", "title": "دعوای مالیاتی غول صنعتی", "desc": "یک هلدینگ بزرگ از مالیات سنگین به دادگاه شکایت کرده"},
	{"id": "media_case", "title": "پرونده رسانه منتقد", "desc": "دادگاه در حال رسیدگی به شکایت دولت علیه یک رسانه مستقل است"}
]

func ensure(state: Dictionary) -> Dictionary:
	if not state.has("judiciary"):
		state["judiciary"] = {"independence": 0.55, "backlog": 0.4, "verdicts": 0, "pending_ruling": {}}
	return state

# ── شبیه‌سازی ماهانه ──
func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var jud: Dictionary = state["judiciary"]
	var pol: Dictionary = state.get("politics", {})
	var econ: Dictionary = state.get("economy", {})
	var media: Dictionary = state.get("media", {})
	var independence := float(jud.get("independence", 0.55))
	var backlog := float(jud.get("backlog", 0.4))

	# استقلال با فساد و فشار دولت تحلیل می‌رود؛ با آزادی رسانه بازمی‌گردد
	independence += (0.5 - float(pol.get("corruption", 0.3))) * 0.004
	independence -= float(jud.get("pressure_count", 0)) * 0.002
	independence += (float(media.get("trust", 0.55)) - 0.5) * 0.002
	independence += (0.55 - independence) * 0.005
	jud["independence"] = clampf(independence, 0.05, 1.0)

	# تراکم پرونده: با بودجه قوه قضائیه و کارآمدی
	var court_budget := float(econ.get("budget_allocations", {}).get("قضایی", 0.02))
	backlog += 0.02 - court_budget * 0.2
	jud["backlog"] = clampf(backlog, 0.05, 1.0)

	# اثر: استقلال → فساد، اعتماد، سرمایه‌گذاری
	pol["corruption"] = clampf(float(pol.get("corruption", 0.3)) + (0.5 - independence) * 0.004, 0.0, 1.0)
	pol["trust"] = clampf(float(pol.get("trust", 0.55)) + (independence - 0.5) * 0.006, 0.05, 1.0)
	econ["foreign_investment"] = float(econ.get("foreign_investment", 1.0)) * (1.0 + (independence - 0.5) * 0.002)
	# تراکم بالا → بی‌اعتمادی
	if backlog > 0.8:
		pol["trust"] = clampf(float(pol.get("trust", 0.55)) - 0.005, 0.05, 1.0)

	# پرونده بزرگ: هر ~۱۰ نوبت
	if jud.get("pending_ruling", {}).is_empty() and Deterministic.chance(0.08):
		var ruling: Dictionary = RULINGS[Deterministic.next_int_range(0, RULINGS.size() - 1)].duplicate(true)
		ruling["turn"] = turn
		jud["pending_ruling"] = ruling
		events.append({"type": "court_case", "message": "⚖️ «%s» در دادگاه مطرح شد — تصمیم بگیرید" % ruling["title"]})
	elif not jud.get("pending_ruling", {}).is_empty():
		var ruling: Dictionary = jud["pending_ruling"]
		if turn - int(ruling.get("turn", turn)) >= 3:
			jud["pending_ruling"] = {}
			events.append({"type": "court_case_dropped", "message": "پرونده «%s» بدون حکم به بایگانی رفت؛ بی‌اعتمادی به دستگاه قضایی بالا گرفت" % ruling.get("title", "")})
			pol["trust"] = clampf(float(pol.get("trust", 0.55)) - 0.03, 0.05, 1.0)
	state["judiciary"] = jud
	state["politics"] = pol
	state["economy"] = econ
	return {"state": state, "events": events}

# ── اقدامات بازیکن ──
func fund_courts(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var jud: Dictionary = state["judiciary"]
	jud["backlog"] = clampf(float(jud.get("backlog", 0.4)) - 0.15, 0.05, 1.0)
	jud["verdicts"] = int(jud.get("verdicts", 0)) + 1
	state["judiciary"] = jud
	var econ: Dictionary = state.get("economy", {})
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * 0.002
	state["economy"] = econ
	return {"success": true, "state": state,
		"events": [{"type": "court_funding", "message": "⚖️ بودجه قوه قضائیه افزایش یافت؛ تراکم پرونده‌ها کاهش یافت"}]}

func press_court(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var jud: Dictionary = state["judiciary"]
	jud["independence"] = clampf(float(jud.get("independence", 0.55)) - 0.12, 0.05, 1.0)
	jud["pressure_count"] = int(jud.get("pressure_count", 0)) + 1
	state["judiciary"] = jud
	var pol: Dictionary = state.get("politics", {})
	pol["trust"] = clampf(float(pol.get("trust", 0.55)) - 0.03, 0.05, 1.0)
	state["politics"] = pol
	return {"success": true, "state": state,
		"events": [{"type": "court_pressure", "message": "⚖️ دولت به دادگاه فشار آورد؛ استقلال قضایی آسیب دید اما پرونده بسته شد"}]}

func judicial_reform(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var capital := float(state.get("policies", {}).get("political_capital", 0.0))
	if capital < 2.0:
		return {"success": false, "reason": "سرمایه سیاسی کافی نیست (۲ واحد)", "state": state, "events": []}
	state["policies"]["political_capital"] = capital - 2.0
	var jud: Dictionary = state["judiciary"]
	jud["independence"] = clampf(float(jud.get("independence", 0.55)) + 0.15, 0.05, 1.0)
	state["judiciary"] = jud
	var pol: Dictionary = state.get("politics", {})
	pol["trust"] = clampf(float(pol.get("trust", 0.55)) + 0.05, 0.05, 1.0)
	state["politics"] = pol
	return {"success": true, "state": state,
		"events": [{"type": "judicial_reform", "message": "⚖️ اصلاحات قضایی! استقلال دادگاه‌ها تقویت و اعتماد عمومی بازگشت"}]}

func respond_ruling(state: Dictionary, decision: String) -> Dictionary:
	state = ensure(state)
	var jud: Dictionary = state["judiciary"]
	var ruling: Dictionary = jud.get("pending_ruling", {})
	if ruling.is_empty():
		return {"success": false, "reason": "پرونده‌ای در انتظار حکم نیست", "state": state, "events": []}
	if not ["free", "pressure", "mediate"].has(decision):
		return {"success": false, "reason": "تصمیم نامعتبر", "state": state, "events": []}
	var events: Array = []
	var pol: Dictionary = state.get("politics", {})
	var econ: Dictionary = state.get("economy", {})
	var rid := str(ruling.get("id", ""))
	match decision:
		"free":
			jud["independence"] = clampf(float(jud.get("independence", 0.55)) + 0.05, 0.05, 1.0)
			pol["trust"] = clampf(float(pol.get("trust", 0.55)) + 0.03, 0.05, 1.0)
			# پیامد پرونده
			match rid:
				"corruption_trial":
					pol["corruption"] = clampf(float(pol.get("corruption", 0.3)) - 0.04, 0.0, 1.0)
					events.append({"type": "ruling_corruption", "message": "⚖️ محکومیت فساد: مفسد زندانی شد و فساد کاهش یافت"})
				"environment_ruling":
					econ["gdp"] = float(econ.get("gdp", 1.0)) * 0.998
					events.append({"type": "ruling_environment", "message": "⚖️ کارخانه آلاینده تعطیل شد؛ محیط زیست پاک‌تر ولی تولید کمتر"})
				"tax_dispute":
					econ["tax_revenue_loss"] = 0.0
					events.append({"type": "ruling_tax", "message": "⚖️ حکم به نفع دولت؛ مالیات غول صنعتی وصول شد"})
				"media_case":
					events.append({"type": "ruling_media", "message": "⚖️ دادگاه به نفع رسانه مستقل حکم داد؛ آزادی بیان تقویت شد"})
		"pressure":
			jud["independence"] = clampf(float(jud.get("independence", 0.55)) - 0.10, 0.05, 1.0)
			pol["trust"] = clampf(float(pol.get("trust", 0.55)) - 0.03, 0.05, 1.0)
			match rid:
				"corruption_trial":
					pol["corruption"] = clampf(float(pol.get("corruption", 0.3)) + 0.02, 0.0, 1.0)
					events.append({"type": "ruling_pressure_corruption", "message": "⚖️ پرونده فساد با فشار دولت بسته شد؛ فساد ریشه دواند"})
				"environment_ruling":
					events.append({"type": "ruling_pressure_env", "message": "⚖️ کارخانه با فشار دولت جریمه سبکی گرفت؛ تولید حفظ شد"})
				"media_case":
					events.append({"type": "ruling_pressure_media", "message": "⚖️ دادگاه به نفع دولت رأی داد؛ رسانه منتقد بسته شد"})
		"mediate":
			pol["trust"] = clampf(float(pol.get("trust", 0.55)) + 0.01, 0.05, 1.0)
			events.append({"type": "ruling_mediate", "message": "🤝 میانجیگری دولتی: پرونده با توافق طرفین بسته شد"})
	jud["verdicts"] = int(jud.get("verdicts", 0)) + 1
	jud["pending_ruling"] = {}
	state["judiciary"] = jud
	state["politics"] = pol
	state["economy"] = econ
	return {"success": true, "state": state, "events": events}
