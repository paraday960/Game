extends Node
# ────────────────────────────────────────────────────────────────────────────
# ورزش و سلامت عمومی — عمق سلامت جسمی و پرستیژ ورزشی
# ورزش همگانی (سلامت/بهره‌وری)، لیگ حرفه‌ای (جوانان/پرستیژ)، میزبانی رویداد
# ورزشی (مثل رویداد فرهنگی ولی ورزشی)، ضد دوپینگ (تصویر). پیوند: جوانان،
# فرهنگ، گردشگری، بهداشت.
#
# state["sports_policy"] = { "grassroots":0..1, "pro_league":0..1,
#   "anti_doping":0..1, "hosted":0, "fitness":0..1 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("sports_policy"):
		state["sports_policy"] = {"grassroots": 0.3, "pro_league": 0.4, "anti_doping": 0.5, "hosted": 0, "fitness": 0.4}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var sp: Dictionary = state["sports_policy"]
	var econ: Dictionary = state.get("economy", {})
	var grassroots := float(sp.get("grassroots", 0.3))
	var pro_league := float(sp.get("pro_league", 0.4))
	var anti_doping := float(sp.get("anti_doping", 0.5))

	# ورزش همگانی → سلامت و بهره‌وری
	state["health"]["quality"] = clampf(float(state["health"].get("quality", 0.6)) + grassroots * 0.001, 0.1, 1.0)
	state["health"]["fitness"] = clampf(float(state["health"].get("fitness", 0.5)) + grassroots * 0.002, 0.1, 1.0)
	# ممیزی GDP (۱۴۰۵): اثر مداوم از کانال مالک-یکتای sector_boosts (نرخ سالانه؛ ماهانه: ×۱۲)
	var sp_boosts: Dictionary = econ.get("sector_boosts", {})
	sp_boosts["اقتصاد ورزش"] = grassroots * 0.0005 * 12.0
	econ["sector_boosts"] = sp_boosts
	# لیگ حرفه‌ای → جوانان و قدرت نرم
	state["media"]["groups"]["جوانان"]["approval"] = clampf(float(state["media"]["groups"]["جوانان"].get("approval", 45.0)) + pro_league * 0.4, 5.0, 100.0)
	state["culture_policy"]["soft_power"] = clampf(float(state["culture_policy"].get("soft_power", 40.0)) + pro_league * 0.1, 5.0, 100.0)
	# ضد دوپینگ → تصویر جهانی
	if anti_doping > 0.7:
		state["culture_policy"]["soft_power"] = clampf(float(state["culture_policy"].get("soft_power", 40.0)) + 0.1, 5.0, 100.0)
	# رویداد: موفقیت بین‌المللی
	if pro_league > 0.6 and Deterministic.chance(0.05):
		state["media"]["groups"]["جوانان"]["approval"] = clampf(float(state["media"]["groups"]["جوانان"].get("approval", 45.0)) + 2.0, 5.0, 100.0)
		state["leader"]["popularity_world"] = clampf(float(state["leader"].get("popularity_world", 50.0)) + 1.0, 0.0, 100.0)
		events.append({"type": "sports_glory", "message": "🏆 قهرمانی بین‌المللی! کشور در جهان درخشید و جوانان به وجد آمدند"})
	# رسوایی دوپینگ اگر ضد دوپینگ ضعیف
	if anti_doping < 0.3 and Deterministic.chance(0.04):
		state["culture_policy"]["soft_power"] = clampf(float(state["culture_policy"].get("soft_power", 40.0)) - 2.0, 5.0, 100.0)
		events.append({"type": "doping_scandal", "message": "🚨 رسوایی دوپینگ ملی! تصویر ورزشی کشور لکه‌دار شد"})
	state["sports_policy"] = sp
	state["economy"] = econ
	return {"state": state, "events": events}

func grassroots_sports(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["sports_policy"]
	if float(sp.get("grassroots", 0.3)) >= 0.95:
		return {"success": false, "reason": "ورزش همگانی حداکثری است", "state": state, "events": []}
	state["economy"]["national_debt"] = float(state["economy"].get("national_debt", 0.0)) + float(state["economy"].get("gdp", 1.0)) * 0.002
	sp["grassroots"] = clampf(float(sp.get("grassroots", 0.3)) + 0.2, 0.0, 1.0)
	state["sports_policy"] = sp
	return {"success": true, "state": state,
		"events": [{"type": "grassroots", "message": "🏃 طرح ورزش همگانی: پارک‌های ورزشی و مدارس فعال؛ ملت سالم‌تر و شادتر"}]}

func pro_league_invest(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["sports_policy"]
	if float(sp.get("pro_league", 0.4)) >= 0.95:
		return {"success": false, "reason": "لیگ حرفه‌ای حداکثری است", "state": state, "events": []}
	state["economy"]["national_debt"] = float(state["economy"].get("national_debt", 0.0)) + float(state["economy"].get("gdp", 1.0)) * 0.003
	sp["pro_league"] = clampf(float(sp.get("pro_league", 0.4)) + 0.15, 0.0, 1.0)
	state["sports_policy"] = sp
	# اشتغال ورزشی
	state["economy"]["unemployment"] = clampf(float(state["economy"].get("unemployment", 0.08)) - 0.001, 0.02, 0.30)
	return {"success": true, "state": state,
		"events": [{"type": "pro_league", "message": "⚽ لیگ حرفه‌ای توسعه یافت؛ استعدادهای جوان به باشگاه‌ها پیوستند"}]}

func anti_doping(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["sports_policy"]
	if float(sp.get("anti_doping", 0.5)) >= 0.98:
		return {"success": false, "reason": "برنامه ضد دوپینگ کامل است", "state": state, "events": []}
	state["economy"]["national_debt"] = float(state["economy"].get("national_debt", 0.0)) + float(state["economy"].get("gdp", 1.0)) * 0.001
	sp["anti_doping"] = clampf(float(sp.get("anti_doping", 0.5)) + 0.2, 0.0, 1.0)
	state["sports_policy"] = sp
	return {"success": true, "state": state,
		"events": [{"type": "anti_doping", "message": "🧪 آزمایشگاه ضد دوپینگ بین‌المللی تأسیس شد؛ ورزش کشور پاک و معتبر"}]}

func host_major_event(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["sports_policy"]
	if turn - int(sp.get("last_hosted", 0)) < 18:
		return {"success": false, "reason": "رویدادهای بزرگ ورزشی هر ۱۸ نوبت یک بار ممکن‌اند", "state": state, "events": []}
	state["economy"]["national_debt"] = float(state["economy"].get("national_debt", 0.0)) + float(state["economy"].get("gdp", 1.0)) * 0.008
	sp["last_hosted"] = turn
	sp["hosted"] = int(sp.get("hosted", 0)) + 1
	state["sports_policy"] = sp
	# گردشگری + قدرت نرم + زیرساخت
	state["tourism"]["revenue"] = float(state["tourism"].get("revenue", 0.0)) * 1.05
	state["culture_policy"]["soft_power"] = clampf(float(state["culture_policy"].get("soft_power", 40.0)) + 5.0, 5.0, 100.0)
	state["infrastructure"]["roads_quality"] = clampf(float(state["infrastructure"].get("roads_quality", 0.6)) + 0.02, 0.1, 1.0)
	state["media"]["groups"]["جوانان"]["approval"] = clampf(float(state["media"]["groups"]["جوانان"].get("approval", 45.0)) + 3.0, 5.0, 100.0)
	return {"success": true, "state": state,
		"events": [{"type": "host_major_event", "message": "🏟️ میزبانی رویداد بزرگ ورزشی! جهان به کشور آمد؛ گردشگری و پرستیژ جهش کرد"}]}
