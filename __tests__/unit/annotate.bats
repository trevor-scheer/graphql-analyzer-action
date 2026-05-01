#!/usr/bin/env bats

setup() {
  ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export GITHUB_WORKSPACE="$BATS_TEST_TMPDIR/workspace"
  mkdir -p "$GITHUB_WORKSPACE"
}

@test "emits ::error:: for an error in .files[].errors" {
  fixture="$BATS_TEST_TMPDIR/in.json"
  cat > "$fixture" <<JSON
{
  "files": [
    {
      "file": "$GITHUB_WORKSPACE/src/q.graphql",
      "errors": [
        {
          "severity": "error",
          "source": "validation",
          "message": "Cannot query field \"foo\"",
          "location": {"start": {"line": 5, "column": 3}, "end": {"line": 5, "column": 6}},
          "rule": null,
          "url": null,
          "help": null,
          "tags": []
        }
      ],
      "warnings": []
    }
  ],
  "stats": {"total_errors": 1, "total_warnings": 0}
}
JSON
  run "$ROOT/scripts/lib/annotate.sh" "$fixture"
  [ "$status" -eq 0 ]
  [[ "$output" == *"::error file=src/q.graphql,line=5,col=3,endLine=5,endColumn=6,title=validation::Cannot query field \"foo\""* ]]
}

@test "emits ::warning:: for warnings; uses .rule when present" {
  fixture="$BATS_TEST_TMPDIR/in.json"
  cat > "$fixture" <<JSON
{
  "files": [
    {
      "file": "$GITHUB_WORKSPACE/a.graphql",
      "errors": [],
      "warnings": [
        {
          "severity": "warning",
          "source": "lint",
          "message": "soft",
          "location": {"start": {"line": 1, "column": 1}, "end": {"line": 1, "column": 5}},
          "rule": "no-anonymous-operations"
        }
      ]
    }
  ],
  "stats": {"total_errors": 0, "total_warnings": 1}
}
JSON
  run "$ROOT/scripts/lib/annotate.sh" "$fixture"
  [ "$status" -eq 0 ]
  [[ "$output" == *"::warning file=a.graphql,line=1,col=1,endLine=1,endColumn=5,title=no-anonymous-operations::soft"* ]]
}

@test "emits nothing when files[] is empty" {
  fixture="$BATS_TEST_TMPDIR/in.json"
  echo '{"files": [], "stats": {"total_errors": 0, "total_warnings": 0}}' > "$fixture"
  run "$ROOT/scripts/lib/annotate.sh" "$fixture"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "escapes %, CR, LF, and ',', ':' in message per workflow command spec" {
  fixture="$BATS_TEST_TMPDIR/in.json"
  cat > "$fixture" <<JSON
{
  "files": [
    {
      "file": "$GITHUB_WORKSPACE/x.graphql",
      "errors": [
        {
          "severity": "error",
          "source": "v",
          "message": "100% bad\nnext: line, comma",
          "location": {"start": {"line": 1, "column": 1}, "end": {"line": 1, "column": 1}},
          "rule": null
        }
      ],
      "warnings": []
    }
  ],
  "stats": {"total_errors": 1, "total_warnings": 0}
}
JSON
  run "$ROOT/scripts/lib/annotate.sh" "$fixture"
  [ "$status" -eq 0 ]
  [[ "$output" == *"100%25 bad%0Anext: line, comma"* ]]
}

@test "rewrites absolute path to repo-relative against GITHUB_WORKSPACE" {
  fixture="$BATS_TEST_TMPDIR/in.json"
  cat > "$fixture" <<JSON
{
  "files": [
    {
      "file": "$GITHUB_WORKSPACE/deep/nested/file.graphql",
      "errors": [
        {"severity": "error", "source": "v", "message": "x",
         "location": {"start": {"line": 2, "column": 1}, "end": {"line": 2, "column": 1}},
         "rule": null}
      ],
      "warnings": []
    }
  ],
  "stats": {"total_errors": 1, "total_warnings": 0}
}
JSON
  run "$ROOT/scripts/lib/annotate.sh" "$fixture"
  [[ "$output" == *"file=deep/nested/file.graphql"* ]]
  [[ "$output" != *"$GITHUB_WORKSPACE"* ]]
}

@test "passes path through unchanged when it isn't under GITHUB_WORKSPACE" {
  fixture="$BATS_TEST_TMPDIR/in.json"
  cat > "$fixture" <<'JSON'
{
  "files": [
    {
      "file": "/some/other/path.graphql",
      "errors": [
        {"severity": "error", "source": "v", "message": "x",
         "location": {"start": {"line": 1, "column": 1}, "end": {"line": 1, "column": 1}},
         "rule": null}
      ],
      "warnings": []
    }
  ],
  "stats": {"total_errors": 1, "total_warnings": 0}
}
JSON
  run "$ROOT/scripts/lib/annotate.sh" "$fixture"
  [[ "$output" == *"file=/some/other/path.graphql"* ]]
}
