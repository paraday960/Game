extends BaseAI
# هوش تجارت خرد - ۳.۴۵ - دترمینستیک و اتمی

func decide(state: Dictionary, tick: int) -> Array:
	var r = state.get("retail", {})
	var econ = state.get("economy", {})
	var cmds = []

	# پوشش خرده‌فروشی افت کرده → تحریک تقاضا با کاهش مالیات
	if r.get("coverage", 0.85) < 0.60 and econ.get("tax_rate", 0.20) > 0.15:
		cmds.append(GameCommand.create_tax_set(clamp(econ["tax_rate"] - 0.01, 0.10, 0.40)))

	# رقابت بیش از حد کم (انحصار) → پیشنهاد اجرای قانون ضدانحصار
	if r.get("competition", 0.60) < 0.30 and not state.get("policies", {}).get("active", {}).has("antitrust_enforcement"):
		cmds.append(GameCommand.create_policy_change("antitrust_enforcement", true))

	return cmds

func evaluate(state: Dictionary) -> float:
	var r = state.get("retail", {})
	return r.get("coverage", 0.85) * 0.6 + r.get("competition", 0.60) * 0.4
