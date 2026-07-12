#!/bin/bash

input=$(cat)

GREEN='\x1b[32m'
RED='\x1b[31m'
YELLOW='\x1b[33m'
RESET='\x1b[0m'

DIR=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
[ -z "$DIR" ] && DIR="$PWD"

# $HOME 環境変数は statusLine の実行環境で未設定/不一致になりうるため、
# bash組み込みの ~ 展開(パスワードデータベース由来のホームディレクトリ解決)を使う。
# さらに macOS の APFS ファームリンク等でパス表現が食い違う場合に備え、物理パスで比較する。
HOME_REAL=$(cd ~ 2>/dev/null && pwd -P)
DIR_REAL=$(cd "$DIR" 2>/dev/null && pwd -P)
if [ -n "$HOME_REAL" ] && [ -n "$DIR_REAL" ] && [[ "$DIR_REAL" == "$HOME_REAL"* ]]; then
    DISPLAY_DIR="~${DIR_REAL#$HOME_REAL}"
elif [[ "$DIR" =~ ^/Users/[^/]+(/.*)?$ ]]; then
    # sandbox実行環境では statusLine スクリプトの $HOME がホスト(macOS)と食い違い、
    # 上の解決が失敗することがある。/Users/<誰か>/... という見た目のパスは
    # ほぼ確実に自分のホーム配下なので、決め打ちで ~ に丸める。
    DISPLAY_DIR="~${BASH_REMATCH[1]}"
else
    DISPLAY_DIR="$DIR"
fi

if git -C "$DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null)
    [ -z "$BRANCH" ] && BRANCH="$(git -C "$DIR" rev-parse --short HEAD 2>/dev/null)"

    DIRTY=""
    [ -n "$(git -C "$DIR" status --porcelain 2>/dev/null)" ] && DIRTY="${YELLOW}*${RESET}"

    # sbx の worktree (<repo>/.sbx/配下) で作業中かどうかを判定する
    WT_TAG=""
    [[ "$DIR" == *"/.sbx/"* ]] && WT_TAG="[wt] "

    # 未コミットの変更行数・ファイル数 (staged + unstaged の合計、ファイルは重複除去)
    NUMSTAT=$( { git -C "$DIR" diff --numstat 2>/dev/null; git -C "$DIR" diff --cached --numstat 2>/dev/null; } )
    ADDED=0
    DELETED=0
    declare -A SEEN_FILES
    while IFS=$'\t' read -r a d f; do
        [ -z "$f" ] && continue
        [[ "$a" =~ ^[0-9]+$ ]] && ADDED=$((ADDED + a))
        [[ "$d" =~ ^[0-9]+$ ]] && DELETED=$((DELETED + d))
        SEEN_FILES["$f"]=1
    done <<< "$NUMSTAT"
    FILE_COUNT=${#SEEN_FILES[@]}

    # リモートのデフォルトブランチを検出 (取得できなければ main にフォールバック)
    DEFAULT_BRANCH=$(git -C "$DIR" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    [ -z "$DEFAULT_BRANCH" ] && DEFAULT_BRANCH="main"

    AHEAD=0
    if [ "$BRANCH" != "$DEFAULT_BRANCH" ]; then
        AHEAD=$(git -C "$DIR" rev-list --count "origin/${DEFAULT_BRANCH}..HEAD" 2>/dev/null)
        [ -z "$AHEAD" ] && AHEAD=0
    fi

    AHEAD_TEXT=""
    (( AHEAD > 0 )) && AHEAD_TEXT=" (${AHEAD} commits ahead)"

    echo -e "⎇  ${WT_TAG}${BRANCH}${DIRTY} ${GREEN}+${ADDED}${RESET} ${RED}-${DELETED}${RESET} ${FILE_COUNT} files${AHEAD_TEXT} | 📁 ${DISPLAY_DIR}"
else
    echo "📁 ${DISPLAY_DIR}"
fi
