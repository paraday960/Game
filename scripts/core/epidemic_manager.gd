extends Node
# ────────────────────────────────────────────────────────────────────────────
# پاندمی و بهداشت عمومی — عمق سلامت جامعه
# شیوع بیماری با کیفیت بهداشت، تراکم شهری، باز بودن مرزها و فصل رشد می‌کند.
# بازیکن: قرنطینه (سبک/سنگین)، کمپین واکسیناسیون (نیازمند فناوری پزشکی)،
# بودجه اضطراری بیمارستان. هر تصمیم هزینه اقتصادی/رضایت دارد.
#
# state["epidemic"] = { "status":"normal"|"outbreak"|"pandemic", "spread":0..1,
#   "lockdown":0|1|2, "vaccination":0..1, "vaccinated":0..1, "deaths":0,
#   "hospital_bonus":0..1 }
# ────────────────────────────────────────────────────────────────────────────

func ensure(state: Dictionary) -> Dictionary:
	if not state.has("epidemic"):
		state["epidemic"] = {
			"status": "normal", "spread": 0.05, "lockdown": 0,
			"vaccination": 0.0, "vaccinated": 0.0, "deaths": 0, "hospital_bonus": 0.0
		}
	return state

# ── شبیه‌سازی ماهانه ──
func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var ep: Dictionary = state["epidemic"]
	var econ: Dictionary = state.get("economy", {})
	var pop: Dictionary = state.get("population", {})
	var health: Dictionary = state.get("health", {})
	var tech: Dictionary = state.get("technology", {})
	var migration: Dictionary = state.get("migration", {})
	var spread := float(ep.get("spread", 0.05))
	var lockdown := int(ep.get("lockdown", 0))
	var vaccinated := float(ep.get("vaccinated", 0.0))
	var health_q := float(health.get("quality", 0.6))
	var urban := float(pop.get("urbanization", 0.72))
	var borders_open := str(migration.get("policy", "open")) != "restricted"
	var season := str(state.get("time", {}).get("season", "بهار"))

	# رشد شیوع: بهداشت ضعیف + تراکم + مرز باز + زمستان
	var growth := (1.0 - health_q) * 0.05 + urban * 0.02 + (0.03 if borders_open else -0.01)
	if season == "زمستان":
		growth += 0.02
	growth -= vaccinated * 0.06
	growth -= float(lockdown) * 0.05
	spread = clampf(spread + growth, 0.0, 1.0)

	# وضعیت
	var status := "normal"
	if spread > 0.25:
		status = "outbreak"
	if spread > 0.55:
		status = "pandemic"
	var status_changed := status != str(ep.get("status", "normal"))
	ep["status"] = status
	ep["spread"] = spread

	# تلفات: شیوع × (بهداشت − بیمارستان − واکسن − قرنطینه)
	var hospital := float(ep.get("hospital_bonus", 0.0))
	var death_rate := spread * (1.0 - health_q * 0.6 - hospital * 0.4 - vaccinated * 0.7 - float(lockdown) * 0.2)
	var deaths := int(maxf(0.0, death_rate) * 15000.0 * Deterministic.next_range(0.7, 1.3))
	ep["deaths"] = int(ep.get("deaths", 0)) + deaths
	pop["total"] = maxf(1_000_000.0, float(pop.get("total", 85_000_000.0)) - deaths)
	pop["happiness"] = clampf(float(pop.get("happiness", 0.6)) - deaths / 1_000_000.0 - spread * 0.01, 0.05, 1.0)

	# اقتصاد: قرنطینه و شیوع تولید را می‌شکنند
	var econ_hit := spread * 0.01 + float(lockdown) * 0.012
	econ["gdp"] = float(econ.get("gdp", 1.0)) * (1.0 - econ_hit)
	econ["unemployment"] = clampf(float(econ.get("unemployment", 0.08)) + econ_hit * 0.5, 0.02, 0.30)
	# بازگشت اقتصاد پس از فروکش
	if spread < 0.15 and lockdown == 0:
		econ["gdp"] = float(econ.get("gdp", 1.0)) * 1.004

	# رویدادها
	if status_changed and status != "normal":
		var msg := "🦠 شیوع بیماری به «%s» رسید" % ("همه‌گیری" if status == "pandemic" else "شکست کنترل")
		events.append({"type": "epidemic_status", "status": status, "message": msg})
	if deaths > 5000 and Deterministic.chance(0.5):
		events.append({"type": "epidemic_deaths", "message": "☠️ تلفات بیماری این ماه: %s نفر" % PersianFormatter.to_persian_digits(str(deaths))})
	# واکسیناسیون خودکار با فناوری پزشکی بالا
	var med_level := float(tech.get("branch_levels", {}).get("پزشکی", 0))
	if med_level >= 15 and vaccinated < 0.9 and spread > 0.1:
		var prog := 0.03 + med_level * 0.002
		ep["vaccination"] = clampf(float(ep.get("vaccination", 0.0)) + prog, 0.0, 1.0)
		if float(ep["vaccination"]) >= 1.0:
			ep["vaccinated"] = clampf(float(ep.get("vaccinated", 0.0)) + 0.15, 0.0, 1.0)
			ep["vaccination"] = 0.0
			events.append({"type": "auto_vaccination", "message": "💉 کارخانه واکسن داخلی فعال شد؛ پوشش واکسیناسیون بالا رفت"})
	# فروکش طبیعی
	if spread < 0.08 and status == "normal":
		ep["lockdown"] = 0

	state["epidemic"] = ep
	state["economy"] = econ
	state["population"] = pop
	return {"state": state, "events": events}

# ── اقدامات بازیکن ──
func set_lockdown(state: Dictionary, level: int) -> Dictionary:
	state = ensure(state)
	if level < 0 or level > 2:
		return {"success": false, "reason": "سطح قرنطینه نامعتبر (۰ تا ۲)", "state": state, "events": []}
	var ep: Dictionary = state["epidemic"]
	ep["lockdown"] = level
	state["epidemic"] = ep
	var names := ["لغو قرنطینه", "قرنطینه سبک", "قرنطینه سنگین"]
	return {"success": true, "state": state,
		"events": [{"type": "lockdown", "message": "🚧 «%s» اعلام شد؛ شیوع مهار می‌شود ولی اقتصاد و رضایت آسیب می‌بینند" % names[level]}]}

func vaccination_campaign(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var tech: Dictionary = state.get("technology", {})
	var med_level := float(tech.get("branch_levels", {}).get("پزشکی", 0))
	if med_level < 10:
		return {"success": false, "reason": "فناوری پزشکی برای واکسن کافی نیست (سطح ۱۰+ لازم است)", "state": state, "events": []}
	var ep: Dictionary = state["epidemic"]
	if float(ep.get("vaccination", 0.0)) >= 1.0:
		return {"success": false, "reason": "کمپین واکسیناسیون در حال اجراست", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * 0.004
	state["economy"] = econ
	ep["vaccination"] = clampf(float(ep.get("vaccination", 0.0)) + 0.35, 0.0, 1.0)
	state["epidemic"] = ep
	return {"success": true, "state": state,
		"events": [{"type": "vaccination", "message": "💉 کمپین واکسیناسیون سراسری آغاز شد (پیشرفت %s٪)" % PersianFormatter.to_persian_digits(str(int(float(ep["vaccination"]) * 100.0)))}]}

func emergency_hospitals(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var ep: Dictionary = state["epidemic"]
	if float(ep.get("hospital_bonus", 0.0)) >= 0.9:
		return {"success": false, "reason": "ظرفیت بیمارستانی حداکثری است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * 0.005
	state["economy"] = econ
	ep["hospital_bonus"] = clampf(float(ep.get("hospital_bonus", 0.0)) + 0.25, 0.0, 1.0)
	state["epidemic"] = ep
	return {"success": true, "state": state,
		"events": [{"type": "emergency_hospitals", "message": "🏥 بیمارستان‌های صحرایی و تخت‌های اضطراری فعال شدند؛ تلفات کاهش می‌یابد"}]}
