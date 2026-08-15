# -*- coding: utf-8 -*-
"""پین پویش «هزینه‌های ثابت تصمیم‌ها» — دور سیزدهم.

قبلاً تصمیم‌ها و زنجیره‌های بحران هزینه‌ی ثابت (۱.۵ تا ۹ میلیارد) روی
economy.national_debt/foreign_reserves می‌نوشتند که با رشد GDP بی‌اثر می‌شدند
(اتم ناقص: هزینه با مقیاس اقتصاد مقیاس نمی‌گرفت). حالا همه‌ی این اثرها باید با
عملگر gdp_ratio (کسر GDP) نوشته شوند تا در شروع بازی (GDP=500e9) دقیقاً همان
عدد قبلی را بدهند و با رشد اقتصاد بزرگ‌تر شوند.

این تست پین می‌کند:
1) هیچ اثر پول ثابت (op=add با value>=1e6) روی national_debt/foreign_reserves
   در decision_manager / event_crisis / crisis_chains نمانده باشد.
2) عملگر gdp_ratio در هر دو اپلایر اثر پیاده شده باشد.
3) نسبت‌های استفاده‌شده با هزینه‌های معادل شروع (÷ 500e9) دقیقاً مطابقت دارند.
4) آینه‌ی پایتونی شبیه‌سازی (sim_crisis_longrun) هم gdp_ratio را می‌فهمد.
"""
import io
import json
import re
import sys

BASE_GDP = 500_000_000_000.0

FAIL = []


def read(p):
    return io.open(p, encoding="utf-8").read()


def check(name, cond, msg):
    if not cond:
        FAIL.append(msg)
        print("❌ %s: %s" % (name, msg))
    else:
        print("✅ %s" % name)


# ── 1) بدون اثر پول ثابت روی مسیرهای مالی ─────────────────────────────
MONEY_PATHS = ("economy.national_debt", "economy.foreign_reserves")
SOURCES = [
    ("scripts/core/decision_manager.gd", read("scripts/core/decision_manager.gd")),
    ("scripts/core/event_crisis_manager.gd", read("scripts/core/event_crisis_manager.gd")),
    ("data/crisis_chains.json", read("data/crisis_chains.json")),
]

fixed_found = []
for path, src in SOURCES:
    # اثر با op=add و value>=1e6 روی مسیرهای مالی
    pat = re.compile(
        r'"path"\s*:\s*"(economy\.(?:national_debt|foreign_reserves))"'
        r'[^}]*?"op"\s*:\s*"add"[^}]*?"value"\s*:\s*(\d{7,})(?:\.\d+)?'
    )
    for m in pat.finditer(src):
        fixed_found.append((path, m.group(1), m.group(2)))
check(
    "بدون هزینه‌ی ثابت",
    not fixed_found,
    "اثر پول ثابت باقی مانده: %s" % (fixed_found[:5] or "—"),
)

# ── 2) عملگر gdp_ratio در هر دو اپلایر ────────────────────────────────
dm = read("scripts/core/decision_manager.gd")
ecm = read("scripts/core/event_crisis_manager.gd")
check(
    "gdp_ratio در DecisionManager",
    '"gdp_ratio"' in dm and "base_gdp" in dm,
    "عملگر gdp_ratio در decision_manager پیاده نشده",
)
check(
    "gdp_ratio در EventCrisisManager",
    '"gdp_ratio"' in ecm and "base_gdp" in ecm,
    "عملگر gdp_ratio در event_crisis_manager پیاده نشده",
)

# ── 3) نسبت‌ها معادل هزینه‌ی شروع هستند ───────────────────────────────
# هزینه‌ی قبلی (میلیارد) → نسبت معادل
EXPECTED = {
    1.5: 0.003, 1.8: 0.0036, 2.0: 0.004, 2.2: 0.0044, 2.5: 0.005,
    2.8: 0.0056, 3.0: 0.006, 4.0: 0.008, 4.5: 0.009, 5.0: 0.01,
    6.0: 0.012, 7.0: 0.014, 9.0: 0.018,
}
EXPECTED_SET = set(EXPECTED.values())

all_ratios = set()
for path, src in SOURCES:
    for m in re.finditer(r'"op"\s*:\s*"gdp_ratio"[^}]*?"value"\s*:\s*([0-9.]+)', src):
        all_ratios.add(round(float(m.group(1)), 4))
    # ترتیب معکوس value قبل از op هم ممکن است در قالب‌بندی متفاوت باشد
    for m in re.finditer(r'"value"\s*:\s*([0-9.]+)[^}]*?"op"\s*:\s*"gdp_ratio"', src):
        all_ratios.add(round(float(m.group(1)), 4))

bad = all_ratios - EXPECTED_SET
check(
    "نسبت‌ها معادل هزینه‌ی شروع",
    not bad,
    "نسبت‌های غیرمنتظره: %s (خارج از مجموعه‌ی معادل ۱.۵-۹ میلیارد)" % sorted(bad),
)
out_of_range = [r for r in all_ratios if not (0.001 <= r <= 0.05)]
check(
    "دامنه‌ی امن نسبت‌ها",
    not out_of_range,
    "نسبت خارج از بازه‌ی 0.001..0.05: %s" % out_of_range,
)

# ── 4) آینه‌ی پایتونی gdp_ratio را می‌فهمد ────────────────────────────
mirror = read("tests/sim_crisis_longrun.py")
check(
    "آینه‌ی پایتونی",
    'op == "gdp_ratio"' in mirror and "value * gdp" in mirror,
    "sim_crisis_longrun.py باید gdp_ratio را پیاده کند (واگرایی با بازی)",
)

# ── 5) بازگشت به هزینه‌ی معادل: مقدار نسبی × GDP شروع = هزینه‌ی قبلی ──
costs = {}
for r in all_ratios:
    costs[r] = r * BASE_GDP / 1e9  # میلیارد
check(
    "هزینه‌ی معادل در شروع",
    all(0.5 <= v <= 15.0 for v in costs.values()),
    "هزینه‌ی معادل شروع خارج از بازه‌ی معقول: %s" % costs,
)

print()
if FAIL:
    print("==> %d شکست" % len(FAIL))
    sys.exit(1)
print("==> همه‌ی پین‌های هزینه‌ی تصمیم سبزند (%d نسبت بررسی شد)" % len(all_ratios))
