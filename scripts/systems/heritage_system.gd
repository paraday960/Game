extends BaseSystem
# ۳.۴۰ میراث فرهنگی و آرشیو - پیاده‌سازی کامل

func compute(state: Dictionary, tick: int) -> Dictionary:
	var heritage = state.get("heritage", {})
	var culture = state.get("culture", {})
	var tourism = state.get("tourism", {})
	var education = state.get("education", {})
	var economy = state.get("economy", {})

	heritage["sites"] = heritage.get("sites", 20)
	heritage["preservation"] = heritage.get("preservation", 0.65)
	heritage["unesco_sites"] = heritage.get("unesco_sites", 3)
	heritage["museums"] = heritage.get("museums", 150)
	heritage["archives"] = heritage.get("archives", 0.60)
	heritage["digital_archives"] = heritage.get("digital_archives", 0.40)
	heritage["restoration"] = heritage.get("restoration", 0.55)
	heritage["cultural_tourism"] = heritage.get("cultural_tourism", 0.50)
	heritage["research"] = heritage.get("research", 0.45)

	var events = []

	var heritage_budget_share = economy.get("budget_allocations",{}).get("محیط",0.03) * 0.5 + 0.01
	var heritage_budget = economy.get("government_spending",0.0) * heritage_budget_share

	# حفاظت = f(بودجه، فناوری، مدیریت، تهدید)
	var tech_digital = state.get("technology",{}).get("branches",{}).get("دیجیتال",0.20)
	var management = culture.get("cohesion",0.65) * 0.3 + education.get("quality",0.55) * 0.2
	var preservation_target = 0.5 + heritage_budget_share * 5.0 + tech_digital * 0.2 + management * 0.2 - state.get("environment",{}).get("pollution",0.4) * 0.1
	heritage["preservation"] = clamp(heritage["preservation"] * 0.99 + preservation_target * 0.01, 0.2, 0.95)

	# سایت‌های میراث
	if heritage["preservation"] > 0.7 and Deterministic.chance(0.003):
		heritage["sites"] += 1
		events.append({"type": "heritage_site_discovered", "message": "کشف محوطه تاریخی جدید - افزایش سایت‌های میراث", "sites": heritage["sites"]})

	# یونسکو
	if heritage["preservation"] > 0.75 and heritage["sites"] > 15 and Deterministic.chance(0.002):
		heritage["unesco_sites"] += 1
		events.append({"type": "unesco_inscription", "message": "ثبت جهانی یونسکو - افتخار ملی و جذب گردشگر!", "unesco": heritage["unesco_sites"]})

	# موزه‌ها
	heritage["museums"] = int(heritage["museums"] * 0.999 + (heritage_budget / 1_000_000_000.0 * 5.0 + tourism.get("visitors",5_000_000)/5_000_000.0 * 10.0) * 0.001)

	# آرشیو و دیجیتال‌سازی
	var archive_target = 0.5 + heritage_budget_share * 2.0 + tech_digital * 0.3
	heritage["archives"] = clamp(heritage["archives"] * 0.995 + archive_target * 0.005, 0.2, 0.95)
	heritage["digital_archives"] = clamp(heritage["digital_archives"] + tech_digital * 0.002, 0.1, 0.90)

	# مرمت
	heritage["restoration"] = clamp(heritage["restoration"] + (heritage_budget_share - 0.02) * 0.002, 0.1, 0.90)

	# گردشگری فرهنگی
	var cultural_tourism_target = 0.4 + heritage["preservation"] * 0.3 + heritage["unesco_sites"] / 10.0 * 0.2 + culture.get("cultural_output",0.5) * 0.2
	heritage["cultural_tourism"] = clamp(heritage["cultural_tourism"] * 0.98 + cultural_tourism_target * 0.02, 0.1, 0.95)

	# پژوهش میراث
	heritage["research"] = clamp(heritage["research"] + education.get("research_output",0.40) * 0.001, 0.1, 0.90)

	# اثر بر گردشگری
	tourism["cultural_attraction"] = heritage["preservation"] * 0.6 + heritage["unesco_sites"] / 20.0 * 0.4 if tourism.has("cultural_attraction") else heritage["preservation"]
	state["tourism"] = tourism

	# اثر بر فرهنگ و هویت
	culture["identity"] = clamp(culture.get("identity",0.70) + heritage["preservation"] * 0.0005, 0.1, 0.95)
	culture["cohesion"] = clamp(culture.get("cohesion",0.65) + heritage["preservation"] * 0.0003, 0.1, 0.95)
	state["culture"] = culture

	# اثر بر اقتصاد - گردشگری فرهنگی
	economy["gdp"] += heritage["cultural_tourism"] * tourism.get("revenue",5_000_000_000.0) * 0.05 / 365.0
	state["economy"] = economy

	# حلقه: حفاظت ← گردشگری ← درآمد ← حفاظت
	if heritage["cultural_tourism"] > 0.7:
		heritage["preservation"] += 0.0005

	# رویدادها
	if heritage["preservation"] < 0.4 and Deterministic.chance(0.012):
		events.append({"type": "heritage_decay", "message": "تخریب میراث فرهنگی - نیاز فوری به مرمت", "preservation": heritage["preservation"]})

	if heritage["digital_archives"] > 0.7 and Deterministic.chance(0.008):
		events.append({"type": "digital_archive_success", "message": "تحول دیجیتال آرشیو - دسترسی جهانی به اسناد تاریخی"})

	if Deterministic.chance(0.006):
		events.append({"type": "heritage_festival", "message": "جشنواره میراث فرهنگی - استقبال عمومی و توریست"})

	state["heritage"] = heritage
	
		# ── لایه واقع‌گرایانه اختصاصی میراث فرهنگی (جایگزین قالب خودکار) — بخش ۳.۴۰ ──
	# درآمد سالانه میراث: گردشگران × سهم گردشگری فرهنگی × ضریب آثار ثبت جهانی یونسکو
	var visitors_h = float(tourism.get("visitors", 5_000_000))
	heritage["annual_income"] = visitors_h * float(heritage.get("cultural_tourism", 0.50)) * (1.0 + float(heritage.get("unesco_sites", 3)) * 0.15) * 18.0
	# قاچاق آثار باستانی: جرم سازمان‌یافته قوی + حفاظت ضعیف → خروج آثار و فرسایش حفاظت
	var sec_h = state.get("security", {})
	var smuggling = float(sec_h.get("organized_crime", 0.30)) * (1.0 - float(heritage.get("preservation", 0.65)))
	if smuggling > 0.15 and Deterministic.chance(0.005):
		heritage["preservation"] = clampf(float(heritage.get("preservation", 0.65)) - 0.02, 0.10, 0.95)
		events.append({"type": "artifact_smuggling", "message": "قاچاق آثار باستانی به خارج از کشور - ضعف حفاظت از میراث ملی"})
	# جنگ بزرگ‌ترین تهدید سایت‌های تاریخی است
	var wars_h = state.get("world", {}).get("wars", {})
	if not wars_h.is_empty() and Deterministic.chance(0.01):
		heritage["sites"] = maxi(int(heritage.get("sites", 20)) - 1, 5)
		events.append({"type": "heritage_war_damage", "message": "آسیب جنگی به محوطه تاریخی - ابراز نگرانی یونسکو", "sites": heritage["sites"]})
	# حفاظت ضعیف پایدار → تخریب تدریجی آثار
	if float(heritage.get("preservation", 0.65)) < 0.40 and Deterministic.chance(0.006):
		events.append({"type": "heritage_decay", "message": "هشدار: محوطه‌های ارزشمند در معرض تخریب - بودجه مرمت کافی نیست"})
	# آرشیو دیجیتال بالا → رونق پژوهش میراث؛ گردشگری فرهنگی قوی → انگیزه حفاظت بیشتر
	if float(heritage.get("digital_archives", 0.40)) > 0.60:
		heritage["research"] = clampf(float(heritage.get("research", 0.45)) + 0.0008, 0.10, 0.95)
	heritage["preservation"] = clampf(float(heritage.get("preservation", 0.65)) + float(heritage.get("cultural_tourism", 0.50)) * 0.0004, 0.10, 0.95)
	state["heritage"] = heritage

	return {"success": true, "state": state, "events": events}
