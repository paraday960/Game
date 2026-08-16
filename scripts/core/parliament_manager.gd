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
# هر وعده یک «تعهد قابل سنجش» است: متریک و جهتِ محقق‌شدن (عمق‌بخشی ۴۵).
# در انتخابات به‌جای اجرای اتفاقی، بررسی می‌شود که آیا بازیکن واقعاً آن را
# محقق کرده است؛ وعدهٔ شکسته رأی و اعتماد می‌سوزاند.
const PROMISES := {
	"tax_cut": {"name_fa": "کاهش مالیات", "effect": "رشد خصوصی +، درآمد دولت −",
		"metric": "economy.tax_rate", "direction": "down"},
	"welfare_expand": {"name_fa": "گسترش رفاه", "effect": "شادی +، بودجه −",
		"metric": "population.happiness", "direction": "up"},
	"infra_boom": {"name_fa": "جهش زیرساخت", "effect": "زیرساخت +، بدهی +",
		"metric": "infrastructure.quality", "direction": "up"},
	"security_line": {"name_fa": "خط امنیتی قاطع", "effect": "ارتش +، تنش منطقه‌ای +",
		"metric": "military.power", "direction": "up"},
	"fight_corruption": {"name_fa": "مبارزه با فساد", "effect": "فساد −، فشار نخبگان",
		"metric": "politics.corruption", "direction": "down"},
	"green_turn": {"name_fa": "چرخش سبز", "effect": "انرژی پاک +، محبوبیت جهانی +",
		"metric": "technology.branches.انرژی_پاک", "direction": "up"}
}

# ── کمکی: خواندن متریک از مسیر و بررسی محقق‌شدن ──
func _read_metric(state: Dictionary, path: String) -> float:
	var current: Variant = state
	for part in path.split("."):
		if current is Dictionary and current.has(part):
			current = current[part]
		else:
			return -1.0
	return float(current) if current is float or current is int else -1.0

func _promise_kept(state: Dictionary, promise: Dictionary) -> bool:
	var pid := str(promise.get("id", ""))
	var definition: Dictionary = PROMISES.get(pid, {})
	var metric := str(definition.get("metric", ""))
	var direction := str(definition.get("direction", "up"))
	var baseline := float(promise.get("baseline", -1.0))
	var current := _read_metric(state, metric)
	if baseline < 0.0 or current < 0.0:
		return false
	# آستانه: تغییر واقعی لازم است نه نوسان جزیی
	if direction == "down":
		return current < baseline - 0.005
	return current > baseline + 0.005

func promise_ids(promises: Array) -> Array:
	var out: Array = []
	for p in promises:
		if p is Dictionary:
			out.append(str(p.get("id", "")))
		else:
			out.append(str(p))
	return out

func has_promise(promises: Array, pid: String) -> bool:
	return promise_ids(promises).has(pid)

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
	var promises: Array = par.get("promises", [])
	if promises.size() >= 2:
		return {"valid": false, "reason": "حداکثر ۲ وعده می‌توانید بدهید"}
	if has_promise(promises, promise_id):
		return {"valid": false, "reason": "این وعده قبلاً ثبت شده"}
	return {"valid": true, "reason": ""}

func add_promise(state: Dictionary, promise_id: String) -> Dictionary:
	state = ensure(state)
	var check := can_promise(state, promise_id)
	if not check.valid:
		return {"success": false, "reason": check.reason, "state": state, "events": []}
	var par: Dictionary = state["parliament"]
	var promises: Array = par.get("promises", [])
	# baseline از وضعیت فعلی متریک — مبنای سنجش محقق‌شدن در انتخابات
	var definition: Dictionary = PROMISES[promise_id]
	promises.append({
		"id": promise_id,
		"promised_turn": int(state.get("tick", 0)),
		"baseline": _read_metric(state, str(definition.get("metric", "")))
	})
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

	# پشتیبانی از شاخص‌ها + وعده‌ها (وعده‌ها رأی می‌آورند — اما باید محقق شوند)
	var support := 0.35 + happiness * 0.3 + stability * 0.15 + media_approval / 100.0 * 0.2
	support -= unemployment * 0.8 + inflation * 0.6 + corruption * 0.4
	if at_war:
		support -= 0.03
	for pr in par.get("promises", []):
		support += 0.02
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
		# پاسخگویی وعده‌ها (عمق‌بخشی ۴۵): به‌جای اجرای اتفاقی، سنجش محقق‌شدن.
		# وعدهٔ محقق‌شده → ماندات و اعتماد؛ وعدهٔ شکسته → رأی و اعتماد می‌سوزد.
		var kept_count := 0
		var broken_count := 0
		var broken_names: Array = []
		for pr in promises:
			var pid := str(pr.get("id", ""))
			if _promise_kept(state, pr):
				kept_count += 1
				events.append({"type": "promise_kept", "promise_id": pid,
					"message": "✅ وعدهٔ «%s» محقق شد؛ رأی‌دهندگان به عمل دولت رأی دادند" % PROMISES.get(pid, {}).get("name_fa", pid)})
			else:
				broken_count += 1
				broken_names.append(str(PROMISES.get(pid, {}).get("name_fa", pid)))
				media["trust"] = clampf(float(media.get("trust", 0.55)) - 0.02, 0.05, 1.0)
				pol["trust"] = clampf(float(pol.get("trust", 0.55)) - 0.02, 0.05, 1.0)
		if broken_count > 0:
			events.append({"type": "broken_promise", "count": broken_count,
				"message": "💔 وعده‌های شکسته: «%s» — رأی‌دهندگان ناامید و بی‌اعتماد شدند" % "، ".join(broken_names)})
		# ماندات: وعده‌های محقق‌شده دستور قوی می‌سازند؛ شکسته‌ها آن را می‌شکنند
		var promise_effects := float(kept_count) * 0.02 - float(broken_count) * 0.03
		result_support = clampf(result_support + promise_effects, 0.05, 0.95)
		result_mandate = clampf((result_support - 0.35) / 0.3, 0.15, 1.0)
		won = result_support >= 0.42
		par["last_result"] = {"turn": turn, "support": result_support, "mandate": result_mandate, "won": won, "promises_kept": kept_count, "promises_broken": broken_count}
		par["mandate"] = result_mandate
		var history: Array = par.get("history", [])
		history.append({"turn": turn, "support": result_support, "mandate": result_mandate, "won": won,
			"promises_kept": kept_count, "promises_broken": broken_count, "promises": promises.duplicate()})
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
