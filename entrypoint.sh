#!/bin/bash
set -e
git config --global --add safe.directory /github/workspace
echo "🔍 Starting Permission Drift Detector..."

REPORT_FILE="permissions-report.md"
DRIFT_FOUND=false
export GH_TOKEN="$INPUT_GITHUB_TOKEN"

# Ensure yq is installed
if ! command -v yq &> /dev/null; then
    echo "Installing yq..."
    curl -sSL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
        -o /usr/local/bin/yq
    chmod +x /usr/local/bin/yq
fi

BEFORE_SHA=$(jq -r .before "$GITHUB_EVENT_PATH")
AFTER_SHA=$(jq -r .after "$GITHUB_EVENT_PATH")

# Decide whether this is a PR or a direct push
if [[ -n "$GITHUB_BASE_REF" ]]; then
  echo "✅ PR detected (base: $GITHUB_BASE_REF)"
  git fetch origin "$GITHUB_BASE_REF" --depth=1
  CHANGED_FILES=$(git diff --name-only origin/$GITHUB_BASE_REF...HEAD -- '.github/workflows/*.yml')
  GET_OLD_CMD="git show origin/$GITHUB_BASE_REF"
else
  echo "✅ Commit detected"
  echo "BEFORE_SHA=$BEFORE_SHA"
  echo "AFTER_SHA=$AFTER_SHA"
  CHANGED_FILES=$(git diff --name-only $BEFORE_SHA $AFTER_SHA -- '.github/workflows/*.yml')
  GET_OLD_CMD="git show $BEFORE_SHA"
fi

# No workflow changes
if [[ -z "$CHANGED_FILES" ]]; then
    echo "✅ No workflow files changed."
    echo "✅ No workflow files changed." >> "$GITHUB_STEP_SUMMARY"
    exit 0
fi

# Start report
echo "### 🛡 Permission Drift Report" > "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

for file in $CHANGED_FILES; do
    OLD_PERMS=$($GET_OLD_CMD:$file 2>/dev/null | yq '.permissions' || true)
    NEW_PERMS=$(yq '.permissions' "$file" || true)

    if [[ "$(echo "$NEW_PERMS" | yq 'type')" != "!!map" ]]; then
        continue
    fi
    if [[ -z "$OLD_PERMS" && -z "$NEW_PERMS" ]]; then
        continue
    fi

    while IFS= read -r key; do
        OLD_VAL=$(echo "$OLD_PERMS" | yq ".$key" 2>/dev/null || echo "null")
        NEW_VAL=$(echo "$NEW_PERMS" | yq ".$key" 2>/dev/null || echo "null")

        if [[ "$OLD_VAL" != "write" && "$NEW_VAL" == "write" ]]; then
            DRIFT_FOUND=true
            echo "#### File: \`$file\`" >> "$REPORT_FILE"
            echo "- **$key**: $OLD_VAL → **$NEW_VAL**" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"
        fi
    done < <(echo "$NEW_PERMS" | yq 'keys' | sed 's/- //')
done

# Always write to Action Summary
cat "$REPORT_FILE" >> "$GITHUB_STEP_SUMMARY"

# If drift detected → notify via PR comment or Issue
if [[ "$DRIFT_FOUND" = true ]]; then
    echo "⚠️ Permission drift detected!"

    if [[ -n "$GITHUB_BASE_REF" ]]; then
        # PR context → add PR comment
        PR_NUMBER=$(jq -r .pull_request.number "$GITHUB_EVENT_PATH")
        gh api repos/${GITHUB_REPOSITORY}/issues/$PR_NUMBER/comments \
            -f body="$(cat $REPORT_FILE)"
    else
        # Commit context → create issue for repo owner
        OWNER=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f1)
        gh api repos/${GITHUB_REPOSITORY}/issues \
            -f title="⚠️ Permission Drift Detected" \
            -f body="$(cat $REPORT_FILE)" \
            -f assignees[]="$OWNER"
    fi
else
    echo "✅ No permission upgrades detected."
fi
