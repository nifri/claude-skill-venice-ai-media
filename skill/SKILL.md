---
name: venice-image
description: >-
  This skill should be used when the user asks to "generate an image",
  "create an image", "make a picture", "edit an image", "modify an image",
  "upscale an image", "enhance an image", "remove background",
  "background removal", "multi-edit", "image styles", "style presets",
  "use Venice AI", "use nano banana", or mentions image generation or
  image editing. Provides image generation, editing, upscaling, and
  background removal via the Venice.ai API. Default model is Qwen Image
  (budget tier). Also supports premium models like nano-banana-pro.
version: 1.1.0
user-invocable: true
allowed-tools: [Bash, Read, Write]
---

# Venice.ai Image Generation & Editing

Generate and edit images using Venice.ai's API. This skill wraps the Venice.ai image endpoints in a single bash script with seven subcommands: `generate`, `edit`, `upscale`, `multi-edit`, `bg-remove`, `styles`, and `models`.

## Prerequisites

Set your Venice.ai API key using one of these methods:

1. **Environment variable** (preferred): Set `VENICE_API_KEY` in your shell profile or CLAUDE.md
2. **Key file**: Save your key to `~/.config/venice/api_key`

Get an API key at https://venice.ai/settings/api

## Script Location

The script is at: `~/.claude/skills/venice-image/scripts/venice-image.sh`

Use `bash` to invoke it. Always pass the full path or set it as a variable.

## Commands

### Generate an Image

Generate an image from a text prompt. The output format is inferred from the file extension.

```bash
bash ~/.claude/skills/venice-image/scripts/venice-image.sh generate \
  -p "a serene mountain lake at sunset" \
  -o /tmp/lake.png
```

With options:

```bash
bash ~/.claude/skills/venice-image/scripts/venice-image.sh generate \
  -p "professional headshot portrait, studio lighting" \
  -m nano-banana-pro \
  -a 3:4 \
  -n "cartoon, illustration, low quality" \
  --style "Photographic" \
  -o /tmp/portrait.jpg
```

Required flags:
- `-p, --prompt TEXT` — The text prompt describing the image
- `-o, --output FILE` — Output file path (.png, .jpg, or .webp)

Optional flags:
- `-m, --model MODEL` — Model ID (default: `qwen-image`, budget tier)
- `-s, --size WxH` — Image dimensions (e.g., `1024x1024`)
- `-a, --aspect-ratio RATIO` — Aspect ratio (e.g., `16:9`, `1:1`, `3:4`)
- `-n, --negative TEXT` — Negative prompt (things to exclude)
- `--style STYLE` — Style preset (run `styles` for available list)
- `--seed INT` — Random seed for reproducibility
- `--steps INT` — Number of inference steps
- `--cfg-scale FLOAT` — CFG scale value
- `--watermark` — Add Venice watermark (off by default)
- `--unsafe` — Allow NSFW content generation

### Edit an Image

Edit an existing image using a text prompt. The input image is automatically base64-encoded.

```bash
bash ~/.claude/skills/venice-image/scripts/venice-image.sh edit \
  -i /tmp/lake.png \
  -p "add a wooden dock extending into the lake" \
  -o /tmp/lake-with-dock.png
```

With a premium model:

```bash
bash ~/.claude/skills/venice-image/scripts/venice-image.sh edit \
  -i /tmp/photo.png \
  -p "remove the background and replace with a studio backdrop" \
  -m nano-banana-pro-edit \
  -o /tmp/photo-studio.png
```

Required flags:
- `-p, --prompt TEXT` — Text prompt describing the edit
- `-i, --input FILE` — Source image file to edit
- `-o, --output FILE` — Output file path

Optional flags:
- `-m, --model MODEL` — Edit model ID (default: `qwen-edit`)
- `-a, --aspect-ratio RATIO` — Aspect ratio for the output

### Upscale an Image

Upscale an image by 1-4x with optional AI enhancement.

```bash
bash ~/.claude/skills/venice-image/scripts/venice-image.sh upscale \
  -i /tmp/photo.png \
  -o /tmp/photo-2x.png
```

With enhancement:

```bash
bash ~/.claude/skills/venice-image/scripts/venice-image.sh upscale \
  -i /tmp/photo.png \
  -s 4 \
  --enhance \
  --enhance-prompt "sharp details, high resolution" \
  -o /tmp/photo-4x.png
```

Required flags:
- `-i, --input FILE` — Input image file to upscale
- `-o, --output FILE` — Output file path

Optional flags:
- `-s, --scale NUM` — Scale factor 1-4 (default: 2)
- `--enhance` — Enable AI enhancement
- `--enhance-prompt TEXT` — Style descriptor for enhancement (max 1500 chars)
- `--enhance-creativity N` — Creativity level 0-1 (default: 0.5)
- `--replication N` — Detail preservation 0-1 (default: 0.35)

### Multi-Edit an Image

Edit an image using up to 3 layered inputs. The first image is the base; additional images serve as layers or masks.

```bash
bash ~/.claude/skills/venice-image/scripts/venice-image.sh multi-edit \
  -p "combine these images seamlessly" \
  -i base.png \
  -i overlay.png \
  -o /tmp/result.png
```

Required flags:
- `-p, --prompt TEXT` — Text prompt describing the edit
- `-i, --input FILE` — Input image (repeat up to 3 times; first is base)
- `-o, --output FILE` — Output file path

Optional flags:
- `-m, --model MODEL` — Model ID (default: `qwen-edit`)

### Remove Background

Remove the background from an image, producing a PNG with transparent background.

```bash
bash ~/.claude/skills/venice-image/scripts/venice-image.sh bg-remove \
  -i /tmp/photo.png \
  -o /tmp/photo-nobg.png
```

Required flags:
- `-i, --input FILE` — Input image file
- `-o, --output FILE` — Output file path (PNG with transparent background)

### List Style Presets

List available style presets for use with `generate --style`.

```bash
bash ~/.claude/skills/venice-image/scripts/venice-image.sh styles
```

### List Models

Display available image models with pricing information.

```bash
bash ~/.claude/skills/venice-image/scripts/venice-image.sh models
```

## Workflow Guidelines

### Image Generation Workflow

1. Choose the right model for the task (run `models` for current prices):
   - **Quick drafts / iteration**: Use `qwen-image` (default, budget tier) — fast and cheap
   - **Higher quality**: Use `flux-2-pro` or `recraft-v4` (mid tier)
   - **Best quality**: Use `nano-banana-pro` or `gpt-image-1-5` (premium tier)
2. Start with the default model for initial concepts, then upgrade to premium for finals
3. Use `--seed` to lock in a composition you like, then vary the prompt
4. Use negative prompts (`-n`) to remove unwanted elements
5. Use `--style` to apply a consistent visual style (run `styles` for the list)
6. Save to `/tmp/` for throwaway images; ask the user where to save important ones

### Image Editing Workflow

1. Always confirm the input file exists before calling edit
2. Save edited output to a new file (don't overwrite the input)
3. The edit endpoint returns raw PNG data regardless of output extension
4. For iterative edits, chain multiple edit calls with different prompts

### Upscale & Background Removal Workflow

1. Use `upscale` to increase resolution before printing or display at larger sizes
2. Use `--enhance` with `upscale` to add AI detail — useful for low-res source images
3. Use `bg-remove` to isolate subjects for compositing or product photography
4. Background removal outputs PNG with transparency — save as `.png`

### When the User Asks for an Image

1. Craft a detailed prompt — add style, lighting, composition, and quality descriptors
2. Pick the appropriate model based on quality needs and budget
3. Generate the image and show the user the output path
4. Offer to iterate: adjust the prompt, try a different model, or edit the result
5. Use the Read tool to display the image to the user after generation

### Choosing Output Format

- **PNG** — Best for illustrations, graphics, images with transparency
- **JPEG** — Best for photographs, smaller file sizes
- **WebP** — Good balance of quality and file size

## Error Handling

The script uses these exit codes:
- `0` — Success
- `1` — Usage error (missing or invalid arguments)
- `2` — API error (authentication failure, rate limit, server error)
- `3` — File I/O error (can't read input or write output)

The script automatically retries transient errors (HTTP 429 rate limit, 500 server error, 503 capacity) up to 3 times with exponential backoff. For 429 responses, the retry delay is derived from the `x-ratelimit-reset-requests` header when available. Retry status is printed to stderr.

Error messages are classified by HTTP status code to give actionable guidance (e.g., "Insufficient Venice balance — add funds at https://venice.ai/settings/billing" for 402, or "run `models` to see available models" for invalid model errors).

If generation fails:
- Check the API key is valid and has credits
- Try a simpler prompt if getting content policy errors
- Use `--unsafe` only if the user explicitly requests it
- Check the model ID is correct with the `models` subcommand

## Model Reference

See `~/.claude/skills/venice-image/references/models-and-pricing.md` for the complete model catalog with pricing tiers, all parameters, size options, and aspect ratio options.
