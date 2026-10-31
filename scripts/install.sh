#!/bin/zsh
# 构建 Aven 并通过 USB 装到连接的 iPhone 真机（不启动 App、不用模拟器）。
# 接口令牌从本机钥匙串 aven/api-token 读出，构建时注入 Info.plist，不进仓库。
# 用法：scripts/install.sh [设备 UDID]；不给 UDID 时自动选唯一一台有线连接的物理设备。
set -euo pipefail
cd "$(dirname "$0")/.."

device="${1:-}"
if [[ -z "$device" ]]; then
  json=$(mktemp)
  xcrun devicectl list devices --json-output "$json" >/dev/null
  device=$(python3 -I - "$json" <<'PY'
import json, sys
ds = json.load(open(sys.argv[1]))["result"]["devices"]
ok = [d["hardwareProperties"]["udid"] for d in ds
      if d["hardwareProperties"].get("reality") == "physical"
      and d["connectionProperties"].get("transportType") == "wired"
      and d["hardwareProperties"].get("platform") == "iOS"]
print(ok[0] if len(ok) == 1 else "")
PY
)
  rm -f "$json"
  [[ -n "$device" ]] || { echo "没有找到唯一一台有线连接的 iPhone 真机" >&2; exit 1; }
fi

token=$(security find-generic-password -s aven/api-token -w 2>/dev/null || true)
[[ -n "$token" ]] || echo "提醒：钥匙串里没有 aven/api-token，装好后要在 Settings 里手动填令牌" >&2

xcodebuild -project Aven.xcodeproj -scheme Aven -configuration Debug \
  -destination "platform=iOS,id=$device" -derivedDataPath build/DerivedData \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  AVEN_API_TOKEN="$token" build -quiet

xcrun devicectl device install app --device "$device" build/DerivedData/Build/Products/Debug-iphoneos/Aven.app
xcrun devicectl device info apps --device "$device" 2>/dev/null | grep -E 'me\.0xpsyche\.aven' || true
