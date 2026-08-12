extends Node
# ────────────────────────────────────────────────────────────────────────────
# نظام انتخاباتی تعاملی و مجلس — عمق سیاست (حلقه راهبردی ۴ ساله)
# هر ۴۸ نوبت انتخابات برگزار می‌شود. بازیکن با «وعده‌های انتخاباتی» (۲ وعده)
# کمپین می‌کند؛ نتیجه انتخابات «دستور» (ماندات) می‌سازد که هزینه سیاست را
# کم/زیاد می‌کند و ترکیب مجلس/ائتلاف را مشخص می‌کند. انتخابات زودهنگام ریسکی است.
#
# state["parliament"] = {
#   "next_election_turn": 48, "promises": [id,id], "mandate": 0..1,
#   "support": 0..1, "last_result": {turn, support, mandate}, "snap_used": false,
#   "history": [...]
# }
# ────────────────────────────────────────────────────────────────────────────

const ELECTION_INTERVAL := 48
const PROMISES := {
	"tax_cut": {"name_fa": "کاهش مالیات", "effect": "رشد خصوصی +، درآمد دولت −"},
	"welfare_expand": {"name_fa": "گسترش رفاه", "effect": "شادی +، بودجه −"},
	"infra_boom": {"name_fa": "جهش زیرساخت", "effect": "زیرساخت +، بدهی +"},
	"security_line": {"name_fa": "خط امنیتی قاطع", "effect": "ارتش +، تنش منطقه‌ای +"},
	"fight_corruption": {"name_fa": "مبارزه با فساد", "effect": "فساد −، فشار نخبگان"},
	"green_turn": {"name_fa": "چرخش سبز", "effect": "انرژی پاک +، محبوبیت جهانی +"}
}

func ensure(state: Dictionary) -> Dictionary:
	if not state.has("parliament"):
		state["parliament"] = {
			"next_election_turn": ELECTION_INTERVAL,
			"promises": [],
			"mandate": 0.5,
			"support": 0.52,
			"last_result": {},
			"snap_used": false,
			"history": []
		}
	return state

# ── انتخابات زودهنگام (ریسک: شکست = ماندات صفر و افت ثبات) ──
func can_snap(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var par: Dictionary = state["parliament"]
	if bool(par.get("snap_used", false)):
		return {"valid": false, "reason": "یک بار در هر دوره می‌توان انتخابات زودهنگام گرفت"}
	if int(par.get("next_election_turn", 0)) <= turn:
		return {"valid": false, "reason": "انتخابات عادی نزدیک است"}
	return {"valid": true, "reason": ""}

func snap_election(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var check := can_snap(state, turn)
	if not check.valid:
		return {"success": false, "reason": check.reason, "state": state, "events": []}
	var par: Dictionary = state["parliament"]
	par["snap_used"] = true
	par["next_election_turn"] = turn + 1
	state["parliament"] = par
	return {"success": true, "state": state,
		"events": [{"type": "snap_election", "message": "🗳️ انتخابات زودهنگام اعلام شد! همه‌چیز به رضایت مردم بستگی دارد."}]}

# ── ثبت وعده انتخاباتی (حداکثر ۲؛ قبل از انتخابات) ──
func can_promise(state: Dictionary, promise_id: String) -> Dictionary:
	state = ensure(state)
	if not PROMISES.has(promise_id):
		return {"valid": false, "reason": "وعده نامعتبر"}
	var par: Dictionary = state["parliament"]
	if int(par.get("next_election_turn", 0)) > int(state.get("tick", 0)) + 6:
		return {"valid": false, "reason": "وعده‌ها فقط در ۶ نوبت پایانی قبل از انتخابات ثبت می‌شوند"}
	if par.get("promises", []).size() >= 2:
		return {"valid": false, "reason": "حداکثر ۲ وعده می‌توانید بدهید"}
	if par.get("promises", []).has(promise_id):
		return {"valid": false, "reason": "این وعده قبلاً ثبت شده"}
	return {"valid": true, "reason": ""}

func add_promise(state: Dictionary, promise_id: String) -> Dictionary:
	state = ensure(state)
	var check := can_promise(state, promise_id)
	if not check.valid:
		return {"success": false, "reason": check.reason, "state": state, "events": []}
	var par: Dictionary = state["parliament"]
	var promises: Array = par.get("promises", [])
	promises.append(promise_id)
	par["promises"] = promises
	state["parliament"] = par
	return {"success": true, "state": state,
		"events": [{"type": "campaign_promise", "message": "📣 وعده انتخاباتی: «%s»" % PROMISES[promise_id]["name_fa"]}]}

# ── شبیه‌سازی ماهانه: پشتیبانی، ماندات، انتخابات ──
func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var par: Dictionary = state["parliament"]
	var pol: Dictionary = state.get("politics", {})
	var pop: Dictionary = state.get("population", {})
	var econ: Dictionary = state.get("economy", {})
	var media: Dictionary = state.get("media", {})
	var world: Dictionary = state.get("world", {})
	var at_war: bool = not world.get("wars", {}).is_empty()
	var unemployment := float(econ.get("unemployment", 0.08))
	var inflation := float(econ.get("inflation", 0.08))
	var corruption := float(pol.get("corruption", 0.3))
	var stability := float(pol.get("stability", 0.6))
	var happiness := float(pop.get("happiness", 0.6))
	var trust := float(media.get("trust", 0.55))
	var media_approval := MediaManager.overall_approval(state)

	# پشتیبانی از شاخص‌ها + وعده‌ها
	var support := 0.35 + happiness * 0.3 + stability * 0.15 + media_approval / 100.0 * 0.2
	support -= unemployment * 0.8 + inflation * 0.6 + corruption * 0.4
	if at_war:
		support -= 0.03
	for pid in par.get("promises", []):
		support += 0.02  # وعده‌ها رأی می‌آورند
	support += (float(pol.get("political_capital", 0.0)) - 2.5) * 0.01
	par["support"] = clampf(support, 0.05, 0.95)

	# اثر ماندات بر هزینه سیاست (پایین‌تر = ارزان‌تر)
	var mandate := float(par.get("mandate", 0.5))
	var mandate_drift := (float(par.get("support", 0.5)) - 0.55) * 0.02
	par["mandate"] = clampf(mandate + mandate_drift, 0.1, 1.0)

	# برگزاری انتخابات
	if int(par.get("next_election_turn", 0)) <= turn:
		var result_support := float(par.get("support", 0.5))
		var result_mandate := clampf((result_support - 0.35) / 0.3, 0.15, 1.0)
		var won := result_support >= 0.42
		par["last_result"] = {"turn": turn, "support": result_support, "mandate": result_mandate, "won": won}
		par["mandate"] = result_mandate
		par["next_election_turn"] = turn + ELECTION_INTERVAL
		par["snap_used"] = false
		var promises: Array = par.get("promises", [])
		par["promises"] = []
		# اثر وعده‌های محقق‌شده (ماندات)
		var promise_effects := 0.0
		for pid in promises:
			match str(pid):
				"tax_cut":
					econ["tax_rate"] = clampf(float(econ.get("tax_rate", 0.2)) - 0.02, 0.05, 0.45)
					promise_effects += 0.02
				"welfare_expand":
					pop["happiness"] = clampf(float(pop.get("happiness", 0.6)) + 0.02, 0.05, 1.0)
					promise_effects += 0.01
				"infra_boom":
					state.get("infrastructure", {})["quality"] = clampf(float(state.get("infrastructure", {}).get("quality", 0.55)) + 0.01, 0.05, 1.0)
					econ["national_debt"] = float(econ.get("national_debt", 0.0)) + float(econ.get("gdp", 1.0)) * 0.005
					promise_effects += 0.01
				"security_line":
					state.get("military", {})["power"] = float(state.get("military", {}).get("power", 50.0)) * 1.02
					promise_effects += 0.01
				"fight_corruption":
					pol["corruption"] = clampf(float(pol.get("corruption", 0.3)) - 0.03, 0.0, 1.0)
					promise_effects += 0.01
				"green_turn":
					state.get("technology", {}).get("branches", {})["انرژی_پاک"] = clampf(float(state.get("technology", {}).get("branches", {}).get("انرژی_پاک", 0.15)) + 0.01, 0.0, 1.0)
					promise_effects += 0.01
		var history: Array = par.get("history", [])
		history.append({"turn": turn, "support": result_support, "mandate": result_mandate, "won": won, "promises": promises.duplicate()})
		while history.size() > 20:
			history.pop_front()
		par["history"] = history
		var msg := "🗳️ انتخابات برگزار شد: دولت با %s٪ آرا پیروز شد و دستور قوی گرفت" if won else "🗳️ انتخابات برگزار شد: دولت با %s٪ آرا در اقلیت ماند و ماندات ضعیف است"
		events.append({"type": "election_held", "message": msg % PersianFormatter.to_persian_digits(str(int(result_support * 100.0)))})
		if not won:
			pol["stability"] = clampf(float(pol.get("stability", 0.6)) - 0.04, 0.05, 1.0)
			events.append({"type": "election_loss", "message": "اقلیت در مجلس یعنی سیاست‌های پرهزینه و فشار ائتلاف‌ها"})
		# به‌روزرسانی‌ها ذخیره شود
		state["population"] = pop
		state["politics"] = pol
		state["economy"] = econ
	state["parliament"] = par
	state["politics"] = pol
	return {"state": state, "events": events}
