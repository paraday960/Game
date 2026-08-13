extends Node
# ────────────────────────────────────────────────────────────────────────────
# بازار مصرف و خرده‌فروشی — عمق قدرت خرید و تنظیم بازار
# سطح قیمت‌ها، رقابت و تجارت الکترونیک سبد مصرفی خانوار را می‌سازند؛
# اعتماد مصرف‌کننده موتور رشد است. دولت می‌تواند قیمت کالاهای اساسی را
# تنظیم کند، از مصرف‌کننده حمایت کند، تجارت الکترونیک را توسعه دهد یا
# بازارهای سنتی را نوسازی کند. پیوند: اقتصاد، فناوری دیجیتال، گردشگری، رسانه.
#
# state["retail_policy"] = { "price_control":bool, "consumer_protection":0..1,
#   "confidence":0..1, "online_boost":0, "last_bazaar":turn }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("retail_policy"):
		state["retail_policy"] = {"price_control": false, "consumer_protection": 0.4, "confidence": 0.6, "online_boost": 0, "last_bazaar": -99}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var retail: Dictionary = state.get("retail", {})
	var rp: Dictionary = state["retail_policy"]
	var econ: Dictionary = state.get("economy", {})
	var pol: Dictionary = state.get("politics", {})

	var price_level := float(retail.get("price_level", 1.0))
	var inflation := float(econ.get("inflation", 0.08))
	var competition := float(retail.get("competition", 0.6))
	var unemployment := float(econ.get("unemployment", 0.08))
	var happiness := float(state.get("population", {}).get("happiness", 0.6))
	var price_control: bool = bool(rp.get("price_control", false))

	# اعتماد مصرف‌کننده
	var confidence := clampf(0.55 - (price_level - 1.0) * 0.3 - inflation * 0.4 - unemployment * 0.5 + happiness * 0.35 + competition * 0.15, 0.05, 1.0)
	rp["confidence"] = confidence

	# تنظیم قیمت: قیمت پایین‌تر ولی رقابت آسیب می‌بیند و بازار سیاه می‌روید
	if price_control:
		price_level = clampf(price_level * 0.985 + 0.005, 0.7, 1.8)
		competition = clampf(competition - 0.004, 0.1, 0.9)
		state["shadow"]["size"] = clampf(float(state["shadow"].get("size", 0.18)) + 0.002, 0.02, 0.6)
	else:
		price_level = clampf(price_level + inflation * 0.02 - competition * 0.002, 0.7, 1.8)

	# حمایت از مصرف‌کننده: جلوگیری از گران‌فروشی
	var protection := float(rp.get("consumer_protection", 0.4))
	if protection > 0.5:
		price_level = clampf(price_level * 0.995, 0.7, 1.8)
		state["media"]["trust"] = clampf(float(state["media"].get("trust", 0.55)) + 0.002, 0.05, 1.0)

	# اعتراض قیمتی
	if price_level > 1.35 and Deterministic.chance(0.05):
		pol["stability"] = clampf(float(pol.get("stability", 0.6)) - 0.012, 0.05, 1.0)
		state["population"]["happiness"] = clampf(float(state["population"].get("happiness", 0.6)) - 0.005, 0.05, 1.0)
		events.append({"type": "price_protests", "message": "🔥 اعتراض به گرانی کالاهای اساسی! بازارها ملتهب شدند"})
	elif confidence > 0.75 and Deterministic.chance(0.04):
		econ["gdp"] = float(econ.get("gdp", 1.0)) * 1.002
		events.append({"type": "consumer_boom", "message": "🛍️ رونق مصرف! اعتماد خانوار بالا رفت و فروشگاه‌ها شلوغ شدند"})

	retail["price_level"] = price_level
	retail["competition"] = competition
	state["retail"] = retail
	state["retail_policy"] = rp
	state["economy"] = econ
	state["politics"] = pol
	return {"state": state, "events": events}

# ── روشن/خاموش کردن تنظیم قیمت کالاهای اساسی ──
func toggle_price_control(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var rp: Dictionary = state["retail_policy"]
	var new_val := not bool(rp.get("price_control", false))
	rp["price_control"] = new_val
	state["retail_policy"] = rp
	if new_val:
		return {"success": true, "state": state,
			"events": [{"type": "price_control_on", "message": "🏷️ قیمت کالاهای اساسی تثبیت شد؛ مردم ارزان‌تر خرید می‌کنند ولی بازار سیاه می‌بالد"}]}
	return {"success": true, "state": state,
		"events": [{"type": "price_control_off", "message": "📉 قیمت‌گذاری دستوری لغو شد؛ بازار آزاد شد و رقابت برگشت"}]}

# ── تقویت سازمان حمایت از مصرف‌کننده ──
func consumer_protection(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var rp: Dictionary = state["retail_policy"]
	if float(rp.get("consumer_protection", 0.4)) >= 0.98:
		return {"success": false, "reason": "حمایت از مصرف‌کننده حداکثری است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.002
	rp["consumer_protection"] = clampf(float(rp.get("consumer_protection", 0.4)) + 0.3, 0.0, 1.0)
	state["politics"]["corruption"] = clampf(float(state["politics"].get("corruption", 0.3)) - 0.008, 0.01, 1.0)
	state["retail_policy"] = rp
	state["economy"] = econ
	return {"success": true, "state": state,
		"events": [{"type": "consumer_guard", "message": "🛡️ سازمان حمایت از مصرف‌کننده تقویت شد؛ گران‌فروشی و تقلب کاهش یافت"}]}

# ── توسعه تجارت الکترونیک ──
func boost_ecommerce(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var rp: Dictionary = state["retail_policy"]
	var digital_level: int = int(state.get("technology", {}).get("branch_levels", {}).get("دیجیتال", 0))
	if digital_level < 6:
		return {"success": false, "reason": "زیرساخت دیجیتال کافی نیست (شاخه دیجیتال حداقل سطح ۶)", "state": state, "events": []}
	var retail: Dictionary = state.get("retail", {})
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.004
	rp["online_boost"] = int(rp.get("online_boost", 0)) + 1
	retail["e_commerce_share"] = clampf(float(retail.get("e_commerce_share", 0.15)) + 0.05, 0.02, 0.60)
	econ["unemployment"] = clampf(float(econ.get("unemployment", 0.08)) - 0.0005, 0.02, 0.30)
	state["retail"] = retail
	state["retail_policy"] = rp
	state["economy"] = econ
	return {"success": true, "state": state,
		"events": [{"type": "ecommerce", "message": "🛒 سکوی ملی تجارت الکترونیک توسعه یافت؛ خرید آنلاین و اشتغال دیجیتال رشد کرد"}]}

# ── نوسازی بازارهای سنتی ──
func renovate_bazaars(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var rp: Dictionary = state["retail_policy"]
	if turn - int(rp.get("last_bazaar", -99)) < 10:
		return {"success": false, "reason": "نوسازی بازارهای سنتی هر ۱۰ نوبت یک بار ممکن است", "state": state, "events": []}
	var retail: Dictionary = state.get("retail", {})
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.006
	rp["last_bazaar"] = turn
	retail["bazaars"] = int(retail.get("bazaars", 5000)) + 200
	retail["competition"] = clampf(float(retail.get("competition", 0.6)) + 0.03, 0.1, 0.9)
	state["tourism"]["revenue"] = float(state["tourism"].get("revenue", 0.0)) * 1.02
	state["culture_policy"]["soft_power"] = clampf(float(state["culture_policy"].get("soft_power", 40.0)) + 1.0, 5.0, 100.0)
	state["retail"] = retail
	state["retail_policy"] = rp
	state["economy"] = econ
	return {"success": true, "state": state,
		"events": [{"type": "bazaar", "message": "🏪 بازارهای سنتی نوسازی شد؛ گردشگران به کوچه‌های تاریخی هجوم آوردند"}]}
