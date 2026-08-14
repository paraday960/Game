#!/usr/bin/env python3
"""اعتبارسنج قراردادهای موتور — جلوی بازگشت باگ‌های رایج «عمق»های جدید را می‌گیرد.

چک‌ها:
1. هر `simulate_month` باید خروجی `{state, events}` بدهد (نه state خام).
2. هیچ کد شبیه‌سازی نباید از RNG غیردترمینستیک (randi/randf و...) استفاده کند.
3. کلیدهای state نباید توسط چند منیجر با طرح متفاوت ساخته شوند (تداخل مثل waste_policy).
4. هیچ بلوک تکراری «لایه عمیق دوم» نباید وجود داشته باشد (اجرای دوباره معادلات).
"""
import glob, re, sys

FAIL = []

# ── ۱) قرارداد simulate_month ──
def check_simulate_month_contract():
    bad = []
    for f in glob.glob("scripts/**/*.gd", recursive=True):
        src = open(f, encoding="utf-8").read()
        for m in re.finditer(r"func simulate_month\([^)]*\)[^:]*:", src):
            start = m.end()
            end = src.find("\nfunc ", start)
            if end == -1:
                end = len(src)
            body = src[start:end]
            for r in re.findall(r"^\s*return\s+(.+)$", body, re.M):
                r = r.strip()
                if r.startswith("simulate(") or (not r.startswith("{") and "state" in r and "events" not in r):
                    bad.append((f, r))
    if bad:
        for f, r in bad:
            FAIL.append(f"{f}: simulate_month خروجی ناقص دارد → {r}")
    else:
        print("✅ قرارداد simulate_month: همه {state, events} برمی‌گردانند")

# ── ۲) دترمینیسم: RNG خام در کد شبیه‌سازی ──
ALLOWED_RNG = ("scripts/core/deterministic.gd", "scripts/multiplayer/p2p_manager.gd", "scripts/ui/", "scripts/core/ambient_music.gd", "tests/", "tools/")
def check_determinism():
    bad = []
    for f in glob.glob("scripts/**/*.gd", recursive=True):
        if any(f.startswith(a) for a in ALLOWED_RNG):
            continue
        src = open(f, encoding="utf-8").read()
        for pat in ("randi()", "randf()", "randf_range", "randi_range", "randomize()"):
            for i, l in enumerate(src.split("\n"), 1):
                if pat in l and not l.strip().startswith("#"):
                    bad.append((f, i, pat))
    if bad:
        for f, i, p in bad[:10]:
            FAIL.append(f"{f}:{i} RNG غیردترمینستیک → {p}")
    else:
        print("✅ دترمینیسم: هیچ RNG خامی در شبیه‌سازی نیست")

# ── ۳) تداخل کلیدهای state بین منیجرها ──
def check_state_key_collisions():
    owners = {}
    for f in glob.glob("scripts/core/*.gd") + glob.glob("scripts/systems/*.gd"):
        src = open(f, encoding="utf-8").read()
        for m in re.finditer(r'state\["([a-z_]+)"\]\s*=\s*\{', src):
            owners.setdefault(m.group(1), set()).add(f.split("/")[-1])
    conflicts = {k: sorted(v) for k, v in owners.items() if len(v) > 1}
    if conflicts:
        for k, files in conflicts.items():
            FAIL.append(f"تداخل کلید state «{k}»: {files}")
    else:
        print("✅ مالکیت کلیدهای state: بدون تداخل")

# ── ۴) بلوک‌های تکراری «لایه عمیق دوم» ──
def check_duplicate_deep_blocks():
    bad = []
    for f in glob.glob("scripts/systems/*.gd") + glob.glob("scripts/ai/*.gd"):
        src = open(f, encoding="utf-8").read()
        n = len(re.findall(r"^[ \t]*# --- لایه عمیق دوم", src, re.M))
        if n > 1:
            bad.append((f, n))
    if bad:
        for f, n in bad:
            FAIL.append(f"{f}: {n} بلوک «لایه عمیق دوم» — اجرای تکراری معادلات")
    else:
        print("✅ بلوک‌های عمیق: بدون تکرار")

# ── ۵) هر نوع فرمان عمقی باید کیس صریح در _command_queue_key داشته باشد ──
def check_queue_key_coverage():
    cmd_src = open("scripts/core/command.gd", encoding="utf-8").read()
    ui_src = open("scripts/ui/main_ui.gd", encoding="utf-8").read()
    types = re.findall(r'\.new\("([a-z_]+)"', cmd_src)
    missing = []
    mq = re.search(r"func _command_queue_key.*?(?=\nfunc )", ui_src, re.S)
    qk = mq.group(0) if mq else ""
    for t in sorted(set(types)):
        # کیس صریح = برچسب "t": و در ۱۲۰ نویسه بعد یک return (کیس چندخطی مجاز)
        m = re.search(rf'"{t}":', qk)
        if m is None or "return" not in qk[m.end():m.end() + 120]:
            missing.append(t)
    if missing:
        FAIL.append("این نوع فرمان‌ها در _command_queue_key کیس صریح ندارند (دکمه‌های یک‌بار در نوبت غیرفعال نمی‌شوند): " + ", ".join(missing))
    else:
        print("✅ پوشش کلید صف تصمیم: همه نوع فرمان‌ها کیس صریح دارند")

# ── ۵) قرارداد نویز متقارن — راه‌پیمای تصادفی سوگیریدار ممنوع ────────────
# بازرسی واقع‌گرایی ۱۴۰۵: health.vaccination با next_range(-0.001, 0.002) دریفت
# تصادفی ~+۰٫۰۰۰۵ در روز داشت و بی‌توجه به سیاست به سقف می‌چسبید. درمان: واکسیناسیون
# بازگشت‌به‌هدف سیاست‌محور شد و همهٔ «راه‌پیماهای خالص روی سطح پایدار» مرکز-صفر شدند.
NOISE_WALKS = {
    "scripts/systems/health_system.gd": ["vax_target", "next_range(-0.0005, 0.0005)"],
    "scripts/systems/agriculture_system.gd": ["next_range(-0.0015, 0.0015)"],
    "scripts/systems/citizens_system.gd": ["next_range(-0.025, 0.025)"],
    "scripts/systems/culture_system.gd": ["next_range(-0.0025, 0.0025)"],
    "scripts/systems/elections_system.gd": ["next_range(-0.0015, 0.0015)", "next_range(-0.0025, 0.0025)"],
    "scripts/systems/foreign_affairs_system.gd": ["next_range(-0.15, 0.15)"],
    "scripts/systems/security_system.gd": ["next_range(-0.0025, 0.0025)", "next_range(-0.0015, 0.0015)"],
    "scripts/systems/stock_market_system.gd": ["next_range(-0.0015, 0.0015)"],
    "scripts/systems/tourism_system.gd": ["next_range(-0.0025, 0.0025)"],
    "scripts/systems/trade_system.gd": ["next_range(-0.0025, 0.0025)"],
    "scripts/systems/welfare_system.gd": ["next_range(-0.0015, 0.0015)"],
    # سایت‌های سیاست‌محرک (جاروی دوم): نویز مرکز-صفر در کنار جملهٔ سیاستی
    "scripts/systems/central_bank_system.gd": ["next_range(-0.0025, 0.0025)"],
    "scripts/systems/households_system.gd": ["next_range(-0.00045, 0.00045)"],
    "scripts/systems/infrastructure_system.gd": ["next_range(-0.00065, 0.00065)"],
    "scripts/systems/international_orgs_system.gd": ["next_range(-0.00125, 0.00125)"],
    "scripts/systems/migration_system.gd": ["next_range(-2500.0, 2500.0)"],
    "scripts/systems/military_system.gd": ["next_range(-0.065, 0.065)", "next_range(-1.25, 1.25)"],
    "scripts/systems/resources_system.gd": ["next_range(-0.15, 0.15)"],
    "scripts/systems/private_sector_system.gd": ["next_range(-0.015, 0.015)"],
}
# الگوهای سوگیریداری که درمان شدند و نباید برگردند
BIASED_GONE = {
    "scripts/systems/health_system.gd": ["health[\"vaccination\"] + Deterministic.next_range(-0.001, 0.002)"],
}
def check_noise_symmetry():
    for f, pats in sorted(NOISE_WALKS.items()):
        src = open(f, encoding="utf-8").read()
        for pat in pats:
            if pat not in src:
                FAIL.append("الگوی نویز متقارن «%s» در %s یافت نشد" % (pat, f))
    for f, pats in sorted(BIASED_GONE.items()):
        src = open(f, encoding="utf-8").read()
        for pat in pats:
            if pat in src:
                FAIL.append("الگوی نویز سوگیریدار «%s» به %s برگشته" % (pat, f))
    if not FAIL:
        print("✅ قرارداد نویز متقارن: %d سایت راه‌پیمای مرکز-صفر پین شد" % len(NOISE_WALKS))


def check_resource_revenue_basis():
    # بازرسی ۱۴۰۵ (دور هفتم): مبنای درآمد منابع باید «ظرفیت استخراج پایدار» باشد،
    # نه انبارهٔ نوسانی — در غیر این صورت واردات اضطراری گاز (+۱۵) یا اشباع تدریجی
    # انبار به سقف ظرفیت (۱۵۰) رانت صادراتی جعلی می‌سازد و موتور از آینه دور می‌شود.
    src = open("scripts/systems/economy_system.gd", encoding="utf-8").read()
    ok = ('minf(float(resources.get("inventory",{}).get("نفت",80.0)), 80.0)' in src
          and 'minf(float(resources.get("inventory",{}).get("گاز",70.0)), 70.0)' in src)
    if ok:
        print("✅ مبنای درآمد منابع: ظرفیت استخراج پایدار (انباره فقط سمت کمبود اثر دارد)")
    else:
        FAIL.append("مبنای درآمد منابع دوباره به انبارهٔ بی‌سقف گره خورد (واردات→رانت جعلی)")
    # قیمت سوخت داخلی باید به قیمت زندهٔ بازار کالا وصل باشد (نبودن ثابت ۸۲ دلاری)
    fuel = open("scripts/systems/fuel_stations_system.gd", encoding="utf-8").read()
    if 'com_prices_f.get("نفت", 82.0)' in fuel and "var gas_inv" not in fuel:
        print("✅ قیمت پمپ‌بنز به بازار جهانی کالا وصل است و متغیر مردهٔ gas_inv نیست")
    else:
        FAIL.append("قیمت سوخت دوباره ثابت شد یا متغیر مردهٔ gas_inv برگشته است")


def check_strategic_reserves_wiring():
    # بازرسی ۱۴۰۵ (دور نهم): ذخایر راهبردی باید پیش از اعلان بحران تزریق شوند
    # (SPR واقعی: تعویق/جذب شوک) — نه فقط شاخص نمایشیِ بی‌مصرف.
    src = open("scripts/systems/resources_system.gd", encoding="utf-8").read()
    if ('res["strategic_reserves"]["نفت"] = spr_oil - 0.4' in src
            and 'res["strategic_reserves"]["غذا"] = spr_food - 0.5' in src
            and '"spr_release"' in src):
        print("✅ ذخایر راهبردی در آستانهٔ بحران برق/غذا آزاد می‌شوند (SPR واقعی)")
    else:
        FAIL.append("منطق آزادسازی ذخیره راهبردی در آستانهٔ بحران حذف شده")


def check_pension_fund_wiring():
    # بازرسی ۱۴۰۵ (دور دهم): صندوق بازنشستگی باید pay-as-you-go واقعی باشد
    # (تعهدات ∝ سالمندان × درآمد سرانه، منابع = سهم‌برداری + تکمیلی ردیف رفاه).
    # قبل: مستمری ثابت ۵۰۰۰ × میلیون‌ها بازنشسته در هر اجرای هفتگی ⇒ موجودی برای
    # همیشه صفر و بحران فانتوم ۱٪/اجرا. هر بازگشت به مستمری ثابت = باگ واحد.
    src = open("scripts/systems/welfare_system.gd", encoding="utf-8").read()
    if ("retirees\"]" in src and "* 5000.0" in src):
        FAIL.append("مستمری ثابت ۵۰۰۰ برگشته است (باگ واحد صندوق بازنشستگی)")
        return
    ok = ('pc_month' in src and 'contributions_m' in src
          and 'pension_obligations_monthly' in src
          and 'pension_solvency' in src and '"pension_shortfall"' in src)
    if ok:
        print("✅ صندوق بازنشستگی: pay-as-you-go واقعی (تعهدات/منابع/بافر/کسری اجتماعی)")
    else:
        FAIL.append("مدل صندوق بازنشستگی (تعهدات/منابع/کسری) در welfare_system ناقص است")
    # آینهٔ بلندمدت باید همان مدل را بپوشاند (پایش رگرسیون پیری جمعیت)
    mir = open("tests/sim_longrun.py", encoding="utf-8").read()
    if ('pension_solvency' in mir and 'pension_balance' in mir
            and 'elderly_share' in mir):
        print("✅ آینهٔ بلندمدت صندوق بازنشستگی را مدل می‌کند")
    else:
        FAIL.append("آینهٔ sim_longrun مدل صندوق بازنشستگی را ندارد")
    # (دور یازدهم) یک‌سازی دونویسندهٔ pension_pressure: ساختاری در کلید جدا و
    # نمایش/گیت = بیشینهٔ دو منبع؛ بازنویسی شرطی روی کلید مشترک ممنوع
    wm = open("scripts/core/welfare_manager.gd", encoding="utf-8").read()
    dm = open("scripts/core/demographic_manager.gd", encoding="utf-8").read()
    if ('pension_pressure_structural' in dm and 'pension_pressure_structural' in wm
            and 'maxf(pension_pressure_policy,' in wm
            and 'if fund < 0.30:\n\t\twelfare["pension_pressure"]' not in dm):
        print("✅ فشار صندوق: دو منبع (سیاستی/ساختاری) با max تلفیق می‌شوند")
    else:
        FAIL.append("یک‌سازی دونویسندهٔ pension_pressure شکست (بازنویسی شرطی برگشت)")


def check_fuel_subsidy_wiring():
    # بازرسی ۱۴۰۵ (دور دهم): سه باگ سوخت درمان شدند و باید پین شوند —
    # ۱) subsidy_rate باید از سیاست واقعی (fuel_policy.subsidy) خوانده شود،
    #    نه لیترال ۰٫۶۸ (وگرنه اهرم «اصلاح یارانه» به قیمت پمپ نمی‌رسد)؛
    # ۲) قیمت همسایه باید از نفت جهانی/ارز مشتق شود (نه ثابت ۳۰هزار)؛
    # ۳) مالک مدل قاچاق فقط fuel_stations_system است (مدیر گذار ماهانه
    #    state را با فرمول موازی بازنویسی می‌کرد و مدل زنده را خنثی می‌کرد)؛
    # ۴) subsidy_cost یک نویسهٔ مفهومی دارد (+مقداردهی اولیه) — نویسهٔ مرده
    #    دوم (شکاف×مصرف که هر بار بازنویسی می‌شد) برنگردد.
    fuel = open("scripts/systems/fuel_stations_system.gd", encoding="utf-8").read()
    if 'get("subsidy", 0.65)' in fuel and "= 0.68" not in fuel:
        print("✅ نرخ یارانهٔ پمپ به سیاست واقعی fuel_policy.subsidy وصل است")
    else:
        FAIL.append("نرخ یارانهٔ سوخت دوباره سخت‌کد شد (اهرم سیاست قطع است)")
    if "neighbor_price = oil_price" in fuel:
        print("✅ قیمت همسایهٔ قاچاق از نفت جهانی و ارز مشتق می‌شود")
    else:
        FAIL.append("قیمت همسایهٔ قاچاق دوباره ثابت شد")
    if fuel.count('fuel["subsidy_cost"] =') == 2:
        print("✅ subsidy_cost تک‌نویسهٔ مفهومی است (نمایشی، مقیاس دلاری صحیح)")
    else:
        FAIL.append("نویسهٔ مرده/موازی subsidy_cost برگشته است")
    ftm = open("scripts/core/fuel_transition_manager.gd", encoding="utf-8").read()
    if 'fuel_stations["smuggling"] = ' not in ftm and "smuggle_target" not in fuel:
        print("✅ مالکیت مدل قاچاق یکتا است (بازنویسی ماهانهٔ موازی حذف شد)")
    else:
        FAIL.append("مدل موازی قاچاق (بازنویسی state توسط مدیر گذار) برگشته است")


def check_cadence_units_365():
    # بازرسی ۱۴۰۵ (دور یازدهم): قرارداد واحد «تقسیم‌بر ۳۶۵» در سیستم‌های غیرروزانه.
    # سیستم هفتگی ۵ بار در ماه می‌دود (ضریب صحیح سالانه→هر اجرا: ۶/۳۶۵) و ماهانه
    # ۲ بار (۱۵/۳۶۵). ۲۸ سایت پویش شد؛ ۷ سایت روشن‌اثر همین دور اصلاح شدند و
    # بقیه (ضریب تورم/حقوق/فروش مسکن — دریفت کوچک ولی لمس‌شان = جابه‌جایی تعادل)
    # در رجیستری «به‌تأخیرافتاده» پین شدند: تغییر بی‌سروصدا = شکست تست.
    FIXED = {
        "scripts/systems/tourism_system.gd":
            'tourism["revenue"] * 0.1 * 6.0 / 365.0',
        "scripts/systems/space_system.gd":
            "* 1_000_000_000.0 * 15.0 / 365.0",
        "scripts/systems/hospitality_system.gd":
            'hospitality["revenue"] * 0.05 * 15.0 / 365.0',
        "scripts/systems/stock_market_system.gd":
            'stock["foreign_investment"] * 0.01 * 6.0 / 365.0',
        "scripts/systems/heritage_system.gd":
            '* 0.05 * 15.0 / 365.0',
        "scripts/systems/public_transport_system.gd":
            'pt["fleet_age"] += 15.0/365.0',
    }
    # ضربهٔ بازده بورس: دریفت با ۶/۳۶۵ مقیاس می‌شود، نه نویز per-run
    STOCK_DRIFT = '(earnings_growth + interest_effect) * 6.0 / 365.0'
    ok_s = STOCK_DRIFT in open("scripts/systems/stock_market_system.gd",
                               encoding="utf-8").read()
    if ok_s:
        print("✅ بازده بورس: دریفت سالانه با ضریب ۶/۳۶۵ (نویز هفتگی دست‌نخورده)")
    else:
        FAIL.append("ضریب cadence بازده بورس خراب/حذف شد")
    for f, needle in sorted(FIXED.items()):
        if needle in open(f, encoding="utf-8").read():
            print("✅ واحد cadence اصلاح‌شده در %s" % f.split("/")[-1])
        else:
            FAIL.append("سایت cadence اصلاح‌شده در %s پینش شکست: %s" % (f, needle))
    DEFERRED = {
        "scripts/systems/government_buildings_system.gd":
            'gov["maintenance_cost"] *= (1.0 + econ.get("inflation",0.08)/365.0)',
        "scripts/systems/physical_system.gd":
            '* 12.0 / 120000.0 / 365.0',
        "scripts/systems/private_sector_system.gd":
            'priv["investment"] *= (1.0 + priv["investment_growth"]/365.0)',
        "scripts/systems/public_employees_system.gd":
            'emp["salary_avg"] *= (1.0 + wage_growth / 365.0)',
        "scripts/systems/settlements_system.gd":
            '= total_pop * urbanization_rate / 365.0 * urban_attraction',
        "scripts/systems/technology_system.gd":
            'tech["research_points"] += tech["research_rate"] / 365.0',
        "scripts/systems/urban_facilities_system.gd":
            'urban["maintenance_cost"] *= (1.0 + econ.get("inflation",0.08)/365.0)',
        "scripts/systems/financial_services_system.gd":
            'fin["saving_deposits"] *= (1.0 + (growth*0.5 + saving_rate*0.1)/365.0)',
        "scripts/systems/foreign_affairs_system.gd":
            'fa["public_diplomacy_budget"] *= (1.0 + econ.get("growth_rate",0.02)/365.0)',
        "scripts/systems/international_orgs_system.gd":
            'econ["aid_inflow_daily"] = float(intl.get("aid_received", 500_000_000.0)) / 365.0',
        "scripts/systems/political_career_system.gd":
            'career["salaries"] *= (1.0 + inflation * 0.5 / 365.0)',
        "scripts/systems/veterans_system.gd":
            '* retirement_rate / 365.0 * 2.0',
    }
    for f, needle in sorted(DEFERRED.items()):
        if needle not in open(f, encoding="utf-8").read():
            FAIL.append("سایت به‌تأخیرافتادهٔ cadence در %s بی‌سروصدا تغییر کرد "
                        "(رجیستری را آگاهانه به‌روز کن): %s" % (f, needle))
    print("ℹ️ %d سایت cadence به‌تأخیرافتاده در رجیستری پین شد (هر تغییر = بازبینی)"
          % len(DEFERRED))


check_simulate_month_contract()
check_determinism()
check_state_key_collisions()
check_duplicate_deep_blocks()
check_queue_key_coverage()
check_noise_symmetry()
check_resource_revenue_basis()
check_strategic_reserves_wiring()
check_pension_fund_wiring()
check_fuel_subsidy_wiring()
check_cadence_units_365()

if FAIL:
    print("\n❌ ENGINE CONTRACTS FAILED:")
    for x in FAIL:
        print("  -", x)
    sys.exit(1)
print("\n=== ✅ ENGINE CONTRACTS OK ===")
