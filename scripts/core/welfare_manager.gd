extends Node
# ────────────────────────────────────────────────────────────────────────────
# رفاه و تأمین اجتماعی — عمق شبکه امنیت اجتماعی
# سن بازنشستگی (فشار صندوق در برابر اعتراض بازنشستگان)، سطح بیمه بیکاری،
# یارانه فرزند (جمعیت/پیری جمعیت)، بیمه سلامت. پیوند: کارگری، فراکسیون‌ها
# (بازنشستگان گروه رسانه‌ای)، سالخوردگی جمعیت.
#
# state["welfare_policy"] = { "pension_age":60..70, "unemployment_benefit":0..1,
#   "child_allowance":0..1, "health_coverage":0..1 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("welfare_policy"):
		state["welfare_policy"] = {"pension_age": 65, "unemployment_benefit": 0.4, "child_allowance": 0.2, "health_coverage": 0.6, "last_pension": -99}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var wp: Dictionary = state["welfare_policy"]
	var econ: Dictionary = state.get("economy", {})
	var pop: Dictionary = state.get("population", {})
	var welfare: Dictionary = state.get("welfare", {})
	var pension_age := int(wp.get("pension_age", 65))
	var unemployment_benefit := float(wp.get("unemployment_benefit", 0.4))
	var child_allowance := float(wp.get("child_allowance", 0.2))
	var health_coverage := float(wp.get("health_coverage", 0.6))
	var elderly := float(pop.get("elderly_ratio", pop.get("elderly", 0.12)))

	# فشار صندوق بازنشستگی: سالخوردگی + سن بازنشستگی پایین
	var pension_pressure := elderly * 0.5 + (65.0 - float(pension_age)) * 0.02
	welfare["pension_pressure"] = clampf(pension_pressure, 0.0, 1.0)
	# هزینه رفاه: بیمه بیکاری + یارانه فرزند + پوشش سلامت
	# (بازرسی ۱۴۰۵ — دور نهم) انتقال‌های اجتماعی هزینهٔ مداوم ماهانه‌اند؛ قبلاً خاموش
	# به بدهی شارژ می‌شدند و در بودجه/کسری دیده نمی‌شدند → کانال policy_costs.
	var welfare_cost := unemployment_benefit * 0.004 + child_allowance * 0.003 + health_coverage * 0.005 + pension_pressure * 0.003
	econ["welfare_cost"] = welfare_cost
	var wl_costs: Dictionary = econ.get("policy_costs", {})
	wl_costs["انتقال‌های اجتماعی"] = float(econ.get("gdp", 1.0)) * welfare_cost
	econ["policy_costs"] = wl_costs
	# اثرها: رفاه → رضایت بازنشستگان/بیکاران؛ یارانه فرزند → نرخ تولد
	state["media"]["groups"]["بازنشستگان"]["approval"] = clampf(float(state["media"]["groups"]["بازنشستگان"].get("approval", 52.0)) + (0.6 - pension_pressure) * 2.0, 5.0, 100.0)
	pop["birth_rate"] = float(pop.get("birth_rate", 15.0)) + child_allowance * 1.5
	pop["happiness"] = clampf(float(pop.get("happiness", 0.6)) + unemployment_benefit * 0.002 + child_allowance * 0.001, 0.05, 1.0)
	welfare["gini"] = clampf(float(welfare.get("gini", 0.38)) - (unemployment_benefit + child_allowance) * 0.02, 0.15, 0.8)
	# فشار سنگین → بحران صندوق
	if pension_pressure > 0.8 and (turn - int(welfare.get("last_pension_crisis", -99))) >= 12 and Deterministic.chance(0.12):
		econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * 0.005
		welfare["last_pension_crisis"] = turn
		events.append({"type": "pension_crisis", "message": "⚠️ بحران صندوق بازنشستگی: حقوق بازنشستگان به‌موقع پرداخت نمی‌شود!"})
	state["welfare_policy"] = wp
	state["economy"] = econ
	state["population"] = pop
	state["welfare"] = welfare
	return {"state": state, "events": events}

func set_pension_age(state: Dictionary, age: int, turn: int = -1) -> Dictionary:
	state = ensure(state)
	if age < 60 or age > 70:
		return {"success": false, "reason": "سن بازنشستگی باید ۶۰ تا ۷۰ باشد", "state": state, "events": []}
	if turn < 0:
		turn = int(state.get("time", {}).get("turn", 0))
	var wp: Dictionary = state["welfare_policy"]
	# کول‌داون لچ واقعی (بازرسی latch): کلید last_pension در demographic_policy سال‌ها یتیم بود —
	# بازیکن می‌توانست هر ماه سن بازنشستگی را جابه‌جا کند (نوسان رأی رایگان). مهاجرت به
	# welfare_policy + گارد یک‌ساله: اصلاحات بازنشستگی در دنیای واقعی به هر چرخهٔ انتخاباتی محدود است
	# (هم‌خانواده با last_pension_crisis در همین مدیر و last_drill خواهران).
	if turn - int(wp.get("last_pension", -99)) < 12:
		return {"success": false, "reason": "اصلاح سن بازنشستگی هر ۱۲ ماه یک‌بار ممکن است", "state": state, "events": []}
	wp["last_pension"] = turn
	wp["pension_age"] = age
	state["welfare_policy"] = wp
	# واکنش‌ها: بازنشستگان و کارگران
	var delta := 65 - age
	state["media"]["groups"]["بازنشستگان"]["approval"] = clampf(float(state["media"]["groups"]["بازنشستگان"].get("approval", 52.0)) - float(delta) * 1.5, 5.0, 100.0)
	var lab: Dictionary = state.get("labor", {})
	lab["strike_risk"] = clampf(float(lab.get("strike_risk", 0.2)) + float(delta) * 0.02, 0.05, 0.95)
	state["labor"] = lab
	return {"success": true, "state": state,
		"events": [{"type": "pension_age", "message": "👵 سن بازنشستگی به %s سال تغییر کرد؛ صندوق نفس می‌کشد ولی کارگران ناراضی‌اند" % PersianFormatter.to_persian_digits(str(age))}]}

func set_benefit(state: Dictionary, level: float) -> Dictionary:
	state = ensure(state)
	if level < 0.0 or level > 1.0:
		return {"success": false, "reason": "سطح نامعتبر", "state": state, "events": []}
	var wp: Dictionary = state["welfare_policy"]
	wp["unemployment_benefit"] = level
	state["welfare_policy"] = wp
	return {"success": true, "state": state,
		"events": [{"type": "unemployment_benefit", "message": "💰 بیمه بیکاری به %s٪ تنظیم شد؛ بیکاران آسوده‌ترند ولی انگیزه کار کم می‌شود" % PersianFormatter.to_persian_digits(str(int(level * 100.0)))}]}

func child_allowance(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var wp: Dictionary = state["welfare_policy"]
	if float(wp.get("child_allowance", 0.2)) >= 0.9:
		return {"success": false, "reason": "یارانه فرزند حداکثری است", "state": state, "events": []}
	state["economy"]["national_debt"] = float(state["economy"].get("national_debt", 0.0)) + float(state["economy"].get("gdp", 1.0)) * 0.002
	wp["child_allowance"] = clampf(float(wp.get("child_allowance", 0.2)) + 0.2, 0.0, 1.0)
	state["welfare_policy"] = wp
	return {"success": true, "state": state,
		"events": [{"type": "child_allowance", "message": "👶 یارانه فرزند و مرخصی والدین گسترش یافت؛ جمعیت جوان‌تر می‌شود"}]}

func expand_health_coverage(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var wp: Dictionary = state["welfare_policy"]
	if float(wp.get("health_coverage", 0.6)) >= 0.98:
		return {"success": false, "reason": "پوشش بیمه سلامت حداکثری است", "state": state, "events": []}
	state["economy"]["national_debt"] = float(state["economy"].get("national_debt", 0.0)) + float(state["economy"].get("gdp", 1.0)) * 0.004
	wp["health_coverage"] = clampf(float(wp.get("health_coverage", 0.6)) + 0.15, 0.0, 1.0)
	state["welfare_policy"] = wp
	state["health"]["coverage"] = clampf(float(state["health"].get("coverage", 0.75)) + 0.02, 0.1, 1.0)
	state["media"]["groups"]["بازنشستگان"]["approval"] = clampf(float(state["media"]["groups"]["بازنشستگان"].get("approval", 52.0)) + 1.0, 5.0, 100.0)
	return {"success": true, "state": state,
		"events": [{"type": "health_coverage", "message": "🏥 بیمه سلامت همگانی گسترش یافت؛ درمان برای همه در دسترس‌تر شد"}]}
