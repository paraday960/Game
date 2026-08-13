extends RefCounted
class_name GameCommand
# فرمان‌محور - بخش ۳.۷ لایه ۶ - فقط فرمان ارسال می‌شود نه وضعیت

var id: String
var type: String
var player_id: String
var tick: int
var version: int
var payload: Dictionary
var timestamp: float

# شمارنده دترمینستیک - بدون randi() تا قفل دترمینستیک نشکند (بخش ۳.۶)
static var _counter: int = 0

func _init(p_type: String, p_payload: Dictionary = {}, p_player_id: String = "player1"):
	type = p_type
	payload = p_payload
	player_id = p_player_id
	tick = 0
	version = 0
	timestamp = Time.get_unix_time_from_system()
	_counter += 1
	id = "%s_%s_%d" % [type, player_id, _counter]

func to_dict() -> Dictionary:
	return {
		"id": id,
		"type": type,
		"player_id": player_id,
		"tick": tick,
		"version": version,
		"payload": payload,
		"timestamp": timestamp
	}

static func from_dict(d: Dictionary):
	var cmd = _self_script().new(d.get("type", "unknown"), d.get("payload", {}), d.get("player_id", "player1"))
	cmd.id = d.get("id", "")
	cmd.tick = d.get("tick", 0)
	cmd.version = d.get("version", 0)
	cmd.timestamp = d.get("timestamp", 0.0)
	return cmd

# لود خودارجاع - سازگار با import سرد
static func _self_script():
	return load("res://scripts/core/command.gd")

# انواع فرمان‌های بازی
static func create_budget_allocate(allocations: Dictionary):
	return _self_script().new("budget_allocate", {"allocations": allocations})

static func create_tax_set(rate: float):
	return _self_script().new("tax_set", {"rate": rate})

static func create_monetary_policy(mode: String, value: float = 0.0):
	return _self_script().new("monetary_policy", {"mode": mode, "value": value})

static func create_tariff_set(rate: float):
	return _self_script().new("tariff_set", {"rate": rate})

static func create_research_start(tech_id: String):
	return _self_script().new("research_start", {"tech_id": tech_id})

static func create_diplomacy_action(target: String, action: String, goal: String = ""):
	var payload := {"target": target, "action": action}
	if goal != "":
		payload["goal"] = goal
	return _self_script().new("diplomacy", payload)

static func create_country_select(country_id: String, scenario_id: String = "balanced"):
	return _self_script().new("country_select", {"country_id": country_id, "scenario_id": scenario_id})

static func create_policy_change(policy_id: String, enabled: bool):
	return _self_script().new("policy_change", {"policy_id": policy_id, "enabled": enabled})

static func create_municipal_action(action: String):
	return _self_script().new("municipal_action", {"action": action})

static func create_military_program(program_id: String):
	return _self_script().new("military_program", {"program_id": program_id})

static func create_military_doctrine(doctrine: String):
	return _self_script().new("military_doctrine", {"doctrine": doctrine})

static func create_national_project(project_id: String):
	return _self_script().new("national_project", {"project_id": project_id, "action": "start"})

static func create_project_cancel(project_id: String):
	return _self_script().new("national_project", {"project_id": project_id, "action": "cancel"})

static func create_cabinet_appointment(ministry_id: String, candidate_id: String):
	return _self_script().new("cabinet_change", {"ministry_id": ministry_id, "candidate_id": candidate_id, "action": "appoint"})

static func create_cabinet_dismissal(ministry_id: String):
	return _self_script().new("cabinet_change", {"ministry_id": ministry_id, "candidate_id": "", "action": "dismiss"})

static func create_law_change(law_id: String, action: String):
	return _self_script().new("law_change", {"law_id": law_id, "action": action})

static func create_intelligence_operation(operation_id: String, target: String = ""):
	return _self_script().new("intelligence_operation", {"operation_id": operation_id, "target": target, "action": "start"})

static func create_intelligence_cancel(operation_key: String):
	return _self_script().new("intelligence_operation", {"operation_key": operation_key, "action": "cancel"})

static func create_decision_resolve(decision_id: String, choice_id: String):
	return _self_script().new("decision_resolve", {"decision_id": decision_id, "choice_id": choice_id})

static func create_next_tick():
	return _self_script().new("next_tick", {})

static func create_assassinate(target_country: String):
	return _self_script().new("assassinate", {"target": target_country})

static func create_leader_hidden(hidden: bool):
	return _self_script().new("leader_hidden", {"hidden": hidden})

static func create_faction_action(faction: String, action: String):
	return _self_script().new("faction_action", {"faction": faction, "action": action})

static func create_set_war_goal(target: String, goal: String):
	return _self_script().new("set_war_goal", {"target": target, "goal": goal})

static func create_general_recruit():
	return _self_script().new("general_recruit", {})

static func create_general_assign(commander_id: String, war_target: String):
	return _self_script().new("general_assign", {"commander_id": commander_id, "war_target": war_target})

static func create_media_policy(policy: String):
	return _self_script().new("media_policy", {"policy": policy})

static func create_media_campaign(target_group: String, style: String):
	return _self_script().new("media_campaign", {"target_group": target_group, "style": style})

static func create_commodity_trade(commodity: String, amount: float):
	return _self_script().new("commodity_trade", {"commodity": commodity, "amount": amount})

static func create_org_toggle(org: String):
	return _self_script().new("org_toggle", {"org": org})

static func create_org_vote(decision: String):
	return _self_script().new("org_vote", {"decision": decision})

static func create_snap_election():
	return _self_script().new("snap_election", {})

static func create_campaign_promise(promise_id: String):
	return _self_script().new("campaign_promise", {"promise_id": promise_id})

static func create_forex_intervene(amount_billion: float):
	return _self_script().new("forex_intervene", {"amount_billion": amount_billion})

static func create_forex_devalue(percent: float):
	return _self_script().new("forex_devalue", {"percent": percent})

static func create_capital_control():
	return _self_script().new("capital_control", {})

static func create_governor_appoint(province_code: String, faction: String):
	return _self_script().new("governor_appoint", {"province_code": province_code, "faction": faction})

static func create_crisis_stance(stance: String):
	return _self_script().new("crisis_stance", {"stance": stance})

static func create_rivalry_action(action: String):
	return _self_script().new("rivalry_action", {"action": action})

static func create_shadow_action(action: String):
	return _self_script().new("shadow_action", {"action": action})

static func create_court_action(action: String):
	return _self_script().new("court_action", {"action": action})

static func create_energy_action(action: String):
	return _self_script().new("energy_action", {"action": action})

static func create_industry_action(action: String, value: String = ""):
	return _self_script().new("industry_action", {"action": action, "value": value})

static func create_succession_action(action: String):
	return _self_script().new("succession_action", {"action": action})

static func create_labor_action(action: String):
	return _self_script().new("labor_action", {"action": action})

static func create_epidemic_action(action: String):
	return _self_script().new("epidemic_action", {"action": action})

static func create_arms_action(action: String, target: String = "", amount: float = 0.0):
	return _self_script().new("arms_action", {"action": action, "target": target, "amount": amount})

static func create_cyber_action(action: String, target: String = "", kind: String = ""):
	return _self_script().new("cyber_action", {"action": action, "target": target, "kind": kind})

static func create_migration_action(action: String):
	return _self_script().new("migration_action", {"action": action})

static func create_culture_action(action: String, kind: String = ""):
	return _self_script().new("culture_action", {"action": action, "kind": kind})

static func create_education_action(action: String):
	return _self_script().new("education_action", {"action": action})

static func create_agriculture_action(action: String):
	return _self_script().new("agriculture_action", {"action": action})

static func create_tourism_action(action: String, value: String = ""):
	return _self_script().new("tourism_action", {"action": action, "value": value})

static func create_urban_action(action: String):
	return _self_script().new("urban_action", {"action": action})

static func create_security_action(action: String):
	return _self_script().new("security_action", {"action": action})

static func create_infra_action(action: String, value: float = 0.0):
	return _self_script().new("infra_action", {"action": action, "value": value})

static func create_climate_action(action: String, value: float = 0.0):
	return _self_script().new("climate_action", {"action": action, "value": value})

static func create_welfare_action(action: String, value: float = 0.0):
	return _self_script().new("welfare_action", {"action": action, "value": value})

static func create_space_action(action: String):
	return _self_script().new("space_action", {"action": action})

static func create_trade_policy_action(action: String):
	return _self_script().new("trade_policy_action", {"action": action})

static func create_banking_action(action: String, value: float = 0.0):
	return _self_script().new("banking_action", {"action": action, "value": value})

static func create_fdi_action(action: String, value: float = 0.0):
	return _self_script().new("fdi_action", {"action": action, "value": value})

static func create_ambassador_action(action: String, country: String = ""):
	return _self_script().new("ambassador_action", {"action": action, "country": country})

static func create_digital_action(action: String):
	return _self_script().new("digital_action", {"action": action})

static func create_sports_action(action: String):
	return _self_script().new("sports_action", {"action": action})

static func create_dilemma_resolve(choice: String):
	return _self_script().new("dilemma_resolve", {"choice": choice})

static func create_stock_action(action: String):
	# action: ipo, support, capgains, watchdog
	return _self_script().new("stock_action", {"action": action})

static func create_veterans_action(action: String):
	# action: pension, employment, clinic, parade
	return _self_script().new("veterans_action", {"action": action})

static func create_heritage_action(action: String):
	# action: restore, register, festival, antiquities
	return _self_script().new("heritage_action", {"action": action})

static func create_transport_action(action: String):
	# action: metro, brt, subsidy, fleet
	return _self_script().new("transport_action", {"action": action})

static func create_retail_action(action: String):
	# action: price, protect, ecommerce, bazaar
	return _self_script().new("retail_action", {"action": action})

static func create_ethnicity_action(action: String):
	# action: equal, autonomy, dialogue, festival
	return _self_script().new("ethnicity_action", {"action": action})

static func create_water_action(action: String):
	# action: dam, desal, leakage, irrigation
	return _self_script().new("water_action", {"action": action})

static func create_research_action(action: String):
	# action: university, center, transfer, talent
	return _self_script().new("research_action", {"action": action})

static func create_civic_action(action: String):
	# action: opendata, councils, budget, ngos
	return _self_script().new("civic_action", {"action": action})

static func create_diaspora_action(action: String):
	# action: summit, networks, diplomacy, return
	return _self_script().new("diaspora_action", {"action": action})

static func create_civil_defense_action(action: String):
	# action: hardening, redundancy, shelters, stockpile
	return _self_script().new("civil_defense_action", {"action": action})

static func create_blue_economy_action(action: String):
	# action: port, fleet, fishery, patrol
	return _self_script().new("blue_economy_action", {"action": action})

static func create_creative_action(action: String):
	# action: funding, education, platform, export
	return _self_script().new("creative_action", {"action": action})

static func create_demographic_action(action: String):
	# action: pronatal, childcare, elderly, retraining
	return _self_script().new("demographic_action", {"action": action})

static func create_watershed_action(action: String):
	# action: restore, forest, dust, wetlands
	return _self_script().new("watershed_action", {"action": action})

static func create_prison_action(action: String):
	# action: capacity, education, amnesty
	return _self_script().new("prison_action", {"action": action})

static func create_prison_approach(approach: String):
	return _self_script().new("prison_action", {"action": "approach", "approach": approach})

static func create_statistics_action(action: String):
	# action: census, infra, independence, opendata
	return _self_script().new("statistics_action", {"action": action})

static func create_mining_action(action: String):
	# action: mine, refinery, safety, formalize
	return _self_script().new("mining_action", {"action": action})

static func create_waste_action(action: String):
	# action: collection, recycling, landfill, circular
	return _self_script().new("waste_action", {"action": action})

static func create_insurance_action(action: String):
	# action: universal, health, agri, regulation
	return _self_script().new("insurance_action", {"action": action})

static func create_rural_action(action: String):
	# action: roads, internet, processing, nomads
	return _self_script().new("rural_action", {"action": action})

static func create_judicial_reform_action(action: String):
	# action: digital, specialized, mediation, legalaid
	return _self_script().new("judicial_reform_action", {"action": action})

static func create_election_action(action: String):
	# action: hold, monitoring, access, pluralism
	return _self_script().new("election_action", {"action": action})

static func create_fuel_action(action: String):
	# action: reform, charging, emission, fleet
	return _self_script().new("fuel_action", {"action": action})

static func create_housing_action(action: String):
	return _self_script().new("housing_action", {"action": action})

static func create_startup_action(action: String):
	return _self_script().new("startup_action", {"action": action})

static func create_sme_action(action: String):
	return _self_script().new("sme_action", {"action": action})

static func create_supply_action(action: String):
	return _self_script().new("supply_action", {"action": action})

static func create_care_action(action: String):
	return _self_script().new("care_action", {"action": action})

static func create_science_action(action: String):
	return _self_script().new("science_action", {"action": action})

static func create_downstream_action(action: String):
	return _self_script().new("downstream_action", {"action": action})

static func create_higher_ed_action(action: String):
	return _self_script().new("higher_ed_action", {"action": action})

static func create_food_chain_action(action: String):
	return _self_script().new("food_chain_action", {"action": action})

static func create_pharma_action(action: String):
	return _self_script().new("pharma_action", {"action": action})

static func create_ip_action(action: String):
	return _self_script().new("ip_action", {"action": action})

static func create_transit_action(action: String):
	return _self_script().new("transit_action", {"action": action})

static func create_disaster_action(action: String):
	return _self_script().new("disaster_action", {"action": action})

static func create_livestock_action(action: String):
	return _self_script().new("livestock_action", {"action": action})

static func create_textile_action(action: String):
	return _self_script().new("textile_action", {"action": action})

static func create_basic_industry_action(action: String):
	return _self_script().new("basic_industry_action", {"action": action})

static func create_nation_brand_action(action: String):
	return _self_script().new("nation_brand_action", {"action": action})

static func create_ai_action(action: String):
	return _self_script().new("ai_action", {"action": action})

static func create_tax_action(action: String, value: float = 0.0):
	return _self_script().new("tax_action", {"action": action, "value": value})

static func create_ev_action(action: String):
	return _self_script().new("ev_action", {"action": action})

static func create_health_tourism_action(action: String):
	return _self_script().new("health_tourism_action", {"action": action})

static func create_defense_industry_action(action: String):
	return _self_script().new("defense_industry_action", {"action": action})

static func create_knowledge_economy_action(action: String):
	return _self_script().new("knowledge_economy_action", {"action": action})

static func create_waste_management_action(action: String):
	return _self_script().new("waste_mgmt_action", {"action": action})

static func create_aerospace_action(action: String):
	return _self_script().new("aerospace_action", {"action": action})

static func create_petrochemical_action(action: String):
	return _self_script().new("petrochemical_action", {"action": action})

static func create_pro_sports_action(action: String):
	return _self_script().new("pro_sports_action", {"action": action})

static func create_aviation_action(action: String):
	return _self_script().new("aviation_action", {"action": action})

static func create_postal_action(action: String):
	return _self_script().new("postal_action", {"action": action})

static func create_standards_action(action: String):
	return _self_script().new("standards_action", {"action": action})

# === نقشه‌محور: حمله به مسیرهای تجاری ===
static func create_trade_route_attack(route_id: String, route_type: String, operation: String, from_country: String = "", to_country: String = ""):
	# operation: raid, blockade, sabotage, cyber, drone_strike, protect, escort
	return _self_script().new("trade_route_attack", {"route_id": route_id, "route_type": route_type, "operation": operation, "from_country": from_country, "to_country": to_country})

static func create_chokepoint_action(chokepoint_id: String, action: String):
	# action: blockade, mine, secure, patrol
	return _self_script().new("chokepoint_action", {"chokepoint_id": chokepoint_id, "action": action})

static func create_map_operation(target_country: String, operation_type: String, payload: Dictionary = {}):
	# عملیات نقشه‌محور کلی: airstrike, naval_blockade, sabotage_infrastructure, etc
	var p = payload.duplicate(true)
	p["target_country"] = target_country
	p["operation_type"] = operation_type
	return _self_script().new("map_operation", p)

# === نقشه‌محور پیشرفته: طرح نبرد، ساخت‌وساز ===
static func create_battle_plan(from_country: String, from_unit: String, to_country: String, to_unit: String, plan_type: String, from_lat: float = 0.0, from_lon: float = 0.0, to_lat: float = 0.0, to_lon: float = 0.0):
	return _self_script().new("battle_plan", {"from_country": from_country, "from_unit": from_unit, "to_country": to_country, "to_unit": to_unit, "plan_type": plan_type, "from_lat": from_lat, "from_lon": from_lon, "to_lat": to_lat, "to_lon": to_lon})

static func create_construction(from_country: String, from_unit: String, to_country: String, to_unit: String, build_type: String, from_lat: float = 0.0, from_lon: float = 0.0, to_lat: float = 0.0, to_lon: float = 0.0):
	return _self_script().new("construction", {"from_country": from_country, "from_unit": from_unit, "to_country": to_country, "to_unit": to_unit, "build_type": build_type, "from_lat": from_lat, "from_lon": from_lon, "to_lat": to_lat, "to_lon": to_lon})

static func create_map_building(building_type: String, country_id: String, unit_id: String, lat: float = 0.0, lon: float = 0.0):
	return _self_script().new("map_building", {"building_type": building_type, "country_id": country_id, "unit_id": unit_id, "lat": lat, "lon": lon})


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_command(data) -> Dictionary:
	if not data is Dictionary:
		return {"valid": false, "reason": "داده دیکشنری نیست"}
	if data.is_empty():
		return {"valid": false, "reason": "داده خالی"}
	# بررسی NaN/Inf
	for k in data.keys():
		var v = data[k]
		if v is float and (is_nan(v) or is_inf(v)):
			return {"valid": false, "reason": "عدد نامتناهی در %s" % str(k)}
	return {"valid": true, "reason": ""}

func _deep_cache_command_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_command"):
		set_meta("cache_command", {})
	var cache = get_meta("cache_command")
	return cache.get(key, null)

func _deep_cache_command_set(key: String, value):
	if not has_meta("cache_command"):
		set_meta("cache_command", {})
	var cache = get_meta("cache_command")
	cache[key] = value
	set_meta("cache_command", cache)

func _deep_log_command(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_command(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_command(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("command"):
		state["command"] = {}
	return state

func _deep_deterministic_command_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_command(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("command_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_command(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("command", {}).duplicate(true) if state.has("command") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---
