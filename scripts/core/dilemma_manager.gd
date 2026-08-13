extends Node
# ────────────────────────────────────────────────────────────────────────────
# معضلات راهبردی — عمق تصمیم‌گیری اخلاقی/راهبردی
# هر ~۱۰ نوبت یک معضل نادر ظاهر می‌شود: دو انتخاب دشوار که هر کدام پیامدهای
# متفاوت و واقعی روی ثبات، محبوبیت، اقتصاد، فساد، روابط و جامعه دارند.
# هیچ گزینه‌ای «رایگان» نیست — معضل یعنی انتخاب بین دو بدی.
#
# state["dilemmas"] = { "active": {..} | {}, "resolved": 0, "next_turn": 8 }
# ────────────────────────────────────────────────────────────────────────────

const DILEMMAS := [
	{
		"id": "corruption_cover",
		"title": "افشای فساد وزیر اقتصاد",
		"desc": "مدارک فساد گسترده وزیر اقتصاد به دست شما رسیده است؛ او متحد وفادار شماست ولی اموال عمومی را غارت کرده.",
		"option_a": {"label": "🕶️ پوشاندن و حفظ وزیر", "effect": "ثبات −، فساد +، نخبگان وفادار"},
		"option_b": {"label": "⚖️ محاکمه و برکناری او", "effect": "اعتماد +، فساد −، سرمایه سیاسی −"},
	},
	{
		"id": "surveillance",
		"title": "حمله تروریستی قریب‌الوقوع",
		"desc": "اطلاعات از یک حمله قریب‌الوقوع خبر می‌دهد؛ تنها راه شناسایی عاملان، نظارت فراگیر بر ارتباطات شهروندان است.",
		"option_a": {"label": "🔍 نظارت فراگیر (موقت)", "effect": "امنیت +، آزادی مدنی −، رسانه عصبانی"},
		"option_b": {"label": "🕊️ حفظ حریم خصوصی", "effect": "آزادی +، ریسک حمله +"},
	},
	{
		"id": "bailout_industry",
		"title": "سقوط غول صنعتی",
		"desc": "بزرگ‌ترین کارخانه کشور (۱۰۰ هزار شغل) در آستانه ورشکستگی است؛ نجاتش بودجه سنگین می‌خواهد.",
		"option_a": {"label": "💸 نجات با پول دولت", "effect": "بدهی +، اشتغال حفظ، نخبگان خشنود"},
		"option_b": {"label": "🏗️ بازسازی با سرمایه‌گذار جدید", "effect": "بدهی −، ریسک بیکاری موقت، FDI +"},
	},
	{
		"id": "forest_vs_factory",
		"title": "جنگل یا کارخانه؟",
		"desc": "یک شرکت خارجی پیشنهاد کارخانه‌سازی در جنگل بکر شمال داده است: هزاران شغل در برابر اکوسیستم.",
		"option_a": {"label": "🏭 پذیرش کارخانه", "effect": "اشتغال +، GDP +، محیط زیست −، محبوبیت جهانی −"},
		"option_b": {"label": "🌳 حفاظت از جنگل", "effect": "محبوبیت جهانی +، گردشگری +، فرصت شغلی از دست می‌رود"},
	},
	{
		"id": "refugee_crisis",
		"title": "موج پناهندگان",
		"desc": "جنگ همسایه ده‌ها هزار پناهنده به مرز شما آورده است؛ اردوگاه‌ها پر شده‌اند.",
		"option_a": {"label": "🤝 پذیرش و اسکان", "effect": "محبوبیت جهانی +، هزینه رفاه +، تنش پوپولیستی +"},
		"option_b": {"label": "🚧 بستن مرز", "effect": "هزینه −، محبوبیت جهانی −، تنش با همسایه +"},
	},
	{
		"id": "cyber_backdoor",
		"title": "درب پشتی سایبری",
		"desc": "سرویس اطلاعاتی یک قدرت بزرگ می‌خواهد در ازای فناوری پیشرفته، دسترسی پنهان به شبکه ملی شما داشته باشد.",
		"option_a": {"label": "🤝 پذیرش فناوری و دسترسی", "effect": "فناوری +، امنیت سایبری −، استقلال −"},
		"option_b": {"label": "🛡️ رد پیشنهاد", "effect": "استقلال +، فناوری عقب می‌ماند"},
	},
	{
		"id": "protests",
		"title": "اعتراضات سراسری",
		"desc": "افزایش قیمت سوخت جرقه اعتراضات سراسری زده است؛ معترضان خواستار اصلاحات‌اند.",
		"option_a": {"label": "💪 سرکوب شدید", "effect": "آرامش موقت، محبوبیت −، رسانه بین‌المللی خشمگین"},
		"option_b": {"label": "🤝 گفتگو و اصلاحات", "effect": "ثبات بلندمدت +، سرمایه سیاسی −، پوپولیست‌ها قوی‌تر"},
	},
	{
		"id": "oil_windfall",
		"title": "طلای سیاه غیرمنتظره",
		"desc": "میدان نفتی عظیم تازه کشف شده است؛ صندوق ذخیره ملی بسازید یا توسعه فوری؟",
		"option_a": {"label": "🏦 صندوق ذخیره ملی", "effect": "ثبات اقتصادی بلندمدت +، رشد کوتاه‌مدت کمتر"},
		"option_b": {"label": "🚀 توسعه فوری", "effect": "GDP جهش +، تورم +، وابستگی نفتی +"},
	},
]

func ensure(state: Dictionary) -> Dictionary:
	if not state.has("dilemmas"):
		state["dilemmas"] = {"active": {}, "resolved": 0, "next_turn": 8}
	return state

# ── شبیه‌سازی ماهانه: ظهور معضل جدید ──
func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var dm: Dictionary = state["dilemmas"]
	var active: Dictionary = dm.get("active", {})
	if active.is_empty() and int(dm.get("next_turn", 0)) <= turn and Deterministic.chance(0.65):
		var pool := DILEMMAS.duplicate()
		var choice: Dictionary = pool[Deterministic.next_int_range(0, pool.size() - 1)].duplicate(true)
		choice["turn"] = turn
		dm["active"] = choice
		dm["next_turn"] = turn + Deterministic.next_int_range(8, 14)
		state["dilemmas"] = dm
		events.append({"type": "dilemma_appeared", "message": "🤔 معضل راهبردی: «%s» — دو انتخاب دشوار پیش روی شماست" % choice["title"]})
	elif not active.is_empty() and turn - int(active.get("turn", turn)) >= 5:
		# معضل بی‌پاسخ منقضی می‌شود (هزینه بی‌تصمیمی)
		dm["active"] = {}
		state["dilemmas"] = dm
		state["politics"]["stability"] = clampf(float(state["politics"].get("stability", 0.6)) - 0.02, 0.05, 1.0)
		state["media"]["trust"] = clampf(float(state["media"].get("trust", 0.55)) - 0.02, 0.05, 1.0)
		events.append({"type": "dilemma_expired", "message": "🤔 معضل بدون تصمیم ماند؛ بی‌تصمیمی اعتماد و ثبات را خورد"})
	state["dilemmas"] = dm
	return {"state": state, "events": events}

# ── حل معضل: انتخاب A یا B با پیامدهای واقعی ──
func resolve(state: Dictionary, choice: String) -> Dictionary:
	state = ensure(state)
	var dm: Dictionary = state["dilemmas"]
	var active: Dictionary = dm.get("active", {})
	if active.is_empty():
		return {"success": false, "reason": "معضل فعالی نیست", "state": state, "events": []}
	if not ["a", "b"].has(choice):
		return {"success": false, "reason": "انتخاب نامعتبر", "state": state, "events": []}
	var did := str(active.get("id", ""))
	var events: Array = []
	var pol: Dictionary = state.get("politics", {})
	var econ: Dictionary = state.get("economy", {})
	var pop: Dictionary = state.get("population", {})
	var leader: Dictionary = state.get("leader", {})
	var factions: Dictionary = state.get("factions", {})
	var media: Dictionary = state.get("media", {})

	var stability := float(pol.get("stability", 0.6))
	var corruption := float(pol.get("corruption", 0.3))
	var trust := float(media.get("trust", 0.55))
	var happiness := float(pop.get("happiness", 0.6))
	var popularity := float(leader.get("popularity_world", 50.0))
	var gdp := float(econ.get("gdp", 1.0))

	match did:
		"corruption_cover":
			if choice == "a":
				stability = clampf(stability - 0.04, 0.05, 1.0)
				corruption = clampf(corruption + 0.04, 0.0, 1.0)
				if factions.has("نخبگان اقتصادی"):
					factions["نخبگان اقتصادی"]["loyalty"] = clampf(float(factions["نخبگان اقتصادی"].get("loyalty", 50.0)) + 3.0, 0.0, 100.0)
				events.append({"type": "dilemma_resolved", "message": "🕶️ فساد وزیر پوشیده ماند؛ نخبگان وفادار ماندند ولی فساد ریشه دواند"})
			else:
				trust = clampf(trust + 0.05, 0.05, 1.0)
				corruption = clampf(corruption - 0.04, 0.0, 1.0)
				pol["political_capital"] = maxf(0.0, float(pol.get("political_capital", 0.0)) - 1.0)
				if factions.has("نخبگان اقتصادی"):
					factions["نخبگان اقتصادی"]["loyalty"] = clampf(float(factions["نخبگان اقتصادی"].get("loyalty", 50.0)) - 4.0, 0.0, 100.0)
				events.append({"type": "dilemma_resolved", "message": "⚖️ وزیر محاکمه شد؛ اعتماد عمومی بازگشت ولی نخبگان ناخرسندند"})
		"surveillance":
			if choice == "a":
				stability = clampf(stability + 0.03, 0.05, 1.0)
				trust = clampf(trust - 0.05, 0.05, 1.0)
				media["groups"]["جوانان"]["approval"] = clampf(float(media["groups"]["جوانان"].get("approval", 45.0)) - 4.0, 5.0, 100.0)
				events.append({"type": "dilemma_resolved", "message": "🔍 نظارت فراگیر حمله را خنثی کرد ولی آزادی مدنی آسیب دید"})
			else:
				trust = clampf(trust + 0.03, 0.05, 1.0)
				stability = clampf(stability - 0.03, 0.05, 1.0)
				events.append({"type": "dilemma_resolved", "message": "🕊️ حریم خصوصی حفظ شد؛ اما عاملان حمله شناسایی نشدند و امنیت لرزید"})
		"bailout_industry":
			if choice == "a":
				econ["national_debt"] = float(econ.get("national_debt", 0.0)) + gdp * 0.02
				stability = clampf(stability + 0.02, 0.05, 1.0)
				if factions.has("نخبگان اقتصادی"):
					factions["نخبگان اقتصادی"]["loyalty"] = clampf(float(factions["نخبگان اقتصادی"].get("loyalty", 50.0)) + 3.0, 0.0, 100.0)
				events.append({"type": "dilemma_resolved", "message": "💸 غول صنعتی نجات یافت؛ ۱۰۰ هزار شغل حفظ شد ولی بدهی سنگین شد"})
			else:
				econ["foreign_investment"] = float(econ.get("foreign_investment", 1.0)) * 1.04
				econ["unemployment"] = clampf(float(econ.get("unemployment", 0.08)) + 0.004, 0.02, 0.30)
				events.append({"type": "dilemma_resolved", "message": "🏗️ کارخانه با سرمایه خارجی بازسازی شد؛ بیکاری موقت ولی آینده روشن‌تر"})
		"forest_vs_factory":
			if choice == "a":
				econ["gdp"] = gdp * 1.01
				econ["unemployment"] = clampf(float(econ.get("unemployment", 0.08)) - 0.002, 0.02, 0.30)
				popularity = clampf(popularity - 3.0, 0.0, 100.0)
				events.append({"type": "dilemma_resolved", "message": "🏭 کارخانه ساخته شد؛ اشتغال و رشد آمد ولی جهان انتقاد کرد"})
			else:
				popularity = clampf(popularity + 3.0, 0.0, 100.0)
				state["tourism"]["revenue"] = float(state["tourism"].get("revenue", 0.0)) * 1.03
				events.append({"type": "dilemma_resolved", "message": "🌳 جنگل محافظت شد؛ جهان تحسین کرد و گردشگری طبیعت رونق گرفت"})
		"refugee_crisis":
			if choice == "a":
				popularity = clampf(popularity + 3.0, 0.0, 100.0)
				econ["refugee_cost"] = float(econ.get("refugee_cost", 0.0)) + 0.002
				if factions.has("پوپولیست‌ها"):
					factions["پوپولیست‌ها"]["loyalty"] = clampf(float(factions["پوپولیست‌ها"].get("loyalty", 50.0)) - 3.0, 0.0, 100.0)
				events.append({"type": "dilemma_resolved", "message": "🤝 پناهندگان پذیرفته شدند؛ جهان قدردانی کرد ولی هزینه رفاه بالا رفت"})
			else:
				popularity = clampf(popularity - 4.0, 0.0, 100.0)
				state["diplomacy"]["relations"] = state.get("diplomacy", {}).get("relations", {})
				events.append({"type": "dilemma_resolved", "message": "🚧 مرز بسته شد؛ هزینه کم شد ولی تصویر جهانی آسیب دید"})
		"cyber_backdoor":
			if choice == "a":
				state["technology"]["research_points"] = float(state["technology"].get("research_points", 0.0)) + 15.0
				state["cyber"]["firewall"] = clampf(float(state["cyber"].get("firewall", 0.4)) - 0.1, 0.0, 1.0)
				events.append({"type": "dilemma_resolved", "message": "🤝 فناوری پیشرفته گرفتیم ولی درِ پشتی در شبکه ملی باز شد"})
			else:
				state["diplomacy"]["influence"] = clampf(float(state["diplomacy"].get("influence", 40.0)) + 2.0, 0.0, 100.0)
				events.append({"type": "dilemma_resolved", "message": "🛡️ پیشنهاد رد شد؛ استقلال سایبری حفظ شد ولی فناوری عقب ماند"})
		"protests":
			if choice == "a":
				stability = clampf(stability + 0.03, 0.05, 1.0)
				popularity = clampf(popularity - 4.0, 0.0, 100.0)
				trust = clampf(trust - 0.04, 0.05, 1.0)
				events.append({"type": "dilemma_resolved", "message": "💪 اعتراضات سرکوب شد؛ آرامش موقت ولی خشم ماندگار"})
			else:
				pol["political_capital"] = maxf(0.0, float(pol.get("political_capital", 0.0)) - 1.0)
				stability = clampf(stability + 0.04, 0.05, 1.0)
				trust = clampf(trust + 0.04, 0.05, 1.0)
				if factions.has("پوپولیست‌ها"):
					factions["پوپولیست‌ها"]["power"] = clampf(float(factions["پوپولیست‌ها"].get("power", 30.0)) + 4.0, 5.0, 95.0)
				events.append({"type": "dilemma_resolved", "message": "🤝 گفتگو آغاز شد؛ ثبات بلندمدت ولی پوپولیست‌ها قوی‌تر شدند"})
		"oil_windfall":
			if choice == "a":
				econ["foreign_reserves"] = float(econ.get("foreign_reserves", 0.0)) + gdp * 0.01
				events.append({"type": "dilemma_resolved", "message": "🏦 صندوق ذخیره ملی ساخته شد؛ آینده کشور تضمین شد"})
			else:
				econ["gdp"] = gdp * 1.015
				econ["inflation"] = clampf(float(econ.get("inflation", 0.08)) + 0.02, 0.0, 1.5)
				state["trade"]["oil_export_share"] = clampf(float(state["trade"].get("oil_export_share", 0.6)) + 0.1, 0.1, 0.9)
				events.append({"type": "dilemma_resolved", "message": "🚀 توسعه فوری نفت؛ رشد جهش کرد ولی وابستگی و تورم آمد"})

	pol["stability"] = stability
	pol["corruption"] = corruption
	media["trust"] = trust
	pop["happiness"] = happiness
	leader["popularity_world"] = popularity
	state["politics"] = pol
	state["economy"] = econ
	state["population"] = pop
	state["leader"] = leader
	state["factions"] = factions
	state["media"] = media
	dm["active"] = {}
	dm["resolved"] = int(dm.get("resolved", 0)) + 1
	state["dilemmas"] = dm
	return {"success": true, "state": state, "events": events}
