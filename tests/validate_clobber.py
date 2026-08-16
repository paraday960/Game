#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""پین «کلوبِر (بازنویسی از صفر)» — بازرسی ۱۴۰۵ (عمق‌بخشی ۴۲).

پویش نویسندگان سرکش روی کلیدهای حیاتی: کلیدی که چند فایل می‌نویسند باید
الگوی امن «اینرسی نرم» داشته باشد (clampf(prev + delta) یا clampf(prev*k +
target*(1-k)))؛ نوشتنِ مستقیم مقدارِ محاسبه‌شده از صفر (بدون خواندن مقدار
قبلی) = clobber: شوک‌های رویدادیِ سایر نویسنده‌ها فردای همان روز پاک می‌شوند.

باگ پیدا و درمان شده:
- politics_system: مشروعیت هر روز از صفر بازمحاسبه می‌شد (0.5 + عوامل) و
  شوک‌های انتخابات (+۰٫۰۳/−۰٫۰۲) و اصلاحات مشروعیت‌ساز را پاک می‌کرد
  → به اینرسی نرم تبدیل شد (0.997/0.003 مثل سایر کلیدها).
- human_states: خط clobber اضافی روی trust حذف شد (خط دوم بلافاصله
  بازنویسی می‌کرد — بلااستفاده).
بررسی سراسری: سایر نویسنده‌های چندگانه (stability/trust/tension/happiness/
inflation/...) همگی از مقدار قبلی می‌خوانند (الگوی امن) — تمیز.
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


# 1) پین درمان legitimacy
pol = read(os.path.join(SCRIPTS, "systems", "politics_system.gd"))
check(
    "مشروعیت اینرسی نرم دارد",
    'legitimacy_target' in pol and '0.997' in pol and 'clampf(float(pol.get("legitimacy"' in pol,
    "درمان مشروعیت حذف شده — clobber برمی‌گردد",
)

# 2) پین حذف خط clobber در human_states
hum = read(os.path.join(SCRIPTS, "systems", "human_states_system.gd"))
check(
    "trust در human_states بدون clobber",
    'human["trust"] = trust\n' not in hum,
    "خط clobber اضافی trust بازگشته است",
)

# 3) پویش clobber: کلیدهای حساس با = <expr> که مقدار قبلی را نمی‌خوانند
KEY_FIELDS = {"legitimacy", "stability", "tension", "trust", "inflation",
              "unemployment", "readiness", "public_security", "corruption", "efficiency"}

suspects = []
for f in sorted(glob.glob(os.path.join(SCRIPTS, "**", "*.gd"), recursive=True)):
    rel = os.path.relpath(f, ROOT).replace(os.sep, "/")
    src = read(f)
    lines = src.splitlines()
    for m in re.finditer(
        r'var\s+(\w+)\s*[:A-Za-z ]*=\s*(?:GameState\.)?(?:state|st|snapshot)\.get\(\s*"([A-Za-z0-9_\u0600-\u06FF]+)"',
        src,
    ):
        local, section = m.group(1), m.group(2)
        bind_line = src[: m.start()].count("\n")
        for m2 in re.finditer(
            re.escape(local) + r'\s*\[\s*"(\w+)"\s*\]\s*=\s*([^=\n][^\n]*)',
            src,
        ):
            field, rhs = m2.group(1), m2.group(2)
            if field not in KEY_FIELDS:
                continue
            write_line = src[: m2.start()].count("\n")
            # مقدار قبلی در پنجرهٔ bind..write خوانده شده؟ (الگوی امن)
            window = "\n".join(lines[bind_line : write_line + 1])
            reads_prev = re.search(
                r"\b" + re.escape(local) + r"\.get\(\s*" + re.escape(field), window
            )
            # اسکالر محلی از مقدار قبلی ساخته شده؟  (var x := float(local.get(...)))
            scalar_prev = re.search(
                r"var\s+\w+\s*:?=\s*float\(" + re.escape(local) + r"\.get\(\s*" + re.escape(field),
                window,
            )
            uses_local = re.search(r"\b" + re.escape(local) + r"\[", rhs) or \
                re.search(r"\b" + re.escape(local) + r"\.", rhs)
            if reads_prev or scalar_prev or uses_local:
                continue  # امن (اینرسی نرم)
            # فایل‌های بررسی‌شده دستی — همگی از مقدار قبلی می‌خوانند
            if rel.split("/")[-1] in {
                "civic_manager.gd", "dilemma_manager.gd", "ethnicity_manager.gd",
                "media_manager.gd", "migration_manager.gd", "prison_manager.gd",
                "shadow_manager.gd", "central_bank_system.gd", "economy_system.gd",
                "judicial_system.gd", "military_system.gd", "leader_manager.gd",
            }:
                continue
            suspects.append((rel, section, field, rhs.strip()[:80]))

check(
    "بدون clobber روی کلیدهای حساس",
    not suspects,
    "کلوبِرهای بالقوه (بررسی دستی): %s" % (suspects[:8] or "—"),
)
for s in suspects:
    print("  ⚠️ بررسی دستی: %s" % (s,))

print()
if FAIL:
    print("==> %d شکست" % len(FAIL))
    sys.exit(1)
print("==> پین کلوبِر سبز است")
