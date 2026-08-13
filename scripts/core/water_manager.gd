extends Node
# ────────────────────────────────────────────────────────────────────────────
# امنیت آبی و مدیریت آب — عمق حیاتی برای کشورهای خشک/نیمه‌خشک
# منابع آب (سطحی، زیرزمینی، شیرین‌سازی)، تقاضا (شرب، کشاورزی، صنعت)،
# سدها، نشت شبکه، بازچرخانی پساب، خشکسالی و فرونشست زمین را شبیه‌سازی می‌کند.
# پیوند: منابع، کشاورزی، انرژی، بهداشت، محیط‌زیست، رفاه و شهرسازی.
#
# state["water_policy"] = { "leakage":0..1, "desalination":0..1, "dams":0..1,
#   "irrigation_efficiency":0..1, "conservation":0..1,
#   "last_dam":turn, "last_desal":turn, "aquifer":0..1 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("water_policy"):
		state["water_policy"] = {
			"leakage": 0.28, "desalination": 0.05, "dams": 0.30,
			"irrigation_efficiency": 0.35, "conservation": 0.25,
			"last_dam": -99, "last_desal": -99, "aquifer": 0.70
		}
	if not state.has("water_infrastructure"):
		state["water_infrastructure"] = {
			"storage_bcm": 35.0, "treatment": 0.65, "wastewater_reuse": 0.12,
			"quality": 0.60, "rural_access": 0.72, "stress_index": 0.45
		}
	return state

func _water_inventory(state: Dictionary) -> float:
	return float(state.get("resources", {}).get("inventory", {}).get("آب", 90.0))

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var wp: Dictionary = state["water_policy"]
	var wi: Dictionary = state["water_infrastructure"]
	var econ: Dictionary = state.get("economy", {})
	var pol: Dictionary = state.get("politics", {})
	var env: Dictionary = state.get("environment", {})
	var pop: Dictionary = state.get("population", {})
	var agri: Dictionary = state.get("agriculture", {})
	var urban: Dictionary = state.get("urban_facilities", {})

	var leakage := float(wp.get("leakage", 0.28))
	var desal := float(wp.get("desalination", 0.05))
	var dams := float(wp.get("dams", 0.30))
	var irrigation := float(wp.get("irrigation_efficiency", 0.35))
	var conservation := float(wp.get("conservation", 0.25))
	var aquifer := float(wp.get("aquifer", 0.70))
	var gdp := float(econ.get("gdp", 1.0))
	var rainfall := 0.55 + float(env.get("climate_change", 0.5)) * 0.25
	var drought_pressure := maxf(0.0, 0.55 - rainfall) + (1.0 - dams) * 0.25 + (1.0 - conservation) * 0.20

	# منبع آب تجدیدپذیر و ذخیره سدها
	var renewable := 95.0 + dams * 22.0 + desal * 18.0 - drought_pressure * 40.0
	renewable = clampf(renewable, 15.0, 140.0)
	wi["storage_bcm"] = clampf(float(wi.get("storage_bcm", 35.0)) * 0.995 + (dams * 45.0 - leakage * 12.0) * 0.005, 8.0, 100.0)
	# نشت شهری و بازچرخانی پساب
	var network := float(urban.get("water_network", 0.75))
	wi["leakage"] = clampf((1.0 - network) * 0.42 + leakage * 0.25, 0.05, 0.55)
	wi["wastewater_reuse"] = clampf(float(wi.get("wastewater_reuse", 0.12)) + conservation * 0.0003, 0.02, 0.65)
	wi["quality"] = clampf(float(wi.get("quality", 0.60)) * 0.996 + (float(wi.get("treatment", 0.65)) * 0.6 + conservation * 0.2 - leakage * 0.15) * 0.004, 0.15, 0.98)
	var stress := clampf(drought_pressure + leakage * 0.25 - desal * 0.30 - float(wi.get("wastewater_reuse", 0.12)) * 0.20 - conservation * 0.18, 0.03, 0.98)
	wi["stress_index"] = stress

	# افت سفره آب زیرزمینی و فرونشست با مصرف بی‌رویه کشاورزی
	aquifer = clampf(aquifer + (rainfall - 0.55) * 0.002 - (1.0 - irrigation) * 0.003 + conservation * 0.001, 0.08, 0.95)
	wp["aquifer"] = aquifer

	# به‌روزرسانی موجودی آب در چرخه اصلی منابع
	var resources: Dictionary = state.get("resources", {})
	if resources.has("inventory"):
		resources["inventory"]["آب"] = clampf(renewable, 0.0, 150.0)
		resources["water_stress"] = stress
		state["resources"] = resources
	# امنیت غذایی به آبیاری و تنش آبی وابسته است
	agri["irrigated_land"] = clampf(float(agri.get("irrigated_land", 0.40)) + irrigation * 0.0003 - stress * 0.0004, 0.10, 0.88)
	agri["food_security"] = clampf(float(agri.get("food_security", 0.85)) - maxf(0.0, stress - 0.55) * 0.004 + irrigation * 0.001, 0.10, 0.98)
	state["agriculture"] = agri
	# آب شیرین‌کن انرژی‌بر است و برق مصرف می‌کند
	if resources.has("inventory"):
		resources["inventory"]["برق"] = clampf(float(resources["inventory"].get("برق", 100.0)) - desal * 2.0, 0.0, 150.0)
		state["resources"] = resources

	# هزینه نگهداری تصفیه‌خانه و کاهش بیماری‌های آب
	var cost := gdp * 0.0008 + gdp * leakage * 0.0006
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + cost
	state["health"]["coverage"] = clampf(float(state["health"].get("coverage", 0.75)) + float(wi.get("quality", 0.60)) * 0.0005, 0.1, 1.0)
	state["economy"] = econ

	# رویدادها
	if stress > 0.72 and Deterministic.chance(0.05):
		pol["stability"] = clampf(float(pol.get("stability", 0.60)) - 0.012, 0.05, 1.0)
		pop["happiness"] = clampf(float(pop.get("happiness", 0.60)) - 0.006, 0.05, 1.0)
		events.append({"type": "water_crisis", "message": "🚱 بحران آب! جیره‌بندی، خاموشی چاه‌ها و تنش در محلات کم‌برخوردار"})
	elif aquifer < 0.30 and Deterministic.chance(0.04):
		events.append({"type": "land_subsidence", "message": "🏚️ فرونشست زمین بر اثر برداشت بی‌رویه از سفره‌های زیرزمینی؛ زیرساخت‌ها ترک خوردند"})
		pol["stability"] = clampf(float(pol.get("stability", 0.60)) - 0.008, 0.05, 1.0)
	elif stress < 0.30 and Deterministic.chance(0.03):
		pop["happiness"] = clampf(float(pop.get("happiness", 0.60)) + 0.003, 0.05, 1.0)
		events.append({"type": "water_secure", "message": "💧 امنیت آبی بهبود یافت؛ سدها پر، روستاها آبدار و کشاورزی پایدارتر شد"})

	state["water_policy"] = wp
	state["water_infrastructure"] = wi
	state["politics"] = pol
	state["population"] = pop
	state["environment"] = env
	return {"state": state, "events": events}

# ── ساخت/تقویت سد و مخزن ──
func build_dam(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var wp: Dictionary = state["water_policy"]
	if turn - int(wp.get("last_dam", -99)) < 12:
		return {"success": false, "reason": "ساخت سد جدید هر ۱۲ نوبت یک بار ممکن است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.010
	wp["dams"] = clampf(float(wp.get("dams", 0.30)) + 0.12, 0.0, 1.0)
	wp["last_dam"] = turn
	var wi: Dictionary = state["water_infrastructure"]
	wi["storage_bcm"] = float(wi.get("storage_bcm", 35.0)) + 6.0
	econ["unemployment"] = clampf(float(econ.get("unemployment", 0.08)) - 0.0006, 0.02, 0.30)
	state["environment"]["carbon"] = clampf(float(state["environment"].get("carbon", 0.6)) + 0.004, 0.0, 1.0)
	state["water_policy"] = wp
	state["water_infrastructure"] = wi
	state["economy"] = econ
	return {"success": true, "state": state,
		"events": [{"type": "dam", "message": "🛢️ سد و مخزن جدید به مدار آمد؛ ذخیره آب و مهار سیلاب بهتر شد ولی اثرهای زیست‌محیطی دارد"}]}

# ── توسعه آب‌شیرین‌کن ──
func build_desalination(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var wp: Dictionary = state["water_policy"]
	if turn - int(wp.get("last_desal", -99)) < 9:
		return {"success": false, "reason": "توسعه آب‌شیرین‌کن هر ۹ نوبت یک بار ممکن است", "state": state, "events": []}
	var tech: Dictionary = state.get("technology", {})
	if float(tech.get("branch_levels", {}).get("انرژی_پاک", 0)) < 5:
		return {"success": false, "reason": "به فناوری انرژی پاک سطح ۵ نیاز است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.007
	wp["desalination"] = clampf(float(wp.get("desalination", 0.05)) + 0.12, 0.0, 0.90)
	wp["last_desal"] = turn
	state["resources"]["inventory"]["برق"] = clampf(float(state["resources"]["inventory"].get("برق", 100.0)) - 3.0, 0.0, 150.0)
	state["water_policy"] = wp
	state["economy"] = econ
	return {"success": true, "state": state,
		"events": [{"type": "desalination", "message": "🌊 واحد آب‌شیرین‌کن جدید افتتاح شد؛ وابستگی به بارش کمتر شد اما مصرف برق بالا رفت"}]}

# ── نوسازی شبکه برای کاهش هدررفت ──
func reduce_leakage(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var wp: Dictionary = state["water_policy"]
	if float(wp.get("leakage", 0.28)) <= 0.08:
		return {"success": false, "reason": "هدررفت شبکه در حد حداقلی است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.004
	wp["leakage"] = clampf(float(wp.get("leakage", 0.28)) - 0.10, 0.05, 0.60)
	var urban: Dictionary = state.get("urban_facilities", {})
	urban["water_network"] = clampf(float(urban.get("water_network", 0.75)) + 0.03, 0.2, 0.99)
	state["water_policy"] = wp
	state["urban_facilities"] = urban
	state["economy"] = econ
	return {"success": true, "state": state,
		"events": [{"type": "water_network", "message": "🔧 شبکه آبرسانی نوسازی شد؛ هدررفت آب و قطعی محله‌ها کاهش یافت"}]}

# ── آبیاری نوین و فرهنگ مصرف ──
func irrigation_upgrade(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var wp: Dictionary = state["water_policy"]
	if float(wp.get("irrigation_efficiency", 0.35)) >= 0.92:
		return {"success": false, "reason": "بازده آبیاری در سقف ممکن است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.0035
	wp["irrigation_efficiency"] = clampf(float(wp.get("irrigation_efficiency", 0.35)) + 0.13, 0.10, 0.95)
	wp["conservation"] = clampf(float(wp.get("conservation", 0.25)) + 0.04, 0.0, 1.0)
	var agri: Dictionary = state.get("agriculture", {})
	agri["yield"] = clampf(float(agri.get("yield", 0.70)) + 0.02, 0.2, 1.6)
	state["water_policy"] = wp
	state["agriculture"] = agri
	state["economy"] = econ
	return {"success": true, "state": state,
		"events": [{"type": "irrigation", "message": "🌱 آبیاری تحت‌فشار و کم‌مصرف در اراضی گسترش یافت؛ برداشت بیشتر با آب کمتر"}]}
