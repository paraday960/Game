#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""پین «عمق جناح‌ها» — بازرسی ۱۴۰۵ (عمق‌بخشی ۴۶).

جناح‌ها از «۳ اکشن ساده + واکنش محدود» به عمق واقعی ارتقا یافتند:
- معامله با جناح (قول در ازای حمایت): هر جناح ۲ معامله با متریک/جهت/آستانه
  دارد؛ بازیکن قول می‌دهد (مثلاً به ارتش: بودجهٔ دفاع ≥ ۱۰٪). در شبیه‌سازی
  محقق‌شدن سنجیده می‌شود: محقق → وفاداری/نفوذ پاداش؛ شکسته → وفاداری
  می‌سوزد (پاسخگویی مثل وعده‌های انتخاباتی).
- واکنش جناح‌ها به قوانین: نخبگان ↔ investment_code/labor_protection/
  anti_corruption_act، ارتش ↔ emergency_powers، رسانه ↔ anti_corruption_act.

این تست پین می‌کند: دادهٔ معاملات، توابع مدیر، سنجش در شبیه‌سازی،
اتصال فرمان، UI و واکنش به قوانین.
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FAIL = []


def read(p):
    return io.open(p, encoding="utf-8").read()


def check(name, cond, msg):
    if not cond:
        FAIL.append(msg)
        print("❌ %s: %s" % (name, msg))
    else:
        print("✅ %s" % name)


fm = read(os.path.join(ROOT, "scripts", "core", "faction_manager.gd"))

# 1) معاملات: هر ۶ جناح ≥۲ معامله با فیلدهای کامل
deal_blocks = re.findall(r'"id": "(\w+)", "title_fa": "[^"]+", "desc_fa": "[^"]+",\s*"metric": "([^"]+)", "direction": "(\w+)", "target": ([0-9.]+), "loyalty": ([0-9.]+), "power": ([0-9.]+)', fm)
check("معاملات کامل", len(deal_blocks) >= 10, "تعداد معاملات: %d" % len(deal_blocks))
for mid, metric, direction, target, loyalty, power in deal_blocks:
    if direction not in ("gte", "lte", "exists"):
        check("جهت معاملهٔ %s" % mid, False, direction)
    if not (1.0 <= float(loyalty) <= 20.0):
        check("پاداش وفاداری %s" % mid, False, loyalty)

# 2) توابع مدیر
for marker in ["func get_deals", "func can_deal", "func make_deal", "func _deal_kept", "func _read_metric"]:
    if marker not in fm:
        check("مدیر: %s" % marker, False, "نیست")

# 3) سنجش در شبیه‌سازی (پاسخگویی)
check("پاداش محقق", '"faction_deal_kept"' in fm and 'deal_def.get("loyalty"' in fm,
      "پاداش معاملهٔ محقق نیست")
check("جریمهٔ شکسته", '"faction_deal_broken"' in fm and "- 18.0" in fm, "جریمهٔ معاملهٔ شکسته نیست")

# 4) واکنش به قوانین
for law in ["investment_code", "labor_protection", "emergency_powers", "anti_corruption_act"]:
    if law not in fm:
        check("واکنش به %s" % law, False, "نیست")

# 5) فرمان و موتور
cmd = read(os.path.join(ROOT, "scripts", "core", "command.gd"))
check("فرمان", "create_faction_deal" in cmd, "create_faction_deal نیست")
eng = read(os.path.join(ROOT, "scripts", "core", "engine.gd"))
for marker in ['"faction_deal"', "FactionManager.can_deal", "FactionManager.make_deal"]:
    if marker not in eng:
        check("موتور: %s" % marker, False, "نیست")

# 6) UI
ui = read(os.path.join(ROOT, "scripts", "ui", "main_ui.gd"))
for marker in ["FactionManager.get_deals", "_on_faction_deal", "facdeal:", "معاملات فعال"]:
    if marker not in ui:
        check("UI: %s" % marker, False, "نیست")

print()
if FAIL:
    print("==> %d شکست" % len(FAIL))
    sys.exit(1)
print("==> پین عمق جناح‌ها سبز است (%d معامله)" % len(deal_blocks))
