#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ "${1:-}" == "--help" || -z "${1:-}" ]]; then
  echo 'Usage: API_BASE_URL=http://MAC_LAN_IP:8000 ./scripts/profile_mobile.sh DEVICE_ID'
  echo 'Find DEVICE_ID with: flutter devices. Use a physical iPhone or Android.'
  exit 0
fi
profile_device="$1"
profile_api="${API_BASE_URL:-}"
if [[ -z "$profile_api" && "$(uname)" == Darwin ]]; then
  profile_interface="$(route -n get default 2>/dev/null | awk '/interface:/ {print $2}')"
  profile_ip="$(ipconfig getifaddr "$profile_interface" 2>/dev/null || true)"
  if [[ -n "$profile_ip" ]]; then profile_api="http://${profile_ip}:8000"; fi
fi
if [[ -z "$profile_api" ]]; then
  echo 'Set API_BASE_URL to the backend URL reachable from the phone.' >&2
  exit 1
fi
cd "$project_dir/flutter_app"
exec flutter run --profile -d "$profile_device" \
  --dart-define=PERF_METRICS=true \
  "--dart-define=API_BASE_URL=$profile_api"
