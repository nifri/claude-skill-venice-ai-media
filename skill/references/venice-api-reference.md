# Venice.ai API Reference Notes

Base URL: `https://api.venice.ai/api/v1`
Auth: `Authorization: Bearer <VENICE_API_KEY>`
Docs: https://docs.venice.ai
Swagger: https://docs.venice.ai/swagger.yaml

## Endpoints Overview

### Image
| Method | Path | Description |
|--------|------|-------------|
| POST | `/images/generations` | Generate image from prompt (Venice-native, all params) |
| POST | `/images/generations-simple` | OpenAI-compatible image generation (limited params) |
| POST | `/images/edits` | Edit single image with prompt |
| POST | `/images/edits-multi` | Composite/edit up to 3 layered images |
| POST | `/images/upscale` | Upscale (2x-4x) and/or enhance images |
| POST | `/images/remove-background` | Remove image background |

Note: The skill uses `/image/...` (singular) paths. The swagger docs show `/images/...` (plural) paths. Both work — they are equivalent.

### Chat
| Method | Path | Description |
|--------|------|-------------|
| POST | `/chat/completions` | Chat completions (OpenAI-compatible, multimodal) |
| POST | `/responses` | Alternative completion with reasoning/tools support |

### Audio
| Method | Path | Description |
|--------|------|-------------|
| POST | `/audio/speech` | Text-to-speech (TTS) |
| POST | `/audio/transcriptions` | Speech-to-text (STT) |

### Video (async queue-based)
| Method | Path | Description |
|--------|------|-------------|
| POST | `/videos/generations` | Queue video generation |
| POST | `/videos/generations/quote` | Get price quote before generating |
| GET | `/videos/generations/{queue_id}` | Poll for status/result |
| POST | `/videos/generations/complete` | Finalize completed video |

### Models
| Method | Path | Description |
|--------|------|-------------|
| GET | `/models` | List models (filter with `?type=image|inpaint|upscale|text|code|audio|video|embedding`) |
| GET | `/models/{model_id}` | Get single model details |

### Other
| Method | Path | Description |
|--------|------|-------------|
| POST | `/embeddings` | Generate text embeddings |
| GET | `/characters` | List Venice characters |
| GET | `/characters/{character_id}` | Get character details |
| GET | `/api_keys` | List API keys |

---

## Image Generation — POST /images/generations

### Required
- `model` (string) — model ID
- `prompt` (string, 1-7500 chars)

### Optional
| Param | Type | Default | Notes |
|-------|------|---------|-------|
| `width` | int | 1024 | max 1280 |
| `height` | int | 1024 | max 1280 |
| `aspect_ratio` | string | — | e.g. "16:9", "1:1" (for compatible models like nano-banana) |
| `resolution` | string | — | "1K", "2K", "4K" (for compatible models; affects pricing) |
| `format` | string | "webp" | jpeg, png, webp |
| `negative_prompt` | string | — | max 7500 chars |
| `cfg_scale` | number | — | 0-20, controls prompt adherence |
| `steps` | int | 8 | inference steps (model-dependent) |
| `seed` | int | 0 | -999999999 to 999999999 |
| `variants` | int | — | 1-4, number of images (incompatible with return_binary) |
| `style_preset` | string | — | e.g. "3D Model" |
| `safe_mode` | bool | true | blurs adult content |
| `hide_watermark` | bool | false | remove Venice watermark |
| `return_binary` | bool | false | raw binary instead of base64 JSON |
| `embed_exif_metadata` | bool | false | embeds gen metadata in EXIF |
| `lora_strength` | int | — | 0-100, LoRA intensity |
| `enable_web_search` | bool | false | uses web data, extra credits |

### Response (JSON, 200)
```json
{
  "id": "generate-image-...",
  "images": ["<base64>", ...],
  "request": {},
  "timing": { "inferenceDuration", "inferencePreprocessingTime", "inferenceQueueTime", "total" }
}
```
With `return_binary=true`: raw image bytes, Content-Type matches format.

### Response Headers
- `x-venice-is-blurred` — adult content was blurred
- `x-venice-is-content-violation` — TOS violation flag
- `x-venice-model-deprecation-warning` / `x-venice-model-deprecation-date`

---

## Image Generation (OpenAI-compatible) — POST /images/generations-simple

Simpler interface for OpenAI compatibility.

| Param | Type | Default | Notes |
|-------|------|---------|-------|
| `prompt` | string | required | 1-1500 chars |
| `model` | string | "default" | model ID |
| `n` | int | 1 | only 1 supported |
| `size` | enum | "auto" | 256x256, 512x512, 1024x1024, 1536x1024, 1024x1536, 1792x1024, 1024x1792, auto |
| `response_format` | enum | "b64_json" | b64_json, url |
| `output_format` | enum | "png" | jpeg, png, webp |
| `quality` | enum | "auto" | auto, high, medium, low, hd, standard |
| `style` | enum | "natural" | vivid, natural |
| `moderation` | enum | "auto" | auto (safe), low |
| `background` | enum | "auto" | transparent, opaque, auto |

---

## Image Edit — POST /images/edits

### Content Types: application/json or multipart/form-data

### Required
- `image` (file/string/URL) — 65536-33177600 pixels, <25MB
- `prompt` (string, 1-32768 chars)

### Optional
- `modelId` (string, default "qwen-edit") — qwen-edit, flux-2-max-edit, gpt-image-1-5-edit, nano-banana-pro-edit, seedream-v4-edit
- `aspect_ratio` (string) — auto, 1:1, 3:2, 16:9, 21:9, 9:16, 2:3, 3:4, 4:5

### Response: binary PNG with headers

---

## Multi-Image Edit — POST /images/edits-multi

### Required
- `prompt` (string, 1-32768 chars)
- `images` (array, 1-3 items) — first is base, others are layers. Base64 or URL.

### Optional
- `modelId` (string, default "qwen-edit")

### Response: image (base64 or URL)

---

## Image Upscale — POST /images/upscale

### Content Types: application/json or multipart/form-data

### Required
- `image` (file/string) — 65536 min pixels, 16777216 max after scaling, <25MB

### Optional
| Param | Type | Default | Notes |
|-------|------|---------|-------|
| `scale` | number | 2 | 1-4. scale=1 requires enhance=true |
| `enhance` | bool | false | enables enhancement |
| `enhancePrompt` | string | — | max 1500 chars, style descriptor ("gold", "marble") |
| `enhanceCreativity` | number | 0.5 | 0-1, higher = more creative variation |
| `replication` | number | 0.35 | 0-1, higher = preserves more detail |

### Response: binary PNG

---

## Background Removal — POST /images/remove-background

- `image` (file/string, optional) — file upload or base64, <25MB
- `image_url` (string URI, optional) — URL of image

Provide either `image` or `image_url`.

### Response: image with transparent background

---

## Text-to-Speech — POST /audio/speech

### Required
- `input` (string, 1-4096 chars)

### Optional
| Param | Type | Default | Notes |
|-------|------|---------|-------|
| `model` | string | "tts-kokoro" | only tts-kokoro available |
| `voice` | string | "af_sky" | 41 voices: af_alloy, af_bella, af_heart, af_jadore, af_jessica, af_kore, af_nicole, af_nova, af_river, af_sarah, af_sky, am_adam, am_echo, am_eric, am_fenrir, am_liam, am_michael, am_onyx, am_puck, am_santa, bf_alice, bf_emma, bf_lily, bm_daniel, bm_fable, bm_george, bm_lewis, zf_xiaobei, zf_xiaoni, zf_xiaoyi, zm_yunjian, zm_yunxi, zm_yunyang, ff_siwis, hf_alpha, hf_beta, if_sara, jf_alpha, jf_gongitsune, pf_dora, ef_dora |
| `response_format` | string | "mp3" | mp3, opus, aac, flac, wav, pcm |
| `speed` | number | 1.0 | 0.25-4.0 |
| `streaming` | bool | false | stream sentence-by-sentence |

### Response: audio binary in selected format

---

## Speech-to-Text — POST /audio/transcriptions

### Required
- `file` (binary) — WAV, WAVE, FLAC, M4A, AAC, MP4, MP3

### Optional
| Param | Type | Default | Notes |
|-------|------|---------|-------|
| `model` | enum | "nvidia/parakeet-tdt-0.6b-v3" | or "openai/whisper-large-v3" |
| `response_format` | enum | "json" | json, text |
| `timestamps` | bool | false | include timing data |
| `language` | string | — | ISO 639-1, model-dependent |

### Response: JSON transcript or plain text

---

## Video Generation (async)

### Step 1: Quote — POST /videos/generations/quote
| Param | Type | Required | Notes |
|-------|------|----------|-------|
| `model` | string | yes | |
| `duration` | enum | yes | "5s" or "10s" |
| `aspect_ratio` | string | no | |
| `resolution` | enum | no | 1080p, 720p (default), 480p |
| `audio` | bool | no | |

### Step 2: Queue — POST /videos/generations
| Param | Type | Required | Notes |
|-------|------|----------|-------|
| `model` | string | yes | |
| `prompt` | string | yes | 1-2500 chars |
| `duration` | enum | yes | "5s" or "10s" |
| `image_url` | string | yes | reference image (URL or data URL) for img2vid |
| `negative_prompt` | string | no | 0-2500 chars |
| `aspect_ratio` | string | no | |
| `resolution` | enum | no | 1080p, 720p (default), 480p |
| `audio` | bool | no | default true |
| `end_image_url` | string | no | end frame image |
| `audio_url` | string | no | background music (WAV/MP3, max 30s, 15MB) |
| `video_url` | string | no | reference video (MP4/MOV/WebM) |
| `reference_image_urls` | array | no | up to 4 reference images for consistency |

Response: `{ "model": "...", "queue_id": "..." }`

### Step 3: Poll — GET /videos/generations/{queue_id}
Returns status and result when complete.

### Step 4: Complete — POST /videos/generations/complete
| Param | Type | Required |
|-------|------|----------|
| `model` | string | yes |
| `queue_id` | string | yes |

---

## Chat Completions — POST /chat/completions

OpenAI-compatible. Venice-specific params in `venice_parameters`:
- `character_slug` — public Venice character
- `enable_web_search` — "off", "on", "auto"
- `enable_web_scraping` — bool, scrape URLs in messages
- `enable_web_citations` — bool, [REF] format citations
- `include_venice_system_prompt` — bool (default true)
- `strip_thinking_response` — bool, remove <think> blocks
- `disable_thinking` — bool
- `prompt_cache_key` — routing hint for cache

---

## Responses API — POST /responses

Alternative to chat completions with reasoning/tools.
- `model`, `input` (required)
- `max_output_tokens`, `temperature` (0-2), `top_p` (0-1)
- `reasoning` — { effort: low|medium|high, summary: auto|concise|detailed }
- `tools` — functions, web_search, code_interpreter, file_search
- `tool_choice` — auto, none, required, or specific function
- `stream` — bool

---

## Embeddings — POST /embeddings

- `input` (string or array, required) — max 8192 tokens
- `model` (string) — "text-embedding-bge-m3"
- `dimensions` (int, optional) — output vector dimensions
- `encoding_format` (enum) — "float" (default) or "base64"

---

## Models — GET /models

Query params: `type` (image, inpaint, upscale, text, code, audio, video, embedding)

Response includes per model: `id`, `model_spec.name`, `model_spec.traits`, `model_spec.pricing.*`

Pricing paths by type:
- image: `.model_spec.pricing.generation.usd` (or `.resolutions` for resolution-based)
- inpaint: `.model_spec.pricing.inpaint.usd`
- upscale: `.model_spec.pricing.upscale.{2x,4x}.usd`

---

## Rate Limits

| Type | Limit |
|------|-------|
| Image | 20 req/min |
| Audio | 60 req/min |
| Video queue | 40 req/min |
| Video retrieve | 120 req/min |
| Embedding | 500 req/min |
| Text (varies by size) | 20-500 req/min |

Abuse protection: >20 failed requests in 30s → 30s block.

Rate limit headers: `x-ratelimit-limit-requests`, `x-ratelimit-remaining-requests`, `x-ratelimit-reset-requests`, `x-ratelimit-limit-tokens`, `x-ratelimit-remaining-tokens`, `x-ratelimit-reset-tokens`

Account headers: `x-venice-balance-diem`, `x-venice-balance-usd`

---

## Error Codes

| Code | Key | Meaning |
|------|-----|---------|
| 400 | INVALID_REQUEST | Bad parameters |
| 400 | INVALID_MODEL | Bad model ID |
| 400 | INVALID_IMAGE_FORMAT | Bad image format |
| 400 | CORRUPTED_IMAGE | Unreadable image |
| 401 | AUTHENTICATION_FAILED | Auth failed |
| 401 | INVALID_API_KEY | Bad API key |
| 402 | — | Insufficient balance |
| 403 | UNAUTHORIZED | No access |
| 404 | MODEL_NOT_FOUND | Model doesn't exist |
| 404 | CHARACTER_NOT_FOUND | Character doesn't exist |
| 413 | INVALID_FILE_SIZE | File too large |
| 415 | INVALID_CONTENT_TYPE | Wrong content type |
| 429 | RATE_LIMIT_EXCEEDED | Rate limited |
| 500 | INFERENCE_FAILED | Processing error |
| 500 | UPSCALE_FAILED | Upscale error |
| 503 | — | Model at capacity |

---

## Current Skill Coverage

The venice-image skill (`skill/scripts/venice-image.sh`) currently implements:
- `generate` → POST /image/generate (with `style_preset` support)
- `edit` → POST /image/edit
- `upscale` → POST /image/upscale
- `multi-edit` → POST /image/multi-edit
- `bg-remove` → POST /image/background-remove
- `styles` → GET /image/styles
- `models` → GET /models?type={image,inpaint,upscale}

### Not yet implemented in the skill
- OpenAI-compatible generation (POST /images/generations-simple)
- Variants (multiple images per request)
- `format` param (currently hardcoded webp→convert flow)
- `resolution` param for nano-banana-pro pricing tiers
- `embed_exif_metadata`, `lora_strength`, `enable_web_search`
- Audio TTS/STT, Video, Chat, Embeddings (out of scope for image skill)
