#!/bin/bash
set -euo pipefail

# ANSI colors
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
CYAN="\033[36m"
RESET="\033[0m"

# OS検出
OS="$(uname -s)"

SERVICE_NAME="Claude Code-credentials"
USAGE_URL="https://api.anthropic.com/api/oauth/usage"
BETA_HEADER="anthropic-beta: oauth-2025-04-20"

# TMPDIR フォールバック（Linuxでは未設定の場合がある）
: "${TMPDIR:=/tmp}"

# クロスプラットフォーム mtime取得
get_mtime() {
  if [ "$OS" = "Darwin" ]; then
    stat -f %m "$1" 2>/dev/null || echo 0
  else
    stat -c %Y "$1" 2>/dev/null || echo 0
  fi
}

# --- キャッシュ設定 ---
CACHE_DIR="$HOME/.claude/statuslines/.cache"
CACHE_FILE="$CACHE_DIR/usage_response.json"
CACHE_TTL=150 # 秒（2分30秒）

mkdir -p "$CACHE_DIR"

LOCK_FILE="$CACHE_DIR/usage_lock"

# リクエスト間隔の制御（キャッシュ or ロックファイルで判定）
skip_request=false
if [ -f "$CACHE_FILE" ] && [ -s "$CACHE_FILE" ]; then
  cache_mtime="$(get_mtime "$CACHE_FILE")"
  now="$(date +%s)"
  age=$(( now - cache_mtime ))
  if [ "$age" -lt "$CACHE_TTL" ]; then
    skip_request=true
  fi
elif [ -f "$LOCK_FILE" ]; then
  lock_mtime="$(get_mtime "$LOCK_FILE")"
  now="$(date +%s)"
  lock_age=$(( now - lock_mtime ))
  if [ "$lock_age" -lt "$CACHE_TTL" ]; then
    # ロック中（前回API失敗から待機中）→ リクエストしない
    skip_request=true
  fi
fi

if [ "$skip_request" = true ]; then
  if [ -f "$CACHE_FILE" ] && [ -s "$CACHE_FILE" ]; then
    response="$(cat "$CACHE_FILE")"
  else
    # ロック中だがキャッシュなし → 前回失敗からの待機中
    echo -e "${YELLOW}Usage⏳${RESET}"
    exit 0
  fi
else
  # --- 資格情報の取得（OSごとに分岐） ---
  creds_json=""
  if [ "$OS" = "Darwin" ]; then
    # macOS: Keychain
    creds_json="$(security find-generic-password -s "$SERVICE_NAME" -w 2>/dev/null || true)"
  else
    # Linux: ~/.claude/.credentials.json から読む
    CREDS_FILE="$HOME/.claude/.credentials.json"
    if [ -f "$CREDS_FILE" ]; then
      creds_json="$(cat "$CREDS_FILE" 2>/dev/null || true)"
    fi
  fi

  if [ -z "$creds_json" ]; then
    echo -e "${RED}Token❌${RESET}"
    exit 0
  fi

  # --- JSON から accessToken 抽出（{"claudeAiOauth":{"accessToken":"..."}} 対応）---
  token="$(
    python3 -c '
import sys, json, re
s = sys.stdin.read().strip()
token = ""
try:
    obj = json.loads(s)
    if isinstance(obj, dict):
        token = (obj.get("claudeAiOauth") or {}).get("accessToken") or ""
        if not token:
            token = obj.get("accessToken") or ""
except Exception:
    pass
if not token:
    m = re.search(r"\"accessToken\"\s*:\s*\"([^\"]+)\"", s)
    if m: token = m.group(1)
print(token)
' <<<"$creds_json" 2>/dev/null || true
  )"

  if [ -z "$token" ]; then
    echo -e "${RED}Token❌${RESET}"
    exit 0
  fi

  # --- usage API ---
  http_code="$(
    curl -sS -w "%{http_code}" -o "$TMPDIR/usage_body.json" -D "$TMPDIR/usage_headers.txt" --config - <<CURL 2>/dev/null || echo "000"
url = "$USAGE_URL"
header = "Authorization: Bearer $token"
header = "$BETA_HEADER"
CURL
  )"

  if [ "$http_code" = "200" ] && [ -f "$TMPDIR/usage_body.json" ]; then
    response="$(cat "$TMPDIR/usage_body.json")"
    # 有効なJSONかチェック
    if python3 -c 'import sys,json; json.loads(sys.stdin.read())' <<<"$response" 2>/dev/null; then
      echo "$response" > "$CACHE_FILE"
    else
      # 不正なレスポンスの場合はキャッシュにフォールバック
      if [ -f "$CACHE_FILE" ]; then
        response="$(cat "$CACHE_FILE")"
      else
        echo -e "${RED}Usage❌${RESET}"
        exit 0
      fi
    fi
  else
    # 429の場合、レスポンスボディに有効なデータが含まれていれば使う
    if [ "$http_code" = "429" ] && [ -f "$TMPDIR/usage_body.json" ]; then
      body_429="$(cat "$TMPDIR/usage_body.json" 2>/dev/null)"
      if [ -n "$body_429" ] && python3 -c 'import sys,json; d=json.loads(sys.stdin.read()); assert "five_hour" in d' <<<"$body_429" 2>/dev/null; then
        response="$body_429"
        echo "$response" > "$CACHE_FILE"
        rm -f "$TMPDIR/usage_body.json" "$TMPDIR/usage_headers.txt" 2>/dev/null
        # 成功パスへ（下の出力処理へ進む）
      fi
    fi

    # responseがまだ未設定の場合、キャッシュにフォールバック
    if [ -z "${response:-}" ]; then
      # ロックファイルでリクエストループを防止
      touch "$LOCK_FILE" 2>/dev/null

      if [ -f "$CACHE_FILE" ] && [ -s "$CACHE_FILE" ]; then
        response="$(cat "$CACHE_FILE")"
        export USAGE_STALE="⚠${http_code}"
      else
        echo -e "${RED}Usage❌(HTTP:${http_code})${RESET}"
        exit 0
      fi
    fi
  fi
  rm -f "$TMPDIR/usage_body.json" "$TMPDIR/usage_headers.txt" 2>/dev/null
fi

# --- parse & output（残り時間つき / 単位の間に空白）---
out="$(
  python3 -c '
import sys, json
from datetime import datetime

GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
CYAN="\033[36m"
RESET="\033[0m"

def clamp(v):
    try: v = int(float(v))
    except: v = 0
    return max(0, min(100, v))

def color_for(p):
    if p >= 80: return RED
    if p >= 50: return YELLOW
    return GREEN

def bar(p):
    # 点字1マスは8ドット。10マス x 8ドット = 80段階 (1.25%刻み) で utilization を表現する。
    # utilization は整数パーセント精度なので、これより細かくしても情報量は増えない。
    cells = 10
    # ドット点灯順: 左列を下から上、続けて右列を下から上 (U+2800 基準のビット値)。
    # 使用率メーターとして下から満ちていく見た目にする。
    order = (0x40, 0x04, 0x02, 0x01, 0x80, 0x20, 0x10, 0x08)
    lit = round(p / 100 * cells * 8)
    out = []
    for i in range(cells):
        n = min(8, max(0, lit - 8 * i))
        bits = 0
        for k in range(n):
            bits |= order[k]
        out.append(chr(0x2800 + bits))
    return "".join(out)

def fmt_with_remaining(raw):
    if not raw:
        return "", ""
    raw = raw.replace("Z", "+00:00")
    try:
        dt = datetime.fromisoformat(raw).astimezone()
        now = datetime.now().astimezone()
        diff = dt - now

        total_sec = int(diff.total_seconds())
        if total_sec < 0:
            remaining = "reset"
        else:
            days = total_sec // 86400
            hours = (total_sec % 86400) // 3600
            minutes = (total_sec % 3600) // 60

            # 単位の間に空白。0の単位は省略（見た目重視）
            if days > 0:
                remaining = f"{days}d" + (f" {hours}h" if hours > 0 else "")
            elif hours > 0:
                remaining = f"{hours}h" + (f" {minutes}m" if minutes > 0 else "")
            else:
                remaining = f"{minutes}m"

        formatted = dt.strftime("%m/%d %H:%M")
        return formatted, remaining
    except:
        return "", ""

obj = json.loads(sys.stdin.read().strip())

five = clamp((obj.get("five_hour") or {}).get("utilization", 0))
seven = clamp((obj.get("seven_day") or {}).get("utilization", 0))

r5, rem5 = fmt_with_remaining((obj.get("five_hour") or {}).get("resets_at"))
r7, rem7 = fmt_with_remaining((obj.get("seven_day") or {}).get("resets_at"))

r5s = f" {CYAN}{r5}{RESET} ({rem5})" if r5 else ""
r7s = f" {CYAN}{r7}{RESET} ({rem7})" if r7 else ""

import os
stale = os.environ.get("USAGE_STALE", "")
stale_suffix = f" {YELLOW}{stale}{RESET}" if stale else ""
print(f"5h {color_for(five)}{bar(five)} {five}%{RESET}{r5s} | 7d {color_for(seven)}{bar(seven)} {seven}%{RESET}{r7s}{stale_suffix}")
' <<<"$response" 2>/dev/null || true
)"

if [ -z "$out" ]; then
  echo -e "${RED}Parse❌${RESET}"
  exit 0
fi

echo -e "$out"

