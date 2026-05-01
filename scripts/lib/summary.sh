#!/usr/bin/env bash
# Append a markdown summary of CLI results to a file (default
# $GITHUB_STEP_SUMMARY). Writes a heading, error/warning counts, and a table
# of the first 10 diagnostics.
#
# Usage: summary.sh RESULTS_JSON [OUTPUT_PATH]
#
# Reads the same JSON shape as annotate.sh: top-level .files[] with .errors
# and .warnings arrays, plus .stats.{total_errors,total_warnings}. Paths are
# made repo-relative against $GITHUB_WORKSPACE for readability.
#
# Output path is configurable so tests can run summary.sh against a fixed
# location without colliding with the runner's per-step GITHUB_STEP_SUMMARY
# (which the runner resets between steps).
set -euo pipefail

input="${1:?usage: summary.sh RESULTS_JSON [OUTPUT_PATH]}"
output="${2:-${GITHUB_STEP_SUMMARY:-}}"
if [ -z "$output" ]; then
  echo "summary.sh: no output path (pass as arg or set GITHUB_STEP_SUMMARY)" >&2
  exit 1
fi
ws="${GITHUB_WORKSPACE:-}"

errors=$(jq -r '.stats.total_errors // 0' "$input")
warnings=$(jq -r '.stats.total_warnings // 0' "$input")

{
  echo "## GraphQL Analyzer"
  echo
  echo "**$errors errors** · **$warnings warnings**"
  echo

  total=$((errors + warnings))
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
        # Errors first, then warnings (reflected in caller order).
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
  fi
} >> "$output"
