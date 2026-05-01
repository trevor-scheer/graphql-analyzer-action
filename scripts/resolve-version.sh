#!/usr/bin/env bash
# Resolve INPUT_VERSION to a concrete CLI version and emit it as a step output.
# When INPUT_VERSION is "latest", queries gh release list for the highest
# graphql-analyzer-cli/v* tag.
set -euo pipefail

input="${INPUT_VERSION:-latest}"

if [ "$input" != "latest" ]; then
  printf 'version=%s\n' "$input" >> "$GITHUB_OUTPUT"
  exit 0
fi

# Primary path: structured query via gh --json piped through jq. Piping
# locally (rather than using gh's --jq) keeps the script portable across gh
# versions and easier to test with a stubbed gh.
resolved="$(gh release list \
  --repo trevor-scheer/graphql-analyzer \
  --limit 50 \
  --json tagName,publishedAt \
  2>/dev/null \
  | jq -r '[.[] | select(.tagName | startswith("graphql-analyzer-cli/v"))] | sort_by(.publishedAt) | last | .tagName | ltrimstr("graphql-analyzer-cli/v") // ""' \
  2>/dev/null || true)"

# Fallback: parse plain-text output if --jq path fails (older gh, network blip).
if [ -z "$resolved" ]; then
  resolved="$(gh release list --repo trevor-scheer/graphql-analyzer --limit 50 \
    | grep -oE 'graphql-analyzer-cli/v[0-9]+\.[0-9]+\.[0-9]+' \
    | head -n1 \
    | sed 's|graphql-analyzer-cli/v||' || true)"
fi

if [ -z "$resolved" ]; then
  echo "::error::Could not resolve latest graphql-analyzer-cli release" >&2
  exit 1
fi

printf 'version=%s\n' "$resolved" >> "$GITHUB_OUTPUT"
