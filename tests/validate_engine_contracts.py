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

# ── ۵) هر نوع فرمان عمقی باید کیس صریح در _command_queue_key داشته باشد ──
def check_queue_key_coverage():
    cmd_src = open("scripts/core/command.gd", encoding="utf-8").read()
    ui_src = open("scripts/ui/main_ui.gd", encoding="utf-8").read()
    types = re.findall(r'\.new\("([a-z_]+)"', cmd_src)
    missing = []
    mq = re.search(r"func _command_queue_key.*?(?=\nfunc )", ui_src, re.S)
    qk = mq.group(0) if mq else ""
    for t in sorted(set(types)):
        # کیس صریح = برچسب "t": و در ۱۲۰ نویسه بعد یک return (کیس چندخطی مجاز)
        m = re.search(rf'"{t}":', qk)
        if m is None or "return" not in qk[m.end():m.end() + 120]:
            missing.append(t)
    if missing:
        FAIL.append("این نوع فرمان‌ها در _command_queue_key کیس صریح ندارند (دکمه‌های یک‌بار در نوبت غیرفعال نمی‌شوند): " + ", ".join(missing))
    else:
        print("✅ پوشش کلید صف تصمیم: همه نوع فرمان‌ها کیس صریح دارند")

# ── ۵) قرارداد نویز متقارن — راه‌پیمای تصادفی سوگیریدار ممنوع ────────────
# بازرسی واقع‌گرایی ۱۴۰۵: health.vaccination با next_range(-0.001, 0.002) دریفت
# تصادفی ~+۰٫۰۰۰۵ در روز داشت و بی‌توجه به سیاست به سقف می‌چسبید. درمان: واکسیناسیون
# بازگشت‌به‌هدف سیاست‌محور شد و همهٔ «راه‌پیماهای خالص روی سطح پایدار» مرکز-صفر شدند.
NOISE_WALKS = {
    "scripts/systems/health_system.gd": ["vax_target", "next_range(-0.0005, 0.0005)"],
    "scripts/systems/agriculture_system.gd": ["next_range(-0.0015, 0.0015)"],
    "scripts/systems/citizens_system.gd": ["next_range(-0.025, 0.025)"],
    "scripts/systems/culture_system.gd": ["next_range(-0.0025, 0.0025)"],
    "scripts/systems/elections_system.gd": ["next_range(-0.0015, 0.0015)", "next_range(-0.0025, 0.0025)"],
    "scripts/systems/foreign_affairs_system.gd": ["next_range(-0.15, 0.15)"],
    "scripts/systems/security_system.gd": ["next_range(-0.0025, 0.0025)", "next_range(-0.0015, 0.0015)"],
    "scripts/systems/stock_market_system.gd": ["next_range(-0.0015, 0.0015)"],
    "scripts/systems/tourism_system.gd": ["next_range(-0.0025, 0.0025)"],
    "scripts/systems/trade_system.gd": ["next_range(-0.0025, 0.0025)"],
    "scripts/systems/welfare_system.gd": ["next_range(-0.0015, 0.0015)"],
    # سایت‌های سیاست‌محرک (جاروی دوم): نویز مرکز-صفر در کنار جملهٔ سیاستی
    "scripts/systems/central_bank_system.gd": ["next_range(-0.0025, 0.0025)"],
    "scripts/systems/households_system.gd": ["next_range(-0.00045, 0.00045)"],
    "scripts/systems/infrastructure_system.gd": ["next_range(-0.00065, 0.00065)"],
    "scripts/systems/international_orgs_system.gd": ["next_range(-0.00125, 0.00125)"],
    "scripts/systems/migration_system.gd": ["next_range(-2500.0, 2500.0)"],
    "scripts/systems/military_system.gd": ["next_range(-0.065, 0.065)", "next_range(-1.25, 1.25)"],
    "scripts/systems/resources_system.gd": ["next_range(-0.15, 0.15)"],
    "scripts/systems/private_sector_system.gd": ["next_range(-0.015, 0.015)"],
}
# الگوهای سوگیریداری که درمان شدند و نباید برگردند
BIASED_GONE = {
    "scripts/systems/health_system.gd": ["health[\"vaccination\"] + Deterministic.next_range(-0.001, 0.002)"],
}
def check_noise_symmetry():
    for f, pats in sorted(NOISE_WALKS.items()):
        src = open(f, encoding="utf-8").read()
        for pat in pats:
            if pat not in src:
                FAIL.append("الگوی نویز متقارن «%s» در %s یافت نشد" % (pat, f))
    for f, pats in sorted(BIASED_GONE.items()):
        src = open(f, encoding="utf-8").read()
        for pat in pats:
            if pat in src:
                FAIL.append("الگوی نویز سوگیریدار «%s» به %s برگشته" % (pat, f))
    if not FAIL:
        print("✅ قرارداد نویز متقارن: %d سایت راه‌پیمای مرکز-صفر پین شد" % len(NOISE_WALKS))


check_simulate_month_contract()
check_determinism()
check_state_key_collisions()
check_duplicate_deep_blocks()
check_queue_key_coverage()
check_noise_symmetry()

if FAIL:
    print("\n❌ ENGINE CONTRACTS FAILED:")
    for x in FAIL:
        print("  -", x)
    sys.exit(1)
print("\n=== ✅ ENGINE CONTRACTS OK ===")
