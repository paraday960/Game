extends BaseSystem
# ۳.۶۱ رهبران مذهبی و اجتماعی - نفوذ، اعتماد، اعتدال، خیریه، شبکه مساجد، گفتمان

func compute(state: Dictionary, tick: int) -> Dictionary:
	var rel = state.get("religious_leaders", {})
	rel["count"] = rel.get("count", 30000)
	rel["influence"] = rel.get("influence", 0.60)
	rel["trust"] = rel.get("trust", 0.65)
	rel["moderation"] = rel.get("moderation", 0.60)
	rel["charity"] = rel.get("charity", 0.55)
	rel["mosque_network"] = rel.get("mosque_network", 60000.0)
	rel["sermons_per_week"] = rel.get("sermons_per_week", 3.0)
	rel["social_services"] = rel.get("social_services", 0.50)
	rel["youth_reach"] = rel.get("youth_reach", 0.45)
	rel["interfaith_dialogue"] = rel.get("interfaith_dialogue", 0.40)
	rel["political_stance"] = rel.get("political_stance", 0.10) # 0 بیطرف، مثبت حامی دولت، منفی منتقد

	var events = []
	var culture = state.get("culture", {})
	var edu = state.get("education", {})
	var welfare = state.get("welfare", {})
	var pol = state.get("politics", {})
	var eth = state.get("ethnicity", {})
	var family = state.get("family", {})

	var cohesion = culture.get("cohesion", 0.65)
	var literacy = edu.get("literacy", 0.85)
	var poverty = welfare.get("poverty", 0.15)
	var stability = pol.get("stability", 0.60)
	var tension = pol.get("tension", 0.35)

	# نفوذ - همبسته با انسجام، فقر (پناه به دین)، تعداد مساجد
	var influence_target = cohesion * 0.4 + (1.0 - literacy*0.3) * 0.2 + poverty * 0.2 + 0.2
	rel["influence"] = clamp(rel["influence"]*0.994 + influence_target*0.006, 0.15, 0.95)

	# اعتماد - تابع خیریه، اعتدال، خدمات اجتماعی
	var trust_target = rel["charity"]*0.3 + rel["moderation"]*0.3 + rel["social_services"]*0.2 + 0.2
	rel["trust"] = clamp(rel["trust"]*0.992 + trust_target*0.008 + Deterministic.next_range(-0.002,0.002), 0.1, 0.95)

	# اعتدال - آموزش و گفتمان بین‌ادیانی اثر مثبت، تنش قومی اثر منفی
	var moderation_change = edu.get("quality",0.55)*0.0004 + rel["interfaith_dialogue"]*0.0005 - eth.get("tension",0.30)*0.0008 - tension*0.0003
	rel["moderation"] = clamp(rel["moderation"] + moderation_change, 0.1, 0.95)

	# خیریه - فقر بالا انگیزه خیریه بیشتر اما توان کمتر
	rel["charity"] = clamp(rel["charity"]*0.998 + (0.5 + poverty*0.2 - welfare.get("gini",0.38)*0.2)*0.002, 0.2, 0.90)

	# شبکه مساجد - رشد کند جمعیت
	if tick % 60 == 15:
		var pop_growth = state.get("population",{}).get("growth_rate",0.012)
		rel["mosque_network"] += pop_growth * 100.0
		rel["count"] = int(rel["mosque_network"] * 0.5)

	# خدمات اجتماعی - بودجه رفاه
	rel["social_services"] = clamp(rel["social_services"]*0.995 + welfare.get("poverty",0.15)*0.001 + rel["charity"]*0.001, 0.2, 0.90)

	# دسترسی به جوانان - اثر سواد دیجیتال و تحصیلات
	var tech = state.get("technology",{}).get("branches",{}).get("دیجیتال",0.20)
	rel["youth_reach"] = clamp(rel["youth_reach"]*0.993 + (tech*0.3 + edu.get("quality",0.55)*0.3)*0.007, 0.1, 0.90)

	# گفتگوی بین‌ادیانی - انسجام ملی و ثبات
	rel["interfaith_dialogue"] = clamp(rel["interfaith_dialogue"] + cohesion*0.0002 - eth.get("tension",0.30)*0.0002, 0.1, 0.90)

	# موضع سیاسی - دولت ضعیف رهبران منتقد می‌شوند
	var gov_trust = pol.get("trust",0.55)
	if gov_trust < 0.35:
		rel["political_stance"] = clamp(rel["political_stance"] - 0.001, -0.50, 0.50)
	else:
		rel["political_stance"] = clamp(rel["political_stance"] + 0.0005, -0.50, 0.50)

	# رویدادها
	if rel["moderation"] < 0.32 and Deterministic.chance(0.014):
		events.append({"type":"religious_extremism","moderation": rel["moderation"], "message":"گرایش افراطی در برخی تریبون‌های مذهبی - هشدار نهادهای امنیتی"})

	if rel["moderation"] > 0.80 and rel["interfaith_dialogue"] > 0.70 and Deterministic.chance(0.008):
		events.append({"type":"interfaith_success","message":"همایش بزرگ تقریب مذاهب - کاهش تنش قومی"})

	if rel["trust"] < 0.35 and Deterministic.chance(0.01):
		events.append({"type":"religious_trust_crisis","trust": rel["trust"], "message":"افت اعتماد به نهادهای مذهبی - شایعات فساد مالی"})

	if rel["charity"] > 0.75 and poverty > 0.20 and Deterministic.chance(0.012):
		events.append({"type":"charity_relief","charity": rel["charity"], "message":"شبکه خیریه مساجد - توزیع گسترده بسته معیشتی"})

	if rel["political_stance"] < -0.30 and Deterministic.chance(0.01):
		events.append({"type":"clerical_criticism","stance": rel["political_stance"], "message":"انتقاد صریح ائمه جمعه از عملکرد اقتصادی دولت"})

	state["religious_leaders"] = rel
	
	# ── لایه واقع‌گرایانه اختصاصی رهبران مذهبی (جایگزین قالب خودکار) — بخش ۳.۶۱ ──
	# ریسک افراطی‌گری: نفوذ بالا × اعتدال پایین → فشار رادیکالیزه که امنیت می‌تواند بخواند
	var sec_rl = state.get("security", {})
	sec_rl["extremism_risk"] = clampf((1.0 - float(rel.get("moderation", 0.60))) * float(rel.get("influence", 0.60)) * float(rel.get("youth_reach", 0.45)), 0.0, 0.90)
	state["security"] = sec_rl
	# موضع سیاسی روحانیت به عملکرد واقعی دولت واکنش نشان می‌دهد — فقر و بیکاری منتقد می‌سازد
	var stance_target = clampf(0.25 - float(poverty) * 0.8 - float(pol.get("corruption", 0.30)) * 0.5 + float(pol.get("legitimacy", 0.58)) * 0.3, -0.60, 0.60)
	rel["political_stance"] = clampf(float(rel.get("political_stance", 0.10)) * 0.997 + stance_target * 0.003, -0.60, 0.60)
	# شبکه مساجد باید با جمعیت هم‌پوشانی داشته باشد — حدود یک مسجد به‌ازای هر ۱۴۰۰ نفر
	var pop_rl = float(state.get("population", {}).get("total", 85_000_000))
	rel["mosque_network"] = clampf(float(rel.get("mosque_network", 60000.0)) * 0.9995 + (pop_rl / 1400.0) * 0.0005, 5000.0, 120000.0)
	# دسترسی به جوانان: نسل تحصیل‌کرده و رسانه‌محور، کمتر جذب اِنشاء سنتی می‌شود
	var youth_target = float(rel.get("influence", 0.60)) * (1.15 - float(literacy) * 0.5 - float(culture.get("media_freedom", 0.5)) * 0.2)
	rel["youth_reach"] = clampf(float(rel.get("youth_reach", 0.45)) * 0.998 + youth_target * 0.002, 0.05, 0.90)
	# سهم خیریه در شبکه امنیت اجتماعی (رفاه می‌تواند بخواند — نود جمعیت هدف قرار نمی‌گیرد)
	welfare["charity_contribution"] = clampf(float(rel.get("charity", 0.55)) * float(rel.get("influence", 0.60)) * 0.25, 0.0, 0.30)
	state["welfare"] = welfare
	if float(sec_rl.get("extremism_risk", 0.0)) > 0.35 and Deterministic.chance(0.006):
		events.append({"type": "radical_sermons_warning", "message": "گسترش گفتمان افراطی در برخی کانون‌ها - هشدار نهادهای امنیتی"})
	if float(rel.get("interfaith_dialogue", 0.40)) > 0.60 and Deterministic.chance(0.004):
		events.append({"type": "interfaith_summit", "message": "نشست گفت‌وگوی ادیان - صدور اعلامیه وحدت و اعتدال"})
	state["religious_leaders"] = rel

	return {"success":true,"state":state,"events":events}
