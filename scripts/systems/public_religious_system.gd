extends BaseSystem
# ۳.۵۱ اماکن عمومی و مذهبی - پارک، مسجد، کلیسا، معبد، حسینیه، فضای سبز، دسترسی، نگهداری

func compute(state: Dictionary, tick: int) -> Dictionary:
	var places = state.get("public_religious", {})
	places["parks"] = places.get("parks", 3000)
	places["mosques"] = places.get("mosques", 60000)
	places["churches"] = places.get("churches", 300)
	places["temples"] = places.get("temples", 100)
	places["hosseiniyeh"] = places.get("hosseiniyeh", 8000)
	places["libraries_public"] = places.get("libraries_public", 3500)
	places["community_centers"] = places.get("community_centers", 2500)
	places["green_space_per_capita"] = places.get("green_space_per_capita", 15.0)
	places["green_space_total_km2"] = places.get("green_space_total_km2", 500.0)
	places["access"] = places.get("access", 0.70)
	places["maintenance"] = places.get("maintenance", 0.60)
	places["cleanliness"] = places.get("cleanliness", 0.65)
	places["safety"] = places.get("safety", 0.70)
	places["utilization_rate"] = places.get("utilization_rate", 0.60)
	places["private_vs_public_ratio"] = places.get("private_vs_public_ratio", 0.30)

	var events = []
	var pop_total = state.get("population", {}).get("total", 85_000_000.0)
	var urban_ratio = state.get("population", {}).get("urban_ratio", 0.75)
	var econ = state.get("economy", {})
	var env = state.get("environment", {})
	var security = state.get("security", {})
	var culture = state.get("culture", {})

	# فضای سبز سرانه = پارک‌ها * مساحت متوسط / جمعیت
	var avg_park_size = 0.02 # km2
	places["green_space_total_km2"] = places["parks"] * avg_park_size
	var green_pc_m2 = places["green_space_total_km2"] * 1_000_000.0 / max(pop_total,1.0)
	places["green_space_per_capita"] = clamp(green_pc_m2, 1.0, 60.0)

	# دسترسی - زیرساخت + حمل‌ونقل عمومی + اقتصاد
	var pt_coverage = state.get("public_transport", {}).get("coverage", 0.60) if state.has("public_transport") else 0.60
	var infra_q = state.get("infrastructure", {}).get("quality", 0.55)
	var access_target = infra_q*0.3 + pt_coverage*0.3 + (1.0 - econ.get("poverty",0.15))*0.2 + 0.2
	places["access"] = clamp(places["access"]*0.992 + access_target*0.008, 0.2, 0.98)

	# نگهداری - بودجه رفاه و شهرداری
	var welfare_budget = econ.get("budget_allocations", {}).get("رفاه", 0.15)
	places["maintenance"] = clamp(places["maintenance"]*0.995 + welfare_budget*0.5*0.005 + infra_q*0.003, 0.15, 0.95)

	# تمیزی - آلودگی و نگهداری
	var pollution = env.get("pollution", 0.4) if env.has("pollution") else state.get("environment", {}).get("air_quality",0.6)
	if pollution is float:
		# air_quality inverse
		pollution = 1.0 - state.get("environment", {}).get("air_quality",0.60)
	places["cleanliness"] = clamp(places["maintenance"]*0.6 + (1.0-pollution)*0.3 + 0.1, 0.1, 0.95)

	# امنیت - امنیت عمومی
	places["safety"] = clamp(places["safety"]*0.98 + security.get("public_security",0.70)*0.02, 0.2, 0.95)

	# بهره‌برداری - دسترسی + کیفیت + فرهنگ
	places["utilization_rate"] = clamp(places["access"]*0.4 + places["safety"]*0.2 + culture.get("cohesion",0.65)*0.2 + places["cleanliness"]*0.2, 0.1, 0.95)

	# نسبت خصوصی به عمومی
	places["private_vs_public_ratio"] = clamp(places["private_vs_public_ratio"] + econ.get("growth_rate",0.02)*0.0005, 0.1, 0.70)

	# رشد اماکن با جمعیت
	if tick % 120 == 0:
		var needed_parks = int(pop_total / 25000.0)
		if places["parks"] < needed_parks:
			places["parks"] += Deterministic.next_int_range(5, 20)
		places["mosques"] = int(pop_total / 1400.0)
		places["libraries_public"] += Deterministic.next_int_range(0, 5)

	# رویدادها
	if places["green_space_per_capita"] < 5.0 and Deterministic.chance(0.015):
		events.append({"type":"green_space_crisis","green": places["green_space_per_capita"], "message":"کمبود فضای سبز - شهرها بتنی، سرانه %d متر مربع" % int(places["green_space_per_capita"])})

	if places["maintenance"] < 0.35 and Deterministic.chance(0.011):
		events.append({"type":"public_places_decay","maintenance": places["maintenance"], "message":"فرسودگی اماکن عمومی - نیمکت‌های شکسته، سرویس غیربهداشتی"})

	if places["safety"] < 0.40 and Deterministic.chance(0.010):
		events.append({"type":"park_safety_issue","safety": places["safety"], "message":"ناامنی پارک‌ها شب‌ها - خانواده‌ها نمی‌روند"})

	if places["utilization_rate"] > 0.85 and Deterministic.chance(0.009):
		events.append({"type":"high_utilization","util": places["utilization_rate"], "message":"استقبال پرشور از فضاهای عمومی - فرهنگ پیاده‌روی رونق گرفت"})

	state["public_religious"] = places
	return {"success":true,"state":state,"events":events}
