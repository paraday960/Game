extends Node
# ────────────────────────────────────────────────────────────────────────────
# مشارکت مدنی و اعتماد اجتماعی — عمق سرمایه اجتماعی
# جامعه مدنی (سمن‌ها، شوراهای محلی، شفافیت داده، بودجه‌ریزی مشارکتی، دیده‌بان
# فساد) را شبیه‌سازی می‌کند. مشارکت بالا اعتماد و کارآمدی می‌سازد و بحران را
# نرم می‌کند؛ سرکوب آن در کوتاه‌مدت کنترل می‌دهد اما خشم و بی‌اعتمادی پنهان می‌کارد.
# پیوند: سیاست، امنیت، رسانه، فرهنگ، رفاه، فساد و ثبات.
#
# state["civic_policy"] = { "transparency":0..1, "local_councils":0..1,
#   "participatory_budget":0..1, "ngo_space":0..1, "watchdog":0..1,
#   "last_assembly":turn, "social_capital":0..1, "protests_under":0 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("civic_policy"):
		state["civic_policy"] = {
			"transparency": 0.45, "local_councils": 0.35,
			"participatory_budget": 0.20, "ngo_space": 0.40,
			"watchdog": 0.25, "last_assembly": -99,
			"social_capital": 0.50, "protests_under": 0
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var cp: Dictionary = state["civic_policy"]
	var pol: Dictionary = state.get("politics", {})
	var media: Dictionary = state.get("media", {})
	var welfare: Dictionary = state.get("welfare", {})
	var econ: Dictionary = state.get("economy", {})
	var pop: Dictionary = state.get("population", {})
	var security: Dictionary = state.get("security", {})

	var transparency := float(cp.get("transparency", 0.45))
	var councils := float(cp.get("local_councils", 0.35))
	var participatory := float(cp.get("participatory_budget", 0.20))
	var ngo := float(cp.get("ngo_space", 0.40))
	var watchdog := float(cp.get("watchdog", 0.25))
	var trust := float(pol.get("trust", 0.55))
	var censorship := 1.0 - float(media.get("freedom", 0.5))
	var pressure := clampf((1.0 - trust) * 0.6 + float(econ.get("unemployment", 0.08)) * 1.2 + censorship * 0.25 - ngo - councils, 0.0, 2.0)

	# سرمایه اجتماعی با شفافیت، شوراها و سمن‌ها بالا می‌رود و با فساد/فقر می‌افتد
	var social_capital := clampf(
		0.25 + transparency * 0.18 + councils * 0.20 + ngo * 0.18 +
		participatory * 0.12 + watchdog * 0.10 - float(pol.get("corruption", 0.3)) * 0.25 -
		float(welfare.get("poverty", 0.15)) * 0.20,
		0.05, 0.98)
	cp["social_capital"] = social_capital

	# اعتماد و ثبات: سرمایه اجتماعی شوک‌ها را جذب می‌کند
	pol["trust"] = clampf(trust + (social_capital - 0.5) * 0.004, 0.05, 1.0)
	pol["stability"] = clampf(float(pol.get("stability", 0.60)) + social_capital * 0.002 - maxf(0.0, pressure - 1.1) * 0.004, 0.05, 1.0)
	pol["corruption"] = clampf(float(pol.get("corruption", 0.30)) - watchdog * 0.002 - transparency * 0.001, 0.02, 1.0)
	state["politics"] = pol

	# شفافیت داده و شوراها کارایی اداری و امنیت اجتماعی را بالا می‌برند
	state["administration"]["efficiency"] = clampf(float(state["administration"].get("efficiency", 0.60)) + (councils + transparency) * 0.001, 0.1, 0.98)
	security["public_security"] = clampf(float(security.get("public_security", 0.70)) + social_capital * 0.001 - pressure * 0.001, 0.1, 1.0)
	state["security"] = security
	media["trust"] = clampf(float(media.get("trust", 0.55)) + transparency * 0.002 - watchdog * 0.001, 0.05, 1.0)
	state["media"] = media

	# اگر جامعه مدنی سرکوب شده اما فشار بالاست، اعتراض زیرزمینی انباشته می‌شود
	if ngo < 0.25 and pressure > 0.9:
		cp["protests_under"] = clampi(int(cp.get("protests_under", 0)) + 1, 0, 24)
	else:
		cp["protests_under"] = maxi(0, int(cp.get("protests_under", 0)) - 1)

	# بودجه‌ریزی مشارکتی هزینه دارد ولی رضایت و بهره‌وری محلی را بالا می‌برد
	var gdp := float(econ.get("gdp", 1.0))
	econ["government_spending"] = float(econ.get("government_spending", 0.0)) + gdp * 0.0006 * (participatory + councils)
	econ["gdp"] = gdp * (1.0 + social_capital * 0.0003 - pressure * 0.0002)
	pop["happiness"] = clampf(float(pop.get("happiness", 0.60)) + (participatory + councils - 0.5) * 0.001, 0.05, 1.0)
	state["economy"] = econ
	state["population"] = pop

	# رویدادها
	if int(cp.get("protests_under", 0)) >= 12 and Deterministic.chance(0.08):
		pol["stability"] = clampf(float(pol.get("stability", 0.60)) - 0.020, 0.05, 1.0)
		pop["happiness"] = clampf(float(pop.get("happiness", 0.60)) - 0.010, 0.05, 1.0)
		cp["protests_under"] = 0
		state["politics"] = pol
		state["population"] = pop
		events.append({"type": "civic_unrest", "message": "📣 اعتراض‌های مدنی فروخورده به خیابان سرریز شد؛ بستن فضای مدنی بحران را عمیق‌تر کرده بود"})
	elif social_capital > 0.75 and Deterministic.chance(0.035):
		events.append({"type": "social_cohesion", "message": "🤝 سرمایه اجتماعی بالا؛ شوراها و سمن‌ها در بحران کنار دولت و مردم ایستادند"})
	elif transparency > 0.75 and watchdog > 0.60 and Deterministic.chance(0.025):
		pol["corruption"] = clampf(float(pol.get("corruption", 0.30)) - 0.006, 0.02, 1.0)
		state["politics"] = pol
		events.append({"type": "civic_watchdog", "message": "🕵️ دیده‌بان مدنی فساد بزرگی را افشا کرد؛ شفافیت اجتماعی اعتماد را بازگرداند"})

	state["civic_policy"] = cp
	return {"state": state, "events": events}

# ── قانون دسترسی آزاد به اطلاعات/داده باز ──
func open_data(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var cp: Dictionary = state["civic_policy"]
	if float(cp.get("transparency", 0.45)) >= 0.95:
		return {"success": false, "reason": "شفافیت داده‌ها در حداکثر ممکن است", "state": state, "events": []}
	cp["transparency"] = clampf(float(cp.get("transparency", 0.45)) + 0.15, 0.0, 1.0)
	cp["watchdog"] = clampf(float(cp.get("watchdog", 0.25)) + 0.04, 0.0, 1.0)
	state["politics"]["corruption"] = clampf(float(state["politics"].get("corruption", 0.30)) - 0.012, 0.02, 1.0)
	state["civic_policy"] = cp
	return {"success": true, "state": state,
		"events": [{"type": "open_data", "message": "📂 داده‌های دولتی باز شد؛ روزنامه‌نگاران، پژوهشگران و سمن‌ها به اطلاعات رسمی دسترسی یافتند"}]}

# ── تقویت شوراهای محلی ──
func empower_councils(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var cp: Dictionary = state["civic_policy"]
	if float(cp.get("local_councils", 0.35)) >= 0.95:
		return {"success": false, "reason": "اختیارات شوراهای محلی در سقف ممکن است", "state": state, "events": []}
	cp["local_councils"] = clampf(float(cp.get("local_councils", 0.35)) + 0.15, 0.0, 1.0)
	state["administration"]["decentralization"] = clampf(float(state["administration"].get("decentralization", 0.40)) + 0.02, 0.05, 0.95)
	state["politics"]["trust"] = clampf(float(state["politics"].get("trust", 0.55)) + 0.012, 0.05, 1.0)
	state["civic_policy"] = cp
	return {"success": true, "state": state,
		"events": [{"type": "local_councils", "message": "🏘️ شوراهای محلی قدرت گرفتند؛ پروژه‌های شهر و روستا با رای مردم اولویت‌بندی شد"}]}

# ── بودجه‌ریزی مشارکتی ──
func participatory_budget(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var cp: Dictionary = state["civic_policy"]
	if turn - int(cp.get("last_assembly", -99)) < 5:
		return {"success": false, "reason": "مجمع بودجه مشارکتی هر ۵ نوبت یک بار ممکن است", "state": state, "events": []}
	if float(cp.get("participatory_budget", 0.20)) >= 0.90:
		return {"success": false, "reason": "بودجه‌ریزی مشارکتی در سقف ممکن است", "state": state, "events": []}
	cp["participatory_budget"] = clampf(float(cp.get("participatory_budget", 0.20)) + 0.15, 0.0, 1.0)
	cp["last_assembly"] = turn
	state["population"]["happiness"] = clampf(float(state["population"].get("happiness", 0.60)) + 0.006, 0.05, 1.0)
	state["welfare"]["poverty"] = clampf(float(state["welfare"].get("poverty", 0.15)) - 0.004, 0.02, 0.80)
	state["civic_policy"] = cp
	return {"success": true, "state": state,
		"events": [{"type": "participatory_budget", "message": "🗳️ مجمع شهروندی برای بودجه‌ریزی برگزار شد؛ محروم‌ترین محله‌ها صاحب پروژه شدند"}]}

# ── تقویت امنیت فضای سمن‌ها ──
func protect_ngos(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var cp: Dictionary = state["civic_policy"]
	if float(cp.get("ngo_space", 0.40)) >= 0.95:
		return {"success": false, "reason": "امنیت فضای سازمان‌های مردم‌نهاد در سقف است", "state": state, "events": []}
	cp["ngo_space"] = clampf(float(cp.get("ngo_space", 0.40)) + 0.15, 0.0, 1.0)
	cp["protests_under"] = maxi(0, int(cp.get("protests_under", 0)) - 2)
	state["politics"]["stability"] = clampf(float(state["politics"].get("stability", 0.60)) + 0.006, 0.05, 1.0)
	state["media"]["trust"] = clampf(float(state["media"].get("trust", 0.55)) + 0.010, 0.05, 1.0)
	state["civic_policy"] = cp
	return {"success": true, "state": state,
		"events": [{"type": "ngo_protection", "message": "🕊️ فعالیت سازمان‌های مردم‌نهاد تضمین شد؛ اعتراض مدنی مسالمت‌آمیز به مسیر گفت‌وگو منتقل شد"}]}
