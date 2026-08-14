#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""قرارداد سیم‌کشی کلیدهای یتیم — تثبیت رگرسیون بازرسی «کلید یتیم ۱۴۰۵».

پویش state.gd نشان داد خانواده‌ای از کلیدها «محاسبه/نوشته» می‌شوند ولی هرگز اثر
واقعی ندارند (یتیم). این تست درمان‌های اعمال‌شده را پین می‌کند تا برنگردند:

۱) کانال بودجهٔ ترانزیت: transit_manager باید «transit_revenue_monthly» بنویسد و
   economy_system آن را در government_revenue مصرف کند؛ نویسهٔ مستقیم روی ذخایر ممنوع.
۲) کانال رویالتی: intellectual_property_manager «royalty_revenue_monthly» بنویسد
   و economy_system مصرف کند.
۳) مالکیت یکتای تجارت: هیچ فایلی جز trade_system اجازهٔ نوشتن سطح
   exports/imports/balance را ندارد (نویسندگان سرکش transit/map_layer حذف شدند).
۴) latch کرش بورس: last_crash باید در stock_market_manager خوانده شود نه فقط نوشته.
۵) اتصال شبکه: map_network باید در trade_system و tourism_system خوانده شود.
۶) پاک‌سازی init: کلیدهای کاملاً مرده (citizens_sample/front_lines) در state.gd نباشند.

خروج غیرصفر = بازگشت هر یک از این الگوهای مرده.
"""
import io
import re
import sys
import glob

fail = []

def src(path):
    return io.open(path, encoding="utf-8").read()

# ── ۱) کانال ترانزیت ────────────────────────────────────────────────────
transit = src("scripts/core/transit_manager.gd")
econ = src("scripts/systems/economy_system.gd")
if '["transit_revenue_monthly"]' in transit:
    print("✅ transit_manager کانال ماهانهٔ درآمد ترانزیت را می‌نویسد")
else:
    fail.append("transit_manager کانال transit_revenue_monthly را نمی‌نویسد")
if '"transit_revenue_monthly"' in econ:
    print("✅ economy_system کانال ترانزیت را در بودجه مصرف می‌کند")
else:
    fail.append("economy_system کانال transit_revenue_monthly را مصرف نمی‌کند")
if re.search(r'\["foreign_reserves"\]\s*(?:=|\+=)\s*[^=\s]', transit):
    fail.append("transit_manager دوباره مستقیم روی ذخایر ارزی می‌نویسد")
else:
    print("✅ نویسهٔ مستقیم ترانزیت روی ذخایر ارزی حذف شده")

# ── ۲) کانال رویالتی ────────────────────────────────────────────────────
ip = src("scripts/core/intellectual_property_manager.gd")
if '["royalty_revenue_monthly"]' in ip:
    print("✅ intellectual_property_manager کانال ماهانهٔ رویالتی را می‌نویسد")
else:
    fail.append("intellectual_property_manager کانال royalty_revenue_monthly را نمی‌نویسد")
if '"royalty_revenue_monthly"' in econ:
    print("✅ economy_system کانال رویالتی را در بودجه مصرف می‌کند")
else:
    fail.append("economy_system کانال royalty_revenue_monthly را مصرف نمی‌کند")

# ── ۳) مالکیت یکتای سطح تجارت ───────────────────────────────────────────
# تشخیص receiver: فقط نوشتن روی دیکشنریِ واقعی state.trade ممنوع است (نه کلیدهای
# همنام در دیکشنری‌های دیگر مانند pro_sports_policy.exports یا arms.exports).
TRADE_BIND_RE = re.compile(
    r'(\w+)\s*(?::\s*Dictionary)?\s*=\s*state(?:\.get\(\s*["\']trade["\']|\s*\[\s*["\']trade["\']\s*\])')
# فهرست سفید «ضربهٔ گذرا»: شوک‌های بحران/جنگ/کاهش ارزش حق دارند به جریان سطح
# ضربهٔ یک‌باره بزنند (بهبود پس از پایان بحران خودکار است)؛ این با «دریفت پنهان
# سیستماتیک» فرق دارد که باید از کانال هدف برود.
TRANSIENT_OK = {"scripts/core/engine.gd", "scripts/systems/trade_route_warfare_system.gd"}

rogue = []
for f in sorted(glob.glob("scripts/**/*.gd", recursive=True)):
    if f.endswith("trade_system.gd") or f.replace("\\", "/") in TRANSIENT_OK:
        continue
    s = src(f)
    bound = set(TRADE_BIND_RE.findall(s))          # varهای محلیِ گره‌خورده به trade
    # الگوی مستقیم state["trade"]["exports"] =
    for m in re.finditer(r'state\s*\[\s*["\']trade["\']\s*\]\s*\[\s*["\'](exports|imports|balance)["\']\s*\]\s*=(?![=])', s):
        rogue.append((f, m.group(1)))
    # الگوی receiver محلی: trade["exports"] = / trade_d["imports"] = ...
    for m in re.finditer(r'\b(\w+)\s*\[\s*["\'](exports|imports|balance)["\']\s*\]\s*=(?![=])', s):
        if m.group(1) in bound:
            rogue.append((f, "%s.%s" % (m.group(1), m.group(2))))
if rogue:
    for f, k in rogue:
        fail.append("نویسندهٔ سرکش سطح تجارت در %s: %s" % (f, k))
else:
    print("✅ مالکیت یکتای سطح exports/imports/balance با trade_system است (شوک‌های گذرا مستثنا)")

# ── ۴) latch کرش بورس ───────────────────────────────────────────────────
sm = src("scripts/core/stock_market_manager.gd")
if re.search(r'\.get\("last_crash"', sm):
    print("✅ latch کرش بورس (last_crash) خوانده می‌شود — رژیم بهبود فعال است")
else:
    fail.append("last_crash دوباره یتیم شد: در stock_market_manager خوانده نمی‌شود")

# ── ۵) اتصال شبکه ────────────────────────────────────────────────────────
trade = src("scripts/systems/trade_system.gd")
tourism = src("scripts/systems/tourism_system.gd")
if '"map_network"' in trade and "air_connectivity" in trade:
    print("✅ trade_system اتصال/اختلال map_network را در سهم هدف مصرف می‌کند")
else:
    fail.append("trade_system دیگر map_network را نمی‌خواند")
if '"map_network"' in tourism and "air_connectivity" in tourism:
    print("✅ tourism_system اتصال map_network را در جذابیت مقصد مصرف می‌کند")
else:
    fail.append("tourism_system دیگر map_network را نمی‌خواند")

# ── ۶) پاک‌سازی init ────────────────────────────────────────────────────
st = src("scripts/core/state.gd")
for dead in ["citizens_sample", "front_lines"]:
    if '"%s"' % dead in st:
        fail.append("کلید مردهٔ «%s» دوباره به state.gd برگشته" % dead)
    else:
        print("✅ کلید مردهٔ «%s» از init حذف شده" % dead)

if fail:
    print("\n❌ شکست قرارداد سیم‌کشی کلیدهای یتیم:")
    for x in fail:
        print("  • " + x)
    sys.exit(1)
print("\nسیم‌کشی کلیدهای یتیم OK: همهٔ درمان‌های بازرسی ۱۴۰۵ پایدارند.")
