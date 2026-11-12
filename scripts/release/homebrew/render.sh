#!/usr/bin/env bash
# Usage: render.sh <X.Y.Z> <sha256 or placeholder text>
# Prints scripts/release/homebrew/berth.rb with {{VERSION}} and {{SHA256}} filled in.
set -euo pipefail

version="${1:-}"
sha256="${2:-}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ || -z "$sha256" ]]; then
    echo "usage: $0 <X.Y.Z> <sha256>" >&2
    exit 64
fi

template="$(cat "$(dirname "$0")/berth.rb")"
template="${template//\{\{VERSION\}\}/$version}"
echo "${template//\{\{SHA256\}\}/$sha256}"
