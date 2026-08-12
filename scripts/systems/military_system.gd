extends BaseSystem
# ارتش و دفاع - ۳.۱۳ - نسخه عمیق واقع‌گرایانه (واقعی مثل دنیای واقعی - همه کار ممکن)
# پوشش کامل: بسیج، سربازگیری، شاخه‌ها، تجهیزات تفصیلی، لجستیک، فرماندهی، دکترین، جبهه‌ها،
# عملیات تهاجمی/تدافعی/ثبات/ویژه/راهبردی، جنگ هوایی/دریایی/موشکی/پهپادی/سایبری/فضایی/هیبریدی،
# تلفات، اقتصاد جنگی، جنگ اطلاعاتی، حقوق جنگ، خاتمه جنگ

func compute(state: Dictionary, tick: int) -> Dictionary:
	var mil = state.get("military", {})
	var econ = state.get("economy", {})
	var pop = state.get("population", {})
	var pol = state.get("politics", {})
	var tech = state.get("technology", {})
	var infra = state.get("infrastructure", {})
	var resources = state.get("resources", {})
	var culture = state.get("culture", {})
	var intel = state.get("intelligence", {})
	var world = state.get("world", {})
	var diplomacy = state.get("diplomacy", {})

	var events = []

	# ==================== ۱) ساختار پایه - حفظ سازگاری ====================
	mil["power"] = mil.get("power", 65.0)
	mil["readiness"] = mil.get("readiness", float(BalanceConfig.get_value("military.readiness_initial", 0.70)))
	mil["budget_share"] = econ.get("budget_allocations", {}).get("ارتش", 0.08)
	mil["personnel"] = mil.get("personnel", 500000)
	mil["branches"] = mil.get("branches", {"زمینی":0.50,"هوایی":0.25,"دریایی":0.15,"موشکی":0.10})
	mil["deterrence"] = mil.get("deterrence", 60.0)
	mil["war_exhaustion"] = mil.get("war_exhaustion", 0.0)

	var development_modifiers = MilitaryManager.get_effective_modifiers(state)
	var effective_readiness_base = clamp(float(mil["readiness"]) + float(development_modifiers.get("readiness_bonus", 0.0)), 0.1, 1.0)
	mil["effective_readiness"] = effective_readiness_base

	# ==================== ۲) پرسنل - تفصیلی واقعی ====================
	var personnel = mil.get("personnel_detail", {})
	personnel["active"] = personnel.get("active", 350000) # حرفه‌ای
	personnel["reserve"] = personnel.get("reserve", 400000) # ذخیره آموزش‌دیده
	personnel["conscript"] = personnel.get("conscript", 150000) # وظیفه
	personnel["paramilitary"] = personnel.get("paramilitary", 80000) # شبه‌نظامی / مرزبانی / بسیج
	personnel["special_forces"] = personnel.get("special_forces", 15000)
	personnel["total"] = personnel["active"] + personnel["reserve"] + personnel["conscript"] + personnel["paramilitary"]
	personnel["mobilized"] = personnel.get("mobilized", 0) # تعداد فراخوانده‌شده اضافی
	personnel["casualties_kia"] = personnel.get("casualties_kia", 0)
	personnel["casualties_wia"] = personnel.get("casualties_wia", 0)
	personnel["casualties_mia"] = personnel.get("casualties_mia", 0)
	personnel["pow"] = personnel.get("pow", 0) # اسیر
	personnel["training_level"] = personnel.get("training_level", 0.65) # 0-1
	personnel["experience"] = personnel.get("experience", 0.50) # تجربه رزمی
	personnel["morale"] = personnel.get("morale", 0.70)
	personnel["cohesion"] = personnel.get("cohesion", 0.68)
	personnel["leadership_quality"] = personnel.get("leadership_quality", 0.60) # کیفیت فرماندهان
	personnel["conscription_policy"] = personnel.get("conscription_policy", "volunteer_selective") # volunteer, selective, universal, mass_levy
	personnel["draft_age_min"] = personnel.get("draft_age_min", 18)
	personnel["draft_age_max"] = personnel.get("draft_age_max", 27)
	personnel["women_in_military"] = personnel.get("women_in_military", 0.12)
	personnel["desertion_rate"] = personnel.get("desertion_rate", 0.02)

	# ==================== ۳) بسیج (Mobilization) - ۵ سطح واقعی ====================
	var mobilization = mil.get("mobilization", {})
	mobilization["level"] = mobilization.get("level", 0) # 0=صلح, 1=هشدار, 2=بسیج جزئی, 3=کامل, 4=جنگ تمام‌عیار, 5=هسته‌ای
	mobilization["level_fa"] = mobilization.get("level_fa", "صلح")
	mobilization["progress"] = mobilization.get("progress", 1.0) # 0-1 پیشرفت بسیج فعلی
	mobilization["days_to_full"] = mobilization.get("days_to_full", 0)
	mobilization["war_economy"] = mobilization.get("war_economy", 0.0) # 0-1 سهم اقتصاد جنگی
	mobilization["martial_law"] = mobilization.get("martial_law", false)
	mobilization["rationing"] = mobilization.get("rationing", false)

	var level_names = {0:"صلح", 1:"آمادگی پایین", 2:"بسیج جزئی", 3:"بسیج کامل", 4:"جنگ تمام‌عیار", 5:"هشدار هسته‌ای"}
	mobilization["level_fa"] = level_names.get(mobilization["level"], "نامشخص")

	# محاسبه زمان بسیج و اثر اقتصادی/اجتماعی
	var base_mobilization_time = {0:0, 1:7, 2:21, 3:45, 4:90, 5:2}.get(mobilization["level"], 0)
	mobilization["days_to_full"] = int(base_mobilization_time * (1.5 - personnel["training_level"]*0.5))

	# اثر بسیج بر اقتصاد و شادی - واقعی: بسیج گسترده تولید غیرنظامی را مختل می‌کند
	var mobilization_econ_cost = mobilization["level"] * 0.015
	var mobilization_happiness_cost = mobilization["level"] * 0.03
	if mobilization["level"] >= 3:
		mobilization["war_economy"] = clamp(mobilization["war_economy"] + 0.01, 0.0, 0.85)
		mobilization["rationing"] = mobilization["level"] >= 4
		mobilization["martial_law"] = mobilization["level"] >= 4 and pol.get("tension",0.35) > 0.6
	else:
		mobilization["war_economy"] = clamp(mobilization["war_economy"] - 0.005, 0.0, 0.85)

	# ==================== ۴) تجهیزات - انبار تفصیلی واقعی ====================
	var equipment = mil.get("equipment_detail", {})
	# زمینی
	equipment["tanks_mbt"] = equipment.get("tanks_mbt", 1200) # تانک اصلی میدان
	equipment["tanks_light"] = equipment.get("tanks_light", 300)
	equipment["ifv"] = equipment.get("ifv", 1500) # نفربر رزمی
	equipment["apc"] = equipment.get("apc", 2500) # نفربر زرهی
	equipment["artillery_towed"] = equipment.get("artillery_towed", 800)
	equipment["artillery_sp"] = equipment.get("artillery_sp", 500) # خودکششی
	equipment["mlrs"] = equipment.get("mlrs", 200) # راکت‌انداز چندگانه
	equipment["mortar"] = equipment.get("mortar", 1200)
	equipment["atgm"] = equipment.get("atgm", 3000) # موشک ضدتانک
	equipment["manpads"] = equipment.get("manpads", 1500)
	equipment["shorad"] = equipment.get("shorad", 120) # پدافند کوتاه‌برد
	equipment["sam_medium"] = equipment.get("sam_medium", 40)
	equipment["sam_long"] = equipment.get("sam_long", 18)
	equipment["trucks"] = equipment.get("trucks", 12000)
	equipment["engineering"] = equipment.get("engineering", 400) # مهندسی رزمی

	# هوایی
	equipment["fighters_air_superiority"] = equipment.get("fighters_air_superiority", 80)
	equipment["fighters_multirole"] = equipment.get("fighters_multirole", 120)
	equipment["bombers"] = equipment.get("bombers", 20)
	equipment["attack_helicopters"] = equipment.get("attack_helicopters", 60)
	equipment["transport_helicopters"] = equipment.get("transport_helicopters", 80)
	equipment["transport_aircraft"] = equipment.get("transport_aircraft", 30)
	equipment["awacs"] = equipment.get("awacs", 4)
	equipment["tankers"] = equipment.get("tankers", 6)
	equipment["uav_recon"] = equipment.get("uav_recon", 150)
	equipment["uav_combat"] = equipment.get("uav_combat", 80)
	equipment["uav_loitering"] = equipment.get("uav_loitering", 300) # مهمات پرسه‌زن مثل شاهد
	equipment["uav_swarm_capable"] = equipment.get("uav_swarm_capable", 20)

	# دریایی
	equipment["carrier"] = equipment.get("carrier", 0)
	equipment["destroyer"] = equipment.get("destroyer", 6)
	equipment["frigate"] = equipment.get("frigate", 10)
	equipment["corvette"] = equipment.get("corvette", 15)
	equipment["submarine_ssn"] = equipment.get("submarine_ssn", 0) # هسته‌ای تهاجمی
	equipment["submarine_ssk"] = equipment.get("submarine_ssk", 6) # دیزلی
	equipment["submarine_ssbn"] = equipment.get("submarine_ssbn", 0) # هسته‌ای بالستیک
	equipment["amphibious"] = equipment.get("amphibious", 8)
	equipment["patrol_boats"] = equipment.get("patrol_boats", 40)
	equipment["minesweepers"] = equipment.get("minesweepers", 6)
	equipment["supply_ships"] = equipment.get("supply_ships", 10)

	# موشکی و پدافند راهبردی
	equipment["ballistic_short"] = equipment.get("ballistic_short", 200) # <1000km
	equipment["ballistic_medium"] = equipment.get("ballistic_medium", 60) # 1000-3000km
	equipment["ballistic_irbm"] = equipment.get("ballistic_irbm", 10)
	equipment["cruise_land_attack"] = equipment.get("cruise_land_attack", 300)
	equipment["cruise_antiship"] = equipment.get("cruise_antiship", 150)
	equipment["hypersonic"] = equipment.get("hypersonic", 10)
	equipment["sam_long_strategic"] = equipment.get("sam_long_strategic", 12) # S-300/400

	# سایبری، فضایی، جنگ الکترونیک
	equipment["ew_systems"] = equipment.get("ew_systems", 40) # اخلالگر
	equipment["cyber_units"] = equipment.get("cyber_units", 15)
	equipment["satellites_military"] = equipment.get("satellites_military", 6)
	equipment["satellites_recon"] = equipment.get("satellites_recon", 4)

	# وضعیت کیفی تجهیزات
	equipment["avg_age_years"] = equipment.get("avg_age_years", 12.0)
	equipment["operational_rate"] = equipment.get("operational_rate", 0.75) # نرخ عملیاتی - چقدر آماده است
	equipment["maintenance_backlog"] = equipment.get("maintenance_backlog", 0.20)

	# ==================== ۵) لجستیک - شریان حیاتی جنگ واقعی ====================
	var logistics = mil.get("logistics_detail", {})
	logistics["fuel_stock_days"] = logistics.get("fuel_stock_days", 25.0)
	logistics["ammo_stock_days"] = logistics.get("ammo_stock_days", 20.0)
	logistics["ammo_types"] = logistics.get("ammo_types", {"small_arms":100.0,"artillery":100.0,"tank":100.0,"air":100.0,"missile":100.0,"sam":100.0})
	logistics["spare_parts"] = logistics.get("spare_parts", 70.0)
	logistics["food_stock_days"] = logistics.get("food_stock_days", 30.0)
	logistics["medical_capacity"] = logistics.get("medical_capacity", 0.70)
	logistics["medevac_helicopters"] = logistics.get("medevac_helicopters", 20)
	logistics["field_hospitals"] = logistics.get("field_hospitals", 12)

	logistics["supply_lines"] = logistics.get("supply_lines", {"road":0.60,"rail":0.50,"sea":0.40,"air":0.35})
	logistics["supply_line_vulnerability"] = logistics.get("supply_line_vulnerability", 0.30) # آسیب‌پذیری در برابر کمین/پهپاد
	logistics["depots"] = logistics.get("depots", 15)
	logistics["fobs"] = logistics.get("fobs", 8) # پایگاه جلویی
	logistics["convoy_trucks"] = logistics.get("convoy_trucks", 800)
	logistics["convoy_protection"] = logistics.get("convoy_protection", 0.60)

	logistics["daily_consumption"] = logistics.get("daily_consumption", {"fuel":500.0,"ammo":300.0,"food":100.0}) # تن در روز در صلح
	logistics["wartime_multiplier"] = logistics.get("wartime_multiplier", 4.5) # در جنگ ۴.۵ برابر

	logistics["airlift_capacity"] = logistics.get("airlift_capacity", 800.0) # تن در روز
	logistics["sealift_capacity"] = logistics.get("sealift_capacity", 5000.0)
	logistics["rail_capacity"] = logistics.get("rail_capacity", 3000.0)
	logistics["road_capacity"] = logistics.get("road_capacity", 2000.0)

	logistics["is_blockaded"] = logistics.get("is_blockaded", false)
	logistics["blockade_level"] = logistics.get("blockade_level", 0.0)

	# مصرف روزانه بر اساس سطح بسیج و جنگ
	var is_at_war = not world.get("wars", {}).is_empty()
	var consumption_mult = 1.0 + mobilization["level"]*0.8 + (4.0 if is_at_war else 0.0)
	logistics["daily_consumption"]["fuel"] = 500.0 * consumption_mult
	logistics["daily_consumption"]["ammo"] = 300.0 * consumption_mult * (1.2 if mil.get("branches",{}).get("زمینی",0.5) > 0.5 else 0.8)
	logistics["daily_consumption"]["food"] = 100.0 * (1.0 + personnel["total"]/500000.0*0.3)

	# کاهش ذخایر با مصرف، افزایش با تولید و واردات
	var prod_capacity = state.get("industry",{}).get("output",100.0)/100.0
	var fuel_prod = resources.get("production",{}).get("نفت",8.0) * prod_capacity
	logistics["fuel_stock_days"] = clamp(logistics["fuel_stock_days"] - consumption_mult*0.05 + fuel_prod*0.02 + (0.0 if logistics["is_blockaded"] else 0.08) + Deterministic.next_range(-0.05,0.08), 1.0, 90.0)
	logistics["ammo_stock_days"] = clamp(logistics["ammo_stock_days"] - consumption_mult*0.06 + prod_capacity*0.04 + Deterministic.next_range(-0.06,0.07), 0.5, 60.0)
	logistics["food_stock_days"] = clamp(logistics["food_stock_days"] - 0.03 + state.get("agriculture",{}).get("food_security",0.85)*0.05, 3.0, 90.0)

	# مهمات تفکیکی - هر نوع جدا
	for ammo_type in logistics["ammo_types"].keys():
		var base_cons = {"small_arms":0.03,"artillery":0.08,"tank":0.06,"air":0.07,"missile":0.05,"sam":0.04}.get(ammo_type,0.05)
		var new_val = float(logistics["ammo_types"][ammo_type]) - base_cons*consumption_mult + prod_capacity*0.03 + Deterministic.next_range(-1.0,1.5)
		logistics["ammo_types"][ammo_type] = clamp(new_val, 0.0, 150.0)

	# قطعات یدکی - فرسایش با سن تجهیزات
	logistics["spare_parts"] = clamp(logistics["spare_parts"] - equipment["avg_age_years"]*0.001 - consumption_mult*0.002 + prod_capacity*0.01, 10.0, 100.0)
	equipment["operational_rate"] = clamp(0.40 + logistics["spare_parts"]/100.0*0.40 + (1.0 - equipment["maintenance_backlog"])*0.20, 0.20, 0.95)
	equipment["maintenance_backlog"] = clamp(equipment["maintenance_backlog"] + consumption_mult*0.001 - float(state.get("economy",{}).get("budget_allocations",{}).get("ارتش",0.12))*0.002, 0.05, 0.70)
	equipment["avg_age_years"] += 1.0/365.0

	# خطوط تدارکات - آسیب‌پذیری در برابر پهپاد و پارتیزان
	if is_at_war:
		var enemy_air_superiority = 0.5 # ساده‌سازی - بعدا از جنگ هوایی می‌آید
		var drone_threat = 0.40 + (world.get("wars",{}).size()*0.05)
		logistics["supply_line_vulnerability"] = clamp(0.20 + enemy_air_superiority*0.25 + drone_threat*0.25 + (1.0 - logistics["convoy_protection"])*0.20, 0.05, 0.90)
		# اگر آسیب‌پذیری بالا، ذخایر سریع‌تر کم می‌شود
		if logistics["supply_line_vulnerability"] > 0.65 and Deterministic.chance(0.015):
			logistics["fuel_stock_days"] -= Deterministic.next_range(1.0,3.0)
			events.append({"type":"supply_convoy_ambushed","vulnerability": logistics["supply_line_vulnerability"], "message":"کمین به کاروان تدارکاتی - %d کامیون سوخت منهدم شد" % Deterministic.next_int_range(2,8)})
	else:
		logistics["supply_line_vulnerability"] = clamp(logistics["supply_line_vulnerability"]*0.98, 0.05, 0.40)

	# محاصره دریایی - اثر دریایی و قدرت دشمن
	if is_at_war and world.get("wars",{}).size() > 0:
		# اگر دشمن ناوگان قوی داشته باشد و ما ضعیف
		var enemy_naval_power = 70.0 # فرض میانگین
		var our_naval = float(equipment["destroyer"]*15 + equipment["frigate"]*10 + equipment["submarine_ssk"]*20)
		if enemy_naval_power > our_naval*0.5 and Deterministic.chance(0.008):
			logistics["is_blockaded"] = true
			logistics["blockade_level"] = clamp(logistics["blockade_level"]+0.05, 0.0, 0.85)
			events.append({"type":"naval_blockade","level": logistics["blockade_level"], "message":"محاصره دریایی - واردات سوخت ۴۰٪ کاهش یافت"})
		elif our_naval > enemy_naval_power and logistics["is_blockaded"]:
			logistics["blockade_level"] = clamp(logistics["blockade_level"]-0.03, 0.0, 0.85)
			if logistics["blockade_level"] < 0.10:
				logistics["is_blockaded"] = false
				events.append({"type":"blockade_broken","message":"شکست محاصره دریایی - خطوط کشتیرانی باز شد"})

	# ==================== ۶) فرماندهی و دکترین - ۸ دکترین واقعی ====================
	var command = mil.get("command_detail", {})
	command["doctrine"] = command.get("doctrine", mil.get("military_development",{}).get("doctrine","balanced") if mil.has("military_development") else "balanced")
	command["doctrine_name_fa"] = command.get("doctrine_name_fa", "متوازن")
	command["c4isr_level"] = command.get("c4isr_level", 0.60) # فرماندهی، کنترل، ارتباطات، کامپیوتر، اطلاعات، مراقبت، شناسایی
	command["communication_security"] = command.get("communication_security", 0.65)
	command["ew_capability"] = command.get("ew_capability", 0.55) # جنگ الکترونیک
	command["night_operations"] = command.get("night_operations", 0.50)
	command["joint_operations"] = command.get("joint_operations", 0.55) # عملیات مشترک زمین/هوا/دریا
	command["initiative"] = command.get("initiative", 0.60) # ابتکار
	command["decision_cycle"] = command.get("decision_cycle", 24.0) # ساعت - OODA loop
	command["general_staff_quality"] = command.get("general_staff_quality", 0.60)

	var doctrines_full = {
		"defensive":{"name_fa":"دفاع سرزمینی","desc":"دفاع در عمق، استحکامات، ضد حمله محدود","power_mult":0.92,"readiness_bonus":0.06,"defense_bonus":0.35,"offense_penalty":-0.25,"deterrence_bonus":8.0,"casualty_reduction":0.18,"logistics_bonus":0.05},
		"balanced":{"name_fa":"متوازن","desc":"ترکیب دفاع و حمله منعطف","power_mult":1.0,"readiness_bonus":0.0,"defense_bonus":0.10,"offense_bonus":0.10,"deterrence_bonus":0.0,"casualty_reduction":0.0,"logistics_bonus":0.0},
		"maneuver":{"name_fa":"مانور / بلیتزکریگ","desc":"نفوذ سریع، محاصره، جنگ برق‌آسا، تمرکز زرهی","power_mult":1.18,"readiness_bonus":-0.03,"defense_bonus":-0.15,"offense_bonus":0.40,"deterrence_bonus":5.0,"casualty_reduction":-0.08,"logistics_bonus":-0.10},
		"attrition":{"name_fa":"فرسایشی","desc":"آتش سنگین، نابودی تدریجی دشمن، جنگ خندق","power_mult":1.05,"readiness_bonus":0.02,"defense_bonus":0.15,"offense_bonus":0.15,"deterrence_bonus":2.0,"casualty_reduction":-0.05,"logistics_bonus":-0.15},
		"guerrilla":{"name_fa":"چریکی / نامتقارن","desc":"کمین، تله، جنگ فرسایشی طولانی، عدم تقارن","power_mult":0.75,"readiness_bonus":0.08,"defense_bonus":0.40,"offense_bonus":-0.20,"deterrence_bonus":-5.0,"casualty_reduction":0.20,"logistics_bonus":0.20},
		"expeditionary":{"name_fa":"برون‌مرزی","desc":"قدرت‌نمایی، عملیات دوربرد، آبی-خاکی","power_mult":1.08,"readiness_bonus":-0.02,"defense_bonus":-0.10,"offense_bonus":0.25,"deterrence_bonus":4.0,"casualty_reduction":-0.05,"logistics_bonus":-0.12},
		"hybrid":{"name_fa":"هیبریدی","desc":"ترکیب متعارف + سایبری + اطلاعاتی + نیابتی + پهپاد swarm","power_mult":1.12,"readiness_bonus":0.04,"defense_bonus":0.10,"offense_bonus":0.20,"deterrence_bonus":6.0,"casualty_reduction":0.08,"logistics_bonus":0.05},
		"deterrence":{"name_fa":"بازدارندگی هسته‌ای/راهبردی","desc":"حداکثر بازدارندگی با حداقل درگیری","power_mult":0.95,"readiness_bonus":0.05,"defense_bonus":0.30,"offense_bonus":-0.30,"deterrence_bonus":25.0,"casualty_reduction":0.15,"logistics_bonus":0.10}
	}
	var current_doctrine = doctrines_full.get(command["doctrine"], doctrines_full["balanced"])
	command["doctrine_name_fa"] = current_doctrine["name_fa"]

	# C4ISR با فناوری دیجیتال و ماهواره و آموزش
	var sat_recon = float(equipment["satellites_recon"])
	var c4isr_target = float(state.get("technology",{}).get("branches",{}).get("دیجیتال",0.20))*0.35 + tech.get("branches",{}).get("صنعت",0.20)*0.15 + personnel["training_level"]*0.20 + sat_recon*0.05 + 0.25
	command["c4isr_level"] = clamp(command["c4isr_level"]*0.97 + c4isr_target*0.03, 0.15, 0.97)

	# جنگ الکترونیک - تجهیزات + سایبر
	command["ew_capability"] = clamp(command["ew_capability"]*0.985 + (float(equipment["ew_systems"])/40.0*0.4 + float(equipment["cyber_units"])/15.0*0.3 + 0.3)*0.015, 0.10, 0.95)

	# عملیات شبانه - آموزش + تجهیزات دید در شب
	command["night_operations"] = clamp(command["night_operations"] + personnel["training_level"]*0.0003 + current_doctrine["readiness_bonus"]*0.0002, 0.10, 0.90)

	# عملیات مشترک - ستاد کل
	command["joint_operations"] = clamp(command["joint_operations"]*0.992 + (command["c4isr_level"]*0.4 + personnel["leadership_quality"]*0.3 + 0.3)*0.008, 0.15, 0.95)
	command["general_staff_quality"] = clamp(command["general_staff_quality"] + personnel["experience"]*0.0002 + state.get("education",{}).get("quality",0.55)*0.0001, 0.20, 0.95)

	# چرخه تصمیم OODA - کوتاه‌تر بهتر (آمریکا ~12 ساعت، روسیه ~24-48)
	command["decision_cycle"] = 48.0 - command["c4isr_level"]*20.0 - command["general_staff_quality"]*10.0 - personnel["training_level"]*5.0
	command["decision_cycle"] = clamp(command["decision_cycle"], 4.0, 48.0)

	# ابتکار = روحیه + آموزش + دکترین تهاجمی
	command["initiative"] = clamp(personnel["morale"]*0.3 + personnel["training_level"]*0.25 + current_doctrine["offense_bonus"]*0.2 + command["c4isr_level"]*0.15 + 0.10, 0.10, 0.95)

	# ==================== ۷) جبهه‌ها و عملیات - مدل واقعی جنگ ====================
	var fronts = mil.get("fronts_detail", {}) # هر جنگ می‌تواند چند جبهه داشته باشد
	fronts["active_fronts"] = fronts.get("active_fronts", [])
	fronts["total_width_km"] = fronts.get("total_width_km", 0.0)
	fronts["breakthrough_sectors"] = fronts.get("breakthrough_sectors", 0)

	# اگر در جنگیم، جبهه بساز یا به‌روز کن
	if is_at_war:
		for war_target in world.get("wars", {}).keys():
			var war = world["wars"][war_target]
			var front = {}
			front["target"] = war_target
			front["progress"] = float(war.get("progress", 0.0)) # -100 تا +100
			front["width_km"] = 300.0 + Deterministic.next_range(-50.0, 150.0) # عرض جبهه
			front["terrain"] = ["دشت","کوهستان","شهری","بیابان","جنگل","باتلاق"].pick_random() if false else "دشت" # ساده‌سازی دترمینستیک
			# تعیین زمین بر اساس اقلیم کشور هدف - ساده
			front["terrain"] = "کوهستان" if Deterministic.chance(0.15) else "دشت" if Deterministic.chance(0.5) else "شهری" if Deterministic.chance(0.2) else "بیابان"
			front["weather"] = "آفتابی" if Deterministic.chance(0.6) else "بارانی" if Deterministic.chance(0.2) else "برفی" if Deterministic.chance(0.1) else "مه‌آلود"
			front["fortification"] = 0.40 + Deterministic.next_range(0.0,0.40) # استحکامات دشمن
			front["supply_status"] = clamp(logistics["fuel_stock_days"]/30.0*0.4 + logistics["ammo_stock_days"]/20.0*0.4 + logistics["supply_lines"]["road"]*0.2, 0.05, 0.98)
			front["air_superiority"] = 0.50 + (float(equipment["fighters_multirole"])/120.0 - 0.5)*0.3 + command["c4isr_level"]*0.1 # 0=برتری دشمن، 1=برتری ما
			front["force_ratio"] = 1.0 # نسبت نیرو بعدا محاسبه می‌شود
			fronts["active_fronts"].append(front)
		fronts["total_width_km"] = 0.0
		for f in fronts["active_fronts"]:
			fronts["total_width_km"] += float(f.get("width_km",300.0))

		# تشخیص رخنه / محاصره
		fronts["breakthrough_sectors"] = 0
		for f in fronts["active_fronts"]:
			if float(f.get("progress",0.0)) > 60.0 and float(f.get("supply_status",0.5)) > 0.6 and Deterministic.chance(0.08):
				fronts["breakthrough_sectors"] += 1
				events.append({"type":"breakthrough","target": f.get("target",""), "progress": f.get("progress",0.0), "message":"رخنه در جبهه %s - نیروهای زرهی وارد عمق شدند" % WorldManager.get_country_name(f.get("target",""))})

			if float(f.get("progress",0.0)) < -60.0 and Deterministic.chance(0.06):
				events.append({"type":"enemy_breakthrough","target": f.get("target",""), "message":"دشمن در جبهه %s رخنه کرد - عقب‌نشینی تاکتیکی" % WorldManager.get_country_name(f.get("target",""))})

			# محاصره - اگر تدارکات قطع
			if float(f.get("supply_status",0.5)) < 0.25 and Deterministic.chance(0.04):
				events.append({"type":"encirclement_risk","target": f.get("target",""), "supply": f.get("supply_status",0.5), "message":"خطر محاصره در جبهه %s - خط تدارکات قطع شد" % WorldManager.get_country_name(f.get("target",""))})

	else:
		fronts["active_fronts"] = []
		fronts["total_width_km"] = 0.0
		fronts["breakthrough_sectors"] = 0

	# ==================== ۸) عملیات جنگی - انواع واقعی ====================
	var operations = mil.get("operations_detail", {})
	operations["offensive_operations"] = operations.get("offensive_operations", []) # تهاجمی: breakthrough, encirclement, pincer, frontal, amphibious, air_assault
	operations["defensive_operations"] = operations.get("defensive_operations", []) # تدافعی: area_defense, mobile_defense, defense_in_depth, retrograde, delay
	operations["special_operations"] = operations.get("special_operations", []) # ویژه: raid, sabotage, decapitation, hostage_rescue, psyops
	operations["strategic_operations"] = operations.get("strategic_operations", []) # راهبردی: strategic_bombing, SEAD, interdiction, blockade, nuclear_deterrence
	operations["last_operation_tick"] = operations.get("last_operation_tick", 0)

	# ==================== ۹) تلفات و پزشکی - واقعی ====================
	var casualties = mil.get("casualties_detail", {})
	casualties["kia_daily_avg"] = casualties.get("kia_daily_avg", 0.0)
	casualties["wia_daily_avg"] = casualties.get("wia_daily_avg", 0.0)
	casualties["civilian_estimated"] = casualties.get("civilian_estimated", 0)
	casualties["pow_held"] = casualties.get("pow_held", personnel["pow"])
	casualties["pow_enemy_held"] = casualties.get("pow_enemy_held", 0)
	casualties["evacuation_success"] = casualties.get("evacuation_success", 0.85)
	casualties["field_hospital_capacity"] = casualties.get("field_hospital_capacity", logistics["field_hospitals"]*200.0)
	casualties["war_crimes_risk"] = casualties.get("war_crimes_risk", 0.05)
	casualties["geneva_compliance"] = casualties.get("geneva_compliance", 0.85)

	# تخلیه مجروح - هلیکوپتر + بیمارستان
	casualties["evacuation_success"] = clamp(logistics["medevac_helicopters"]/20.0*0.4 + logistics["medical_capacity"]*0.3 + infra.get("quality",0.55)*0.15 + 0.15, 0.20, 0.98)
	casualties["field_hospital_capacity"] = logistics["field_hospitals"] * 200.0 * casualties["evacuation_success"]

	# خطر جرایم جنگی - با کاهش انضباط و افزایش خستگی جنگ
	var discipline = personnel["cohesion"] * 0.5 + personnel["leadership_quality"]*0.3 + command["general_staff_quality"]*0.2
	casualties["war_crimes_risk"] = clamp((1.0 - discipline)*0.4 + mil["war_exhaustion"]*0.3 + (1.0 - casualties["geneva_compliance"])*0.3, 0.01, 0.40)
	casualties["geneva_compliance"] = clamp(casualties["geneva_compliance"] + discipline*0.0002 - mil["war_exhaustion"]*0.0001, 0.40, 0.98)

	# ==================== ۱۰) اقتصاد جنگی ====================
	var war_economy = mil.get("war_economy_detail", {})
	war_economy["industrial_conversion"] = war_economy.get("industrial_conversion", mobilization["war_economy"])
	war_economy["rationing_level"] = war_economy.get("rationing_level", 0.20 if mobilization["rationing"] else 0.0)
	war_economy["war_bonds"] = war_economy.get("war_bonds", 0.0)
	war_economy["lend_lease_received"] = war_economy.get("lend_lease_received", 0.0)
	war_economy["lend_lease_given"] = war_economy.get("lend_lease_given", 0.0)
	war_economy["black_market"] = war_economy.get("black_market", 0.10)
	war_economy["gdp_war_boost"] = war_economy.get("gdp_war_boost", 0.0)

	# تبدیل صنایع
	war_economy["industrial_conversion"] = mobilization["war_economy"]
	if is_at_war:
		war_economy["gdp_war_boost"] = war_economy["industrial_conversion"] * 0.15 - mobilization["war_economy"]*0.10 # کینزی جنگی کوتاه‌مدت اما فرسایش بلندمدت
		war_economy["black_market"] = clamp(war_economy["black_market"] + war_economy["rationing_level"]*0.002, 0.05, 0.50)
		war_economy["rationing_level"] = clamp(mobilization["war_economy"]*0.6, 0.0, 0.80)

	# اوراق قرضه جنگی
	if is_at_war and tick % 90 == 0:
		war_economy["war_bonds"] += econ.get("gdp",500e9)*0.02
		econ["national_debt"] += war_economy["war_bonds"]*0.1

	# ==================== ۱۱) جنگ اطلاعاتی و هیبریدی ====================
	var info_war = mil.get("info_war_detail", {})
	info_war["propaganda_level"] = info_war.get("propaganda_level", 0.40)
	info_war["censorship"] = info_war.get("censorship", 0.30)
	info_war["psyops_offensive"] = info_war.get("psyops_offensive", 0.35)
	info_war["disinformation_defense"] = info_war.get("disinformation_defense", 0.45)
	info_war["public_support_war"] = info_war.get("public_support_war", 0.60)
	info_war["enemy_morale_targeted"] = info_war.get("enemy_morale_targeted", 0.40)
	info_war["cyber_attacks_daily"] = info_war.get("cyber_attacks_daily", 5.0)
	info_war["electronic_warfare_success"] = info_war.get("electronic_warfare_success", 0.50)

	if is_at_war:
		info_war["propaganda_level"] = clamp(info_war["propaganda_level"] + 0.005, 0.20, 0.95)
		info_war["censorship"] = clamp(info_war["censorship"] + 0.003, 0.10, 0.90)
		info_war["public_support_war"] = clamp(info_war["public_support_war"] + (float(state.get("population",{}).get("happiness",0.60))*0.1 + pol.get("trust",0.55)*0.1 - mil["war_exhaustion"]*0.15) - 0.02, 0.10, 0.90)
		info_war["cyber_attacks_daily"] = 5.0 + float(equipment["cyber_units"])*1.5 + command["ew_capability"]*5.0
		info_war["electronic_warfare_success"] = clamp(command["ew_capability"]*0.6 + float(equipment["ew_systems"])/40.0*0.3 + 0.1, 0.10, 0.95)
		if info_war["public_support_war"] < 0.35 and Deterministic.chance(0.012):
			events.append({"type":"anti_war_protest","support": info_war["public_support_war"], "message":"تظاهرات ضدجنگ - حمایت عمومی %.0f٪ سقوط کرد" % (info_war["public_support_war"]*100.0)})
	else:
		info_war["propaganda_level"] = clamp(info_war["propaganda_level"] - 0.002, 0.10, 0.90)
		info_war["public_support_war"] = clamp(info_war["public_support_war"]*0.99 + 0.60*0.01, 0.20, 0.90)

	# ==================== ۱۲) حقوق جنگ و پایان جنگ ====================
	var laws_of_war = mil.get("laws_of_war", {})
	laws_of_war["geneva_compliance"] = casualties["geneva_compliance"]
	laws_of_war["war_crimes_allegations"] = laws_of_war.get("war_crimes_allegations", 0)
	laws_of_war["icc_investigation"] = laws_of_war.get("icc_investigation", false)
	laws_of_war["pow_treatment"] = laws_of_war.get("pow_treatment", 0.70)

	if casualties["war_crimes_risk"] > 0.25 and Deterministic.chance(casualties["war_crimes_risk"]*0.05):
		laws_of_war["war_crimes_allegations"] += 1
		events.append({"type":"war_crime_allegation","risk": casualties["war_crimes_risk"], "message":"اتهام جنایت جنگی - گلوله‌باران منطقه مسکونی"})

	if laws_of_war["war_crimes_allegations"] > 3 and not laws_of_war["icc_investigation"]:
		laws_of_war["icc_investigation"] = true
		events.append({"type":"icc_investigation","message":"دادگاه لاهه تحقیقات جنایات جنگی را آغاز کرد - تحریم‌های جدید"})

	# ==================== ۱۳) محاسبات نهایی قدرت و آمادگی - چندضربی واقعی ====================
	var budget_share_val = econ.get("budget_allocations", {}).get("ارتش", 0.08)
	mil["budget_share"] = budget_share_val
	var mil_budget = econ.get("government_spending", 95e9) * budget_share_val

	var maintenance_ratio = float(BalanceConfig.get_value("military.maintenance", 0.15))
	var maintenance_cost = mil["power"] * 10_000_000.0 * maintenance_ratio / 12.0
	var readiness = mil["readiness"]

	if mil_budget < maintenance_cost:
		readiness -= 0.008
		if Deterministic.chance(0.015):
			events.append({"type":"low_military_budget","readiness": readiness, "budget": mil_budget, "maintenance": maintenance_cost, "message":"بودجه نظامی کم - آمادگی %.0f٪" % (readiness*100.0)})
	else:
		readiness += 0.003

	# اثر خستگی جنگ
	var war_exhaustion = float(mil.get("war_exhaustion", 0.0))
	if is_at_war:
		war_exhaustion = clamp(war_exhaustion + 0.0015 + float(fronts.get("active_fronts",[]).size())*0.0005, 0.0, 1.0)
	else:
		war_exhaustion = clamp(war_exhaustion - 0.008, 0.0, 1.0)
	mil["war_exhaustion"] = war_exhaustion
	readiness = clamp(readiness - war_exhaustion*0.05, 0.05, 1.0)

	# محاسبه قدرت با دکترین و لجستیک و C4ISR و روحیه و تجهیزات
	var personnel_factor = float(personnel["total"]) / 500000.0
	var tech_factor = tech.get("branches",{}).get("نظامی",0.15) * 1.5 + tech.get("branches",{}).get("دیجیتال",0.20)*0.5
	var readiness_factor = clamp(readiness + float(development_modifiers.get("readiness_bonus", 0.0)) + current_doctrine["readiness_bonus"] + command["c4isr_level"]*0.05, 0.1, 1.0)
	mil["effective_readiness"] = readiness_factor
	var logistics_factor = clamp(infra.get("quality",0.55)*0.3 + float(development_modifiers.get("logistics_bonus",0.0)) + float(logistics["supply_lines"]["road"])*0.2 + logistics["fuel_stock_days"]/30.0*0.1 + logistics["ammo_stock_days"]/20.0*0.1, 0.3, 1.6) + current_doctrine["logistics_bonus"]
	var morale_factor = personnel["morale"] * 0.6 + personnel["cohesion"]*0.4
	var equipment_factor = equipment["operational_rate"] * (0.5 + float(equipment["tanks_mbt"])/1200.0*0.2 + float(equipment["fighters_multirole"])/120.0*0.15 + float(equipment["uav_combat"])/80.0*0.10 + 0.25)
	var doctrine_power_mult = current_doctrine["power_mult"]
	var joint_factor = command["joint_operations"] * 0.3 + 0.7

	# پایه قدرت: همیشه از مقدار داده کشور (مثل ۶۵ برای ایران) گرفته می‌شود.
	# نکته مهم: نباید از mil["power"] قبلی استفاده شود چون قدرت قبلی خودش حاصل ضرب
	# ضرایب است و استفاده دوباره از آن، سقوط نمایی قدرت (۶۵→۲۷→۱۳→۵) ایجاد می‌کرد
	# و بازیکن در جنگ‌ها همیشه می‌باخت.
	var player_code = str(state.get("world", {}).get("player_country", "IRN"))
	var country_profile = WorldManager.get_country(player_code)
	var power_base = float(country_profile.get("military_power", float(mil.get("power", 65.0))))
	var power = power_base
	power *= (0.6 + personnel_factor*0.4)
	power *= (0.8 + tech_factor*0.2)
	power *= (0.6 + readiness_factor*0.4)
	power *= logistics_factor
	power *= (0.85 + budget_share_val/0.08*0.15)
	power *= float(development_modifiers.get("power_multiplier", 1.0)) * doctrine_power_mult
	power *= (0.7 + morale_factor*0.3)
	power *= equipment_factor
	power *= joint_factor
	power *= (1.0 - war_exhaustion*0.20)

	# تعادل: قدرت نباید از مقدار داده کشور خیلی فاصله بگیرد.
	# فرمول ضربی عوامل (که غالباً <1 هستند) قدرت را از ۶۵ به ~۳۰ می‌رساند؛
	# با ضریب ۱.۶ خروجی در حالت پایه ~۶۰ می‌شود (نزدیک داده) و با ارتقای ارتش بالاتر می‌رود.
	power *= 1.6
	mil["power"] = clamp(power, 5.0, 350.0)
	mil["readiness"] = clamp(readiness, 0.05, 1.0)

	# بازدارندگی = قدرت + سلاح راهبردی + دکترین + اتحاد + سلاح هسته‌ای فرضی
	var deterrence = mil["power"] * 0.5 + readiness_factor*25.0 + float(development_modifiers.get("deterrence_bonus",0.0)) + current_doctrine["deterrence_bonus"]
	deterrence += float(equipment["ballistic_medium"])*0.5 + float(equipment["ballistic_irbm"])*2.0 + float(equipment["submarine_ssbn"])*15.0 + float(equipment["hypersonic"])*1.5
	deterrence += float(world.get("alliances",[]).size())*4.0
	deterrence += float(equipment["satellites_military"])*1.0
	mil["deterrence"] = clamp(deterrence, 0.0, 150.0)

	# اثر اقتصادی جنگ
	if is_at_war:
		var gdp_cost = war_exhaustion*0.01 + mobilization["level"]*0.005 + fronts["active_fronts"].size()*0.003
		econ["gdp"] = float(econ.get("gdp",500e9)) * (1.0 - gdp_cost/365.0)
		econ["growth_rate"] = float(econ.get("growth_rate",0.02)) - gdp_cost*0.1
		pop["happiness"] = clamp(float(pop.get("happiness",0.60)) - war_exhaustion*0.0006 - mobilization["level"]*0.0003, 0.05, 0.95)
		pol["stability"] = clamp(float(pol.get("stability",0.60)) - war_exhaustion*0.0004 + (1.0 - info_war["public_support_war"])*0.0003, 0.05, 0.95)

	# رویدادهای عمومی نظامی
	if Deterministic.chance(0.009) and is_at_war:
		var front_count = fronts["active_fronts"].size()
		events.append({"type":"war_update","fronts": front_count, "power": mil["power"], "readiness": mil["readiness"], "exhaustion": war_exhaustion, "message":"گزارش جبهه - %d جبهه فعال، قدرت %.0f، خستگی جنگ %.0f٪" % [front_count, mil["power"], war_exhaustion*100.0]})

	if mil["readiness"] < 0.35 and Deterministic.chance(0.018):
		events.append({"type":"military_crisis","readiness": mil["readiness"], "message":"آمادگی رزمی بحرانی - نیاز به نوسازی فوری"})

	if logistics["fuel_stock_days"] < 5.0 and Deterministic.chance(0.015):
		events.append({"type":"fuel_crisis_military","fuel_days": logistics["fuel_stock_days"], "message":"بحران سوخت نظامی - ذخیره %d روز" % int(logistics["fuel_stock_days"])})

	if logistics["ammo_stock_days"] < 3.0 and Deterministic.chance(0.016):
		events.append({"type":"ammo_crisis","ammo_days": logistics["ammo_stock_days"], "message":"بحران مهمات - ذخیره %d روز، آتش محدود" % int(logistics["ammo_stock_days"])})

	if personnel["morale"] < 0.40 and Deterministic.chance(0.012):
		events.append({"type":"low_morale_army","morale": personnel["morale"], "message":"روحیه پایین ارتش - فرار از خدمت افزایش یافت"})

	if equipment["operational_rate"] < 0.50 and Deterministic.chance(0.011):
		events.append({"type":"low_operational_rate","rate": equipment["operational_rate"], "message":"نرخ عملیاتی تجهیزات %d٪ - نیاز به قطعه" % int(equipment["operational_rate"]*100.0)})

	# ذخیره زیرساخت‌های تفصیلی
	mil["personnel_detail"] = personnel
	mil["mobilization"] = mobilization
	mil["equipment_detail"] = equipment
	mil["logistics_detail"] = logistics
	mil["command_detail"] = command
	mil["fronts_detail"] = fronts
	mil["operations_detail"] = operations
	mil["casualties_detail"] = casualties
	mil["war_economy_detail"] = war_economy
	mil["info_war_detail"] = info_war
	mil["laws_of_war"] = laws_of_war

	state["military"] = mil
	state["economy"] = econ
	state["population"] = pop
	state["politics"] = pol
	return {"success":true,"state":state,"events":events}
