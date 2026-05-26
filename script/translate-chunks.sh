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

set -euo pipefail

CHUNK_SIZE="${CHUNK_SIZE:-40}"
work_dir="${GITHUB_WORKSPACE:-$PWD}/.l10n-work"
chunks_dir="$work_dir/chunks"
src="$work_dir/to_translate.json"

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

claude_args=(
  --print
  --permission-mode acceptEdits
  --allowedTools "Read,Write,Edit"
  --max-turns 10
)
if [[ -n "${CLAUDE_MODEL:-}" ]]; then
  claude_args+=(--model "$CLAUDE_MODEL")
fi

current=0
for in_file in "$chunks_dir"/in-*.json; do
  current=$((current + 1))
  out_file="${in_file/in-/out-}"
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

  claude "${claude_args[@]}" "$prompt" > /dev/null

  if [[ ! -f "$out_file" ]]; then
    echo "::error::Chunk $current did not produce output: $out_file" >&2
    exit 1
  fi
  echo "::endgroup::"
done

# Merge all chunk outputs into a single translated.json keyed by the original
# opaque path tokens. Later chunks override earlier ones on key collision
# (collisions should not happen because chunks are disjoint).
jq -s 'reduce .[] as $o ({}; . * $o)' "$chunks_dir"/out-*.json > "$work_dir/translated.json"
echo "Translated keys: $(jq 'length' "$work_dir/translated.json")"
