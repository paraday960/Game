# -*- coding: utf-8 -*-
"""پین پویش «منبع تورم بانک مرکزی» — بازرسی ۱۴۰۵.

تورم واقعی کشور در economy.inflation زندگی می‌کند، ولی سه جا آن را از بخش
central_bank با پیش‌فرض ثابت ۰.۰۸ می‌خواندند (کلیدی که هرگز نوشته نمی‌شود):
- هوش بانک مرکزی (central_bank_ai): شرط «تورم > ۱۵٪» هرگز برقرار نمی‌شد
  → AI هرگز نرخ بهره را برای مهار تورم بالا نمی‌برد (باگ منطقی).
- لایه‌ی نقشه‌ی central_bank در unified_map: همیشه ۰.۷۳ نشان می‌داد.
- امتیاز central_bank در country_geography_manager: همیشه مقدار ثابت.

درمان: هر سه به economy.inflation وصل شدند.
این تست پین می‌کند: هیچ خواندن تورمی از central_bank/cb باقی نماند و
سه فایل درمان‌شده از economy.inflation بخوانند.
"""
import io
import re
import sys
import glob

FAIL = []


def read(p):
    return io.open(p, encoding="utf-8").read()


def check(name, cond, msg):
    if not cond:
        FAIL.append(msg)
        print("❌ %s: %s" % (name, msg))
    else:
        print("✅ %s" % name)


# 1) هیچ خواندن تورمی از بخش central_bank/cb
bad = []
for f in glob.glob("scripts/**/*.gd", recursive=True):
    src = read(f)
    for m in re.finditer(
        r'(central_bank|cb)\.get\(\s*"inflation"|'
        r'\["central_bank"\]\s*\.get\(\s*"inflation"|'
        r'get\("central_bank",[^)]*\)\.get\(\s*"inflation"',
        src,
    ):
        ln = src[: m.start()].count("\n") + 1
        bad.append((f, ln))
check(
    "بدون خواندن تورم از central_bank",
    not bad,
    "خواندن از بخش اشتباه: %s" % (bad or "—"),
)

# 2) سه فایل درمان‌شده از economy.inflation می‌خوانند
cba = read("scripts/ai/central_bank_ai.gd")
check(
    "AI بانک مرکزی از economy.inflation",
    'float(econ.get("inflation", 0.08))' in cba,
    "central_bank_ai باید تورم را از econ بخواند",
)

geo = read("scripts/core/country_geography_manager.gd")
check(
    "جغرافی از economy.inflation",
    'state.get("economy", {}).get("inflation",0.08)' in geo,
    "country_geography_manager باید تورم را از economy بخواند",
)

umap = read("scripts/ui/unified_map.gd")
check(
    "نقشه از economy.inflation",
    'full_state.get("economy", {}).get("inflation", 0.08)' in umap,
    "unified_map باید تورم را از economy بخواند",
)

print()
if FAIL:
    print("==> %d شکست" % len(FAIL))
    sys.exit(1)
print("==> پین‌های منبع تورم سبزند")
