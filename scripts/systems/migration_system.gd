extends BaseSystem
# ۳.۶۹ مهاجرت و پناهندگی - مهاجرت، مهاجرت معکوس، پناهندگی، کنترل مرز، ادغام، حواله

func compute(state: Dictionary, tick: int) -> Dictionary:
	var mig = state.get("migration_detail", {})
	mig["immigration"] = mig.get("immigration", 50000.0)
	mig["emigration"] = mig.get("emigration", 40000.0)
	mig["net"] = mig.get("net", 10000.0)
	mig["refugees_in"] = mig.get("refugees_in", 10000.0)
	mig["refugees_out"] = mig.get("refugees_out", 5000.0)
	mig["border_control_effect"] = mig.get("border_control_effect", state.get("security", {}).get("border_control", 0.60))
	mig["integration"] = mig.get("integration", 0.55)
	mig["diaspora"] = mig.get("diaspora", 5_000_000.0)
	mig["remittances"] = mig.get("remittances", 2_000_000_000.0)
	mig["skilled_immigration"] = mig.get("skilled_immigration", 0.25)
	mig["illegal_immigration"] = mig.get("illegal_immigration", 10000.0)
	mig["returnees"] = mig.get("returnees", 8000.0)
	mig["asylum_acceptance"] = mig.get("asylum_acceptance", 0.60)
	mig["xenophobia"] = mig.get("xenophobia", 0.25)

	var events = []
	var pop = state.get("population", {})
	var econ = state.get("economy", {})
	var pol = state.get("politics", {})
	var sec = state.get("security", {})
	var welfare = state.get("welfare", {})
	var eth = state.get("ethnicity", {})

	var pop_hap = pop.get("happiness", 0.6)
	var gdp_pc = econ.get("gdp_per_capita", 5000.0)
	var growth = econ.get("growth_rate", 0.02)
	var unemployment = econ.get("unemployment", 0.08)
	var stability = pol.get("stability", 0.60)
	var tension = pol.get("tension", 0.35)

	# جذابیت کشور = شادی + درآمد + ثبات - بیکاری
	var attractiveness = pop_hap*0.3 + (gdp_pc/8000.0)*0.25 + stability*0.25 + (1.0 - unemployment)*0.15 + (1.0 - tension)*0.05
	attractiveness = clamp(attractiveness, 0.1, 1.2)

	# مهاجرت ورودی - جذابیت + دیپلماسی + کنترل مرز
	var border_ctrl = sec.get("border_control", 0.60)
	mig["border_control_effect"] = border_ctrl
	var immigration_base = 50000.0 * attractiveness * (0.5 + border_ctrl*0.5)
	mig["immigration"] = clamp(mig["immigration"]*0.92 + immigration_base*0.08 + Deterministic.next_range(-2000.0,3000.0), 5000.0, 300000.0)

	# مهاجرت خروجی - نارضایتی + بیکاری + فساد
	var push_factor = (1.0 - pop_hap)*0.4 + unemployment*0.3 + pol.get("corruption",0.30)*0.15 + (1.0 - stability)*0.15
	var emigration_base = 40000.0 * (0.5 + push_factor*1.5)
	mig["emigration"] = clamp(mig["emigration"]*0.92 + emigration_base*0.08 + Deterministic.next_range(-2000.0,2000.0), 5000.0, 400000.0)

	mig["net"] = mig["immigration"] - mig["emigration"]

	# پناهندگان ورودی - بی‌ثباتی منطقه‌ای و جنگ جهانی
	var world_instability = 0.30 + Deterministic.next_range(0.0,0.20)
	mig["refugees_in"] = clamp(mig["refugees_in"]*0.95 + world_instability*20000.0*attractiveness*0.05 + (1.0-border_ctrl)*10000.0*0.05, 1000.0, 200000.0)
	mig["refugees_out"] = clamp(mig["refugees_out"]*0.95 + push_factor*8000.0, 500.0, 100000.0)

	# ادغام - زبان، آموزش، شغل
	var edu_q = state.get("education", {}).get("quality",0.55)
	var welfare_sup = welfare.get("unemployment_support",0.5)
	mig["integration"] = clamp(mig["integration"]*0.992 + (pop_hap*0.3 + edu_q*0.3 + welfare_sup*0.2 + (1.0-eth.get("tension",0.30))*0.2)*0.008, 0.15, 0.92)

	# بیگانه‌هراسی - تنش قومی + بیکاری + پناهنده زیاد
	var xenophobia_target = eth.get("tension",0.30)*0.4 + unemployment*0.3 + min(mig["refugees_in"],100000.0)/100000.0*0.2 + 0.05
	mig["xenophobia"] = clamp(mig["xenophobia"]*0.985 + xenophobia_target*0.015, 0.05, 0.75)

	# دیاسپورا و حواله - تجمعی
	mig["diaspora"] += (mig["emigration"] - mig["returnees"]) / 365.0
	mig["diaspora"] = max(mig["diaspora"], 100000.0)
	mig["remittances"] = mig["diaspora"] * 400.0 * (0.5 + pop_hap*0.5) # میانگین 400 دلار

	# مهاجرت ماهر - کیفیت آموزش و درآمد
	mig["skilled_immigration"] = clamp(mig["skilled_immigration"]*0.98 + (gdp_pc/10000.0*0.4 + edu_q*0.3 + growth*10.0*0.2 + 0.1)*0.02, 0.05, 0.70)

	# غیرقانونی - کنترل مرز معکوس
	mig["illegal_immigration"] = clamp((1.0 - border_ctrl)*50000.0 + mig["immigration"]*0.1, 1000.0, 100000.0)

	# بازگشتی‌ها - جذابیت + برنامه بازگشت
	mig["returnees"] = clamp(mig["returnees"]*0.90 + attractiveness*5000.0 + mig["diaspora"]*0.001, 1000.0, 50000.0)

	# پذیرش پناهندگی - حقوق بشر + ظرفیت
	var judicial_roi = state.get("judicial", {}).get("rule_of_law",0.60)
	mig["asylum_acceptance"] = clamp(judicial_roi*0.4 + pop_hap*0.2 + (1.0 - mig["xenophobia"])*0.3 + 0.1, 0.1, 0.95)

	# اثر بر جمعیت و اقتصاد
	pop["migration_net"] = mig["net"] + mig["refugees_in"] - mig["refugees_out"] + mig["illegal_immigration"]*0.5
	econ["government_revenue"] = econ.get("government_revenue",0.0) + mig["remittances"]*0.02 # مالیات غیرمستقیم

	# رویدادها
	if mig["refugees_in"] > 60000.0 and Deterministic.chance(0.014):
		events.append({"type":"refugee_wave","refugees": mig["refugees_in"], "message":"موج پناهجویان ورودی - %d نفر پشت مرز" % int(mig["refugees_in"])})

	if mig["emigration"] > 100000.0 and Deterministic.chance(0.012):
		events.append({"type":"emigration_wave","emigration": mig["emigration"], "message":"موج مهاجرت خروجی - صف ویزا طولانی"})

	if mig["integration"] < 0.30 and Deterministic.chance(0.011):
		events.append({"type":"integration_failure","integration": mig["integration"], "message":"شکست ادغام مهاجران - محله‌های جداافتاده"})

	if mig["xenophobia"] > 0.60 and Deterministic.chance(0.010):
		events.append({"type":"xenophobia_rise","xenophobia": mig["xenophobia"], "message":"بیگانه‌هراسی بالا - حمله به مغازه مهاجران"})

	if mig["skilled_immigration"] > 0.50 and Deterministic.chance(0.009):
		events.append({"type":"brain_gain_migration","skilled": mig["skilled_immigration"], "message":"مهاجرت معکوس متخصصان - ۲۰۰۰ مهندس برگشتند"})

	if mig["illegal_immigration"] > 50000.0 and Deterministic.chance(0.010):
		events.append({"type":"illegal_immigration_crisis","illegal": mig["illegal_immigration"], "message":"مهاجرت غیرقانونی گسترده - قاچاق انسان در مرز شرقی"})

	state["migration_detail"] = mig
	state["population"] = pop
	state["economy"] = econ
	
	# ── لایه واقع‌گرایانه اختصاصی مهاجرت (جایگزین قالب خودکار تکراری) — بخش ۳.۶۹ ──
	# خروجی با بیکاری و بی‌ثباتی؛ ورودی با امنیت و رشد و کنترل مرز
	var econ_m: Dictionary = state.get("economy", {})
	var push_m: float = float(econ_m.get("unemployment", 0.08)) * 2.0 + (1.0 - float(state.get("politics", {}).get("stability", 0.60))) * 0.5
	var pull_m: float = float(state.get("security", {}).get("public_security", 0.60)) * 0.5 + clampf(float(econ_m.get("growth_rate", 0.02)) * 10.0, 0.0, 0.5)
	mig["emigration"] = maxf(float(mig.get("emigration", 40000.0)) * (1.0 + (push_m - 0.55) * 0.0008), 1000.0)
	mig["immigration"] = maxf(float(mig.get("immigration", 50000.0)) * (1.0 + (pull_m - 0.55) * 0.0008 * float(mig.get("border_control_effect", 0.60))), 1000.0)
	mig["net"] = float(mig["immigration"]) - float(mig["emigration"])
	# حواله‌های دیاسپورا متناسب با اندازه جمعیت ایرانیان خارج
	mig["remittances"] = maxf(float(mig.get("diaspora", 5_000_000.0)) * 400.0, 0.0)
	if float(mig.get("emigration", 40000.0)) > 120000.0 and Deterministic.chance(0.004):
		events.append({"type": "brain_exodus", "message": "خروج انبوه نخبگان - موج مهاجرت متخصصان", "emigration": mig["emigration"]})
	state["migration_detail"] = mig

	return {"success":true,"state":state,"events":events}
