extends Node
# ────────────────────────────────────────────────────────────────────────────
# دیپلماسی علمی و فناوری — عمق همکاری دانشی
# توافق‌نامه‌های علمی، آزمایشگاه‌های مشترک، جذب دانشمندان بین‌المللی،
# کنسرسیوم‌های فناوری و دیپلماسی قطب/فضا. این لایه به تبادل دانش،
# سرعت پژوهش، قدرت نرم و اقتصاد دانش‌بنیان کمک می‌کند.
# پیوند: پژوهش، دیاسپورا، فناوری، دیپلماسی، آموزش.
#
# state["science_policy"] = {
#   "bilateral":0..1, "joint_labs":0..1, "scholarships":0..1,
#   "tech_consortium":0..1, "last_agreement":turn,
#   "knowledge_flow":0..1, "brain_gain":0..1 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("science_policy"):
		state["science_policy"] = {
			"bilateral": 0.20, "joint_labs": 0.15, "scholarships": 0.25,
			"tech_consortium": 0.10, "last_agreement": -99,
			"knowledge_flow": 0.20, "brain_gain": 0.15,
			"co_publications": 0.10, "tech_absorption": 0.25
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var sp: Dictionary = state["science_policy"]
	var tech: Dictionary = state.get("technology", {})
	var research: Dictionary = state.get("research_policy", {})
	var edu: Dictionary = state.get("education", {})
	var dip: Dictionary = state.get("diplomacy", {})
	var diaspora: Dictionary = state.get("diaspora_policy", {})

	var bilateral: float = float(sp.get("bilateral", 0.20))
	var labs: float = float(sp.get("joint_labs", 0.15))
	var scholarship: float = float(sp.get("scholarships", 0.25))
	var consortium: float = float(sp.get("tech_consortium", 0.10))

	# جریان دانش: توافق دوجانبه + آزمایشگاه مشترک + بورس
	var knowledge: float = clampf(
		0.05 + bilateral * 0.25 + labs * 0.25 + scholarship * 0.20 + consortium * 0.20,
		0.05, 0.98)
	sp["knowledge_flow"] = knowledge
	sp["co_publications"] = clampf(0.05 + bilateral * 0.30 + labs * 0.30 + scholarship * 0.20, 0.0, 0.95)

	# جذب نخبگان: بورس + دیاسپورا
	var diaspora_trust: float = float(diaspora.get("trust", 0.45))
	var brain_gain: float = clampf(
		0.05 + scholarship * 0.30 + bilateral * 0.15 + labs * 0.20 + diaspora_trust * 0.20,
		0.02, 0.90)
	sp["brain_gain"] = brain_gain

	# جذب فناوری
	var edu_q: float = float(edu.get("quality", 0.55))
	var absorption: float = clampf(0.15 + knowledge * 0.40 + edu_q * 0.30, 0.05, 0.98)
	sp["tech_absorption"] = absorption

	# اثر بر پژوهش و فناوری
	if research.has("innovation_index"):
		research["innovation_index"] = clampf(float(research.get("innovation_index", 0.30)) + knowledge * 0.001, 0.05, 1.0)
		state["research_policy"] = research
	if tech.has("branch_levels") and tech["branch_levels"].has("دیجیتال"):
		tech["research_rate"] = float(tech.get("research_rate", 10.0)) * (1.0 + knowledge * 0.003)
		state["technology"] = tech

	# قدرت نرم
	dip["soft_power"] = clampf(float(dip.get("soft_power", 35.0)) + knowledge * 0.05, 0.0, 100.0)
	state["diplomacy"] = dip

	# فرار مغزها کم می‌شود
	if research.has("brain_drain"):
		research["brain_drain"] = clampf(float(research.get("brain_drain", 0.28)) - brain_gain * 0.002, 0.05, 0.80)
		state["research_policy"] = research

	# رویدادها
	if knowledge > 0.65 and Deterministic.chance(0.03):
		events.append({"type": "science_breakthrough", "message": "🔬 همکاری علمی بین‌المللی به یک کشف مشترک انجامید"})
	elif brain_gain > 0.60 and Deterministic.chance(0.025):
		var tech_bg: Dictionary = state.get("technology", {})
		tech_bg["research_rate"] = float(tech_bg.get("research_rate", 20.0)) + 2.0
		state["technology"] = tech_bg
		events.append({"type": "brain_gain", "message": "🧑‍🔬 دانشمندان برجسته به کشور بازگشتند؛ سرعت پژوهش بالا رفت"})
	elif consortium > 0.60 and Deterministic.chance(0.02):
		events.append({"type": "tech_consortium", "message": "🤝 کنسرسیوم فناوری دسترسی به دانش پیشرفته را گشود"})

	state["science_policy"] = sp
	return {"state": state, "events": events}

func science_agreement(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["science_policy"]
	if turn - int(sp.get("last_agreement", -99)) < 6:
		return {"success": false, "reason": "توافق علمی هر ۶ نوبت یک بار", "state": state, "events": []}
	sp["last_agreement"] = turn
	sp["bilateral"] = clampf(float(sp.get("bilateral", 0.20)) + 0.15, 0.0, 1.0)
	state["science_policy"] = sp
	return {"success": true, "state": state,
		"events": [{"type": "bilateral", "message": "📜 توافق‌نامه همکاری علمی دوجانبه امضا شد"}]}

func joint_lab(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["science_policy"]
	if float(sp.get("joint_labs", 0.15)) >= 0.95:
		return {"success": false, "reason": "آزمایشگاه‌های مشترک در سقف هستند", "state": state, "events": []}
	var tech_level: float = float(state.get("technology", {}).get("branch_levels", {}).get("دیجیتال", 0))
	if tech_level < 4:
		return {"success": false, "reason": "به فناوری دیجیتال سطح ۴ نیاز است", "state": state, "events": []}
	sp["joint_labs"] = clampf(float(sp.get("joint_labs", 0.15)) + 0.15, 0.0, 1.0)
	state["science_policy"] = sp
	return {"success": true, "state": state,
		"events": [{"type": "joint_lab", "message": "🔬 آزمایشگاه مشترک تحقیقاتی تأسیس شد"}]}

func scholarship_program(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["science_policy"]
	sp["scholarships"] = clampf(float(sp.get("scholarships", 0.25)) + 0.15, 0.0, 1.0)
	state["science_policy"] = sp
	return {"success": true, "state": state,
		"events": [{"type": "scholarship", "message": "🎓 برنامه بورس بین‌المللی دانشجویان و اساتید گسترش یافت"}]}

func tech_consortium(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var sp: Dictionary = state["science_policy"]
	sp["tech_consortium"] = clampf(float(sp.get("tech_consortium", 0.10)) + 0.15, 0.0, 1.0)
	state["science_policy"] = sp
	return {"success": true, "state": state,
		"events": [{"type": "consortium", "message": "🌐 مشارکت در کنسرسیوم بین‌المللی فناوری آغاز شد"}]}
