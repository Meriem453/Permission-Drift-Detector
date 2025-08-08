#!/bin/bash

echo "🔍 Checking for permission drift in workflow files..."

git fetch origin main:refs/remotes/origin/main

DIFF_FILES=$(git diff origin/main...HEAD --name-only -- '.github/workflows/*.yml')

if [[ -z "$DIFF_FILES" ]]; then
  echo "✅ No workflow files changed."
  exit 0
fi

echo "⚠️ Workflow files changed:"
echo "$DIFF_FILES"

echo "### ⚠️ Permission Drift Detected" > permissions-report.md

for file in $DIFF_FILES; do
  echo "- Checking file: $file" >> permissions-report.md

  # Get old and new permission blocks
  OLD_PERMS=$(git show origin/main:$file | grep -A5 "permissions:" | sed 's/^/OLD: /')
  NEW_PERMS=$(cat "$file" | grep -A5 "permissions:" | sed 's/^/NEW: /')

  # Compare and log
  echo '```yaml' >> permissions-report.md
  echo "$OLD_PERMS" >> permissions-report.md
  echo "$NEW_PERMS" >> permissions-report.md
  echo '```' >> permissions-report.md

  # Optional: exit non-zero if drift found
done
