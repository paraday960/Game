extends Node
# ============================================================
# 📰 مدیر اخبار — تحریریه بین‌المللی
# اطلاعات نمایشی بازی بر اساس «حساسیت» دسته‌بندی می‌شود:
#   🔒 حساس (Sensitive): آمادگی رزمی، عملیات اطلاعاتی، طرح‌های عملیاتی، برنامه‌های
#      تسلیحاتی، جزئیات جبهه — اسراری که فقط رهبر کشور خودش می‌داند.
#   🌐 غیرحساس (Non-Sensitive): اقتصاد، جمعیت، سیاست عمومی، دیپلماسی، تجارت،
#      بحران‌ها، ورزش، فرهنگ — اطلاعات رسمی که همه‌جا منتشر می‌شود.
# قاعده انتشار (مثل دنیای واقعی):
#   - کشور بازیکن: هم اخبار حساس و هم غیرحساس منتشر می‌شود.
#   - کشورهای دیگر: فقط اخبار غیرحساس آن‌ها دیده می‌شود؛ اسرار دیگران محرمانه است.
# ============================================================

const MAX_NEWS_ITEMS = 40
const MAX_OTHER_COUNTRIES_PER_MONTH = 3
const SENSITIVE_LABEL := "sensitive"
const PUBLIC_LABEL := "non_sensitive"

func ensure_state(state: Dictionary) -> Dictionary:
	if not state.has("news") or not state["news"] is Dictionary:
		state["news"] = {"items": [], "generated_tick": -1}
	return state

# انتشار اخبار در پایان هر ماه (از _month_close موتور صدا زده می‌شود)
func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure_state(state)
	var news: Dictionary = state["news"]
	if int(news.get("generated_tick", -1)) == turn:
		return {"state": state, "events": []}
	news["generated_tick"] = turn
	var fresh: Array = _generate(state, turn)
	var items: Array = news.get("items", [])
	for item in fresh:
		items.push_front(item)
	while items.size() > MAX_NEWS_ITEMS:
		items.pop_back()
	news["items"] = items
	state["news"] = news
	var events: Array = []
	if fresh.size() > 0:
		events.append({"type": "news_published", "count": fresh.size(),
			"message": "%s خبر جدید در تحریریه منتشر شد" % PersianFormatter.to_persian_digits(str(fresh.size()))})
	return {"state": state, "events": events}

# اخبار قابل مشاهده برای بازیکن:
#  - اخبار کشور خودش (حساس + غیرحساس)
#  - اخبار غیرحساس کشورهای دیگر (حساسِ دیگران فیلتر می‌شود)
func get_visible_news(state: Dictionary) -> Array:
	state = ensure_state(state)
	var player: String = _player_id(state)
	var out: Array = []
	for item in state["news"].get("items", []):
		var is_player: bool = bool(item.get("is_player", false))
		if str(item.get("country", "")) == player:
			is_player = true
		if not is_player and str(item.get("sensitivity", PUBLIC_LABEL)) == SENSITIVE_LABEL:
			continue
		out.append(item)
	return out

func count_items(state: Dictionary) -> Dictionary:
	state = ensure_state(state)
	var player: String = _player_id(state)
	var sensitive := 0
	var public := 0
	var player_count := 0
	for item in state["news"].get("items", []):
		var is_player: bool = bool(item.get("is_player", false))
		if str(item.get("country", "")) == player:
			is_player = true
		if is_player:
			player_count += 1
		if str(item.get("sensitivity", PUBLIC_LABEL)) == SENSITIVE_LABEL:
			sensitive += 1
		else:
			public += 1
	return {"total": state["news"].get("items", []).size(), "sensitive": sensitive,
		"public": public, "player": player_count}

# ---------------- تولید اخبار ----------------
func _generate(state: Dictionary, turn: int) -> Array:
	var out: Array = []
	var player: String = _player_id(state)
	var clock: Dictionary = state.get("clock", {})
	var year: int = int(clock.get("year", 2027))
	var month: int = int(clock.get("month", 1))
	var month_fa: String = TimeManager.month_name(month)
	out.append_array(_player_news(state, turn, player, year, month_fa))
	out.append_array(_world_news(state, turn, player, year, month_fa))
	return out

func _player_id(state: Dictionary) -> String:
	var pid: String = str(state.get("world", {}).get("player_country", ""))
	if pid == "":
		pid = WorldManager.default_country
	return pid

func _make_item(state: Dictionary, country: String, is_player: bool, category: String, category_fa: String,
		icon: String, sensitivity: String, headline: String, body: String, year: int, month_fa: String, turn: int, seq: int) -> Dictionary:
	var world: Dictionary = state.get("world", {})
	var countries_map: Dictionary = world.get("countries", {})
	var name_fa: String = str(countries_map.get(country, {}).get("name_fa", country))
	return {
		"id": "news_%d_%d" % [turn, seq],
		"tick": turn,
		"year": year,
		"month_fa": month_fa,
		"country": country,
		"country_fa": name_fa,
		"is_player": is_player,
		"category": category,
		"category_fa": category_fa,
		"icon": icon,
		"sensitivity": sensitivity,
		"headline": headline,
		"body": body
	}

func _fmt_percent(value: float) -> String:
	return PersianFormatter.to_persian_digits("%.1f" % (value * 100.0)) + "٪"

func _fmt_num(value: float, decimals := 1) -> String:
	return PersianFormatter.to_persian_digits("%.1f" % value)

# ---- اخبار کشور بازیکن: حساس + غیرحساس ----
func _player_news(state: Dictionary, turn: int, player: String, year: int, month_fa: String) -> Array:
	var out: Array = []
	var seq := 0
	var econ: Dictionary = state.get("economy", {})
	var mil: Dictionary = state.get("military", {})
	var pop: Dictionary = state.get("population", {})
	var pol: Dictionary = state.get("politics", {})
	var world: Dictionary = state.get("world", {})
	var name_fa: String = WorldManager.get_country_name(player)

	# ===== غیرحساس =====
	# ۱) اقتصاد
	var growth = float(econ.get("growth_rate", 0.02)) * 100.0
	var gdp = float(econ.get("gdp", 0.0))
	if growth < -0.5:
		# رکود واقعی: خبر منفی (بازرسی ۱۴۰۵ — دور سیزدهم: اخبار باید واقعیت را بگویند)
		out.append(_make_item(state, player, true, "economy", "اقتصاد", "📉", PUBLIC_LABEL,
			"رکود اقتصادی؛ رشد %s درصدی ثبت شد" % _fmt_num(growth),
			"گزارش‌های رسمی از ادامه‌ی روند منفی تولید ناخالص داخلی حکایت دارد. اقتصاددانان هشدار می‌دهند چرخه‌ی رکود بدون اصلاحات ساختاری ادامه خواهد یافت.",
			year, month_fa, turn, seq)); seq += 1
	else:
		out.append(_make_item(state, player, true, "economy", "اقتصاد", "📈", PUBLIC_LABEL,
			"رشد %s درصدی اقتصاد %s در ماه %s" % [_fmt_num(growth), name_fa, month_fa],
			"تولید ناخالص داخلی کشور به %s رسید. کارشناسان این روند را حاصل ثبات کلان، سرمایه‌گذاری زیرساختی و بهره‌وری نیروی کار ارزیابی می‌کنند." % PersianFormatter.format_money(gdp),
			year, month_fa, turn, seq)); seq += 1
	# ۲) تورم — واکنشگر: اگر از کنترل خارج شده، خبر هشدار
	var inflation = float(econ.get("inflation", 0.08))
	if inflation > 0.25:
		out.append(_make_item(state, player, true, "economy", "اقتصاد", "🔥", PUBLIC_LABEL,
			"هشدار: تورم %s — قیمت‌ها از کنترل خارج شده است" % _fmt_percent(inflation),
			"نرخ تورم به سطوح بحرانی رسیده و سفره‌ی خانوار به شدت تحت فشار است. بانک مرکزی برای مهار انتظارات تورمی با چالش جدی روبه‌روست.",
			year, month_fa, turn, seq)); seq += 1
	elif inflation > 0.15:
		out.append(_make_item(state, player, true, "economy", "اقتصاد", "🏦", PUBLIC_LABEL,
			"تورم %s؛ بانک مرکزی سیاست انضباط پولی را تشدید کرد" % _fmt_percent(inflation),
			"افزایش شاخص قیمت مصرف‌کننده، بانک مرکزی را به سیاست‌های انقباضی سوق داده است. کارشناسان بر مهار انتظارات تورمی تأکید دارند.",
			year, month_fa, turn, seq)); seq += 1
	else:
		out.append(_make_item(state, player, true, "economy", "اقتصاد", "🏦", PUBLIC_LABEL,
			"نرخ تورم %s اعلام شد؛ بانک مرکزی سیاست انضباط پولی را ادامه می‌دهد" % _fmt_percent(inflation),
			"طبق گزارش رسمی بانک مرکزی، نرخ تورم در محدوده هدف مدیریتی باقی مانده و برنامه مهار تورم با موفقیت در جریان است.",
			year, month_fa, turn, seq)); seq += 1
	# ۳) بیکاری — واکنشگر
	var unemployment = float(econ.get("unemployment", 0.08))
	if unemployment > 0.15:
		out.append(_make_item(state, player, true, "economy", "اقتصاد", "💼", PUBLIC_LABEL,
			"بحران اشتغال؛ بیکاری %s — جوانان بیشترین سهم را دارند" % _fmt_percent(unemployment),
			"نرخ بیکاری به سطوح هشدار رسیده و نارضایتی در بازار کار رو به گسترش است. برنامه‌های اشتغال‌زایی موجود پاسخگوی تقاضا نیست.",
			year, month_fa, turn, seq)); seq += 1
	else:
		out.append(_make_item(state, player, true, "economy", "اقتصاد", "💼", PUBLIC_LABEL,
			"نرخ بیکاری کشور %s گزارش شد" % _fmt_percent(unemployment),
			"وزارت کار آخرین آمار بازار کار را منتشر کرد؛ برنامه‌های اشتغال‌زایی و مهارت‌آموزی در حال گسترش است.",
			year, month_fa, turn, seq)); seq += 1
	# ۴) جمعیت
	var total_pop = float(pop.get("total", 0.0))
	out.append(_make_item(state, player, true, "society", "جامعه", "👥", PUBLIC_LABEL,
		"جمعیت %s به %s نفر رسید" % [name_fa, PersianFormatter.format_large(total_pop)],
		"مرکز آمار ملی جدیدترین برآورد جمعیتی کشور را منتشر کرد؛ روند رشد جمعیت و ترکیب سنی در حال پایش است.",
		year, month_fa, turn, seq)); seq += 1
	# ۵) رضایت عمومی — واکنشگر
	var satisfaction = float(pop.get("satisfaction", pop.get("happiness", 0.6)))
	if satisfaction < 0.35:
		out.append(_make_item(state, player, true, "society", "جامعه", "😠", PUBLIC_LABEL,
			"نارضایتی گسترده؛ شاخص رضایت عمومی به %s سقوط کرد" % _fmt_percent(satisfaction),
			"نظرسنجی‌های ملی از افت شدید رضایت عمومی حکایت دارد؛ فشار معیشتی و ناامیدی از آینده، خیابان‌ها را به اعتراض کشانده است.",
			year, month_fa, turn, seq)); seq += 1
	else:
		out.append(_make_item(state, player, true, "society", "جامعه", "😊", PUBLIC_LABEL,
			"شاخص رضایت عمومی %s ارزیابی شد" % _fmt_percent(satisfaction),
			"نظرسنجی‌های ملی نشان می‌دهد سیاست‌های رفاهی و خدمات عمومی با استقبال شهروندان روبه‌رو شده است.",
			year, month_fa, turn, seq)); seq += 1
	# ۶) روابط خارجی و درگیری‌ها (جنگ عمومی است)
	var wars: Dictionary = world.get("wars", {})
	if wars.size() > 0:
		var war_names: Array = []
		for target in wars.keys():
			war_names.append(WorldManager.get_country_name(str(target)))
		out.append(_make_item(state, player, true, "diplomacy", "دیپلماسی", "⚔️", PUBLIC_LABEL,
			"درگیری نظامی با %s ادامه دارد" % "، ".join(war_names),
			"وزارت امور خارجه در نشست خبری آخرین وضعیت درگیری‌های جاری را تشریح کرد و بر پیگیری راه‌های دیپلماتیک تأکید نمود.",
			year, month_fa, turn, seq)); seq += 1
	# ۷) بحران‌ها — واکنشگر: گزارش دقیق هر بحران فعال (بازرسی ۱۴۰۵ — دور سیزدهم)
	var crises: Array = state.get("events_active", [])
	if crises.size() > 0:
		out.append(_make_item(state, player, true, "crisis", "بحران", "⚠️", PUBLIC_LABEL,
			"هشدار: %s بحران فعال در کشور تحت مدیریت قرار دارد" % PersianFormatter.to_persian_digits(str(crises.size())),
			"ستاد مدیریت بحران کشور تدابیر لازم را فعال کرده و از شهروندان خواسته است اخبار رسمی را دنبال کنند.",
			year, month_fa, turn, seq)); seq += 1
		# گزارش تفصیلی هر بحران/نخ فعال (واکنش به وضعیت واقعی — عمق‌بخشی ۳)
		for crisis in crises:
			if str(crisis.get("status", "active")) != "active":
				continue
			var c_title: String = str(crisis.get("title", "بحران"))
			var c_type: String = str(crisis.get("type", ""))
			if int(crisis.get("stage_count", 0)) > 0:
				var stage_now: int = int(crisis.get("stage", 0)) + 1
				var stage_total: int = int(crisis.get("stage_count", 1))
				out.append(_make_item(state, player, true, "crisis", "بحران", "🔗", PUBLIC_LABEL,
					"«%s» — مرحلهٔ %s از %s: %s" % [
						c_title, PersianFormatter.to_persian_digits(str(stage_now)),
						PersianFormatter.to_persian_digits(str(stage_total)),
						str(crisis.get("stage_name_fa", ""))],
					"نخ بحران «%s» همچنان در جریان است و کارشناسان نسبت به پیامدهای مرحلهٔ کنونی هشدار می‌دهند. ستاد بحران بر مدیریت مرحله‌به‌مرحله تأکید دارد." % c_title,
					year, month_fa, turn, seq)); seq += 1
			else:
				out.append(_make_item(state, player, true, "crisis", "بحران", "🚨", PUBLIC_LABEL,
					"بحران «%s» فعال است؛ ستاد مدیریت بحران در جلسهٔ فوق‌العاده" % c_title,
					"مقام‌ها از شهروندان خواسته‌اند آرامش خود را حفظ کنند و اخبار را تنها از منابع رسمی دنبال کنند.",
					year, month_fa, turn, seq)); seq += 1
	# ۸) ثبات سیاسی — واکنشگر
	var stability = float(pol.get("stability", 0.6))
	if stability < 0.35:
		out.append(_make_item(state, player, true, "politics", "سیاست", "🏛️", PUBLIC_LABEL,
			"بی‌ثباتی سیاسی؛ شاخص ثبات به %s رسید" % _fmt_percent(stability),
			"نهادهای بین‌المللی درباره‌ی وضعیت سیاسی کشور هشدار داده‌اند. تحلیلگران از شکاف فزاینده میان دولت و جامعه سخن می‌گویند.",
			year, month_fa, turn, seq)); seq += 1
	else:
		out.append(_make_item(state, player, true, "politics", "سیاست", "🏛️", PUBLIC_LABEL,
			"شاخص ثبات سیاسی کشور %s ارزیابی شد" % _fmt_percent(stability),
			"تحلیلگران سیاسی وضعیت کلی حاکمیت را باثبات توصیف می‌کنند و نهادهای داخلی در حال اجرای برنامه‌های توسعه‌اند.",
			year, month_fa, turn, seq)); seq += 1

	# ===== حساس (فقط کشور خود بازیکن) =====
	# ۱) آمادگی رزمی
	var readiness = float(mil.get("readiness", 0.6))
	out.append(_make_item(state, player, true, "military", "نظامی", "🛡️", SENSITIVE_LABEL,
		"گزارش محرمانه: سطح آمادگی رزمی نیروهای مسلح %s برآورد شد" % _fmt_percent(readiness),
		"سند داخلی ستاد کل نیروهای مسلح که به دست تحریریه رسیده، حاکی از %s آمادگی رزمی در سطوح عملیاتی و پدافندی است. جزئیات این گزارش محرمانه است." % _fmt_percent(readiness),
		year, month_fa, turn, seq)); seq += 1
	# ۲) عملیات اطلاعاتی
	var intel: Dictionary = state.get("intelligence", {})
	var cyber = float(intel.get("cyber_readiness", 0.5))
	out.append(_make_item(state, player, true, "intelligence", "اطلاعات", "🕵️", SENSITIVE_LABEL,
		"عملیات‌های اطلاعاتی و امنیت ملی در جریان است؛ جزئیات محرمانه اعلام نشد",
		"منابع آگاه از اجرای مجموعه‌ای از عملیات‌های اطلاعاتی، ضدجاسوسی و مقابله با تهدیدهای سایبری (با آمادگی سایبری %s) خبر می‌دهند." % _fmt_percent(cyber),
		year, month_fa, turn, seq)); seq += 1
	# ۳) طرح‌های عملیاتی
	var adv: Dictionary = state.get("map_advanced", {})
	var plans: Array = adv.get("battle_plans", [])
	if plans.size() > 0:
		out.append(_make_item(state, player, true, "military", "نظامی", "🗺️", SENSITIVE_LABEL,
			"طرح‌های عملیاتی جدیدی در ستاد فرماندهی در حال تدوین است",
			"بر اساس اسناد محرمانه، تعداد %s طرح عملیاتی در مراحل مختلف آماده‌سازی قرار دارد. تحلیلگران نظامی از تغییر احتمالی در آرایش دفاعی کشور خبر می‌دهند." % PersianFormatter.to_persian_digits(str(plans.size())),
			year, month_fa, turn, seq)); seq += 1
	return out

# ---- اخبار کشورهای دیگر: فقط غیرحساس ----
func _world_news(state: Dictionary, turn: int, player: String, year: int, month_fa: String) -> Array:
	var out: Array = []
	var world: Dictionary = state.get("world", {})
	var countries_map: Dictionary = world.get("countries", {})
	var codes: Array = []
	for c in countries_map.keys():
		if str(c) != player:
			# کشور ضمیمه‌شده مستقل نیست؛ اخبار جداگانه ندارد (بازرسی ۱۴۰۵)
			if str(countries_map.get(c, {}).get("annexed_by", "")) != "":
				continue
			codes.append(str(c))
	if codes.is_empty():
		return out
	codes.sort()
	var npc_wars: Dictionary = world.get("npc_wars", {})
	var npc_alliances: Array = world.get("npc_alliances", [])
	var npc_trade: Array = world.get("npc_trade_agreements", [])
	var player_wars: Dictionary = world.get("wars", {})

	for i in range(MAX_OTHER_COUNTRIES_PER_MONTH):
		var ci = (turn * 31 + i * 97) % codes.size()
		var code: String = str(codes[ci])
		var profile: Dictionary = countries_map.get(code, {})
		if profile.is_empty():
			continue
		var name: String = str(profile.get("name_fa", code))
		var template = (turn + i) % 7
		var headline := ""; var body := ""; var cat := "world"; var cat_fa := "بین‌الملل"; var icon := "🌍"
		match template:
			0:  # رشد اقتصادی (برآورد)
				var gdp = float(profile.get("gdp", 1.0))
				var growth = Deterministic.next_range(0.4, 4.8)
				headline = "پیش‌بینی رشد %s درصدی اقتصاد %s در سال جاری" % [_fmt_num(growth), name]
				body = "نهادهای مالی بین‌المللی چشم‌انداز مثبتی برای اقتصاد %s ترسیم کردند؛ ارزش تولید ناخالص داخلی این کشور حدود %s برآورد می‌شود." % [name, PersianFormatter.format_large(gdp)]
				cat = "economy"; cat_fa = "اقتصاد"; icon = "📈"
			1:  # جمعیت
				var pop_n = float(profile.get("population", 1_000_000.0))
				headline = "جمعیت %s از مرز %s نفر گذشت" % [name, PersianFormatter.format_large(pop_n)]
				body = "اداره آمار %s جدیدترین سرشماری را منتشر کرد؛ ترکیب سنی و نرخ رشد جمعیت در گزارش رسمی اعلام شده است." % name
				cat = "society"; cat_fa = "جامعه"; icon = "👥"
			2:  # شاخص توان نظامی (رتبه‌بندی عمومی)
				var mil_power = float(profile.get("military_power", 50.0))
				headline = "شاخص توان نظامی %s در رتبه‌بندی جهانی اعلام شد" % name
				body = "مؤسسه‌های بین‌المللی رتبه‌بندی سالانه توان نظامی را منتشر کردند؛ %s با شاخص %s در جمع کشورهای مورد توجه قرار گرفته است." % [name, _fmt_num(mil_power, 0)]
				cat = "military"; cat_fa = "نظامی"; icon = "⚔️"
			3:  # جنگ جاری میان کشورها (عمومی)
				var enemy := ""
				for key in npc_wars.keys():
					var parts: Array = str(key).split("|")
					if parts.has(code):
						enemy = str(parts[0]) if str(parts[1]) == code else str(parts[1])
						break
				if enemy != "":
					headline = "درگیری %s و %s ادامه دارد؛ تحلیلگران از تغییر توازن قوا خبر می‌دهند" % [name, WorldManager.get_country_name(enemy)]
					body = "گزارش‌های میدانی از ادامه درگیری میان %s و %s حکایت دارد؛ نهادهای بین‌المللی خواستار کاهش تنش شدند." % [name, WorldManager.get_country_name(enemy)]
					cat = "diplomacy"; cat_fa = "دیپلماسی"; icon = "⚔️"
				else:
					headline = "گزارش وضعیت منطقه‌ای: %s سیاست خارجی فعالی را دنبال می‌کند" % name
					body = "کارشناسان روابط بین‌الملل نقش رو به رشد %s را در تحولات منطقه‌ای مورد توجه قرار داده‌اند." % name
					cat = "diplomacy"; cat_fa = "دیپلماسی"; icon = "🌍"
			4:  # اتحادها
				var ally_count := 0
				for key in npc_alliances:
					if str(key).split("|").has(code):
						ally_count += 1
				if ally_count > 0:
					headline = "%s ائتلاف‌های راهبردی خود را گسترش داد" % name
					body = "تحلیلگران امنیتی از تحکیم ائتلاف‌های منطقه‌ای %s (در حال حاضر %s ائتلاف) خبر می‌دهند که می‌تواند معادلات منطقه را تغییر دهد." % [name, PersianFormatter.to_persian_digits(str(ally_count))]
				else:
					headline = "%s در حال بررسی شراکت‌های راهبردی تازه است" % name
					body = "منابع دیپلماتیک از مذاکرات اولیه %s برای گسترش شراکت‌های امنیتی و اقتصادی خبر می‌دهند." % name
				cat = "diplomacy"; cat_fa = "دیپلماسی"; icon = "🤝"
			5:  # تجارت
				var trade_count := 0
				for key in npc_trade:
					if str(key).split("|").has(code):
						trade_count += 1
				headline = "گسترش توافق‌های تجاری %s در بازارهای جهانی" % name
				body = "%s با %s توافق تجاری فعال، مسیر توسعه صادرات را دنبال می‌کند؛ کارشناسان این روند را برای اقتصاد منطقه مثبت ارزیابی می‌کنند." % [name, PersianFormatter.to_persian_digits(str(trade_count))]
				cat = "economy"; cat_fa = "اقتصاد"; icon = "📦"
			6:  # جنگ با بازیکن (عمومی — اعلام جنگ)
				var at_war_with_player := player_wars.has(code)
				if at_war_with_player:
					headline = "وضعیت درگیری میان %s و %s در کانون توجه رسانه‌ها" % [name, WorldManager.get_country_name(player)]
					body = "رسانه‌های جهانی تحولات درگیری میان %s و %s را پوشش می‌دهند؛ واکنش‌های دیپلماتیک ادامه دارد." % [name, WorldManager.get_country_name(player)]
					cat = "diplomacy"; cat_fa = "دیپلماسی"; icon = "⚔️"
				else:
					headline = "%s گزارش اقتصادی ماهانه خود را منتشر کرد" % name
					body = "داده‌های اقتصادی منتشرشده از %s نشان‌دهنده روند باثبات در شاخص‌های کلان این کشور است." % name
					cat = "economy"; cat_fa = "اقتصاد"; icon = "📊"
		out.append(_make_item(state, code, false, cat, cat_fa, icon, PUBLIC_LABEL, headline, body, year, month_fa, turn, 100 + i))
	# اخبار جهانی واکنشگر به بازار کالاها (عمق‌بخشی ۳): شوک‌های قیمت نفت/گاز/
	# گندم/فلزات که اقتصاد همه‌ی کشورها را می‌لرزاند باید در تحریریه دیده شوند.
	out.append_array(_world_market_news(state, turn, player, year, month_fa))
	return out

# اخبار بازار جهانی کالا — واکنش به قیمت‌های واقعی commodities (عمق‌بخشی ۳)
func _world_market_news(state: Dictionary, turn: int, player: String, year: int, month_fa: String) -> Array:
	var out: Array = []
	var prices: Dictionary = state.get("commodities", {}).get("prices", {})
	var base := CommodityManager.BASE_PRICES
	var oil := float(prices.get("نفت", float(base.get("نفت", 75.0))))
	var gas := float(prices.get("گاز", float(base.get("گاز", 3.2))))
	var wheat := float(prices.get("گندم", float(base.get("گندم", 260.0))))
	var metals := float(prices.get("فلزات", float(base.get("فلزات", 1800.0))))
	if oil > 110.0:
		out.append(_make_item(state, player, false, "economy", "اقتصاد", "🛢️", PUBLIC_LABEL,
			"بازار جهانی نفت؛ بشکه %s دلار — فشار بر واردکنندگان انرژی" % _fmt_num(oil, 0),
			"قیمت نفت در پی تنش‌های ژئوپلیتیک و اختلال عرضه به %s دلار رسید. کشورهای واردکننده با افزایش هزینه‌ی انرژی و تورم وارداتی روبه‌رو شده‌اند." % _fmt_num(oil, 0),
			year, month_fa, turn, 201))
	elif oil < 45.0:
		out.append(_make_item(state, player, false, "economy", "اقتصاد", "🛢️", PUBLIC_LABEL,
			"ریزش قیمت نفت؛ بشکه %s دلار — فشار بر بودجه‌ی صادرکنندگان" % _fmt_num(oil, 0),
			"قیمت نفت به %s دلار سقوط کرد و بودجه‌ی کشورهای صادرکننده را تحت فشار قرار داده است. بازارهای مالی با نوسان شدید دست‌وپنجه نرم می‌کنند." % _fmt_num(oil, 0),
			year, month_fa, turn, 202))
	if wheat > 400.0:
		out.append(_make_item(state, player, false, "economy", "اقتصاد", "🌾", PUBLIC_LABEL,
			"شوک جهانی غذا؛ قیمت گندم به %s دلار رسید" % _fmt_num(wheat, 0),
			"خشکسالی و اختلال زنجیره‌ی تأمین، قیمت جهانی گندم را به %s دلار رساند. کشورهای وابسته به واردات با خطر ناامنی غذایی روبه‌رو شده‌اند." % _fmt_num(wheat, 0),
			year, month_fa, turn, 203))
	if metals > 3000.0:
		out.append(_make_item(state, player, false, "economy", "اقتصاد", "⚙️", PUBLIC_LABEL,
			"رونق فلزات صنعتی؛ تقاضای دیتاسنترها و انرژی پاک قیمت را بالا برد",
			"قیمت جهانی فلزات به %s دلار رسید. رقابت بر سر زیرساخت هوش مصنوعی و گذار انرژی، تقاضای فلزات را به اوج تاریخی رسانده است." % _fmt_num(metals, 0),
			year, month_fa, turn, 204))
	return out
