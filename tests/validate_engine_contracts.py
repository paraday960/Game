#!/usr/bin/env python3
"""اعتبارسنج قراردادهای موتور — جلوی بازگشت باگ‌های رایج «عمق»های جدید را می‌گیرد.

چک‌ها:
1. هر `simulate_month` باید خروجی `{state, events}` بدهد (نه state خام).
2. هیچ کد شبیه‌سازی نباید از RNG غیردترمینستیک (randi/randf و...) استفاده کند.
3. کلیدهای state نباید توسط چند منیجر با طرح متفاوت ساخته شوند (تداخل مثل waste_policy).
4. هیچ بلوک تکراری «لایه عمیق دوم» نباید وجود داشته باشد (اجرای دوباره معادلات).
"""
import glob, re, sys

FAIL = []

# ── ۱) قرارداد simulate_month ──
def check_simulate_month_contract():
    bad = []
    for f in glob.glob("scripts/**/*.gd", recursive=True):
        src = open(f, encoding="utf-8").read()
        for m in re.finditer(r"func simulate_month\([^)]*\)[^:]*:", src):
            start = m.end()
            end = src.find("\nfunc ", start)
            if end == -1:
                end = len(src)
            body = src[start:end]
            for r in re.findall(r"^\s*return\s+(.+)$", body, re.M):
                r = r.strip()
                if r.startswith("simulate(") or (not r.startswith("{") and "state" in r and "events" not in r):
                    bad.append((f, r))
    if bad:
        for f, r in bad:
            FAIL.append(f"{f}: simulate_month خروجی ناقص دارد → {r}")
    else:
        print("✅ قرارداد simulate_month: همه {state, events} برمی‌گردانند")

# ── ۲) دترمینیسم: RNG خام در کد شبیه‌سازی ──
ALLOWED_RNG = ("scripts/core/deterministic.gd", "scripts/multiplayer/p2p_manager.gd", "scripts/ui/", "scripts/core/ambient_music.gd", "tests/", "tools/")
def check_determinism():
    bad = []
    for f in glob.glob("scripts/**/*.gd", recursive=True):
        if any(f.startswith(a) for a in ALLOWED_RNG):
            continue
        src = open(f, encoding="utf-8").read()
        for pat in ("randi()", "randf()", "randf_range", "randi_range", "randomize()"):
            for i, l in enumerate(src.split("\n"), 1):
                if pat in l and not l.strip().startswith("#"):
                    bad.append((f, i, pat))
    if bad:
        for f, i, p in bad[:10]:
            FAIL.append(f"{f}:{i} RNG غیردترمینستیک → {p}")
    else:
        print("✅ دترمینیسم: هیچ RNG خامی در شبیه‌سازی نیست")

# ── ۳) تداخل کلیدهای state بین منیجرها ──
def check_state_key_collisions():
    owners = {}
    for f in glob.glob("scripts/core/*.gd") + glob.glob("scripts/systems/*.gd"):
        src = open(f, encoding="utf-8").read()
        for m in re.finditer(r'state\["([a-z_]+)"\]\s*=\s*\{', src):
            owners.setdefault(m.group(1), set()).add(f.split("/")[-1])
    conflicts = {k: sorted(v) for k, v in owners.items() if len(v) > 1}
    if conflicts:
        for k, files in conflicts.items():
            FAIL.append(f"تداخل کلید state «{k}»: {files}")
    else:
        print("✅ مالکیت کلیدهای state: بدون تداخل")

# ── ۴) بلوک‌های تکراری «لایه عمیق دوم» ──
def check_duplicate_deep_blocks():
    bad = []
    for f in glob.glob("scripts/systems/*.gd") + glob.glob("scripts/ai/*.gd"):
        src = open(f, encoding="utf-8").read()
        n = len(re.findall(r"^[ \t]*# --- لایه عمیق دوم", src, re.M))
        if n > 1:
            bad.append((f, n))
    if bad:
        for f, n in bad:
            FAIL.append(f"{f}: {n} بلوک «لایه عمیق دوم» — اجرای تکراری معادلات")
    else:
        print("✅ بلوک‌های عمیق: بدون تکرار")

check_simulate_month_contract()
check_determinism()
check_state_key_collisions()
check_duplicate_deep_blocks()

if FAIL:
    print("\n❌ ENGINE CONTRACTS FAILED:")
    for x in FAIL:
        print("  -", x)
    sys.exit(1)
print("\n=== ✅ ENGINE CONTRACTS OK ===")
