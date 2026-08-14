extends Node
# ────────────────────────────────────────────────────────────────────────────
# زیرساخت و نگهداری — عمق سرمایه فیزیکی
# نگهداری در برابر توسعه‌ی جدید: بی‌توجهی به نگهداری، زیرساخت را می‌پوساند
# (خاموشی، قطع آب، تصادف جاده‌ای) و اقتصاد را می‌خورد. بازیکن سهم بودجه
# نگهداری و اولویت توسعه (جاده/برق/آب/مخابرات) را انتخاب می‌کند.
#
# state["infra_policy"] = { "maintenance":0..1, "focus":"roads"|"power"|"water"|"telecom",
#   "decay":0..1, "events_count":0 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("infra_policy"):
		state["infra_policy"] = {"maintenance": 0.4, "focus": "roads", "decay": 0.3, "events_count": 0}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var ip: Dictionary = state["infra_policy"]
	var infra: Dictionary = state.get("infrastructure", {})
	var econ: Dictionary = state.get("economy", {})
	var pop: Dictionary = state.get("population", {})
	var maintenance := float(ip.get("maintenance", 0.4))
	var focus := str(ip.get("focus", "roads"))
	var decay := float(ip.get("decay", 0.3))

	# پوسیدگی طبیعی − نگهداری
	decay = clampf(decay + 0.02 - maintenance * 0.035, 0.05, 0.95)
	ip["decay"] = decay

	# کیفیت هر بخش: نگهداری + تمرکز
	var base := 0.55 + maintenance * 0.2
	var roads := clampf(float(infra.get("roads_quality", 0.6)) + (base - 0.6) * 0.1 + (0.04 if focus == "roads" else 0.0) - decay * 0.05, 0.1, 1.0)
	var power := clampf(float(infra.get("power_grid", infra.get("electricity", 0.65))) + (base - 0.65) * 0.1 + (0.04 if focus == "power" else 0.0) - decay * 0.05, 0.1, 1.0)
	var water := clampf(float(infra.get("water", 0.7)) + (base - 0.7) * 0.1 + (0.04 if focus == "water" else 0.0) - decay * 0.05, 0.1, 1.0)
	infra["roads_quality"] = roads
	infra["power_grid"] = power
	infra["electricity"] = power
	infra["water"] = water
	# quality و telecom مالک یکتایشان infrastructure_system روزانه است؛ این مدیر فقط سیاست
	# maintenance/focus را ذخیره می‌کند و سیستم روزانه اثرش را اعمال می‌کند (رفع shadow-write:
	# قبلاً هر ماه quality از میانگین مؤلفه‌ها بازنویسی می‌شد و دینامیک فرسودگی سیستم پاک می‌گشت)
	state["infrastructure"] = infra

	# رویداد پوسیدگی: اگر نگهداری ضعیف و پوسیدگی بالا
	if maintenance < 0.3 and decay > 0.6 and Deterministic.chance(0.1):
		econ["gdp"] = float(econ.get("gdp", 1.0)) * 0.995
		pop["happiness"] = clampf(float(pop.get("happiness", 0.6)) - 0.015, 0.05, 1.0)
		ip["events_count"] = int(ip.get("events_count", 0)) + 1
		events.append({"type": "infra_failure", "message": "⚠️ شکست زیرساخت: قطع برق/آب و تصادفات جاده‌ای! نگهداری نادیده گرفته شده بود"})

	# نگهداری خوب → اقتصاد روان‌تر
	# ممیزی GDP (۱۴۰۵): اثر مداوم از کانال مالک-یکتای sector_boosts (نرخ سالانه؛ ×۱۲)
	var inf_boosts: Dictionary = econ.get("sector_boosts", {})
	inf_boosts["نگهداری زیرساخت"] = (maintenance * 0.0008 - decay * 0.001) * 12.0
	econ["sector_boosts"] = inf_boosts
	state["infra_policy"] = ip
	state["economy"] = econ
	state["population"] = pop
	return {"state": state, "events": events}

func set_maintenance(state: Dictionary, level: float) -> Dictionary:
	state = ensure(state)
	if level < 0.0 or level > 1.0:
		return {"success": false, "reason": "سطح نامعتبر", "state": state, "events": []}
	var ip: Dictionary = state["infra_policy"]
	ip["maintenance"] = level
	state["infra_policy"] = ip
	state["economy"]["national_debt"] = float(state["economy"].get("national_debt", 0.0)) + float(state["economy"].get("gdp", 1.0)) * level * 0.003
	return {"success": true, "state": state,
		"events": [{"type": "maintenance", "message": "🔧 سهم نگهداری زیرساخت به %s٪ تنظیم شد؛ پوسیدگی مهار می‌شود ولی بدهی می‌آورد" % PersianFormatter.to_persian_digits(str(int(level * 100.0)))}]}

func set_focus(state: Dictionary, focus: String) -> Dictionary:
	state = ensure(state)
	if not ["roads", "power", "water", "telecom"].has(focus):
		return {"success": false, "reason": "اولویت نامعتبر", "state": state, "events": []}
	var ip: Dictionary = state["infra_policy"]
	ip["focus"] = focus
	state["infra_policy"] = ip
	var names := {"roads": "جاده و حمل‌ونقل", "power": "شبکه برق", "water": "آب و فاضلاب", "telecom": "مخابرات و اینترنت"}
	return {"success": true, "state": state,
		"events": [{"type": "infra_focus", "message": "🎯 اولویت توسعه زیرساخت: «%s»" % names[focus]}]}
