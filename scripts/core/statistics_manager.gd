extends Node
# ────────────────────────────────────────────────────────────────────────────
# آمار ملی و حاکمیت داده — عمق تصمیم‌گیری مبتنی بر شواهد
# مرکز آمار، ثبت احوال، سرشماری، پایش تورم/بیکاری و داده باز، کیفیت داده‌های
# کشور را تعیین می‌کند. آمار دقیق سیاست‌گذاری را بهتر و فساد را کم می‌کند؛
# آمار نادرست یا دستکاری‌شده باعث خطای سیاست و بحران اعتماد می‌شود.
# پیوند: آموزش، اقتصاد، رفاه، فناوری دیجیتال، شفافیت مدنی.
#
# state["statistics_policy"] = {
#   "census_quality":0..1, "data_infrastructure":0..1, "independence":0..1,
#   "open_data":0..1, "id_coverage":0..1, "last_census":turn,
#   "accuracy":0..1, "trust_in_data":0..1 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("statistics_policy"):
		state["statistics_policy"] = {
			"census_quality": 0.50, "data_infrastructure": 0.40,
			"independence": 0.55, "open_data": 0.30, "id_coverage": 0.85,
			"last_census": -99, "accuracy": 0.75, "trust_in_data": 0.55,
			"underreporting": 0.20
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var sp: Dictionary = state["statistics_policy"]
	var econ: Dictionary = state.get("economy", {})
	var edu: Dictionary = state.get("education", {})
	var digital: Dictionary = state.get("digital_policy", {})
	var media: Dictionary = state.get("media", {})
	var pol: Dictionary = state.get("politics", {})
	var welfare: Dictionary = state.get("welfare", {})

	var census_q := float(sp.get("census_quality", 0.50))
	var infra := float(sp.get("data_infrastructure", 0.40))
	var independence := float(sp.get("independence", 0.55))
	var open_data := float(sp.get("open_data", 0.30))
	var id_cov := float(sp.get("id_coverage", 0.85))
	var digital_cov := float(digital.get("internet_coverage", 0.5))

	# دقت آمار: زیرساخت + استقلال مرکز آمار + پوشش ملی کد + سواد دیجیتال
	var accuracy := clampf(
		0.25 + census_q * 0.20 + infra * 0.20 + independence * 0.20 +
		id_cov * 0.15 + digital_cov * 0.15 + float(edu.get("literacy", 0.85)) * 0.05,
		0.05, 0.99)
	sp["accuracy"] = accuracy
	var underreporting := clampf(1.0 - accuracy + (1.0 - independence) * 0.10, 0.02, 0.80)
	sp["underreporting"] = underreporting

	# اعتماد به آمار رسمی
	var trust_data := clampf(
		0.30 + independence * 0.30 + accuracy * 0.25 + open_data * 0.20 +
		(1.0 - float(pol.get("corruption", 0.30))) * 0.15, 0.05, 0.98)
	sp["trust_in_data"] = trust_data
	media["trust"] = clampf(float(media.get("trust", 0.55)) + (trust_data - 0.55) * 0.003, 0.05, 1.0)
	state["media"] = media

	# خطای سیاست‌گذاری با آمار بد: سیاست‌ها به خطا می‌روند و بودجه هدر می‌شود
	var error_cost := (1.0 - accuracy) * 0.0008
	econ["government_spending"] = float(econ.get("government_spending", 0.0)) + float(econ.get("gdp", 1.0)) * error_cost
	# آمار دقیق هدفمندی یارانه/رفاه را بهتر می‌کند
	if accuracy > 0.70:
		welfare["poverty"] = clampf(float(welfare.get("poverty", 0.15)) - 0.0004, 0.02, 0.80)
		state["welfare"] = welfare
	# داده باز و استقلال، فساد را می‌خشکاند
	if open_data > 0.5:
		pol["corruption"] = clampf(float(pol.get("corruption", 0.30)) - 0.0015, 0.01, 1.0)
		state["politics"] = pol

	# پوشش ثبت احوال با گذشت زمان و دیجیتال بهتر می‌شود
	sp["id_coverage"] = clampf(id_cov + 0.0003 + digital_cov * 0.0002, 0.30, 1.0)
	state["economy"] = econ

	# رویدادها
	if underreporting > 0.55 and Deterministic.chance(0.040):
		pol["trust"] = clampf(float(pol.get("trust", 0.55)) - 0.012, 0.05, 1.0)
		state["politics"] = pol
		events.append({"type": "data_discrepancy", "message": "📊 اختلاف آماری فاش شد! تصمیم‌های گذشته بر اساس داده نادرست گرفته شده بودند"})
	elif trust_data > 0.80 and Deterministic.chance(0.025):
		events.append({"type": "trusted_data", "message": "📈 گزارش‌های شفاف مرکز آمار اعتماد عمومی به سیاست‌گذاری را بالا برد"})
	elif accuracy < 0.30 and Deterministic.chance(0.030):
		events.append({"type": "stats_blackout", "message": "🗂️ سیستم آمار فرسوده؛ سیاست‌گذاری در تاریکی انجام می‌شود"})

	state["statistics_policy"] = sp
	return {"state": state, "events": events}

# ── سرشماری ملی ──
func run_census(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["statistics_policy"]
	if turn - int(sp.get("last_census", -99)) < 10:
		return {"success": false, "reason": "سرشماری ملی هر ۱۰ نوبت یک بار", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["government_spending"] = float(econ.get("government_spending", 0.0)) + float(econ.get("gdp", 1.0)) * 0.002
	sp["last_census"] = turn
	sp["census_quality"] = clampf(float(sp.get("census_quality", 0.50)) + 0.12, 0.0, 1.0)
	sp["accuracy"] = clampf(float(sp.get("accuracy", 0.75)) + 0.04, 0.0, 1.0)
	sp["id_coverage"] = clampf(float(sp.get("id_coverage", 0.85)) + 0.03, 0.0, 1.0)
	state["economy"] = econ
	state["statistics_policy"] = sp
	return {"success": true, "state": state,
		"events": [{"type": "census", "message": "📋 سرشماری ملی انجام شد؛ داده‌های دقیق جمعیت، اشتغال و مسکن به‌روز شد"}]}

# ── تقویت زیرساخت داده (دیتابیس ملی) ──
func build_data_infra(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["statistics_policy"]
	if float(sp.get("data_infrastructure", 0.40)) >= 0.95:
		return {"success": false, "reason": "زیرساخت داده در سقف است", "state": state, "events": []}
	var tech := float(state.get("technology", {}).get("branch_levels", {}).get("دیجیتال", 0))
	if tech < 5:
		return {"success": false, "reason": "به فناوری دیجیتال سطح ۵ نیاز است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["government_spending"] = float(econ.get("government_spending", 0.0)) + float(econ.get("gdp", 1.0)) * 0.003
	sp["data_infrastructure"] = clampf(float(sp.get("data_infrastructure", 0.40)) + 0.15, 0.0, 1.0)
	state["economy"] = econ
	state["statistics_policy"] = sp
	return {"success": true, "state": state,
		"events": [{"type": "data_infra", "message": "🗄️ پایگاه ملی داده و رصدخانه سیاستی راه‌اندازی شد؛ سیاست‌گذاری دقیق‌تر می‌شود"}]}

# ── تضمین استقلال مرکز آمار ──
func guarantee_independence(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["statistics_policy"]
	if float(sp.get("independence", 0.55)) >= 0.95:
		return {"success": false, "reason": "استقلال آمار در سقف است", "state": state, "events": []}
	sp["independence"] = clampf(float(sp.get("independence", 0.55)) + 0.15, 0.0, 1.0)
	sp["trust_in_data"] = clampf(float(sp.get("trust_in_data", 0.55)) + 0.05, 0.0, 1.0)
	state["politics"]["trust"] = clampf(state["politics"].get("trust", 0.55) + 0.008, 0.05, 1.0)
	state["statistics_policy"] = sp
	return {"success": true, "state": state,
		"events": [{"type": "stats_independence", "message": "📜 استقلال مرکز آمار تضمین شد؛ آمار دستکاری‌نشده منتشر می‌شود"}]}

# ── انتشار داده باز ──
func open_data_initiative(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["statistics_policy"]
	if float(sp.get("open_data", 0.30)) >= 0.95:
		return {"success": false, "reason": "داده باز در سقف است", "state": state, "events": []}
	sp["open_data"] = clampf(float(sp.get("open_data", 0.30)) + 0.15, 0.0, 1.0)
	state["politics"]["corruption"] = clampf(state["politics"].get("corruption", 0.30) - 0.008, 0.01, 1.0)
	state["digital_policy"]["egovernment"] = clampf(state["digital_policy"].get("egovernment", 0.30) + 0.01, 0.0, 1.0)
	state["statistics_policy"] = sp
	return {"success": true, "state": state,
		"events": [{"type": "open_data_stats", "message": "🔓 درگاه داده‌های باز راه‌اندازی شد؛ پژوهشگران و رسانه‌ها به آمار رسمی دسترسی دارند"}]}
