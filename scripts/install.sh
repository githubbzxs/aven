#!/bin/zsh
# 构建 Aven 并装到 iPhone 真机（不启动 App、不用模拟器）。
# 接口令牌从本机钥匙串 aven/api-token 读出，构建时注入 Info.plist，不进仓库。
# 用法：scripts/install.sh [--any] [设备 UDID]
#   不给 UDID 时自动选唯一一台有线连接的物理 iPhone；--any 时也接受经局域网连接的（自动续签用）。
# 装好后把描述文件到期时刻写进 ~/Library/Application Support/Aven/expiry（renew.sh 读）。
set -euo pipefail
cd "$(dirname "$0")/.."

any=0
if [[ "${1:-}" == "--any" ]]; then any=1; shift; fi
device="${1:-}"
if [[ -z "$device" ]]; then
  json=$(mktemp)
  xcrun devicectl list devices --json-output "$json" >/dev/null 2>&1
  device=$(python3 -I - "$json" "$any" <<'PY'
import json, sys
ds = json.load(open(sys.argv[1]))["result"]["devices"]
def usable(c):
    # 默认只认有线；--any 时有线或无线（同一局域网）都行
    if sys.argv[2] == "0":
        return c.get("transportType") == "wired"
    return c.get("transportType") is not None and c.get("pairingState") == "paired"
ok = [d["hardwareProperties"]["udid"] for d in ds
      if d["hardwareProperties"].get("reality") == "physical"
      and d["hardwareProperties"].get("platform") == "iOS"
      and d["connectionProperties"].get("tunnelState") != "unavailable"
      and usable(d["connectionProperties"])]
print(ok[0] if len(ok) == 1 else "")
PY
)
  rm -f "$json"
  [[ -n "$device" ]] || { echo "没有找到唯一一台可用的 iPhone 真机" >&2; exit 2; }
fi

token=$(security find-generic-password -s aven/api-token -w 2>/dev/null || true)
[[ -n "$token" ]] || echo "提醒：钥匙串里没有 aven/api-token，装好后要在 Settings 里手动填令牌" >&2

xcodebuild -project Aven.xcodeproj -scheme Aven -configuration Debug \
  -destination "platform=iOS,id=$device" -derivedDataPath build/DerivedData \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  AVEN_API_TOKEN="$token" build -quiet

app=build/DerivedData/Build/Products/Debug-iphoneos/Aven.app
xcrun devicectl device install app --device "$device" "$app"
xcrun devicectl device info apps --device "$device" 2>/dev/null | grep -E 'me\.0xpsyche\.aven' || true

# 记录描述文件到期时刻（epoch 秒）
state="$HOME/Library/Application Support/Aven"
mkdir -p "$state"
security cms -D -i "$app/embedded.mobileprovision" 2>/dev/null \
  | python3 -I -c 'import plistlib,sys,datetime; e=plistlib.loads(sys.stdin.buffer.read())["ExpirationDate"]; print(int(e.replace(tzinfo=datetime.timezone.utc).timestamp()))' \
  > "$state/expiry.tmp" && mv "$state/expiry.tmp" "$state/expiry"
echo "描述文件到期：$(date -r "$(cat "$state/expiry")" '+%Y-%m-%d %H:%M')"
