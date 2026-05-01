#!/usr/bin/env bash
# Download and extract the graphql-cli release tarball matching $VERSION
# into $RUNNER_TEMP/graphql-cli. The directory is created fresh each call.
#
# Asset matrix mirrors graphql-analyzer's release.yml:
#   graphql-cli-x86_64-unknown-linux-gnu.tar.xz
#   graphql-cli-aarch64-unknown-linux-gnu.tar.xz
#   graphql-cli-x86_64-apple-darwin.tar.xz
#   graphql-cli-aarch64-apple-darwin.tar.xz
#   graphql-cli-x86_64-pc-windows-msvc.zip   (deferred; not handled here yet)
set -euo pipefail

: "${VERSION:?VERSION is required}"
: "${RUNNER_TEMP:?RUNNER_TEMP is required}"

target_dir="$RUNNER_TEMP/graphql-cli"
mkdir -p "$target_dir"

case "${RUNNER_OS:-}-${RUNNER_ARCH:-}" in
  Linux-X64)   asset="graphql-cli-x86_64-unknown-linux-gnu.tar.xz" ;;
  Linux-ARM64) asset="graphql-cli-aarch64-unknown-linux-gnu.tar.xz" ;;
  macOS-X64)   asset="graphql-cli-x86_64-apple-darwin.tar.xz" ;;
  macOS-ARM64) asset="graphql-cli-aarch64-apple-darwin.tar.xz" ;;
  *)
    echo "::error::Unsupported runner: ${RUNNER_OS:-?}-${RUNNER_ARCH:-?}" >&2
    exit 1
    ;;
esac

tag="graphql-analyzer-cli/v${VERSION}"
echo "Downloading $asset from $tag"

gh release download "$tag" \
  --repo trevor-scheer/graphql-analyzer \
  --pattern "$asset" \
  --dir "$target_dir"

tar -xJf "$target_dir/$asset" -C "$target_dir"
rm -f "$target_dir/$asset"
chmod +x "$target_dir/graphql"

"$target_dir/graphql" --version
