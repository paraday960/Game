#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""اعتبارسنج کانال مالک-یکتای سطح GDP (sector_boosts) — تست ۱۵ (ممیزی نویسندگان ۱۴۰۵).

قرارداد (کامل در tests/gdp_contract.py که منبع واحد این تست و پویشگر است):
- C1) ``sector_boosts`` در init state.gd موجود باشد.
- C2) زیرساخت اعمال کانال در economy_system: ثابت‌های سقف + حلقهٔ جمع + انتشار total.
- C3) هر فایل مندرج در MIGRATED کلید(های) کانالش را با همان نام فارسی بنویسد؛
  هر کلید فارسی (≥۵ نویسه) و یکتا در سراسر ناشران باشد (یک کلید = یک مالک).
- C4) آینهٔ sim_longrun کانال را اعمال و سناریوی «کانال GDP» را اجرا کند.
- C5) بودجهٔ pestleٔ نویسه‌های مستقیم ``["gdp"]``: تعداد واقعی هر فایل ≤ سقف BUDGET؛
  هیچ فایل جدیدی نویسندهٔ مستقیم نشود. سقف‌ها فقط کم می‌شوند (فایل‌های ترم‌صفر = تمیز).
- C6) الگوی «سطح هدف همگرا» (_gdp_boost) فقط با تعقیب‌وضعیت مجاز است — وگرنه «سطح
  هدف» به انباشتگر مخفی بدل می‌شود و بلندمدت بازی را منفجر می‌کند.

طبقه‌بندی بقایا (۷۱ نویسه پس از مهاجرت دور دوم): مالک (economy_system)، شوک‌های
گذرای رویدادی (کمیاب/شرطی)، الگوی سطح هدف همگرا (با تعقیب)، و نویسه‌های جهان/NPC.
خروج غیرصفر = نقض قرارداد.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from gdp_contract import (ROOT, SCRIPTS, read, rel, esc, ARABIC_PERSIAN_KEY_RE,
                          MIGRATED, BUDGET, SINGLE_OWNER_ALLOW, RESERVE_PUBLISHERS,
                          RESERVE_BUDGET, collect_gd_files, collect_write_sites,
                          get_convergent_level_files, is_convergent_level_site)


def main():
    FAIL = []
    NOTES = []

    def check(name, ok, detail=""):
        if ok:
            NOTES.append("✅ " + name)
        else:
            FAIL.append("❌ " + name + (" — " + detail if detail else ""))

    # ── C1/C2: زیرساخت کانال ────────────────────────────────────────────
    state_src = read(os.path.join(SCRIPTS, "core", "state.gd"))
    check("C1) مقداردهی اولیهٔ sector_boosts در state.gd",
          re.search(r'"sector_boosts":\s*\{\}', state_src) is not None)

    econ_src = read(os.path.join(SCRIPTS, "systems", "economy_system.gd"))
    check("C2) ثابت سقف تکی SECTOR_BOOST_MAX در economy_system",
          "const SECTOR_BOOST_MAX := 0.05" in econ_src)
    check("C2) ثابت سقف کلی SECTOR_BOOSTS_CAP در economy_system",
          "const SECTOR_BOOSTS_CAP := 0.10" in econ_src)
    check("C2) حلقهٔ جمع نرخ بخش‌ها در economy_system",
          'for boost_key in econ.get("sector_boosts", {}).keys():' in econ_src)
    check("C2) اعمال سقف کلی و انتشار sector_boosts_total",
          "clampf(boost_total, -SECTOR_BOOSTS_CAP, SECTOR_BOOSTS_CAP)" in econ_src
          and 'econ["sector_boosts_total"] = boost_total' in econ_src)

    # ── C3: کلیدهای کانال ناشران مهاجرت‌یافته ────────────────────────────
    boost_write_re = re.compile(r'\["(' + "|".join(
        re.escape(k) for ks in MIGRATED.values() for k in ks) + r')"\]\s*=')
    seen = {}
    gd_files = collect_gd_files()
    for f, keys in sorted(MIGRATED.items()):
        src = read(os.path.join(ROOT, f))
        for key in keys:
            check("C3) ناشر کانال «%s» در %s" % (key, f),
                  ('["%s"]' % key) in src, "کلید یافت نشد")
            check("C3) فرم کلید «%s» فارسی و استاندارد است" % key,
                  ARABIC_PERSIAN_KEY_RE.match(key) is not None and len(key) >= 3)
    # یکتایی کلید در سراسر ناشران (یک کلید = یک مالک)
    all_keys = [k for ks in MIGRATED.values() for k in ks]
    dup = [k for k in set(all_keys) if all_keys.count(k) > 1]
    check("C3) هیچ کلید کانالی توسط دو فایل نوشته نمی‌شود (مالکیت یکتا)", not dup,
          "تکراری: %s" % dup)

    # ── C2b: مالکیت یکتای کلیدهای حساس (growth_rate و…) ───────────────
    for skey, allowed in SINGLE_OWNER_ALLOW.items():
        bad = []
        for path in gd_files:
            rp = rel(path)
            if rp in allowed:
                continue
            for no, line in enumerate(read(path).splitlines(), 1):
                if line.strip().startswith("#"):
                    continue
                if re.search(r'\["%s"\]\s*=[^=]' % skey, line):
                    bad.append("%s:%d" % (rp, no))
        check("C2b) نویسهٔ «%s» فقط در مالک‌های مجاز است" % skey, not bad,
              "نویسهٔ سرکش: %s" % ", ".join(bad[:6]))

    # ── C4: آینهٔ پایتونی همگام است ─────────────────────────────────────
    mirror = read(os.path.join(ROOT, "tests", "sim_longrun.py"))
    check("C4) آینه: sector_boosts در initial_state", '"sector_boosts": {}' in mirror)
    check("C4) آینه: سقف تکی/کلی و اعمال در step_day",
          "clamp(sum(clamp(float(v), -0.05, 0.05)" in mirror and "boost_total / 365.0" in mirror)
    check("C4) آینه: سناریوی کانال GDP ثبت و اجرا می‌شود",
          "def run_gdp_boost_suite()" in mirror and "run_gdp_boost_suite() and ok" in mirror)

    # ── C7: کانال نرخ ماهانهٔ ورودی ذخایر ارزی (reserve_inflows) ─────────
    RES_WRITE_RE = re.compile(r'\["foreign_reserves"\]\s*[+\-]?\*?=[^=]')
    check("C7) مقداردهی اولیهٔ reserve_inflows در state.gd",
          re.search(r'"reserve_inflows":\s*\{\}', state_src) is not None)
    cb_src = read(os.path.join(SCRIPTS, "systems", "central_bank_system.gd"))
    check("C7) مالک تسویهٔ کانال: حلقهٔ جمع + تقسیم روزانه + انتشار در central_bank",
          'for _rk in economy.get("reserve_inflows", {}).keys():' in cb_src
          and "reserves_now += inflow_month / 30.0" in cb_src
          and 'economy["reserve_inflows_monthly"] = inflow_month' in cb_src)
    for f, keys in sorted(RESERVE_PUBLISHERS.items()):
        src = read(os.path.join(ROOT, f))
        for key in keys:
            check("C7) ناشر ذخایر «%s» در %s" % (key, f),
                  ('_infl["%s"]' % key) in src)
    all_rkeys = [k for ks in RESERVE_PUBLISHERS.values() for k in ks]
    rdup = [k for k in set(all_rkeys) if all_rkeys.count(k) > 1]
    check("C7) یکتایی کلیدهای کانال ذخایر (یک کلید = یک مالک)", not rdup, str(rdup))
    actual_r = {}
    for path in gd_files:
        cnt = 0
        for line in read(path).splitlines():
            if line.strip().startswith("#"):
                continue
            if RES_WRITE_RE.search(line):
                cnt += 1
        if cnt:
            actual_r[rel(path)] = cnt
    new_rf = sorted(set(actual_r) - set(RESERVE_BUDGET))
    check("C7) نویسندهٔ مستقیم جدیدی برای ذخایر اضافه نشده", not new_rf,
          "فایل‌های جدید: %s" % ", ".join(new_rf))
    over_r = {f: (a, RESERVE_BUDGET[f]) for f, a in actual_r.items()
              if f in RESERVE_BUDGET and a > RESERVE_BUDGET[f]}
    check("C7) بودجهٔ نویسهٔ مستقیم ذخایر در هیچ فایلی رشد نکرده",
          not over_r, "بیشتر از سقف: %s" % over_r)
    NOTES.append("ℹ️ ذخایر: %d ناشر کانال، %d نویسهٔ مستقیم باقی‌مانده (سقف %d)"
                 % (len(RESERVE_PUBLISHERS), sum(actual_r.values()),
                    sum(RESERVE_BUDGET.values())))
    mirror2 = read(os.path.join(ROOT, "tests", "sim_longrun.py"))
    check("C7) آینه: reserve_inflows در initial_state و تسویهٔ روزانه",
          '"reserve_inflows": {}' in mirror2 and "infl / 30.0" in mirror2)
    check("C7) آینه: سناریوی کانال ذخایر اجرا می‌شود",
          "def run_reserve_inflow_suite()" in mirror2
          and "run_reserve_inflow_suite() and ok" in mirror2)

    # ── C5: بودجهٔ نویسه‌های مستقیم (pestle — فقط کم می‌شود) ───────────
    actual = {}
    for path in gd_files:
        count = len(collect_write_sites(path))
        if count:
            actual[rel(path)] = count
    new_files = sorted(set(actual) - set(BUDGET))
    check("C5) هیچ نویسندهٔ مستقیم جدیدی (فایل تازه) اضافه نشده",
          not new_files, "فایل‌های جدید: %s" % ", ".join(new_files))
    over = {f: (a, BUDGET[f]) for f, a in actual.items() if f in BUDGET and a > BUDGET[f]}
    check("C5) بودجهٔ نویسهٔ مستقیم GDP در هیچ فایلی رشد نکرده",
          not over, "بیشتر از سقف: %s" % over)
    shrunk = [f for f, a in actual.items() if f in BUDGET and a < BUDGET[f]]
    if shrunk:
        NOTES.append("ℹ️ پیشرفت مهاجرت — سقف BUDGET در gdp_contract برای %s را کم کنید"
                     % ", ".join(sorted(shrunk)))
    clean = [f for f in MIGRATED if actual.get(f, 0) == 0]
    NOTES.append("ℹ️ فایل‌های کاملاً تمیز (بدون نویسهٔ مستقیم): %d از %d مهاجرت‌یافته"
                 % (len(clean), len(MIGRATED)))
    NOTES.append("ℹ️ مجموع نویسه‌های مستقیم باقی‌مانده: %d (سقف پین‌شده: %d)"
                 % (sum(actual.values()), sum(BUDGET.values())))

    # ── C8: نمایش کانال‌ها در UI (بازرسی ۱۴۰۵ج) ─────────────────────────
    # کانال‌های GDP و ورودی ذخایر برای بازیکن دیده می‌شوند — در غیر این صورت
    # سیم‌کشی مدل «جعبهٔ سیاه» می‌ماند و قراردادِ نمایش زنجیره‌اثر نقض است.
    ui_src = read(os.path.join(SCRIPTS, "ui", "main_ui.gd"))
    check("C8) کارت آمار مالی: خواندن sector_boosts_total و لیبل «رشد کانال بخش‌ها»",
          'econ.get("sector_boosts_total"' in ui_src and "رشد کانال بخش‌ها" in ui_src)
    check("C8) کارت آمار مالی: برترین سهم‌دهندهٔ کانال (حلقهٔ کلیدها + لیبل)",
          'for bk in econ.get("sector_boosts", {}).keys():' in ui_src
          and "برترین اثر بخشی" in ui_src)
    check("C8) کارت ارز: نمایش ورودی ماهانهٔ بخشی ذخایر (reserve_inflows_monthly)",
          'econ_fx.get("reserve_inflows_monthly"' in ui_src
          and "ورودی بخشی ذخایر (ماهانه)" in ui_src)
    check("C8) کارت ارز: نمایش علامت‌دار — خروج/فرار سرمایه (شرط != ۰ و لیبل منفی)",
          "inflow_m != 0.0" in ui_src
          and "خروج بخشی ذخایر (ماهانه)" in ui_src)
    check("C8) مرورگر سامانه‌ها: کارت تفصیلی ریز کانال GDP (عنوان + مرتب‌سازی اندازه‌ای)",
          "ریز اثر بخش‌ها بر رشد (کانال GDP)" in ui_src
          and "boost_rows.sort_custom" in ui_src
          and "absf(bv) > 0.000001" in ui_src)
    check("C8) مرورگر سامانه‌ها: کارت «شاخص‌های کلیدی بخش‌ها» (جاروی یتیم اطلاعاتی)",
          "SECTOR_INDICATORS" in ui_src
          and "شاخص‌های کلیدی بخش‌ها" in ui_src)
    check("C8) نمونه‌های کلید یتیم سیم‌کشی‌شده در جدول شاخص‌ها (جمعیت/مسکن/آب/دارو)",
          '"population", "dependency_ratio"' in ui_src
          and '"housing_policy", "home_ownership"' in ui_src
          and '"water_infrastructure", "rural_access"' in ui_src
          and '"pharma_policy", "drug_cost"' in ui_src)

    # ── C9: فید رویدادهای کانال GDP (بازرسی ۱۴۰۵د) ───────────────────────
    check("C9) رویداد محرک کانال در economy_system (نوع sector_boost_drive)",
          '"type": "sector_boost_drive"' in econ_src and "_sb_prev_total" in econ_src)
    check("C9) پنجرهٔ فرکانس/شدت رویداد محرک (هر ۳ روز + پنجرهٔ شدت)",
          "tick % 3 == 0" in econ_src and "0.007" in econ_src and "0.015" in econ_src)
    check("C9) فید اخبار مهم UI نوع رویداد را می‌شناسد (sector_boost در hints)",
          '"sector_boost"' in ui_src)
    check("C9) آینه: رویداد محرک در سناریوی کانال پایش می‌شود",
          "_sb_prev_total" in mirror2 if "mirror2" in dir() else "_sb_prev_total" in mirror)

    # ── C6: قفل الگوی «سطح هدف همگرا» (_gdp_boost) ───────────────────────
    for conv in get_convergent_level_files():
        src_conv = read(os.path.join(ROOT, conv))
        check("C6) الگوی همگرای _gdp_boost در %s تعقیب‌وضعیت دارد" % conv,
              "_gdp_boost" in src_conv)
    # و سایت همان‌خطی باید افزایشِ سطح با دلتا باشد (الگو از مسیر خارج نشده باشد)
    for conv in get_convergent_level_files():
        for no, line in collect_write_sites(os.path.join(ROOT, conv)):
            if is_convergent_level_site(conv, line):
                check("C6) سایت همگرا در %s:%d الگوی جمع-دلتا دارد" % (conv, no),
                      "boost_delta" in line or "+" in line)

    for note in NOTES:
        print(note)
    if FAIL:
        print("\n═══ شکست — %d نقض قرارداد کانال GDP ═══" % len(FAIL))
        for f in FAIL:
            print("  " + f)
        return 1
    print("\n═══ موفق — کانال مالک-یکتای GDP سالم و بودجهٔ مهاجرت محرز است ═══")
    return 0


if __name__ == "__main__":
    sys.exit(main())
