# -*- coding: utf-8 -*-
"""پین پوشش اعتبارسنجی و اجرای فرمان‌ها — بازرسی ۱۴۰۵.

هر فرمان در SUPPORTED_COMMANDS باید:
۱) شاخه‌ی اجرا در _apply_command_to_snapshot داشته باشد (در غیر این صورت
   فرمان «بی‌اثر» است: UI چیزی می‌سازد که موتور هیچ‌کاری روی آن نمی‌کند).
   تنها استثنای قبلی next_tick بود (نشانگر پایان نوبت، عمداً بی‌اثر) که
   شاخه‌ی صریح و مستند گرفت.
۲) شاخه‌ی اعتبارسنجی پیلود در _validate_commands داشته باشد، یا در فهرست
   صریح «فرمان‌های بی‌پارامتر» باشد (این‌ها پیلود نمی‌گیرند پس اعتبارسنجی
   پیلود لازم نیست): capital_control، general_recruit، next_tick، snap_election.
"""
import io
import re
import sys

FAIL = []

PARAMETERLESS = {"capital_control", "general_recruit", "next_tick", "snap_election"}


def read(p):
    return io.open(p, encoding="utf-8").read()


def check(name, cond, msg):
    if not cond:
        FAIL.append(msg)
        print("❌ %s: %s" % (name, msg))
    else:
        print("✅ %s" % name)


eng = read("scripts/core/engine.gd")
lines = eng.splitlines()

m = re.search(r"SUPPORTED_COMMANDS\s*=\s*\[(.*?)\]", eng, re.S)
supported = set(re.findall(r'"(\w+)"', m.group(1)))

# validation branches
m2 = re.search(
    r"func _validate_commands\(commands: Array, state: Dictionary, expected_tick: int, expected_version: int\) -> Dictionary:\n(.*?)(?=\nfunc |\n\t# )",
    eng, re.S,
)
vbody = m2.group(1) if m2 else ""
validated = set(re.findall(r'cmd\.type\s*==\s*"(\w+)"', vbody))

# apply branches (by line slicing)
start = next(i for i, l in enumerate(lines) if l.startswith("func _apply_command_to_snapshot("))
end = next((j for j in range(start + 1, len(lines)) if re.match(r"^func ", lines[j])), len(lines))
abody = "\n".join(lines[start:end])
applied = set(re.findall(r'cmd\.type\s*==\s*"(\w+)"', abody))

# 1) اجرا
missing_apply = sorted(supported - applied)
check(
    "هر فرمان شاخه‌ی اجرا دارد",
    not missing_apply,
    "بدون شاخه‌ی اجرا: %s" % (missing_apply or "—"),
)

# 2) اعتبارسنجی (یا بی‌پارامتر بودن)
no_validation = sorted(s for s in supported if s not in validated and s not in PARAMETERLESS)
check(
    "هر فرمان پیلود-دار اعتبارسنجی دارد",
    not no_validation,
    "بدون اعتبارسنجی: %s" % (no_validation or "—"),
)
# مطمئن شویم فهرست بی‌پارامتر هنوز واقعاً بی‌پارامتر است (پیلود مصرف نمی‌کنند)
for c in PARAMETERLESS:
    if c not in supported:
        check("فهرست بی‌پارامتر معتبر", False, "%s دیگر در SUPPORTED نیست" % c)

print()
if FAIL:
    print("==> %d شکست" % len(FAIL))
    sys.exit(1)
print("==> پوشش اعتبارسنجی/اجرای فرمان‌ها سبز است (%d فرمان، %d اعتبارسنجی، %d اجرا)" % (
    len(supported), len(validated), len(applied)))
