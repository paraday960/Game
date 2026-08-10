extends BaseSystem
# دیپلماسی و روابط بین‌الملل - ۳.۱۴

func compute(state: Dictionary, tick: int) -> Dictionary:
	state = WorldManager.ensure_world(state)
	var dip = state["diplomacy"]
	var mil = state["military"]
	var econ = state["economy"]
	var pol = state["politics"]

	var events = []

	# روابط دوجانبه پویا
	for country in dip["relations"].keys():
		var rel = dip["relations"][country]
		# f(تاریخچه، تجارت، اتحادها، ایدئولوژی، همسایگی)
		var change = Deterministic.next_range(-1.5, 1.5)
		# قدرت نظامی بر دیپلماسی اثر دارد
		change += (mil["power"] - 65.0) * 0.01
		# اقتصاد
		change += (econ["gdp"] / 500_000_000_000.0 - 1.0) * 2.0
		rel += change
		dip["relations"][country] = clamp(rel, 0.0, 100.0)

		# آستانه خصومت <25
		if rel < 25 and Deterministic.chance(0.02):
			events.append({"type": "hostility", "country": country, "relation": rel, "message": "روابط با %s به مرحله خصومت رسید" % WorldManager.get_country_name(country)})

	# نفوذ = f(اقتصاد، ارتش، فناوری، قدرت نرم)
	var influence = 0.0
	influence += (econ["gdp"] / 1_000_000_000_000.0) * 30.0
	influence += mil["power"] * 0.3
	influence += state["technology"]["branches"]["دیجیتال"] * 20.0
	influence += state["culture"]["cohesion"] * 0.2
	dip["influence"] = clamp(influence, 0.0, 100.0)

	# قدرت نرم
	var soft = 0.0
	soft += state["culture"]["cohesion"] * 20.0
	soft += state["education"]["quality"] * 15.0
	soft += dip["influence"] * 0.3
	dip["soft_power"] = clamp(soft, 0.0, 100.0)

	# فقط تحریم‌های ورودی بر اقتصاد بازیکن جریمه مستقیم دارند؛ تحریم اعمال‌شده توسط بازیکن جداست.
	var incoming_sanctions = 0
	for sanction in dip["sanctions"]:
		if not sanction is Dictionary or sanction.get("by", "foreign") != "player":
			incoming_sanctions += 1
	if incoming_sanctions > 0:
		var sanction_penalty = incoming_sanctions * 0.02
		econ["gdp"] *= (1.0 - sanction_penalty / 365.0)
		events.append({"type": "sanction_effect", "gdp_loss": sanction_penalty})

	state["diplomacy"] = dip
	state["economy"] = econ
	var world_result = WorldManager.simulate(state, tick)
	state = world_result.state
	events.append_array(world_result.events)
	return {"success": true, "state": state, "events": events}
