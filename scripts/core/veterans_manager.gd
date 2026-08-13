extends Node
# ────────────────────────────────────────────────────────────────────────────
# بنیاد ایثارگران و کهنه‌سربازان — عمق اجتماعی-نظامی
# در جنگ‌ها شمار کهنه‌سربازان می‌شکفد و در صلح آرام کاهش می‌یابد؛ رضایت آنان
# به مستمری، اشتغال، بهداشت و تکریم بستگی دارد. بی‌توجهی، ثبات را می‌خورد.
# پیوند: ارتش، بودجه، سلامت، رسانه، رهبر.
#
# state["veterans_policy"] = { "pension_level": 0..1, "employment_program": 0..1,
#   "clinic": false, "parades": 0, "last_parade": turn, "satisfaction": 0..1 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("veterans_policy"):
		state["veterans_policy"] = {"pension_level": 0.5, "employment_program": 0.4, "clinic": false, "parades": 0, "last_parade": -99, "satisfaction": 0.6}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var vt: Dictionary = state.get("veterans", {})
	var vp: Dictionary = state["veterans_policy"]
	var econ: Dictionary = state.get("economy", {})
	var pol: Dictionary = state.get("politics", {})
	var world: Dictionary = state.get("world", {})

	var count := float(vt.get("count", 500000.0))
	var at_war: bool = not world.get("wars", {}).is_empty()

	# پویایی شمار: جنگ → جانبازان تازه؛ صلح → بازنشستگی طبیعی
	if at_war:
		count = count * 1.01 + 12000.0
	else:
		count = maxf(20000.0, count * 0.995)

	var pension_level := float(vp.get("pension_level", 0.5))
	var employment_program := float(vp.get("employment_program", 0.4))
	var recognition := float(vt.get("recognition", 0.7))
	var health_care := float(vt.get("health_care", 0.65))
	var clinic_active := bool(vp.get("clinic", false))
	if clinic_active:
		health_care = clampf(health_care + 0.02, 0.05, 1.0)

	# هزینه ماهانه مستمری و برنامه‌ها (اشتغال هزینه پشتیبانی را کم می‌کند)
	var gdp := float(econ.get("gdp", 1.0))
	var cost := gdp * (0.001 + pension_level * 0.002) * (1.0 - employment_program * 0.3)
	if clinic_active:
		cost += gdp * 0.0005
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + cost
	var revenue := float(econ.get("government_revenue", 0.0))
	if cost > revenue * 0.08:
		econ["national_debt"] = float(econ.get("national_debt", 0.0)) + (cost - revenue * 0.08) * 0.5

	# رضایت کهنه‌سربازان
	var satisfaction := clampf(0.30 + pension_level * 0.25 + employment_program * 0.20 + recognition * 0.10 + health_care * 0.15, 0.05, 1.0)
	vp["satisfaction"] = satisfaction
	vt["recognition"] = recognition
	vt["health_care"] = health_care
	vt["employment"] = clampf(float(vt.get("employment", 0.6)) * 0.6 + employment_program * 0.4, 0.05, 1.0)
	vt["pension"] = pension_level

	# بی‌توجهی → نارضایتی و بی‌ثباتی
	if satisfaction < 0.40:
		pol["stability"] = clampf(float(pol.get("stability", 0.6)) - 0.006, 0.05, 1.0)
		if Deterministic.chance(0.06):
			events.append({"type": "veterans_protest", "message": "✊ تجمع کهنه‌سربازان مقابل مجلس! مستمری و بیمه ناکافی است"})
	elif satisfaction > 0.75 and at_war and Deterministic.chance(0.03):
		state["media"]["groups"]["جوانان"]["approval"] = clampf(float(state["media"]["groups"]["جوانان"].get("approval", 45.0)) + 1.5, 5.0, 100.0)
		events.append({"type": "veterans_pride", "message": "🎖️ موج حمایت از کهنه‌سربازان در جامعه؛ جوانان به خدمت سربازی افتخار می‌کنند"})

	vt["count"] = count
	state["veterans"] = vt
	state["veterans_policy"] = vp
	state["economy"] = econ
	state["politics"] = pol
	return {"state": state, "events": events}

# ── افزایش مستمری ──
func raise_pension(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var vp: Dictionary = state["veterans_policy"]
	if float(vp.get("pension_level", 0.5)) >= 0.98:
		return {"success": false, "reason": "مستمری در سقف ممکن است", "state": state, "events": []}
	vp["pension_level"] = clampf(float(vp.get("pension_level", 0.5)) + 0.15, 0.0, 1.0)
	state["veterans_policy"] = vp
	return {"success": true, "state": state,
		"events": [{"type": "pension_rise", "message": "💵 مستمری کهنه‌سربازان افزایش یافت؛ خانه‌هایشان لبخند دید"}]}

# ── طرح اشتغال ──
func employment_plan(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var vp: Dictionary = state["veterans_policy"]
	if float(vp.get("employment_program", 0.4)) >= 0.98:
		return {"success": false, "reason": "طرح اشتغال حداکثری است", "state": state, "events": []}
	vp["employment_program"] = clampf(float(vp.get("employment_program", 0.4)) + 0.2, 0.0, 1.0)
	state["economy"]["unemployment"] = clampf(float(state["economy"].get("unemployment", 0.08)) - 0.0015, 0.02, 0.30)
	state["veterans_policy"] = vp
	return {"success": true, "state": state,
		"events": [{"type": "veterans_jobs", "message": "👷 طرح اشتغال جانبازان: کارگاه‌های مهارت‌آموزی و اولویت استخدام؛ بیکاری کم شد"}]}

# ── بیمارستان تخصصی ──
func veterans_clinic(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var vp: Dictionary = state["veterans_policy"]
	if bool(vp.get("clinic", false)):
		return {"success": false, "reason": "بیمارستان تخصصی از قبل فعال است", "state": state, "events": []}
	vp["clinic"] = true
	state["health"]["quality"] = clampf(float(state["health"].get("quality", 0.6)) + 0.015, 0.1, 1.0)
	state["veterans_policy"] = vp
	return {"success": true, "state": state,
		"events": [{"type": "veterans_clinic", "message": "🏥 بیمارستان تخصصی جانبازان افتتاح شد؛ درمان رایگان برای قهرمانان ملی"}]}

# ── بزرگداشت و بنای یادبود ──
func veterans_parade(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var vp: Dictionary = state["veterans_policy"]
	if turn - int(vp.get("last_parade", -99)) < 12:
		return {"success": false, "reason": "مراسم بزرگداشت هر ۱۲ نوبت یک بار ممکن است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.004
	vp["last_parade"] = turn
	vp["parades"] = int(vp.get("parades", 0)) + 1
	state["veterans"]["recognition"] = clampf(float(state["veterans"].get("recognition", 0.7)) + 0.1, 0.05, 1.0)
	state["leader"]["popularity_world"] = clampf(float(state["leader"].get("popularity_world", 50.0)) + 1.5, 0.0, 100.0)
	state["population"]["happiness"] = clampf(float(state["population"].get("happiness", 0.6)) + 0.008, 0.05, 1.0)
	state["economy"] = econ
	state["veterans_policy"] = vp
	return {"success": true, "state": state,
		"events": [{"type": "veterans_parade", "message": "🎖️ روز بزرگداشت ایثارگران: رژه باشکوه، رسانه‌های جهان پخش کردند؛ ملت یکپارچه شد"}]}
