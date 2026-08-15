#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""قرارداد بازار مالی جهانی + سناریوهای تاریخی — بازرسی ۱۴۰۵ دور سیزدهم.

بازی از نظر «اقتصاد مالی جهانی» و «بافت تاریخی» عمق گرفت:
- global_market_manager: شاخص سهام جهانی، شاخص دلار و احساس ریسک جهانی که به
  بحران‌های world_scope و شوک‌های تصادفی واکنش نشان می‌دهند و روی FDI و
  اعتماد سرمایه‌گذار داخلی اثر می‌گذارند.
- بحران‌های جهانی (نفت/تنگه/AI) به شاخص مالی اثر می‌زنند (crisis_chains).
- سناریوهای تاریخی (۱۹۷۳/۲۰۰۸/۲۰۲۰) با startup_effects و startup_crises.

خروج غیرصفر = نقض هر بند.
"""
import io
import json
import sys

fail = []

# ── بازار مالی جهانی ─────────────────────────────────────────────────────
gm = io.open("scripts/core/global_market_manager.gd", encoding="utf-8").read()
for needle, label in [
    ('world_stock_index', "شاخص سهام جهانی"),
    ('usd_index', "شاخص دلار"),
    ('risk_sentiment', "احساس ریسک جهانی"),
    ('func simulate_month', "شبیه‌سازی ماهانه"),
    ('fdi_global_factor', "اثر روی FDI"),
    ('global_financial_crisis', "بحران مالی جهانی تصادفی"),
    ('Deterministic', "دترمینیسم"),
]:
    if needle in gm:
        print("✅ global_market: %s" % label)
    else:
        fail.append("global_market: %s از دست رفته (%s)" % (label, needle))
if "randi" in gm or "randf" in gm:
    fail.append("global_market: RNG خام — دترمینیسم شکسته")
else:
    print("✅ global_market: بدون RNG خام")

# autoload
proj = io.open("project.godot", encoding="utf-8").read()
if 'GlobalMarketManager="*res://scripts/core/global_market_manager.gd"' in proj:
    print("✅ autoload GlobalMarketManager ثبت شده")
else:
    fail.append("project.godot: autoload GlobalMarketManager نیست")

# اتصال در engine
eng = io.open("scripts/core/engine.gd", encoding="utf-8").read()
if "GlobalMarketManager.simulate_month" in eng:
    print("✅ engine هر ماه بازار مالی جهانی را اجرا می‌کند")
else:
    fail.append("engine: GlobalMarketManager.simulate_month از دست رفته")

# اتصال به FDI
fdi = io.open("scripts/core/fdi_manager.gd", encoding="utf-8").read()
if "fdi_global_factor" in fdi:
    print("✅ fdi_manager از جو جهانی اثر می‌گیرد")
else:
    fail.append("fdi_manager: fdi_global_factor مصرف نشده")

# state init
st = io.open("scripts/core/state.gd", encoding="utf-8").read()
if '"global_market"' in st:
    print("✅ state.gd مقداردهی اولیه global_market")
else:
    fail.append("state.gd: global_market در init نیست")

# ── اتصال بحران‌های جهانی به شاخص مالی ───────────────────────────────────
chains = json.load(io.open("data/crisis_chains.json", encoding="utf-8"))["chains"]
wm = [c for c in chains if c.get("world_scope")]
if len(wm) >= 3:
    print("✅ %d بحران جهانی یافت شد" % len(wm))
else:
    fail.append("کمتر از ۳ بحران world_scope")
has_fin = any(
    any("global_market" in str(e.get("path", ""))
        for st2 in c["stages"] for k in ("on_enter_effects", "persist_effects")
        for e in st2.get(k, []))
    for c in wm)
if has_fin:
    print("✅ بحران‌های جهانی به شاخص مالی اثر می‌زنند")
else:
    fail.append("هیچ بحران جهانی به global_market اثر نمی‌زند")

# ── سناریوهای تاریخی ─────────────────────────────────────────────────────
sc = json.load(io.open("data/scenarios.json", encoding="utf-8"))["scenarios"]
hist = [s for s in sc if s.get("startup_effects") or s.get("startup_crises")]
if len(hist) >= 3:
    print("✅ %d سناریوی تاریخی با شرایط اولیه" % len(hist))
else:
    fail.append("کمتر از ۳ سناریوی تاریخی")
for s in hist:
    if not s.get("startup_effects"):
        fail.append("سناریوی %s بدون startup_effects" % s["id"])
    if s.get("startup_crises") and not s["startup_crises"][0].get("type"):
        fail.append("سناریوی %s: startup_crises بدون type" % s["id"])
sm = io.open("scripts/core/scenario_manager.gd", encoding="utf-8").read()
for needle, label in [
    ('_apply_startup_effect', "اعمال startup_effects"),
    ('startup_crises', "بحران‌های اولیه"),
    ('startup_effects', "اثرهای اولیه"),
]:
    if needle in sm:
        print("✅ scenario_manager: %s" % label)
    else:
        fail.append("scenario_manager: %s از دست رفته" % label)

# ── پایداری بلندمدت (آینهٔ ساده) ─────────────────────────────────────────
import random
random.seed(42)
idx = 1000.0; usd = 100.0; risk = 0.30
lo_idx = 1e9; hi_idx = 0; lo_usd = 1e9; hi_usd = 0
for turn in range(120):
    d = random.uniform(-0.8, 0.8); ud = random.uniform(-0.4, 0.4)
    if random.random() < 0.05:
        r = random.random()
        if r < 0.5:
            d -= 6.0; risk = min(0.95, risk + 0.20)
        else:
            d += 3.0; risk = max(0.05, risk - 0.08)
    idx = max(150.0, idx * (1.0 + d / 100.0))
    usd = max(50.0, usd * (1.0 + ud / 100.0))
    lo_idx = min(lo_idx, idx); hi_idx = max(hi_idx, idx)
    lo_usd = min(lo_usd, usd); hi_usd = max(hi_usd, usd)
if 150.0 <= lo_idx and hi_idx <= 3000.0 and 50.0 <= lo_usd and hi_usd <= 200.0:
    print("✅ پایداری ۱۰ ساله: شاخص سهام جهانی و دلار در محدوده")
else:
    fail.append("پایداری: شاخص/دلار از محدوده خارج شد (lo_idx=%.0f hi_idx=%.0f)" % (lo_idx, hi_idx))

# ── جمع‌بندی ─────────────────────────────────────────────────────────────
if fail:
    print("\n❌ GLOBAL MARKET + HISTORICAL FAILED:")
    for x in fail:
        print("  -", x)
    sys.exit(1)
print("\n=== ✅ GLOBAL MARKET + HISTORICAL OK ===")
