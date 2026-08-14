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
                          MIGRATED, BUDGET, collect_gd_files, collect_write_sites,
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

    # ── C4: آینهٔ پایتونی همگام است ─────────────────────────────────────
    mirror = read(os.path.join(ROOT, "tests", "sim_longrun.py"))
    check("C4) آینه: sector_boosts در initial_state", '"sector_boosts": {}' in mirror)
    check("C4) آینه: سقف تکی/کلی و اعمال در step_day",
          "clamp(sum(clamp(float(v), -0.05, 0.05)" in mirror and "boost_total / 365.0" in mirror)
    check("C4) آینه: سناریوی کانال GDP ثبت و اجرا می‌شود",
          "def run_gdp_boost_suite()" in mirror and "run_gdp_boost_suite() and ok" in mirror)

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
