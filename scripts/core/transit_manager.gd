extends Node
# ────────────────────────────────────────────────────────────────────────────
# لجستیک و ترانزیت بین‌المللی — عمق کریدورها
# راهگذرهای ترانزیتی، توافق گمرکی، ناوگان ریلی/جاده‌ای و منطقه آزاد.
# ترانزیت منبع درآمد ارزی پایدار است و موقعیت ژئوپلیتیک کشور را تقویت می‌کند.
# پیوند: تجارت، اقتصاد دریایی، زیرساخت، دیپلماسی، انرژی.
#
# state["transit_policy"] = {
#   "corridors":0..1, "customs":0..1, "rail":0..1,
#   "free_zones":0..1, "last_corridor":turn,
#   "transit_share":0..1, "freight":0..1 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("transit_policy"):
		state["transit_policy"] = {
			"corridors": 0.25, "customs": 0.30, "rail": 0.25,
			"free_zones": 0.20, "last_corridor": -99,
			"transit_share": 0.15, "freight": 0.30,
			"revenue": 0.0, "border_delay": 0.50
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var tp: Dictionary = state["transit_policy"]
	var econ: Dictionary = state.get("economy", {})
	var infra: Dictionary = state.get("infrastructure", {})
	var dip: Dictionary = state.get("diplomacy", {})

	var corridors: float = float(tp.get("corridors", 0.25))
	var customs: float = float(tp.get("customs", 0.30))
	var rail: float = float(tp.get("rail", 0.25))
	var free_zones: float = float(tp.get("free_zones", 0.20))

	# شاخص بار (lumped freight)
	var freight: float = clampf(
		0.15 + corridors * 0.30 + customs * 0.20 + rail * 0.25 + free_zones * 0.15,
		0.05, 0.98)
	tp["freight"] = freight

	# تأخیر مرزی: با گمرک هوشمند کم می‌شود
	var border_delay: float = clampf(0.80 - customs * 0.50 - rail * 0.20, 0.05, 0.95)
	tp["border_delay"] = border_delay

	# سهم ترانزیت منطقه
	var soft: float = float(dip.get("soft_power", 35.0)) / 100.0
	var transit_share: float = clampf(
		0.05 + corridors * 0.35 + freight * 0.20 + soft * 0.20 + free_zones * 0.10,
		0.02, 0.90)
	tp["transit_share"] = transit_share

	# درآمد ترانزیت — بازرسی کلید یتیم ۱۴۰۵: سابقاً ۳۰٪ مستقیم و بی‌بازخوان به ذخایر
	# ارزی می‌رفت و ۷۰٪ باقی‌مانده رها می‌شد (چرخهٔ بودجه شکسته). ضریب هم به مقیاس
	# واقع‌گرایانه اصلاح شد: عوارض ترانزیت کشورهای هاب ~۰٫۲٪ GDP است نه ~۱٫۸٪.
	# کانال استاندارد: نرخ ماهانه که economy_system در درآمد دولت مصرف می‌کند.
	var gdp: float = float(econ.get("gdp", 1.0))
	var revenue: float = gdp * transit_share * 0.0015
	tp["revenue"] = revenue
	econ["transit_revenue_monthly"] = revenue
	state["economy"] = econ
	# اثر لجستیک بر صادرات دیگر این‌جا اعمال نمی‌شود: مالکیت یکتای سطح
	# exports/imports/balance با trade_system است و freight از کانال سهم هدف اثر می‌گذارد.

	# زیرساخت کلی
	if infra.has("capacity"):
		infra["capacity"] = clampf(float(infra.get("capacity", 0.60)) + corridors * 0.001, 0.1, 1.0)
		state["infrastructure"] = infra

	# رویدادها
	if transit_share > 0.55 and Deterministic.chance(0.03):
		events.append({"type": "transit_hub", "message": "🚛 کریدور ترانزیتی به هاب منطقه تبدیل شد؛ درآمد ارزی بالا رفت"})
	elif border_delay > 0.65 and Deterministic.chance(0.04):
		events.append({"type": "border_queue", "message": "🛂 صف‌های طولانی مرزی، ترانزیت را فراری داد"})
	elif free_zones > 0.55 and Deterministic.chance(0.02):
		events.append({"type": "free_zone", "message": "🏗️ منطقه آزاد تجاری سرمایه‌گذاران خارجی را جذب کرد"})

	state["transit_policy"] = tp
	return {"state": state, "events": events}

func expand_corridor(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var tp: Dictionary = state["transit_policy"]
	if turn - int(tp.get("last_corridor", -99)) < 6:
		return {"success": false, "reason": "پروژه کریدور هر ۶ نوبت یک بار", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.006
	tp["last_corridor"] = turn
	tp["corridors"] = clampf(float(tp.get("corridors", 0.25)) + 0.15, 0.0, 1.0)
	state["economy"] = econ
	state["transit_policy"] = tp
	return {"success": true, "state": state,
		"events": [{"type": "corridor", "message": "🛣️ کریدور ترانزیتی جدید توسعه یافت"}]}

func customs_reform(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var tp: Dictionary = state["transit_policy"]
	var tech: float = float(state.get("technology", {}).get("branch_levels", {}).get("دیجیتال", 0))
	if tech < 4:
		return {"success": false, "reason": "به فناوری دیجیتال سطح ۴ نیاز است", "state": state, "events": []}
	tp["customs"] = clampf(float(tp.get("customs", 0.30)) + 0.15, 0.0, 1.0)
	state["transit_policy"] = tp
	return {"success": true, "state": state,
		"events": [{"type": "customs", "message": "🛃 گمرک هوشمند و پنجره واحد تجاری راه‌اندازی شد"}]}

func rail_freight(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var tp: Dictionary = state["transit_policy"]
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.005
	tp["rail"] = clampf(float(tp.get("rail", 0.25)) + 0.15, 0.0, 1.0)
	state["economy"] = econ
	state["transit_policy"] = tp
	return {"success": true, "state": state,
		"events": [{"type": "rail", "message": "🚂 شبکه ریلی باری و اتصال به همسایگان توسعه یافت"}]}

func free_zone(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var tp: Dictionary = state["transit_policy"]
	tp["free_zones"] = clampf(float(tp.get("free_zones", 0.20)) + 0.15, 0.0, 1.0)
	state["transit_policy"] = tp
	return {"success": true, "state": state,
		"events": [{"type": "freezone", "message": "🏭 منطقه آزاد تجاری-صنعتی گسترش یافت"}]}
