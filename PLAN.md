# Venice.ai Image Generation Skill for Claude Code

## Context

Create a reusable Claude Code personal skill that provides image generation and editing via the Venice.ai API. This enables any Claude Code session on this machine to generate or edit images on demand. The skill will be available to both users (via `/venice-image`) and other agents/skills (via direct script invocation).

## File Structure

### Development repo (source of truth)
```
/home/user/claude-projects/skill-development/venice-ai-image-gen/
├── skill/                            # Mirrors install target
│   ├── SKILL.md
│   ├── scripts/
│   │   └── venice-image.sh
│   └── references/
│       ├── models-and-pricing.md
│       └── venice-api-reference.md
├── install.sh                        # Copies skill/ -> ~/.claude/skills/venice-image/
└── test/
    ├── test-generate.sh
    └── test-edit.sh
```

### Install target (personal skill)
```
~/.claude/skills/venice-image/
├── SKILL.md
├── scripts/
│   └── venice-image.sh
└── references/
    ├── models-and-pricing.md
    └── venice-api-reference.md
```

## Implementation Details

### `scripts/venice-image.sh`
Single bash script with three subcommands: `generate`, `edit`, `models`.
- Auth: `$VENICE_API_KEY` env var or `~/.config/venice/api_key` file
- JSON payloads built with `jq -n --arg` for injection safety
- Exit codes: 0=success, 1=usage, 2=API error, 3=file I/O

### `references/models-and-pricing.md`
Model catalog with tier labels (Budget, Mid, Premium). Dollar amounts removed — run `venice-image.sh models` for live pricing from the API.

### `SKILL.md`
Skill definition with frontmatter triggers, usage examples, workflow guidelines.

### `install.sh`
Copies `skill/` contents to `~/.claude/skills/venice-image/`.

### Smoke Tests
Verify error handling for missing keys, missing args, bad formats.

---

## Iteration History

### Phase 1: Initial skill (commit 733a57e)
- Created `venice-image.sh` with `generate`, `edit`, `models` subcommands
- `SKILL.md` with frontmatter triggers, usage examples, workflow guidelines
- `install.sh` to deploy to `~/.claude/skills/venice-image/`
- Smoke tests for missing keys, missing args, bad formats
- `models-and-pricing.md` reference with hardcoded pricing tiers

**Status: IMPLEMENTED**

### Phase 2: Live model pricing (commit eca4117)
- Replaced hardcoded model pricing in `models` subcommand with live API data
- Fetches from three endpoints: `?type=image`, `?type=inpaint`, `?type=upscale`
- Removed dollar amounts from `models-and-pricing.md` (run `models` for live pricing)

**Status: IMPLEMENTED**

### Phase 3: API reference (commit 7b5808f)
- Saved full Venice.ai API reference at `skill/references/venice-api-reference.md`

**Status: IMPLEMENTED**

### Phase 4: Retry logic and error classification

Added retry logic, error classification, and curl timeouts to `venice-image.sh`.

**Sources:** https://docs.venice.ai/api-reference/rate-limiting, https://docs.venice.ai/api-reference/error-codes

**Files modified:**
- `skill/scripts/venice-image.sh` — new functions + refactored call sites
- `skill/SKILL.md` — updated Error Handling section to document retry behavior

**Changes:**

#### 1. `classify_error()` function (after `die()`)
Maps HTTP status + Venice error key to actionable messages:
- **400** → parse error key (`INVALID_MODEL` → "run `models` to see available", `INVALID_IMAGE_FORMAT` → "use PNG, JPEG, or WebP", `CORRUPTED_IMAGE` → specific msg, default → "check your parameters")
- **401** → "check your VENICE_API_KEY is valid and active"
- **402** → "Insufficient Venice balance — add funds at https://venice.ai/settings/billing"
- **403** → "your API key does not have access"
- **404** → `MODEL_NOT_FOUND` → "run `models` to see available", default → "resource not found"
- **413** → "Venice limits images to 25MB"
- **415** → "check the image format"
- **429** → "Rate limit exceeded"
- **500/503** → "Venice server error (transient)"
- **000** → "Network error — check your internet connection"
- Extracts error key via `jq -r '.error.code // .error.type // ""'`

#### 2. `is_retryable()` function (after `classify_error()`)
Returns 0 (true) for 429, 500, 503, 000 (network error). Returns 1 (false) otherwise.

#### 3. `venice_request()` wrapper function (before `get_api_key()`)
Central curl wrapper with retry, timeout, and header capture.

**Interface:** `venice_request [--binary-output FILE] -- [curl_args...]`

- **JSON mode** (default): returns `body\nhttp_code` on stdout
- **Binary mode** (`--binary-output FILE`): writes to file via `-o`
- On non-retryable error: calls `die 2` with classified message
- On success: returns 0

**Retry logic:**
- Max 3 retries (4 attempts total)
- **429**: parse `x-ratelimit-reset-requests` header, fall back to exponential backoff, cap at 60s
- **500/503/000**: exponential backoff (2s, 4s, 8s)
- `--max-time 120` on all curl calls
- `--dump-header <tmpfile>` for rate-limit header capture
- Prints "Retrying in Ns..." to stderr

#### 4. Refactored call sites
- `cmd_generate()` — uses `venice_request`, removed manual error block
- `cmd_edit()` — uses `venice_request --binary-output`, removed manual error block
- `cmd_models()` — uses `venice_request` for all 3 model fetches, removed error checks

#### 5. Updated SKILL.md Error Handling section
Documented retry behavior and error classification.

**Status: IMPLEMENTED**

### Phase 5: Add all Venice image endpoints

Added 4 new subcommands (`styles`, `bg-remove`, `upscale`, `multi-edit`) and `--style` flag to `generate`, bringing coverage from 3 to 7 of Venice's image endpoints.

**Files modified:**
- `skill/scripts/venice-image.sh` — new commands, usage functions, main case statement, `--style` flag on generate
- `skill/SKILL.md` — updated frontmatter triggers, added command sections for all new commands, updated workflow guidelines
- `CLAUDE.md` — updated architecture section for seven subcommands, added test commands

**Files created:**
- `test/test-upscale.sh` (6 tests)
- `test/test-multi-edit.sh` (7 tests)
- `test/test-bg-remove.sh` (5 tests)
- `test/test-styles.sh` (3 tests)

**New commands:**

#### 1. `styles` — GET /image/styles
Lists available style presets. Simplest command — single GET, JSON response displayed in columns.

#### 2. `generate --style` enhancement
New `--style STYLE` flag adds `style_preset` to the generate payload. Run `styles` to see available presets.

#### 3. `bg-remove` — POST /image/background-remove
Removes background from an image. Python3 payload builder (base64 data URI), binary response via `--binary-output`.

#### 4. `upscale` — POST /image/upscale
Upscales image 1-4x with optional AI enhancement. Flags: `-s/--scale`, `--enhance`, `--enhance-prompt`, `--enhance-creativity`, `--replication`. Python3 payload builder, binary response.

#### 5. `multi-edit` — POST /image/multi-edit
Edits with up to 3 layered images. `-i` flag is repeated to collect images into a bash array. Python3 payload builder reads paths from stdin, encodes each as data URI. Binary response.

**Status: IMPLEMENTED**
