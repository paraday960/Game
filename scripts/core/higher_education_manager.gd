extends Node
# ────────────────────────────────────────────────────────────────────────────
# آموزش عالی و دانشگاه — عمق سرمایه انسانی
# بودجه دانشگاه، کیفیت آموزش، تحقیقات دانشگاهی، رتبه‌بندی بین‌المللی و
# سهم پذیرش. دانشگاه قوی نوآوری، فناوری و جذب دانشجوی خارجی می‌آورد.
# پیوند: آموزش، پژوهش، فناوری، اقتصاد دانش‌بنیان.
#
# state["higher_ed_policy"] = {
#   "funding":0..1, "research":0..1, "faculty":0..1,
#   "international":0..1, "last_endowment":turn,
#   "quality":0..1, "graduates":0, "ranking":0..1 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("higher_ed_policy"):
		state["higher_ed_policy"] = {
			"funding": 0.30, "research": 0.25, "faculty": 0.30,
			"international": 0.15, "last_endowment": -99,
			"quality": 0.35, "graduates": 500000, "ranking": 0.20,
			"brain_gain": 0.10, "tuition_access": 0.55
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var hp: Dictionary = state["higher_ed_policy"]
	var econ: Dictionary = state.get("economy", {})
	var edu: Dictionary = state.get("education", {})
	var tech: Dictionary = state.get("technology", {})
	var research: Dictionary = state.get("research_policy", {})
	var science: Dictionary = state.get("science_policy", {})

	var funding: float = float(hp.get("funding", 0.30))
	var research_u: float = float(hp.get("research", 0.25))
	var faculty: float = float(hp.get("faculty", 0.30))
	var intl: float = float(hp.get("international", 0.15))
	var gdp: float = float(econ.get("gdp", 1.0))

	# کیفیت: بودجه + هیئت علمی + تحقیق
	var quality: float = clampf(
		0.15 + funding * 0.30 + faculty * 0.25 + research_u * 0.25 +
		float(edu.get("quality", 0.55)) * 0.10, 0.05, 0.98)
	hp["quality"] = quality

	# رتبه بین‌المللی: کیفیت + همکاری علمی
	var intl_coop: float = float(science.get("knowledge_flow", 0.20))
	var ranking: float = clampf(0.05 + quality * 0.50 + intl * 0.25 + intl_coop * 0.15, 0.02, 0.95)
	hp["ranking"] = ranking

	# فارغ‌التحصیلان
	var graduates: int = int(300000.0 + quality * 800000.0 + funding * 200000.0)
	hp["graduates"] = graduates

	# جذب نخبگان: رتبه بالا + دیاسپورا
	var brain_gain: float = clampf(ranking * 0.40 + intl * 0.25 + float(state.get("diaspora_policy", {}).get("trust", 0.4)) * 0.20, 0.0, 0.9)
	hp["brain_gain"] = brain_gain

	# اثر اقتصادی و پژوهشی
	# ممیزی GDP (۱۴۰۵): اثر مداوم از کانال مالک-یکتای sector_boosts (نرخ سالانه؛ ماهانه: ×۱۲)
	var quality * 0.0004 * 12.0_boosts: Dictionary = econ.get("sector_boosts", {})
	quality * 0.0004 * 12.0_boosts["آموزش عالی"] = quality * 0.0004 * 12.0
	econ["sector_boosts"] = quality * 0.0004 * 12.0_boosts
	state["economy"] = econ
	# سرعت پژوهش
	if not research.is_empty():
		research["innovation_index"] = clampf(float(research.get("innovation_index", 0.30)) + quality * 0.001, 0.05, 1.0)
		state["research_policy"] = research
	if tech.has("research_rate"):
		tech["research_rate"] = float(tech.get("research_rate", 10.0)) * (1.0 + quality * 0.003)
		state["technology"] = tech

	# هزینه
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + gdp * (0.002 + funding * 0.003)
	state["economy"] = econ

	# رویدادها
	if ranking > 0.65 and Deterministic.chance(0.03):
		events.append({"type": "uni_ranking", "message": "🎓 دانشگاه‌های کشور در رتبه‌بندی جهانی درخشیدند؛ دانشجوی خارجی جذب شد"})
	elif quality < 0.25 and Deterministic.chance(0.04):
		events.append({"type": "brain_drain_uni", "message": "📉 افت کیفیت دانشگاه، مهاجرت نخبگان را تشدید کرد"})
	elif research_u > 0.60 and Deterministic.chance(0.025):
		events.append({"type": "research_win", "message": "🔬 پارک علم و فناوری دانشگاه، شرکت‌های دانش‌بنیان جدید تولید کرد"})

	state["higher_ed_policy"] = hp
	return {"state": state, "events": events}

func increase_funding(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var hp: Dictionary = state["higher_ed_policy"]
	if turn - int(hp.get("last_endowment", -99)) < 5:
		return {"success": false, "reason": "افزایش بودجه دانشگاه هر ۵ نوبت یک بار", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.004
	hp["last_endowment"] = turn
	hp["funding"] = clampf(float(hp.get("funding", 0.30)) + 0.15, 0.0, 1.0)
	state["economy"] = econ
	state["higher_ed_policy"] = hp
	return {"success": true, "state": state,
		"events": [{"type": "uni_funding", "message": "💰 بودجه پژوهشی و عمرانی دانشگاه‌ها افزایش یافت"}]}

func research_grant(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var hp: Dictionary = state["higher_ed_policy"]
	hp["research"] = clampf(float(hp.get("research", 0.25)) + 0.15, 0.0, 1.0)
	state["higher_ed_policy"] = hp
	return {"success": true, "state": state,
		"events": [{"type": "grant", "message": "🔬 گرنت‌های پژوهشی اساتید و دانشجویان تحصیلات تکمیلی گسترش یافت"}]}

func faculty_development(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var hp: Dictionary = state["higher_ed_policy"]
	hp["faculty"] = clampf(float(hp.get("faculty", 0.30)) + 0.15, 0.0, 1.0)
	state["higher_ed_policy"] = hp
	return {"success": true, "state": state,
		"events": [{"type": "faculty", "message": "👨‍🏫 جذب هیئت علمی و فرصت مطالعاتی تقویت شد"}]}

func internationalize(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var hp: Dictionary = state["higher_ed_policy"]
	hp["international"] = clampf(float(hp.get("international", 0.15)) + 0.15, 0.0, 1.0)
	state["higher_ed_policy"] = hp
	return {"success": true, "state": state,
		"events": [{"type": "intl_uni", "message": "🌐 تبادل دانشجو و استاد با دانشگاه‌های جهان افزایش یافت"}]}
