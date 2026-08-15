#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""قرارداد عمق‌بخشی ۱۳: نام رهبر انتخابی + دیپلماسی واقعی.

- بازیکن می‌تواند نام رهبر را خودش انتخاب کند (فرمان leader_name + UI).
- دیپلماسی واقعی: کمک بشردوستانه، میانجیگری صلح، بازگشایی سفارت،
  تنش‌زدایی، پیمان دفاعی متقابل (با واکنش جنگ)، دیپلماسی فرهنگی.

خروج غیرصفر = نقض هر بند.
"""
import io
import sys

fail = []

# ── نام رهبر انتخابی ─────────────────────────────────────────────────────
cmd = io.open("scripts/core/command.gd", encoding="utf-8").read()
if 'create_leader_name' in cmd:
    print("✅ command: create_leader_name")
else:
    fail.append("command: create_leader_name نیست")

eng = io.open("scripts/core/engine.gd", encoding="utf-8").read()
for needle, label in [
    ('"leader_name"', "فرمان leader_name در SUPPORTED"),
    ('LeaderManager.set_leader_name', "هندل set_leader_name"),
    ('نام رهبر باید بین ۲ تا ۳۰ نویسه', "اعتبارسنجی طول نام"),
]:
    if needle in eng:
        print("✅ engine: %s" % label)
    else:
        fail.append("engine: %s از دست رفته (%s)" % (label, needle))

lm = io.open("scripts/core/leader_manager.gd", encoding="utf-8").read()
if 'func set_leader_name' in lm and 'state["leader"]["name_fa"]' in lm:
    print("✅ leader_manager: set_leader_name")
else:
    fail.append("leader_manager: set_leader_name نیست")

ui = io.open("scripts/ui/main_ui.gd", encoding="utf-8").read()
for needle, label in [
    ('_on_leader_name_chosen', "UI انتخاب نام"),
    ('create_leader_name', "فرمان از UI"),
]:
    if needle in ui:
        print("✅ UI: %s" % label)
    else:
        fail.append("UI: %s از دست رفته" % label)

# ── دیپلماسی واقعی ──────────────────────────────────────────────────────
wm = io.open("scripts/core/world_manager.gd", encoding="utf-8").read()
for needle, label in [
    ('"humanitarian_aid"', "کمک بشردوستانه"),
    ('"mediate_peace"', "میانجیگری صلح"),
    ('"open_embassy"', "بازگشایی سفارت"),
    ('"de_escalate"', "تنش‌زدایی"),
    ('"defense_pact"', "پیمان دفاعی متقابل"),
    ('"cultural_diplomacy"', "دیپلماسی فرهنگی"),
    ('defense_pact_triggered', "واکنش جنگ به پیمان دفاعی"),
    ('humanitarian_acts', "ثبت کمک‌های بشردوستانه"),
    ('_has_defense_pact', "تابع بررسی پیمان دفاعی"),
]:
    if needle in wm:
        print("✅ world_manager: %s" % label)
    else:
        fail.append("world_manager: %s از دست رفته (%s)" % (label, needle))

for needle, label in [
    ('🤲 کمک بشردوستانه', "دکمه کمک بشردوستانه در UI"),
    ('🛡 پیمان دفاعی متقابل', "دکمه پیمان دفاعی در UI"),
    ('میانجیگری صلح در جنگ‌های جهانی', "بخش میانجیگری در UI"),
    ('create_diplomacy_action', "ارسال فرمان از UI"),
]:
    if needle in ui:
        print("✅ UI دیپلماسی: %s" % label)
    else:
        fail.append("UI دیپلماسی: %s از دست رفته (%s)" % (label, needle))

# ── جمع‌بندی ─────────────────────────────────────────────────────────────
if fail:
    print("\n❌ DEPTH 13 FAILED:")
    for x in fail:
        print("  -", x)
    sys.exit(1)
print("\n=== ✅ DEPTH 13 OK ===")
