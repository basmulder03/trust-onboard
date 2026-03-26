#!/usr/bin/env sh
set -eu

repo_name="${1:-trust-onboard}"
visibility="${2:-private}"

case "$visibility" in
  public|private|internal) ;;
  *)
    printf 'unsupported visibility: %s\n' "$visibility" >&2
    exit 1
    ;;
esac

git init
git add .
git commit -m "Initial trust-onboard import"
gh repo create "$repo_name" "--$visibility" --source=. --remote=origin --push
