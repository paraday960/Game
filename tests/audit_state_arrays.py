#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""پویش رشد بی‌مهار آرایه‌های state (بازرسی ۱۴۰۵) — ابزار برنامه‌ریزی، همیشه موفق.

ریسک موبایل: آرایه‌ای در state که هر نوبت append می‌شود و هرگز trim نمی‌شود،
در سیوهای چندصدنوبتی باد می‌کند و لود/ذخیره را کند می‌کند.

الگوهای «مهار» شناخته‌شده (هرکدام = سالم):
- filter/rebuild:  arr = arr.filter(...)  یا  arr = []  یا  active_* = rebuild
- سقف صریح:        if arr.size() < N  پیش از append
- حلقهٔ trim:       while arr.size() > MAX ... pop_front()/remove_at()
- طراحی کران‌دار:   unlocks/achievements (کران = تعداد کل اقلام بازی)

نتیجهٔ نخستین پویش: همهٔ برگ‌کلیدها مهاردار بودند و فید رویداد/اخبار هم با
حلقهٔ while-trim سقف‌دار است.
محدودیت: انتساب مهار در سطح فایل است (نه به‌ازای کلید) — مثلاً treaties که با
اقدام جفت-به-جفت و erase مدیریت می‌شود در فایلی با حلقهٔ trim دیگری هم قرار
دارد؛ گزارش «مهاردار» یعنی «در فایلش الگوی مهار می‌بینیم» ولی تأیید نهایی با
مرور چشمی فهرست است. این ابزار گیت CI نیست.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = os.path.join(ROOT, "scripts")

APPEND_RE = re.compile(r'(\w+)\s*(?:\[\s*"([^"]+)"\s*\])?\s*\.append\s*\(')
TRIM_LOOP_RE = re.compile(r"while\s+\w+(?:\[[^\]]+\])?\.size\(\)\s*>")
FILTER_RE = re.compile(r"=\s*\w+(?:\[[^\]]+\])?\.filter\(")
REBUILD_RE = re.compile(r"=\s*\[\s*\]\s*(?:#|$)", re.M)
CAP_RE = re.compile(r"\.size\(\)\s*<\s*\d+")
POP_RE = re.compile(r"pop_front|pop_back|remove_at\(|\.resize\s*\(")

# کلیدهای کران‌دارِ ذاتیِ طراحی (دستاورد/انلاک محدود به فهرست کل بازی است)
DESIGN_BOUNDED = {"achievements", "unlocked", "last_unlocks"}


def main():
    suspects = []
    bounded = []
    for base, _dirs, names in os.walk(SCRIPTS):
        for name in sorted(names):
            if not name.endswith(".gd"):
                continue
            path = os.path.join(base, name)
            src = open(path, encoding="utf-8").read()
            keys = sorted({m.group(2) for m in APPEND_RE.finditer(src) if m.group(2)})
            if not keys:
                continue
            rel = os.path.relpath(path, ROOT).replace(os.sep, "/")
            why = []
            if TRIM_LOOP_RE.search(src) or POP_RE.search(src):
                why.append("حلقهٔ trim")
            if FILTER_RE.search(src):
                why.append("filter/rebuild")
            if REBUILD_RE.search(src):
                why.append("بازسازی []")
            if CAP_RE.search(src):
                why.append("سقف size<N")
            for k in keys:
                row = (rel, k)
                if k in DESIGN_BOUNDED:
                    why_k = why + ["کران‌دار طراحی"]
                    bounded.append((row, why_k))
                elif why:
                    bounded.append((row, why))
                else:
                    suspects.append(row)
    print("برگ‌کلیدهای append‌شوندهٔ مهاردار: %d" % len(bounded))
    for (rel, k), why in sorted(bounded):
        print("  ✅ %-50s %-22s (%s)" % (rel, k, " + ".join(why)))
    print("─" * 90)
    if suspects:
        print("⚠️ مشکوک بدون الگوی مهار (بررسی دستی لازم): %d" % len(suspects))
        for rel, k in suspects:
            print("  • %s :: %s" % (rel, k))
    else:
        print("✅ هیچ آرایهٔ append‌شوندهٔ بدون مهار یافت نشد")
    sys.exit(0)  # ابزار برنامه‌ریزی — همیشه موفق


if __name__ == "__main__":
    main()
