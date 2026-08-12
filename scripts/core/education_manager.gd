extends Node
# ────────────────────────────────────────────────────────────────────────────
# سیاست آموزش — عمق سرمایه انسانی
# آموزش فنی‌وحرفه‌ای (اشتغال)، استقلال دانشگاه (نوآوری/فرار مغزها)، بورس
# تحصیلی (عدالت)، آموزش دیجیتال (فناوری). پیوند: فرار مغزها، تکنوکرات‌ها.
#
# state["education_policy"] = { "vocational":0..1, "university_autonomy":0..1,
#   "scholarships":0..1, "digital_learning":0..1, "literacy_bonus":0 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("education_policy"):
		state["education_policy"] = {"vocational": 0.3, "university_autonomy": 0.4, "scholarships": 0.2, "digital_learning": 0.2, "literacy_bonus": 0.0}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var ed: Dictionary = state["education_policy"]
	var econ: Dictionary = state.get("economy", {})
	var tech: Dictionary = state.get("technology", {})
	var mig: Dictionary = state.get("migration", {})
	var edu: Dictionary = state.get("education", {})
	var vocational := float(ed.get("vocational", 0.3))
	var autonomy := float(ed.get("university_autonomy", 0.4))
	var scholarships := float(ed.get("scholarships", 0.2))
	var digital := float(ed.get("digital_learning", 0.2))

	# اثر: آموزش فنی بیکاری را می‌کاهد؛ استقلال دانشگاه نوآوری و فرار مغزها را تعدیل می‌کند
	econ["unemployment"] = clampf(float(econ.get("unemployment", 0.08)) - vocational * 0.0015, 0.02, 0.30)
	tech["research_rate"] = float(tech.get("research_rate", 20.0)) * (1.0 + autonomy * 0.01 + digital * 0.01)
	# استقلال بالا → دانشگاه‌ها بهتر ولی ممکن است نخبگان مهاجرت کنند (فرار مغزها کم‌تر با بورس)
	var brain := float(mig.get("brain_drain", 0.25))
	brain += autonomy * 0.01 - scholarships * 0.02
	mig["brain_drain"] = clampf(brain, 0.0, 0.9)
	state["migration"] = mig
	# بورس → عدالت آموزشی و رضایت جوانان
	state["media"]["groups"]["جوانان"]["approval"] = clampf(float(state["media"]["groups"]["جوانان"].get("approval", 45.0)) + scholarships * 0.3, 5.0, 100.0)
	# ادبیات: آموزش دیجیتال به‌تدریج
	ed["literacy_bonus"] = clampf(float(ed.get("literacy_bonus", 0.0)) + digital * 0.002, 0.0, 0.2)
	edu["literacy"] = clampf(float(edu.get("literacy", 0.85)) + float(ed["literacy_bonus"]) * 0.01, 0.1, 1.0)
	state["education"] = edu
	state["education_policy"] = ed
	state["economy"] = econ
	state["technology"] = tech
	return {"state": state, "events": events}

func vocational_program(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var ed: Dictionary = state["education_policy"]
	if float(ed.get("vocational", 0.3)) >= 0.95:
		return {"success": false, "reason": "ظرفیت آموزش فنی کامل است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * 0.002
	state["economy"] = econ
	ed["vocational"] = clampf(float(ed.get("vocational", 0.3)) + 0.15, 0.0, 1.0)
	state["education_policy"] = ed
	return {"success": true, "state": state,
		"events": [{"type": "vocational", "message": "🔧 شبکه آموزش فنی‌وحرفه‌ای گسترش یافت؛ مهارت نیروی کار و اشتغال رو به بهبود"}]}

func university_reform(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var ed: Dictionary = state["education_policy"]
	if float(ed.get("university_autonomy", 0.4)) >= 0.95:
		return {"success": false, "reason": "استقلال دانشگاه‌ها حداکثری است", "state": state, "events": []}
	var capital := float(state.get("policies", {}).get("political_capital", 0.0))
	if capital < 1.0:
		return {"success": false, "reason": "سرمایه سیاسی کافی نیست", "state": state, "events": []}
	state["policies"]["political_capital"] = capital - 1.0
	ed["university_autonomy"] = clampf(float(ed.get("university_autonomy", 0.4)) + 0.2, 0.0, 1.0)
	state["education_policy"] = ed
	# واکنش تکنوکرات‌ها
	var factions: Dictionary = state.get("factions", {})
	if factions.has("تکنوکرات‌ها"):
		var f: Dictionary = factions["تکنوکرات‌ها"]
		f["loyalty"] = clampf(float(f.get("loyalty", 50.0)) + 3.0, 0.0, 100.0)
		factions["تکنوکرات‌ها"] = f
		state["factions"] = factions
	return {"success": true, "state": state,
		"events": [{"type": "university_reform", "message": "🎓 اصلاحات دانشگاهی: استقلال دانشگاه‌ها و آزادی علمی افزایش یافت"}]}

func scholarship_program(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var ed: Dictionary = state["education_policy"]
	if float(ed.get("scholarships", 0.2)) >= 0.9:
		return {"success": false, "reason": "پوشش بورس حداکثری است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * 0.003
	state["economy"] = econ
	ed["scholarships"] = clampf(float(ed.get("scholarships", 0.2)) + 0.2, 0.0, 1.0)
	state["education_policy"] = ed
	return {"success": true, "state": state,
		"events": [{"type": "scholarships", "message": "🎓 بورس تحصیلی برای مناطق محروم گسترش یافت؛ استعدادها در کشور می‌مانند"}]}

func digital_education(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var ed: Dictionary = state["education_policy"]
	if float(ed.get("digital_learning", 0.2)) >= 0.95:
		return {"success": false, "reason": "آموزش دیجیتال کامل است", "state": state, "events": []}
	var tech: Dictionary = state.get("technology", {})
	if float(tech.get("branch_levels", {}).get("دیجیتال", 0)) < 8:
		return {"success": false, "reason": "زیرساخت دیجیتال کافی نیست (شاخه دیجیتال ۸+)", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * 0.002
	state["economy"] = econ
	ed["digital_learning"] = clampf(float(ed.get("digital_learning", 0.2)) + 0.2, 0.0, 1.0)
	state["education_policy"] = ed
	return {"success": true, "state": state,
		"events": [{"type": "digital_education", "message": "💻 مدارس هوشمند و آموزش آنلاین سراسری راه‌اندازی شد؛ سواد دیجیتال جهش کرد"}]}
