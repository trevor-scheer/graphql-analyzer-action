#!/usr/bin/env bats

setup() {
  ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export GITHUB_STEP_SUMMARY="$BATS_TEST_TMPDIR/summary.md"
  export GITHUB_WORKSPACE="$BATS_TEST_TMPDIR/workspace"
  mkdir -p "$GITHUB_WORKSPACE"
  : > "$GITHUB_STEP_SUMMARY"
}

@test "writes heading and zero counts on a clean result" {
  fixture="$BATS_TEST_TMPDIR/in.json"
  echo '{"files": [], "stats": {"total_errors": 0, "total_warnings": 0}, "success": true}' > "$fixture"
  run "$ROOT/scripts/lib/summary.sh" "$fixture"
  [ "$status" -eq 0 ]
  grep -q "GraphQL Analyzer" "$GITHUB_STEP_SUMMARY"
  grep -q "0 errors" "$GITHUB_STEP_SUMMARY"
  grep -q "0 warnings" "$GITHUB_STEP_SUMMARY"
}

@test "renders the first 10 diagnostics in a table and notes overflow" {
  fixture="$BATS_TEST_TMPDIR/in.json"
  jq -n --arg ws "$GITHUB_WORKSPACE" '
    {
      files: [
        { file: ($ws + "/f.graphql"),
          errors: [ range(0;15) | {
            severity: "error", source: "validation",
            message: "m\(.)",
            location: {start: {line: ., column: 1}, end: {line: ., column: 2}},
            rule: null
          } ],
          warnings: []
        }
      ],
      stats: {total_errors: 15, total_warnings: 0},
      success: false
    }
  ' > "$fixture"
  run "$ROOT/scripts/lib/summary.sh" "$fixture"
  [ "$status" -eq 0 ]
  grep -q "| File | Line | Severity | Rule | Message |" "$GITHUB_STEP_SUMMARY"
  table_rows=$(grep -cE '^\| f\.graphql' "$GITHUB_STEP_SUMMARY")
  [ "$table_rows" -eq 10 ]
  grep -q "5 more" "$GITHUB_STEP_SUMMARY"
}

@test "uses repo-relative paths in the table" {
  fixture="$BATS_TEST_TMPDIR/in.json"
  cat > "$fixture" <<JSON
{
  "files": [
    {
      "file": "$GITHUB_WORKSPACE/deep/q.graphql",
      "errors": [
        {"severity":"error","source":"v","message":"m",
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
  run "$ROOT/scripts/lib/summary.sh" "$fixture"
  grep -qE '^\| deep/q\.graphql ' "$GITHUB_STEP_SUMMARY"
}

@test "escapes pipes inside messages" {
  fixture="$BATS_TEST_TMPDIR/in.json"
  cat > "$fixture" <<JSON
{
  "files": [
    {
      "file": "$GITHUB_WORKSPACE/x",
      "errors": [
        {"severity":"error","source":"v","message":"a | b | c",
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
  run "$ROOT/scripts/lib/summary.sh" "$fixture"
  # Pipes inside the message should be escaped so they don't break the table.
  grep -q 'a \\| b \\| c' "$GITHUB_STEP_SUMMARY"
}
