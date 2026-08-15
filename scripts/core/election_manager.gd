extends Node
# ────────────────────────────────────────────────────────────────────────────
# انتخابات و رقابت سیاسی — عمق مشروعیت و دموکراسی
# روی لایه پارلمان می‌نشیند: انتخابات منصفانه، نظارت بر انتخابات، احزاب،
# مشارکت مردمی و رسانه‌های مستقل. انتخابات شفاف مشروعیت می‌سازد و حاکمیت
# قانون را تحکیم می‌کند؛ تقلب یا سرکوب در کوتاه‌مدت قدرت می‌دهد ولی
# خیزش و بی‌اعتمادی پنهان انبار می‌کند.
# پیوند: سیاست، رسانه، مشارکت مدنی، ثبات، رهبری.
#
# state["election_policy"] = {
#   "fairness":0..1, "voter_access":0..1, "party_pluralism":0..1,
#   "media_monitoring":0..1, "campaign_finance":0..1,
#   "next_election_turn":48, "legitimacy":0..1, "turnout":0..1 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("election_policy"):
		state["election_policy"] = {
			"fairness": 0.55, "voter_access": 0.60, "party_pluralism": 0.50,
			"media_monitoring": 0.45, "campaign_finance": 0.40,
			"next_election_turn": 48, "legitimacy": 0.60, "turnout": 0.60,
			"last_election": -99, "suppressed": 0, "opposition_pressure": 0.30
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var ep: Dictionary = state["election_policy"]
	var pol: Dictionary = state.get("politics", {})
	var media: Dictionary = state.get("media", {})
	var civic: Dictionary = state.get("civic_policy", {})
	var pop: Dictionary = state.get("population", {})

	var fairness := float(ep.get("fairness", 0.55))
	var access := float(ep.get("voter_access", 0.60))
	var pluralism := float(ep.get("party_pluralism", 0.50))
	var media_mon := float(ep.get("media_monitoring", 0.45))
	var finance := float(ep.get("campaign_finance", 0.40))

	# مشارکت انتخاباتی از دسترسی + آزادی احزاب + اعتماد
	var turnout := clampf(
		0.25 + access * 0.25 + pluralism * 0.20 + fairness * 0.15 +
		float(civic.get("social_capital", 0.5)) * 0.15, 0.15, 0.95)
	ep["turnout"] = turnout

	# مشروعیت: انتخابات منصفانه + مشارکت
	var legitimacy := clampf(
		0.20 + fairness * 0.30 + turnout * 0.25 + pluralism * 0.20 +
		media_mon * 0.15 + float(media.get("trust", 0.55)) * 0.10, 0.05, 0.98)
	ep["legitimacy"] = legitimacy

	# اعتراض سرکوب‌شده انباشته می‌شود
	var suppressed := float(ep.get("suppressed", 0))
	var opp_pressure := clampf(
		(1.0 - fairness) * 0.35 + (1.0 - pluralism) * 0.25 + suppressed * 0.20, 0.05, 0.95)
	ep["opposition_pressure"] = opp_pressure
	# با هرچه مشروعیت بالاتر، فشار به‌آرامی تخلیه می‌شود
	suppressed = clampf(suppressed - (legitimacy - 0.5) * 0.01 - 0.002, 0.0, 1.0)
	ep["suppressed"] = suppressed

	# اثر بر سیاست و ثبات
	pol["trust"] = clampf(float(pol.get("trust", 0.55)) + (legitimacy - 0.5) * 0.003, 0.05, 1.0)
	pol["stability"] = clampf(float(pol.get("stability", 0.60)) + legitimacy * 0.001 - opp_pressure * 0.001, 0.05, 1.0)
	state["politics"] = pol

	# آزادی احزاب به حاکمیت قانون کمک می‌کند
	var jud: Dictionary = state.get("judicial", {})
	if not jud.is_empty():
		jud["independence"] = clampf(float(jud.get("independence", 0.55)) + pluralism * 0.0005, 0.1, 1.0)
		state["judicial"] = jud

	# رسانه مستقل
	media["trust"] = clampf(float(media.get("trust", 0.55)) + media_mon * 0.001, 0.05, 1.0)
	state["media"] = media

	# شمارش معکوس انتخابات
	ep["next_election_turn"] = maxi(0, int(ep.get("next_election_turn", 48)) - 1)

	# رویدادها
	if opp_pressure > 0.70 and suppressed > 0.30 and Deterministic.chance(0.05):
		pol["stability"] = clampf(float(pol.get("stability", 0.60)) - 0.020, 0.05, 1.0)
		pop["happiness"] = clampf(float(pop.get("happiness", 0.60)) - 0.010, 0.05, 1.0)
		state["politics"] = pol
		state["population"] = pop
		events.append({"type": "election_unrest", "message": "🗳️ در آستانه انتخابات، سرکوب اعتراض‌ها به خیزش انجامید"})
	elif fairness > 0.75 and turnout > 0.70 and Deterministic.chance(0.03):
		var pol_el: Dictionary = state.get("politics", {})
		pol_el["legitimacy"] = clampf(float(pol_el.get("legitimacy", 0.58)) + 0.02, 0.1, 0.95)
		pol_el["trust"] = clampf(float(pol_el.get("trust", 0.55)) + 0.015, 0.05, 1.0)
		state["politics"] = pol_el
		events.append({"type": "election_legitimacy", "message": "🗳️ انتخابات پرشور و منصفانه، مشروعیت ملی را تقویت کرد"})

	state["election_policy"] = ep
	return {"state": state, "events": events}

# ── برگزاری انتخابات ──
func hold_election(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var ep: Dictionary = state["election_policy"]
	if int(ep.get("next_election_turn", 48)) > 1:
		return {"success": false, "reason": "هنوز زمان انتخابات فرا نرسیده است", "state": state, "events": []}
	# latch بازرسی ۱۴۰۵: last_election از کلید نوشته‌بی‌خوان به کول‌داون واقعی بدل شد —
	# انتخابات زودهنگام حداقل یک سال پس از دور قبلی ممکن است (پایداری نهادها)
	if turn - int(ep.get("last_election", -99)) < 12:
		return {"success": false, "reason": "انتخابات زودهنگام حداقل یک سال پس از دور قبلی ممکن است", "state": state, "events": []}
	var fairness := float(ep.get("fairness", 0.55))
	var turnout := float(ep.get("turnout", 0.60))
	var legitimacy := clampf(fairness * 0.5 + turnout * 0.3 + 0.2, 0.1, 0.98)
	ep["legitimacy"] = legitimacy
	ep["last_election"] = turn
	ep["next_election_turn"] = 48
	var pol: Dictionary = state.get("politics", {})
	pol["trust"] = clampf(float(pol.get("trust", 0.55)) + (fairness - 0.5) * 0.05, 0.05, 1.0)
	state["politics"] = pol
	state["election_policy"] = ep
	var msg: String = "🗳️ انتخابات برگزار شد؛ مشارکت بالا رفت" if fairness > 0.5 else "⚠️ انتخابات با ایرادهای نظارتی برگزار شد"
	return {"success": true, "state": state,
		"events": [{"type": "election", "message": msg}]}

# ── نظارت مستقل انتخابات ──
func strengthen_monitoring(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var ep: Dictionary = state["election_policy"]
	if float(ep.get("media_monitoring", 0.45)) >= 0.95:
		return {"success": false, "reason": "نظارت انتخابات در سقف است", "state": state, "events": []}
	ep["media_monitoring"] = clampf(float(ep.get("media_monitoring", 0.45)) + 0.15, 0.0, 1.0)
	ep["fairness"] = clampf(float(ep.get("fairness", 0.55)) + 0.05, 0.0, 1.0)
	state["politics"]["trust"] = clampf(state["politics"].get("trust", 0.55) + 0.005, 0.05, 1.0)
	state["election_policy"] = ep
	return {"success": true, "state": state,
		"events": [{"type": "election_monitor", "message": "🔍 نهاد ناظر مستقل و شفافیت مالی انتخابات تقویت شد"}]}

# ── دسترسی به صندوق رأی ──
func improve_voter_access(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var ep: Dictionary = state["election_policy"]
	if float(ep.get("voter_access", 0.60)) >= 0.95:
		return {"success": false, "reason": "دسترسی رأی‌دهندگان در سقف است", "state": state, "events": []}
	ep["voter_access"] = clampf(float(ep.get("voter_access", 0.60)) + 0.15, 0.0, 1.0)
	state["media"]["trust"] = clampf(state["media"].get("trust", 0.55) + 0.004, 0.05, 1.0)
	state["election_policy"] = ep
	return {"success": true, "state": state,
		"events": [{"type": "voter_access", "message": "🗳️ دسترسی روستاییان و اقلیت‌ها به صندوق رأی بهبود یافت"}]}

# ── تکثر احزاب ──
func party_pluralism(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var ep: Dictionary = state["election_policy"]
	if float(ep.get("party_pluralism", 0.50)) >= 0.95:
		return {"success": false, "reason": "تکثر احزاب در سقف است", "state": state, "events": []}
	ep["party_pluralism"] = clampf(float(ep.get("party_pluralism", 0.50)) + 0.15, 0.0, 1.0)
	ep["opposition_pressure"] = clampf(float(ep.get("opposition_pressure", 0.30)) - 0.10, 0.05, 0.95)
	state["election_policy"] = ep
	return {"success": true, "state": state,
		"events": [{"type": "pluralism", "message": "🏛️ فضای رقابت حزبی بازتر شد؛ مخالفان صدای رسمی یافتند"}]}
