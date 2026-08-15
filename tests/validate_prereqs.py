# -*- coding: utf-8 -*-
"""پین پویش «پیش‌نیازهای ناموجود» — دور سیزدهم.

۹ برنامه‌ی نظامی پیش‌نیاز فناوری‌ای داشتند که در technologies.json وجود ندارد
(ai_combat، advanced_radar، advanced_training، sonar_tech، advanced_materials،
stealth_tech، advanced_avionics، battlefield_network) یا به برنامه‌ی دیگری ارجاع
می‌دادند (naval_modernization) که هرگز وارد technology.unlocked نمی‌شود.
نتیجه: آن برنامه‌ها برای همیشه «قفل» بودند — محتوای مرده.

درمان: نگاشت به فناوری‌های موجود و هم‌معنا:
drone_swarm→defense_drones+national_ai | electronic_warfare→cyber_defense+quantum_radar
special_forces_expansion→counter_intel_network | urban_warfare→defense_drones
submarine_force→advanced_manufacturing+quantum_radar | amphibious→advanced_manufacturing
hypersonic→missile_defense+advanced_manufacturing | stealth→advanced_manufacturing+quantum_radar
c4isr→cyber_defense

این تست پین می‌کند: هر پیش‌نیاز در data/*.json باید در اتحاد ID های
laws+policies+technologies+projects+programs وجود داشته باشد.
"""
import io
import json
import sys
import glob

FAIL = []


def check(name, cond, msg):
    if not cond:
        FAIL.append(msg)
        print("❌ %s: %s" % (name, msg))
    else:
        print("✅ %s" % name)


DATA_FILES = [
    "data/laws.json",
    "data/policies.json",
    "data/technologies.json",
    "data/national_projects.json",
    "data/military_programs.json",
]


def load_items(path):
    d = json.load(io.open(path, encoding="utf-8"))
    if isinstance(d, list):
        return d
    for v in d.values():
        if isinstance(v, list):
            return v
    return []


all_ids = set()
items_by_file = {}
for f in DATA_FILES:
    items = load_items(f)
    items_by_file[f] = items
    for it in items:
        if isinstance(it.get("id"), str):
            all_ids.add(it["id"])

bad = []
for f, items in items_by_file.items():
    for it in items:
        for pr in it.get("prerequisites", []):
            if pr not in all_ids:
                bad.append((f, it.get("id"), pr))

check(
    "همه‌ی پیش‌نیازها معتبر",
    not bad,
    "پیش‌نیازهای ناموجود: %s" % (bad or "—"),
)

# پین صریح برنامه‌های درمان‌شده: همه باید قابل شروع شوند (فقط فناوری موجود)
progs = load_items("data/military_programs.json")
tech_ids = set(i["id"] for i in load_items("data/technologies.json"))
dead = []
for p in progs:
    if any(pr not in tech_ids for pr in p.get("prerequisites", [])):
        dead.append(p["id"])
check(
    "بدون برنامه‌ی نظامی قفل‌شده",
    not dead,
    "برنامه‌های همچنان مرده: %s" % (dead or "—"),
)

print()
if FAIL:
    print("==> %d شکست" % len(FAIL))
    sys.exit(1)
print("==> همه‌ی پین‌های پیش‌نیاز سبزند (%d شناسه در اتحاد)" % len(all_ids))
