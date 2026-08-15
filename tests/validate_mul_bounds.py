# -*- coding: utf-8 -*-
"""پین «mul باید min/max داشته باشد» — بازرسی ۱۴۰۵.

قاعده‌ی تعادلی (که قبلاً فقط برای crisis_chains پین شده بود) به همه‌ی داده‌ها
تعمیم داده شد: هر اثر با op=mul باید هر دو کران min و max را داشته باشد تا
مقدار از محدوده خارج نشود. مورد پیدا شده: port_expansion در national_projects
روی trade.exports با mul 1.05 فقط min داشت (صادرات پولی نرم‌شده بدون سقف) —
max اضافه شد.

این تست پین می‌کند: هیچ mul در data/*.json بدون min یا بدون max نماند.
"""
import io
import json
import sys
import glob

FAIL = []


def check(name, cond, msg):
    if not cond:
        FAIL.append(msg)
        print("❌ %s: %s" % (name, msg))
    else:
        print("✅ %s" % name)


def walk(node, out):
    if isinstance(node, dict):
        if isinstance(node.get("path"), str) and node.get("op") == "mul":
            out.append(node)
        for v in node.values():
            walk(v, out)
    elif isinstance(node, list):
        for v in node:
            walk(v, out)


bad = []
total_mul = 0
for f in sorted(glob.glob("data/*.json")):
    try:
        d = json.load(io.open(f, encoding="utf-8"))
    except Exception as ex:
        check("JSON معتبر %s" % f, False, str(ex))
        continue
    muls = []
    walk(d, muls)
    total_mul += len(muls)
    for e in muls:
        if "min" not in e or "max" not in e:
            bad.append((f, e.get("path"), "min" if "min" not in e else "max"))

check(
    "هر mul دارای min و max است",
    not bad,
    "mul بدون کران: %s" % (bad or "—"),
)
check(
    "افکت‌های mul وجود دارند (پین معنادار است)",
    total_mul > 0,
    "هیچ mul ای در داده‌ها نیست — پین خالی است",
)

print()
if FAIL:
    print("==> %d شکست" % len(FAIL))
    sys.exit(1)
print("==> پین کران‌های mul سبز است (%d اثر mul بررسی شد)" % total_mul)
