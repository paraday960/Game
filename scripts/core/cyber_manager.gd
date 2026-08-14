extends Node
# ────────────────────────────────────────────────────────────────────────────
# جنگ سایبری — عمق امنیت دیجیتال
# توان تهاجمی/دفاعی سایبری از شاخه «دیجیتال» و فناوری cyber_defense می‌آید.
# بازیکن: ساخت فایروال (دفاع)، حمله سایبری به دشمن (اقتصاد/زیرساخت/اطلاعات)
# با ریسک افشا (روابط −) و مقابله با حملات دشمن در تنش بالا.
#
# state["cyber"] = { "firewall":0..1, "attribution_risk":0..1, "ops":0,
#   "last_attack":0, "defended":0, "attacks_launched":0 }
# ────────────────────────────────────────────────────────────────────────────

func ensure(state: Dictionary) -> Dictionary:
	if not state.has("cyber"):
		state["cyber"] = {"firewall": 0.4, "attribution_risk": 0.1, "ops": 0, "last_attack": -99, "defended": 0, "attacks_launched": 0}
	return state

func offense_level(state: Dictionary) -> float:
	var tech: Dictionary = state.get("technology", {})
	var digital := float(tech.get("branch_levels", {}).get("دیجیتال", 0))
	var has_ai: bool = tech.get("unlocked", []).has("national_ai")
	return digital * 3.0 + (10.0 if has_ai else 0.0)

func defense_level(state: Dictionary) -> float:
	var tech: Dictionary = state.get("technology", {})
	var digital := float(tech.get("branch_levels", {}).get("دیجیتال", 0))
	var has_cyber: bool = tech.get("unlocked", []).has("cyber_defense")
	return digital * 3.0 + (12.0 if has_cyber else 0.0) + float(state.get("cyber", {}).get("firewall", 0.0)) * 15.0

# ── شبیه‌سازی ماهانه ──
func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var cy: Dictionary = state["cyber"]
	var econ: Dictionary = state.get("economy", {})
	var riv: Dictionary = state.get("rivalry", {})
	var tension := float(riv.get("tension", 40.0))
	var defense := defense_level(state)
	var firewall := float(cy.get("firewall", 0.4))

	# فایروال با گذر زمان کمی فرسوده می‌شود (نگهداری)
	cy["firewall"] = clampf(firewall - 0.005, 0.0, 1.0)

	# حمله دشمن: تنش بالا + توان سایبری دشمن
	var enemy_cyber := tension * 0.02 + 10.0
	var attack_success := enemy_cyber > defense * 1.05 and Deterministic.chance(0.08)
	if attack_success:
		var damage := 0.004 + (enemy_cyber - defense) / 100.0 * 0.01
		econ["gdp"] = float(econ.get("gdp", 1.0)) * (1.0 - damage)
		state.get("infrastructure", {})["telecom"] = clampf(float(state.get("infrastructure", {}).get("telecom", 0.7)) - 0.02, 0.1, 1.0)
		events.append({"type": "cyber_attack_incoming", "message": "💥 حمله سایبری دشمن! زیرساخت دیجیتال آسیب دید و GDP کاهش یافت"})
		cy["defended"] = int(cy.get("defended", 0))
	elif enemy_cyber <= defense * 1.05 and tension > 60 and Deterministic.chance(0.06):
		events.append({"type": "cyber_attack_foiled", "message": "🛡️ حمله سایبری دشمن توسط فایروال دفع شد؛ زیرساخت‌ها امن ماندند"})
		cy["defended"] = int(cy.get("defended", 0)) + 1

	state["cyber"] = cy
	state["economy"] = econ
	return {"state": state, "events": events}

# ── اقدامات بازیکن ──
func build_firewall(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var cy: Dictionary = state["cyber"]
	if float(cy.get("firewall", 0.4)) >= 0.95:
		return {"success": false, "reason": "فایروال حداکثری است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * 0.002
	state["economy"] = econ
	cy["firewall"] = clampf(float(cy.get("firewall", 0.4)) + 0.2, 0.0, 1.0)
	state["cyber"] = cy
	return {"success": true, "state": state,
		"events": [{"type": "firewall_upgrade", "message": "🛡️ سامانه دفاع سایبری ارتقا یافت؛ حملات دشمن سخت‌تر نفوذ می‌کنند"}]}

func cyber_attack(state: Dictionary, target: String, kind: String) -> Dictionary:
	state = ensure(state)
	var offense := offense_level(state)
	if offense < 25.0:
		return {"success": false, "reason": "توان تهاجمی سایبری کافی نیست (شاخه دیجیتال را بالا ببرید)", "state": state, "events": []}
	if not WorldManager.countries.has(target):
		return {"success": false, "reason": "هدف نامعتبر", "state": state, "events": []}
	var world: Dictionary = state.get("world", {})
	var player_id := str(world.get("player_country", WorldManager.default_country))
	if target == player_id:
		return {"success": false, "reason": "نمی‌توان به خود حمله کرد", "state": state, "events": []}
	var relations: Dictionary = state.get("diplomacy", {}).get("relations", {})
	var rel := float(relations.get(target, 50.0))
	if rel > 45.0 and not world.get("wars", {}).has(target):
		return {"success": false, "reason": "حمله سایبری فقط علیه دشمنان (جنگ یا روابط خصمانه)", "state": state, "events": []}
	if not ["economy", "infrastructure", "information"].has(kind):
		return {"success": false, "reason": "نوع حمله نامعتبر", "state": state, "events": []}
	# کول‌داون لچ واقعی (بازرسی latch): last_attack از آغاز init بود ولی هیچ‌وقت نوشته نمی‌شد —
	# حملهٔ تهاجمی هر نوبت قابل اسپم بود (به شرط min_offense). مثل مانورها/سدهای خواهران: ۳ نوبت.
	var turn := int(state.get("time", {}).get("turn", 0))
	var cy: Dictionary = state["cyber"]
	if turn - int(cy.get("last_attack", -99)) < 3:
		return {"success": false, "reason": "حمله سایبری هر ۳ نوبت یک‌بار ممکن است (آماده‌سازی عملیات)", "state": state, "events": []}
	cy["last_attack"] = turn
	# دفاع هدف از سطح فناوری NPC
	var target_tech := float(world.get("countries", {}).get(target, {}).get("tech_level", 0.35))
	var target_defense := target_tech * 30.0
	var success := Deterministic.chance(clampf(0.35 + (offense - target_defense) * 0.02, 0.1, 0.85))
	cy["attacks_launched"] = int(cy.get("attacks_launched", 0)) + 1
	var events: Array = []
	var target_country: Dictionary = world.get("countries", {}).get(target, {})
	if success:
		match kind:
			"economy":
				target_country["gdp"] = maxf(1.0, float(target_country.get("gdp", 1.0)) * 0.97)
				events.append({"type": "cyber_attack_success", "message": "💻 حمله سایبری موفق به %s: اقتصاد آن کشور آسیب دید" % WorldManager.get_country_name(target)})
			"infrastructure":
				target_country["stability"] = clampf(float(target_country.get("stability", 60.0)) - 3.0, 5.0, 100.0)
				events.append({"type": "cyber_attack_success", "message": "💻 حمله سایبری موفق به %s: زیرساخت‌های حیاتی مختل و ثبات آن کشور کاهش یافت" % WorldManager.get_country_name(target)})
			"information":
				target_country["stability"] = clampf(float(target_country.get("stability", 60.0)) - 2.0, 5.0, 100.0)
				events.append({"type": "cyber_attack_success", "message": "💻 عملیات اطلاعاتی سایبری: رسانه‌های %s هک شدند و اعتماد عمومی آن کشور آسیب دید" % WorldManager.get_country_name(target)})
		world["countries"][target] = target_country
		state["world"] = world
	else:
		events.append({"type": "cyber_attack_failed", "message": "💻 حمله سایبری به %s ناکام ماند؛ دفاع سایبری هدف قوی بود" % WorldManager.get_country_name(target)})
	# ریسک افشا
	var attribution := clampf(0.25 + (target_defense - offense) * 0.01 + (0.25 if kind == "infrastructure" else 0.0), 0.05, 0.8)
	cy["attribution_risk"] = attribution
	if Deterministic.chance(attribution):
		if relations.has(target):
			relations[target] = maxf(0.0, rel - 20.0)
			state["diplomacy"]["relations"] = relations
		events.append({"type": "cyber_exposed", "message": "🚨 دست داشتن کشور شما در حمله سایبری به %s فاش شد! روابط به شدت آسیب دید" % WorldManager.get_country_name(target)})
		# واکنش: کشور هدف ممکن است اعلام جنگ کند
		if float(relations.get(target, 50.0)) <= 20.0 and not world.get("wars", {}).has(target):
			world["wars"][target] = {"target": target, "started_tick": int(state.get("tick", 0)), "progress": 0.0, "player_losses": 0, "enemy_losses": 0}
			state["world"] = world
			events.append({"type": "cyber_war", "message": "⚔️ %s در واکنش به حمله سایبری اعلام جنگ کرد!" % WorldManager.get_country_name(target)})
	state["cyber"] = cy
	return {"success": true, "state": state, "events": events}
