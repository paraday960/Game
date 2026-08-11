#!/usr/bin/env python3
# حذف تعریف‌های تکراری متغیر سطح‌بالا (نگه‌داشتن نخستین) — ادامه تعمیر عمیق‌سازی
import os, re

ROOT = "scripts"
DECL = re.compile(r'^(func|static func|var|const|signal|class|enum|@[a-zA-Z])')
VARD = re.compile(r'^var\s+([A-Za-z_][A-Za-z0-9_]*)')

def fix(path):
    lines = open(path, encoding='utf-8').read().split('\n')
    n = len(lines)
    decls = [i for i, l in enumerate(lines) if DECL.match(l)]
    decls.append(n)
    seen = {}
    removed = []
    delset = set()
    for k, s in enumerate(decls):
        if s >= n:
            continue
        m = VARD.match(lines[s])
        if not m:
            continue
        name = m.group(1)
        e = decls[k + 1]
        if name in seen:
            # فقط خط تعریف متغیر حذف می‌شود (متغیرها تک‌خطی‌اند در این قالب)
            delset.add(s)
            removed.append((name, s + 1, lines[s].strip()))
        else:
            seen[name] = s
    if not delset:
        return []
    out = [l for i, l in enumerate(lines) if i not in delset]
    while len(out) > 1 and out[-1] == '' and out[-2] == '':
        out.pop()
    open(path, 'w', encoding='utf-8').write('\n'.join(out))
    return removed

total = 0
files = 0
for dirpath, _dirs, fs in os.walk(ROOT):
    for fn in sorted(fs):
        if not fn.endswith('.gd'):
            continue
        p = os.path.join(dirpath, fn)
        r = fix(p)
        if r:
            files += 1
            total += len(r)
print("REMOVED %d duplicate top-level vars from %d files" % (total, files))
