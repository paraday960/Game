# -*- coding: utf-8 -*-
"""پین «نام فارسی سامانه‌ها» — بازرسی ۱۴۰۵.

SYSTEM_FA در main_ui باید برچسب فارسی همه‌ی سامانه‌های رسمی (GameEngine.system_order)
و همه‌ی شناسه‌های system که در payload رویدادها/تشخیص AI می‌آیند را داشته باشد.
در غیر این صورت به بازیکن «سامانه»/«یکی از سامانه‌ها» نمایش داده می‌شود
(نقض قانون ۶: نمایش فارسی). دو سامانه‌ی رسمی (trade_route_warfare، map_advanced)
و ۱۱ شناسه‌ی رویداد (citizens، crisis، ...) فاقد برچسب بودند — اضافه شدند.
"""
import io
import re
import sys
import glob

FAIL = []


def read(p):
    return io.open(p, encoding="utf-8").read()


def check(name, cond, msg):
    if not cond:
        FAIL.append(msg)
        print("❌ %s: %s" % (name, msg))
    else:
        print("✅ %s" % name)


main = read("scripts/ui/main_ui.gd")
m = re.search(r"SYSTEM_FA\s*:?=\s*\{(.*?)\n\}", main, re.S)
sys_fa = set(re.findall(r'"([a-z_0-9]+)"\s*:', m.group(1))) if m else set()
check("SYSTEM_FA وجود دارد", len(sys_fa) > 60, "SYSTEM_FA یافت نشد/ناقص است")

# 1) سامانه‌های رسمی موتور
eng = read("scripts/core/engine.gd")
me = re.search(r"system_order\s*[:=]?\s*\[(.*?)\]", eng, re.S)
order = re.findall(r'"([a-z_0-9]+)"', me.group(1)) if me else []
missing_order = [s for s in order if s not in sys_fa]
check(
    "همه‌ی سامانه‌های رسمی برچسب فارسی دارند",
    not missing_order,
    "بدون برچسب: %s" % (missing_order or "—"),
)

# 2) شناسه‌های system در payload رویدادها و تشخیص AI
used = set()
for f in glob.glob("scripts/**/*.gd", recursive=True):
    src = read(f)
    for mm in re.finditer(r'"system"\s*:\s*"([a-z_0-9]+)"', src):
        used.add(mm.group(1))
    for mm in re.finditer(r'["\']system["\']\s*=\s*["\']([a-z_0-9]+)["\']', src):
        used.add(mm.group(1))
missing_used = sorted(used - sys_fa)
check(
    "همه‌ی شناسه‌های رویداد برچسب فارسی دارند",
    not missing_used,
    "بدون برچسب: %s" % (missing_used or "—"),
)

print()
if FAIL:
    print("==> %d شکست" % len(FAIL))
    sys.exit(1)
print("==> پوشش نام فارسی سامانه‌ها سبز است (SYSTEM_FA=%d کلید)" % len(sys_fa))
