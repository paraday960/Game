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
SKIP_RE = re.compile(r"per_capita|gdp_")
NOMIN = r'\["gdp"\]\s*[+\-]?\*?=\s*[^\n]*(?:\(1\.0|[+\-]?\*?\s*1\.0|\*\s*0\.9|\*\s*1\.0|[+\-]\s*(?:gdp|float\())'
ARABIC_PERSIAN_KEY_RE = re.compile(r'^[\u0600-\u06FF\u200c0-9\s\(\)\/،\-]{3,}$')

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
    "scripts/core/labor_manager.gd": 2,            # اعتصاب/بحران کارگری گذرا
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
