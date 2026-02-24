#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$HOME/.claude/skills/venice-image"

mkdir -p "$SKILL_DIR"
cp -r "$SCRIPT_DIR/skill/"* "$SKILL_DIR/"
chmod +x "$SKILL_DIR/scripts/venice-image.sh"

echo "Installed venice-image skill to $SKILL_DIR"
