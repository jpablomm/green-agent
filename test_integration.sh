#!/bin/bash
# Integration Test Script

set -e  # Exit on error

echo "======================================"
echo "Green Agent + OSWorld Integration Test"
echo "======================================"
echo

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: Fake Mode
echo -e "${YELLOW}Test 1: Fake Mode (Quick Sanity Check)${NC}"
echo "Starting fresh Green Agent with USE_FAKE_OSWORLD=1..."

# Kill existing Green Agent
pkill -f "green_agent.app" || true
sleep 2

# Start Green Agent in fake mode
export USE_FAKE_OSWORLD=1
uv run uvicorn green_agent.app:app --host 0.0.0.0 --port 8080 &
GREEN_PID=$!
echo "Green Agent started (PID: $GREEN_PID)"
sleep 5

# Trigger fake mode assessment
echo "Triggering fake mode assessment..."
cat > /tmp/test_fake.json << EOF
{"task_id":"ubuntu_001","white_agent_url":"http://localhost:8090"}
EOF

RESPONSE=$(curl -s -X POST http://localhost:8080/assessments/start \
  -H "Content-Type: application/json" \
  --data @/tmp/test_fake.json)

ASSESSMENT_ID=$(echo $RESPONSE | python3 -c "import sys, json; print(json.load(sys.stdin)['assessment_id'])")
echo "Assessment ID: $ASSESSMENT_ID"

# Wait for completion
echo "Waiting for assessment to complete..."
sleep 5

# Get results
RESULTS=$(curl -s http://localhost:8080/assessments/$ASSESSMENT_ID/results)
echo "Results: $RESULTS"

SUCCESS=$(echo $RESULTS | python3 -c "import sys, json; print(json.load(sys.stdin)['success'])")
STEPS=$(echo $RESULTS | python3 -c "import sys, json; print(json.load(sys.stdin)['steps'])")

if [ "$SUCCESS" = "1" ] && [ "$STEPS" = "10" ]; then
    echo -e "${GREEN}✓ Test 1 PASSED: Fake mode works correctly${NC}"
    echo "  - Success: $SUCCESS"
    echo "  - Steps: $STEPS"

    # Check artifacts
    if [ -d "runs/$ASSESSMENT_ID/frames" ]; then
        FRAME_COUNT=$(ls runs/$ASSESSMENT_ID/frames/*.png 2>/dev/null | wc -l)
        echo "  - Frames generated: $FRAME_COUNT"
    fi
else
    echo -e "${RED}✗ Test 1 FAILED${NC}"
    echo "Results: $RESULTS"
    kill $GREEN_PID
    exit 1
fi

echo
echo "======================================"
echo

# Test 2: Real OSWorld Mode
echo -e "${YELLOW}Test 2: Real OSWorld Mode (Full Integration)${NC}"
echo "Restarting Green Agent with USE_FAKE_OSWORLD=0..."

# Kill existing Green Agent
kill $GREEN_PID
sleep 2

# Start Green Agent in real mode
export USE_FAKE_OSWORLD=0
uv run uvicorn green_agent.app:app --host 0.0.0.0 --port 8080 &
GREEN_PID=$!
echo "Green Agent started (PID: $GREEN_PID)"
sleep 5

# Trigger real mode assessment
echo "Triggering real OSWorld assessment..."
cat > /tmp/test_real.json << EOF
{"task_id":"ubuntu_001","white_agent_url":"http://localhost:8090"}
EOF

RESPONSE=$(curl -s -X POST http://localhost:8080/assessments/start \
  -H "Content-Type: application/json" \
  --data @/tmp/test_real.json)

ASSESSMENT_ID=$(echo $RESPONSE | python3 -c "import sys, json; print(json.load(sys.stdin)['assessment_id'])")
echo "Assessment ID: $ASSESSMENT_ID"

# Wait for OSWorld to start and run
echo "Waiting for OSWorld assessment (this may take 2-5 minutes)..."
echo "Monitoring logs..."

# Monitor progress
for i in {1..60}; do
    sleep 5
    STATUS=$(curl -s http://localhost:8080/assessments/$ASSESSMENT_ID/status)
    CURRENT_STATUS=$(echo $STATUS | python3 -c "import sys, json; print(json.load(sys.stdin)['status'])" 2>/dev/null || echo "unknown")
    echo "[$i] Status: $CURRENT_STATUS"

    if [ "$CURRENT_STATUS" = "completed" ]; then
        echo "Assessment completed!"
        break
    fi
done

# Get final results
RESULTS=$(curl -s http://localhost:8080/assessments/$ASSESSMENT_ID/results)
echo
echo "Final Results:"
echo "$RESULTS" | python3 -m json.tool

# Check if it ran successfully (even if task failed)
FAILURE_REASON=$(echo $RESULTS | python3 -c "import sys, json; r=json.load(sys.stdin); print(r.get('failure_reason', 'none'))")
STEPS=$(echo $RESULTS | python3 -c "import sys, json; print(json.load(sys.stdin)['steps'])")

if [ "$FAILURE_REASON" = "none" ] || [ "$FAILURE_REASON" = "null" ] || [[ "$FAILURE_REASON" == *"task_failed"* ]]; then
    echo -e "${GREEN}✓ Test 2 PASSED: Real OSWorld integration works${NC}"
    echo "  - Assessment ran without errors"
    echo "  - Steps executed: $STEPS"

    # Check logs
    if [ -f "runs/$ASSESSMENT_ID/osworld/osworld.log" ]; then
        echo "  - OSWorld log created"
        tail -5 "runs/$ASSESSMENT_ID/osworld/osworld.log"
    fi
elif [[ "$FAILURE_REASON" == *"OSWorld dependencies not installed"* ]]; then
    echo -e "${YELLOW}⚠ Test 2 SKIPPED: Dependencies not fully installed${NC}"
    echo "  This is expected - run: pip install -r vendor/OSWorld/requirements.txt"
else
    echo -e "${RED}✗ Test 2 FAILED${NC}"
    echo "  Failure reason: $FAILURE_REASON"

    # Show logs if available
    if [ -f "runs/$ASSESSMENT_ID/osworld/osworld.log" ]; then
        echo
        echo "OSWorld log (last 20 lines):"
        tail -20 "runs/$ASSESSMENT_ID/osworld/osworld.log"
    fi
fi

# Cleanup
echo
echo "======================================"
echo "Cleaning up..."
kill $GREEN_PID 2>/dev/null || true
echo "Tests complete!"
