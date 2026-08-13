extends Node
# ────────────────────────────────────────────────────────────────────────────
# اصلاحات قضایی و عدالت ترمیمی — عمق فرآیند دادرسی
# روی لایه موجود قوه قضائیه می‌نشیند: هوشمندسازی دادگاه‌ها (کاهش اطاله دادرسی)،
# دادگاه‌های تخصصی تجاری/خانواده، میانجی‌گری و پیشگیری از جرم. هدف کاهش تراکم
# پرونده، دسترسی به عدالت و اعتماد است نه صرفاً احکام سنگین.
# پیوند: قضایی، امنیت، اقتصاد، رسانه، زندان، فساد.
#
# state["judicial_reform_policy"] = {
#   "digital_courts":0..1, "specialized_courts":0..1,
#   "mediation":0..1, "legal_aid":0..1, "crime_prevention":0..1,
#   "last_digital":turn, "case_resolution":0..1 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("judicial_reform_policy"):
		state["judicial_reform_policy"] = {
			"digital_courts": 0.20, "specialized_courts": 0.20,
			"mediation": 0.20, "legal_aid": 0.25,
			"crime_prevention": 0.20, "last_digital": -99,
			"case_resolution": 0.45, "cost_of_delay": 0.30,
			"business_disputes": 0.40
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var jrp: Dictionary = state["judicial_reform_policy"]
	var jud: Dictionary = state.get("judicial", {})
	var pol: Dictionary = state.get("politics", {})
	var econ: Dictionary = state.get("economy", {})
	var media: Dictionary = state.get("media", {})
	var prison: Dictionary = state.get("prison", {})

	var digital := float(jrp.get("digital_courts", 0.20))
	var specialized := float(jrp.get("specialized_courts", 0.20))
	var mediation := float(jrp.get("mediation", 0.20))
	var legal_aid := float(jrp.get("legal_aid", 0.25))
	var prevention := float(jrp.get("crime_prevention", 0.20))
	var gdp := float(econ.get("gdp", 1.0))

	# سرعت رسیدگی: دیجیتال + دادگاه‌های تخصصی + میانجی‌گری
	var resolution := clampf(
		0.30 + digital * 0.25 + specialized * 0.20 + mediation * 0.15 +
		legal_aid * 0.10 + prevention * 0.10, 0.10, 0.95)
	jrp["case_resolution"] = resolution
	var delay_cost := clampf(1.0 - resolution, 0.05, 0.80)
	jrp["cost_of_delay"] = delay_cost

	# کاهش تراکم پرونده در لایه قضایی اصلی
	if jud.has("backlog"):
		jud["backlog"] = clampf(float(jud.get("backlog", 0.4)) * 0.98 + (1.0 - resolution) * 0.02, 0.05, 1.0)
		jud["efficiency"] = clampf(float(jud.get("efficiency", 0.60)) * 0.99 + resolution * 0.01, 0.1, 0.98)
		jud["access"] = clampf(float(jud.get("access", 0.60)) * 0.99 + (legal_aid * 0.5 + digital * 0.3) * 0.01, 0.1, 0.98)
		state["judicial"] = jud

	# دادگاه‌های تجاری → محیط کسب‌وکار و اعتماد اقتصادی
	var business_disputes := clampf(1.0 - specialized * 0.6 - digital * 0.3, 0.05, 0.95)
	jrp["business_disputes"] = business_disputes
	econ["gdp"] = gdp * (1.0 + (0.6 - business_disputes) * 0.0004)
	# اطاله دادرسی هزینه اقتصادی دارد
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + gdp * (0.0008 + delay_cost * 0.0008)
	state["economy"] = econ

	# میانجی‌گری و پیشگیری → زندان و امنیت
	if not prison.is_empty():
		prison["recidivism"] = clampf(float(prison.get("recidivism", 0.35)) - mediation * 0.001 - prevention * 0.001, 0.05, 0.85)
		prison["population"] = int(maxf(float(prison.get("population", 80000)) * (1.0 - mediation * 0.0005), 5000.0))
		state["prison"] = prison
	var sec: Dictionary = state.get("security", {})
	sec["public_security"] = clampf(float(sec.get("public_security", 0.70)) + prevention * 0.0005 - delay_cost * 0.001, 0.1, 1.0)
	state["security"] = sec

	# اعتماد
	pol["trust"] = clampf(float(pol.get("trust", 0.55)) + (resolution - 0.5) * 0.003, 0.05, 1.0)
	media["trust"] = clampf(float(media.get("trust", 0.55)) + (resolution - 0.5) * 0.002, 0.05, 1.0)
	state["politics"] = pol
	state["media"] = media

	# رویدادها
	if delay_cost > 0.60 and Deterministic.chance(0.04):
		events.append({"type": "case_backlog", "message": "📋 اطاله دادرسی بحرانی شد؛ دادگاه‌ها از حجم پرونده‌ها عقب ماندند"})
	elif resolution > 0.75 and Deterministic.chance(0.03):
		events.append({"type": "justice_fast", "message": "⚖️ دیجیتالی شدن دادگاه‌ها زمان رسیدگی را چشمگیر کم کرد؛ امید به عدالت بالا رفت"})
	elif specialized > 0.60 and Deterministic.chance(0.025):
		events.append({"type": "commercial_court", "message": "🏛️ دادگاه تجاری تخصصی اعتماد سرمایه‌گذاران را بالا برد"})

	state["judicial_reform_policy"] = jrp
	return {"state": state, "events": events}

# ── دیجیتالی کردن دادگاه‌ها ──
func digitalize_courts(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var jrp: Dictionary = state["judicial_reform_policy"]
	if turn - int(jrp.get("last_digital", -99)) < 6:
		return {"success": false, "reason": "پروژه دیجیتال‌سازی هر ۶ نوبت یک بار", "state": state, "events": []}
	var tech := float(state.get("technology", {}).get("branch_levels", {}).get("دیجیتال", 0))
	if tech < 4:
		return {"success": false, "reason": "به فناوری دیجیتال سطح ۴ نیاز است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.003
	jrp["last_digital"] = turn
	jrp["digital_courts"] = clampf(float(jrp.get("digital_courts", 0.20)) + 0.15, 0.0, 1.0)
	state["economy"] = econ
	state["judicial_reform_policy"] = jrp
	return {"success": true, "state": state,
		"events": [{"type": "digital_courts", "message": "💻 دادگاه‌های الکترونیک و ابلاغ دیجیتال راه‌اندازی شد؛ کاغذبازی کم شد"}]}

# ── دادگاه‌های تخصصی ──
func specialized_courts(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var jrp: Dictionary = state["judicial_reform_policy"]
	if float(jrp.get("specialized_courts", 0.20)) >= 0.95:
		return {"success": false, "reason": "دادگاه‌های تخصصی در سقف هستند", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.002
	jrp["specialized_courts"] = clampf(float(jrp.get("specialized_courts", 0.20)) + 0.15, 0.0, 1.0)
	state["economy"] = econ
	state["judicial_reform_policy"] = jrp
	return {"success": true, "state": state,
		"events": [{"type": "specialized", "message": "🏛️ دادگاه‌های تجاری، خانواده و کودک راه‌اندازی شدند"}]}

# ── میانجی‌گری و عدالت ترمیمی ──
func mediation_program(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var jrp: Dictionary = state["judicial_reform_policy"]
	if float(jrp.get("mediation", 0.20)) >= 0.95:
		return {"success": false, "reason": "برنامه میانجی‌گری در سقف است", "state": state, "events": []}
	jrp["mediation"] = clampf(float(jrp.get("mediation", 0.20)) + 0.15, 0.0, 1.0)
	if state.has("prison"):
		state["prison"]["population"] = int(maxf(float(state["prison"].get("population", 80000)) * 0.97, 5000.0))
	state["judicial_reform_policy"] = jrp
	return {"success": true, "state": state,
		"events": [{"type": "mediation", "message": "🤝 مراکز میانجی‌گری توسعه یافت؛ اختلاف‌های کوچک پیش از دادگاه حل می‌شوند"}]}

# ── معاضدت حقوقی و پیشگیری ──
func legal_aid(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var jrp: Dictionary = state["judicial_reform_policy"]
	if float(jrp.get("legal_aid", 0.25)) >= 0.95:
		return {"success": false, "reason": "معاضدت حقوقی در سقف است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.0015
	jrp["legal_aid"] = clampf(float(jrp.get("legal_aid", 0.25)) + 0.15, 0.0, 1.0)
	jrp["crime_prevention"] = clampf(float(jrp.get("crime_prevention", 0.20)) + 0.08, 0.0, 1.0)
	state["economy"] = econ
	state["politics"]["trust"] = clampf(state["politics"].get("trust", 0.55) + 0.005, 0.05, 1.0)
	state["judicial_reform_policy"] = jrp
	return {"success": true, "state": state,
		"events": [{"type": "legal_aid", "message": "🧑⚖️ وکیل تسخیری و معاضدت حقوقی برای اقشار کم‌درآمد توسعه یافت"}]}
