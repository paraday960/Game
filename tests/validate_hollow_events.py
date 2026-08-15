#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""قرارداد «رویدادهای بی‌اثر» — بازرسی ۱۴۰۵ دور سیزدهم (عمق‌بخشی ۱۴).

بررسیِ منطقِ بازی: هر رویداد (events.append با پیامِ ادعایِ اثر) باید اثرِ
واقعی روی state داشته باشد — نه فقط «پیام توخالی». این قرارداد فهرستِ
رویدادهای درمان‌شده را پین می‌کند تا «رویدادهای توخالی» (مثل ai_boom که
می‌گفت «بهره‌وری جهش کرد» ولی هیچ کاری نمی‌کرد) برنگردند.

خروج غیرصفر = بازگشت هر رویداد بی‌اثر.
"""
import io
import re
import sys

fail = []

# ── رویدادهای درمان‌شده + اثر موردانتظارشان (پین) ────────────────────────
# هر ورودی: (فایل، نوع رویداد، الگوی اثری که باید کنارش باشد)
PINS = [
    ("scripts/core/ai_industry_manager.gd", "ai_boom", 'sector_boosts'),
    ("scripts/core/basic_industry_manager.gd", "steel_export", 'reserve_inflows'),
    ("scripts/core/blue_economy_manager.gd", "port_hub", 'reserve_inflows'),
    ("scripts/core/blue_economy_manager.gd", "coast_patrol", 'shadow'),
    ("scripts/core/creative_manager.gd", "games_boom", 'sector_boosts'),
    ("scripts/core/demographic_manager.gd", "demographic_dividend", 'sector_boosts'),
    ("scripts/core/demographic_manager.gd", "aging_society", 'pension_pressure_structural'),
    ("scripts/core/demographic_manager.gd", "baby_boom", 'birth_rate'),
    ("scripts/core/downstream_energy_manager.gd", "petrochem_boom", 'reserve_inflows'),
    ("scripts/core/housing_manager.gd", "housing_boom", 'sector_boosts'),
    ("scripts/core/intellectual_property_manager.gd", "patent_boom", 'sector_boosts'),
    ("scripts/core/mining_manager.gd", "mining_boom", 'sector_boosts'),
    ("scripts/core/pharma_manager.gd", "pharma_export", 'reserve_inflows'),
    ("scripts/core/sme_manager.gd", "sme_boom", 'sector_boosts'),
    ("scripts/core/startup_manager.gd", "startup_boom", 'sector_boosts'),
    ("scripts/core/textile_manager.gd", "textile_export", 'reserve_inflows'),
    ("scripts/core/tourism_manager.gd", "tourism_boom", 'revenue'),
    ("scripts/core/tourism_manager.gd", "tourism_slump", 'revenue'),
    ("scripts/core/waste_manager.gd", "circular_win", 'sector_boosts'),
    ("scripts/core/world_manager.gd", "war_defeat_terms", 'national_debt'),
    ("scripts/core/election_manager.gd", "election_legitimacy", 'legitimacy'),
    ("scripts/core/food_value_chain_manager.gd", "food_waste", 'food_security'),
    ("scripts/core/insurance_manager.gd", "insurance_resilience", 'stability'),
    ("scripts/core/science_diplomacy_manager.gd", "brain_gain", 'research_rate'),
    ("scripts/core/rural_manager.gd", "rural_depopulation", 'urban_ratio'),
    ("scripts/core/rural_manager.gd", "rural_revival", 'urban_ratio'),
    ("scripts/core/civil_defense_manager.gd", "cd_gap", 'preparedness'),
    ("scripts/core/downstream_energy_manager.gd", "fuel_import", 'fuel_security'),
    ("scripts/core/forex_manager.gd", "policy_flipflop", 'independence'),
    ("scripts/core/prison_manager.gd", "rehab_success", 'rehabilitation'),
]

for path, ev_type, effect_needle in PINS:
    try:
        src = io.open(path, encoding="utf-8").read()
    except OSError:
        fail.append("%s: فایل پیدا نشد" % path)
        continue
    if ev_type not in src:
        fail.append("%s: رویداد «%s» حذف شده (نباید حذف می‌شد)" % (path, ev_type))
        continue
    # اثر باید در ۵ خطِ اطرافِ رویداد باشد
    lines = src.splitlines()
    idx = None
    for i, l in enumerate(lines):
        if ev_type in l and "events.append" in l:
            idx = i
            break
    if idx is None:
        # رویداد در جای دیگر تعریف شده (مثلاً ساختار داده) — رد نکن
        continue
    ctx = "\n".join(lines[max(0, idx - 6):idx + 2])
    if effect_needle not in ctx:
        fail.append("%s: رویداد «%s» بی‌اثر است (اثر %s در ±۶ خط نیست)" % (path, ev_type, effect_needle))

# ── پویش سراسری: رویدادهای با ادعای اثر ولی بدون هیچ assignment در بلوک if ──
import os
EFFECT_WORDS = ["جهش", "افزایش", "کاهش", "سقوط", "رونق", "تقویت", "آسیب", "فشار", "بهبود", "ارزآور", "بازگشت", "تضعیف", "رشد"]
for dp, _, files in os.walk("scripts/core"):
    for fn in files:
        if not fn.endswith(".gd") or fn.endswith(".uid"):
            continue
        p = os.path.join(dp, fn)
        lines = io.open(p, encoding="utf-8").read().splitlines()
        for i, line in enumerate(lines):
            if "events.append" in line and "message" in line:
                if not any(w in line for w in EFFECT_WORDS):
                    continue
                # پیدا کردن شروع بلوک if
                indent = len(line) - len(line.lstrip())
                block_start = i
                for j in range(i, -1, -1):
                    s = lines[j].strip()
                    ci = len(lines[j]) - len(lines[j].lstrip())
                    if ci < indent and (s.startswith("if ") or s.startswith("elif ") or s.startswith("for ")):
                        block_start = j
                        break
                block = "\n".join(lines[max(0, block_start - 1):i + 1])
                # اثر با هر عملگر (=, +=, -=, *=, /=) و حتی در ۳ خط قبل از if
                has_effect = bool(re.search(r'\["[^"]+"\]\s*[+\-*/]?=', block)) \
                    or bool(re.search(r'\b[a-z_]+\s*\*?=\s*\d', block))
                # رد کردن رویدادهای شناخته‌شده (خروجی از DecisionManager و وضعیت‌ها)
                known_special = ["decision", "crisis_stage", "dilemma", "war_", "incoming_offer", "offer_", "world_opinion"]
                if not has_effect and not any(k in line for k in known_special):
                    # اگر رویداد در فهرست پین‌ها نبود و بی‌اثر بود — هشدار جدی
                    fail.append("%s:%d: رویداد بی‌اثر جدید: %s" % (p.replace("scripts/core/", ""), i + 1, line.strip()[:70]))

if fail:
    print("\n❌ HOLLOW EVENTS FAILED:")
    for x in fail:
        print("  -", x)
    sys.exit(1)
print("\n=== ✅ HOLLOW EVENTS OK ===")
