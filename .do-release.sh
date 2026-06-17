#!/bin/sh
set -eu

VERSION=${1:-}

if [ -z "$VERSION" ]; then
  echo "Usage: ./.do-release.sh <version>" >&2
  echo "Example: ./.do-release.sh 1.0.0" >&2
  exit 1
fi

VERSION=${VERSION#v}

echo "Creating release for ${VERSION}"

if [ -n "$(git status --porcelain)" ]; then
  echo "Working tree is not clean. Commit or stash changes before release." >&2
  exit 1
fi

UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true)
if [ -z "$UPSTREAM" ]; then
  echo "No upstream configured for $(git rev-parse --abbrev-ref HEAD). Set upstream before release." >&2
  exit 1
fi

if ! git fetch --quiet; then
  echo "Failed to fetch remote updates. Check your network or remote access." >&2
  exit 1
fi

set -- $(git rev-list --left-right --count "${UPSTREAM}...HEAD")
BEHIND_COUNT=$1
AHEAD_COUNT=$2

if [ "$BEHIND_COUNT" -ne 0 ] || [ "$AHEAD_COUNT" -ne 0 ]; then
  echo "Branch is not in sync with ${UPSTREAM} (behind ${BEHIND_COUNT}, ahead ${AHEAD_COUNT})." >&2
  echo "Pull/push until the branch matches upstream before release." >&2
  exit 1
fi

if git rev-parse -q --verify "refs/tags/v${VERSION}" >/dev/null; then
  echo "Tag v${VERSION} already exists. Aborting." >&2
  exit 1
fi

git tag -a "v${VERSION}" -m "Release version ${VERSION}"
git push origin "v${VERSION}"
