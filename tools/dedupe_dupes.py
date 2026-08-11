#!/usr/bin/env python3
# حذف نسخه‌های تکراری توابع سطح‌بالا (نگه‌داشتن نخستین نسخه) — تعمیر کامیت‌های عمیق‌سازی
import os, re

ROOT = "scripts"
DECL = re.compile(r'^(func|static func|var|const|signal|class|enum|@[a-zA-Z])')
FUNC = re.compile(r'^(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(')

def dedupe(path):
    lines = open(path, encoding='utf-8').read().split('\n')
    n = len(lines)
    decls = [i for i, l in enumerate(lines) if DECL.match(l)]
    decls.append(n)  # پایان‌یاب مجازی
    spans = []  # (start, end_after_this_decl_start, name)
    for k, s in enumerate(decls):
        if s >= n:
            continue
        m = FUNC.match(lines[s])
        if not m:
            continue
        e = decls[k + 1]
        spans.append((s, e, m.group(1)))
    seen = {}
    delete_spans = []
    for s, e, name in spans:
        if name in seen:
            delete_spans.append((s, e, name))
        else:
            seen[name] = True
    if not delete_spans:
        return 0
    delset = set()
    for s, e, _name in delete_spans:
        for i in range(s, e):
            delset.add(i)
    out = [l for i, l in enumerate(lines) if i not in delset]
    # پاک‌سازی انتهای فایل: فقط یک خط‌جدید پایانی
    while len(out) > 1 and out[-1] == '' and out[-2] == '':
        out.pop()
    open(path, 'w', encoding='utf-8').write('\n'.join(out))
    return len(delete_spans)

total = 0
touched = []
for dirpath, _dirs, files in os.walk(ROOT):
    for fn in sorted(files):
        if not fn.endswith('.gd'):
            continue
        p = os.path.join(dirpath, fn)
        c = dedupe(p)
        if c:
            touched.append((p, c))
            total += c
print("REMOVED %d duplicate funcs from %d files" % (total, len(touched)))
for p, c in touched:
    print("%s: -%d" % (p, c))
