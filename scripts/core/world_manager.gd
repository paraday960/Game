extends Node
# داده و منطق جهان: کشورها، انتخاب کشور، پیمان، تحریم و جنگ فرمان‌محور

const COUNTRIES_PATH = "res://data/countries.json"
const ACTIONS = [
	"improve_relations", "trade_agreement", "end_trade_agreement",
	"form_alliance", "leave_alliance", "sanction", "lift_sanction",
	"declare_war", "offer_peace", "negotiate_sanctions"
]
const ACTION_COSTS = {
	"improve_relations": 1.0, "trade_agreement": 1.5, "end_trade_agreement": 0.5,
	"form_alliance": 2.0, "leave_alliance": 1.0, "sanction": 1.0,
	"lift_sanction": 0.5, "declare_war": 3.0, "offer_peace": 1.0,
	"negotiate_sanctions": 1.0
}

var countries: Dictionary = {}
var default_country: String = "IRN"
var data_version: String = ""
var load_errors: Array = []

func _ready():
	reload()

func reload() -> bool:
	countries.clear()
	load_errors.clear()
	var file = FileAccess.open(COUNTRIES_PATH, FileAccess.READ)
	if file == null:
		load_errors.append("فایل کشورهای جهان خوانده نشد")
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or not parsed.get("countries", null) is Array:
		load_errors.append("ساختار فایل کشورهای جهان نامعتبر است")
		return false
	default_country = str(parsed.get("default_country", "IRN"))
	data_version = str(parsed.get("version", "1.0.0"))
	for raw in parsed["countries"]:
		if not raw is Dictionary or str(raw.get("id", "")).is_empty():
			continue
		countries[str(raw["id"])] = raw.duplicate(true)
	if not countries.has(default_country):
		load_errors.append("کشور پیش‌فرض در داده جهان وجود ندارد")
	return load_errors.is_empty()

func is_valid() -> bool:
	return countries.size() >= 8 and load_errors.is_empty()

func get_country_ids() -> Array:
	var ids = countries.keys()
	ids.sort_custom(func(a, b): return get_country_name(a) < get_country_name(b))
	return ids

func get_country(country_id: String) -> Dictionary:
	return countries.get(country_id, {}).duplicate(true)

func get_country_name(country_id: String) -> String:
	return str(countries.get(country_id, {}).get("name_fa", country_id))

func ensure_world(state: Dictionary) -> Dictionary:
	var player_id = str(state.get("country", {}).get("id", default_country))
	if not countries.has(player_id):
		player_id = default_country
	if not state.has("world") or not state["world"] is Dictionary:
		state["world"] = _build_world(player_id)
	var world: Dictionary = state["world"]
	world["data_version"] = data_version
	world["player_country"] = player_id
	world["countries"] = world.get("countries", _runtime_countries())
	world["wars"] = world.get("wars", {})
	world["war_history"] = world.get("war_history", [])
	world["alliances"] = world.get("alliances", [])
	world["trade_agreements"] = world.get("trade_agreements", [])
	world["npc_relations"] = world.get("npc_relations", _build_npc_relations(player_id))
	world["npc_wars"] = world.get("npc_wars", {})
	world["npc_alliances"] = world.get("npc_alliances", [])
	world["npc_trade_agreements"] = world.get("npc_trade_agreements", [])
	world["recent_global_events"] = world.get("recent_global_events", [])
	state["world"] = world
	if not state.has("diplomacy"):
		state["diplomacy"] = {}
	var diplomacy: Dictionary = state["diplomacy"]
	var relations = diplomacy.get("relations", {})
	var uses_legacy_relations = relations.has("همسایه_شرقی") or relations.has("ابرقدرت_۱")
	if relations.is_empty() or uses_legacy_relations:
		relations = _initial_relations(player_id)
	diplomacy["relations"] = relations
	diplomacy["action_points"] = float(diplomacy.get("action_points", 3.0))
	diplomacy["sanctions"] = diplomacy.get("sanctions", [])
	diplomacy["treaties"] = diplomacy.get("treaties", [])
	state["diplomacy"] = diplomacy
	var profile = countries[player_id]
	state["country"] = {
		"id": player_id,
		"name": profile["name_fa"],
		"capital": profile["capital_fa"],
		"currency": profile["currency_fa"]
	}
	return state

func apply_country_profile(state: Dictionary, country_id: String) -> Dictionary:
	if not countries.has(country_id):
		return state
	var profile: Dictionary = countries[country_id]
	state["country"] = {
		"id": country_id, "name": profile["name_fa"],
		"capital": profile["capital_fa"], "currency": profile["currency_fa"]
	}
	state["economy"]["gdp"] = float(profile["gdp"])
	state["economy"]["gdp_per_capita"] = float(profile["gdp"]) / max(float(profile["population"]), 1.0)
	state["population"]["total"] = float(profile["population"])
	state["military"]["power"] = float(profile["military_power"])
	state["military"]["readiness"] = clamp(0.45 + float(profile["military_power"]) / 250.0, 0.45, 0.88)
	var tech_level = float(profile["tech_level"])
	for branch in state["technology"]["branches"].keys():
		state["technology"]["branches"][branch] = clamp(tech_level * 0.55, 0.08, 0.75)
	state["world"] = _build_world(country_id)
	state["diplomacy"]["relations"] = _initial_relations(country_id)
	state["diplomacy"]["sanctions"] = []
	state["diplomacy"]["treaties"] = []
	state["diplomacy"]["action_points"] = 3.0
	return state

func can_select_country(state: Dictionary, country_id: String) -> Dictionary:
	if int(state.get("tick", 0)) != 0:
		return {"valid": false, "reason": "کشور فقط پیش از نخستین روز قابل انتخاب است"}
	if not countries.has(country_id):
		return {"valid": false, "reason": "کشور انتخابی در داده جهان وجود ندارد"}
	return {"valid": true, "reason": ""}

func can_action(state: Dictionary, target: String, action: String) -> Dictionary:
	state = ensure_world(state.duplicate(true))
	if not ACTIONS.has(action):
		return {"valid": false, "reason": "اقدام بین‌المللی شناخته‌شده نیست"}
	var player = str(state["world"].get("player_country", default_country))
	if target == player or not countries.has(target):
		return {"valid": false, "reason": "کشور هدف معتبر نیست"}
	var diplomacy: Dictionary = state["diplomacy"]
	var points = float(diplomacy.get("action_points", 0.0))
	if points < float(ACTION_COSTS.get(action, 1.0)):
		return {"valid": false, "reason": "امتیاز اقدام دیپلماتیک کافی نیست"}
	var relation = float(diplomacy.get("relations", {}).get(target, 50.0))
	var world: Dictionary = state["world"]
	var wars: Dictionary = world.get("wars", {})
	var alliances: Array = world.get("alliances", [])
	var agreements: Array = world.get("trade_agreements", [])
	if wars.has(target) and action != "offer_peace":
		return {"valid": false, "reason": "در زمان جنگ فقط پیشنهاد صلح قابل ارسال است"}
	match action:
		"trade_agreement":
			if relation < 45.0: return {"valid": false, "reason": "برای توافق تجاری رابطه حداقل ۴۵ لازم است"}
			if agreements.has(target): return {"valid": false, "reason": "توافق تجاری از قبل فعال است"}
		"end_trade_agreement":
			if not agreements.has(target): return {"valid": false, "reason": "توافق تجاری فعالی برای پایان‌دادن وجود ندارد"}
		"form_alliance":
			if relation < 75.0: return {"valid": false, "reason": "برای اتحاد رابطه حداقل ۷۵ لازم است"}
			if alliances.has(target): return {"valid": false, "reason": "اتحاد از قبل فعال است"}
		"leave_alliance":
			if not alliances.has(target): return {"valid": false, "reason": "اتحاد فعالی برای خروج وجود ندارد"}
		"sanction":
			if alliances.has(target): return {"valid": false, "reason": "اعمال تحریم علیه متحد ممکن نیست؛ ابتدا از اتحاد خارج شوید"}
			if _has_player_sanction(diplomacy, target): return {"valid": false, "reason": "این کشور از قبل تحریم شده است"}
		"lift_sanction":
			if not _has_player_sanction(diplomacy, target): return {"valid": false, "reason": "تحریم فعالی برای لغو وجود ندارد"}
		"declare_war":
			if relation > 35.0: return {"valid": false, "reason": "اعلام جنگ فقط در رابطه ۳۵ یا کمتر ممکن است"}
			if alliances.has(target): return {"valid": false, "reason": "برای جنگ ابتدا باید از اتحاد خارج شوید"}
			if agreements.has(target): return {"valid": false, "reason": "برای جنگ ابتدا توافق تجاری را پایان دهید"}
			if wars.has(target): return {"valid": false, "reason": "کشور هم‌اکنون در جنگ است"}
			if float(state["military"].get("readiness", 0.0)) < 0.45: return {"valid": false, "reason": "آمادگی نظامی برای جنگ کافی نیست"}
		"offer_peace":
			if not wars.has(target): return {"valid": false, "reason": "جنگ فعالی با این کشور وجود ندارد"}
		"negotiate_sanctions":
			if not _has_incoming_sanction(diplomacy, target): return {"valid": false, "reason": "تحریم ورودی از این کشور وجود ندارد"}
	return {"valid": true, "reason": ""}

func apply_action(state: Dictionary, target: String, action: String, tick: int) -> Dictionary:
	var check = can_action(state, target, action)
	if not check.valid:
		return {"success": false, "reason": check.reason, "state": state, "events": []}
	var diplomacy: Dictionary = state["diplomacy"]
	var world: Dictionary = state["world"]
	var events: Array = []
	diplomacy["action_points"] = max(0.0, float(diplomacy["action_points"]) - float(ACTION_COSTS[action]))
	match action:
		"improve_relations":
			diplomacy["relations"][target] = clamp(float(diplomacy["relations"].get(target, 50.0)) + 8.0, 0.0, 100.0)
			events.append(_event("relations_improved", target, "روابط با %s بهبود یافت" % get_country_name(target)))
		"trade_agreement":
			world["trade_agreements"].append(target)
			diplomacy["relations"][target] = clamp(float(diplomacy["relations"][target]) + 4.0, 0.0, 100.0)
			state["trade"]["trade_agreements"] = int(state["trade"].get("trade_agreements", 0)) + 1
			state["trade"]["exports"] *= 1.01
			events.append(_event("trade_agreement_signed", target, "توافق تجاری با %s امضا شد" % get_country_name(target)))
		"end_trade_agreement":
			world["trade_agreements"].erase(target)
			state["trade"]["trade_agreements"] = max(0, int(state["trade"].get("trade_agreements", 0)) - 1)
			diplomacy["relations"][target] = clamp(float(diplomacy["relations"][target]) - 5.0, 0.0, 100.0)
			events.append(_event("trade_agreement_ended", target, "توافق تجاری با %s پایان یافت" % get_country_name(target)))
		"form_alliance":
			world["alliances"].append(target)
			diplomacy["treaties"].append({"type":"alliance", "target":target, "tick":tick})
			diplomacy["relations"][target] = max(float(diplomacy["relations"][target]), 82.0)
			events.append(_event("alliance_formed", target, "اتحاد راهبردی با %s شکل گرفت" % get_country_name(target)))
		"leave_alliance":
			world["alliances"].erase(target)
			_remove_treaty(diplomacy, "alliance", target)
			diplomacy["relations"][target] = clamp(float(diplomacy["relations"][target]) - 12.0, 0.0, 100.0)
			state["politics"]["trust"] = clamp(float(state["politics"].get("trust", 0.5)) - 0.01, 0.0, 1.0)
			events.append(_event("alliance_left", target, "کشور از اتحاد با %s خارج شد" % get_country_name(target)))
		"sanction":
			diplomacy["sanctions"].append({"target":target, "by":"player", "tick":tick})
			diplomacy["relations"][target] = clamp(float(diplomacy["relations"][target]) - 18.0, 0.0, 100.0)
			state["trade"]["exports"] *= 0.995
			events.append(_event("sanction_imposed", target, "%s تحریم شد" % get_country_name(target)))
		"lift_sanction":
			_remove_player_sanction(diplomacy, target)
			diplomacy["relations"][target] = clamp(float(diplomacy["relations"][target]) + 7.0, 0.0, 100.0)
			events.append(_event("sanction_lifted", target, "تحریم %s لغو شد" % get_country_name(target)))
		"declare_war":
			world["wars"][target] = {"target":target, "started_tick":tick, "progress":0.0, "player_losses":0, "enemy_losses":0}
			diplomacy["relations"][target] = 0.0
			state["politics"]["tension"] = clamp(float(state["politics"].get("tension", 0.3)) + 0.12, 0.0, 1.0)
			state["population"]["happiness"] = clamp(float(state["population"].get("happiness", 0.6)) - 0.04, 0.0, 1.0)
			events.append(_event("war_declared", target, "جنگ با %s آغاز شد" % get_country_name(target)))
		"offer_peace":
			var peace_record: Dictionary = world["wars"].get(target, {}).duplicate(true)
			peace_record["outcome"] = "peace"
			peace_record["ended_tick"] = tick
			world["war_history"].append(peace_record)
			world["wars"].erase(target)
			diplomacy["relations"][target] = 20.0
			state["politics"]["tension"] = clamp(float(state["politics"].get("tension", 0.3)) - 0.08, 0.0, 1.0)
			events.append(_event("peace_signed", target, "پیمان صلح با %s امضا شد" % get_country_name(target)))
		"negotiate_sanctions":
			_remove_incoming_sanction(diplomacy, target)
			diplomacy["relations"][target] = clamp(float(diplomacy["relations"].get(target, 50.0)) + 4.0, 0.0, 100.0)
			events.append(_event("sanction_negotiation", target, "مذاکره تحریم با %s انجام شد" % get_country_name(target)))
	state["diplomacy"] = diplomacy
	state["world"] = world
	return {"success": true, "state": state, "events": events}

func simulate(state: Dictionary, tick: int) -> Dictionary:
	state = ensure_world(state)
	var world: Dictionary = state["world"]
	var diplomacy: Dictionary = state["diplomacy"]
	var events: Array = []
	diplomacy["action_points"] = min(5.0, float(diplomacy.get("action_points", 3.0)) + 0.15)
	for country_id in world["countries"].keys():
		if country_id == world["player_country"]:
			continue
		var runtime: Dictionary = world["countries"][country_id]
		runtime["gdp"] = max(1.0, float(runtime.get("gdp", 1.0)) * (1.0 + Deterministic.next_range(-0.00008, 0.00012)))
		runtime["military_power"] = clamp(float(runtime.get("military_power", 50.0)) + Deterministic.next_range(-0.015, 0.02), 10.0, 120.0)
		world["countries"][country_id] = runtime
	var finished: Array = []
	for target in world["wars"].keys():
		if not world["countries"].has(target):
			finished.append(target)
			continue
		var war: Dictionary = world["wars"][target]
		var enemy: Dictionary = world["countries"][target]
		var player_force = float(state["military"].get("power", 50.0)) * float(state["military"].get("readiness", 0.6))
		var enemy_force = float(enemy.get("military_power", 50.0)) * 0.68
		var advantage = (player_force - enemy_force) / max(player_force + enemy_force, 1.0)
		var daily_progress = clamp(advantage * 4.0 + Deterministic.next_range(-1.2, 1.2), -3.5, 3.5)
		war["progress"] = float(war.get("progress", 0.0)) + daily_progress
		var casualty_modifier = 1.0 - float(MilitaryManager.get_effective_modifiers(state).get("casualty_reduction", 0.0))
		var player_loss = int(max(10.0, enemy_force * Deterministic.next_range(0.4, 1.2) * casualty_modifier))
		var enemy_loss = int(max(10.0, player_force * Deterministic.next_range(0.4, 1.2)))
		war["player_losses"] = int(war.get("player_losses", 0)) + player_loss
		war["enemy_losses"] = int(war.get("enemy_losses", 0)) + enemy_loss
		state["military"]["personnel"] = max(1000, int(state["military"].get("personnel", 500000)) - player_loss)
		state["military"]["readiness"] = clamp(float(state["military"].get("readiness", 0.6)) - 0.0008, 0.1, 1.0)
		state["economy"]["gdp"] *= 0.99996
		enemy["military_power"] = max(10.0, float(enemy["military_power"]) - enemy_loss / 500000.0)
		world["countries"][target] = enemy
		if war["progress"] >= 100.0:
			finished.append(target)
			war["outcome"] = "victory"
			war["ended_tick"] = tick
			world["war_history"].append(war.duplicate(true))
			diplomacy["relations"][target] = 18.0
			diplomacy["influence"] = clamp(float(diplomacy.get("influence", 40.0)) + 6.0, 0.0, 100.0)
			events.append(_event("war_victory", target, "پیروزی در جنگ با %s؛ رهبر در قدرت باقی ماند" % get_country_name(target)))
		elif war["progress"] <= -100.0:
			finished.append(target)
			war["outcome"] = "defeat"
			war["ended_tick"] = tick
			world["war_history"].append(war.duplicate(true))
			diplomacy["relations"][target] = 12.0
			state["politics"]["stability"] = clamp(float(state["politics"].get("stability", 0.5)) - 0.08, 0.05, 0.95)
			state["population"]["happiness"] = clamp(float(state["population"].get("happiness", 0.5)) - 0.06, 0.05, 0.95)
			events.append(_event("war_defeat", target, "شکست نظامی برابر %s؛ کشور آسیب دید اما رهبر برکنار نشد" % get_country_name(target)))
		else:
			world["wars"][target] = war
	for target in finished:
		world["wars"].erase(target)
	while world["war_history"].size() > 50:
		world["war_history"].pop_front()
	state["world"] = world
	state["diplomacy"] = diplomacy
	var day_in_month = int(state.get("time", {}).get("day_in_month", 1))
	var days_in_month = int(state.get("time", {}).get("days_in_month", 30))
	if day_in_month >= days_in_month:
		var npc_result = simulate_npc_month(state, int(state.get("time", {}).get("turn", tick)))
		state = npc_result.state
		events.append_array(npc_result.events)
	return {"state": state, "events": events}

func simulate_npc_month(state: Dictionary, turn: int, forced: Dictionary = {}) -> Dictionary:
	state = ensure_world(state)
	var world: Dictionary = state["world"]
	var relations: Dictionary = world.get("npc_relations", {})
	var npc_wars: Dictionary = world.get("npc_wars", {})
	var npc_alliances: Array = world.get("npc_alliances", [])
	var npc_trade: Array = world.get("npc_trade_agreements", [])
	var events: Array = []
	var player_id = str(world.get("player_country", default_country))

	# روابط کشورهای غیرِبازیکن با بلوک، فاصله، قدرت و نویز کم ماهانه تغییر می‌کند.
	for key in relations.keys():
		var pair = str(key).split("|")
		if pair.size() != 2:
			continue
		var a = str(pair[0]); var b = str(pair[1])
		var relation = float(relations[key])
		var profile_a = countries.get(a, {})
		var profile_b = countries.get(b, {})
		var drift = Deterministic.next_range(-0.45, 0.45)
		if str(profile_a.get("bloc", "")) == str(profile_b.get("bloc", "")):
			drift += (68.0 - relation) * 0.015
		else:
			drift += (48.0 - relation) * 0.006
		if npc_trade.has(key): drift += (72.0 - relation) * 0.02
		if npc_alliances.has(key): drift += (86.0 - relation) * 0.03
		if npc_wars.has(key): drift += (0.0 - relation) * 0.08
		relations[key] = clamp(relation + drift, 0.0, 100.0)

	var force_pair: Array = forced.get("force_war", [])
	if force_pair.size() == 2:
		var forced_key = _pair_key(str(force_pair[0]), str(force_pair[1]))
		if relations.has(forced_key) and not npc_wars.has(forced_key):
			npc_wars[forced_key] = _new_npc_war(str(force_pair[0]), str(force_pair[1]), turn)
			relations[forced_key] = 0.0
			events.append(_global_event("npc_war_started", str(force_pair[0]), str(force_pair[1]), "جنگ میان %s و %s آغاز شد" % [get_country_name(str(force_pair[0])), get_country_name(str(force_pair[1]))]))

	# تصمیم راهبردی محدود: حداکثر یک اقدام جدید در هر ماه تا جهان بیش از حد تصادفی نشود.
	var acted = not events.is_empty()
	if not acted:
		var keys = relations.keys()
		keys.sort()
		for key in keys:
			var relation = float(relations[key])
			var pair = str(key).split("|")
			if pair.size() != 2: continue
			var a = str(pair[0]); var b = str(pair[1])
			if relation <= 12.0 and not npc_wars.has(key) and Deterministic.chance(0.045):
				npc_wars[key] = _new_npc_war(a, b, turn)
				relations[key] = 0.0
				events.append(_global_event("npc_war_started", a, b, "جنگ میان %s و %s آغاز شد" % [get_country_name(a), get_country_name(b)]))
				acted = true
				break
			elif relation >= 80.0 and not npc_alliances.has(key) and Deterministic.chance(0.035):
				npc_alliances.append(key)
				events.append(_global_event("npc_alliance", a, b, "اتحاد تازه‌ای میان %s و %s شکل گرفت" % [get_country_name(a), get_country_name(b)]))
				acted = true
				break
			elif relation >= 58.0 and not npc_trade.has(key) and Deterministic.chance(0.055):
				npc_trade.append(key)
				events.append(_global_event("npc_trade_agreement", a, b, "توافق تجاری تازه میان %s و %s امضا شد" % [get_country_name(a), get_country_name(b)]))
				acted = true
				break

	# جنگ‌های AI ماهانه پیش می‌روند و بر اقتصاد جهانی و شرکای بازیکن اثر می‌گذارند.
	var finished: Array = []
	for key in npc_wars.keys():
		var war: Dictionary = npc_wars[key]
		var a = str(war.get("a", "")); var b = str(war.get("b", ""))
		if not world["countries"].has(a) or not world["countries"].has(b):
			finished.append(key); continue
		var country_a: Dictionary = world["countries"][a]
		var country_b: Dictionary = world["countries"][b]
		var force_a = float(country_a.get("military_power", 50.0))
		var force_b = float(country_b.get("military_power", 50.0))
		var advantage = (force_a - force_b) / max(force_a + force_b, 1.0)
		war["progress"] = float(war.get("progress", 0.0)) + clamp(advantage * 13.0 + Deterministic.next_range(-5.0, 5.0), -12.0, 12.0)
		var loss_a = int(max(20.0, force_b * Deterministic.next_range(4.0, 12.0)))
		var loss_b = int(max(20.0, force_a * Deterministic.next_range(4.0, 12.0)))
		war["losses_a"] = int(war.get("losses_a", 0)) + loss_a
		war["losses_b"] = int(war.get("losses_b", 0)) + loss_b
		country_a["military_power"] = max(8.0, force_a - loss_a / 100000.0)
		country_b["military_power"] = max(8.0, force_b - loss_b / 100000.0)
		country_a["gdp"] = max(1.0, float(country_a.get("gdp", 1.0)) * 0.9985)
		country_b["gdp"] = max(1.0, float(country_b.get("gdp", 1.0)) * 0.9985)
		world["countries"][a] = country_a; world["countries"][b] = country_b
		if world.get("trade_agreements", []).has(a) or world.get("trade_agreements", []).has(b):
			state["trade"]["exports"] *= 0.995
			state["trade"]["imports"] *= 0.997
		if abs(float(war["progress"])) >= 100.0 or turn - int(war.get("started_turn", turn)) >= 36:
			finished.append(key)
			var winner = a if float(war["progress"]) >= 0.0 else b
			var loser = b if winner == a else a
			relations[key] = 18.0
			events.append(_global_event("npc_war_ended", winner, loser, "جنگ %s و %s با برتری %s پایان یافت" % [get_country_name(a), get_country_name(b), get_country_name(winner)]))
		else:
			npc_wars[key] = war
	for key in finished: npc_wars.erase(key)

	world["npc_relations"] = relations
	world["npc_wars"] = npc_wars
	world["npc_alliances"] = npc_alliances
	world["npc_trade_agreements"] = npc_trade
	var recent: Array = world.get("recent_global_events", [])
	for event in events: recent.append(event.duplicate(true))
	while recent.size() > 30: recent.pop_front()
	world["recent_global_events"] = recent
	state["world"] = world
	return {"state":state, "events":events}

func _build_npc_relations(player_id: String) -> Dictionary:
	var matrix: Dictionary = {}
	var ids = countries.keys(); ids.sort()
	for i in range(ids.size()):
		var a = str(ids[i])
		if a == player_id: continue
		for j in range(i + 1, ids.size()):
			var b = str(ids[j])
			if b == player_id: continue
			var pa = countries[a]; var pb = countries[b]
			var relation = 52.0
			if str(pa.get("bloc", "")) == str(pb.get("bloc", "")): relation = 68.0
			elif [str(pa.get("bloc", "")), str(pb.get("bloc", ""))].has("غربی") and [str(pa.get("bloc", "")), str(pb.get("bloc", ""))].has("اوراسیا"): relation = 28.0
			var distance = Vector2(float(pa.get("lon", 0.0)), float(pa.get("lat", 0.0))).distance_to(Vector2(float(pb.get("lon", 0.0)), float(pb.get("lat", 0.0))))
			if distance < 22.0: relation += 3.0
			matrix[_pair_key(a, b)] = clamp(relation, 12.0, 86.0)
	return matrix

func _pair_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]

func _new_npc_war(a: String, b: String, turn: int) -> Dictionary:
	return {"a":a, "b":b, "started_turn":turn, "progress":0.0, "losses_a":0, "losses_b":0}

func _global_event(type: String, a: String, b: String, message: String) -> Dictionary:
	return {"type":type, "a":a, "b":b, "message":message}

func _build_world(player_id: String) -> Dictionary:
	return {
		"data_version": data_version,
		"player_country": player_id,
		"countries": _runtime_countries(),
		"wars": {}, "war_history": [], "alliances": [], "trade_agreements": [],
		"npc_relations": _build_npc_relations(player_id),
		"npc_wars": {}, "npc_alliances": [], "npc_trade_agreements": [],
		"recent_global_events": []
	}

func _runtime_countries() -> Dictionary:
	var runtime: Dictionary = {}
	for id in countries.keys():
		runtime[id] = countries[id].duplicate(true)
	return runtime

func _initial_relations(player_id: String) -> Dictionary:
	var result: Dictionary = {}
	var player = countries.get(player_id, {})
	for id in countries.keys():
		if id == player_id:
			continue
		var other = countries[id]
		var relation = 52.0
		if str(player.get("bloc", "")) == str(other.get("bloc", "")):
			relation = 66.0
		elif [str(player.get("bloc", "")), str(other.get("bloc", ""))].has("غربی") and [str(player.get("bloc", "")), str(other.get("bloc", ""))].has("اوراسیا"):
			relation = 34.0
		var distance = Vector2(float(player.get("lon", 0.0)), float(player.get("lat", 0.0))).distance_to(Vector2(float(other.get("lon", 0.0)), float(other.get("lat", 0.0))))
		if distance < 22.0:
			relation += 4.0
		result[id] = clamp(relation, 15.0, 85.0)
	return result

func _has_player_sanction(diplomacy: Dictionary, target: String) -> bool:
	for item in diplomacy.get("sanctions", []):
		if item is Dictionary and item.get("target", "") == target and item.get("by", "") == "player":
			return true
	return false

func _remove_player_sanction(diplomacy: Dictionary, target: String):
	var kept: Array = []
	for item in diplomacy.get("sanctions", []):
		if item is Dictionary and item.get("target", "") == target and item.get("by", "") == "player":
			continue
		kept.append(item)
	diplomacy["sanctions"] = kept

func _has_incoming_sanction(diplomacy: Dictionary, target: String) -> bool:
	for item in diplomacy.get("sanctions", []):
		if item is Dictionary and item.get("target", "") == target and item.get("by", "foreign") != "player":
			return true
	return false

func _remove_incoming_sanction(diplomacy: Dictionary, target: String):
	var removed = false
	var kept: Array = []
	for item in diplomacy.get("sanctions", []):
		if not removed and item is Dictionary and item.get("target", "") == target and item.get("by", "foreign") != "player":
			removed = true
			continue
		kept.append(item)
	diplomacy["sanctions"] = kept

func _remove_treaty(diplomacy: Dictionary, treaty_type: String, target: String):
	var kept: Array = []
	for treaty in diplomacy.get("treaties", []):
		if treaty is Dictionary and treaty.get("type", "") == treaty_type and treaty.get("target", "") == target:
			continue
		kept.append(treaty)
	diplomacy["treaties"] = kept

func _event(type: String, target: String, message: String) -> Dictionary:
	return {"type":type, "target":target, "country":get_country_name(target), "message":message}
