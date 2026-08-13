extends Node
# ────────────────────────────────────────────────────────────────────────────
# آبخیزداری، بیابان‌زایی و مقابله با ریزگرد — عمق سرزمین
# فرسایش خاک، پوشش جنگلی، بیابان‌زایی، مقابله با ریزگرد، پخش سیلاب و
# احیای تا‌لاب‌ها نه فقط محیط‌زیست، بلکه امنیت غذایی، سلامت، مهاجرت داخلی و
# حتی روابط همسایگان (منبع ریزگرد فرامرزی) را تحت تاثیر قرار می‌دهد.
# پیوند: آب، کشاورزی، اقلیم، بهداشت، مهاجرت، دیپلماسی، امداد.
#
# state["watershed_policy"] = {
#   "restoration":0..1, "check_dams":0..1, "forestry":0..1,
#   "dust_control":0..1, "wetlands":0..1, "last_restoration":turn,
#   "soil_health":0..1, "desertification":0..1, "dust":0..1 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("watershed_policy"):
		state["watershed_policy"] = {
			"restoration": 0.20, "check_dams": 0.15, "forestry": 0.25,
			"dust_control": 0.20, "wetlands": 0.20, "last_restoration": -99,
			"soil_health": 0.55, "desertification": 0.45, "dust": 0.40,
			"forest_cover": 0.20, "erosion_rate": 0.35
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var wp: Dictionary = state["watershed_policy"]
	var env: Dictionary = state.get("environment", {})
	var agri: Dictionary = state.get("agriculture", {})
	var health: Dictionary = state.get("health", {})
	var water: Dictionary = state.get("water_policy", {})
	var econ: Dictionary = state.get("economy", {})
	var pop: Dictionary = state.get("population", {})
	var climate_policy: Dictionary = state.get("climate_policy", {})

	var restoration := float(wp.get("restoration", 0.20))
	var check_dams := float(wp.get("check_dams", 0.15))
	var forestry := float(wp.get("forestry", 0.25))
	var dust_control := float(wp.get("dust_control", 0.20))
	var wetlands := float(wp.get("wetlands", 0.20))
	var pollution := float(climate_policy.get("pollution", 0.5))
	var rainfall_pressure := float(env.get("climate_change", 0.5))

	# پوشش جنگلی و فرسایش
	var forest := clampf(0.20 + forestry * 0.35 - pollution * 0.10 - rainfall_pressure * 0.05, 0.02, 0.80)
	wp["forest_cover"] = forest
	var erosion := clampf(0.55 - restoration * 0.25 - check_dams * 0.20 - forest * 0.20 + pollution * 0.10, 0.05, 0.95)
	wp["erosion_rate"] = erosion
	var soil := clampf(0.50 + restoration * 0.20 + forest * 0.15 - erosion * 0.20, 0.10, 0.95)
	wp["soil_health"] = soil

	# بیابان‌زایی: خشکی + تخریج - آبخیزداری - جنگل
	var desert := clampf(
		0.50 + rainfall_pressure * 0.25 - restoration * 0.25 -
		wetlands * 0.15 - forestry * 0.15 + (1.0 - float(water.get("aquifer", 0.7))) * 0.10,
		0.05, 0.95)
	wp["desertification"] = desert

	# ریزگرد: منبع داخلی (کویر) + فرامرزی؛ پایش و کانون‌یابی آن را می‌کاهد
	var dust := clampf(
		desert * 0.50 + (1.0 - dust_control) * 0.25 + (1.0 - wetlands) * 0.10,
		0.05, 0.95)
	wp["dust"] = dust

	# اثر بر کشاورزی: خاک سالم = محصول؛ گردوغبار و بیابان = افت
	agri["yield"] = clampf(float(agri.get("yield", 0.70)) * 0.995 + (soil - desert * 0.3) * 0.005, 0.2, 1.6)
	state["agriculture"] = agri

	# اثر بر سلامت: ریزگرد → بیماری‌های تنفسی
	if dust > 0.60:
		health["quality"] = clampf(float(health.get("quality", 0.60)) - 0.002, 0.1, 1.0)
		pop["happiness"] = clampf(float(pop.get("happiness", 0.60)) - 0.003, 0.05, 1.0)
	state["health"] = health
	state["population"] = pop

	# خسارت اقتصادی بیابان‌زایی و ریزگرد
	var gdp := float(econ.get("gdp", 1.0))
	var damage := gdp * (desert * 0.0003 + dust * 0.0005 - restoration * 0.0002)
	econ["gdp"] = gdp - damage
	state["economy"] = econ

	# کنترل بیابان‌زایی فرصت اشتغال روستایی می‌سازد
	if restoration > 0.40:
		state["welfare"]["poverty"] = clampf(float(state.get("welfare", {}).get("poverty", 0.15)) - 0.0004, 0.02, 0.80)
		state["population"]["happiness"] = clampf(float(state["population"].get("happiness", 0.60)) + 0.001, 0.05, 1.0)

	# رویدادها
	if dust > 0.70 and Deterministic.chance(0.06):
		pop["happiness"] = clampf(float(pop.get("happiness", 0.60)) - 0.010, 0.05, 1.0)
		state["population"] = pop
		events.append({"type": "dust_storm", "message": "🌪️ طوفان گردوغبار! شهرها تعطیل شدند، تنفس و حمل‌ونقل آسیب دید"})
	elif soil < 0.30 and Deterministic.chance(0.040):
		events.append({"type": "soil_loss", "message": "🏜️ فرسایش خاک شدید گرفت؛ حاصلخیزی زمین‌های کشاورزی رو به افول است"})
	elif erosion < 0.25 and Deterministic.chance(0.025):
		events.append({"type": "watershed_win", "message": "🌱 آبخیزداری جواب داد؛ سیلاب مهار، سفره تغذیه و خاک حاصلخیز شد"})

	state["watershed_policy"] = wp
	state["environment"] = env
	return {"state": state, "events": events}

# ── احیای آبخیز و پخش سیلاب ──
func restore_watershed(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var wp: Dictionary = state["watershed_policy"]
	if turn - int(wp.get("last_restoration", -99)) < 6:
		return {"success": false, "reason": "پروژه آبخیزداری هر ۶ نوبت یک بار", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.004
	wp["last_restoration"] = turn
	wp["restoration"] = clampf(float(wp.get("restoration", 0.20)) + 0.13, 0.0, 1.0)
	wp["check_dams"] = clampf(float(wp.get("check_dams", 0.15)) + 0.05, 0.0, 1.0)
	state["water_policy"]["aquifer"] = clampf(float(state["water_policy"].get("aquifer", 0.70)) + 0.03, 0.05, 0.95)
	state["economy"] = econ
	state["watershed_policy"] = wp
	return {"success": true, "state": state,
		"events": [{"type": "watershed_restore", "message": "⛰️ طرح آبخیزداری و پخش سیلاب اجرا شد؛ فرسایش کم و سفره‌های زیرزمینی تغذیه شد"}]}

# ── جنگل‌کاری و احیای مرتع ──
func reforest_land(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var wp: Dictionary = state["watershed_policy"]
	if float(wp.get("forestry", 0.25)) >= 0.95:
		return {"success": false, "reason": "پوشش جنگلی و مرتعی در سقف است", "state": state, "events": []}
	wp["forestry"] = clampf(float(wp.get("forestry", 0.25)) + 0.13, 0.0, 1.0)
	state["environment"]["carbon"] = clampf(state["environment"].get("carbon", 0.6) - 0.01, 0.0, 1.0)
	state["watershed_policy"] = wp
	return {"success": true, "state": state,
		"events": [{"type": "reforest_land", "message": "🌲 جنگل‌کاری و احیای مراتع انجام شد؛ خاک و هوا بهتر شد"}]}

# ── مقابله با کانون‌های ریزگرد ──
func control_dust(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var wp: Dictionary = state["watershed_policy"]
	if float(wp.get("dust_control", 0.20)) >= 0.95:
		return {"success": false, "reason": "پروژه‌های مقابله با ریزگرد در سقف است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.003
	wp["dust_control"] = clampf(float(wp.get("dust_control", 0.20)) + 0.13, 0.0, 1.0)
	state["economy"] = econ
	state["watershed_policy"] = wp
	return {"success": true, "state": state,
		"events": [{"type": "dust_control", "message": "💨 کانون‌های ریزگرد مالچ‌پاشی و نهال‌کاری شد؛ پایش هوای استان‌ها بهتر شد"}]}

# ── احیای تا‌لاب و دریاچه ──
func restore_wetlands(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var wp: Dictionary = state["watershed_policy"]
	if float(wp.get("wetlands", 0.20)) >= 0.95:
		return {"success": false, "reason": "وضعیت تا‌لاب‌ها در سقف بهبود است", "state": state, "events": []}
	wp["wetlands"] = clampf(float(wp.get("wetlands", 0.20)) + 0.13, 0.0, 1.0)
	state["water_policy"]["aquifer"] = clampf(state["water_policy"].get("aquifer", 0.70) + 0.02, 0.05, 0.95)
	state["culture_policy"]["soft_power"] = clampf(state.get("culture_policy", {}).get("soft_power", 40.0) + 0.5, 5.0, 100.0)
	state["watershed_policy"] = wp
	return {"success": true, "state": state,
		"events": [{"type": "wetlands", "message": "🦩 حقابه تا‌لاب‌ها و دریاچه‌ها تامین شد؛ تنوع زیستی و تصویر محیط‌زیستی بهتر شد"}]}
