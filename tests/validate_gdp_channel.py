#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""اعتبارسنج کانال مالک-یکتای سطح GDP (sector_boosts) — ممیزی نویسندگان چندگانهٔ GDP.

نگه‌داشتن تست ۱۵ از ۱۵.

پیش از این ممیزی، بیش از ۱۱۰ نقطه در ده‌ها سیستم/مدیر ماهانه/روزانه روی
``economy.gdp`` ضرب مستقیم می‌کردند («gdp *= (۱+x)»). چون همه روی همان انباشتگر
سطح سوار می‌شدند، «سهمِ بخش» به‌اشتباه «رشدِ ماهانهٔ کل» تلقی می‌شد (دوشماره‌ای؛
بدترین‌ها: اقتصاد خلاق ≈ +۱۲٫۷٪/سال و اقتصاد آبی ≈ +۸٫۵٪/سال اضافی فراتر از رشد مرکزی).

قرارداد جدید (مانند کانال‌های نرخ ماهانهٔ بودجه):
- C1) اثر *مداوم* هر بخش فقط از کانال ``economy.sector_boosts`` می‌گذرد: هر ناشر
  نرخ *سالانهٔ* خود را با کلید فارسی مختص خودش **بازنویسی** می‌کند (هرگز += نیست؛
  بیکار = ۰٫۰). economy_system تنها مالک اعمال روزانه است (با سقف تکی/کلی).
- C2) زیرساخت: ``sector_boosts`` در init state.gd موجود باشد؛ اقتصاد ثابت‌های
  ``SECTOR_BOOST_MAX``/``SECTOR_BOOSTS_CAP`` را داشته باشد و حلقهٔ جمع+سقف+اعمال را.
- C3) هر فایل مهاجرت‌یافته کلید(های) کانال خودش را دقیقاً با همین نام‌ها داشته باشد.
- C4) اعتبار سناریوی آینه: sim_longrun باید کانال را اعمال و سناریوی
  «کانال GDP» را اجرا کند.
- C5) بودجهٔ موقت (pestle): تعداد نویسه‌های مستقیم ``["gdp"]`` باقی‌مانده در هر فایل
  نباید از پینِ جدول افزایش یابد و فایل جدیدی نباید نویسندهٔ مستقیم شود. در دورهای
  بعدی پین‌ها فقط کم می‌شوند (مهاجرت) تا بودجه به بخش‌های واقعاً گذرا برسد.

کلاس‌بندی نویسه‌های باقی‌مانده:
- مالک (economy_system): روند رشد، کشش فساد/نابرابری، شوک‌های رویدادی تصادفی.
- گذرا/اقدام-محور (TRANSIENT_OK): فروکش بحران بانکی/نجات (banking)، خشکسالی
  (agriculture)، سود صلح رویدادی (diplomacy)، شوک بلایا/سایبری/اطلاعاتی/جنگ، ساخت‌وساز
  نقشه (اقدام بازیکن)، محاصرهٔ فصلی — ضربه‌های یک‌بارهٔ مشروط، نه رشد مداوم.
- NPC/جهان (دایرکتوری مجزا رفتار می‌کنند ولی در جدول پین شده‌اند تا رشد نکنند):
  world_manager/npc_turn/leader/multiplayer/engine(snapshot).

خروج غیرصفر = نقض قرارداد (نویسندهٔ مستقیم جدید، رشد بودجه، کلید کانال گمشده،
زیرساخت ناقص).
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = os.path.join(ROOT, "scripts")

FAIL = []
NOTES = []


def rel(path):
    return os.path.relpath(path, ROOT).replace(os.sep, "/")


def read(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def check(name, ok, detail=""):
    if ok:
        NOTES.append("✅ " + name)
    else:
        FAIL.append("❌ " + name + (" — " + detail if detail else ""))


# ── C1/C2: زیرساخت کانال ────────────────────────────────────────────────
state_src = read(os.path.join(SCRIPTS, "core", "state.gd"))
check("C1) مقداردهی اولیهٔ sector_boosts در state.gd",
      re.search(r'"sector_boosts":\s*\{\}', state_src) is not None)

econ_path = os.path.join(SCRIPTS, "systems", "economy_system.gd")
econ_src = read(econ_path)
check("C2) ثابت سقف تکی SECTOR_BOOST_MAX در economy_system",
      "const SECTOR_BOOST_MAX := 0.05" in econ_src)
check("C2) ثابت سقف کلی SECTOR_BOOSTS_CAP در economy_system",
      "const SECTOR_BOOSTS_CAP := 0.10" in econ_src)
check("C2) حلقهٔ جمع نرخ بخش‌ها در economy_system",
      'for boost_key in econ.get("sector_boosts", {}).keys():' in econ_src)
check("C2) اعمال سقف کلی و انتشار sector_boosts_total",
      "clampf(boost_total, -SECTOR_BOOSTS_CAP, SECTOR_BOOSTS_CAP)" in econ_src
      and 'econ["sector_boosts_total"] = boost_total' in econ_src)

# ── C3: فایل‌های مهاجرت‌یافته و کلیدهای کانال (پین دقیق نام فارسی) ──────
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
}
for path_rel, keys in sorted(MIGRATED.items()):
    src = read(os.path.join(ROOT, path_rel))
    for key in keys:
        check("C3) ناشر کانال «%s» در %s" % (key, path_rel),
              ('boosts["%s"]' % key) in src.replace("_boosts[", "boosts["),
              "کلید یافت نشد")

# ── C4: آینهٔ پایتونی همگام است ─────────────────────────────────────────
mirror = read(os.path.join(ROOT, "tests", "sim_longrun.py"))
check("C4) آینه: sector_boosts در initial_state", '"sector_boosts": {}' in mirror)
check("C4) آینه: سقف تکی/کلی و اعمال در step_day",
      "clamp(sum(clamp(float(v), -0.05, 0.05)" in mirror and "boost_total / 365.0" in mirror)
check("C4) آینه: سناریوی کانال GDP ثبت و اجرا می‌شود",
      "def run_gdp_boost_suite()" in mirror and "run_gdp_boost_suite() and ok" in mirror)

# ── C5: بودجهٔ نویسه‌های مستقیم باقی‌مانده (pestle — فقط کم می‌شود) ─────
# هر فایل → سقف تعداد نویسهٔ مستقیم ["gdp"] (بعد از مهاجرت دور نخست).
# فایل‌هایی با سقف ۰ کاملاً مهاجرت کرده‌اند و دیگر حق نویسهٔ مستقیم ندارند.
BUDGET = {
    # مالک کانال (روند/کشش‌ها/شوک‌های درون‌سیستمی)
    "scripts/systems/economy_system.gd": 7,
    # فایل‌های مهاجرت‌یافته به کانال (نویسهٔ مستقیم = ۰)
    "scripts/systems/industry_system.gd": 0,
    "scripts/systems/transport_roads_system.gd": 0,
    "scripts/systems/environment_system.gd": 0,
    "scripts/core/fdi_manager.gd": 0,
    "scripts/core/digital_manager.gd": 0,
    "scripts/core/mining_manager.gd": 0,
    "scripts/core/creative_manager.gd": 0,
    "scripts/core/blue_economy_manager.gd": 0,
    "scripts/core/urban_manager.gd": 0,
    "scripts/core/care_economy_manager.gd": 0,
    "scripts/core/civic_manager.gd": 0,
    "scripts/core/downstream_energy_manager.gd": 0,
    "scripts/core/basic_industry_manager.gd": 0,
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
    "scripts/core/prison_manager.gd": 0,
    "scripts/core/pro_sports_manager.gd": 0,
    "scripts/core/waste_manager.gd": 0,
    "scripts/core/supply_chain_manager.gd": 0,
    "scripts/core/judicial_reform_manager.gd": 0,
    "scripts/core/waste_management_manager.gd": 0,
    # الگوی «سطح هدف همگرا» (_gdp_boost): اثر بخش مسیر محدود و خودمهارکننده به سقف
    # سهمش دارد و سپس صفر می‌شود؛ جمعِ بی‌پایان نیست. مستثنی از کانال (BUDGET=۱ پین).
    "scripts/core/aerospace_manager.gd": 1,
    "scripts/core/aviation_manager.gd": 1,
    "scripts/core/defense_industry_manager.gd": 1,
    "scripts/core/ev_industry_manager.gd": 1,
    "scripts/core/health_tourism_manager.gd": 1,
    "scripts/core/knowledge_economy_manager.gd": 1,
    "scripts/core/standards_manager.gd": 1,
    "scripts/core/postal_manager.gd": 1,
    "scripts/core/petrochemical_manager.gd": 1,
    # مختلط: نویسه(های) گذرای رویدادی باقی‌مانده (پایش‌شده)
    "scripts/systems/diplomacy_system.gd": 1,      # سود صلح (رویداد شرطی ×۱۰۰۵)
    "scripts/systems/emergency_system.gd": 1,      # خسارت اضطراری گذرا
    "scripts/systems/intelligence_system.gd": 1,   # ضربهٔ عملیاتی گذرا
    "scripts/systems/map_advanced_system.gd": 1,   # اقدام ساخت‌وساز بازیکن (یک‌باره)
    "scripts/systems/trade_route_warfare_system.gd": 1,  # دزدی دریایی گذرا
    "scripts/core/agriculture_manager.gd": 1,      # خشکسالی (رویداد شانسی)
    "scripts/core/banking_manager.gd": 2,          # فروکش بحران/نجات (رویداد/اقدام)
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
    "scripts/core/housing_manager.gd": 1,          # ترکیدن حباب مسکن گذرا
    "scripts/core/sme_manager.gd": 1,              # موج تعطیلی بنگاه‌ها گذرا
    "scripts/core/ai_industry_manager.gd": 1,      # اعتراض به اتوماسیون گذرا
    "scripts/core/textile_manager.gd": 1,          # کمبود ماده اولیه گذرا
    "scripts/core/infrastructure_manager.gd": 1,   # شکست زیرساخت (رویداد پوسیدگی)
}

WRITE_RE = re.compile(r'\["gdp"\]\s*\*?=[^=]')
SKIP_RE = re.compile(r"per_capita|gdp_")
actual = {}
for base, _dirs, names in os.walk(SCRIPTS):
    for name in names:
        if not name.endswith(".gd"):
            continue
        path = os.path.join(base, name)
        count = 0
        for line in read(path).splitlines():
            if line.strip().startswith("#") or SKIP_RE.search(line):
                continue
            if WRITE_RE.search(line):
                count += 1
        if count:
            actual[rel(path)] = count

new_files = sorted(set(actual) - set(BUDGET))
check("C5) هیچ نویسندهٔ مستقیم جدیدی (فایل تازه) اضافه نشده",
      not new_files, "فایل‌های جدید: %s" % ", ".join(new_files))
over = {f: (a, BUDGET[f]) for f, a in actual.items() if f in BUDGET and a > BUDGET[f]}
check("C5) بودجهٔ نویسهٔ مستقیم GDP در هیچ فایلی رشد نکرده",
      not over, "بیشتر از پین: %s" % over)
# ── C6: قرارداد الگوی «سطح هدف همگرا» (_gdp_boost) ─────────────────────
# این الگو فقط وقتی مجاز است که فاصله تا هدف تعقیب شود (_gdp_boost)؛ وگرنه «سطح
# هدف» خود به انباشتگر مخفی بدل می‌شود و بازی را در بلندمدت منفجر می‌کند.
CONVERGENT_FILES = [f for f, cap in BUDGET.items()
                    if cap == 1 and f.startswith("scripts/core/")
                    and any(tag in f for tag in
                            ("aerospace", "aviation", "defense_industry", "ev_industry",
                             "health_tourism", "knowledge_economy", "standards",
                             "postal", "petrochemical"))]
for conv in CONVERGENT_FILES:
    src_conv = read(os.path.join(ROOT, conv))
    check("C6) الگوی همگرای _gdp_boost در %s تعقیب‌وضعیت دارد" % conv,
          "_gdp_boost" in src_conv)

shrunk = [f for f, a in actual.items() if f in BUDGET and a < BUDGET[f]]
if shrunk:
    NOTES.append("ℹ️ پیشرفت مهاجرت — پین‌های BUDGET برای %s را در همین فایل کم کنید"
                 % ", ".join(sorted(shrunk)))
NOTES.append("ℹ️ مجموع نویسه‌های مستقیم باقی‌مانده: %d (سقف پین‌شده: %d)"
             % (sum(actual.values()), sum(BUDGET.values())))

for note in NOTES:
    print(note)
if FAIL:
    print("\n═══ شکست — %d نقض قرارداد کانال GDP ═══" % len(FAIL))
    for f in FAIL:
        print("  " + f)
    sys.exit(1)
print("\n═══ موفق — کانال مالک-یکتای GDP سالم و بودجهٔ مهاجرت محرز است ═══")
