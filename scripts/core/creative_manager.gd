extends Node
# ────────────────────────────────────────────────────────────────────────────
# اقتصاد خلاق و صنایع فرهنگی — عمق تولید نرم
# سینما، موسیقی، بازی‌سازی، پویانمایی، نشر و صنایع دستی نه‌تنها درآمد و اشتغال
# می‌سازند بلکه قدرت نرم، گردشگری و هویت ملی را تقویت می‌کنند. بازیکن با
# تامین‌مالی، حمایت از پلتفرم، آموزش و صادرات فرهنگی این اکوسیستم را می‌سازد.
# پیوند: فرهنگ، گردشگری، آموزش، دیجیتال، رسانه، اقتصاد، دیاسپورا.
#
# state["creative_policy"] = {
#   "funding":0..1, "education":0..1, "platform":0..1, "export":0..1,
#   "cinema":0..1, "music":0..1, "games":0..1, "crafts":0..1,
#   "last_festival":turn, "creative_gdp":0, "jobs":0 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("creative_policy"):
		state["creative_policy"] = {
			"funding": 0.25, "education": 0.25, "platform": 0.15, "export": 0.15,
			"cinema": 0.35, "music": 0.40, "games": 0.15, "crafts": 0.45,
			"last_festival": -99, "creative_gdp": 0.0, "jobs": 0,
			"creative_index": 0.30, "piracy": 0.45
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var cp: Dictionary = state["creative_policy"]
	var econ: Dictionary = state.get("economy", {})
	var edu: Dictionary = state.get("education", {})
	var media: Dictionary = state.get("media", {})
	var tourism: Dictionary = state.get("tourism", {})
	var digital: Dictionary = state.get("digital_policy", {})
	var culture: Dictionary = state.get("culture_policy", {})
	var pop: Dictionary = state.get("population", {})
	var gdp := float(econ.get("gdp", 1.0))

	var funding := float(cp.get("funding", 0.25))
	var education := float(cp.get("education", 0.25))
	var platform := float(cp.get("platform", 0.15))
	var export_share := float(cp.get("export", 0.15))
	var digital_cov := float(digital.get("internet_coverage", 0.5))
	var literacy := float(edu.get("quality", 0.55))

	# شاخص خلاقیت: آموزش + بودجه + پلتفرم دیجیتال + صادرات
	var index := clampf(
		0.10 + funding * 0.22 + education * 0.22 + platform * 0.18 +
		export_share * 0.16 + digital_cov * 0.12 + literacy * 0.10,
		0.05, 0.98)
	cp["creative_index"] = index

	# هر رشته بر اساس سرمایه‌گذاری و شاخص رشد می‌کند
	cp["cinema"] = clampf(float(cp.get("cinema", 0.35)) * 0.995 + index * 0.005 + funding * 0.001, 0.05, 1.0)
	cp["music"] = clampf(float(cp.get("music", 0.40)) * 0.996 + index * 0.004 + platform * 0.001, 0.05, 1.0)
	cp["games"] = clampf(float(cp.get("games", 0.15)) * 0.99 + (index + digital_cov) * 0.008, 0.02, 1.0)
	cp["crafts"] = clampf(float(cp.get("crafts", 0.45)) * 0.998 + index * 0.002, 0.10, 1.0)

	# اندازه اقتصاد خلاق و اشتغال
	var creative_share := 0.008 + index * 0.035 + export_share * 0.015 + float(cp.get("games", 0.0)) * 0.008
	var creative_gdp := gdp * creative_share
	cp["creative_gdp"] = creative_gdp
	cp["jobs"] = int(250000.0 + index * 1_500_000.0 + float(cp.get("crafts", 0.0)) * 400000.0)
	# ممیزی GDP (۱۴۰۵): «share×۰٫۲۵ ماهانه» سهمِ بخش را به‌اشتباه رشدِ ماهانهٔ کل می‌ساخت
	# (دوشماره‌ای ≈ ۱۲٫۷٪/سال اضافی!). سهم‌دهی واقع‌بینانه از کانال مالک-یکتای sector_boosts:
	# سهم بخش × رشد ممتاز سالانهٔ ~۱۵٪ → مشارکت ≈ share×۰٫۱۵ در سال (≈۰٫۶٪).
	var cr_boosts: Dictionary = econ.get("sector_boosts", {})
	cr_boosts["اقتصاد خلاق"] = creative_share * 0.15
	econ["sector_boosts"] = cr_boosts
	econ["unemployment"] = clampf(float(econ.get("unemployment", 0.08)) - index * 0.0003, 0.02, 0.30)
	state["economy"] = econ

	# دزدی دریایی/کپی‌رایت: پلتفرم رسمی و قانون کپی‌رایت آن را می‌کاهد
	var piracy := clampf(0.55 - platform * 0.25 - export_share * 0.10 + float(cp.get("piracy", 0.45)) * 0.0, 0.10, 0.85)
	cp["piracy"] = piracy

	# قدرت نرم و گردشگری فرهنگی
	culture["soft_power"] = clampf(float(culture.get("soft_power", 40.0)) + index * 0.08, 5.0, 100.0)
	state["culture_policy"] = culture
	tourism["revenue"] = float(tourism.get("revenue", 0.0)) * (1.0 + index * 0.0005)
	state["tourism"] = tourism
	media["trust"] = clampf(float(media.get("trust", 0.55)) + funding * 0.001, 0.05, 1.0)
	state["media"] = media
	# رضایت جوانان از فرصت فرهنگی/هنری
	state["media"]["groups"]["جوانان"]["approval"] = clampf(
		float(state["media"]["groups"]["جوانان"].get("approval", 45.0)) + index * 0.15, 5.0, 100.0)
	pop["happiness"] = clampf(float(pop.get("happiness", 0.60)) + index * 0.001, 0.05, 1.0)
	state["population"] = pop

	# هزینه حمایت
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + gdp * (0.001 + funding * 0.0015)
	state["economy"] = econ

	# رویدادها
	if index > 0.70 and Deterministic.chance(0.035):
		econ["foreign_reserves"] = float(econ.get("foreign_reserves", 0.0)) + creative_gdp * 0.05
		state["economy"] = econ
		events.append({"type": "creative_export", "message": "🎬 محصول فرهنگی ایران در جشنواره‌های جهان درخشید؛ صادرات فرهنگی و قدرت نرم بالا رفت"})
	elif float(cp.get("games", 0.0)) > 0.55 and Deterministic.chance(0.030):
		events.append({"type": "games_boom", "message": "🎮 استودیوهای بازی‌سازی داخلی بازار منطقه را فتح کردند؛ اشتغال جوانان رشد کرد"})
	elif piracy > 0.70 and Deterministic.chance(0.025):
		events.append({"type": "piracy", "message": "🏴 دزدی دریایی محصولات فرهنگی هنرمندان را به ورشکستگی کشاند؛ پلتفرم رسمی لازم است"})

	state["creative_policy"] = cp
	return {"state": state, "events": events}

# ── صندوق حمایت از تولید فرهنگی ──
func increase_funding(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var cp: Dictionary = state["creative_policy"]
	if float(cp.get("funding", 0.25)) >= 0.95:
		return {"success": false, "reason": "بودجه صندوق فرهنگی در سقف است", "state": state, "events": []}
	cp["funding"] = clampf(float(cp.get("funding", 0.25)) + 0.15, 0.0, 1.0)
	state["creative_policy"] = cp
	return {"success": true, "state": state,
		"events": [{"type": "creative_fund", "message": "💰 صندوق حمایت از تولید فرهنگی تقویت شد؛ پروژه‌های سینما، موسیقی و بازی جان گرفتند"}]}

# ── آموزش هنر/خلاقیت در مدارس و دانشگاه‌ها ──
func creative_education(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var cp: Dictionary = state["creative_policy"]
	if float(cp.get("education", 0.25)) >= 0.95:
		return {"success": false, "reason": "آموزش فرهنگی در سقف است", "state": state, "events": []}
	cp["education"] = clampf(float(cp.get("education", 0.25)) + 0.15, 0.0, 1.0)
	state["education"]["quality"] = clampf(state["education"].get("quality", 0.55) + 0.01, 0.1, 1.0)
	state["creative_policy"] = cp
	return {"success": true, "state": state,
		"events": [{"type": "creative_edu", "message": "🎓 رشته‌های هنری، انیمیشن و بازی‌سازی تقویت شدند؛ نسل جدید خالق تربیت شد"}]}

# ── پلتفرم پخش/توزیع دیجیتال بومی و قانون کپی‌رایت ──
func build_platform(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var cp: Dictionary = state["creative_policy"]
	if float(cp.get("platform", 0.15)) >= 0.95:
		return {"success": false, "reason": "پلتفرم توزیع فرهنگی در سقف است", "state": state, "events": []}
	var digital := float(state.get("technology", {}).get("branch_levels", {}).get("دیجیتال", 0))
	if digital < 8:
		return {"success": false, "reason": "به فناوری دیجیتال سطح ۸ نیاز است", "state": state, "events": []}
	cp["platform"] = clampf(float(cp.get("platform", 0.15)) + 0.15, 0.0, 1.0)
	cp["piracy"] = clampf(float(cp.get("piracy", 0.45)) - 0.08, 0.10, 0.85)
	state["creative_policy"] = cp
	return {"success": true, "state": state,
		"events": [{"type": "creative_platform", "message": "📱 سکوی بومی پخش فیلم، موسیقی و بازی راه افتاد؛ کپی‌رایت تقویت و دزدی دریایی کم شد"}]}

# ── جشنواره/هفته فرهنگی و صادرات ──
func cultural_export(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var cp: Dictionary = state["creative_policy"]
	if turn - int(cp.get("last_festival", -99)) < 6:
		return {"success": false, "reason": "جشنواره فرهنگی هر ۶ نوبت یک بار ممکن است", "state": state, "events": []}
	cp["last_festival"] = turn
	cp["export"] = clampf(float(cp.get("export", 0.15)) + 0.13, 0.0, 1.0)
	state["culture_policy"]["soft_power"] = clampf(state.get("culture_policy", {}).get("soft_power", 40.0) + 2.0, 5.0, 100.0)
	state["economy"]["foreign_reserves"] = state["economy"].get("foreign_reserves", 0.0) + state["economy"].get("gdp", 1.0) * 0.001
	state["creative_policy"] = cp
	return {"success": true, "state": state,
		"events": [{"type": "cultural_export", "message": "🌍 جشنواره فرهنگی بین‌المللی برپا شد؛ صنایع خلاق به بازارهای خارجی راه یافتند"}]}
