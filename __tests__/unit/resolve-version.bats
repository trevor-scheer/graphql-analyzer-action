#!/usr/bin/env bats

setup() {
  ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  export PATH="$ROOT/__tests__/stubs:$PATH"
  export GITHUB_OUTPUT="$BATS_TEST_TMPDIR/output"
  : > "$GITHUB_OUTPUT"
}

@test "resolves an explicit version verbatim" {
  INPUT_VERSION=1.2.3 run "$ROOT/scripts/resolve-version.sh"
  [ "$status" -eq 0 ]
  grep -q '^version=1.2.3$' "$GITHUB_OUTPUT"
}

@test "resolves 'latest' from gh release list" {
  INPUT_VERSION=latest run "$ROOT/scripts/resolve-version.sh"
  [ "$status" -eq 0 ]
  grep -q '^version=9.9.9$' "$GITHUB_OUTPUT"
}

@test "fails when 'latest' resolves to nothing" {
  INPUT_VERSION=latest STUB_GH_EMPTY=1 run "$ROOT/scripts/resolve-version.sh"
  [ "$status" -ne 0 ]
}
