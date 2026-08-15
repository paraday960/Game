extends BaseSystem
# سیستم اقتصاد و بودجه - ۳.۱۰ - نسخه عمیق واقعی - اقتصاد جنگی، بسیج صنعتی، جیره‌بندی، بازار سیاه، بدهی جنگی، تحریم

# ── کانال مالک-یکتای سطح GDP (ممیزی نویسندگان چندگانهٔ GDP، ۱۴۰۵) ──
# تا قبل از این ممیزی، ده‌ها سیستم/مدیر هر ماه «gdp *= (۱+x)» می‌کردند؛ ضرایب روی هم
# سوار می‌شدند («سهمِ بخش» به‌اشتباه «رشدِ ماهانهٔ کل» تلقی می‌شد — دوشماره‌ای بزرگ).
# قرارداد: هر ناشرِ اثر *مداوم* نرخ سالانهٔ خود را در economy.sector_boosts بازنویسی
# می‌کند (هرگز += نیست؛ بیکار = ۰٫۰) و اعمالِ روزانه فقط این‌جاست. ضربه‌های گذرای
# رویدادی (شوک جنگ، کرش بانکی، بحران مالی…) از قاعده مستثناست.
const SECTOR_BOOST_MAX := 0.05   # سقف نرخ سالانهٔ هر بخش (±۵٪)
const SECTOR_BOOSTS_CAP := 0.10  # سقف جمع کانال بخش‌ها (±۱۰٪ در سال)

func compute(state: Dictionary, tick: int) -> Dictionary:
	var econ = state.get("economy", {})
	var pop = state.get("population", {})
	var pol = state.get("politics", {})
	var resources = state.get("resources", {})
	var infra = state.get("infrastructure", {})
	var tech = state.get("technology", {})
	var trade = state.get("trade", {})
	var central_bank = state.get("central_bank", {})
	var world = state.get("world", {})
	var mil = state.get("military", {})
	var welfare = state.get("welfare", {})
	var private_sector = state.get("private_sector", {})

	var events = []

	# ── چرخه اقتصادی: رونق/رشد/رکود/رکود عمیق با اعتماد سرمایه‌گذاران ──
	var cycle: Dictionary = econ.get("cycle", {})
	if cycle.is_empty():
		cycle = {"phase": "growth", "months_left": 5.0, "confidence": 55.0}
	cycle["phase"] = str(cycle.get("phase", "growth"))
	cycle["months_left"] = float(cycle.get("months_left", 5.0))
	cycle["confidence"] = clampf(float(cycle.get("confidence", 55.0)), 5.0, 95.0)
	var cycle_effect: float = float({"boom": 0.012, "growth": 0.004, "stagnation": -0.006, "recession": -0.014}.get(str(cycle["phase"]), 0.0))
	# اعتماد سرمایه‌گذاران: ثبات، فساد، مالیات، تورم، جنگ
	var inflation_rate: float = float(econ.get("inflation", 0.08))
	var conf_drift: float = (float(pol.get("stability", 0.6)) - 0.6) * 0.5 - float(pol.get("corruption", 0.3)) * 0.6 - absf(float(econ.get("tax_rate", 0.2)) - 0.2) * 0.4 - inflation_rate * 0.9
	cycle["confidence"] = clampf(float(cycle["confidence"]) + conf_drift * 0.02 + (50.0 - float(cycle["confidence"])) * 0.004, 5.0, 95.0)
	# شمارش معکوس فاز؛ هنگام تغییر، فاز تازه با وزن دترمینستیک انتخاب می‌شود
	cycle["months_left"] = float(cycle["months_left"]) - 1.0 / 30.0
	if float(cycle["months_left"]) <= 0.0:
		var conf := float(cycle["confidence"])
		var weights := {"boom": 0.12 + conf / 100.0 * 0.22, "growth": 0.34, "stagnation": 0.30, "recession": 0.12 + (50.0 - conf) / 100.0 * 0.24}
		var total_w := 0.0
		for w in weights.values():
			total_w += float(w)
		var roll: float = Deterministic.next_range(0.0, total_w)
		var new_phase := "growth"
		for ph in weights.keys():
			roll -= float(weights[ph])
			if roll <= 0.0:
				new_phase = ph
				break
		if new_phase != str(cycle["phase"]):
			var old_phase: String = str(cycle["phase"])
			cycle["phase"] = new_phase
			var phase_msg: String = String({"boom": "🔥 رونق اقتصادی! سرمایه‌گذاری‌ها جهش کرد و بازارها در اوج‌اند", "growth": "📈 رشد پایدار اقتصادی ادامه دارد", "stagnation": "📉 رکود خفیف: رشد اقتصادی متوقف شد و سرمایه‌گذاران محتاط‌اند", "recession": "🛑 رکود عمیق! بیکاری و ناامیدی اقتصادی در حال گسترش است"}.get(new_phase, ""))
			events.append({"type": "business_cycle", "from": old_phase, "to": new_phase, "message": phase_msg})
		cycle["months_left"] = float(Deterministic.next_int_range(4, 10))
	econ["cycle"] = cycle

	# ==================== الف) تولید ناخالص داخلی - مدل رشد عمیق ====================
	var growth_base = econ.get("growth_rate", 0.02)
	var infra_q = infra.get("quality", 0.55)
	var infra_capacity = infra.get("capacity", 0.60)
	var workforce = pop.get("workforce", 55_000_000.0)
	var happiness = pop.get("happiness", 0.60)
	var participation = pop.get("participation_rate", 0.65)
	var tech_ind = tech.get("branches", {}).get("صنعت", 0.20)
	var tech_digital = tech.get("branches", {}).get("دیجیتال", 0.20)
	var stability = pol.get("stability", 0.60)
	var trust = pol.get("trust", 0.55)
	var corruption = pol.get("corruption", 0.30)
	var energy_crisis = resources.get("energy_crisis", false)
	var food_crisis = resources.get("food_crisis", false)
	var is_at_war = not world.get("wars", {}).is_empty()
	var mobilization = mil.get("mobilization", {}).get("level", 0)
	var war_economy = mil.get("mobilization", {}).get("war_economy", 0.0)

	# اثرات زیرساخت - هر ۱۰٪ کیفیت = ۰.۵٪ رشد (۳.۱۵.۴) + گلوگاه
	var infra_effect = (infra_q - 0.5) * 0.02 + (infra_capacity - 0.6) * 0.01
	# نیروی کار - شادی + مشارکت + مهارت + سلامت
	var skill_avg = state.get("citizens_detail", {}).get("skill_avg", 0.55) if state.has("citizens_detail") else 0.55
	var health_q = state.get("health", {}).get("quality", 0.60)
	var workforce_effect = (happiness - 0.5) * 0.02 + (participation - 0.65) * 0.01 + (skill_avg - 0.5)*0.015 + (health_q - 0.5)*0.01
	# فناوری
	var tech_effect = tech_ind * 0.02 + tech_digital * 0.015
	# ثبات و اعتماد
	var stability_effect = (stability - 0.5) * 0.03 + (trust - 0.5)*0.01
	# بحران انرژی و غذا
	var energy_penalty = (-0.05 * float(BalanceConfig.get_value("resources.energy_crisis_factor", 0.5))) if energy_crisis else 0.0
	var food_penalty = -0.018 if food_crisis else 0.0
	# اثر جنگ - بسیج جزئی +۱٪ رشد کینزی کوتاه‌مدت اما جنگ تمام‌عیار -۲٪ به خاطر نابودی سرمایه
	var war_effect = 0.0
	if is_at_war:
		if mobilization == 2: war_effect = 0.008 # بسیج جزئی - تحریک تقاضا
		elif mobilization == 3: war_effect = -0.005
		elif mobilization >= 4: war_effect = -0.018 # جنگ تمام‌عیار - نابودی
		war_effect -= float(mil.get("war_exhaustion",0.0))*0.015
	# تحریم
	var sanctions = state.get("diplomacy", {}).get("sanctions", []).size()
	var sanction_penalty = sanctions * 0.003

	# پتانسیل ساختاری از عوامل عرضه؛ جناح نوسان (جنگ، بحران انرژی/غذا، تحریم، چرخه) فقط بر رشد امروز
	var growth_potential: float = clamp(0.02 + infra_effect + workforce_effect + tech_effect + stability_effect, -0.05, 0.12)
	# حالت موتوم رشد با بازگشت میانگین ۵٪/روز به پتانسیل — رشد دیروز دیگر خودکار بر امروز سوار نمی‌شود
	# (رفع قفل‌شدن رشد روی سقف ۱۰٪ در شبیه‌سازی بلندمدت؛ کشور پیش‌فرض قرار نیست چین شود)
	var growth_smoothed: float = clamp(growth_base * 0.95 + growth_potential * 0.05, -0.10, 0.12)
	var real_growth = clamp(growth_smoothed + energy_penalty + food_penalty + war_effect - sanction_penalty + cycle_effect, -0.08, 0.10)

	var old_gdp = econ.get("gdp", 500e9)
	econ["gdp"] *= (1.0 + real_growth / 365.0)
	# کانال مالک-یکتا: جمع نرخ‌های سالانهٔ بخش‌ها (بازنویسی‌شده توسط ناشران) با سقف تکی/کلی
	var boost_total: float = 0.0
	for boost_key in econ.get("sector_boosts", {}).keys():
		boost_total += clampf(float(econ["sector_boosts"][boost_key]), -SECTOR_BOOST_MAX, SECTOR_BOOST_MAX)
	boost_total = clampf(boost_total, -SECTOR_BOOSTS_CAP, SECTOR_BOOSTS_CAP)
	econ["gdp"] *= (1.0 + boost_total / 365.0)
	econ["sector_boosts_total"] = boost_total
	econ["gdp"] = max(econ["gdp"], 10_000_000_000.0)
	econ["gdp_per_capita"] = econ["gdp"] / max(pop.get("total",85_000_000.0), 1.0)
	econ["growth_rate"] = growth_smoothed
	econ["real_growth"] = real_growth
	# بیکاری با فاز چرخه حرکت می‌کند (رونق اشتغال‌زا، رکود بیکارکننده)
	var unemp: float = float(econ.get("unemployment", 0.08))
	# کشش به نرخ طبیعی بیکاری — چرخه دیگر بیکاری را ابداً صفر/سقف نمی‌کند.
	# ناپایایی مهارت (بینشِ مدلِ حذف‌شدهٔ رفاه، قانون ۶: حفظ اثر طراحی) NAIRU را از ۶٪ بالا می‌برد؛
	# با skill_match پیش‌فرض ۰٫۶۰ نرخ تعادلی ≈ ۹٫۲٪ است (نزدیک الگوی کشور درحال‌توسعه).
	var skill_match_u: float = clampf(float(state.get("education", {}).get("skill_match", 0.60)), 0.0, 1.0)
	var nairu: float = 0.06 + (1.0 - skill_match_u) * 0.08
	var unemp_drift: float = (nairu - unemp) * 0.0003
	# قانون اوکن: رشد بالاتر از روند ۲٪ بیکاری را می‌کاهد (تصحیح مقیاس روزانه ÷۳۰)
	var okun: float = (real_growth - 0.02) * -0.0008 / 30.0
	econ["unemployment"] = clampf(unemp + unemp_drift + okun, 0.02, 0.30)

	# ==================== ب) درآمد دولت - مالیه عمومی عمیق ====================
	var monthly_gdp = econ["gdp"] / 12.0
	var tax_rate = econ.get("tax_rate", 0.20)
	# درآمد مالیاتی - نرخ * پایه * کارآمدی وصول + نفت
	var tax_efficiency = 0.75 + (1.0 - corruption)*0.2 + infra_q*0.05 # فساد و زیرساخت دیجیتال اثر
	var tax_revenue = tax_rate * monthly_gdp * tax_efficiency

	# درآمد منابع — نفت و گاز و معدن (بازرسی مالی بلندمدت ۱۴۰۵)
	# دو اصلاح واقع‌گرایانه روی فرمول ثابتِ قبلی:
	#  الف) اتصال به بازار جهانی کالا: تا قبل از این قیمت ثابتِ فرضی جا مانده بود
	#     (متغیر مردهٔ oil_price = 82 که هرگز خوانده نمی‌شد) و چرخه/شوک قیمتِ
	#     commodity_manager هرگز به خزانه نمی‌رسید؛ حالا سهم نفت/گاز با نسبت قیمت
	#     زنده به پایه (۷۵ دلار / ۳٫۲) تنفس می‌کند — بودجهٔ نفتی واقعاً رانتی است.
	#  ب) شاخص بلندمدت قیمت منابع (resource_price_index): فرمول قبلی ثابت بود و با
	#     سه‌برابر شدن GDP در افق ۳۰ ساله سهم درآمد منابع از خزانه آب می‌رفت — ریشهٔ
	#     فرسایش آرام بودجهٔ بهداشت (health_q: ۰٫۶۱→۰٫۴۹ در آینه). در بلندمدت قیمت
	#     اسمی کالاها با رشد اسمی اقتصاد هم‌پاست؛ شاخص به نسبت GDP/مبنا با ثابت
	#     زمانی ~۴ سال تطبیق می‌یابد (کف ۰٫۵ / سقف ۳٫۰ — محدودهٔ واقع‌بینانهٔ رانت).
	# مبنای درآمد = ظرفیت استخراج پایدار (۸۰/۷۰)، نه انبارهٔ نوسانی: انبارهٔ نفت/گاز
	# انبارهٔ مصرف داخلی است (زمستان آن را می‌خورد، محاصره خالی و واردات اضطراری پر
	# می‌کند). درآمد صادراتی خزانه باید به برداشت مدیریت‌شده گره بخورد، نه مورد:
	#  • کمبود انباره (زمستان/محاصره) → درآمد واقعاً می‌افتد (minf فعال — مانند قبل)؛
	#  • مازاد انباره (واردات اضطراری +۱۵ یا اشباع تدریجی به سقف ظرفیت ۱۵۰) → دیگر
	#    درآمد صادراتی جعلی تولید نمی‌کند (قبلاً «واردات گاز» رانت خزانه می‌ساخت و
	#    موتور تا ۲× از مبنای کالیبرهٔ آینه دور می‌شد).
	var oil_inventory = minf(float(resources.get("inventory",{}).get("نفت",80.0)), 80.0)
	var gas_inventory = minf(float(resources.get("inventory",{}).get("گاز",70.0)), 70.0)
	var com_prices: Dictionary = state.get("commodities", {}).get("prices", {})
	# oil_price_bonus: نرخ اوپک از org_manager (۱٫۱۰ عضو / ۱٫۰ غیرعضو) — قیمت محقق‌شده
	var oil_ratio = clampf(float(com_prices.get("نفت", 75.0)) / 75.0 * float(econ.get("oil_price_bonus", 1.0)), 0.40, 2.40)
	var gas_ratio = clampf(float(com_prices.get("گاز", 3.2)) / 3.2, 0.375, 2.50)
	if float(econ.get("gdp_baseline", 0.0)) <= 0.0:
		econ["gdp_baseline"] = float(econ.get("gdp", 500_000_000_000.0))
	var rpi_target = clampf(float(econ.get("gdp", 500_000_000_000.0)) / max(float(econ["gdp_baseline"]), 1e9), 0.50, 3.00)
	var rpi_prev = float(econ.get("resource_price_index", 1.0))
	econ["resource_price_index"] = clampf(rpi_prev + (rpi_target - rpi_prev) * 0.02 / 30.0, 0.50, 3.00)
	var resource_revenue = (oil_inventory * 120_000_000.0 * oil_ratio + gas_inventory * 60_000_000.0 * gas_ratio) * float(econ["resource_price_index"])

	# درآمد گمرک و تجارت — واردات سالانه × تعرفه × کارآمدی گمرک → نرخ ماهانه
	# (بازرسی تراز پرداخت‌ها: ternary قبلی باگ‌دار بود و عملاً ۰٫۶۴٪ واردات می‌داد —
	#  چون tariff_rate در دیکشنری trade است نه economy — یعنی ~۱۴ برابر کمتر از طراحی)
	var customs_revenue = trade.get("imports",70e9) / 12.0 * float(trade.get("tariff_rate",0.15)) * float(trade.get("customs_efficiency",0.60))

	# درآمد خلق پول (سینیوریج) - بانک مرکزی
	var seigniorage = central_bank.get("money_supply",1.0) * 0.005 * monthly_gdp

	# درآمد کل
	# کانال‌های نرخ ماهانهٔ سیستم‌های همکار (بازرسی مالکیت بودجه): مالیات حواله‌های دیاسپورا
	# (migration) و زیان قاچاق سوخت (fuel_stations) — نویسهٔ مستقیم‌شان روی این سطح مرده بود.
	var remittance_tax = float(econ.get("remittance_tax_monthly", 0.0))
	var smuggling_loss = float(econ.get("fuel_smuggling_loss_monthly", 0.0))
	# کانال‌های بیشتر (بازرسی کلید یتیم ۱۴۰۵): عوارض ترانزیت (transit) و درآمد رویالتی/مالکیت فکری
	# (intellectual_property) — هر دو قبلاً محاسبه و رها می‌شدند و به خزانه نمی‌رسیدند.
	var transit_fees = float(econ.get("transit_revenue_monthly", 0.0))
	var royalty_fees = float(econ.get("royalty_revenue_monthly", 0.0))
	# کانال‌های درآمدی ماهانهٔ بخش‌ها (بازرسی ۱۴۰۵ — دور هشتم): قبلاً مالیات کربن
	# و مالیات عایدی سرمایه به‌جای خزانه، بدهی را خاموش کم می‌کردند (و یکی جمعی فانتوم
	# روی revenue می‌نوشت که روز بعد پاک می‌شد). (دور یازدهم) «درآمد اصلاح قیمت سوخت»
	# حذف شد: با هزینهٔ واقعی یارانهٔ سوخت در کانال policy_costs ادغام شد — یارانهٔ
	# رایگان و پاداش سه‌گانهٔ اصلاح مرد.
	var carbon_tax = float(econ.get("carbon_tax_monthly", 0.0))
	var stock_gains = float(econ.get("stock_gains_monthly", 0.0))
	econ["government_revenue"] = tax_revenue + resource_revenue/12.0 + customs_revenue + remittance_tax - smuggling_loss + transit_fees + royalty_fees + carbon_tax + stock_gains + seigniorage*0.1
	var corruption_loss = corruption * 0.06 + float(private_sector.get("informal_economy",0.25))*0.08
	econ["government_revenue"] *= (1.0 - corruption_loss)
	econ["government_revenue"] = max(econ["government_revenue"], 1_000_000_000.0)
	# کمک خارجی به خزانه (بازرسی ۱۴۰۵ — دور دوازدهم): این واریز قبلاً پایین‌تر از محاسبهٔ
	# کسری/بدهی/بدهی-روزانه انجام می‌شد و چون این سیستم روزانه است و درآمد هر روز از نو
	# ساخته می‌شود، رقم کمک همان روز پاک می‌گشت — کانال فقط در UI نفس می‌کشید و به
	# خزانه نمی‌رسید. حالا در مبدأ به پایهٔ درآمد اضافه می‌شود: بودجهٔ ردیفی آن را خرج
	# می‌کند و مابقی‌اش کسری/بدهی را کم می‌کند (نرخ روزانه × ۳۰ = سهم ماهانه).
	econ["government_revenue"] += float(econ.get("aid_inflow_daily", 0.0)) * 30.0

	# ==================== ج) هزینه و بودجه - ۱۰ ردیف ====================
	var budget_alloc = econ.get("budget_allocations", {})
	var total_alloc = 0.0
	for v in budget_alloc.values(): total_alloc += v
	# نرمالایز اگر جمع ≠ ۱
	if abs(total_alloc - 1.0) > 0.01:
		for k in budget_alloc.keys():
			budget_alloc[k] = float(budget_alloc[k]) / total_alloc

	# هزینه هر بخش - واقع‌گرایی: هزینه‌کرد = درآمد منهای سهمیه ذخیره (تصمیم بازیکن)
	# قبلاً هزینه‌کرد از درآمد مشتق می‌شد و سهمیه ذخیره فقط نصف‌شمرده می‌شد؛
	# حالا بازیکن با ذخیره واقعاً سیاست احتیاط/انبساط مالی را کنترل می‌کند
	var saving_share: float = float(budget_alloc.get("ذخیره", 0.15))
	var spending = econ["government_revenue"] * (1.0 - saving_share) * (2.2 if is_at_war else 1.0) # فشار جنگ: دو برابر
	# ظرف بودجهٔ اختیاری (بازرسی ۱۴۰۵ — دور دوازدهم): همهٔ سیستم‌ها بودجهٔ ردیفی‌شان را
	# «سهم ردیف × government_spending» می‌خوانند. چون هزینه‌های قانونی مداوم (یارانه‌ها،
	# سهم صندوق بازنشستگی/کهنه‌سربازان)، هزینه‌های یک‌بارمصرف و اضافهٔ جنگی بعداً به
	# spending اضافه می‌شوند، خواندن از جمع کل باعث می‌شد یارانهٔ سوخت، ردیف‌های
	# اختیاری بهداشت/آموزش/رفاه را هم ببادد (۱۲٪+ تورم بودجه‌ای فانتوم؛ در آینهٔ
	# sim_longrun سلامت خط پایه از سال ۷ به سقف ۰٫۹۵ می‌چسبید و اثر سیاست مرده بود).
	# fix: ردیف‌های اختیاری فقط از این ظرف پایه تغذیه می‌شوند؛ government_spending
	# جمع واقعی کل هزینه‌کرد دولت می‌ماند (کسری/بدهی/نمایش مالی).
	econ["government_spend_base"] = spending

	# هزینه جنگی اضافی - ۰.۲ تا ۰.۵٪ GDP ماهانه (واحد اصلاح شد: قبلاً جریان روزانه ÷365 بود
	# و وارد نرخ ماهانه می‌شد، یعنی ۳۰ برابر ضعیف‌تر از طراحی — جنگ تقریباً رایگان بود!)
	var war_spending_extra = 0.0
	if is_at_war:
		war_spending_extra = econ["gdp"] * (0.002 + mobilization*0.001 + float(mil.get("war_exhaustion",0.0))*0.001) / 12.0
		spending += war_spending_extra
		econ["war_spending"] = war_spending_extra  # نرخ ماهانه — هماهنگ با قرارداد کانال‌های بودجه
	else:
		econ["war_spending"] = 0.0

	# کانال هزینه اقدامات بازیکن و برنامه‌های مدیران (بازرسی واحد ۱۴۰۵): مبالغ یک‌بارمصرف
	# قبلاً در یک تیک روزانه بلع می‌شدند و چون spending نرخ «ماهانه» است، بدهی فقط
	# ~۱/۳۰ مبلغ واقعی را حس می‌کرد (برنامهٔ ۲ میلیارد دلاری عملاً ۶۶ میلیون هزینه داشت!).
	# حالا مبالغ به انبارهٔ oneoff_spending_pool می‌ریزند و در سراسر ماه مستهلک می‌شوند —
	# بدهی کل مبلغ برنامه را می‌بیند و نمایش ماهانه هم لرزش تیک‌وار ندارد.
	var dpm: float = max(float(BalanceConfig.get_value("simulation.days_per_month", 30)), 1.0)
	var oneoff_pool: float = float(econ.get("oneoff_spending_pool", 0.0)) + float(econ.get("extra_spending_daily", 0.0))
	econ["extra_spending_daily"] = 0.0
	var oneoff_month: float = oneoff_pool / dpm
	econ["oneoff_spending_monthly"] = oneoff_month   # برای نمایش UI و تحلیل بودجه
	spending += oneoff_month
	econ["oneoff_spending_pool"] = max(oneoff_pool - oneoff_month, 0.0)
	# کانال هزینهٔ سیاست‌های فعال (بازرسی ۱۴۰۵): نرخ ماهانه که policy_manager انتشار
	# می‌دهد؛ صفر نمی‌شود چون نرخِ پایدار است، نه انباشتگر یک‌بارمصرف. منفی = صرفه‌جویی.
	spending += float(econ.get("policy_spending_monthly", 0.0))
	# کانال چندناشری هزینه‌های بخشی مداوم (بازرسی ۱۴۰۵ — دور هشتم): مدیران بخش
	# (انرژی/فضا/…) نرخ ماهانهٔ خود را در دیکشنری policy_costs با کلید فارسی
	# بازنویسی می‌کنند (بیکار = ۰)؛ مالک این‌جا جمع و به هزینه اضافه می‌کند —
	# دیگر هزینهٔ مداوم مستقیم روی بدهی شارژ نمی‌شود (مجاری بودجه: کسری دیده می‌شود).
	var pc_total := 0.0
	for _pk in econ.get("policy_costs", {}).keys():
		pc_total += float(econ["policy_costs"][_pk])
	econ["policy_costs_total"] = pc_total
	spending += pc_total
	econ["government_spending"] = spending
	econ["budget_allocations"] = budget_alloc

	# ==================== د) کسری، بدهی، اوراق جنگی ====================
	var days_in_month = max(float(BalanceConfig.get_value("simulation.days_per_month", 30)), 1.0)
	var surplus = econ["government_revenue"] - econ["government_spending"]
	econ["deficit"] = max(-surplus, 0.0)
	econ["surplus"] = max(surplus, 0.0)

	# نرخ مؤثر سود بدهی: ۶۰٪ نرخ سیاستی جاری + ۴۰٪ کوپن قدیمی بدهی انباشته
	var legacy_coupon = float(BalanceConfig.get_value("economy.debt_interest", 0.12))
	var policy_rate = float(central_bank.get("interest_rate", legacy_coupon))
	var interest_rate = policy_rate * 0.6 + legacy_coupon * 0.4
	var debt_interest = econ["national_debt"] * interest_rate / 365.0
	econ["national_debt"] = max(econ["national_debt"] - surplus / days_in_month + debt_interest, 0.0)
	econ["debt_to_gdp"] = econ["national_debt"] / max(econ["gdp"], 1.0)
	econ["debt_interest_daily"] = debt_interest

	# اوراق قرضه جنگی
	var war_bonds = econ.get("war_bonds", 0.0)
	if is_at_war and tick % 30 == 0:
		var bond_issue = econ["gdp"] * 0.015 * (0.5 + mobilization*0.1) / 12.0
		war_bonds += bond_issue
		econ["national_debt"] += bond_issue*0.6 # ۶۰٪ بدهی دولت، ۴۰٪ مردم
		econ["war_bonds"] = war_bonds
		if Deterministic.chance(0.03):
			events.append({"type":"war_bonds_issued","amount": bond_issue, "message":"انتشار اوراق جنگی %.1f میلیارد - مردم مشارکت کردند" % (bond_issue/1e9)})

	# سقف بدهی - ۲۰۰٪ GDP + جنگی تا ۲۵۰٪
	var debt_ceiling = float(BalanceConfig.get_value("economy.debt_ceiling", 2.0)) + (0.5 if is_at_war else 0.0)
	if econ["debt_to_gdp"] > debt_ceiling:
		events.append({"type":"debt_crisis","debt_ratio": econ["debt_to_gdp"], "ceiling": debt_ceiling, "message":"بحران بدهی - نسبت بدهی %.0f٪ از سقف %.0f٪ گذشت" % [econ["debt_to_gdp"]*100.0, debt_ceiling*100.0]})
		pol["stability"] = clamp(float(pol.get("stability",0.60)) - 0.015, 0.05, 0.95)
		pol["trust"] = clamp(float(pol.get("trust",0.55)) - 0.025, 0.05, 0.95)

	# ==================== ه) تورم، بیکاری، دستمزد - مدل ماهانه ====================
	var money_supply = central_bank.get("money_supply", 1.0)
	var money_growth = central_bank.get("money_growth", 0.02) if central_bank.has("money_growth") else 0.02

	# تورم - پول + تقاضا + هزینه + جنگ + تحریم + انتظارات
	var demand_pull = real_growth * 0.5
	var cost_push = (0.02 if energy_penalty < 0 else 0.0) + (0.01 if food_penalty < 0 else 0.0)
	var war_push = war_economy*0.03 + mobilization*0.005
	var sanction_push = sanction_penalty*0.5
	var inflation_change = ( (money_supply-1.0)*0.010 + demand_pull*0.008 + cost_push + war_push + sanction_push - 0.0015) / days_in_month
	# لنگر هدف تورمی بانک مرکزی (اصلاح آینه بلندمدت: ضریب ۰٫۰۲ → ۰٫۱۲).
	# با ۰٫۰۲ (τ≈۴ سال) جمله ثابت −۰٫۰۰۱۵ لنگر را می‌شکست و تورم طی ~۸ سال به زیر صفر
	# می‌لغزید (دیفلشن مزمن). با ۰٫۱۲ (τ≈۸ ماه) هدف تورمی جاذب واقعی است و تعادل ≈ ۴٪ می‌ماند.
	var inflation_target_cb: float = float(central_bank.get("inflation_target", 0.05))
	econ["inflation"] += inflation_change + (inflation_target_cb - econ["inflation"]) * 0.12 / days_in_month
	econ["inflation"] = clamp(econ["inflation"], -0.03, 0.60)

	# منحنی فیلیپس + انتظارات تورمی
	var unemployment = econ.get("unemployment", 0.08)
	if unemployment < 0.04:
		econ["inflation"] += 0.0015 / days_in_month # بیکاری خیلی کم = فشار دستمزد (ملایم)
	elif unemployment > 0.12:
		econ["inflation"] -= 0.004 / days_in_month

	# بیکاری - قانون اوکان + بسیج جنگی
	# توجه: real_growth نرخ سالانه است؛ همه اجزا باید به مقیاس روزانه تبدیل شوند (تقسیم بر ۳۶۵)
	var okun_daily = -real_growth * 0.5 / 365.0
	var mobilization_employment = mobilization*0.015 / 365.0 # بسیج اشتغال ایجاد می‌کند (ارتش)
	var tech_unemployment = (tech_digital*0.005 - tech_ind*0.003) / 365.0
	econ["unemployment"] += (okun_daily - mobilization_employment + tech_unemployment + Deterministic.next_range(-0.0006,0.0006)) / days_in_month
	econ["unemployment"] = clamp(econ["unemployment"], 0.015, 0.40)

	# دستمزد و بهره‌وری
	var avg_wage = econ.get("avg_wage", 4000.0)
	var productivity = state.get("workforce_detail",{}).get("productivity",0.60) if state.has("workforce_detail") else 0.60
	avg_wage *= (1.0 + (real_growth*0.7 + econ["inflation"]*0.5 + (productivity-0.6)*0.02)/365.0)
	econ["avg_wage"] = avg_wage

	# ==================== و) تجارت، تراز، جیره‌بندی ====================
	# (بازرسی تراز پرداخت‌ها) صادرات/واردات/تراز از این پس مالکیت یکتای trade_system است
	# (مدل «سهم هدف از GDP + بازگشت») — اهرم‌های رشد/تحریم/محاصره/جنگ به آن منتقل شد.
	# این سیستم فقط trade را می‌خواند (گمرک و هشدارها) و دیگر نمی‌نویسد؛ پیش‌تر نویسندگی
	# موازی این‌جا باعث رشد دوگانهٔ روزانهٔ صادرات در کنار لایهٔ دوم trade_system می‌شد.

	# جیره‌بندی - در جنگ تمام‌عیار
	var rationing = mil.get("mobilization",{}).get("rationing",false)
	econ["rationing_level"] = 0.60 if rationing else 0.0
	if rationing:
		# بازار سیاه
		var black_market = state.get("war_economy_detail",{}).get("black_market",0.10) if state.has("war_economy_detail") else mil.get("war_economy_detail",{}).get("black_market",0.10)
		econ["black_market_size"] = black_market * econ["gdp"] * 0.1
		if Deterministic.chance(0.012):
			events.append({"type":"black_market_growth","size": econ["black_market_size"], "message":"بازار سیاه رونق گرفت - جیره‌بندی"})

	# ── رویدادهای کانال GDP (بازرسی ۱۴۰۵د): تغییر رژیمِ کانال برای بازیکن روایت شود.
	# فقط جهش/فرود هم‌جهت در پنجرهٔ [۰٫۷٪، ۱٫۵٪] هر ۳ روز یک بار — عبور صفر یا تغییر
	# بزرگ‌تر (شوک/تحریم) رویدادهای اختصاصی خودشان را دارند و اسپم نمی‌شود.
	if tick % 3 == 0:
		var prev_boost: float = float(econ.get("_sb_prev_total", 0.0))
		var boost_jump: float = absf(boost_total - prev_boost)
		if prev_boost * boost_total >= 0.0 and boost_jump >= 0.007 and boost_jump <= 0.015:
			var drive_key := ""
			var drive_val := 0.0
			for bk in econ.get("sector_boosts", {}).keys():
				var bv: float = float(econ["sector_boosts"][bk])
				if absf(bv) > absf(drive_val):
					drive_val = bv
					drive_key = str(bk)
			var drive_fa := "جهش محرک بخش‌ها" if boost_total > prev_boost else "فرود محرک بخش‌ها"
			events.append({"type": "sector_boost_drive",
				"message": "📊 %s: کانال GDP به %.1f٪/سال رسید (بزرگ‌ترین سهم‌دهنده: %s)"
					% [drive_fa, boost_total * 100.0, drive_key]})
		econ["_sb_prev_total"] = boost_total
		state["economy"] = econ

	# ==================== ز) اقتصاد سایه، فساد، نابرابری ====================
	var gini = welfare.get("gini",0.38)
	var poverty = welfare.get("poverty",0.15)
	# فساد اثر بر GDP - هر ۱۰٪ فساد = ۰.۵٪ رشد کمتر (مطالعات)
	var corruption_drag = corruption*0.05
	econ["gdp"] *= (1.0 - corruption_drag/365.0/10.0)

	# نابرابری - رشد اگر نابرابری خیلی بالا باشد کند می‌شود (فقر تقاضا کم)
	if gini > 0.45:
		econ["gdp"] *= (1.0 - (gini-0.45)*0.01/365.0)

	# ==================== رویدادهای اقتصادی - عمیق ====================
	if Deterministic.chance(0.012):
		if econ["inflation"] > 0.20:
			events.append({"type":"hyperinflation_risk","inflation": econ["inflation"], "message":"خطر ابرتورم - تورم %.0f٪" % (econ["inflation"]*100.0)})
			central_bank["money_supply"] = float(central_bank.get("money_supply",1.0)) * 0.99 # سیاست انقباضی خودکار
		if econ["unemployment"] > 0.18:
			events.append({"type":"unemployment_crisis","rate": econ["unemployment"], "message":"بحران بیکاری %.0f٪ - اعتراض کارگری" % (econ["unemployment"]*100.0)})
		if econ["debt_to_gdp"] > 1.2:
			events.append({"type":"debt_warning","ratio": econ["debt_to_gdp"], "message":"هشدار بدهی - %.0f٪ GDP" % (econ["debt_to_gdp"]*100.0)})
		if trade["balance"] < -20e9:
			events.append({"type":"trade_deficit_warning","balance": trade["balance"], "message":"کسری تجاری سنگین - وابستگی به واردات"})

	if is_at_war and Deterministic.chance(0.015):
		events.append({"type":"war_economy_report","war_spending": econ.get("war_spending",0.0), "mobilization": mobilization, "message":"اقتصاد جنگی - %.0f٪ GDP صرف جنگ" % (war_economy*100.0)})

	if rationing and Deterministic.chance(0.010):
		events.append({"type":"rationing_effect","level": econ["rationing_level"], "message":"جیره‌بندی کالاهای اساسی - صف نان"})

	# شوک‌های تصادفی - نفت، غذا، بحران مالی
	if Deterministic.chance(0.004):
		var shock_type = ["oil_shock","food_shock","financial_crisis","boom"].pick_random() if false else "oil_shock"
		# دترمینستیک انتخاب
		var r = Deterministic.next_float()
		if r < 0.25:
			events.append({"type":"oil_price_shock","message":"شوک قیمت نفت - جهش ۳۰٪"})
			econ["inflation"] += 0.02
		elif r < 0.50:
			events.append({"type":"food_price_shock","message":"شوک قیمت غذا - خشکسالی جهانی"})
			econ["inflation"] += 0.015
		elif r < 0.75:
			events.append({"type":"financial_crisis","message":"بحران مالی منطقه‌ای - فرار سرمایه"})
			econ["gdp"] *= 0.98
		else:
			events.append({"type":"economic_boom","message":"رونق صادراتی - تقاضای جهانی بالا"})
			econ["gdp"] *= 1.015

	state["economy"] = econ
	state["trade"] = trade
	state["central_bank"] = central_bank
	state["politics"] = pol

	# ── لایه واقع‌گرایانه اختصاصی اقتصاد (جایگزین قالب خودکار) ──
	# اقتصاد غیررسمی، مالیات دولت را می‌نوردد — برآورد آماری (دور ۱۰) به درآمد واقعی وصل شد
	var informal_e = float(state.get("statistics", {}).get("informal_economy_estimate", 0.25))
	# کلید روزانه از نرخ سالانه فرار (سهم غیررسمی × ۳۰٪ شکاف وصولی) روی قاعده درآمد سالانه: ماهانه = سالانه/۱۲، روزانه = /۳۶۰
	econ["informal_tax_loss_daily"] = float(econ.get("government_revenue", 0.0)) * informal_e * 0.30 / 30.0  # کسر ماهانه = درآمد ماهانه × غیررسمی × ۳۰٪؛ کلید = کسر ماهانه ÷ ۳۰
	# کسر ماهانه از درآمد ماهانه (پیشتر فقط ۱/۳۰ مقدار طراحی‌شده کم می‌شد)
	econ["government_revenue"] = float(econ.get("government_revenue", 0.0)) - float(econ["informal_tax_loss_daily"]) * 30.0
	# برق نامطمئن (تأسیسات شهری دور ۱۲) تولید را گران و سرمایه‌گذاری را فراری می‌کند
	var power_rel_e = float(econ.get("power_reliability", 1.0))
	if power_rel_e < 0.75:
		econ["growth_rate"] = clampf(float(econ.get("growth_rate", 0.02)) - (0.75 - power_rel_e) * 0.0015, -0.12, 0.15)
	# (واریز کمک خارجی از این‌جا به مبدأ محاسبهٔ درآمد منتقل شد — دور دوازدهم؛
	# این‌جا بودنش آن را به کانال مرده تبدیل کرده بود.)
	# سرمایه‌گذاری بخش خصوصی از فضای کسب‌وکار (دور ۹) و اعتماد بانکی (دور ۱۵)
	var biz_climate = float(private_sector.get("business_ease", private_sector.get("ease_of_business", 0.55)))
	var bank_trust_e = float(state.get("financial_services", {}).get("trust_banks", 0.60))
	econ["private_investment"] = clampf(float(econ.get("private_investment", 0.15)) * 0.995 + (biz_climate * 0.20 + bank_trust_e * 0.05 + 0.02) * 0.005, 0.03, 0.40)
	# اثر شتاب‌دهنده: سرمایه‌گذاری خصوصی بالاتر از تعادل ۱۵٪ رشد نوبت بعد را بالا/پایین می‌برد
	econ["growth_rate"] = clampf(float(econ.get("growth_rate", 0.02)) + (float(econ["private_investment"]) - 0.15) * 0.003, -0.12, 0.15)
	if informal_e > 0.40 and Deterministic.chance(0.004):
		events.append({"type": "shadow_economy_leak", "message": "دزدی مالیاتی اقتصاد زیرزمینی - خزانه از %d٪ اقتصاد بی‌نصیب است" % int(informal_e * 100.0), "informal": informal_e})
	if power_rel_e < 0.55 and Deterministic.chance(0.005):
		events.append({"type": "power_drag_growth", "message": "قطعی‌های برق، چرخ تولید را کند کرده — رشد در محاصره خاموشی"})
	state["economy"] = econ

	return {"success":true,"state":state,"events":events}
