#!/usr/bin/env bash
# release.sh — publish the version in ReagentTracker.toc as a GitHub release.
# Human keystroke only (`make release`); agents never run this.
#
# Steps: refuse unless on a clean, pushed main with an unused version tag ->
# make package -> commit the zip -> tag vX.Y.Z -> push -> gh release create.
# Release notes: $NOTES if set, otherwise a standard install blurb.
set -euo pipefail

ADDON=ReagentTracker
VERSION=$(sed -n 's/^## Version: *//p' "$ADDON/$ADDON.toc")
TAG="v$VERSION"
ZIP="release/$ADDON-$VERSION.zip"
die() { echo "release: $*" >&2; exit 1; }

[ -n "$VERSION" ] || die "no '## Version:' line in $ADDON/$ADDON.toc"
[ "$(git rev-parse --abbrev-ref HEAD)" = main ] || die "not on main"
[ -z "$(git status --porcelain)" ] || die "working tree not clean — commit first"
git fetch -q --tags origin
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || die "main is not in sync with origin/main — push or pull first"
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  die "tag $TAG already exists — bump '## Version:' in $ADDON/$ADDON.toc"
fi

make package
git add "$ZIP"
git commit -qm "release: $TAG"
git tag -a "$TAG" -m "$ADDON $VERSION"
git push -q origin main "$TAG"

NOTES=${NOTES:-"Download **$ADDON-$VERSION.zip** below, unzip, and put the \`$ADDON\` folder in \`_forever_/Interface/AddOns\`. See the README for full install steps."}
gh release create "$TAG" "$ZIP" --title "Reagent Tracker $VERSION" --notes "$NOTES"
