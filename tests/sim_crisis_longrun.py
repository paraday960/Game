#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""آینهٔ بلندمدت نخ‌های بحران (Crisis Threads Mirror) — بازرسی ۱۴۰۵ دور سیزدهم.

هستهٔ شبیه‌سازی در Godot است و در سندباکس اجرا نمی‌شود؛ این آینه منطق
رجیستری crisis_chains.json را در پایتون خام بازتولید می‌کند تا ثابت کند
زنجیره‌ها در افق ۱۰ سال:
- تریگر می‌شوند، مراحل را پیش می‌برند و نهایتاً پایان می‌یابند (چرخهٔ کامل)؛
- اثرهای مرحله/اسکار با min/max خودشان (که در validate_crisis_chains پین شده)
  شاخص‌های کلان را از محدودهٔ معقول خارج نمی‌کنند؛
- کولداون و سقف نمونهٔ هم‌زمان (max_instances) رعایت می‌شود؛
- همه‌چیز دترمینستیک است (بدون RNG خام؛ فقط چرخهٔ شبه‌تصادفی ثابت).

خروج غیرصفر = نقض پایداری.
"""
import io
import json
import random
import sys

random.seed(12345)  # seed ثابت (مثل Deterministic موتور)

FAIL = []


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def read_path(state, path):
    cur = state
    for part in path.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return None
        cur = cur[part]
    return cur


def apply_effect(state, eff):
    path = str(eff.get("path", ""))
    parts = path.split(".")
    cur = state
    for part in parts[:-1]:
        if not isinstance(cur, dict):
            return
        cur = cur.setdefault(part, {})
    leaf = parts[-1]
    op = eff.get("op", "add")
    value = float(eff.get("value", 0.0))
    lo = eff.get("min")
    hi = eff.get("max")
    if isinstance(cur, dict):
        old = cur.get(leaf, 0.0)
        try:
            old = float(old)
        except (TypeError, ValueError):
            old = 0.0
        if op == "add":
            new = old + value
        elif op == "mul":
            new = old * value
        elif op == "set":
            new = value
        else:
            return
        if lo is not None and hi is not None:
            new = clamp(new, float(lo), float(hi))
        cur[leaf] = new


def initial_state():
    # همتای state برای تست تعادل نخ‌ها (کلیدهایی که زنجیره‌ها لمس می‌کنند)
    return {
        "economy": {
            "gdp": 500e9, "growth_rate": 0.02, "inflation": 0.08,
            "unemployment": 0.08, "national_debt": 200e9,
            "foreign_reserves": 60e9, "debt_to_gdp": 0.4, "gdp_per_capita": 5000.0,
            "policy_costs": {"فشار صندوق بازنشستگی": 500e6},
        },
        "population": {
            "total": 85e6, "happiness": 0.60, "satisfaction": 0.62,
            "workforce": 55e6, "migration_net": 10000.0,
            "age_structure": {"سالمند": 0.10, "کودک": 0.25, "بزرگسال": 0.45, "جوان": 0.20},
        },
        "politics": {"stability": 0.60, "trust": 0.55, "tension": 0.35, "legitimacy": 0.60},
        "welfare": {"poverty": 0.15, "gini": 0.38, "pension_pressure_structural": 0.30,
                    "social_safety": 0.60},
        "health": {"quality": 0.60, "coverage": 0.75, "vaccination": 0.55},
        "agriculture": {"food_security": 0.65, "irrigated_land": 0.30},
        "resources": {"inventory": {"نفت": 80.0, "غذا": 85.0, "برق": 100.0}},
        "commodities": {"prices": {"نفت": 75.0, "گاز": 3.2, "گندم": 260.0, "فلزات": 1800.0}},
        "central_bank": {"exchange_rate": 1.0, "interest_rate": 0.15, "credit_growth": 0.10},
        "banking": {"bank_health": 0.70, "credit_growth": 0.10},
        "financial_services": {"trust_banks": 0.60, "investor_confidence": 0.55},
        "stock_market": {"investor_confidence": 0.55},
        "shadow": {"size": 0.18},
        "transport_detail": {"logistics_efficiency": 0.60},
        "trade": {"balance": 10e9},
        "diplomacy": {"influence": 45.0},
        "military": {"war_exhaustion": 0.0, "deterrence": 60.0},
        "environment": {"green_energy_share": 0.20, "carbon_emission": 0.50},
        "technology": {"research_rate": 20.0, "branches": {"دیجیتال": 0.30, "انرژی_پاک": 0.15}},
        "education": {"human_capital": 0.60},
        "ai_policy": {"productivity": 0.15},
        "demographic_policy": {"pension_fund": 0.55, "fertility_incentive": 0.20},
        "emergency": {"preparedness": 0.50},
        "public_services_detail": {},
        "migration": {"integration": 0.30},
        # مدیریت بحران
        "events_active": [],
        "crisis_cooldowns": {},
        "crisis_scars": [],
    }


def load_chains():
    with io.open("data/crisis_chains.json", encoding="utf-8") as fh:
        data = json.load(fh)
    return data["chains"]


def triggered(state, chain):
    trig = chain.get("trigger", {})
    if isinstance(trig, dict):
        mode = trig.get("mode", "all")
        conditions = trig.get("conditions", [])
    else:
        mode = chain.get("trigger_mode", "all")
        conditions = trig
    if not conditions:
        return False
    for cond in conditions:
        value = read_path(state, str(cond.get("path", "")))
        if not isinstance(value, (int, float)):
            if mode == "all":
                return False
            continue
        op = cond.get("op", ">")
        hit = float(value) > float(cond["value"]) if op == ">" else float(value) < float(cond["value"])
        if mode == "any" and hit:
            return True
        if mode == "all" and not hit:
            return False
    return mode == "all"


def simulate_month(state, chains, turn):
    """یک ماه: اثر اسکارها، پیشروی/پایان نخ‌ها، تریگر نخ‌های تازه."""
    events = []
    DAYS = 30
    current_day = turn * DAYS

    # اسکارها
    kept_scars = []
    for scar in state["crisis_scars"]:
        if current_day >= scar.get("expires_day", current_day + 1):
            events.append("scar_healed:" + scar.get("title_fa", ""))
            continue
        for eff in scar.get("effects", []):
            apply_effect(state, eff)
        kept_scars.append(scar)
    state["crisis_scars"] = kept_scars

    # نخ‌های فعال
    kept = []
    for crisis in state["events_active"]:
        chain_def = next((c for c in chains if c["id"] == crisis["type"]), None)
        if current_day >= crisis.get("expires_day", current_day + 1):
            if chain_def and crisis["stage"] < crisis["stage_count"] - 1:
                # پیشروی مرحله
                crisis["stage"] += 1
                st = chain_def["stages"][crisis["stage"]]
                crisis["stage_name_fa"] = st.get("name_fa", "")
                crisis["started_day"] = current_day
                crisis["expires_day"] = current_day + st.get("duration_days", 90)
                for eff in st.get("on_enter_effects", []):
                    apply_effect(state, eff)
                events.append("stage:" + crisis["title"])
                kept.append(crisis)
                continue
            # پایان کامل
            if chain_def:
                last = chain_def["stages"][-1]
                for eff in last.get("resolve_effects", []):
                    apply_effect(state, eff)
                state["crisis_cooldowns"][crisis["type"]] = current_day + chain_def.get("cooldown_days", 120)
                scar_def = chain_def.get("scar", {})
                if scar_def:
                    if len(state["crisis_scars"]) >= 3:
                        state["crisis_scars"].pop(0)
                    state["crisis_scars"].append({
                        "title_fa": scar_def.get("title_fa", "اسکار"),
                        "effects": scar_def.get("effects", []),
                        "started_day": current_day,
                        "expires_day": current_day + int(scar_def.get("duration_months", 12)) * 30,
                    })
                    events.append("scar:" + scar_def.get("title_fa", ""))
            else:
                state["crisis_cooldowns"][crisis["type"]] = current_day + 120
            events.append("resolved:" + crisis["title"])
            continue
        # اثر ماندگار مرحله
        if chain_def:
            st = chain_def["stages"][clamp(crisis["stage"], 0, len(chain_def["stages"]) - 1)]
            for eff in st.get("persist_effects", []):
                apply_effect(state, eff)
        kept.append(crisis)
    state["events_active"] = kept

    # تریگر نخ‌های تازه
    active_types = {c["type"] for c in kept}
    for chain in chains:
        if len(kept) >= 4:
            break
        ctype = chain["id"]
        if ctype in active_types:
            continue
        if state["crisis_cooldowns"].get(ctype, -1) > current_day:
            continue
        instances = sum(1 for c in kept if c["type"] == ctype)
        if instances >= chain.get("max_instances", 1):
            continue
        if not triggered(state, chain):
            continue
        if random.random() > chain.get("chance", 0.1):
            continue
        st0 = chain["stages"][0]
        for eff in st0.get("on_enter_effects", []):
            apply_effect(state, eff)
        kept.append({
            "type": ctype,
            "title": chain.get("title_fa", ctype),
            "severity": chain.get("severity", 2),
            "status": "active",
            "stage": 0,
            "stage_count": len(chain["stages"]),
            "stage_name_fa": st0.get("name_fa", ""),
            "started_day": current_day,
            "expires_day": current_day + st0.get("duration_days", 90),
        })
        active_types.add(ctype)
        events.append("start:" + ctype)
    state["events_active"] = kept
    return events


def run(years=10):
    chains = load_chains()
    state = initial_state()
    total_months = years * 12
    chain_starts = {}
    chain_resolves = {}
    max_active = 0
    extremes = {
        "inflation": (1.0, 0.0), "debt_to_gdp": (0.0, 0.0),
        "foreign_reserves": (1e18, 0.0), "growth": (1.0, -1.0),
        "happiness": (1.0, 0.0), "exchange_rate": (1e9, 0.0),
        "unemployment": (1.0, 0.0), "gini": (1.0, 0.0),
    }

    for turn in range(total_months):
        events = simulate_month(state, chains, turn)
        # ثبت آمار
        for e in events:
            if e.startswith("start:"):
                chain_starts[e[6:]] = chain_starts.get(e[6:], 0) + 1
            elif e.startswith("resolved:"):
                chain_resolves[e[9:]] = chain_resolves.get(e[9:], 0) + 1
        max_active = max(max_active, len(state["events_active"]))
        # ثبت حدها
        e = state["economy"]
        extremes["inflation"] = (min(extremes["inflation"][0], e["inflation"]), max(extremes["inflation"][1], e["inflation"]))
        extremes["debt_to_gdp"] = (min(extremes["debt_to_gdp"][0], e["debt_to_gdp"]), max(extremes["debt_to_gdp"][1], e["debt_to_gdp"]))
        extremes["foreign_reserves"] = (min(extremes["foreign_reserves"][0], e["foreign_reserves"]), max(extremes["foreign_reserves"][1], e["foreign_reserves"]))
        extremes["growth"] = (min(extremes["growth"][0], e["growth_rate"]), max(extremes["growth"][1], e["growth_rate"]))
        p = state["population"]
        extremes["happiness"] = (min(extremes["happiness"][0], p["happiness"]), max(extremes["happiness"][1], p["happiness"]))
        cb = state["central_bank"]
        extremes["exchange_rate"] = (min(extremes["exchange_rate"][0], cb["exchange_rate"]), max(extremes["exchange_rate"][1], cb["exchange_rate"]))
        extremes["unemployment"] = (min(extremes["unemployment"][0], e["unemployment"]), max(extremes["unemployment"][1], e["unemployment"]))
        w = state["welfare"]
        extremes["gini"] = (min(extremes["gini"][0], w["gini"]), max(extremes["gini"][1], w["gini"]))

    print("═══ آینهٔ نخ‌های بحران — %d سال (%d ماه) ═══" % (years, total_months))
    print("  تریگر زنجیره‌ها: %s" % ", ".join("%s=%d" % (k, v) for k, v in sorted(chain_starts.items())))
    print("  پایان زنجیره‌ها: %s" % ", ".join("%s=%d" % (k, v) for k, v in sorted(chain_resolves.items())))
    print("  حداکثر بحران‌های هم‌زمان: %d (سقف ۴)" % max_active)
    print("  اسکارهای فعال در پایان: %d (سقف ۳)" % len(state["crisis_scars"]))
    for k, (lo, hi) in sorted(extremes.items()):
        print("  %-18s min=%.4f  max=%.4f" % (k, lo, hi))
    return state, extremes, chain_starts, chain_resolves, max_active


def check(state, extremes, chain_starts, chain_resolves, max_active):
    ok = True
    # ۱) حداقل چند زنجیره باید در ۱۰ سال تریگر و پایان یافته باشد (چرخهٔ کامل)
    if sum(chain_starts.values()) < 4:
        FAIL.append("خیلی کم تریگر: فقط %d زنجیره در ۱۰ سال" % sum(chain_starts.values()))
        ok = False
    if sum(chain_resolves.values()) < 2:
        FAIL.append("خیلی کم پایان: فقط %d زنجیره پایان یافت (چرخهٔ ناتمام؟)" % sum(chain_resolves.values()))
        ok = False
    # ۲) سقف هم‌زمانی
    if max_active > 4:
        FAIL.append("تعداد بحران‌های هم‌زمان از سقف ۴ گذشت: %d" % max_active)
        ok = False
    # ۳) شاخص‌ها در محدودهٔ معقول
    e = state["economy"]
    if not (0.0 <= e["inflation"] <= 0.60):
        FAIL.append("تورم از محدوده خارج شد: %.3f" % e["inflation"]); ok = False
    if extremes["inflation"][1] > 0.60 or extremes["inflation"][0] < 0.0:
        FAIL.append("تورم در مسیر از محدوده خارج شد: %s" % (extremes["inflation"],)); ok = False
    if not (0.0 <= e["debt_to_gdp"] <= 3.0):
        FAIL.append("بدهی/GDP از محدوده خارج شد: %.3f" % e["debt_to_gdp"]); ok = False
    if extremes["debt_to_gdp"][1] > 3.0:
        FAIL.append("بدهی/GDP در مسیر از ۳ گذشت: %.3f" % extremes["debt_to_gdp"][1]); ok = False
    if extremes["foreign_reserves"][0] < 0.0:
        FAIL.append("ذخایر ارزی منفی شد: %.0f" % extremes["foreign_reserves"][0]); ok = False
    if not (0.0 <= state["central_bank"]["exchange_rate"] <= 10.0):
        FAIL.append("نرخ ارز از محدوده خارج شد: %.3f" % state["central_bank"]["exchange_rate"]); ok = False
    if extremes["exchange_rate"][1] > 10.0 or extremes["exchange_rate"][0] <= 0.0:
        FAIL.append("نرخ ارز در مسیر از محدوده خارج شد: %s" % (extremes["exchange_rate"],)); ok = False
    if extremes["growth"][0] < -0.15 or extremes["growth"][1] > 0.20:
        FAIL.append("رشد از محدوده خارج شد: %s" % (extremes["growth"],)); ok = False
    if extremes["happiness"][0] < 0.05 or extremes["happiness"][1] > 0.95:
        FAIL.append("شادی از محدوده خارج شد: %s" % (extremes["happiness"],)); ok = False
    if extremes["gini"][0] < 0.0 or extremes["gini"][1] > 1.0:
        FAIL.append("جینی از محدوده خارج شد: %s" % (extremes["gini"],)); ok = False
    # ۴) دترمینیسم: اجرای دوباره با همان seed باید همان خروجی را بدهد
    return ok


def check_determinism():
    chains = load_chains()
    s1 = initial_state()
    s2 = initial_state()
    rnd_state = random.getstate()
    for turn in range(120):
        simulate_month(s1, chains, turn)
    random.setstate(rnd_state)
    for turn in range(120):
        simulate_month(s2, chains, turn)
    same = (s1["economy"]["inflation"] == s2["economy"]["inflation"]
            and s1["economy"]["national_debt"] == s2["economy"]["national_debt"]
            and [c["type"] for c in s1["events_active"]] == [c["type"] for c in s2["events_active"]])
    if not same:
        FAIL.append("دترمینیسم شکست: دو اجرا با seed یکسان نتیجه‌ی متفاوت دادند")
        return False
    print("✅ دترمینیسم: دو اجرای ۱۰ساله با seed یکسان نتیجهٔ یکسان دارند")
    return True


def main():
    state, extremes, starts, resolves, max_active = run(10)
    print()
    ok = check(state, extremes, starts, resolves, max_active)
    print()
    ok = check_determinism() and ok
    print()
    # ── سناریوی «کشور در فشار»: زنجیره‌های شرطی (خشکسالی/تحریم/بانکی/همه‌گیری/
    # انتخابات/پناهندگان/جمعیت) را هم باید پوشش دهیم، نه فقط جهانی‌ها ──
    ok = run_pressure_scenario() and ok
    print()
    if FAIL:
        print("═══ شکست — %d نقض پایداری نخ‌های بحران ═══" % len(FAIL))
        for f in FAIL:
            print("  • " + f)
        sys.exit(1)
    print("═══ موفق — نخ‌های بحران در افق ۱۰ سال پایدار و در محدوده‌اند ═══")


def run_pressure_scenario(years=10):
    """کشوری که از قبل در فشار است: شرط‌های زنجیره‌های داخلی برقرار است."""
    chains = load_chains()
    state = initial_state()
    # فشار اولیه: خشکسالی + بی‌ثباتی + ضعف سلامت + فشار صندوق + تنش
    state["agriculture"]["food_security"] = 0.45
    state["resources"]["inventory"]["غذا"] = 35.0
    state["politics"]["stability"] = 0.40
    state["politics"]["tension"] = 0.62
    state["diplomacy"]["influence"] = 25.0
    state["health"]["quality"] = 0.42
    state["banking"]["bank_health"] = 0.38
    state["financial_services"]["trust_banks"] = 0.40
    state["stock_market"]["investor_confidence"] = 0.38
    state["welfare"]["pension_pressure_structural"] = 0.45
    state["demographic_policy"]["pension_fund"] = 0.30
    state["population"]["age_structure"]["سالمند"] = 0.14
    state["economy"]["debt_to_gdp"] = 1.35
    state["economy"]["inflation"] = 0.27
    state["economy"]["foreign_reserves"] = 10e9
    state["military"]["war_exhaustion"] = 0.35
    state["migration"]["integration"] = 0.20
    state["technology"]["branches"]["دیجیتال"] = 0.40

    starts = {}
    total_months = years * 12
    max_active = 0
    for turn in range(total_months):
        events = simulate_month(state, chains, turn)
        for e in events:
            if e.startswith("start:"):
                starts[e[6:]] = starts.get(e[6:], 0) + 1
        max_active = max(max_active, len(state["events_active"]))

    print("═══ سناریوی فشار — %d سال ═══" % years)
    print("  تریگر زنجیره‌ها: %s" % ", ".join("%s=%d" % (k, v) for k, v in sorted(starts.items())) if starts else "  (هیچ!)")
    print("  حداکثر بحران‌های هم‌زمان: %d (سقف ۴)" % max_active)
    # پایداری نهایی
    e = state["economy"]
    p = state["population"]
    ok = True
    if not (0.0 <= e["inflation"] <= 0.60):
        FAIL.append("سناریوی فشار: تورم از محدوده خارج شد %.3f" % e["inflation"]); ok = False
    if not (0.0 <= e["debt_to_gdp"] <= 3.5):
        FAIL.append("سناریوی فشار: بدهی/GDP از محدوده خارج شد %.3f" % e["debt_to_gdp"]); ok = False
    if e["foreign_reserves"] < 0.0:
        FAIL.append("سناریوی فشار: ذخایر ارزی منفی شد %.0f" % e["foreign_reserves"]); ok = False
    if not (0.0 <= state["central_bank"]["exchange_rate"] <= 12.0):
        FAIL.append("سناریوی فشار: نرخ ارز از محدوده خارج شد %.3f" % state["central_bank"]["exchange_rate"]); ok = False
    if not (0.05 <= p["happiness"] <= 0.95):
        FAIL.append("سناریوی فشار: شادی از محدوده خارج شد %.3f" % p["happiness"]); ok = False
    if not (0.0 <= state["welfare"]["gini"] <= 1.0):
        FAIL.append("سناریوی فشار: جینی از محدوده خارج شد %.3f" % state["welfare"]["gini"]); ok = False
    # حداقل چند زنجیره‌ی داخلی باید تریگر شده باشد
    internal = {k: v for k, v in starts.items() if k not in ("oil_shock_world", "chokepoint_chain", "ai_revolution_chain")}
    if sum(internal.values()) < 3:
        FAIL.append("سناریوی فشار: فقط %d زنجیره‌ی داخلی تریگر شد (انتظار ≥ ۳)" % sum(internal.values()))
        ok = False
    return ok


if __name__ == "__main__":
    main()
