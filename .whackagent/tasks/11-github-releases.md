---
issue: 11
phase: validated
wiki: [[architecture]], [[cli]], [[release]]
note: Blocks #13 (auto update reads the version and the asset names set here).
created: 2026-10-16
---

## Context / Decisions

Source: issue #11 body, user request "release github" (`/wa-autopilot --afk`, 2026-10-16). Grilled unattended: every decision below tagged `(autopilot assumption)` was picked by the agent and waits for the user's confirmation.

Goal: users install a prebuilt berth from GitHub Releases instead of building from source.

- Pushing a tag `vX.Y.Z` runs a GitHub Actions workflow (`.github/workflows/release.yml`). It runs the tests, builds release binaries, packages them and publishes a GitHub Release with generated notes. A tag that is not `vX.Y.Z` (three numbers) fails the workflow before anything is published. (autopilot assumption)
- The version comes from the tag. A new `Sources/BerthCore/Version.swift` holds the version string, `dev` in the repository. The packaging step stamps the tag's version into it before building. `berth --version` reads it, so local builds print `dev`. It lives in BerthCore so the daemon and the auto update (#13) can read it too. (autopilot assumption)
- Packaging is one script, `scripts/release/package.sh <version> <out dir>`: stamp version, `swift build -c release`, archive, checksum. The workflow calls it, and a developer can run it locally. It restores `Version.swift`, so it leaves the working tree clean. (autopilot assumption)
- Assets have stable names: `berth-macos-arm64.tar.gz` (holding `berth` and `berth-bar` at the archive root) and `berth-macos-arm64.tar.gz.sha256` (`shasum -a 256` output format). Stable names make `https://github.com/LunabeeStudio/berth/releases/latest/download/<asset>` a permanent link, used by the README and by #13. (autopilot assumption)
- Apple silicon (arm64) only: the README already states it. No Intel or universal build. (autopilot assumption)
- No code signing or notarization: a `curl` download carries no quarantine attribute, and the arm64 linker's ad-hoc signature is enough to run. Notarization needs Apple Developer secrets: out of scope. (autopilot assumption)
- The workflow also runs on pull requests that change it or the packaging script: tests, build, package, upload the archive as a workflow artifact, never publish. That proves the pipeline without pushing a tag. (autopilot assumption)
- Runner: a GitHub-hosted macOS arm64 runner whose Xcode builds this Swift 6 package; the implementer picks the image and Xcode version that build green and records them.
- Publishing uses `gh release create` (preinstalled on runners, `GITHUB_TOKEN` with `contents: write`), no third-party action.
- README "Install" gives the `curl … | tar` one-liner into `~/.local/bin`, and keeps the source build as an alternative.
- Release flow documented in `docs/RELEASING.md`; `.whackagent/config.md` `release.doc` points at it so `/wa-release` follows it.
- Out of scope (YAGNI): Homebrew tap, Intel build, changelog file, signing, prereleases.

Prior art:
- GoReleaser: built for Go, prebuilt-binary mode works but adds a tool and a config for a 10-line job. Not used.
- `softprops/action-gh-release`: third-party action doing what the preinstalled `gh release create` does. Not used.

## Acceptance criteria

- A local `swift build` gives a `berth` whose `berth --version` prints `dev`.
- `scripts/release/package.sh 1.2.3 <dir>` produces `<dir>/berth-macos-arm64.tar.gz` and `<dir>/berth-macos-arm64.tar.gz.sha256`, and leaves the git working tree clean.
- The archive extracts to `berth` and `berth-bar` at its root; the extracted `berth --version` prints `1.2.3`.
- `shasum -a 256 -c berth-macos-arm64.tar.gz.sha256`, run in that directory, reports OK.
- On a pull request that changes the release workflow, the workflow runs green (tests, build, package, artifact upload) and creates no release.
- Pushing tag `v1.2.3` on the repository creates GitHub Release `v1.2.3` with both assets and generated notes.
- A tag that does not match `vX.Y.Z` makes the workflow fail before publishing.
- README "Install" shows the one-liner downloading `releases/latest/download/berth-macos-arm64.tar.gz` into `~/.local/bin`.
- `docs/RELEASING.md` describes how to cut a release, and `.whackagent/config.md` `release.doc` points at it.

## Implementation

- Brick 1: `Sources/BerthCore/Version.swift` (`BerthVersion.current = "dev"`, shared contract with #13); `Berth.swift` `version:` reads it. `scripts/release/package.sh <X.Y.Z> <out>`: validates version (exit 64), resolves out dir from caller cwd, stamps `Version.swift`, builds `berth` + `berth-bar` release arm64, tars both at root, writes `.sha256`, restores `Version.swift` on exit (trap on a mktemp copy).
- Decision taken while coding: the CLI version is now `dev`, so `PluginSyncTests` no longer ties the plugin version to it. The test checks that plugin.json and marketplace.json agree, and the workflow checks that the tag equals both. (autopilot assumption)
- Brick 2: `.github/workflows/release.yml`, two jobs. `build` (macos-26, image default Xcode, `contents: read`, checkout `persist-credentials: false`) resolves the version (tag regex, plugin version match; `0.0.0` on PRs), runs `swift test` and `package.sh`, and uploads the artifact. `publish` (ubuntu-latest, tag only, `contents: write`) downloads it and runs `gh release create --generate-notes --verify-tag`. Actions are pinned to commit SHAs.
- README Install = curl one-liner into `~/.local/bin`, "From source" subsection; Menu bar section runs `berth-bar` from PATH. `docs/RELEASING.md` = release flow; `.whackagent/config.md` `release.doc` points at it. `.gitignore` gets `dist/`.
- Build ✅ · tests ✅ (all suites).

## Review

### Round validation (autopilot) — 2026-10-16

Lenses: style ✓ · elegance ✓ · structure ✓ · correctness ✓. Verdict: clean after 1 autofix round.

Fixed by autofix:
- critical, correctness: `permissions` held an expression, which GitHub rejects. Split into `build` (read) and `publish` (write, tag only).
- minor, correctness: actions pinned to SHAs; checkout `persist-credentials: false`.
- minor, correctness: Xcode glob could pick a beta; the image default Xcode is used now.
- minor, correctness: PR `paths` filter now includes `Version.swift`.
- minor, correctness: `package.sh` resolved a relative out dir against the repo root.
- minor, correctness: `dist/` added to `.gitignore`.
- minor, structure: README Menu bar section still built from source.
- minor, style: `PluginSyncTests` uses `#require`; unused `@testable import` removed.

## Verification

- ✅ `swift build` → `berth --version` prints `dev`.
- ✅ `package.sh 1.2.3 <dir>` → archive + `.sha256`; `shasum -a 256 -c` OK; working tree clean afterwards.
- ✅ Extracted archive holds `berth` and `berth-bar`; `berth --version` prints `1.2.3`.
- ✅ `package.sh` run from another cwd with a relative out dir writes there.
- ✅ Tag check logic run locally: `v0.1.0` passes, `v0.2.0` fails (plugin version mismatch), `v1.2` fails (regex).
- ✅ PR #14 run of the Release workflow on `macos-26` (run 38912997948): `build` green in 2m33s, `publish` skipped, no release created. Artifact `berth-macos-arm64`: `shasum -a 256 -c` OK, holds `berth` + `berth-bar`, `berth --version` prints `0.0.0`.
- ❌ not run by agent: pushing a real tag creating a release (needs a human to tag).

## Feedback
