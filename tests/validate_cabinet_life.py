#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""پین «کابینهٔ زنده» — بازرسی ۱۴۰۵ (عمق‌بخشی ۴۴).

کابینه از «آمار ثابت» به «زنده» ارتقا یافت:
- مأموریت ویژه به وزیر در بحران (موفقیت به شایستگی/پاکدستی/انسجام؛ کولداون)
- چرخهٔ عمر: فرسودگی (tenure>36 + resilience پایین)، استعفای جاه‌طلبانه
  (ambition بالا)، درگذشت (سن بالا) → جای خالی و جریمه
- درگیری وزرا با ایدئولوژی متضاد (محافظه‌کار↔اصلاح‌طلب، پوپولیست↔تکنوکرات)
- میانجیگری رهبر برای پایان درگیری (هزینهٔ سرمایه سیاسی)
داده: هر وزیر age/ideology/ambition/resilience گرفت (۳۰ کاندیدا).

این تست پین می‌کند: داده، توابع مدیر، اتصال فرمان، UI و کلیدهای state.
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


# 1) داده: هر کاندیدا ویژگی‌های عمر دارد
data = json.load(io.open(os.path.join(ROOT, "data", "cabinet.json"), encoding="utf-8"))
cands = [c for m in data["ministries"] for c in m.get("candidates", [])]
missing = [c.get("id") for c in cands if not all(k in c for k in ("age", "ideology", "ambition", "resilience"))]
check("دادهٔ وزیران ویژگی‌های عمر دارد", not missing, "کمبود: %s" % (missing[:5] or "—"))
bad_ideo = [c.get("id") for c in cands if c.get("ideology") not in ("محافظه‌کار", "اصلاح‌طلب", "تکنوکرات", "پوپولیست")]
check("ایدئولوژی معتبر", not bad_ideo, "ایدئولوژی نامعتبر: %s" % bad_ideo)
for c in cands:
    if not (30 <= int(c.get("age", 0)) <= 80):
        check("سن معقول", False, "%s: سن %s" % (c.get("id"), c.get("age")))
        break

# 2) مدیر: توابع جدید
mg = read(os.path.join(ROOT, "scripts", "core", "cabinet_manager.gd"))
for marker in ["func can_mission", "func assign_mission", "func mediate_dispute",
               "func get_disputes", "minister_mission_success", "minister_mission_failed",
               "minister_resigned", "minister_died", "cabinet_dispute", "cabinet_mediation"]:
    if marker not in mg:
        check("مدیر: %s" % marker, False, "در cabinet_manager.gd نیست")
# چرخهٔ عمر
check("چرخهٔ عمر", "resilience" in mg and "ambition" in mg and "درگذشت" in mg,
      "چرخهٔ عمر (فرسودگی/جاه‌طلبی/درگذشت) نیست")
# کلیدهای state
for key in ['"missions"', '"disputes"', '"next_mission_turn"']:
    if key not in mg:
        check("state: %s" % key, False, "کلید در مدیر نیست")

# 3) فرمان و موتور
eng = read(os.path.join(ROOT, "scripts", "core", "engine.gd"))
for marker in ['"mission"', '"mediate"', "CabinetManager.can_mission",
               "CabinetManager.assign_mission", "CabinetManager.mediate_dispute"]:
    if marker not in eng:
        check("موتور: %s" % marker, False, "در engine.gd نیست")
cmd = read(os.path.join(ROOT, "scripts", "core", "command.gd"))
for marker in ["create_cabinet_mission", "create_cabinet_mediate"]:
    if marker not in cmd:
        check("فرمان: %s" % marker, False, "در command.gd نیست")

# 4) UI
ui = read(os.path.join(ROOT, "scripts", "ui", "main_ui.gd"))
for marker in ["مأموریت ویژه", "میانجیگری", "_on_cabinet_mission", "_on_cabinet_mediate",
               "cabmission:", "cabmediate"]:
    if marker not in ui:
        check("UI: %s" % marker, False, "در main_ui.gd نیست")
# queue_key
check("queue_key برای مأموریت/میانجیگری", '"mission": return "cabmission:' in ui and '"mediate": return "cabmediate"' in ui,
      "queue_key کابینه کامل نیست")

print()
if FAIL:
    print("==> %d شکست" % len(FAIL))
    sys.exit(1)
print("==> پین کابینهٔ زنده سبز است (%d وزیر)" % len(cands))
