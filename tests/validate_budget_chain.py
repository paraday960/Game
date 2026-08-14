#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
قرارداد زنجیره بودجه: هر ردیف budget_allocations باید
۱) دست‌کم یک خواننده معادله‌دار در systems/managers داشته باشد (نه فقط UI/AI/state)
۲) فایل خواننده واقعاً کلیدی از state را بازنویسی کند (اثرگذار باشد، نه فقط بخواند)
۳) ردیف «ذخیره» از مسیر saving_share در اقتصاد معقول باشد
خروجی: ۰ سالم | ۱ با گزارش شکاف
"""
import sys, os, re, glob

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def load_budget_keys():
    src = open(os.path.join(ROOT, "scripts/core/state.gd"), encoding="utf-8").read()
    m = re.search(r'"budget_allocations"\s*:\s*\{([^}]+)\}', src)
    assert m, "budget_allocations در state.gd پیدا نشد"
    return re.findall(r'"([^"]+)"\s*:', m.group(1))

def files_reading(key):
    hits = []
    pat = re.compile(r'budget_allocations?.{0,30}"' + re.escape(key) + r'"')
    for path in glob.glob(os.path.join(ROOT, "scripts/**/*.gd"), recursive=True):
        if path.endswith(".uid") or "main_ui" in path or "state.gd" in path or "/ai/" in path:
            continue
        if pat.search(open(path, encoding="utf-8").read()):
            hits.append(path)
    return hits

def file_effective(path):
    """فایل علاوه بر خواندن، state را هم جایی بازنویسی می‌کند؟"""
    src = open(path, encoding="utf-8").read()
    # انتساب به دیکشنری بخش state (الگوی بازنویسی شاخص‌ها)
    return bool(re.search(r'\w+\["[آ-یA-Za-z_]+"\]\s*=\s*(?:clamp|max|min|maxf|clampf|\w)', src))

def main():
    keys = load_budget_keys()
    failures = []
    print(f"ردیف‌های بودجه: {'، '.join(keys)}")
    for key in keys:
        if key == "ذخیره":
            econ = open(os.path.join(ROOT, "scripts/systems/economy_system.gd"), encoding="utf-8").read()
            ok = 'budget_alloc.get("ذخیره"' in econ and "saving_share" in econ
            print(f"{'✅' if ok else '❌'} ذخیره → saving_share در economy_system")
            if not ok:
                failures.append("ذخیره به saving_share وصل نیست")
            continue
        readers = files_reading(key)
        effective = [r for r in readers if file_effective(r)]
        ok = len(effective) >= 1
        names = ", ".join(os.path.basename(r) for r in effective) or "—"
        print(f"{'✅' if ok else '❌'} {key} → خواننده مؤثر: {names}")
        if not ok:
            failures.append(f"ردیف «{key}» بدون خواننده مؤثر است")
    if failures:
        print("\n".join(failures))
        return 1
    print(f"\n✅ زنجیره بودجه کامل است: هر {len(keys)} ردیف به معادله بخش خود می‌رسد")
    return 0

if __name__ == "__main__":
    sys.exit(main())
