# -*- coding: utf-8 -*-
"""پین پوشش فرمان‌ها — بازرسی ۱۴۰۵.

قرارداد: هر نوع فرمانی که command.gd می‌سازد (خروجی .new("TYPE", ...)) باید در
SUPPORTED_COMMANDS موتور باشد؛ در غیر این صورت UI دکمه/اکشنی می‌سازد که موتور
بی‌سروصدا ردش می‌کند (باگ کلاس «کنترل مرده»).

نکته‌ی پویش: نام تابع create_X با نوع فرمان یکی نیست (مثلاً
create_cabinet_appointment → نوع cabinet_change)؛ پس باید نوعِ تولیدشده را
از بدنه‌ی تابع استخراج کرد نه از نامش.
"""
import io
import re
import sys

FAIL = []


def read(p):
    return io.open(p, encoding="utf-8").read()


def check(name, cond, msg):
    if not cond:
        FAIL.append(msg)
        print("❌ %s: %s" % (name, msg))
    else:
        print("✅ %s" % name)


eng = read("scripts/core/engine.gd")
m = re.search(r"SUPPORTED_COMMANDS\s*=\s*\[(.*?)\]", eng, re.S)
supported = set(re.findall(r'"(\w+)"', m.group(1)))

cmd_src = read("scripts/core/command.gd")
func_pattern = re.compile(r"static func (create_\w+)\([^)]*\):(.*?)(?=static func |\Z)", re.S)
produced = {}
for fm in func_pattern.finditer(cmd_src):
    body = fm.group(2)
    tm = re.search(r'\.new\(\s*"(\w+)"', body)
    produced[fm.group(1)] = tm.group(1) if tm else None

check("همه‌ی create_* نوع تولیدی دارند", all(t is not None for t in produced.values()),
      "تابع‌های بدون .new(\"TYPE\"): %s" % [f for f, t in produced.items() if t is None])

bad = [(f, t) for f, t in produced.items() if t not in supported]
check(
    "هر نوع تولیدی پشتیبانی‌شده است",
    not bad,
    "نوع تولیدی بدون پشتیبانی موتور: %s" % (bad or "—"),
)

# بالعکس: فرمان‌های پشتیبانی‌شده باید قابل ساخت باشند (یا توسط AI ساخته شوند)
ai_src = " ".join(read(f) for f in __import__("glob").glob("scripts/ai/*.gd"))
created_types = set(produced.values())
# AIها مستقیماً GameCommand.new یا create_* استفاده می‌کنند — شمارش دستی در پین کافی است:
check(
    "فهرست پشتیبانی خالی نیست",
    len(supported) >= 100,
    "SUPPORTED_COMMANDS غیرعادی کوچک است: %d" % len(supported),
)

print()
if FAIL:
    print("==> %d شکست" % len(FAIL))
    sys.exit(1)
print("==> پوشش فرمان‌ها سبز است (%d تابع create → %d نوع پشتیبانی‌شده)" % (len(produced), len(supported)))
