#!/usr/bin/env python3
# اسکنر هم‌پوشانی توابع سطح‌بالا در فایل‌های GDScript پس از کامیت‌های عمیق‌سازی
import os, re, sys

ROOT = "scripts"
DECL = re.compile(r'^(func|static func|var|const|signal|class|enum|@[a-zA-Z])')
FUNC = re.compile(r'^(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(')

def analyze(path):
    lines = open(path, encoding='utf-8').read().split('\n')
    n = len(lines)
    decls = []
    for idx, l in enumerate(lines):
        if DECL.match(l):
            decls.append(idx)
    decls.append(n)
    seen = {}
    dupes = []
    for k, s in enumerate(decls):
        if s >= n:
            continue
        m = FUNC.match(lines[s])
        if not m:
            continue
        name = m.group(1)
        e = decls[k + 1] if k + 1 < len(decls) else n
        body = '\n'.join(lines[s:e]).strip()
        if name in seen:
            same = (seen[name] == body)
            dupes.append((name, same, s, e))
        else:
            seen[name] = body
    return dupes

total_same = 0
total_diff = 0
hits = []
for dirpath, _dirs, files in os.walk(ROOT):
    for fn in sorted(files):
        if not fn.endswith(".gd"):
            continue
        path = os.path.join(dirpath, fn)
        dupes = analyze(path)
        if dupes:
            for name, same, s, _e in dupes:
                hits.append((path, name, same, s + 1))
                if same:
                    total_same += 1
                else:
                    total_diff += 1

print("FILES WITH DUPES: %d" % len(set(h[0] for h in hits)))
print("DUPE FUNCS identical: %d, DIFFERENT: %d" % (total_same, total_diff))
for path, name, same, ln in hits:
    print("%s:%d %s %s" % (path, ln, name, "SAME" if same else "*** DIFFERENT ***"))
