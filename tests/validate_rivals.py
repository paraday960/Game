#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""پین «رقبای داخلی و توطئه» — بازرسی ۱۴۰۵ (عمق‌بخشی ۴۹).

رهبرِ مطلق رقیب‌های داخلی دارد: ۳ چهره از جناح‌ها با جاه‌طلبی/حمایت/وفاداری،
دریفت ماهانه، توطئه و کودتای همیشه-شکست‌خورده. بازیکن با ۴ ابزار مدیریت
می‌کند: همکاری، مذاکره، زیر نظر گرفتن، تبعید — همه با هزینهٔ سرمایهٔ سیاسی،
کول‌داون و بده‌بستان واقعی روی کانال‌های state.

این تست پین می‌کند: کلیدهای state، توابع مدیر، ثابت‌ها، مالکیت ساختار
(FactionManager.ensure)، برکنارنشدنی بودن رهبر در کودتا، latchهای
last_* (گارد + نوشتن)، اتصال فرمان/موتور/صف، هوش منحصربه‌فرد (اصل ۲.۲.۷)،
شمارش شورای هوشمند، UI و برچسب فارسی.
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


rm = read(os.path.join(ROOT, "scripts", "core", "rivals_manager.gd"))

# 1) کلیدهای state
for key in ['"figures"', '"threat"', '"coup_attempts"', '"last_exile_turn"',
            '"last_surveil_turn"', '"last_recruit_turn"']:
    if key not in rm:
        check("state: %s" % key, False, "کلید در rivals_manager نیست")

# 2) توابع مدیر و ثابت‌ها
for marker in ["func ensure", "func simulate_month", "func can_coopt", "func coopt",
               "func can_exile", "func exile", "func can_negotiate", "func negotiate",
               "func can_surveil", "func surveil", "func _attempt_coup"]:
    if marker not in rm:
        check("مدیر: %s" % marker, False, "نیست")
for const in ["MAX_FIGURES", "EXILE_COOLDOWN", "SURVEIL_COOLDOWN", "RECRUIT_COOLDOWN",
              "PLOT_MIN_SUPPORT", "PLOT_MIN_AMBITION", "PLOT_MAX_LOYALTY", "COUP_CHANCE"]:
    if const not in rm:
        check("ثابت: %s" % const, False, "نیست")

# 3) مالکیت یکتا: ساختار جناح‌ها فقط از مدیر مالک ساخته می‌شود
check("مالکیت factions از FactionManager", "state = FactionManager.ensure(state)" in rm,
      "rivals_manager ساختار جناح‌ها را دور می‌زند (کرش faction_manager)")

# 4) رهبر برکنارنشدنی: کودتا فقط هزینه می‌دهد، mode/alive را دست نمی‌زند
coup_body = rm.split("func _attempt_coup", 1)[1]
check("کودتا رهبر را برکنار نمی‌کند",
      '"mode"' not in coup_body and '"alive"' not in coup_body,
      "کودتا حالت رهبر را تغییر می‌دهد — نقض قانون بازی")
check("کودتا هزینهٔ واقعی دارد", 'pol["stability"]' in coup_body and "coup_attempts" in coup_body,
      "کودتا بدون هزینه است")

# 5) latchها: گارد زمانی + نوشتن واقعی (قرارداد latch)
check("گارد تبعید", "EXILE_COOLDOWN > tick" in rm, "گارد کول‌داون تبعید نیست")
check("گارد نظارت", "SURVEIL_COOLDOWN > tick" in rm, "گارد کول‌داون نظارت نیست")
check("نوشتن latchها", 'rivals["last_exile_turn"] = tick' in rm and 'rivals["last_surveil_turn"] = tick' in rm,
      "نوشتن latchها نیست")
check("سقف تعداد رقبا", "figures.size() < MAX_FIGURES" in rm and "remove_at" in rm,
      "آرایهٔ رقبا سقف ندارد (نشت رشد)")
check("جایگزینی فقط با کول‌داون", "while fill_figures.size() < MAX_FIGURES:" in rm,
      "ensure بلافاصله رقیب تبعیدشده را جایگزین می‌کند (کول‌داون استخدام دور می‌خورد)")

# 6) فرمان و موتور
cmd = read(os.path.join(ROOT, "scripts", "core", "command.gd"))
check("فرمان", "create_rivals_action" in cmd, "create_rivals_action نیست")
eng = read(os.path.join(ROOT, "scripts", "core", "engine.gd"))
for marker in ['"rivals_action"', "RivalsManager.can_coopt", "RivalsManager.coopt",
               "RivalsManager.can_exile", "RivalsManager.exile",
               "RivalsManager.can_negotiate", "RivalsManager.negotiate",
               "RivalsManager.can_surveil", "RivalsManager.surveil",
               "RivalsManager.ensure(snapshot)", "RivalsManager.simulate_month(snapshot, turn)"]:
    if marker not in eng:
        check("موتور: %s" % marker, False, "نیست")

# 7) هوش منحصربه‌فرد رقبا (اصل ۲.۲.۷)
rai_path = os.path.join(ROOT, "scripts", "ai", "rivals_ai.gd")
if not os.path.exists(rai_path):
    check("هوش رقبا", False, "scripts/ai/rivals_ai.gd نیست")
else:
    rai = read(rai_path)
    check("هوش رقبا", "func diagnose" in rai and '"system": "rivals"' in rai, "تشخیص رقبا نیست")
    check("پرونده پایه همیشه غیرخالی", "func _profile" in rai and "rivals.threat" in rai,
          "تشخیص رقبا در حالت عادی خالی است")
bai = read(os.path.join(ROOT, "scripts", "ai", "base_ai.gd"))
check("پرونده تشخیصی PROFILES رقبا", '"rivals": ["rivals.threat"' in bai,
      "رقبا در BaseAI.PROFILES نیست (نگهبان هوش test_scene می‌شکند)")
ts = read(os.path.join(ROOT, "tests", "test_scene.gd"))
check("شورای هوشمند ۶۹ عامل", "agents.size() != 69" in ts and "diagnoses.size() != 69" in ts,
      "شمارش شورای هوشمند با هوش رقبا هماهنگ نیست")

# 8) UI
ui = read(os.path.join(ROOT, "scripts", "ui", "main_ui.gd"))
for marker in ["رقبای داخلی", "rivalsact:"]:
    if marker not in ui:
        check("UI: %s" % marker, False, "نیست")
check("برچسب رقبا در SYSTEM_FA", '"rivals": "رقبای داخلی"' in ui, "قانون ۶ برای سامانه رقبا نیست")

# 9) تست گودو در CI
tr = read(os.path.join(ROOT, "tests", "test_rivals.gd"))
for marker in ["create_rivals_action(\"coopt\"", "create_rivals_action(\"exile\"",
               "create_rivals_action(\"negotiate\"", "create_rivals_action(\"surveil\"",
               "_attempt_coup"]:
    if marker not in tr:
        check("تست گودو: %s" % marker, False, "نیست")

print()
if FAIL:
    print("==> %d شکست" % len(FAIL))
    sys.exit(1)
print("==> پین رقبای داخلی سبز است")
