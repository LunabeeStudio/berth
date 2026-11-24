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
archive="berth-macos-universal.tar.gz"
# The same archive under the name releases before 0.8.0 download: their auto update asks for it.
legacy="berth-macos-arm64.tar.gz"
arch=(--arch arm64 --arch x86_64)

original="$(mktemp)"
cp "$version_file" "$original"
trap 'cp "$original" "$version_file"; rm -f "$original"' EXIT

sed -i '' "s/\"dev\"/\"$version\"/" "$version_file"
grep -q "\"$version\"" "$version_file"

swift build -c release "${arch[@]}" --product berth
swift build -c release "${arch[@]}" --product berth-bar
bin="$(swift build -c release "${arch[@]}" --show-bin-path)"
for name in berth berth-bar; do
    archs="$(lipo -archs "$bin/$name")"
    if [[ " $archs " != *" arm64 "* || " $archs " != *" x86_64 "* ]]; then
        echo "$name holds '$archs', not arm64 and x86_64" >&2
        exit 1
    fi
done

COPYFILE_DISABLE=1 tar -czf "$out/$archive" -C "$bin" berth berth-bar
cp "$out/$archive" "$out/$legacy"
(cd "$out" && shasum -a 256 "$archive" > "$archive.sha256" && shasum -a 256 "$legacy" > "$legacy.sha256")
