# Venice AI Media Skill for Claude Code

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skill that adds image generation, editing, upscaling, and background removal to your terminal — powered by the [Venice.ai](https://venice.ai) API.

Ask Claude to "generate an image of a mountain lake at sunset" and it handles the rest: crafting the API call, saving the file, and showing you the result.

## Features

- **Text-to-image generation** with multiple models and style presets
- **Image editing** via natural language instructions
- **Upscaling** up to 4x with optional AI enhancement
- **Multi-image editing** with layered inputs and masks
- **Background removal** with transparent PNG output
- **Live model listing** with current pricing from Venice.ai

## What is a Claude Code skill?

A skill is a set of instructions and tools that extend what [Claude Code](https://docs.anthropic.com/en/docs/claude-code) can do. Once installed, Claude automatically invokes the skill when your request matches its triggers — no slash commands needed, just natural language.

## Built with Claude Code

This project was itself built using Claude Code. The `CLAUDE.md` and `PLAN.md` files in this repo document the agentic development process — they're a record of how an AI assistant and a human collaborated to build a working tool from scratch.

## Platform support

- Linux
- macOS
- Windows (via WSL)

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and working
- `bash`, `curl`, `jq`, `python3`

### Installing dependencies

**Debian / Ubuntu / WSL:**

```bash
sudo apt update && sudo apt install -y curl jq python3
```

**Fedora:**

```bash
sudo dnf install -y curl jq python3
```

**macOS (Homebrew):**

```bash
brew install curl jq python3
```

## Installation

```bash
git clone https://github.com/nifri/claude-skill-venice-ai-media.git
cd claude-skill-venice-ai-media
bash install.sh
```

This copies the skill to `~/.claude/skills/venice-image/`, where Claude Code picks it up automatically.

## API key setup

Get an API key from [Venice.ai](https://venice.ai/settings/api) and configure it using one of these methods:

```bash
# Option A: config file (persistent, recommended)
mkdir -p ~/.config/venice
echo "your-api-key-here" > ~/.config/venice/api_key

# Option B: environment variable (add to ~/.bashrc for persistence)
export VENICE_API_KEY="your-api-key-here"
```

## Usage

Launch Claude Code and use natural language. The skill triggers automatically on phrases like "generate an image", "edit an image", "upscale an image", "remove background", or "use Venice AI".

**Examples:**

- "Generate an image of a cozy coffee shop in the rain"
- "Edit this photo to add dramatic lighting"
- "Upscale /tmp/photo.png to 4x"
- "Remove the background from /tmp/portrait.png"
- "What image models are available?"

## Commands

| Command | Description |
|---------|-------------|
| `generate` | Generate images from text prompts |
| `edit` | Edit existing images with text instructions |
| `upscale` | Upscale images to higher resolution (1-4x) |
| `multi-edit` | Edit images using layered inputs and masks |
| `bg-remove` | Remove image backgrounds (transparent PNG) |
| `styles` | List available style presets |
| `models` | List available models with live pricing |

## Running tests

The test suite validates input handling and error paths. No API key is required.

```bash
bash test/test-generate.sh
bash test/test-edit.sh
bash test/test-upscale.sh
bash test/test-multi-edit.sh
bash test/test-bg-remove.sh
bash test/test-styles.sh
```

## License

[MIT](LICENSE)
