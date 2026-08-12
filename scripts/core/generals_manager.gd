extends Node
# ────────────────────────────────────────────────────────────────────────────
# فرماندهان ارتش — عمق جنگ
# هر فرمانده ویژگی‌ها (تهاجمی/دفاعی/لجستیک/فناوری/جسور) و «تجربه» دارد که از
# نبردها رشد می‌کند. بازیکن فرمانده استخدام/برکنار می‌کند و به جنگ‌ها می‌گمارد؛
# فرماندهِ منصوب‌شده نیروی جبهه را تغییر می‌دهد و در نبردها تجربه می‌گیرد.
#
# state["generals"] = {
#   "commanders": { id: {name_fa, trait, experience, level, assigned_war, cost} },
#   "next_id": 1
# }
# ────────────────────────────────────────────────────────────────────────────

const TRAITS := {
	"offensive": {"name_fa": "تهاجمی", "offense": 0.14, "defense": -0.05, "desc": "متخصص حمله برق‌آسا؛ برتری در پیشروی ولی آسیب‌پذیرتر در دفاع"},
	"defensive": {"name_fa": "دفاعی", "offense": -0.04, "defense": 0.15, "desc": "استاد دفاع در عمق؛ تلفات کمتر و مقاومت بیشتر"},
	"logistics": {"name_fa": "لجستیک‌دان", "offense": 0.05, "defense": 0.06, "desc": "تدارکات بی‌نقص؛ مصرف سوخت و مهمات کمتر"},
	"tech": {"name_fa": "فناوری‌گرا", "offense": 0.07, "defense": 0.05, "desc": "استفاده هوشمند از پهپاد و جنگ الکترونیک؛ برتری در هوا"},
	"bold": {"name_fa": "جسور", "offense": 0.12, "defense": -0.12, "desc": "ریسک‌پذیر؛ پیروزی‌های بزرگ یا فاجعه‌های بزرگ"}
}
const NAMES := ["سپهبد آریا", "سرلشکر بهرام", "سرلشکر داریوش", "سپهبد کاوه", "سرلشکر رستم", "سپهبد سیاوش", "سرلشکر تهماسب", "سپهبد بهمن"]
const MAX_COMMANDERS := 6

func ensure(state: Dictionary) -> Dictionary:
	if not state.has("generals"):
		state["generals"] = {"commanders": {}, "next_id": 1}
	return state

# ── استخدام فرمانده (هزینه) ──
func can_recruit(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var generals: Dictionary = state["generals"]
	if int(generals.get("next_id", 1)) - 1 >= MAX_COMMANDERS:
		return {"valid": false, "reason": "ظرفیت فرماندهان تکمیل است (حداکثر %s)" % PersianFormatter.to_persian_digits(str(MAX_COMMANDERS))}
	var capital := float(state.get("policies", {}).get("political_capital", 0.0))
	if capital < 1.0:
		return {"valid": false, "reason": "سرمایه سیاسی کافی نیست (۱ واحد لازم است)"}
	return {"valid": true, "reason": ""}

func recruit(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var check := can_recruit(state)
	if not check.valid:
		return {"success": false, "reason": check.reason, "state": state, "events": []}
	var generals: Dictionary = state["generals"]
	var id := str(int(generals.get("next_id", 1)))
	generals["next_id"] = int(generals.get("next_id", 1)) + 1
	var trait_keys := TRAITS.keys()
	var chosen_trait: String = str(trait_keys[Deterministic.next_int_range(0, trait_keys.size() - 1)])
	var chosen_name: String = NAMES[Deterministic.next_int_range(0, NAMES.size() - 1)]
	var commanders: Dictionary = generals.get("commanders", {})
	commanders[id] = {"name_fa": chosen_name, "trait": chosen_trait, "experience": 0.0,
			"level": 1, "assigned_war": "", "battles": 0, "wins": 0}
	generals["commanders"] = commanders
	state["generals"] = generals
	var policies: Dictionary = state.get("policies", {})
	policies["political_capital"] = float(policies.get("political_capital", 0.0)) - 1.0
	state["policies"] = policies
	return {"success": true, "state": state,
		"events": [{"type": "general_recruited", "message": "🪖 %s (ویژگی: %s) به ارتش پیوست" % [name, TRAITS[chosen_trait]["name_fa"]]}]}

# ── گماردن/برکناری فرمانده از جنگ ──
func assign(state: Dictionary, commander_id: String, war_target: String) -> Dictionary:
	state = ensure(state)
	var generals: Dictionary = state["generals"]
	var commanders: Dictionary = generals.get("commanders", {})
	if not commanders.has(commander_id):
		return {"success": false, "reason": "فرمانده یافت نشد", "state": state, "events": []}
	# برکناری از جنگ قبلی
	for cid in commanders.keys():
		if str(commanders[cid].get("assigned_war", "")) == war_target and cid != commander_id:
			commanders[cid]["assigned_war"] = ""
	if war_target != "":
		if not state.get("world", {}).get("wars", {}).has(war_target):
			return {"success": false, "reason": "جنگ فعالی با این کشور نیست", "state": state, "events": []}
	commanders[commander_id]["assigned_war"] = war_target
	generals["commanders"] = commanders
	state["generals"] = generals
	var assign_msg: String = "از جبهه برکنار شد"
	if war_target != "":
		assign_msg = "به جبهه " + WorldManager.get_country_name(war_target) + " گمارده شد"
	var assign_events: Array = [{"type": "general_assigned", "message": "🪖 " + str(commanders[commander_id]["name_fa"]) + " " + assign_msg}]
	return {"success": true, "state": state, "events": assign_events}
# ── شبیه‌سازی ماهانه: تجربه از نبردها + ارتقای سطح ──
func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var generals: Dictionary = state["generals"]
	var commanders: Dictionary = generals.get("commanders", {})
	var world: Dictionary = state.get("world", {})
	var wars: Dictionary = world.get("wars", {})
	for cid in commanders.keys():
		var commander: Dictionary = commanders[cid]
		var target := str(commander.get("assigned_war", ""))
		if target == "" or not wars.has(target):
			continue
		var war: Dictionary = wars[target]
		var progress := float(war.get("progress", 0.0))
		var battle_won := progress >= 0.0
		commander["battles"] = int(commander.get("battles", 0)) + 1
		if battle_won:
			commander["wins"] = int(commander.get("wins", 0)) + 1
		commander["experience"] = float(commander.get("experience", 0.0)) + (2.5 if battle_won else 1.2)
		# ارتقای سطح: هر ۱۰ تجربه یک سطح
		var new_level := 1 + int(float(commander["experience"]) / 10.0)
		if new_level > int(commander.get("level", 1)):
			commander["level"] = new_level
			events.append({"type": "general_leveled", "message": "⭐ %s به درجه سرلشکری ارتقا یافت (سطح %s)" % [commander["name_fa"], PersianFormatter.to_persian_digits(str(new_level))]})
		commanders[cid] = commander
	generals["commanders"] = commanders
	state["generals"] = generals
	return {"state": state, "events": events}

# ── اثر فرمانده منصوب بر نیروی جبهه (برای world_manager) ──
func front_bonus(state: Dictionary, war_target: String) -> Dictionary:
	state = ensure(state)
	var bonus := {"offense": 0.0, "defense": 0.0, "logistics": 0.0, "air": 0.0}
	var commanders: Dictionary = state["generals"].get("commanders", {})
	for cid in commanders.keys():
		var commander: Dictionary = commanders[cid]
		if str(commander.get("assigned_war", "")) != war_target:
			continue
		var trait_data: Dictionary = TRAITS.get(str(commander.get("trait", "offensive")), TRAITS["offensive"])
		var level_bonus := 1.0 + (float(commander.get("level", 1)) - 1.0) * 0.02
		bonus["offense"] += float(trait_data.get("offense", 0.0)) * level_bonus
		bonus["defense"] += float(trait_data.get("defense", 0.0)) * level_bonus
		bonus["logistics"] += 0.05 if str(commander.get("trait", "")) == "logistics" else 0.0
		bonus["air"] += 0.06 if str(commander.get("trait", "")) == "tech" else 0.0
	return bonus

func get_trait_fa(trait_id: String) -> String:
	return str(TRAITS.get(trait_id, {}).get("name_fa", trait_id))

func get_trait_desc(trait_id: String) -> String:
	return str(TRAITS.get(trait_id, {}).get("desc", ""))
