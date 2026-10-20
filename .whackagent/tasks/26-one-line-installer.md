---
issue: 26
phase: validated
type: feature
wiki: [[release]]
note: User request (2026-10-20): One line installer in readme. Grilled unattended by autopilot.
created: 2026-10-20
---

## Context / Decisions

User request (2026-10-20): "One line installer in readme". Today the README Install section starts with `mkdir -p ~/.local/bin && curl … | tar -xz -C ~/.local/bin`. It skips the checksum, says nothing when `~/.local/bin` is not on `PATH`, and overwrites the binaries in place. The repository is public, and every release publishes `berth-macos-arm64.tar.gz` and `berth-macos-arm64.tar.gz.sha256` under the stable `releases/latest/download/` permalink.

Decisions:
- **One line.** `curl -fsSL https://raw.githubusercontent.com/LunabeeStudio/berth/main/install.sh | bash`. The script lives at the repository root as `install.sh`, executable, so the URL stays short. It is served from `main`, not attached to releases: the release workflow stays unchanged. (autopilot assumption)
- **What the script does**, with `set -euo pipefail` and nothing written outside the install directory and a temporary directory:
  1. Refuses to run on anything but macOS on Apple silicon (`uname -s` = `Darwin`, `uname -m` = `arm64`), with a message that names the only supported platform.
  2. Downloads the archive and its `.sha256` from `https://github.com/LunabeeStudio/berth/releases/latest/download/` into a `mktemp -d` directory, removed on exit.
  3. Checks the archive with `shasum -a 256 -c`. A mismatch stops the install, and nothing is replaced.
  4. Installs `berth` and `berth-bar` into `${BERTH_INSTALL_DIR:-$HOME/.local/bin}` (created if missing). Each binary goes in by `mv` from a temporary file in that same directory, so a running daemon or `berth-bar` keeps its old file, the same rule as `berth update`.
  5. Prints the installed version (`berth --version`).
  6. When the install directory is not on `PATH`, prints the line to add to `~/.zshrc`.
  7. Prints the next steps: `berth prepare <AVD>`, then `berth status`.
- **No sudo, no daemon start, no login item.** Those stay explicit commands in the README. (autopilot assumption, YAGNI)
- **Re-running it** installs the latest release over the current one. That is how to reinstall; `berth update` stays the way to update.
- **README.** The Install section opens with the one line. The manual `curl | tar` line stays below it as the no-script alternative, along with `BERTH_INSTALL_DIR` and the PATH note. "From source" is unchanged.
- **Wiki.** `release` lists `install.sh` among the consumers of the asset permalink.

## Acceptance criteria

- `install.sh` exists at the repository root, is executable, and passes `bash -n`.
- `curl -fsSL https://raw.githubusercontent.com/LunabeeStudio/berth/main/install.sh | bash` installs the latest release's `berth` and `berth-bar` into `~/.local/bin` once this is merged on `main`.
- With `BERTH_INSTALL_DIR=<dir>`, the script installs into `<dir>` (creating it) and touches no other install directory.
- The script verifies the archive's SHA-256 against the release's `.sha256` file. On a mismatch it stops with an error, and the binaries already installed stay unchanged.
- On a platform other than macOS arm64, the script stops with a message naming the supported platform and installs nothing.
- When the install directory is not on `PATH`, the script prints the line to add to the shell profile.
- The script ends by printing the installed version and the next steps (`berth prepare <AVD>`, `berth status`).
- Running the script while the daemon runs leaves the running daemon working: binaries are replaced by rename, not overwritten in place.
- The README Install section starts with the one-line command and keeps the manual `curl | tar` alternative.

## Implementation

Autopilot run, 2026-10-20. One brick, then 2 autofix rounds.

- `install.sh` at the repository root, executable, bash with `set -euo pipefail`. The body is in `main`, and the file ends with `main "$@"`, so a cut-off download runs nothing.
- Platform check: `Darwin` + `arm64`. The script also accepts `sysctl -in hw.optional.arm64` = `1`, so a Rosetta shell is not refused.
- Download and check: the archive and its `.sha256` come from `releases/latest/download/` into a `mktemp -d` dir, then `shasum -a 256 -c`. A mismatch prints `checksum mismatch …, nothing installed` and exits 1.
- Install: `${BERTH_INSTALL_DIR:-$HOME/.local/bin}`, made absolute. `berth` and `berth-bar` are both staged in that dir first, then both renamed with `mv -f`. The EXIT trap removes the work dir and any staged file.
- Output: `berth --version`, the PATH line when the dir is not on `PATH`, and the next steps.
- Test overrides, named in the header: `BERTH_RELEASE_URL`, `BERTH_UNAME_S`, `BERTH_UNAME_M`.
- README `## Install`:
  - opens with the one line plus prepare/status, and a paragraph on what it does
  - a fenced `| BERTH_INSTALL_DIR=<dir> bash` example
  - "Without the script:" keeps the manual `curl | tar` line
- Wiki `release`: `install.sh` is listed as a consumer of the asset permalink.

## Review

Round `validation (autopilot)`. LENSES: style ✓ · elegance ✓ · structure ✓ · correctness ✓.

- Pass 1: 9 minor findings, all fixed.
  - stage both binaries, then rename both
  - trap cleans up staged files
  - `main` wrapper against a truncated pipe
  - absolute dir (relative path, trailing slash)
  - test overrides documented
  - Rosetta accepted
  - wiki `release` updated
  - README shows where `BERTH_INSTALL_DIR` goes
  - `binaries` array
- Pass 2: 1 minor (README fenced block), fixed.
- Pass 3: clean.

## Verification

- `bash -n install.sh` ✅, also under macOS `/bin/bash` 3.2. shellcheck is not installed.
- Real network, latest release (0.2.0), into a temp dir, through `cat install.sh | bash`: both binaries installed with mode 755, `berth --version` printed `0.2.0`, and the PATH line and next steps were printed. ✅ Run again by the PM on the final script.
- Checksum mismatch (`BERTH_RELEASE_URL=file://…`, bad `.sha256`): exit 1, the existing binaries are byte-identical, and no stray file is left in the dir. ✅
- Platform: `BERTH_UNAME_S/M` = `Linux x86_64` and `Darwin x86_64` both exit 1 with the Darwin arm64 message, and nothing is created. A `uname` stub reporting x86_64 with the real sysctl returning 1 installs (Rosetta path). Real Rosetta was not tested: this Mac has no x86_64 execution. ✅
- Rename install: after a reinstall the path gets a new inode, while an fd held open on the old file keeps the old inode at full size. ✅
- Truncated pipe (`head -c 900 install.sh | bash`): syntax error, exit 2, nothing run or created. ✅
- Relative `BERTH_INSTALL_DIR` gives absolute output. A trailing slash already on PATH prints no hint. ✅
- The user's real `~/.local/bin` was never touched.
- Not provable before merge: the raw `main` URL serves `install.sh` only once this is on `main`.

## Feedback
