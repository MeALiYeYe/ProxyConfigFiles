#!/usr/bin/env bash
set -e

cd "$(dirname "$0")/../.."

echo "== Git Commit =="

git config --global user.name "github-actions"
git config --global user.email "actions@github.com"

git add .

if git diff --cached --quiet; then
  echo "No changes"
  exit 0
fi

git commit -m "auto: full pipeline"

# 避免冲突
git pull --rebase origin main

git push
