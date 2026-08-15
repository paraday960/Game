extends Node
# ────────────────────────────────────────────────────────────────────────────
# پتروشیمی و پالایش — عمق ارزش‌افزوده انرژی
# به‌جای خام‌فروشی نفت/گاز، ظرفیت پالایش و پتروشیمی، محصولات با ارزش،
# خودکفایی بنزین و صادرات محصول نهایی. تحریم‌ها خام‌فروشی را می‌زنند اما
# محصولات پایین‌دستی دور زدن راحت‌تری دارند. پیوند: انرژی، معدن، تجارت، صنعت.
#
# state["downstream_policy"] = {
#   "refining":0..1, "petrochemical":0..1, "self_sufficiency":0..1,
#   "value_added":0..1, "last_refinery":turn,
#   "raw_export_share":0..1, "fuel_security":0..1 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("downstream_policy"):
		state["downstream_policy"] = {
			"refining": 0.35, "petrochemical": 0.30, "self_sufficiency": 0.40,
			"value_added": 0.25, "last_refinery": -99,
			"raw_export_share": 0.65, "fuel_security": 0.45,
			"product_exports": 0.10, "refining_capacity": 0.40
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var dp: Dictionary = state["downstream_policy"]
	var econ: Dictionary = state.get("economy", {})
	var trade: Dictionary = state.get("trade", {})
	var resources: Dictionary = state.get("resources", {})
	var energy: Dictionary = state.get("energy_policy", {})
	var industry: Dictionary = state.get("industry", {})

	var refining: float = float(dp.get("refining", 0.35))
	var petchem: float = float(dp.get("petrochemical", 0.30))
	var self_suff: float = float(dp.get("self_sufficiency", 0.40))
	var gdp: float = float(econ.get("gdp", 1.0))

	# ظرفیت پالایش: با سرمایه‌گذاری و فناوری
	var ref_cap: float = clampf(0.20 + refining * 0.55 + self_suff * 0.20, 0.1, 0.98)
	dp["refining_capacity"] = ref_cap

	# امنیت سوخت: هرچه پالایش بیشتر، واردات بنزین کمتر
	var fuel_sec: float = clampf(0.20 + ref_cap * 0.60 + self_suff * 0.20, 0.05, 0.98)
	dp["fuel_security"] = fuel_sec

	# سهم خام‌فروشی: با پتروشیمی/پالایش کم می‌شود
	var raw_share: float = clampf(0.85 - petchem * 0.40 - refining * 0.30 - value_added(dp) * 0.10, 0.15, 0.95)
	dp["raw_export_share"] = raw_share

	# ارزش افزوده و صادرات محصول
	var va: float = clampf(0.10 + petchem * 0.40 + refining * 0.30 + self_suff * 0.15, 0.05, 0.95)
	dp["value_added"] = va
	dp["product_exports"] = clampf(petchem * 0.40 + refining * 0.30, 0.0, 0.90)

	# اثر اقتصادی: خام‌فروشی در برابر تحریم آسیب‌پذیرتر است (درآمد کمتر اما نوسان بیشتر)
	var sanction: float = float(state.get("world", {}).get("sanctions_pressure", 0.3))
	var raw_penalty: float = raw_share * sanction * 0.001
	var downstream_bonus: float = va * 0.0006
	# ممیزی GDP (۱۴۰۵): اثر مداوم از کانال مالک-یکتای sector_boosts (نرخ سالانه؛ ماهانه: ×۱۲)
	var de_boosts: Dictionary = econ.get("sector_boosts", {})
	de_boosts["زنجیرهٔ ارزش انرژی"] = (downstream_bonus - raw_penalty) * 12.0
	econ["sector_boosts"] = de_boosts
	# درآمد ارزی: محصول صادر می‌شود حتی با تحریم
	if va > 0.4:
		# ممیزی ذخایر (۱۴۰۵): ورودی ماهانه به کانال reserve_inflows (مالک: بانک مرکزی)
		var de_infl: Dictionary = econ.get("reserve_inflows", {})
		de_infl["محصولات پالایشی"] = gdp * va * 0.0004
		econ["reserve_inflows"] = de_infl
	state["economy"] = econ

	# خوراک پتروشیمی از منابع گاز/نفت می‌آید
	if resources.has("inventory") and resources["inventory"].has("گاز"):
		# پتروشیمی گاز را مصرف ولی ارزش می‌سازد (شبیه‌سازی ساده)
		pass

	# آلودگی پتروشیمی
	var env: Dictionary = state.get("environment", {})
	env["pollution"] = clampf(float(env.get("pollution", env.get("pollution_level", 0.45))) + petchem * 0.002 - ref_cap * 0.0005, 0.05, 0.95)
	state["environment"] = env

	# رویدادها
	if raw_share > 0.75 and sanction > 0.5 and Deterministic.chance(0.05):
		events.append({"type": "raw_export_loss", "message": "🛢️ وابستگی به خام‌فروشی، ضربه تحریم را سنگین‌تر کرد"})
	elif fuel_sec < 0.30 and Deterministic.chance(0.04):
			var ft_imp: Dictionary = state.get("fuel_transition", {})
			ft_imp["fuel_security"] = clampf(float(ft_imp.get("fuel_security", 0.6)) - 0.02, 0.1, 0.95)
			state["fuel_transition"] = ft_imp
			events.append({"type": "fuel_import", "message": "⛽ وابستگی به واردات بنزین، آسیب‌پذیری انرژی بالا گرفت"})
	elif va > 0.65 and Deterministic.chance(0.03):
		var ri_petro: Dictionary = state.get("economy", {}).get("reserve_inflows", {})
		ri_petro["صادرات پتروشیمی"] = float(state.get("economy", {}).get("gdp", 500e9)) * 0.0005
		state["economy"]["reserve_inflows"] = ri_petro
		events.append({"type": "petrochem_boom", "message": "🏭 صادرات محصول پتروشیمی جهش کرد؛ ارزآوری غیرنفتی بالا رفت"})

	state["downstream_policy"] = dp
	return {"state": state, "events": events}

func value_added(dp: Dictionary) -> float:
	return float(dp.get("value_added", 0.25))

func expand_refining(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var dp: Dictionary = state["downstream_policy"]
	if turn - int(dp.get("last_refinery", -99)) < 6:
		return {"success": false, "reason": "پروژه پالایش هر ۶ نوبت یک بار", "state": state, "events": []}
	var tech: float = float(state.get("technology", {}).get("branch_levels", {}).get("صنعت", 0))
	if tech < 4:
		return {"success": false, "reason": "به فناوری صنعت سطح ۴ نیاز است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.008
	dp["last_refinery"] = turn
	dp["refining"] = clampf(float(dp.get("refining", 0.35)) + 0.15, 0.0, 1.0)
	dp["self_sufficiency"] = clampf(float(dp.get("self_sufficiency", 0.40)) + 0.05, 0.0, 1.0)
	state["economy"] = econ
	state["downstream_policy"] = dp
	return {"success": true, "state": state,
		"events": [{"type": "refinery", "message": "🏗️ فاز جدید پالایشگاه به بهره‌برداری رسید؛ خودکفایی بنزین بالا رفت"}]}

func expand_petrochemical(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var dp: Dictionary = state["downstream_policy"]
	if float(dp.get("petrochemical", 0.30)) >= 0.95:
		return {"success": false, "reason": "ظرفیت پتروشیمی در سقف است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.007
	dp["petrochemical"] = clampf(float(dp.get("petrochemical", 0.30)) + 0.15, 0.0, 1.0)
	state["economy"] = econ
	state["downstream_policy"] = dp
	return {"success": true, "state": state,
		"events": [{"type": "petrochem", "message": "🧪 مجتمع پتروشیمی جدید افتتاح شد؛ ارزش‌افزوده انرژی بالا رفت"}]}

func self_sufficiency_drive(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var dp: Dictionary = state["downstream_policy"]
	dp["self_sufficiency"] = clampf(float(dp.get("self_sufficiency", 0.40)) + 0.15, 0.0, 1.0)
	dp["fuel_security"] = clampf(float(dp.get("fuel_security", 0.45)) + 0.08, 0.0, 1.0)
	state["downstream_policy"] = dp
	return {"success": true, "state": state,
		"events": [{"type": "self_suff", "message": "⛽ طرح خودکفایی بنزین و فرآورده اجرا شد"}]}

func upgrade_value_chain(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var dp: Dictionary = state["downstream_policy"]
	var tech: float = float(state.get("technology", {}).get("branch_levels", {}).get("صنعت", 0))
	if tech < 6:
		return {"success": false, "reason": "به فناوری صنعت سطح ۶ نیاز است", "state": state, "events": []}
	dp["value_added"] = clampf(float(dp.get("value_added", 0.25)) + 0.15, 0.0, 1.0)
	state["downstream_policy"] = dp
	return {"success": true, "state": state,
		"events": [{"type": "value_chain", "message": "⬆️ زنجیره ارزش پتروشیمی به محصولات پیشرفته ارتقا یافت"}]}
