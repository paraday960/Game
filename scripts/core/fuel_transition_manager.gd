extends Node
# ────────────────────────────────────────────────────────────────────────────
# سوخت و گذار انرژی در حمل‌ونقل — عمق یارانه و الکتریسیته
# سهمیه سوخت، ایستگاه شارژ برقی، استاندارد آلایندگی خودرو و گذار به خودروی
# برقی. حذف یارانه سوخت درآمد می‌سازد و قاچاق را می‌خشکاند اما تورم و
# اعتراض می‌آورد. ناوگان برقی آلودگی و مصرف سوخت را کم می‌کند.
# پیوند: انرژی، اقلیم، شهرسازی، رفاه، امنیت، حمل‌ونقل.
#
# state["fuel_policy"] = {
#   "subsidy":0..1, "ev_charging":0..1, "emission_standard":0..1,
#   "public_fleet":0..1, "last_reform":turn, "smuggling":0..1,
#   "fuel_demand":0..1, "ev_share":0..1 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("fuel_policy"):
		state["fuel_policy"] = {
			"subsidy": 0.65, "ev_charging": 0.10, "emission_standard": 0.25,
			"public_fleet": 0.20, "last_reform": -99, "smuggling": 0.30,
			"fuel_demand": 0.70, "ev_share": 0.02, "fuel_revenue": 0.0
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var fp: Dictionary = state["fuel_policy"]
	var econ: Dictionary = state.get("economy", {})
	var env: Dictionary = state.get("environment", {})
	var urban: Dictionary = state.get("urban_policy", {})
	var welfare: Dictionary = state.get("welfare", {})
	var blue: Dictionary = state.get("blue_economy_policy", {})
	var fuel_stations: Dictionary = state.get("fuel_stations", {})

	var subsidy := float(fp.get("subsidy", 0.65))
	var ev_charging := float(fp.get("ev_charging", 0.10))
	var emission := float(fp.get("emission_standard", 0.25))
	var public_fleet := float(fp.get("public_fleet", 0.20))
	var gdp := float(econ.get("gdp", 1.0))

	# تقاضای سوخت: خودرو زیاد + یارانه بالا - خودرو برقی - حمل‌ونقل عمومی
	var demand := clampf(
		0.85 - ev_charging * 0.40 - public_fleet * 0.25 - float(urban.get("public_transit", 0.4)) * 0.20 + subsidy * 0.15,
		0.20, 1.10)
	fp["fuel_demand"] = demand

	# سهم خودرو برقی
	var ev_share := clampf(ev_charging * 0.30 + emission * 0.20 + public_fleet * 0.15, 0.0, 0.70)
	fp["ev_share"] = ev_share

	# قاچاق سوخت: یارانه زیاد + گشت دریایی کم
	var coast_guard := float(blue.get("coast_guard", 0.30))
	var smuggling := clampf(subsidy * 0.55 - coast_guard * 0.20, 0.02, 0.80)
	fp["smuggling"] = smuggling
	fuel_stations["smuggling"] = smuggling
	state["fuel_stations"] = fuel_stations

	# درآمد اصلاح قیمت (هرچه یارانه کمتر، درآمد بیشتر)
	var revenue := gdp * (1.0 - subsidy) * 0.012
	fp["fuel_revenue"] = revenue
	econ["national_debt"] = maxf(0.0, float(econ.get("national_debt", 0.0)) - revenue * 0.5)
	# اما حذف یارانه تورم‌زا است
	econ["inflation"] = clampf(float(econ.get("inflation", 0.08)) + (1.0 - subsidy) * 0.003 - ev_share * 0.002, 0.0, 1.0)
	state["economy"] = econ

	# آلودگی: سوخت زیاد + استاندارد پایین - خودرو برقی
	var vehicle_pollution := demand * 0.30 - ev_share * 0.20 - emission * 0.20
	env["pollution"] = clampf(float(env.get("pollution", env.get("pollution_level", 0.45))) + vehicle_pollution * 0.002, 0.05, 0.95)
	env["air_quality"] = clampf(float(env.get("air_quality", 0.60)) - vehicle_pollution * 0.003, 0.05, 1.0)
	state["environment"] = env

	# ناوگان عمومی برقی رضایت می‌سازد
	if public_fleet > 0.3:
		state["population"]["happiness"] = clampf(float(state["population"].get("happiness", 0.60)) + 0.001, 0.05, 1.0)

	# رویدادها
	if subsidy < 0.30 and float(econ.get("inflation", 0.08)) > 0.15 and Deterministic.chance(0.06):
		state["politics"]["stability"] = clampf(state["politics"].get("stability", 0.60) - 0.020, 0.05, 1.0)
		events.append({"type": "fuel_protest", "message": "⛽ اعتراض به گرانی سوخت و تورم برخاست؛ ثبات سیاسی تحت فشار"})
	elif smuggling > 0.50 and Deterministic.chance(0.04):
		events.append({"type": "fuel_smuggling", "message": "🚛 قاچاق سازمان‌یافته سوخت؛ یارانه از مرز خارج می‌شود"})
	elif ev_share > 0.35 and Deterministic.chance(0.03):
		events.append({"type": "ev_transition", "message": "🔌 گذار به خودروی برقی شتاب گرفت؛ هوای شهرها پاک‌تر شد"})

	state["fuel_policy"] = fp
	return {"state": state, "events": events}

# ── اصلاح یارانه سوخت ──
func reform_subsidy(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var fp: Dictionary = state["fuel_policy"]
	if turn - int(fp.get("last_reform", -99)) < 10:
		return {"success": false, "reason": "اصلاح قیمت سوخت هر ۱۰ نوبت یک بار", "state": state, "events": []}
	fp["last_reform"] = turn
	fp["subsidy"] = clampf(float(fp.get("subsidy", 0.65)) - 0.15, 0.10, 1.0)
	# درآمد هدفمندی به رفاه
	var econ: Dictionary = state.get("economy", {})
	econ["national_debt"] = maxf(0.0, float(econ.get("national_debt", 0.0)) - float(econ.get("gdp", 1.0)) * 0.003)
	state["economy"] = econ
	state["fuel_policy"] = fp
	return {"success": true, "state": state,
		"events": [{"type": "fuel_reform", "message": "💰 اصلاح یارانه سوخت اجرا شد؛ درآمد هدفمند شد ولی تورم و نارضایتی در پی دارد"}]}

# ── توسعه ایستگاه شارژ برقی ──
func build_charging(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var fp: Dictionary = state["fuel_policy"]
	if float(fp.get("ev_charging", 0.10)) >= 0.95:
		return {"success": false, "reason": "ایستگاه شارژ در سقف است", "state": state, "events": []}
	var tech := float(state.get("technology", {}).get("branch_levels", {}).get("انرژی_پاک", 0))
	if tech < 4:
		return {"success": false, "reason": "به فناوری انرژی پاک سطح ۴ نیاز است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["government_spending"] = float(econ.get("government_spending", 0.0)) + float(econ.get("gdp", 1.0)) * 0.003
	fp["ev_charging"] = clampf(float(fp.get("ev_charging", 0.10)) + 0.15, 0.0, 1.0)
	state["economy"] = econ
	state["fuel_policy"] = fp
	return {"success": true, "state": state,
		"events": [{"type": "charging", "message": "⚡ شبکه ایستگاه‌های شارژ برقی گسترش یافت"}]}

# ── استاندارد آلایندگی ──
func emission_standard(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var fp: Dictionary = state["fuel_policy"]
	if float(fp.get("emission_standard", 0.25)) >= 0.95:
		return {"success": false, "reason": "استاندارد آلایندگی در سقف است", "state": state, "events": []}
	fp["emission_standard"] = clampf(float(fp.get("emission_standard", 0.25)) + 0.15, 0.0, 1.0)
	var factions: Dictionary = state.get("factions", {})
	if factions.has("نخبگان اقتصادی"):
		var f: Dictionary = factions["نخبگان اقتصادی"]
		f["loyalty"] = clampf(float(f.get("loyalty", 50.0)) - 0.5, 0.0, 100.0)
		factions["نخبگان اقتصادی"] = f
		state["factions"] = factions
	state["fuel_policy"] = fp
	return {"success": true, "state": state,
		"events": [{"type": "emission_std", "message": "🚗 استاندارد آلایندگی سختگیرانه‌تر شد؛ خودروهای فرسوده محدود شدند"}]}

# ── نوسازی ناوگان عمومی برقی ──
func electrify_public_fleet(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var fp: Dictionary = state["fuel_policy"]
	if float(fp.get("public_fleet", 0.20)) >= 0.95:
		return {"success": false, "reason": "ناوگان عمومی برقی در سقف است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["government_spending"] = float(econ.get("government_spending", 0.0)) + float(econ.get("gdp", 1.0)) * 0.004
	fp["public_fleet"] = clampf(float(fp.get("public_fleet", 0.20)) + 0.15, 0.0, 1.0)
	state["urban_policy"]["public_transit"] = clampf(state["urban_policy"].get("public_transit", 0.4) + 0.05, 0.0, 1.0)
	state["economy"] = econ
	state["fuel_policy"] = fp
	return {"success": true, "state": state,
		"events": [{"type": "e_bus", "message": "🚍 ناوگان اتوبوس برقی شهری توسعه یافت؛ آلودگی کمتر و رضایت بیشتر"}]}
