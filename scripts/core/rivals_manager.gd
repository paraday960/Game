extends Node
# ────────────────────────────────────────────────────────────────────────────
# رقبای داخلی و توطئه (عمق‌بخشی ۴۹) — دشمنان درونیِ رهبرِ مطلق
#
# رهبر هرگز برکنار نمی‌شود (قانون بازی)، اما رقیب‌های داخلی می‌توانند ناراضی
# شوند، توطئه بچینند و دست به کودتا بزنند. کودتا همیشه می‌شکند؛ هزینه‌اش ثبات،
# اعتماد و وفاداری جناح‌هاست و رهبرِ بازمانده سرمایهٔ سیاسی هم به دست می‌آورد.
# بازیکن با چهار ابزار مدیریت می‌کند: همکاری (دعوت به هیئت دولت)، مذاکره،
# زیر نظر گرفتن (سرویس اطلاعات) و تبعید. هر ابزار بده‌بستان واقعی دارد
# (اصل ۲.۲: هیچ عمل بدون پیامد نیست) و همه روی کانال‌های واقعی می‌نشیند.
#
# state["rivals"] = {
#   "figures": [ { id, name_fa, faction, ambition(0..100), support(0..100),
#                  loyalty(0..100), status: "loyal"|"coopted"|"restless"|"plotting",
#                  joined_turn, last_plot_turn } ],
#   "threat": 0..1,          # شاخص تهدید داخلی (برای هوش و UI)
#   "coup_attempts": int,    # شمار کودتاهای شکست‌خورده (روایت، سقف‌دار نیست چون شمارنده است)
#   "last_exile_turn": -99, "last_surveil_turn": -99, "last_recruit_turn": -99
# }
# ────────────────────────────────────────────────────────────────────────────

const MAX_FIGURES := 3
const EXILE_COOLDOWN := 8
const SURVEIL_COOLDOWN := 4
const RECRUIT_COOLDOWN := 4
const PLOT_RECHECK_TURNS := 6
const PLOT_MIN_SUPPORT := 55.0
const PLOT_MIN_AMBITION := 50.0
const PLOT_MAX_LOYALTY := 40.0
const COUP_CHANCE := 0.15

const FIRST_NAMES := ["کامران", "سیاوش", "اردلان", "فرهاد", "بابک", "تورج",
	"مازیار", "هوتن", "شاپور", "کاووس", "گودرز", "بیژن", "آبتین", "سهراب",
	"پشنگ", "قارن", "میلاد", "نوشاد", "بهرنگ", "خسرو"]
const LAST_NAMES := ["فرخ‌زاد", "اسفندیاری", "تهمتن", "پارسا", "دریایی", "کوهیار",
	"شهریاری", "آزادگان", "بیابانی", "چمنی", "دشتی", "رزم‌آرا", "سپاهی", "شجاعی",
	"صفوی", "قزوینی", "کاویانی", "لرستانی", "مازندرانی", "نیشابوری"]

const STATUS_FA := {
	"loyal": "وفادار", "coopted": "هم‌پیمان", "restless": "ناراضی", "plotting": "توطئه‌گر"
}

# ── تضمین ساختار (اسپاون دترمینستیک و بدون RNG تا اعتبارسنجی و اجرا یکسان باشند) ──
func ensure(state: Dictionary) -> Dictionary:
	state = FactionManager.ensure(state)
	if not state.has("rivals"):
		state["rivals"] = {
			"figures": [], "threat": 0.15, "coup_attempts": 0,
			"last_exile_turn": -99, "last_surveil_turn": -99, "last_recruit_turn": -99
		}
		state["rivals"]["figures"] = []
		# پر کردن اولیه فقط هنگام ساخت بخش — جایگزینی بعدی فقط از مسیر
		# simulate_month و با رعایت RECRUIT_COOLDOWN انجام می‌شود (تبعید اثر دارد)
		var fill_figures: Array = state["rivals"]["figures"]
		while fill_figures.size() < MAX_FIGURES:
			state = _spawn_figure(state, int(state.get("tick", 0)))
			fill_figures = state["rivals"]["figures"]
	var rivals: Dictionary = state["rivals"]
	rivals["threat"] = clampf(float(rivals.get("threat", 0.15)), 0.0, 1.0)
	rivals["coup_attempts"] = int(rivals.get("coup_attempts", 0))
	rivals["last_exile_turn"] = int(rivals.get("last_exile_turn", -99))
	rivals["last_surveil_turn"] = int(rivals.get("last_surveil_turn", -99))
	rivals["last_recruit_turn"] = int(rivals.get("last_recruit_turn", -99))
	var figures: Array = rivals.get("figures", [])
	for i in range(figures.size()):
		figures[i] = _normalize_figure(figures[i], "%d_%d" % [int(rivals.get("last_recruit_turn", 0)), i])
	rivals["figures"] = figures
	state["rivals"] = rivals
	return state

# ── شبیه‌سازی ماهانه: دریفت حمایت/جاه‌طلبی/وفاداری، توطئه و کودتا ──
func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	state = FactionManager.ensure(state)
	var rivals: Dictionary = state["rivals"]
	var figures: Array = rivals.get("figures", [])
	var events: Array = []
	var factions: Dictionary = state.get("factions", {})
	var pol: Dictionary = state.get("politics", {})
	var econ: Dictionary = state.get("economy", {})
	var leader: Dictionary = state.get("leader", {})
	var world: Dictionary = state.get("world", {})
	var stability := float(pol.get("stability", 0.6))
	var popularity := float(leader.get("popularity_world", 50.0))
	var growth := float(econ.get("growth_rate", 0.02))
	var at_war: bool = not world.get("wars", {}).is_empty()

	var coup_list: Array = []
	for i in range(figures.size()):
		var f: Dictionary = _normalize_figure(figures[i], "x")
		var faction := str(f.get("faction", ""))
		var fl := float(factions.get(faction, {}).get("loyalty", 50.0))
		var support := float(f.get("support", 0.0))
		var loyalty := float(f.get("loyalty", 0.0))
		var ambition := float(f.get("ambition", 0.0))
		var status := str(f.get("status", "loyal"))
		# ── دریفت ماهانه: وفاداری جناح، محبوبیت رهبر، ثبات و رشد اقتصاد ──
		support += (fl - 50.0) * 0.05 + (50.0 - popularity) * 0.02 + (0.6 - stability) * 8.0
		if growth < 0.0:
			support += 1.0
		if at_war and status != "coopted":
			support -= 1.5
		support = clampf(support, 0.0, 100.0)
		if status == "coopted":
			loyalty = clampf(loyalty + 0.5, 0.0, 100.0)
		else:
			loyalty = clampf(loyalty + (50.0 - loyalty) * 0.01, 0.0, 100.0)
		if fl < 35.0:
			ambition = clampf(ambition + 0.8, 0.0, 100.0)
		else:
			# نوسان فرمول‌محور دترمینستیک — بدون مصرف RNG تا توالی تصادفی
			# سایر سیستم‌ها/تست‌ها جابه‌جا نشود (قفل دترمینستیک چندنفره)
			ambition = clampf(ambition + 0.25 * sin(float(turn * 3 + i) * 0.7), 0.0, 100.0)
		f["support"] = support
		f["loyalty"] = loyalty
		f["ambition"] = ambition
		# ── گذار وضعیت ──
		if status == "loyal" and support >= 45.0 and ambition >= 45.0 and loyalty <= 45.0:
			f["status"] = "restless"
			events.append({"type": "rivals_restless", "message": "😟 «%s» از رهبر فاصله گرفته و در محافل خصوصی انتقاد می‌کند" % str(f.get("name_fa", ""))})
		elif status == "restless" and support >= PLOT_MIN_SUPPORT and ambition >= PLOT_MIN_AMBITION and loyalty <= PLOT_MAX_LOYALTY and stability < 0.55 and turn - int(f.get("last_plot_turn", -99)) >= PLOT_RECHECK_TURNS:
			f["status"] = "plotting"
			f["last_plot_turn"] = turn
			events.append({"type": "rivals_plot", "message": "🕵️ گزارش محرمانهٔ سرویس اطلاعات: «%s» در حال سامان‌دهی توطئه‌ای بر ضد رهبر است!" % str(f.get("name_fa", ""))})
		elif status == "plotting":
			if support < 45.0 or loyalty > 55.0:
				f["status"] = "restless"
			elif (turn * 37 + i * 13) % 100 < int(COUP_CHANCE * 100.0):
				coup_list.append(str(f.get("id", "")))
	rivals["figures"] = figures

	# ── کودتا: همیشه می‌شکند — رهبر برکنارنشدنی است (قانون بازی) ──
	for coup_id in coup_list:
		var coup = _attempt_coup(state, coup_id, turn)
		state = coup.state
		events.append_array(coup.events)
		rivals = state["rivals"]
		figures = rivals.get("figures", [])
		factions = state.get("factions", {})
		pol = state.get("politics", {})

	# ── جایگزینی رقیب حذف‌شده (سقف MAX_FIGURES — بدون رشد نامحدود) ──
	if figures.size() < MAX_FIGURES and turn - int(rivals.get("last_recruit_turn", -99)) >= RECRUIT_COOLDOWN:
		state = _spawn_figure(state, turn)
		rivals = state["rivals"]
		figures = rivals["figures"]

	# ── شاخص تهدید داخلی ──
	var threat := 0.15
	for f in figures:
		var s := float(f.get("support", 0.0)) * 0.006
		var a := float(f.get("ambition", 0.0)) * 0.004
		var m := 1.3 if str(f.get("status", "loyal")) == "plotting" else 1.0
		threat = maxf(threat, clampf((s + a) * m, 0.0, 1.0))
	rivals["threat"] = threat
	state["rivals"] = rivals
	state["politics"] = pol
	state["factions"] = factions
	return {"state": state, "events": events}

# ────────────────────────────────────────────────────────────────────────────
# ابزارهای بازیکن (فرمان‌محور: validation ← can_*، اجرا ← خود اقدام)
# ────────────────────────────────────────────────────────────────────────────

# 🤝 همکاری: دعوت رقیب ناراضی به هیئت دولت — وفاداری می‌خرید ولی کمی فساد می‌آورد
func can_coopt(state: Dictionary, target_id: String, tick: int) -> Dictionary:
	state = ensure(state)
	var figure := _get_figure(state, target_id)
	if figure.is_empty():
		return {"valid": false, "reason": "رقیب یافت نشد"}
	if not str(figure.get("status", "loyal")) in ["restless", "plotting"]:
		return {"valid": false, "reason": "این چهره اکنون تهدیدی نیست"}
	if float(state.get("policies", {}).get("political_capital", 0.0)) < 1.0:
		return {"valid": false, "reason": "سرمایه سیاسی کافی نیست"}
	return {"valid": true, "reason": ""}

func coopt(state: Dictionary, target_id: String, tick: int) -> Dictionary:
	var check := can_coopt(state, target_id, tick)
	if not check.valid:
		return {"success": false, "reason": check.reason, "state": state, "events": []}
	state = ensure(state)
	state = FactionManager.ensure(state)
	var rivals: Dictionary = state["rivals"]
	var figures: Array = rivals.get("figures", [])
	var figure := _get_figure(state, target_id)
	figure["status"] = "coopted"
	figure["loyalty"] = 70.0
	figure["support"] = float(figure.get("support", 50.0)) * 0.6
	figure["last_plot_turn"] = -99
	rivals["figures"] = figures
	var factions: Dictionary = state.get("factions", {})
	var pol: Dictionary = state.get("politics", {})
	if factions.has(str(figure.get("faction", ""))):
		var fac: Dictionary = factions[str(figure["faction"])]
		fac["loyalty"] = clampf(float(fac.get("loyalty", 55.0)) + 3.0, 0.0, 100.0)
		factions[str(figure["faction"])] = fac
	pol["corruption"] = clampf(float(pol.get("corruption", 0.3)) + 0.01, 0.0, 1.0)
	var policies: Dictionary = state.get("policies", {})
	policies["political_capital"] = max(0.0, float(policies.get("political_capital", 0.0)) - 1.0)
	state["rivals"] = rivals
	state["factions"] = factions
	state["politics"] = pol
	state["policies"] = policies
	return {"success": true, "state": state, "events": [{
		"type": "rivals_coopt",
		"message": "🤝 «%s» به هیئت دولت پیوست؛ رقیب دیروز، هم‌پیمان امروز — اما خرید وفاداری اندکی فساد آورد" % str(figure.get("name_fa", ""))}]}

# 🚪 تبعید: حذف توطئه‌گر — قاطعانه است ولی جناحش را می‌رنجاند و دیگران را می‌ترساند
func can_exile(state: Dictionary, target_id: String, tick: int) -> Dictionary:
	state = ensure(state)
	var figure := _get_figure(state, target_id)
	if figure.is_empty():
		return {"valid": false, "reason": "رقیب یافت نشد"}
	if str(figure.get("status", "loyal")) != "plotting":
		return {"valid": false, "reason": "فقط توطئه‌گرِ اثبات‌شده را می‌توان تبعید کرد"}
	if int(state.get("rivals", {}).get("last_exile_turn", -99)) + EXILE_COOLDOWN > tick:
		return {"valid": false, "reason": "تبعید پیاپی مشروعیت را می‌سوزاند؛ کمی صبر کنید"}
	if float(state.get("policies", {}).get("political_capital", 0.0)) < 1.5:
		return {"valid": false, "reason": "سرمایه سیاسی کافی نیست"}
	return {"valid": true, "reason": ""}

func exile(state: Dictionary, target_id: String, tick: int) -> Dictionary:
	var check := can_exile(state, target_id, tick)
	if not check.valid:
		return {"success": false, "reason": check.reason, "state": state, "events": []}
	state = ensure(state)
	state = FactionManager.ensure(state)
	var rivals: Dictionary = state["rivals"]
	var figures: Array = rivals.get("figures", [])
	var figure := _get_figure(state, target_id)
	var name_fa := str(figure.get("name_fa", ""))
	var faction := str(figure.get("faction", ""))
	var idx := -1
	for i in range(figures.size()):
		if str(figures[i].get("id", "")) == target_id:
			idx = i
			break
	if idx >= 0:
		figures.remove_at(idx)
	rivals["figures"] = figures
	rivals["last_exile_turn"] = tick
	var pol: Dictionary = state.get("politics", {})
	var factions: Dictionary = state.get("factions", {})
	pol["stability"] = clampf(float(pol.get("stability", 0.6)) - 0.005, 0.05, 1.0)
	pol["trust"] = clampf(float(pol.get("trust", 0.55)) + 0.01, 0.05, 1.0)
	if factions.has(faction):
		var fac: Dictionary = factions[faction]
		fac["loyalty"] = clampf(float(fac.get("loyalty", 55.0)) - 4.0, 0.0, 100.0)
		factions[faction] = fac
	for f in figures:
		f["loyalty"] = clampf(float(f.get("loyalty", 50.0)) - 5.0, 0.0, 100.0)
		f["ambition"] = clampf(float(f.get("ambition", 50.0)) - 8.0, 0.0, 100.0)
	rivals["figures"] = figures
	var policies: Dictionary = state.get("policies", {})
	policies["political_capital"] = max(0.0, float(policies.get("political_capital", 0.0)) - 1.5)
	state["rivals"] = rivals
	state["politics"] = pol
	state["factions"] = factions
	state["policies"] = policies
	return {"success": true, "state": state, "events": [{
		"type": "rivals_exile",
		"message": "🚪 «%s» تبعید شد؛ رقبا حساب کار دستشان آمد — اما زمزمهٔ نارضایتی در جناح‌ها پیچید" % name_fa}]}

# 🗣️ مذاکره: پای میز نشاندن رقیب — وفاداری بالا، جاه‌طلبی و حمایت پایین
func can_negotiate(state: Dictionary, target_id: String, tick: int) -> Dictionary:
	state = ensure(state)
	var figure := _get_figure(state, target_id)
	if figure.is_empty():
		return {"valid": false, "reason": "رقیب یافت نشد"}
	if not str(figure.get("status", "loyal")) in ["restless", "plotting"]:
		return {"valid": false, "reason": "این چهره اکنون تهدیدی نیست"}
	if float(state.get("policies", {}).get("political_capital", 0.0)) < 0.5:
		return {"valid": false, "reason": "سرمایه سیاسی کافی نیست"}
	return {"valid": true, "reason": ""}

func negotiate(state: Dictionary, target_id: String, tick: int) -> Dictionary:
	var check := can_negotiate(state, target_id, tick)
	if not check.valid:
		return {"success": false, "reason": check.reason, "state": state, "events": []}
	state = ensure(state)
	var rivals: Dictionary = state["rivals"]
	var figures: Array = rivals.get("figures", [])
	var figure := _get_figure(state, target_id)
	figure["loyalty"] = clampf(float(figure.get("loyalty", 50.0)) + 15.0, 0.0, 100.0)
	figure["ambition"] = clampf(float(figure.get("ambition", 50.0)) - 10.0, 0.0, 100.0)
	figure["support"] = clampf(float(figure.get("support", 50.0)) - 5.0, 0.0, 100.0)
	if str(figure.get("status", "loyal")) == "plotting":
		figure["status"] = "restless"
	rivals["figures"] = figures
	var policies: Dictionary = state.get("policies", {})
	policies["political_capital"] = max(0.0, float(policies.get("political_capital", 0.0)) - 0.5)
	state["rivals"] = rivals
	state["policies"] = policies
	return {"success": true, "state": state, "events": [{
		"type": "rivals_negotiate",
		"message": "🗣️ مذاکره با «%s» نتیجه داد؛ وفاداری بالا رفت و جاه‌طلبی فروکش کرد" % str(figure.get("name_fa", ""))}]}

# 🕵️ زیر نظر گرفتن: سرویس اطلاعات توطئه را افشا می‌کند؛ نیازمند آمادگی سایبری
func can_surveil(state: Dictionary, target_id: String, tick: int) -> Dictionary:
	state = ensure(state)
	var figure := _get_figure(state, target_id)
	if figure.is_empty():
		return {"valid": false, "reason": "رقیب یافت نشد"}
	if not str(figure.get("status", "loyal")) in ["restless", "plotting"]:
		return {"valid": false, "reason": "این چهره اکنون تهدیدی نیست"}
	if int(state.get("rivals", {}).get("last_surveil_turn", -99)) + SURVEIL_COOLDOWN > tick:
		return {"valid": false, "reason": "سرویس اطلاعات هنوز مشغول پروندهٔ قبلی است"}
	if float(state.get("intelligence", {}).get("cyber_readiness", 0.0)) < 0.3:
		return {"valid": false, "reason": "آمادگی سایبری سرویس اطلاعات کافی نیست"}
	if float(state.get("policies", {}).get("political_capital", 0.0)) < 0.5:
		return {"valid": false, "reason": "سرمایه سیاسی کافی نیست"}
	return {"valid": true, "reason": ""}

func surveil(state: Dictionary, target_id: String, tick: int) -> Dictionary:
	var check := can_surveil(state, target_id, tick)
	if not check.valid:
		return {"success": false, "reason": check.reason, "state": state, "events": []}
	state = ensure(state)
	var rivals: Dictionary = state["rivals"]
	var figures: Array = rivals.get("figures", [])
	var figure := _get_figure(state, target_id)
	rivals["last_surveil_turn"] = tick
	var plotting := str(figure.get("status", "loyal")) == "plotting"
	if plotting:
		figure["support"] = clampf(float(figure.get("support", 50.0)) - 25.0, 0.0, 100.0)
		figure["loyalty"] = clampf(float(figure.get("loyalty", 50.0)) - 15.0, 0.0, 100.0)
		figure["status"] = "restless"
	else:
		figure["loyalty"] = clampf(float(figure.get("loyalty", 50.0)) - 3.0, 0.0, 100.0)
	rivals["figures"] = figures
	var policies: Dictionary = state.get("policies", {})
	policies["political_capital"] = max(0.0, float(policies.get("political_capital", 0.0)) - 0.5)
	state["rivals"] = rivals
	state["policies"] = policies
	if plotting:
		return {"success": true, "state": state, "events": [{
			"type": "rivals_surveil",
			"message": "🕵️ توطئهٔ «%s» افشا و خنثی شد؛ شبکهٔ حامیانش فروپاشید" % str(figure.get("name_fa", ""))}]}
	return {"success": true, "state": state, "events": [{
		"type": "rivals_surveil",
		"message": "🕵️ بررسی سرویس اطلاعات روی «%s» چیز مهمی نیافت؛ رقیب از زیر نظر بودن آزرده شد" % str(figure.get("name_fa", ""))}]}

# ────────────────────────────────────────────────────────────────────────────
# کمکی‌ها
# ────────────────────────────────────────────────────────────────────────────

func _get_figure(state: Dictionary, target_id: String) -> Dictionary:
	var figures: Array = state.get("rivals", {}).get("figures", [])
	for f in figures:
		if str(f.get("id", "")) == target_id:
			return f
	return {}

func _normalize_figure(f: Dictionary, fallback_id: String) -> Dictionary:
	f["id"] = str(f.get("id", fallback_id))
	f["name_fa"] = str(f.get("name_fa", "چهرهٔ ناشناس"))
	f["faction"] = str(f.get("faction", "رسانه"))
	f["ambition"] = clampf(float(f.get("ambition", 50.0)), 0.0, 100.0)
	f["support"] = clampf(float(f.get("support", 30.0)), 0.0, 100.0)
	f["loyalty"] = clampf(float(f.get("loyalty", 50.0)), 0.0, 100.0)
	f["status"] = str(f.get("status", "loyal"))
	f["joined_turn"] = int(f.get("joined_turn", 0))
	f["last_plot_turn"] = int(f.get("last_plot_turn", -99))
	return f

# اسپاون دترمینستیک (بدون RNG): اعتبارسنجی و اجرا همیشه چهرهٔ یکسان می‌سازند
func _spawn_figure(state: Dictionary, turn: int) -> Dictionary:
	state = FactionManager.ensure(state)
	var rivals: Dictionary = state["rivals"]
	var figures: Array = rivals.get("figures", [])
	var index := figures.size()
	var id := "%d_%d" % [turn, index]
	var first: String = FIRST_NAMES[(turn * 3 + index) % FIRST_NAMES.size()]
	var last: String = LAST_NAMES[(turn * 7 + index * 5) % LAST_NAMES.size()]
	var faction: String = FactionManager.FACTIONS[(turn + index) % FactionManager.FACTIONS.size()]
	var faction_power := float(state.get("factions", {}).get(faction, {}).get("power", 45.0))
	var figure := {
		"id": id, "name_fa": "%s %s" % [first, last], "faction": faction,
		"ambition": 30.0 + float((turn * 7 + index * 11) % 46),
		"support": clampf(faction_power * 0.5 + 20.0, 10.0, 90.0),
		"loyalty": 40.0 + float((turn * 5 + index * 13) % 26),
		"status": "loyal", "joined_turn": turn, "last_plot_turn": -99
	}
	figures.append(figure)
	rivals["figures"] = figures
	rivals["last_recruit_turn"] = turn
	state["rivals"] = rivals
	return state

# کودتا: همیشه می‌شکند — رهبر برکنارنشدنی است؛ اما هزینهٔ واقعی دارد
func _attempt_coup(state: Dictionary, figure_id: String, turn: int) -> Dictionary:
	var rivals: Dictionary = state.get("rivals", {})
	var figures: Array = rivals.get("figures", [])
	var events: Array = []
	var idx := -1
	for i in range(figures.size()):
		if str(figures[i].get("id", "")) == figure_id:
			idx = i
			break
	if idx == -1:
		return {"state": state, "events": events}
	var figure: Dictionary = figures[idx]
	var name_fa := str(figure.get("name_fa", ""))
	var faction := str(figure.get("faction", ""))
	figures.remove_at(idx)
	rivals["figures"] = figures
	rivals["coup_attempts"] = int(rivals.get("coup_attempts", 0)) + 1
	var pol: Dictionary = state.get("politics", {})
	var factions: Dictionary = state.get("factions", {})
	var policies: Dictionary = state.get("policies", {})
	var leader: Dictionary = state.get("leader", {})
	var max_capital := float(BalanceConfig.get_value("politics.policy_capital_max", 5.0))
	pol["stability"] = clampf(float(pol.get("stability", 0.6)) - 0.04, 0.05, 1.0)
	pol["trust"] = clampf(float(pol.get("trust", 0.55)) - 0.02, 0.05, 1.0)
	if factions.has(faction):
		var fac: Dictionary = factions[faction]
		fac["loyalty"] = clampf(float(fac.get("loyalty", 55.0)) - 8.0, 0.0, 100.0)
		factions[faction] = fac
	policies["political_capital"] = min(max_capital, float(policies.get("political_capital", 0.0)) + 0.5)
	leader["popularity_world"] = clampf(float(leader.get("popularity_world", 50.0)) + 1.0, 0.0, 100.0)
	state["rivals"] = rivals
	state["politics"] = pol
	state["factions"] = factions
	state["policies"] = policies
	state["leader"] = leader
	events.append({"type": "rivals_coup", "message": "💥 کودتای «%s» در نطفه خفه شد! رهبر مطلق پابرجاست؛ اما زخم بی‌اعتمادی بر تن کشور نشست" % name_fa})
	return {"state": state, "events": events}
