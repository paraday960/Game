#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""پین «میزبانی رویداد بزرگ جهانی» — بازرسی ۱۴۰۵ (عمق‌بخشی ۴۳).

قابلیت جدید: بازیکن برای رویدادهای بزرگ (جام جهانی/المپیک/اکسپو/گرندپری)
نامزد می‌شود؛ موفقیت به زیرساخت/ثبات/قدرت نرم/گردشگری بستگی دارد؛ در حین
میزبانی گردشگری و قدرت نرم جهش می‌کند؛ پس از آن میراث ماندگار (یا «فیل
سفید» اگر زیرساخت ضعیف بود).

این تست پین می‌کند:
1) داده‌ی mega_events.json معتبر و کامل است (≥۳ رویداد، همه‌ی فیلدها).
2) فرمان mega_event در SUPPORTED_COMMANDS و command.gd و validation ثبت شده.
3) MegaEventManager در simulate_month موتور فراخوانی می‌شود.
4) مدیر، مدیر/داده‌ی اتصال کامل دارند (autoload در project.godot).
5) نام فارسی سیستم (SYSTEM_FA) و اهمیت رویداد (EVENT_IMPORTANT_HINTS) هست.
"""
import io
import json
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


# 1) داده
data = json.load(io.open(os.path.join(ROOT, "data", "mega_events.json"), encoding="utf-8"))
events = data.get("events", [])
check("داده‌ی رویدادها معتبر", len(events) >= 3, "تعداد رویدادها: %d" % len(events))
required = {"id", "name_fa", "icon", "description_fa", "bid_cost_gdp_ratio",
            "duration_months", "monthly_tourism_gdp_ratio", "soft_power_gain",
            "happiness_gain", "legacy_tourism_base", "legacy_soft_power"}
missing = []
for e in events:
    for f in required:
        if f not in e:
            missing.append((e.get("id"), f))
check("فیلدهای رویدادها کامل", not missing, "نقص: %s" % (missing or "—"))
ids = [e.get("id") for e in events]
check("شناسه‌ها یکتا", len(ids) == len(set(ids)), "تکراری: %s" % ids)
for e in events:
    ratio = float(e.get("bid_cost_gdp_ratio", 0))
    if not (0.005 <= ratio <= 0.05):
        check("هزینه‌ی نامزدی معقول", False, "%s: %s" % (e.get("id"), ratio))
        break

# 2) فرمان
eng = read(os.path.join(ROOT, "scripts", "core", "engine.gd"))
check("فرمان در SUPPORTED_COMMANDS", '"mega_event"' in eng, "mega_event در SUPPORTED نیست")
check("validation دارد", 'cmd.type == "mega_event"' in eng, "validation mega_event نیست")
check("apply دارد", "MegaEventManager.bid(snapshot" in eng, "apply mega_event نیست")
check("simulate_month موتور وصل است", "MegaEventManager.simulate_month(snapshot, turn)" in eng,
      "simulate ماهانهٔ mega_event در engine نیست")
cmd = read(os.path.join(ROOT, "scripts", "core", "command.gd"))
check("سازنده‌ی فرمان", "create_mega_event_action" in cmd and '"mega_event"' in cmd,
      "create_mega_event_action در command.gd نیست")

# 3) مدیر و autoload
mg = read(os.path.join(ROOT, "scripts", "core", "mega_event_manager.gd"))
for marker in ["func bid", "func can_bid", "func simulate_month", "reserve_inflows",
               "sector_boosts", "soft_power", "white_elephant"]:
    if marker not in mg:
        check("مدیر: %s" % marker, False, "در mega_event_manager.gd نیست")
proj = read(os.path.join(ROOT, "project.godot"))
check("autoload ثبت شده", 'MegaEventManager="*res://scripts/core/mega_event_manager.gd"' in proj,
      "autoload MegaEventManager نیست")

# 4) UI
ui = read(os.path.join(ROOT, "scripts", "ui", "main_ui.gd"))
check("کارت UI دارد", "func _build_mega_event_card" in ui and "_build_mega_event_card(st)" in ui,
      "کارت میزبانی در UI نیست")
check("نام فارسی سیستم", '"mega_event": "میزبانی رویداد جهانی"' in ui, "SYSTEM_FA برای mega_event نیست")
m = re.search(r'EVENT_IMPORTANT_HINTS\s*:=\s*\[(.*?)\]', ui, re.S)
check("اهمیت رویداد", bool(m) and '"mega_event"' in m.group(1),
      "mega_event در EVENT_IMPORTANT_HINTS نیست")

print()
if FAIL:
    print("==> %d شکست" % len(FAIL))
    sys.exit(1)
print("==> پین میزبانی رویداد جهانی سبز است (%d رویداد)" % len(events))
