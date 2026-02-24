#!/usr/bin/env bash
set -euo pipefail

# Venice.ai Image Generation & Editing CLI
# Usage: venice-image.sh <command> [options]
# Commands: generate, edit, upscale, multi-edit, bg-remove, styles, models

SCRIPT_NAME="$(basename "$0")"
API_BASE="https://api.venice.ai/api/v1"

# --- Utility functions ---

die() {
  local code="$1"; shift
  echo "Error: $*" >&2
  exit "$code"
}

classify_error() {
  local http_code="$1" body="$2"
  local error_key
  error_key="$(echo "$body" | jq -r '.error.code // .error.type // ""' 2>/dev/null || echo "")"

  case "$http_code" in
    400)
      case "$error_key" in
        INVALID_MODEL|INVALID_MODEL_ID) echo "Invalid model — run \`models\` to see available models" ;;
        INVALID_IMAGE_FORMAT) echo "Invalid image format — use PNG, JPEG, or WebP" ;;
        CORRUPTED_IMAGE) echo "The input image appears to be corrupted or unreadable" ;;
        *) echo "Bad request (HTTP 400) — check your parameters" ;;
      esac
      ;;
    401) echo "Authentication failed — check your VENICE_API_KEY is valid and active" ;;
    402) echo "Insufficient Venice balance — add funds at https://venice.ai/settings/billing" ;;
    403) echo "Access denied — your API key does not have access to this resource" ;;
    404)
      case "$error_key" in
        MODEL_NOT_FOUND) echo "Model not found — run \`models\` to see available models" ;;
        *) echo "Resource not found (HTTP 404)" ;;
      esac
      ;;
    413) echo "Image too large — Venice limits images to 25 MB" ;;
    415) echo "Unsupported media type — check the image format" ;;
    429) echo "Rate limit exceeded — request will be retried" ;;
    500|503) echo "Venice server error (transient, HTTP $http_code)" ;;
    000) echo "Network error — check your internet connection" ;;
    *)
      local api_msg
      api_msg="$(echo "$body" | jq -r '.error.message // .error // .message // .details._errors[0] // empty' 2>/dev/null || true)"
      if [[ -n "$api_msg" ]]; then
        echo "$api_msg"
      else
        echo "Request failed (HTTP $http_code)"
      fi
      ;;
  esac
}

is_retryable() {
  local http_code="$1"
  case "$http_code" in
    429|500|503|000) return 0 ;;
    *) return 1 ;;
  esac
}

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME <command> [options]

Commands:
  generate    Generate an image from a text prompt
  edit        Edit an existing image with a text prompt
  upscale     Upscale and optionally enhance an image
  multi-edit  Edit an image with up to 3 layered inputs
  bg-remove   Remove the background from an image
  styles      List available image style presets
  models      List available image models with pricing

Run '$SCRIPT_NAME <command> --help' for command-specific help.
EOF
  exit 1
}

usage_generate() {
  cat <<EOF
Usage: $SCRIPT_NAME generate [options]

Required:
  -p, --prompt TEXT        Text prompt for image generation
  -o, --output FILE        Output file path (.png, .jpg, .webp)

Optional:
  -m, --model MODEL        Model to use (default: qwen-image)
  -s, --size WxH           Image size (e.g., 1024x1024)
  -a, --aspect-ratio RATIO Aspect ratio (e.g., 16:9, 1:1)
  -n, --negative TEXT      Negative prompt
      --seed INT           Random seed for reproducibility
      --steps INT          Number of inference steps
      --cfg-scale FLOAT    CFG scale value
      --style STYLE        Style preset (run 'styles' for list)
      --watermark          Add Venice watermark (off by default)
      --unsafe             Allow NSFW content generation

Examples:
  $SCRIPT_NAME generate -p "a sunset over mountains" -o sunset.png
  $SCRIPT_NAME generate -p "portrait photo" -m nano-banana-pro -a 3:4 -o portrait.jpg
  $SCRIPT_NAME generate -p "a cat" --style "Anime" -o anime-cat.png
EOF
  exit 1
}

usage_edit() {
  cat <<EOF
Usage: $SCRIPT_NAME edit [options]

Required:
  -p, --prompt TEXT        Text prompt describing the edit
  -i, --input FILE         Input image file to edit
  -o, --output FILE        Output file path

Optional:
  -m, --model MODEL        Model to use (default: qwen-edit)
  -a, --aspect-ratio RATIO Aspect ratio (e.g., 16:9, 1:1)

Examples:
  $SCRIPT_NAME edit -i photo.png -p "make the sky purple" -o edited.png
  $SCRIPT_NAME edit -i logo.png -p "add a golden border" -m gpt-image-1-5-edit -o logo-v2.png
EOF
  exit 1
}

usage_upscale() {
  cat <<EOF
Usage: $SCRIPT_NAME upscale [options]

Required:
  -i, --input FILE           Input image file to upscale
  -o, --output FILE          Output file path

Optional:
  -s, --scale NUM            Scale factor 1-4 (default: 2)
      --enhance              Enable AI enhancement
      --enhance-prompt TEXT   Style descriptor for enhancement (max 1500 chars)
      --enhance-creativity N Creativity level 0-1 (default: 0.5)
      --replication N        Detail preservation 0-1 (default: 0.35)

Examples:
  $SCRIPT_NAME upscale -i photo.png -o photo-2x.png
  $SCRIPT_NAME upscale -i photo.png -s 4 --enhance --enhance-prompt "sharp details" -o photo-4x.png
EOF
  exit 1
}

usage_multi_edit() {
  cat <<EOF
Usage: $SCRIPT_NAME multi-edit [options]

Required:
  -p, --prompt TEXT          Text prompt describing the edit
  -i, --input FILE           Input image (repeat up to 3 times; first is base)
  -o, --output FILE          Output file path

Optional:
  -m, --model MODEL          Model to use (default: qwen-edit)

Examples:
  $SCRIPT_NAME multi-edit -p "combine these images" -i base.png -i layer.png -o result.png
  $SCRIPT_NAME multi-edit -p "blend with mask" -i photo.png -i overlay.png -i mask.png -o blended.png
EOF
  exit 1
}

usage_bg_remove() {
  cat <<EOF
Usage: $SCRIPT_NAME bg-remove [options]

Required:
  -i, --input FILE           Input image file
  -o, --output FILE          Output file path (PNG with transparent background)

Examples:
  $SCRIPT_NAME bg-remove -i photo.png -o photo-nobg.png
EOF
  exit 1
}

usage_styles() {
  cat <<EOF
Usage: $SCRIPT_NAME styles

List available image style presets for use with 'generate --style'.

No options required.
EOF
  exit 1
}

venice_request() {
  local binary_output=""
  local curl_args=()

  # Parse our arguments, everything after -- goes to curl
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --binary-output) binary_output="$2"; shift 2 ;;
      --) shift; break ;;
      *) die 1 "venice_request: unknown option '$1'" ;;
    esac
  done
  curl_args=("$@")

  local max_retries=3
  local attempt=0
  local header_file
  header_file="$(mktemp)"

  while true; do
    local http_code="" body="" curl_exit=0

    if [[ -n "$binary_output" ]]; then
      http_code="$(curl -s -w "%{http_code}" --max-time 120 \
        --dump-header "$header_file" \
        -o "$binary_output" \
        "${curl_args[@]}")" || curl_exit=$?
    else
      local raw_response=""
      raw_response="$(curl -s -w "\n%{http_code}" --max-time 120 \
        --dump-header "$header_file" \
        "${curl_args[@]}")" || curl_exit=$?
      http_code="$(echo "$raw_response" | tail -1)"
      body="$(echo "$raw_response" | sed '$d')"
    fi

    # Treat curl failure (DNS, timeout, etc.) as retryable network error
    if [[ "$curl_exit" -ne 0 ]]; then
      http_code="000"
      body=""
    fi

    # Success — return result
    if [[ "$http_code" == "200" ]]; then
      rm -f "$header_file"
      if [[ -z "$binary_output" ]]; then
        printf '%s\n%s' "$body" "$http_code"
      fi
      return 0
    fi

    # On error, read body from binary output file for error classification
    if [[ -n "$binary_output" && -f "$binary_output" ]]; then
      body="$(cat "$binary_output" 2>/dev/null || true)"
    fi

    # Check if retryable
    if is_retryable "$http_code" && [[ "$attempt" -lt "$max_retries" ]]; then
      attempt=$((attempt + 1))
      local wait_time=0

      if [[ "$http_code" == "429" ]]; then
        # Try to parse rate-limit reset header
        local reset_val
        reset_val="$(grep -i 'x-ratelimit-reset-requests' "$header_file" 2>/dev/null \
          | sed 's/^[^:]*: *//' | tr -d '\r' || true)"

        if [[ -n "$reset_val" ]]; then
          if [[ "$reset_val" -gt 1700000000 ]] 2>/dev/null; then
            # Unix timestamp — compute seconds until reset
            local now
            now="$(date +%s)"
            wait_time=$(( reset_val - now ))
            [[ "$wait_time" -lt 1 ]] && wait_time=1
          else
            # Seconds until reset
            wait_time="$reset_val"
          fi
        fi

        # Fall back to exponential backoff if header missing/unparseable
        if [[ "$wait_time" -le 0 ]]; then
          wait_time=$(( 2 ** attempt ))
        fi

        # Cap at 60 seconds
        [[ "$wait_time" -gt 60 ]] && wait_time=60
      else
        # 500/503/000 — exponential backoff
        wait_time=$(( 2 ** attempt ))
      fi

      echo "Retrying in ${wait_time}s (attempt ${attempt}/${max_retries}, HTTP ${http_code})..." >&2
      sleep "$wait_time"
      continue
    fi

    # Non-retryable or retries exhausted — clean up and die
    rm -f "$header_file"
    if [[ -n "$binary_output" ]]; then
      rm -f "$binary_output"
    fi
    local msg
    msg="$(classify_error "$http_code" "$body")"
    die 2 "$msg"
  done
}

get_api_key() {
  if [[ -n "${VENICE_API_KEY:-}" ]]; then
    echo "$VENICE_API_KEY"
    return
  fi

  local key_file="$HOME/.config/venice/api_key"
  if [[ -f "$key_file" ]]; then
    local key
    key="$(cat "$key_file")"
    if [[ -n "$key" ]]; then
      echo "$key"
      return
    fi
  fi

  die 1 "No API key found. Set VENICE_API_KEY env var or create ~/.config/venice/api_key"
}

detect_format() {
  local file="$1"
  local ext="${file##*.}"
  ext="${ext,,}" # lowercase
  case "$ext" in
    png)  echo "png" ;;
    jpg|jpeg) echo "jpeg" ;;
    webp) echo "webp" ;;
    *) die 1 "Unsupported output format '.$ext'. Use .png, .jpg, or .webp" ;;
  esac
}

mime_from_ext() {
  local file="$1"
  local ext="${file##*.}"
  ext="${ext,,}"
  case "$ext" in
    png)  echo "image/png" ;;
    jpg|jpeg) echo "image/jpeg" ;;
    webp) echo "image/webp" ;;
    gif)  echo "image/gif" ;;
    *) echo "application/octet-stream" ;;
  esac
}

# --- Commands ---

cmd_generate() {
  local prompt="" output="" model="qwen-image" size="" aspect_ratio=""
  local negative="" seed="" steps="" cfg_scale="" style_preset=""
  local watermark="false" safe_mode="true"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--prompt)    prompt="$2"; shift 2 ;;
      -o|--output)    output="$2"; shift 2 ;;
      -m|--model)     model="$2"; shift 2 ;;
      -s|--size)      size="$2"; shift 2 ;;
      -a|--aspect-ratio) aspect_ratio="$2"; shift 2 ;;
      -n|--negative)  negative="$2"; shift 2 ;;
      --seed)         seed="$2"; shift 2 ;;
      --steps)        steps="$2"; shift 2 ;;
      --cfg-scale)    cfg_scale="$2"; shift 2 ;;
      --style)        style_preset="$2"; shift 2 ;;
      --watermark)    watermark="true"; shift ;;
      --unsafe)       safe_mode="false"; shift ;;
      --help|-h)      usage_generate ;;
      *) die 1 "Unknown option: $1. Run '$SCRIPT_NAME generate --help' for usage." ;;
    esac
  done

  [[ -z "$prompt" ]] && die 1 "Missing required --prompt. Run '$SCRIPT_NAME generate --help' for usage."
  [[ -z "$output" ]] && die 1 "Missing required --output. Run '$SCRIPT_NAME generate --help' for usage."

  local format
  format="$(detect_format "$output")"

  local api_key
  api_key="$(get_api_key)"

  # Build JSON payload safely with jq
  # Uses Venice-native /image/generate endpoint (supports all params)
  local payload
  payload="$(jq -n \
    --arg model "$model" \
    --arg prompt "$prompt" \
    --argjson hide_watermark "$([ "$watermark" = "false" ] && echo true || echo false)" \
    --argjson safe_mode "$safe_mode" \
    --argjson return_binary false \
    '{
      model: $model,
      prompt: $prompt,
      hide_watermark: $hide_watermark,
      safe_mode: $safe_mode,
      return_binary: $return_binary
    }'
  )"

  # Add optional parameters
  if [[ -n "$size" ]]; then
    local width height
    width="${size%%x*}"
    height="${size##*x}"
    payload="$(echo "$payload" | jq --argjson w "$width" --argjson h "$height" '. + {width: $w, height: $h}')"
  fi

  if [[ -n "$aspect_ratio" ]]; then
    payload="$(echo "$payload" | jq --arg ar "$aspect_ratio" '.aspect_ratio = $ar')"
  fi

  if [[ -n "$negative" ]]; then
    payload="$(echo "$payload" | jq --arg neg "$negative" '.negative_prompt = $neg')"
  fi

  if [[ -n "$seed" ]]; then
    payload="$(echo "$payload" | jq --argjson s "$seed" '.seed = $s')"
  fi

  if [[ -n "$steps" ]]; then
    payload="$(echo "$payload" | jq --argjson s "$steps" '.steps = $s')"
  fi

  if [[ -n "$cfg_scale" ]]; then
    payload="$(echo "$payload" | jq --argjson c "$cfg_scale" '.cfg_scale = $c')"
  fi

  if [[ -n "$style_preset" ]]; then
    payload="$(echo "$payload" | jq --arg s "$style_preset" '.style_preset = $s')"
  fi

  echo "Generating image with model '$model'..." >&2

  # Write payload to temp file to handle large payloads
  local tmp_payload
  tmp_payload="$(mktemp)"
  trap 'rm -f "$tmp_payload"' RETURN
  echo "$payload" > "$tmp_payload"

  local response http_code body
  response="$(venice_request -- \
    -X POST "$API_BASE/image/generate" \
    -H "Authorization: Bearer $api_key" \
    -H "Content-Type: application/json" \
    -d @"$tmp_payload"
  )"

  http_code="$(echo "$response" | tail -1)"
  body="$(echo "$response" | sed '$d')"

  # Venice-native endpoint returns { images: ["<base64>"] }
  local b64_data
  b64_data="$(echo "$body" | jq -r '.images[0] // empty')"

  if [[ -z "$b64_data" ]]; then
    die 2 "No image data in API response. Response: $(echo "$body" | head -c 200)"
  fi

  # Ensure output directory exists
  local out_dir
  out_dir="$(dirname "$output")"
  if [[ ! -d "$out_dir" ]]; then
    mkdir -p "$out_dir" || die 3 "Cannot create output directory: $out_dir"
  fi

  # Decode base64 and convert format if needed
  # The API returns webp by default; convert to requested format
  if command -v convert &>/dev/null && [[ "$format" != "webp" ]]; then
    echo "$b64_data" | base64 -d | convert webp:- "${format}:$output" || die 3 "Failed to write output file: $output"
  else
    echo "$b64_data" | base64 -d > "$output" || die 3 "Failed to write output file: $output"
  fi

  local file_size
  file_size="$(stat -c%s "$output" 2>/dev/null || stat -f%z "$output" 2>/dev/null || echo "unknown")"
  echo "Image saved to $output ($file_size bytes)" >&2
}

cmd_edit() {
  local prompt="" input="" output="" model="qwen-edit" aspect_ratio=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--prompt)    prompt="$2"; shift 2 ;;
      -i|--input)     input="$2"; shift 2 ;;
      -o|--output)    output="$2"; shift 2 ;;
      -m|--model)     model="$2"; shift 2 ;;
      -a|--aspect-ratio) aspect_ratio="$2"; shift 2 ;;
      --help|-h)      usage_edit ;;
      *) die 1 "Unknown option: $1. Run '$SCRIPT_NAME edit --help' for usage." ;;
    esac
  done

  [[ -z "$prompt" ]] && die 1 "Missing required --prompt. Run '$SCRIPT_NAME edit --help' for usage."
  [[ -z "$input" ]]  && die 1 "Missing required --input. Run '$SCRIPT_NAME edit --help' for usage."
  [[ -z "$output" ]] && die 1 "Missing required --output. Run '$SCRIPT_NAME edit --help' for usage."
  [[ ! -f "$input" ]] && die 3 "Input file not found: $input"

  local api_key
  api_key="$(get_api_key)"

  # Build JSON payload with python3 to handle large base64 image data
  # (jq --arg has command-line length limits that base64 images exceed)
  local tmp_payload
  tmp_payload="$(mktemp)"
  trap 'rm -f "$tmp_payload"' RETURN

  local mime_type
  mime_type="$(mime_from_ext "$input")"

  python3 -c "
import json, base64, sys

with open(sys.argv[1], 'rb') as f:
    img_bytes = f.read()
b64 = base64.b64encode(img_bytes).decode('ascii')
data_uri = 'data:' + sys.argv[2] + ';base64,' + b64

payload = {
    'modelId': sys.argv[3],
    'prompt': sys.argv[4],
    'image': data_uri
}
if sys.argv[5]:
    payload['aspect_ratio'] = sys.argv[5]

with open(sys.argv[6], 'w') as f:
    json.dump(payload, f)
" "$input" "$mime_type" "$model" "$prompt" "$aspect_ratio" "$tmp_payload" \
    || die 3 "Failed to build request payload"

  echo "Editing image with model '$model'..." >&2

  # Ensure output directory exists
  local out_dir
  out_dir="$(dirname "$output")"
  if [[ ! -d "$out_dir" ]]; then
    mkdir -p "$out_dir" || die 3 "Cannot create output directory: $out_dir"
  fi

  # Edit endpoint returns raw binary PNG — write directly to output
  venice_request --binary-output "$output" -- \
    -X POST "$API_BASE/image/edit" \
    -H "Authorization: Bearer $api_key" \
    -H "Content-Type: application/json" \
    -d @"$tmp_payload"

  local file_size
  file_size="$(stat -c%s "$output" 2>/dev/null || stat -f%z "$output" 2>/dev/null || echo "unknown")"
  echo "Edited image saved to $output ($file_size bytes)" >&2
}

cmd_styles() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h) usage_styles ;;
      *) die 1 "Unknown option: $1. Run '$SCRIPT_NAME styles --help' for usage." ;;
    esac
  done

  local api_key
  api_key="$(get_api_key)"

  echo "Fetching style presets..." >&2

  local response http_code body
  response="$(venice_request -- \
    -X GET "$API_BASE/image/styles" \
    -H "Authorization: Bearer $api_key"
  )"

  http_code="$(echo "$response" | tail -1)"
  body="$(echo "$response" | sed '$d')"

  echo ""
  echo "Available Style Presets"
  echo "======================"
  echo ""
  echo "$body" | jq -r '.data[]' 2>/dev/null | column 2>/dev/null || \
    echo "$body" | jq -r '.data[]' 2>/dev/null || \
    echo "$body"
  echo ""
  echo "Use with: $SCRIPT_NAME generate --style \"STYLE NAME\" ..."
}

cmd_bg_remove() {
  local input="" output=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -i|--input)  input="$2"; shift 2 ;;
      -o|--output) output="$2"; shift 2 ;;
      --help|-h)   usage_bg_remove ;;
      *) die 1 "Unknown option: $1. Run '$SCRIPT_NAME bg-remove --help' for usage." ;;
    esac
  done

  [[ -z "$input" ]]  && die 1 "Missing required --input. Run '$SCRIPT_NAME bg-remove --help' for usage."
  [[ -z "$output" ]] && die 1 "Missing required --output. Run '$SCRIPT_NAME bg-remove --help' for usage."
  [[ ! -f "$input" ]] && die 3 "Input file not found: $input"

  local api_key
  api_key="$(get_api_key)"

  # Build JSON payload with python3 (base64 image data exceeds shell limits)
  local tmp_payload
  tmp_payload="$(mktemp)"
  trap 'rm -f "$tmp_payload"' RETURN

  local mime_type
  mime_type="$(mime_from_ext "$input")"

  python3 -c "
import json, base64, sys

with open(sys.argv[1], 'rb') as f:
    img_bytes = f.read()
b64 = base64.b64encode(img_bytes).decode('ascii')
data_uri = 'data:' + sys.argv[2] + ';base64,' + b64

payload = {'image': data_uri}

with open(sys.argv[3], 'w') as f:
    json.dump(payload, f)
" "$input" "$mime_type" "$tmp_payload" \
    || die 3 "Failed to build request payload"

  echo "Removing background..." >&2

  # Ensure output directory exists
  local out_dir
  out_dir="$(dirname "$output")"
  if [[ ! -d "$out_dir" ]]; then
    mkdir -p "$out_dir" || die 3 "Cannot create output directory: $out_dir"
  fi

  venice_request --binary-output "$output" -- \
    -X POST "$API_BASE/image/background-remove" \
    -H "Authorization: Bearer $api_key" \
    -H "Content-Type: application/json" \
    -d @"$tmp_payload"

  local file_size
  file_size="$(stat -c%s "$output" 2>/dev/null || stat -f%z "$output" 2>/dev/null || echo "unknown")"
  echo "Background-removed image saved to $output ($file_size bytes)" >&2
}

cmd_upscale() {
  local input="" output="" scale="2" enhance="false"
  local enhance_prompt="" enhance_creativity="" replication=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -i|--input)             input="$2"; shift 2 ;;
      -o|--output)            output="$2"; shift 2 ;;
      -s|--scale)             scale="$2"; shift 2 ;;
      --enhance)              enhance="true"; shift ;;
      --enhance-prompt)       enhance_prompt="$2"; shift 2 ;;
      --enhance-creativity)   enhance_creativity="$2"; shift 2 ;;
      --replication)          replication="$2"; shift 2 ;;
      --help|-h)              usage_upscale ;;
      *) die 1 "Unknown option: $1. Run '$SCRIPT_NAME upscale --help' for usage." ;;
    esac
  done

  [[ -z "$input" ]]  && die 1 "Missing required --input. Run '$SCRIPT_NAME upscale --help' for usage."
  [[ -z "$output" ]] && die 1 "Missing required --output. Run '$SCRIPT_NAME upscale --help' for usage."
  [[ ! -f "$input" ]] && die 3 "Input file not found: $input"

  local api_key
  api_key="$(get_api_key)"

  # Build JSON payload with python3 (base64 image data exceeds shell limits)
  local tmp_payload
  tmp_payload="$(mktemp)"
  trap 'rm -f "$tmp_payload"' RETURN

  local mime_type
  mime_type="$(mime_from_ext "$input")"

  python3 -c "
import json, base64, sys

with open(sys.argv[1], 'rb') as f:
    img_bytes = f.read()
b64 = base64.b64encode(img_bytes).decode('ascii')

payload = {
    'image': b64,
    'scale': float(sys.argv[3]),
    'enhance': sys.argv[4] == 'true'
}

if sys.argv[5]:
    payload['enhancePrompt'] = sys.argv[5]
if sys.argv[6]:
    payload['enhanceCreativity'] = float(sys.argv[6])
if sys.argv[7]:
    payload['replication'] = float(sys.argv[7])

with open(sys.argv[8], 'w') as f:
    json.dump(payload, f)
" "$input" "$mime_type" "$scale" "$enhance" "$enhance_prompt" "$enhance_creativity" "$replication" "$tmp_payload" \
    || die 3 "Failed to build request payload"

  echo "Upscaling image (${scale}x, enhance=${enhance})..." >&2

  # Ensure output directory exists
  local out_dir
  out_dir="$(dirname "$output")"
  if [[ ! -d "$out_dir" ]]; then
    mkdir -p "$out_dir" || die 3 "Cannot create output directory: $out_dir"
  fi

  venice_request --binary-output "$output" -- \
    -X POST "$API_BASE/image/upscale" \
    -H "Authorization: Bearer $api_key" \
    -H "Content-Type: application/json" \
    -d @"$tmp_payload"

  local file_size
  file_size="$(stat -c%s "$output" 2>/dev/null || stat -f%z "$output" 2>/dev/null || echo "unknown")"
  echo "Upscaled image saved to $output ($file_size bytes)" >&2
}

cmd_multi_edit() {
  local prompt="" output="" model="qwen-edit"
  local -a inputs=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p|--prompt) prompt="$2"; shift 2 ;;
      -i|--input)  inputs+=("$2"); shift 2 ;;
      -o|--output) output="$2"; shift 2 ;;
      -m|--model)  model="$2"; shift 2 ;;
      --help|-h)   usage_multi_edit ;;
      *) die 1 "Unknown option: $1. Run '$SCRIPT_NAME multi-edit --help' for usage." ;;
    esac
  done

  [[ -z "$prompt" ]]        && die 1 "Missing required --prompt. Run '$SCRIPT_NAME multi-edit --help' for usage."
  [[ ${#inputs[@]} -eq 0 ]] && die 1 "Missing required --input. Run '$SCRIPT_NAME multi-edit --help' for usage."
  [[ -z "$output" ]]        && die 1 "Missing required --output. Run '$SCRIPT_NAME multi-edit --help' for usage."
  [[ ${#inputs[@]} -gt 3 ]] && die 1 "Too many --input files (max 3). Run '$SCRIPT_NAME multi-edit --help' for usage."

  # Validate all input files exist
  for f in "${inputs[@]}"; do
    [[ ! -f "$f" ]] && die 3 "Input file not found: $f"
  done

  local api_key
  api_key="$(get_api_key)"

  # Build JSON payload with python3 — multiple base64 images
  local tmp_payload
  tmp_payload="$(mktemp)"
  trap 'rm -f "$tmp_payload"' RETURN

  printf '%s\n' "${inputs[@]}" | python3 -c "
import json, base64, sys, os

def mime_from_ext(path):
    ext = os.path.splitext(path)[1].lower()
    return {'.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
            '.webp': 'image/webp', '.gif': 'image/gif'}.get(ext, 'application/octet-stream')

paths = [line.strip() for line in sys.stdin if line.strip()]
images = []
for p in paths:
    with open(p, 'rb') as f:
        img_bytes = f.read()
    b64 = base64.b64encode(img_bytes).decode('ascii')
    data_uri = 'data:' + mime_from_ext(p) + ';base64,' + b64
    images.append(data_uri)

payload = {
    'modelId': sys.argv[1],
    'prompt': sys.argv[2],
    'images': images
}

with open(sys.argv[3], 'w') as f:
    json.dump(payload, f)
" "$model" "$prompt" "$tmp_payload" \
    || die 3 "Failed to build request payload"

  echo "Editing image with ${#inputs[@]} input(s), model '$model'..." >&2

  # Ensure output directory exists
  local out_dir
  out_dir="$(dirname "$output")"
  if [[ ! -d "$out_dir" ]]; then
    mkdir -p "$out_dir" || die 3 "Cannot create output directory: $out_dir"
  fi

  venice_request --binary-output "$output" -- \
    -X POST "$API_BASE/image/multi-edit" \
    -H "Authorization: Bearer $api_key" \
    -H "Content-Type: application/json" \
    -d @"$tmp_payload"

  local file_size
  file_size="$(stat -c%s "$output" 2>/dev/null || stat -f%z "$output" 2>/dev/null || echo "unknown")"
  echo "Multi-edited image saved to $output ($file_size bytes)" >&2
}

cmd_models() {
  local api_key
  api_key="$(get_api_key)"

  echo "Fetching available image models..." >&2

  # Fetch all three model type endpoints
  local img_response img_body
  img_response="$(venice_request -- \
    -X GET "$API_BASE/models?type=image" \
    -H "Authorization: Bearer $api_key"
  )"
  img_body="$(echo "$img_response" | sed '$d')"

  local edit_response edit_body
  edit_response="$(venice_request -- \
    -X GET "$API_BASE/models?type=inpaint" \
    -H "Authorization: Bearer $api_key"
  )"
  edit_body="$(echo "$edit_response" | sed '$d')"

  local upscale_response upscale_body
  upscale_response="$(venice_request -- \
    -X GET "$API_BASE/models?type=upscale" \
    -H "Authorization: Bearer $api_key"
  )"
  upscale_body="$(echo "$upscale_response" | sed '$d')"

  echo ""
  echo "Venice.ai Image Models (live pricing from API)"
  echo "==============================================="

  # --- Generation Models ---
  echo ""
  echo "Generation Models"
  echo "-----------------"
  echo ""

  echo "$img_body" | jq -r '
    .data
    | sort_by(.model_spec.pricing.generation.usd // 999)
    | .[]
    | .id as $id
    | .model_spec.name as $name
    | (.model_spec.traits // [] | join(", ")) as $traits
    | (
        if .model_spec.pricing.resolutions then
          (.model_spec.pricing.resolutions | [to_entries[].value.usd] | min) as $min
          | (.model_spec.pricing.resolutions | [to_entries[].value.usd] | max) as $max
          | if $min == $max then "$\($min)"
            else "$\($min)–$\($max)"
            end
        elif .model_spec.pricing.generation.usd then
          "$\(.model_spec.pricing.generation.usd)"
        else
          "—"
        end
      ) as $price
    | "\($id)\t\($price)\t\($name)\t\($traits)"
  ' | column -t -s $'\t' -N "MODEL,PRICE,NAME,TRAITS" 2>/dev/null \
    || echo "$img_body" | jq -r '
      .data | sort_by(.id) | .[]
      | "\(.id)\t$\(.model_spec.pricing.generation.usd // "?")\t\(.model_spec.name // "")"
    '

  # --- Edit Models ---
  echo ""
  echo "Edit Models"
  echo "-----------"
  echo ""

  echo "$edit_body" | jq -r '
    .data
    | sort_by(.model_spec.pricing.inpaint.usd // 999)
    | .[]
    | .id as $id
    | .model_spec.name as $name
    | (.model_spec.traits // [] | join(", ")) as $traits
    | "$\(.model_spec.pricing.inpaint.usd // "—")" as $price
    | "\($id)\t\($price)\t\($name)\t\($traits)"
  ' | column -t -s $'\t' -N "MODEL,PRICE,NAME,TRAITS" 2>/dev/null \
    || echo "$edit_body" | jq -r '
      .data | sort_by(.id) | .[]
      | "\(.id)\t$\(.model_spec.pricing.inpaint.usd // "?")\t\(.model_spec.name // "")"
    '

  # --- Upscale Models ---
  echo ""
  echo "Upscale Models"
  echo "--------------"
  echo ""

  echo "$upscale_body" | jq -r '
    .data
    | sort_by(.id)
    | .[]
    | .id as $id
    | .model_spec.name as $name
    | (.model_spec.traits // [] | join(", ")) as $traits
    | "$\(.model_spec.pricing.upscale."2x".usd // "—") (2x)" as $price2x
    | "$\(.model_spec.pricing.upscale."4x".usd // "—") (4x)" as $price4x
    | "\($id)\t\($price2x), \($price4x)\t\($name)\t\($traits)"
  ' | column -t -s $'\t' -N "MODEL,PRICE,NAME,TRAITS" 2>/dev/null \
    || echo "$upscale_body" | jq -r '
      .data | sort_by(.id) | .[]
      | "\(.id)\t\(.model_spec.name // "")"
    '

  echo ""
  echo "Defaults: generate → qwen-image | edit/multi-edit → qwen-edit"
}

# --- Main ---

[[ $# -lt 1 ]] && usage

command="$1"; shift

case "$command" in
  generate)   cmd_generate "$@" ;;
  edit)       cmd_edit "$@" ;;
  upscale)    cmd_upscale "$@" ;;
  multi-edit) cmd_multi_edit "$@" ;;
  bg-remove)  cmd_bg_remove "$@" ;;
  styles)     cmd_styles "$@" ;;
  models)     cmd_models "$@" ;;
  --help|-h) usage ;;
  *) die 1 "Unknown command: $command. Run '$SCRIPT_NAME --help' for usage." ;;
esac
