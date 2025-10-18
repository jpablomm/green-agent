#!/bin/bash
# Simple OSWorld API test - more robust error handling

SERVER="http://localhost:5000"

echo "=========================================="
echo "Testing OSWorld Server API"
echo "=========================================="
echo ""

# Test 1: Screenshot
echo "1. Testing screenshot endpoint..."
if curl -s -f $SERVER/screenshot -o /tmp/test_screenshot.png 2>/dev/null; then
    if [ -s /tmp/test_screenshot.png ]; then
        echo "   ✓ Screenshot: OK"
        ls -lh /tmp/test_screenshot.png
    else
        echo "   ✗ Screenshot: Empty file"
    fi
else
    echo "   ✗ Screenshot: FAILED"
    echo "   Server may not be running. Check: sudo systemctl status osworld-server"
    exit 1
fi
echo ""

# Test 2: Platform
echo "2. Testing platform endpoint..."
PLATFORM=$(curl -s $SERVER/platform 2>/dev/null)
if [ -n "$PLATFORM" ]; then
    echo "   ✓ Platform: $PLATFORM"
else
    echo "   ✗ Platform: FAILED"
    exit 1
fi
echo ""

# Test 3: Simple command
echo "3. Testing execute endpoint (whoami)..."
RESULT=$(curl -s -X POST $SERVER/execute \
    -H "Content-Type: application/json" \
    -d '{"command": ["whoami"]}' 2>/dev/null)
echo "   Response: $RESULT"
echo ""

# Test 4: Shell command
echo "4. Testing execute with shell..."
RESULT=$(curl -s -X POST $SERVER/execute \
    -H "Content-Type: application/json" \
    -d '{"command": "echo Hello OSWorld", "shell": true}' 2>/dev/null)
echo "   Response: $RESULT"
echo ""

# Test 5: Cursor position
echo "5. Testing cursor position..."
RESULT=$(curl -s $SERVER/cursor_position 2>/dev/null)
echo "   Response: $RESULT"
echo ""

echo "=========================================="
echo "Basic tests complete!"
echo "=========================================="
echo ""
echo "To test Chrome launch manually:"
echo "  curl -X POST http://localhost:5000/execute -H 'Content-Type: application/json' -d '{\"command\": [\"google-chrome\", \"--version\"]}'"
echo ""
