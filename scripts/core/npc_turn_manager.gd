extends RefCounted
class_name NpcTurnManager
# مدیریت نوبت کشورهای غیربازیکن — بازی کاملاً نوبتی:
#   فاز ۱ (تصمیم‌گیری، آغاز نوبت): هر کشور همه تصمیم‌های ممکنش را می‌گیرد و به‌صورت
#       فشرده در world.npc_turn_plans ثبت می‌کند.
#   فاز ۲ (اجرا، پایان نوبت): تصمیم‌های همان نوبت یکجا اعمال و در رویدادها بازتاب می‌شوند.
# همه تصمیم‌ها با RNG دترمینستیک (Deterministic) گرفته می‌شوند تا زنجیره صحت و
# برابری تیک‌ها حفظ شود.
#
# قالب فشرده هر تصمیم (برای محدود ماندن حجم state در زنجیره صحت):
#   [country, action, target, key] — و برای «ادامه وضع موجود»: [country, "sq"]
# متن فارسی تصمیم‌ها هنگام نمایش (گزارش نوبت) ساخته می‌شود.

const MAX_PLAN_TURNS := 6

# ────────────────────────────────────────────────────────────────
# فاز ۱: تصمیم‌گیری — هر کشور غیربازیکن تصمیم این نوبت خود را می‌گیرد
# ────────────────────────────────────────────────────────────────
static func plan_npc_turn(state: Dictionary, turn: int) -> Dictionary:
	state = WorldManager.ensure_world(state)
	var world: Dictionary = state["world"]
	var plans: Dictionary = world.get("npc_turn_plans", {})
	var turn_plans: Array = []
	var countries: Dictionary = world["countries"]
	var relations: Dictionary = world.get("npc_relations", {})
	var wars: Dictionary = world.get("npc_wars", {})
	var alliances: Array = world.get("npc_alliances", [])
	var trades: Array = world.get("npc_trade_agreements", [])
	var player_id = str(world.get("player_country", WorldManager.default_country))

	var action_counts := {"war": 0, "alliance": 0, "trade": 0, "sanction": 0}
	for country_id in countries.keys():
		if country_id == player_id:
			continue
		var decision: Array = _decide_country(
			str(country_id), countries[country_id], relations,
			wars, alliances, trades, player_id, action_counts)
		# «ادامه وضع موجود» تصمیم هر کشور است اما برای محدود ماندن حجم state
		# ذخیره نمی‌شود؛ اجرای آن بی‌اثر است.
		if str(decision[1]) != "sq":
			turn_plans.append(decision)

	plans[str(turn)] = turn_plans
	# فقط چند نوبت اخیر نگهداری می‌شود تا حجم state محدود بماند
	while plans.size() > MAX_PLAN_TURNS:
		var oldest_key := ""
		var oldest_turn := 1 << 60
		for k in plans.keys():
			var t := int(k)
			if t < oldest_turn:
				oldest_turn = t
				oldest_key = k
		plans.erase(oldest_key)
	world["npc_turn_plans"] = plans
	state["world"] = world
	return {"state": state, "plans": turn_plans}

# ────────────────────────────────────────────────────────────────
# تصمیم یک کشور: اولویت با جنگ/اتحاد/تجارت/تحریم (دیپلماسی)، سپس
# تقویت ارتش در جنگ، سرمایه‌گذاری فناوری، اصلاحات داخلی یا وضع موجود
# ────────────────────────────────────────────────────────────────
static func _decide_country(id: String, runtime: Dictionary, relations: Dictionary,
		wars: Dictionary, alliances: Array, trades: Array, player_id: String,
		action_counts: Dictionary) -> Array:
	var at_war := _at_war(id, wars)
	if at_war:
		return [id, "build_military", "", ""]

	var gdp := float(runtime.get("gdp", 10.0))
	var population := float(runtime.get("population", 5_000_000.0))
	var tech := float(runtime.get("tech_level", 0.35))
	var stability := float(runtime.get("stability", 60.0))
	# GDP داده به دلار است؛ سرانه = GDP / جمعیت
	var gdp_per_cap: float = gdp * 1e9 / max(population, 1.0)

	# بدترین رقیب و بهترین دوست
	var worst := {"key": "", "other": "", "val": 100.0}
	var best := {"key": "", "other": "", "val": 0.0}
	for key in relations.keys():
		var pair := str(key).split("|")
		if pair.size() != 2 or (pair[0] != id and pair[1] != id):
			continue
		var other := pair[0] if pair[0] != id else pair[1]
		if other == player_id:
			continue  # کشورهای NPC خودسرانه علیه بازیکن اقدام نمی‌کنند
		var rel := float(relations[key])
		if rel < worst.val:
			worst = {"key": str(key), "other": other, "val": rel}
		if rel > best.val:
			best = {"key": str(key), "other": other, "val": rel}

	# اعلام جنگ به بدترین رقیب (روابط بسیار بد)
	if worst.has("other") and worst.key != "" and worst.val <= 28.0 \
			and not wars.has(worst.key) and int(action_counts.get("war", 0)) < 3 \
			and Deterministic.chance(0.015):
		action_counts["war"] = int(action_counts.get("war", 0)) + 1
		return [id, "war", worst.other, worst.key]
	# اتحاد با بهترین دوست
	if best.has("other") and best.key != "" and best.val >= 78.0 \
			and not alliances.has(best.key) and int(action_counts.get("alliance", 0)) < 3 \
			and Deterministic.chance(0.04):
		action_counts["alliance"] = int(action_counts.get("alliance", 0)) + 1
		return [id, "alliance", best.other, best.key]
	# توافق تجاری
	if best.has("other") and best.key != "" and best.val >= 58.0 \
			and not trades.has(best.key) and int(action_counts.get("trade", 0)) < 4 \
			and Deterministic.chance(0.035):
		action_counts["trade"] = int(action_counts.get("trade", 0)) + 1
		return [id, "trade", best.other, best.key]
	# تحریم رقیب بد
	if worst.has("other") and worst.key != "" and worst.val <= 16.0 \
			and not wars.has(worst.key) and int(action_counts.get("sanction", 0)) < 4 \
			and Deterministic.chance(0.05):
		action_counts["sanction"] = int(action_counts.get("sanction", 0)) + 1
		return [id, "sanction", worst.other, worst.key]
	# سرمایه‌گذاری در فناوری (کشورهای پیشرفته و آرام)
	if tech < 0.78 and gdp_per_cap > 12000.0 and Deterministic.chance(0.12):
		return [id, "tech_invest", "", ""]
	# اصلاحات داخلی (ثبات پایین)
	if stability < 55.0 and Deterministic.chance(0.20):
		return [id, "reform", "", ""]
	# تقویت دفاعی در صورت تهدید امنیتی (جنگ در زیرمنطقه خود کشور)
	if _threatened(id, runtime, wars, WorldManager.countries) and Deterministic.chance(0.35):
		return [id, "build_military", "", ""]
	return [id, "sq", "", ""]

# آیا این کشور در جنگی مشارکت دارد؟
static func _at_war(id: String, wars: Dictionary) -> bool:
	for key in wars.keys():
		if str(key).split("|").has(id):
			return true
	return false

# تهدید امنیتی: جنگی در منطقه کشور با قدرتی نزدیک یا بالاتر
static func _threatened(id: String, runtime: Dictionary, wars: Dictionary, static_data: Dictionary) -> bool:
	var my_mil := float(runtime.get("military_power", 50.0))
	var my_region := str(static_data.get(id, {}).get("subregion", ""))
	for key in wars.keys():
		var pair := str(key).split("|")
		if pair.size() != 2:
			continue
		for p in pair:
			if p == id:
				continue
			var profile: Dictionary = static_data.get(p, {})
			if str(profile.get("subregion", "")) == my_region \
					and float(profile.get("military_power", 0.0)) > my_mil * 1.1:
				return true
	return false

# ────────────────────────────────────────────────────────────────
# فاز ۲: اجرا — تصمیم‌های نوبت یکجا در پایان نوبت اعمال می‌شوند
# ────────────────────────────────────────────────────────────────
static func execute_npc_turn(state: Dictionary, turn: int) -> Dictionary:
	state = WorldManager.ensure_world(state)
	var world: Dictionary = state["world"]
	var plans: Dictionary = world.get("npc_turn_plans", {})
	var turn_plans: Array = plans.get(str(turn), [])
	var events: Array = []
	var relations: Dictionary = world.get("npc_relations", {})
	var wars: Dictionary = world.get("npc_wars", {})
	var alliances: Array = world.get("npc_alliances", [])
	var trades: Array = world.get("npc_trade_agreements", [])
	var countries_data: Dictionary = world["countries"]

	for plan in turn_plans:
		if not plan is Array or plan.size() < 2:
			continue
		var c := str(plan[0])
		var action := str(plan[1])
		var key := str(plan[3]) if plan.size() > 3 else ""
		var target := str(plan[2]) if plan.size() > 2 else ""
		if action == "sq":
			continue
		match action:
			"war":
				if key != "" and relations.has(key) and not wars.has(key) \
						and countries_data.has(c) and countries_data.has(target):
					wars[key] = {"a": c, "b": target, "started_turn": turn,
							"progress": 0.0, "losses_a": 0, "losses_b": 0}
					relations[key] = 0.0
					events.append({"type": "npc_war_started", "a": c, "b": target,
							"message": "جنگ میان %s و %s آغاز شد" % [_cname(c), _cname(target)]})
			"alliance":
				if key != "" and relations.has(key) and not alliances.has(key) \
						and countries_data.has(c) and countries_data.has(target):
					alliances.append(key)
					events.append({"type": "npc_alliance", "a": c, "b": target,
							"message": "اتحاد تازه‌ای میان %s و %s شکل گرفت" % [_cname(c), _cname(target)]})
			"trade":
				if key != "" and relations.has(key) and not trades.has(key) \
						and countries_data.has(c) and countries_data.has(target):
					trades.append(key)
					events.append({"type": "npc_trade_agreement", "a": c, "b": target,
							"message": "توافق تجاری میان %s و %s امضا شد" % [_cname(c), _cname(target)]})
			"sanction":
				if key != "" and relations.has(key) and countries_data.has(c) and countries_data.has(target):
					relations[key] = max(0.0, float(relations[key]) - 14.0)
					events.append({"type": "npc_sanction", "a": c, "b": target,
							"message": "%s تحریم اقتصادی %s را اعلام کرد" % [_cname(c), _cname(target)]})
			"build_military":
				if countries_data.has(c):
					var runtime: Dictionary = countries_data[c]
					runtime["military_power"] = clamp(float(runtime.get("military_power", 50.0)) * 1.02 + 0.4, 8.0, 130.0)
					runtime["gdp"] = max(1.0, float(runtime.get("gdp", 1.0)) * 0.9995)
					countries_data[c] = runtime
			"tech_invest":
				if countries_data.has(c):
					var runtime: Dictionary = countries_data[c]
					runtime["tech_level"] = clamp(float(runtime.get("tech_level", 0.35)) + 0.004, 0.05, 0.95)
					runtime["gdp"] = max(1.0, float(runtime.get("gdp", 1.0)) * 0.999)
					countries_data[c] = runtime
			"reform":
				if countries_data.has(c):
					var runtime: Dictionary = countries_data[c]
					runtime["stability"] = clamp(float(runtime.get("stability", 60.0)) + 2.0, 5.0, 100.0)
					runtime["gdp"] = max(1.0, float(runtime.get("gdp", 1.0)) * 0.9985)
					countries_data[c] = runtime

	world["npc_relations"] = relations
	world["npc_wars"] = wars
	world["npc_alliances"] = alliances
	world["npc_trade_agreements"] = trades
	world["countries"] = countries_data
	state["world"] = world
	return {"state": state, "events": events}

# ────────────────────────────────────────────────────────────────
# نمایش: متن فارسی تصمیم برای گزارش نوبت
# ────────────────────────────────────────────────────────────────
static func action_icon(action: String) -> String:
	match action:
		"war": return "⚔"
		"alliance": return "🤝"
		"trade": return "📦"
		"sanction": return "🚫"
		"build_military": return "🛡"
		"tech_invest": return "🔬"
		"reform": return "🏛"
	return "🌍"

static func describe(plan: Array) -> String:
	if plan.size() < 2:
		return ""
	var c := str(plan[0])
	var action := str(plan[1])
	var target := str(plan[2]) if plan.size() > 2 else ""
	match action:
		"war": return "اعلام جنگ به %s" % _cname(target)
		"alliance": return "اتحاد راهبردی با %s" % _cname(target)
		"trade": return "توافق تجاری با %s" % _cname(target)
		"sanction": return "تحریم اقتصادی %s" % _cname(target)
		"build_military": return "تقویت توان دفاعی"
		"tech_invest": return "سرمایه‌گذاری در فناوری"
		"reform": return "اصلاحات داخلی و ثبات‌سازی"
		"sq": return "ادامه وضع موجود"
	return ""

static func _cname(id: String) -> String:
	return WorldManager.get_country_name(id)
