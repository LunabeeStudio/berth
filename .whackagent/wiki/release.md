# Release

GitHub Releases = install channel. Flow for humans: `docs/RELEASING.md`.

- **Trigger**: push tag `vX.Y.Z` → `.github/workflows/release.yml`. Job `build` (macos-26, default Xcode, `contents: read`): tag regex + tag == plugin.json == marketplace.json version, `swift test`, `scripts/release/package.sh`, upload artifact. Job `publish` (ubuntu, `contents: write`, tag only): `gh release create --generate-notes --verify-tag`.
- **PR dry run**: PR touching workflow, `scripts/release/**`, `Package.swift` or `Version.swift` → `build` job with version `0.0.0`, artifact only, no release.
- **Version**: `BerthCore/Version.swift` `BerthVersion.current` = `"dev"` in repo. `package.sh` stamps tag version (sed on `"dev"` literal), restores file on exit → tree stays clean. `berth --version` reads it. Plugin version ≠ CLI version in source; aligned per release by the tag check.
- **Assets** (stable names → `releases/latest/download/<asset>` permalink, README + auto update rely on it): `berth-macos-arm64.tar.gz` (`berth` + `berth-bar` at root), `berth-macos-arm64.tar.gz.sha256` (`shasum -a 256`, relative name → `shasum -c` works).
- arm64 only. No signing/notarization: curl download has no quarantine xattr, ad-hoc linker signature runs.
- Actions pinned to commit SHAs, checkout `persist-credentials: false`.
