extends Node
# ────────────────────────────────────────────────────────────────────────────
# دیپلماسی برند ملی و گردشگری فرهنگی — عمق تصویر کشور
# برند ملی، رویدادهای بین‌المللی، نمایشگاه‌ها، میراث فرهنگی و گردشگری فرهنگی.
# برند قوی، گردشگری، صادرات و جذب سرمایه را بالا می‌برد.
# پیوند: گردشگری، فرهنگ، میراث، رسانه، دیاسپورا.
#
# state["nation_brand_policy"] = {
#   "branding":0..1, "events":0..1, "heritage":0..1,
#   "cultural_exports":0..1, "last_event":turn,
#   "brand_index":0..1, "soft_power_gain":0..1 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("nation_brand_policy"):
		state["nation_brand_policy"] = {
			"branding": 0.25, "events": 0.20, "heritage": 0.40,
			"cultural_exports": 0.20, "last_event": -99,
			"brand_index": 0.35, "soft_power_gain": 0.10,
			"tourism_boost": 0.0, "media_image": 0.40
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var nbp: Dictionary = state["nation_brand_policy"]
	var tourism: Dictionary = state.get("tourism", {})
	var culture: Dictionary = state.get("culture_policy", {})
	var heritage: Dictionary = state.get("heritage_policy", {})
	var media: Dictionary = state.get("media", {})
	var econ: Dictionary = state.get("economy", {})
	var dip: Dictionary = state.get("diplomacy", {})

	var branding: float = float(nbp.get("branding", 0.25))
	var events_int: float = float(nbp.get("events", 0.20))
	var her: float = float(nbp.get("heritage", 0.40))
	var exports: float = float(nbp.get("cultural_exports", 0.20))

	# شاخص برند: برندسازی + رویدادها + میراث + تصویر رسانه
	var media_trust: float = float(media.get("trust", 0.55))
	var brand: float = clampf(
		0.15 + branding * 0.30 + events_int * 0.25 + her * 0.20 + exports * 0.15 + media_trust * 0.10,
		0.05, 0.98)
	nbp["brand_index"] = brand

	# قدرت نرم از برند می‌آید
	var soft: float = float(dip.get("soft_power", 35.0)) / 100.0
	var gain: float = clampf((brand - soft) * 0.05, -0.02, 0.05)
	nbp["soft_power_gain"] = gain
	dip["soft_power"] = clampf(float(dip.get("soft_power", 35.0)) + gain * 10.0, 0.0, 100.0)
	state["diplomacy"] = dip

	# تقویت گردشگری
	var tourism_boost: float = clampf(brand * 0.40 + events_int * 0.30, 0.0, 0.95)
	nbp["tourism_boost"] = tourism_boost
	if not tourism.is_empty():
		tourism["visitors"] = int(float(tourism.get("visitors", 5_000_000)) * (1.0 + tourism_boost * 0.001))
		state["tourism"] = tourism

	# تصویر رسانه
	nbp["media_image"] = clampf(0.20 + brand * 0.50 + events_int * 0.20, 0.05, 0.98)

	# اقتصاد فرهنگی
	var gdp: float = float(econ.get("gdp", 1.0))
	# ممیزی GDP (۱۴۰۵): اثر مداوم از کانال مالک-یکتای sector_boosts (نرخ سالانه؛ ماهانه: ×۱۲)
	var nat_boost: Dictionary = econ.get("sector_boosts", {})
	nat_boost["برند ملی"] = (exports * 0.0003 + brand * 0.0002) * 12.0
	econ["sector_boosts"] = nat_boost
	state["economy"] = econ

	# رویدادها
	if brand > 0.65 and Deterministic.chance(0.03):
		events.append({"type": "nation_brand_win", "message": "🌟 برند ملی در رتبه‌بندی جهانی بالا رفت؛ گردشگر و سرمایه جذب شد"})
	elif events_int > 0.55 and Deterministic.chance(0.025):
		events.append({"type": "event_success", "message": "🎪 رویداد بین‌المللی با موفقیت برگزار شد؛ تصویر کشور بهتر شد"})

	state["nation_brand_policy"] = nbp
	return {"state": state, "events": events}

func brand_campaign(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var nbp: Dictionary = state["nation_brand_policy"]
	if turn - int(nbp.get("last_event", -99)) < 5:
		return {"success": false, "reason": "کمپین برند هر ۵ نوبت یک بار", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.003
	nbp["last_event"] = turn
	nbp["branding"] = clampf(float(nbp.get("branding", 0.25)) + 0.15, 0.0, 1.0)
	state["economy"] = econ
	state["nation_brand_policy"] = nbp
	return {"success": true, "state": state,
		"events": [{"type": "branding", "message": "📢 کمپین برند ملی در رسانه‌های جهانی آغاز شد"}]}

func host_event(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var nbp: Dictionary = state["nation_brand_policy"]
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.005
	nbp["events"] = clampf(float(nbp.get("events", 0.20)) + 0.15, 0.0, 1.0)
	state["economy"] = econ
	state["nation_brand_policy"] = nbp
	return {"success": true, "state": state,
		"events": [{"type": "event", "message": "🏟️ میزبانی رویداد بین‌المللی به تصویر کشور کمک کرد"}]}

func promote_heritage(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var nbp: Dictionary = state["nation_brand_policy"]
	nbp["heritage"] = clampf(float(nbp.get("heritage", 0.40)) + 0.15, 0.0, 1.0)
	if state.has("heritage_policy"):
		var hp: Dictionary = state["heritage_policy"]
		hp["preservation"] = clampf(float(hp.get("preservation", 0.5)) + 0.05, 0.0, 1.0)
		state["heritage_policy"] = hp
	state["nation_brand_policy"] = nbp
	return {"success": true, "state": state,
		"events": [{"type": "heritage", "message": "🏛️ میراث فرهنگی در سطح جهانی معرفی شد"}]}

func cultural_export(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var nbp: Dictionary = state["nation_brand_policy"]
	nbp["cultural_exports"] = clampf(float(nbp.get("cultural_exports", 0.20)) + 0.15, 0.0, 1.0)
	state["nation_brand_policy"] = nbp
	return {"success": true, "state": state,
		"events": [{"type": "cultural_export", "message": "🎬 صادرات فرهنگی (سینما، موسیقی، صنایع دستی) ترویج شد"}]}
