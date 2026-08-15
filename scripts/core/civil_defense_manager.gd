extends Node
# ────────────────────────────────────────────────────────────────────────────
# پدافند غیرعامل و تاب‌آوری ملی — عمق دفاع بدون شلیک
# برخلاف ارتش که قدرت رزمی می‌سازد، پدافند غیرعامل آسیب‌پذیری زیرساخت‌های حیاتی
# (برق، آب، مخابرات، پالایش، سایبر، بهداشت) را در برابر حمله، خرابکاری،
# بمباران و بحران کاهش می‌دهد. پراکندگی، پناهگاه، ذخیره راهبردی، تمرین و
# سخت‌سازی هدف‌ها خسارت جنگ را کم می‌کند. پیوند: ارتش، انرژی، آب، مخابرات،
# بهداشت، امداد، امنیت، اقتصاد.
#
# state["civil_defense_policy"] = {
#   "hardening":0..1, "redundancy":0..1, "shelters":0..1,
#   "strategic_stock":0..1, "drills":0..1, "last_drill":turn,
#   "resilience_index":0..1, "last_hardening":turn }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("civil_defense_policy"):
		state["civil_defense_policy"] = {
			"hardening": 0.25, "redundancy": 0.20, "shelters": 0.20,
			"strategic_stock": 0.30, "drills": 0.20, "last_drill": -99,
			"resilience_index": 0.30, "last_hardening": -99,
			"civilian_protection": 0.30
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var cd: Dictionary = state["civil_defense_policy"]
	var mil: Dictionary = state.get("military", {})
	var em: Dictionary = state.get("emergency", {})
	var resources: Dictionary = state.get("resources", {})
	var infra: Dictionary = state.get("infrastructure", {})
	var econ: Dictionary = state.get("economy", {})
	var pop: Dictionary = state.get("population", {})

	var hardening := float(cd.get("hardening", 0.25))
	var redundancy := float(cd.get("redundancy", 0.20))
	var shelters := float(cd.get("shelters", 0.20))
	var stock := float(cd.get("strategic_stock", 0.30))
	var drills := float(cd.get("drills", 0.20))
	var gdp := float(econ.get("gdp", 1.0))

	# شاخص تاب‌آوری ترکیبی
	var resilience := clampf(
		0.10 + hardening * 0.22 + redundancy * 0.22 + shelters * 0.18 +
		stock * 0.16 + drills * 0.12 + float(em.get("preparedness", 0.50)) * 0.10,
		0.05, 0.98)
	cd["resilience_index"] = resilience
	cd["civilian_protection"] = clampf(
		0.15 + shelters * 0.35 + drills * 0.20 + hardening * 0.18 +
		float(em.get("preparedness", 0.50)) * 0.12, 0.05, 0.98)

	# بازدارندگی: پدافند خوب هزینه حمله به کشور را بالا می‌برد
	mil["deterrence"] = clampf(float(mil.get("deterrence", 60.0)) + resilience * 1.2, 0.0, 100.0)
	mil["readiness"] = clampf(float(mil.get("readiness", 0.70)) + drills * 0.002, 0.05, 1.0)
	state["military"] = mil

	# کاهش تلفات و خسارت در درگیری (سیگنال به سامانه جنگ): در صورت جنگ،
	# resilience تلفات را می‌کاهد. اینجا یک بافر آماده می‌کنیم.
	cd["damage_mitigation"] = resilience

	# آمادگی امدادی بهتر
	em["preparedness"] = clampf(float(em.get("preparedness", 0.50)) + drills * 0.002, 0.1, 1.0)
	em["response_time"] = clampf(float(em.get("response_time", 10.0)) - drills * 0.02, 2.0, 60.0)
	state["emergency"] = em

	# افزونگی زیرساخت از خرابی آبشاری جلوگیری می‌کند
	infra["quality"] = clampf(float(infra.get("quality", 0.55)) + redundancy * 0.001, 0.1, 1.0)
	state["infrastructure"] = infra

	# هزینه نگهداری مستمر پدافند
	var cost := gdp * (0.0015 + hardening * 0.002 + redundancy * 0.0015 + shelters * 0.001)
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + cost
	state["economy"] = econ

	# رویدادها: تمرین سراسری و حفظ آمادگی
	if drills > 0.50 and Deterministic.chance(0.030):
		em["response_time"] = clampf(float(em.get("response_time", 10.0)) - 0.5, 2.0, 60.0)
		state["emergency"] = em
		events.append({"type": "cd_drill", "message": "🚨 مانور سراسری پدافند غیرعامل برگزار شد؛ هماهنگی دستگاه‌ها و واکنش اضطراری بهتر شد"})
	elif resilience < 0.30 and Deterministic.chance(0.030):
			var em_gap: Dictionary = state.get("emergency", {})
			em_gap["preparedness"] = clampf(float(em_gap.get("preparedness", 0.50)) - 0.01, 0.1, 0.95)
			state["emergency"] = em_gap
			events.append({"type": "cd_gap", "message": "⚠️ آسیب‌پذیری زیرساخت‌های حیاتی بالا است؛ یک حمله محدود می‌تواند به اختلال گسترده بینجامد"})
	elif resilience > 0.70 and Deterministic.chance(0.020):
		mil["deterrence"] = clampf(float(mil.get("deterrence", 60.0)) + 0.5, 0.0, 100.0)
		state["military"] = mil
		events.append({"type": "cd_resilient", "message": "🛡️ پراکندگی و سخت‌سازی هدف‌ها، هزینه تهاجم احتمالی را بالا برد؛ بازدارندگی رشد کرد"})

	# ذخیره راهبردی: در فشار بالا، ضربه‌گیر خاموشی/کمبود است
	if stock > 0.50 and resources.has("inventory"):
		resources["inventory"]["برق"] = clampf(float(resources["inventory"].get("برق", 100.0)) + stock * 0.2, 0.0, 150.0)
		resources["inventory"]["غذا"] = clampf(float(resources["inventory"].get("غذا", 85.0)) + stock * 0.2, 0.0, 150.0)
		state["resources"] = resources

	state["civil_defense_policy"] = cd
	pop["happiness"] = clampf(float(pop.get("happiness", 0.60)) - cost / gdp * 0.02 + resilience * 0.001, 0.05, 1.0)
	state["population"] = pop
	return {"state": state, "events": events}

# ── سخت‌سازی هدف‌های حیاتی ──
func harden_targets(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var cd: Dictionary = state["civil_defense_policy"]
	if turn - int(cd.get("last_hardening", -99)) < 6:
		return {"success": false, "reason": "پروژه سخت‌سازی هر ۶ نوبت یک بار ممکن است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.008
	cd["last_hardening"] = turn
	cd["hardening"] = clampf(float(cd.get("hardening", 0.25)) + 0.12, 0.0, 1.0)
	state["economy"] = econ
	state["civil_defense_policy"] = cd
	return {"success": true, "state": state,
		"events": [{"type": "hardening", "message": "🏗️ سخت‌سازی نیروگاه‌ها، پالایشگاه‌ها و مراکز مخابراتی در برابر حمله انجام شد"}]}

# ── افزونگی و پراکندگی زیرساخت ──
func build_redundancy(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var cd: Dictionary = state["civil_defense_policy"]
	if float(cd.get("redundancy", 0.20)) >= 0.95:
		return {"success": false, "reason": "افزونگی زیرساخت در سقف ممکن است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.007
	cd["redundancy"] = clampf(float(cd.get("redundancy", 0.20)) + 0.13, 0.0, 1.0)
	var infra: Dictionary = state.get("infrastructure", {})
	infra["capacity"] = clampf(float(infra.get("capacity", 0.60)) + 0.01, 0.1, 1.0)
	state["economy"] = econ
	state["infrastructure"] = infra
	state["civil_defense_policy"] = cd
	return {"success": true, "state": state,
		"events": [{"type": "redundancy", "message": "🔀 افزونگی و پراکندگی به شبکه برق، گاز و داده اضافه شد؛ اختلال نقطه‌ای دیگر کل کشور را زمین‌گیر نمی‌کند"}]}

# ── توسعه پناهگاه و حفاظت غیرنظامی ──
func build_shelters(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var cd: Dictionary = state["civil_defense_policy"]
	if float(cd.get("shelters", 0.20)) >= 0.95:
		return {"success": false, "reason": "پوشش پناهگاه در سقف ممکن است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.005
	cd["shelters"] = clampf(float(cd.get("shelters", 0.20)) + 0.13, 0.0, 1.0)
	state["media"]["groups"]["شهرنشینان"]["approval"] = clampf(float(state["media"]["groups"]["شهرنشینان"].get("approval", 55.0)) + 1.0, 5.0, 100.0)
	state["economy"] = econ
	state["civil_defense_policy"] = cd
	return {"success": true, "state": state,
		"events": [{"type": "shelters", "message": "🏚️ پناهگاه‌ها و مسیرهای تخلیه در شهرها توسعه یافت؛ حفاظت از غیرنظامیان بهتر شد"}]}

# ── ذخیره راهبردی و مانور ──
func strategic_stockpile(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var cd: Dictionary = state["civil_defense_policy"]
	if float(cd.get("strategic_stock", 0.30)) >= 0.95:
		return {"success": false, "reason": "ذخیره راهبردی در سقف ممکن است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.006
	cd["strategic_stock"] = clampf(float(cd.get("strategic_stock", 0.30)) + 0.13, 0.0, 1.0)
	var resources: Dictionary = state.get("resources", {})
	if resources.has("inventory"):
		resources["inventory"]["غذا"] = clampf(float(resources["inventory"].get("غذا", 85.0)) + 8.0, 0.0, 150.0)
		resources["inventory"]["برق"] = clampf(float(resources["inventory"].get("برق", 100.0)) + 4.0, 0.0, 150.0)
		state["resources"] = resources
	state["economy"] = econ
	state["civil_defense_policy"] = cd
	return {"success": true, "state": state,
		"events": [{"type": "stockpile", "message": "📦 ذخیره راهبردی غذا، دارو، سوخت و قطعات حساس افزایش یافت؛ کشور در برابر محاصره مقاوم‌تر شد"}]}
