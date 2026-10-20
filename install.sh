#!/usr/bin/env bash
# Usage: curl -fsSL https://raw.githubusercontent.com/LunabeeStudio/berth/main/install.sh | bash
# Env: BERTH_INSTALL_DIR (default ~/.local/bin)
# Test overrides: BERTH_RELEASE_URL, BERTH_UNAME_S, BERTH_UNAME_M
set -euo pipefail

work=""
staged=()
cleanup() {
    [[ -z "$work" ]] || rm -rf "$work"
    [[ ${#staged[@]} -eq 0 ]] || rm -f "${staged[@]}"
}

main() {
    local os="${BERTH_UNAME_S:-$(uname -s)}"
    local arch="${BERTH_UNAME_M:-$(uname -m)}"
    if [[ -z "${BERTH_UNAME_M:-}" && "$arch" != "arm64" && "$(sysctl -in hw.optional.arm64 2>/dev/null || true)" == "1" ]]; then
        arch="arm64"
    fi
    if [[ "$os" != "Darwin" || "$arch" != "arm64" ]]; then
        echo "berth supports only macOS on Apple silicon (Darwin arm64), found $os $arch" >&2
        exit 1
    fi

    local base="${BERTH_RELEASE_URL:-https://github.com/LunabeeStudio/berth/releases/latest/download}"
    local dir="${BERTH_INSTALL_DIR:-$HOME/.local/bin}"
    local archive="berth-macos-arm64.tar.gz"
    local binaries=(berth berth-bar)

    work="$(mktemp -d)"
    trap cleanup EXIT

    echo "Downloading $archive"
    curl -fsSL "$base/$archive" -o "$work/$archive"
    curl -fsSL "$base/$archive.sha256" -o "$work/$archive.sha256"

    if ! (cd "$work" && shasum -a 256 -c "$archive.sha256" >/dev/null 2>&1); then
        echo "checksum mismatch for $archive, nothing installed" >&2
        exit 1
    fi

    mkdir -p "$work/unpack"
    tar -xzf "$work/$archive" -C "$work/unpack" "${binaries[@]}"

    mkdir -p "$dir"
    dir="$(cd "$dir" && pwd)"

    local name file i
    for name in "${binaries[@]}"; do
        file="$(mktemp "$dir/.$name.XXXXXX")"
        staged+=("$file")
        cp "$work/unpack/$name" "$file"
        chmod 755 "$file"
    done
    for i in "${!binaries[@]}"; do
        mv -f "${staged[$i]}" "$dir/${binaries[$i]}"
    done

    echo "Installed to $dir"
    "$dir/berth" --version

    case ":$PATH:" in
        *":$dir:"*) ;;
        *)
            echo
            echo "$dir is not on your PATH. Add it to ~/.zshrc:"
            echo "  export PATH=\"$dir:\$PATH\""
            ;;
    esac

    echo
    echo "Next steps:"
    echo "  berth prepare <AVD>   # once per AVD: saves the clean snapshot (about 30 s)"
    echo "  berth status          # starts the daemon, writes the default config"
}

main "$@"
