#!/usr/bin/env python3
# پویش کلید یتیم: کلیدهای init در state.gd که در هیچ‌جای کدبیس «خوانده» نمی‌شوند.
import os, re, sys, json

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATE_GD = os.path.join(ROOT, "scripts/core/state.gd")

# ---------- ۱) استخراج مسیرهای برگ از دیکشنری init ----------
def extract_paths():
    src = open(STATE_GD, encoding="utf-8").read()
    start = src.index("state = {")
    i = src.index("{", start)
    depth = 0
    stack = []
    leaves, containers = {}, set()
    pending_key = None
    n = len(src)
    while i < n:
        c = src[i]
        if c == '"':
            j = i + 1
            while j < n and src[j] != '"':
                if src[j] == "\\":
                    j += 1
                j += 1
            token = src[i + 1:j]
            k = j + 1
            while k < n and src[k] in " \t":
                k += 1
            if k < n and src[k] == ":" and stack and stack[-1][1]:
                pending_key = (stack[-1][0], token)
            i = j + 1
            continue
        if c == "#":
            while i < n and src[i] != "\n":
                i += 1
            continue
        if c == "{":
            if pending_key is not None:
                stack.append((tuple(list(pending_key[0]) + [pending_key[1]]), True))
                containers.add(stack[-1][0])
                pending_key = None
            else:
                base = stack[-1][0] if stack else ()
                stack.append((tuple(list(base) + ["[]"]), True))
            depth += 1
            i += 1
            continue
        if c == "[":
            if pending_key is not None:
                p = tuple(list(pending_key[0]) + [pending_key[1]])
                leaves[p] = True
                stack.append((p, False))
                pending_key = None
            else:
                base = stack[-1][0] if stack else ()
                stack.append((tuple(list(base) + ["[]"]), False))
            depth += 1
            i += 1
            continue
        if c in "}]":
            if stack:
                stack.pop()
            depth -= 1
            pending_key = None
            i += 1
            if depth == 0:
                break
            continue
        if c == "," and pending_key is not None:
            leaves[tuple(list(pending_key[0]) + [pending_key[1]])] = True
            pending_key = None
            i += 1
            continue
        i += 1
    for c_ in containers:
        leaves.pop(c_, None)
    return sorted(leaves)

# ---------- ۲) پاس خطی: شمارش خواندن/نوشتن ----------
RE_BRACKET = re.compile(r'\["([^"]+)"\]\s*(=|\+=|-=|\*=|/=)?')
RE_GET = re.compile(r'\.(?:get|has|erase)\("([^"]+)"')
RE_DOT = re.compile(r'\.([A-Za-z_]\w*)\s*(=|\+=|-=|\*=|/=)?')
RE_INITKEY = re.compile(r'"([^"]+)"\s*:')
RE_PATHSTR = re.compile(r'(?:get_value|apply_delta)\("([^"]+)"')

def strip_comments(line):
    out = []
    in_str = False
    for ch in line:
        if ch == '"':
            in_str = not in_str
        if ch == "#" and not in_str:
            break
        out.append(ch)
    return "".join(out)

def main():
    leaves = extract_paths()
    reads = {}   # seg -> count
    writes = {}
    segs = set(p[-1] for p in leaves if not p[-1].startswith("[]"))
    files = []
    for dirpath, _dirs, fs in os.walk(os.path.join(ROOT, "scripts")):
        for f in fs:
            if f.endswith(".gd"):
                fp = os.path.join(dirpath, f)
                if os.path.abspath(fp) != os.path.abspath(STATE_GD):
                    files.append(fp)
    seg_paths = {}
    for p in leaves:
        seg_paths.setdefault(p[-1], []).append(p)

    for fp in files:
        for line in open(fp, encoding="utf-8"):
            code = strip_comments(line)
            for m in RE_PATHSTR.finditer(code):
                last = m.group(1).split(".")[-1]
                if last in segs:
                    reads[last] = reads.get(last, 0) + 1
            for m in RE_GET.finditer(code):
                seg = m.group(1)
                if seg in segs:
                    reads[seg] = reads.get(seg, 0) + 1
            for m in RE_BRACKET.finditer(code):
                seg, op = m.group(1), m.group(2)
                if seg not in segs:
                    continue
                if op == "=":
                    writes[seg] = writes.get(seg, 0) + 1
                else:
                    reads[seg] = reads.get(seg, 0) + 1
            for m in RE_DOT.finditer(code):
                seg, op = m.group(1), m.group(2)
                if seg not in segs:
                    continue
                if op == "=":
                    writes[seg] = writes.get(seg, 0) + 1
                else:
                    reads[seg] = reads.get(seg, 0) + 1
            for m in RE_INITKEY.finditer(code):
                seg = m.group(1)
                if seg in segs:
                    writes[seg] = writes.get(seg, 0) + 1

    # دادهٔ JSON: کلیدهای پروفایل کشور ممکن است init-only شبیه باشند ولی از طریق apply_country_profile مصرف می‌شوند
    print(f"کلیدهای برگ: {len(leaves)} | بخش منحصربه‌فرد: {len(segs)} | فایل‌ها: {len(files)}")
    print(f"\n=== کلیدهای بدون هیچ خواندنی ===")
    count = 0
    for seg in sorted(segs):
        r = reads.get(seg, 0)
        w = writes.get(seg, 0)
        if r == 0:
            for p in seg_paths[seg]:
                print(f"  W={w:<3} {'.'.join(p)}")
                count += 1
    print(f"\nمجموع یتیم: {count}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
