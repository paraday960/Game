#!/usr/bin/env bash
# تست شبکهی محلی (ENet) — همان الگوی CI با دایرکتوریهای جدا.
# مشکل race روی .godot مشترک: هر نمونه دایرکتوری خودش را دارد.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/tmp/Godot_v4.7.1-stable_linux.x86_64}"
if [ ! -x "$GODOT" ]; then
  echo "Godot یافت نشد. مسیر را با GODOT=... بدهید."
  exit 2
fi
rm -rf /tmp/GameHost /tmp/GameClient
cp -r . /tmp/GameHost
cp -r . /tmp/GameClient
rm -rf /tmp/GameHost/.godot /tmp/GameHost/.git /tmp/GameClient/.godot /tmp/GameClient/.git
"$GODOT" --headless --path /tmp/GameHost --import > /dev/null 2>&1
"$GODOT" --headless --path /tmp/GameClient --import > /dev/null 2>&1
echo "setup ok — running network + competitive tests"

(cd /tmp/GameHost && timeout 120 "$GODOT" --headless --path . -s res://tests/test_network_host.gd > /tmp/network-host.log 2>&1) &
HOST_PID=$!
sleep 2
CLIENT_STATUS=0; HOST_STATUS=0
(cd /tmp/GameClient && timeout 120 "$GODOT" --headless --path . -s res://tests/test_network_client.gd > /tmp/network-client.log 2>&1) || CLIENT_STATUS=$?
wait "$HOST_PID" || HOST_STATUS=$?
grep -E "PASSED|FAILED|TIMEOUT" /tmp/network-host.log /tmp/network-client.log || true
[ "$HOST_STATUS" -eq 0 ] && [ "$CLIENT_STATUS" -eq 0 ] || { echo "❌ NETWORK TEST FAILED"; exit 1; }
echo "✅ NETWORK TEST PASSED"

(cd /tmp/GameHost && timeout 120 "$GODOT" --headless --path . -s res://tests/test_competitive_host.gd > /tmp/competitive-host.log 2>&1) &
COMP_HOST_PID=$!
sleep 2
COMP_CLIENT_STATUS=0; COMP_HOST_STATUS=0
(cd /tmp/GameClient && timeout 120 "$GODOT" --headless --path . -s res://tests/test_competitive_client.gd > /tmp/competitive-client.log 2>&1) || COMP_CLIENT_STATUS=$?
wait "$COMP_HOST_PID" || COMP_HOST_STATUS=$?
grep -E "PASSED|FAILED|TIMEOUT" /tmp/competitive-host.log /tmp/competitive-client.log || true
[ "$COMP_HOST_STATUS" -eq 0 ] && [ "$COMP_CLIENT_STATUS" -eq 0 ] || { echo "❌ COMPETITIVE TEST FAILED"; exit 1; }
echo "✅ COMPETITIVE TEST PASSED"
