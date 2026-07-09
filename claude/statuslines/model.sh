#!/bin/bash

input=$(cat)

model_id=$(echo "$input" | jq -r '.model.id')
model_name=$(echo "$input" | jq -r '.model.display_name')

if [[ "$model_id" == *-fable-* ]]; then
    symbol="💎"
elif [[ "$model_id" == *-opus-* ]]; then
    symbol="🏆"
elif [[ "$model_id" == *-sonnet-* ]]; then
    symbol="⭐️"
elif [[ "$model_id" == *-haiku-* ]]; then
    symbol="🍀"
fi

echo "$symbol $model_name"
