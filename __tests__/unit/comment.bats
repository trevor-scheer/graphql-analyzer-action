#!/usr/bin/env bats

setup() {
  ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export GITHUB_WORKSPACE="$BATS_TEST_TMPDIR/workspace"
  mkdir -p "$GITHUB_WORKSPACE"
}

@test "render: includes stable HTML marker so future runs can dedupe" {
  fixture="$BATS_TEST_TMPDIR/in.json"
  echo '{"files": [], "stats": {"total_errors": 0, "total_warnings": 0}, "success": true}' > "$fixture"
  run "$ROOT/scripts/lib/comment.sh" --render "$fixture"
  [ "$status" -eq 0 ]
  [[ "$output" == *"<!-- graphql-analyzer-action -->"* ]]
}

@test "render: includes heading and counts" {
  fixture="$BATS_TEST_TMPDIR/in.json"
  cat > "$fixture" <<JSON
{
  "files": [
    {
      "file": "$GITHUB_WORKSPACE/a.graphql",
      "errors": [
        {"severity":"error","source":"validation","message":"oops",
         "location":{"start":{"line":1,"column":1},"end":{"line":1,"column":1}},
         "rule":null}
      ],
      "warnings": []
    }
  ],
  "stats": {"total_errors": 1, "total_warnings": 0},
  "success": false
}
JSON
  run "$ROOT/scripts/lib/comment.sh" --render "$fixture"
  [ "$status" -eq 0 ]
  [[ "$output" == *"## GraphQL Analyzer"* ]]
  [[ "$output" == *"1 error"* ]]
}

@test "render: shows 'no issues' message when clean" {
  fixture="$BATS_TEST_TMPDIR/in.json"
  echo '{"files": [], "stats": {"total_errors": 0, "total_warnings": 0}, "success": true}' > "$fixture"
  run "$ROOT/scripts/lib/comment.sh" --render "$fixture"
  [[ "$output" == *"No issues"* ]]
}

@test "render: pluralizes correctly" {
  fixture="$BATS_TEST_TMPDIR/in.json"
  echo '{"files": [], "stats": {"total_errors": 2, "total_warnings": 1}, "success": false}' > "$fixture"
  run "$ROOT/scripts/lib/comment.sh" --render "$fixture"
  [[ "$output" == *"2 errors"* ]]
  [[ "$output" == *"1 warning"* ]]
  # Singular for warning (1), plural for error (2)
  [[ "$output" != *"1 warnings"* ]]
}

@test "post: skips with warning when not on a pull_request" {
  fixture="$BATS_TEST_TMPDIR/in.json"
  echo '{"files": [], "stats": {"total_errors": 0, "total_warnings": 0}, "success": true}' > "$fixture"
  unset GITHUB_PR_NUMBER GITHUB_EVENT_PATH
  run "$ROOT/scripts/lib/comment.sh" --post "$fixture"
  [ "$status" -eq 0 ]
  [[ "$output" == *"not running on a pull_request"* ]]
}
