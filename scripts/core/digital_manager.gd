extends Node
# ────────────────────────────────────────────────────────────────────────────
# اقتصاد دیجیتال — عمق تحول دیجیتال
# پوشش اینترنت، دولت الکترونیک (کارآمدی/فساد)، ارز دیجیتال بانک مرکزی (CBDC)،
# حریم خصوصی (اعتماد/نظارت). پیوند: دیجیتال، سایبر، آموزش، بانکداری، رسانه.
#
# state["digital_policy"] = { "internet_coverage":0..1, "egovernment":0..1,
#   "cbdc":0..1, "privacy":0..1, "digital_gdp":0 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("digital_policy"):
		state["digital_policy"] = {"internet_coverage": 0.5, "egovernment": 0.3, "cbdc": 0.0, "privacy": 0.5, "digital_gdp": 0.0}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var dp: Dictionary = state["digital_policy"]
	var econ: Dictionary = state.get("economy", {})
	var pol: Dictionary = state.get("politics", {})
	var cyber: Dictionary = state.get("cyber", {})
	var coverage := float(dp.get("internet_coverage", 0.5))
	var egovernment := float(dp.get("egovernment", 0.3))
	var cbdc := float(dp.get("cbdc", 0.0))
	var privacy := float(dp.get("privacy", 0.5))

	# اقتصاد دیجیتال: پوشش + دولت الکترونیک + CBDC
	var digital_gdp := coverage * 0.1 + egovernment * 0.05 + cbdc * 0.08
	dp["digital_gdp"] = digital_gdp
	# ممیزی GDP (۱۴۰۵): اثر مداوم دیجیتال از کانال مالک-یکتای sector_boosts (نرخ سالانه؛ ×۱۲)
	var dig_boosts: Dictionary = econ.get("sector_boosts", {})
	dig_boosts["اقتصاد دیجیتال"] = digital_gdp * 0.01 * 12.0
	econ["sector_boosts"] = dig_boosts
	# دولت الکترونیک فساد را می‌کاهد
	pol["corruption"] = clampf(float(pol.get("corruption", 0.3)) - egovernment * 0.002, 0.0, 1.0)
	# CBDC: بانکداری را شفاف می‌کند (سایه را می‌خورد) ولی حریم خصوصی را می‌آزارد
	state["shadow"]["size"] = clampf(float(state["shadow"].get("size", 0.18)) - cbdc * 0.01, 0.03, 0.55)
	cyber["firewall"] = clampf(float(cyber.get("firewall", 0.4)) - cbdc * 0.002, 0.0, 1.0)  # سطح حمله بیشتر
	state["cyber"] = cyber
	# حریم خصوصی: اعتماد رسانه
	state["media"]["trust"] = clampf(float(state["media"].get("trust", 0.55)) + (privacy - 0.5) * 0.005, 0.05, 1.0)
	# رویداد: قطعی اینترنت در پوشش پایین و تنش بالا
	if coverage < 0.3 and Deterministic.chance(0.04):
		state["media"]["groups"]["جوانان"]["approval"] = clampf(float(state["media"]["groups"]["جوانان"].get("approval", 45.0)) - 2.0, 5.0, 100.0)
		events.append({"type": "internet_outage", "message": "📵 قطعی گسترده اینترنت! کسب‌وکارهای دیجیتال و جوانان آسیب دیدند"})
	state["digital_policy"] = dp
	state["economy"] = econ
	state["politics"] = pol
	return {"state": state, "events": events}

func expand_internet(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var dp: Dictionary = state["digital_policy"]
	if float(dp.get("internet_coverage", 0.5)) >= 0.98:
		return {"success": false, "reason": "پوشش اینترنت کامل است", "state": state, "events": []}
	state["economy"]["national_debt"] = float(state["economy"].get("national_debt", 0.0)) + float(state["economy"].get("gdp", 1.0)) * 0.004
	dp["internet_coverage"] = clampf(float(dp.get("internet_coverage", 0.5)) + 0.15, 0.0, 1.0)
	state["digital_policy"] = dp
	return {"success": true, "state": state,
		"events": [{"type": "internet_expand", "message": "📡 فیبر نوری و اینترنت پرسرعت به مناطق محروم رسید؛ روستاها به شبکه جهانی پیوستند"}]}

func e_government(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var dp: Dictionary = state["digital_policy"]
	if float(dp.get("egovernment", 0.3)) >= 0.95:
		return {"success": false, "reason": "دولت الکترونیک کامل است", "state": state, "events": []}
	var tech: Dictionary = state.get("technology", {})
	if float(tech.get("branch_levels", {}).get("دیجیتال", 0)) < 8:
		return {"success": false, "reason": "فناوری دیجیتال کافی نیست (سطح ۸+)", "state": state, "events": []}
	state["economy"]["national_debt"] = float(state["economy"].get("national_debt", 0.0)) + float(state["economy"].get("gdp", 1.0)) * 0.003
	dp["egovernment"] = clampf(float(dp.get("egovernment", 0.3)) + 0.2, 0.0, 1.0)
	state["digital_policy"] = dp
	# کارآمدی + کاهش فساد
	state["politics"]["corruption"] = clampf(float(state["politics"].get("corruption", 0.3)) - 0.02, 0.0, 1.0)
	return {"success": true, "state": state,
		"events": [{"type": "egovernment", "message": "🏛️ دولت الکترونیک: خدمات آنلاین، شفافیت و کاهش فساد اداری"}]}

func cbdc_launch(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var dp: Dictionary = state["digital_policy"]
	if float(dp.get("cbdc", 0.0)) >= 1.0:
		return {"success": false, "reason": "ارز دیجیتال ملی فعال است", "state": state, "events": []}
	var tech: Dictionary = state.get("technology", {})
	if float(tech.get("branch_levels", {}).get("دیجیتال", 0)) < 12:
		return {"success": false, "reason": "فناوری دیجیتال کافی نیست (سطح ۱۲+)", "state": state, "events": []}
	state["economy"]["national_debt"] = float(state["economy"].get("national_debt", 0.0)) + float(state["economy"].get("gdp", 1.0)) * 0.005
	dp["cbdc"] = 1.0
	state["digital_policy"] = dp
	# شفافیت مالی: سایه و فرار مالیاتی کم
	state["shadow"]["size"] = clampf(float(state["shadow"].get("size", 0.18)) - 0.04, 0.03, 0.55)
	return {"success": true, "state": state,
		"events": [{"type": "cbdc", "message": "💳 ارز دیجیتال بانک مرکزی راه‌اندازی شد! اقتصاد سایه و فرار مالیاتی ضربه خورد"}]}

func privacy_law(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var dp: Dictionary = state["digital_policy"]
	if float(dp.get("privacy", 0.5)) >= 0.95:
		return {"success": false, "reason": "حفاظت حریم خصوصی حداکثری است", "state": state, "events": []}
	dp["privacy"] = clampf(float(dp.get("privacy", 0.5)) + 0.2, 0.0, 1.0)
	state["digital_policy"] = dp
	state["media"]["trust"] = clampf(float(state["media"].get("trust", 0.55)) + 0.03, 0.05, 1.0)
	# نظارت سخت‌تر می‌شود → جرم‌شناسی دیجیتال سخت
	state["cyber"]["firewall"] = clampf(float(state["cyber"].get("firewall", 0.4)) + 0.05, 0.0, 1.0)
	return {"success": true, "state": state,
		"events": [{"type": "privacy_law", "message": "🔒 قانون حفاظت از داده‌ها تصویب شد؛ اعتماد دیجیتال مردم بازگشت"}]}
