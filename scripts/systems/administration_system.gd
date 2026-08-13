extends BaseSystem
# ۳.۲۶ تقسیمات کشوری و حکومت محلی

func compute(state: Dictionary, tick: int) -> Dictionary:
	var admin = state.get("administration", {})
	var pop = state.get("population", {})
	var econ = state.get("economy", {})
	var politics = state.get("politics", {})
	var infra = state.get("infrastructure", {})

	admin["efficiency"] = admin.get("efficiency", 0.60)
	admin["decentralization"] = admin.get("decentralization", 0.40)
	admin["regional_inequality"] = admin.get("regional_inequality", 0.35)
	admin["local_governance"] = admin.get("local_governance", 0.55)
	var country_id = str(state.get("country", {}).get("id", WorldManager.default_country))
	admin["provinces"] = max(1, CountryGeographyManager.get_unit_count(country_id))
	admin["municipalities"] = max(admin["provinces"], int(admin.get("municipalities", 1200)))
	admin["local_budget_share"] = admin.get("local_budget_share", 0.25)
	admin["service_coverage"] = admin.get("service_coverage", 0.70)

	var events = []

	var admin_budget_share = econ.get("budget_allocations", {}).get("اداره", 0.07)
	var admin_budget = econ.get("government_spending", 0.0) * admin_budget_share

	# کارآمدی اداره = f(بودجه، فساد، فناوری، تمرکززدایی)
	var corruption = politics.get("corruption", 0.30)
	var decentral = admin["decentralization"]
	var tech_digital = state.get("technology", {}).get("branches", {}).get("دیجیتال", 0.20)

	var efficiency = 0.5 + (admin_budget / 5_000_000_000.0) * 0.1 - corruption * 0.3 + decentral * 0.1 + tech_digital * 0.1
	admin["efficiency"] = clamp(admin["efficiency"] * 0.99 + efficiency * 0.01, 0.1, 0.95)

	# حکومت محلی
	var local_gov = 0.5 + decentral * 0.3 + admin["efficiency"] * 0.2
	admin["local_governance"] = clamp(local_gov, 0.1, 0.95)

	# نابرابری منطقه‌ای = f(تمرکز بودجه، زیرساخت، حکومت محلی)
	# تمرکز زیاد در پایتخت → نابرابری
	var inequality = 0.35 + (1.0 - decentral) * 0.2 + (1.0 - infra.get("coverage",0.70)) * 0.2 - admin["local_governance"] * 0.1
	admin["regional_inequality"] = clamp(admin["regional_inequality"] * 0.99 + inequality * 0.01, 0.05, 0.80)

	# پوشش خدمات محلی
	var coverage = 0.6 + infra.get("quality",0.55) * 0.2 + admin["local_governance"] * 0.2
	admin["service_coverage"] = clamp(coverage, 0.1, 0.95)

	# سهم بودجه محلی
	admin["local_budget_share"] = clamp(admin["decentralization"] * 0.5 + 0.1, 0.10, 0.60)

	# تمرکززدایی پویا
	if politics.get("stability",0.6) > 0.7 and admin["efficiency"] > 0.6 and Deterministic.chance(0.005):
		admin["decentralization"] += 0.01
		events.append({"type": "decentralization_reform", "message": "اصلاحات تمرکززدایی - اختیار بیشتر به استان‌ها"})
	elif politics.get("tension",0.35) > 0.7 and Deterministic.chance(0.005):
		admin["decentralization"] -= 0.01
		events.append({"type": "centralization", "message": "تمرکزگرایی برای کنترل تنش"})

	admin["decentralization"] = clamp(admin["decentralization"], 0.1, 0.85)

	# حلقه بازخورد: حکومت محلی خوب → رضایت منطقه‌ای → ثبات
	pop["happiness"] = clamp(pop.get("happiness",0.6) + (admin["service_coverage"] - 0.5) * 0.0005 - admin["regional_inequality"] * 0.0005, 0.05, 0.95)
	politics["stability"] = clamp(politics.get("stability",0.6) + (admin["local_governance"] - 0.5) * 0.0005, 0.05, 0.95)
	state["population"] = pop
	state["politics"] = politics

	# رویدادها
	if admin["regional_inequality"] > 0.6 and Deterministic.chance(0.012):
		events.append({"type": "regional_inequality_protest", "message": "اعتراض مناطق محروم به نابرابری منطقه‌ای", "inequality": admin["regional_inequality"]})

	if admin["efficiency"] < 0.4 and Deterministic.chance(0.01):
		events.append({"type": "bureaucracy_crisis", "message": "بحران بوروکراسی و ناکارآمدی اداره"})

	if Deterministic.chance(0.006):
		events.append({"type": "local_success", "message": "موفقیت مدیریت محلی - افزایش رضایت منطقه‌ای"})

	state["administration"] = admin
	
		# ── لایه واقع‌گرایانه اختصاصی حکومت محلی (جایگزین قالب خودکار) — بخش ۳.۲۶ ──
	# سهم بودجه محلی باید با میزان تمرکززدایی واقعی هم‌راستا شود — تفکیک بدون بودجه، نمایشی است
	var local_budget_target = 0.08 + float(admin.get("decentralization", 0.40)) * 0.42
	admin["local_budget_share"] = clampf(float(admin.get("local_budget_share", 0.25)) * 0.995 + local_budget_target * 0.005, 0.05, 0.60)
	# پوشش خدمات محلی: بودجه محلی × کارایی × زیرساخت — نابرابری منطقه‌ای آن را فرسایش می‌دهد
	var service_target = float(admin.get("local_budget_share", 0.25)) * 1.4 + float(admin.get("efficiency", 0.60)) * 0.3 + float(infra.get("coverage", 0.70)) * 0.2 - float(admin.get("regional_inequality", 0.35)) * 0.25
	admin["service_coverage"] = clampf(float(admin.get("service_coverage", 0.70)) * 0.995 + service_target * 0.005, 0.15, 0.97)
	# بازخورد مثبت: حکومت محلی خوب به‌تدریج نابرابری منطقه‌ای را می‌کاهد (همگرایی مناطق)
	admin["regional_inequality"] = clampf(float(admin.get("regional_inequality", 0.35)) - (float(admin.get("local_governance", 0.55)) - 0.5) * 0.0006, 0.05, 0.80)
	if float(admin.get("regional_inequality", 0.35)) > 0.55 and Deterministic.chance(0.005):
		events.append({"type": "regional_deprivation_protest", "message": "تجمع استانی علیه محرومیت منطقه‌ای - مطالبه تخصیص عادلانه بودجه", "gap": admin["regional_inequality"]})
	if float(admin.get("decentralization", 0.40)) > 0.55 and float(admin.get("local_governance", 0.55)) < 0.40 and Deterministic.chance(0.004):
		events.append({"type": "decentralization_mismatch", "message": "واگذاری اختیار بدون ظرفیت محلی - هرج‌ومرج خدمات در شهرستان‌ها"})
	state["administration"] = admin

	return {"success": true, "state": state, "events": events}
