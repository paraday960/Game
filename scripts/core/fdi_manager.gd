extends Node
# ────────────────────────────────────────────────────────────────────────────
# سرمایه‌گذاری خارجی (FDI) — عمق اقتصاد باز
# جذب سرمایه خارجی با ثبات/فساد/مالیات/زیرساخت؛ مناطق ویژه اقتصادی، حمایت
# از شرکت‌های خارجی، حقوق مالکیت فکری، محدودیت‌های ورود. پیوند: تحریم، ارز،
# صنعت، نخبگان، زیرساخت.
#
# state["fdi"] = { "inflow":0..1, "special_zones":0..1, "ip_protection":0..1,
#   "restrictions":0..1, "companies":0 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("fdi_policy"):
		state["fdi_policy"] = {"inflow": 0.25, "special_zones": 0.2, "ip_protection": 0.4, "restrictions": 0.3, "companies": 0}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var fdi: Dictionary = state["fdi_policy"]
	var econ: Dictionary = state.get("economy", {})
	var pol: Dictionary = state.get("politics", {})
	var infra: Dictionary = state.get("infrastructure", {})
	var sanctions: int = state.get("diplomacy", {}).get("sanctions", []).size()
	var inflow := float(fdi.get("inflow", 0.25))
	var zones := float(fdi.get("special_zones", 0.2))
	var ip := float(fdi.get("ip_protection", 0.4))
	var restrictions := float(fdi.get("restrictions", 0.3))

	# جذابیت: ثبات + زیرساخت + حفاظت IP − فساد − محدودیت − تحریم
	var stability := float(pol.get("stability", 0.6))
	var corruption := float(pol.get("corruption", 0.3))
	var infra_q := float(infra.get("quality", 0.6))
	var attractiveness := stability * 0.3 + infra_q * 0.2 + ip * 0.15 - corruption * 0.25 - restrictions * 0.15 - float(sanctions) * 0.1
	inflow = clampf(inflow + (attractiveness - 0.25) * 0.03 + zones * 0.005, 0.0, 0.95)
	fdi["inflow"] = inflow

	# اثر: FDI → سرمایه‌گذاری، اشتغال، فناوری
	econ["foreign_investment"] = float(econ.get("foreign_investment", 1.0)) * (1.0 + inflow * 0.004)
	# ممیزی GDP (۱۴۰۵): اثر مداوم FDI از کانال مالک-یکتای sector_boosts (نرخ سالانه؛ ×۱۲)
	var fdi_boosts: Dictionary = econ.get("sector_boosts", {})
	fdi_boosts["سرمایه‌گذاری خارجی"] = inflow * 0.002 * 12.0
	econ["sector_boosts"] = fdi_boosts
	econ["unemployment"] = clampf(float(econ.get("unemployment", 0.08)) - inflow * 0.0008, 0.02, 0.30)
	# شرکت‌های خارجی → نفوذ فناوری
	state["technology"]["spillover"] = clampf(float(state["technology"].get("spillover", 0.1)) + inflow * 0.002, 0.02, 0.5)
	# ممیزی ذخایر (۱۴۰۵): خروج سرمایه دیگر برش یک‌بارهٔ مخزن نیست — جریان ماهانهٔ
	# منفی در کانال reserve_inflows است (مالک تسویه: بانک مرکزی). تا وقتی اعتماد فرو
	# ریخته (inflow<0.08) جریان ادامه دارد و با بازگشت اعتماد خودبه‌خود صفر می‌شود؛
	# بازیکن در کارت ارز رقم منفی را می‌بیند (اصلاح نمایش مقادیر منفی).
	var fdi_infl: Dictionary = econ.get("reserve_inflows", {})
	var flight_month: float = 0.0
	if inflow < 0.08:
		flight_month = -float(econ.get("foreign_reserves", 0.0)) * 0.002
	fdi_infl["خروج سرمایه خارجی"] = flight_month
	econ["reserve_inflows"] = fdi_infl
	# رویداد: ورود غول خارجی
	if inflow > 0.6 and Deterministic.chance(0.06):
		fdi["companies"] = int(fdi.get("companies", 0)) + 1
		events.append({"type": "fdi_boom", "message": "🏢 سرمایه‌گذار بزرگ خارجی کارخانه جدید افتتاح کرد؛ هزاران شغل ایجاد شد"})
	elif inflow < 0.08 and Deterministic.chance(0.05):
		# اعلان خبرِ جریانِ جاریِ خروج سرمایه (اثر ارزی از کانال می‌گذرد؛ فرسایش
		# سرمایه‌گذاری خصوصی اثر گذرای بحران است و همچنان مستقیم اعمال می‌شود)
		econ["private_investment"] = clampf(float(econ.get("private_investment", 0.15)) - 0.010, 0.03, 0.40)
		state["economy"] = econ
		events.append({"type": "fdi_flee", "message": "✈️ سرمایه‌گذاران خارجی کشور را ترک می‌کنند؛ ذخایر ارزی در حال تخلیه است"})
	state["fdi_policy"] = fdi
	state["economy"] = econ
	return {"state": state, "events": events}

func special_zone(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var fdi: Dictionary = state["fdi_policy"]
	if float(fdi.get("special_zones", 0.2)) >= 0.9:
		return {"success": false, "reason": "ظرفیت مناطق ویژه کامل است", "state": state, "events": []}
	state["economy"]["national_debt"] = float(state["economy"].get("national_debt", 0.0)) + float(state["economy"].get("gdp", 1.0)) * 0.003
	fdi["special_zones"] = clampf(float(fdi.get("special_zones", 0.2)) + 0.2, 0.0, 1.0)
	state["fdi_policy"] = fdi
	return {"success": true, "state": state,
		"events": [{"type": "special_zone", "message": "🏙️ منطقه ویژه اقتصادی جدید: معافیت مالیاتی و زیرساخت برای سرمایه‌گذار خارجی"}]}

func ip_protection(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var fdi: Dictionary = state["fdi_policy"]
	if float(fdi.get("ip_protection", 0.4)) >= 0.95:
		return {"success": false, "reason": "حفاظت مالکیت فکری حداکثری است", "state": state, "events": []}
	state["economy"]["national_debt"] = float(state["economy"].get("national_debt", 0.0)) + float(state["economy"].get("gdp", 1.0)) * 0.002
	fdi["ip_protection"] = clampf(float(fdi.get("ip_protection", 0.4)) + 0.2, 0.0, 1.0)
	state["fdi_policy"] = fdi
	return {"success": true, "state": state,
		"events": [{"type": "ip_protection", "message": "📜 قانون سخت‌گیرانه مالکیت فکری تصویب شد؛ شرکت‌های فناوری به کشور جذب می‌شوند"}]}

func fdi_restrictions(state: Dictionary, level: float) -> Dictionary:
	state = ensure(state)
	if level < 0.0 or level > 1.0:
		return {"success": false, "reason": "سطح نامعتبر", "state": state, "events": []}
	var fdi: Dictionary = state["fdi_policy"]
	fdi["restrictions"] = level
	state["fdi_policy"] = fdi
	return {"success": true, "state": state,
		"events": [{"type": "fdi_restrictions", "message": "🚧 محدودیت سرمایه‌گذاری خارجی به %s٪ تنظیم شد؛ کنترل بیشتر، جذابیت کمتر" % PersianFormatter.to_persian_digits(str(int(level * 100.0)))}]}

func fdi_diplomacy(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var fdi: Dictionary = state["fdi_policy"]
	var capital := float(state.get("policies", {}).get("political_capital", 0.0))
	if capital < 1.0:
		return {"success": false, "reason": "سرمایه سیاسی کافی نیست", "state": state, "events": []}
	state["policies"]["political_capital"] = capital - 1.0
	fdi["inflow"] = clampf(float(fdi.get("inflow", 0.25)) + 0.1, 0.0, 0.95)
	state["fdi_policy"] = fdi
	state["diplomacy"]["influence"] = clampf(float(state["diplomacy"].get("influence", 40.0)) + 1.0, 0.0, 100.0)
	return {"success": true, "state": state,
		"events": [{"type": "fdi_diplomacy", "message": "🤝 هیئت اقتصادی برای جذب سرمایه‌گذار به خارج اعزام شد؛ چند قرارداد مقدماتی امضا شد"}]}
