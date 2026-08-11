extends BaseSystem
# ۳.۹۰ عملیات پیشرفته نقشه‌محور - طرح نبرد، ساخت‌وساز، ساختمان‌های نقشه‌محور
# نسخه پیشرفته: رسم فلش تهاجمی HOI4، ساخت جاده/راه‌آهن با کشیدن خط، سنگر، انبار، باند، رادار

func compute(state: Dictionary, tick: int) -> Dictionary:
	var adv = state.get("map_advanced", {})
	adv["battle_plans"] = adv.get("battle_plans", [])
	adv["constructions"] = adv.get("constructions", [])
	adv["buildings"] = adv.get("buildings", []) # ساختمان‌های ساخته‌شده روی نقشه
	adv["forts"] = adv.get("forts", {}) # استان -> سطح استحکامات
	adv["depots"] = adv.get("depots", {}) # انبارها
	adv["airfields"] = adv.get("airfields", {})
	adv["radar_stations"] = adv.get("radar_stations", {})
	adv["supply_depots"] = adv.get("supply_depots", {})

	var events = []
	var econ = state.get("economy", {})
	var mil = state.get("military", {})
	var infra = state.get("infrastructure", {})
	var is_at_war = not state.get("world", {}).get("wars", {}).is_empty()

	# ==================== ۱) به‌روزرسانی طرح‌های نبرد ====================
	var active_plans = []
	for plan in adv["battle_plans"]:
		var age = tick - int(plan.get("tick", tick))
		var plan_type = str(plan.get("plan_type", "offensive"))
		var progress = float(plan.get("progress", 0.0))

		# پیشرفت طرح بر اساس آمادگی، تدارکات، دکترین
		var readiness = float(mil.get("readiness", 0.70))
		var logistics = float(mil.get("logistics_detail", {}).get("supply_line_vulnerability", 0.30)) if mil.has("logistics_detail") else 0.30
		var planning_speed = readiness*0.02 + (1.0 - logistics)*0.01 + 0.01
		if is_at_war:
			planning_speed *= 1.5

		progress += planning_speed
		plan["progress"] = progress

		# اگر طرح کامل شد (۱۰۰٪)، اثر بگذار
		if progress >= 1.0 and str(plan.get("status","planned")) != "executed":
			plan["status"] = "executed"
			var from_c = str(plan.get("from_country",""))
			var to_c = str(plan.get("to_country",""))
			# اثر بر جنگ
			if plan_type in ["offensive","breakthrough","pincer","encirclement"]:
				if state.get("world",{}).get("wars",{}).has(to_c):
					state["world"]["wars"][to_c]["progress"] = float(state["world"]["wars"][to_c].get("progress",0.0)) + {"offensive":3.0,"breakthrough":5.0,"encirclement":7.0,"pincer":6.0}.get(plan_type,3.0)
					events.append({"type":"battle_plan_executed","plan_type":plan_type,"from":from_c,"to":to_c,"message":"طرح نبرد %s از %s به %s اجرا شد - پیشروی" % [plan_type, from_c, to_c]})
			elif plan_type == "defensive":
				# تقویت دفاع
				adv["forts"][from_c] = int(adv["forts"].get(from_c,0)) + 1
				events.append({"type":"defensive_plan_executed","from":from_c,"message":"طرح دفاعی %s مستحکم شد" % from_c})

		# طرح‌ها تا ۱۸۰ روز باقی می‌مانند
		if age < 180:
			active_plans.append(plan)
		else:
			events.append({"type":"battle_plan_expired","plan_type":plan_type,"message":"طرح نبرد %s منقضی شد" % plan_type})

	adv["battle_plans"] = active_plans

	# ==================== ۲) ساخت‌وساز - پیشرفت ====================
	var active_constructions = []
	for construction in adv["constructions"]:
		var age = tick - int(construction.get("tick", tick))
		var build_type = str(construction.get("build_type","road"))
		var progress = float(construction.get("progress",0.0))

		# سرعت ساخت بر اساس بودجه زیرساخت، فناوری، نیروی کار
		var budget_share = econ.get("budget_allocations",{}).get("زیرساخت",0.18)
		var build_speed = budget_share*0.05 + infra.get("quality",0.55)*0.02 + 0.01
		# جنگ سرعت را کم می‌کند
		if is_at_war:
			build_speed *= 0.7

		progress += build_speed
		construction["progress"] = progress

		if progress >= 1.0 and str(construction.get("status","building")) != "completed":
			construction["status"] = "completed"
			var from_c = str(construction.get("from_country",""))
			var to_c = str(construction.get("to_country",""))

			# اثر بر اساس نوع ساخت
			match build_type:
				"road":
					infra["quality"] = clamp(float(infra.get("quality",0.55)) + 0.005, 0.05, 0.98)
					infra["road_quality"] = clamp(float(infra.get("road_quality",0.55)) + 0.01, 0.10, 0.95) if infra.has("road_quality") else 0.60
					events.append({"type":"road_built","from":from_c,"to":to_c,"message":"جاده %s → %s تکمیل شد - زیرساخت +۰.۵٪" % [from_c, to_c]})
				"rail":
					infra["rail_quality"] = clamp(float(infra.get("rail_quality",0.45)) + 0.015, 0.10, 0.95) if infra.has("rail_quality") else 0.50
					events.append({"type":"rail_built","from":from_c,"to":to_c,"message":"راه‌آهن %s → %s تکمیل - ظرفیت ریلی +"})
				"fort":
					adv["forts"][from_c] = int(adv["forts"].get(from_c,0)) + 2
					events.append({"type":"fort_built","country":from_c,"message":"استحکامات سطح %d در %s ساخته شد" % [adv["forts"][from_c], from_c]})
				"depot","supply_depot":
					adv["depots"][from_c] = int(adv["depots"].get(from_c,0)) + 1
					adv["supply_depots"][from_c] = float(adv["supply_depots"].get(from_c,0.0)) + 0.15
					mil["logistics_detail"]["supply_line_vulnerability"] = clamp(float(mil.get("logistics_detail",{}).get("supply_line_vulnerability",0.30)) - 0.05, 0.05, 0.90) if mil.has("logistics_detail") else 0.30
					events.append({"type":"depot_built","country":from_c,"message":"انبار تدارکات در %s - آسیب‌پذیری تدارکات -۵٪" % from_c})
				"airfield":
					adv["airfields"][from_c] = int(adv["airfields"].get(from_c,0)) + 1
					events.append({"type":"airfield_built","country":from_c,"message":"باند هوایی در %s ساخته شد - برد هوایی +۱۰٪" % from_c})
				"radar":
					adv["radar_stations"][from_c] = int(adv["radar_stations"].get(from_c,0)) + 1
					mil["command_detail"]["c4isr_level"] = clamp(float(mil.get("command_detail",{}).get("c4isr_level",0.60)) + 0.02, 0.10, 0.97) if mil.has("command_detail") else 0.62
					events.append({"type":"radar_built","country":from_c,"message":"ایستگاه رادار در %s - شناسایی +۲٪" % from_c})
				"factory":
					state.get("industry",{}).update({"output": float(state.get("industry",{}).get("output",100.0)) + 1.0})
					events.append({"type":"factory_built","country":from_c,"message":"کارخانه در %s - تولید صنعتی +۱٪" % from_c})
				"air_defense":
					events.append({"type":"air_defense_built","country":from_c,"message":"سامانه پدافند هوایی در %s مستقر شد" % from_c})
				"port":
					events.append({"type":"port_built","country":from_c,"message":"بندر در %s توسعه یافت - اتصال دریایی +۱۵٪" % from_c})

		if age < 365:
			active_constructions.append(construction)
		else:
			if str(construction.get("status","")) != "completed":
				events.append({"type":"construction_abandoned","build_type":build_type,"message":"ساخت %s نیمه‌کاره رها شد - کمبود بودجه" % build_type})

	adv["constructions"] = active_constructions

	# ==================== ۳) ساختمان‌ها - نگهداری ====================
	var buildings = adv["buildings"]
	var active_buildings = []
	for building in buildings:
		var age = tick - int(building.get("tick",tick))
		# ساختمان‌ها دائمی هستند اما نیاز به نگهداری دارند
		if age < 365*5: # ۵ سال عمر مفید بدون نوسازی
			active_buildings.append(building)
		else:
			# نیاز به نوسازی
			if Deterministic.chance(0.01):
				events.append({"type":"building_decay","building_type":building.get("building_type",""),"message":"ساختمان %s در %s نیاز به نوسازی دارد" % [building.get("building_type",""), building.get("country_id","")]})
			active_buildings.append(building) # هنوز نگه می‌داریم اما با کیفیت کمتر

	adv["buildings"] = active_buildings

	# ==================== ۴) اثرات تجمیعی ====================
	# استحکامات اثر بر دفاع
	var total_forts = 0
	for v in adv["forts"].values():
		total_forts += int(v)
	if total_forts > 0:
		mil["deterrence"] = clamp(float(mil.get("deterrence",60.0)) + total_forts*0.5, 0.0, 150.0)

	# انبارها اثر بر لجستیک
	var total_depots = 0
	for v in adv["depots"].values():
		total_depots += int(v)
	if total_depots > 0:
		mil["logistics_detail"]["fuel_stock_days"] = clamp(float(mil.get("logistics_detail",{}).get("fuel_stock_days",25.0)) + total_depots*0.5, 1.0, 90.0) if mil.has("logistics_detail") else 25.0

	state["map_advanced"] = adv
	state["economy"] = econ
	state["infrastructure"] = infra
	state["military"] = mil

	return {"success":true,"state":state,"events":events}

# === عملیات‌های نقشه‌محور - فراخوان از engine ===
func apply_battle_plan(state: Dictionary, from_c: String, from_unit: String, to_c: String, to_unit: String, plan_type: String, from_lat: float, from_lon: float, to_lat: float, to_lon: float, tick: int) -> Dictionary:
	state = state.duplicate(true)
	var adv = state.get("map_advanced", {})
	adv["battle_plans"] = adv.get("battle_plans", [])

	# هزینه طرح نبرد بر اساس نوع
	var cost_map = {"offensive":0.3e9,"defensive":0.2e9,"encirclement":0.8e9,"breakthrough":0.6e9,"pincer":0.7e9,"amphibious":2.5e9,"airborne":1.5e9}
	var cost = cost_map.get(plan_type, 0.5e9)
	state["economy"]["national_debt"] = float(state["economy"].get("national_debt",0.0)) + cost
	state["military"]["readiness"] = clamp(float(state["military"].get("readiness",0.70)) - 0.003, 0.10, 1.0)

	adv["battle_plans"].append({
		"from_country": from_c,
		"from_unit": from_unit,
		"to_country": to_c,
		"to_unit": to_unit,
		"plan_type": plan_type,
		"from_lat": from_lat,
		"from_lon": from_lon,
		"to_lat": to_lat,
		"to_lon": to_lon,
		"tick": tick,
		"status": "planned",
		"progress": 0.0,
		"label": "%s: %s → %s" % [plan_type, from_c, to_c]
	})

	state["map_advanced"] = adv

	var events = [{
		"type":"battle_plan_created",
		"plan_type":plan_type,
		"from":from_c,"to":to_c,
		"message":"طرح نبرد %s از %s به %s ترسیم شد - هزینه %.1f میلیارد" % [plan_type, WorldManager.get_country_name(from_c) if from_c != "" else "%.1f,%.1f" % [from_lat, from_lon], WorldManager.get_country_name(to_c) if to_c != "" else "%.1f,%.1f" % [to_lat, to_lon], cost/1e9]
	}]

	return {"success":true,"state":state,"events":events}

func apply_construction(state: Dictionary, from_c: String, from_unit: String, to_c: String, to_unit: String, build_type: String, from_lat: float, from_lon: float, to_lat: float, to_lon: float, tick: int) -> Dictionary:
	state = state.duplicate(true)
	var adv = state.get("map_advanced", {})
	adv["constructions"] = adv.get("constructions", [])

	var cost_map = {"road":0.8e9,"rail":1.5e9,"fort":0.6e9,"depot":0.5e9,"airfield":1.2e9,"radar":0.4e9,"port":2.0e9,"bunker":0.3e9,"factory":3.0e9,"air_defense":1.0e9}
	var cost = cost_map.get(build_type, 0.8e9)
	state["economy"]["national_debt"] = float(state["economy"].get("national_debt",0.0)) + cost
	state["economy"]["gdp"] = float(state["economy"].get("gdp",500e9)) * 0.9998 # سرمایه‌گذاری

	adv["constructions"].append({
		"from_country": from_c,
		"from_unit": from_unit,
		"to_country": to_c,
		"to_unit": to_unit,
		"build_type": build_type,
		"from_lat": from_lat,
		"from_lon": from_lon,
		"to_lat": to_lat,
		"to_lon": to_lon,
		"tick": tick,
		"progress": 0.0,
		"status": "building",
		"label": "%s: %s → %s" % [build_type, from_c, to_c]
	})

	state["map_advanced"] = adv

	var events = [{
		"type":"construction_started",
		"build_type":build_type,
		"from":from_c,"to":to_c,
		"message":"ساخت %s از %s به %s آغاز شد - هزینه %.1f میلیارد" % [build_type, from_c, to_c, cost/1e9]
	}]

	return {"success":true,"state":state,"events":events}

func apply_building(state: Dictionary, building_type: String, country_id: String, unit_id: String, lat: float, lon: float, tick: int) -> Dictionary:
	state = state.duplicate(true)
	var adv = state.get("map_advanced", {})
	adv["buildings"] = adv.get("buildings", [])

	var cost_map = {"fort":0.6e9,"airfield":1.2e9,"depot":0.5e9,"radar":0.4e9,"factory":3.0e9,"bunker":0.3e9,"air_defense":1.0e9,"port":2.0e9,"silo":1.5e9,"barracks":0.8e9}
	var cost = cost_map.get(building_type, 0.8e9)
	state["economy"]["national_debt"] = float(state["economy"].get("national_debt",0.0)) + cost

	adv["buildings"].append({
		"building_type": building_type,
		"country_id": country_id,
		"unit_id": unit_id,
		"lat": lat,
		"lon": lon,
		"tick": tick,
		"status": "active",
		"label": "%s در %s" % [building_type, country_id]
	})

	# اثر فوری بر اساس نوع ساختمان
	match building_type:
		"fort":
			adv["forts"] = adv.get("forts",{})
			adv["forts"][country_id] = int(adv["forts"].get(country_id,0)) + 1
		"depot":
			adv["depots"] = adv.get("depots",{})
			adv["depots"][country_id] = int(adv["depots"].get(country_id,0)) + 1
		"airfield":
			adv["airfields"] = adv.get("airfields",{})
			adv["airfields"][country_id] = int(adv["airfields"].get(country_id,0)) + 1
		"radar":
			adv["radar_stations"] = adv.get("radar_stations",{})
			adv["radar_stations"][country_id] = int(adv["radar_stations"].get(country_id,0)) + 1

	state["map_advanced"] = adv

	var events = [{
		"type":"building_built",
		"building_type":building_type,
		"country":country_id,
		"message":"ساختمان %s در %s ساخته شد - %.1f میلیارد" % [building_type, country_id, cost/1e9]
	}]

	return {"success":true,"state":state,"events":events}

func apply_map_operation(state: Dictionary, target_country: String, operation_type: String, payload: Dictionary, tick: int) -> Dictionary:
	# برای سازگاری با trade_route_warfare - عملیات نقشه‌محور ساده
	state = state.duplicate(true)
	var events = []

	var cost = 0.8e9
	match operation_type:
		"fortify": cost = 0.6e9
		"airfield": cost = 1.2e9
		"depot": cost = 0.5e9
		"radar": cost = 0.4e9
		"factory": cost = 3.0e9
		"bunker": cost = 0.3e9
		"sabotage": cost = 0.5e9
		"airstrike": cost = 1.5e9
		"drone_recon": cost = 0.2e9
		"psyops": cost = 0.1e9
		"special_ops": cost = 1.0e9
		"blockade": cost = 1.0e9

	state["economy"]["national_debt"] = float(state["economy"].get("national_debt",0.0)) + cost

	var adv = state.get("map_advanced",{})
	adv["buildings"] = adv.get("buildings",[])
	adv["buildings"].append({"building_type":operation_type,"country_id":target_country,"tick":tick,"status":"active"})

	state["map_advanced"] = adv

	events.append({"type":"map_operation_"+operation_type,"target":target_country,"message":"عملیات %s در %s اجرا شد" % [operation_type, target_country]})

	return {"success":true,"state":state,"events":events}
