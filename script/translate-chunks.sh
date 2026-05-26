#!/usr/bin/env bash
# Translate .l10n-work/to_translate.json by splitting it into chunks and
# invoking Claude Code CLI per chunk. Aggregates outputs into
# .l10n-work/translated.json.
#
# Required env:
#   CLAUDE_CODE_OAUTH_TOKEN  - OAuth token used by `claude` CLI.
#   GITHUB_WORKSPACE         - Workspace root (set automatically in Actions).
#
# Optional env:
#   CHUNK_SIZE                     - Keys per chunk (default: 40).
#   CLAUDE_CODE_MAX_OUTPUT_TOKENS  - Per-call output token cap (default: 32000).
#   CLAUDE_MODEL                   - Override Claude model id.
#   MAX_RETRIES                    - Claude CLI retry attempts per chunk (default: 3).
#   MAX_CHUNKS                     - Upper bound on chunk count (default: 150).

set -euo pipefail

CHUNK_SIZE="${CHUNK_SIZE:-40}"
work_dir="${GITHUB_WORKSPACE:-$PWD}/.l10n-work"
chunks_dir="$work_dir/chunks"
src="$work_dir/to_translate.json"

if ! command -v claude > /dev/null 2>&1; then
  echo "::error::claude CLI not found on PATH" >&2
  exit 1
fi
echo "claude version: $(claude --version 2>&1 || true)"

if [[ ! -f "$src" ]]; then
  echo "Source worklist not found: $src" >&2
  exit 1
fi

mkdir -p "$chunks_dir"
rm -f "$chunks_dir"/in-*.json "$chunks_dir"/out-*.json

total=$(jq 'length' "$src")
if [[ "$total" == "0" ]]; then
  echo '{}' > "$work_dir/translated.json"
  echo "No keys to translate; wrote empty translated.json"
  exit 0
fi

# Split worklist into chunk files (in-NNN.json), each holding up to CHUNK_SIZE
# entries from the source object.
idx=0
for ((start=0; start<total; start+=CHUNK_SIZE)); do
  end=$((start + CHUNK_SIZE))
  out_path=$(printf "%s/in-%03d.json" "$chunks_dir" "$idx")
  jq --argjson s "$start" --argjson e "$end" '
    to_entries | .[$s:$e] | from_entries
  ' "$src" > "$out_path"
  idx=$((idx + 1))
done

chunk_count="$idx"
echo "Created $chunk_count chunks (chunk_size=$CHUNK_SIZE, total_keys=$total)"

# 150 chunks × 40 keys/chunk = 6,000 keys; covers the largest known n8n locale files.
MAX_CHUNKS="${MAX_CHUNKS:-150}"
if [[ "$chunk_count" -gt "$MAX_CHUNKS" ]]; then
  echo "::error::chunk_count ($chunk_count) exceeds MAX_CHUNKS ($MAX_CHUNKS). Reduce CHUNK_SIZE or raise MAX_CHUNKS." >&2
  exit 1
fi

claude_args=(
  --print
  --permission-mode acceptEdits
  --allowedTools "Read,Write,Edit"
  --max-turns 10
)
if [[ -n "${CLAUDE_MODEL:-}" ]]; then
  claude_args+=(--model "$CLAUDE_MODEL")
fi

translate_log="$work_dir/translate.log"
: > "$translate_log"

mapfile -t chunk_files < <(compgen -G "$chunks_dir/in-*.json" 2>/dev/null | sort || true)
if [[ "${#chunk_files[@]}" -eq 0 ]]; then
  echo "::error::No chunk input files found in $chunks_dir" >&2
  exit 1
fi

current=0
for in_file in "${chunk_files[@]}"; do
  current=$((current + 1))
  chunk_name="$(basename "$in_file")"
  out_file="${chunks_dir}/out-${chunk_name#in-}"
  echo "::group::Translating chunk $current / $chunk_count ($in_file)"

  prompt=$(cat <<PROMPT
n8n の UI 文言を英語から日本語へ翻訳するタスク。
入力ファイル: $in_file
出力ファイル: $out_file

手順:
1. $in_file を読む（JSON オブジェクト。各エントリは "不透明なキー": "英語原文"）。
2. 各エントリの英語原文を、UI 文言として自然な日本語へ翻訳する。
3. キーは一字一句そのまま（変更・整形・並べ替え禁止）、値だけを
   日本語に置き換えた JSON オブジェクトを $out_file に書く。
   入力と出力のキー集合は完全一致させ、全エントリを漏れなく翻訳する。
プレースホルダ（{name} や {{count}} 等）と HTML タグはそのまま保持する。
$out_file のみを作成・編集し、他のファイルや git の操作はしないこと。
PROMPT
)

  max_retries="${MAX_RETRIES:-3}"
  attempt=0
  delay=2
  while true; do
    attempt=$((attempt + 1))
    # Feed the prompt via stdin (`set +o pipefail` would mask claude's exit
    # status when piped through tee). Capture status via PIPESTATUS instead.
    set -o pipefail
    if printf '%s\n' "$prompt" | claude "${claude_args[@]}" 2>&1 | tee -a "$translate_log"; then
      break
    fi
    if [[ "$attempt" -ge "$max_retries" ]]; then
      echo "::error::claude failed on chunk $current ($in_file) after $max_retries attempts" >&2
      exit 1
    fi
    echo "::warning::claude CLI failed (attempt $attempt/$max_retries), retrying in ${delay}s..."
    sleep "$delay"
    delay=$((delay * 2))
  done

  if [[ ! -f "$out_file" ]]; then
    echo "::error::Chunk $current did not produce output: $out_file" >&2
    exit 1
  fi

  # Validate output: must be a JSON object whose key set exactly matches the
  # input's. Key count alone misses key renames or duplications.
  if ! jq -e --slurpfile ref "$in_file" '
    type == "object"
    and (keys_unsorted | sort) == ($ref[0] | keys_unsorted | sort)
  ' "$out_file" > /dev/null; then
    echo "::error::Chunk $current key set mismatch or invalid JSON ($out_file)" >&2
    exit 1
  fi
  echo "::endgroup::"
done

# Merge all chunk outputs into a single translated.json keyed by the original
# opaque path tokens. Later chunks override earlier ones on key collision
# (collisions should not happen because chunks are disjoint).
mapfile -t out_files < <(compgen -G "$chunks_dir/out-*.json" 2>/dev/null | sort || true)
if [[ "${#out_files[@]}" -eq 0 ]]; then
  echo "::error::No chunk output files found in $chunks_dir; translation produced no output" >&2
  exit 1
fi
jq -s 'reduce .[] as $o ({}; . * $o)' "${out_files[@]}" > "$work_dir/translated.json"
echo "Translated keys: $(jq 'length' "$work_dir/translated.json")"
