#!/usr/bin/env bash
# Invoke the graphql CLI per the action's inputs, capture JSON output, derive
# error/warning counts from the CLI's `stats` block, emit annotations + step
# summary, set step outputs, and propagate the CLI's exit code.
#
# JSON schema (from `graphql check --format=json`):
#   {
#     "files": [
#       { "file": "<abs path>",
#         "errors":   [{"severity":"error",   "message":"...", "location":{"start":{"line":N,"column":N},"end":{"line":N,"column":N}}, "rule":null|"...", "source":"validation"|"lint", ...}],
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

# ACTION_PATH is set by action.yml; falls back to the script's directory for
# local invocation.
action_path="${ACTION_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"

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

if [ "${INPUT_ANNOTATE:-true}" = "true" ] && [ -s "$results" ]; then
  "$action_path/scripts/lib/annotate.sh" "$results"
fi

if [ -s "$results" ] && [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  "$action_path/scripts/lib/summary.sh" "$results" || true
fi

# SARIF: second CLI invocation. Mutually exclusive with --format=json, hence
# a separate run. The CLI exits non-zero when diagnostics exist but the SARIF
# document is still valid in that case, so we discard the exit code here.
if [ "${INPUT_SARIF:-false}" = "true" ]; then
  sarif_args=("$cmd" "--format=sarif" "--no-color" "--no-progress")
  [ -n "${INPUT_CONFIG:-}" ] && sarif_args+=("-c" "$INPUT_CONFIG")
  [ -n "${INPUT_PROJECT:-}" ] && sarif_args+=("-p" "$INPUT_PROJECT")

  sarif_path="${INPUT_SARIF_FILE:-graphql-results.sarif}"
  graphql "${sarif_args[@]}" > "$sarif_path" || true

  if [ -s "$sarif_path" ]; then
    printf 'sarif-file=%s\n' "$sarif_path" >> "${GITHUB_OUTPUT:-/dev/stdout}"
  fi
fi

printf 'errors=%s\n' "$errors" >> "${GITHUB_OUTPUT:-/dev/stdout}"
printf 'warnings=%s\n' "$warnings" >> "${GITHUB_OUTPUT:-/dev/stdout}"

exit "$exit_code"
