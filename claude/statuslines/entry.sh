#!/bin/bash

# パス定数の定義
STATUSLINES_DIR=".claude/statuslines"

input=$(cat)

MODEL=$(echo "$input" | "$STATUSLINES_DIR/model.sh")
CONTEXT=$(echo "$input" | "$STATUSLINES_DIR/context.sh")
WORKSPACE=$(echo "$input" | "$STATUSLINES_DIR/workspace.sh")

echo "$MODEL | $CONTEXT"
echo "$WORKSPACE"

