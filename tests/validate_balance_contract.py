# -*- coding: utf-8 -*-
"""پین قرارداد «منبع واحد تنظیم» — بازرسی ۱۴۰۵.

balance.json باید تنها منبع مقادیر قابل تنظیم موتور باشد. پویش نشان داد
کلید monetary.neutral_real_rate (نرخ خنثای واقعی بانک مرکزی، ۲٪) در کد خوانده
می‌شد ولی در balance.json نبود — یعنی قابل تنظیم از داده نبود و بی‌سروصدا از
پیش‌فرض استفاده می‌کرد. بخش monetary اضافه شد.

این تست پین می‌کند:
1) هر کلیدی که کد با BalanceConfig.get_value می‌خواند باید در balance.json
   وجود داشته باشد (هیچ کلید «بی‌سروصدا-پیش‌فرض» نماند).
2) بخش monetary با neutral_real_rate موجود است.
"""
import io
import json
import re
import sys
import glob

FAIL = []


def check(name, cond, msg):
    if not cond:
        FAIL.append(msg)
        print("❌ %s: %s" % (name, msg))
    else:
        print("✅ %s" % name)


def flatten(d, prefix=""):
    out = {}
    for k, v in d.items():
        path = "%s.%s" % (prefix, k) if prefix else k
        if isinstance(v, dict):
            out.update(flatten(v, path))
        else:
            out[path] = v
    return out


bal = json.load(io.open("data/balance.json", encoding="utf-8"))
flat = flatten(bal)

read_keys = set()
for f in glob.glob("scripts/**/*.gd", recursive=True):
    src = io.open(f, encoding="utf-8").read()
    for m in re.finditer(r'BalanceConfig\.get_value\(\s*"([^"]+)"', src):
        read_keys.add(m.group(1))
    for m in re.finditer(r'BalanceConfig\.get\(\s*"([^"]+)"', src):
        read_keys.add(m.group(1))

missing = sorted(read_keys - set(flat.keys()))
check(
    "هر کلید خوانده‌شده در balance.json هست",
    not missing,
    "خوانده می‌شود ولی در balance.json نیست: %s" % (missing or "—"),
)

mon = bal.get("monetary", {})
check(
    "بخش monetary موجود است",
    isinstance(mon, dict) and "neutral_real_rate" in mon,
    "بخش monetary.neutral_real_rate در balance.json نیست",
)
if isinstance(mon, dict) and "neutral_real_rate" in mon:
    check(
        "نرخ خنثای واقعی در بازه‌ی معقول",
        0.005 <= float(mon["neutral_real_rate"]) <= 0.06,
        "neutral_real_rate=%s خارج از بازه‌ی 0.005..0.06" % mon.get("neutral_real_rate"),
    )

print()
if FAIL:
    print("==> %d شکست" % len(FAIL))
    sys.exit(1)
print("==> قرارداد balance.json سبز است (%d کلید خوانده‌شده)" % len(read_keys))
