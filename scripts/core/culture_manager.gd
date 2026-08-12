extends Node
# ────────────────────────────────────────────────────────────────────────────
# فرهنگ و قدرت نرم — عمق نفوذ جهانی
# سرمایه فرهنگی (میراث، هنر، رسانه) قدرت نرم می‌سازد که روابط، گردشگری،
# محبوبیت رهبر و نفوذ دیپلماتیک را تقویت می‌کند. بازیکن: سرمایه‌گذاری میراث،
# میزبانی رویدادهای جهانی (جشنواره/ورزشی/سینمایی) و تبادل فرهنگی.
#
# state["culture"] = { "soft_power":0..100, "heritage":0..100,
#   "last_event":0, "events_hosted":0 }
# ────────────────────────────────────────────────────────────────────────────

func ensure(state: Dictionary) -> Dictionary:
	if not state.has("culture_policy"):
		state["culture_policy"] = {"soft_power": 40.0, "heritage": 35.0, "last_event": 0, "events_hosted": 0}
	return state

# ── شبیه‌سازی ماهانه ──
func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var cul: Dictionary = state["culture_policy"]
	var econ: Dictionary = state.get("economy", {})
	var leader: Dictionary = state.get("leader", {})
	var tourism: Dictionary = state.get("tourism", {})
	var media: Dictionary = state.get("media", {})
	var soft := float(cul.get("soft_power", 40.0))
	var heritage := float(cul.get("heritage", 35.0))

	# قدرت نرم: میراث + رسانه + محبوبیت رهبر + نفوذ
	soft += (heritage - 50.0) * 0.02
	soft += (float(media.get("trust", 0.55)) - 0.5) * 5.0
	soft += (float(leader.get("popularity_world", 50.0)) - 50.0) * 0.15
	soft += (float(state.get("diplomacy", {}).get("influence", 40.0)) - 40.0) * 0.1
	soft += (40.0 - soft) * 0.01
	cul["soft_power"] = clampf(soft, 5.0, 100.0)

	# اثر: گردشگری + محبوبیت + روابط
	var soft_ratio := soft / 100.0
	tourism["income"] = float(tourism.get("income", 1.0)) * (1.0 + (soft_ratio - 0.4) * 0.003)
	leader["popularity_world"] = clampf(float(leader.get("popularity_world", 50.0)) + (soft_ratio - 0.5) * 0.4, 0.0, 100.0)
	state["leader"] = leader
	state["tourism"] = tourism
	state["culture_policy"] = cul
	return {"state": state, "events": events}

# ── اقدامات بازیکن ──
func invest_heritage(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var cul: Dictionary = state["culture_policy"]
	if float(cul.get("heritage", 35.0)) >= 95.0:
		return {"success": false, "reason": "سرمایه میراثی حداکثری است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * 0.003
	state["economy"] = econ
	cul["heritage"] = clampf(float(cul.get("heritage", 35.0)) + 12.0, 0.0, 100.0)
	state["culture_policy"] = cul
	return {"success": true, "state": state,
		"events": [{"type": "heritage_invest", "message": "🏛️ مرمت بناهای تاریخی و سرمایه‌گذاری میراثی آغاز شد؛ قدرت نرم رو به رشد است"}]}

func host_event(state: Dictionary, kind: String, turn: int) -> Dictionary:
	state = ensure(state)
	if not ["festival", "sports", "film"].has(kind):
		return {"success": false, "reason": "نوع رویداد نامعتبر", "state": state, "events": []}
	var cul: Dictionary = state["culture_policy"]
	if turn - int(cul.get("last_event", 0)) < 12:
		return {"success": false, "reason": "رویدادهای جهانی هر ۱۲ نوبت یک بار ممکن‌اند", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	var cost := 0.006
	var boost := 8.0
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * cost
	cul["soft_power"] = clampf(float(cul.get("soft_power", 40.0)) + boost, 5.0, 100.0)
	cul["last_event"] = turn
	cul["events_hosted"] = int(cul.get("events_hosted", 0)) + 1
	state["culture_policy"] = cul
	state["economy"] = econ
	state["population"]["happiness"] = clampf(float(state["population"].get("happiness", 0.6)) + 0.02, 0.05, 1.0)
	state["tourism"]["income"] = float(state.get("tourism", {}).get("income", 1.0)) * 1.05
	var names := {"festival": "جشنواره فرهنگی بین‌المللی", "sports": "رویداد ورزشی بزرگ", "film": "جشنواره فیلم جهانی"}
	return {"success": true, "state": state,
		"events": [{"type": "host_event", "message": "🎉 «%s» میزبانی شد! گردشگری و قدرت نرم جهش کرد" % names[kind]}]}

func cultural_exchange(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var econ: Dictionary = state.get("economy", {})
	econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * 0.001
	state["economy"] = econ
	var cul: Dictionary = state["culture_policy"]
	cul["soft_power"] = clampf(float(cul.get("soft_power", 40.0)) + 3.0, 5.0, 100.0)
	state["culture_policy"] = cul
	state["diplomacy"]["influence"] = clampf(float(state["diplomacy"].get("influence", 40.0)) + 1.0, 0.0, 100.0)
	return {"success": true, "state": state,
		"events": [{"type": "cultural_exchange", "message": "🌐 برنامه تبادل فرهنگی و بورس دانشجویی آغاز شد؛ نفوذ نرم در جهان رشد کرد"}]}
