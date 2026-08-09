extends BaseSystem
# زیرساخت - ۳.۱۵

func compute(state: Dictionary, tick: int) -> Dictionary:
	var infra = state["infrastructure"]
	var econ = state["economy"]
	var pop = state["population"]
	var resources = state["resources"]

	var events = []

	var budget = econ["budget_allocations"].get("زیرساخت", 0.18) * econ["government_spending"]

	# کیفیت زیرساخت
	var maintenance_need = infra["quality"] * 0.02 * econ["gdp"] * 0.01  # ۲٪ ارزش سالانه
	if budget < maintenance_need:
		infra["quality"] -= 0.001  # فرسودگی ۵٪ سالانه ۳.۱۵.۴
	else:
		infra["quality"] += 0.0005

	infra["quality"] = clamp(infra["quality"], 0.1, 1.0)

	# ظرفیت - اثر گلوگاه
	var demand = pop["total"] / 85_000_000.0
	var capacity_ratio = demand / max(infra["capacity"], 0.1)
	if capacity_ratio > 1.0:
		events.append({"type": "bottleneck", "ratio": capacity_ratio, "message": "گلوگاه زیرساختی - تقاضا بیش از ظرفیت"})
		infra["capacity"] += 0.0002  # سرمایه‌گذاری خودکار کم
	else:
		infra["capacity"] = clamp(infra["capacity"] + 0.0001, 0.2, 1.5)

	# اثر زیرساخت بر رشد - هر +۱۰ کیفیت → +۰.۵٪ رشد ۳.۱۵.۴
	var growth_bonus = (infra["quality"] - 0.5) * 0.05
	# این در اقتصاد اعمال می‌شود اما اینجا ثبت

	# بلایای طبیعی به زیرساخت آسیب می‌زند
	if Deterministic.chance(0.005):
		var damage = Deterministic.next_range(0.01, 0.05)
		infra["quality"] -= damage
		events.append({"type": "infrastructure_damage", "damage": damage, "message": "آسیب به زیرساخت به دلیل بلای طبیعی"})

	state["infrastructure"] = infra
	return {"success": true, "state": state, "events": events}
