#!/bin/bash
set -euo pipefail

usage() {
	cat <<'EOF'
Update this fork with the latest RuneLite upstream release tag.

Usage:
  ./update-runelite-tag.sh [options]

Options:
  -r, --remote <name>         Git remote to read tags from (default: upstream)
  -b, --branch <name>         Branch name to create for the merge
      --into-current-branch   Merge directly into the currently checked out branch
      --allow-dirty           Allow running with uncommitted changes
      --tag-regex <regex>     Regex used to select candidate tags
  -h, --help                  Show this help

Notes:
  - By default this script creates a new branch and merges the latest upstream tag into it.
  - Default tag regex matches runelite-parent-x.y.z and runelite-parent-x.y.z.w.
EOF
}

die() {
	echo "ERROR: $*" >&2
	exit 1
}

REMOTE="upstream"
TAG_REGEX='^runelite-parent-[0-9]+\.[0-9]+\.[0-9]+(\.[0-9]+)?$'
CUSTOM_BRANCH=""
INTO_CURRENT_BRANCH=0
ALLOW_DIRTY=0

while [[ $# -gt 0 ]]; do
	case "$1" in
	-r|--remote)
		[[ $# -ge 2 ]] || die "Missing value for $1"
		REMOTE="$2"
		shift 2
		;;
	-b|--branch)
		[[ $# -ge 2 ]] || die "Missing value for $1"
		CUSTOM_BRANCH="$2"
		shift 2
		;;
	--into-current-branch)
		INTO_CURRENT_BRANCH=1
		shift
		;;
	--allow-dirty)
		ALLOW_DIRTY=1
		shift
		;;
	--tag-regex)
		[[ $# -ge 2 ]] || die "Missing value for $1"
		TAG_REGEX="$2"
		shift 2
		;;
	-h|--help)
		usage
		exit 0
		;;
	*)
		die "Unknown argument: $1"
		;;
	esac
done

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Not inside a git repository"
git remote get-url "$REMOTE" >/dev/null 2>&1 || die "Remote '$REMOTE' does not exist"

CURRENT_BRANCH="$(git symbolic-ref --quiet --short HEAD || true)"
[[ -n "$CURRENT_BRANCH" ]] || die "Detached HEAD is not supported. Check out a branch first."

if [[ "$ALLOW_DIRTY" -eq 0 ]] && [[ -n "$(git status --porcelain)" ]]; then
	die "Working tree is not clean. Commit/stash changes, or use --allow-dirty."
fi

LATEST_TAG="$(
	git ls-remote --tags --refs "$REMOTE" \
		| awk '{print $2}' \
		| sed 's#refs/tags/##' \
		| awk -v regex="$TAG_REGEX" '$0 ~ regex' \
		| sort -V \
		| tail -n 1
)"

[[ -n "$LATEST_TAG" ]] || die "No upstream tags matched regex: $TAG_REGEX"

echo "Latest upstream tag: $LATEST_TAG (remote: $REMOTE)"
echo "Fetching tag object..."
git fetch "$REMOTE" "refs/tags/$LATEST_TAG:refs/tags/$LATEST_TAG"

if git merge-base --is-ancestor "$LATEST_TAG" HEAD; then
	echo "Current branch already contains $LATEST_TAG; no merge needed."
	exit 0
fi

if [[ "$INTO_CURRENT_BRANCH" -eq 1 ]]; then
	TARGET_BRANCH="$CURRENT_BRANCH"
	echo "Merging into current branch: $TARGET_BRANCH"
else
	TARGET_BRANCH="${CUSTOM_BRANCH:-update/runelite-$LATEST_TAG}"
	if git rev-parse --verify --quiet "$TARGET_BRANCH" >/dev/null; then
		die "Branch already exists: $TARGET_BRANCH (pick a different name with --branch)"
	fi
	echo "Creating update branch: $TARGET_BRANCH"
	git checkout -b "$TARGET_BRANCH"
fi

MERGE_MSG="Merge upstream RuneLite tag $LATEST_TAG"
if ! git merge --no-ff "$LATEST_TAG" -m "$MERGE_MSG"; then
	echo ""
	echo "Merge conflicts detected."
	echo "Resolve conflicts, then run:"
	echo "  git add <resolved-files>"
	echo "  git commit"
	exit 1
fi

echo ""
echo "Merge complete on branch: $TARGET_BRANCH"
echo "Next step: run ./sync-bronzeman.sh and validate the client build."
