extends BaseSystem
# ۳.۸۰ جنگ مسیرهای تجاری - نسخه عمیق نقشه‌محور - حمله به کریدورهای تجاری روی نقشه قابل مشاهده و اجرا
# پوشش: مسیر زمینی/هوایی/دریایی، گلوگاه ۶گانه، عملیات نقشه‌محور، اقتصاد جنگی، دیپلماسی، حقوق بین‌الملل

func compute(state: Dictionary, tick: int) -> Dictionary:
	var warfare = state.get("trade_route_warfare", {})
	warfare["attacks"] = warfare.get("attacks", []) # لیست حملات فعال
	warfare["chokepoints"] = warfare.get("chokepoints", {}) # وضعیت گلوگاه‌ها
	warfare["protected_routes"] = warfare.get("protected_routes", [])
	warfare["convoy_escorts"] = warfare.get("convoy_escorts", [])
	warfare["disrupted_volume"] = warfare.get("disrupted_volume", 0.0)
	warfare["piracy_level"] = warfare.get("piracy_level", 0.10)
	warfare["blockade_effectiveness"] = warfare.get("blockade_effectiveness", 0.0)
	warfare["total_raids"] = warfare.get("total_raids", 0)
	warfare["total_blockades"] = warfare.get("total_blockades", 0)
	warfare["economic_damage"] = warfare.get("economic_damage", 0.0)

	var events = []
	var world = state.get("world", {})
	var econ = state.get("economy", {})
	var mil = state.get("military", {})
	var diplomacy = state.get("diplomacy", {})
	var trade = state.get("trade", {})
	var intel = state.get("intelligence", {})
	var is_at_war = not world.get("wars", {}).is_empty()

	# ==================== ۱) به‌روزرسانی حملات فعال - زمان، فرسایش، تعمیر ====================
	var active_attacks = []
	var disrupted_volume = 0.0
	var total_damage = 0.0

	for attack in warfare["attacks"]:
		var age = tick - int(attack.get("tick", tick))
		var route_type = str(attack.get("route_type", "trade"))
		var operation = str(attack.get("operation", "raid"))
		var from_c = str(attack.get("from", ""))
		var to_c = str(attack.get("to", ""))

		# هر حمله طول عمر دارد - مثلا محاصره ۹۰ روز، حمله ۷ روز، مین ۱۸۰ روز
		var lifetime = {"raid":15, "blockade":90, "sabotage":30, "mine":180, "cyber":10, "drone_strike":7, "protect":60, "escort":45}.get(operation, 30)
		if age > lifetime:
			# حمله تمام شد - ترمیم
			events.append({"type":"route_attack_ended","route_id": attack.get("route_id",""), "operation": operation, "from": from_c, "to": to_c, "message":"پایان عملیات %s بر مسیر %s → %s" % [operation, from_c, to_c]})
			continue

		# اثر حمله بر حجم تجارت مختل شده
		var volume_impact = {"raid":0.8,"blockade":1.5,"sabotage":1.0,"mine":1.2,"cyber":0.5,"drone_strike":0.7,"protect":-0.5,"escort":-0.6}.get(operation, 0.8)
		disrupted_volume += volume_impact
		total_damage += volume_impact * 0.5e9 # نیم میلیارد دلار به ازای هر واحد

		# اگر حمله تهاجمی، احتمال کشف و تلافی
		if operation in ["raid","blockade","sabotage","mine","drone_strike"] and age == 5 and Deterministic.chance(0.15):
			events.append({"type":"route_attack_detected","operation": operation, "from": from_c, "to": to_c, "message":"حمله شما به مسیر تجاری %s کشف شد - محکومیت بین‌المللی" % attack.get("route_id","")})
			diplomacy["influence"] = clamp(float(diplomacy.get("influence",40.0)) - 2.0, 0.0, 100.0)

		active_attacks.append(attack)

	warfare["attacks"] = active_attacks
	warfare["disrupted_volume"] = disrupted_volume
	warfare["economic_damage"] = total_damage
	warfare["piracy_level"] = clamp(disrupted_volume * 0.05 + 0.05, 0.05, 0.80)
	warfare["blockade_effectiveness"] = clamp(active_attacks.filter(func(a): return str(a.get("operation",""))=="blockade").size()*0.15, 0.0, 0.90)

	# ==================== ۲) گلوگاه‌های ۶گانه جهانی - هرمز، سوئز، باب‌المندب، مالاکا، پاناما، جبل‌الطارق ====================
	var chokepoints_data = {
		"hormuz":{"name_fa":"تنگه هرمز","type":"sea","volume":0.9,"critical":true,"lat":26.5,"lon":56.2},
		"suez":{"name_fa":"کانال سوئز","type":"sea","volume":0.85,"critical":true,"lat":30.0,"lon":32.5},
		"bab_el_mandeb":{"name_fa":"باب‌المندب","type":"sea","volume":0.75,"critical":true,"lat":12.5,"lon":43.3},
		"malacca":{"name_fa":"تنگه مالاکا","type":"sea","volume":0.80,"critical":true,"lat":2.5,"lon":101.0},
		"panama":{"name_fa":"کانال پاناما","type":"sea","volume":0.70,"critical":false,"lat":9.0,"lon":-79.5},
		"gibraltar":{"name_fa":"جبل‌الطارق","type":"sea","volume":0.65,"critical":false,"lat":36.0,"lon":-5.5}
	}

	var chokepoints = warfare["chokepoints"]
	# پاکسازی قدیمی‌ها (+۱۸۰ روز)
	var active_chokepoints = {}
	for cp_id in chokepoints.keys():
		var cp = chokepoints[cp_id]
		if tick - int(cp.get("tick",tick)) < 180:
			active_chokepoints[cp_id] = cp
		else:
			events.append({"type":"chokepoint_cleared","id": cp_id, "message":"گلوگاه %s پاکسازی شد - تردد عادی" % chokepoints_data.get(cp_id,{}).get("name_fa",cp_id)})
	chokepoints = active_chokepoints

	# اثر گلوگاه بر تجارت جهانی
	var blockade_penalty = 0.0
	for cp_id in chokepoints.keys():
		var cp = chokepoints[cp_id]
		var action = str(cp.get("action","blockade"))
		var cp_info = chokepoints_data.get(cp_id,{"volume":0.5})
		var vol = float(cp_info.get("volume",0.5))
		if action == "blockade":
			blockade_penalty += vol*0.15
			if Deterministic.chance(0.012):
				events.append({"type":"chokepoint_blockade_impact","id": cp_id, "name": cp_info.get("name_fa",cp_id), "message":"محاصره %s - قیمت نفت +۱۰٪" % cp_info.get("name_fa",cp_id)})
				econ["inflation"] = clamp(float(econ.get("inflation",0.08)) + 0.005, -0.02, 0.60)
		elif action == "mine":
			blockade_penalty += vol*0.20
		elif action == "secure":
			blockade_penalty -= vol*0.10

	# ==================== ۳) اثرات اقتصادی - واقعی ====================
	if disrupted_volume > 0.0 or blockade_penalty > 0.0:
		var total_penalty = disrupted_volume*0.008 + blockade_penalty
		trade["exports"] = float(trade.get("exports",80e9)) * (1.0 - total_penalty*0.02/365.0)
		trade["imports"] = float(trade.get("imports",70e9)) * (1.0 - total_penalty*0.015/365.0)
		econ["gdp"] = float(econ.get("gdp",500e9)) * (1.0 - total_penalty*0.01/365.0)
		econ["inflation"] = float(econ.get("inflation",0.08)) + total_penalty*0.001/365.0

		# اثر بر ذخایر نفت و غذا اگر گلوگاه انرژی باشد
		var resources = state.get("resources",{})
		if chokepoints.has("hormuz") or chokepoints.has("bab_el_mandeb"):
			resources["inventory"]["نفت"] = clamp(float(resources["inventory"].get("نفت",80.0)) - total_penalty*0.1, 5.0, 150.0)
			state["resources"] = resources

	# ==================== ۴) اثرات دیپلماتیک و نظامی ====================
	if disrupted_volume > 3.0 and Deterministic.chance(0.015):
		events.append({"type":"trade_route_crisis","disrupted": disrupted_volume, "message":"بحران مسیرهای تجاری - %.1f واحد حجم مختل شد - تورم جهانی" % disrupted_volume})
		diplomacy["influence"] = clamp(float(diplomacy.get("influence",40.0)) - 1.0, 0.0, 100.0)

	if warfare["piracy_level"] > 0.50 and Deterministic.chance(0.012):
		events.append({"type":"piracy_surge","piracy": warfare["piracy_level"], "message":"افزایش دزدی دریایی - بیمه کشتیرانی +۳۰۰٪"})

	# اگر در جنگیم، حملات به مسیرهای دشمن مشروع‌تر است
	if is_at_war and disrupted_volume > 0:
		mil["deterrence"] = clamp(float(mil.get("deterrence",60.0)) + disrupted_volume*0.5, 0.0, 150.0)
		state["military"]["logistics_detail"]["supply_line_vulnerability"] = clamp(float(state["military"]["logistics_detail"].get("supply_line_vulnerability",0.30)) + disrupted_volume*0.01, 0.05, 0.90)

	# ==================== ۵) حفاظت و اسکورت ====================
	var protected_volume = 0.0
	for attack in active_attacks:
		if str(attack.get("operation","")) in ["protect","escort"]:
			protected_volume += 0.6

	if protected_volume > 0:
		trade["exports"] = float(trade.get("exports",80e9)) * (1.0 + protected_volume*0.005/365.0)
		if Deterministic.chance(0.008):
			events.append({"type":"convoy_protection_success","protected": protected_volume, "message":"اسکورت کاروان موفق - %d کشتی با امنیت عبور کرد" % int(protected_volume*10.0)})

	# ==================== ۶) آمار ====================
	warfare["total_raids"] = active_attacks.filter(func(a): return str(a.get("operation",""))=="raid").size()
	warfare["total_blockades"] = active_attacks.filter(func(a): return str(a.get("operation",""))=="blockade").size() + chokepoints.size()

	state["trade_route_warfare"] = warfare
	state["economy"] = econ
	state["trade"] = trade
	state["diplomacy"] = diplomacy
	state["military"] = mil

	return {"success":true,"state":state,"events":events}

# ==================== عملیات حمله - از فرمان‌ها صدا زده می‌شود ====================
func apply_attack(state: Dictionary, route_id: String, route_type: String, operation: String, from_c: String, to_c: String, tick: int) -> Dictionary:
	state = state.duplicate(true)
	var warfare = state.get("trade_route_warfare", {})
	warfare["attacks"] = warfare.get("attacks", [])

	# هزینه عملیات بر اساس نوع
	var cost_map = {"raid":0.5e9,"blockade":2.0e9,"sabotage":0.8e9,"mine":1.2e9,"cyber":0.3e9,"drone_strike":1.0e9,"protect":1.5e9,"escort":1.0e9}
	var cost = cost_map.get(operation, 0.5e9)
	state["economy"]["national_debt"] = float(state["economy"].get("national_debt",0.0)) + cost
	state["military"]["readiness"] = clamp(float(state["military"].get("readiness",0.70)) - 0.005, 0.10, 1.0)

	warfare["attacks"].append({
		"route_id": route_id,
		"route_type": route_type,
		"type": route_type,
		"operation": operation,
		"from": from_c,
		"to": to_c,
		"from_country": from_c,
		"to_country": to_c,
		"tick": tick,
		"cost": cost,
		"status": "active",
		"label": "%s → %s (%s)" % [WorldManager.get_country_name(from_c) if from_c != "" else route_id, WorldManager.get_country_name(to_c) if to_c != "" else "", operation]
	})

	state["trade_route_warfare"] = warfare

	var events = [{
		"type":"route_attack_launched",
		"route_id": route_id,
		"route_type": route_type,
		"operation": operation,
		"from": from_c,
		"to": to_c,
		"cost": cost,
		"message":"عملیات %s بر مسیر %s (%s → %s) آغاز شد - هزینه %.1f میلیارد" % [operation, route_type, from_c, to_c, cost/1e9]
	}]

	# اثر فوری
	if operation == "blockade":
		state["diplomacy"]["influence"] = clamp(float(state["diplomacy"].get("influence",40.0)) - 1.5, 0.0, 100.0)
	elif operation == "protect":
		state["diplomacy"]["influence"] = clamp(float(state["diplomacy"].get("influence",40.0)) + 1.0, 0.0, 100.0)

	return {"success":true,"state":state,"events":events}

func apply_chokepoint(state: Dictionary, chokepoint_id: String, action: String, tick: int) -> Dictionary:
	state = state.duplicate(true)
	var warfare = state.get("trade_route_warfare", {})
	warfare["chokepoints"] = warfare.get("chokepoints", {})

	var cost_map = {"blockade":3.0e9,"mine":2.5e9,"secure":2.0e9,"patrol":1.0e9,"sabotage":1.5e9}
	var cost = cost_map.get(action, 2.0e9)
	state["economy"]["national_debt"] = float(state["economy"].get("national_debt",0.0)) + cost

	warfare["chokepoints"][chokepoint_id] = {
		"id": chokepoint_id,
		"action": action,
		"tick": tick,
		"cost": cost,
		"level": 0.6 if action == "blockade" else 0.5
	}

	state["trade_route_warfare"] = warfare

	var chokepoint_names = {"hormuz":"هرمز","suez":"سوئز","bab_el_mandeb":"باب‌المندب","malacca":"مالاکا","panama":"پاناما","gibraltar":"جبل‌الطارق"}
	var fa_name = chokepoint_names.get(chokepoint_id, chokepoint_id)

	var events = [{
		"type":"chokepoint_action",
		"id": chokepoint_id,
		"action": action,
		"message":"عملیات %s در گلوگاه %s آغاز شد" % [action, fa_name]
	}]

	return {"success":true,"state":state,"events":events}

func apply_map_operation(state: Dictionary, target_country: String, operation_type: String, payload: Dictionary, tick: int) -> Dictionary:
	state = state.duplicate(true)
	var events = []

	# هزینه و اثر بر اساس نوع عملیات نقشه‌محور
	var cost = 0.0
	var message = ""
	match operation_type:
		"airstrike":
			cost = 1.5e9
			message = "حمله هوایی به %s - خسارت به زیرساخت" % WorldManager.get_country_name(target_country)
			state["military"]["readiness"] = clamp(float(state["military"].get("readiness",0.70)) - 0.01, 0.10, 1.0)
			if state.get("world",{}).get("wars",{}).has(target_country):
				state["world"]["wars"][target_country]["progress"] = float(state["world"]["wars"][target_country].get("progress",0.0)) + 2.0
		"naval_blockade":
			cost = 2.5e9
			message = "محاصره دریایی %s - بنادر قفل شد" % WorldManager.get_country_name(target_country)
			state["trade_route_warfare"] = state.get("trade_route_warfare",{})
			state["trade_route_warfare"]["attacks"] = state["trade_route_warfare"].get("attacks",[])
			state["trade_route_warfare"]["attacks"].append({"route_id": "naval_"+target_country, "route_type":"sea","operation":"blockade","from":state.get("world",{}).get("player_country","IRN"),"to":target_country,"tick":tick,"status":"active"})
		"sabotage_infrastructure":
			cost = 0.8e9
			message = "خرابکاری زیرساخت %s - خط لوله منفجر شد" % WorldManager.get_country_name(target_country)
			state["infrastructure"]["quality"] = clamp(float(state["infrastructure"].get("quality",0.55)) - 0.005, 0.05, 0.98)
		"drone_swarm":
			cost = 1.2e9
			message = "حمله پهپاد انبوه به %s - ۲۰ فروند" % WorldManager.get_country_name(target_country)
		"cyber_attack":
			cost = 0.5e9
			message = "حمله سایبری به %s - شبکه برق مختل" % WorldManager.get_country_name(target_country)
		"propaganda":
			cost = 0.2e9
			message = "عملیات روانی علیه %s - تضعیف روحیه" % WorldManager.get_country_name(target_country)
		"humanitarian":
			cost = 0.6e9
			message = "کمک بشردوستانه به %s - نفوذ نرم" % WorldManager.get_country_name(target_country)
			state["diplomacy"]["soft_power"] = clamp(float(state["diplomacy"].get("soft_power",35.0)) + 2.0, 0.0, 100.0)

	state["economy"]["national_debt"] = float(state["economy"].get("national_debt",0.0)) + cost
	events.append({"type":"map_operation","operation":operation_type,"target":target_country,"cost":cost,"message":message})

	return {"success":true,"state":state,"events":events}
