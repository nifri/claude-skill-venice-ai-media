# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A Claude Code personal skill (`venice-image`) that provides image generation and editing via the Venice.ai API. The `skill/` directory is the source of truth; `install.sh` deploys it to `~/.claude/skills/venice-image/`.

## Commands

```bash
# Run tests (no API key needed — these are input-validation smoke tests)
bash test/test-generate.sh
bash test/test-edit.sh
bash test/test-upscale.sh
bash test/test-multi-edit.sh
bash test/test-bg-remove.sh
bash test/test-styles.sh

# Deploy updated skill to ~/.claude/skills/venice-image/
bash install.sh

# Quick smoke test with classified error output (expects 401)
VENICE_API_KEY=fake bash skill/scripts/venice-image.sh generate -p "test" -o /tmp/test.png

# Lint (if shellcheck is installed)
shellcheck skill/scripts/venice-image.sh
```

## Architecture

**Single script** (`skill/scripts/venice-image.sh`) with seven subcommands: `generate`, `edit`, `upscale`, `multi-edit`, `bg-remove`, `styles`, `models`.

### Layered function structure

1. **Error layer** — `die()`, `classify_error()`, `is_retryable()`: Maps HTTP status codes + Venice error keys to actionable messages. Exit codes: 0=success, 1=usage, 2=API, 3=file I/O.
2. **Request layer** — `venice_request()`: Central curl wrapper handling retries (max 3, exponential backoff), 429 rate-limit header parsing, 120s timeout, and binary vs JSON response modes. All API calls go through this. On non-retryable error, it calls `die 2` with a classified message — callers never handle HTTP errors directly.
3. **Command layer** — `cmd_generate()`, `cmd_edit()`, `cmd_upscale()`, `cmd_multi_edit()`, `cmd_bg_remove()`, `cmd_styles()`, `cmd_models()`: Parse flags, build payloads, call `venice_request()`, process responses.

### Key design decisions

- **jq for JSON payloads** in `cmd_generate()` — prevents prompt injection via `--arg` safe quoting.
- **Python3 for image payloads** in `cmd_edit()`, `cmd_upscale()`, `cmd_multi_edit()`, `cmd_bg_remove()` — base64-encoded images exceed shell command-line length limits, so a Python helper builds the JSON.
- **`venice_request --binary-output FILE`** — The edit endpoint returns raw PNG bytes (not JSON), so binary mode writes directly to file via curl `-o` and reads the file back for error classification on failure.
- **Live pricing** in `cmd_models()` — Fetches from three separate endpoints (`?type=image`, `?type=inpaint`, `?type=upscale`) rather than using static data.

### Skill registration

`skill/SKILL.md` frontmatter defines trigger keywords (e.g. "generate an image", "edit an image", "use Venice AI") and `allowed-tools: [Bash, Read, Write]`. Claude Code matches user intent to these triggers.

## Workflow

- Always write the plan to a `PLAN.md` file once a plan has been accepted. When the plan is updated, also update the file on disk. PLAN.md should retain all iteration history — append new phases, don't replace.
- Run both test scripts after any change to the main script.
- Run `install.sh` after changes to deploy the updated skill.

## API Notes

- Auth: `VENICE_API_KEY` env var or `~/.config/venice/api_key` file
- Base URL: `https://api.venice.ai/api/v1`
- The script uses Venice-native paths (`/image/generate`, `/image/edit`) not the OpenAI-compatible paths (`/images/generations`)
- Full API reference at `skill/references/venice-api-reference.md`
