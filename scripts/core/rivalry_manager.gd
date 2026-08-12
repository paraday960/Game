extends Node
# ────────────────────────────────────────────────────────────────────────────
# رقابت قدرت‌های بزرگ — عمق ژئوپلیتیک
# «تنش بلوکی» (۰ تا ۱۰۰) میان بلوک غربی و اوراسیا: جنگ‌ها و رقابت NPC آن را
# بالا می‌برند و دیپلماسی کاهش می‌دهد. تنش بالا → مسابقه تسلیحاتی جهان و خطر
# جنگ‌های بیشتر؛ بازیکن می‌تواند تنش‌زدایی یا تشدید کند. بحران‌های منطقه‌ای
# رویداد تصمیم می‌سازند که موضع بازیکن روابط با بلوک‌ها را تغییر می‌دهد.
#
# state["rivalry"] = { "tension": 0..100, "arms_race": 0..1, "crisis": {..} | {} }
# ────────────────────────────────────────────────────────────────────────────

const CRISES := [
	{"id": "strait_blockade", "title": "بحران تنگه راهبردی", "desc": "یک قدرت بزرگ کشتیرانی در تنگه را مختل کرد", "west_effect": "روابط با غرب", "east_effect": "روابط با اوراسیا"},
	{"id": "border_incident", "title": "درگیری مرزی منطقه‌ای", "desc": "درگیری مرزی میان دو کشور همسایه شعله‌ور شد", "west_effect": "روابط با غرب", "east_effect": "روابط با اوراسیا"},
	{"id": "energy_blackmail", "title": "ابزار انرژی", "desc": "قطع عرضه انرژی توسط یک بلوک برای فشار سیاسی", "west_effect": "روابط با غرب", "east_effect": "روابط با اوراسیا"},
	{"id": "cyber_attack", "title": "حمله سایبری بزرگ", "desc": "حمله سایبری به زیرساخت‌های مالی جهانی", "west_effect": "روابط با غرب", "east_effect": "روابط با اوراسیا"}
]

func ensure(state: Dictionary) -> Dictionary:
	if not state.has("rivalry"):
		state["rivalry"] = {"tension": 40.0, "arms_race": 0.3, "crisis": {}}
	return state

# ── شبیه‌سازی ماهانه ──
func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var riv: Dictionary = state["rivalry"]
	var world: Dictionary = state.get("world", {})
	var npc_wars: Dictionary = world.get("npc_wars", {})
	var wars: Dictionary = world.get("wars", {})
	var tension := float(riv.get("tension", 40.0))

	# جنگ‌های جهان تنش را بالا می‌برند
	tension += float(npc_wars.size()) * 0.4
	tension += float(wars.size()) * 0.25
	# آرامش: بازگشت تدریجی
	tension += (40.0 - tension) * 0.008
	# مسابقه تسلیحاتی: در تنش بالا، کشورها هزینه نظامی بیشتری می‌کنند
	var arms_race := clampf(float(riv.get("arms_race", 0.3)) + (tension - 50.0) * 0.002, 0.0, 1.0)
	riv["arms_race"] = arms_race
	riv["tension"] = clampf(tension, 0.0, 100.0)

	# اثر بر جهان: در تنش بالا، NPCها جنگ‌طلب‌تر می‌شوند (شانس جنگ NPC بیشتر)
	if tension > 70.0:
		for key in npc_wars.keys():
			var war: Dictionary = npc_wars[key]
			war["progress"] = float(war.get("progress", 0.0)) + 0.4
			npc_wars[key] = war
		world["npc_wars"] = npc_wars
	# بحران منطقه‌ای: هر ~۱۰ نوبت یک‌بار
	if riv.get("crisis", {}).is_empty() and Deterministic.chance(0.09):
		var crisis: Dictionary = CRISES[Deterministic.next_int_range(0, CRISES.size() - 1)].duplicate(true)
		crisis["turn"] = turn
		riv["crisis"] = crisis
		events.append({"type": "regional_crisis", "message": "🚨 بحران منطقه‌ای: «%s» — موضع کشور را انتخاب کنید" % crisis["title"]})
	# بحران منقضی (۳ نوبت)
	elif not riv.get("crisis", {}).is_empty():
		var crisis: Dictionary = riv["crisis"]
		if turn - int(crisis.get("turn", turn)) >= 3:
			riv["crisis"] = {}
			events.append({"type": "crisis_passed", "message": "بحران منطقه‌ای بدون موضع‌گیری فروکش کرد (فرصت از دست رفت)"})
	state["rivalry"] = riv
	state["world"] = world
	return {"state": state, "events": events}

# ── موضع‌گیری در بحران ──
func resolve_crisis(state: Dictionary, stance: String) -> Dictionary:
	state = ensure(state)
	var riv: Dictionary = state["rivalry"]
	var crisis: Dictionary = riv.get("crisis", {})
	if crisis.is_empty():
		return {"success": false, "reason": "بحران فعالی نیست", "state": state, "events": []}
	if not ["west", "east", "neutral"].has(stance):
		return {"success": false, "reason": "موضع نامعتبر", "state": state, "events": []}
	var events: Array = []
	var diplomacy: Dictionary = state.get("diplomacy", {})
	var leader: Dictionary = state.get("leader", {})
	var relations: Dictionary = diplomacy.get("relations", {})
	# بلوک‌ها: برای سادگی کشورهای نماینده بلوک‌ها
	var west_leaders := ["USA", "GBR", "FRA", "DEU"]
	var east_leaders := ["RUS", "CHN", "PRK", "IRN"]
	match stance:
		"west":
			for cid in west_leaders:
				if relations.has(cid):
					relations[cid] = clampf(float(relations[cid]) + 6.0, 0.0, 100.0)
			for cid in east_leaders:
				if relations.has(cid):
					relations[cid] = clampf(float(relations[cid]) - 5.0, 0.0, 100.0)
			leader["popularity_world"] = clampf(float(leader.get("popularity_world", 50.0)) + 2.0, 0.0, 100.0)
			events.append({"type": "crisis_stance", "message": "🌍 کشور در بحران «%s» جانب غرب را گرفت؛ روابط با غرب بهبود یافت" % crisis.get("title", "")})
		"east":
			for cid in east_leaders:
				if relations.has(cid):
					relations[cid] = clampf(float(relations[cid]) + 6.0, 0.0, 100.0)
			for cid in west_leaders:
				if relations.has(cid):
					relations[cid] = clampf(float(relations[cid]) - 5.0, 0.0, 100.0)
			state["diplomacy"]["influence"] = clampf(float(state["diplomacy"].get("influence", 40.0)) + 3.0, 0.0, 100.0)
			events.append({"type": "crisis_stance", "message": "🌍 کشور در بحران «%s» جانب اوراسیا را گرفت؛ نفوذ منطقه‌ای افزایش یافت" % crisis.get("title", "")})
		"neutral":
			state["politics"]["stability"] = clampf(float(state["politics"].get("stability", 0.6)) + 0.02, 0.05, 1.0)
			events.append({"type": "crisis_stance", "message": "🕊️ کشور در بحران «%s» بی‌طرف ماند؛ ثبات داخلی حفظ شد" % crisis.get("title", "")})
	diplomacy["relations"] = relations
	state["diplomacy"] = diplomacy
	state["leader"] = leader
	riv["crisis"] = {}
	state["rivalry"] = riv
	return {"success": true, "state": state, "events": events}

# ── اقدامات بازیکن بر تنش ──
func de_escalate(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var riv: Dictionary = state["rivalry"]
	riv["tension"] = clampf(float(riv.get("tension", 40.0)) - 12.0, 0.0, 100.0)
	state["rivalry"] = riv
	state["diplomacy"]["influence"] = clampf(float(state.get("diplomacy", {}).get("influence", 40.0)) + 2.0, 0.0, 100.0)
	return {"success": true, "state": state,
		"events": [{"type": "de_escalation", "message": "🕊️ ابتکار تنش‌زدایی: کشور میانجی‌گری کرد و تنش جهانی کاهش یافت"}]}

func escalate(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var riv: Dictionary = state["rivalry"]
	riv["tension"] = clampf(float(riv.get("tension", 40.0)) + 12.0, 0.0, 100.0)
	riv["arms_race"] = clampf(float(riv.get("arms_race", 0.3)) + 0.1, 0.0, 1.0)
	state["rivalry"] = riv
	# تقویت ارتش در مسابقه تسلیحاتی
	state["military"]["power"] = float(state.get("military", {}).get("power", 50.0)) * 1.02
	return {"success": true, "state": state,
		"events": [{"type": "escalation", "message": "⚔️ کشور بودجه نظامی را افزایش داد و تنش جهانی را تشدید کرد؛ ارتش تقویت شد"}]}
