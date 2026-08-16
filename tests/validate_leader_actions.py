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
# عمق‌بخشی ۴۸ — کلیدهای کول‌داون اقدامات جدید
for key in ["last_inspection_turn", "last_amnesty_turn", "last_honors_turn",
            "last_un_address_turn", "last_interview_turn", "last_summit_turn",
            "last_dialogue_turn"]:
    if '"%s"' % key not in lm:
        check("state: %s" % key, False, "کلید کول‌داون در leader_manager نیست")

# 2) توابع مدیر
for marker in ["func can_speech", "func speech", "func can_style", "func set_style",
               "func can_presence", "func presence", "const STYLES", "func get_style_name"]:
    if marker not in lm:
        check("مدیر: %s" % marker, False, "نیست")
# عمق‌بخشی ۴۸ — اقدامات جدید (can + اجرا)
for action in ["inspection", "amnesty", "honors", "un_address", "interview",
               "summit", "dialogue"]:
    for marker in ["func can_%s" % action, "func %s(" % action]:
        if marker not in lm:
            check("مدیر ۴۸: %s" % marker, False, "نیست")

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

# 5) کانال‌های واقعی اقدامات ۴۸ (فانتوم ممنوع — اصل ۲.۲)
check("بازدید سرزده", "بازدید سرزده" in lm and 'pol["corruption"]' in lm, "بازدید سرزده/فساد نیست")
check("عفو از کانال زندان", "PrisonManager.amnesty_program" in lm, "عفو رهبر از کانال واقعی زندان نمی‌گذرد")
check("نشان از کانال recognition", 'vt["recognition"]' in lm, "نشان ملی کانال تکریم واقعی ندارد")
check("سازمان ملل", "سازمان ملل" in lm and 'relations[cid]' in lm, "سخنرانی سازمان ملل نیست")
check("پروپاگاندا (رسانه مهارشده)", 'if freedom < 0.35:' in lm, "واکنش به رسانه مهارشده نیست")
check("اعتماد سرمایه‌گذاران", 'cycle["confidence"]' in lm, "دیدار سرمایه‌داران کانال واقعی ندارد")
check("تنش قومی", 'ethnicity["tension"]' in lm, "گفتگوی ملی کانال تنش قومی ندارد")
# مالکیت یکتا: ساختار جناح‌ها/رسانه فقط از مدیر مالک ساخته می‌شود (نه دیکشنری خالی)
check("مالکیت factions از FactionManager", "state = FactionManager.ensure(state)" in lm,
      "اقدام رهبری ساختار جناح‌ها را دور می‌زند (کرش faction_manager)")
check("مالکیت media از MediaManager", "state = MediaManager.ensure(state)" in lm,
      "اقدام رهبری ساختار رسانه را دور می‌زند")

# 6) فرمان و موتور
cmd = read(os.path.join(ROOT, "scripts", "core", "command.gd"))
check("فرمان", "create_leader_action" in cmd, "create_leader_action نیست")
eng = read(os.path.join(ROOT, "scripts", "core", "engine.gd"))
for marker in ['"leader_action"', "LeaderManager.can_speech", "LeaderManager.presence", "LeaderManager.set_style"]:
    if marker not in eng:
        check("موتور: %s" % marker, False, "نیست")
for marker in ["LeaderManager.can_inspection", "LeaderManager.inspection",
               "LeaderManager.can_amnesty", "LeaderManager.amnesty",
               "LeaderManager.can_honors", "LeaderManager.honors",
               "LeaderManager.can_un_address", "LeaderManager.un_address",
               "LeaderManager.can_interview", "LeaderManager.interview",
               "LeaderManager.can_summit", "LeaderManager.summit",
               "LeaderManager.can_dialogue", "LeaderManager.dialogue"]:
    if marker not in eng:
        check("موتور ۴۸: %s" % marker, False, "نیست")

# 7) هوش منحصربه‌فرد رهبر (اصل ۲.۲.۷)
lai_path = os.path.join(ROOT, "scripts", "ai", "leader_ai.gd")
if not os.path.exists(lai_path):
    check("هوش رهبر", False, "scripts/ai/leader_ai.gd نیست")
else:
    lai = read(lai_path)
    check("هوش رهبر", "func diagnose" in lai and '"system": "leader"' in lai, "تشخیص رهبری نیست")
    check("پرونده پایه همیشه غیرخالی", "func _profile" in lai and "leader.popularity_world" in lai,
          "تشخیص رهبر در حالت عادی خالی است (شورای هوشمند ناقص می‌شود)")
bai = read(os.path.join(ROOT, "scripts", "ai", "base_ai.gd"))
check("پرونده تشخیصی PROFILES رهبر", '"leader": ["leader.popularity_world"' in bai,
      "رهبر در BaseAI.PROFILES نیست (نگهبان هوش test_scene می‌شکند)")
ts = read(os.path.join(ROOT, "tests", "test_scene.gd"))
check("شورای هوشمند ۶۹ عامل (۴۸+۴۹)", "agents.size() != 69" in ts and "diagnoses.size() != 69" in ts,
      "شمارش شورای هوشمند با هوش رهبر/رقبا هماهنگ نیست")

# 8) UI
ui = read(os.path.join(ROOT, "scripts", "ui", "main_ui.gd"))
for marker in ["اقدامات رهبر", "_on_leader_speech", "_on_leader_style", "_on_leader_presence",
               "leaderspeech:", "leaderstyle:", "leaderpresence"]:
    if marker not in ui:
        check("UI: %s" % marker, False, "نیست")
for marker in ["_on_leader_inspection", "_on_leader_amnesty", "_on_leader_honors",
               "_on_leader_un_address", "_on_leader_interview", "_on_leader_summit",
               "_on_leader_dialogue", "leaderinspection", "leaderamnesty", "leaderhonors",
               "leaderunaddress", "leaderinterview", "leadersummit", "leaderdialogue"]:
    if marker not in ui:
        check("UI ۴۸: %s" % marker, False, "نیست")
check("برچسب رهبری در SYSTEM_FA", '"leader": "رهبری"' in ui, "قانون ۶ برای سامانه رهبری نیست")

# 9) تست گودو در CI
tl = read(os.path.join(ROOT, "tests", "test_leader_actions.gd"))
for marker in ["create_leader_action(\"inspection\")", "create_leader_action(\"amnesty\")",
               "create_leader_action(\"honors\")", "create_leader_action(\"un_address\")",
               "create_leader_action(\"interview\")", "create_leader_action(\"summit\")",
               "create_leader_action(\"dialogue\")"]:
    if marker not in tl:
        check("تست گودو: %s" % marker, False, "نیست")

print()
if FAIL:
    print("==> %d شکست" % len(FAIL))
    sys.exit(1)
print("==> پین اقدامات رهبر سبز است")
