extends BaseSystem
# سیستم منابع و انرژی - بخش ۳.۹ کامل - با عمق واقع‌گرایانه

func compute(state: Dictionary, tick: int) -> Dictionary:
	var res = state["resources"]
	var pop = state["population"]
	var econ = state["economy"]
	var infra = state["infrastructure"]
	var tech = state["technology"]

	# بخش الف) تولید ناخالص منابع - ۳.۹.۳
	for resource_name in res["production"].keys():
		var prod_capacity = res["capacity"][resource_name] if res["capacity"].has(resource_name) else 100.0
		var base_prod = res["production"][resource_name]
		
		# بازده تولید = f(انرژی تامین‌شده، زیرساخت، فناوری، نیروی کار)
		var energy_factor = 1.0
		if res["inventory"]["برق"] < 20:
			energy_factor = 0.5  # ضریب بحران انرژی - ۳.۹.۴
		
		var infra_factor = 0.5 + infra["quality"] * 0.5
		var tech_factor = 0.7 + tech["branches"]["صنعت"] * 0.3
		var workforce_factor = 0.6 + pop["happiness"] * 0.4
		
		var efficiency = energy_factor * infra_factor * tech_factor * workforce_factor
		var actual_prod = base_prod * efficiency
		
		# محدودیت ظرفیت
		actual_prod = min(actual_prod, prod_capacity * 0.1)  # روزانه ۱۰٪ ظرفیت
		
		# بخش ب) خالص تولید
		var consumption = res["demand"][resource_name] if res["demand"].has(resource_name) else 5.0
		# مصرف با جمعیت رشد می‌کند
		consumption *= (1.0 + (pop["total"] / 85_000_000.0 - 1.0) * 0.5)
		
		var net = actual_prod - consumption
		
		# بخش ج) تغییر موجودی
		var old_inv = res["inventory"][resource_name]
		var new_inv = old_inv + net
		new_inv = min(new_inv, res["capacity"][resource_name])
		new_inv = max(new_inv, 0.0)
		res["inventory"][resource_name] = new_inv
		
		# تشخیص بحران
		if resource_name == "غذا" and new_inv < 30:
			res["food_crisis"] = true
		elif resource_name == "غذا" and new_inv > 50:
			res["food_crisis"] = false
		
		if resource_name == "برق" and new_inv < 15:
			res["energy_crisis"] = true
		elif resource_name == "برق" and new_inv > 30:
			res["energy_crisis"] = false

	# بخش ه) خودکفایی
	var total_prod = 0.0
	var total_dem = 0.0
	for k in res["production"].keys():
		total_prod += res["production"][k]
		total_dem += res["demand"][k] if res["demand"].has(k) else 0
	res["self_sufficiency"] = total_prod / max(total_dem, 1.0)

	# زنجیره تامین چندلایه - عمق ۳.۹.۶
	# لجستیک: اگر زیرساخت ضعیف باشد، منابع نمی‌رسند
	var logistics_factor = infra["capacity"]
	if logistics_factor < 0.4:
		# گلوگاه توزیع
		for r in res["inventory"].keys():
			res["inventory"][r] *= 0.98  # ۲٪ افت به دلیل گلوگاه

	# کیفیت و قیمت - ۳.۹.۶ ج و ه
	# نوسان قیمت با کمبود
	var price_events = []
	for r in res["inventory"].keys():
		var inv_ratio = res["inventory"][r] / max(res["capacity"][r], 1.0)
		if inv_ratio < 0.2 and Deterministic.chance(0.1):
			price_events.append({"type": "price_spike", "resource": r, "reason": "کمبود %s" % r})

	# رویدادهای منابع - ۳.۹.۵
	var events = []
	if Deterministic.chance(0.02):
		var event_types = ["کشف_منبع", "خشکسالی", "بحران_انرژی_جهانی", "تحریم_منابع"]
		var chosen = Deterministic.shuffle_array(event_types)[0]
		events.append({"type": chosen, "severity": Deterministic.next_range(0.1, 0.5)})

	state["resources"] = res
	return {"success": true, "state": state, "events": events + price_events}
