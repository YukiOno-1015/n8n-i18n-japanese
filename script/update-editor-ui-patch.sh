#!/usr/bin/env bash
set -euo pipefail

N8N_ROOT="${1:-n8n}"
PATCH_OUT="${2:-fix_editor-ui.patch}"

TARGET_REL="packages/frontend/editor-ui/src/app/App.vue"
TARGET_FILE="$N8N_ROOT/$TARGET_REL"

if [[ ! -f "$TARGET_FILE" ]]; then
  echo "Target file not found: $TARGET_FILE" >&2
  exit 1
fi

if grep -Fq "loadLanguage('ja'" "$TARGET_FILE"; then
  echo "Upstream already contains ja runtime loading. Keep existing patch as-is."
  exit 0
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

orig_file="$tmp_dir/orig.vue"
new_file="$tmp_dir/new.vue"
raw_diff="$tmp_dir/raw.diff"

cp "$TARGET_FILE" "$orig_file"
cp "$TARGET_FILE" "$new_file"

# Import loadLanguage and ja base text for runtime locale injection.
perl -0777 -i -pe "s#import \{ setLanguage \} from '\@n8n/i18n';#import { loadLanguage, setLanguage } from '\@n8n/i18n';\nimport type { LocaleMessages } from '\@n8n/i18n';#" "$new_file"

if ! grep -Fq "import japaneseBaseText from '@n8n/i18n/locales/ja.json';" "$new_file"; then
  perl -0777 -i -pe "s#import \{ useRootStore \} from '\@n8n/stores/useRootStore';#import japaneseBaseText from '\@n8n/i18n/locales/ja.json';\nimport { useRootStore } from '\@n8n/stores/useRootStore';#" "$new_file"
fi

# Switch locale handling to load ja messages explicitly.
perl -0777 -i -pe "s#\n\t\tsetLanguage\(newLocale\);\n#\n\t\tif (newLocale === 'ja') {\n\t\t\tloadLanguage('ja', japaneseBaseText as unknown as LocaleMessages);\n\t\t} else {\n\t\t\tsetLanguage(newLocale);\n\t\t}\n#" "$new_file"

if cmp -s "$orig_file" "$new_file"; then
  echo "Failed to produce patch content changes from $TARGET_REL" >&2
  exit 1
fi

if ! diff -u --label "a/$TARGET_REL" --label "b/$TARGET_REL" "$orig_file" "$new_file" > "$raw_diff"; then
  :
fi

{
  echo "diff --git a/$TARGET_REL b/$TARGET_REL"
  cat "$raw_diff"
} > "$PATCH_OUT"

echo "Updated patch: $PATCH_OUT"
