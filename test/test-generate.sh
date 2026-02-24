#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/../skill/scripts/venice-image.sh"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "=== venice-image.sh generate tests ==="
echo ""

# Test 1: Missing API key
echo "Test: Missing API key produces error"
unset VENICE_API_KEY 2>/dev/null || true
output="$(env -u VENICE_API_KEY HOME=/nonexistent bash "$SCRIPT" generate -p "test" -o /tmp/test.png 2>&1)" && fail "should exit non-zero" || {
  if echo "$output" | grep -qi "api key"; then
    pass "missing API key error"
  else
    fail "expected 'api key' in error, got: $output"
  fi
}

# Test 2: Missing required --prompt
echo "Test: Missing --prompt produces error"
output="$(VENICE_API_KEY=fake bash "$SCRIPT" generate -o /tmp/test.png 2>&1)" && fail "should exit non-zero" || {
  if echo "$output" | grep -qi "prompt"; then
    pass "missing prompt error"
  else
    fail "expected 'prompt' in error, got: $output"
  fi
}

# Test 3: Missing required --output
echo "Test: Missing --output produces error"
output="$(VENICE_API_KEY=fake bash "$SCRIPT" generate -p "test" 2>&1)" && fail "should exit non-zero" || {
  if echo "$output" | grep -qi "output"; then
    pass "missing output error"
  else
    fail "expected 'output' in error, got: $output"
  fi
}

# Test 4: Unsupported output format
echo "Test: Unsupported output format produces error"
output="$(VENICE_API_KEY=fake bash "$SCRIPT" generate -p "test" -o /tmp/test.bmp 2>&1)" && fail "should exit non-zero" || {
  if echo "$output" | grep -qi "unsupported\|format"; then
    pass "unsupported format error"
  else
    fail "expected format error, got: $output"
  fi
}

# Test 5: Unknown option
echo "Test: Unknown option produces error"
output="$(VENICE_API_KEY=fake bash "$SCRIPT" generate --bogus 2>&1)" && fail "should exit non-zero" || {
  if echo "$output" | grep -qi "unknown"; then
    pass "unknown option error"
  else
    fail "expected 'unknown' in error, got: $output"
  fi
}

# Test 6: Help flag
echo "Test: --help shows usage"
output="$(bash "$SCRIPT" generate --help 2>&1)" || true
if echo "$output" | grep -qi "usage"; then
  pass "help output"
else
  fail "expected usage info, got: $output"
fi

# Test 7: No command shows usage
echo "Test: No command shows usage"
output="$(bash "$SCRIPT" 2>&1)" || true
if echo "$output" | grep -qi "usage"; then
  pass "no-command usage"
else
  fail "expected usage info, got: $output"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
