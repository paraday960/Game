extends Node
# ────────────────────────────────────────────────────────────────────────────
# اقتصاد مراقبت و سالمندی (Care Economy) — عمق کار بی‌مزد
# نگهداری از سالمندان، کودکان و افراد وابسته عمدتاً کار بی‌مزد زنان است.
# مراکز نگهداری روزانه، مراقبت در منزل، مهاجرت پرستار و مرخصی زایمان
# مشارکت نیروی کار (به‌ویژه زنان) و باروری را بالا می‌برد.
# پیوند: جمعیت، رفاه، بهداشت، خانواده، زنان.
#
# state["care_policy"] = {
#   "eldercare":0..1, "childcare":0..1, "home_care":0..1,
#   "paid_leave":0..1, "care_workers":0..1,
#   "last_program":turn, "female_lfp":0..1, "care_burden":0..1 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("care_policy"):
		state["care_policy"] = {
			"eldercare": 0.25, "childcare": 0.25, "home_care": 0.20,
			"paid_leave": 0.30, "care_workers": 0.25,
			"last_program": -99, "female_lfp": 0.35, "care_burden": 0.55,
			"informal_care": 0.70, "labor_force_gain": 0.0
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var cp: Dictionary = state["care_policy"]
	var pop: Dictionary = state.get("population", {})
	var welfare: Dictionary = state.get("welfare", {})
	var econ: Dictionary = state.get("economy", {})
	var health: Dictionary = state.get("health", {})
	var edu: Dictionary = state.get("education", {})

	var elder: float = float(cp.get("eldercare", 0.25))
	var child: float = float(cp.get("childcare", 0.25))
	var home: float = float(cp.get("home_care", 0.20))
	var leave: float = float(cp.get("paid_leave", 0.30))
	var workers: float = float(cp.get("care_workers", 0.25))
	var aging: float = float(state.get("demographic_policy", {}).get("aging_index", 0.25))

	# بار مراقبت: سالمندی + کودکان - خدمات رسمی
	var care_burden: float = clampf(
		0.40 + aging * 0.35 + (1.0 - child) * 0.15 - elder * 0.20 - home * 0.10, 0.05, 0.95)
	cp["care_burden"] = care_burden
	cp["informal_care"] = clampf(0.85 - elder * 0.30 - child * 0.25 - home * 0.20, 0.10, 0.95)

	# مشارکت زنان: مهدکودک و مرخصی زایمان آن‌ها را به بازار کار برمی‌گرداند
	var female_lfp: float = clampf(
		0.25 + child * 0.30 + leave * 0.15 + workers * 0.15 + float(edu.get("quality", 0.55)) * 0.10,
		0.10, 0.85)
	cp["female_lfp"] = female_lfp
	var labor_gain: float = female_lfp * 0.05 + child * 0.03
	cp["labor_force_gain"] = labor_gain

	# اثر اقتصادی: نیروی کار بیشتر = رشد + مالیات
	var gdp: float = float(econ.get("gdp", 1.0))
	econ["gdp"] = gdp * (1.0 + labor_gain * 0.0008)
	econ["unemployment"] = clampf(float(econ.get("unemployment", 0.08)) - labor_gain * 0.0005, 0.02, 0.30)
	# بار اقتصادی مراقبت غیررسمی (فرصت ازدست‌رفته)
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + gdp * (0.001 + elder * 0.001 + child * 0.001)
	state["economy"] = econ

	# سلامت سالمندان
	if aging > 0.4:
		health["quality"] = clampf(float(health.get("quality", 0.60)) + (elder + home) * 0.001, 0.1, 1.0)
		state["health"] = health

	# باروری: مهدکودک و مرخصی زایمان
	if state.has("family") and state["family"].has("fertility"):
		state["family"]["fertility"] = clampf(float(state["family"]["fertility"]) + (child + leave) * 0.002, 0.8, 3.2)

	# رویدادها
	if care_burden > 0.70 and Deterministic.chance(0.04):
		# اثر واقعی بحران مراقبت: مراقبت غیررسمی نیروی کار را می‌بلعد و سالمندان آسیب می‌بینند
		econ["unemployment"] = clampf(float(econ.get("unemployment", 0.08)) + 0.003, 0.02, 0.30)
		pop["happiness"] = clampf(float(pop.get("happiness", 0.60)) - 0.020, 0.05, 1.0)
		health["quality"] = clampf(float(health.get("quality", 0.60)) - 0.010, 0.10, 1.0)
		state["economy"] = econ
		state["population"] = pop
		state["health"] = health
		events.append({"type": "care_crisis", "message": "👵 بحران مراقبت! بار نگهداری از سالمندان بر دوش خانواده‌ها افتاد"})
	elif female_lfp > 0.65 and Deterministic.chance(0.025):
		events.append({"type": "women_workforce", "message": "👩‍💼 مشارکت زنان در بازار کار رکورد شکست؛ اقتصاد جان گرفت"})
	elif workers > 0.60 and Deterministic.chance(0.02):
		events.append({"type": "care_jobs", "message": "🧑‍⚕️ بخش مراقبت رسمی به منبع بزرگ اشتغال تبدیل شد"})

	state["care_policy"] = cp
	return {"state": state, "events": events}

func eldercare_program(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var cp: Dictionary = state["care_policy"]
	cp["eldercare"] = clampf(float(cp.get("eldercare", 0.25)) + 0.15, 0.0, 1.0)
	state["care_policy"] = cp
	return {"success": true, "state": state,
		"events": [{"type": "eldercare", "message": "🏥 مراکز نگهداری روزانه سالمندان توسعه یافت"}]}

func childcare_expansion(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var cp: Dictionary = state["care_policy"]
	cp["childcare"] = clampf(float(cp.get("childcare", 0.25)) + 0.15, 0.0, 1.0)
	state["care_policy"] = cp
	return {"success": true, "state": state,
		"events": [{"type": "childcare", "message": "🧸 مهدکودک‌ها گسترش یافت؛ زنان راحت‌تر کار می‌کنند"}]}

func home_care_program(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var cp: Dictionary = state["care_policy"]
	cp["home_care"] = clampf(float(cp.get("home_care", 0.20)) + 0.15, 0.0, 1.0)
	state["care_policy"] = cp
	return {"success": true, "state": state,
		"events": [{"type": "home_care", "message": "🏠 خدمات مراقبت در منزل توسعه یافت"}]}

func paid_parental_leave(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var cp: Dictionary = state["care_policy"]
	if float(cp.get("paid_leave", 0.30)) >= 0.95:
		return {"success": false, "reason": "مرخصی زایمان در سقف است", "state": state, "events": []}
	cp["paid_leave"] = clampf(float(cp.get("paid_leave", 0.30)) + 0.15, 0.0, 1.0)
	state["care_policy"] = cp
	return {"success": true, "state": state,
		"events": [{"type": "parental_leave", "message": "🤱 مرخصی زایمان با حقوق تقویت شد"}]}
