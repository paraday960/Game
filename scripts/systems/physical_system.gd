extends BaseSystem
# لایه اماکن و نهادهای فیزیکی - بخش ۳.۴۲ تا ۳.۵۲ - 11 دسته مکانی

func compute(state: Dictionary, tick: int) -> Dictionary:
	var physical = state.get("physical", {})
	var pop = state.get("population", {})
	var econ = state.get("economy", {})

	physical["settlements"] = physical.get("settlements", 1200)
	physical["settlement_details"] = physical.get("settlement_details", {
		"شهر_بزرگ": 50,
		"شهر_متوسط": 200,
		"شهر_کوچک": 350,
		"شهرک": 400,
		"روستا": 10000
	})
	physical["transport"] = physical.get("transport", 5000)
	physical["transport_details"] = physical.get("transport_details", {
		"جاده": 3000,
		"راه_آهن": 500,
		"بندر": 20,
		"فرودگاه": 60,
		"ایستگاه_مترو": 200
	})
	physical["facilities"] = physical.get("facilities", 3000)
	physical["housing_units"] = physical.get("housing_units", 25000000)
	physical["housing_shortage"] = physical.get("housing_shortage", 0.10)
	physical["commercial"] = physical.get("commercial", {
		"رستوران": 50000,
		"فروشگاه": 200000,
		"بازار": 5000,
		"هتل": 3000
	})
	physical["public_services"] = physical.get("public_services", {
		"بیمارستان": 500,
		"مدرسه": 10000,
		"دانشگاه": 150,
		"ایستگاه_پلیس": 2000,
		"آتش_نشانی": 500
	})
	physical["industry_sites"] = physical.get("industry_sites", {
		"کارخانه": 5000,
		"انبار": 10000,
		"معدن": 200,
		"نیروگاه": 100
	})
	physical["energy_fuel"] = physical.get("energy_fuel", {
		"پمپ_بنزین": 4000,
		"ایستگاه_شارژ": 500,
		"شبکه_برق": 0.70
	})

	var events = []

	# رشد سکونتگاه‌ها با جمعیت
	var pop_growth = pop.get("growth_rate",0.012)
	physical["settlements"] += pop_growth * 100.0
	physical["housing_units"] += pop_growth * physical["housing_units"] * 0.5

	# کمبود مسکن = تقاضا - عرضه
	var housing_demand = pop.get("total",85_000_000) / 3.0  # هر خانوار 3 نفر
	var housing_shortage = (housing_demand - physical["housing_units"]) / housing_demand
	physical["housing_shortage"] = clamp(housing_shortage, -0.2, 0.60)

	if physical["housing_shortage"] > 0.2 and Deterministic.chance(0.01):
		events.append({"type": "housing_crisis", "message": "بحران مسکن - کمبود %s٪" % str(int(physical["housing_shortage"]*100)), "shortage": physical["housing_shortage"]})

	# حمل‌ونقل با زیرساخت رشد می‌کند
	var infra_q = state.get("infrastructure",{}).get("quality",0.55)
	physical["transport"] += infra_q * 0.5

	# ساخت مسکن واقعی: ۲۰٪ بودجه زیرساخت به واحد مسکونی تبدیل می‌شود (~۱۲۰هزار دلار/واحد).
	# (جمله قدیمی روی شمارنده facilities می‌نوشت که world_manager هر بار از نو محاسبه می‌کند — مرده بود)
	# واحد cadence (دور دوازدهم): سیستم هفتگی است (۶۰ اجرا در سال) ⇒ ساخت سالانه با
	# ۶/۳۶۵ در هر اجرا فرومی‌آید (پیش از این ~۴۷هزار خانه/سال ساخته می‌شد — یک‌ششمِ
	# طراحی ۲۸۸هزار — و عقب‌ماندگی مسکن هرگز جمع نمی‌شد؛ حالا با مقیاس واقعی).
	var housing_build_daily: float = econ.get("budget_allocations",{}).get("زیرساخت",0.18) * econ.get("government_spend_base",0.0) * 0.2 * 12.0 * 6.0 / 120000.0 / 365.0
	physical["housing_units"] += int(housing_build_daily)
	physical["housing_build_daily"] = housing_build_daily  # نرخ واقعی — مصرف‌کننده: settlements_system

	# خدمات عمومی
	if tick % 30 == 15:  # ماهانه
		physical["public_services"]["بیمارستان"] += 0.01
		physical["public_services"]["مدرسه"] += 0.1

	# تجاری
	if economy_growth(state) > 0.02 and Deterministic.chance(0.01):
		physical["commercial"]["فروشگاه"] += 10
		physical["commercial"]["رستوران"] += 5

	# اثرات زیست‌محیطی ساخت‌وساز
	if physical["settlements"] > 1500 and Deterministic.chance(0.005):
		events.append({"type": "urban_sprawl", "message": "گسترش شهری بی‌رویه - تخریب منابع طبیعی"})
		state["environment"]["forest_coverage"] = clamp(state.get("environment",{}).get("forest_coverage",0.30) - 0.001, 0.05, 0.70)

	# رویدادهای فیزیکی
	if infra_q < 0.4 and Deterministic.chance(0.012):
		events.append({"type": "infrastructure_decay", "message": "فرسودگی زیرساخت‌های فیزیکی - نیاز به بازسازی"})

	state["physical"] = physical
	
	# ── لایه واقع‌گرایانه اختصاصی لایه اماکن (جایگزین قالب خودکار) — همگام‌سازی آینه با منابع معتبر ──
	# سکونتگاه‌ها از سیستم مرجع (دور ۱۲) — نه رشد روزانه خودسرانه
	var sd = state.get("settlements_detail", {})
	var sd_det = physical.get("settlement_details", {})
	sd_det["شهر_بزرگ"] = int(sd.get("cities_large", 50))
	sd_det["شهر_متوسط"] = int(sd.get("cities_medium", 200))
	sd_det["شهر_کوچک"] = int(sd.get("cities_small", 350))
	sd_det["روستا"] = int(sd.get("villages", 10000))
	physical["settlement_details"] = sd_det
	physical["settlements"] = int(sd.get("total", 1200))
	# مسیر و ایستگاه‌ها از سیستم راه‌ها (دور ۱۲)
	var tr_d = state.get("transport_detail", {})
	var tr_det = physical.get("transport_details", {})
	tr_det["بندر"] = int(tr_d.get("ports", 20))
	tr_det["فرودگاه"] = int(tr_d.get("airports", 60))
	tr_det["ایستگاه_مترو"] = int(tr_d.get("metro_stations", 200))
	physical["transport_details"] = tr_det
	# خدمات عمومی از سیستم مرجع (دور ۱۵)
	var ps_d = state.get("public_services_detail", {})
	var ps_det = physical.get("public_services", {})
	ps_det["بیمارستان"] = int(ps_d.get("hospitals", 500))
	ps_det["مدرسه"] = int(ps_d.get("schools", 10000))
	ps_det["دانشگاه"] = int(ps_d.get("universities", 150))
	ps_det["ایستگاه_پلیس"] = int(ps_d.get("police_stations", 2000))
	ps_det["آتش_نشانی"] = int(ps_d.get("fire_stations", 500))
	physical["public_services"] = ps_det
	# صنعت و تجارت از مراجع دور ۱۵ و ۱۱
	var is_d = physical.get("industry_sites", {})
	is_d["کارخانه"] = int(state.get("industry_sites_detail", {}).get("factories", 5000))
	is_d["معدن"] = int(state.get("industry_sites_detail", {}).get("mines", 200))
	physical["industry_sites"] = is_d
	var cm_d = physical.get("commercial", {})
	cm_d["رستوران"] = int(state.get("hospitality", {}).get("restaurants", 50000))
	cm_d["هتل"] = int(state.get("hospitality", {}).get("hotels", 3000))
	cm_d["فروشگاه"] = int(state.get("retail", {}).get("shops", 200000))
	physical["commercial"] = cm_d
	# یادداشت: حاشیه‌نشینی (دور ۱۲) کیفیت واحدهای مسکونی را می‌خورد
	physical["housing_units"] = maxi(int(float(physical.get("housing_units", 25000000)) * (1.0 + float(pop_growth) / 365.0)), 5000000)
	if float(sd.get("slum_ratio", 0.15)) > 0.28 and Deterministic.chance(0.004):
		events.append({"type": "informal_settlements_physical", "message": "ساخت‌وساز خودسر در پشت بام‌ها - شهر فیزیکی از نقشه عمرانی جلو زده"})
	state["physical"] = physical

	return {"success": true, "state": state, "events": events}

func economy_growth(state: Dictionary) -> float:
	return state.get("economy",{}).get("growth_rate",0.02)
