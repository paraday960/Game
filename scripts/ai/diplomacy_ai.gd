extends BaseAI
# هوش دیپلماسی و روابط بین‌الملل - ۳.۱۴.۷ - دترمینستیک و اتمی

func decide(state: Dictionary, tick: int) -> Array:
	var dip = state.get("diplomacy", {})
	var cmds = []

	# بدترین رابطه → تلاش برای بهبود
	var relations = dip.get("relations", {})
	var worst_key = ""
	var worst_val = 1000
	for k in relations.keys():
		if relations[k] < worst_val:
			worst_val = relations[k]
			worst_key = k

	if worst_key != "" and worst_val < 25:
		cmds.append(GameCommand.create_diplomacy_action(worst_key, "improve_relations"))

	# تحریم‌های ورودی زیاد → مذاکره با یکی از تحریم‌کنندگان معتبر
	if dip.get("sanctions", []).size() > 2:
		var sanction_target = worst_key
		for sanction in dip.get("sanctions", []):
			if sanction is Dictionary and sanction.get("by", "foreign") != "player" and relations.has(sanction.get("target", "")):
				sanction_target = sanction["target"]
				break
		if sanction_target != "":
			cmds.append(GameCommand.create_diplomacy_action(sanction_target, "negotiate_sanctions"))

	# --- لایه عمیق دوم: تحلیل چندسناریویی و پیش‌بینی ---
	var _future_risk = 0.0
	var _trend = 0.0
	var _diag = diagnose(state)
	var _health = float(_diag.get("health",0.5))
	var _urgency = float(_diag.get("urgency",0.0))

	# پیش‌بینی ۳ ماه آینده با نرخ فعلی
	var _current_val = float(_diag.get("value",0.5))
	var _target = float(_diag.get("target",0.6))
	if _health < 0.45:
		_future_risk = _urgency * 1.5 + (1.0 - _health)*0.5
		_trend = -0.02 if _current_val < _target else 0.01

	# تحلیل ریشه‌ای - چرا شاخص پایین است؟
	var _root_causes = []
	var _econ = state.get("economy",{})
	var _pol = state.get("politics",{})
	var _infra = state.get("infrastructure",{})
	if float(_pol.get("corruption",0.30)) > 0.50:
		_root_causes.append("فساد")
	if float(_infra.get("quality",0.55)) < 0.45:
		_root_causes.append("زیرساخت فرسوده")
	if float(_econ.get("unemployment",0.08)) > 0.15:
		_root_causes.append("بیکاری")
	if float(state.get("population",{}).get("happiness",0.60)) < 0.45:
		_root_causes.append("نارضایتی")

	# اگر ریسک آینده بالا، حتی اگر اورژانسی فعلی کم باشد اقدام کن
	if _future_risk > 0.60 and _urgency < 0.18:
		var _preventive = build_budget_command(state, _diag.get("budget_key", "ذخیره"))
		if _preventive != null:
			cmds.append(_preventive)

	# تحلیل هزینه-فایده - آیا بودجه دادن به این سیستم ROI دارد؟
	var _roi = _health * 0.5 + _urgency*0.5
	if _roi < 0.35 and cmds.is_empty():
		# حتی اگر ROI کم، اگر بحران انسانی است اقدام کن
		if "diplomacy" in ["health","education","welfare","food_security","citizens"]:
			var _emergency = build_budget_command(state, "رفاه")
			if _emergency != null:
				cmds.append(_emergency)

	# هم‌افزایی با سیستم‌های دیگر - اگر این سیستم وابسته به دیگری است
	var _interdependency = state.get("interdependency",{})
	if not _interdependency.is_empty() and _interdependency.get("bottlenecks",[]).size() > 2:
		# گلوگاه چندگانه - اولویت به رفع گلوگاه اصلی
		if _diag.get("metric_path","").begins_with("infrastructure") or _diag.get("metric_path","").begins_with("energy"):
			var _bottleneck_cmd = build_budget_command(state, "زیرساخت")
			if _bottleneck_cmd != null and cmds.size() < 2:
				cmds.append(_bottleneck_cmd)

	# دکترین - اگر نظامی یا امنیتی
	if "diplomacy" in ["military","security","intelligence","security_forces"]:
		var _mil = state.get("military",{})
		if float(_mil.get("readiness",0.70)) < 0.50 and float(_mil.get("war_exhaustion",0.0)) < 0.30:
			# پیشنهاد رزمایش
			if not state.get("policies",{}).get("active",{}).has("military_drill"):
				cmds.append(GameCommand.create_policy_change("military_drill", true))

	# محدودیت - حداکثر ۳ فرمان در هر تیک برای جلوگیری از اسپم بودجه
	if cmds.size() > 3:
		cmds = cmds.slice(0, 3)



	# --- لایه عمیق دوم: تحلیل چندسناریویی و پیش‌بینی ---
	_future_risk = 0.0
	_trend = 0.0
	_diag = diagnose(state)
	_health = float(_diag.get("health",0.5))
	_urgency = float(_diag.get("urgency",0.0))

	# پیش‌بینی ۳ ماه آینده با نرخ فعلی
	_current_val = float(_diag.get("value",0.5))
	_target = float(_diag.get("target",0.6))
	if _health < 0.45:
		_future_risk = _urgency * 1.5 + (1.0 - _health)*0.5
		_trend = -0.02 if _current_val < _target else 0.01

	# تحلیل ریشه‌ای - چرا شاخص پایین است؟
	_root_causes = []
	_econ = state.get("economy",{})
	_pol = state.get("politics",{})
	_infra = state.get("infrastructure",{})
	if float(_pol.get("corruption",0.30)) > 0.50:
		_root_causes.append("فساد")
	if float(_infra.get("quality",0.55)) < 0.45:
		_root_causes.append("زیرساخت فرسوده")
	if float(_econ.get("unemployment",0.08)) > 0.15:
		_root_causes.append("بیکاری")
	if float(state.get("population",{}).get("happiness",0.60)) < 0.45:
		_root_causes.append("نارضایتی")

	# اگر ریسک آینده بالا، حتی اگر اورژانسی فعلی کم باشد اقدام کن
	if _future_risk > 0.60 and _urgency < 0.18:
		var _preventive = build_budget_command(state, _diag.get("budget_key", "ذخیره"))
		if _preventive != null:
			cmds.append(_preventive)

	# تحلیل هزینه-فایده - آیا بودجه دادن به این سیستم ROI دارد؟
	_roi = _health * 0.5 + _urgency*0.5
	if _roi < 0.35 and cmds.is_empty():
		# حتی اگر ROI کم، اگر بحران انسانی است اقدام کن
		if "diplomacy" in ["health","education","welfare","food_security","citizens"]:
			var _emergency = build_budget_command(state, "رفاه")
			if _emergency != null:
				cmds.append(_emergency)

	# هم‌افزایی با سیستم‌های دیگر - اگر این سیستم وابسته به دیگری است
	_interdependency = state.get("interdependency",{})
	if not _interdependency.is_empty() and _interdependency.get("bottlenecks",[]).size() > 2:
		# گلوگاه چندگانه - اولویت به رفع گلوگاه اصلی
		if _diag.get("metric_path","").begins_with("infrastructure") or _diag.get("metric_path","").begins_with("energy"):
			var _bottleneck_cmd = build_budget_command(state, "زیرساخت")
			if _bottleneck_cmd != null and cmds.size() < 2:
				cmds.append(_bottleneck_cmd)

	# دکترین - اگر نظامی یا امنیتی
	if "diplomacy" in ["military","security","intelligence","security_forces"]:
		var _mil = state.get("military",{})
		if float(_mil.get("readiness",0.70)) < 0.50 and float(_mil.get("war_exhaustion",0.0)) < 0.30:
			# پیشنهاد رزمایش
			if not state.get("policies",{}).get("active",{}).has("military_drill"):
				cmds.append(GameCommand.create_policy_change("military_drill", true))

	# محدودیت - حداکثر ۳ فرمان در هر تیک برای جلوگیری از اسپم بودجه
	if cmds.size() > 3:
		cmds = cmds.slice(0, 3)


	return cmds

func evaluate(state: Dictionary) -> float:
	var dip = state.get("diplomacy", {})
	var avg = 0.0
	var relations = dip.get("relations", {})
	if relations.size() > 0:
		for v in relations.values():
			avg += v
		avg /= relations.size()
	return clamp(avg / 100.0, 0.0, 1.0) * 0.6 + clamp(dip.get("influence", 40.0) / 100.0, 0.0, 1.0) * 0.4
