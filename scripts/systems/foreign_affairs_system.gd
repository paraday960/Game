extends BaseSystem
# ۳.۷۱ امور خارجی - سفارت، کنسولگری، دیپلمات، قدرت نرم، ویزا، معاهدات فعال

func compute(state: Dictionary, tick: int) -> Dictionary:
	var fa = state.get("foreign_affairs", {})
	fa["embassies"] = fa.get("embassies", 100)
	fa["consulates"] = fa.get("consulates", 150)
	fa["diplomats"] = fa.get("diplomats", 2000)
	fa["local_staff"] = fa.get("local_staff", 5000)
	fa["treaties_active"] = fa.get("treaties_active", state.get("diplomacy", {}).get("treaties", []).size())
	fa["treaties_pending"] = fa.get("treaties_pending", 3)
	fa["soft_power"] = fa.get("soft_power", state.get("diplomacy", {}).get("soft_power", 35.0)/100.0)
	fa["visa_policy"] = fa.get("visa_policy", 0.50)
	fa["visa_free_count"] = fa.get("visa_free_count", 40)
	fa["cultural_missions"] = fa.get("cultural_missions", 20)
	fa["public_diplomacy_budget"] = fa.get("public_diplomacy_budget", 100_000_000.0)
	fa["consular_cases"] = fa.get("consular_cases", 5000)

	var events = []
	var diplomacy = state.get("diplomacy", {})
	var culture = state.get("culture", {})
	var econ = state.get("economy", {})
	var pop = state.get("population", {})

	var influence = diplomacy.get("influence", 40.0)
	var soft = diplomacy.get("soft_power", 35.0)

	# قدرت نرم = فرهنگ + دیپلماسی + آموزش + گردشگری
	var tourism = state.get("tourism", {}).get("visitors", 5_000_000) / 10_000_000.0
	var soft_target = culture.get("cohesion",0.65)*0.25 + soft/100.0*0.25 + state.get("education",{}).get("quality",0.55)*0.15 + tourism*0.15 + 0.20
	fa["soft_power"] = clamp(fa["soft_power"]*0.988 + soft_target*0.012, 0.05, 0.95)

	# تعداد معاهدات فعال
	fa["treaties_active"] = diplomacy.get("treaties", []).size()
	fa["treaties_pending"] = clamp(fa["treaties_pending"] + Deterministic.next_range(-0.1,0.2), 0, 10)

	# سیاست روادید - قدرت نرم بالا روادید بازتر
	var visa_target = fa["soft_power"]*0.6 + influence/100.0*0.4
	fa["visa_policy"] = clamp(fa["visa_policy"]*0.993 + visa_target*0.007, 0.10, 0.95)
	fa["visa_free_count"] = int(fa["visa_policy"] * 120.0)

	# دیپلمات‌ها - رشد با نفوذ
	if tick % 90 == 0 and influence > 50.0:
		fa["diplomats"] += Deterministic.next_int_range(20, 80)
		fa["embassies"] += Deterministic.next_int_range(0, 2)
		fa["consulates"] += Deterministic.next_int_range(0, 3)

	# ماموریت‌های فرهنگی
	fa["cultural_missions"] = int(fa["soft_power"] * 50.0)
	fa["public_diplomacy_budget"] *= (1.0 + econ.get("growth_rate",0.02)/365.0)

	# پرونده‌های کنسولی - مهاجرت
	var migration = state.get("migration_detail", {}).get("emigration", 40000.0) if state.has("migration_detail") else 40000.0
	fa["consular_cases"] = int(migration * 0.15 + pop.get("total",85_000_000.0)*0.00005)

	# پرسنل محلی - هزینه
	fa["local_staff"] = fa["embassies"] * 25 + fa["consulates"] * 10

	# رویدادها
	if fa["embassies"] < 50 and Deterministic.chance(0.007):
		events.append({"type":"embassy_shortage","embassies": fa["embassies"], "message":"کمبود سفارتخانه - پوشش دیپلماتیک ناقص در آفریقا"})

	if fa["visa_policy"] > 0.75 and Deterministic.chance(0.012):
		events.append({"type":"visa_liberalization","visa_free": fa["visa_free_count"], "message":"لغو روادید با %d کشور - جهش گردشگری ورودی" % fa["visa_free_count"]})

	if fa["consular_cases"] > 15000 and Deterministic.chance(0.010):
		events.append({"type":"consular_overload","cases": fa["consular_cases"], "message":"ازدحام پرونده کنسولی ایرانیان خارج کشور"})

	if fa["soft_power"] > 0.70 and tick % 180 == 0 and Deterministic.chance(0.02):
		events.append({"type":"soft_power_peak","soft": fa["soft_power"], "message":"قدرت نرم در اوج - سریال ایرانی در ۲۰ کشور پخش شد"})

	state["foreign_affairs"] = fa
	return {"success":true,"state":state,"events":events}
