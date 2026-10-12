#!/bin/bash
export OPENROUTER_API_KEY=$(grep OPENROUTER_API_KEY /opt/hermes-stack/.env | cut -d'=' -f2)
echo "OPENROUTER_API_KEY=$OPENROUTER_API_KEY"
cd /opt/hermes-stack/memu-memory
/root/.local/bin/memu-server start