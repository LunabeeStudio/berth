#!/usr/bin/env bash
# Usage: release.sh [X.Y.Z] [--yes] [--dry-run]
set -Eeuo pipefail

usage() {
    echo "usage: $0 [X.Y.Z] [--yes] [--dry-run]" >&2
    exit 64
}

semver_part="(0|[1-9][0-9]*)"
semver="^$semver_part\\.$semver_part\\.$semver_part\$"
version=""
assume_yes=false
dry_run=false
for arg in "$@"; do
    case "$arg" in
        --yes) assume_yes=true ;;
        --dry-run) dry_run=true ;;
        *)
            [[ -z "$version" && "$arg" =~ $semver ]] || usage
            version="$arg"
            ;;
    esac
done

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"

plugin_file="claude-plugin/.claude-plugin/plugin.json"
marketplace_file=".claude-plugin/marketplace.json"
assets=(berth-macos-arm64.tar.gz berth-macos-arm64.tar.gz.sha256)

current_step=""
tag=""
tag_created=false
draft_created=false
published=false
pr_branch=""
pr_url=""
next=""

fail() {
    echo "error: $*" >&2
    return 1
}

step() {
    current_step="$1"
    echo "==> $1"
}

on_error() {
    local status=$?
    ((BASH_SUBSHELL == 0)) || exit "$status"
    trap - ERR
    [[ -n "$current_step" ]] || exit "$status"
    echo "" >&2
    echo "FAILED at step: $current_step (exit $status)" >&2
    if [[ -n "$pr_branch" ]]; then
        echo "A version PR was left half done. Clean up:" >&2
        echo "  git switch main; git branch -D $pr_branch; git push --delete origin $pr_branch" >&2
        if [[ -n "$pr_url" ]]; then echo "  gh pr close $pr_url   (only if it is not merged)" >&2; fi
    fi
    if $published; then
        echo "Release $tag is live, do not delete it: open the bump PR to $next by hand." >&2
    elif $tag_created || $draft_created; then
        echo "Clean up before retrying:" >&2
        if $tag_created; then echo "  git push --delete origin $tag; git tag -d $tag" >&2; fi
        if $draft_created; then echo "  gh release delete $tag" >&2; fi
    fi
    exit "$status"
}
trap on_error ERR

plugin_versions() {
    echo "$(plutil -extract version raw "$plugin_file") $(plutil -extract plugins.0.version raw "$marketplace_file")"
}

versions_are() {
    [[ "$(plugin_versions)" == "$1 $1" ]]
}

next_minor() {
    local major minor
    IFS=. read -r major minor _ <<< "$1"
    echo "$major.$((minor + 1)).0"
}

lowest_plane_version() {
    [[ -n "${PLANE_API_KEY:-}" ]] || fail "no version given: pass X.Y.Z or export PLANE_API_KEY"
    local milestones
    milestones="$("$root/.github/board/wa-backlog" milestones)"
    python3 -c '
import json, re, sys
titles = [m["title"] for m in json.loads(sys.argv[1]) if m["open"] and re.fullmatch(sys.argv[2], m["title"])]
print(min(titles, key=lambda t: tuple(map(int, t.split(".")))) if titles else "")' "$milestones" "$semver"
}

check_tools() {
    local tool
    for tool in git gh swift plutil python3; do
        command -v "$tool" > /dev/null || fail "$tool is not on PATH: install it"
    done
    gh auth status > /dev/null 2>&1 || fail "gh is not authenticated: run 'gh auth login'"
    [[ "$(uname -s)" == "Darwin" && "$(uname -m)" == "arm64" ]] \
        || fail "release builds need macOS arm64 (this is $(uname -s) $(uname -m)): run it on an Apple silicon Mac"
}

check_main() {
    local branch
    branch="$(git rev-parse --abbrev-ref HEAD)"
    [[ "$branch" == "main" ]] || fail "on '$branch', not main: run 'git switch main'"
    [[ -z "$(git status --porcelain --untracked-files=normal)" ]] || fail "working tree is not clean: commit or stash your changes"
    git fetch --quiet origin main
    local ahead behind
    read -r ahead behind < <(git rev-list --left-right --count HEAD...origin/main)
    ((ahead == 0)) || fail "main is $ahead commit(s) ahead of origin/main: push or reset them"
    ((behind == 0)) || fail "main is $behind commit(s) behind origin/main: run 'git pull --ff-only'"
}

check_version_free() {
    git rev-parse -q --verify "refs/tags/$tag" > /dev/null && fail "tag $tag exists locally: run 'git tag -d $tag' if it is stale"
    local code=0
    git ls-remote --exit-code --tags origin "refs/tags/$tag" > /dev/null || code=$?
    ((code != 0)) || fail "tag $tag exists on origin: pick another version"
    ((code == 2)) || fail "could not read tags from origin (git exit $code)"
    local output
    if output="$(gh api "repos/{owner}/{repo}/releases/tags/$tag" 2>&1)"; then
        fail "release $tag already exists: pick another version"
    fi
    [[ "$output" == *"HTTP 404"* ]] || fail "could not look up release $tag: $output"
    output="$(gh release list --limit 200 --json tagName,isDraft --jq ".[] | select(.isDraft and .tagName == \"$tag\") | .tagName")"
    [[ -z "$output" ]] || fail "a draft release $tag exists: run 'gh release delete $tag' if it is stale"
    return 0
}

confirm() {
    local answer
    read -r -p "Proceed? [y/N] " answer || answer=""
    [[ "$answer" == [yY] ]] || fail "not confirmed, nothing changed"
}

version_pr() {
    local kind="$1" target="$2" message="$3"
    local branch="release/$kind-$target"
    pr_branch="$branch"
    git switch --quiet -c "$branch" main
    sed -i '' -E "s/(\"version\": \")[^\"]*(\")/\1$target\2/" "$plugin_file" "$marketplace_file"
    versions_are "$target" || fail "plugin versions are not $target after the edit"
    git add "$plugin_file" "$marketplace_file"
    git commit --quiet -m "$message"
    git push --quiet -u origin "$branch"
    pr_url="$(gh pr create --base main --head "$branch" --title "$message" \
        --body "Version $target, opened by scripts/release/release.sh.")"
    gh pr merge "$pr_url" --squash --delete-branch
    git switch --quiet main
    git pull --quiet --ff-only
    git branch --quiet -D "$branch" 2> /dev/null || true
    pr_branch=""
    pr_url=""
}

check_tools
check_main

if [[ -z "$version" ]]; then
    version="$(lowest_plane_version)"
    [[ -n "$version" ]] || fail "no open Plane module titled X.Y.Z: pass X.Y.Z"
    echo "Version $version (lowest open Plane module)"
fi
tag="v$version"
next="$(next_minor "$version")"
check_version_free

if versions_are "$version"; then
    set_plan="plugin versions already $version, no version PR"
else
    set_plan="open a PR setting plugin versions to $version and merge it"
fi

cat <<PLAN
Release $tag. Plan:
  1. $set_plan
  2. run swift test
  3. build berth-macos-arm64 with package.sh
  4. tag $tag and push it
  5. create draft release $tag
  6. upload ${assets[0]} and ${assets[1]}
  7. check both assets on the draft
  8. publish $tag as latest
  9. open a PR bumping plugin versions to $next and merge it
PLAN

if $dry_run; then
    echo "Dry run: nothing changed."
    exit 0
fi
$assume_yes || confirm

if versions_are "$version"; then
    step "1/9 plugin versions already $version"
else
    step "1/9 setting plugin versions to $version"
    version_pr set "$version" "Set version $version"
fi

step "2/9 swift test"
swift test

step "3/9 building assets"
dist="$(mktemp -d)"
trap 'rm -rf "$dist"' EXIT
scripts/release/package.sh "$version" "$dist"

step "4/9 tagging $tag"
git tag "$tag"
tag_created=true
git push --quiet origin "$tag"

step "5/9 creating draft release $tag"
gh release create "$tag" --draft --verify-tag --generate-notes --title "$tag"
draft_created=true

step "6/9 uploading assets"
gh release upload "$tag" "$dist/${assets[0]}" "$dist/${assets[1]}"

step "7/9 checking assets on the draft"
attached="$(gh release view "$tag" --json assets --jq '.assets[].name')"
for asset in "${assets[@]}"; do
    grep -qxF "$asset" <<< "$attached" || fail "$asset is missing on the draft $tag"
done

step "8/9 publishing $tag"
gh release edit "$tag" --draft=false --latest
published=true

step "9/9 bumping plugin versions to $next"
version_pr bump "$next" "Bump version to $next for the next release"

echo "Released $tag. main holds $next."
