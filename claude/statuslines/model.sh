#!/bin/bash

input=$(cat)

model_id=$(echo "$input" | jq -r '.model.id')
if [[ "$model_id" == claude-fable-5* ]]; then
    MODEL_NAME="👑 Fable 5"
elif [[ "$model_id" == claude-opus-4-8* ]]; then
    MODEL_NAME="🏆 Opus 4.8"
elif [[ "$model_id" == claude-sonnet-4-6* ]]; then
    MODEL_NAME="⭐️ Sonnet 4.6"
else
    MODEL_NAME="Unknown Model"
fi

echo "$MODEL_NAME"
