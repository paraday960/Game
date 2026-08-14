extends Node
# ────────────────────────────────────────────────────────────────────────────
# بورس اوراق بهادار — عمق بازار سرمایه
# شاخص بورس تحت تأثیر رشد، تورم، ثبات، فساد و اعتماد سرمایه‌گذار است؛
# حباب قیمتی می‌سازد و گاهی می‌ترکد. دولت می‌تواند: عرضه اولیه سهام،
# حمایت از بازار، مالیات بر عایدی سرمایه یا تقویت نهاد ناظر را انتخاب کند.
# پیوند: اقتصاد، سیاست، رسانه، معضلات راهبردی.
#
# state["stock_policy"] = { "policy": "none"|"capgains", "ipos": 0,
#   "bubble": 0..1, "last_crash": turn, "last_support": turn, "watchdog": 0..1 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("stock_policy"):
		state["stock_policy"] = {"policy": "none", "ipos": 0, "bubble": 0.0, "last_crash": -99, "last_support": -99, "watchdog": 0.0}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var sm: Dictionary = state.get("stock_market", {})
	var sp: Dictionary = state["stock_policy"]
	var econ: Dictionary = state.get("economy", {})
	var pol: Dictionary = state.get("politics", {})

	var index := float(sm.get("index", 1000.0))
	var confidence := float(sm.get("investor_confidence", 0.6))
	var stability := float(pol.get("stability", 0.6))
	var corruption := float(pol.get("corruption", 0.3))
	var inflation := float(econ.get("inflation", 0.08))
	var growth := float(econ.get("growth_rate", 0.02))
	var bubble := float(sp.get("bubble", 0.0))

	# روند پایه: سود شرکت‌ها منهای تورم، اعتماد، ثبات
	var momentum := growth * 1.2 - inflation * 0.5 + (confidence - 0.5) * 0.06 + (stability - 0.5) * 0.08
	if str(sp.get("policy", "none")) == "capgains":
		momentum -= 0.035
	if float(sp.get("watchdog", 0.0)) > 0.5:
		momentum -= 0.01  # نظارت سخت‌گیرانه کمی رشد را می‌گیرد ولی شفافیت می‌آورد

	# حباب: رشد بی‌پشتوانه (فساد آن را تغذیه می‌کند)
	if momentum > 0.04:
		bubble = clampf(bubble + (momentum - 0.04) * 2.0 + corruption * 0.02, 0.0, 1.0)
	else:
		bubble = clampf(bubble - 0.02, 0.0, 1.0)

	var shock := Deterministic.next_range(-0.02, 0.02)
	index = maxf(50.0, index * (1.0 + momentum + shock))

	# رژیم بهبود پس از سقوط (بازرسی کلید یتیم ۱۴۰۵): latch «last_crash» قبلاً فقط نوشته
	# می‌شد و هیچ خواننده‌ای نداشت. واقع‌گرایی: اعتماد سرمایه‌گذار تا ~۱۲ دور پس از کرش
	# شکننده می‌ماند و رالی‌های بیرحمانه مکندهٔ اعتماد به تأخیر می‌افتد.
	var months_since_crash: int = turn - int(sp.get("last_crash", -99))
	var post_crash: bool = months_since_crash >= 0 and months_since_crash < 12

	# ترکیدن حباب
	if bubble > 0.55 and Deterministic.chance(0.30):
		var drop := Deterministic.next_range(0.15, 0.30)
		index *= (1.0 - drop)
		sp["bubble"] = 0.0
		sp["last_crash"] = turn
		confidence = clampf(confidence - 0.15, 0.05, 1.0)
		state["media"]["trust"] = clampf(float(state["media"].get("trust", 0.55)) - 0.04, 0.05, 1.0)
		events.append({"type": "market_crash", "message": "📉 سقوط بورس! شاخص %d%% ریخت و اعتماد سرمایه‌گذاران فروپاشید" % int(drop * 100.0)})
	elif corruption > 0.5 and float(sp.get("watchdog", 0.0)) < 0.5 and Deterministic.chance(0.05):
		index *= 0.93
		events.append({"type": "market_scandal", "message": "🚨 رسوایی دستکاری بازار! شاخص ۷٪ سقوط کرد؛ افکار عمومی خواستار ناظر قوی‌ترند"})
	# رالی مثبت — در رژیم بهبود پس از کرش کندتر (اعتماد شکننده)
	elif Deterministic.chance(0.04 * (0.4 if post_crash else 1.0)):
		index *= 1.05
		confidence = clampf(confidence + 0.03, 0.05, 1.0)
		events.append({"type": "market_rally", "message": "📈 رالی بورس! شاخص ۵٪ صعود کرد و سرمایه خارجی به بازار بازگشت"})

	# درآمد مالیات بر عایدی سرمایه (بازرسی ۱۴۰۵ — دور هشتم): قبلاً هم به
	# government_revenue می‌نوشت (فانتوم — روز بعد بازنویسی می‌شد) و هم بدهی
	# را خاموش کم می‌کرد. حالا نرخ ماهانهٔ پاک: مالک خزانه مصرف می‌کند.
	econ["stock_gains_monthly"] = (float(econ.get("gdp", 1.0)) * 0.004 * 0.5) if str(sp.get("policy", "none")) == "capgains" else 0.0

	sm["index"] = index
	sm["investor_confidence"] = confidence
	state["stock_market"] = sm
	sp["bubble"] = bubble
	state["stock_policy"] = sp
	state["economy"] = econ
	return {"state": state, "events": events}

# ── عرضه اولیه سهام یک شرکت دولتی ──
func ipo(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["stock_policy"]
	if int(sp.get("ipos", 0)) >= 5:
		return {"success": false, "reason": "شرکت دولتی قابل عرضه‌ای باقی نمانده است", "state": state, "events": []}
	var sm: Dictionary = state.get("stock_market", {})
	var econ: Dictionary = state.get("economy", {})
	var gdp := float(econ.get("gdp", 1.0))
	var inflow := gdp * 0.03
	econ["government_revenue"] = float(econ.get("government_revenue", 0.0)) + inflow
	econ["national_debt"] = maxf(0.0, float(econ.get("national_debt", 0.0)) - inflow * 0.5)
	sm["index"] = float(sm.get("index", 1000.0)) * 1.03
	sm["listed_companies"] = int(sm.get("listed_companies", 100)) + 1
	sp["ipos"] = int(sp.get("ipos", 0)) + 1
	state["stock_market"] = sm
	state["stock_policy"] = sp
	state["economy"] = econ
	return {"success": true, "state": state,
		"events": [{"type": "ipo", "message": "🏦 عرضه اولیه موفق! یک شرکت دولتی وارد بورس شد؛ خزانه نفس تازه کرد و شاخص رشد کرد"}]}

# ── حمایت دولت از بازار در آستانه سقوط ──
func support_market(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["stock_policy"]
	if turn - int(sp.get("last_support", -99)) < 6:
		return {"success": false, "reason": "صندوق تثبیت هر ۶ نوبت یک بار می‌تواند وارد شود", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	var sm: Dictionary = state.get("stock_market", {})
	var gdp := float(econ.get("gdp", 1.0))
	var cost := gdp * 0.01
	econ["foreign_reserves"] = maxf(0.0, float(econ.get("foreign_reserves", 0.0)) - cost)
	var bubble := float(sp.get("bubble", 0.0))
	sp["bubble"] = bubble * 0.4
	sp["last_support"] = turn
	sm["index"] = float(sm.get("index", 1000.0)) * 1.04
	sm["investor_confidence"] = clampf(float(sm.get("investor_confidence", 0.6)) + 0.06, 0.05, 1.0)
	state["stock_market"] = sm
	state["stock_policy"] = sp
	state["economy"] = econ
	return {"success": true, "state": state,
		"events": [{"type": "market_support", "message": "🛡️ صندوق تثبیت وارد بازار شد؛ شاخص نفس کشید و حباب تخلیه شد"}]}

# ── تغییر سیاست مالیات بر عایدی سرمایه ──
func capgains_tax(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["stock_policy"]
	var new_policy := "none"
	if str(sp.get("policy", "none")) != "capgains":
		new_policy = "capgains"
	sp["policy"] = new_policy
	state["stock_policy"] = sp
	if new_policy == "capgains":
		return {"success": true, "state": state,
			"events": [{"type": "capgains_on", "message": "🧾 مالیات بر عایدی سرمایه تصویب شد؛ هر ماه درآمد تازه به خزانه می‌رسد ولی بازار سرد می‌شود"}]}
	return {"success": true, "state": state,
		"events": [{"type": "capgains_off", "message": "📊 مالیات بر عایدی سرمایه لغو شد؛ معامله‌گران نفس راحتی کشیدند"}]}

# ── تقویت نهاد ناظر بازار ──
func watchdog(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["stock_policy"]
	if float(sp.get("watchdog", 0.0)) >= 0.95:
		return {"success": false, "reason": "نهاد ناظر بازار حداکثری است", "state": state, "events": []}
	var sm: Dictionary = state.get("stock_market", {})
	var econ: Dictionary = state.get("economy", {})
	sp["watchdog"] = clampf(float(sp.get("watchdog", 0.0)) + 0.5, 0.0, 1.0)
	sm["transparency"] = clampf(float(sm.get("transparency", 0.55)) + 0.1, 0.05, 1.0)
	sm["regulation"] = clampf(float(sm.get("regulation", 0.6)) + 0.1, 0.05, 1.0)
	state["politics"]["corruption"] = clampf(float(state["politics"].get("corruption", 0.3)) - 0.01, 0.01, 1.0)
	state["stock_market"] = sm
	state["stock_policy"] = sp
	state["economy"] = econ
	return {"success": true, "state": state,
		"events": [{"type": "watchdog", "message": "🔍 نهاد ناظر بازار تقویت شد؛ دستکاری‌ها لو می‌روند و شفافیت رشد می‌کند"}]}
