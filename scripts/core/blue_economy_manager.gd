extends Node
# ────────────────────────────────────────────────────────────────────────────
# اقتصاد دریایی (Blue Economy) — کشتیرانی، بنادر و شیلات
# سهم دریا فقط «ماهی» نیست؛ بنادر کانتینری، ناوگان تجاری، بنادر کانتینری،
# شیلات پایدار و اقتصاد بندری است. توسعه بندر به تجارت و لجستیک کمک می‌کند،
# صید بی‌رویه ذخایر را نابود می‌کند و گشت دریایی قاچاق/صید غیرمجاز را مهار می‌کند.
# پیوند: تجارت، کشاورزی/امنیت غذایی، انرژی، گردشگری، نیروی دریایی، اشتغال.
#
# state["blue_economy_policy"] = {
#   "port_capacity":0..1, "merchant_fleet":0..1, "sustainable_fisheries":0..1,
#   "coast_guard":0..1, "shipbuilding":0..1, "last_port":turn,
#   "last_fleet":turn, "last_patrol":turn, "blue_gdp":0 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("blue_economy_policy"):
		state["blue_economy_policy"] = {
			"port_capacity": 0.40, "merchant_fleet": 0.30,
			"sustainable_fisheries": 0.35, "coast_guard": 0.30,
			"shipbuilding": 0.20, "last_port": -99, "last_fleet": -99,
			"last_patrol": -99, "blue_gdp": 0.0, "container_throughput": 0.0
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var be: Dictionary = state["blue_economy_policy"]
	var econ: Dictionary = state.get("economy", {})
	var trade: Dictionary = state.get("trade", {})
	var fisheries: Dictionary = state.get("fisheries", {})
	var fuel: Dictionary = state.get("fuel_stations", {})
	var mil: Dictionary = state.get("military", {})
	var env: Dictionary = state.get("environment", {})
	var pop: Dictionary = state.get("population", {})
	var gdp := float(econ.get("gdp", 1.0))

	var port := float(be.get("port_capacity", 0.40))
	var fleet := float(be.get("merchant_fleet", 0.30))
	var sustainable := float(be.get("sustainable_fisheries", 0.35))
	var coast_guard := float(be.get("coast_guard", 0.30))
	var shipbuilding := float(be.get("shipbuilding", 0.20))

	# رشد اقتصاد دریایی: بندر + ناوگان + کشتی‌سازی
	var trade_ratio: float = float(trade.get("exports", 0.0)) / maxf(gdp, 1.0)
	var blue_share := 0.012 + port * 0.025 + fleet * 0.018 + shipbuilding * 0.012 + trade_ratio * 0.04
	var blue_gdp := gdp * blue_share
	be["blue_gdp"] = blue_gdp
	be["container_throughput"] = clampf(port * 0.7 + fleet * 0.3, 0.0, 1.0)

	# اثر بنادر/ناوگان بر صادرات از کانال پایدار می‌گذرد (بازرسی کلید یتیم ۱۴۰۵):
	# port_capacity/merchant_fleet در trade_system بخشی از «امتیاز لجستیک» هستند — ضربهٔ
	# مستقیم سطح (نویسندهٔ سرکشِ مالکیت یکتا) حذف شد. اثر بندر کروز بر گردشگری نیز از
	# کانال اتصال دریایی map_network → جذابیت مقصد جاری است.
	# ممیزی GDP (۱۴۰۵): «share×۰٫۱۲ ماهانه» نیز دوشماره‌ای سهم بود (≈ ۸٫۵٪/سال اضافی)؛
	# جایگزین: مشارکت رشد سالانه share×۰٫۱۵ از کانال مالک-یکتای sector_boosts (≈۰٫۹٪/سال).
	var be_boosts: Dictionary = econ.get("sector_boosts", {})
	be_boosts["اقتصاد آبی"] = blue_share * 0.15
	econ["sector_boosts"] = be_boosts
	econ["unemployment"] = clampf(float(econ.get("unemployment", 0.08)) - port * 0.0002 - shipbuilding * 0.0002, 0.02, 0.30)
	state["economy"] = econ

	# شیلات: پایداری ذخایر را نگه می‌دارد؛ بی‌توجهی صید را زیاد ولی ذخیره را می‌کاهد
	var stock_health := float(fisheries.get("stock_health", 0.65))
	var overfishing := 0.02 - sustainable * 0.025 - coast_guard * 0.010
	stock_health = clampf(stock_health - overfishing * 0.4, 0.10, 1.0)
	fisheries["stock_health"] = stock_health
	var catch_factor := clampf(stock_health * (0.7 + fleet * 0.5) - (1.0 - sustainable) * 0.10, 0.10, 1.5)
	fisheries["catch"] = float(fisheries.get("catch", 500000.0)) * 0.97 + 500000.0 * catch_factor * 0.03
	fisheries["sustainability"] = clampf(fisheries.get("sustainability", 0.60) * 0.99 + sustainable * 0.01, 0.05, 1.0)
	state["fisheries"] = fisheries
	# امنیت غذایی از شیلات
	state["resources"]["inventory"]["غذا"] = clampf(
		float(state["resources"]["inventory"].get("غذا", 85.0)) + catch_factor * 0.05, 0.0, 150.0)
	state["welfare"]["poverty"] = clampf(float(state.get("welfare", {}).get("poverty", 0.15)) - catch_factor * 0.0004, 0.02, 0.80)

	# گشت دریایی قاچاق سوخت را می‌کاهد و امنیت آبراه را بالا می‌برد
	fuel["smuggling"] = clampf(float(fuel.get("smuggling", 0.15)) - coast_guard * 0.002, 0.02, 0.60)
	state["fuel_stations"] = fuel
	mil["deterrence"] = clampf(float(mil.get("deterrence", 60.0)) + coast_guard * 0.5, 0.0, 100.0)
	state["military"] = mil

	# هزینه نگهداشت
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + gdp * (0.0008 + port * 0.0005 + coast_guard * 0.0008)
	state["economy"] = econ

	# رویدادها
	if stock_health < 0.25 and (turn - int(fisheries.get("last_collapse_warn", -99))) >= 6 and Deterministic.chance(0.050):
		fisheries["last_collapse_warn"] = turn
		events.append({"type": "fish_stock_collapse", "message": "🐟 ذخایر ماهی در آستانه فروپاشی! صید بی‌رویه معیشت ساحلی را تهدید می‌کند"})
		pop["happiness"] = clampf(float(pop.get("happiness", 0.60)) - 0.006, 0.05, 1.0)
	elif port > 0.70 and fleet > 0.50 and Deterministic.chance(0.030):
		var ri_port: Dictionary = state.get("economy", {}).get("reserve_inflows", {})
		ri_port["درآمد بندری"] = float(state.get("economy", {}).get("gdp", 500e9)) * 0.0005
		state["economy"]["reserve_inflows"] = ri_port
		var td_port: Dictionary = state.get("transport_detail", {})
		td_port["logistics_efficiency"] = clampf(float(td_port.get("logistics_efficiency", 0.60)) + 0.01, 0.0, 1.0)
		state["transport_detail"] = td_port
		events.append({"type": "port_hub", "message": "🚢 بندر کشور به هاب ترانزیت منطقه تبدیل شد؛ کانتینرها و کشتی‌های تجاری رونق آوردند"})
	elif coast_guard > 0.60 and Deterministic.chance(0.020):
		var sm_coast: Dictionary = state.get("shadow", {})
		sm_coast["size"] = clampf(float(sm_coast.get("size", 0.18)) - 0.01, 0.03, 0.55)
		state["shadow"] = sm_coast
		events.append({"type": "coast_patrol", "message": "🛡️ گشت دریایی شبکه قاچاق سوخت و صید غیرمجاز را متلاشی کرد"})

	state["blue_economy_policy"] = be
	state["population"] = pop
	state["environment"] = env
	return {"state": state, "events": events}

# ── توسعه ظرفیت بندر ──
func expand_port(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var be: Dictionary = state["blue_economy_policy"]
	if turn - int(be.get("last_port", -99)) < 8:
		return {"success": false, "reason": "توسعه بندر هر ۸ نوبت یک بار ممکن است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.009
	be["last_port"] = turn
	be["port_capacity"] = clampf(float(be.get("port_capacity", 0.40)) + 0.13, 0.0, 1.0)
	state["infrastructure"]["capacity"] = clampf(float(state["infrastructure"].get("capacity", 0.60)) + 0.01, 0.1, 1.0)
	state["economy"] = econ
	state["blue_economy_policy"] = be
	return {"success": true, "state": state,
		"events": [{"type": "port_expand", "message": "⚓ توسعه بندر و اسکله کانتینری به پایان رسید؛ لجستیک تجارت خارجی جهش کرد"}]}

# ── توسعه ناوگان تجاری و کشتیرانی ──
func expand_fleet(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var be: Dictionary = state["blue_economy_policy"]
	if turn - int(be.get("last_fleet", -99)) < 10:
		return {"success": false, "reason": "نوسازی ناوگان هر ۱۰ نوبت یک بار ممکن است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.007
	be["last_fleet"] = turn
	be["merchant_fleet"] = clampf(float(be.get("merchant_fleet", 0.30)) + 0.13, 0.0, 1.0)
	be["shipbuilding"] = clampf(float(be.get("shipbuilding", 0.20)) + 0.05, 0.0, 1.0)
	state["economy"] = econ
	state["blue_economy_policy"] = be
	return {"success": true, "state": state,
		"events": [{"type": "fleet_expand", "message": "🚢 کشتی‌های باری نو به ناوگان تجاری پیوست؛ وابستگی به حمل خارجی کمتر شد"}]}

# ── مدیریت پایدار شیلات ──
func sustainable_fisheries(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var be: Dictionary = state["blue_economy_policy"]
	if float(be.get("sustainable_fisheries", 0.35)) >= 0.95:
		return {"success": false, "reason": "مدیریت پایدار شیلات در سقف ممکن است", "state": state, "events": []}
	be["sustainable_fisheries"] = clampf(float(be.get("sustainable_fisheries", 0.35)) + 0.15, 0.0, 1.0)
	state["fisheries"]["sustainability"] = clampf(state["fisheries"].get("sustainability", 0.60) + 0.05, 0.05, 1.0)
	state["media"]["groups"]["روستاییان"]["approval"] = clampf(float(state["media"]["groups"].get("روستاییان", {}).get("approval", 52.0)) + 1.5, 5.0, 100.0)
	state["blue_economy_policy"] = be
	return {"success": true, "state": state,
		"events": [{"type": "sustainable_fishery", "message": "🐟 فصل‌های ممنوعیت صید، زیستگاه مصنوعی و نظارت بر ذخایر اجرا شد؛ شیلات بلندمدت حفظ شد"}]}

# ── گشت دریایی و حفاظت آبراه ──
func coast_guard_patrol(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var be: Dictionary = state["blue_economy_policy"]
	if turn - int(be.get("last_patrol", -99)) < 4:
		return {"success": false, "reason": "گشت فشرده دریایی هر ۴ نوبت یک بار ممکن است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.003
	be["last_patrol"] = turn
	be["coast_guard"] = clampf(float(be.get("coast_guard", 0.30)) + 0.12, 0.0, 1.0)
	state["fuel_stations"]["smuggling"] = clampf(float(state["fuel_stations"].get("smuggling", 0.15)) - 0.03, 0.02, 0.60)
	state["military"]["deterrence"] = clampf(float(state["military"].get("deterrence", 60.0)) + 0.5, 0.0, 100.0)
	state["economy"] = econ
	state["blue_economy_policy"] = be
	return {"success": true, "state": state,
		"events": [{"type": "coast_guard", "message": "🛥️ گشت دریایی تقویت شد؛ قاچاق سوخت و صید غیرمجاز در آب‌های سرزمینی مهار شد"}]}
