#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""قرارداد عمق‌بخشی ۱۲: شخصیت رهبر + داده کلان کشورها + نرخ بهره جهانی.

- هر کشور داده کلان واقعی دارد (inflation_base/interest_rate_base/
  unemployment_base) که در انتخاب کشور به state اعمال می‌شود — ژاپن با تورم
  ~۲٪ و ترکیه با ~۴۰٪ شروع می‌کنند.
- رهبر نام و سن تصادفیِ دترمینستیک دارد (نه «رهبر ملی» بی‌نام).
- بازار مالی جهانی نرخ بهره جهانی (فدرال رزرو/ECB) را شبیه‌سازی می‌کند که
  روی بانک مرکزی داخلی اثر ملایم دارد.

خروج غیرصفر = نقض هر بند.
"""
import io
import json
import re
import sys

fail = []

# ── داده کلان کشورها ─────────────────────────────────────────────────────
countries = json.load(io.open("data/countries.json", encoding="utf-8"))["countries"]
with_macro = [c for c in countries if "inflation_base" in c and "unemployment_base" in c]
if len(with_macro) == len(countries):
    print("✅ همهٔ ۱۹۵ کشور داده کلان دارند")
else:
    fail.append("فقط %d/%d کشور داده کلان دارند" % (len(with_macro), len(countries)))

# نمونه‌های واقعی
sample = {c["id"]: c for c in countries}
for cid, lo, hi in [("JPN", 0.0, 0.05), ("TUR", 0.3, 0.6), ("ARG", 0.3, 0.7), ("DEU", 0.0, 0.05)]:
    if cid in sample:
        v = float(sample[cid].get("inflation_base", 0))
        if lo <= v <= hi:
            print("✅ %s: تورم پایه %.1f%% (واقع‌گرایانه)" % (cid, v * 100))
        else:
            fail.append("%s: تورم پایه نامعتبر %.2f (باید بین %s-%s)" % (cid, v, lo, hi))

# ── اعمال در world_manager ───────────────────────────────────────────────
wm = io.open("scripts/core/world_manager.gd", encoding="utf-8").read()
for needle, label in [
    ('inflation_base', "خواندن تورم پایه"),
    ('unemployment_base', "خواندن بیکاری پایه"),
    ('interest_rate_base', "خواندن نرخ بهره پایه"),
    ('state["central_bank"]["interest_rate"]', "اعمال به بانک مرکزی"),
]:
    if needle in wm:
        print("✅ world_manager: %s" % label)
    else:
        fail.append("world_manager: %s از دست رفته" % label)

# ── شخصیت رهبر ──────────────────────────────────────────────────────────
lm = io.open("scripts/core/leader_manager.gd", encoding="utf-8").read()
for needle, label in [
    ('first_names', "لیست نام‌های فارسی"),
    ('last_names', "لیست نام خانوادگی فارسی"),
    ('"name_fa": "%s %s"', "نام ترکیبی"),
    ('"age": leader_age', "سن تصادفی"),
    ('Deterministic.next_int_range', "دترمینیسم"),
]:
    if needle in lm:
        print("✅ leader_manager: %s" % label)
    else:
        fail.append("leader_manager: %s از دست رفته (%s)" % (label, needle))

ui = io.open("scripts/ui/main_ui.gd", encoding="utf-8").read()
if 'leader.get("name_fa"' in ui and '"سن"' in ui:
    print("✅ UI: نام و سن رهبر نمایش داده می‌شود")
else:
    fail.append("UI: نام/سن رهبر در کارت رهبر نیست")

# ── نرخ بهره جهانی ──────────────────────────────────────────────────────
gm = io.open("scripts/core/global_market_manager.gd", encoding="utf-8").read()
for needle, label in [
    ('global_rate', "نرخ بهره جهانی"),
    ('BASE_GLOBAL_RATE', "نرخ پایه"),
    ('rate_history', "تاریخچه نرخ"),
    ('cb["interest_rate"]', "اثر روی بانک مرکزی داخلی"),
]:
    if needle in gm:
        print("✅ global_market: %s" % label)
    else:
        fail.append("global_market: %s از دست رفته" % label)

# دترمینیسم
if re.search(r'\brand[fi]\(|\.random', lm) or re.search(r'\brand[fi]\(|\.random', gm):
    fail.append("RNG خام در leader/global_market — دترمینیسم شکسته")

# ── جمع‌بندی ─────────────────────────────────────────────────────────────
if fail:
    print("\n❌ DEPTH 12 FAILED:")
    for x in fail:
        print("  -", x)
    sys.exit(1)
print("\n=== ✅ DEPTH 12 OK ===")
