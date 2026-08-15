extends Node
# ────────────────────────────────────────────────────────────────────────────
# بازار مسکن و املاک — عمق دارایی خانوار
# عرضه و تقاضای مسکن، حباب قیمت، اجاره‌بها، بافت فرسوده، ساخت‌وساز و وام
# مسکن. این سامانه روی شهرسازی می‌نشیند و بر تورم، رفاه و مهاجرت اثر می‌گذارد.
# پیوند: شهرسازی، جمعیت، بانک، رفاه، اقتصاد.
#
# state["housing_policy"] = {
#   "social_supply":0..1, "mortgage_access":0..1, "renewal":0..1,
#   "property_tax":0..1, "construction":0..1,
#   "last_social":turn, "price_index":0..1, "bubble":0..1 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("housing_policy"):
		state["housing_policy"] = {
			"social_supply": 0.20, "mortgage_access": 0.35, "renewal": 0.15,
			"property_tax": 0.20, "construction": 0.40,
			"last_social": -99, "price_index": 0.50, "bubble": 0.25,
			"rent_burden": 0.35, "home_ownership": 0.60, "vacancy": 0.10
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var hp: Dictionary = state["housing_policy"]
	var econ: Dictionary = state.get("economy", {})
	var pop: Dictionary = state.get("population", {})
	var urban: Dictionary = state.get("urban_policy", {})
	var banking: Dictionary = state.get("banking", {})
	var welfare: Dictionary = state.get("welfare", {})

	var social := float(hp.get("social_supply", 0.20))
	var mortgage := float(hp.get("mortgage_access", 0.35))
	var renewal := float(hp.get("renewal", 0.15))
	var prop_tax := float(hp.get("property_tax", 0.20))
	var construction := float(hp.get("construction", 0.40))
	var urban_ratio := float(pop.get("urban_ratio", 0.75))

	# فشار تقاضا: شهرنشینی + وام مسکن آسان
	var demand := clampf(urban_ratio * 0.6 + mortgage * 0.30 + 0.20, 0.10, 1.20)
	# عرضه: مسکن اجتماعی + ساخت‌وساز + نوسازی
	var supply := clampf(social * 0.30 + construction * 0.50 + renewal * 0.20, 0.05, 1.10)

	# قیمت: تقاضا/عرضه؛ وام آسان حباب می‌سازد، مالیات بر عایدى حباب را می‌خشکاند
	var price := clampf(0.30 + demand * 0.40 - supply * 0.30, 0.10, 1.20)
	var bubble := clampf(
		hp.get("bubble", 0.25) * 0.90 + (mortgage - supply) * 0.05 - prop_tax * 0.02 + (price - 0.6) * 0.03,
		0.0, 1.0)
	hp["price_index"] = price
	hp["bubble"] = bubble

	# بار اجاره
	var rent_burden := clampf(0.20 + price * 0.40 - social * 0.20, 0.10, 0.85)
	hp["rent_burden"] = rent_burden
	# مالکیت: با وام و عرضه بالا، با قیمت پایین
	hp["home_ownership"] = clampf(0.45 + mortgage * 0.25 + social * 0.15 - price * 0.20, 0.20, 0.95)
	# خانه‌های خالی: با ساخت‌وساز سوداگرانه و تقاضای پایین
	hp["vacancy"] = clampf(0.05 + (supply - demand) * 0.15 + bubble * 0.10, 0.02, 0.50)

	# اثر اقتصادی: بخش مسکن بخشی از GDP؛ حباب خطر بانکی است
	var gdp := float(econ.get("gdp", 1.0))
	# ممیزی GDP (۱۴۰۵): اثر مداوم از کانال مالک-یکتای sector_boosts (نرخ سالانه؛ ماهانه: ×۱۲) (کمک قیمت می‌تواند منفی شود)
	var hs_boosts: Dictionary = econ.get("sector_boosts", {})
	hs_boosts["ساخت‌وساز و مسکن"] = (construction * 0.0003 + (price - 0.6) * 0.0001) * 12.0
	econ["sector_boosts"] = hs_boosts
	if bubble > 0.70:
		banking["stability"] = clampf(float(banking.get("stability", 0.65)) - 0.002, 0.05, 1.0)
		state["banking"] = banking
	# تورم از گرانی مسکن و اجاره
	econ["inflation"] = clampf(float(econ.get("inflation", 0.08)) + (price - 0.5) * 0.002 - prop_tax * 0.001, 0.0, 1.0)
	# فقر و رضایت
	welfare["poverty"] = clampf(float(welfare.get("poverty", 0.15)) + (rent_burden - 0.40) * 0.0008, 0.02, 0.80)
	state["welfare"] = welfare
	state["economy"] = econ

	# نوسازی بافت فرسوده به رضایت شهرنشین کمک می‌کند
	if renewal > 0.4 and state["media"]["groups"].has("شهرنشینان"):
		state["media"]["groups"]["شهرنشینان"]["approval"] = clampf(
			float(state["media"]["groups"]["شهرنشینان"].get("approval", 55.0)) + 0.1, 5.0, 100.0)

	# رویدادها
	if bubble > 0.75 and Deterministic.chance(0.05):
		econ["gdp"] = float(econ.get("gdp", gdp)) * 0.995
		# بازار سقوط‌کرده حبابش را تخلیه می‌کند؛ ترکیدن‌های ماهانه پیاپی غیرواقعی بود
		hp["bubble"] = 0.30
		bubble = 0.30
		state["economy"] = econ
		events.append({"type": "housing_bubble", "message": "🏚️ حباب مسکن ترکید! قیمت‌ها سقوط کرد و وام‌های معوق بانک‌ها بالا رفت"})
	elif rent_burden > 0.60 and Deterministic.chance(0.04):
		state["population"]["happiness"] = clampf(float(pop.get("happiness", 0.60)) - 0.008, 0.05, 1.0)
		events.append({"type": "rent_crisis", "message": "🏠 بحران اجاره‌بها؛ حاشیه‌نشینی و نارضایتی بالا گرفت"})
	elif supply > 0.7 and Deterministic.chance(0.025):
		var sb_hous: Dictionary = state.get("economy", {}).get("sector_boosts", {})
		sb_hous["ساخت‌وساز و مسکن"] = float(sb_hous.get("ساخت‌وساز و مسکن", 0.0)) + 0.0004 * 12.0
		state["economy"]["sector_boosts"] = sb_hous
		events.append({"type": "housing_boom", "message": "🏗️ رونق مسکن؛ اشتغال ساخت‌وساز و عرضه بالا رفت"})

	state["housing_policy"] = hp
	return {"state": state, "events": events}

# ── مسکن اجتماعی ──
func build_social_housing(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var hp: Dictionary = state["housing_policy"]
	if turn - int(hp.get("last_social", -99)) < 5:
		return {"success": false, "reason": "پروژه مسکن اجتماعی هر ۵ نوبت یک بار", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.005
	hp["last_social"] = turn
	hp["social_supply"] = clampf(float(hp.get("social_supply", 0.20)) + 0.13, 0.0, 1.0)
	state["economy"] = econ
	state["housing_policy"] = hp
	return {"success": true, "state": state,
		"events": [{"type": "social_housing", "message": "🏘️ واحدهای مسکن اجتماعی تحویل داده شد؛ بار اجاره کم شد"}]}

# ── وام مسکن ──
func mortgage_policy(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var hp: Dictionary = state["housing_policy"]
	if float(hp.get("mortgage_access", 0.35)) >= 0.95:
		return {"success": false, "reason": "دسترسی به وام مسکن در سقف است", "state": state, "events": []}
	hp["mortgage_access"] = clampf(float(hp.get("mortgage_access", 0.35)) + 0.15, 0.0, 1.0)
	state["housing_policy"] = hp
	return {"success": true, "state": state,
		"events": [{"type": "mortgage", "message": "🏦 تسهیلات وام مسکن گسترش یافت؛ تقاضا بالا رفت اما ریسک حباب افزایش یافت"}]}

# ── نوسازی بافت فرسوده ──
func urban_renewal(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var hp: Dictionary = state["housing_policy"]
	if float(hp.get("renewal", 0.15)) >= 0.95:
		return {"success": false, "reason": "نوسازی بافت فرسوده در سقف است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.004
	hp["renewal"] = clampf(float(hp.get("renewal", 0.15)) + 0.13, 0.0, 1.0)
	state["economy"] = econ
	state["housing_policy"] = hp
	return {"success": true, "state": state,
		"events": [{"type": "renewal", "message": "🏚️ نوسازی بافت فرسوده آغاز شد؛ ایمنی و کیفیت زندگی بالا رفت"}]}

# ── تنظیم بازار (مالیات بر عایدی سرمایه) ──
func regulate_market(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var hp: Dictionary = state["housing_policy"]
	hp["property_tax"] = clampf(float(hp.get("property_tax", 0.20)) + 0.15, 0.0, 1.0)
	hp["bubble"] = clampf(float(hp.get("bubble", 0.25)) - 0.08, 0.0, 1.0)
	state["housing_policy"] = hp
	return {"success": true, "state": state,
		"events": [{"type": "property_tax", "message": "📊 مالیات بر خانه‌های خالی و عایدی سرمایه اعمال شد؛ سوداگری کم شد"}]}
