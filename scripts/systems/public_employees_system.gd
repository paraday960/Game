extends BaseSystem
# ۳.۵۷ کارکنان بخش عمومی - تعداد، حقوق، رضایت، کارآمدی، فساد، بهره‌وری، بازنشستگی

func compute(state: Dictionary, tick: int) -> Dictionary:
	var emp = state.get("public_employees", {})
	emp["count"] = emp.get("count", 2000000)
	emp["salary_avg"] = emp.get("salary_avg", 4000.0)
	emp["satisfaction"] = emp.get("satisfaction", 0.55)
	emp["efficiency"] = emp.get("efficiency", 0.60)
	emp["corruption"] = emp.get("corruption", 0.25)
	emp["training_hours"] = emp.get("training_hours", 20.0)
	emp["overtime_rate"] = emp.get("overtime_rate", 0.15)
	emp["absenteeism"] = emp.get("absenteeism", 0.08)
	emp["digital_literacy"] = emp.get("digital_literacy", 0.50)
	emp["retirement_pressure"] = emp.get("retirement_pressure", 0.20)
	emp["union_strength"] = emp.get("union_strength", 0.45)

	var events = []
	var econ = state.get("economy", {})
	var edu = state.get("education", {})
	var pol = state.get("politics", {})
	var admin = state.get("administration", {})
	var judicial = state.get("judicial", {})

	var inflation = econ.get("inflation", 0.08)
	var growth = econ.get("growth_rate", 0.02)
	var corruption_national = pol.get("corruption", 0.30)
	var gdp_pc = econ.get("gdp_per_capita", 5000.0)

	# حقوق - تورم + رشد اما با تاخیر دولتی
	var wage_growth = inflation * 0.6 + growth * 0.3
	emp["salary_avg"] *= (1.0 + wage_growth / 365.0)
	# اثر کسری بودجه - اگر کسری بالا حقوق معوق
	if econ.get("deficit",0.0) > econ.get("government_revenue",1.0)*0.15:
		emp["salary_avg"] *= (1.0 - 0.0001)

	# رضایت = حقوق واقعی + امنیت شغلی + کارآمدی دولت معکوس؟ فساد معکوس
	var real_wage = emp["salary_avg"] / (1.0 + inflation)
	var satisfaction_target = (real_wage / 4000.0)*0.3 + emp["efficiency"]*0.2 + (1.0 - emp["corruption"])*0.25 + (1.0 - emp["overtime_rate"])*0.15 + 0.1
	emp["satisfaction"] = clamp(emp["satisfaction"]*0.96 + satisfaction_target*0.04 - emp["absenteeism"]*0.01, 0.05, 0.95)

	# کارآمدی = آموزش + سواد دیجیتال + رضایت + مدیریت
	var eff_target = emp["digital_literacy"]*0.25 + edu.get("quality",0.55)*0.20 + emp["satisfaction"]*0.25 + admin.get("efficiency",0.60)*0.20 + 0.10
	emp["efficiency"] = clamp(emp["efficiency"]*0.985 + eff_target*0.015, 0.10, 0.95)

	# فساد کارکنان = فساد ملی + نظارت قضایی معکوس + حقوق پایین
	var oversight = judicial.get("rule_of_law",0.60)
	emp["corruption"] = clamp(corruption_national*0.5 + (1.0-oversight)*0.3 + (1.0 - emp["salary_avg"]/5000.0)*0.1 + 0.05, 0.05, 0.70)

	# آموزش
	emp["training_hours"] = clamp(emp["training_hours"] + edu.get("quality",0.55)*0.02, 5.0, 120.0)
	emp["digital_literacy"] = clamp(emp["digital_literacy"] + state.get("technology",{}).get("branches",{}).get("دیجیتال",0.20)*0.001, 0.2, 0.95)

	# اضافه‌کاری - کمبود نیرو
	var needed = state.get("population",{}).get("total",85_000_000.0) / 40.0 # هر 40 نفر 1 کارمند
	var staffing_ratio = float(emp["count"]) / max(needed,1.0)
	emp["overtime_rate"] = clamp((1.0 - staffing_ratio)*0.3 + 0.05, 0.02, 0.50)

	# غیبت - رضایت پایین غیبت بالا
	emp["absenteeism"] = clamp((1.0 - emp["satisfaction"])*0.15 + 0.02, 0.01, 0.25)

	# بازنشستگی - پیری جمعیت
	var elderly = state.get("population",{}).get("age_structure",{}).get("سالمند",0.10)
	emp["retirement_pressure"] = clamp(elderly*0.8 + emp["retirement_pressure"]*0.2, 0.05, 0.60)

	# تشکل‌ها
	emp["union_strength"] = clamp(emp["union_strength"] + (emp["satisfaction"]<0.4 and 1 or 0)*0.001 - (pol.get("tension",0.35))*0.0005, 0.1, 0.85)

	# تعداد کارکنان - رشد جمعیت
	if tick % 90 == 0:
		var target_count = int(state.get("population",{}).get("total",85_000_000.0) / 42.0)
		if emp["count"] < target_count:
			emp["count"] += Deterministic.next_int_range(5000, 15000)
		# بازنشستگی
		emp["count"] = int(emp["count"] * (1.0 - emp["retirement_pressure"]*0.002))

	# رویدادها
	if emp["satisfaction"] < 0.30 and Deterministic.chance(0.014):
		events.append({"type":"public_employee_strike","satisfaction": emp["satisfaction"], "message":"اعتصاب کارکنان دولت - ادارات با حداقل نیرو"})

	if emp["corruption"] > 0.50 and Deterministic.chance(0.010):
		events.append({"type":"bureaucratic_corruption","corruption": emp["corruption"], "message":"فساد خرده‌پا در ادارات - رشوه برای تسریع پرونده"})

	if emp["digital_literacy"] > 0.75 and emp["efficiency"] > 0.75 and tick % 180 == 0 and Deterministic.chance(0.02):
		events.append({"type":"digital_workforce_success","message":"کارکنان دولت دیجیتال شد - میانگین ۸۰ ساعت آموزش سالانه"})

	if emp["union_strength"] > 0.70 and emp["satisfaction"] < 0.40 and Deterministic.chance(0.012):
		events.append({"type":"union_protest","strength": emp["union_strength"], "message":"اتحادیه کارمندان بیانیه تند - تهدید به اعتصاب سراسری"})

	state["public_employees"] = emp
	state["economy"] = econ
	return {"success":true,"state":state,"events":events}
