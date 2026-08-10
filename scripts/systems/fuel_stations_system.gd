extends BaseSystem
# ۳.۴۶ سوخت و ایستگاه‌های انرژی - پمپ بنزین و شارژ

func compute(state: Dictionary, tick: int) -> Dictionary:
	var fuel = state.get("fuel_stations", {})
	var resources = state.get("resources", {})
	var econ = state.get("economy", {})
	var transport = state.get("transport_detail", {})

	fuel["gas_stations"] = fuel.get("gas_stations", 4000)
	fuel["ev_charging"] = fuel.get("ev_charging", 500)
	fuel["gasoline_price"] = fuel.get("gasoline_price", 15000.0)  # ریال per liter
	fuel["coverage"] = fuel.get("coverage", 0.75)
	fuel["renewable_share"] = fuel.get("renewable_share", 0.05)
	fuel["storage_days"] = fuel.get("storage_days", 15.0)
	fuel["smuggling"] = fuel.get("smuggling", 0.15)

	var events = []

	var oil_inventory = resources.get("inventory",{}).get("نفت",80.0)
	var oil_price_global = 80.0  # دلار per barrel - ثابت فرض
	var exchange_rate = state.get("central_bank",{}).get("exchange_rate",1.0)

	# قیمت بنزین = f(قیمت نفت جهانی، یارانه، نرخ ارز، مالیات)
	var subsidy = 0.7  # 70٪ یارانه
	var gasoline_price_target = oil_price_global * 1000.0 * exchange_rate * (1.0 - subsidy) + 5000.0
	fuel["gasoline_price"] = fuel["gasoline_price"] * 0.99 + gasoline_price_target * 0.01

	# پوشش جایگاه‌ها = f(جاده، جمعیت، خودرو)
	var roads_km = transport.get("roads_km",80000.0)
	var cars = state.get("people",{}).get("households_details",{}).get("دارای_خودرو",0.40) * state.get("population",{}).get("total",85_000_000) / 3.0
	var coverage_target = 0.6 + roads_km / 100000.0 * 0.2 + cars / 10_000_000.0 * 0.1
	fuel["coverage"] = clamp(fuel["coverage"] * 0.99 + coverage_target * 0.01, 0.3, 0.98)

	# سهم انرژی تجدیدپذیر در حمل‌ونقل
	var green_energy = state.get("environment",{}).get("green_energy_share",0.20)
	fuel["renewable_share"] = clamp(fuel["renewable_share"] + green_energy * 0.0005, 0.02, 0.50)

	# جایگاه شارژ برقی با انرژی پاک رشد می‌کند
	if green_energy > 0.3 and Deterministic.chance(0.01):
		fuel["ev_charging"] += 5
		events.append({"type": "ev_charging_expansion", "message": "توسعه ایستگاه شارژ خودرو برقی - %s ایستگاه" % str(fuel["ev_charging"])})

	# ذخیره سوخت - روز
	var consumption = transport.get("fuel_consumption",100.0)
	fuel["storage_days"] = oil_inventory / max(consumption / 100.0, 1.0) * 15.0
	fuel["storage_days"] = clamp(fuel["storage_days"], 3.0, 60.0)

	# قاچاق سوخت = f(یارانه، اختلاف قیمت با همسایه، کنترل مرز)
	var price_diff = 30000.0 - fuel["gasoline_price"]  # اختلاف با قیمت همسایه
	var border_control = state.get("security",{}).get("border_control",0.60)
	var smuggling_target = 0.1 + price_diff / 30000.0 * 0.4 - border_control * 0.2
	fuel["smuggling"] = clamp(fuel["smuggling"] * 0.98 + smuggling_target * 0.02, 0.02, 0.60)

	if fuel["smuggling"] > 0.4 and Deterministic.chance(0.012):
		events.append({"type": "fuel_smuggling_crisis", "message": "بحران قاچاق سوخت - یارانه به جیب قاچاقچیان!", "smuggling": fuel["smuggling"]})
		econ["government_revenue"] = econ.get("government_revenue",0.0) - fuel["smuggling"] * 1_000_000_000.0
		state["economy"] = econ

	# کمبود سوخت
	if fuel["storage_days"] < 7.0 and Deterministic.chance(0.015):
		events.append({"type": "fuel_shortage", "message": "کمبود سوخت - صف‌های طولانی در پمپ بنزین‌ها!", "storage": fuel["storage_days"]})
		transport["traffic_congestion"] = clamp(transport.get("traffic_congestion",0.4) + 0.1, 0.05, 0.90)
		state["transport_detail"] = transport

	# اثر قیمت بنزین بر تورم و رضایت
	var price_effect = (15000.0 - fuel["gasoline_price"]) / 15000.0
	state["population"]["happiness"] = clamp(state.get("population",{}).get("happiness",0.6) + price_effect * 0.0005, 0.05, 0.95)
	state["economy"]["inflation"] = clamp(state.get("economy",{}).get("inflation",0.08) + (fuel["gasoline_price"] - 15000.0)/15000.0 * 0.0001, -0.02, 0.50)

	state["fuel_stations"] = fuel
	return {"success": true, "state": state, "events": events}
