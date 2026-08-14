extends Node
# هوش سیاست خارجی کشورهای جهان - رودمپ ۵
# دیپلماسی تا پیش از این یک‌طرفه بود: فقط بازیکن اقدام می‌کرد. حالا کشورهای راهبردی (۴۰ قدرت
# اصلی و نزدیک‌ترین همسایگان) هر ماه نسبت به بازیکن موضع می‌گیرند و بر اساس آن تصمیم می‌گیرند:
# تحریم بازیکن، پیشنهاد توافق تجاری/اتحاد/صلح از سوی آن‌ها، و در موقعیت بسیار خصمانه و در برابر
# بازکننده‌ی ضعیف، اعلام جنگ علیه بازیکن. همه تصمیم‌ها دترمینستیک و سهماهه محدودند تا جهان
# زنده ولی قابل‌پیش‌بینی بماند.

const MAX_FOREIGN_ACTIONS_PER_MONTH = 2
const OFFER_LIFETIME_DAYS = 60
const MAX_PENDING_OFFERS = 3
const OFFER_TYPES_TEXT = {
	"trade_agreement": "پیشنهاد توافق تجاری",
	"alliance": "پیشنهاد تشکیل اتحاد",
	"peace": "درخواست صلح"
}

# اعتبارسنجی ایستای وابستگی‌ها؛ قالب داده خارجی ندارد و از داده WorldManager تغذیه می‌کند.
func is_valid() -> bool:
	return WorldManager.is_valid()

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = WorldManager.ensure_world(state)
	var world: Dictionary = state["world"]
	var diplomacy: Dictionary = state["diplomacy"]
	var player_id = str(world.get("player_country", WorldManager.default_country))
	var events: Array = []

	# انقضای پیشنهادهای ورودی که بازیکن به آن‌ها پاسخ نداده است.
	var current_day = TimeManager.get_total_days(state)
	var live_offers: Array = []
	for offer in world.get("incoming_offers", []):
		if int(offer.get("expires_day", current_day + 1)) > current_day:
			live_offers.append(offer)
		else:
			events.append({
				"type": "offer_expired",
				"target": str(offer.get("from", "")),
				"message": "مهلت «%s» از سوی %s به پایان رسید" % [
					str(offer.get("offer_text", "پیشنهاد")), WorldManager.get_country_name(str(offer.get("from", "")))]
			})
	world["incoming_offers"] = live_offers

	# به‌روزرسانی موضع همه کشورهای با رابطه ثبت‌شده نسبت به بازیکن.
	var stances: Dictionary = world.get("player_stances", {})
	for country_id in diplomacy.get("relations", {}).keys():
		stances[country_id] = _stance_for(state, str(country_id))
	world["player_stances"] = stances

	# تصمیم ماهانه‌ی کشورهای راهبردی، به ترتیب ثابت برای قطعی‌بودن مصرف اعداد دترمینستیک.
	var issued = 0
	var strategic_ids = WorldManager.get_strategic_country_ids(player_id, 40).duplicate()
	strategic_ids.sort()
	for country_id in strategic_ids:
		if issued >= MAX_FOREIGN_ACTIONS_PER_MONTH:
			break
		country_id = str(country_id)
		if country_id == player_id or not diplomacy.get("relations", {}).has(country_id):
			continue
		var decision = _country_decision(state, country_id, turn, current_day)
		if decision.has("action"):
			issued += 1
			events.append_array(decision.get("events", []))

	state["world"] = world
	state["diplomacy"] = diplomacy
	return {"state": state, "events": events}

# موضع کشور نسبت به بازیکن: allied / friendly / neutral / hostile / at_war
func _stance_for(state: Dictionary, country_id: String) -> String:
	var world: Dictionary = state.get("world", {})
	if world.get("wars", {}).has(country_id):
		return "at_war"
	if world.get("alliances", []).has(country_id):
		return "allied"
	var relation = float(state.get("diplomacy", {}).get("relations", {}).get(country_id, 50.0))
	if relation >= 60.0:
		return "friendly"
	if relation <= 25.0:
		return "hostile"
	return "neutral"

func _country_decision(state: Dictionary, country_id: String, turn: int, current_day: int) -> Dictionary:
	var world: Dictionary = state["world"]
	var diplomacy: Dictionary = state["diplomacy"]
	var relation = float(diplomacy.get("relations", {}).get(country_id, 50.0))
	var stance = _stance_for(state, country_id)
	var name_fa = WorldManager.get_country_name(country_id)
	var events: Array = []

	# ۱) در جنگ با بازیکن: دشمنِ در حال باختن صلح می‌خواهد.
	if world.get("wars", {}).has(country_id):
		var war: Dictionary = world["wars"][country_id]
		if float(war.get("progress", 0.0)) >= 55.0 and not _has_offer(world, "peace", country_id):
			_add_offer(world, "peace", country_id, turn, current_day,
				"دولت %s در برابر پیشروی شما برای آتش‌بس آماده است" % name_fa)
			events.append({
				"type": "incoming_offer", "target": country_id,
				"message": "%s رسماً درخواست آتش‌بس کرد؛ در پرونده دیپلماسی پاسخ دهید" % name_fa
			})
			return {"action": "offer_peace", "events": events}
		return {}

	# ۲) متخاصم: تحریم بازیکن یا در برابر بازیکن‌ی ضعیف و بی‌پشت، اعلام جنگ.
	if stance == "hostile":
		if not WorldManager._has_incoming_sanction(diplomacy, country_id) and relation <= 20.0:
			if Deterministic.chance(0.20):
				diplomacy["sanctions"].append({"target": country_id, "by": "foreign", "tick": turn})
				events.append({
					"type": "foreign_sanction", "target": country_id,
					"message": "%s کشور شما را تحریم کرد؛ راه مذاکره باز است" % name_fa
				})
				return {"action": "sanction", "events": events}
		# جنگ‌طلبی فقط در برابر کشوری با بازدارندگی فرسوده که همسایه است یا وزن راهبردی بالا دارد.
		var deterrence = float(state.get("military", {}).get("deterrence", 60.0))
		var player_wars = world.get("wars", {}).size()
		if relation <= 10.0 and deterrence < 30.0 and player_wars <= 1 and _can_reach_player(state, country_id):
			if Deterministic.chance(0.06):
				world["wars"][country_id] = {
					"target": country_id, "started_tick": turn, "progress": 0.0,
					"player_losses": 0, "enemy_losses": 0, "started_by": "foreign"
				}
				diplomacy["relations"][country_id] = 0.0
				state["politics"]["tension"] = clamp(float(state["politics"].get("tension", 0.3)) + 0.10, 0.0, 1.0)
				events.append({
					"type": "foreign_war_declared", "target": country_id,
					"message": "⚠️ %s به کشور شما اعلام جنگ داد!" % name_fa
				})
				return {"action": "war", "events": events}
		return {}

	# ۳) دوستانه: پیشنهاد توافق تجاری یا اتحاد به بازیکن.
	if stance == "friendly" or stance == "allied":
		if not world.get("trade_agreements", []).has(country_id) and relation >= 58.0 and not _has_offer(world, "trade_agreement", country_id):
			if Deterministic.chance(0.12):
				_add_offer(world, "trade_agreement", country_id, turn, current_day,
					"دولت %s آمادگی امضای توافق تجاری با شما را دارد" % name_fa)
				events.append({
					"type": "incoming_offer", "target": country_id,
					"message": "%s توافق تجاری پیشنهاد کرد" % name_fa
				})
				return {"action": "offer_trade", "events": events}
		if stance == "friendly" and not world.get("alliances", []).has(country_id) and relation >= 78.0 and not _has_offer(world, "alliance", country_id):
			if Deterministic.chance(0.08):
				_add_offer(world, "alliance", country_id, turn, current_day,
					"دولت %s برای پیمان دفاعی-راهبردی با شما اعلام آمادگی کرد" % name_fa)
				events.append({
					"type": "incoming_offer", "target": country_id,
					"message": "%s پیشنهاد اتحاد راهبردی داد" % name_fa
				})
				return {"action": "offer_alliance", "events": events}
	return {}

# جنگ زمینی/تنها از همسایه نزدیک معقول است؛ قدرت‌های بزرگ از راه دور هم می‌رسند.
func _can_reach_player(state: Dictionary, country_id: String) -> bool:
	var world: Dictionary = state["world"]
	var player_id = str(world.get("player_country", ""))
	var us = WorldManager.countries.get(player_id, {})
	var them = WorldManager.countries.get(country_id, {})
	if them.is_empty() or us.is_empty():
		return false
	if float(them.get("strategic_weight", 0.0)) >= 0.70:
		return true
	var distance = Vector2(float(us.get("lon", 0.0)), float(us.get("lat", 0.0))).distance_to(Vector2(float(them.get("lon", 0.0)), float(them.get("lat", 0.0))))
	return distance < 35.0

func _has_offer(world: Dictionary, offer_type: String, from_country: String) -> bool:
	for offer in world.get("incoming_offers", []):
		if str(offer.get("type", "")) == offer_type and str(offer.get("from", "")) == from_country:
			return true
	return false

func _add_offer(world: Dictionary, offer_type: String, from_country: String, turn: int, current_day: int, text: String):
	var offers: Array = world.get("incoming_offers", [])
	while offers.size() >= MAX_PENDING_OFFERS:
		offers.pop_front()
	offers.append({
		"id": "%s_%s_%d" % [offer_type, from_country, turn],
		"type": offer_type,
		"from": from_country,
		"offer_text": str(OFFER_TYPES_TEXT.get(offer_type, offer_type)),
		"message": text,
		"created_day": current_day,
		"expires_day": current_day + OFFER_LIFETIME_DAYS,
		"tick": turn
	})
	world["incoming_offers"] = offers
