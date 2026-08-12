extends Node
# داده و منطق جهان: کشورها، انتخاب کشور، پیمان، تحریم و جنگ فرمان‌محور

const COUNTRIES_PATH = "res://data/countries.json"
const NpcTurnManagerClass = preload("res://scripts/core/npc_turn_manager.gd")
const ACTIONS = [
	"improve_relations", "trade_agreement", "end_trade_agreement",
	"form_alliance", "leave_alliance", "sanction", "lift_sanction",
	"declare_war", "offer_peace", "negotiate_sanctions", "ultimatum",
	"accept_offer", "reject_offer"
]
const ACTION_COSTS = {
	"improve_relations": 1.0, "trade_agreement": 1.5, "end_trade_agreement": 0.5,
	"form_alliance": 2.0, "leave_alliance": 1.0, "sanction": 1.0,
	"lift_sanction": 0.5, "declare_war": 2.0, "offer_peace": 1.0,
	"negotiate_sanctions": 1.0, "ultimatum": 1.0, "accept_offer": 0.0, "reject_offer": 0.0
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
	if countries.size() != 195 or not load_errors.is_empty():
		return false
	for country in countries.values():
		for key in ["id","name_fa","capital_fa","currency_fa","population","gdp","lat","lon","climate_fa"]:
			if not country.has(key): return false
	return true

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
	# جنگ‌های اولیه واقعی جهان (تا جهان از ابتدا زنده و درگیر باشد):
	# فقط وقتی هنوز هیچ جنگی ثبت نشده (اولین ساخت) — جنگ‌های بلوک‌های متضاد
	if world["npc_wars"].is_empty() and world["war_history"].is_empty():
		var initial_wars: Array = [
			["RUS", "UKR"],
			["USA", "PRK"]
		]
		for pair in initial_wars:
			var a: String = str(pair[0]); var b: String = str(pair[1])
			if countries.has(a) and countries.has(b):
				world["npc_wars"][_pair_key(a, b)] = _new_npc_war(a, b, 0)
				var rel_key = _pair_key(a, b)
				if world["npc_relations"].has(rel_key):
					world["npc_relations"][rel_key] = 0.0
	world["recent_global_events"] = world.get("recent_global_events", [])
	# رودمپ ۵: پیشنهادهای ورودی از کشورها و موضع فعلی هر کشور نسبت به بازیکن
	world["incoming_offers"] = world.get("incoming_offers", [])
	world["player_stances"] = world.get("player_stances", {})
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
	# سیستم سطوح ۳۰: مقدار float سازگاری و سطح هر شاخه از تکنولوژی کشور
	var tech_state: Dictionary = state.get("technology", {})
	var branch_levels: Dictionary = tech_state.get("branch_levels", {})
	for branch in state["technology"]["branches"].keys():
		var value: float = clamp(tech_level * 0.55, 0.08, 0.75)
		state["technology"]["branches"][branch] = value
		if branch_levels.has(branch):
			branch_levels[branch] = clampi(int(round(value * 30.0)), 0, 30)
	if not branch_levels.is_empty():
		tech_state["branch_levels"] = branch_levels
		state["technology"] = tech_state
	_apply_national_geography_profile(state, country_id, profile)
	state["world"] = _build_world(country_id)
	state["diplomacy"]["relations"] = _initial_relations(country_id)
	state["diplomacy"]["sanctions"] = []
	state["diplomacy"]["treaties"] = []
	state["diplomacy"]["action_points"] = 3.0
	return state

func _apply_national_geography_profile(state: Dictionary, country_id: String, profile: Dictionary):
	# تعداد و مقیاس تأسیسات هر کشور از نقشه واقعی، مساحت، جمعیت و اقتصاد همان کشور آغاز می‌شود.
	var population = max(1.0, float(profile.get("population", 1.0)))
	var area = max(0.1, float(profile.get("area_km2", 1.0)))
	var gdp = max(1.0, float(profile.get("gdp", 1.0)))
	var technology = clamp(float(profile.get("tech_level", 0.4)), 0.05, 1.0)
	var unit_count = max(1, CountryGeographyManager.get_unit_count(country_id))
	var city_count = max(1, CountryGeographyManager.get_cities(country_id).size())
	var administration: Dictionary = state.get("administration", {})
	administration["provinces"] = unit_count
	administration["municipalities"] = max(unit_count, int(pow(population / 50000.0, 0.82)))
	administration["regional_inequality"] = clamp(0.48 - technology * 0.20 + min(0.12, float(unit_count) / 1000.0), 0.12, 0.62)
	state["administration"] = administration
	var roads_km = max(5.0, area * (0.035 + technology * 0.045) + population / (1400.0 - technology * 550.0))
	var rail_km = roads_km * (0.025 + technology * 0.105)
	var coastal = not bool(profile.get("landlocked", false))
	state["transport_detail"] = {
		"roads_km": roads_km,
		"roads_quality": clamp(0.30 + technology * 0.58, 0.25, 0.94),
		"rail_km": rail_km,
		"rail_quality": clamp(0.25 + technology * 0.60, 0.20, 0.94),
		"ports": max(1, int(sqrt(gdp / 1000000000.0) * 1.5)) if coastal else 0,
		"ports_capacity": clamp(0.30 + technology * 0.55, 0.20, 1.0) if coastal else 0.0,
		"airports": max(1, int(pow(population / 750000.0, 0.72)) + city_count / 2),
		"airports_capacity": clamp(0.30 + technology * 0.58, 0.20, 1.0),
		"metro_stations": max(0, int((population / 1000000.0) * technology * technology * 5.0)),
		"traffic_congestion": clamp(0.58 - technology * 0.24 + float(city_count) / 500.0, 0.12, 0.78),
		"logistics_efficiency": clamp(0.28 + technology * 0.65, 0.20, 0.95),
		"fuel_consumption": roads_km * 0.012,
	}
	state["settlements_detail"] = {
		"total": max(city_count, int(pow(population / 12000.0, 0.78))),
		"cities_large": max(0, int(population / 1500000.0)),
		"cities_medium": max(1, int(population / 350000.0)),
		"cities_small": max(city_count, int(population / 120000.0)),
		"towns": max(1, int(population / 60000.0)),
		"villages": max(1, int(population / 7000.0)),
		"urban_pop": population * float(state.get("population", {}).get("urban_ratio", 0.65)),
		"rural_pop": population * (1.0 - float(state.get("population", {}).get("urban_ratio", 0.65))),
		"density": population / area,
		"sprawl": clamp(0.48 - technology * 0.20, 0.12, 0.55),
		"housing_quality": clamp(0.35 + technology * 0.52, 0.25, 0.92),
	}
	state["industry_sites_detail"] = {
		"factories": max(1, int(gdp / 100000000.0)),
		"warehouses": max(1, int(gdp / 60000000.0)),
		"mines": max(0, int(area / 8500.0 * (0.45 + float(profile.get("strategic_weight", 0.3))))),
		"power_plants": max(1, int(population / 800000.0)),
		"industrial_parks": max(1, int(gdp / 15000000000.0)),
		"utilization": 0.70,
		"pollution_industrial": clamp(0.52 - technology * 0.18, 0.18, 0.58),
	}
	state["physical"]["settlements"] = state["settlements_detail"]["total"]
	state["physical"]["transport_routes"] = max(unit_count, int(roads_km / 25.0))
	state["physical"]["facilities"] = max(unit_count, int(population / 18000.0))

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
	# در زمان جنگ، صلح و پاسخ به پیشنهادهای ورودی مجاز است
	if wars.has(target) and not ["offer_peace", "accept_offer", "reject_offer"].has(action):
		return {"valid": false, "reason": "در زمان جنگ فقط صلح یا پاسخ به پیشنهاد قابل انجام است"}
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
			if relation > 40.0: return {"valid": false, "reason": "اعلام جنگ فقط در رابطه ۴۰ یا کمتر ممکن است؛ با تحریم یا اولتیماتوم رابطه را کاهش دهید"}
			if alliances.has(target): return {"valid": false, "reason": "برای جنگ ابتدا باید از اتحاد خارج شوید"}
			if agreements.has(target): return {"valid": false, "reason": "برای جنگ ابتدا توافق تجاری را پایان دهید"}
			if wars.has(target): return {"valid": false, "reason": "کشور هم‌اکنون در جنگ است"}
			if float(state["military"].get("readiness", 0.0)) < 0.45: return {"valid": false, "reason": "آمادگی نظامی برای جنگ کافی نیست"}
		"ultimatum":
			if relation <= 40.0: return {"valid": false, "reason": "برای اولتیماتوم رابطه بالای ۴۰ لازم است (برای جنگ مستقیم اعلام جنگ بزنید)"}
			if alliances.has(target): return {"valid": false, "reason": "اولتیماتوم به متحد ممکن نیست؛ ابتدا از اتحاد خارج شوید"}
			if wars.has(target): return {"valid": false, "reason": "کشور هم‌اکنون در جنگ است"}
		"offer_peace":
			if not wars.has(target): return {"valid": false, "reason": "جنگ فعالی با این کشور وجود ندارد"}
		"accept_offer":
			if not _has_offer(world, [], target): return {"valid": false, "reason": "پیشنهاد فعالی از این کشور وجود ندارد"}
		"reject_offer":
			if not _has_offer(world, [], target): return {"valid": false, "reason": "پیشنهاد فعالی از این کشور وجود ندارد"}
		"negotiate_sanctions":
			if not _has_incoming_sanction(diplomacy, target): return {"valid": false, "reason": "تحریم ورودی از این کشور وجود ندارد"}
	return {"valid": true, "reason": ""}

func apply_action(state: Dictionary, target: String, action: String, tick: int, goal: String = "reparations") -> Dictionary:
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
			diplomacy["relations"][target] = clamp(float(diplomacy["relations"][target]) - 22.0, 0.0, 100.0)
			state["trade"]["exports"] *= 0.995
			events.append(_event("sanction_imposed", target, "%s تحریم شد" % get_country_name(target)))
		"lift_sanction":
			_remove_player_sanction(diplomacy, target)
			diplomacy["relations"][target] = clamp(float(diplomacy["relations"][target]) + 7.0, 0.0, 100.0)
			events.append(_event("sanction_lifted", target, "تحریم %s لغو شد" % get_country_name(target)))
		"ultimatum":
			diplomacy["relations"][target] = clamp(float(diplomacy["relations"][target]) - 28.0, 0.0, 100.0)
			state["politics"]["tension"] = clamp(float(state["politics"].get("tension", 0.3)) + 0.10, 0.0, 1.0)
			events.append(_event("ultimatum_issued", target, "اولتیماتوم به %s ارسال شد - روابط به شدت تنش یافت" % get_country_name(target)))
		"declare_war":
			world["wars"][target] = {"target":target, "started_tick":tick, "progress":0.0, "player_losses":0, "enemy_losses":0,
				"goal": goal, "goal_scale": float(war_goal_scale(goal))}
			diplomacy["relations"][target] = 0.0
			state["politics"]["tension"] = clamp(float(state["politics"].get("tension", 0.3)) + 0.12, 0.0, 1.0)
			state["population"]["happiness"] = clamp(float(state["population"].get("happiness", 0.6)) - 0.04, 0.0, 1.0)
			events.append(_event("war_declared", target, "جنگ با %s آغاز شد" % get_country_name(target)))
		"offer_peace":
			# پذیرش صلح دیگر تضمین‌شده نیست: دشمن صلح را وقتی قبول می‌کند که در آستانه
			# پیروزی نباشد (پیشروی بازیکن > -۴۰) یا جنگ بیش از یک سال کشیده باشد.
			var war: Dictionary = world["wars"].get(target, {})
			var progress = float(war.get("progress", 0.0))
			var months_in_war = max(0, tick - int(war.get("started_tick", tick)))
			if progress > -40.0 or months_in_war >= 12:
				var peace_record: Dictionary = war.duplicate(true)
				peace_record["outcome"] = "peace"
				peace_record["ended_tick"] = tick
				world["war_history"].append(peace_record)
				world["wars"].erase(target)
				diplomacy["relations"][target] = 20.0
				state["politics"]["tension"] = clamp(float(state["politics"].get("tension", 0.3)) - 0.08, 0.0, 1.0)
				state["military"]["war_exhaustion"] = max(0.0, float(state["military"].get("war_exhaustion", 0.0)) - 0.15)
				events.append(_event("peace_signed", target, "پیمان صلح با %s امضا شد" % get_country_name(target)))
			else:
				diplomacy["relations"][target] = clamp(float(diplomacy["relations"].get(target, 0.0)) - 2.0, 0.0, 100.0)
				events.append(_event("peace_rejected", target, "%s پیشنهاد صلح را رد کرد؛ در آستانه پیروزی خود را می‌بیند" % get_country_name(target)))
		"accept_offer":
			var offer = find_offer(world, target)
			var offer_type = str(offer.get("type", ""))
			world = _remove_offer(world, str(offer.get("id", "")))
			match offer_type:
				"trade_agreement":
					if not world["trade_agreements"].has(target):
						world["trade_agreements"].append(target)
						state["trade"]["trade_agreements"] = int(state["trade"].get("trade_agreements", 0)) + 1
						state["trade"]["exports"] = float(state["trade"].get("exports", 0.0)) * 1.01
					diplomacy["relations"][target] = clamp(float(diplomacy["relations"].get(target, 50.0)) + 3.0, 0.0, 100.0)
					events.append(_event("trade_agreement_signed", target, "پیشنهاد تجاری %s پذیرفته شد؛ توافق امضا شد" % get_country_name(target)))
				"alliance":
					if not world["alliances"].has(target):
						world["alliances"].append(target)
						diplomacy["treaties"].append({"type":"alliance", "target":target, "tick":tick})
					diplomacy["relations"][target] = max(float(diplomacy["relations"].get(target, 50.0)), 80.0)
					events.append(_event("alliance_formed", target, "اتحاد راهبردی با %s برقرار شد" % get_country_name(target)))
				"peace":
					var offer_war = world["wars"].get(target, {})
					if world["wars"].has(target):
						var offer_peace_record: Dictionary = offer_war.duplicate(true)
						offer_peace_record["outcome"] = "peace"
						offer_peace_record["ended_tick"] = tick
						world["war_history"].append(offer_peace_record)
						world["wars"].erase(target)
						diplomacy["relations"][target] = 22.0
						state["politics"]["tension"] = clamp(float(state["politics"].get("tension", 0.3)) - 0.08, 0.0, 1.0)
						state["military"]["war_exhaustion"] = max(0.0, float(state["military"].get("war_exhaustion", 0.0)) - 0.15)
					events.append(_event("peace_signed", target, "آتش‌بس با %s برقرار شد" % get_country_name(target)))
				_:
					events.append(_event("offer_accepted", target, "پیشنهاد %s پذیرفته شد" % get_country_name(target)))
		"reject_offer":
			var rejected_offer = find_offer(world, target)
			world = _remove_offer(world, str(rejected_offer.get("id", "")))
			diplomacy["relations"][target] = clamp(float(diplomacy["relations"].get(target, 50.0)) - 2.0, 0.0, 100.0)
			events.append(_event("offer_rejected", target, "پیشنهاد %s رد شد" % get_country_name(target)))
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
	# کشورهای غیربازیکن: فقط نویز روزانه بسیار سبک؛ رشد کامل ماهانه در simulate_npc_month
	for country_id in world["countries"].keys():
		if country_id == world["player_country"]:
			continue
		var runtime: Dictionary = world["countries"][country_id]
		runtime["gdp"] = max(1.0, float(runtime.get("gdp", 1.0)) * (1.0 + Deterministic.next_range(-0.00003, 0.00004)))
		world["countries"][country_id] = runtime
	var finished: Array = []
	for target in world["wars"].keys():
		if not world["countries"].has(target):
			finished.append(target)
			continue
		var war: Dictionary = world["wars"][target]
		var enemy: Dictionary = world["countries"][target]
		# ==================== محاسبه نیروی واقعی - مدل عمیق چندعاملی (واقع‌گرایانه) ====================
		# اطلاعات شناسایی
		var recon_bonus = IntelligenceOperationManager.get_recon_bonus(state,target)
		var mil = state["military"]
		var mil_detail = mil.get("personnel_detail", {})
		var equip = mil.get("equipment_detail", {})
		var logi = mil.get("logistics_detail", {})
		var cmd_detail = mil.get("command_detail", {})
		var front_detail = mil.get("fronts_detail", {})

		# نیروی پایه
		var player_power = float(mil.get("power", 50.0))
		var readiness = float(mil.get("readiness", 0.6))
		var effective_readiness = float(mil.get("effective_readiness", readiness))

		# ضرایب پرسنلی
		var morale = float(mil_detail.get("morale", 0.70))
		var training = float(mil_detail.get("training_level", 0.65))
		var experience = float(mil_detail.get("experience", 0.50))
		var cohesion = float(mil_detail.get("cohesion", 0.68))
		var leadership = float(mil_detail.get("leadership_quality", 0.60))
		var personnel_factor = morale*0.25 + training*0.20 + experience*0.20 + cohesion*0.15 + leadership*0.20

		# ضرایب تجهیزاتی - نرخ عملیاتی و تنوع
		var operational_rate = float(equip.get("operational_rate", 0.75))
		var tank_factor = float(equip.get("tanks_mbt",1200))/1200.0*0.15
		var ifv_factor = float(equip.get("ifv",1500))/1500.0*0.10
		var artillery_factor = (float(equip.get("artillery_sp",500))+float(equip.get("mlrs",200))*1.5)/700.0*0.10
		var fighter_factor = (float(equip.get("fighters_multirole",120))+float(equip.get("fighters_air_superiority",80))*1.2)/200.0*0.15
		var drone_factor = (float(equip.get("uav_combat",80))+float(equip.get("uav_loitering",300))*0.3+float(equip.get("uav_swarm_capable",20))*2.0)/200.0*0.12
		var sam_factor = (float(equip.get("sam_long",18))+float(equip.get("sam_medium",40))*0.5)/40.0*0.08
		var missile_factor = (float(equip.get("ballistic_short",200))*0.2+float(equip.get("cruise_land_attack",300))*0.3+float(equip.get("hypersonic",10))*2.0)/200.0*0.10
		var naval_factor = (float(equip.get("destroyer",6))*15.0+float(equip.get("frigate",10))*10.0+float(equip.get("submarine_ssk",6))*20.0)/300.0*0.10
		var equipment_factor = clamp(operational_rate*0.5 + tank_factor+ifv_factor+artillery_factor+fighter_factor+drone_factor+sam_factor+missile_factor+naval_factor, 0.3, 2.0)

		# لجستیک - سوخت، مهمات، خطوط تدارک، آسیب‌پذیری
		var fuel_days = float(logi.get("fuel_stock_days",25.0))
		var ammo_days = float(logi.get("ammo_stock_days",20.0))
		var supply_vuln = float(logi.get("supply_line_vulnerability",0.30))
		var convoy_prot = float(logi.get("convoy_protection",0.60))
		var logistics_factor = clamp(fuel_days/30.0*0.25 + ammo_days/20.0*0.30 + float(logi.get("supply_lines",{}).get("road",0.60))*0.20 + convoy_prot*0.15 + (1.0-supply_vuln)*0.10, 0.15, 1.4)

		# فرماندهی - C4ISR، جنگ الکترونیک، ابتکار، چرخه تصمیم
		var c4isr = float(cmd_detail.get("c4isr_level",0.60))
		var ew = float(cmd_detail.get("ew_capability",0.55))
		var initiative = float(cmd_detail.get("initiative",0.60))
		var decision_cycle = float(cmd_detail.get("decision_cycle",24.0))
		var decision_factor = clamp(1.2 - decision_cycle/48.0, 0.5, 1.2) # چرخه کوتاه‌تر = بهتر
		var doctrine = cmd_detail.get("doctrine","balanced")
		var doctrine_mods = MilitaryManager.get_effective_modifiers(state)
		var doctrine_offense = float(doctrine_mods.get("offense_bonus",0.0))
		var doctrine_defense = float(doctrine_mods.get("defense_bonus",0.0))
		var command_factor = clamp(c4isr*0.30 + ew*0.20 + initiative*0.25 + decision_factor*0.15 + (0.5+doctrine_offense*0.3)*0.10, 0.4, 1.6)

		# جغرافیا و هوا - از جبهه‌ها
		var terrain_modifier = 1.0
		var weather_modifier = 1.0
		if front_detail.get("active_fronts",[]).size() > 0:
			for front in front_detail["active_fronts"]:
				if str(front.get("target","")) == target:
					var terrain = str(front.get("terrain","دشت"))
					var weather = str(front.get("weather","آفتابی"))
					# دکترین مانور در دشت بهتر، چریکی در کوهستان/شهری
					terrain_modifier += MilitaryManager.get_doctrine_bonus_for_terrain(doctrine, terrain)
					if weather == "بارانی":
						terrain_modifier -= 0.15 # گل و لای
						logistics_factor *= 0.85
					elif weather == "برفی":
						terrain_modifier -= 0.10
						if mil.get("military_development",{}).get("completed",[]).has("winter_warfare"):
							terrain_modifier += 0.15
					elif weather == "مه‌آلود":
						terrain_modifier -= 0.05
						fighter_factor *= 0.7 # دید کم
					break

		# برتری هوایی - از جبهه
		var air_superiority = 0.50
		if front_detail.get("active_fronts",[]).size() > 0:
			for front in front_detail["active_fronts"]:
				if str(front.get("target","")) == target:
					air_superiority = float(front.get("air_superiority",0.50))
					break
		var air_factor = clamp(0.6 + air_superiority*0.8, 0.3, 1.6) # برتری هوایی ۰ تا ۱.۶ برابر

		# فرمانده منصوب به این جبهه: ویژگی‌ها و تجربه، نیروی تهاجمی/دفاعی، لجستیک و هوا را تغییر می‌دهد
		var general_bonus: Dictionary = GeneralsManager.front_bonus(state, target)
		command_factor = clamp(command_factor + float(general_bonus.get("offense", 0.0)) + float(general_bonus.get("defense", 0.0)) * 0.5, 0.4, 1.8)
		logistics_factor = clamp(logistics_factor + float(general_bonus.get("logistics", 0.0)), 0.15, 1.5)
		air_factor = clamp(air_factor + float(general_bonus.get("air", 0.0)), 0.3, 1.7)

		# کمک متحدان
		var ally_support = 0.08 * float(world.get("alliances", []).size())
		var ally_factor = min(1.0 + ally_support, 1.30) # کمی بیشتر از قبل به خاطر عملیات مشترک

		# نیروی نهایی بازیکن - مدل چندضربی متوازن:
		# هر عامل به صورت (0.5 + f*0.5) اعمال می‌شود تا ضرب عوامل متعدد، نیرو را به‌شدت
		# له نکند (قبلاً ۷ عامل <1 باعث می‌شد نیروی ایران با قدرت ۳۲ در برابر آذربایجان ۴۸،
		# فقط ۵٪ نیروی دشمن باشد و بازیکن در ۱-۲ ماه همیشه ببازد).
		var player_force = player_power * (0.5 + effective_readiness*0.5)
		player_force *= (0.5 + personnel_factor*0.5)
		player_force *= (0.5 + equipment_factor*0.5)
		player_force *= (0.5 + logistics_factor*0.5)
		player_force *= (0.5 + command_factor*0.5)
		player_force *= (0.7 + terrain_modifier*0.3)
		player_force *= (0.8 + weather_modifier*0.2)
		player_force *= (0.5 + air_factor*0.5)
		player_force *= (1.0 + recon_bonus)
		player_force *= ally_factor

		# نیروی دشمن - با نویز و متحدان NPC و قدرت دریایی و هوایی
		var enemy_base = float(enemy.get("military_power", 50.0))
		var enemy_allies = 0
		for pair_key in world.get("npc_alliances", []):
			if str(pair_key).split("|").has(target):
				enemy_allies += 1
		var enemy_ally_factor = min(1.0 + 0.06 * float(enemy_allies), 1.25)
		var enemy_terrain = 1.0 # دشمن در خانه می‌جنگد = دفاع بهتر
		if Deterministic.chance(0.6):
			enemy_terrain = 1.15
		var enemy_logistics = clamp(0.7 + Deterministic.next_range(-0.1,0.15), 0.4, 1.2)
		var enemy_force = enemy_base * 0.70 * enemy_ally_factor * enemy_terrain * enemy_logistics * (0.9 + Deterministic.next_range(-0.15,0.15))

		# نسبت قوا و محاسبه پیشرفت روزانه با قانون لانچستر + عوامل
		var force_ratio = player_force / max(enemy_force, 1.0)
		var advantage = (player_force - enemy_force) / max(player_force + enemy_force, 1.0) # -1 تا +1
		# پیشرفت روزانه: اگر برتری + terrain + هوا + لجستیک خوب باشد، پیشروی سریع‌تر
		var base_progress = advantage * 3.5
		base_progress += (air_superiority - 0.5)*1.2 # برتری هوایی
		base_progress += (logistics_factor - 0.8)*0.8
		base_progress += (command_factor - 0.8)*0.6
		base_progress += doctrine_offense*0.5
		base_progress += Deterministic.next_range(-1.0, 1.0) # نویز واقعی جنگ
		# اگر تدارکات بحرانی، پیشروی کند یا حتی منفی
		if fuel_days < 5.0 or ammo_days < 3.0:
			base_progress -= 1.5
		var daily_progress = clamp(base_progress, -1.4, 1.4)
		war["progress"] = float(war.get("progress", 0.0)) + daily_progress

		# تلفات واقعی - چندعاملی: قدرت دشمن * آسیب‌پذیری + مهمات + لجستیک + دکترین
		var casualty_modifier = 1.0 - float(MilitaryManager.get_effective_modifiers(state).get("casualty_reduction", 0.0))
		# تلفات ما: نیروی دشمن * (1 - دفاع) * (1 - لجستیک پزشکی) * terrain
		var defense_factor = 1.0 + doctrine_defense
		var medical_factor = float(state.get("military",{}).get("logistics_detail",{}).get("medical_capacity",0.70))
		var player_loss_base = enemy_force * (0.5 + (1.0 - defense_factor*0.3)) * (1.2 - medical_factor*0.3) * (0.8 + supply_vuln*0.4)
		var player_loss = int(max(15.0, player_loss_base * Deterministic.next_range(0.5, 1.4) * casualty_modifier * (1.3 if fuel_days < 5.0 else 1.0)))

		# تلفات دشمن: نیروی ما * حمله * برتری هوایی * پهپاد
		var offense_factor = 1.0 + doctrine_offense
		var enemy_loss_base = player_force * offense_factor * air_factor * (0.7 + drone_factor*0.5) * (0.6 + missile_factor*0.3)
		var enemy_loss = int(max(15.0, enemy_loss_base * Deterministic.next_range(0.5, 1.4) * (1.2 if air_superiority > 0.7 else 0.9)))

		# تلفات تجهیزات (نسبتی از تلفات انسانی)
		var equip_loss_ratio = 0.08
		var player_equip_loss = int(player_loss * equip_loss_ratio)
		var enemy_equip_loss = int(enemy_loss * equip_loss_ratio)
		# ثبت تلفات انسانی و تجهیزاتی - واقعی
		war["player_losses"] = int(war.get("player_losses", 0)) + player_loss
		war["enemy_losses"] = int(war.get("enemy_losses", 0)) + enemy_loss
		war["player_equip_losses"] = int(war.get("player_equip_losses", 0)) + player_equip_loss
		war["enemy_equip_losses"] = int(war.get("enemy_equip_losses", 0)) + enemy_equip_loss
		war["daily_progress"] = daily_progress
		war["force_ratio"] = force_ratio
		war["air_superiority"] = air_superiority

		# کاهش پرسنل تفصیلی
		state["military"]["personnel"] = max(1000, int(state["military"].get("personnel", 500000)) - player_loss)
		var personnel_detail = state["military"].get("personnel_detail", {})
		if not personnel_detail.is_empty():
			personnel_detail["casualties_kia"] = int(personnel_detail.get("casualties_kia",0)) + int(player_loss*0.35)
			personnel_detail["casualties_wia"] = int(personnel_detail.get("casualties_wia",0)) + int(player_loss*0.50)
			personnel_detail["casualties_mia"] = int(personnel_detail.get("casualties_mia",0)) + int(player_loss*0.05)
			personnel_detail["pow"] = int(personnel_detail.get("pow",0)) + int(player_loss*0.10)
			personnel_detail["morale"] = clamp(float(personnel_detail.get("morale",0.70)) - 0.0012 - float(state["military"].get("war_exhaustion",0.0))*0.0005, 0.10, 0.95)
			personnel_detail["experience"] = clamp(float(personnel_detail.get("experience",0.50)) + 0.0015, 0.20, 0.95) # تجربه با جنگ
			state["military"]["personnel_detail"] = personnel_detail

		# کاهش تجهیزات - تانک، نفربر، توپ، پهپاد
		var equip_detail = state["military"].get("equipment_detail", {})
		if not equip_detail.is_empty():
			equip_detail["tanks_mbt"] = max(0, int(equip_detail.get("tanks_mbt",1200)) - int(player_equip_loss*0.15))
			equip_detail["ifv"] = max(0, int(equip_detail.get("ifv",1500)) - int(player_equip_loss*0.20))
			equip_detail["apc"] = max(0, int(equip_detail.get("apc",2500)) - int(player_equip_loss*0.25))
			equip_detail["artillery_sp"] = max(0, int(equip_detail.get("artillery_sp",500)) - int(player_equip_loss*0.08))
			equip_detail["uav_combat"] = max(0, int(equip_detail.get("uav_combat",80)) - int(player_equip_loss*0.05))
			equip_detail["uav_loitering"] = max(0, int(equip_detail.get("uav_loitering",300)) - int(player_equip_loss*0.10))
			equip_detail["operational_rate"] = clamp(float(equip_detail.get("operational_rate",0.75)) - 0.0015, 0.15, 0.95)
			state["military"]["equipment_detail"] = equip_detail

		# کاهش آمادگی و ذخایر لجستیکی با مصرف جنگی
		var logi_detail = state["military"].get("logistics_detail", {})
		if not logi_detail.is_empty():
			logi_detail["fuel_stock_days"] = clamp(float(logi_detail.get("fuel_stock_days",25.0)) - 0.08 - supply_vuln*0.05, 0.5, 90.0)
			logi_detail["ammo_stock_days"] = clamp(float(logi_detail.get("ammo_stock_days",20.0)) - 0.10 - (1.0-air_superiority)*0.05, 0.2, 60.0)
			# کاهش مهمات تفکیکی
			var ammo_types = logi_detail.get("ammo_types", {})
			for k in ammo_types.keys():
				ammo_types[k] = clamp(float(ammo_types[k]) - Deterministic.next_range(0.2,0.8), 0.0, 150.0)
			logi_detail["ammo_types"] = ammo_types
			state["military"]["logistics_detail"] = logi_detail

		state["military"]["readiness"] = clamp(float(state["military"].get("readiness", 0.6)) - 0.0012 - supply_vuln*0.0005, 0.08, 1.0)
		state["economy"]["gdp"] *= 0.99994 # هزینه کمی بیشتر به خاطر جنگ عمیق
		# هزینه‌ی واقعی جنگ: حدود ۰٫۵٪ GDP سالانه بر بدهی (جنگ مدرن گران‌تر)
		state["economy"]["national_debt"] = float(state["economy"].get("national_debt", 0.0)) + float(state["economy"].get("gdp", 1.0)) * 0.005 / 365.0
		# خستگی جنگ با تلفات و طول جنگ (+ هدف الحاق: جنگ طاقت‌فرسا)
		var goal_extra := 0.004 if str(war.get("goal", "reparations")) == "annexation" else 0.0
		state["military"]["war_exhaustion"] = clamp(float(state["military"].get("war_exhaustion", 0.0)) + 0.005 + float(player_loss)/500000.0*0.01 + goal_extra, 0.0, 1.0)
		enemy["military_power"] = max(10.0, float(enemy["military_power"]) - enemy_loss / 500000.0)
		world["countries"][target] = enemy
		if war["progress"] >= 100.0:
			finished.append(target)
			war["outcome"] = "victory"
			war["ended_tick"] = tick
			world["war_history"].append(war.duplicate(true))
			diplomacy["relations"][target] = 18.0
			diplomacy["influence"] = clamp(float(diplomacy.get("influence", 40.0)) + 6.0, 0.0, 100.0)
			# غنایم و بازارهای تازه: رشد یک‌باره اقتصادی و امید عمومی پس از پیروزی
			state["economy"]["gdp"] = float(state["economy"].get("gdp", 1.0)) * 1.02
			state["population"]["happiness"] = clamp(float(state["population"].get("happiness", 0.5)) + 0.04, 0.05, 0.95)
			state["military"]["war_exhaustion"] = max(0.0, float(state["military"].get("war_exhaustion", 0.0)) - 0.20)
			# نتیجه بر پایه هدف جنگی — هر هدف پیامد متفاوتی دارد
			var goal_outcome := _apply_war_goal_victory(state, target, str(war.get("goal", "reparations")), war)
			state = goal_outcome.state
			events.append_array(goal_outcome.events)
			events.append(_event("war_victory", target, "پیروزی در جنگ با %s؛ رهبر در قدرت باقی ماند و غنایم به خزانه رسید" % get_country_name(target)))
		elif war["progress"] <= -100.0:
			finished.append(target)
			war["outcome"] = "defeat"
			war["ended_tick"] = tick
			world["war_history"].append(war.duplicate(true))
			diplomacy["relations"][target] = 12.0
			state["politics"]["stability"] = clamp(float(state["politics"].get("stability", 0.5)) - 0.08, 0.05, 0.95)
			state["population"]["happiness"] = clamp(float(state["population"].get("happiness", 0.5)) - 0.06, 0.05, 0.95)
			# جبران خسارت جنگ: بدهی پرش می‌کند و اقتصاد ضربه می‌خورد
			state["economy"]["national_debt"] = float(state["economy"].get("national_debt", 0.0)) + float(state["economy"].get("gdp", 1.0)) * 0.03
			state["economy"]["gdp"] = float(state["economy"].get("gdp", 1.0)) * 0.97
			state["military"]["war_exhaustion"] = clamp(float(state["military"].get("war_exhaustion", 0.0)) + 0.10, 0.0, 1.0)
			# جریمه بر پایه هدف جنگیِ پیروز (هر هدف پیامد متفاوتی دارد)
			var defeat_outcome := _apply_war_goal_defeat(state, target, str(war.get("goal", "reparations")), war)
			state = defeat_outcome.state
			events.append_array(defeat_outcome.events)
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

	# ===== رشد ماهانه کشورهای غیربازیکن (جهان زنده) =====
	# هر کشور بر پایه سطح فناوری، بلوک و منطقه رشد اقتصادی، جمعیت و قدرت نظامی واقعی دارد.
	var world_growth_shock = Deterministic.next_range(-0.004, 0.006) # شوک اقتصادی جهانی ماهانه
	for country_id in world["countries"].keys():
		if country_id == player_id:
			continue
		var runtime: Dictionary = world["countries"][country_id]
		var base_growth = 0.0012 + float(runtime.get("tech_level", 0.35)) * 0.0018
		var bloc_growth = {"غربی": 0.0008, "شرقی": 0.0006, "جنوب": 0.0003}.get(str(runtime.get("bloc", "")), 0.0002)
		var at_war = false
		for war_key in world.get("npc_wars", {}).keys():
			if str(war_key).split("|").has(country_id):
				at_war = true
				break
		var growth = base_growth + bloc_growth + world_growth_shock + (-0.006 if at_war else 0.0)
		growth += Deterministic.next_range(-0.0008, 0.0012)
		runtime["gdp"] = max(1.0, float(runtime.get("gdp", 1.0)) * (1.0 + growth))
		var pop_growth = {"Africa": 0.0016, "Americas": 0.0007, "Asia": 0.0009, "Europe": 0.0002, "Oceania": 0.0008}.get(str(runtime.get("region", "")), 0.0008)
		pop_growth += Deterministic.next_range(-0.0002, 0.0003)
		if at_war:
			pop_growth -= 0.001
		runtime["population"] = max(100_000.0, float(runtime.get("population", 1_000_000.0)) * (1.0 + pop_growth))
		runtime["military_power"] = clamp(float(runtime.get("military_power", 50.0)) + growth * 30.0 + Deterministic.next_range(-0.08, 0.12), 8.0, 130.0)
		runtime["tech_level"] = clamp(float(runtime.get("tech_level", 0.35)) + 0.00015 + Deterministic.next_range(-0.00005, 0.0001), 0.05, 0.95)
		world["countries"][country_id] = runtime
	state["world"] = world

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
			drift += (78.0 - relation) * 0.015
		else:
			drift += (48.0 - relation) * 0.006
		# بلوک‌های متضاد (غربی-اوراسیا): تنش ساختاری → روابط آرام به سمت آستانه جنگ می‌رود
		var blocs_a = str(profile_a.get("bloc", "")); var blocs_b = str(profile_b.get("bloc", ""))
		var opposing = (blocs_a == "غربی" and blocs_b == "اوراسیا") or (blocs_a == "اوراسیا" and blocs_b == "غربی")
		if opposing:
			drift += (20.0 - relation) * 0.028
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

	# فاز اجرای تصمیم‌های کشورهای غیربازیکن: هر کشور در آغاز نوبت تصمیم گرفت
	# (NpcTurnManager.plan_npc_turn) و اکنون در پایان نوبت یکجا اجرا می‌شود.
	var npc_exec_result = NpcTurnManagerClass.execute_npc_turn(state, turn)
	state = npc_exec_result.state
	world = state["world"]
	relations = world.get("npc_relations", {})
	npc_wars = world.get("npc_wars", {})
	npc_alliances = world.get("npc_alliances", [])
	npc_trade = world.get("npc_trade_agreements", [])
	events.append_array(npc_exec_result.events)

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
		war["progress"] = float(war.get("progress", 0.0)) + clamp(advantage * 4.0 + Deterministic.next_range(-1.5, 1.5), -3.5, 3.5)
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
			# ثبت جنگ تمام‌شده در تاریخچه (برای نمایش و حس جهان زنده)
			var ended_war: Dictionary = war.duplicate(true)
			ended_war["winner"] = winner
			ended_war["loser"] = loser
			ended_war["ended_turn"] = turn
			world["war_history"].append(ended_war)
			while world["war_history"].size() > 50:
				world["war_history"].pop_front()
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

func get_strategic_country_ids(player_id: String = "", limit: int = 40) -> Array:
	var ids = countries.keys()
	ids.sort_custom(func(a,b): return float(countries[a].get("strategic_weight",0.0)) > float(countries[b].get("strategic_weight",0.0)))
	var selected: Array = ids.slice(0,min(limit,ids.size()))
	if countries.has(player_id):
		var player = countries[player_id]
		var nearby: Array = []
		for id in countries.keys():
			if id == player_id: continue
			var other = countries[id]
			var distance = Vector2(float(player.get("lon",0.0)),float(player.get("lat",0.0))).distance_to(Vector2(float(other.get("lon",0.0)),float(other.get("lat",0.0))))
			nearby.append({"id":id,"distance":distance})
		nearby.sort_custom(func(a,b): return float(a.distance) < float(b.distance))
		for item in nearby.slice(0,min(8,nearby.size())):
			if not selected.has(item.id): selected.append(item.id)
	return selected

func _build_npc_relations(player_id: String) -> Dictionary:
	var matrix: Dictionary = {}
	# ماتریس کامل ۱۹۵×۱۹۵ برای هر بازیکن حجیم است؛ AI راهبردی روی ۴۰ قدرت اصلی
	# و نزدیک‌ترین همسایگان کشور بازیکن اجرا می‌شود. همه ۱۹۵ کشور همچنان قابل‌بازی‌اند.
	var ids = get_strategic_country_ids(player_id, 40)
	ids.sort()

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

# --- پیشنهادهای ورودی (رودمپ ۵) ---
# offer_types خالی یعنی هر نوعی؛ جست‌وجو بر اساس کشور فرستنده
func find_offer(world: Dictionary, country: String) -> Dictionary:
	for offer in world.get("incoming_offers", []):
		if str(offer.get("from", "")) == country:
			return offer
	return {}

func _has_offer(world: Dictionary, offer_types: Array, country: String) -> bool:
	for offer in world.get("incoming_offers", []):
		if str(offer.get("from", "")) != country:
			continue
		if offer_types.is_empty() or offer_types.has(str(offer.get("type", ""))):
			return true
	return false

func _remove_offer(world: Dictionary, offer_id: String) -> Dictionary:
	var kept: Array = []
	for offer in world.get("incoming_offers", []):
		if str(offer.get("id", "")) == offer_id:
			continue
		kept.append(offer)
	world["incoming_offers"] = kept
	return world

func _remove_treaty(diplomacy: Dictionary, treaty_type: String, target: String):
	var kept: Array = []
	for treaty in diplomacy.get("treaties", []):
		if treaty is Dictionary and treaty.get("type", "") == treaty_type and treaty.get("target", "") == target:
			continue
		kept.append(treaty)
	diplomacy["treaties"] = kept

func _event(type: String, target: String, message: String) -> Dictionary:
	return {"type":type, "target":target, "country":get_country_name(target), "message":message}


# ────────────────────────────────────────────────────────────────
# اهداف جنگی: مقیاس و پیامدهای پیروزی/شکست بر پایه هدف
# ────────────────────────────────────────────────────────────────
func war_goal_scale(goal: String) -> float:
	# مقیاس دشواری/بها: هر هدف جنگی «بهای» متفاوتی دارد
	return {"reparations": 1.0, "annexation": 1.6, "humiliation": 0.8, "liberation": 0.7}.get(goal, 1.0)

func get_war_goal_name(goal: String) -> String:
	return {"reparations": "غرامت جنگی", "annexation": "الحاق و سلطه", "humiliation": "تحقیر راهبردی", "liberation": "آزادسازی"}.get(goal, goal)

func _apply_war_goal_victory(state: Dictionary, target: String, goal: String, war: Dictionary) -> Dictionary:
	var events: Array = []
	var world: Dictionary = state.get("world", {})
	var econ: Dictionary = state.get("economy", {})
	var player_id := str(world.get("player_country", default_country))
	var enemy: Dictionary = world.get("countries", {}).get(target, {})
	var enemy_gdp := float(enemy.get("gdp", 1.0))
	var leader: Dictionary = state.get("leader", {})
	match goal:
		"reparations":
			# GDP کشورها در world به دلار خام است؛ غرامت = ۴٪ تولید ناخالص دشمن
			var payout: float = enemy_gdp * 0.04
			econ["foreign_reserves"] = float(econ.get("foreign_reserves", 0.0)) + payout
			diplomacy_relations_add(state, target, -10.0)
			events.append({"type": "war_reparations", "message": "%s غرامت جنگی معادل %s به خزانه کشور واریز کرد" % [get_country_name(target), PersianFormatter.format_money(payout)]})
		"annexation":
			if _is_neighbor_state(state, player_id, target):
				# الحاق بخشی از خاک و توانایی‌ها
				world["annexations"].append({"annexed": target, "by": player_id, "turn": int(war.get("ended_tick", 0)), "partial": true})
				enemy["partial_annexed_by"] = player_id
				var gain := enemy_gdp * 0.05
				enemy["gdp"] = maxf(1.0, enemy_gdp * 0.95)
				econ["gdp"] = float(econ.get("gdp", 1.0)) * (1.0 + gain * 0.02)
				enemy["population"] = maxf(100000.0, float(enemy.get("population", 1.0)) * 0.94)
				world["countries"][target] = enemy
				events.append({"type": "war_annexation", "message": "بخشی از خاک %s ضمیمه کشور شد و توانایی‌های آن به کشور شما منتقل گردید" % get_country_name(target)})
			else:
				# بدون مرز: حاکم دست‌نشانده
				world["puppets"].append({"puppet": target, "master": player_id, "turn": int(war.get("ended_tick", 0))})
				enemy["puppet_master"] = player_id
				world["countries"][target] = enemy
				events.append({"type": "war_puppet", "message": "%s تحت حاکمیت دست‌نشانده کشور شما قرار گرفت" % get_country_name(target)})
			leader["popularity_world"] = clampf(float(leader.get("popularity_world", 50.0)) - 6.0, 0.0, 100.0)
			state["leader"] = leader
		"humiliation":
			diplomacy_relations_add(state, target, -18.0)
			state["diplomacy"]["influence"] = clamp(float(state["diplomacy"].get("influence", 40.0)) + 10.0, 0.0, 100.0)
			events.append({"type": "war_humiliation", "message": "%s در برابر کشور شما تحقیر شد؛ نفوذ بین‌المللی کشور به‌شدت بالا رفت" % get_country_name(target)})
		"liberation":
			leader["popularity_world"] = clampf(float(leader.get("popularity_world", 50.0)) + 8.0, 0.0, 100.0)
			diplomacy_relations_add(state, target, 12.0)
			state["diplomacy"]["influence"] = clamp(float(state["diplomacy"].get("influence", 40.0)) + 8.0, 0.0, 100.0)
			state["population"]["happiness"] = clamp(float(state["population"].get("happiness", 0.5)) + 0.03, 0.05, 0.95)
			events.append({"type": "war_liberation", "message": "پیروزی آزادی‌بخش، کشور را در جهان محبوب کرد و رهبر اعتبار بین‌المللی گرفت"})
	state["economy"] = econ
	state["world"] = world
	return {"state": state, "events": events}

func _apply_war_goal_defeat(state: Dictionary, target: String, goal: String, war: Dictionary) -> Dictionary:
	var events: Array = []
	var econ: Dictionary = state.get("economy", {})
	var leader: Dictionary = state.get("leader", {})
	var gdp := float(econ.get("gdp", 1.0))
	match goal:
		"annexation":
			econ["national_debt"] = float(econ.get("national_debt", 0.0)) + gdp * 0.05
			leader["popularity_world"] = clampf(float(leader.get("popularity_world", 50.0)) - 4.0, 0.0, 100.0)
			events.append({"type": "war_defeat_annexation", "message": "دشمنِ الحاق‌طلب پیروز شد؛ بدهی سنگینی بر کشور تحمیل و اعتبار رهبر در جهان خدشه‌دار شد"})
		"reparations":
			var payout := gdp * 0.03
			econ["foreign_reserves"] = maxf(0.0, float(econ.get("foreign_reserves", 0.0)) - payout)
			events.append({"type": "war_reparations_paid", "message": "کشور موظف به پرداخت غرامت جنگی به %s شد و ذخایر ارزی کاهش یافت" % get_country_name(target)})
		"humiliation":
			state["diplomacy"]["influence"] = clamp(float(state["diplomacy"].get("influence", 40.0)) - 8.0, 0.0, 100.0)
			events.append({"type": "war_humiliation_suffered", "message": "شکست تحقیرآمیز، نفوذ دیپلماتیک کشور را به‌شدت کاهش داد"})
		_:
			events.append({"type": "war_defeat_terms", "message": "پایان جنگ با شرایط دشمن؛ کشور آسیب اقتصادی دید"})
	state["economy"] = econ
	state["leader"] = leader
	return {"state": state, "events": events}

func _is_neighbor_state(state: Dictionary, a: String, b: String) -> bool:
	var profile_a: Dictionary = countries.get(a, {})
	var profile_b: Dictionary = countries.get(b, {})
	var lat_a := deg_to_rad(float(profile_a.get("lat", 0.0)))
	var lon_a := deg_to_rad(float(profile_a.get("lon", 0.0)))
	var lat_b := deg_to_rad(float(profile_b.get("lat", 0.0)))
	var lon_b := deg_to_rad(float(profile_b.get("lon", 0.0)))
	var dlat := lat_b - lat_a
	var dlon := lon_b - lon_a
	var h: float = pow(sin(dlat * 0.5), 2.0) + cos(lat_a) * cos(lat_b) * pow(sin(dlon * 0.5), 2.0)
	var dist_deg: float = rad_to_deg(2.0 * atan2(sqrt(h), sqrt(max(0.0, 1.0 - h))))
	return dist_deg <= 16.0

func diplomacy_relations_add(state: Dictionary, target: String, delta: float):
	var relations: Dictionary = state.get("diplomacy", {}).get("relations", {})
	if relations.has(target):
		relations[target] = clampf(float(relations[target]) + delta, 0.0, 100.0)
		state["diplomacy"]["relations"] = relations
