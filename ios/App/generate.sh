#!/usr/bin/env bash
# Regenerates FatwaBot.xcodeproj from project.yml.
#
# Use this instead of calling `xcodegen generate` directly. The project file is
# generated and gitignored, so anything set in Xcode's UI — signing team above
# all — is destroyed on the next generate. Keeping the team in a local, ignored
# file is what makes it survive.
#
# Set your team once:
#   echo 'DEVELOPMENT_TEAM=XXXXXXXXXX' > ios/App/Local.env
#
# Find the ID in Xcode → Settings → Accounts → your team, or at
# developer.apple.com → Membership. It is not a secret (it ships inside every
# signed binary), but it is per-developer, so it stays out of the repo.
set -euo pipefail
cd "$(dirname "$0")"

[ -f Local.env ] && set -a && . ./Local.env && set +a

# XcodeGen substitutes ${DEVELOPMENT_TEAM} and has no notion of a default — an
# unset variable is written through literally, which Xcode then shows as a
# team named "${DEVELOPMENT_TEAM}". Defaulting to empty keeps a fresh clone
# behaving exactly as before.
export DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}"

xcodegen generate
if [ -n "$DEVELOPMENT_TEAM" ]; then
  echo "✓ signing team: $DEVELOPMENT_TEAM"
else
  echo "• no signing team set — create ios/App/Local.env to assign one (see this script's header)"
fi
