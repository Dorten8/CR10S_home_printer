#!/usr/bin/env bash
# CR-10S Upgrade - System Ready Diagnostic Runner
set -euo pipefail

TARGET_HOST="${1:-3d-print-dorten.local}"
TARGET_USER="${2:-dorten}"

echo "=========================================================="
echo "      CR-10S UPGRADE: SYSTEM DIAGNOSTICS & TEST RUNNER    "
echo "=========================================================="
echo "Target Host: ${TARGET_USER}@${TARGET_HOST}"
echo ""

echo "[1/4] Checking Network & SSH Connectivity..."
if ssh -o ConnectTimeout=5 "${TARGET_USER}@${TARGET_HOST}" "hostname" > /dev/null 2>&1; then
    echo "  [OK] SSH Connection Successful!"
else
    echo "  [FAIL] Unable to connect via SSH to ${TARGET_USER}@${TARGET_HOST}."
    exit 1
fi

echo "[2/4] Checking Moonraker Klipper API Status..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://${TARGET_HOST}:7125/printer/info" || true)
if [ "$HTTP_CODE" -eq 200 ]; then
    echo "  [OK] Moonraker API is ONLINE (HTTP 200)"
else
    echo "  [WARN] Moonraker API returned HTTP status ${HTTP_CODE}. (Ensure Klipper service is running)."
fi

echo "[3/4] Triggering Stepper Buzz Diagnostic Test Macro..."
curl -s -X POST "http://${TARGET_HOST}:7125/printer/gcode/script?script=STEPPER_BUZZ_ALL" > /dev/null || true
echo "  [SENT] Macro 'STEPPER_BUZZ_ALL' triggered via API."

echo "[4/4] Triggering Sensor Query Test..."
curl -s -X POST "http://${TARGET_HOST}:7125/printer/gcode/script?script=TEST_SENSORS" > /dev/null || true
echo "  [SENT] Macro 'TEST_SENSORS' triggered via API."

echo ""
echo "=========================================================="
echo "Diagnostics Trigger Complete! Open http://${TARGET_HOST} to view live logs."
echo "=========================================================="
