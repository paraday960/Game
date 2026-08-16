#!/usr/bin/env bash
# اجرای همه‌ی تست‌های Godot (سوئیت کامل) — شامل تست‌های عمقی که در CI نیستند.
# کاربرد: ./tools/run_all_godot_tests.sh  [GODOT=/path/to/godot]
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/tmp/Godot_v4.7.1-stable_linux.x86_64}"
if [ ! -x "$GODOT" ]; then
  echo "Godot یافت نشد. مسیر را با GODOT=... بدهید."
  exit 2
fi

# import یک‌بار برای cache پایدار
"$GODOT" --headless --path . --import > /dev/null 2>&1

PASS=0
FAIL=0
FAILED_LIST=""
for f in tests/*.gd; do
  name=$(basename "$f" .gd)
  # تست‌های شبکه/رقابتی جداگانه (دو نمونه) اجرا می‌شوند
  case "$name" in
    test_network_*|test_competitive_*) continue ;;
  esac
  # test_long و test_scene از طریق .tscn اجرا می‌شوند (SceneTree کامل)
  if [ -f "tests/$name.tscn" ]; then
    target="res://tests/$name.tscn"
    mode=""
  else
    target="res://tests/$name.gd"
    mode="-s"
  fi
  if timeout 240 "$GODOT" --headless --path . $mode "$target" > /tmp/gdtest.log 2>&1; then
    PASS=$((PASS+1))
    echo "✅ $name"
  else
    FAIL=$((FAIL+1))
    FAILED_LIST="$FAILED_LIST $name"
    echo "❌ $name"
    grep -E "❌|FAILED|SCRIPT ERROR" /tmp/gdtest.log | tail -3
  fi
done

echo ""
echo "=== GODOT TESTS: PASS=$PASS FAIL=$FAIL ==="
[ -n "$FAILED_LIST" ] && echo "FAILED:$FAILED_LIST" || echo "ALL GREEN"
exit $FAIL
