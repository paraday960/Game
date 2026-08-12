extends Node
# ────────────────────────────────────────────────────────────────────────────
# امنیت داخلی — عمق نظم و آزادی
# سیاست پلیس (آزادی مدنی/نظارت/سختگیرانه)، مبارزه با قاچاق، پلیس محله و
# نوسازی نیروی پلیس. امنیت بالا جرم را می‌کاهد ولی آزادی مدنی و رسانه را
# می‌آزارد. پیوند: قوه قضائیه، رسانه، شهرنشینان، اقتصاد سایه.
#
# state["security_policy"] = { "mode":"civil"|"surveillance"|"tough",
#   "anti_smuggling":0..1, "community_police":0..1, "police_modern":0..1,
#   "crime":0..1 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("security_policy"):
		state["security_policy"] = {"mode": "civil", "anti_smuggling": 0.3, "community_police": 0.3, "police_modern": 0.3, "crime": 0.35}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var sp: Dictionary = state["security_policy"]
	var econ: Dictionary = state.get("economy", {})
	var pol: Dictionary = state.get("politics", {})
	var shadow: Dictionary = state.get("shadow", {})
	var mode := str(sp.get("mode", "civil"))
	var crime := float(sp.get("crime", 0.35))
	var anti := float(sp.get("anti_smuggling", 0.3))
	var community := float(sp.get("community_police", 0.3))
	var modern := float(sp.get("police_modern", 0.3))

	# جرم: بیکاری + فساد + اقتصاد سایه − پلیس
	var unemployment := float(econ.get("unemployment", 0.08))
	var corruption := float(pol.get("corruption", 0.3))
	var shadow_size := float(shadow.get("size", 0.18))
	crime = clampf(crime + unemployment * 0.06 + corruption * 0.03 + shadow_size * 0.03 - anti * 0.025 - community * 0.02 - modern * 0.015, 0.05, 0.95)
	sp["crime"] = crime

	# اثر حالت پلیس
	var freedom := 1.0
	match mode:
		"civil":
			freedom = 1.0
			crime = clampf(crime + 0.004, 0.05, 0.95)
		"surveillance":
			freedom = 0.75
			crime = clampf(crime - 0.010, 0.05, 0.95)
		"tough":
			freedom = 0.55
			crime = clampf(crime - 0.020, 0.05, 0.95)
	sp["crime"] = crime

	# امنیت عمومی = ۱ − جرم
	state["security"]["public_security"] = clampf(1.0 - crime, 0.1, 0.98)
	# آزادی مدنی: رسانه و قوه قضائیه
	state["media"]["trust"] = clampf(float(state.get("media", {}).get("trust", 0.55)) + (freedom - 0.85) * 0.01, 0.05, 1.0)
	var jud: Dictionary = state.get("judiciary", {})
	jud["independence"] = clampf(float(jud.get("independence", 0.55)) + (freedom - 0.85) * 0.01, 0.05, 1.0)
	state["judiciary"] = jud
	# جرم پایین → سرمایه‌گذاری و رضایت شهرنشینان
	if crime < 0.2:
		econ["foreign_investment"] = float(econ.get("foreign_investment", 1.0)) * 1.001
	state["media"]["groups"]["شهرنشینان"]["approval"] = clampf(float(state["media"]["groups"]["شهرنشینان"].get("approval", 55.0)) - crime * 2.0, 5.0, 100.0)
	state["security_policy"] = sp
	state["economy"] = econ
	state["politics"] = pol
	return {"state": state, "events": events}

func police_mode(state: Dictionary, mode: String) -> Dictionary:
	state = ensure(state)
	if not ["civil", "surveillance", "tough"].has(mode):
		return {"success": false, "reason": "حالت نامعتبر", "state": state, "events": []}
	var sp: Dictionary = state["security_policy"]
	sp["mode"] = mode
	state["security_policy"] = sp
	var names := {"civil": "آزادی‌محور", "surveillance": "نظارتی", "tough": "سختگیرانه"}
	return {"success": true, "state": state,
		"events": [{"type": "police_mode", "message": "👮 سیاست پلیس به «%s» تغییر کرد؛ جرم و آزادی مدنی به‌هم‌راه تغییر می‌کنند" % names[mode]}]}

func anti_smuggling(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["security_policy"]
	if float(sp.get("anti_smuggling", 0.3)) >= 0.95:
		return {"success": false, "reason": "مبارزه با قاچاق حداکثری است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * 0.002
	state["economy"] = econ
	sp["anti_smuggling"] = clampf(float(sp.get("anti_smuggling", 0.3)) + 0.2, 0.0, 1.0)
	state["security_policy"] = sp
	# کاهش اقتصاد سایه
	var shadow: Dictionary = state.get("shadow", {})
	shadow["size"] = clampf(float(shadow.get("size", 0.18)) - 0.02, 0.03, 0.55)
	state["shadow"] = shadow
	return {"success": true, "state": state,
		"events": [{"type": "anti_smuggling", "message": "🚔 مبارزه با قاچاق کالا تشدید شد؛ اقتصاد سایه و قاچاق سوخت کاهش یافت"}]}

func community_police(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["security_policy"]
	if float(sp.get("community_police", 0.3)) >= 0.95:
		return {"success": false, "reason": "شبکه پلیس محله کامل است", "state": state, "events": []}
	sp["community_police"] = clampf(float(sp.get("community_police", 0.3)) + 0.2, 0.0, 1.0)
	state["security_policy"] = sp
	# اعتماد مردم به پلیس بالا
	state["politics"]["trust"] = clampf(float(state["politics"].get("trust", 0.55)) + 0.02, 0.05, 1.0)
	return {"success": true, "state": state,
		"events": [{"type": "community_police", "message": "👮 پلیس محله در محلات مستقر شد؛ اعتماد عمومی و پیشگیری از جرم بهبود یافت"}]}

func police_modernization(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["security_policy"]
	if float(sp.get("police_modern", 0.3)) >= 0.95:
		return {"success": false, "reason": "نوسازی پلیس کامل است", "state": state, "events": []}
	var tech: Dictionary = state.get("technology", {})
	if float(tech.get("branch_levels", {}).get("دیجیتال", 0)) < 6:
		return {"success": false, "reason": "فناوری دیجیتال کافی نیست (سطح ۶+)", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * 0.003
	state["economy"] = econ
	sp["police_modern"] = clampf(float(sp.get("police_modern", 0.3)) + 0.2, 0.0, 1.0)
	state["security_policy"] = sp
	return {"success": true, "state": state,
		"events": [{"type": "police_modern", "message": "💻 پلیس هوشمند: دوربین‌های تحلیل‌گر، آزمایشگاه جنایی و پلیس سایبری راه‌اندازی شد"}]}
