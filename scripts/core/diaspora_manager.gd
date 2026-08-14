extends Node
# ────────────────────────────────────────────────────────────────────────────
# دیاسپورا و دیپلماسی عمومی — عمق ملت فرامرزی
# ایرانیان/شهروندان خارج از کشور فقط «فرار مغز» نیستند؛ شبکه‌ای از سرمایه،
# دانش، اعتبار، لابی و گردشگری هستند. تعامل حرفه‌ای با آن‌ها remittance،
# سرمایه‌گذاری و قدرت نرم می‌آورد؛ بی‌اعتمادی یا تنش سیاسی آن‌ها را می‌راند.
# پیوند: مهاجرت، پژوهش، اقتصاد، رسانه، فرهنگ، دیپلماسی.
#
# state["diaspora_policy"] = {
#   "engagement":0..1, "networks":0..1, "public_diplomacy":0..1,
#   "return_incentive":0..1, "last_summit":turn, "remittance_b":0..1,
#   "soft_power_boost":0..1, "trust":0..1 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("diaspora_policy"):
		state["diaspora_policy"] = {
			"engagement": 0.35, "networks": 0.25, "public_diplomacy": 0.20,
			"return_incentive": 0.15, "last_summit": -99,
			"remittance_b": 12.0, "soft_power_boost": 0.0, "trust": 0.45
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var dp: Dictionary = state["diaspora_policy"]
	var econ: Dictionary = state.get("economy", {})
	var dip: Dictionary = state.get("diplomacy", {})
	var culture: Dictionary = state.get("culture", {})
	var media: Dictionary = state.get("media", {})
	var research: Dictionary = state.get("research_policy", {})
	var pop: Dictionary = state.get("population", {})

	var engagement := float(dp.get("engagement", 0.35))
	var networks := float(dp.get("networks", 0.25))
	var public_dip := float(dp.get("public_diplomacy", 0.20))
	var incentive := float(dp.get("return_incentive", 0.15))
	var gdp := float(econ.get("gdp", 1.0))
	var stability := float(state.get("politics", {}).get("stability", 0.60))
	var corruption := float(state.get("politics", {}).get("corruption", 0.30))

	# اعتماد دیاسپورا: ثبات/تعامل/شفافیت در برابر فساد و تنش
	var trust := clampf(
		0.30 + engagement * 0.25 + networks * 0.15 + public_dip * 0.15 +
		incentive * 0.12 + stability * 0.12 - corruption * 0.28,
		0.05, 0.98)
	dp["trust"] = trust

	# حواله‌های ارزی: وقتی اعتماد و شبکه بالا باشد، ارز پایدار به خانوار می‌رسد
	var remittance_gdp_share := 0.005 + trust * 0.018 + networks * 0.010
	var remittance := gdp * remittance_gdp_share
	dp["remittance_b"] = remittance / 1_000_000_000.0
	econ["foreign_reserves"] = float(econ.get("foreign_reserves", 0.0)) + remittance * 0.35
	# ممیزی GDP (۱۴۰۵): اثر مداوم از کانال مالک-یکتای sector_boosts (نرخ سالانه؛ ماهانه: ×۱۲) (سایت قبلی با ماسک gdp_ پنهان بود)
	var ds_boosts: Dictionary = econ.get("sector_boosts", {})
	ds_boosts["حواله‌های دیاسپورا"] = remittance_gdp_share * 0.08 * 12.0
	econ["sector_boosts"] = ds_boosts
	pop["happiness"] = clampf(float(pop.get("happiness", 0.60)) + trust * 0.001, 0.05, 1.0)
	state["economy"] = econ
	state["population"] = pop

	# قدرت نرم و لابی دیاسپورا
	var soft_boost := clampf(trust * 0.20 + public_dip * 0.25 + networks * 0.15, 0.0, 0.40)
	dp["soft_power_boost"] = soft_boost
	dip["soft_power"] = clampf(float(dip.get("soft_power", 35.0)) + soft_boost * 0.15, 0.0, 100.0)
	dip["influence"] = clampf(float(dip.get("influence", 40.0)) + trust * 0.04, 0.0, 100.0)
	state["diplomacy"] = dip
	culture["cohesion"] = clampf(float(culture.get("cohesion", 0.65)) + networks * 0.001, 0.05, 1.0)
	state["culture"] = culture
	media["trust"] = clampf(float(media.get("trust", 0.55)) + public_dip * 0.001, 0.05, 1.0)
	state["media"] = media

	# بازگشت نخبگان و دانش: فرار مغز را جبران می‌کند
	if not research.is_empty():
		research["brain_drain"] = clampf(float(research.get("brain_drain", 0.28)) - incentive * 0.002 - trust * 0.001, 0.05, 0.80)
		research["innovation_index"] = clampf(float(research.get("innovation_index", 0.35)) + networks * 0.0008, 0.05, 1.0)
		state["research_policy"] = research

	# رویدادها
	if trust > 0.75 and Deterministic.chance(0.040):
		econ["foreign_reserves"] = float(econ.get("foreign_reserves", 0.0)) + gdp * 0.002
		state["economy"] = econ
		events.append({"type": "diaspora_investment", "message": "🌍 موج سرمایه‌گذاری دیاسپورا! کارآفرینان خارج از کشور پروژه‌های مشترک راه انداختند"})
	elif trust < 0.25 and Deterministic.chance(0.050):
		dip["soft_power"] = clampf(float(dip.get("soft_power", 35.0)) - 0.8, 0.0, 100.0)
		state["diplomacy"] = dip
		events.append({"type": "diaspora_rift", "message": "📉 بی‌اعتمادی دیاسپورا بالا گرفت؛ کمپین منفی در رسانه‌های خارجی به تصویر کشور آسیب زد"})
	elif networks > 0.65 and Deterministic.chance(0.025):
		events.append({"type": "diaspora_lobby", "message": "🤝 شبکه دیاسپورا از موضع دیپلماتیک کشور در یک مجمع بین‌المللی دفاع کرد"})

	state["diaspora_policy"] = dp
	return {"state": state, "events": events}

# ── اجلاس جهانی دیاسپورا ──
func hold_summit(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var dp: Dictionary = state["diaspora_policy"]
	if turn - int(dp.get("last_summit", -99)) < 8:
		return {"success": false, "reason": "اجلاس دیاسپورا هر ۸ نوبت یک بار ممکن است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.002
	dp["last_summit"] = turn
	dp["engagement"] = clampf(float(dp.get("engagement", 0.35)) + 0.15, 0.0, 1.0)
	dp["trust"] = clampf(float(dp.get("trust", 0.45)) + 0.05, 0.0, 1.0)
	state["culture_policy"]["soft_power"] = clampf(float(state.get("culture_policy", {}).get("soft_power", 40.0)) + 2.0, 0.0, 100.0)
	state["economy"] = econ
	state["diaspora_policy"] = dp
	return {"success": true, "state": state,
		"events": [{"type": "diaspora_summit", "message": "🌐 اجلاس جهانی دیاسپورا برگزار شد؛ شبکه‌های علمی، سرمایه‌گذاری و فرهنگی دوباره به کشور وصل شدند"}]}

# ── توسعه شبکه‌های تخصصی خارج از کشور ──
func build_networks(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var dp: Dictionary = state["diaspora_policy"]
	if float(dp.get("networks", 0.25)) >= 0.95:
		return {"success": false, "reason": "شبکه‌های دیاسپورا در سقف ممکن است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.0015
	dp["networks"] = clampf(float(dp.get("networks", 0.25)) + 0.15, 0.0, 1.0)
	dp["soft_power_boost"] = clampf(float(dp.get("soft_power_boost", 0.0)) + 0.03, 0.0, 1.0)
	state["economy"] = econ
	state["diaspora_policy"] = dp
	return {"success": true, "state": state,
		"events": [{"type": "diaspora_network", "message": "🔗 مراکز تخصصی دیاسپورا در دانشگاه‌ها و مراکز فناوری جهان راه‌اندازی شد"}]}

# ── دیپلماسی عمومی و رسانه‌ای ──
func public_diplomacy(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var dp: Dictionary = state["diaspora_policy"]
	if float(dp.get("public_diplomacy", 0.20)) >= 0.95:
		return {"success": false, "reason": "دیپلماسی عمومی در سقف ممکن است", "state": state, "events": []}
	dp["public_diplomacy"] = clampf(float(dp.get("public_diplomacy", 0.20)) + 0.15, 0.0, 1.0)
	state["media"]["freedom"] = clampf(float(state["media"].get("freedom", 0.5)) + 0.01, 0.05, 1.0)
	state["media"]["trust"] = clampf(float(state["media"].get("trust", 0.55)) + 0.008, 0.05, 1.0)
	state["diplomacy"]["soft_power"] = clampf(float(state["diplomacy"].get("soft_power", 35.0)) + 1.0, 0.0, 100.0)
	state["diaspora_policy"] = dp
	return {"success": true, "state": state,
		"events": [{"type": "public_diplomacy", "message": "📡 روایت ملی در رسانه‌ها، دانشگاه‌ها و فضای دیجیتال خارجی تقویت شد"}]}

# ── بسته بازگشت نخبگان ──
func return_talent(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var dp: Dictionary = state["diaspora_policy"]
	if float(dp.get("return_incentive", 0.15)) >= 0.95:
		return {"success": false, "reason": "بسته بازگشت نخبگان در سقف ممکن است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["extra_spending_daily"] = float(econ.get("extra_spending_daily", 0.0)) + float(econ.get("gdp", 1.0)) * 0.0025
	dp["return_incentive"] = clampf(float(dp.get("return_incentive", 0.15)) + 0.15, 0.0, 1.0)
	dp["trust"] = clampf(float(dp.get("trust", 0.45)) + 0.03, 0.0, 1.0)
	var research: Dictionary = state.get("research_policy", {})
	if not research.is_empty():
		research["brain_drain"] = clampf(float(research.get("brain_drain", 0.28)) - 0.05, 0.05, 0.80)
		state["research_policy"] = research
	state["population"]["migration_net"] = int(float(state["population"].get("migration_net", 10000)) + 12000)
	state["economy"] = econ
	state["diaspora_policy"] = dp
	return {"success": true, "state": state,
		"events": [{"type": "return_talent", "message": "🧳 بسته بازگشت نخبگان اعلام شد؛ آزمایشگاه، گرنت و معافیت‌های شغلی مهاجران ماهر را به کشور بازمی‌گرداند"}]}
