extends Node
# ────────────────────────────────────────────────────────────────────────────
# اقتصاد سایه و فساد — عمق اقتصادی-سیاسی
# اقتصاد سایه (٪ از GDP) با مالیات بالا، فساد و مقررات رشد می‌کند؛ اشتغال
# غیررسمی را جذب می‌کند ولی درآمد مالیاتی را می‌دزدد. بازیکن سه اهرم دارد:
# سرکوب (کاهش سایه با هزینه ناآرامی)، عفو (بازگشت سرمایه با از دست دادن
# درآمد)، و رسیدگی به رسوایی‌های فساد (پوشش/تحقیق/نادیده‌گرفتن).
#
# state["shadow"] = { "size": 0..1, "scandal": {..} | {}, "crackdowns": 0 }
# ────────────────────────────────────────────────────────────────────────────

func ensure(state: Dictionary) -> Dictionary:
	if not state.has("shadow"):
		state["shadow"] = {"size": 0.18, "scandal": {}, "crackdowns": 0}
	return state

# ── شبیه‌سازی ماهانه ──
func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var shadow: Dictionary = state["shadow"]
	var econ: Dictionary = state.get("economy", {})
	var pol: Dictionary = state.get("politics", {})
	var tax := float(econ.get("tax_rate", 0.2))
	var corruption := float(pol.get("corruption", 0.3))
	var unemployment := float(econ.get("unemployment", 0.08))
	var size := float(shadow.get("size", 0.18))

	# رشد سایه: مالیات بالا + فساد + بیکاری
	size += (tax - 0.2) * 0.03 + corruption * 0.01 + unemployment * 0.02
	size -= 0.004  # پوسیدگی طبیعی
	size = clampf(size, 0.03, 0.55)
	shadow["size"] = size

	# اثر: درآمد مالیاتی از دست رفته ولی بیکاری جذب می‌شود
	var tax_loss := size * 0.05
	econ["tax_revenue_loss"] = tax_loss
	econ["unemployment"] = clampf(unemployment - size * 0.004, 0.02, 0.30)

	# رسوایی فساد بزرگ (وزیر/استاندار): هر ~۸ نوبت
	if shadow.get("scandal", {}).is_empty() and Deterministic.chance(0.07):
		var names := ["وزیر اقتصاد", "استاندار کلان‌شهر", "مدیرعامل بانک ملی", "رئیس گمرک"]
		shadow["scandal"] = {"id": names[Deterministic.next_int_range(0, names.size() - 1)], "turn": turn}
		events.append({"type": "corruption_scandal", "message": "🚨 رسوایی فساد «%s» افشا شد! تصمیم بگیرید: پوشش، تحقیق یا نادیده‌گرفتن" % shadow["scandal"]["id"]})
	elif not shadow.get("scandal", {}).is_empty():
		var scandal: Dictionary = shadow["scandal"]
		if turn - int(scandal.get("turn", turn)) >= 2:
			shadow["scandal"] = {}
			events.append({"type": "scandal_faded", "message": "رسوایی فساد بدون رسیدگی به حاشیه رفت؛ اما بی‌اعتمادی باقی ماند"})
			pol["trust"] = clampf(float(pol.get("trust", 0.55)) - 0.02, 0.05, 1.0)
	state["shadow"] = shadow
	state["economy"] = econ
	state["politics"] = pol
	return {"state": state, "events": events}

# ── سرکوب اقتصاد سایه ──
func crackdown(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var shadow: Dictionary = state["shadow"]
	var size := float(shadow.get("size", 0.18))
	if size < 0.08:
		return {"success": false, "reason": "اقتصاد سایه کوچک است؛ سرکوب ارزش ندارد", "state": state, "events": []}
	shadow["size"] = clampf(size * 0.7, 0.03, 0.55)
	shadow["crackdowns"] = int(shadow.get("crackdowns", 0)) + 1
	state["shadow"] = shadow
	# ناآرامی: بخش غیررسمی می‌شورد
	state["politics"]["stability"] = clampf(float(state["politics"].get("stability", 0.6)) - 0.02, 0.05, 1.0)
	state["population"]["happiness"] = clampf(float(state["population"].get("happiness", 0.6)) - 0.015, 0.05, 1.0)
	state["economy"]["foreign_reserves"] = maxf(0.0, float(state["economy"].get("foreign_reserves", 0.0)) + size * float(state["economy"].get("gdp", 1.0)) * 0.002)
	return {"success": true, "state": state,
		"events": [{"type": "shadow_crackdown", "message": "🚔 سرکوب اقتصاد سایه: بخشی از آن جمع شد و درآمد مالیاتی بهبود یافت؛ اما ناآرامی خیابانی بالا گرفت"}]}

# ── عفو مالیاتی ──
func amnesty(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var shadow: Dictionary = state["shadow"]
	var size := float(shadow.get("size", 0.18))
	if size < 0.10:
		return {"success": false, "reason": "اقتصاد سایه کوچک است", "state": state, "events": []}
	shadow["size"] = clampf(size * 0.8, 0.03, 0.55)
	state["shadow"] = shadow
	# بازگشت سرمایه: ذخایر ارزی + سرمایه‌گذاری
	state["economy"]["foreign_reserves"] = float(state["economy"].get("foreign_reserves", 0.0)) + size * float(state["economy"].get("gdp", 1.0)) * 0.004
	state["economy"]["foreign_investment"] = float(state["economy"].get("foreign_investment", 1.0)) * 1.02
	state["politics"]["stability"] = clampf(float(state["politics"].get("stability", 0.6)) + 0.01, 0.05, 1.0)
	return {"success": true, "state": state,
		"events": [{"type": "shadow_amnesty", "message": "🤝 عفو مالیاتی: بخشی از سرمایه‌های خارج‌شده بازگشت و ثبات بهبود یافت"}]}

# ── رسیدگی به رسوایی فساد ──
func handle_scandal(state: Dictionary, decision: String) -> Dictionary:
	state = ensure(state)
	var shadow: Dictionary = state["shadow"]
	var scandal: Dictionary = shadow.get("scandal", {})
	if scandal.is_empty():
		return {"success": false, "reason": "رسوایی فعالی نیست", "state": state, "events": []}
	if not ["cover", "investigate", "ignore"].has(decision):
		return {"success": false, "reason": "تصمیم نامعتبر", "state": state, "events": []}
	var events: Array = []
	var pol: Dictionary = state.get("politics", {})
	var capital := float(state.get("policies", {}).get("political_capital", 0.0))
	match decision:
		"cover":
			if capital < 1.0:
				return {"success": false, "reason": "سرمایه سیاسی برای پوشش کافی نیست", "state": state, "events": []}
			state["policies"]["political_capital"] = capital - 1.0
			pol["corruption"] = clampf(float(pol.get("corruption", 0.3)) + 0.02, 0.0, 1.0)
			var risk := Deterministic.chance(0.4)
			if risk:
				pol["stability"] = clampf(float(pol.get("stability", 0.6)) - 0.05, 0.05, 1.0)
				pol["trust"] = clampf(float(pol.get("trust", 0.55)) - 0.05, 0.05, 1.0)
				events.append({"type": "scandal_cover_exposed", "message": "🔥 پوشش رسوایی فاش شد! رسوایی بزرگ‌تر شد و اعتماد عمومی فرو ریخت"})
			else:
				events.append({"type": "scandal_covered", "message": "🕶️ رسوایی با سرمایه سیاسی پوشیده شد؛ اما فساد ریشه دواند"})
		"investigate":
			pol["corruption"] = clampf(float(pol.get("corruption", 0.3)) - 0.04, 0.0, 1.0)
			pol["trust"] = clampf(float(pol.get("trust", 0.55)) + 0.04, 0.05, 1.0)
			state["policies"]["political_capital"] = capital + 0.5
			# واکنش جناح نخبگان
			var factions: Dictionary = state.get("factions", {})
			if factions.has("نخبگان اقتصادی"):
				var f: Dictionary = factions["نخبگان اقتصادی"]
				f["loyalty"] = clampf(float(f.get("loyalty", 50.0)) - 6.0, 0.0, 100.0)
				factions["نخبگان اقتصادی"] = f
				state["factions"] = factions
			events.append({"type": "scandal_investigated", "message": "⚖️ تحقیق درباره رسوایی آغاز شد: مفسدان مجازات شدند و اعتماد عمومی بازگشت؛ اما نخبگان ناخرسندند"})
		"ignore":
			pol["trust"] = clampf(float(pol.get("trust", 0.55)) - 0.03, 0.05, 1.0)
			pol["stability"] = clampf(float(pol.get("stability", 0.6)) - 0.01, 0.05, 1.0)
			events.append({"type": "scandal_ignored", "message": "🤷 رسوایی نادیده گرفته شد؛ افکار عمومی به بی‌تفاوتی دولت پی برد"})
	shadow["scandal"] = {}
	state["shadow"] = shadow
	state["politics"] = pol
	return {"success": true, "state": state, "events": events}
