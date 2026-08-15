#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""پین «سقف آرایه‌های state» — بازرسی ۱۴۰۵ (عمق‌بخشی ۴۱).

پویش رشد نامحدود: آرایه‌های state که در simulate (روزانه/ماهانه) با .append()
رشد می‌کنند ولی هیچ سقف سنی/اندازه‌ای ندارند = نشت حافظهٔ state در بازی
بلندمدت (هر سال حجم ذخیره/شبکه بزرگ‌تر می‌شود).

بررسی سراسری نشان داد اکثر آرایه‌ها سقف دارند:
- npc_turn_plans (MAX_PLAN_TURNS)، war_history (≤۵۰)، decision_history (≤۲۰۰)
- analytics.history (≤۱۲۰)، weather.history (≤۳۶)، special_events (انقضا)
- battle_plans (≤۱۸۰ روز)، constructions (≤۳۶۵ روز)، pending_commands (clear)
- buildings: **باگ واقعی** — بعد از ۵ سال هم دوباره append می‌شد (هرگز حذف
  نمی‌شد) → سقف ۱۰ ساله اضافه شد (بعد از ۱۰ سال بدون نوسازی، ساختمان از بین
  می‌رود). این تست درمان را پین می‌کند.

این تست پین می‌کند:
1) buildings در map_advanced_system سقف سنی دارد (else بعد از ۱۰ سال حذف).
2) هیچ آرایه‌ی state در سیستم‌ها با الگوی «append بدون سقف» بازنگردد
   (هیوریستیک: append در simulate بدون هیچ while/pop_front/slice/MAX در همان تابع).
"""
import io
import os
import re
import sys
import glob

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = os.path.join(ROOT, "scripts")
FAIL = []


def read(p):
    return io.open(p, encoding="utf-8").read()


def check(name, cond, msg):
    if not cond:
        FAIL.append(msg)
        print("❌ %s: %s" % (name, msg))
    else:
        print("✅ %s" % name)


# 1) پین درمان buildings
mas = read(os.path.join(SCRIPTS, "systems", "map_advanced_system.gd"))
check(
    "buildings سقف سنی دارد",
    "age < 365*10" in mas and "فرسوده و از دور خارج می‌شود" in mas,
    "سقف ۱۰ سالهٔ buildings حذف شده — نشت حافظه برمی‌گردد",
)

# 2) پویش append بدون سقف در simulate (هیوریستیک)
TRIM = re.compile(r"pop_front|pop_back|resize\(|slice\(|\.clear\(\)|while .*size\(\)|if .*size\(\) >|MAX_|until_tick|expires|expire")
LOCAL_ARRAYS = {
    "events", "result", "out", "points", "values", "chosen", "last", "cmds",
    "rows", "pool", "candidates", "fails", "bad", "items", "samples", "tmp",
    "temp", "list", "founds", "hits", "cities", "units", "fronts",
    "active_attacks", "wars_arr", "war_list", "queued", "all", "owned",
    "recommendations", "picked", "new_missions", "fresh", "live_offers",
    "turn_plans", "plans", "targets", "names", "matches", "codes", "nearby",
    "selected", "eligible_hubs", "kept", "filtered", "clean", "committed",
    "consumed", "traits", "a_traits", "active_plans", "active_constructions",
    "active_buildings", "slots", "entries", "ranked", "unlocked", "available",
    "migrated", "objectives", "promises", "occupied", "countries_to_show",
    "participants", "translated", "prerequisite_names", "unlocked_names",
    "lines", "matches", "shade_pts", "_confetti", "_stars", "_shooting_stars",
    "_dust", "_note_cache", "_unit_screen_records", "_city_screen_records",
    "tick_events", "generated_events",  # محلیِ هر تیک (در state ذخیره نمی‌شوند)
}

suspicious = []
for f in sorted(glob.glob(os.path.join(SCRIPTS, "**", "*.gd"), recursive=True)):
    rel = os.path.relpath(f, ROOT).replace(os.sep, "/")
    lines = read(f).splitlines()
    for i, line in enumerate(lines):
        if ".append(" not in line:
            continue
        # تابع میزبان
        start = None
        for j in range(i, -1, -1):
            if re.match(r"^func \w+\(", lines[j]):
                start = j
                break
        if start is None:
            continue
        end = len(lines)
        for j in range(start + 1, len(lines)):
            if re.match(r"^func |^class ", lines[j]):
                end = j
                break
        func_body = "\n".join(lines[start:end])
        # اگر تابع simulate نیست و آرایه محلی است، رد شو
        if not re.search(r"simulate|_tick|update|compute|plan_npc_turn", "\n".join(lines[start:start+2])):
            continue
        if TRIM.search(func_body):
            continue  # سقف دارد
        m = re.search(r"([\w]+)\.append\(", line)
        if not m:
            continue
        arr = m.group(1)
        if arr in LOCAL_ARRAYS:
            continue
        # آرایه‌ی state واقعی (از state.get یا state[...] می‌آید)
        suspicious.append((rel, i + 1, arr, line.strip()[:80]))

check(
    "بدون append بدون سقف در simulate",
    not suspicious,
    "موردهای مشکوک: %s" % (suspicious[:8] or "—"),
)
for s in suspicious:
    print("  ⚠️ بررسی دستی: %s" % (s,))

print()
if FAIL:
    print("==> %d شکست" % len(FAIL))
    sys.exit(1)
print("==> پین سقف آرایه‌های state سبز است")
