extends Node
# ────────────────────────────────────────────────────────────────────────────
# زندان و سیاست کیفری — عمق عدالت و بازاجتماعی‌سازی
# رویکرد سخت‌گیرانه/بازپرورانه، ظرفیت زندان، آموزش و کار در زندان، آزادی مشروط
# و بازگشت به جامعه. این سیستم بین دو هدف در نوسان است: کاهش جرم (امنیت) و
# کاهش بازگشت به جرم (عدالت ترمیمی). پیوند: امنیت، قضایی، رفاه، اقتصاد، رسانه.
#
# state["prison_policy"] = {
#   "approach":"balanced"|"rehab"|"punitive", "parole":0..1,
#   "capacity_expansion":0..1, "prison_labor":0..1, "education":0..1,
#   "last_amnesty":turn, "last_expansion":turn }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("prison_policy"):
		state["prison_policy"] = {
			"approach": "balanced", "parole": 0.30, "capacity_expansion": 0.30,
			"prison_labor": 0.25, "education": 0.30, "last_amnesty": -99,
			"last_expansion": -99, "recidivism_target": 0.35
		}
	if not state.has("prison"):
		state["prison"] = {
			"population": 80000, "capacity": 100000, "overcrowding": 0.80,
			"rehabilitation": 0.40, "recidivism": 0.35, "conditions": 0.55,
			"education_prison": 0.35, "work_programs": 0.30, "security_level": 0.70,
			"violence_rate": 0.05, "escapes": 5
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var pp: Dictionary = state["prison_policy"]
	var prison: Dictionary = state["prison"]
	var sec: Dictionary = state.get("security", {})
	var jud: Dictionary = state.get("judicial", {})
	var econ: Dictionary = state.get("economy", {})
	var welfare: Dictionary = state.get("welfare", {})
	var media: Dictionary = state.get("media", {})
	var pol: Dictionary = state.get("politics", {})

	var approach := str(pp.get("approach", "balanced"))
	var parole := float(pp.get("parole", 0.30))
	var expansion := float(pp.get("capacity_expansion", 0.30))
	var labor := float(pp.get("prison_labor", 0.25))
	var edu := float(pp.get("education", 0.30))

	# رویکرد کیفری: جمعیت بیشتر، امنیت کوتاه‌مدت، خشونت و هزینه بیشتر
	var approach_factor := 1.0
	var security_bonus := 0.0
	var rights_hit := 0.0
	match approach:
		"punitive":
			approach_factor = 1.15
			security_bonus = 0.004
			rights_hit = 0.006
		"rehab":
			approach_factor = 0.90
			security_bonus = -0.002
			rights_hit = -0.003
		_:
			approach_factor = 1.0

	# جمعیت زندان: جرم (امنیت معکوس) + رویکرد
	var crime_pressure := (1.0 - float(sec.get("public_security", 0.70))) * 120000.0 + approach_factor * 60000.0
	# آزادی مشروط و عفو جمعیت را کم می‌کند
	crime_pressure -= parole * 50000.0
	prison["population"] = int(clampf(float(prison.get("population", 80000)) * 0.99 + crime_pressure * 0.01, 8000.0, 400000.0))

	# ظرفیت
	var cap_base := 100000.0 + expansion * 120000.0
	prison["capacity"] = int(cap_base)
	prison["overcrowding"] = clampf(float(prison["population"]) / max(float(prison["capacity"]), 1.0), 0.2, 2.5)

	# شرایط و خشونت
	var conditions := clampf(
		0.55 - (prison["overcrowding"] - 1.0) * 0.25 + edu * 0.05 + labor * 0.05 +
		(1.0 if approach == "rehab" else 0.0) * 0.05, 0.05, 0.95)
	prison["conditions"] = conditions
	prison["violence_rate"] = clampf(
		prison["overcrowding"] * 0.025 + (1.0 - conditions) * 0.06 +
		(1.0 - float(prison.get("security_level", 0.70))) * 0.02, 0.005, 0.35)

	# بازاجتماعی‌سازی: آموزش + کار + شرایط
	var rehab := clampf(edu * 0.35 + labor * 0.25 + conditions * 0.30 + parole * 0.10, 0.05, 0.95)
	prison["rehabilitation"] = rehab
	var unemployment := float(econ.get("unemployment", 0.08))
	var recidivism := clampf((1.0 - rehab) * 0.50 + unemployment * 0.30 + maxf(0.0, prison["overcrowding"] - 1.0) * 0.05, 0.05, 0.85)
	prison["recidivism"] = recidivism
	pp["recidivism_target"] = recidivism

	# فرار و امنیت
	prison["escapes"] = int((1.0 - float(prison.get("security_level", 0.70))) * 8.0 + maxf(0.0, prison["overcrowding"] - 1.0) * 4.0)
	sec["public_security"] = clampf(
		float(sec.get("public_security", 0.70)) + security_bonus - prison["escapes"] * 0.0005 - recidivism * 0.002,
		0.1, 1.0)
	state["security"] = sec

	# اثر اقتصادی: هزینه نگهداری و کار زندانیان
	var gdp := float(econ.get("gdp", 1.0))
	var cost: float = gdp * 0.001 * (0.5 + float(prison["overcrowding"]) * 0.3 - labor * 0.1)
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + cost
	# کار زندانیان سهم کوچکی در اقتصاد دارد
	if labor > 0.3:
		econ["gdp"] = gdp * (1.0 + labor * 0.0001)
	state["economy"] = econ

	# اثر اجتماعی: حقوق بشر/رسانه
	media["trust"] = clampf(
		float(media.get("trust", 0.55)) + (conditions - 0.5) * 0.004 - rights_hit, 0.05, 1.0)
	state["media"] = media
	# رضایت محافظه‌کاران/پوپولیست از رویکرد سختگیرانه
	if state.has("factions") and state["factions"].has("پوپولیست‌ها"):
		var fac: Dictionary = state["factions"]["پوپولیست‌ها"]
		var shift := 0.0
		if approach == "punitive": shift = 0.15
		elif approach == "rehab": shift = -0.10
		fac["loyalty"] = clampf(float(fac.get("loyalty", 50.0)) + shift, 0.0, 100.0)
		state["factions"]["پوپولیست‌ها"] = fac

	# رویدادها
	if prison["overcrowding"] > 1.6 and Deterministic.chance(0.05):
		pol["stability"] = clampf(float(pol.get("stability", 0.60)) - 0.010, 0.05, 1.0)
		events.append({"type": "prison_riot", "message": "🔥 شورش در زندان به‌خاطر ازدحام و شرایط بد! خواستار اصلاح فوری"})
		state["politics"] = pol
	elif recidivism < 0.20 and Deterministic.chance(0.03):
		events.append({"type": "rehab_success", "message": "🌱 برنامه‌های بازاجتماعی‌سازی جواب داد؛ بازگشت به جرم به کمترین میزان رسید"})
	elif prison["escapes"] > 8 and Deterministic.chance(0.04):
		events.append({"type": "prison_escape", "message": "🚔 فرار دسته‌جمعی از زندان؛ انتقادها از امنیت زندان‌ها بالا گرفت"})

	state["prison"] = prison
	state["prison_policy"] = pp
	return {"state": state, "events": events}

# ── تغییر رویکرد کیفری ──
func set_approach(state: Dictionary, approach: String) -> Dictionary:
	state = ensure(state)
	if not ["punitive", "balanced", "rehab"].has(approach):
		return {"success": false, "reason": "رویکرد نامعتبر", "state": state, "events": []}
	state["prison_policy"]["approach"] = approach
	var names := {"punitive": "سخت‌گیرانه", "balanced": "متعادل", "rehab": "بازپرورانه"}
	return {"success": true, "state": state,
		"events": [{"type": "approach", "message": "⚖️ رویکرد سیاست کیفری به «%s» تغییر کرد" % names.get(approach, approach)}]}

# ── توسعه ظرفیت زندان ──
func expand_capacity(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var pp: Dictionary = state["prison_policy"]
	if turn - int(pp.get("last_expansion", -99)) < 6:
		return {"success": false, "reason": "توسعه زندان هر ۶ نوبت یک بار", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.005
	pp["last_expansion"] = turn
	pp["capacity_expansion"] = clampf(float(pp.get("capacity_expansion", 0.30)) + 0.15, 0.0, 1.0)
	state["economy"] = econ
	state["prison_policy"] = pp
	return {"success": true, "state": state,
		"events": [{"type": "prison_expand", "message": "🏗️ ظرفیت زندان‌ها و بازداشتگاه‌ها توسعه یافت؛ ازدحام کنترل شد"}]}

# ── برنامه آموزشی در زندان ──
func education_program(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var pp: Dictionary = state["prison_policy"]
	if float(pp.get("education", 0.30)) >= 0.95:
		return {"success": false, "reason": "برنامه آموزشی زندان در سقف است", "state": state, "events": []}
	pp["education"] = clampf(float(pp.get("education", 0.30)) + 0.15, 0.0, 1.0)
	state["education"]["quality"] = clampf(state["education"].get("quality", 0.55) + 0.005, 0.1, 1.0)
	state["prison_policy"] = pp
	return {"success": true, "state": state,
		"events": [{"type": "prison_edu", "message": "📚 برنامه سوادآموزی و مهارت‌آموزی در زندان‌ها گسترش یافت؛ بازگشت به جرم کاهش می‌یابد"}]}

# ── عفو و آزادی مشروط ──
func amnesty_program(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var pp: Dictionary = state["prison_policy"]
	if turn - int(pp.get("last_amnesty", -99)) < 8:
		return {"success": false, "reason": "عفو سراسری هر ۸ نوبت یک بار", "state": state, "events": []}
	pp["last_amnesty"] = turn
	pp["parole"] = clampf(float(pp.get("parole", 0.30)) + 0.15, 0.0, 1.0)
	var prison: Dictionary = state["prison"]
	prison["population"] = int(maxf(float(prison["population"]) * 0.88, 5000.0))
	state["population"]["happiness"] = clampf(state["population"].get("happiness", 0.60) + 0.005, 0.05, 1.0)
	state["prison"] = prison
	state["prison_policy"] = pp
	return {"success": true, "state": state,
		"events": [{"type": "amnesty", "message": "🕊️ عفو و آزادی مشروط گروهی از زنداجران اجرا شد؛ ازدحام کم و امید به بازگشت بیشتر شد"}]}
