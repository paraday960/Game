extends Node
# ────────────────────────────────────────────────────────────────────────────
# بنگاه‌های کوچک و متوسط (SME) — عمق ستون فقرات اقتصاد
# تسهیل کسب‌وکار، وام‌های خرد، تأمین مالی زنجیره تأمین و سهم از GDP.
# بنگاه‌های کوچک بزرگ‌ترین کارفرما هستند؛ بهبود فضای کسب‌وکار آن‌ها را رسمی
# می‌کند، بیکاری را کم و اقتصاد سایه را می‌خشکاند. پیوند: اقتصاد، بانک، کار.
#
# state["sme_policy"] = {
#   "ease_business":0..1, "micro_credit":0..1, "supply_chain":0..1,
#   "formalization":0..1, "last_credit":turn,
#   "sme_share":0..1, "jobs":0, "business_count":0 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("sme_policy"):
		state["sme_policy"] = {
			"ease_business": 0.35, "micro_credit": 0.30, "supply_chain": 0.25,
			"formalization": 0.30, "last_credit": -99,
			"sme_share": 0.40, "jobs": 12_000_000, "business_count": 1_500_000,
			"credit_gap": 0.45, "productivity": 0.35
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var sp: Dictionary = state["sme_policy"]
	var econ: Dictionary = state.get("economy", {})
	var banking: Dictionary = state.get("banking", {})
	var shadow: Dictionary = state.get("shadow", {})
	var labor: Dictionary = state.get("labor", {})
	var edu: Dictionary = state.get("education", {})
	var gdp: float = float(econ.get("gdp", 1.0))

	var ease: float = float(sp.get("ease_business", 0.35))
	var credit: float = float(sp.get("micro_credit", 0.30))
	var supply: float = float(sp.get("supply_chain", 0.25))
	var formal: float = float(sp.get("formalization", 0.30))

	# شکاف اعتباری: هرچه اعتبار خرد و وام‌دهی بانکی کمتر، شکاف بیشتر
	var bank_stability: float = float(banking.get("stability", 0.65))
	var credit_gap: float = clampf(0.70 - credit * 0.40 - bank_stability * 0.25, 0.05, 0.90)
	sp["credit_gap"] = credit_gap

	# تعداد کسب‌وکارها: تسهیل + اعتبار
	var edu_level: float = float(edu.get("quality", 0.55))
	var count: int = int(sp.get("business_count", 1_500_000))
	count = maxi(200_000, int(count * 0.995 + ease * 8000.0 + credit * 5000.0 + edu_level * 3000.0))
	sp["business_count"] = count

	# سهم SME از اقتصاد و اشتغال
	var sme_share: float = clampf(
		0.25 + ease * 0.20 + credit * 0.15 + supply * 0.15 + formal * 0.20, 0.10, 0.75)
	sp["sme_share"] = sme_share
	sp["jobs"] = int(8_000_000.0 + sme_share * 18_000_000.0)
	var productivity: float = clampf(0.20 + ease * 0.25 + supply * 0.20 + edu_level * 0.20, 0.10, 0.90)
	sp["productivity"] = productivity

	# اثر اقتصادی: SME موتور رشد و اشتغال است
	econ["gdp"] = gdp * (1.0 + sme_share * 0.0006 + productivity * 0.0003)
	econ["unemployment"] = clampf(float(econ.get("unemployment", 0.08)) - sme_share * 0.0004, 0.02, 0.30)
	# رسمی‌سازی اقتصاد سایه را کوچک می‌کند
	if not shadow.is_empty():
		shadow["size"] = clampf(float(shadow.get("size", 0.18)) - formal * 0.001, 0.03, 0.55)
		state["shadow"] = shadow
	# اتحادیه کارگری و کار
	if labor.has("wage_policy"):
		state["labor"] = labor

	# هزینه بهبود فضای کسب‌وکار
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + gdp * 0.0008
	state["economy"] = econ

	# رویدادها
	if credit_gap > 0.65 and Deterministic.chance(0.05):
		# موج تعطیلی بنگاه‌های کوچک: تولید و اشتغال واقعی ضربه می‌خورد
		econ["gdp"] = float(econ.get("gdp", 1.0)) * 0.997
		econ["unemployment"] = clampf(float(econ.get("unemployment", 0.08)) + 0.005, 0.015, 0.40)
		state["economy"] = econ
		events.append({"type": "credit_crunch", "message": "💳 خشکی اعتبار بنگاه‌های کوچک را زمین‌گیر کرد؛ تعطیلی‌ها بالا رفت"})
	elif ease > 0.70 and productivity > 0.60 and Deterministic.chance(0.03):
		events.append({"type": "sme_boom", "message": "📈 بنگاه‌های کوچک شکوفا شدند؛ اشتغال و صادرات غیرنفتی رشد کرد"})
	elif formal > 0.60 and Deterministic.chance(0.02):
		events.append({"type": "formalization_win", "message": "🧾 رسمی‌سازی کسب‌وکارها، درآمد مالیاتی را بالا برد"})

	state["sme_policy"] = sp
	return {"state": state, "events": events}

# ── بهبود فضای کسب‌وکار ──
func cut_red_tape(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["sme_policy"]
	if float(sp.get("ease_business", 0.35)) >= 0.95:
		return {"success": false, "reason": "سهولت کسب‌وکار در سقف است", "state": state, "events": []}
	sp["ease_business"] = clampf(float(sp.get("ease_business", 0.35)) + 0.15, 0.0, 1.0)
	state["sme_policy"] = sp
	return {"success": true, "state": state,
		"events": [{"type": "red_tape", "message": "📝 مقررات دست‌وپاگیر کسب‌وکار ساده‌سازی شد"}]}

# ── صندوق وام خرد ──
func micro_credit_fund(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["sme_policy"]
	if turn - int(sp.get("last_credit", -99)) < 5:
		return {"success": false, "reason": "صندوق وام خرد هر ۵ نوبت یک بار", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.002
	sp["last_credit"] = turn
	sp["micro_credit"] = clampf(float(sp.get("micro_credit", 0.30)) + 0.15, 0.0, 1.0)
	state["economy"] = econ
	state["sme_policy"] = sp
	return {"success": true, "state": state,
		"events": [{"type": "micro_credit", "message": "🏦 صندوق وام خرد کسب‌وکارهای کوچک را تغذیه کرد"}]}

# ── تأمین مالی زنجیره تأمین ──
func supply_chain_finance(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["sme_policy"]
	if float(sp.get("supply_chain", 0.25)) >= 0.95:
		return {"success": false, "reason": "زنجیره تأمین در سقف است", "state": state, "events": []}
	sp["supply_chain"] = clampf(float(sp.get("supply_chain", 0.25)) + 0.15, 0.0, 1.0)
	state["sme_policy"] = sp
	return {"success": true, "state": state,
		"events": [{"type": "supply_chain", "message": "🔗 تأمین مالی زنجیره تأمین به بنگاه‌های کوچک نقدینگی رساند"}]}

# ── تسهیل رسمی‌سازی ──
func formalize_businesses(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["sme_policy"]
	if float(sp.get("formalization", 0.30)) >= 0.95:
		return {"success": false, "reason": "رسمی‌سازی در سقف است", "state": state, "events": []}
	sp["formalization"] = clampf(float(sp.get("formalization", 0.30)) + 0.15, 0.0, 1.0)
	state["sme_policy"] = sp
	return {"success": true, "state": state,
		"events": [{"type": "formalize", "message": "🧾 صدور مجوز یکپارچه و مشوق‌های مالیاتی کسب‌وکارها را رسمی کرد"}]}
