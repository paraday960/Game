#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""قرارداد کانال بدهی ملی (بازرسی ۱۴۰۵ — دور هشتم).

یافته: ۹۲ سایت در ۴۰ فایل مستقیم روی economy.national_debt می‌نوشتند. طبقه‌بندی:
• ~۷۱ سایت «اقدام یک‌بارمصرف» (بازیکن/AI) — الگوی جاافتادهٔ «تأمین مالی با اوراق»؛
  منطقِ صحیح‌تر = انبارهٔ oneoff_spending_pool (امواج نمایشی)، ولی مهاجرت یک‌جای
  ۷۱ سایت ریسک بالایی دارد و در برنامهٔ بلندمدت است (سرشماری زیر «فقط کم است»).
• ~۱۷ سایت «هزینهٔ مداوم ماهانه» — تخلفِ واقعی لوله‌کشی مالی: یارانه انرژی، صندوق
  بازنشستگی، برنامهٔ فضایی… هر ماه به بدهی شارژ می‌شدند و در بودجه/کسری دیده
  نمی‌شدند و سود بدهی هم به آن‌ها نمی‌چسبید. این‌ها به کانال چندناشری
  economy.policy_costs مهاجرت می‌کنند (مصرف‌کنندهٔ مالک: economy_system → spending).
• چند سایت درآمدی (کاربون/سوخت/بورس) که بدهی را مستقیم کم می‌کردند — جبههٔ
  کانال درآمد (دور بعد).

قرارداد:
۱) سرشماری نویسندگان مستقیم در هر فایل «فقط کم می‌شود» (بیشتر شود = باگ جدید).
۲) سایت‌های سیاستی مهاجرت‌یافته پین‌اند: فایل باید کلید فارسی‌اش را در
   policy_costs منتشر کند و دیگر نویسهٔ مستقیم بدهی در آن فایل ممنوع (در بخش
   simulate_month ماهانه؛ اقدامات مستثنی‌اند و در سرشماری باقی می‌مانند).
۳) مالک مصرف: economy_system باید جمع کانال را به هزینه اضافه و
   policy_costs_total را منتشر کند.
خروج غیرصفر = نقض هر بند.
"""
import io
import os
import re
import sys

fail = []

def src(path):
    return io.open(path, encoding="utf-8").read()

WRITE_RE = re.compile(r'"national_debt"\]\s*[+\-*/]?=[^=]')

# سرشماری دور هشتم: تعداد نویسه‌های مستقیم بدهی به‌ازای هر فایل — سقف، نه هدف.
DEBT_WRITER_CENSUS = {
    "scripts/core/agriculture_manager.gd": 3,
    "scripts/core/arms_manager.gd": 1,  # سایت ماهانه به کانال رفت؛ فروش تسلیحات (اقدام) باقی
    "scripts/core/banking_manager.gd": 3,
    "scripts/core/climate_manager.gd": 3,  # درآمد کربن به کانال خزانه رفت (بدهیِ خاموش حذف)
    "scripts/core/culture_manager.gd": 3,
    "scripts/core/cyber_manager.gd": 1,
    "scripts/core/demographic_manager.gd": 0,  # فشار صندوق به کانال policy_costs رفت
    "scripts/core/digital_manager.gd": 3,
    "scripts/core/dilemma_manager.gd": 1,
    "scripts/core/education_manager.gd": 3,
    # energy_manager: یارانه → کانال (سایت ماهانهٔ ۶۴ مهاجرت کرد؛ ۳ اقدام باقی)
    "scripts/core/energy_manager.gd": 3,
    "scripts/core/engine.gd": 3,
    "scripts/core/epidemic_manager.gd": 2,
    "scripts/core/fdi_manager.gd": 2,
    "scripts/core/fuel_transition_manager.gd": 0,  # دور یازدهم: کسر یک‌بارهٔ بدهی هم حذف شد (پاداش = هزینهٔ کمتر یارانه)
    "scripts/core/heritage_manager.gd": 1,  # عایدی ضدقاچاق (اقدام؛ قبلاً جمع فانتوم روی revenue بود)
    "scripts/core/industry_manager.gd": 1,
    "scripts/core/infrastructure_manager.gd": 1,
    "scripts/core/insurance_manager.gd": 1,
    "scripts/core/intelligence_operation_manager.gd": 1,
    "scripts/core/judiciary_manager.gd": 1,
    "scripts/core/migration_manager.gd": 2,
    "scripts/core/military_manager.gd": 1,
    "scripts/core/national_project_manager.gd": 1,  # هزینهٔ ماهانه به کانال رفت؛ اقدام شروع پروژه باقی
    "scripts/core/parliament_manager.gd": 1,
    "scripts/core/seasonal_manager.gd": 1,
    "scripts/core/security_manager.gd": 2,
    "scripts/core/space_manager.gd": 5,  # آژانس به کانال رفت؛ ۴ اقدام + ۱ رویداد شکست باقی
    "scripts/core/sports_manager.gd": 4,
    "scripts/core/stock_market_manager.gd": 1,  # مالیات عایدی به کانال رفت (جمع فانتوم هم حذف)؛ صندوق تثبیت باقی
    "scripts/core/tourism_manager.gd": 3,
    "scripts/core/trade_policy_manager.gd": 4,
    "scripts/core/transport_manager.gd": 0,  # یارانه به کانال رفت؛ شارژ دوم مازاد (دوشماره‌ای) حذف شد
    "scripts/core/urban_manager.gd": 3,
    "scripts/core/veterans_manager.gd": 0,  # مستمری به کانال رفت؛ شارژ دوم مازاد (دوشماره‌ای) حذف شد
    "scripts/core/welfare_manager.gd": 3,  # انتقال‌ها به کانال رفت؛ ۲ اقدام + رویداد بحران صندوق باقی
    "scripts/core/world_manager.gd": 4,  # + کمک بشردوستانه (عمق‌بخشی ۱۳؛ هزینه یک‌باره به بدهی)
    "scripts/systems/economy_system.gd": 2,   # مالک مخزن: تسویهٔ کسری/سود + اوراق جنگی
    "scripts/systems/map_advanced_system.gd": 4,
    "scripts/systems/military_system.gd": 1,  # سهم اوراق جنگی
    "scripts/systems/trade_route_warfare_system.gd": 3,
}

# سایت‌های سیاستی مهاجرت‌یافته به کانال policy_costs: فایل → کلید فارسی ناشر
POLICY_COST_PUBLISHERS = {
    "scripts/core/energy_manager.gd": ["یارانه انرژی"],
    "scripts/core/demographic_manager.gd": ["فشار صندوق بازنشستگی"],
    "scripts/core/arms_manager.gd": ["نگهداری صنایع دفاعی"],
    "scripts/core/space_manager.gd": ["برنامه فضایی (آژانس)"],
    "scripts/core/national_project_manager.gd": ["پروژه‌های ملی"],
    # دور نهم: تحلیل سه‌گانهٔ transferها (transport/veterans شارژ دومِ مازادِ
    # دوشماره‌ای هم داشتند که حذف شد؛ welfare از شارژ خاموش بدهی مهاجرت کرد)
    "scripts/core/transport_manager.gd": ["یارانه کرایه حمل‌ونقل عمومی"],
    "scripts/core/veterans_manager.gd": ["مستمری و خدمات کهنه‌سربازان"],
    "scripts/core/welfare_manager.gd": ["انتقال‌های اجتماعی"],
    # دور یازدهم: ادغام مفهومی یارانه — هزینهٔ واقعی یارانهٔ سوخت از مدل زندهٔ
    # شکاف قیمت پمپ‌بنز؛ «درآمد اصلاح قیمت» و کسر یک‌بارهٔ بدهی حذف شدند
    "scripts/core/fuel_transition_manager.gd": ["یارانه سوخت"],
}

# ── ۱) سرشماری «فقط کم است» ────────────────────────────────────────────
actual = {}
for f in sorted(DEBT_WRITER_CENSUS):
    body = src(f)
    cnt = 0
    for line in body.splitlines():
        st = line.strip()
        if st.startswith("#") or "debt_to_gdp" in line:
            continue
        if WRITE_RE.search(line):
            cnt += 1
    actual[f] = cnt
    budget = DEBT_WRITER_CENSUS[f]
    if cnt > budget:
        fail.append("%s نویسهٔ مستقیم بدهی %d > سرشماری %d (سایت جدید بدون قرارداد)"
                    % (f, cnt, budget))
print("✅ سرشماری نویسه‌های مستقیم بدهی در همهٔ فایل‌ها از سقف دور هشتم فراتر نرفت")
extra_total = sum(actual.values())
print("   مجموع فعلی نویسه‌های مستقیم: %d" % extra_total)

# ── ۲) پین ناشران policy_costs ──────────────────────────────────────────
for f, keys in sorted(POLICY_COST_PUBLISHERS.items()):
    body = src(f)
    for key in keys:
        if '_costs["%s"]' % key in body:
            print("✅ ناشر هزینهٔ بخشی «%s» در %s" % (key, f))
        else:
            fail.append("ناشر هزینهٔ بخشی «%s» در %s یافت نشد (مهاجرت برگشته)" % (key, f))

# ── ۳) مالک مصرف کانال ──────────────────────────────────────────────────
econ = src("scripts/systems/economy_system.gd")
if ("pc_total" in econ and "policy_costs_total" in econ
        and 'econ.get("policy_costs", {})' in econ and "spending += pc_total" in econ):
    print("✅ economy_system مالک مصرف کانال policy_costs است (جمع→هزینه→کسری/بدهی)")
else:
    fail.append("economy_system دیگر مالک مصرف کانال policy_costs نیست")

# ── ۴) کانال‌های درآمدی ماهانه (مهاجرت از «کسر خاموش بدهی») ─────────────
REVENUE_PUBLISHERS = {
    "scripts/core/climate_manager.gd": "carbon_tax_monthly",
    # دور یازدهم: fuel_transition_monthly حذف شد — با هزینهٔ واقعی یارانهٔ سوخت
    # در کانال policy_costs ادغام شد (یارانهٔ رایگان/پاداش سه‌گانهٔ اصلاح مرد)
    "scripts/core/stock_market_manager.gd": "stock_gains_monthly",
}
for f, key in sorted(REVENUE_PUBLISHERS.items()):
    if ('econ["%s"]' % key) in src(f):
        print("✅ ناشر درآمد ماهانهٔ «%s» در %s" % (key, f))
    else:
        fail.append("ناشر درآمد ماهانهٔ «%s» در %s یافت نشد" % (key, f))
for key in REVENUE_PUBLISHERS.values():
    if 'econ.get("%s", 0.0)' % key in econ:
        print("✅ economy_system درآمد «%s» را در خزانه مصرف می‌کند" % key)
    else:
        fail.append("economy_system درآمد «%s» را مصرف نمی‌کند" % key)

if fail:
    print("\n❌ شکست قرارداد کانال بدهی:")
    for x in fail:
        print("  • " + x)
    sys.exit(1)
print("\nکانال بدهی OK: سرشماری محرز، ناشران سیاسی سیم‌کشی‌شده، مالک مصرف سر جایش.")
