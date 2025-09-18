#!/bin/bash
set -e
git config --global --add safe.directory /github/workspace
echo "🔍 Starting Permission Drift Detector with YAML parsing..."

BASE_BRANCH=${GITHUB_BASE_REF:-main}
REPORT_FILE="permissions-report.md"
DRIFT_FOUND=false

# Install yq if not present (needed for YAML parsing)
if ! command -v yq &> /dev/null; then
    echo "Installing yq..."
    sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    sudo chmod +x /usr/local/bin/yq
fi

if [[ -n "$GITHUB_BASE_REF" ]]; then
  echo "✅ pr"
  git fetch origin "$GITHUB_BASE_REF" --depth=1
  CHANGED_FILES=$(git diff --name-only origin/$GITHUB_BASE_REF...HEAD -- '.github/workflows/*.yml')
else
  echo "✅ commit"
  CHANGED_FILES=$(git diff --name-only $GITHUB_EVENT_BEFORE $GITHUB_SHA -- '.github/workflows/*.yml')
fi


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

    # Extract old and new permissions as YAML maps
    OLD_PERMS=$(git show origin/$BASE_BRANCH:$file 2>/dev/null | yq '.permissions' || true)
    NEW_PERMS=$(yq '.permissions' "$file" || true)
    if [[ "$(echo "$NEW_PERMS" | yq 'type')" != "!!map" ]]; then
        continue
    fi
    # Skip if no permissions in both versions
    if [[ -z "$OLD_PERMS" && -z "$NEW_PERMS" ]]; then
        continue
    fi

    # Compare each permission key
    while IFS= read -r key; do
        OLD_VAL=$(echo "$OLD_PERMS" | yq ".$key" 2>/dev/null || echo "null")
        NEW_VAL=$(echo "$NEW_PERMS" | yq ".$key" 2>/dev/null || echo "null")

        # Flag only upgrades (e.g., read -> write or null -> write)
        if [[ "$OLD_VAL" != "write" && "$NEW_VAL" == "write" ]]; then
            DRIFT_FOUND=true
            echo "#### File: \`$file\`" >> "$REPORT_FILE"
            echo "- **$key**: $OLD_VAL → **$NEW_VAL**" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"
        fi
    done < <(echo "$NEW_PERMS" | yq 'keys' | sed 's/- //')
done

if [[ "$DRIFT_FOUND" = true ]]; then
    echo "⚠️ Permission drift detected!"
else
    echo "✅ No permission upgrades detected."
fi
