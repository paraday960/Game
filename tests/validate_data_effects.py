# -*- coding: utf-8 -*-
"""پین پویش «افکت‌های داده روی کلیدهای مرده» — دور سیزدهم.

قانون «حریم خصوصی دیجیتال» (digital_privacy) روی دو کلید اثر می‌گذاشت که
هیچ مصرف‌کننده‌ای نداشتند: intelligence.oversight و intelligence.surveillance
(بخش intelligence در بازی فقط drone_surveillance/sigint/humint/... دارد).
قانون ادعای اثر می‌کرد ولی عملاً فقط trust را کمی بالا می‌برد.

درمان: اثرها به کلیدهای زنده و هم‌معنا نگاشت شدند:
- judicial.rule_of_law  (نظارت قانونی بر نهادها)
- politics.trust        (اعتماد عمومی)
- politics.tension      (کاهش تنش دولت-مردم در برابر نظارت فراگیر)

این تست پین می‌کند:
1) هیچ مسیر اثری در data/*.json به کلیدی نرسد که در هیچ اسکریپتی
   (و نه initial_state) به‌صورت literal وجود نداشته باشد.
   استثناهای صریح: کلیدهای شرطی پویا که scenario_manager محاسبه می‌کند.
2) قانون digital_privacy هرگز به کلیدهای مرده‌ی سابق برنگردد.
"""
import io
import json
import re
import sys
import glob

FAIL = []


def read(p):
    return io.open(p, encoding="utf-8").read()


def check(name, cond, msg):
    if not cond:
        FAIL.append(msg)
        print("❌ %s: %s" % (name, msg))
    else:
        print("✅ %s" % name)


# ── 1) کلیدهای پویا که by-design محاسبه می‌شوند ─────────────────────────
# scenario_manager این مسیرها را به‌جای خواندن مستقیم state، محاسبه می‌کند
DYNAMIC_KEYS = {"world.alliances_count", "world.active_wars_count"}


def build_universe():
    keys = set()
    for f in glob.glob("scripts/**/*.gd", recursive=True):
        src = read(f)
        for m in re.finditer(r'["\']([^"\']{2,40})["\']', src):
            k = m.group(1)
            # کلیدهای state: الفبایی/انگلیسی یا فارسی (با فاصله بین واژه‌های فارسی)
            if re.fullmatch(r"[\w\u0600-\u06FF]+(?: [\w\u0600-\u06FF]+)*", k):
                keys.add(k)
    # initial_state
    init = json.load(io.open("data/initial_state.json", encoding="utf-8"))

    def collect(node):
        if isinstance(node, dict):
            for k, v in node.items():
                keys.add(str(k))
                collect(v)
        elif isinstance(node, list):
            for v in node:
                collect(v)
    collect(init)
    return keys


universe = build_universe()


def walk_effects(node, out):
    if isinstance(node, dict):
        if isinstance(node.get("path"), str):
            out.append(node["path"])
        for v in node.values():
            walk_effects(v, out)
    elif isinstance(node, list):
        for v in node:
            walk_effects(v, out)


dead = []
for f in sorted(glob.glob("data/*.json")):
    try:
        d = json.load(io.open(f, encoding="utf-8"))
    except Exception as ex:
        check("JSON معتبر %s" % f, False, str(ex))
        continue
    paths = []
    walk_effects(d, paths)
    for p in paths:
        if p in DYNAMIC_KEYS:
            continue
        leaf = p.split(".")[-1]
        if leaf not in universe:
            dead.append((f, p))

check(
    "بدون افکت داده روی کلید مرده",
    not dead,
    "مسیرهای مرده: %s" % (dead or "—"),
)

# ── 2) پین قانون حریم خصوصی ────────────────────────────────────────────
laws = json.load(io.open("data/laws.json", encoding="utf-8"))
law_list = laws if isinstance(laws, list) else laws.get("laws", [])
dp = next((l for l in law_list if l.get("id") == "digital_privacy"), None)
check("قانون حریم خصوصی موجود است", dp is not None, "digital_privacy حذف شده")

if dp is not None:
    eff_paths = [e.get("path") for e in dp.get("effects", [])]
    check(
        "بدون بازگشت کلید مرده",
        not any(p in ("intelligence.oversight", "intelligence.surveillance") for p in eff_paths),
        "کلید مرده بازگشته: %s" % eff_paths,
    )
    expected = {"judicial.rule_of_law", "politics.trust", "politics.tension"}
    check(
        "اثرهای زنده‌ی معادل",
        expected.issubset(set(eff_paths)),
        "اثرهای موردانتظار ناقص‌اند: %s" % eff_paths,
    )

print()
if FAIL:
    print("==> %d شکست" % len(FAIL))
    sys.exit(1)
print("==> همه‌ی پین‌های افکت داده سبزند (%d کلید در universe)" % len(universe))
