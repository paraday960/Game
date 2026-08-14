#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""قرارداد لایه‌ی واکنشگری (Reactivity Layer) — بازرسی ۱۴۰۵ دور سیزدهم.

در دنیای واقعی، اخبار و واکنش کشورها به وضعیت واقعی گره خورده است؛ این تست
پین می‌کند که:

اخبار (news_manager.gd):
- خبر تورم/رشد/بیکاری/رضایت/ثبات شرطی است: وقتی شاخص بحرانی است، خبر منفی
  (رکود/هشدار تورم/بحران اشتغال/نارضایتی/بی‌ثباتی) منتشر می‌شود نه خبر مثبت قالبی.
- هر بحران فعال به‌صورت جداگانه گزارش می‌شود؛ نخ‌ها «مرحلهٔ x/y: نام» دارند.
- خبر بازار جهانی کالا (_world_market_news) وجود دارد و به قیمت‌های واقعی
  commodities (نفت/گاز/گندم/فلزات) واکنش نشان می‌دهد.

واکنش جهان (foreign_ai_manager.gd):
- _crisis_reaction وجود دارد و از simulate_month فراخوانی می‌شود.
- دشمن در بحران بازیکن فرصت‌طلب می‌شود (تحریم/جنگ) و متحد پیشنهاد کمک می‌دهد.

خروج غیرصفر = بازگشت اخبار/واکنش‌های قالبیِ بی‌رابطه با وضعیت.
"""
import io
import re
import sys

fail = []

# ── اخبار واکنشگر ────────────────────────────────────────────────────────
nm = io.open("scripts/core/news_manager.gd", encoding="utf-8").read()
for needle, label in [
    ('"رکود اقتصادی؛ رشد', "خبر شرطی رکود (رشد منفی)"),
    ('هشدار: تورم', "خبر شرطی تورم بالا"),
    ('بحران اشتغال', "خبر شرطی بیکاری بالا"),
    ('نارضایتی گسترده', "خبر شرطی نارضایتی"),
    ('بی‌ثباتی سیاسی', "خبر شرطی بی‌ثباتی"),
    ('stage_name_fa', "گزارش مرحله‌ای نخ‌های بحران"),
    ('func _world_market_news', "خبر بازار جهانی کالا"),
    ('"شوک جهانی غذا؛ قیمت گندم', "خبر شوک جهانی غذا"),
    ('"بازار جهانی نفت', "خبر بازار جهانی نفت"),
]:
    if needle in nm:
        print("✅ news_manager: %s" % label)
    else:
        fail.append("news_manager: %s از دست رفته (%s)" % (label, needle))

# دترمینیسم اخبار: نباید RNG خام داشته باشد (Deterministic مجاز است)
if re.search(r'\brand[fi]\(|\.random|pick_random', nm):
    fail.append("news_manager: RNG خام استفاده شده — دترمینیسم را می‌شکند")
else:
    print("✅ news_manager: بدون RNG خام (دترمینیسم حفظ شده)")

# ── واکنش جهان به بحران بازیکن ───────────────────────────────────────────
fa = io.open("scripts/core/foreign_ai_manager.gd", encoding="utf-8").read()
for needle, label in [
    ('func _crisis_reaction', "تابع _crisis_reaction"),
    ('crisis_action = _crisis_reaction', "فراخوانی از simulate_month"),
    ('foreign_sanction', "واکنش تحریمی دشمن"),
    ('foreign_war_declared', "واکنش جنگی دشمن"),
    ('توافق تجاری ترجیحی', "پیشنهاد کمک متحد"),
]:
    if needle in fa:
        print("✅ foreign_ai: %s" % label)
    else:
        fail.append("foreign_ai: %s از دست رفته (%s)" % (label, needle))

# ── پاشش قیمت کالاها به اقتصاد جهان ──────────────────────────────────────
wm = io.open("scripts/core/world_manager.gd", encoding="utf-8").read()
for needle, label in [
    ('func _commodity_growth_effect', "تابع اثر کالا روی رشد NPC"),
    ('_commodity_growth_effect(str(country_id)', "فراخوانی در simulate_npc_month"),
    ('OIL_EXPORTERS', "لیست صادرکنندگان نفت"),
    ('wheat_price > 380.0', "اثر گرانی گندم بر کم‌درآمدها"),
    ('func _player_crisis_weight', "تابع شاخص بحران‌زایی بازیکن"),
    ('regional_contagion', "سرایت منطقه‌ای بحران به همسایگان"),
    ('player_borders', "استفاده از مرزهای واقعی برای سرایت"),
]:
    if needle in wm:
        print("✅ world_manager: %s" % label)
    else:
        fail.append("world_manager: %s از دست رفته (%s)" % (label, needle))

# ── جمع‌بندی ─────────────────────────────────────────────────────────────
if fail:
    print("\n❌ REACTIVITY LAYER FAILED:")
    for x in fail:
        print("  -", x)
    sys.exit(1)
print("\n=== ✅ REACTIVITY LAYER OK ===")
