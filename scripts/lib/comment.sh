#!/usr/bin/env bash
# Render or post a PR summary comment derived from a graphql-cli JSON results
# file. Usage:
#   comment.sh --render RESULTS_JSON              -> prints markdown to stdout
#   comment.sh --post   RESULTS_JSON              -> upserts a comment on the
#                                                    current PR
#
# Re-uses the same shape rendered by summary.sh: heading, counts, table of
# the first 10 diagnostics. Adds a stable HTML marker (<!-- graphql-analyzer-
# action -->) so subsequent runs find and PATCH the existing comment instead
# of stacking duplicates.
set -euo pipefail

mode="${1:?--render or --post}"
input="${2:?usage: comment.sh --render|--post RESULTS_JSON}"

MARKER='<!-- graphql-analyzer-action -->'

render() {
  local errors warnings total ws
  ws="${GITHUB_WORKSPACE:-}"
  errors=$(jq -r '.stats.total_errors // 0' "$input")
  warnings=$(jq -r '.stats.total_warnings // 0' "$input")
  total=$((errors + warnings))

  echo "$MARKER"
  echo "## GraphQL Analyzer"
  echo
  printf '**%s error%s** · **%s warning%s**\n\n' \
    "$errors" "$([ "$errors" = "1" ] || echo s)" \
    "$warnings" "$([ "$warnings" = "1" ] || echo s)"

  if [ "$total" -gt 0 ]; then
    echo "| File | Line | Severity | Rule | Message |"
    echo "| --- | --- | --- | --- | --- |"
    jq -r --arg ws "$ws" '
      def relpath($file):
        if ($ws | length) > 0 and ($file | startswith($ws + "/"))
        then $file[($ws | length) + 1:]
        else $file
        end;
      def row($file; $sev):
        "| \(relpath($file)) | \(.location.start.line) | \($sev) | \(.rule // .source // "—") | \(.message | gsub("\\|"; "\\|") | gsub("\n"; " ")) |";
      [
        .files[]?
        | . as $f
        | (($f.errors[]?   | row($f.file; "error")),
           ($f.warnings[]? | row($f.file; "warning")))
      ][0:10][]
    ' "$input"

    if [ "$total" -gt 10 ]; then
      echo
      echo "_…and $((total - 10)) more_"
    fi
  else
    echo "_No issues found._"
  fi
}

post() {
  local body pr_number existing
  body="$(render)"

  pr_number="${GITHUB_PR_NUMBER:-}"
  if [ -z "$pr_number" ] && [ -n "${GITHUB_EVENT_PATH:-}" ] && [ -f "$GITHUB_EVENT_PATH" ]; then
    pr_number=$(jq -r '.pull_request.number // empty' "$GITHUB_EVENT_PATH")
  fi
  if [ -z "$pr_number" ]; then
    echo "::warning::comment:true but not running on a pull_request; skipping" >&2
    return 0
  fi

  existing=$(gh api "repos/$GITHUB_REPOSITORY/issues/$pr_number/comments" \
    --paginate \
    --jq "[.[] | select(.body | contains(\"$MARKER\"))] | first | .id // empty")

  if [ -n "$existing" ]; then
    gh api --method PATCH "repos/$GITHUB_REPOSITORY/issues/comments/$existing" \
      -f body="$body" > /dev/null
  else
    gh pr comment "$pr_number" --repo "$GITHUB_REPOSITORY" --body "$body"
  fi
}

case "$mode" in
  --render) render ;;
  --post)   post ;;
  *)
    echo "::error::comment.sh: unknown mode $mode" >&2
    exit 1
    ;;
esac
