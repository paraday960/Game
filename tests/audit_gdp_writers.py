#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""پویشگر کمکی نویسه‌های GDP (ممیزی ۱۴۰۵) — ابزار برنامه‌ریزی مهاجرت، همیشه موفق.

گیت CI نیست؛ خروجی = جدول طبقه‌بندی‌شدهٔ همهٔ نویسه‌های مستقیم ``["gdp"]`` با
قرارداد اسمی کلید کانال برای فایل‌های درانتظار مهاجرت (برای پیش‌نویس C3 تست ۱۵)
و پیش‌بینی نویسه‌های گذرای باقی‌مانده.

طبقه‌ها:
- OWNER          : economy_system — مالک کانال GDP.
- CONVERGENT     : الگوی «سطح هدف همگرا» (_gdp_boost) — با تعقیب وضعیت مجاز (قفل C6 تست ۱۵).
- NPC            : نویسه روی runtime کشورهای NPC/جهان — سطح GDP بازیکن نیست.
- TRANSIENT      : شوک/رویداد/اقدام یک‌بارهٔ تشخیص‌داده‌شده (بقایای مجاز در BUDGET).
- STEADY?        : در انتظار مهاجرت — نامزدهای دورهای بعد (هدف: رقم نهایی صفر).
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from gdp_contract import (  # noqa: E402
    SCRIPTS, ROOT, read, rel as vrel, collect_write_sites, BUDGET, MIGRATED,
    get_convergent_level_files, is_convergent_level_site,
)

OWNER_FILES = {"scripts/systems/economy_system.gd"}
NPC_MARKERS = ("runtime[", "target_country[", "country_a[", "country_b[",
               "enemy[", "winner_runtime[", "snapshot[", "live[")
TRANSIENT_MARKERS = ("chance", "crisis", "war", "shock", "bailout", "drought",
                     "loss", "damage", "dmg", "attack", "disaster", "blackout",
                     "protest", "strike", "blocked", "penalty", "boom",
                     "dividend", "boom", "age >=", "mobiliz", "exhaustion",
                     "escape", "banking_crisis_end", "crop_failure",
                     "peace_dividend", "infra_failure", "apply_construction",
                     "epidemic", "pandemic", "climate", "flood", "sanction",
                     "agreement", "shortage", "unrest", "coup", "collapse",
                     "bubble", "automation", "devalue", "intervene")


def classify(rel, line, ctx):
    if rel in OWNER_FILES:
        return "OWNER"
    if any(m in line for m in NPC_MARKERS):
        return "NPC"
    if is_convergent_level_site(rel, line):
        return "CONVERGENT"
    if MIGRATED.get(rel):
        return "REMAINDER"          # فایل مهاجرت‌یافته؛ نویسه = گذرای مجاز پین‌شده
    if rel in BUDGET:
        return "TRANSIENT"          # خانوادهٔ شوک/رویداد/NPC با سقف پایش‌شده
    return "STEADY?"                # خارج از قرارداد — تست ۱۵ هم آن را رد می‌کند


def main():
    files = []
    for base, _dirs, names in os.walk(SCRIPTS):
        for name in sorted(names):
            if name.endswith(".gd"):
                files.append(os.path.join(base, name))
    rows = []
    counts = {}
    for path in files:
        rel = vrel(path)
        lines = read(path).splitlines()
        sites = collect_write_sites(path)
        for line_no, line in sites:
            ctx = "\n".join(lines[max(0, line_no - 3):line_no + 1])
            cls = classify(rel, line, ctx)
            counts[cls] = counts.get(cls, 0) + 1
            rows.append((cls, rel, line_no, line.strip()[:96]))
    order = ["STEADY?", "REMAINDER", "TRANSIENT", "CONVERGENT", "NPC", "OWNER"]
    rows.sort(key=lambda r: (order.index(r[0]), r[1], r[2]))
    width = max((len(r[1]) for r in rows), default=10)
    print("طبقه | فایل:خط | نویسه")
    print("─" * 110)
    for cls, rel, no, line in rows:
        print("%-10s | %-*s:%-4d | %s" % (cls, width, rel, no, line))
    print("─" * 110)
    for cls in order:
        if cls in counts:
            print("%s: %d" % (cls, counts[cls]))

    steady = [r for r in rows if r[0] == "STEADY?"]
    if steady:
        print("\nSTEADY? (خارج از قرارداد — باید به کانال برود یا در BUDGET مستند شود):")
        for cls, rel, no, line in steady:
            print("  • %s:%d %s" % (rel, no, line))
    else:
        print("\n✅ همهٔ نویسه‌های مستقیم در چارچوب قرارداد (BUDGET/CONVERGENT/OWNER) پوشیده‌اند.")
    print("REMAINDER = بقایای گذرای مجاز در فایل‌های مهاجرت‌یافته؛ پین‌ها در gdp_contract.BUDGET.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
