extends BaseSystem
# دیپلماسی و روابط بین‌الملل - ۳.۱۴ - روابط دوجانبه، نفوذ، قدرت نرم، تحریم، پیمان، بحران

func compute(state: Dictionary, tick: int) -> Dictionary:
	state = WorldManager.ensure_world(state)
	var dip = state["diplomacy"]
	var mil = state["military"]
	var econ = state["economy"]
	var pol = state["politics"]
	var culture = state.get("culture", {})

	var events = []

	# روابط دوجانبه پویا - دترمینستیک با تاثیر تجارت، اتحاد، جنگ
	var world: Dictionary = state.get("world", {})
	var trade_agreements = world.get("trade_agreements", [])
	var alliances = world.get("alliances", [])
	var wars = world.get("wars", {})

	for country in dip["relations"].keys():
		var rel = float(dip["relations"][country])
		var change = Deterministic.next_range(-0.08, 0.08)
		# تجارت اثر مثبت
		if trade_agreements.has(country):
			change += (70.0 - rel) * 0.003 + 0.02
		# اتحاد اثر قوی مثبت
		if alliances.has(country):
			change += (85.0 - rel) * 0.005 + 0.03
		# جنگ اثر منفی شدید
		if wars.has(country):
			change += (0.0 - rel) * 0.02 - 0.10
		else:
			# بازگشت کند به خنثی ۵۰
			change += (50.0 - rel) * 0.0005
		# اثر قدرت اقتصادی - کشورهای ثروتمند رابطه بهتر
		var gdp_factor = (econ["gdp"]/500e9) * 0.01
		change += gdp_factor
		rel += change
		rel = clamp(rel, 0.0, 100.0)
		dip["relations"][country] = rel

		# آستانه‌ها
		if rel < 20.0 and Deterministic.chance(0.015):
			events.append({"type":"hostility","country":country,"relation":rel,"message":"روابط با %s در آستانه خصومت - سفیر احضار شد" % WorldManager.get_country_name(country)})
		elif rel > 80.0 and Deterministic.chance(0.010):
			events.append({"type":"friendship","country":country,"relation":rel,"message":"دوستی عمیق با %s - تبادل هیات بلندپایه" % WorldManager.get_country_name(country)})

	# نفوذ جهانی = GDP + قدرت نظامی + فناوری دیجیتال + فرهنگ + تجارت
	var influence = 0.0
	influence += (econ["gdp"] / 1_000_000_000_000.0) * 28.0
	influence += mil["power"] * 0.25
	influence += state["technology"]["branches"]["دیجیتال"] * 18.0
	influence += culture.get("cohesion",0.65) * 12.0
	influence += dip["relations"].size() * 0.15
	influence += world.get("trade_agreements", []).size() * 0.8
	dip["influence"] = clamp(influence, 0.0, 100.0)

	# قدرت نرم = فرهنگ + آموزش + دیپلماسی + گردشگری + رسانه
	var soft = 0.0
	soft += culture.get("cohesion",0.65) * 18.0
	soft += state["education"]["quality"] * 12.0
	soft += dip["influence"] * 0.25
	soft += state.get("tourism",{}).get("visitors",5_000_000)/10_000_000.0 * 10.0
	soft += culture.get("media_freedom",0.5) * 8.0
	dip["soft_power"] = clamp(soft, 0.0, 100.0)

	# امتیاز اقدام دیپلماتیک - هر ماه ۳ امتیاز بازتولید
	dip["action_points"] = clamp(float(dip.get("action_points",3.0)) + 0.1, 0.0, 5.0)

	# معاهدات - رشد با نفوذ
	if tick % 60 == 0 and dip["influence"] > 50.0 and Deterministic.chance(0.15):
		var treaty_types = ["تجارت آزاد", "همکاری نظامی", "فرهنگی", "انرژی"]
		dip["treaties"].append({"type": treaty_types[Deterministic.next_int_range(0, treaty_types.size()-1)], "partner": "کشور تصادفی", "tick": tick})

	# تحریم ورودی - اثر بر GDP
	var incoming_sanctions = 0
	for s in dip.get("sanctions", []):
		if not s is Dictionary or s.get("by","foreign") != "player":
			incoming_sanctions += 1
	if incoming_sanctions > 0:
		var penalty = incoming_sanctions * 0.02
		econ["gdp"] *= (1.0 - penalty/365.0)
		econ["growth_rate"] = econ.get("growth_rate",0.02) - penalty*0.001
		events.append({"type":"sanction_effect","count": incoming_sanctions, "gdp_loss": penalty, "message":"%d تحریم فعال - رشد %.2f٪ کاهش" % [incoming_sanctions, penalty*100.0]})

	# رویدادهای دیپلماتیک تصادفی
	if Deterministic.chance(0.008):
		var r = Deterministic.next_float()
		if r < 0.25:
			events.append({"type":"diplomatic_visit","message":"سفر دیپلماتیک - هیاتی از همسایگان وارد شد"})
		elif r < 0.50:
			events.append({"type":"trade_negotiation","message":"مذاکره تجاری - تعرفه‌ها در حال بازنگری"})
		elif r < 0.75:
			if dip["soft_power"] > 60.0:
				events.append({"type":"cultural_exchange","message":"تبادل فرهنگی - هفته فیلم ایرانی در ۵ پایتخت"})
		else:
			events.append({"type":"border_meeting","message":"نشست مرزی - فرماندهان مرزبانی دیدار کردند"})

	state["diplomacy"] = dip
	state["economy"] = econ
	var world_result = WorldManager.simulate(state, tick)
	state = world_result.state
	events.append_array(world_result.events)
	return {"success":true,"state":state,"events":events}
