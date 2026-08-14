extends BaseSystem
# دیپلماسی و روابط بین‌الملل - ۳.۱۴ - نسخه عمیق واقعی - جنگ، اتحاد، صلح، تحریم، حقوق بین‌الملل

func compute(state: Dictionary, tick: int) -> Dictionary:
	state = WorldManager.ensure_world(state)
	var dip = state["diplomacy"]
	var mil = state["military"]
	var econ = state["economy"]
	var pol = state["politics"]
	var culture = state.get("culture", {})
	var intel = state.get("intelligence", {})
	var world = state.get("world", {})

	var events = []

	# ==================== روابط دوجانبه - پویا با تجارت، اتحاد، جنگ ====================
	var trade_agreements = world.get("trade_agreements", [])
	var alliances = world.get("alliances", [])
	var wars = world.get("wars", {})

	for country in dip["relations"].keys():
		var rel = float(dip["relations"][country])
		var change = Deterministic.next_range(-0.08, 0.08)
		# عوامل
		if trade_agreements.has(country):
			change += (70.0 - rel) * 0.003 + 0.02
		if alliances.has(country):
			change += (85.0 - rel) * 0.005 + 0.03
		if wars.has(country):
			change += (0.0 - rel) * 0.02 - 0.10
		else:
			# (بازرسی NPC بلندمدت) قدرت اقتصادی/نرم نباید دریفت مثبتِ بی‌شرط باشد؛ پیش‌تر
			# جمله‌ای همیشه‌مثبت (≈+۶ واحد/سال برای همه — حتی دشمنان) روابطِ همه را به ~۸۴
			# می‌کشاند و خصومت/تحریم در بلندمدت بی‌معنی می‌شد. حالا فقط «هدف» جاذب خنثی جابه‌جا
			# می‌شود: ۵۰ + امتیاز قدرت (≈۵۰ تا ۶۲) — جنگ/اتحاد/تجارت جاذب‌های قوی‌ترند.
			var gdp_factor = (econ["gdp"]/500e9) * 0.01
			var soft_factor = dip.get("soft_power",35.0)/100.0 * 0.02
			var gdp_soft: float = clamp(gdp_factor + soft_factor, 0.0, 0.03)
			change += (50.0 + gdp_soft * 400.0 - rel) * 0.001  # τ≈۲٫۷ سال — بازگشت ملایمِ خنثی

		# اثر جنگ جاری بر روابط دیگران - کشورها موضع می‌گیرند
		if not wars.is_empty():
			# کشورهای هم‌بلوک با دشمن، رابطه‌شان با ما بد می‌شود
			var enemy_bloc = ""
			if world.get("countries",{}).has(country):
				enemy_bloc = str(world["countries"][country].get("bloc",""))
			if enemy_bloc == "غربی" and pol.get("corruption",0.30) > 0.5:
				change -= 0.02

		rel += change
		rel = clamp(rel, 0.0, 100.0)
		dip["relations"][country] = rel

		if rel < 20.0 and Deterministic.chance(0.015):
			events.append({"type":"hostility","country":country,"relation":rel,"message":"روابط با %s در آستانه خصومت - سفیر احضار شد" % WorldManager.get_country_name(country)})
		elif rel > 80.0 and Deterministic.chance(0.010):
			events.append({"type":"friendship","country":country,"relation":rel,"message":"دوستی عمیق با %s - تبادل هیات بلندپایه" % WorldManager.get_country_name(country)})

	# ==================== نفوذ و قدرت نرم - چندعاملی ====================
	var influence = 0.0
	influence += (econ["gdp"] / 1_000_000_000_000.0) * 28.0
	influence += mil["power"] * 0.25
	influence += state["technology"]["branches"]["دیجیتال"] * 18.0
	influence += culture.get("cohesion",0.65) * 12.0
	influence += float(dip["relations"].size()) * 0.15
	influence += float(trade_agreements.size()) * 0.8
	influence += float(alliances.size()) * 2.5
	influence += float(world.get("war_history",[]).size()) * 0.1 # تجربه جنگی
	dip["influence"] = clamp(influence, 0.0, 100.0)

	var soft = 0.0
	soft += culture.get("cohesion",0.65) * 18.0
	soft += state["education"]["quality"] * 12.0
	soft += dip["influence"] * 0.25
	soft += state.get("tourism",{}).get("visitors",5_000_000)/10_000_000.0 * 10.0
	soft += culture.get("media_freedom",0.5) * 8.0
	soft += state.get("sports_youth",{}).get("participation",0.40)*5.0
	dip["soft_power"] = clamp(soft, 0.0, 100.0)

	# امتیاز اقدام دیپلماتیک
	dip["action_points"] = clamp(float(dip.get("action_points",3.0)) + 0.12 + dip["influence"]/100.0*0.05, 0.0, 6.0)

	# ==================== معاهدات و اتحاد - عمیق ====================
	var treaties = dip.get("treaties", [])
	# رشد معاهدات با نفوذ
	if tick % 60 == 0 and dip["influence"] > 50.0 and Deterministic.chance(0.15):
		var treaty_types = ["تجارت آزاد","همکاری نظامی","فرهنگی","انرژی","امنیتی","فضایی","سایبری","بهداشتی"]
		var new_treaty = {"type": treaty_types[Deterministic.next_int_range(0, treaty_types.size()-1)], "partner": "کشور تصادفی", "tick": tick, "strength": dip["influence"]/100.0}
		treaties.append(new_treaty)
		events.append({"type":"new_treaty","treaty": new_treaty,"message":"معاهده %s جدید امضا شد" % new_treaty["type"]})
	dip["treaties"] = treaties

	# ==================== جنگ و صلح - دیپلماسی جنگی عمیق ====================
	# پیشنهاد صلح - شرایط واقعی: خستگی جنگ، تلفات، اقتصاد، حمایت عمومی
	var war_diplomacy = dip.get("war_diplomacy", {})
	war_diplomacy["ceasefire_offers"] = war_diplomacy.get("ceasefire_offers", 0)
	war_diplomacy["peace_talks"] = war_diplomacy.get("peace_talks", 0)
	war_diplomacy["un_resolutions"] = war_diplomacy.get("un_resolutions", 0)
	war_diplomacy["war_crimes_tribunal"] = war_diplomacy.get("war_crimes_tribunal", false)

	if not wars.is_empty():
		# سازمان ملل - قطعنامه آتش‌بس
		if tick % 30 == 0 and Deterministic.chance(0.12):
			war_diplomacy["un_resolutions"] += 1
			events.append({"type":"un_resolution","count": war_diplomacy["un_resolutions"], "message":"قطعنامه شورای امنیت برای آتش‌بس - رای‌گیری"})

		# پیشنهاد آتش‌بس محلی برای تخلیه مجروح (ژنو)
		if Deterministic.chance(0.015):
			events.append({"type":"local_ceasefire_proposal","message":"پیشنهاد آتش‌بس محلی برای تخلیه مجروحان - کنوانسیون ژنو ماده ۱۵"})

		# مذاکره صلح - بر اساس خستگی جنگ
		var exhaustion = float(mil.get("war_exhaustion",0.0))
		if exhaustion > 0.60 and Deterministic.chance(0.010):
			war_diplomacy["peace_talks"] += 1
			events.append({"type":"peace_talks_initiated","exhaustion": exhaustion, "message":"مذاکرات صلح محرمانه آغاز شد - خستگی جنگ %.0f٪" % (exhaustion*100.0)})

		# شرایط صلح - انواع واقعی: بلا قید و شرط، مشروط، آتش‌بس، صلح مسلح
		# الحاق، دست‌نشاندگی، غرامت، منطقه غیرنظامی، خلع سلاح، اشغال
		var peace_terms = war_diplomacy.get("peace_terms", {})
		peace_terms["annexation"] = peace_terms.get("annexation", false)
		peace_terms["puppet_state"] = peace_terms.get("puppet_state", false)
		peace_terms["reparations"] = peace_terms.get("reparations", 0.0)
		peace_terms["dmz"] = peace_terms.get("dmz", false)
		peace_terms["demilitarization"] = peace_terms.get("demilitarization", false)
		peace_terms["occupation_zones"] = peace_terms.get("occupation_zones", 0)
		war_diplomacy["peace_terms"] = peace_terms

	dip["war_diplomacy"] = war_diplomacy

	# ==================== تحریم - جنگ اقتصادی ====================
	var incoming_sanctions = 0
	var outgoing_sanctions = 0
	for s in dip.get("sanctions", []):
		if not s is Dictionary:
			continue
		if s.get("by","foreign") != "player":
			incoming_sanctions += 1
		else:
			outgoing_sanctions += 1

	if incoming_sanctions > 0:
		var penalty = incoming_sanctions * 0.02
		# تحریم‌های هوشمند vs جامع - اثر متفاوت
		var smart_sanction = incoming_sanctions * 0.6 # ۶۰٪ هوشمند
		var comprehensive = incoming_sanctions * 0.4
		var gdp_loss = penalty*0.6 + comprehensive*0.04
		econ["growth_rate"] = float(econ.get("growth_rate",0.02)) - gdp_loss*0.001
		# دور زدن تحریم - قاچاق، واسطه
		var evasion = state.get("private_sector",{}).get("informal_economy",0.25)*0.3 + intel.get("sigint",0.50)*0.1
		# ممیزی GDP (۱۴۰۵): فشار تحریم و اثر دورزدن هر دو «اثر مداوم»‌اند و از کانال
		# مالک-یکتای sector_boosts می‌گذرند (نرخ سالانه — همان مقادیر قبلی که روزانه اعمال می‌شد)
		var dip_boosts: Dictionary = econ.get("sector_boosts", {})
		dip_boosts["فشار تحریم‌ها"] = -gdp_loss
		dip_boosts["دور زدن تحریم"] = evasion * 0.01
		econ["sector_boosts"] = dip_boosts
		if tick % 90 == 0:
			events.append({"type":"sanction_effect","count": incoming_sanctions, "gdp_loss": gdp_loss, "evasion": evasion, "message":"%d تحریم فعال - تلاش برای دور زدن %.0f٪" % [incoming_sanctions, evasion*100.0]})
	else:
		# تحریم فعالی نیست → اثر مداوم به خواب می‌رود (بازنویسی، نه انباشت)
		var dip_boosts_idle: Dictionary = econ.get("sector_boosts", {})
		if dip_boosts_idle.has("فشار تحریم‌ها") or dip_boosts_idle.has("دور زدن تحریم"):
			dip_boosts_idle["فشار تحریم‌ها"] = 0.0
			dip_boosts_idle["دور زدن تحریم"] = 0.0
			econ["sector_boosts"] = dip_boosts_idle

	# تحریم‌های ما علیه دیگران - اثر بر صادرات
	if outgoing_sanctions > 0 and tick % 60 == 0:
		econ["trade"] = econ.get("trade",{}) # placeholder
		events.append({"type":"our_sanctions_impact","count": outgoing_sanctions, "message":"%d تحریم اعمالی ما - اهرم چانه‌زنی" % outgoing_sanctions})

	# ==================== حقوق بین‌الملل و جنگ ====================
	var international_law = dip.get("international_law", {})
	international_law["geneva_compliance"] = international_law.get("geneva_compliance", state.get("military",{}).get("laws_of_war",{}).get("geneva_compliance",0.85))
	international_law["icc_risk"] = international_law.get("icc_risk", 0.10)
	international_law["un_votes_won"] = international_law.get("un_votes_won", 0)
	international_law["un_votes_lost"] = international_law.get("un_votes_lost", 0)

	# رای سازمان ملل
	if tick % 90 == 0 and Deterministic.chance(0.10):
		if dip["influence"] > 50.0 and Deterministic.next_float() < dip["influence"]/100.0:
			international_law["un_votes_won"] += 1
			events.append({"type":"un_vote_won","message":"پیروزی در رای‌گیری مجمع عمومی سازمان ملل"})
		else:
			international_law["un_votes_lost"] += 1

	# خطر دادگاه لاهه اگر جنایات جنگی بالا
	var war_crimes = state.get("military",{}).get("laws_of_war",{}).get("war_crimes_allegations",0)
	international_law["icc_risk"] = clamp(float(war_crimes)*0.15 + (1.0 - international_law["geneva_compliance"])*0.3, 0.0, 0.85)
	dip["international_law"] = international_law

	# ==================== ائتلاف و بلوک‌بندی ====================
	var coalition = dip.get("coalition_detail", {})
	coalition["active_coalitions"] = coalition.get("active_coalitions", world.get("alliances",[]).size())
	coalition["coalition_strength"] = coalition.get("coalition_strength", 0.60)
	coalition["burden_sharing"] = coalition.get("burden_sharing", 0.50) # تقسیم بار
	coalition["interoperability"] = coalition.get("interoperability", 0.55) # هم‌کنش‌پذیری

	var alliance_count = float(world.get("alliances",[]).size())
	coalition["coalition_strength"] = clamp(alliance_count*0.15 + dip["influence"]/100.0*0.4 + 0.2, 0.10, 0.95)
	coalition["burden_sharing"] = clamp(coalition["coalition_strength"]*0.6 + pol.get("trust",0.55)*0.2 + 0.20, 0.10, 0.90)
	coalition["interoperability"] = clamp(state.get("military",{}).get("command_detail",{}).get("joint_operations",0.55)*0.5 + state.get("technology",{}).get("branches",{}).get("دیجیتال",0.20)*0.3 + 0.20, 0.15, 0.95)
	dip["coalition_detail"] = coalition

	# ==================== رویدادهای دیپلماتیک ====================
	if Deterministic.chance(0.008):
		var r = Deterministic.next_float()
		if r < 0.20:
			events.append({"type":"diplomatic_visit","message":"سفر دیپلماتیک - هیاتی بلندپایه وارد شد"})
		elif r < 0.40:
			events.append({"type":"trade_negotiation","message":"مذاکره تجاری - تعرفه‌ها بازنگری می‌شود"})
		elif r < 0.60:
			if dip["soft_power"] > 60.0:
				events.append({"type":"cultural_exchange","message":"تبادل فرهنگی - هفته فیلم ایرانی در ۵ پایتخت"})
		elif r < 0.80:
			events.append({"type":"border_meeting","message":"نشست مرزی فرماندهان مرزبانی"})
		else:
			events.append({"type":"track_two_diplomacy","message":"دیپلماسی پنهان - مذاکره پشت پرده با میانجی عمان"})

	# بحران دیپلماتیک - اخراج سفیر، بستن سفارت
	if dip["relations"].values().filter(func(v): return float(v) < 15.0).size() > 3 and Deterministic.chance(0.012):
		events.append({"type":"diplomatic_crisis","message":"بحران دیپلماتیک - ۳ کشور سفرای خود را فراخواندند"})

	# صلح پایدار - اگر ۶ ماه بدون جنگ
	if wars.is_empty() and tick % 180 == 0 and Deterministic.chance(0.20):
		events.append({"type":"peace_dividend","message":"سود صلح - سرمایه‌گذاری خارجی افزایش یافت"})
		econ["gdp"] *= 1.005

	state["diplomacy"] = dip
	state["economy"] = econ
	var world_result = WorldManager.simulate(state, tick)
	state = world_result.state
	events.append_array(world_result.events)
	
	# --- لایه عمیق دوم: اقتصاد سیاسی، شبکه اجتماعی، فناوری دوگانه، تاب‌آوری اقلیمی ---
	var _extra_politics = state.get("politics",{})
	var _extra_econ = state.get("economy",{})
	var _extra_pop = state.get("population",{})
	var _extra_env = state.get("environment",{})
	var _extra_tech = state.get("technology",{})
	var _extra_culture = state.get("culture",{})

	var _trust = float(_extra_politics.get("trust",0.55))
	var _corruption = float(_extra_politics.get("corruption",0.30))
	var _stability = float(_extra_politics.get("stability",0.60))
	var _happiness = float(_extra_pop.get("happiness",0.60))
	var _gini = float(state.get("welfare",{}).get("gini",0.38))
	var _digital = float(state.get("technology",{}).get("branches",{}).get("دیجیتال",0.20) if _extra_tech.has("branches") else 0.20)
	var _green = float(_extra_env.get("green_energy",0.20) if _extra_env.has("green_energy") else 0.20)

	# اثر اعتماد بر کارآمدی
	var _sys_q = 0.60
	if state.has("diplomacy") and state["diplomacy"] is Dictionary:
		_sys_q = float(state["diplomacy"].get("quality",0.60) if state["diplomacy"].has("quality") else state["diplomacy"].get("efficiency",0.60) if state["diplomacy"].has("efficiency") else 0.60)
	_sys_q = clamp(_sys_q*0.96 + _trust*0.02 + (1.0-_corruption)*0.02 + _happiness*0.01 + Deterministic.next_range(-0.001,0.001), 0.05, 0.98)
	if state.has("diplomacy") and state["diplomacy"] is Dictionary:
		state["diplomacy"]["quality"] = _sys_q

	# نابرابری و نارضایتی
	if _gini > 0.42 and Deterministic.chance(0.007):
		events.append({"type":"inequality_diplomacy_deep","gini": _gini, "message":"نابرابری اثر بر diplomacy - شکاف طبقاتی"})

	# فناوری دوگانه (نظامی-غیرنظامی)
	if _digital > 0.65 and Deterministic.chance(0.006):
		events.append({"type":"dual_use_tech_diplomacy","digital": _digital, "message":"فناوری دوگانه در diplomacy - کاربرد نظامی و غیرنظامی"})

	# تاب‌آوری اقلیمی
	var _climate_resilience = float(state.get("quantitative",{}).get("shock_absorption",0.60) if state.has("quantitative") else 0.60)
	if _climate_resilience < 0.35 and Deterministic.chance(0.005):
		events.append({"type":"climate_vulnerability_diplomacy","resilience": _climate_resilience, "message":"آسیب‌پذیری اقلیمی diplomacy"})

	# شبکه اجتماعی و سرمایه اجتماعی
	var _social_capital = float(_extra_culture.get("cohesion",0.65))*0.5 + _trust*0.3 + _happiness*0.2
	if _social_capital < 0.40 and Deterministic.chance(0.006):
		events.append({"type":"low_social_capital_diplomacy","capital": _social_capital, "message":"سرمایه اجتماعی پایین در diplomacy"})

	# اثر تورمی بر هزینه نگهداری
	var _inflation = float(_extra_econ.get("inflation",0.08))
	if state.has("diplomacy") and state["diplomacy"] is Dictionary and state["diplomacy"].has("maintenance_cost"):
		state["diplomacy"]["maintenance_cost"] = float(state["diplomacy"]["maintenance_cost"]) * (1.0 + _inflation*0.5/365.0)


	
	return {"success":true,"state":state,"events":events}
