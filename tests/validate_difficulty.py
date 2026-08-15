# -*- coding: utf-8 -*-
"""پین «ضریب سختی سناریو» — بازرسی ۱۴۰۵ (عمق‌بخشی ۳۳).

difficulty_fa فقط برچسب نمایشی بود؛ سختی واقعی وجود نداشت. مکانیزم ضریب سختی
اضافه شد: هر سناریو difficulty_multiplier دارد و هزینه‌ی بدهیِ تصمیم‌ها
(resolve_decision → gdp_ratio روی national_debt) در سناریوهای سخت‌تر سنگین‌تر
می‌شود. درآمد ارزی (foreign_reserves) ضرب نمی‌شود.
"""
import io
import json
import sys

FAIL = []


def check(name, cond, msg):
    if not cond:
        FAIL.append(msg)
        print("❌ %s: %s" % (name, msg))
    else:
        print("✅ %s" % name)


# 1) همه‌ی سناریوها difficulty_multiplier دارند
sc = json.load(io.open("data/scenarios.json", encoding="utf-8"))
scenarios = sc.get("scenarios", [])
missing = [s.get("id") for s in scenarios if "difficulty_multiplier" not in s]
check("همه‌ی سناریوها ضریب سختی دارند", not missing, "بدون ضریب: %s" % (missing or "—"))

# 2) مقادیر در بازه‌ی معقول (۱.۰ تا ۱.۵) و با درجه‌ی دشواری هم‌خوان
bad = []
for s in scenarios:
    m = s.get("difficulty_multiplier", 1.0)
    if not (1.0 <= float(m) <= 1.5):
        bad.append((s.get("id"), m))
check("ضریب‌ها در بازه‌ی معقول", not bad, "خارج از بازه: %s" % (bad or "—"))

diff_map = {"معمولی": 1.0, "سخت": 1.15, "بحرانی": 1.30, "بسیار سخت": 1.45}
misaligned = []
for s in scenarios:
    expected = diff_map.get(s.get("difficulty_fa", ""))
    if expected is not None and abs(float(s.get("difficulty_multiplier", 0)) - expected) > 0.001:
        misaligned.append((s.get("id"), s.get("difficulty_fa"), s.get("difficulty_multiplier")))
check("ضریب با درجه‌ی دشواری هم‌خوان است", not misaligned, "%s" % (misaligned or "—"))

# 3) resolve_decision از ضریب استفاده می‌کند
dm = io.open("scripts/core/decision_manager.gd", encoding="utf-8").read()
check(
    "resolve_decision ضریب را می‌خواند",
    "cost_multiplier" in dm and "difficulty_multiplier" in dm,
    "resolve_decision باید ضریب سختی را از state.scenario بخواند",
)
check(
    "فقط بدهی ضرب می‌شود",
    'str(effect.get("path", "")) == "economy.national_debt"' in dm,
    "ضریب باید فقط روی national_debt اعمال شود (نه درآمد ارزی)",
)

sm = io.open("scripts/core/scenario_manager.gd", encoding="utf-8").read()
check(
    "apply_scenario ضریب را ذخیره می‌کند",
    '"difficulty_multiplier": float(definition.get("difficulty_multiplier", 1.0))' in sm,
    "apply_scenario باید difficulty_multiplier را در state.scenario بنویسد",
)

print()
if FAIL:
    print("==> %d شکست" % len(FAIL))
    sys.exit(1)
print("==> پین ضریب سختی سبز است (%d سناریو)" % len(scenarios))
