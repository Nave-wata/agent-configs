#!/bin/bash

input=$(cat)

# 色定義
GREEN='\x1b[32m'
YELLOW='\x1b[33m'
RED='\x1b[31m'
RESET='\x1b[0m'

CONTEXT_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size')
USAGE=$(echo "$input" | jq '.context_window.current_usage')

if [ "$USAGE" != "null" ] && [ "$CONTEXT_SIZE" != "null" ] && [ "$CONTEXT_SIZE" != "0" ]; then
    ORIGIN=$(echo "$USAGE" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
    CURRENT=$((ORIGIN + 40 * 1000))
    PERCENT=$((CURRENT * 100 / CONTEXT_SIZE))
    (( PERCENT > 100 )) && PERCENT=100
    (( PERCENT < 0 )) && PERCENT=0

    TOKENS_FMT=$(python3 -c '
current = '"$CURRENT"'
size = '"$CONTEXT_SIZE"'

def fmt_tokens(n):
    if n >= 1_000_000:
        v = n / 1_000_000
        s = f"{v:.0f}" if v == int(v) else f"{v:.1f}"
        return s + "M"
    if n >= 1_000:
        return f"{round(n / 1000)}K"
    return str(n)

print(f"{fmt_tokens(current)} / {fmt_tokens(size)}")
')

    # 色の選択(パーセント表示にのみ適用する)
    if (( PERCENT >= 90 )); then
        COLOR=$RED
    elif (( PERCENT >= 70 )); then
        COLOR=$YELLOW
    else
        COLOR=$GREEN
    fi

    echo -e "🪙 ${TOKENS_FMT} (${COLOR}${PERCENT}%${RESET})"
else
    echo -e "🪙 -- / -- (${GREEN}--%${RESET})"
fi
