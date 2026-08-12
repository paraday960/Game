extends Node
# ============================================================
# 🎯 رویدادهای ویژه فصلی — مثل رویدادهای محدود زمان در بازی‌های موفق
# هر فصل یک رویداد تصادفی (دترمینستیک از seed) با افکت روی بازار/اقتصاد.
# در state ذخیره می‌شود (دترمینستیک — از Deterministic استفاده می‌کند).
# ============================================================

const EVENT_POOL = [
	{"id": "oil_boom", "title": "بازار نفت داغ", "icon": "🛢️",
		"desc": "قیمت جهانی نفت به‌شدت بالا رفت — درآمد صادرات نفت +۵۰٪", "duration": 3},
	{"id": "tech_wave", "title": "موج فناوری", "icon": "💡",
		"desc": "پیشرفت جهانی فناوری شتاب گرفت — سرعت پژوهش +۳۰٪", "duration": 3},
	{"id": "tourism_boom", "title": "رونق گردشگری", "icon": "🏖️",
		"desc": "گردشگران جهانی به کشور شما هجوم آوردند — درآمد گردشگری +۴۰٪", "duration": 2},
	{"id": "grain_crisis", "title": "بحران غله جهانی", "icon": "🌾",
		"desc": "خشکسالی جهانی قیمت غذا را بالا برد — امنیت غذایی تحت فشار", "duration": 2},
	{"id": "sports_glory", "title": "افتخار ورزشی", "icon": "🏅",
		"desc": "پیروزی‌های ورزشی بین‌المللی — شادی مردم +۵٪", "duration": 1},
	{"id": "green_push", "title": "جنبش سبز جهانی", "icon": "🌱",
		"desc": "فشار جهانی برای محیط‌زیست — انرژی پاک +۲۰٪", "duration": 3}
]

const SEASONS := ["بهار", "تابستان", "پاییز", "زمستان"]

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	var active: Array = state.get("special_events", [])
	# انقضای رویدادهای قدیمی
	var fresh: Array = []
	for event in active:
		if int(event.get("until_tick", 0)) > turn:
			fresh.append(event)
	active = fresh
	# شروع رویداد جدید در ابتدای هر فصل (تغییر فصل)
	var season: String = str(state.get("time", {}).get("season", state.get("clock", {}).get("season", "بهار")))
	var last_season: String = str(state.get("last_event_season", ""))
	if season != last_season and active.size() == 0:
		var seed_val := int(state.get("seed", 12345)) + turn
		var idx := seed_val % EVENT_POOL.size()
		var event_def: Dictionary = EVENT_POOL[idx]
		active.append({
			"id": event_def["id"], "title": event_def["title"], "icon": event_def["icon"],
			"desc": event_def["desc"], "start_tick": turn,
			"until_tick": turn + int(event_def.get("duration", 2)) * 30
		})
		state["last_event_season"] = season
	# اعمال افکت‌های رویدادهای فعال روی state
	_apply_effects(state, active)
	state["special_events"] = active
	return {"state": state, "events": []}

func _apply_effects(state: Dictionary, active: Array) -> void:
	var market: Dictionary = state.get("market", {})
	var prices: Dictionary = market.get("prices", {})
	var econ: Dictionary = state.get("economy", {})
	var tech: Dictionary = state.get("technology", {})
	var pop: Dictionary = state.get("population", {})
	var env: Dictionary = state.get("environment", {})
	for event in active:
		match str(event.get("id", "")):
			"oil_boom":
				prices["نفت"] = float(prices.get("نفت", 75.0)) * 1.05
				econ["oil_revenue_multiplier"] = 1.5
			"tech_wave":
				tech["research_bonus"] = 1.3
			"tourism_boom":
				econ["tourism_multiplier"] = 1.4
			"grain_crisis":
				prices["غذا"] = float(prices.get("غذا", 0.9)) * 1.08
			"sports_glory":
				pop["happiness"] = clampf(float(pop.get("happiness", 0.6)) + 0.003, 0.05, 0.95)
			"green_push":
				env["green_energy"] = clampf(float(env.get("green_energy", 0.2)) + 0.003, 0.02, 0.9)
	market["prices"] = prices
	state["market"] = market
	state["economy"] = econ
	state["technology"] = tech
	state["population"] = pop
	state["environment"] = env
