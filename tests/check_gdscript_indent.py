#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
بررسی ساختار تورفتگی فایل‌های GDScript — سبک و بدون نیاز به Godot.
قوانین:
۱) خط عمیق‌تر از خط معنادار قبلی فقط پس از بازکننده بلوک (پایان «:») مجاز است
۲) dedent باید به یکی از سطوح پشته برسد
۳) توازن کلی پرانتز/کروشه/آکولاد (رشته‌ها و کامنت‌ها مصون‌اند)
۴) ادامه‌خط با بک‌اسلش یا پرانتز باز، از قواعد بلوک مستثناست
۵) تورفتگی یکدست تب یا فاصله آزاد؛ مخلوط دو تای آن‌ها خطاست
خروجی: ۰ اگر سالم، ۱ با فهرست تخلف‌ها
"""
import sys, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def strip_comment(line: str) -> str:
    in_str = None
    i = 0
    out = []
    while i < len(line):
        ch = line[i]
        if in_str:
            out.append(ch)
            if ch == "\\" and i + 1 < len(line):
                out.append(line[i + 1]); i += 2; continue
            if ch == in_str:
                in_str = None
        else:
            if ch in ("\"", "'"):
                in_str = ch; out.append(ch)
            elif ch == "#":
                break
            else:
                out.append(ch)
        i += 1
    return "".join(out)

def check_file(path: str):
    errors = []
    with open(path, encoding="utf-8") as f:
        lines = f.read().splitlines()

    indent_stack = [0]
    paren_depth = 0
    prev_significant = None       # (indent, opens_block)
    bracket_balance = {40: 0, 91: 0, 123: 0}   # ( [ {
    pairs = {41: 40, 93: 91, 125: 123}
    continuation = False
    chain_indent = 0  # تورفتگی خط نخستِ جمله چندخطی

    for n, raw in enumerate(lines, 1):
        if not raw.strip():
            continue
        code = strip_comment(raw)
        if not code.strip():
            continue
        lead = raw[: len(raw) - len(raw.lstrip())]
        stripped = code.rstrip()
        is_continuation = continuation
        # مخلوط تب/فاصله فقط در شروع جمله خطاست؛ داخل عبارت چندخطی (کروشه/بک‌اسلش) آزاد است
        if not is_continuation and "\t" in lead and " " in lead:
            errors.append(f"{n}: تب و فاصله مخلوط در تورفتگی")
        indent = lead.count("\t") if "\t" in lead else len(lead) // 4
        if not is_continuation:
            chain_indent = indent

        if prev_significant is not None and not is_continuation:
            p_indent, p_opens = prev_significant
            if indent > p_indent:
                if not p_opens:
                    errors.append(f"{n}: تورفتگی غیرمنتظره (خط قبلی بلوک باز نمی‌کند): {stripped.strip()[:50]}")
                else:
                    indent_stack.append(indent)
            elif indent < p_indent:
                while len(indent_stack) > 1 and indent_stack[-1] > indent:
                    indent_stack.pop()
                if indent_stack[-1] != indent:
                    errors.append(f"{n}: dedent به سطح ناموجود ({indent} سطح): {stripped.strip()[:50]}")

        for ch in code:
            oc = ord(ch)
            if oc in bracket_balance:
                paren_depth += 1
                bracket_balance[oc] += 1
            elif oc in pairs:
                paren_depth = max(0, paren_depth - 1)
                bracket_balance[pairs[oc]] -= 1

        continuation = stripped.endswith("\\") or paren_depth > 0
        if not continuation:
            prev_significant = (chain_indent, stripped.endswith(":"))

    for oc, cnt in bracket_balance.items():
        if cnt != 0:
            errors.append(f"EOF: عدم‌توازن '{chr(oc)}' = {cnt}")
    return errors

def main():
    bad = 0
    files = []
    for root, _, names in os.walk(os.path.join(ROOT, "scripts")):
        for name in sorted(names):
            if name.endswith(".gd"):
                files.append(os.path.join(root, name))
    for path in files:
        errs = check_file(path)
        if errs:
            bad += 1
            print(f"❌ {os.path.relpath(path, ROOT)}")
            for e in errs[:5]:
                print(f"   {e}")
    if bad:
        print(f"\n{bad} فایل از {len(files)} خطای ساختاری دارد")
        return 1
    print(f"✅ ساختار تورفتگی و توازن براکت {len(files)} فایل GDScript سالم است")
    return 0

if __name__ == "__main__":
    sys.exit(main())
