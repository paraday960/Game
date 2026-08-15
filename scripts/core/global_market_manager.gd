extends Node
# ── بازار مالی جهانی (عمق‌بخشی ۱۱) ────────────────────────────────────────
# اقتصاد جهانی فقط کالا نیست؛ شاخص‌های مالی هم هستند که به رویدادهای جهان
# واکنش نشان می‌دهند (مثل ۲۰۰۸ یا ۲۰۱۴):
#   - world_stock_index: شاخص سهام جهانی (میانگین وزنی بازارهای بزرگ)
#   - usd_index: شاخص دلار (قدرت دلار در برابر سبد ارزها)
#   - risk_sentiment: احساس ریسک جهانی (۰..۱) — در بحران بالا می‌رود
# این شاخص‌ها از بحران‌های فعالِ world_scope اثر می‌گیرند و روی FDI و
# اعتماد سرمایه‌گذار داخلی اثر می‌گذارند.

const BASE_INDEX := 1000.0
const BASE_USD := 100.0

func ensure(state: Dictionary) -> Dictionary:
	if not state.has("global_market") or not state["global_market"] is Dictionary:
		state["global_market"] = {
			"world_stock_index": BASE_INDEX,
			"usd_index": BASE_USD,
			"risk_sentiment": 0.30,
			"history": [],
			"crash_recent": false,
			"last_crash_turn": -99
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var gm: Dictionary = state["global_market"]
	var world: Dictionary = state.get("world", {})
	var wars_count: int = world.get("wars", {}).size() + world.get("npc_wars", {}).size()
	var commodities: Dictionary = state.get("commodities", {}).get("prices", {})

	# ── عوامل بنیادی ──
	# جنگ‌های زیاد = ریسک بالا + شاخص پایین (مثل ۱۹۱۴ یا ۲۰۰۱)
	# شاخص‌های کالا: نفت گران = تورم جهانی = فشار بر شاخص (مثل ۱۹۷۳)
	var stock_drift := 0.0
	var usd_drift := 0.0
	var risk := float(gm.get("risk_sentiment", 0.30))

	# جنگ‌ها
	stock_drift -= float(wars_count) * 0.35
	risk = clampf(risk + float(wars_count) * 0.01, 0.05, 0.95)

	# نفت گران → شاخص جهانی تحت فشار (هزینه انرژی) ولی دلار تقویت (نفت دلاری)
	var oil := float(commodities.get("نفت", 75.0))
	if oil > 100.0:
		stock_drift -= (oil - 100.0) * 0.05
		usd_drift += (oil - 100.0) * 0.04
	elif oil < 45.0:
		stock_drift += (45.0 - oil) * 0.02
		usd_drift -= (45.0 - oil) * 0.03

	# ── واکنش به بحران‌های فعال جهانی (world_scope) ──
	# بحران مالی/بانکی/نفتی → شاخص سقوط می‌کند و ریسک می‌پرد
	var active_chain_crash := false
	for c in state.get("events_active", []):
		var ctype := str(c.get("type", ""))
		if ctype in ["oil_shock_world", "chokepoint_chain"]:
			stock_drift -= 1.2
			risk = clampf(risk + 0.08, 0.05, 0.95)
			active_chain_crash = true
		elif ctype == "banking_chain":
			stock_drift -= 2.0
			risk = clampf(risk + 0.12, 0.05, 0.95)
			active_chain_crash = true

	# شوک تصادفی بزرگ (بحران مالی جهانی، رونق فناوری) — هر ~۱۵ ماه یک‌بار
	var recent_crash := turn - int(gm.get("last_crash_turn", -99)) < 12
	if not active_chain_crash and not recent_crash and Deterministic.chance(0.07):
		var r := Deterministic.next_float()
		if r < 0.45:
			# بحران مالی جهانی
			stock_drift -= 6.0
			risk = clampf(risk + 0.20, 0.05, 0.95)
			gm["crash_recent"] = true
			gm["last_crash_turn"] = turn
			events.append({"type": "global_financial_crisis",
				"message": "🌍 بحران مالی جهانی! شاخص سهام بازارهای بزرگ سقوط کرد و هراس به وال‌استریت تا توکیو رسید"})
		elif r < 0.70:
			# رونق فناوری
			stock_drift += 3.5
			risk = clampf(risk - 0.10, 0.05, 0.95)
			events.append({"type": "global_tech_rally",
				"message": "📈 رونق جهانی فناوری! شاخص سهام به لطف هوش مصنوعی و تراشه به اوج رسید"})
		elif r < 0.85:
			# بحران ارزی در بازارهای نوظهور
			usd_drift += 2.5
			stock_drift -= 1.5
			risk = clampf(risk + 0.08, 0.05, 0.95)
			events.append({"type": "emerging_market_crisis",
				"message": "💱 بحران ارزی در بازارهای نوظهور؛ دلار جهش کرد و سرمایه از آسیا و آمریکای لاتین فرار کرد"})
		else:
			# تنش ژئوپلیتیک
			stock_drift -= 2.0
			risk = clampf(risk + 0.06, 0.05, 0.95)
			events.append({"type": "geopolitical_tension",
				"message": "⚔️ تنش ژئوپلیتیک جهانی؛ بازارها محتاط شدند و طلا رکورد زد"})

	# ── نویز روزانهٔ واقعی ──
	stock_drift += Deterministic.next_range(-0.8, 0.8)
	usd_drift += Deterministic.next_range(-0.4, 0.4)

	# ── اعمال ──
	var index := float(gm.get("world_stock_index", BASE_INDEX))
	var usd := float(gm.get("usd_index", BASE_USD))
	index = maxf(150.0, index * (1.0 + stock_drift / 100.0))
	usd = maxf(50.0, usd * (1.0 + usd_drift / 100.0))
	gm["world_stock_index"] = index
	gm["usd_index"] = usd
	gm["risk_sentiment"] = risk

	# تاریخچه (محدود)
	var history: Array = gm.get("history", [])
	history.append({"turn": turn, "index": index, "usd": usd})
	while history.size() > 60:
		history.pop_front()
	gm["history"] = history
	gm["crash_recent"] = active_chain_crash or (turn - int(gm.get("last_crash_turn", -99)) < 6)

	state["global_market"] = gm

	# ── اثر روی اقتصاد داخلی ──
	# شاخص جهانی ضعیف/ریسک بالا → سرمایه خارجی (FDI) کم می‌شود
	var econ: Dictionary = state.get("economy", {})
	var fdi_effect := clampf((index / BASE_INDEX - 1.0) * 0.4 - (risk - 0.3) * 0.5, -0.06, 0.06)
	econ["fdi_global_factor"] = fdi_effect
	# اعتماد سرمایه‌گذار داخلی از جو جهانی اثر می‌گیرد
	var sm: Dictionary = state.get("stock_market", {})
	var confidence := float(sm.get("investor_confidence", 0.6))
	confidence = clampf(confidence + (index / BASE_INDEX - 1.0) * 0.05 - (risk - 0.3) * 0.10, 0.10, 0.95)
	sm["investor_confidence"] = confidence
	state["stock_market"] = sm
	state["economy"] = econ

	return {"state": state, "events": events}
