extends Node
# ────────────────────────────────────────────────────────────────────────────
# صنعت بیمه و حفاظت مالی — عمق تاب‌آوری اقتصادی
# بیمه درمان تکمیلی، بیمه عمر، بیمه کشاورزی (بلایا)، بیمه سپرده و بیمه
# اتکایی. ضریب نفوذ بالا، خسارت بحران را جذب می‌کند؛ نظارت ضعیف حباب و
# ورشکستگی می‌آفریند. پیوند: اقتصاد، بانک، رفاه، بهداشت، کشاورزی، اقلیم.
#
# state["insurance_policy"] = {
#   "penetration":0..1, "health_insurance":0..1, "agri_insurance":0..1,
#   "deposit_insurance":0..1, "reinsurance":0..1, "regulation":0..1,
#   "last_scheme":turn, "solvency":0..1, "claims":0 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("insurance_policy"):
		state["insurance_policy"] = {
			"penetration": 0.30, "health_insurance": 0.45, "agri_insurance": 0.15,
			"deposit_insurance": 0.40, "reinsurance": 0.30, "regulation": 0.50,
			"last_scheme": -99, "solvency": 0.70, "claims": 0.0,
			"premium_gdp": 0.0, "default_risk": 0.15
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var ip: Dictionary = state["insurance_policy"]
	var econ: Dictionary = state.get("economy", {})
	var health: Dictionary = state.get("health", {})
	var agri: Dictionary = state.get("agriculture", {})
	var welfare: Dictionary = state.get("welfare", {})
	var banking: Dictionary = state.get("banking", {})
	var climate: Dictionary = state.get("climate_policy", {})

	var penetration := float(ip.get("penetration", 0.30))
	var health_ins := float(ip.get("health_insurance", 0.45))
	var agri_ins := float(ip.get("agri_insurance", 0.15))
	var deposit_ins := float(ip.get("deposit_insurance", 0.40))
	var reinsurance := float(ip.get("reinsurance", 0.30))
	var regulation := float(ip.get("regulation", 0.50))
	var gdp := float(econ.get("gdp", 1.0))

	# نفوذ از درآمد سرانه و اعتماد به نظام مالی می‌آید
	var gdp_pc := gdp / maxf(float(state.get("population", {}).get("total", 85e6)), 1.0)
	var target := clampf(0.10 + gdp_pc / 50000.0 * 0.5 + regulation * 0.2, 0.05, 0.95)
	penetration = clampf(penetration * 0.98 + target * 0.02, 0.05, 0.95)
	ip["penetration"] = penetration

	# توانگری بیمه: حق بیمه + اتکایی - خسارت
	var premium_gdp := 0.012 + penetration * 0.025 + health_ins * 0.005
	ip["premium_gdp"] = premium_gdp
	var disaster_pressure := float(climate.get("disasters_handled", 0)) * 0.0002 + (1.0 - float(climate.get("disaster_readiness", 0.3))) * 0.002
	var agri_claims := (1.0 - float(agri.get("food_security", 0.85))) * agri_ins * 0.3
	var health_claims := (1.0 - float(health.get("quality", 0.60))) * health_ins * 0.2
	var claim_ratio := 0.55 + agri_claims + health_claims + disaster_pressure + (1.0 - regulation) * 0.10
	var solvency := clampf(0.50 + reinsurance * 0.25 + regulation * 0.20 - claim_ratio * 0.45 + penetration * 0.10, 0.05, 1.0)
	ip["solvency"] = solvency
	ip["claims"] = claim_ratio
	ip["default_risk"] = clampf(1.0 - solvency, 0.02, 0.95)

	# حق بیمه بخشی از اقتصاد است
	econ["gdp"] = gdp * (1.0 + penetration * 0.0002)
	state["economy"] = econ

	# بیمه درمان تکمیلی: کیفیت بهداشت و رفاه
	health["quality"] = clampf(float(health.get("quality", 0.60)) + health_ins * 0.001, 0.1, 1.0)
	state["health"] = health
	welfare["poverty"] = clampf(float(welfare.get("poverty", 0.15)) - health_ins * 0.0008 - penetration * 0.0005, 0.02, 0.80)
	state["welfare"] = welfare

	# بیمه کشاورزی خسارت بلایا را جذب می‌کند (تاب‌آوری کشاورزی)
	if agri_ins > 0.3:
		agri["food_security"] = clampf(float(agri.get("food_security", 0.85)) + agri_ins * 0.0008, 0.1, 1.0)
		state["agriculture"] = agri

	# بیمه سپرده: ثبات بانکی
	if banking.has("stability"):
		banking["stability"] = clampf(float(banking.get("stability", 0.65)) + deposit_ins * 0.002, 0.05, 1.0)
		state["banking"] = banking
	# حتی اگر کلید نباشد، بحران بانکی احتمالی کاهش می‌یابد

	# رویدادها
	if solvency < 0.25 and (turn - int(ip.get("last_default", -99))) >= 24 and Deterministic.chance(0.05):
		econ["national_debt"] = float(econ.get("national_debt", 0.0)) + gdp * 0.004
		state["economy"] = econ
		state["politics"]["trust"] = clampf(state["politics"].get("trust", 0.55) - 0.015, 0.05, 1.0)
		ip["last_default"] = turn
		events.append({"type": "insurer_default", "message": "💥 یک شرکت بیمه بزرگ ورشکست شد؛ خسارت مردم و بیمه‌گذاران پرداخت نشد"})
	elif penetration > 0.70 and solvency > 0.65 and Deterministic.chance(0.03):
		events.append({"type": "insurance_resilience", "message": "🛡️ ضریب نفوذ بیمه بالا، خسارت یک بحران را جذب کرد؛ تاب‌آوری اقتصاد تقویت شد"})
	elif agri_ins > 0.50 and Deterministic.chance(0.025):
		events.append({"type": "agri_insurance", "message": "🌾 بیمه کشاورزی غرامت خشکسالی را به‌موقع پرداخت کرد؛ مهاجرت روستایی کنترل شد"})

	state["insurance_policy"] = ip
	return {"state": state, "events": events}

# ── طرح بیمه فراگیر (افزایش ضریب نفوذ) ──
func universal_scheme(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var ip: Dictionary = state["insurance_policy"]
	if turn - int(ip.get("last_scheme", -99)) < 8:
		return {"success": false, "reason": "طرح سراسری بیمه هر ۸ نوبت یک بار", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.004
	ip["last_scheme"] = turn
	ip["penetration"] = clampf(float(ip.get("penetration", 0.30)) + 0.15, 0.0, 1.0)
	state["economy"] = econ
	state["insurance_policy"] = ip
	return {"success": true, "state": state,
		"events": [{"type": "universal_scheme", "message": "📋 طرح بیمه فراگیر آغاز شد؛ اقشار کم‌درآمد زیر چتر حمایت رفتند"}]}

# ── بیمه درمان تکمیلی ──
func expand_health(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var ip: Dictionary = state["insurance_policy"]
	if float(ip.get("health_insurance", 0.45)) >= 0.95:
		return {"success": false, "reason": "بیمه درمان تکمیلی در سقف است", "state": state, "events": []}
	ip["health_insurance"] = clampf(float(ip.get("health_insurance", 0.45)) + 0.15, 0.0, 1.0)
	state["insurance_policy"] = ip
	return {"success": true, "state": state,
		"events": [{"type": "health_insurance", "message": "🏥 بیمه درمان تکمیلی گسترش یافت؛ هزینه‌های کمرشکن درمان کاهش یافت"}]}

# ── بیمه کشاورزی و بلایا ──
func expand_agri(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var ip: Dictionary = state["insurance_policy"]
	if float(ip.get("agri_insurance", 0.15)) >= 0.90:
		return {"success": false, "reason": "بیمه کشاورزی در سقف است", "state": state, "events": []}
	ip["agri_insurance"] = clampf(float(ip.get("agri_insurance", 0.15)) + 0.15, 0.0, 1.0)
	state["insurance_policy"] = ip
	return {"success": true, "state": state,
		"events": [{"type": "agri_scheme", "message": "🌾 صندوق بیمه کشاورزی با حمک خشکسالی، سیل و تگرگ راه‌اندازی شد"}]}

# ── بیمه سپرده و مقررات نظارتی ──
func strengthen_regulation(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var ip: Dictionary = state["insurance_policy"]
	if float(ip.get("regulation", 0.50)) >= 0.95:
		return {"success": false, "reason": "نظارت بیمه‌ای در سقف است", "state": state, "events": []}
	ip["regulation"] = clampf(float(ip.get("regulation", 0.50)) + 0.15, 0.0, 1.0)
	ip["reinsurance"] = clampf(float(ip.get("reinsurance", 0.30)) + 0.05, 0.0, 1.0)
	ip["solvency"] = clampf(float(ip.get("solvency", 0.70)) + 0.05, 0.0, 1.0)
	state["insurance_policy"] = ip
	return {"success": true, "state": state,
		"events": [{"type": "insurance_regulation", "message": "⚖️ مقررات نظارتی و بیمه اتکایی تقویت شد؛ ریسک ورشکستگی شرکت‌ها کم شد"}]}
