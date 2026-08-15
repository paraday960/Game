# -*- coding: utf-8 -*-
"""پین «سیگنال‌های مرده» — بازرسی ۱۴۰۵ (عمق‌بخشی ۳۷).

پویش: سیگنال‌هایی که emit می‌شوند ولی هیچ شنونده‌ای ندارند = اتم مرده.
درمان شده:
- ۱۲ سیگنال `*_changed` مدیران بخشی (aerospace/aviation/defense_industry/ev/
  health_tourism/knowledge_economy/petrochemical/postal/pro_sports/standards/
  tax/waste_management) — UI از polling استفاده می‌کند، سیگنال بی‌اثر بود.
- command_palette.closed و unified_map.zoom_tier_changed — emit بدون مصرف.

سیگنال‌های عمومی autoload (event_added، state_changed، save_completed/
load_completed/operation_failed، lobby_changed، campaign_advanced) به‌عمد حفظ
می‌شوند: API عمومی رویداد-محور برای مصرف‌کننده‌های آینده/ابزار/تست.
سیگنال‌های تست‌ها با `await signal` شنیده می‌شوند (نه connect) — معتبرند.

این تست پین می‌کند: هیچ سیگنال emit-بدون-شنونده‌ای (خارج از whitelist) بازنگردد.
"""
import io
import re
import sys
import glob

FAIL = []

# سیگنال‌های عمومی عمدی (API رویداد-محور autoload)
PUBLIC_API_SIGNALS = {
    "event_added",               # event_log
    "state_changed",             # state
    "save_completed", "load_completed", "operation_failed",  # save_manager
    "lobby_changed", "campaign_advanced", "turn_finished_changed",
    "chat_message_received",     # multiplayer_campaign_manager
    "settings_changed",          # settings_manager (شنونده دارد ولی API است)
}


def read(p):
    return io.open(p, encoding="utf-8").read()


def check(name, cond, msg):
    if not cond:
        FAIL.append(msg)
        print("❌ %s: %s" % (name, msg))
    else:
        print("✅ %s" % name)


all_src = {}
for f in glob.glob("scripts/**/*.gd", recursive=True):
    all_src[f] = read(f)
for f in glob.glob("tests/*.gd") + glob.glob("scenes/**/*.gd", recursive=True):
    try:
        all_src[f] = read(f)
    except OSError:
        pass


def emit_count(sig):
    n = 0
    for src in all_src.values():
        n += len(re.findall(r'emit_signal\(\s*"' + re.escape(sig) + r'"', src))
        n += len(re.findall(r"\b" + re.escape(sig) + r"\.emit\(", src))
    return n


def listener_count(sig):
    n = 0
    for src in all_src.values():
        n += len(re.findall(r'\.connect\(\s*"' + re.escape(sig) + r'"', src))
        n += len(re.findall(r"\b" + re.escape(sig) + r"\.connect\(", src))
        # شنونده با await (تست‌ها)
        n += len(re.findall(r"\bawait\s+" + re.escape(sig), src))
    return n


dead = []
for f, src in sorted(all_src.items()):
    for sig in re.findall(r"^signal (\w+)", src, re.M):
        if sig in PUBLIC_API_SIGNALS:
            continue
        if emit_count(sig) > 0 and listener_count(sig) == 0:
            dead.append((f.split("/")[-1], sig))

check(
    "بدون سیگنال emit-بدون-شنونده",
    not dead,
    "سیگنال‌های مرده: %s" % (dead or "—"),
)

# سیگنال‌های عمومی باید همچنان تعریف‌شده و emit شونده باشند
for sig in ("event_added", "state_changed", "save_completed"):
    defined = any(sig in re.findall(r"^signal (\w+)", src, re.M) for src in all_src.values())
    check("API عمومی %s حفظ شده" % sig, defined and emit_count(sig) > 0,
          "%s حذف یا بی‌emit شده" % sig)

print()
if FAIL:
    print("==> %d شکست" % len(FAIL))
    sys.exit(1)
print("==> پین سیگنال‌های مرده سبز است")
