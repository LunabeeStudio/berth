---
issue: 11
phase:
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

## Review

## Verification

## Feedback
