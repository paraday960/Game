# -*- coding: utf-8 -*-
"""پین پویش «اتم‌های فارسی UI» — دور سیزدهم.

دو کلاس باگ پیدا و رفع شد:
1) نمایش عدد با ارقام انگلیسی به بازیکن: نرخ مالیات، شمار طرح‌های فعال،
   درصد اختلاف مقایسه (همه در main_ui.gd) → همه باید از PersianFormatter
   یا معادل آن (مثل _fa در trend_chart) عبور کنند.
2) نمودار روند ماهانه: کلید label در نمونه‌های تاریخچه نبود → هاورکارت
   «ماه N» نشان می‌داد به‌جای «مرداد ۱۴۰۶» → analytics_manager باید
   برچسب فارسی ماه+سال بنویسد.

این تست پین می‌کند:
- هیچ متن لیبل در فایل‌های UI نباید عدد را با عملگر %d یا %.Nf مستقیم
  (بدون تبدیل ارقام) قالب بزند.
- نمونه‌ی تاریخچه analytics باید کلید label فارسی داشته باشد.
"""
import io
import re
import sys

FAIL = []
UI_FILES = [
    "scripts/ui/main_ui.gd",
    "scripts/ui/unified_map.gd",
    "scripts/ui/trend_chart.gd",
    "scripts/ui/toast_stack.gd",
    "scripts/ui/command_palette.gd",
    "scripts/ui/feedback_manager.gd",
    "scripts/ui/celebration_layer.gd",
    "scripts/ui/map_fx_layer.gd",
    "scripts/ui/hero_ambient.gd",
    "scripts/ui/command_background.gd",
    "scripts/ui/touch_scroll_container.gd",
]


def read(p):
    return io.open(p, encoding="utf-8").read()


def check(name, cond, msg):
    if not cond:
        FAIL.append(msg)
        print("❌ %s: %s" % (name, msg))
    else:
        print("✅ %s" % name)


# ── 1) اعداد در .text بدون تبدیل ارقام فارسی ─────────────────────────
# الگوی ممنوع: .text = "...%d..." یا "...%.Nf..." بدون PersianFormatter/_fa در همان خط
bad = []
for f in UI_FILES:
    src = read(f)
    for m in re.finditer(r'\.text\s*=.*%(?:[+ ]?\d*\.?\d*[fdx])', src):
        line = m.group(0)
        # استثنا: همان خط تبدیل ارقام دارد
        if re.search(r'PersianFormatter|to_persian|format_money|format_percent|format_number|format_large|_fa\(', line):
            continue
        # استثنا: جایگزینی رشته (بدون عدد) یا پارامتر توابع
        if re.search(r'%\[|%\s*[a-z_]+\.|%\(', line):
            continue
        line_no = src[:m.start()].count("\n") + 1
        bad.append((f, line_no, line.strip()[:100]))
check(
    "اعداد فارسی در UI",
    not bad,
    "قالب عددی بدون تبدیل ارقام: %s" % (bad[:5] or "—"),
)

# ── 2) برچسب فارسی در تاریخچه‌ی نمودار ───────────────────────────────
am = read("scripts/core/analytics_manager.gd")
check(
    "برچسب فارسی تاریخچه",
    '"label": "%s %s"' in am and "TimeManager.month_name" in am and "to_persian_digits" in am,
    "نمونه‌ی history باید label فارسی ماه+سال داشته باشد",
)

# ── 3) ابزار تبدیل ارقام موجود و متصل ─────────────────────────────────
pm = read("scripts/ui/persian_formatter.gd")
for marker in ["func to_persian_digits", "func format_money", "func format_percent", "func format_large"]:
    if marker not in pm:
        check("PersianFormatter.%s" % marker, False, "تابع از دست رفته")
main = read("scripts/ui/main_ui.gd")
uses = main.count("PersianFormatter.")
check("استفاده‌ی گسترده از PersianFormatter", uses > 20, "تنها %d استفاده — احتمال نشت اعداد انگلیسی" % uses)

print()
if FAIL:
    print("==> %d شکست" % len(FAIL))
    sys.exit(1)
print("==> همه‌ی پین‌های فارسی UI سبزند")
