extends Node
# ────────────────────────────────────────────────────────────────────────────
# سیاست انرژی و اقلیم — عمق انرژی
# ترکیب انرژی کشور (فسیلی/هسته‌ای/تجدیدپذیر/برق‌آبی)، امنیت انرژی، یارانه‌ها و
# تلاش اقلیمی. یارانه بالا رضایت می‌آورد ولی بودجه را می‌سوزاند؛ وابستگی به
# واردات و قیمت جهانی نفت امنیت را تکان می‌دهد؛ خاموشی‌ها (قطع برق) به GDP و
# رضایت آسیب می‌زنند. فناوری «انرژی پاک» سرمایه‌گذاری سبز را ارزان‌تر می‌کند.
#
# state["energy"] = { "mix": {fossil,nuclear,renewable,hydro}, "security":0..1,
#   "subsidies":0..1, "climate_effort":0..1, "blackout_risk":0..1, "emissions":0..1 }
# ────────────────────────────────────────────────────────────────────────────

func ensure(state: Dictionary) -> Dictionary:
	if not state.has("energy_policy"):
		state["energy_policy"] = {
			"mix": {"fossil": 0.72, "nuclear": 0.03, "renewable": 0.12, "hydro": 0.13},
			"security": 0.62, "subsidies": 0.45, "climate_effort": 0.2,
			"blackout_risk": 0.1, "emissions": 0.7
		}
	return state

func _mix_sum(state: Dictionary) -> float:
	var mix: Dictionary = state["energy_policy"].get("mix", {})
	var total := 0.0
	for v in mix.values():
		total += float(v)
	return max(total, 0.001)

# ── شبیه‌سازی ماهانه ──
func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var en: Dictionary = state["energy_policy"]
	var econ: Dictionary = state.get("economy", {})
	var pop: Dictionary = state.get("population", {})
	var pol: Dictionary = state.get("politics", {})
	var tech: Dictionary = state.get("technology", {})
	var com: Dictionary = state.get("commodities", {})
	var mix: Dictionary = en.get("mix", {})
	var fossil := float(mix.get("fossil", 0.7))
	var renewable := float(mix.get("renewable", 0.1))
	var nuclear := float(mix.get("nuclear", 0.05))
	var oil_price := float(com.get("prices", {}).get("نفت", 75.0))
	var subsidies := float(en.get("subsidies", 0.45))
	var green_tech := float(tech.get("branches", {}).get("انرژی_پاک", 0.15))
	var climate_effort := float(en.get("climate_effort", 0.2))

	# امنیت انرژی: تنوع + تولید داخلی − وابستگی به واردات − قیمت نفت بالا
	var diversity := 1.0 - (absf(fossil - 0.5) * 0.6 + absf(renewable - 0.25) * 0.4)
	var import_dependence := maxf(0.0, fossil * 0.5 - nuclear * 0.2 - renewable * 0.1)
	var security := diversity * 0.5 + (1.0 - import_dependence) * 0.3 + (0.8 - (oil_price - 75.0) / 200.0) * 0.2
	en["security"] = clampf(security, 0.05, 1.0)

	# ریسک خاموشی: امنیت پایین + یارانه بالا (مصرف بی‌رویه)
	en["blackout_risk"] = clampf((1.0 - float(en["security"])) * 0.6 + subsidies * 0.2, 0.0, 1.0)
	if float(en["blackout_risk"]) > 0.7 and Deterministic.chance(0.25):
		econ["gdp"] = float(econ.get("gdp", 1.0)) * 0.995
		pop["happiness"] = clampf(float(pop.get("happiness", 0.6)) - 0.02, 0.05, 1.0)
		events.append({"type": "blackout", "message": "⚡ خاموشی سراسری! شبکه برق ناپایدار شد؛ تولید و رضایت آسیب دید"})

	# هزینه یارانه: بودجه را می‌سوزاند؛ در قیمت بالای نفت سنگین‌تر
	var subsidy_cost := subsidies * (0.6 + (oil_price - 75.0) / 200.0) * 0.02
	econ["subsidy_cost"] = subsidy_cost
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * subsidy_cost / 12.0

	# انتشار کربن: از فسیلی و تلاش اقلیمی
	en["emissions"] = clampf(fossil * 0.9 - climate_effort * 0.5, 0.05, 1.0)

	# فناوری سبز به‌تدریج سبد را تغییر می‌دهد
	if green_tech > 0.3:
		var shift := (green_tech - 0.3) * 0.004
		mix["renewable"] = clampf(renewable + shift, 0.0, 0.8)
		mix["fossil"] = clampf(fossil - shift, 0.05, 0.95)
		en["mix"] = mix
	state["energy_policy"] = en
	state["economy"] = econ
	state["population"] = pop
	state["politics"] = pol
	return {"state": state, "events": events}

# ── اقدامات بازیکن ──
func invest_renewable(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var en: Dictionary = state["energy_policy"]
	var mix: Dictionary = en.get("mix", {})
	var green_tech := float(state.get("technology", {}).get("branches", {}).get("انرژی_پاک", 0.15))
	var cost := 0.004 - green_tech * 0.002  # فناوری سبز سرمایه‌گذاری را ارزان می‌کند
	mix["renewable"] = clampf(float(mix.get("renewable", 0.1)) + 0.06, 0.0, 0.8)
	mix["fossil"] = clampf(float(mix.get("fossil", 0.7)) - 0.05, 0.05, 0.95)
	en["mix"] = mix
	en["climate_effort"] = clampf(float(en.get("climate_effort", 0.2)) + 0.05, 0.0, 1.0)
	state["energy_policy"] = en
	var econ: Dictionary = state.get("economy", {})
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * cost
	state["economy"] = econ
	return {"success": true, "state": state,
		"events": [{"type": "renewable_invest", "message": "🌱 سرمایه‌گذاری بزرگ در انرژی تجدیدپذیر آغاز شد؛ سهم سبز در سبد انرژی بالا رفت"}]}

func invest_nuclear(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var en: Dictionary = state["energy_policy"]
	var mix: Dictionary = en.get("mix", {})
	mix["nuclear"] = clampf(float(mix.get("nuclear", 0.05)) + 0.04, 0.0, 0.5)
	mix["fossil"] = clampf(float(mix.get("fossil", 0.7)) - 0.03, 0.05, 0.95)
	en["mix"] = mix
	state["energy_policy"] = en
	var econ: Dictionary = state.get("economy", {})
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * 0.006
	state["economy"] = econ
	return {"success": true, "state": state,
		"events": [{"type": "nuclear_invest", "message": "☢️ ساخت نیروگاه هسته‌ای جدید آغاز شد؛ وابستگی به سوخت فسیلی کم می‌شود"}]}

func reform_subsidies(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var en: Dictionary = state["energy_policy"]
	var subsidies := float(en.get("subsidies", 0.45))
	if subsidies < 0.1:
		return {"success": false, "reason": "یارانه انرژی تقریباً حذف شده است", "state": state, "events": []}
	en["subsidies"] = clampf(subsidies - 0.15, 0.0, 1.0)
	state["energy_policy"] = en
	var econ: Dictionary = state.get("economy", {})
	econ["inflation"] = clampf(float(econ.get("inflation", 0.08)) + 0.01, 0.0, 1.5)
	var pop: Dictionary = state.get("population", {})
	pop["happiness"] = clampf(float(pop.get("happiness", 0.6)) - 0.02, 0.05, 1.0)
	state["economy"] = econ
	state["population"] = pop
	return {"success": true, "state": state,
		"events": [{"type": "subsidy_reform", "message": "⚡ اصلاح یارانه انرژی: بودجه سبک‌تر شد ولی قیمت حامل‌ها و نارضایتی بالا رفت"}]}

func climate_pledge(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var en: Dictionary = state["energy_policy"]
	en["climate_effort"] = clampf(float(en.get("climate_effort", 0.2)) + 0.15, 0.0, 1.0)
	state["energy_policy"] = en
	var leader: Dictionary = state.get("leader", {})
	leader["popularity_world"] = clampf(float(leader.get("popularity_world", 50.0)) + 3.0, 0.0, 100.0)
	state["leader"] = leader
	var econ: Dictionary = state.get("economy", {})
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * 0.003
	state["economy"] = econ
	return {"success": true, "state": state,
		"events": [{"type": "climate_pledge", "message": "🌍 تعهد اقلیمی تازه: کشور به کاهش انتشار کربن متعهد شد و در جهان درخشید"}]}
