#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
تست قراردادی کلیدهای وضعیت — چک رگرسیون dead-key.

قاعده‌ی قرارداد: هر کلیدی که سیستم/مدیر/موتور درون state می‌نویسد باید
دست‌کم یک «مصرف‌کننده» داشته باشد، یعنی دست‌کم یکی از این چهار:
  ۱) خواننده‌ی تحت‌اللفظی در فایلی غیر از فایل(های) نویسنده
     (سیستم/مدیر/موتور دیگر، UI یا AI) — مهم‌ترین حالت: زنجیره‌ی اثر بسته است؛
  ۲) خوانده‌شدن در همان فایل نویسنده (دفترداری داخلی مشروع مانند کول‌داون)؛
  ۳) قرار گرفتن در بخشی که مرورگر عمومی سامانه‌ها (_build_system_detail)
     به‌صورت پویا به بازیکن نمایش می‌دهد؛
  ۴) تطابق با الگوی فهرست سفید دفترداری داخلی (last_* ، prev_* ، ...).

علاوه بر این، کلیدهای IMPORTANT_KEYS (زنجیره‌های اثر حیاتیِ سیم‌کشی‌شده در
بازرسی‌های تعادلی) الزاماً باید خواننده‌ای بیرون از فایل نویسنده داشته باشند.

خروج غیرصفر = یافتن کلید یتیم (orphan) یا نقض قرارداد کلید مهم.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = os.path.join(ROOT, "scripts")

# ── الگوها ──────────────────────────────────────────────────────────────
# بستن نام محلی به بخش state:  var econ = state.get("economy", {})
BIND_GET_RE = re.compile(
    r'^\s*(?:var\s+)?(\w+)\s*(?::\s*Dictionary)?\s*=\s*'
    r'(?:GameState\.)?(?:state|st|snapshot)\s*\.\s*get\(\s*"([A-Za-z0-9_]+)"'
)
BIND_SUB_RE = re.compile(
    r'^\s*(?:var\s+)?(\w+)\s*(?::\s*Dictionary)?\s*=\s*'
    r'(?:GameState\.)?(?:state|st|snapshot)\s*\[\s*"([A-Za-z0-9_]+)"\s*\]\s*$'
)
# اتصال پسینی:  state["banking"] = bk_dict   (bk_dict از این لحظه بخش banking است)
RETRO_BIND_RE = re.compile(
    r'^\s*(?:GameState\.)?(?:state|st|snapshot)\s*\[\s*"([A-Za-z0-9_]+)"\s*\]\s*=\s*(\w+)\s*$'
)
# بستن تودرتو:  var cycle = econ.get("cycle", {})
NESTED_BIND_RE = re.compile(
    r'^\s*(?:var\s+)?(\w+)\s*(?::\s*Dictionary)?\s*=\s*(\w+)\s*\.\s*get\(\s*"([A-Za-z0-9_]+)"'
)
# نوشتن:  econ["gdp"] = ...  یا  econ["gdp"] += ...
WRITE_RE = re.compile(
    r'^\s*(\w+)\s*\[\s*"([A-Za-z0-9_]+)"\s*\]\s*([+\-*/]?=)(?![=])'
)
# نوشتن دوسطحی مستقیم:  state["economy"]["gdp"] = ...
DIRECT_WRITE_RE = re.compile(
    r'^\s*(?:GameState\.)?(?:state|st|snapshot)\s*\[\s*"([A-Za-z0-9_]+)"\s*\]'
    r'\s*\[\s*"([A-Za-z0-9_]+)"\s*\]\s*([+\-*/]?=)(?![=])'
)
# نوشتن نقطه‌ای:  econ.gdp = ...   (فقط اگر نام به بخشی بسته شده باشد)
DOT_WRITE_RE = re.compile(r'^\s*(\w+)\.([A-Za-z0-9_]+)\s*([+\-*/]?=)(?![=])')

# الگوهای مشروع دفترداری داخلی (خودکفا بودن آن‌ها نقص نیست)
WHITELIST_RE = re.compile(
    r'(?:^last_|^prev_|_history$|_hist$|_cooldown$|_latched?$|^shock_|_shock$|'
    r'^initial_|_initialized$|^seen_|^pending_|_queue$|^queued_|'
    # دفترچه‌ی صورت‌وضعیت سناریو/جهان برای یکپارچگی ذخیره و چندنفره:
    r'^completed_day$|^completed_tick$|^partial_annexed_by$)'
)

# کلیدهای حیاتیِ زنجیره‌ی اثر — باید بیرون از فایل نویسنده هم خواننده داشته باشند.
IMPORTANT_KEYS = {
    "economy": ["growth_rate", "real_growth", "inflation", "unemployment",
                "national_debt", "government_revenue", "government_spending",
                "private_investment", "informal_tax_loss_daily", "aid_inflow_daily",
                # بازرسی کلید یتیم ۱۴۰۵: کانال‌های ماهانهٔ ترانزیت/رویالتی (زنجیرهٔ بودجه)
                "remittance_tax_monthly", "fuel_smuggling_loss_monthly",
                "transit_revenue_monthly", "royalty_revenue_monthly",
                "policy_spending_monthly"],
    "trade": ["market_access_bonus"],
    "stock_policy": ["last_crash"],
    "resources": ["energy_crisis", "food_crisis"],
    "military": ["morale"],
    "technology": ["research_rate"],
    "politics": ["tension", "legitimacy"],
}


def collect_gd_files():
    files = []
    for base, _dirs, names in os.walk(SCRIPTS):
        for name in names:
            if name.endswith(".gd"):
                files.append(os.path.join(base, name))
    return sorted(files)


def rel(path):
    return os.path.relpath(path, ROOT).replace(os.sep, "/")


def extract_browsable_sections():
    """بخش‌هایی که مرورگر عمومی سامانه‌ها در UI به‌صورت پویا نمایش می‌دهد."""
    sections = set()
    engine_path = os.path.join(SCRIPTS, "core", "engine.gd")
    ui_path = os.path.join(SCRIPTS, "ui", "main_ui.gd")
    with open(engine_path, encoding="utf-8") as fh:
        engine_src = fh.read()
    sections.update(re.findall(r'systems\["([a-z_]+)"\]', engine_src))
    # ثبت پویا: حلقه‌هایی مانند for name in remaining: systems[name] = load(...)
    for arr_var, arr_body in re.findall(r'var (\w+)\s*=\s*\[([^\]]+)\]', engine_src):
        if re.search(r'for \w+ in ' + re.escape(arr_var) + r'[\s\S]{0,200}?systems\[\w+\]\s*=', engine_src):
            sections.update(re.findall(r'"([a-z_]+)"', arr_body))
    with open(ui_path, encoding="utf-8") as fh:
        ui_src = fh.read()
    alias_block = re.search(
        r'const SYSTEM_STATE_ALIASES\s*=\s*\{(.*?)\}', ui_src, re.S)
    if alias_block:
        for key, value in re.findall(
                r'"([a-z_]+)"\s*:\s*"([a-z_]+)"', alias_block.group(1)):
            sections.add(key)
            sections.add(value)
    return sections


def scan_file(path):
    """استخراج اتصال‌ها و نوشتن‌های یک فایل.

    خروجی: (writes, bindings)
      writes: فهرست (key, section|None)
      bindings: نگاشت نام‌محلی → مسیر بخش
    """
    writes = []
    bindings = {}
    pending = []  # نوشتن‌هایی که پیش از اتصال پسینی دیده شده‌اند
    with open(path, encoding="utf-8") as fh:
        lines = fh.readlines()

    def _bind(var, section):
        if var and section:
            bindings[var] = section
            # اتصال پسینی: نوشتن‌های قبلی روی همان نام را حل کن
            for idx, (wvar, wkey, wsec) in enumerate(pending):
                if wvar == var and wsec is None:
                    pending[idx] = (wvar, wkey, section.split(".")[0])

    for raw in lines:
        line = raw.rstrip("\n")
        m = BIND_GET_RE.match(line)
        if m:
            _bind(m.group(1), m.group(2))
            continue
        m = BIND_SUB_RE.match(line)
        if m:
            _bind(m.group(1), m.group(2))
            continue
        m = RETRO_BIND_RE.match(line)
        if m:
            section, var = m.group(1), m.group(2)
            if var not in ("state", "st", "snapshot", "GameState"):
                _bind(var, section)
            continue
        m = DIRECT_WRITE_RE.match(line)
        if m:
            writes.append((m.group(2), m.group(1)))
            continue
        m = WRITE_RE.match(line)
        if m:
            var, key = m.group(1), m.group(2)
            section = bindings.get(var)
            pending.append((var, key, section))
            continue
        m = DOT_WRITE_RE.match(line)
        if m and m.group(1) in bindings:
            section = bindings[m.group(1)]
            pending.append((m.group(1), m.group(2), section))
            continue
        m = NESTED_BIND_RE.match(line)
        if m and m.group(2) in bindings:
            parent = bindings[m.group(2)]
            _bind(m.group(1), parent.split(".")[0])

    # نوشتن‌هایی که پس از اتصال معمولی دیده شده‌اند را به فهرست نهایی ببر
    for var, key, section in pending:
        if section is None:
            section = bindings.get(var)
        writes.append((key, section))
    return writes, bindings


def main():
    files = collect_gd_files()
    if not files:
        print("✗ هیچ فایل .gd یافت نشد")
        return 1

    # اسکن نوشتن‌ها
    writers = {}        # key → set(files)
    key_sections = {}   # key → set(sections)
    write_counts = {}   # (file, key) → تعداد خطوط نوشتن
    for path in files:
        writes, _bindings = scan_file(path)
        for key, section in writes:
            writers.setdefault(key, set()).add(path)
            write_counts[(path, key)] = write_counts.get((path, key), 0) + 1
            if section:
                key_sections.setdefault(key, set()).add(section)

    # شمارش رخداد تحت‌اللفظی هر کلید در همه‌ی فایل‌ها (شامل خواندن‌ها)
    literal_files = {key: set() for key in writers}
    literal_hits = {}   # (file, key) → تعداد رخداد "key"
    key_res = {}
    for key in writers:
        key_res[key] = re.compile(r'"%s"' % re.escape(key))
    for path in files:
        with open(path, encoding="utf-8") as fh:
            src = fh.read()
        for key, rx in key_res.items():
            hits = len(rx.findall(src))
            if hits:
                literal_files[key].add(path)
                literal_hits[(path, key)] = hits

    browsable = extract_browsable_sections()

    orphans, ui_only, self_only, unresolved = [], [], [], 0
    for key in sorted(writers):
        if WHITELIST_RE.search(key):
            continue
        wfiles = writers[key]
        readers = literal_files.get(key, set()) - wfiles
        if readers:
            continue  # ۱) خواننده‌ی متقاطع دارد — قرارداد برقرار است
        # ۲) خواندن درون همان فایل نویسنده؟
        self_read = any(
            literal_hits.get((path, key), 0) > write_counts.get((path, key), 0)
            for path in wfiles
        )
        if self_read:
            self_only.append(key)
            continue
        sections = {s for s in key_sections.get(key, set()) if s}
        if not sections:
            unresolved += 1
            continue  # نام‌متغیر حل‌نشده — بخش نامعلوم (معمولاً دیکشنری رویداد/محلی)
        # ۳) نمایش پویای UI؟
        top_sections = {s.split(".")[0] for s in sections}
        if top_sections & browsable:
            ui_only.append((key, sorted(top_sections)))
            continue
        orphans.append((key, sorted(top_sections),
                        sorted(rel(f) for f in wfiles)))

    # قرارداد کلیدهای مهم: باید خواننده‌ی بیرون از فایل نویسنده داشته باشند
    contract_failures = []
    for section, keys in IMPORTANT_KEYS.items():
        for key in keys:
            wfiles = writers.get(key, set())
            readers = literal_files.get(key, set()) - wfiles
            if not readers:
                where = sorted(rel(f) for f in wfiles) or ["(ناشناخته)"]
                contract_failures.append((section, key, where))

    # ── گزارش ──
    total = len(writers)
    print("═" * 60)
    print("تست قراردادی کلیدهای وضعیت (dead-key)")
    print("═" * 60)
    print("کلیدهای نوشته‌شده در state: %d" % total)
    print("بخش‌های قابل‌مرور در UI: %d" % len(browsable))
    print("خودکفا (دفترداری درون‌فایلی): %d" % len(self_only))
    print("فقط نمایش پویای UI: %d" % len(ui_only))
    print("نام‌متغیر حل‌نشده (نادیده‌گرفته‌شده): %d" % unresolved)

    ok = True
    if orphans:
        ok = False
        print("\n✗ کلیدهای یتیم (نوشته می‌شوند ولی هیچ‌جا مصرف نمی‌شوند): %d"
              % len(orphans))
        for key, sections, wfiles in orphans[:40]:
            print("  • %s  بخش=%s  نویسنده=%s"
                  % (key, ",".join(sections), ",".join(wfiles)))
    else:
        print("\n✓ هیچ کلید یتیمی یافت نشد")

    if contract_failures:
        ok = False
        print("\n✗ نقض قرارداد کلید مهم (بدون خواننده‌ی خارجی): %d"
              % len(contract_failures))
        for section, key, where in contract_failures:
            print("  • %s.%s  نویسنده=%s" % (section, key, ",".join(where)))
    else:
        print("✓ همه‌ی کلیدهای مهم قراردادی خواننده‌ی خارجی دارند")

    if ui_only:
        print("\nℹ کلیدهای فقط‌نمایشی (مصرف‌کننده‌ی منطقی ندارند؛ فقط در مرورگر دیده می‌شوند): %d"
              % len(ui_only))
        for key, sections in ui_only[:25]:
            print("  - %s (%s)" % (key, ",".join(sections)))

    print("═" * 60)
    print("نتیجه: %s" % ("موفق ✓" if ok else "ناموفق ✗"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
