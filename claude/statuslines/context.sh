#!/bin/bash

input=$(cat)

format_token_count() {
  local tokens=$1
  if (( tokens >= 1000000 )); then
    printf "%.1fM\n" "$(echo "scale=1; $tokens / 1000000" | bc)"
  elif (( tokens >= 1000 )); then
    printf "%.1fK\n" "$(echo "scale=1; $tokens / 1000" | bc)"
  else
    echo "$tokens"
  fi
}

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
    TOKEN=$(format_token_count "$CURRENT")
    PERCENT=$((CURRENT * 100 / CONTEXT_SIZE))
    
    # 色の選択
    if (( PERCENT >= 90 )); then
        COLOR=$RED
    elif (( PERCENT >= 70 )); then
        COLOR=$YELLOW
    else
        COLOR=$GREEN
    fi
    
    echo -e "🪙 ${TOKEN} token / ${COLOR}${PERCENT}%${RESET}"
else
    echo "🪙 --- token / --%"
fi

