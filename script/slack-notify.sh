#!/usr/bin/env bash
# Post a single-line escalation message to Slack via Incoming Webhook.
# Designed to be called from GitHub Actions on failure / human-review
# escalation paths only, so the normal auto-loop stays silent.
#
# When SLACK_WEBHOOK_URL is unset or empty the script logs and exits 0,
# so workflows that have not enabled Slack notifications keep passing.
#
# Required env:
#   SLACK_WEBHOOK_URL  Slack incoming webhook URL (repo secret).
#
# Args:
#   $1: text  Free-form message body (required).
#   $2: url   Optional link URL appended as "<url|details>".
#
# Usage:
#   SLACK_WEBHOOK_URL=... script/slack-notify.sh \
#     "Auto-heal Actions failure: upstream-monitor" \
#     "https://github.com/owner/repo/actions/runs/123"

set -euo pipefail

text="${1:-}"
url="${2:-}"

if [[ -z "$text" ]]; then
  echo "slack-notify: text argument is required" >&2
  exit 1
fi

if [[ -z "${SLACK_WEBHOOK_URL:-}" ]]; then
  echo "slack-notify: SLACK_WEBHOOK_URL not set; skipping"
  exit 0
fi

if ! command -v jq > /dev/null 2>&1; then
  echo "slack-notify: jq not found on PATH" >&2
  exit 1
fi

if [[ -n "$url" ]]; then
  body=$(jq -n --arg text "$text" --arg url "$url" '
    {text: ($text + "\n<" + $url + "|details>")}')
else
  body=$(jq -n --arg text "$text" '{text: $text}')
fi

# Fail loudly only when the webhook itself rejects the payload; do not
# block the calling workflow on transient network issues.
if ! curl -fsS -X POST -H 'Content-Type: application/json' \
     --max-time 10 --retry 2 --retry-delay 2 \
     -d "$body" "$SLACK_WEBHOOK_URL" > /dev/null; then
  echo "slack-notify: webhook POST failed" >&2
  exit 1
fi
echo "slack-notify: posted"
