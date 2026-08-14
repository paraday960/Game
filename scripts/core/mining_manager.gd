extends Node
# ────────────────────────────────────────────────────────────────────────────
# معدن و صنایع استخراجی — عمق زیرزمین و زنجیره ارزش
# استخراج سنگ‌آهن، مس، عناصر راهبردی و زغال، فرآوری در داخل (به‌جای خام‌فروشی)،
# ایمنی معدن و آلودگی معادن. بازیکن می‌تواند معدن توسعه دهد، فرآوری بومی را
# الزامی کند، ایمنی را بالا ببرد و معادن کوچک غیرمجاز را ساماندهی کند.
# پیوند: منابع، صنعت، انرژی، محیط‌زیست، کارگری، اقتصاد، فناوری.
#
# state["mining_policy"] = {
#   "exploration":0..1, "processing":0..1, "safety":0..1, "formalization":0..1,
#   "last_mine":turn, "last_refinery":turn, "output":0, "reserves":0..1 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("mining_policy"):
		state["mining_policy"] = {
			"exploration": 0.30, "processing": 0.25, "safety": 0.40,
			"formalization": 0.35, "last_mine": -99, "last_refinery": -99,
			"output": 0.0, "reserves": 0.65, "accident_risk": 0.30,
			"raw_export_share": 0.70
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var mp: Dictionary = state["mining_policy"]
	var econ: Dictionary = state.get("economy", {})
	var resources: Dictionary = state.get("resources", {})
	var industry: Dictionary = state.get("industry", {})
	var env: Dictionary = state.get("environment", {})
	var labor: Dictionary = state.get("labor", {})
	var tech: Dictionary = state.get("technology", {})

	var exploration := float(mp.get("exploration", 0.30))
	var processing := float(mp.get("processing", 0.25))
	var safety := float(mp.get("safety", 0.40))
	var formal := float(mp.get("formalization", 0.35))
	var gdp := float(econ.get("gdp", 1.0))

	# ذخایر: با اکتشاف بالا می‌رود؛ با استخراج مستهلک می‌شود
	var reserves := float(mp.get("reserves", 0.65))
	reserves = clampf(reserves + exploration * 0.0015 - 0.0008, 0.10, 1.0)
	mp["reserves"] = reserves

	# تولید: ذخایر + اکتشاف + استخراج رسمی
	var output := (0.4 + reserves + exploration * 0.3 + formal * 0.2)
	mp["output"] = output

	# خام‌فروشی در برابر فرآوری داخل
	var raw_share := clampf(0.85 - processing * 0.6, 0.15, 0.90)
	mp["raw_export_share"] = raw_share
	var value_added := 1.0 + processing * 1.5  # ارزش افزوده فرآوری
	var mining_gdp := gdp * 0.025 * output * value_added
	# ممیزی GDP (۱۴۰۵): مشارکت مداوم معدن از کانال مالک-یکتای sector_boosts (نرخ سالانه؛ ×۱۲)
	var min_boosts: Dictionary = econ.get("sector_boosts", {})
	min_boosts["معدن"] = 0.025 * output * value_added / 100.0 * 12.0
	econ["sector_boosts"] = min_boosts
	state["economy"] = econ

	# منابع معدنی: آهن/مس بیشتر، مواد صنعتی بیشتر
	if resources.has("inventory"):
		var tech_mult := 0.8 + float(tech.get("branch_levels", {}).get("صنعت", 5)) / 30.0
		resources["inventory"]["آهن"] = clampf(float(resources["inventory"].get("آهن", 60.0)) + output * 0.08 * tech_mult, 0.0, 150.0)
		resources["inventory"]["مس"] = clampf(float(resources["inventory"].get("مس", 50.0)) + output * 0.05 * tech_mult, 0.0, 150.0)
		resources["inventory"]["مواد_صنعتی"] = clampf(float(resources["inventory"].get("مواد_صنعتی", 65.0)) + processing * 0.06, 0.0, 150.0)
		state["resources"] = resources

	# صنعت: فرآوری مواد معدنی به صنعت کمک می‌کند
	industry["output"] = clampf(float(industry.get("output", 100.0)) + processing * 0.05, 10.0, 200.0)
	industry["capacity_usage"] = clampf(float(industry.get("capacity_usage", 0.75)) + output * 0.0005, 0.3, 0.98)
	state["industry"] = industry

	# اشتغال و اتحادیه‌ها (ایمنی پایین → نارضایتی کارگری)
	econ["unemployment"] = clampf(float(econ.get("unemployment", 0.08)) - output * 0.0003, 0.02, 0.30)
	state["economy"] = econ
	# ریسک حادثه: ایمنی کم + معادن غیررسمی زیاد
	var risk := clampf(0.65 - safety * 0.45 - formal * 0.15, 0.05, 0.80)
	mp["accident_risk"] = risk
	if risk > 0.55:
		if state["media"]["groups"].has("روستاییان"):
			state["media"]["groups"]["روستاییان"]["approval"] = clampf(
				float(state["media"]["groups"]["روستاییان"].get("approval", 50.0)) - 0.05, 5.0, 100.0)

	# آلودگی معدن: استخراج بالا بدون فرآوری سبز
	var pollution := output * 0.15 - processing * 0.03
	env["pollution"] = clampf(float(env.get("pollution", 0.4)) + pollution * 0.001, 0.05, 1.0)
	state["environment"] = env

	# رویدادها
	if risk > 0.60 and Deterministic.chance(0.05):
		state["politics"]["trust"] = clampf(state["politics"].get("trust", 0.55) - 0.012, 0.05, 1.0)
		events.append({"type": "mine_accident", "message": "⛏️ حادثه در یک معدن! ایمنی پایین و معادن غیرمجاز قربانی گرفت"})
	elif processing > 0.65 and Deterministic.chance(0.03):
		events.append({"type": "mining_value_chain", "message": "🏭 زنجیره فرآوری مواد معدنی کامل شد؛ خام‌فروشی جای خود را به صادرات فرآورده داد"})
	elif output > 0.80 and Deterministic.chance(0.025):
		events.append({"type": "mining_boom", "message": "💎 کشف ذخایر جدید معدنی؛ تولید و اشتغال معدن رشد کرد"})

	state["mining_policy"] = mp
	return {"state": state, "events": events}

# ── اکتشاف و توسعه معدن ──
func develop_mine(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var mp: Dictionary = state["mining_policy"]
	if turn - int(mp.get("last_mine", -99)) < 5:
		return {"success": false, "reason": "توسعه معدن هر ۵ نوبت یک بار", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.006
	mp["last_mine"] = turn
	mp["exploration"] = clampf(float(mp.get("exploration", 0.30)) + 0.12, 0.0, 1.0)
	mp["reserves"] = clampf(float(mp.get("reserves", 0.65)) + 0.05, 0.0, 1.0)
	econ["unemployment"] = clampf(float(econ.get("unemployment", 0.08)) - 0.0005, 0.02, 0.30)
	state["economy"] = econ
	state["mining_policy"] = mp
	return {"success": true, "state": state,
		"events": [{"type": "mine_develop", "message": "⛏️ عملیات اکتشاف و توسعه معدن جدید آغاز شد؛ ذخایر و اشتغال رشد می‌کند"}]}

# ── احداث واحد فرآوری داخل کشور ──
func build_refinery(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var mp: Dictionary = state["mining_policy"]
	if turn - int(mp.get("last_refinery", -99)) < 7:
		return {"success": false, "reason": "احداث کارخانه فرآوری هر ۷ نوبت یک بار", "state": state, "events": []}
	var tech_level := float(state.get("technology", {}).get("branch_levels", {}).get("صنعت", 0))
	if tech_level < 6:
		return {"success": false, "reason": "به فناوری صنعت سطح ۶ نیاز است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.008
	mp["last_refinery"] = turn
	mp["processing"] = clampf(float(mp.get("processing", 0.25)) + 0.13, 0.0, 1.0)
	state["economy"] = econ
	state["mining_policy"] = mp
	return {"success": true, "state": state,
		"events": [{"type": "refinery", "message": "🏭 کارخانه فرآوری مواد معدنی افتتاح شد؛ خام‌فروشی کم و ارزش افزوده بیشتر شد"}]}

# ── ارتقای ایمنی معادن ──
func improve_safety(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var mp: Dictionary = state["mining_policy"]
	if float(mp.get("safety", 0.40)) >= 0.95:
		return {"success": false, "reason": "ایمنی معادن در سقف است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.002
	mp["safety"] = clampf(float(mp.get("safety", 0.40)) + 0.15, 0.0, 1.0)
	state["economy"] = econ
	state["mining_policy"] = mp
	return {"success": true, "state": state,
		"events": [{"type": "mine_safety", "message": "🦺 استانداردهای ایمنی معادن ارتقا یافت؛ از حوادث کاسته می‌شود"}]}

# ── ساماندهی معادن کوچک و غیرمجاز ──
func formalize_mines(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var mp: Dictionary = state["mining_policy"]
	if float(mp.get("formalization", 0.35)) >= 0.95:
		return {"success": false, "reason": "ساماندهی معادن در سقف است", "state": state, "events": []}
	mp["formalization"] = clampf(float(mp.get("formalization", 0.35)) + 0.15, 0.0, 1.0)
	state["shadow"]["size"] = clampf(state["shadow"].get("size", 0.18) - 0.005, 0.03, 0.55)
	mp["accident_risk"] = clampf(float(mp.get("accident_risk", 0.30)) - 0.05, 0.05, 0.80)
	state["mining_policy"] = mp
	return {"success": true, "state": state,
		"events": [{"type": "formalize", "message": "📋 معادن کوچک مقیاس ساماندهی شدند؛ قاچاق مواد معدنی و حوادث غیررسمی کاهش یافت"}]}
