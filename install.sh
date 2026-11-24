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
    if [[ "$os" != "Darwin" || ( "$arch" != "arm64" && "$arch" != "x86_64" ) ]]; then
        echo "berth supports only macOS (Darwin arm64 or x86_64), found $os $arch" >&2
        exit 1
    fi

    local base="${BERTH_RELEASE_URL:-https://github.com/LunabeeStudio/berth/releases/latest/download}"
    local dir="${BERTH_INSTALL_DIR:-$HOME/.local/bin}"
    local archive="berth-macos-universal.tar.gz"
    local binaries=(berth berth-bar)

    work="$(mktemp -d)"
    trap cleanup EXIT

    echo "Downloading $archive"
    # A network failure stops here with curl's own error. 000 = a file:// URL (tests), which has no HTTP status.
    local status
    status="$(curl -sSL -w '%{http_code}' "$base/$archive" -o "$work/$archive")"
    if [[ "$status" == 404 ]]; then
        # Releases before 0.8.0 carry only the arm64 archive.
        if [[ "$arch" != "arm64" ]]; then
            echo "no $archive in the release: berth runs on Intel Macs from 0.8.0" >&2
            exit 1
        fi
        archive="berth-macos-arm64.tar.gz"
        echo "Downloading $archive"
        curl -fsSL "$base/$archive" -o "$work/$archive"
    elif [[ "$status" != 200 && "$status" != 000 ]]; then
        echo "downloading $archive failed: HTTP $status" >&2
        exit 1
    fi
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
