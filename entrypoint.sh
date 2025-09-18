#!/bin/bash
set -e
git config --global --add safe.directory /github/workspace
echo "🔍 Starting Permission Drift Detector with YAML parsing..."

REPORT_FILE="permissions-report.md"
DRIFT_FOUND=false

# Ensure yq is installed
if ! command -v yq &> /dev/null; then
    echo "Installing yq..."
    curl -sSL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
        -o /usr/local/bin/yq
    chmod +x /usr/local/bin/yq
fi
echo "GITHUB_EVENT_BEFORE=$GITHUB_EVENT_BEFORE"
echo "GITHUB_SHA=$GITHUB_SHA"
# Decide whether this is a PR or a direct push
if [[ -n "$GITHUB_BASE_REF" ]]; then
  echo "✅ PR detected (base: $GITHUB_BASE_REF)"
  git fetch origin "$GITHUB_BASE_REF" --depth=1
  CHANGED_FILES=$(git diff --name-only origin/$GITHUB_BASE_REF...HEAD -- '.github/workflows/*.yml')
  GET_OLD_CMD="git show origin/$GITHUB_BASE_REF"
else
  echo "✅ Commit detected"
  CHANGED_FILES=$(git diff --name-only $GITHUB_EVENT_BEFORE $GITHUB_SHA -- '.github/workflows/*.yml')
  GET_OLD_CMD="git show $GITHUB_EVENT_BEFORE"
fi

# No workflow changes
if [[ -z "$CHANGED_FILES" ]]; then
    echo "✅ No workflow files changed."
    exit 0
fi

echo "⚠️ Workflow files changed:"
echo "$CHANGED_FILES"

# Start report
echo "### 🛡 Permission Drift Report" > "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

for file in $CHANGED_FILES; do
    echo "Analyzing: $file"

    # Extract old and new permissions
    OLD_PERMS=$($GET_OLD_CMD:$file 2>/dev/null | yq '.permissions' || true)
    NEW_PERMS=$(yq '.permissions' "$file" || true)

    # Skip files without permissions map
    if [[ "$(echo "$NEW_PERMS" | yq 'type')" != "!!map" ]]; then
        continue
    fi
    if [[ -z "$OLD_PERMS" && -z "$NEW_PERMS" ]]; then
        continue
    fi

    # Compare each permission key
    while IFS= read -r key; do
        OLD_VAL=$(echo "$OLD_PERMS" | yq ".$key" 2>/dev/null || echo "null")
        NEW_VAL=$(echo "$NEW_PERMS" | yq ".$key" 2>/dev/null || echo "null")

        # Flag only upgrades (read → write, null → write)
        if [[ "$OLD_VAL" != "write" && "$NEW_VAL" == "write" ]]; then
            DRIFT_FOUND=true
            echo "#### File: \`$file\`" >> "$REPORT_FILE"
            echo "- **$key**: $OLD_VAL → **$NEW_VAL**" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"
        fi
    done < <(echo "$NEW_PERMS" | yq 'keys' | sed 's/- //')
done

# Final result
if [[ "$DRIFT_FOUND" = true ]]; then
    echo "⚠️ Permission drift detected!"
else
    echo "✅ No permission upgrades detected."
fi
