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

    # 点字1マスは8ドット。10マス x 8ドット = 80段階 (1.25%刻み) で使用率を表現する。
    BAR=$(python3 -c '
p = '"$PERCENT"'
cells = 10
# ドット点灯順: 左列を下から上、続けて右列を下から上 (U+2800 基準のビット値)。
order = (0x40, 0x04, 0x02, 0x01, 0x80, 0x20, 0x10, 0x08)
lit = round(p / 100 * cells * 8)
out = []
for i in range(cells):
    n = min(8, max(0, lit - 8 * i))
    bits = 0
    for k in range(n):
        bits |= order[k]
    out.append(chr(0x2800 + bits))
print("".join(out))
')

    # 色の選択
    if (( PERCENT >= 90 )); then
        COLOR=$RED
    elif (( PERCENT >= 70 )); then
        COLOR=$YELLOW
    else
        COLOR=$GREEN
    fi

    echo -e "🪙 ${COLOR}${BAR} ${PERCENT}%${RESET}"
else
    echo -e "🪙 ${GREEN}⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀ --%${RESET}"
fi
