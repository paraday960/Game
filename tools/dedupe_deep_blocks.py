#!/usr/bin/env python3
"""حذف بلوک‌های تکراری «لایه عمیق دوم» در سیستم‌ها و هوش‌های تخصصی.

قانون: بلوک دوم فقط وقتی حذف می‌شود که پس از نرمال‌سازی «var X = ...» به «X = ...»
دقیقاً با بلوک اول یکسان باشد. موارد متفاوت فقط گزارش می‌شوند.
"""
import glob, re, sys

HEADER = re.compile(r"^\s*# --- لایه عمیق دوم", re.MULTILINE)
RETURN_SUCCESS = re.compile(r'^\s*return \{"success"', re.MULTILINE)
RETURN_CMDS = re.compile(r"^\s*return cmds\b", re.MULTILINE)
VAR_ASSIGN = re.compile(r"^\s*var (\w+)\s*=")

def norm(block):
    # مقایسه فقط بر اساس محتوای معنایی: فاصله/تب ابتدای خط و «var» نادیده گرفته می‌شود؛
    # خط return پایانی متعلق به تابع است نه بلوک تکراری
    b = [VAR_ASSIGN.sub(r"\1 =", l.strip()) for l in block]
    while b and b[0] == "":
        b.pop(0)
    while b and (b[-1] == "" or b[-1].startswith("return")):
        b.pop()
    return b

def find_headers(lines):
    return [i for i, l in enumerate(lines) if HEADER.search(l)]

def dedupe_file(path, end_re):
    with open(path, encoding="utf-8") as f:
        lines = f.read().split("\n")
    removed_total = 0
    while True:
        hs = find_headers(lines)
        done = False
        for i in range(len(hs) - 1):
            h1, h2 = hs[i], hs[i + 1]
            # بلوک ۱: از هدر ۱ تا هدر ۲ | بلوک ۲: از هدر ۲ تا اولین return معیار
            r2 = next((j for j in range(h2 + 1, len(lines)) if end_re.search(lines[j])), None)
            if r2 is None:
                continue
            b1 = lines[h1:h2]
            b2 = lines[h2:r2]
            if norm(b1) == norm(b2):
                del lines[h2:r2]
                removed_total += r2 - h2
                done = True
                break
        if not done:
            break
    if removed_total:
        with open(path, "w", encoding="utf-8") as f:
            f.write("\n".join(lines))
    return removed_total

total = 0
skipped = []
files = sorted(glob.glob("scripts/systems/*.gd")) + sorted(glob.glob("scripts/ai/*.gd"))
for path in files:
    try:
        with open(path, encoding="utf-8") as f:
            src = f.read()
    except Exception:
        continue
    if HEADER.search(src) is None:
        continue
    lines = src.split("\n")
    hs = find_headers(lines)
    end_re = RETURN_SUCCESS if RETURN_SUCCESS.search(src) else RETURN_CMDS
    n = dedupe_file(path, end_re)
    if n:
        print(f"✅ {path}: {n} خط تکراری حذف شد")
        total += n
    else:
        if len(hs) >= 2:
            skipped.append(path)

print(f"\nمجموع: {total} خط تکراری حذف شد")
for p in skipped:
    print(f"⚠️ باقی ماند (بلوک‌های نایکسان — بررسی دستی): {p}")
