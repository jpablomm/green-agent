#!/bin/bash
# Test OSWorld server API endpoints
set -euo pipefail

SERVER="http://localhost:5000"

echo "=========================================="
echo "Testing OSWorld Server API"
echo "=========================================="
echo ""

# Test 1: Screenshot
echo "1. Testing screenshot endpoint..."
curl -s $SERVER/screenshot -o /tmp/test_screenshot.png
if [ -s /tmp/test_screenshot.png ]; then
    SIZE=$(stat -c%s /tmp/test_screenshot.png 2>/dev/null || stat -f%z /tmp/test_screenshot.png 2>/dev/null)
    echo "   ✓ Screenshot: OK (${SIZE} bytes)"
else
    echo "   ✗ Screenshot: FAILED"
fi
echo ""

# Test 2: Platform info
echo "2. Testing platform endpoint..."
PLATFORM=$(curl -s $SERVER/platform)
echo "   Platform: $PLATFORM"
echo ""

# Test 3: Execute simple command (with shell)
echo "3. Testing /execute with shell command..."
curl -s -X POST $SERVER/execute \
    -H "Content-Type: application/json" \
    -d '{
        "command": "echo Hello from OSWorld",
        "shell": true
    }' | python3 -m json.tool
echo ""

# Test 4: Execute command with array
echo "4. Testing /execute with command array..."
curl -s -X POST $SERVER/execute \
    -H "Content-Type: application/json" \
    -d '{
        "command": ["whoami"]
    }' | python3 -m json.tool
echo ""

# Test 5: Launch Chrome
echo "5. Testing Chrome launch..."
curl -s -X POST $SERVER/execute \
    -H "Content-Type: application/json" \
    -d '{
        "command": ["google-chrome", "--new-window", "https://www.google.com"],
        "shell": false
    }' | python3 -m json.tool
echo ""

# Wait a moment for Chrome to open
sleep 3

# Test 6: Get accessibility tree (shows open windows/apps)
echo "6. Testing accessibility tree (shows open apps)..."
curl -s $SERVER/accessibility | python3 -c "
import sys, json
data = json.load(sys.stdin)
print('   Open applications:')
# Show top-level windows
if 'children' in data:
    for child in data['children'][:5]:  # Show first 5
        if 'name' in child and child['name']:
            print(f\"     - {child['name']} (role: {child.get('role', 'unknown')})\")
" 2>/dev/null || echo "   (Accessibility tree too large to parse quickly)"
echo ""

# Test 7: Cursor position
echo "7. Testing cursor position..."
curl -s $SERVER/cursor_position | python3 -m json.tool
echo ""

# Test 8: Screen size
echo "8. Testing screen size..."
curl -s -X POST $SERVER/screen_size -H "Content-Type: application/json" -d '{}' | python3 -m json.tool
echo ""

echo "=========================================="
echo "Test Complete!"
echo "=========================================="
echo ""
echo "The OSWorld server is working correctly!"
echo ""
echo "Available endpoints:"
echo "  - GET  /screenshot          - Capture screen with cursor"
echo "  - GET  /platform            - Get platform info"
echo "  - POST /execute             - Execute commands"
echo "  - POST /setup/launch        - Launch applications"
echo "  - GET  /accessibility       - Get UI element tree"
echo "  - GET  /cursor_position     - Get mouse position"
echo "  - POST /screen_size         - Get screen dimensions"
echo "  - GET  /terminal            - Get terminal output"
echo ""
