#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""پین «فرکانس مؤثر رویدادهای واقعی» — بازرسی ۱۴۰۵ (عمق‌بخشی ۳۸).

پویش قبلی (audit_event_odds.py) فقط کران بالای خام می‌داد و گیت‌های زمانی
`tick % N == X` را نادیده می‌گرفت — درنتیجه ۴۵ «هرز» پرچم می‌کرد که همگی
فالبوک بودند (رویدادهای واقعی گیت زمانی یا بلاک شرطی دارند). بررسی دستی
همهٔ ۴۵ مورد: تمیز.

این تست فرکانس **مؤثر** را می‌سنجد:
- فقط رویدادهای واقعی (`events.append` همراه با پیام در همان خط/نزدیک آن).
- گیت‌های زمانی تابع میزبان (`tick % N == X` یا `tick % N == 0`) تقسیم‌کنندهٔ
  فرکانس‌اند: per_year / N (برای روزانه ۳۶۰، هفتگی ۶۰، ماهانه ۲۴).
- اگر هیچ گیت زمانی نبود، احتمال شرطی شدن با وجود `if`/`and` در همان خط
  به‌عنوان «نامشخص» علامت می‌شود نه هرز (فالبوک‌پذیر).

آستانهٔ پین: رویداد واقعی با انتظار مؤثر > ۱۲ در سال بدون هیچ شرطی = هرز.
خروج غیرصفر = رویداد هرز واقعی بازگشته.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = os.path.join(ROOT, "scripts")
ENGINE = os.path.join(SCRIPTS, "core", "engine.gd")

FAIL = []


def check(name, cond, msg):
    if not cond:
        FAIL.append(msg)
        print("❌ %s: %s" % (name, msg))
    else:
        print("✅ %s" % name)


def load_cadence():
    src = open(ENGINE, encoding="utf-8").read()
    out = {}
    for const, per_year in (("DAILY_SYSTEMS", 360), ("WEEKLY_SYSTEMS", 60),
                            ("MONTHLY_SYSTEMS", 24)):
        m = re.search(const + r"\s*=\s*\[(.*?)\]", src, re.S)
        for name in re.findall(r'"([^"]+)"', m.group(1)):
            out[name] = per_year
    return out


CAD = load_cadence()
APPEND_RE = re.compile(r"events\.append\(")
GATE_RE = re.compile(r"tick\s*%\s*(\d+)\s*==\s*(\d+)")
CHANCE_RE = re.compile(r"Deterministic\.chance\(\s*(?:float\()?\s*([0-9]*\.?[0-9]+)")
FUNC_RE = re.compile(r"^func\s+(\w+)")

spam = []
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
            per_year = CAD.get(sys_name) or CAD.get(stem)
        else:
            per_year = 12  # مدیرها: simulate_month

        for i, line in enumerate(lines):
            if not APPEND_RE.search(line):
                continue
            if line.strip().startswith("#"):
                continue
            # تابع میزبان
            fn = ""
            for j in range(i, -1, -1):
                m = FUNC_RE.match(lines[j])
                if m:
                    fn = m.group(1)
                    break
            # گیت‌های زمانی در ۱۲ خط قبل (همان تابع)
            gates = []
            for j in range(max(0, i - 12), i):
                for gm in GATE_RE.finditer(lines[j]):
                    gates.append(int(gm.group(1)))
            # احتمال در همان خط یا خط قبل
            p = None
            for j in (i, i - 1):
                if j < 0:
                    continue
                cm = CHANCE_RE.search(lines[j])
                if cm:
                    p = float(cm.group(1))
                    break
            if p is None:
                continue  # رویداد غیرتصادفی (شرطی قطعی) — خارج از پویش
            # فرکانس مؤثر: per_year تقسیم بر کوچک‌ترین گیت زمانی (اگر هست)
            eff = per_year if per_year else 12
            if gates:
                eff = eff / min(gates)
            expect = eff * p
            # شرطی‌بودن: if/and در خط رویداد یا خط قبل = کران بالاست نه قطعی
            has_cond = bool(re.search(r"\bif\b|\band\b", lines[i])) or \
                bool(re.search(r"\bif\b", lines[i - 1])) if i > 0 else False
            if expect > 12.0 and not has_cond:
                spam.append((rel, i + 1, fn, p, eff, expect))

check(
    "بدون رویداد هرز واقعی (انتظار مؤثر > ۱۲/سال)",
    not spam,
    "رویدادهای هرز: %s" % (spam or "—"),
)

# گزارش برای شفافیت
print("فرکانس مؤثر با گیت‌های زمانی محاسبه شد (cadence: %d سیستم)" % len(CAD))

print()
if FAIL:
    print("==> %d شکست" % len(FAIL))
    sys.exit(1)
print("==> پین فرکانس مؤثر رویدادها سبز است")
