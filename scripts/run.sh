#!/usr/bin/env bash
# Invoke the graphql CLI per the action's inputs, capture JSON output, derive
# error/warning counts from the CLI's `stats` block, set step outputs, and
# propagate the CLI's exit code. Annotations, step summary, SARIF, and PR
# comment are added in later phases.
#
# JSON schema (from `graphql check --format=json`):
#   {
#     "files": [
#       { "file": "<abs path>",
#         "errors":   [{"severity":"error",   "message":"...", "location":{"start":{"line":N,"column":N},"end":{"line":N,"column":N}}, "rule":null|"...", ...}],
#         "warnings": [{"severity":"warning", ...}] }
#     ],
#     "stats": {"total_errors":N, "total_warnings":N, ...},
#     "success": true|false
#   }
set -uo pipefail

cmd="${INPUT_COMMAND:-check}"
case "$cmd" in
  check|validate|lint) ;;
  *)
    echo "::error::Invalid command: $cmd (must be check, validate, or lint)" >&2
    exit 1
    ;;
esac

args=("$cmd" "--format=json" "--no-color" "--no-progress")
[ -n "${INPUT_CONFIG:-}" ] && args+=("-c" "$INPUT_CONFIG")
[ -n "${INPUT_PROJECT:-}" ] && args+=("-p" "$INPUT_PROJECT")
[ -n "${INPUT_MAX_WARNINGS:-}" ] && args+=("--max-warnings" "$INPUT_MAX_WARNINGS")

results="${RUNNER_TEMP:-/tmp}/graphql-results.json"
graphql "${args[@]}" > "$results"
exit_code=$?

errors=0
warnings=0
if [ -s "$results" ]; then
  errors=$(jq -r '.stats.total_errors // 0' "$results")
  warnings=$(jq -r '.stats.total_warnings // 0' "$results")
fi

printf 'errors=%s\n' "$errors" >> "${GITHUB_OUTPUT:-/dev/stdout}"
printf 'warnings=%s\n' "$warnings" >> "${GITHUB_OUTPUT:-/dev/stdout}"

exit "$exit_code"
