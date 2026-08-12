extends Node
# ────────────────────────────────────────────────────────────────────────────
# تجارت راهبردی و زنجیره تأمین — عمق اقتصاد باز
# تنوع صادرات (وابستگی به نفت)، ذخیره راهبردی واردات (بحران‌های عرضه)، مأموریت
# تجاری (روابط و قراردادها)، امنیت زنجیره تأمین (وابستگی به واردات حیاتی).
# پیوند: بازار کالا، ارز، صنعت، سازمان‌ها، تحریم‌ها.
#
# state["trade_policy"] = { "export_diversity":0..1, "strategic_imports":0..1,
#   "trade_missions":0, "supply_security":0..1 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("trade_policy"):
		state["trade_policy"] = {"export_diversity": 0.3, "strategic_imports": 0.2, "trade_missions": 0, "supply_security": 0.3}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var tp: Dictionary = state["trade_policy"]
	var econ: Dictionary = state.get("economy", {})
	var trade: Dictionary = state.get("trade", {})
	var com: Dictionary = state.get("commodities", {})
	var oil_price := float(com.get("prices", {}).get("نفت", 75.0))
	var diversity := float(tp.get("export_diversity", 0.3))
	var imports := float(tp.get("strategic_imports", 0.2))
	var supply := float(tp.get("supply_security", 0.3))

	# وابستگی به نفت: صادرات نفتی سهم بزرگ دارد
	var oil_share := 0.7 - diversity * 0.5
	trade["oil_export_share"] = clampf(oil_share, 0.1, 0.9)
	# نوسان قیمت نفت با تنوع کم، درآمد را می‌لرزاند
	var volatility := (oil_price - 75.0) / 75.0 * (1.0 - diversity)
	econ["exports"] = float(econ.get("exports", 1.0)) * (1.0 + volatility * 0.05)
	# ذخیره راهبردی واردات: بحران عرضه را مهار می‌کند
	var supply_shock := (1.0 - supply) * 0.01 - imports * 0.005
	if Deterministic.chance(clampf(supply_shock, 0.005, 0.06)):
		econ["gdp"] = float(econ.get("gdp", 1.0)) * 0.995
		econ["inflation"] = clampf(float(econ.get("inflation", 0.08)) + 0.008, 0.0, 1.5)
		events.append({"type": "supply_shock", "message": "⛓️ اختلال زنجیره تأمین جهانی! ذخیره راهبردی%s خسارت را مهار کرد" % (" (ناکافی)" if imports < 0.3 else "")})
	# تحریم‌ها: امنیت زنجیره را می‌شکنند
	var sanctions: int = state.get("diplomacy", {}).get("sanctions", []).size()
	if sanctions > 0:
		supply = clampf(supply - sanctions * 0.01, 0.05, 1.0)
		tp["supply_security"] = supply
	# تنوع صادرات: صنعت صادراتی رشد
	if diversity > 0.5:
		econ["gdp"] = float(econ.get("gdp", 1.0)) * 1.001
	state["trade_policy"] = tp
	state["economy"] = econ
	state["trade"] = trade
	return {"state": state, "events": events}

func export_diversification(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var tp: Dictionary = state["trade_policy"]
	if float(tp.get("export_diversity", 0.3)) >= 0.9:
		return {"success": false, "reason": "تنوع صادرات حداکثری است", "state": state, "events": []}
	state["economy"]["national_debt"] = float(state["economy"].get("national_debt", 0.0)) + float(state["economy"].get("gdp", 1.0)) * 0.003
	tp["export_diversity"] = clampf(float(tp.get("export_diversity", 0.3)) + 0.15, 0.0, 1.0)
	state["trade_policy"] = tp
	return {"success": true, "state": state,
		"events": [{"type": "export_diversity", "message": "📦 صادرات غیرنفتی: صنایع پتروشیمی، کشاورزی و فناوری توسعه یافت؛ وابستگی به نفت کم شد"}]}

func strategic_imports(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var tp: Dictionary = state["trade_policy"]
	if float(tp.get("strategic_imports", 0.2)) >= 0.9:
		return {"success": false, "reason": "ذخیره راهبردی کامل است", "state": state, "events": []}
	state["economy"]["national_debt"] = float(state["economy"].get("national_debt", 0.0)) + float(state["economy"].get("gdp", 1.0)) * 0.002
	tp["strategic_imports"] = clampf(float(tp.get("strategic_imports", 0.2)) + 0.2, 0.0, 1.0)
	state["trade_policy"] = tp
	return {"success": true, "state": state,
		"events": [{"type": "strategic_imports", "message": "📦 ذخیره راهبردی دارو، غلات و قطعات حیاتی تکمیل شد؛ در برابر بحران عرضه ایمن‌تر شدیم"}]}

func trade_mission(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var tp: Dictionary = state["trade_policy"]
	var capital := float(state.get("policies", {}).get("political_capital", 0.0))
	if capital < 1.0:
		return {"success": false, "reason": "سرمایه سیاسی کافی نیست (۱ واحد)", "state": state, "events": []}
	state["policies"]["political_capital"] = capital - 1.0
	state["economy"]["national_debt"] = float(state["economy"].get("national_debt", 0.0)) + float(state["economy"].get("gdp", 1.0)) * 0.001
	tp["trade_missions"] = int(tp.get("trade_missions", 0)) + 1
	state["trade_policy"] = tp
	# قرارداد تازه: صادرات و روابط با کشورهای تصادفی
	state["economy"]["exports"] = float(state["economy"].get("exports", 1.0)) * 1.015
	state["diplomacy"]["influence"] = clampf(float(state["diplomacy"].get("influence", 40.0)) + 1.5, 0.0, 100.0)
	var relations: Dictionary = state.get("diplomacy", {}).get("relations", {})
	if not relations.is_empty():
		var keys := relations.keys()
		var cid := str(keys[Deterministic.next_int_range(0, keys.size() - 1)])
		relations[cid] = clampf(float(relations.get(cid, 50.0)) + 4.0, 0.0, 100.0)
		state["diplomacy"]["relations"] = relations
	return {"success": true, "state": state,
		"events": [{"type": "trade_mission", "message": "🤝 مأموریت تجاری به خارج اعزام شد؛ قرارداد صادراتی تازه امضا شد"}]}

func supply_chain_security(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var tp: Dictionary = state["trade_policy"]
	if float(tp.get("supply_security", 0.3)) >= 0.95:
		return {"success": false, "reason": "امنیت زنجیره تأمین حداکثری است", "state": state, "events": []}
	state["economy"]["national_debt"] = float(state["economy"].get("national_debt", 0.0)) + float(state["economy"].get("gdp", 1.0)) * 0.003
	tp["supply_security"] = clampf(float(tp.get("supply_security", 0.3)) + 0.2, 0.0, 1.0)
	state["trade_policy"] = tp
	return {"success": true, "state": state,
		"events": [{"type": "supply_security", "message": "🔗 زنجیره تأمین امن شد: تولید داخلی قطعات حیاتی و تنوع شرکای تجاری"}]}
