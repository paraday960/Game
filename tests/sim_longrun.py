#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""شبیه‌ساز بلندمدت (آینه عددی) — اجرای مجازی ۱۰ سال از حلقه‌های اصلی بازی.

بدون Godot، در پایتون خام، معادلات روزانهٔ هستهٔ کوپل‌شده را بازتولید می‌کند:
economy / population / politics / health / education / welfare / central_bank

هدف: اثبات پایداری تعادل در نقطهٔ شروع پیش‌فرض (بدون اقدام بازیکن) —
هیچ متغیری نباید به دیوارهٔ clamp بچسبد، منفجر شود یا فروفرورود.

ساده‌سازی‌های آگاهانه (بدون اثر قطعی بر نتیجهٔ پایداری):
- چرخهٔ اقتصادی روی فاز شروع «growth» (اثر +۰٫۰۰۴) ثابت نگه داشته می‌شود،
  چون گذر فازها دترمینستیک-تصادفی است و آزمونِ آینه، مسیرِ انتظاری است نه نمونهٔ تصادفی.
- نویزهای Deterministic با امید ریاضی صفر حذف می‌شوند.
- بحران انرژی/غذا در نقطهٔ شروع رخ نمی‌دهد (تولید > تقاضا؛ دریفت تقاضا ≈ ناچیز).
- جنگ/تحریم: ند (سناریوی پایه).
"""
import sys

FAIL = []
DAYS = 3650          # ۱۰ سال
DPM = 30             # روز در ماه (قرارداد موتور)

def clamp(x, lo, hi):
    return max(lo, min(hi, x))

# ───────── وضعیت اولیه — دقیقاً مطابق state.gd / BalanceConfig ─────────
def initial_state():
    return {
        # economy
        "gdp": 500_000_000_000.0, "growth_rate": 0.02, "real_growth": 0.02,
        "inflation": 0.08, "unemployment": 0.08, "tax_rate": 0.20,
        "national_debt": 200_000_000_000.0,
        "exports": 80e9, "imports": 70e9, "trade_balance": 10e9,
        "avg_wage": 4000.0,
        # تجارت و ارز (بازرسی تراز پرداخت‌ها — مدل سهم هدف از GDP + مخزن واحد ذخایر)
        "tariff_rate": 0.15, "customs_eff": 0.60, "export_div": 0.55,
        "industry_adv": 0.15, "exchange_rate": 1.0,
        "foreign_reserves": 60e9,
        # central bank (policy_mode=independent)
        "interest_rate": 0.15, "money_supply": 1.0, "inflation_target": 0.05,
        "independence": 0.70,
        # population
        "pop_total": 85_000_000.0, "birth_rate": 15.0, "death_rate": 8.0,
        "migration_net": 10000.0, "happiness": 0.60, "satisfaction": 0.62,
        "participation": 0.65, "workforce": 55_000_000.0, "urban_ratio": 0.75,
        # politics
        "stability": 0.60, "trust": 0.55, "corruption": 0.30, "tension": 0.35,
        # social
        "health_q": 0.60, "edu_q": 0.55, "literacy": 0.85,
        "poverty": 0.15, "gini": 0.38, "social_safety": 0.60,
        # منابع (ممیزی انرژی: تقاضای نسبی + جاذب تولید + انبار واقعی)
        "res_prod": {"برق": 15.0, "نفت": 8.0, "غذا": 10.0},
        "res_dem": {"برق": 12.0, "نفت": 6.0, "غذا": 9.0},
        "res_dem_base": {"برق": 12.0, "نفت": 6.0, "غذا": 9.0},
        "res_war_extra": {"برق": 0.0, "نفت": 0.0, "غذا": 0.0},
        "res_inv": {"برق": 100.0, "نفت": 80.0, "غذا": 85.0},
        "res_cap": {"برق": 100.0, "نفت": 100.0, "غذا": 100.0},
        "res_energy_crisis": False, "res_food_crisis": False,
        # سکونتگاه‌ها (تعمیق فاز B: بازخورد ظرفیت)
        "urban_pop": 85_000_000.0 * 0.75, "cities_large": 50, "cities_medium": 200,
        "cities_small": 350, "density": 1700.0, "crowding": 0.16,
        "service_access": 0.70, "housing_quality": 0.60,
        # ثابت‌های کند (در افق ۱۰ساله تقریباً ایستا)
        "skill_avg": 0.55, "skill_match": 0.60, "infra_q": 0.55,
        "infra_cap": 0.60, "tech_ind": 0.20, "tech_dig": 0.20,
        "rule_of_law": 0.60, "informal": 0.25, "policy_continuity": 0.50,
        # بودجه (state.gd)
        "alloc": {"آموزش": 0.08, "بهداشت": 0.10, "ارتش": 0.08, "زیرساخت": 0.18,
                  "رفاه": 0.15, "فناوری": 0.04, "امنیت": 0.05, "اداره": 0.07,
                  "محیط": 0.03, "ذخیره": 0.22},
    }

CYCLE_EFFECT = 0.004   # فاز «growth» در شروع

def step_day(s):
    """یک گام روزانه — آینهٔ دقیق معادلات سیستم‌ها (ترتیب system_order)."""
    # ── economy_system ──
    infra_effect = (s["infra_q"] - 0.5) * 0.02 + (s["infra_cap"] - 0.6) * 0.01
    workforce_effect = ((s["happiness"] - 0.5) * 0.02 + (s["participation"] - 0.65) * 0.01
                        + (s["skill_avg"] - 0.5) * 0.015 + (s["health_q"] - 0.5) * 0.01)
    tech_effect = s["tech_ind"] * 0.02 + s["tech_dig"] * 0.015
    stability_effect = (s["stability"] - 0.5) * 0.03 + (s["trust"] - 0.5) * 0.01
    # جناح شوک (سناریوی جنگ): پیش‌فرض صلح — مقادیر صفر/خاموش
    mobil = s.get("shock_mobil", 0.0)
    war_eco = s.get("shock_war_economy", 0.0)
    war_exh = s.get("shock_war_exhaustion", 0.0)
    n_sanc = s.get("shock_sanctions", 0)
    e_crisis = s.get("shock_energy_crisis", False) or s.get("res_energy_crisis", False)
    f_crisis = s.get("shock_food_crisis", False) or s.get("res_food_crisis", False)
    sanct_pen = n_sanc * 0.003
    energy_penalty = -0.025 if e_crisis else 0.0
    food_penalty = -0.018 if f_crisis else 0.0
    war_effect = 0.0
    if mobil > 0:
        war_effect = (0.008 if mobil == 2 else (-0.005 if mobil == 3 else -0.018)) - war_exh * 0.015
    growth_potential = clamp(0.02 + infra_effect + workforce_effect + tech_effect
                             + stability_effect, -0.05, 0.12)
    g_smoothed = clamp(s["growth_rate"] * 0.95 + growth_potential * 0.05, -0.10, 0.12)
    real_growth = clamp(g_smoothed + energy_penalty + food_penalty + war_effect - sanct_pen
                        + (CYCLE_EFFECT * 0.3 if mobil > 0 else CYCLE_EFFECT), -0.08, 0.10)
    s["gdp"] = max(s["gdp"] * (1.0 + real_growth / 365.0), 10e9)
    gdp_pc = s["gdp"] / s["pop_total"]
    s["growth_rate"], s["real_growth"] = g_smoothed, real_growth

    # بیکاری — لنگر NAIRU با تعدیل ناپایایی مهارت (پس از ادغام مدل رفاه)
    nairu = 0.06 + (1.0 - s["skill_match"]) * 0.08
    u = s["unemployment"]
    u += (nairu - u) * 0.0003 + (real_growth - 0.02) * -0.0008 / 30.0
    u = clamp(u, 0.02, 0.30)
    u += (-real_growth * 0.5 / 365.0 - mobil * 0.015 / 365.0
          + (s["tech_dig"] * 0.005 - s["tech_ind"] * 0.003) / 365.0) / DPM
    s["unemployment"] = clamp(u, 0.015, 0.40)

    # درآمد/هزینه/بدهی (نرخ ماهانه، به روز تسهیل)
    monthly_gdp = s["gdp"] / 12.0
    tax_eff = 0.75 + (1.0 - s["corruption"]) * 0.2 + s["infra_q"] * 0.05
    tax_rev = s["tax_rate"] * monthly_gdp * tax_eff
    resource_rev = (80.0 * 120e6 + 70.0 * 60e6) / 12.0
    # گمرک ماهانه = واردات سالانه/۱۲ × تعرفه × کارآمدی (بازرسی: ternary باگ‌دار قبلی حذف)
    customs = s["imports"] / 12.0 * s["tariff_rate"] * s["customs_eff"]
    seign = s["money_supply"] * 0.005 * monthly_gdp * 0.1
    revenue = (tax_rev + resource_rev + customs + seign)
    revenue = max(revenue * (1.0 - (s["corruption"] * 0.06 + s["informal"] * 0.08)), 1e9)
    if mobil > 0:
        revenue *= 0.9   # اختلال جنگی در مالیه
    saving = s["alloc"]["ذخیره"]
    spending = revenue * (1.0 - saving) * (2.2 if mobil > 0 else 1.0)
    if mobil > 0:
        spending += s["gdp"] * (0.002 + mobil * 0.001 + war_exh * 0.001) / 12.0  # هزینه جنگ (نرخ ماهانه)
    surplus = revenue - spending
    eff_rate = s["interest_rate"] * 0.6 + 0.12 * 0.4
    s["national_debt"] = max(s["national_debt"] - surplus / DPM
                             + s["national_debt"] * eff_rate / 365.0, 0.0)

    # تورم
    infl_change = ((s["money_supply"] - 1.0) * 0.010 + real_growth * 0.5 * 0.008
                   + (0.02 if energy_penalty < 0 else 0.0) + (0.01 if f_crisis else 0.0)
                   + war_eco * 0.03 + mobil * 0.005
                   + sanct_pen * 0.5 - 0.0015) / DPM
    s["inflation"] += infl_change + (s["inflation_target"] - s["inflation"]) * 0.12 / DPM
    if s["unemployment"] < 0.04:
        s["inflation"] += 0.0015 / DPM
    elif s["unemployment"] > 0.12:
        s["inflation"] -= 0.004 / DPM
    s["inflation"] = clamp(s["inflation"], -0.03, 0.60)

    # ── trade_system (بازرسی تراز پرداخت‌ها: مالکیت یکتا، مدل سهم هدف از GDP) ──
    # صادرات: رقابت‌پذیری + نرخ ارز + تنوع − تحریم؛ واردات: تعرفه − محاصره + اقتصاد جنگی
    block_pen = 0.05 if s.get("shock_blockaded", False) else 0.0
    exp_block_pen = 0.07 if s.get("shock_blockaded", False) else 0.0  # محاصره صادرات را هم می‌بندد
    comps = s["industry_adv"] * 0.5 + s["customs_eff"] * 0.3 - s["inflation"] * 0.5
    fx_bonus = (s["exchange_rate"] - 1.0) * 0.5
    exp_share_t = clamp(0.13 + comps * 0.03 + fx_bonus * 0.02 + s["export_div"] * 0.02
                        - n_sanc * 0.008 - exp_block_pen, 0.06, 0.25)
    s["exports"] = max(s["exports"] * 0.997 + s["gdp"] * exp_share_t * 0.003, 1e9)
    cover = s["foreign_reserves"] / max(s["imports"] / 12.0, 1.0)
    cover_pen = clamp((3.0 - cover) * 0.008, 0.0, 0.03)
    imp_share_t = clamp(0.16 - s["tariff_rate"] * 0.25 - block_pen + war_eco * 0.02 - cover_pen, 0.05, 0.30)
    s["imports"] = max(s["imports"] * 0.997 + s["gdp"] * imp_share_t * 0.003, 1e9)
    s["trade_balance"] = s["exports"] - s["imports"]

    # ── population_system (مدل هدف+بازگشت میانگین، τ≈۷ماه) ──
    welfare_effect = (gdp_pc / 5000.0 - 1.0) * 0.5 + s["poverty"] * -2.0
    birth_target = clamp(15.0 + welfare_effect + (s["happiness"] - 0.5) * 2.0, 5.0, 35.0)
    s["birth_rate"] += (birth_target - s["birth_rate"]) * 0.005
    death_target = clamp(8.0 + (s["health_q"] - 0.5) * -3.0, 4.0, 25.0)
    s["death_rate"] += (death_target - s["death_rate"]) * 0.005
    natural = (s["birth_rate"] - s["death_rate"]) / 1000.0
    mig_cap = max(s["pop_total"] * 0.02, 10000.0)
    s["migration_net"] = clamp(s["migration_net"] * 0.999, -mig_cap, mig_cap)
    s["growth_rate_pop"] = (natural + s["migration_net"] / s["pop_total"]) / 365.0
    s["pop_total"] = max(s["pop_total"] * (1.0 + s["growth_rate_pop"]), 1000.0)

    h_target = (0.05 + (1.0 - s["unemployment"]) * 0.2 + (1.0 - s["inflation"]) * 0.15
                + s["health_q"] * 0.15 + s["edu_q"] * 0.1 + (1.0 - s["poverty"]) * 0.2
                + s["trust"] * 0.1 - s["tension"] * 0.2 - (0.1 if e_crisis else 0.0) - (0.2 if f_crisis else 0.0))
    s["happiness"] = s["happiness"] * 0.95 + clamp(h_target, 0.05, 0.95) * 0.05
    s["satisfaction"] = s["happiness"] * 0.9 + s["trust"] * 0.1

    # ── settlements_system (مهاجرت با بازخورد ظرفیت تراکم) ──
    area = s["cities_large"] * 250.0 + s["cities_medium"] * 80.0 + s["cities_small"] * 25.0
    d_target = 7000.0 + s["housing_quality"] * 6000.0
    s["crowding"] = clamp((s["urban_pop"] / max(area, 1.0)) / d_target, 0.0, 1.5)
    capacity_factor = clamp(1.6 - s["crowding"], 0.15, 1.6)
    rural_stay = min((0.40 + 0.25 + 0.25 + 0.20) * 0.10, 0.45)
    attr = ((gdp_pc / 5000.0) * 0.3 + s["infra_q"] * 0.3 + s["service_access"] * 0.2 + 0.2) * (1.0 - rural_stay) * capacity_factor
    s["urban_pop"] = clamp(s["urban_pop"] + s["pop_total"] * 0.012 / 365.0 * attr,
                           s["pop_total"] * 0.05, s["pop_total"] * 0.90)
    s["urban_ratio"] = clamp(s["urban_pop"] / s["pop_total"], 0.0, 0.90)
    s["density"] = s["urban_pop"] / max(area, 1.0)

    # ── resources_system (برق/نفت/غذا: تقاضای نسبی + جاذب تولید + انبار) ──
    invest_factor = s["alloc"]["زیرساخت"] * 1.5 + 0.5
    rel_growth = s["growth_rate_pop"] * 365.0 * 0.4 + s["real_growth"] * 0.6
    for r in ("برق", "نفت", "غذا"):
        base = s["res_dem_base"][r]
        base = max(base + base * rel_growth / 365.0, 1.0)
        s["res_dem_base"][r] = base
        war_add = (mobil * 0.03 + 0.15) if mobil > 0 else 0.0
        we = s["res_war_extra"][r]
        we = we + base * war_add / 365.0 if war_add > 0.0 else we * (1.0 - 1.0 / 365.0)
        s["res_war_extra"][r] = we
        dem = max(base + we, 1.0)   # تقاضای مؤثر = بنیادی + افزونهٔ جنگی
        margin = 0.06 + invest_factor * 0.02 + 0.83 * 0.01
        target = min(dem * (1.0 + margin), s["res_cap"][r] * 1.2)
        pull = (0.04 + invest_factor * 0.02 + 0.83 * 0.02 + s["infra_q"] * 0.01) / 30.0
        prod = s["res_prod"][r]
        prod += (target - prod) * pull
        if mobil > 0 and r in ("نفت", "برق"):
            prod += mobil * 0.005 / 30.0
        if mobil >= 4 and r == "غذا":
            prod -= 0.008 / 30.0
        prod = clamp(prod, 1.0, s["res_cap"][r] * 1.2)
        net = prod - dem
        if net < 0:
            net *= 0.75   # واردات ~۲۵٪ کسری را پوشش می‌دهد
        s["res_inv"][r] = clamp(s["res_inv"][r] + net * 0.05, 0.0, 150.0)
        s["res_prod"][r], s["res_dem"][r] = prod, dem
    s["res_energy_crisis"] = s["res_inv"]["برق"] < 20.0 and s["res_dem"]["برق"] > 10.0
    s["res_food_crisis"] = s["res_inv"]["غذا"] < 30.0

    # ── politics_system ──
    econ_effect = ((-0.1 if s["unemployment"] > 0.12 else 0.0) + (-0.1 if s["inflation"] > 0.12 else 0.0)
                   + (-0.05 if mobil > 0 else 0.0))
    new_stab = clamp(0.6 + (s["happiness"] - 0.5) * 0.5 - s["corruption"] * 0.4
                     - s["gini"] * 0.3 + (s["trust"] - 0.5) * 0.3 + econ_effect
                     + (s["policy_continuity"] - 0.50) * 0.10, 0.05, 0.95)
    s["stability"] = s["stability"] * 0.97 + new_stab * 0.03
    trust_t = (0.5 + (s["stability"] - 0.5) * 0.3 + (1.0 - s["corruption"]) * 0.3
               + (s["satisfaction"] - 0.5) * 0.2 + (s["rule_of_law"] - 0.5) * 0.2)
    s["trust"] = clamp(s["trust"] * 0.98 + trust_t * 0.02, 0.05, 0.95)
    tens_t = (0.3 + (1.0 - s["happiness"]) * 0.4 + s["corruption"] * 0.2
              + s["gini"] * 0.2 + s["unemployment"] * 0.3)
    s["tension"] = clamp(s["tension"] * 0.97 + tens_t * 0.03, 0.0, 1.0)

    # ── health_system (کیفیت با بودجه) ──
    hb_share = s["alloc"]["بهداشت"]
    hb_budget = spending * hb_share
    hb_norm = max(s["gdp"], 1.0) * 0.02 / 12.0   # نُرم ۲٪ GDP عمومی (طبق مستندات تعادل)
    s["health_q"] = clamp(s["health_q"] + (hb_share - 0.08) * 0.01
                          + clamp(hb_budget / hb_norm - 1.0, -1.0, 1.0) * 0.001, 0.1, 0.95)

    # ── education_system (کیفیت) ──
    ed_share = s["alloc"]["آموزش"]
    qt = 0.4 + ed_share * 1.5 + (20.0 / 25.0) * 0.1 + s["tech_dig"] * 0.2
    s["edu_q"] = clamp(s["edu_q"] * 0.998 + qt * 0.002, 0.1, 0.95)

    # ── welfare_system (پس از ادغام بیکاری: فقط خواندن) ──
    poverty_t = (0.15 + s["unemployment"] * 0.8 - s["social_safety"] * 0.3
                 + s["gini"] * 0.2)
    s["poverty"] = clamp(s["poverty"] * 0.99 + poverty_t * 0.01, 0.02, 0.60)
    s["happiness"] = clamp(s["happiness"] + (0.08 - s["unemployment"]) * 0.001
                           + (0.15 - s["poverty"]) * 0.001, 0.05, 0.95)
    s["tension"] = clamp(s["tension"] + s["poverty"] * 0.002 + s["unemployment"] * 0.003, 0.0, 1.0)

    # ── central_bank_system (قاعدهٔ تیلور یکتا — پس از اتحاد دولایه، بازرسی بانک مرکزی) ──
    growth_gap = s["growth_rate"] - 0.025
    infl_gap = s["inflation"] - s["inflation_target"]
    taylor = clamp(s["inflation_target"] + s["inflation"] + 0.5 * infl_gap + 0.5 * growth_gap, 0.01, 0.60)
    pressure = (1.0 - s["independence"]) * 0.02 + (-0.01 if s["stability"] < 0.4 else 0.0)
    taylor_step = 0.010 + s["independence"] * 0.02   # سرعت وابسته به استقلال (تعادل ثابت)
    s["interest_rate"] = clamp(s["interest_rate"] * (1.0 - taylor_step) + (taylor + pressure) * taylor_step, 0.01, 0.60)
    money_change = (0.15 - s["interest_rate"]) * 0.01 + growth_gap * 0.005
    s["money_supply"] = clamp(s["money_supply"] + money_change * 0.01, 0.5, 1.8)

    # ذخایر ارزیِ واحد (بازرسی: cb/econ ادغام شدند) + نرخ ارز شناور
    # (در بازی بانک مرکزی تراز تیکِ قبل را می‌خواند؛ این‌جا همان تیک — تفاوت یک‌روزه ناچیز)
    s["foreign_reserves"] = max(s["foreign_reserves"] + s["trade_balance"] / 365.0 * 0.3, 0.0)
    trade_anchor = max(s["gdp"] * 0.2, 1e9)
    exch_change = (-s["trade_balance"] / trade_anchor * 0.02 * 0.01
                   - (s["inflation"] - 0.03) * 0.02 + (s["interest_rate"] - 0.05) * 0.03)
    s["exchange_rate"] = clamp(s["exchange_rate"] + exch_change * 0.01, 0.2, 5.0)

def run(years=10, verbose=True, policy_hook=None):
    s = initial_state()
    hist = []
    for day in range(1, DAYS + 1):
        if policy_hook is not None:
            policy_hook(day, s)
        step_day(s)
        for k, v in s.items():
            if isinstance(v, float) and (v != v or v in (float("inf"), float("-inf"))):
                FAIL.append(f"NaN/Inf در «{k}» در روز {day}")
                return s, hist
        if day % 365 == 0:
            hist.append((day // 365, dict(s)))
            if verbose:
                y = s
                print("سال %2d | GDP %5.0fB (سرانه %5.0f$) | رشد %+.1f%% | تورم %5.1f%% | بیکاری %4.1f%% | "
                      "بدهی/GDP %4.0f%% | جمعیت %5.1fM | تولد %4.1f مرگ %4.1f | شادی %.2f ثبات %.2f | "
                      "سلامت %.2f آموزش %.2f فقر %.2f | نرخ‌بهره %.2f پول %.2f | "
                      "تراز %+5.1fB ذخیره %4.0fB ارز %.2f" % (
                          day // 365, y["gdp"] / 1e9, y["gdp"] / y["pop_total"],
                          y["growth_rate"] * 100, y["inflation"] * 100, y["unemployment"] * 100,
                          y["national_debt"] / y["gdp"] * 100, y["pop_total"] / 1e6,
                          y["birth_rate"], y["death_rate"],
                          y["happiness"], y["stability"], y["health_q"], y["edu_q"],
                          y["poverty"], y["interest_rate"], y["money_supply"],
                          y["trade_balance"] / 1e9, y["foreign_reserves"] / 1e9, y["exchange_rate"]))
    return s, hist

def check_bounds(s, hist):
    """ادعاهای پایداری — هر نقض = شکست تست."""
    gdp_pc0 = 500e9 / 85e6
    gdp_pc_f = s["gdp"] / s["pop_total"]
    checks = [
        ("GDP نهایی مثبت و محدود", 100e9 < s["gdp"] < 2e12),
        ("رشد نهایی در دالان معقول (−۲٪ تا +۸٪)", -0.02 <= s["growth_rate"] <= 0.08),
        ("تورم نهایی (۰ تا ۲۵٪)", 0.0 <= s["inflation"] <= 0.25),
        ("بیکاری نهایی (۴ تا ۲۰٪)", 0.04 <= s["unemployment"] <= 0.20),
        ("نسبت بدهی به GDP زیر ۱۰۰٪ (بدون مارپیچ بدهی)", s["national_debt"] / s["gdp"] < 1.0),
        ("جمعیت در محدودهٔ واقع‌بینانه (۶۸M تا ۱۲۷M)", 68e6 <= s["pop_total"] <= 127e6),
        ("تولد به دیوارهٔ clamp نچسبیده", not (s["birth_rate"] >= 34.9 or s["birth_rate"] <= 5.1)),
        ("مرگ به دیوارهٔ clamp نچسبیده", not (s["death_rate"] >= 24.9 or s["death_rate"] <= 4.1)),
        ("شادی نهایی (۰٫۳ تا ۰٫۹۵)", 0.30 <= s["happiness"] <= 0.95),
        ("ثبات نهایی (۰٫۳ تا ۰٫۹۵)", 0.30 <= s["stability"] <= 0.95),
        ("کیفیت سلامت بالای کف بحران (≥۰٫۴)", s["health_q"] >= 0.40),
        ("فقر نهایی زیر ۳۵٪", s["poverty"] <= 0.35),
        ("نسبت شهری معقول (۵۰٪ تا ۹۰٪)", 0.50 <= s["urban_ratio"] <= 0.90),
        ("تراکم شهری مهارشده (<۱۶k نفر/km² — بازخورد ظرفیت کار می‌کند)", s["density"] < 16000),
        ("crowding نهایی زیر ۱٫۳۵", s["crowding"] < 1.35),
        ("انرژی: بدون بحران کاذب در خط پایه", not s["res_energy_crisis"] and not s["res_food_crisis"]),
        ("انرژی: تقاضای برق با اقتصاد رشد می‌کند (≥۱۴ تا سال ۱۰، از ۱۲)", s["res_dem"]["برق"] >= 14.0),
        ("انرژی: تولید برق به تقاضا+حاشیه همگرا می‌شود (فاصله < ۴ واحد)", abs(s["res_prod"]["برق"] - s["res_dem"]["برق"]) < 4.0),
        ("GDP سرانه ۱۰ساله در محدودهٔ واقعی (۰٫۹× تا ۱٫۶×)", 0.9 <= gdp_pc_f / gdp_pc0 <= 1.6),
        # ── تجارت و تراز پرداخت‌ها (بازرسی فاز تجارت) ──
        ("تجارت: سهم صادرات از GDP واقع‌بینانه (۶٪ تا ۲۸٪)", 0.06 < s["exports"] / s["gdp"] < 0.28),
        ("تجارت: سهم واردات از GDP واقع‌بینانه (۵٪ تا ۳۰٪)", 0.05 < s["imports"] / s["gdp"] < 0.30),
        ("تجارت: تراز نهایی مهارشده (<۵٪ GDP — بدون انفجار مازاد/کسری)", abs(s["trade_balance"]) < 0.05 * s["gdp"]),
        ("ذخایر ارزی: مثبت و مهارشده (<۴۰۰ میلیارد)", 0.0 < s["foreign_reserves"] < 400e9),
        ("نرخ ارز: در دالان معقول بدون چسبیدن به دیوارهٔ clamp", 0.25 < s["exchange_rate"] < 4.5),
    ]
    # پایداری مسیر: تورم در هیچ سالی ابرتورم نشود؛ شادی زیر آستانهٔ شورش نیاید
    for y, snap in hist[2:]:   # دو سال اول گذار آزاد
        checks.append((f"سال {y}: بدون ابرتورم (>۴۰٪)", snap["inflation"] <= 0.40))
        checks.append((f"سال {y}: شادی بالای آستانهٔ شورش (۰٫۳۰)", snap["happiness"] > 0.30))
        checks.append((f"سال {y}: ثبات بالای ۰٫۳۵", snap["stability"] > 0.35))
    ok = True
    for name, passed in checks:
        if passed:
            print("✅ " + name)
        else:
            print("❌ " + name)
            FAIL.append(name)
            ok = False
    return ok

def check_determinism():
    s1, _ = run(verbose=False)
    s2, _ = run(verbose=False)
    same = all((not isinstance(v, float)) or v == s2[k] for k, v in s1.items())
    if same:
        print("✅ دترمینیسم: دو اجرا کاملاً یکسان")
    else:
        FAIL.append("دترمینیسم: دو اجرای آینه متفاوت!")
        print("❌ دترمینیسم")
    return same

def run_shock_suite():
    """سناریوی شوک ترکیبی (سال دوم) — اثبات پاسخ‌گویی و بازگشت به تعادل بعد از شوک."""
    print("═══ سناریوی شوک: جنگ تمام‌عیار + ۲ تحریم + قطع برق + بسیج کامل (از روز ۳۶۵ به مدت ۱ سال) ═══")
    s = initial_state()
    peak_infl = 0.0
    war_h = None
    peace_h = None
    for day in range(1, 365 * 4 + 1):   # ۴ سال: ۱ عادی + ۱ شوک + ۲ بازسازی
        in_shock = 365 < day <= 730
        if in_shock:
            _apply_shock(s)
        else:
            _restore_shock(s)
        step_day(s)
        if in_shock:
            peak_infl = max(peak_infl, s["inflation"])
            war_h = s["happiness"]
        if day == 730:
            war_h = s["happiness"]; war_infl = s["inflation"]; war_debt = s["national_debt"] / s["gdp"]
            war_dem = s["res_dem"]["برق"]
        if day == 365 * 4:
            peace_h = s["happiness"]; peace_infl = s["inflation"]; peace_dem = s["res_dem"]["برق"]
    print("پایان جنگ: تورم %.0f%% | شادی %.2f | بدهی/GDP %.0f%%" % (war_infl * 100, war_h, war_debt * 100))
    print("اوج تورم جنگی: %.0f%% | دو سال بعد: تورم %.1f%% | شادی %.2f" % (peak_infl * 100, peace_infl * 100, peace_h))
    checks = [
        ("شوک: تورم به سقف ابرتورم (۶۰٪) نمی‌رسد", peak_infl < 0.60),
        ("شوک: تورم جنگی بالای ۱۵٪ (هزینه واقعی جنگ)", war_infl > 0.15),
        ("شوک: شادی در جنگ افت معنادار می‌کند (<۰٫۵۵ در برابر ۰٫۶۶ صلح)", war_h < 0.55),
        ("شوک: تقاضای برق جنگی جهش می‌کند (≥۱۳٫۵ از ۱۲)", war_dem >= 13.5),
        ("شوک: بازگشت تقاضا پس از جنگ (<۱۴٫۵ دو سال بعد)", peace_dem < 14.5),
        ("شوک: بدون بحران انرژی ابدی (۲ سال پس از جنگ پاک)", not s["res_energy_crisis"]),
        ("بازسازی: ۲ سال پس از جنگ تورم زیر ۱۲٪ برمی‌گردد", peace_infl < 0.12),
        ("بازسازی: شادی بازیابی می‌شود (>۰٫۵۵)", peace_h > 0.55),
    ]
    ok = True
    for name, passed in checks:
        print(("✅ " if passed else "❌ ") + name)
        if not passed:
            FAIL.append(name); ok = False
    return ok

def run_policy_suites(base_final):
    """سناریوهای «دولت فعال» — اثبات پاسخ‌گویی مدل به سیاست مالی/اجتماعی در برابر خط پایه."""
    print("═══ سناریوی ۱: انبساطی (مالیات ۲۸٪ + ذخیره ۵٪ + سلامت/آموزش سنگین) ═══")
    def expansion(day, s):
        if day == 120:  # از ماه چهارم
            s["tax_rate"] = 0.28
            s["alloc"].update({"ذخیره": 0.05, "بهداشت": 0.14, "آموزش": 0.12, "رفاه": 0.18})
    xe, _ = run(verbose=False, policy_hook=expansion)
    exp_rev = xe["tax_rate"] * (xe["gdp"] / 12.0)
    print("پایان: رشد %+.1f%% | تورم %.1f%% | بدهی/GDP %.0f%% | سلامت %.2f | آموزش %.2f | شادی %.2f" % (
        xe["growth_rate"] * 100, xe["inflation"] * 100,
        xe["national_debt"] / xe["gdp"] * 100, xe["health_q"], xe["edu_q"], xe["happiness"]))
    checks1 = [
        ("انبساطی: بدون فروپاشی مالی (بدهی/GDP < ۱۰۰٪)", xe["national_debt"] / xe["gdp"] < 1.0),
        ("انبساطی: تورم مهارشده (<۱۵٪)", xe["inflation"] < 0.15),
        ("انبساطی: سلامت بهتر از خط پایه (سیاست اثر دارد)", xe["health_q"] > base_final["health_q"] + 0.03),
        ("انبساطی: آموزش بهتر از خط پایه", xe["edu_q"] > base_final["edu_q"] + 0.02),
        ("انبساطی: رشد منفی نیست", xe["growth_rate"] > 0.0),
    ]
    print("═══ سناریوی ۲: انقباضی (مالیات ۱۵٪ + ذخیره ۴۰٪ — ریاضت) ═══")
    def austerity(day, s):
        if day == 120:
            s["tax_rate"] = 0.15
            s["alloc"]["ذخیره"] = 0.40
            s["alloc"]["رفاه"] = 0.10
    xa, _ = run(verbose=False, policy_hook=austerity)
    print("پایان: رشد %+.1f%% | تورم %.1f%% | بدهی/GDP %.0f%% | سلامت %.2f | شادی %.2f | ثبات %.2f" % (
        xa["growth_rate"] * 100, xa["inflation"] * 100,
        xa["national_debt"] / xa["gdp"] * 100, xa["health_q"], xa["happiness"], xa["stability"]))
    checks2 = [
        ("انقباضی: بدهی/GDP نهایی کمتر از خط پایه (ریاضت کار می‌کند)",
         xa["national_debt"] / xa["gdp"] < base_final["national_debt"] / base_final["gdp"] - 0.03),
        ("انقباضی: بدون سقوط آزاد (رشد > −۲٪)", xa["growth_rate"] > -0.02),
        ("انقباضی: بدون بحران شادی (شادی > ۰٫۴)", xa["happiness"] > 0.40),
        ("انقباضی: بدون فروپاشی ثبات (≥۰٫۳۵)", xa["stability"] >= 0.35),
    ]
    ok = True
    for name, passed in checks1 + checks2:
        print(("✅ " if passed else "❌ ") + name)
        if not passed:
            FAIL.append(name); ok = False
    return ok

def run_sanctions_suite():
    """سناریوی تحریم طولانی/شدید (۳ تحریم دائمی از ماه ۱۴) — تاب‌آوری بدون مرگ اقتصادی."""
    base, _ = run(verbose=False)
    def emb(day, s):
        if day == 400:
            s["shock_sanctions"] = 3
    x, _ = run(verbose=False, policy_hook=emb)
    print("═══ سناریوی تحریم طولانی: ۳ تحریم دائمی از سال ۲ ═══")
    print("پایان سال ۱۰: رشد %+.1f%% | تورم %.1f%% | بیکاری %.1f%% | GDP %.0fB (خط پایه %.0fB) | ثبات %.2f | شادی %.2f" % (
        x["growth_rate"] * 100, x["inflation"] * 100, x["unemployment"] * 100,
        x["gdp"] / 1e9, base["gdp"] / 1e9, x["stability"], x["happiness"]))
    checks = [
        ("تحریم: اقتصاد زنده می‌ماند (GDP ≥ ۸۵٪ خط پایه)", x["gdp"] >= base["gdp"] * 0.85),
        ("تحریم: تورم مزمنه ولی مهارشده (<۱۸٪)", x["inflation"] < 0.18),
        ("تحریم: تورم از خط پایه بالاتر است (هزینه واقعی)", x["inflation"] > base["inflation"] + 0.01),
        ("تحریم: بیکاری بحرانی نمی‌شود (≤۱۶٪)", x["unemployment"] <= 0.16),
        ("تحریم: بدون فروپاشی (ثبات ≥ ۰٫۳۵، شادی ≥ ۰٫۴۰)", x["stability"] >= 0.35 and x["happiness"] >= 0.40),
        ("تحریم: بحران انرژی خودبه‌خودی شلیک نمی‌کند", not x["res_energy_crisis"]),
    ]
    ok = True
    for name, passed in checks:
        print(("✅ " if passed else "❌ ") + name)
        if not passed:
            FAIL.append(name); ok = False
    return ok

def run_blockade_suite():
    """سناریوی چهارم: جنگ اقتصادی — محاصرهٔ واردات (سال ۲ تا ۴) + ۲ تحریم دائمی
    + کاهش ارزش اضطراری ۱۸٪ (اهرم واقعی forex روی تراز). اثبات اثر و بازیابی."""
    base, base_hist = run(verbose=False)
    snap = {}
    def war_econ(day, s):
        if day == 365:
            s["shock_blockaded"] = True
            s["shock_sanctions"] = 2
        elif day == 400:
            # کاهش ارزش ۱۸٪: ضربهٔ یک‌بارهٔ واقعی به تجارت و تورم (مثل forex_manager.devalue)
            s["exchange_rate"] = min(s["exchange_rate"] * 1.18, 5.0)
            s["exports"] *= 1.0 + 0.18 * 0.6
            s["imports"] *= 1.0 + 0.18 * 0.4
            s["inflation"] = clamp(s["inflation"] + 0.18 * 0.3, 0.0, 1.5)
        elif day == 365 * 4:
            s.pop("shock_blockaded", None)   # پایان محاصره در آستانهٔ سال پنجم
        if day == 730:
            snap.update(dict(s))   # میانهٔ محاصره
    x, _ = run(verbose=False, policy_hook=war_econ)
    b_y2 = base_hist[1][1]   # خط پایه پایان سال ۲
    print("═══ سناریوی محاصرهٔ اقتصادی: بلوکاد سال ۲ تا ۴ + ۲ تحریم دائمی + کاهش ارزش ۱۸٪ ═══")
    print("میانهٔ محاصره: صادرات %.0fB واردات %.0fB تراز %+.1fB | پایان: صادرات %.0fB تراز %+.1fB ذخیره %.0fB ارز %.2f" % (
        snap["exports"] / 1e9, snap["imports"] / 1e9, snap["trade_balance"] / 1e9,
        x["exports"] / 1e9, x["trade_balance"] / 1e9, x["foreign_reserves"] / 1e9, x["exchange_rate"]))
    checks = [
        ("محاصره: واردات در بلوکاد افت می‌کند (≥۸٪ زیر خط پایه)", snap["imports"] < b_y2["imports"] * 0.92),
        ("محاصره: صادرات زیر ۲ تحریم افت می‌کند (<۹۷٪ خط پایه)", snap["exports"] < b_y2["exports"] * 0.97),
        ("جنگ اقتصادی: اثر ماندگار — ذخایر پایانی زیر خط پایه", x["foreign_reserves"] < base["foreign_reserves"] - 5e9),
        ("بازیابی: واردات پس از محاصره برمی‌گردد (>+۸٪ نسبت به میانهٔ بلوکاد)", x["imports"] > snap["imports"] * 1.08),
        ("کاهش ارزش: نرخ ارز بلندمدت ضعیف‌تر از خط پایه می‌ماند", x["exchange_rate"] > base["exchange_rate"] * 1.02),
        ("جنگ اقتصادی: بدون فروپاشی (GDP ≥ ۸۰٪ خط پایه، ثبات ≥ ۰٫۳۵)",
         x["gdp"] >= base["gdp"] * 0.80 and x["stability"] >= 0.35),
        ("جنگ اقتصادی: ذخایر منفی نمی‌شود و ارز داخل clamp", x["foreign_reserves"] >= 0.0 and 0.2 <= x["exchange_rate"] <= 5.0),
    ]
    ok = True
    for name, passed in checks:
        print(("✅ " if passed else "❌ ") + name)
        if not passed:
            FAIL.append(name); ok = False
    return ok

def run_reserve_crisis_suite():
    """سناریوی پنجم: بحران تراز پرداخت‌ها — ۲ تحریم دائمی + مداخلهٔ ارزی ماهانهٔ سنگین
    (حمایت از نرخ ارز با سوزاندن ذخایر) تا پوشش واردات از ۳ ماه پایین بیاید؛
    اثبات فعال‌شدن بازخورد خودکار فشردگی واردات و بازسازی ذخایر پس از توقف مداخله."""
    base, _ = run(verbose=False)
    snap0, snap1 = {}, {}
    def drain(day, s):
        if day == 200:
            snap0.update(dict(s))
            s["shock_sanctions"] = 2
        # مداخلهٔ ماهانهٔ ۲ میلیارد دلاری به مدت ۳ سال (مانند forex_manager.intervene)
        if 240 <= day < 240 + 365 * 3 and day % 30 == 0 and s["foreign_reserves"] > 2.0e9:
            s["foreign_reserves"] = s["foreign_reserves"] - 2.0e9
            s["exchange_rate"] = max(s["exchange_rate"] * 0.99, 0.2)   # تقویت موقت
        if day == 240 + 365 * 3:
            snap1.update(dict(s))
    x, _ = run(verbose=False, policy_hook=drain)
    print("═══ سناریوی بحران ذخایر: ۲ تحریم دائمی + مداخلهٔ ۲B$/ماه به مدت ۳ سال ═══")
    print("پایان مداخله: ذخیره %.1fB (شروع %.0fB) پوشش %.1f ماه واردات | پایان: ذخیره %.0fB ارز %.2f" % (
        snap1["foreign_reserves"] / 1e9, snap0["foreign_reserves"] / 1e9,
        snap1["foreign_reserves"] / max(snap1["imports"] / 12.0, 1.0),
        x["foreign_reserves"] / 1e9, x["exchange_rate"]))
    checks = [
        ("بحران ذخایر: مداخلهٔ مداوم ذخایر را واقعاً تخلیه می‌کند (زیر ۱۵ میلیارد)",
         snap1["foreign_reserves"] < 15e9),
        ("بحران ذخایر: پوشش واردات از ۳ ماه پایین می‌آید (بازخورد فعال می‌شود)",
         snap1["foreign_reserves"] / max(snap1["imports"] / 12.0, 1.0) < 3.0),
        ("بحران ذخایر: واردات در بحران فشرده می‌شود (< واردات پیش از شوک)",
         snap1["imports"] < snap0["imports"]),
        ("بازسازی: پس از توقف مداخله ذخایر برمی‌گردند (≥ +۱۰ میلیارد)",
         x["foreign_reserves"] >= snap1["foreign_reserves"] + 10e9),
        ("بحران ذخایر: ذخایر هرگز منفی نمی‌شود (کف clamp)",
         snap1["foreign_reserves"] >= 0.0 and x["foreign_reserves"] >= 0.0),
        ("بحران ذخایر: حمایت مصنوعی موقت است — پس از توقف مداخله ارز تضعیف می‌شود (≥+۲٪)",
         x["exchange_rate"] >= snap1["exchange_rate"] * 1.02),
        ("بحران ذخایر: بدون فروپاشی (GDP ≥ ۸۵٪ خط پایه)",
         x["gdp"] >= base["gdp"] * 0.85),
    ]
    ok = True
    for name, passed in checks:
        print(("✅ " if passed else "❌ ") + name)
        if not passed:
            FAIL.append(name); ok = False
    return ok

def _apply_shock(s):
    """فعال‌سازی رژیم جنگ تمام‌عیار روی آینه (ایدمپوتنت)."""
    s["shock_mobil"] = 4.0
    s["shock_war_economy"] = 0.8
    s["shock_war_exhaustion"] = 0.3
    s["shock_sanctions"] = 2
    s["shock_energy_crisis"] = True

def _restore_shock(s, _saved=None):
    """بازگشت به صلح کامل (پایان جنگ)."""
    for k in ("shock_mobil", "shock_war_economy", "shock_war_exhaustion",
              "shock_sanctions", "shock_energy_crisis"):
        s.pop(k, None)

if __name__ == "__main__":
    print("═══ شبیه‌سازی بلندمدت — ۱۰ سال از نقطهٔ شروع پیش‌فرض (بدون اقدام بازیکن) ═══")
    s, hist = run()
    print()
    ok = check_bounds(s, hist) and check_determinism()
    print()
    ok = run_policy_suites(s) and ok
    print()
    ok = run_sanctions_suite() and ok
    print()
    ok = run_blockade_suite() and ok
    print()
    ok = run_reserve_crisis_suite() and ok
    print()
    ok = run_shock_suite() and ok
    print()
    if FAIL:
        print("═══ شکست — %d نقض پایداری ═══" % len(FAIL))
        for f in FAIL:
            print("  • " + f)
        sys.exit(1)
    print("═══ موفق — تعادل بلندمدت هستهٔ شبیه‌سازی پایدار است ═══")
