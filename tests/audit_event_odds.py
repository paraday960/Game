#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""پویش فرکانس رویدادهای تصادفی (بازرسی ۱۴۰۵) — ابزار برنامه‌ریزی، همیشه موفق.

هر ``Deterministic.chance(p)`` را با فرکانس اجرای میزبانش می‌سنجد تا رویدادهای
هرز (اسپم) یا تقریباً نامرئی (محتوای مرده) پیدا شوند:

- سیستم‌های روزانه: ۳۶۰ بار در سال | هفتگی: ۶۰ | ماهانهٔ سیستمی: ۲۴
- مدیرها (simulate_month): ۱۲ بار در سال
- توابع اقدام (apply_*/_on_*/اقدام مستقیم): «اقدامی» — فرکانس به بازیکن بستگی
  دارد و از ارزیابی تناوب کنار گذاشته می‌شوند.

توجه: p شرطی (if ... and chance(p)) فرکانس مؤثرش کمتر از برآورد است؛ جدول
«انتظار در سال» یک کران بالاست.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = os.path.join(ROOT, "scripts")

ENGINE = os.path.join(SCRIPTS, "core", "engine.gd")


def load_cadence():
    """نگاشت نام سیستم → اجرا در سال، از لیست‌های engine.gd."""
    src = open(ENGINE, encoding="utf-8").read()
    out = {}
    for const, per_year in (("DAILY_SYSTEMS", 360), ("WEEKLY_SYSTEMS", 60),
                            ("MONTHLY_SYSTEMS", 24)):
        m = re.search(const + r"\s*=\s*\[(.*?)\]", src, re.S)
        for name in re.findall(r'"([^"]+)"', m.group(1)):
            out[name] = per_year
    return out


CHANCE_RE = re.compile(r"Deterministic\.chance\(\s*(?:float\()?\s*([0-9]*\.?[0-9]+)")
FUNC_RE = re.compile(r"^func\s+(\w+)")
ACTION_HINTS = ("apply_", "_on_", "action", "decision", "command", "press",
                "coup", "war_",  "operation", "intervene", "devalue")


def enclosing_func(lines, idx):
    for j in range(idx, -1, -1):
        m = FUNC_RE.match(lines[j])
        if m:
            return m.group(1)
    return ""


def main():
    cad = load_cadence()
    rows = []
    for base, _dirs, names in os.walk(SCRIPTS):
        for name in sorted(names):
            if not name.endswith(".gd"):
                continue
            path = os.path.join(base, name)
            rel = os.path.relpath(path, ROOT).replace(os.sep, "/")
            lines = open(path, encoding="utf-8").read().splitlines()
            stem = name[:-3]
            if "/systems/" in path.replace(os.sep, "/"):
                sys_name = stem[:-len("_system")] if stem.endswith("_system") else stem
                per_year = cad.get(sys_name)
                per_year = per_year if per_year is not None else cad.get(stem)
            else:
                per_year = 12  # مدیرها: simulate_month
            for i, line in enumerate(lines):
                if line.strip().startswith("#"):
                    continue
                for m in CHANCE_RE.finditer(line):
                    p = float(m.group(1))
                    fn = enclosing_func(lines, i)
                    is_action = any(fn.startswith(h) or h in fn for h in ACTION_HINTS) \
                        and fn != "simulate_month"
                    expect = None if (is_action or per_year is None) else p * per_year
                    rows.append((rel, i + 1, fn, p, per_year, expect))

    print("%-52s %-5s %-8s %s" % ("سایت", "p", "اجرا/سال", "انتظار در سال"))
    print("─" * 92)
    spam, rare, action_n, unknown = [], [], 0, 0
    for rel, no, fn, p, per_year, expect in rows:
        if expect is None:
            if per_year is None:
                unknown += 1
            else:
                action_n += 1
            continue
        tag = ""
        if expect > 6.0:
            tag = "⚠️ هرز (بیش از ~شش‌بار در سال)"; spam.append(rel)
        elif expect < 0.05:
            tag = "💤 تقریباً نامرئی (کمتر از یک‌بار در ۲۰ سال)"; rare.append(rel)
        print("%-40s:%-4d %-7.3f %-8d %-18.1f %s"
              % (rel, no, p, per_year, expect, tag))
    print("─" * 92)
    print("اقدامی (کنار گذاشته شد): %d | سیستم ناشناختهٔ cadence: %d" % (action_n, unknown))
    print("هرز: %d | تقریباً نامرئی: %d" % (len(spam), len(rare)))
    sys.exit(0)


if __name__ == "__main__":
    main()
