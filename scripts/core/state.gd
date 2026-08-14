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
		# سیاست‌های عمق: بورس اوراق بهادار، بنیاد ایثارگران، میراث فرهنگی
		"stock_policy": {"policy": "none", "ipos": 0, "bubble": 0.0, "last_crash": -99, "last_support": -99, "watchdog": 0.0},
		"veterans_policy": {"pension_level": 0.5, "employment_program": 0.4, "clinic": false, "parades": 0, "last_parade": -99, "satisfaction": 0.6},
		"heritage_policy": {"restored": 0, "registered": 0, "festivals": 0, "last_festival": -99, "last_disaster": -99, "last_antiq": -99},
		"transport_policy": {"subsidy_level": 0.5, "last_metro": -99, "last_fleet": -99, "last_brt": -99, "metro_built": 0, "brt_built": 0},
		"retail_policy": {"price_control": false, "consumer_protection": 0.4, "confidence": 0.6, "online_boost": 0, "last_bazaar": -99},
		"ethnicity_policy": {"equal_programs": 0.4, "autonomy": 0.4, "dialogues": 0, "last_dialogue": -99, "last_festival": -99, "representation": 0.4},
		"water_policy": {"leakage": 0.28, "desalination": 0.05, "dams": 0.30, "irrigation_efficiency": 0.35, "conservation": 0.25, "last_dam": -99, "last_desal": -99, "aquifer": 0.70},
		"water_infrastructure": {"storage_bcm": 35.0, "treatment": 0.65, "wastewater_reuse": 0.12, "quality": 0.60, "rural_access": 0.72, "stress_index": 0.45},
		"research_policy": {"university_funding": 0.45, "rnd_centers": 0.25, "tech_transfer": 0.20, "commercialization": 0.30, "brain_drain": 0.28, "papers": 0, "patents": 0, "last_center": -99, "last_grant": -99, "innovation_index": 0.35},
		"civic_policy": {"transparency": 0.45, "local_councils": 0.35, "participatory_budget": 0.20, "ngo_space": 0.40, "watchdog": 0.25, "last_assembly": -99, "social_capital": 0.50, "protests_under": 0},
		"diaspora_policy": {"engagement": 0.35, "networks": 0.25, "public_diplomacy": 0.20, "return_incentive": 0.15, "last_summit": -99, "remittance_b": 12.0, "soft_power_boost": 0.0, "trust": 0.45},
		"civil_defense_policy": {"hardening": 0.25, "redundancy": 0.20, "shelters": 0.20, "strategic_stock": 0.30, "drills": 0.20, "last_drill": -99, "resilience_index": 0.30, "last_hardening": -99, "civilian_protection": 0.30},
		"blue_economy_policy": {"port_capacity": 0.40, "merchant_fleet": 0.30, "sustainable_fisheries": 0.35, "coast_guard": 0.30, "shipbuilding": 0.20, "last_port": -99, "last_fleet": -99, "last_patrol": -99, "blue_gdp": 0.0, "container_throughput": 0.0},
		"creative_policy": {"funding": 0.25, "education": 0.25, "platform": 0.15, "export": 0.15, "cinema": 0.35, "music": 0.40, "games": 0.15, "crafts": 0.45, "last_festival": -99, "creative_gdp": 0.0, "jobs": 0, "creative_index": 0.30, "piracy": 0.45},
		"demographic_policy": {"fertility_incentive": 0.20, "childcare": 0.25, "elderly_care": 0.20, "retraining": 0.15, "last_pro_natal": -99, "last_pension": -99, "window": 0.55, "aging_index": 0.25, "pension_fund": 0.55, "dependency_ratio": 0.45, "median_age": 31.0},
		"watershed_policy": {"restoration": 0.20, "check_dams": 0.15, "forestry": 0.25, "dust_control": 0.20, "wetlands": 0.20, "last_restoration": -99, "soil_health": 0.55, "desertification": 0.45, "dust": 0.40, "forest_cover": 0.20, "erosion_rate": 0.35},
		"prison_policy": {"approach": "balanced", "parole": 0.30, "capacity_expansion": 0.30, "prison_labor": 0.25, "education": 0.30, "last_amnesty": -99, "last_expansion": -99, "recidivism_target": 0.35},
		"prison": {"population": 80000, "capacity": 100000, "overcrowding": 0.80, "rehabilitation": 0.40, "recidivism": 0.35, "conditions": 0.55, "education_prison": 0.35, "work_programs": 0.30, "security_level": 0.70, "violence_rate": 0.05, "escapes": 5},
		"statistics_policy": {"census_quality": 0.50, "data_infrastructure": 0.40, "independence": 0.55, "open_data": 0.30, "id_coverage": 0.85, "last_census": -99, "accuracy": 0.75, "trust_in_data": 0.55, "underreporting": 0.20},
		"mining_policy": {"exploration": 0.30, "processing": 0.25, "safety": 0.40, "formalization": 0.35, "last_mine": -99, "last_refinery": -99, "output": 0.0, "reserves": 0.65, "accident_risk": 0.30, "raw_export_share": 0.70},
		"waste_policy": {"collection": 0.65, "sanitary_landfill": 0.30, "recycling": 0.18, "compost": 0.10, "wte": 0.05, "circular": 0.15, "last_plant": -99, "last_circular": -99, "recycling_rate": 0.15, "landfill_dependency": 0.75, "illegal_dumping": 0.35},
		"insurance_policy": {"penetration": 0.30, "health_insurance": 0.45, "agri_insurance": 0.15, "deposit_insurance": 0.40, "reinsurance": 0.30, "regulation": 0.50, "last_scheme": -99, "solvency": 0.70, "claims": 0.0, "premium_gdp": 0.0, "default_risk": 0.15},
		"rural_policy": {"rural_roads": 0.40, "rural_internet": 0.25, "agro_processing": 0.20, "nomadic_services": 0.30, "micro_credit": 0.25, "last_road": -99, "rural_pop_share": 0.25, "depopulation": 0.40, "rural_income": 0.40, "food_sovereignty": 0.50},
		"judicial_reform_policy": {"digital_courts": 0.20, "specialized_courts": 0.20, "mediation": 0.20, "legal_aid": 0.25, "crime_prevention": 0.20, "last_digital": -99, "case_resolution": 0.45, "cost_of_delay": 0.30, "business_disputes": 0.40},
		"election_policy": {"fairness": 0.55, "voter_access": 0.60, "party_pluralism": 0.50, "media_monitoring": 0.45, "campaign_finance": 0.40, "next_election_turn": 48, "legitimacy": 0.60, "turnout": 0.60, "last_election": -99, "suppressed": 0, "opposition_pressure": 0.30},
		"fuel_policy": {"subsidy": 0.65, "ev_charging": 0.10, "emission_standard": 0.25, "public_fleet": 0.20, "last_reform": -99, "smuggling": 0.30, "fuel_demand": 0.70, "ev_share": 0.02},
		"housing_policy": {"social_supply": 0.20, "mortgage_access": 0.35, "renewal": 0.15, "property_tax": 0.20, "construction": 0.40, "last_social": -99, "price_index": 0.50, "bubble": 0.25, "rent_burden": 0.35, "home_ownership": 0.60, "vacancy": 0.10},
		"startup_policy": {"accelerators": 0.20, "vc_funding": 0.15, "incubators": 0.25, "regulatory_sandbox": 0.10, "last_fund": -99, "startups": 100, "unicorns": 0, "innovation_rate": 0.20, "failure_rate": 0.50, "tech_exports": 0.10},
		"sme_policy": {"ease_business": 0.35, "micro_credit": 0.30, "supply_chain": 0.25, "formalization": 0.30, "last_credit": -99, "sme_share": 0.40, "jobs": 12000000, "business_count": 1500000, "credit_gap": 0.45, "productivity": 0.35},
		"supply_policy": {"strategic_reserve": 0.35, "diversification": 0.40, "domestic_capacity": 0.40, "stockpile_rotation": 0.30, "last_reserve": -99, "disruption": 0.20, "import_dependency": 0.45, "logistics_index": 0.45, "inventory_days": 60.0},
		"care_policy": {"eldercare": 0.25, "childcare": 0.25, "home_care": 0.20, "paid_leave": 0.30, "care_workers": 0.25, "last_program": -99, "female_lfp": 0.35, "care_burden": 0.55, "informal_care": 0.70, "labor_force_gain": 0.0},
		"science_policy": {"bilateral": 0.20, "joint_labs": 0.15, "scholarships": 0.25, "tech_consortium": 0.10, "last_agreement": -99, "knowledge_flow": 0.20, "brain_gain": 0.15, "co_publications": 0.10, "tech_absorption": 0.25},
		"downstream_policy": {"refining": 0.35, "petrochemical": 0.30, "self_sufficiency": 0.40, "value_added": 0.25, "last_refinery": -99, "raw_export_share": 0.65, "fuel_security": 0.45, "product_exports": 0.10, "refining_capacity": 0.40},
		"higher_ed_policy": {"funding": 0.30, "research": 0.25, "faculty": 0.30, "international": 0.15, "last_endowment": -99, "quality": 0.35, "graduates": 500000, "ranking": 0.20, "brain_gain": 0.10, "tuition_access": 0.55},
		"food_chain_policy": {"storage": 0.25, "processing": 0.20, "logistics": 0.30, "safety": 0.40, "last_storage": -99, "waste": 0.35, "food_security": 0.55, "price_volatility": 0.40, "cold_chain": 0.20, "self_sufficiency": 0.60},
		"pharma_policy": {"domestic": 0.30, "generic": 0.40, "stockpile": 0.30, "vaccine": 0.20, "medical_devices": 0.25, "last_plant": -99, "import_dep": 0.65, "drug_security": 0.40, "drug_cost": 0.60, "local_production": 0.35},
		"ip_policy": {"patents": 0.25, "copyright": 0.30, "tech_transfer": 0.20, "enforcement": 0.30, "last_reform": -99, "innovation_index": 0.25, "patent_count": 500, "royalty_income": 0.05, "ip_compliance": 0.40},
		"transit_policy": {"corridors": 0.25, "customs": 0.30, "rail": 0.25, "free_zones": 0.20, "last_corridor": -99, "transit_share": 0.15, "freight": 0.30, "revenue": 0.0, "border_delay": 0.50},
		"disaster_policy": {"early_warning": 0.30, "shelter": 0.25, "response": 0.35, "relief_stock": 0.30, "last_drill": -99, "preparedness": 0.30, "risk": 0.45, "casualty_risk": 0.50, "recovery_speed": 0.35, "drills": 0},
		"livestock_policy": {"industrial": 0.30, "vaccination": 0.45, "feed": 0.35, "breeding": 0.25, "last_program": -99, "self_suff": 0.65, "protein_security": 0.55, "herd_size": 0.50, "disease_risk": 0.30, "milk_production": 0.45, "meat_production": 0.40},
		"textile_policy": {"raw_material": 0.35, "spinning": 0.30, "apparel": 0.40, "branding": 0.20, "last_mill": -99, "output": 0.35, "export_share": 0.20, "employment": 500000, "value_added": 0.30, "import_dep": 0.45},
		"basic_industry_policy": {"steel": 0.35, "cement": 0.40, "integration": 0.25, "efficiency": 0.30, "last_capacity": -99, "output": 0.35, "self_sufficiency": 0.60, "exports": 0.15, "import_dep": 0.40, "construction_materials": 0.50},
		"nation_brand_policy": {"branding": 0.25, "events": 0.20, "heritage": 0.40, "cultural_exports": 0.20, "last_event": -99, "brand_index": 0.35, "soft_power_gain": 0.10, "tourism_boost": 0.0, "media_image": 0.40},
		"ai_policy": {"adoption": 0.10, "robotics": 0.10, "reskilling": 0.20, "data_infra": 0.20, "last_program": -99, "productivity": 0.15, "job_displacement": 0.0, "ai_exports": 0.0, "ethics": 0.40},
		"clock": {
			"year": 2027,
			"month": 1,
			"day": 1,
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
			# کانال مالک-یکتای سطح GDP: نرخ سالانهٔ سهم هر بخش (بازنویسی، نه انباشت)
			"sector_boosts": {},
			"sector_boosts_total": 0.0,
			# کانال نرخ ماهانهٔ ورودی ذخایر ارزی: ناشر→مبلغ دلاری ماهانه (بازنویسی، نه انباشت)
			"reserve_inflows": {},
			"reserve_inflows_monthly": 0.0,
			"government_revenue": 100_000_000_000.0,
			"foreign_reserves": 60_000_000_000.0,
			"celebration_tracking": {"last_stage": "دولت نوپا", "last_achievement_count": 0, "last_high_score": 0.0, "last_pop_mark": 0, "last_gdp_mark": 0},
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
		"trade_route_warfare": {
			"attacks": [],
			"chokepoints": {},
			"protected_routes": [],
			"convoy_escorts": [],
			"disrupted_volume": 0.0,
			"piracy_level": 0.10,
			"blockade_effectiveness": 0.0,
			"total_raids": 0,
			"total_blockades": 0,
			"economic_damage": 0.0
		},
		"map_advanced": {
			"battle_plans": [],
			"constructions": [],
			"buildings": [],
			"forts": {},
			"depots": {},
			"airfields": {},
			"radar_stations": {},
			"supply_depots": {}
		},
		"map_network": {"air_connectivity":0.5,"sea_connectivity":0.5,"land_connectivity":0.5,"disrupted_routes":0,"updated_turn":0},
		# لایه‌ی اماکن فیزیکی و مردم و ...
		"physical": {
			"settlements": 1200,
			"transport_routes": 5000,
			"facilities": 3000
		},
		"people": {
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
