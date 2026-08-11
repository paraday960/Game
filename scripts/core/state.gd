extends Node
# مدل داده کامل - بخش ۳.۲ - لایه‌های سیستم، اماکن، آدم‌ها، زمان و جریان

# وضعیت اصلی بازی - همیشه از طریق Engine به‌صورت اتمی تغییر می‌کند
var state: Dictionary = {}
var version: int = 0
var tick: int = 0
var seed_value: int = 123456789

signal state_changed(new_state)

func _ready():
	init_default_state()

func init_default_state():
	state = {
			"schema_version": 20,  # 20: هوش خارجی (incoming_offers/player_stances) + خستگی جنگ
			"version": 0,
			"tick": 0,
			"seed": seed_value,
			"command_receipts": [],
			"clock": {
			"year": 2027,
			"month": 1,
			"day": 1,
			"hour": 0,
			"season": "بهار"
		},
		# لایه‌ی سیستم‌های عملکردی - ۳۳ سیستم
		"economy": {
			"gdp": 500_000_000_000.0,  # 500 میلیارد
			"gdp_per_capita": 5000.0,
				"growth_rate": float(BalanceConfig.get_value("economy.growth_base", 0.02)),
				"inflation": float(BalanceConfig.get_value("economy.inflation_initial", 0.08)),
				"unemployment": float(BalanceConfig.get_value("economy.unemployment_initial", 0.08)),
				"tax_rate": float(BalanceConfig.get_value("economy.tax_base", 0.20)),
			"government_revenue": 100_000_000_000.0,
			"government_spending": 95_000_000_000.0,
			"deficit": 5_000_000_000.0,  # قرارداد واحد: مثبت یعنی کسری
			"national_debt": 200_000_000_000.0,
			"debt_to_gdp": 0.4,
			"budget_allocations": {
				"آموزش": 0.08,
				"بهداشت": 0.10,
				"ارتش": 0.08,
				"زیرساخت": 0.18,
				"رفاه": 0.15,
				"فناوری": 0.04,
				"امنیت": 0.05,
				"اداره": 0.07,
				"محیط": 0.03,
				"ذخیره": 0.22
			}
		},
		"resources": {
			"inventory": {
				"برق": 100.0,
				"نفت": 80.0,
				"گاز": 70.0,
				"آب": 90.0,
				"غذا": 85.0,
				"آهن": 60.0,
				"مس": 50.0,
				"مواد_صنعتی": 65.0
			},
			"capacity": {
				"برق": 200.0,
				"نفت": 150.0,
				"گاز": 150.0,
				"آب": 150.0,
				"غذا": 150.0,
				"آهن": 120.0,
				"مس": 100.0,
				"مواد_صنعتی": 120.0
			},
			"production": {
				"برق": 15.0,
				"نفت": 8.0,
				"گاز": 6.0,
				"آب": 12.0,
				"غذا": 10.0,
				"آهن": 4.0,
				"مس": 2.0,
				"مواد_صنعتی": 5.0
			},
			"demand": {
				"برق": 12.0,
				"نفت": 6.0,
				"گاز": 5.0,
				"آب": 10.0,
				"غذا": 9.0,
				"آهن": 3.0,
				"مس": 1.5,
				"مواد_صنعتی": 4.0
			},
			"self_sufficiency": 0.85,
			"energy_crisis": false,
			"food_crisis": false
		},
		"population": {
			"total": 85_000_000,
				"growth_rate": 0.012,
				"birth_rate": float(BalanceConfig.get_value("population.birth_base", 15.0)),
				"death_rate": float(BalanceConfig.get_value("population.death_base", 8.0)),
				"migration_net": 10000,
				"happiness": float(BalanceConfig.get_value("population.happiness_initial", 0.60)),
				"satisfaction": 0.62,
				"workforce": 55_000_000,
				"participation_rate": float(BalanceConfig.get_value("population.participation", 0.65)),
			"dependency_ratio": 0.55,
			"age_structure": {
				"کودک": 0.25,
				"جوان": 0.35,
				"بزرگسال": 0.30,
				"سالمند": 0.10
			},
			"urban_ratio": 0.75
		},
		"politics": {
				"stability": float(BalanceConfig.get_value("politics.stability_initial", 0.60)),
				"trust": 0.55,
				"corruption": float(BalanceConfig.get_value("politics.corruption_initial", 0.30)),
			"legitimacy": 0.58,
			"tension": 0.35,
			"system": "جمهوری ریاستی",
			"election_cycle": 4
		},
		"military": {
				"power": 65.0,
				"readiness": float(BalanceConfig.get_value("military.readiness_initial", 0.70)),
				"budget_share": float(BalanceConfig.get_value("military.budget_share", 0.08)),
			"personnel": 500_000,
			"branches": {
				"زمینی": 0.50,
				"هوایی": 0.25,
				"دریایی": 0.15,
				"موشکی": 0.10
			},
			"deterrence": 60.0,
			"war_exhaustion": 0.0
		},
			"diplomacy": {
				"relations": {},
				"influence": 40.0,
				"soft_power": 35.0,
				"action_points": 3.0,
				"treaties": [],
				"sanctions": []
			},
		"infrastructure": {
			"quality": 0.55,
			"capacity": 0.60,
			"coverage": 0.70,
			"maintenance_cost": 0.02,
			"projects": []
		},
		"technology": {
			"research_points": 0.0,
				"research_rate": 10.0,
				"tree_version": "1.0.0",
				"unlocked": ["industry_basic", "agriculture_basic"],
				"in_progress": null,
			"branches": {
				"صنعت": 0.20,
				"انرژی_پاک": 0.15,
				"پزشکی": 0.10,
				"نظامی": 0.15,
				"دیجیتال": 0.20,
				"فضا": 0.05
			}
		},
		# سایر سیستم‌ها - خلاصه
		"health": {"coverage": 0.75, "quality": 0.60, "hospital_beds": 150000},
		"education": {"literacy": 0.85, "quality": 0.55, "coverage": 0.80},
		"welfare": {"poverty": 0.15, "gini": 0.38, "unemployment_support": 0.5},
		"environment": {"air_quality": 0.60, "carbon": 0.6, "green_energy": 0.20},
		"culture": {"cohesion": 0.65, "media_freedom": 0.5, "identity": 0.70},
		"intelligence": {"power": 50.0, "cyber_readiness": 0.5},
		"judicial": {"rule_of_law": 0.60, "crime_rate": 50.0, "efficiency": 0.60},
		"security": {"public_security": 0.70, "police_presence": 0.5},
		"administration": {"efficiency": 0.60, "decentralization": 0.4},
		"central_bank": {"interest_rate": 0.15, "money_supply": 1.0, "exchange_rate": 1.0, "policy_mode":"independent", "manual_rate":0.15, "inflation_target":0.05},
		"trade": {"exports": 80_000_000_000.0, "imports": 70_000_000_000.0, "balance": 10_000_000_000.0},
		"tourism": {"visitors": 5_000_000, "revenue": 5_000_000_000.0},
		"stock_market": {"index": 1000.0, "growth": 0.05},
		"agriculture": {"production": 100.0, "food_security": 0.85},
		"industry": {"output": 100.0, "capacity_usage": 0.75},
		"family": {"marriage_rate": 0.007, "divorce_rate": 0.002, "fertility": 1.8},
		"sports_youth": {"participation": 0.40, "facilities": 0.5},
		"ethnicity": {"diversity": 0.6, "tension": 0.30},
		"emergency": {"preparedness": 0.50, "response_time": 10.0},
		"heritage": {"sites": 20, "preservation": 0.65},
		"space": {"level": 0.10, "satellites": 2},
		"elections": {"participation": 0.60, "transparency": 0.55},
		"veterans": {"count": 500000, "pension": 0.70, "health_care": 0.65, "fund_balance": 500_000_000.0},
		"fisheries": {"catch": 500000.0, "fleet_size": 1000, "sustainability": 0.60, "stock_health": 0.65},
		"statistics": {"accuracy": 0.75, "coverage": 0.85, "digital": 0.60, "id_coverage": 0.92},
		# لایه‌ی اماکن فیزیکی و مردم و ...
		"physical": {
			"settlements": 1200,
			"transport_routes": 5000,
			"facilities": 3000
		},
		"people": {
			"citizens_sample": 1000,
			"households": 25_000_000,
			"leaders": 100
		},
		# سیستم‌های فیزیکی تفصیلی - 3.45 تا 3.47 (کلیدهای یکسان با سیستم‌ها)
		"retail": {"shops": 200000, "chain_stores": 5000, "bazaars": 5000, "supermarkets": 3000,
			"coverage": 0.85, "competition": 0.60, "price_level": 1.0, "e_commerce_share": 0.15, "employment": 1500000},
		"fuel_stations": {"gas_stations": 4000, "ev_charging": 500, "gasoline_price": 15000.0,
			"coverage": 0.75, "renewable_share": 0.05, "storage_days": 15.0, "smuggling": 0.15},
		"urban_facilities": {"water_network": 0.75, "electricity_grid": 0.70, "telecom_coverage": 0.80,
			"waste_collection": 0.70, "waste_recycling": 0.15, "sewage_coverage": 0.65,
			"street_lighting": 0.60, "maintenance_cost": 2_000_000_000.0},
		# شاخص‌های کلان
		"indicators": {
			"hdi": 0.75,
			"happiness": 0.60,
			"stability": 0.60,
			"power_score": 55.0
		},
			"events_active": [],
			"crisis_cooldowns": {},
			"pending_decisions": [],
			"decision_history": [],
			"progression": {
				"streak": 0,
				"best_streak": 0,
				"combo": 1,
				"previous_score": 0.0,
				"high_score": 0.0,
				"legacy_score": 0,
				"achievements": [],
				"last_unlocks": [],
				"stage": "دولت نوپا"
			},
			"score": 0.0,
			"level": 1,
			"xp": 0.0
		}
	_apply_initial_overrides()
	version = 0
	tick = 0

func _apply_initial_overrides():
	var file = FileAccess.open("res://data/initial_state.json", FileAccess.READ)
	if file != null:
		var parsed = JSON.parse_string(file.get_as_text())
		file.close()
		if parsed is Dictionary:
			_deep_merge(state, parsed)
	# JSON همه اعداد را اعشاری می‌خواند؛ کلیدهای تقویمی باید int بمانند.
	state["clock"]["year"] = int(state["clock"].get("year", 2027))
	state["clock"]["month"] = int(state["clock"].get("month", 1))
	state["clock"]["day"] = int(state["clock"].get("day", 1))
	state["clock"]["hour"] = int(state["clock"].get("hour", 0))
	state["schema_version"] = int(state.get("schema_version", 20))
	# کشور پیش‌فرض و درخت فناوری پیش از نخستین روز آماده می‌شوند.
	state = WorldManager.apply_country_profile(state, WorldManager.default_country)
	state = TimeManager.reset(state)
	state = SeasonalManager.reset_for_country(state, WorldManager.default_country)
	state = MilitaryManager.reset(state)
	state = NationalProjectManager.reset(state)
	state = CabinetManager.reset(state)
	state = LawManager.reset(state)
	state = IntelligenceOperationManager.reset(state)
	state = MapLayerManager.update_network_metrics(state)
	state = ScenarioManager.apply_scenario(state, ScenarioManager.default_scenario, 0)
	state = TechnologyManager.migrate_state(state)
	state = PolicyManager.reset(state)
	state = AnalyticsManager.reset(state)
	# مقادیر بالانس، مرجع نرخ‌های قابل تنظیم‌اند و پس از پروفایل کشور اعمال می‌شوند.
	state["economy"]["tax_rate"] = float(BalanceConfig.get_value("economy.tax_base", state["economy"]["tax_rate"]))
	state["population"]["birth_rate"] = float(BalanceConfig.get_value("population.birth_base", state["population"]["birth_rate"]))
	state["population"]["death_rate"] = float(BalanceConfig.get_value("population.death_base", state["population"]["death_rate"]))
	state = AuditManager.reset(state)

func _deep_merge(target: Dictionary, source: Dictionary):
	for key in source.keys():
		if target.has(key) and target[key] is Dictionary and source[key] is Dictionary:
			_deep_merge(target[key], source[key])
		else:
			target[key] = source[key]

func get_state_copy() -> Dictionary:
	return state.duplicate(true)

func set_state(new_state: Dictionary, new_version: int, new_tick: int):
	state = new_state.duplicate(true)
	version = new_version
	tick = new_tick
	state["version"] = version
	state["tick"] = tick
	emit_signal("state_changed", state)

func get_value(path: String):
	# مثال: "economy.gdp" یا "population.happiness"
	var parts = path.split(".")
	var current = state
	for p in parts:
		if current is Dictionary and current.has(p):
			current = current[p]
		else:
			return null
	return current

func apply_delta(path: String, delta):
	var parts = path.split(".")
	var current = state
	for i in range(parts.size() - 1):
		current = current[parts[i]]
	var last = parts[-1]
	if current is Dictionary and current.has(last):
		if typeof(current[last]) == TYPE_FLOAT or typeof(current[last]) == TYPE_INT:
			current[last] += delta
