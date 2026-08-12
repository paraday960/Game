extends Node
# ────────────────────────────────────────────────────────────────────────────
# دیپلماسی و سفیران — عمق روابط دوجانبه
# سفیران در کشورهای کلیدی (بزرگ/همسایه/درگیر) اثر واقعی بر روابط و اطلاعات
# دارند. بازیکن: اعزام سفیر، فراخوانی (اعتراض)، مذاکره، و ردّ پای دیپلماتیک
# (تصویر). پیوند: روابط، اطلاعات، سازمان‌ها، رقابت قدرتها.
#
# state["diplomacy_policy"] = { "ambassadors":{country:0..1}, "missions":0,
#   "image":0..100 }
# ────────────────────────────────────────────────────────────────────────────
const KEY_COUNTRIES := ["USA", "CHN", "RUS", "TUR", "DEU", "SAU", "JPN", "IND"]

func ensure(state: Dictionary) -> Dictionary:
	if not state.has("diplomacy_policy"):
		var ambassadors: Dictionary = {}
		for cid in KEY_COUNTRIES:
			ambassadors[cid] = 0.0
		state["diplomacy_policy"] = {"ambassadors": ambassadors, "missions": 0, "image": 50.0}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var dp: Dictionary = state["diplomacy_policy"]
	var diplomacy: Dictionary = state.get("diplomacy", {})
	var relations: Dictionary = diplomacy.get("relations", {})
	var ambassadors: Dictionary = dp.get("ambassadors", {})
	var image := float(dp.get("image", 50.0))

	# سفیران روابط را تقویت می‌کنند
	for cid in ambassadors.keys():
		var level := float(ambassadors[cid])
		if level > 0.0 and relations.has(cid):
			relations[cid] = clampf(float(relations.get(cid, 50.0)) + level * 0.15, 0.0, 100.0)
	diplomacy["relations"] = relations
	state["diplomacy"] = diplomacy
	# تصویر دیپلماتیک: از قدرت نرم و رفتار
	image = clampf(image + (float(state["culture_policy"].get("soft_power", 40.0)) - 50.0) * 0.05, 0.0, 100.0)
	dp["image"] = image
	# رویداد: بحران دیپلماتیک در روابط بسیار بد با سفیر
	for cid in ambassadors.keys():
		var level := float(ambassadors[cid])
		if level > 0.0 and relations.has(cid) and float(relations[cid]) < 15.0 and Deterministic.chance(0.04):
			ambassadors[cid] = 0.0
			events.append({"type": "ambassador_expelled", "message": "🚨 سفیر کشور در %s اخراج شد؛ روابط به پایین‌ترین سطح رسید" % WorldManager.get_country_name(cid)})
	dp["ambassadors"] = ambassadors
	state["diplomacy_policy"] = dp
	return {"state": state, "events": events}

func send_ambassador(state: Dictionary, country: String) -> Dictionary:
	state = ensure(state)
	if not KEY_COUNTRIES.has(country):
		return {"success": false, "reason": "کشور در فهرست سفارت‌های کلیدی نیست", "state": state, "events": []}
	var dp: Dictionary = state["diplomacy_policy"]
	var ambassadors: Dictionary = dp.get("ambassadors", {})
	if float(ambassadors.get(country, 0.0)) >= 1.0:
		return {"success": false, "reason": "سفیر در این کشور مستقر است", "state": state, "events": []}
	var capital := float(state.get("policies", {}).get("political_capital", 0.0))
	if capital < 0.5:
		return {"success": false, "reason": "سرمایه سیاسی کافی نیست", "state": state, "events": []}
	state["policies"]["political_capital"] = capital - 0.5
	ambassadors[country] = 1.0
	dp["ambassadors"] = ambassadors
	dp["missions"] = int(dp.get("missions", 0)) + 1
	state["diplomacy_policy"] = dp
	state["diplomacy"]["influence"] = clampf(float(state["diplomacy"].get("influence", 40.0)) + 1.0, 0.0, 100.0)
	return {"success": true, "state": state,
		"events": [{"type": "ambassador_sent", "message": "🤝 سفیر جدید در %s مستقر شد؛ روابط و نفوذ دیپلماتیک تقویت یافت" % WorldManager.get_country_name(country)}]}

func recall_ambassador(state: Dictionary, country: String) -> Dictionary:
	state = ensure(state)
	if not KEY_COUNTRIES.has(country):
		return {"success": false, "reason": "کشور نامعتبر", "state": state, "events": []}
	var dp: Dictionary = state["diplomacy_policy"]
	var ambassadors: Dictionary = dp.get("ambassadors", {})
	if float(ambassadors.get(country, 0.0)) <= 0.0:
		return {"success": false, "reason": "سفیری برای فراخوانی نیست", "state": state, "events": []}
	ambassadors[country] = 0.0
	dp["ambassadors"] = ambassadors
	state["diplomacy_policy"] = dp
	var relations: Dictionary = state.get("diplomacy", {}).get("relations", {})
	if relations.has(country):
		relations[country] = clampf(float(relations.get(country, 50.0)) - 5.0, 0.0, 100.0)
		state["diplomacy"]["relations"] = relations
	return {"success": true, "state": state,
		"events": [{"type": "ambassador_recalled", "message": "✈️ سفیر از %s فراخوانده شد؛ پیام اعتراض رسمی به کشور مقصد" % WorldManager.get_country_name(country)}]}

func diplomatic_negotiation(state: Dictionary, country: String) -> Dictionary:
	state = ensure(state)
	if not KEY_COUNTRIES.has(country):
		return {"success": false, "reason": "کشور نامعتبر", "state": state, "events": []}
	var dp: Dictionary = state["diplomacy_policy"]
	var capital := float(state.get("policies", {}).get("political_capital", 0.0))
	if capital < 1.0:
		return {"success": false, "reason": "سرمایه سیاسی کافی نیست", "state": state, "events": []}
	state["policies"]["political_capital"] = capital - 1.0
	dp["missions"] = int(dp.get("missions", 0)) + 1
	state["diplomacy_policy"] = dp
	var relations: Dictionary = state.get("diplomacy", {}).get("relations", {})
	var gain := 6.0 + float(dp.get("image", 50.0)) / 20.0
	if relations.has(country):
		relations[country] = clampf(float(relations.get(country, 50.0)) + gain, 0.0, 100.0)
		state["diplomacy"]["relations"] = relations
	state["diplomacy"]["influence"] = clampf(float(state["diplomacy"].get("influence", 40.0)) + 1.5, 0.0, 100.0)
	return {"success": true, "state": state,
		"events": [{"type": "negotiation", "message": "🗣️ مذاکرات سطح بالا با %s: روابط %s واحد بهبود یافت" % [WorldManager.get_country_name(country), PersianFormatter.to_persian_digits(str(int(gain)))]}]}
