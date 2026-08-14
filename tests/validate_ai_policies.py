#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""قرارداد زنجیرهٔ بازخورد AI → سیاست (بازرسی ممیزی AI ۱۴۰۵).

هر شناسهٔ سیاستی که مشاوران AI از طریق create_policy_change توصیه می‌کنند باید در
رجیستری واقعی data/policies.json وجود داشته باشد؛ در غیر این صورت توصیهٔ مشاور به
اکشنی مرده می‌رسد (بازیکن روی آن کلیک می‌کند و هیچ اثری در شبیه‌سازی نمی‌شود).
همچنین هر اثر سیاست باید به کلیدی عددی واقعی اشاره کند (در کد نوشته یا در init آمده).

خروج غیرصفر = شناسهٔ مفقود یا مسیر اثر نامعتبر.
"""
import glob
import io
import json
import os
import re
import sys

fail = []

# رجیستری
with io.open("data/policies.json", encoding="utf-8") as fh:
    registry = json.load(fh)
reg_ids = set()
reg_paths = set()
for pol in registry.get("policies", []):
    reg_ids.add(pol.get("id", ""))
    for eff in pol.get("effects", []):
        reg_paths.add(str(eff.get("path", "")))

# شناسه‌های توصیه‌شده توسط AI
used = set()
for f in sorted(glob.glob("scripts/ai/*.gd")):
    src = io.open(f, encoding="utf-8").read()
    for m in re.finditer(r'create_policy_change\("(\w+)"', src):
        used.add(m.group(1))

missing = sorted(used - reg_ids)
if missing:
    for m in missing:
        fail.append("شناسهٔ سیاستِ توصیهٔ AI در رجیستری نیست: %s" % m)
else:
    print("✅ هر %d شناسهٔ سیاست توصیهٔ AI در رجیستری موجود است" % len(used))

# اعتبار مسیرهای اثر: section.key باید جایی در state واقعی باشد
state_src = io.open("scripts/core/state.gd", encoding="utf-8").read()
init_secs = set(re.findall(r'"(\w+)":\s*\{', state_src))
init_keys = set(re.findall(r'"([^"{}]{1,40})":', state_src))
written = {}
ALL_GD = glob.glob("scripts/**/*.gd", recursive=True)
for f in ALL_GD:
    src = io.open(f, encoding="utf-8").read()
    for m in re.finditer(r'state\["(\w+)"\]\["([^"]+)"\]', src):
        written.setdefault(m.group(1), set()).add(m.group(2))
    for vb in re.finditer(r'(\w+)\s*(?::\s*Dictionary)?\s*=\s*state(?:\.get\(\s*"(\w+)"|\["(\w+)"\])', src):
        var, sec = vb.group(1), vb.group(2) or vb.group(3)
        for w in re.finditer(r'\b%s\s*\["([^"]+)"\]\s*=' % re.escape(var), src):
            written.setdefault(sec, set()).add(w.group(1))
bad_paths = []
for path in reg_paths:
    parts = path.split(".")
    sec, key = parts[-2] if len(parts) > 1 else "", parts[-1]
    if key in written.get(sec, set()):
        continue
    if len(parts) == 2 and parts[0] in init_secs and key in init_keys:
        continue
    if sec in init_secs and key in init_keys:
        continue
    bad_paths.append(path)
if bad_paths:
    for p in sorted(set(bad_paths)):
        fail.append("مسیر اثر نامعتبر در رجیستری سیاست‌ها: %s" % p)
else:
    print("✅ هر %d مسیر اثر رجیستری به کلید واقعی state اشاره می‌کند" % len(reg_paths))

# ── کانال هزینهٔ سیاست‌ها (بازرسی ۱۴۰۵) ────────────────────────────────
# قرارداد منفی: هیچ اثری نباید مستقیم روی economy.national_debt بنشیند — هزینهٔ
# سیاست باید از کانال بودجه (policy_spending_monthly) عبور کند تا کسری واقعی نشان دهد.
for pol in registry.get("policies", []):
    for eff in pol.get("effects", []):
        if str(eff.get("path", "")) == "economy.national_debt":
            fail.append("اثر دورزنندهٔ بودجه در سیاست %s: ممانعت از national_debt مستقیم" % pol.get("id"))
    if "daily_cost" not in pol:
        fail.append("سیاست بدون daily_cost: %s" % pol.get("id"))
    elif abs(float(pol.get("daily_cost", 0.0))) > 25_000_000:
        fail.append("daily_cost غیرواقعی در %s" % pol.get("id"))
if not any("national_debt" in str(e.get("path", "")) for pol in registry.get("policies", []) for e in pol.get("effects", [])):
    print("✅ هیچ سیاستی مستقیم به بدهی نمی‌ریزد (کانال بودجه یکتا)")
pm = io.open("scripts/core/policy_manager.gd", encoding="utf-8").read()
if '"policy_spending_monthly"' in pm and "daily_cost" in pm:
    print("✅ policy_manager نرخ ماهانهٔ هزینهٔ سیاست‌ها را منتشر می‌کند")
else:
    fail.append("policy_manager دیگر policy_spending_monthly منتشر نمی‌کند")
es = io.open("scripts/systems/economy_system.gd", encoding="utf-8").read()
if '"policy_spending_monthly"' in es:
    print("✅ economy_system هزینهٔ سیاست‌ها را در بودجه مصرف می‌کند")
else:
    fail.append("economy_system کانال policy_spending_monthly را مصرف نمی‌کند")

if fail:
    print("\n❌ شکست قرارداد زنجیرهٔ AI→سیاست:")
    for x in fail:
        print("  • " + x)
    sys.exit(1)
print("\nزنجیرهٔ AI→سیاست OK: توصیه‌های مشاوران به اکشن‌های واقعی شبیه‌سازی وصل‌اند.")
