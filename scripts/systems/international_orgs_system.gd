extends BaseSystem
# ۳.۶۸ سازمان‌های بین‌المللی - عضویت، نفوذ، تطابق، معاهدات، کمک‌های بین‌المللی

func compute(state: Dictionary, tick: int) -> Dictionary:
	var intl = state.get("international_orgs", {})
	intl["un_membership"] = intl.get("un_membership", 1.0)
	intl["influence_un"] = intl.get("influence_un", state.get("diplomacy", {}).get("influence", 40.0)/100.0)
	intl["world_bank"] = intl.get("world_bank", 0.50)
	intl["imf"] = intl.get("imf", 0.50)
	intl["wto"] = intl.get("wto", 0.45)
	intl["treaties_intl"] = intl.get("treaties_intl", 10)
	intl["compliance"] = intl.get("compliance", 0.60)
	intl["aid_received"] = intl.get("aid_received", 500_000_000.0)
	intl["aid_given"] = intl.get("aid_given", 100_000_000.0)
	intl["un_votes_won"] = intl.get("un_votes_won", 5)
	intl["sanctions_un"] = intl.get("sanctions_un", 0)
	intl["peacekeeping_contrib"] = intl.get("peacekeeping_contrib", 0.30)

	var events = []
	var diplomacy = state.get("diplomacy", {})
	var econ = state.get("economy", {})
	var pol = state.get("politics", {})
	var sec = state.get("security", {})

	# نفوذ در سازمان ملل = دیپلماسی + قدرت نرم + اقتصاد
	var influence_target = diplomacy.get("influence",40.0)/100.0 *0.5 + diplomacy.get("soft_power",35.0)/100.0 *0.3 + (econ.get("gdp",500e9)/1e12)*0.2
	intl["influence_un"] = clamp(intl["influence_un"]*0.985 + influence_target*0.015, 0.03, 0.95)

	# تطابق - حاکمیت قانون و ثبات
	var rule_of_law = state.get("judicial",{}).get("rule_of_law",0.60)
	intl["compliance"] = clamp(intl["compliance"] + rule_of_law*0.0002 - pol.get("corruption",0.30)*0.0002 + Deterministic.next_range(-0.001,0.0015), 0.15, 0.95)

	# بانک جهانی و IMF - تطابق و بدهی
	var debt_ratio = econ.get("debt_to_gdp",0.4)
	intl["world_bank"] = clamp(intl["world_bank"]*0.992 + intl["compliance"]*0.005 - debt_ratio*0.002, 0.1, 0.95)
	intl["imf"] = clamp(intl["imf"]*0.992 + intl["compliance"]*0.005, 0.1, 0.95)
	intl["wto"] = clamp(intl["wto"]*0.994 + diplomacy.get("influence",40.0)/100.0*0.003, 0.1, 0.90)

	# معاهدات
	if tick % 60 == 0 and intl["influence_un"] > 0.5 and Deterministic.chance(0.08):
		intl["treaties_intl"] += 1

	# کمک‌ها - GDP
	intl["aid_received"] *= (1.0 + (0.5 - intl["compliance"])*0.0005)
	intl["aid_given"] = econ.get("gdp",500e9) * 0.0002 * intl["influence_un"]

	# رای سازمان ملل
	if tick % 30 == 0 and Deterministic.chance(0.10):
		if Deterministic.next_float() < intl["influence_un"]:
			intl["un_votes_won"] += 1

	# تحریم‌های سازمان ملل - تطابق پایین
	if intl["compliance"] < 0.35 and intl["influence_un"] < 0.30 and Deterministic.chance(0.006):
		intl["sanctions_un"] += 1
		events.append({"type":"un_sanction","compliance": intl["compliance"], "message":"قطعنامه تحریمی شورای امنیت - تطابق پایین"})

	# مشارکت در صلح‌بانی
	intl["peacekeeping_contrib"] = clamp(intl["peacekeeping_contrib"] + pol.get("stability",0.60)*0.0002, 0.05, 0.85)

	# رویدادها
	if Deterministic.chance(0.006):
		var r = Deterministic.next_float()
		if r < 0.33:
			events.append({"type":"un_resolution","influence": intl["influence_un"], "message":"قطعنامه سازمان ملل با حمایت شما تصویب شد"})
		elif r < 0.66:
			if intl["world_bank"] > 0.60 and Deterministic.chance(0.5):
				events.append({"type":"worldbank_loan_approved","message":"وام توسعه بانک جهانی تایید شد - زیرساخت"})
				econ["foreign_reserves"] = float(econ.get("foreign_reserves", 0.0)) + 200_000_000.0  # وام دلاری بانک جهانی → ذخایر ارزی (بازرسی مالکیت بودجه)
		else:
			if intl["treaties_intl"] > 15 and Deterministic.chance(0.3):
				events.append({"type":"treaty_milestone","treaties": intl["treaties_intl"], "message":"نقطه عطف - %d معاهده فعال بین‌المللی" % intl["treaties_intl"]})

	if intl["aid_received"] < 100_000_000.0 and econ.get("gdp_per_capita",5000.0) < 3000.0 and tick % 90 == 0:
		events.append({"type":"aid_crisis","message":"کاهش کمک‌های بین‌المللی - کسری بودجه توسعه"})

	state["international_orgs"] = intl
	state["economy"] = econ
	
	# ── لایه واقع‌گرایانه اختصاصی سازمان‌های بین‌المللی (جایگزین قالب خودکار) — بخش ۳.۶۸ ──
	# جریان کمک‌های بین‌المللی به بودجه دولت واقعاً وارد شود — نه اینکه فقط عددی روی کاغذ بماند
	econ["aid_inflow_daily"] = float(intl.get("aid_received", 500_000_000.0)) / 365.0
	state["economy"] = econ
	# تحریم سازمانی: تطابق پایین ممتد + بی‌اعتبار دیپلماتیک → رأی شورای امنیت علیه کشور
	if float(intl.get("compliance", 0.60)) < 0.35 and float(diplomacy.get("global_reputation", 0.50)) < 0.35 and Deterministic.chance(0.003):
		intl["sanctions_un"] = int(intl.get("sanctions_un", 0)) + 1
		intl["aid_received"] = float(intl.get("aid_received", 500_000_000.0)) * 0.85
		events.append({"type": "un_sanction", "message": "قطعنامه شورای امنیت علیه کشور - تشدید فشار بین‌المللی", "sanctions": intl["sanctions_un"]})
	# رفع تحریم با تطابق بالای پایدار ممکن است
	if int(intl.get("sanctions_un", 0)) > 0 and float(intl.get("compliance", 0.60)) > 0.70 and Deterministic.chance(0.004):
		intl["sanctions_un"] = int(intl.get("sanctions_un", 0)) - 1
		events.append({"type": "sanction_lifted", "message": "لغو یک قطعنامه - تنش‌زدایی دیپلماتیک نتیجه داد", "sanctions": intl["sanctions_un"]})
	# مشارکت صلح‌بانی: اعتبار می‌آورد و روابط را گرم نگه می‌دارد
	if float(intl.get("peacekeeping_contrib", 0.30)) > 0.50 and Deterministic.chance(0.004):
		events.append({"type": "peacekeeping_praise", "message": "تقدیر سازمان ملل از سهم صلح‌بانی کشور - اعتبار جهانی بالا رفت"})
	# عضویت کامل تجارت جهانی: نقطه فیصله برای صادرات غیرنفتی
	if float(intl.get("wto", 0.45)) > 0.80 and Deterministic.chance(0.003):
		events.append({"type": "wto_accession", "message": "عضویت نهایی در سازمان تجارت جهانی - دروازه صادرات گشوده شد", "wto": intl["wto"]})
	state["international_orgs"] = intl

	return {"success":true,"state":state,"events":events}
