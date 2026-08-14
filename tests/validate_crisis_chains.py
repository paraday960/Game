#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""قرارداد نخ‌های بحران (Crisis Threads) — بازرسی ۱۴۰۵ دور سیزدهم.

رویدادهای واقعی زنجیره‌ای‌اند نه تک‌ضربه؛ این رجیستری data/crisis_chains.json
الگوهای چندمرحله‌ای (خشکسالی ← تورم خوراک ← فشار ارزی و...) را تعریف می‌کند.
قراردادها:
- هر زنجیره شناسه‌ی یکتا، حداقل ۲ مرحله، cooldown و سقف نمونه‌ی هم‌زمان دارد.
- هر مرحله name_fa و duration_days دارد؛ اثرهایش به کلیدهای واقعی state اشاره
  می‌کنند (بخش اول = کلید سطح بالای state؛ برگ = در init یا در جای کد نوشته می‌شود).
- هر تصمیم (entry_decision یا stage.decision) باید قالب فارسی در
  DecisionManager.TEMPLATES داشته باشد، وگرنه رویداد به تصمیم مرده می‌رسد.
- هیچ RNG خامی (randi/randf/random/shuffle) در رجیستری مجاز نیست — فقط
  Deterministic موتور که دترمینستیک است.
- موتور (event_crisis_manager) باید لودر، is_valid و چرخه‌ی stage_count داشته باشد.

خروج غیرصفر = نقض هر بند.
"""
import glob
import io
import json
import re
import sys

fail = []

# ── رجیستری ─────────────────────────────────────────────────────────────
with io.open("data/crisis_chains.json", encoding="utf-8") as fh:
    data = json.load(fh)
chains = data.get("chains", [])
print("✅ رجیستری crisis_chains: %d زنجیره" % len(chains))
if len(chains) < 4:
    fail.append("حداقل ۴ زنجیره‌ی بحران باید در رجیستری باشد")

# یکتایی شناسه‌ها
ids = [str(c.get("id", "")) for c in chains]
dupes = sorted({i for i in ids if ids.count(i) > 1})
if dupes:
    fail.append("شناسه‌ی تکراری زنجیره: %s" % ", ".join(dupes))
else:
    print("✅ شناسه‌ی همه‌ی زنجیره‌ها یکتاست")

# ── کلیدهای TEMPLATES تصمیم (برای بررسی پوشش) ──────────────────────────
dm_src = io.open("scripts/core/decision_manager.gd", encoding="utf-8").read()
start = dm_src.index("const TEMPLATES = {")
end = dm_src.index("const ALIASES")
templates = set(re.findall(r'^\s*"([A-Za-z0-9_]+)":\s*\{', dm_src[start:end], re.M))
print("✅ قالب‌های تصمیم: %d" % len(templates))

# ── کلیدهای واقعی state (برای اعتبار مسیر اثر) ──────────────────────────
state_src = io.open("scripts/core/state.gd", encoding="utf-8").read()
init_sections = set(re.findall(r'"(\w+)":\s*\{', state_src))
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

VALID_COM = {"نفت", "گاز", "گندم", "فلزات"}

# ── بررسی هر زنجیره ─────────────────────────────────────────────────────
RAW_RNG = re.compile(r'\brand[fi]\b|\.random|pick_random|shuffle_array|randomize')

def check_effect(eff, where):
    if not isinstance(eff, dict):
        fail.append("%s: اثر باید دیکشنری باشد: %s" % (where, eff))
        return
    path = str(eff.get("path", ""))
    parts = path.split(".")
    if len(parts) < 2:
        fail.append("%s: مسیر اثر کوتاه است: %s" % (where, path))
        return
    sec, leaf = parts[0], parts[-1]
    if sec not in init_sections and sec not in written:
        fail.append("%s: بخش ناشناخته در مسیر اثر: %s" % (where, path))
    # برگ باید در init یا نوشته‌شده‌ها باشد؛ استثنا: کالاهای جهانی
    if sec == "commodities" and parts[1] == "prices":
        if leaf not in VALID_COM:
            fail.append("%s: کالای ناشناخته در مسیر اثر: %s" % (where, path))
        return
    known = written.get(sec, set())
    if leaf not in known and leaf not in init_sections:
        # مسیرهای عمیق مثل policy_costs.X یا age_structure.X را ساده چک کن
        parent = parts[-2] if len(parts) >= 3 else sec
        if parent not in written.get(sec, set()) and parent not in init_sections:
            fail.append("%s: برگ ناشناخته در مسیر اثر: %s" % (where, path))

for chain in chains:
    cid = str(chain.get("id", ""))
    where = "زنجیره‌ی «%s»" % cid
    if not chain.get("title_fa"):
        fail.append("%s: title_fa الزامی است" % where)
    if not (1 <= int(chain.get("severity", 0)) <= 3):
        fail.append("%s: severity باید ۱ تا ۳ باشد" % where)
    if int(chain.get("cooldown_days", 0)) < 60:
        fail.append("%s: cooldown_days باید ≥ ۶۰ باشد" % where)
    if int(chain.get("max_instances", 0)) < 1:
        fail.append("%s: max_instances باید ≥ ۱ باشد" % where)
    if not (0.0 < float(chain.get("chance", 0.0)) <= 1.0):
        fail.append("%s: chance باید بین ۰ و ۱ باشد" % where)
    entry = str(chain.get("entry_decision", ""))
    if entry not in templates:
        fail.append("%s: entry_decision «%s» در TEMPLATES نیست" % (where, entry))
    stages = chain.get("stages", [])
    if len(stages) < 2:
        fail.append("%s: حداقل ۲ مرحله لازم است" % where)
    # اسکار (اثر ماندگار پس از نخ) — عمق‌بخشی ۵
    scar = chain.get("scar", {})
    if scar:
        if not scar.get("title_fa"):
            fail.append("%s: scar.title_fa الزامی است" % where)
        if int(scar.get("duration_months", 0)) < 6:
            fail.append("%s: scar.duration_months باید ≥ ۶ باشد" % where)
        if not scar.get("effects"):
            fail.append("%s: scar باید دست‌کم یک اثر داشته باشد" % where)
        for eff in scar.get("effects", []):
            check_effect(eff, "%s / اسکار" % where)
    if chain.get("world_scope") is True:
        has_commodity = any(
            str(e.get("path", "")).startswith("commodities.prices.")
            for st in stages for key in ("on_enter_effects", "persist_effects", "resolve_effects")
            for e in st.get(key, []))
        if not has_commodity:
            fail.append("%s: زنجیره‌ی جهانی باید اثر روی commodities.prices داشته باشد" % where)
    for si, stage in enumerate(stages):
        sw = "%s / مرحلهٔ %d" % (where, si + 1)
        if not stage.get("name_fa"):
            fail.append("%s: name_fa الزامی است" % sw)
        if int(stage.get("duration_days", 0)) < 15:
            fail.append("%s: duration_days باید ≥ ۱۵ باشد" % sw)
        if stage.get("decision") and str(stage["decision"]) not in templates:
            fail.append("%s: تصمیم «%s» در TEMPLATES نیست" % (sw, stage["decision"]))
        for key in ("on_enter_effects", "persist_effects", "resolve_effects"):
            for eff in stage.get(key, []):
                check_effect(eff, sw)
                # تعادل: ضرب باید min/max داشته باشد تا از کنترل خارج نشود (دور سیزدهم)
                if eff.get("op") == "mul" and ("min" not in eff or "max" not in eff):
                    fail.append("%s: mul بدون min/max (خطر خروج از محدوده): %s" % (sw, eff.get("path")))

# ── دترمینیسم رجیستری ───────────────────────────────────────────────────
raw = io.open("data/crisis_chains.json", encoding="utf-8").read()
rng_hits = RAW_RNG.findall(raw)
if rng_hits:
    fail.append("RNG خام در رجیستری: %s" % ", ".join(sorted(set(rng_hits))))
else:
    print("✅ هیچ RNG خامی در رجیستری نیست (دترمینیسم حفظ شده)")

# ── سیم‌کشی موتور ───────────────────────────────────────────────────────
ecm = io.open("scripts/core/event_crisis_manager.gd", encoding="utf-8").read()
for needle, label in [
    ('CHAINS_PATH', "ثابت مسیر رجیستری"),
    ('func reload()', "لودر زنجیره‌ها"),
    ('"stage_count"', "چرخه‌ی مرحله‌ای (stage_count)"),
    ('"entry_decision"', "اعتبارسنجی entry_decision"),
]:
    if needle not in ecm:
        fail.append("event_crisis_manager: %s (%s) از دست رفته" % (needle, label))
    else:
        print("✅ event_crisis_manager: %s" % label)
eng = io.open("scripts/core/engine.gd", encoding="utf-8").read()
if "EventCrisisManager.simulate_month" in eng:
    print("✅ engine هر ماه EventCrisisManager.simulate_month را صدا می‌زند")
else:
    fail.append("engine: اتصال EventCrisisManager.simulate_month از دست رفته")

# ── جمع‌بندی ────────────────────────────────────────────────────────────
if fail:
    print("\n❌ CRISIS CHAINS FAILED:")
    for x in fail:
        print("  -", x)
    sys.exit(1)
print("\n=== ✅ CRISIS CHAINS OK ===")
