extends BaseSystem
# ۳.۴۶ سوخت و ایستگاه‌های انرژی - پمپ بنزین، شارژ برقی، قیمت، پوشش، ذخیره، قاچاق، یارانه

func compute(state: Dictionary, tick: int) -> Dictionary:
	var fuel = state.get("fuel_stations", {})
	var resources = state.get("resources", {})
	var econ = state.get("economy", {})
	var transport = state.get("transport_detail", {"roads_km":80000.0, "fuel_consumption":100.0, "traffic_congestion":0.4})

	fuel["gas_stations"] = fuel.get("gas_stations", 4000)
	fuel["ev_charging"] = fuel.get("ev_charging", 500)
	fuel["cng_stations"] = fuel.get("cng_stations", 800)
	fuel["gasoline_price"] = fuel.get("gasoline_price", 15000.0)
	fuel["diesel_price"] = fuel.get("diesel_price", 12000.0)
	fuel["cng_price"] = fuel.get("cng_price", 8000.0)
	fuel["electric_price"] = fuel.get("electric_price", 2000.0)
	fuel["coverage"] = fuel.get("coverage", 0.75)
	fuel["renewable_share"] = fuel.get("renewable_share", 0.05)
	fuel["storage_days"] = fuel.get("storage_days", 15.0)
	fuel["smuggling"] = fuel.get("smuggling", 0.15)
	fuel["subsidy_cost"] = fuel.get("subsidy_cost", 50_000_000_000.0)
	fuel["consumption_daily"] = fuel.get("consumption_daily", 80_000_000.0)

	var events = []

	var oil_inv = resources.get("inventory",{}).get("نفت",80.0)
	var gas_inv = resources.get("inventory",{}).get("گاز",70.0)
	var oil_price = 82.0
	var exchange = state.get("central_bank",{}).get("exchange_rate",1.0)
	var inflation = econ.get("inflation",0.08)

	# قیمت‌ها - تابع نفت جهانی + یارانه + ارز + مالیات
	var subsidy_rate = 0.68
	var gasoline_target = oil_price * 1050.0 * exchange * (1.0 - subsidy_rate*0.8) + 4000.0
	fuel["gasoline_price"] = fuel["gasoline_price"]*0.985 + gasoline_target*0.015 + inflation*100.0
	fuel["diesel_price"] = fuel["gasoline_price"]*0.85
	fuel["cng_price"] = fuel["gasoline_price"]*0.55
	fuel["electric_price"] = 2000.0 + inflation*500.0

	# پوشش جایگاه‌ها - جاده و خودرو
	var roads_km = transport.get("roads_km",80000.0)
	var pop_total = state.get("population",{}).get("total",85_000_000.0)
	var car_ownership = 0.40
	var cars = pop_total * car_ownership / 3.0
	var coverage_target = 0.55 + roads_km/120000.0*0.25 + cars/12_000_000.0*0.20
	fuel["coverage"] = clamp(fuel["coverage"]*0.988 + coverage_target*0.012, 0.25, 0.98)

	# سهم تجدیدپذیر - انرژی پاک
	var green = state.get("environment",{}).get("green_energy",0.20)
	fuel["renewable_share"] = clamp(fuel["renewable_share"]*0.996 + green*0.001 + state.get("technology",{}).get("branches",{}).get("انرژی_پاک",0.15)*0.001, 0.02, 0.60)

	# رشد ایستگاه شارژ
	if green > 0.28 and Deterministic.chance(0.012):
		fuel["ev_charging"] += Deterministic.next_int_range(3,12)
		fuel["cng_stations"] += Deterministic.next_int_range(1,4)
		if tick % 90 == 0:
			events.append({"type":"ev_expansion","ev": fuel["ev_charging"], "message":"توسعه ایستگاه شارژ برقی - %d ایستگاه فعال" % fuel["ev_charging"]})

	# ذخیره - روز پوشش
	var daily_cons = transport.get("fuel_consumption",100.0) * 800000.0
	fuel["consumption_daily"] = daily_cons
	fuel["storage_days"] = oil_inv / max(daily_cons/80_000_000.0*10.0, 1.0) * 12.0
	fuel["storage_days"] = clamp(fuel["storage_days"], 2.0, 90.0)

	# قاچاق - اختلاف قیمت + کنترل مرز
	var neighbor_price = 30000.0
	var price_gap = neighbor_price - fuel["gasoline_price"]
	var border_ctrl = state.get("security",{}).get("border_control",0.60)
	var smuggling_target = 0.08 + max(0.0, price_gap/30000.0)*0.45 - border_ctrl*0.25 + (1.0 - border_ctrl)*0.10
	fuel["smuggling"] = clamp(fuel["smuggling"]*0.97 + smuggling_target*0.03, 0.01, 0.70)

	# هزینه یارانه - شکاف قیمت * مصرف
	fuel["subsidy_cost"] = max(0.0, price_gap) * daily_cons * 0.7

	# اثر بر اقتصاد و رضایت
	var price_effect = (15000.0 - fuel["gasoline_price"])/15000.0
	state["population"]["happiness"] = clamp(state.get("population",{}).get("happiness",0.60) + price_effect*0.0006 - fuel["smuggling"]*0.0003, 0.05, 0.95)
	state["economy"]["inflation"] = clamp(state.get("economy",{}).get("inflation",0.08) + (fuel["gasoline_price"]-15000.0)/15000.0*0.00015, -0.02, 0.50)

	# رویدادها
	if fuel["smuggling"] > 0.42 and Deterministic.chance(0.014):
		events.append({"type":"fuel_smuggling_crisis","smuggling": fuel["smuggling"], "subsidy": fuel["subsidy_cost"], "message":"بحران قاچاق سوخت - یارانه %d میلیاردی دود شد" % int(fuel["subsidy_cost"]/1_000_000_000.0)})
		econ["government_revenue"] = econ.get("government_revenue",0.0) - fuel["smuggling"]*1_200_000_000.0

	if fuel["storage_days"] < 6.0 and Deterministic.chance(0.018):
		events.append({"type":"fuel_shortage","storage": fuel["storage_days"], "message":"ذخیره سوخت %d روز - صف طولانی پمپ بنزین" % int(fuel["storage_days"])})
		transport["traffic_congestion"] = clamp(transport.get("traffic_congestion",0.4)+0.12, 0.05, 0.95)

	if fuel["coverage"] < 0.50 and Deterministic.chance(0.011):
		events.append({"type":"fuel_coverage_low","coverage": fuel["coverage"], "message":"پوشش جایگاه سوخت پایین - جاده‌های روستایی بدون پمپ"})

	if fuel["ev_charging"] > 2000 and Deterministic.chance(0.008):
		events.append({"type":"ev_milestone","ev": fuel["ev_charging"], "message":"نقطه عطف - %d جایگاه شارژ برقی" % fuel["ev_charging"]})

	state["fuel_stations"] = fuel
	state["transport_detail"] = transport
	state["economy"] = econ
	return {"success":true,"state":state,"events":events}
