#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""پین «اقدامات فعال رهبر» — بازرسی ۱۴۰۵ (عمق‌بخشی ۴۷).

رهبر قبلاً فقط ۳ فرمان داشت (نام، پنهان/آشکار، ترور). حالا به‌عنوان رهبر
می‌توانی واقعاً «عمل» کنی:
- 🎤 سخنرانی عمومی (امیدبخش/قاطع/متحدکننده): واکنش به وضعیت کشور — در
  بحران امید واقعی می‌دهد؛ در رفاه «حرف بی‌عمل» اعتماد می‌سوزاند.
- 👤 سبک رهبری (متعادل/مردمی/اقتدارگرا/تکنوکرات): اثر ماهانه سراسری —
  مردمی: شادی↑/نخبگان↓؛ اقتدارگرا: ثبات↑/رسانه↓/تنش↑؛ تکنوکرات:
  دانشمندان↑ (منبع واقعی پژوهش).
- 🏃 حضور میدانی در بحران: تقویت ۳ ماههٔ ثبات و رضایت.
همه با هزینهٔ سرمایه سیاسی + کولداون (سخنرانی ۳ ماه، حضور ۶ ماه).

این تست پین می‌کند: کلیدهای state، توابع مدیر، اثر ماهانهٔ سبک،
اتصال فرمان (validation شامل کولداون)، UI و queue_key.
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


lm = read(os.path.join(ROOT, "scripts", "core", "leader_manager.gd"))

# 1) کلیدهای state
for key in ['"style"', '"last_speech_turn"', '"last_presence_turn"', '"presence_boost_until"']:
    if key not in lm:
        check("state: %s" % key, False, "کلید در leader_manager نیست")

# 2) توابع مدیر
for marker in ["func can_speech", "func speech", "func can_style", "func set_style",
               "func can_presence", "func presence", "const STYLES", "func get_style_name"]:
    if marker not in lm:
        check("مدیر: %s" % marker, False, "نیست")

# 3) سه تن سخنرانی + حرف بی‌عمل
for tone in ["hope", "resolve", "unite"]:
    if '"%s"' % tone not in lm:
        check("تن سخنرانی %s" % tone, False, "نیست")
check("حرف بی‌عمل", "حرف بی‌عمل" in lm, "واکنش به وضعیت خوب (حرف بی‌عمل) نیست")

# 4) سبک‌ها و اثر ماهانه
for style in ["moderate", "populist", "authoritarian", "technocrat"]:
    if '"%s"' % style not in lm:
        check("سبک %s" % style, False, "نیست")
check("اثر تکنوکرات", 'elites2["scientific"]' in lm, "اثر تکنوکرات روی دانشمندان نیست")
check("اثر مردمی", 'pop2["happiness"]' in lm and '"نخبگان اقتصادی"' in lm, "اثر مردمی نیست")
check("اثر اقتدارگرا", 'media_freedom' in lm, "اثر اقتدارگرا نیست")

# 5) فرمان و موتور
cmd = read(os.path.join(ROOT, "scripts", "core", "command.gd"))
check("فرمان", "create_leader_action" in cmd, "create_leader_action نیست")
eng = read(os.path.join(ROOT, "scripts", "core", "engine.gd"))
for marker in ['"leader_action"', "LeaderManager.can_speech", "LeaderManager.presence", "LeaderManager.set_style"]:
    if marker not in eng:
        check("موتور: %s" % marker, False, "نیست")

# 6) UI
ui = read(os.path.join(ROOT, "scripts", "ui", "main_ui.gd"))
for marker in ["اقدامات رهبر", "_on_leader_speech", "_on_leader_style", "_on_leader_presence",
               "leaderspeech:", "leaderstyle:", "leaderpresence"]:
    if marker not in ui:
        check("UI: %s" % marker, False, "نیست")

print()
if FAIL:
    print("==> %d شکست" % len(FAIL))
    sys.exit(1)
print("==> پین اقدامات رهبر سبز است")
