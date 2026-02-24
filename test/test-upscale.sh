#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/../skill/scripts/venice-image.sh"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "=== venice-image.sh upscale tests ==="
echo ""

# Test 1: Missing API key (need a real input file so the file check passes)
echo "Test: Missing API key produces error"
unset VENICE_API_KEY 2>/dev/null || true
TEMP_INPUT="$(mktemp /tmp/venice-test-XXXXXX.png)"
trap 'rm -f "$TEMP_INPUT"' EXIT
echo "fake" > "$TEMP_INPUT"
output="$(env -u VENICE_API_KEY HOME=/nonexistent bash "$SCRIPT" upscale -i "$TEMP_INPUT" -o /tmp/out.png 2>&1)" && fail "should exit non-zero" || {
  if echo "$output" | grep -qi "api key"; then
    pass "missing API key error"
  else
    fail "expected 'api key' in error, got: $output"
  fi
}

# Test 2: Missing required --input
echo "Test: Missing --input produces error"
output="$(VENICE_API_KEY=fake bash "$SCRIPT" upscale -o /tmp/out.png 2>&1)" && fail "should exit non-zero" || {
  if echo "$output" | grep -qi "input"; then
    pass "missing input error"
  else
    fail "expected 'input' in error, got: $output"
  fi
}

# Test 3: Missing required --output
echo "Test: Missing --output produces error"
output="$(VENICE_API_KEY=fake bash "$SCRIPT" upscale -i /tmp/fake.png 2>&1)" && fail "should exit non-zero" || {
  if echo "$output" | grep -qi "output"; then
    pass "missing output error"
  else
    fail "expected 'output' in error, got: $output"
  fi
}

# Test 4: Input file not found
echo "Test: Non-existent input file produces error"
output="$(VENICE_API_KEY=fake bash "$SCRIPT" upscale -i /tmp/nonexistent-image-12345.png -o /tmp/out.png 2>&1)" && fail "should exit non-zero" || {
  if echo "$output" | grep -qi "not found"; then
    pass "input not found error"
  else
    fail "expected 'not found' in error, got: $output"
  fi
}

# Test 5: Unknown option
echo "Test: Unknown option produces error"
output="$(VENICE_API_KEY=fake bash "$SCRIPT" upscale --bogus 2>&1)" && fail "should exit non-zero" || {
  if echo "$output" | grep -qi "unknown"; then
    pass "unknown option error"
  else
    fail "expected 'unknown' in error, got: $output"
  fi
}

# Test 6: Help flag
echo "Test: --help shows usage"
output="$(bash "$SCRIPT" upscale --help 2>&1)" || true
if echo "$output" | grep -qi "usage"; then
  pass "help output"
else
  fail "expected usage info, got: $output"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
