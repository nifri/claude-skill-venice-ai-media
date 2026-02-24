#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/../skill/scripts/venice-image.sh"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "=== venice-image.sh multi-edit tests ==="
echo ""

# Test 1: Missing API key (need real input files so file checks pass)
echo "Test: Missing API key produces error"
unset VENICE_API_KEY 2>/dev/null || true
TEMP_INPUT="$(mktemp /tmp/venice-test-XXXXXX.png)"
trap 'rm -f "$TEMP_INPUT"' EXIT
echo "fake" > "$TEMP_INPUT"
output="$(env -u VENICE_API_KEY HOME=/nonexistent bash "$SCRIPT" multi-edit -p "test" -i "$TEMP_INPUT" -o /tmp/out.png 2>&1)" && fail "should exit non-zero" || {
  if echo "$output" | grep -qi "api key"; then
    pass "missing API key error"
  else
    fail "expected 'api key' in error, got: $output"
  fi
}

# Test 2: Missing required --prompt
echo "Test: Missing --prompt produces error"
output="$(VENICE_API_KEY=fake bash "$SCRIPT" multi-edit -i /tmp/fake.png -o /tmp/out.png 2>&1)" && fail "should exit non-zero" || {
  if echo "$output" | grep -qi "prompt"; then
    pass "missing prompt error"
  else
    fail "expected 'prompt' in error, got: $output"
  fi
}

# Test 3: Missing required --input
echo "Test: Missing --input produces error"
output="$(VENICE_API_KEY=fake bash "$SCRIPT" multi-edit -p "test" -o /tmp/out.png 2>&1)" && fail "should exit non-zero" || {
  if echo "$output" | grep -qi "input"; then
    pass "missing input error"
  else
    fail "expected 'input' in error, got: $output"
  fi
}

# Test 4: Missing required --output
echo "Test: Missing --output produces error"
output="$(VENICE_API_KEY=fake bash "$SCRIPT" multi-edit -p "test" -i /tmp/fake.png 2>&1)" && fail "should exit non-zero" || {
  if echo "$output" | grep -qi "output"; then
    pass "missing output error"
  else
    fail "expected 'output' in error, got: $output"
  fi
}

# Test 5: Input file not found
echo "Test: Non-existent input file produces error"
output="$(VENICE_API_KEY=fake bash "$SCRIPT" multi-edit -p "test" -i /tmp/nonexistent-image-12345.png -o /tmp/out.png 2>&1)" && fail "should exit non-zero" || {
  if echo "$output" | grep -qi "not found"; then
    pass "input not found error"
  else
    fail "expected 'not found' in error, got: $output"
  fi
}

# Test 6: Too many inputs (>3)
echo "Test: More than 3 inputs produces error"
TEMP2="$(mktemp /tmp/venice-test-XXXXXX.png)"
TEMP3="$(mktemp /tmp/venice-test-XXXXXX.png)"
TEMP4="$(mktemp /tmp/venice-test-XXXXXX.png)"
echo "fake" > "$TEMP2"
echo "fake" > "$TEMP3"
echo "fake" > "$TEMP4"
output="$(VENICE_API_KEY=fake bash "$SCRIPT" multi-edit -p "test" -i "$TEMP_INPUT" -i "$TEMP2" -i "$TEMP3" -i "$TEMP4" -o /tmp/out.png 2>&1)" && fail "should exit non-zero" || {
  if echo "$output" | grep -qi "max 3\|too many"; then
    pass "too many inputs error"
  else
    fail "expected max inputs error, got: $output"
  fi
}
rm -f "$TEMP2" "$TEMP3" "$TEMP4"

# Test 7: Help flag
echo "Test: --help shows usage"
output="$(bash "$SCRIPT" multi-edit --help 2>&1)" || true
if echo "$output" | grep -qi "usage"; then
  pass "help output"
else
  fail "expected usage info, got: $output"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
