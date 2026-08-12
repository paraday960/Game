extends Node
# ────────────────────────────────────────────────────────────────────────────
# سیاست مهاجرت و جمعیت — عمق پویایی جمعیتی
# سیاست مهاجرت (باز/محدود/فقط مهارت‌محور) جریان ورود/خروج را می‌سازد.
# جنگ‌های جهان پناهنده می‌آورند (هزینه رفاه و تنش با پوپولیست‌ها)؛ فرار مغزها
# با بودجه پژوهش مهار می‌شود. مهاجرت نیروی کار و سالخوردگی را جبران می‌کند.
#
# state["migration"] = { "policy":"open"|"restricted"|"skilled", "net":0..±,
#   "refugees":0..1, "brain_drain":0..1, "integration":0..1 }
# ────────────────────────────────────────────────────────────────────────────

func ensure(state: Dictionary) -> Dictionary:
	if not state.has("migration"):
		state["migration"] = {"policy": "restricted", "net": 0.0, "refugees": 0.0, "brain_drain": 0.25, "integration": 0.0}
	return state

# ── شبیه‌سازی ماهانه ──
func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var mig: Dictionary = state["migration"]
	var econ: Dictionary = state.get("economy", {})
	var pop: Dictionary = state.get("population", {})
	var pol: Dictionary = state.get("politics", {})
	var tech: Dictionary = state.get("technology", {})
	var world: Dictionary = state.get("world", {})
	var policy := str(mig.get("policy", "restricted"))
	var unemployment := float(econ.get("unemployment", 0.08))
	var stability := float(pol.get("stability", 0.6))
	var npc_wars: int = world.get("npc_wars", {}).size()
	var refugees := float(mig.get("refugees", 0.0))

	# جریان خالص مهاجرت: سیاست + اقتصاد + ثبات
	var net := 0.0
	match policy:
		"open":
			net = 0.06 + (0.5 - unemployment) * 0.05 + (stability - 0.5) * 0.04
		"restricted":
			net = 0.01 + (stability - 0.5) * 0.02
		"skilled":
			net = 0.03 + (0.5 - unemployment) * 0.03
	net -= float(mig.get("brain_drain", 0.25)) * 0.05
	mig["net"] = clampf(net, -0.1, 0.15)

	# پناهندگان: جنگ‌های NPC + مرز باز
	var refugee_flow := float(npc_wars) * 0.02
	if policy == "open":
		refugee_flow *= 1.5
	refugees = clampf(refugees + refugee_flow - 0.01, 0.0, 1.0)
	mig["refugees"] = refugees

	# فرار مغزها: حقوق پژوهش و ثبات
	var research_budget := float(econ.get("budget_allocations", {}).get("فناوری", 0.04))
	var brain := float(mig.get("brain_drain", 0.25))
	brain += (0.5 - research_budget * 8.0) * 0.01 + (0.5 - stability) * 0.01
	mig["brain_drain"] = clampf(brain, 0.0, 0.9)

	# اثرها
	var pop_growth := net * 0.005
	pop["total"] = maxf(1_000_000.0, float(pop.get("total", 85_000_000.0)) * (1.0 + pop_growth))
	# نیروی کار: مهاجرت بیکاری را کمی تغییر می‌دهد
	econ["unemployment"] = clampf(unemployment - net * 0.1, 0.02, 0.30)
	# پناهندگان: هزینه رفاه + تنش اجتماعی (پوپولیست‌ها)
	econ["refugee_cost"] = refugees * 0.001
	if refugees > 0.4 and Deterministic.chance(0.1):
		pol["stability"] = clampf(stability - 0.02, 0.05, 1.0)
		events.append({"type": "refugee_tension", "message": "⚠️ فشار پناهندگان تنش اجتماعی ایجاد کرد؛ پوپولیست‌ها علیه دولت شعار می‌دهند"})
	# فرار مغزها: پژوهشگران
	tech["researchers"] = maxf(1000.0, float(tech.get("researchers", 50000.0)) * (1.0 - float(mig.get("brain_drain", 0.25)) * 0.01))
	# ادغام پناهندگان: نیروی کار تازه
	var integration := float(mig.get("integration", 0.0))
	if integration > 0.5:
		econ["gdp"] = float(econ.get("gdp", 1.0)) * 1.002
		mig["integration"] = clampf(integration - 0.02, 0.0, 1.0)

	state["migration"] = mig
	state["economy"] = econ
	state["population"] = pop
	state["politics"] = pol
	state["technology"] = tech
	return {"state": state, "events": events}

# ── اقدامات بازیکن ──
func set_policy(state: Dictionary, policy: String) -> Dictionary:
	state = ensure(state)
	if not ["open", "restricted", "skilled"].has(policy):
		return {"success": false, "reason": "سیاست نامعتبر", "state": state, "events": []}
	var mig: Dictionary = state["migration"]
	mig["policy"] = policy
	state["migration"] = mig
	var names := {"open": "باز", "restricted": "محدود", "skilled": "فقط مهارت‌محور"}
	return {"success": true, "state": state,
		"events": [{"type": "migration_policy", "message": "🌍 سیاست مهاجرت به «%s» تغییر کرد" % names[policy]}]}

func integration_program(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var mig: Dictionary = state["migration"]
	if float(mig.get("integration", 0.0)) >= 0.95:
		return {"success": false, "reason": "برنامه ادغام کامل است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * 0.003
	state["economy"] = econ
	mig["integration"] = clampf(float(mig.get("integration", 0.0)) + 0.3, 0.0, 1.0)
	state["migration"] = mig
	return {"success": true, "state": state,
		"events": [{"type": "integration_program", "message": "🤝 برنامه ادغام پناهندگان: آموزش زبان و مهارت آغاز شد؛ نیروی کار آینده تقویت می‌شود"}]}

func stem_brain_drain(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var mig: Dictionary = state["migration"]
	var econ: Dictionary = state.get("economy", {})
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * 0.002
	econ["budget_allocations"]["فناوری"] = clampf(float(econ["budget_allocations"].get("فناوری", 0.04)) + 0.01, 0.0, 0.5)
	state["economy"] = econ
	mig["brain_drain"] = clampf(float(mig.get("brain_drain", 0.25)) - 0.08, 0.0, 0.9)
	state["migration"] = mig
	return {"success": true, "state": state,
		"events": [{"type": "brain_drain_stem", "message": "🎓 بسته حمایت از نخبگان: حقوق پژوهشگران و بودجه دانشگاه‌ها افزایش یافت؛ فرار مغزها کاهش یافت"}]}
