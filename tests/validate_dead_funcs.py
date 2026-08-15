# -*- coding: utf-8 -*-
"""پین «توابع فراخوانی‌نشده» — بازرسی ۱۴۰۵ (عمق‌بخشی ۳۵).

پویش سراسری: توابع عمومی (بدون underscore) در scripts/core که هیچ‌جا
فراخوانی نمی‌شوند و رفرنس رشته‌ای هم ندارند = اتم مرده. ۱۳ تابع از ۱۰ فایل
حذف شد (get_section، has_country، get_seed، is_transaction_active، replay،
export_json، get_faction_status، get_rate، reset_for_session، has_save،
apply_delta، get_technology، sync_all_branch_floats).
نکته: get_errors در balance_config زنده است (در test_scene استفاده می‌شود).

این تست پین می‌کند: هر تابع عمومی تعریف‌شده در scripts/core باید یا در
فهرست سفید API عمومی باشد (call داینامیک/اتصال signal/API مستند) یا حداقل
یک فراخوانی در کل پروژه داشته باشد. خروج غیرصفر = تابع مرده بازگشته.
"""
import io
import re
import sys
import glob

FAIL = []

# API عمومی: فراخوانی داینامیک (.call("..."))، اتصال signal با نام،
# یا API مستند که از بیرون (JSON/ابزار) استفاده می‌شود.
DYNAMIC_API = {
    "reset", "simulate", "simulate_month", "simulate_day", "update",
    "get_summary", "get_policy", "can_action", "can_start", "can_change",
    "can_enact", "can_select", "can_promise", "apply_action", "toggle",
    "recruit", "assign", "trade", "intervene", "devalue", "appoint",
    "snap_election", "add_promise", "resolve_vote", "describe", "action_icon",
    "get_visible_news", "count_items", "ensure_state", "ensure_time",
    "get_state", "set_state", "log_event", "get_last", "count", "celebrate",
    "push_message", "host_game", "join_game", "host_competitive",
    "join_competitive", "broadcast_state", "maybe_autosave", "verify_chain",
    "rewind", "can_rewind", "truncate_after_tick", "get_history", "get_change",
    "get_country", "get_country_name", "get_country_ids", "get_scenario",
    "get_scenario_ids", "get_scenario_name", "apply_scenario", "get_value",
    "set_value", "cycle_speed", "get_speed_label", "play_click", "play_success",
    "play_alert", "play_celebration", "play_levelup", "play_achievement",
    "get_units", "get_unit_metrics", "month_name", "season_for_state",
    "get_total_days", "days_in_month", "format_number", "to_persian_digits",
    "format_money", "format_percent", "format_large", "get_errors",
    "is_valid", "get_technology_name", "get_available", "get_progress",
    "get_definition", "get_summary", "get_rate", "list_slots", "save_slot",
    "load_slot", "delete_slot", "get_autosave_metadata", "save_game",
    "load_game", "import_events", "get_events", "get_seed_state",
    "diagnose", "decide", "build_budget_command", "build_*", "get_faction",
    "get_all", "get_country_name", "get_war_goal_name", "get_stage",
    "get_score", "get_rank", "get_level", "get_xp", "get_speed",
    "get_difficulty", "get_objectives", "get_progress", "get_news",
    "get_tab", "open_palette", "get_budget", "get_allocations",
    "get_boost", "get_inflows", "get_revenue", "get_costs",
}

# الگوهای underscore: خصوصی (ممکن است با connect به‌نام وصل شوند)
def is_public(fn):
    return not fn.startswith("_")


def read(p):
    return io.open(p, encoding="utf-8").read()


def check(name, cond, msg):
    if not cond:
        FAIL.append(msg)
        print("❌ %s: %s" % (name, msg))
    else:
        print("✅ %s" % name)


# جمع‌آوری همه‌ی سورس‌ها
all_src = {}
for f in glob.glob("scripts/**/*.gd", recursive=True):
    all_src[f] = read(f)
for f in glob.glob("tests/*.gd") + glob.glob("scenes/**/*.gd", recursive=True):
    try:
        all_src[f] = read(f)
    except OSError:
        pass

dead = []
for f in sorted(glob.glob("scripts/core/*.gd")):
    src = all_src[f]
    for m in re.finditer(r"^func (\w+)\(", src, re.M):
        fn = m.group(1)
        if not is_public(fn):
            continue
        if fn in DYNAMIC_API:
            continue
        # فراخوانی در همه‌ی فایل‌ها
        called = 0
        for src2 in all_src.values():
            called += len(re.findall(r"\b" + re.escape(fn) + r"\s*\(", src2))
        # منهای تعریف خودش
        called -= len(re.findall(r"^func " + re.escape(fn) + r"\s*\(", src, re.M))
        # رفرنس رشته‌ای (connect/call داینامیک)
        string_ref = 0
        for src2 in all_src.values():
            string_ref += len(re.findall(r'"' + re.escape(fn) + r'"', src2))
        if called == 0 and string_ref == 0:
            dead.append((f.split("/")[-1], fn))

check(
    "بدون تابع عمومی فراخوانی‌نشده",
    not dead,
    "توابع مرده: %s" % (dead or "—"),
)

# ── 2) فایل‌های یتیم: اسکریپت‌های غیرautoload که هیچ رفرنسی ندارند ─────
# (host_manager.gd و command_bus.gd در عمق‌بخشی ۳۵ حذف شدند — هرگز استفاده نمی‌شدند)
proj = read("project.godot")
AUTOLOAD_PATHS = set(re.findall(r'="\*?res://([^"]+\.gd)"', proj))
REFERENCED_SCRIPTS = set()
for src2 in all_src.values():
    for m in re.finditer(r'preload\("res://([^"]+\.gd)"\)', src2):
        REFERENCED_SCRIPTS.add(m.group(1))
    for m in re.finditer(r'"res://([^"]+\.gd)"', src2):
        REFERENCED_SCRIPTS.add(m.group(1))

orphan_files = []
for f in glob.glob("scripts/multiplayer/*.gd") + glob.glob("scripts/core/*.gd"):
    if f in AUTOLOAD_PATHS or f in REFERENCED_SCRIPTS:
        continue
    orphan_files.append(f)

check(
    "بدون اسکریپت یتیم در core/multiplayer",
    not orphan_files,
    "فایل‌های یتیم: %s" % (orphan_files or "—"),
)

print()
if FAIL:
    print("==> %d شکست" % len(FAIL))
    sys.exit(1)
print("==> پین توابع/فایل‌های مرده سبز است")
