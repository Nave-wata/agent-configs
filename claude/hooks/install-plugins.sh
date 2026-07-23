#!/usr/bin/env bash
#
# install-plugins.sh — Claude Code プラグインの自動インストール（SessionStart フック）
#
#   目的:
#     settings.local.json の extraKnownMarketplaces / enabledPlugins はプラグインを
#     「有効」と宣言するだけで、実体のインストールは行わない。sbx（Docker Sandboxes）
#     でエージェントを起動する運用ではサンドボックスごとに ~/.claude が初期状態の
#     ため、宣言済みプラグイン（codex 等）を毎回手動でインストールする必要があった。
#     このフックがセッション開始時に不足分だけを自動で補い、手動インストールを不要にする。
#
#   前提:
#     sbx 内での実行を前提とする（claude CLI / python3 / GNU timeout が存在する Linux）。
#     ホスト側の claude 環境は対象外。
#
#   方式:
#     settings.local.json（このスクリプトと同じ .claude/ 配下）の宣言を正とし、
#     claude plugin marketplace list --json / claude plugin list --json の実状態と
#     突き合わせ、足りないものだけ claude plugin marketplace add / claude plugin
#     install で補う。JSON の解釈は python3（標準ライブラリのみ）に任せる。
#
#   失敗の扱い:
#     このフックが原因でセッション開始を止めないことを最優先とし、前提コマンドの
#     欠如・実状態の取得失敗・追加/インストール失敗はすべて警告のみで exit 0 する。
#     実状態の取得に失敗した場合（コマンド失敗だけでなく、終了コード 0 で不正な
#     JSON が返った場合を含む）は「全部未導入」とは見なさず、このフック自体を
#     スキップする（導入済みプラグインへの無駄な再インストール試行を避けるため）。
#     ネットワーク不通等で claude CLI が返ってこない事故に備え、各呼び出しには
#     timeout を付ける。フック定義側の timeout（1800 秒）は「一覧取得 60 秒 × 2 +
#     add/install 300 秒 × 複数件」の直列実行を収める余裕を持たせた値。万一そこで
#     打ち切られても、未処理分は次回セッション開始時に再試行される。
#
#   排他:
#     同一サンドボックスで複数セッションが同時に起動した場合の add/install 競合を
#     避けるため、flock による非ブロッキング排他を行う（取れなければ他セッションが
#     処理中なので何もせず終了。flock はプロセス消滅で自動解放されるため stale lock
#     は残らない）。flock が無い環境では排他なしで続行する。
#
#   べき等性と起動コスト:
#     宣言と実状態が一致していれば何もせず無言で終了する（実測 0.5 秒程度。
#     claude CLI のローカル読み取り 2 回のみで、ネットワークアクセスは無い）。
#     フック定義側で matcher を "startup" に絞り（resume/clear/compact では発火しない）、
#     "async": true でバックグラウンド実行するため、セッション起動はブロックしない。
#     いずれにせよ新規インストールしたプラグインが有効になるのは次回セッション
#     からなので、非同期化による機能上の損失は無い。
#
set -uo pipefail

warn() { printf 'install-plugins: %s\n' "$1" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS="$SCRIPT_DIR/../settings.local.json"

if [ ! -f "$SETTINGS" ]; then
  warn "警告: 設定ファイルが見つかりません: $SETTINGS"
  exit 0
fi
for cmd in claude python3 timeout; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    warn "警告: $cmd が見つからないため、プラグインの自動インストールをスキップします。"
    exit 0
  fi
done

# --- 排他（同時起動セッション間の add/install 競合防止） ---
if command -v flock >/dev/null 2>&1; then
  lock_file="${HOME}/.claude/.agent-configs-install-plugins.lock"
  mkdir -p "$(dirname "$lock_file")"
  exec 9>"$lock_file"
  if ! flock -n 9; then
    exit 0  # 他セッションが処理中。同じ不足分を二重に処理する意味は無い
  fi
fi

# --- 実状態の取得（失敗したら警告してスキップ。空扱いで進めない） ---
if ! known_json="$(timeout 60 claude plugin marketplace list --json 2>/dev/null)"; then
  warn "警告: マーケットプレイス一覧の取得に失敗したため、自動インストールをスキップします。"
  exit 0
fi
if ! installed_json="$(timeout 60 claude plugin list --json 2>/dev/null)"; then
  warn "警告: インストール済みプラグイン一覧の取得に失敗したため、自動インストールをスキップします。"
  exit 0
fi

# --- 宣言と実状態の差分から実行計画を作る ---
#     出力形式: "marketplace<TAB>名前<TAB>参照" / "plugin<TAB>plugin@marketplace<TAB>"
#     マーケットプレイス追加を先に出力する（後続のプラグインインストールが参照するため）。
if ! plugin_plan="$(
  KNOWN_JSON="$known_json" INSTALLED_JSON="$installed_json" \
  python3 - "$SETTINGS" <<'PY'
import json, os, sys

def load_state(text, label):
    # 実状態が読めないのに空扱いで進めると、導入済み全件の再インストール計画に
    # 化けてしまう。終了コード 0 でも中身が不正なら失敗として全体をスキップさせる。
    try:
        v = json.loads(text)
    except ValueError:
        sys.exit(f"{label} の出力を JSON として解釈できません")
    if not isinstance(v, list):
        sys.exit(f"{label} の出力が想定外の形式です（リストではありません）")
    return v

with open(sys.argv[1], encoding="utf-8") as f:
    settings = json.load(f)

known = {m.get("name") for m in load_state(os.environ["KNOWN_JSON"], "marketplace list") if isinstance(m, dict)}
installed = {p.get("id") for p in load_state(os.environ["INSTALLED_JSON"], "plugin list") if isinstance(p, dict)}

for name, mp in (settings.get("extraKnownMarketplaces") or {}).items():
    if name in known:
        continue
    src = (mp or {}).get("source") or {}
    ref = src.get("repo") or src.get("url") or src.get("path") if isinstance(src, dict) else None
    if ref:
        print(f"marketplace\t{name}\t{ref}")

for plugin, enabled in (settings.get("enabledPlugins") or {}).items():
    if enabled is True and plugin not in installed:
        print(f"plugin\t{plugin}\t")
PY
)"; then
  warn "警告: 実行計画の作成に失敗したため、自動インストールをスキップします（詳細は直前のエラー出力）。"
  exit 0
fi

[ -z "$plugin_plan" ] && exit 0

# --- 計画の適用（1 件の失敗で残りを止めない。原因診断用にエラー先頭行を添える） ---
while IFS=$'\t' read -r kind name ref; do
  [ -z "$kind" ] && continue
  case "$kind" in
    marketplace)
      if err="$(timeout 300 claude plugin marketplace add "$ref" 2>&1)"; then
        printf 'マーケットプレイス %s (%s) を追加しました。\n' "$name" "$ref"
      else
        warn "警告: マーケットプレイス $name ($ref) の追加に失敗しました。"
        warn "       $(printf '%s' "$err" | head -n 1)"
      fi
      ;;
    plugin)
      if err="$(timeout 300 claude plugin install "$name" 2>&1)"; then
        printf 'プラグイン %s をインストールしました（次回セッションから有効）。\n' "$name"
      else
        warn "警告: プラグイン $name のインストールに失敗しました。"
        warn "       $(printf '%s' "$err" | head -n 1)"
      fi
      ;;
  esac
done <<< "$plugin_plan"

exit 0
