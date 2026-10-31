#!/bin/zsh
# 免费签名自动续签（launchd 每小时跑一次，见 scripts/me.0xpsyche.aven-renew.plist）：
# - 描述文件剩不到 48 小时、且 iPhone 有线或经局域网可用时，重新构建并安装；
# - 剩不到 24 小时还没装上，每天经 tg-hub 的 /v1/notify 推一条 Bark 提醒（令牌读钥匙串 aven/notify-token）。
set -uo pipefail
cd "$(dirname "$0")/.."

state="$HOME/Library/Application Support/Aven"
expiry=$(cat "$state/expiry" 2>/dev/null || echo 0)
now=$(date +%s)
left=$(( expiry - now ))
log() { echo "[$(date '+%m-%d %H:%M')] $*"; }

(( left > 48 * 3600 )) && exit 0

log "描述文件还剩 $(( left / 3600 )) 小时，尝试续签"
# 旧描述文件没过期前 Xcode 会一直复用，先删掉本地缓存里快到期的 Aven 描述文件，逼它重新申请
python3 -I - <<'PY'
import datetime, glob, os, plistlib, subprocess
soon = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(hours=48)
for f in glob.glob(os.path.expanduser("~/Library/Developer/Xcode/UserData/Provisioning Profiles/*")):
    try:
        raw = subprocess.run(["security", "cms", "-D", "-i", f], capture_output=True).stdout
        p = plistlib.loads(raw)
    except Exception:
        continue
    app = p.get("Entitlements", {}).get("application-identifier", "")
    if ".me.0xpsyche.aven" in app and p["ExpirationDate"].replace(tzinfo=datetime.timezone.utc) < soon:
        os.remove(f)
        print("删除快到期的描述文件", app)
PY
if scripts/install.sh --any && (( $(cat "$state/expiry") - $(date +%s) > 48 * 3600 )); then
  log "续签完成，新到期：$(date -r "$(cat "$state/expiry")" '+%F %H:%M')"
  rm -f "$state/reminded"
  exit 0
fi
left=$(( $(cat "$state/expiry" 2>/dev/null || echo 0) - $(date +%s) ))

(( left > 24 * 3600 )) && exit 0
today=$(date +%F)
[[ "$(cat "$state/reminded" 2>/dev/null)" == "$today" ]] && exit 0

token=$(security find-generic-password -s aven/notify-token -w 2>/dev/null || true)
[[ -n "$token" ]] || { log "没有 aven/notify-token，跳过提醒"; exit 0; }
hours=$(( left > 0 ? left / 3600 : 0 ))
text=$( (( left > 0 )) && echo "签名还剩约 ${hours} 小时到期。iPhone 连上数据线（或和 Mac 在同一 Wi-Fi）时会自动续签。" \
                       || echo "签名已过期，Aven 打不开了。iPhone 连上数据线后会自动续签。")
body=$(python3 -I -c 'import json,sys; print(json.dumps({"title":"Aven 需要续签","text":sys.argv[1],"level":"timeSensitive"}, ensure_ascii=False))' "$text")
if printf 'Authorization: Bearer %s\n' "$token" | curl -sS --max-time 15 -H @- -H 'Content-Type: application/json' \
     -X POST https://aven.0xpsyche.me/v1/notify --data "$body" >/dev/null; then
  echo "$today" > "$state/reminded"
  log "已推送续签提醒"
fi
