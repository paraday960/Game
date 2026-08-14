#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""قرارداد مشترک مالکیت یکتای سطح GDP (ممیزی نویسندگان ۱۴۰۵).

ماژول داده/توابع خالص — بدون اثر جانبی هنگام import. هم تست رسمی
(validate_gdp_channel.py) و هم پویشگر برنامه‌ریزی (audit_gdp_writers.py)
از این قرارداد واحد استفاده می‌کنند تا تعریف «مهاجرت» و «بودجه» دو نسخه نشود.

قواعد کلیدی:
- کلید کانال باید فارسی حاوی فضای خالی باشد (هم‌سبک پنج کانال نخست) با حداقل ۷ حرف.
- یک کلید = دقیقاً یک فایل ناشر (مالکیت یکتا)؛ و یک فایل حداکثر دو نویسهٔ مستقیم مجاز دارد.
- الگوی «سطح هدف همگرا» (_gdp_boost) با تعقیب وضعیت مجاز است (قفل C6 در تست رسمی).
"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = os.path.join(ROOT, "scripts")

WRITE_RE = re.compile(r'\["gdp"\]\s*\*?=[^=]')
# فقط gdp_per_capita نادیده گرفته می‌شود. توجه: الگوی قدیمی «gdp_» باعث ماسک شدن
# سایت‌هایی می‌شد که در همان خط به gdp_cost/gdp_growth اشاره داشتند (demographic:72،
# diaspora:54، military_system:498 — در بازرسی ۱۴۰۵ کشف و مهاجرت شدند)؛ WRITE_RE خود
# فقط هدفِ دقیق ["gdp"] را می‌گیرد پس ماسک گسترده لازم نیست (و خطرناک بود).
SKIP_RE = re.compile(r"per_capita")
NOMIN = r'\["gdp"\]\s*[+\-]?\*?=\s*[^\n]*(?:\(1\.0|[+\-]?\*?\s*1\.0|\*\s*0\.9|\*\s*1\.0|[+\-]\s*(?:gdp|float\())'
ARABIC_PERSIAN_KEY_RE = re.compile(r'^[\u0600-\u06FF\u200c0-9\s\(\)\/،\-]{3,}$')

# مالکیت یکتای کلیدهای حساس دیگر: نویسهٔ مستقیم فقط در فایل‌های مجاز.
SINGLE_OWNER_ALLOW = {
    # growth_rate (economy) هر روز توسط economy_system بازنویسی می‌شود؛ نویسهٔ نمایشی
    # دیپلماسی (کاهش ۰٫۰۰۱×gdp_loss) مرده بود و حذف شد. رشد جمعیت (pop) مالک جدا دارد.
    "growth_rate": {"scripts/systems/economy_system.gd", "scripts/systems/population_system.gd"},
}

MIGRATED = {
    "scripts/systems/industry_system.gd": ["بازخورد صنعتی"],
    "scripts/systems/transport_roads_system.gd": ["لجستیک حمل‌ونقل"],
    "scripts/systems/environment_system.gd": ["آلودگی زیست‌محیطی"],
    "scripts/systems/diplomacy_system.gd": ["فشار تحریم‌ها", "دور زدن تحریم"],
    "scripts/core/banking_manager.gd": ["اعتبار بانکی"],
    "scripts/core/fdi_manager.gd": ["سرمایه‌گذاری خارجی"],
    "scripts/core/digital_manager.gd": ["اقتصاد دیجیتال"],
    "scripts/core/mining_manager.gd": ["معدن"],
    "scripts/core/creative_manager.gd": ["اقتصاد خلاق"],
    "scripts/core/blue_economy_manager.gd": ["اقتصاد آبی"],
    "scripts/core/urban_manager.gd": ["توسعه شهری"],
    "scripts/core/agriculture_manager.gd": ["کشاورزی"],
    "scripts/core/care_economy_manager.gd": ["اقتصاد مراقبت"],
    "scripts/core/civic_manager.gd": ["سرمایه اجتماعی"],
    "scripts/core/downstream_energy_manager.gd": ["زنجیرهٔ ارزش انرژی"],
    "scripts/core/basic_industry_manager.gd": ["صنایع بنیادی"],
    "scripts/core/industry_manager.gd": ["سهم شرکت‌های دولتی", "صنعت برگزیده"],
    "scripts/core/insurance_manager.gd": ["صنعت بیمه"],
    "scripts/core/intellectual_property_manager.gd": ["نوآوری و مالکیت فکری"],
    "scripts/core/startup_manager.gd": ["اکوسیستم استارتاپ"],
    "scripts/core/research_manager.gd": ["پژوهش و توسعه"],
    "scripts/core/higher_education_manager.gd": ["آموزش عالی"],
    "scripts/core/food_value_chain_manager.gd": ["زنجیرهٔ غذا"],
    "scripts/core/livestock_manager.gd": ["دام و پروتئین"],
    "scripts/core/rural_manager.gd": ["اقتصاد روستایی"],
    "scripts/core/sports_manager.gd": ["اقتصاد ورزش"],
    "scripts/core/nation_brand_manager.gd": ["برند ملی"],
    "scripts/core/pharma_manager.gd": ["صنعت دارو"],
    "scripts/core/prison_manager.gd": ["حبس و کار اجباری"],
    "scripts/core/pro_sports_manager.gd": ["ورزش حرفه‌ای"],
    "scripts/core/waste_manager.gd": ["اقتصاد چرخه‌ای"],
    "scripts/core/supply_chain_manager.gd": ["زنجیرهٔ تأمین"],
    "scripts/core/judicial_reform_manager.gd": ["اصلاح قضایی"],
    "scripts/core/infrastructure_manager.gd": ["نگهداری زیرساخت"],
    "scripts/core/waste_management_manager.gd": ["بازیافت"],
    "scripts/core/sme_manager.gd": ["بنگاه‌های کوچک"],
    "scripts/core/ai_industry_manager.gd": ["هوش مصنوعی و رباتیک"],
    "scripts/core/textile_manager.gd": ["نساجی"],
    "scripts/core/housing_manager.gd": ["ساخت‌وساز و مسکن"],
    "scripts/core/demographic_manager.gd": ["پنجرهٔ جمعیت"],
    "scripts/core/diaspora_manager.gd": ["حواله‌های دیاسپورا"],
    "scripts/core/labor_manager.gd": ["هزینهٔ حداقل دستمزد"],
    "scripts/systems/military_system.gd": ["هزینهٔ جنگ (فرسایش)"],
    "scripts/systems/interdependency_system.gd": ["ریسک آبشاری شبکه"],
    "scripts/systems/people_system.gd": ["بهره‌وری انسانی"],
    "scripts/systems/statistics_system.gd": ["دقت آمار رسمی"],
}

# ── کانال نرخ ماهانهٔ ورودی ذخایر ارزی (reserve_inflows) ─────────────────
# الگوی مشابه sector_boosts: ناشر بخشی کلید فارسی خودش را با «مبلغ دلاری ماهانه»
# بازنویسی می‌کند (نه انباشت) و central_bank_system به‌عنوان مالک روزانه تسویه می‌کند.
# مقادیر منفی = جریان خروج ارز (فرار سرمایه) — کانال، «جریان خالص» است.
RESERVE_PUBLISHERS = {
    "scripts/core/aerospace_manager.gd": ["خدمات ماهواره‌ای"],
    "scripts/core/aviation_manager.gd": ["هاب هوایی و بار"],
    "scripts/core/health_tourism_manager.gd": ["گردشگری سلامت"],
    "scripts/core/startup_manager.gd": ["صادرات فناوری استارتاپی"],
    "scripts/core/standards_manager.gd": ["صادرات استاندارد"],
    "scripts/core/downstream_energy_manager.gd": ["محصولات پالایشی"],
    "scripts/core/diaspora_manager.gd": ["حواله‌های دیاسپورا"],
    "scripts/core/fdi_manager.gd": ["خروج سرمایه خارجی"],
    # مهاجرت دور هفتم بازرسی ۱۴۰۵: جریان‌های ماهانهٔ مداومِ مستقیم → کانال
    "scripts/core/tourism_manager.gd": ["گردشگری و جهانگردی"],
    "scripts/core/knowledge_economy_manager.gd": ["صادرات دانش‌بنیان"],
    "scripts/core/petrochemical_manager.gd": ["صادرات پتروشیمی"],
    "scripts/core/defense_industry_manager.gd": ["صادرات دفاعی"],
    "scripts/core/pro_sports_manager.gd": ["رویدادها و صادرات ورزشی"],
}
# بودجهٔ pestleٔ نویسههای مستقیم foreign_reserves (غیر از کانال) — فقط کم می‌شود.
RESERVE_BUDGET = {
    "scripts/systems/central_bank_system.gd": 3,      # مالک مخزن (init + تسویه)
    # گذرا/اقدام/هزینه‌کرد مستقیم کیف ارزی (مجاز و پایش‌شده)
    "scripts/core/diaspora_manager.gd": 1,            # اقدام اعتماد‌سازی دیاسپورا
    "scripts/core/dilemma_manager.gd": 1,             # پیامد رویداد انتخابی
    "scripts/core/faction_manager.gd": 1,             # برش بحرانی (آشوب)
    "scripts/core/forex_manager.gd": 1,               # هزینهٔ مداخله ارزی (اقدام)
    "scripts/core/industry_manager.gd": 1,            # درآمد خصوصی‌سازی (اقدام)
    "scripts/core/market_manager.gd": 2,              # خرید/فروش بازار (اقدام)
    "scripts/core/daily_reward_manager.gd": 1,        # پاداش روزانه
    "scripts/core/offline_progress_manager.gd": 1,    # پاداش آفلاین
    "scripts/core/org_manager.gd": 2,                 # هزینهٔ عضویت/اقدام سازمانی
    "scripts/core/world_manager.gd": 2,               # جهان/NPC/جنگ
    "scripts/systems/international_orgs_system.gd": 1,  # حقوق دوره‌ای سازمانی
    # مهاجرت دور ششم/هفتم بازرسی ۱۴۰۵: جریان‌های ماهانهٔ مداوم ارزی به کانال
    # reserve_inflows رفتند؛ این فایل‌ها فقط ناشر کلید فارسی اند (نویسهٔ مستقیم = ۰).
    "scripts/core/tourism_manager.gd": 0,
    "scripts/core/knowledge_economy_manager.gd": 0,
    "scripts/core/petrochemical_manager.gd": 0,
    "scripts/core/defense_industry_manager.gd": 0,
    "scripts/core/pro_sports_manager.gd": 0,
    # کانال موازی oil_income (نویسهٔ خودکار ماهانه روی ذخایر) در بازرسی ۱۴۰۵ حذف شد؛
    # فقط فروش دستی ذخایر کالا (اقدام بازیکن) باقی است.
    "scripts/core/commodity_manager.gd": 1,
    "scripts/core/creative_manager.gd": 2,      # رویداد windfall + اقدام جشنواره (می‌مانند)
    "scripts/core/arms_manager.gd": 1,          # فروش تسلیحات (اقدام)
    "scripts/core/stock_market_manager.gd": 1,  # صندوق تثبیت (اقدام، خروج ارز)
    "scripts/core/shadow_manager.gd": 2,        # سرکوب/کانال سفید (اقدامات)
}

BUDGET = {
    # مالک کانال (روند/کشش‌ها/شوک‌های درون‌سیستمی)
    "scripts/systems/economy_system.gd": 7,
    # فایل‌های مهاجرت‌یافته به کانال (بقایای مجاز)
    "scripts/systems/industry_system.gd": 0,
    "scripts/systems/transport_roads_system.gd": 0,
    "scripts/systems/environment_system.gd": 0,
    "scripts/systems/diplomacy_system.gd": 1,      # سود صلح (رویداد شرطی ×۱۰۰۵)
    "scripts/core/fdi_manager.gd": 0,
    "scripts/core/digital_manager.gd": 0,
    "scripts/core/mining_manager.gd": 0,
    "scripts/core/creative_manager.gd": 0,
    "scripts/core/blue_economy_manager.gd": 0,
    "scripts/core/urban_manager.gd": 0,
    "scripts/core/agriculture_manager.gd": 1,      # خشکسالی (رویداد شانسی)
    "scripts/core/banking_manager.gd": 2,          # فروکش بحران/نجات (رویداد/اقدام)
    "scripts/core/care_economy_manager.gd": 0,
    "scripts/core/civic_manager.gd": 0,
    "scripts/core/downstream_energy_manager.gd": 0,
    "scripts/core/basic_industry_manager.gd": 1,  # رویداد کمبود مصالح (شانسی)
    "scripts/core/industry_manager.gd": 0,
    "scripts/core/insurance_manager.gd": 0,
    "scripts/core/intellectual_property_manager.gd": 0,
    "scripts/core/startup_manager.gd": 0,
    "scripts/core/research_manager.gd": 0,
    "scripts/core/higher_education_manager.gd": 0,
    "scripts/core/food_value_chain_manager.gd": 0,
    "scripts/core/livestock_manager.gd": 0,
    "scripts/core/rural_manager.gd": 0,
    "scripts/core/sports_manager.gd": 0,
    "scripts/core/nation_brand_manager.gd": 0,
    "scripts/core/pharma_manager.gd": 0,
    "scripts/core/prison_manager.gd": 0,
    "scripts/core/pro_sports_manager.gd": 0,
    "scripts/core/waste_manager.gd": 0,
    "scripts/core/supply_chain_manager.gd": 0,
    "scripts/core/judicial_reform_manager.gd": 0,
    "scripts/core/waste_management_manager.gd": 1,  # سایت همگرای _gdp_boost انرژی-زباله
    "scripts/core/sme_manager.gd": 1,              # موج تعطیلی بنگاه‌ها گذرا
    "scripts/core/ai_industry_manager.gd": 1,      # اعتراض به اتوماسیون گذرا
    "scripts/core/textile_manager.gd": 1,          # کمبود ماده اولیه گذرا
    "scripts/core/housing_manager.gd": 1,          # ترکیدن حباب مسکن گذرا
    "scripts/core/infrastructure_manager.gd": 1,   # شکست زیرساخت (رویداد پوسیدگی)
    # الگوی «سطح هدف همگرا» (_gdp_boost): اثر بخش مسیر محدود و خودمهارکننده به سقف
    # سهمش دارد و سپس صفر می‌شود؛ جمعِ بی‌پایان نیست. مستثنی از کانال (پین=۱).
    "scripts/core/aerospace_manager.gd": 1,
    "scripts/core/aviation_manager.gd": 1,
    "scripts/core/defense_industry_manager.gd": 1,
    "scripts/core/ev_industry_manager.gd": 1,
    "scripts/core/health_tourism_manager.gd": 1,
    "scripts/core/knowledge_economy_manager.gd": 1,
    "scripts/core/standards_manager.gd": 1,
    "scripts/core/postal_manager.gd": 1,
    "scripts/core/petrochemical_manager.gd": 1,
    # مختلط/گذرا و جهان/NPC (پایش‌شده)
    "scripts/systems/emergency_system.gd": 1,      # خسارت اضطراری گذرا
    "scripts/systems/intelligence_system.gd": 1,   # ضربهٔ عملیاتی گذرا
    "scripts/systems/map_advanced_system.gd": 1,   # اقدام ساخت‌وساز بازیکن (یک‌باره)
    "scripts/systems/trade_route_warfare_system.gd": 1,  # دزدی دریایی گذرا
    "scripts/core/engine.gd": 2,                   # شوک‌های snapshot جنگی
    "scripts/core/world_manager.gd": 10,           # جهان/NPC + نتیجهٔ جنگ (گذرا)
    "scripts/core/npc_turn_manager.gd": 3,         # رشد NPC
    "scripts/multiplayer/multiplayer_campaign_manager.gd": 1,  # کپی runtime چندنفره
    "scripts/core/leader_manager.gd": 2,           # الحاق/جنگ NPC
    "scripts/core/cyber_manager.gd": 2,            # حملهٔ سایبری گذرا (خود/هدف)
    "scripts/core/intelligence_operation_manager.gd": 1,  # عملیات علیه NPC
    "scripts/core/seasonal_manager.gd": 1,         # محاصرهٔ فصلی گذرا
    "scripts/core/disaster_manager.gd": 1,         # خسارت بلایای طبیعی گذرا
    "scripts/core/epidemic_manager.gd": 2,         # ضربهٔ بیماری گذرا + بازیابی
    "scripts/core/climate_manager.gd": 2,          # فاجعهٔ اقلیمی گذرا
    "scripts/core/energy_manager.gd": 1,           # قطعی انرژی گذرا
    "scripts/core/dilemma_manager.gd": 2,          # پیامد رویداد انتخابی گذرا
    "scripts/core/retail_manager.gd": 1,           # رونق مصرف (رویداد شانسی)
    "scripts/core/migration_manager.gd": 1,        # سود مهاجرتی (رویداد شرطی)
    "scripts/core/trade_policy_manager.gd": 2,     # ضربهٔ تحریم/توافق (گذرا)
    "scripts/core/faction_manager.gd": 1,          # آشوب داخلی گذرا
    "scripts/core/labor_manager.gd": 1,            # اعتصاب سراسری (رویداد شانسی)
    "scripts/core/demographic_manager.gd": 0,
    "scripts/core/diaspora_manager.gd": 0,
    "scripts/systems/military_system.gd": 0,
    "scripts/systems/interdependency_system.gd": 0,
    "scripts/core/governors_manager.gd": 1,        # شورش استانی گذرا
    "scripts/core/judiciary_manager.gd": 1,        # بحران قضایی گذرا
    "scripts/core/watershed_manager.gd": 1,        # سیل/خسارت حوضه گذرا (‌کاستن)
}


def read(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def rel(path):
    return os.path.relpath(path, ROOT).replace(os.sep, "/")


def esc(k):
    return k.replace("\\", "\\\\").replace('"', '\\"')


def norm(t):
    t = t.replace("\u200c", "").replace("‌", "").replace(" ", "")
    return t.replace("ي", "ی").replace("ك", "ک")


def transient_pattern(k):
    return re.compile(r'(?:^|["\'])' + re.escape(norm(k)) + r'(?:["\']|\])')


def collect_gd_files():
    files = []
    for base, _dirs, names in os.walk(SCRIPTS):
        for name in sorted(names):
            if name.endswith(".gd"):
                files.append(os.path.join(base, name))
    return sorted(files)


def collect_write_sites(path):
    sites = []
    for i, line in enumerate(read(path).splitlines(), 1):
        t = line.strip()
        if t.startswith("#") or SKIP_RE.search(line):
            continue
        if WRITE_RE.search(line):
            sites.append((i, line))
    return sites


def expected_nominal(f):
    """قرارداد اسمی مهاجرت: برای فایل منتظر مهاجرت یک کلید فارسی منحصربه‌فرد."""
    base = os.path.basename(f)
    stem = (base.replace("_manager.gd", "").replace("_system.gd", "").replace(".gd", "")
            .replace("_", " ").strip())
    return "سهم %s" % stem if stem else None


def get_publisher_keys():
    out = {}
    for f, keys in MIGRATED.items():
        if keys:
            out[f] = [k for k in keys if isinstance(k, str) and len(k) >= 5]
    return out


def get_convergent_level_files():
    """یکی از نویسه‌های مستقیم = الگوی «سطح هدف همگرا» — با _gdp_boost تعقیب می‌شود."""
    return sorted([f for f, cap in BUDGET.items()
                   if cap == 1 and f.startswith("scripts/core/")
                   and any(tag in f for tag in
                           ("aerospace", "aviation", "defense_industry", "ev_industry",
                            "health_tourism", "knowledge_economy", "standards",
                            "postal", "petrochemical", "waste_management"))])


def is_convergent_level_site(fpath, line):
    return ("_gdp_boost" in line) or (os.path.basename(fpath) in
                                      {os.path.basename(x) for x in get_convergent_level_files()}
                                      and "boost_delta" in line)


# ── بازبینی کلاس‌بندی REMAINDER (۱۴۰۵) ────────────────────────────────────
# هر نویسهٔ مستقیم باقی‌مانده در فایل مهاجرت‌یافته باید «گیت شرطی/شانسی» داشته
# باشد (رویداد گذرا: chance/شرط/نگهبان اقدام)؛ نویسهٔ بدون گیت = دریفت مداوم
# و نامزد اجباری مهاجرت به کانال است. این بازبینی دستی ۱۱ سایت REMAINDER را
# همگی گیت‌دار تأیید کرد (خشکسالی، اعتصاب، بحران بانکی، حباب مسکن، سود صلح…)؛
# این تابع آن یافته را به گِیت خودکار تبدیل می‌کند.
TRANSIENT_GATE_RE = re.compile(
    r"(Deterministic\.chance\(|^\s*(?:if|elif)\s)", re.M)


def remainder_sites():
    """نویسه‌های مستقیم باقی‌مانده در فایل‌های مهاجرت‌یافته (طبقهٔ REMAINDER پویشگر)."""
    out = []
    for f in sorted(MIGRATED):
        for line_no, line in collect_write_sites(os.path.join(ROOT, f)):
            out.append((f, line_no, line))
    return out


def is_transient_gated(f, line_no, window=6):
    """آیا نویسه در بافت `window` خطهٔ خود گیت رویداد/شرط دارد؟"""
    lines = read(os.path.join(ROOT, f)).splitlines()
    ctx = "\n".join(lines[max(0, line_no - 1 - window):line_no])
    return TRANSIENT_GATE_RE.search(ctx) is not None
