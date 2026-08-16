extends RefCounted
class_name BaseAI
# پایه‌ی هوش تخصصی سیستم‌ها - تحلیل داده‌محور، دترمینستیک و قابل توضیح

const GameCommandClass = preload("res://scripts/core/command.gd")

# مسیر شاخص، هدف، جهت خطر، ردیف بودجه، نام فارسی، مقیاس
# low: کمتر از هدف خطر است | high: بیشتر از هدف خطر است
const PROFILES = {
	"administration": ["administration.efficiency", 0.65, "low", "اداره", "کارآمدی اداره کشور", 1.0],
	"agriculture": ["agriculture.food_security", 0.80, "low", "زیرساخت", "امنیت غذایی", 1.0],
	"central_bank": ["central_bank.bank_stability", 0.70, "low", "ذخیره", "پایداری بانکی", 1.0],
	"citizens": ["citizens_detail.avg_happiness", 0.62, "low", "رفاه", "رضایت شهروندان", 1.0],
	"culture": ["culture.cohesion", 0.65, "low", "اداره", "انسجام فرهنگی", 1.0],
	"diplomacy": ["diplomacy.influence", 45.0, "low", "اداره", "نفوذ دیپلماتیک", 100.0],
	"economy": ["economy.growth_rate", 0.025, "low", "ذخیره", "رشد اقتصادی", 1.0],
	"education": ["education.quality", 0.65, "low", "آموزش", "کیفیت آموزش", 1.0],
	"elections": ["elections.transparency", 0.70, "low", "اداره", "شفافیت انتخابات", 1.0],
	"elites": ["elites_detail.brain_drain", 0.20, "high", "فناوری", "فرار نخبگان", 1.0],
	"emergency": ["emergency.preparedness", 0.65, "low", "امنیت", "آمادگی بحران", 1.0],
	"environment": ["environment.air_quality", 0.70, "low", "محیط", "کیفیت محیط‌زیست", 1.0],
	"ethnicity": ["ethnicity.tension", 0.35, "high", "رفاه", "تنش قومی", 1.0],
	"family": ["family.child_welfare", 0.70, "low", "رفاه", "رفاه خانواده و کودک", 1.0],
	"financial_services": ["financial_services.financial_inclusion", 0.75, "low", "ذخیره", "فراگیری خدمات مالی", 1.0],
	"fisheries": ["fisheries.stock_health", 0.70, "low", "محیط", "سلامت ذخایر دریایی", 1.0],
	"foreign_affairs": ["foreign_affairs.soft_power", 0.50, "low", "اداره", "قدرت نرم خارجی", 1.0],
	"fuel_stations": ["fuel_stations.storage_days", 15.0, "low", "زیرساخت", "ذخیره راهبردی سوخت", 30.0],
	"government_buildings": ["government_buildings.efficiency", 0.70, "low", "اداره", "کارآمدی نهادهای دولتی", 1.0],
	"health": ["health.quality", 0.70, "low", "بهداشت", "کیفیت سلامت", 1.0],
	"heritage": ["heritage.preservation", 0.72, "low", "اداره", "حفاظت میراث", 1.0],
	"hospitality": ["hospitality.service_quality", 0.72, "low", "زیرساخت", "کیفیت مهمان‌پذیری", 1.0],
	"households": ["households_detail_full.savings_rate", 0.20, "low", "رفاه", "تاب‌آوری خانوار", 1.0],
	"human_states": ["human_states.stress", 0.45, "high", "بهداشت", "فشار روانی جامعه", 1.0],
	"industry": ["industry.productivity", 0.68, "low", "فناوری", "بهره‌وری صنعت", 1.0],
	"industry_sites": ["industry_sites_detail.utilization", 0.72, "low", "زیرساخت", "بهره‌برداری صنعتی", 1.0],
	"infrastructure": ["infrastructure.quality", 0.70, "low", "زیرساخت", "کیفیت زیرساخت", 1.0],
	"intelligence": ["intelligence.cyber_readiness", 0.70, "low", "امنیت", "آمادگی اطلاعاتی و سایبری", 1.0],
	"interdependency": ["indicators.stability", 0.65, "low", "ذخیره", "تاب‌آوری جریان‌های کشور", 1.0],
	"international_orgs": ["international_orgs.compliance", 0.70, "low", "اداره", "تعامل با سازمان‌های جهانی", 1.0],
	"judicial": ["judicial.efficiency", 0.70, "low", "اداره", "کارآمدی قضایی", 1.0],
	"leader": ["leader.popularity_world", 55.0, "low", "ذخیره", "محبوبیت جهانی رهبر", 100.0],
	"rivals": ["rivals.threat", 0.3, "high", "ذخیره", "تهدید رقبای داخلی", 1.0],
	"migration": ["migration_detail.integration", 0.65, "low", "رفاه", "ادغام مهاجران", 1.0],
	"military": ["military.readiness", 0.75, "low", "ارتش", "آمادگی دفاعی", 1.0],
	"officials_managers": ["officials.competence", 0.70, "low", "اداره", "شایستگی مدیران", 1.0],
	"people": ["human_states.happiness_avg", 0.65, "low", "رفاه", "کیفیت زندگی مردم", 1.0],
	"physical": ["physical.housing_shortage", 0.15, "high", "زیرساخت", "کمبود مسکن و اماکن", 1.0],
	"political_career": ["political_career.meritocracy", 0.65, "low", "اداره", "شایسته‌سالاری سیاسی", 1.0],
	"politicians": ["politicians_detail.trust_politicians", 0.55, "low", "اداره", "اعتماد به سیاست‌مداران", 1.0],
	"politics": ["politics.stability", 0.68, "low", "اداره", "ثبات سیاسی", 1.0],
	"population": ["population.happiness", 0.65, "low", "رفاه", "شادی جمعیت", 1.0],
	"prison": ["prison.overcrowding", 0.85, "high", "امنیت", "تراکم زندان", 1.0],
	"private_sector": ["private_sector.business_climate", 0.70, "low", "فناوری", "فضای کسب‌وکار", 1.0],
	"public_employees": ["public_employees.efficiency", 0.68, "low", "اداره", "کارآمدی کارکنان عمومی", 1.0],
	"public_religious": ["public_religious.access", 0.75, "low", "اداره", "دسترسی به اماکن عمومی", 1.0],
	"public_services": ["public_services_detail.coverage_health", 0.82, "low", "بهداشت", "پوشش خدمات عمومی", 1.0],
	"public_transport": ["public_transport.coverage", 0.72, "low", "زیرساخت", "پوشش حمل‌ونقل عمومی", 1.0],
	"quantitative_temporal": ["quantitative.shock_absorption", 0.70, "low", "ذخیره", "جذب شوک‌های بلندمدت", 1.0],
	"religious_leaders": ["religious_leaders.moderation", 0.70, "low", "اداره", "اعتدال اجتماعی", 1.0],
	"resources": ["resources.self_sufficiency", 1.0, "low", "زیرساخت", "خودکفایی منابع", 1.0],
	"retail": ["retail.competition", 0.70, "low", "ذخیره", "رقابت بازار خرد", 1.0],
	"security": ["security.public_security", 0.75, "low", "امنیت", "امنیت عمومی", 1.0],
	"security_forces": ["security_forces_detail.equipment", 0.72, "low", "امنیت", "آمادگی نیروهای امنیتی", 1.0],
	"settlements": ["settlements_detail.housing_quality", 0.70, "low", "زیرساخت", "کیفیت سکونتگاه‌ها", 1.0],
	"space": ["space.level", 0.25, "low", "فناوری", "توان فضایی", 1.0],
	"sports_youth": ["sports_youth.youth_happiness", 0.68, "low", "رفاه", "نشاط جوانان", 1.0],
	"statistics": ["statistics.accuracy", 0.85, "low", "اداره", "دقت آمار ملی", 1.0],
	"stock_market": ["stock_market.investor_confidence", 0.68, "low", "ذخیره", "اعتماد بازار سرمایه", 1.0],
	"technology": ["technology.research_rate", 12.0, "low", "فناوری", "سرعت پژوهش", 20.0],
	"tourism": ["tourism.service_quality", 0.70, "low", "زیرساخت", "کیفیت گردشگری", 1.0],
	"trade": ["trade.export_diversity", 0.65, "low", "زیرساخت", "تنوع صادرات", 1.0],
	"transport_roads": ["transport_detail.traffic_congestion", 0.65, "high", "زیرساخت", "تراکم حمل‌ونقل", 1.0],
	"urban_facilities": ["urban_facilities.water_network", 0.85, "low", "زیرساخت", "پوشش تأسیسات شهری", 1.0],
	"veterans": ["veterans.health_care", 0.75, "low", "رفاه", "خدمات ایثارگران", 1.0],
	"welfare": ["welfare.poverty", 0.12, "high", "رفاه", "کاهش فقر", 1.0],
	"workforce_jobs": ["workforce_detail.unemployed", 0.08, "high", "آموزش", "اشتغال نیروی کار", 1.0],
	"trade_route_warfare": ["trade_route_warfare.blockade_effectiveness", 0.30, "high", "امنیت", "امنیت مسیرهای تجاری", 1.0],
	"crisis": ["economy.debt_to_gdp", 0.4, "low", "ذخیره", "فشار کلان و بحران", 1.0]
}

func get_system_key() -> String:
	var path = get_script().resource_path
	return path.get_file().trim_suffix("_ai.gd")

func diagnose(state: Dictionary) -> Dictionary:
	var key = get_system_key()
	var profile: Array = PROFILES.get(key, [])
	if profile.is_empty():
		return {}
	var raw = _read_path(state, profile[0])
	if not (raw is int or raw is float):
		return {}
	var scale = max(float(profile[5]), 0.000001)
	var value = float(raw) / scale
	var target = float(profile[1]) / scale
	var direction = str(profile[2])
	var urgency = 0.0
	var health = 1.0
	if direction == "high":
		health = clamp(1.0 - value, 0.0, 1.0)
		urgency = clamp((value - target) / max(1.0 - target, 0.05), 0.0, 1.0)
	else:
		health = clamp(value / max(target, 0.000001), 0.0, 1.0)
		urgency = clamp((target - value) / max(target, 0.05), 0.0, 1.0)
	var result = {
		"system": key,
		"title": str(profile[4]),
		"metric_path": str(profile[0]),
		"value": float(raw),
		"target": float(profile[1]),
		"health": health,
		"urgency": urgency,
		"budget_key": str(profile[3]),
		"reason": _explain(str(profile[4]), direction, urgency)
	}
	if urgency > 0.05:
		var cmd = build_budget_command(state, str(profile[3]))
		if cmd != null:
			result["command"] = cmd.to_dict()
	return result

func decide(state: Dictionary, tick: int) -> Array:
	var diagnosis = diagnose(state)
	if diagnosis.get("urgency", 0.0) < 0.15:
		return []
	var cmd = build_budget_command(state, diagnosis.get("budget_key", ""))
	return [cmd] if cmd != null else []

func evaluate(state: Dictionary) -> float:
	return float(diagnose(state).get("health", 0.5))

func build_budget_command(state: Dictionary, budget_key: String):
	var original: Dictionary = state.get("economy", {}).get("budget_allocations", {})
	if original.is_empty() or not original.has(budget_key):
		return null
	var allocs = original.duplicate(true)
	var donor = ""
	var donor_value = -1.0
	if budget_key != "ذخیره" and float(allocs.get("ذخیره", 0.0)) > 0.04:
		donor = "ذخیره"
		donor_value = float(allocs[donor])
	else:
		for key in allocs.keys():
			if key != budget_key and float(allocs[key]) > donor_value:
				donor = key
				donor_value = float(allocs[key])
	if donor == "" or donor_value <= 0.02:
		return null
	var step = min(0.02, donor_value - 0.01)
	allocs[donor] = float(allocs[donor]) - step
	allocs[budget_key] = float(allocs[budget_key]) + step
	return GameCommandClass.create_budget_allocate(allocs)

func _read_path(state: Dictionary, path: String):
	var current = state
	for part in path.split("."):
		if not current is Dictionary or not current.has(part):
			return null
		current = current[part]
	return current

func _explain(title: String, direction: String, urgency: float) -> String:
	var level = "نیازمند توجه"
	if urgency >= 0.65:
		level = "بحرانی"
	elif urgency >= 0.35:
		level = "پرخطر"
	var trend = "بالاتر از حد امن" if direction == "high" else "پایین‌تر از هدف"
	return "%s؛ شاخص «%s» %s است." % [level, title, trend]
