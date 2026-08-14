#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ممیزی اهرم‌های بودجه — تضمین اینکه هر ۱۰ ردیف «budget_allocations» مصرف‌کنندهٔ واقعی دارد.

بازرسی دورهای واقع‌گرایی نشان داد بیماری مزمن ریپو «اهرم مرده» است: سیاستی که بازیکن
می‌بیند ولی به مدل وصل نیست. این تست قرارداد حداقلی را تثبیت می‌کند:
هر ردیف بودجه باید حداقل یک خوانندهٔ بودجه‌محور در سیستم‌ها یا مدیران داشته باشد
(خطی که هم نام ردیف و هم سرنخ بودجه — alloc/budget — را داشته باشد).
"""
import glob
import io
import re
import sys

ROWS = ["آموزش", "بهداشت", "ارتش", "زیرساخت", "رفاه", "فناوری", "امنیت", "اداره", "محیط", "ذخیره"]
FILES = sorted(glob.glob("scripts/systems/*_system.gd") + glob.glob("scripts/core/*_manager.gd"))

fail = []
report = []
for row in ROWS:
    hits = []
    for f in FILES:
        for i, ln in enumerate(io.open(f, encoding="utf-8").read().split("\n"), 1):
            if ('"%s"' % row) in ln and ("alloc" in ln or "budget" in ln):
                hits.append((f, i, ln.strip()))
    if hits:
        report.append((row, hits))
    else:
        fail.append("ردیف بودجه بدون مصرف‌کننده: «%s»" % row)

for row, hits in report:
    print("✅ «%s» → %d خواننده (نخستین: %s:%d)" % (row, len(hits), hits[0][0], hits[0][1]))

# قرارداد منفی: هزینه نباید توسط سیستم دیگری بازنویسی شود (مالکیت یکتای بودجه)
writers = []
for f in glob.glob("scripts/systems/*_system.gd"):
    if f.endswith("economy_system.gd"):
        continue
    src = io.open(f, encoding="utf-8").read()
    for m in re.finditer(r'\["government_(revenue|spending)"\]\s*=(?![=+*/])', src):
        writers.append((f, m.group(1)))
if writers:
    for f, k in writers:
        fail.append("نویسندهٔ غیرمجاز بودجه در %s: %s" % (f, k))
else:
    print("✅ مالکیت یکتای بودجه: فقط economy_system می‌نویسد government_revenue/spending")

if fail:
    print("\n❌ شکست:")
    for x in fail:
        print("  • " + x)
    sys.exit(1)
print("\nبودجه OK: هر %d ردیف، اهرم واقعی است و مالکیت بودجه یکتا است." % len(ROWS))
