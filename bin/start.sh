#!/bin/bash
set -e

pkill -f sinatra_app.rb || true
pkill -f puma || true
pkill -f ngrok || true
sleep 1

echo "🔌 Starting ngrok..."
ngrok http 4567 &
NGROK_PID=$!

# Wait for ngrok to be ready
sleep 4

echo "🚀 Starting Sinatra on :4567..."
ruby sinatra_app.rb &
APP_PID=$!

# Wait for Sinatra to be ready
sleep 2

echo "🔗 Updating webhook..."
ruby app/update_webhook.rb

# Keep processes running
wait