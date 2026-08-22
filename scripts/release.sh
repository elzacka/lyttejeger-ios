#!/bin/bash
#
# One command from a clean tree to a build in App Store Connect.
#
#   scripts/release.sh            archive, upload, tag, create the GitHub release
#   scripts/release.sh --dry-run  stop after export and verify the signing identity
#
# Every step is a gate. The script stops at the first failure rather than
# leaving a half-finished release behind.

set -euo pipefail

cd "$(dirname "$0")/.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'

step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
abort() { printf '\n\033[31mAvbrutt: %s\033[0m\n' "$1" >&2; exit 1; }

# 1. What does App Store Connect actually hold?
step "Versjonsstatus"
if ! swift scripts/asc-status.swift; then
    abort "versjonssjekken feilet. Bump CURRENT_PROJECT_VERSION i project.yml, eller rett opp nøkkelen."
fi

VERSION=$(grep 'MARKETING_VERSION:' project.yml | head -1 | sed 's/.*"\(.*\)".*/\1/')
BUILD=$(grep 'CURRENT_PROJECT_VERSION:' project.yml | head -1 | sed 's/.*"\(.*\)".*/\1/')
TAG="v${VERSION}-build${BUILD}"
# Paths carry the tag, so nothing is ever overwritten or deleted and every
# archive stays on disk as its own record.
ARCHIVE="build/${TAG}.xcarchive"
EXPORT_DIR="build/${TAG}"

# 2. Nothing unsaved, nothing unpushed. A release must be reproducible from the remote.
step "Git-status"
[[ -z "$(git status --porcelain)" ]] || abort "arbeidstreet er ikke rent. Commit eller forkast endringene først."
git fetch --quiet origin main
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || abort "HEAD er ikke lik origin/main. Push først."
git rev-parse "$TAG" >/dev/null 2>&1 && abort "taggen $TAG finnes allerede."
echo "Rent tre, i synk med origin/main."

# 3. Regenerate, then re-check the device family. xcodegen defaults to iPhone+iPad
#    and has silently reintroduced "1,2" before, which makes App Store Connect
#    demand iPad screenshots.
step "Genererer prosjekt"
xcodegen generate
if grep TARGETED_DEVICE_FAMILY Lyttejeger.xcodeproj/project.pbxproj | grep -qv '= 1;'; then
    grep -n TARGETED_DEVICE_FAMILY Lyttejeger.xcodeproj/project.pbxproj
    abort "TARGETED_DEVICE_FAMILY er ikke 1 overalt. Appen er kun for iPhone."
fi
echo "iPhone-only bekreftet."

# 4. Tests, on the same destination CI uses.
step "Tester"
xcodebuild -project Lyttejeger.xcodeproj -scheme Lyttejeger \
    -sdk iphonesimulator -destination "$DESTINATION" \
    -testLanguage nb -testRegion NO \
    -only-testing:LyttejegerTests \
    -only-testing:LyttejegerUITests/LyttejegerUITests \
    CODE_SIGNING_ALLOWED=NO test | tail -20

# 5. Archive. Signs with the development identity; distribution re-signing
#    happens at export, which is why -allowProvisioningUpdates is on both.
step "Arkiverer $VERSION (build $BUILD)"
[[ -e "$ARCHIVE" ]] && abort "$ARCHIVE finnes allerede. Flytt eller slett den selv."
[[ -e "$EXPORT_DIR" ]] && abort "$EXPORT_DIR finnes allerede. Flytt eller slett den selv."
xcodebuild archive \
    -project Lyttejeger.xcodeproj -scheme Lyttejeger \
    -configuration Release -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE" \
    -allowProvisioningUpdates | tail -5

# 6. Export. The dry run stops here so the identity can be inspected.
OPTIONS="$ARCHIVE/ExportOptions.plist"
cp ExportOptions.plist "$OPTIONS"
if $DRY_RUN; then
    /usr/libexec/PlistBuddy -c "Set :destination export" "$OPTIONS"
fi

step "Eksporterer"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportOptionsPlist "$OPTIONS" \
    -exportPath "$EXPORT_DIR" \
    -allowProvisioningUpdates | tail -5

if $DRY_RUN; then
    step "Kontrollerer signering"
    unzip -q "$EXPORT_DIR/Lyttejeger.ipa" -d "$EXPORT_DIR/unzipped"
    codesign -dvvv "$EXPORT_DIR/unzipped/Payload/Lyttejeger.app" 2>&1 | grep Authority | head -3
    printf '\nTørrkjøring ferdig. Forvent "Authority=Apple Distribution" over.\n'
    printf 'Kjør uten --dry-run for å laste opp.\n\n'
    exit 0
fi

# 7. Record what was uploaded. This is the answer to "what is in ASC" that the
#    repo could not give before.
step "Tagger $TAG"
NOTES=$(awk "/^## ${VERSION}\$/{flag=1; next} /^## /{flag=0} flag" CHANGELOG.md)
[[ -n "$NOTES" ]] || abort "fant ingen seksjon for $VERSION i CHANGELOG.md."

git tag -a "$TAG" -m "$VERSION (build $BUILD)"
git push origin "$TAG"
gh release create "$TAG" --title "$VERSION (build $BUILD)" --notes "$NOTES"

printf '\n\033[32mLastet opp: %s (build %s)\033[0m\n' "$VERSION" "$BUILD"
printf 'Neste steg i App Store Connect, manuelt:\n'
printf '  1. Vent på e-post om at builden er klar i TestFlight\n'
printf '  2. Legg inn skjermbilder\n'
printf '  3. Lim inn "What'"'"'s New" fra CHANGELOG.md (seksjon %s)\n' "$VERSION"
printf '  4. Send til vurdering\n\n'
