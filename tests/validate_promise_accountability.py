#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""پین «پاسخگویی وعده‌های انتخاباتی» — بازرسی ۱۴۰۵ (عمق‌بخشی ۴۵).

باگ قبلی: وعده‌ها در انتخابات «اتفاقاً» اجرا می‌شدند (مثل tax_cut که مالیات را
خودش کم می‌کرد) حتی اگر بازیکن هیچ کاری نکرده بود + support رایگان می‌دادند.
یعنی وعده = پاداش بدون مسئولیت.

درمان: وعده = تعهد سنجش‌پذیر:
- هر وعده متریک و جهت دارد (PROMISES.metric/direction).
- هنگام ثبت، baseline شاخص ذخیره می‌شود.
- در انتخابات به‌جای اجرای اتفاقی، «محقق‌شدن» سنجیده می‌شود:
  محقق → ماندات و اعتماد (promise_kept)؛ شکسته → رأی و اعتماد می‌سوزد
  (broken_promise). نتیجه در parliament.last_result ثبت می‌شود
  (promises_kept/promises_broken) و در UI نمایش داده می‌شود.

این تست پین می‌کند: متریک/جهت در داده، baseline در ثبت، سنجش در انتخابات،
نتیجه در last_result، helper های آرایهٔ دیکشنری، و نمایش UI.
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


pm = read(os.path.join(ROOT, "scripts", "core", "parliament_manager.gd"))

# 1) هر وعده متریک و جهت دارد
for m in re.finditer(r'"(\w+)": \{"name_fa": "[^"]+", "effect": "[^"]+",\s*"metric": "([^"]+)", "direction": "(\w+)"\}', pm):
    if m.group(3) not in ("up", "down"):
        check("جهت وعدهٔ %s" % m.group(1), False, m.group(3))
check("وعده‌ها متریک/جهت دارند", pm.count('"metric":') >= 6, "PROMISES متریک ندارند")

# 2) baseline در ثبت
check("baseline در add_promise", '"baseline": _read_metric(state' in pm, "baseline ثبت نمی‌شود")
check("توابع کمکی", "func _read_metric" in pm and "func _promise_kept" in pm,
      "_read_metric/_promise_kept نیستند")
check("helper آرایهٔ دیکشنری", "func promise_ids" in pm and "func has_promise" in pm,
      "promise_ids/has_promise نیستند")

# 3) سنجش در انتخابات (به‌جای اجرای اتفاقی)
check("سنجش محقق‌شدن", "_promise_kept(state, pr)" in pm, "سنجش محقق‌شدن نیست")
check("وعدهٔ محقق → پاداش", '"promise_kept"' in pm, "promise_kept نیست")
check("وعدهٔ شکسته → جریمه", '"broken_promise"' in pm and 'media["trust"] = clampf(float(media.get("trust", 0.55)) - 0.02' in pm,
      "broken_promise/جریمه نیست")
check("نتیجه در last_result", '"promises_kept": kept_count' in pm and '"promises_broken": broken_count' in pm,
      "last_result آمار وعده‌ها را ندارد")
# اجرای اتفاقی قدیمی نباید برگردد
if 'econ["tax_rate"] = clampf(float(econ.get("tax_rate", 0.2)) - 0.02' in pm:
    check("بدون اجرای اتفاقی", False, "اجرای اتفاقی وعده‌ها بازگشته است")

# 4) UI
ui = read(os.path.join(ROOT, "scripts", "ui", "main_ui.gd"))
check("UI از has_promise استفاده می‌کند", "ParliamentManager.has_promise(promises" in ui,
      "UI با آرایهٔ ساده کار می‌کند (سازگاری شکسته)")
check("نمایش وعده‌های شکسته/محقق", "وعده شکسته" in ui and "وعده محقق شد" in ui,
      "نمایش نتیجهٔ پاسخگویی در UI نیست")

print()
if FAIL:
    print("==> %d شکست" % len(FAIL))
    sys.exit(1)
print("==> پین پاسخگویی وعده‌ها سبز است")
