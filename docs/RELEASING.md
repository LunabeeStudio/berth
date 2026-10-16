# Releasing

A release is a `vX.Y.Z` tag. Pushing it runs the Release workflow, which tests, builds `berth` and `berth-bar` for macOS arm64, and publishes a GitHub release with `berth-macos-arm64.tar.gz` and its `.sha256`. The version comes from the tag; nothing in the source needs editing for it.

## Steps

1. Check that main is green and everything you want to ship is merged.
2. Set the new version in both `claude-plugin/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`. Commit both in one change and merge it to main through a PR.
3. Tag that commit and push the tag:
   ```bash
   git tag vX.Y.Z <commit on main>
   git push origin vX.Y.Z
   ```
4. Watch the Release workflow in the Actions tab.
5. Open the release page and check that both assets are attached.

The workflow fails before publishing if the tag is not `vX.Y.Z` or if either plugin file holds a different version.

## If it fails

Nothing is published until the last step, so a failed run leaves no release. Delete the tag, fix the cause, and tag again:

```bash
git push --delete origin vX.Y.Z
git tag -d vX.Y.Z
```

If a release was already created, delete it on GitHub before re-tagging.
