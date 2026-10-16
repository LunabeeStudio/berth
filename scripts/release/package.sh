#!/usr/bin/env bash
# Usage: package.sh <X.Y.Z> <out dir>
set -euo pipefail

version="${1:-}"
out="${2:-}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ || -z "$out" ]]; then
    echo "usage: $0 <X.Y.Z> <out dir>" >&2
    exit 64
fi

mkdir -p "$out"
out="$(cd "$out" && pwd)"

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"
version_file="Sources/BerthCore/Version.swift"
archive="berth-macos-arm64.tar.gz"

original="$(mktemp)"
cp "$version_file" "$original"
trap 'cp "$original" "$version_file"; rm -f "$original"' EXIT

sed -i '' "s/\"dev\"/\"$version\"/" "$version_file"
grep -q "\"$version\"" "$version_file"

swift build -c release --arch arm64 --product berth
swift build -c release --arch arm64 --product berth-bar
bin="$(swift build -c release --arch arm64 --show-bin-path)"

tar -czf "$out/$archive" -C "$bin" berth berth-bar
(cd "$out" && shasum -a 256 "$archive" > "$archive.sha256")
