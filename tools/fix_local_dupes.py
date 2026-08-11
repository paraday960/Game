#!/usr/bin/env python3
# تبدیل تعریف مجدد متغیر محلی به انتساب ساده — در همان تابع و با دامنه‌بندی تورفتگی
import os, re

ROOT = "scripts"
FUNC_RE = re.compile(r'^(?:static\s+)?func\s+[A-Za-z_][A-Za-z0-9_]*\s*\(')
VAR_RE = re.compile(r'^(\s*)var\s+([A-Za-z_][A-Za-z0-9_]*)\b(.*)$')
FOR_RE = re.compile(r'for\s+([A-Za-z_][A-Za-z0-9_]*)\s+in\b')

def indent_of(l):
    w = 0
    for ch in l:
        if ch == '\t':
            w += 4
        elif ch == ' ':
            w += 1
        else:
            break
    return w

def fix_file(path):
    raw = open(path, encoding='utf-8').read()
    lines = raw.split('\n')
    out = []
    scopes = []  # پشته دامنه‌ها: (indent, set(names))
    in_func = False
    prev_indent = None
    fixes = 0
    for idx, l in enumerate(lines):
        stripped = l.strip()
        # خطوط خالی و توضیح ساختاری نیستند
        if stripped == '' or stripped.startswith('#'):
            out.append(l)
            continue
        ind = indent_of(l)
        if FUNC_RE.match(l) and ind == 0:
            in_func = True
            scopes = []
            prev_indent = None
        if not in_func:
            out.append(l)
            continue
        if prev_indent is None:
            scopes = [(ind, set())]
        else:
            if ind > prev_indent:
                scopes.append((ind, set()))
            elif ind < prev_indent:
                while scopes and scopes[-1][0] > ind:
                    scopes.pop()
                if not scopes:
                    scopes = [(ind, set())]
        # ثبت متغیر حلقه در دامنه فعلی
        fm = FOR_RE.search(l)
        if fm and scopes:
            scopes[-1][1].add(fm.group(1))
        m = VAR_RE.match(l)
        if m and scopes:
            name = m.group(2)
            visible = any(name in s[1] for s in scopes)
            if visible:
                # تعریف مجدد → انتساب ساده
                out.append("%s%s%s" % (m.group(1), name, m.group(3)))
                fixes += 1
                prev_indent = ind
                continue
            scopes[-1][1].add(name)
        prev_indent = ind
        out.append(l)
    if fixes:
        open(path, 'w', encoding='utf-8').write('\n'.join(out))
    return fixes

total = 0
touched = 0
for dirpath, _dirs, files in os.walk(ROOT):
    for fn in sorted(files):
        if not fn.endswith('.gd'):
            continue
        p = os.path.join(dirpath, fn)
        c = fix_file(p)
        if c:
            touched += 1
            total += c
print("DEMOTED %d local re-declarations in %d files" % (total, touched))
