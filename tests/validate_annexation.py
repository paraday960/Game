#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""قرارداد تسخیر کشورها (Annexation) — بازرسی ۱۴۰۵ دور سیزدهم.

جنگ‌ها باید بتوانند به تسخیر کامل کشور بازنده بینجامند (مثل دنیای واقعی):
- بازیکن: هدف «الحاق و سلطه» + همسایه + پیروزی → الحاق کامل (ضمیمهٔ خاک،
  انتقال اقتصاد/جمعیت/توانایی، نمایش با رنگ برنده روی نقشه).
- NPC: برنده در پیروزی قاطع (نه تایماوت) می‌تواند همسایه را ضمیمه کند.
- کشور ضمیمه‌شده: مستقل نیست — از بازی راهبردی NPC، اخبار، رشد خودکار و
  روابط/ائتلاف/تجارت/جنگ حذف می‌شود ولی روی نقشه (با رنگ برنده) می‌ماند.
- دترمینیسم: فقط Deterministic.chance (بدون RNG خام).

خروج غیرصفر = بازگشت «جنگ بدون تسخیر».
"""
import io
import re
import sys

fail = []

# ── الحاق کامل بازیکن ───────────────────────────────────────────────────
wm = io.open("scripts/core/world_manager.gd", encoding="utf-8").read()
for needle, label in [
    ('"full": true', "پرچم الحاق کامل در annexations"),
    ('war_full_annexation', "رویداد پیروزی/الحاق کامل بازیکن"),
    ('enemy["annexed_by"] = player_id', "ست کردن annexed_by (نقشه با رنگ برنده)"),
    ('enemy["annexed"] = true', "پرچم annexed روی کشور بازنده"),
    ('_cleanup_annexed(world, target)', "پاک‌سازی ارجاع‌های کشور ضمیمه‌شده (بازیکن)"),
    ('enemy_gdp * 0.6', "انتقال ۶۰٪ اقتصاد دشمن"),
]:
    if needle in wm:
        print("✅ الحاق بازیکن: %s" % label)
    else:
        fail.append("الحاق بازیکن: %s از دست رفته (%s)" % (label, needle))

# ── الحاق NPC ───────────────────────────────────────────────────────────
for needle, label in [
    ('func _annex_npc_country', "تابع الحاق NPC"),
    ('"npc": true', "پرچم الحاق NPC"),
    ('npc_annexation', "رویداد الحاق NPC"),
    ('Deterministic.chance(0.40)', "شانس دترمینستیک الحاق NPC"),
    ('decisive := abs(float(war["progress"])) >= 100.0', "فقط پیروزی قاطع (نه تایماوت)"),
    ('_annex_npc_country(state, winner, loser', "فراخوانی در پایان جنگ NPC"),
]:
    if needle in wm:
        print("✅ الحاق NPC: %s" % label)
    else:
        fail.append("الحاق NPC: %s از دست رفته (%s)" % (label, needle))

# ── پاک‌سازی (cleanup) ──────────────────────────────────────────────────
for needle, label in [
    ('func _cleanup_annexed', "تابع پاک‌سازی ارجاع‌ها"),
    ('world["npc_wars"] = kept_war', "حذف از جنگ‌های NPC"),
    ('world["npc_alliances"] = kept', "حذف از ائتلاف‌های NPC"),
    ('world["npc_trade_agreements"] = kept', "حذف از توافق‌های تجاری NPC"),
    ('world["npc_relations"] = kept_rel', "حذف از روابط NPC"),
    ('world["incoming_offers"] = kept_offers', "حذف از پیشنهادهای ورودی"),
]:
    if needle in wm:
        print("✅ پاک‌سازی: %s" % label)
    else:
        fail.append("پاک‌سازی: %s از دست رفته (%s)" % (label, needle))

# ── فیلتر کشورهای ضمیمه‌شده ─────────────────────────────────────────────
for needle, label in [
    ('get_strategic_country_ids(player_id: String = "", limit: int = 40, state: Dictionary = {})',
     "پارامتر state برای فیلتر راهبردی"),
    ('runtime_map.get(id, {}).get("annexed_by", "")', "فیلتر annexed در کشورهای راهبردی"),
    ('runtime.get("annexed_by", "")', "توقف رشد خودکار کشور ضمیمه‌شده"),
]:
    if needle in wm:
        print("✅ فیلتر: %s" % label)
    else:
        fail.append("فیلتر: %s از دست رفته (%s)" % (label, needle))

fa = io.open("scripts/core/foreign_ai_manager.gd", encoding="utf-8").read()
if 'get_strategic_country_ids(player_id, 40, state)' in fa:
    print("✅ foreign_ai: state به فیلتر راهبردی پاس داده می‌شود")
else:
    fail.append("foreign_ai: state به get_strategic_country_ids پاس داده نشده")
if 'annexed_by' in fa:
    print("✅ foreign_ai: کشورهای ضمیمه‌شده از تصمیم‌گیری حذف می‌شوند")
else:
    fail.append("foreign_ai: گارد annexed در حلقهٔ تصمیم از دست رفته")

nm = io.open("scripts/core/news_manager.gd", encoding="utf-8").read()
if 'annexed_by' in nm and 'codes.append' in nm:
    print("✅ news: کشورهای ضمیمه‌شده خبر مستقل ندارند")
else:
    fail.append("news: فیلتر annexed در اخبار از دست رفته")

# ── دترمینیسم ───────────────────────────────────────────────────────────
if re.search(r'\brand[fi]\(|\.random|pick_random', wm):
    fail.append("world_manager: RNG خام استفاده شده — دترمینیسم را می‌شکند")
else:
    print("✅ دترمینیسم: بدون RNG خام (فقط Deterministic)")

# ── جمع‌بندی ─────────────────────────────────────────────────────────────
if fail:
    print("\n❌ ANNEXATION FAILED:")
    for x in fail:
        print("  -", x)
    sys.exit(1)
print("\n=== ✅ ANNEXATION OK ===")
