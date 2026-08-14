#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""اعتبارسنج latch/cooldown رویدادها و اقدام‌ها.

قرارداد پروژه برای هر کلید «last_x» در state:
- R1) اگر در گارد زمانی (turn/tick - last_x ...) خوانده می‌شود، باید حداقل یک نوشتن
  واقعی (``"last_x"] = ...``) در همان مسیر اقدام/رویداد وجود داشته باشد؛ وگرنه کول‌داون
  مرده است و اقدام هر نوبت اسپم می‌شود.
- R2) ساعت خواندن و نوشتن باید هم‌خانواده باشد (turn=ماه به turn، tick به tick)؛ هر
  مقایسهٔ tick(روز) با last_x که با turn نوشته شده خطای واحد است (×۳۰ یا ÷۳۰).
- R3) کلید init-only (فقط در دیکشنری اولیه/ensure آمده، بدون هیچ نوشتن واقعی) یا حذف شود
  یا با توجیه در فهرست سفید ثبت شود — latch یتیم مساوی است با کول‌داون ناموجود.

فهرست سفید (هر مورد با دلیل):
- last_sample_tick (analytics_manager): خواندن فقط در مسیر مهاجرت اسکیمای قدیمی
  (fallback از کلید منسوخ به last_sample_turn و بلافاصله erase) — latch نیست.
- last_pension (demographic_manager/state): لچ مهاجرت‌یافته به welfare_policy.last_pension؛
  نسخهٔ قدیمی فقط برای سازگاری سیوهای قبلی باقی است (اقدام جدیدی به آن دست نمی‌زند).

کلیدهای اصلاح‌شده در این بازرسی (دیگر یتیم نیستند):
- welfare_policy.last_pension: گارد ۱۲نوبته در WelfareManager.set_pension_age + نوشتن。
- cyber.last_attack: گارد ۳نوبته در CyberManager.cyber_attack + نوشتن (init -99).
- daily_reward last_day → current_day تغییر نام یافت تا با قرارداد last_* اشتباه نشود.
"""
import glob, re, sys, collections

FAIL = []
WHITELIST = {
    "last_sample_tick",  # مسیر مهاجرت اسکیمای قدیمی در analytics_manager (خوانده→erase می‌شود)
    "last_pension",      # مهاجرت‌یافته به welfare_policy.last_pension (بازرسی latch)
}

files = sorted(glob.glob("scripts/**/*.gd", recursive=True))
stat = collections.defaultdict(lambda: {"w": [], "r": [], "init": []})

for f in files:
    for i, line in enumerate(open(f, encoding="utf-8"), 1):
        if line.strip().startswith("#"):
            continue
        for m in re.finditer(r'"(last_[a-z_]+)"', line):
            key = m.group(1)
            after = line[m.end():]
            clock = "turn" if re.search(r"\bturn\b", line) else ("tick" if re.search(r"\btick\b", line) else None)
            if re.match(r"^\s*\]\s*=[^=]", after):
                stat[key]["w"].append((f, i, clock))
            elif re.match(r"^\s*:", after):
                stat[key]["init"].append((f, i, clock))
            elif re.search(r"(turn|tick)\s*-\s*int\(", line) or ".get(\"" + key + "\"" in line and re.search(r"[<>=!]=?", line):
                stat[key]["r"].append((f, i, clock))

# R1: خوانده ولی ننوشته (کول‌داون مرده)
for key in sorted(stat):
    if key in WHITELIST:
        continue
    if stat[key]["r"] and not stat[key]["w"]:
        loc = stat[key]["r"][0]
        FAIL.append("R1 کول‌داون مرده «%s» — در %s:%d گارد خوانده می‌شود ولی هیچ‌جا نوشته نمی‌شود" % (key, loc[0], loc[1]))

# R2: تناقض ساعت در یک فایل
for key in sorted(stat):
    if key in WHITELIST:
        continue
    by_file_w = collections.defaultdict(set)
    by_file_r = collections.defaultdict(set)
    for f, i, c in stat[key]["w"]:
        if c:
            by_file_w[f].add(c)
    for f, i, c in stat[key]["r"]:
        if c:
            by_file_r[f].add(c)
    for f in by_file_w:
        if f in by_file_r and by_file_w[f] != by_file_r[f] and "turn" in (by_file_w[f] | by_file_r[f]):
            FAIL.append("R2 تناقض ساعت «%s» در %s — نوشتن:%s خواندن:%s" % (key, f, sorted(by_file_w[f]), sorted(by_file_r[f])))

# R3: init-only بدون هیچ استفادهٔ منطقی (یتیم کامل)
for key in sorted(stat):
    if key in WHITELIST:
        continue
    if stat[key]["init"] and not stat[key]["w"] and not stat[key]["r"]:
        loc = stat[key]["init"][0]
        FAIL.append("R3 latch یتیم «%s» در %s:%d — فقط مقدار اولیه دارد؛ یا حذف یا به‌کار ببرید یا فهرست سفید با توجیه" % (key, loc[0], loc[1]))

if FAIL:
    print("❌ بازرسی latch/cooldown شکست خورد:")
    for x in FAIL:
        print("  • " + x)
    sys.exit(1)
ok_keys = sum(1 for k in stat if stat[k]["w"] and stat[k]["r"])
print("✅ بازرسی latch: %d کلید last_* با جفت نوشتن+خواندن سالم؛ %d کلید در فهرست سفید موجّه" % (ok_keys, len(WHITELIST)))
