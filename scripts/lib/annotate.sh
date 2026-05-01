#!/usr/bin/env bash
# Read a graphql-cli JSON results file and emit GitHub Actions workflow
# commands (::error::, ::warning::) for each diagnostic.
#
# Workflow command spec:
#   https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions
# Property values escape `%`, CR, LF; message body escapes the same set.
#
# Paths from the CLI are absolute. We strip $GITHUB_WORKSPACE/ when present so
# GitHub renders annotations inline on the diff. Paths outside the workspace
# pass through unchanged (still surfaces in the run log, just not inline).
set -euo pipefail

input="${1:?usage: annotate.sh RESULTS_JSON}"
ws="${GITHUB_WORKSPACE:-}"

jq -r --arg ws "$ws" '
  def escape: gsub("%"; "%25") | gsub("\r"; "%0D") | gsub("\n"; "%0A");
  def relpath($file):
    if ($ws | length) > 0 and ($file | startswith($ws + "/"))
    then $file[($ws | length) + 1:]
    else $file
    end;
  def emit($file; $sev):
    "::\($sev) file=\(relpath($file)),line=\(.location.start.line),col=\(.location.start.column),endLine=\(.location.end.line),endColumn=\(.location.end.column),title=\(.rule // .source // "graphql")::\(.message | escape)";
  .files[]?
  | . as $f
  | (($f.errors[]?   | emit($f.file; "error")),
     ($f.warnings[]? | emit($f.file; "warning")))
' "$input"
