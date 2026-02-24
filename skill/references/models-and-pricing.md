# Venice.ai Image Models & Pricing

> Run `venice-image.sh models` for current live pricing from the API.

## Generation Models

| Model ID | Tier | Description |
|----------|------|-------------|
| `venice-sd35` | Budget | Venice Stable Diffusion 3.5 |
| `hidream` | Budget | HiDream |
| `lustify-sdxl` | Budget | Lustify SDXL |
| `qwen-image` | Budget | Qwen Image (default generation model) |
| `anime-wai` | Budget | Anime (WAI) |
| `z-image-turbo` | Budget | Z-Image Turbo |
| `chroma` | Budget | Chroma |
| `flux-2-pro` | Mid | Flux 2 Pro |
| `recraft-v4` | Mid | Recraft V4 |
| `imagineart-1.5-pro` | Mid | ImagineArt 1.5 Pro |
| `nano-banana-pro` | Premium | Nano Banana Pro |
| `gpt-image-1-5` | Premium | GPT Image 1.5 |
| `recraft-v4-pro` | Premium | Recraft V4 Pro |

## Edit Models

| Model ID | Description |
|----------|-------------|
| `qwen-edit` | Qwen Edit (default edit model) |
| `flux-2-max-edit` | Flux 2 Max Edit |
| `gpt-image-1-5-edit` | GPT Image 1.5 Edit |
| `nano-banana-pro-edit` | Nano Banana Pro Edit |
| `seedream-v4-edit` | Seedream V4 Edit |

## Generation Parameters

| Parameter | Flag | Description | Default |
|-----------|------|-------------|---------|
| Prompt | `-p, --prompt` | Text description of the image to generate | (required) |
| Output | `-o, --output` | Output file path (.png, .jpg, .webp) | (required) |
| Model | `-m, --model` | Model ID from the tables above | `qwen-image` |
| Size | `-s, --size` | Image dimensions as WxH (e.g., `1024x1024`) | Model default |
| Aspect Ratio | `-a, --aspect-ratio` | Aspect ratio (e.g., `16:9`, `1:1`, `3:4`) | Model default |
| Negative Prompt | `-n, --negative` | Things to exclude from the image | None |
| Seed | `--seed` | Random seed for reproducibility | Random |
| Steps | `--steps` | Number of inference steps | Model default |
| CFG Scale | `--cfg-scale` | Classifier-free guidance scale | Model default |
| No Watermark | `--no-watermark` | Disable Venice watermark | Watermark on |
| Unsafe | `--unsafe` | Allow NSFW content generation | Safe mode on |

## Edit Parameters

| Parameter | Flag | Description | Default |
|-----------|------|-------------|---------|
| Prompt | `-p, --prompt` | Text description of the edit to make | (required) |
| Input | `-i, --input` | Source image file to edit | (required) |
| Output | `-o, --output` | Output file path | (required) |
| Model | `-m, --model` | Edit model ID | `qwen-edit` |
| Aspect Ratio | `-a, --aspect-ratio` | Aspect ratio for output | Same as input |

## Common Aspect Ratios

| Ratio | Use Case |
|-------|----------|
| `1:1` | Square, social media posts, avatars |
| `16:9` | Widescreen, desktop wallpapers, presentations |
| `9:16` | Vertical, mobile wallpapers, stories |
| `4:3` | Standard photos, web content |
| `3:4` | Portrait orientation |
| `3:2` | Classic photography ratio |
| `2:3` | Portrait photography |

## Common Sizes

| Size | Use Case |
|------|----------|
| `1024x1024` | Standard square |
| `1920x1080` | Full HD landscape |
| `1080x1920` | Full HD portrait |
| `1280x720` | HD landscape |
| `512x512` | Small square / thumbnails |
