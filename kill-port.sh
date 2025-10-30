#!/bin/bash

# Kill process on specified port
# Usage: ./kill-port.sh [PORT]
# Example: ./kill-port.sh 4001

PORT=${1:-4001}

echo "🔍 Searching for processes on port $PORT..."

# Find process ID using the port
PID=$(lsof -ti:$PORT)

if [ -z "$PID" ]; then
    echo "✓ No process found running on port $PORT"
    exit 0
fi

echo "Found process(es): $PID"
echo "Killing process(es)..."

# Kill the process
kill -9 $PID

if [ $? -eq 0 ]; then
    echo "✓ Successfully killed process(es) on port $PORT"
else
    echo "✗ Failed to kill process. You may need sudo:"
    echo "  sudo ./kill-port.sh $PORT"
    exit 1
fi

# Verify it's dead
sleep 1
CHECK=$(lsof -ti:$PORT)
if [ -z "$CHECK" ]; then
    echo "✓ Port $PORT is now free"
else
    echo "⚠ Process may still be running. Try: sudo kill -9 $CHECK"
fi

