#!/bin/sh
# Makes the GitHub App "Talon Indexer" in the org roc-talon with the manifest flow.
# Usage: research/github-app-check/create.sh [port]
# Needs: node, gh (logged in). Writes the App keys to ~/.config/talon-indexer/ (mode 600).
set -eu
here=$(cd "$(dirname "$0")" && pwd)
exec node "$here/create.mjs" "$@"
