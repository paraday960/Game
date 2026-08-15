# -*- coding: utf-8 -*-
"""پین «فیلدهای نمایش فارسی» — بازرسی ۱۴۰۵.

هر آیتم داده‌ای که در UI نمایش داده می‌شود باید فیلدهای فارسی نمایشی خود را
داشته باشد (نام، دسته/شاخه و...). پویش نشان داد:
- ۳ «کشور خالی» در countries.json در واقع بخش sources (اعتبارنامه‌ی داده) است —
  خود کشورها (۱۹۵) همگی id و name_fa دارند.
- فناوری‌ها به‌جای category_fa از branch فارسی استفاده می‌کنند (انرژی_پاک،
  دیجیتال، ...) — همه موجود.

این تست پین می‌کند: فیلدهای نمایشی در laws/policies/projects/programs/
technologies/scenarios و نام فارسی کشورها کامل و یکتا باشند.
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


def load_list(path, key):
    d = json.load(io.open(path, encoding="utf-8"))
    if isinstance(d, list):
        return d
    if isinstance(d, dict) and key in d:
        return d[key]
    for v in d.values():
        if isinstance(v, list):
            return v
    return []


def missing_fields(items, fields):
    return [(it.get("id"), f) for it in items for f in fields
            if not (str(it.get(f) or "").strip())]


CHECKS = [
    ("data/laws.json", "laws", ["name_fa", "category_fa"]),
    ("data/policies.json", "policies", ["name_fa", "category_fa"]),
    ("data/national_projects.json", "projects", ["name_fa", "category_fa"]),
    ("data/military_programs.json", "programs", ["name_fa"]),
    ("data/technologies.json", "technologies", ["name_fa", "branch"]),
    ("data/scenarios.json", "scenarios", ["name_fa", "difficulty_fa"]),
]
for f, key, fields in CHECKS:
    items = load_list(f, key)
    miss = missing_fields(items, fields)
    check(
        "فیلدهای نمایشی %s" % f.split("/")[-1],
        not miss,
        "خالی: %s" % (miss[:5] or "—"),
    )

# کشورها
countries = load_list("data/countries.json", "countries")
check("تعداد کشورها", len(countries) >= 190, "تعداد کشورها غیرعادی: %d" % len(countries))
miss_id = [c.get("id") for c in countries if not (c.get("id") or "").strip()]
miss_name = [c.get("id") for c in countries if not (c.get("name_fa") or "").strip()]
check("شناسه و نام فارسی همه‌ی کشورها", not miss_id and not miss_name,
      "کشورهای بی‌نام/بی‌شناسه: %s %s" % (miss_id[:5], miss_name[:5]))
names = [str(c.get("name_fa")) for c in countries]
check("نام فارسی یکتا", len(names) == len(set(names)), "نام تکراری کشور")

print()
if FAIL:
    print("==> %d شکست" % len(FAIL))
    sys.exit(1)
print("==> پین فیلدهای نمایش فارسی سبز است (%d کشور)" % len(countries))
