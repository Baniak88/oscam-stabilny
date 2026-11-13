#!/bin/sh
# OSCam Stability installer for OpenATV (opkg)
set -eu

REPO="Baniak88/oscam-stabilny"
API="https://api.github.com/repos/$REPO/releases/latest"
TMPDIR="$(mktemp -d /tmp/oscam-stability.XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT HUP INT TERM

fail() { echo "ERROR: $*" >&2; exit 1; }
[ "$(id -u)" -eq 0 ] || fail "Run as root."
command -v opkg >/dev/null 2>&1 || fail "This receiver does not have opkg (OpenATV required)."
command -v tar >/dev/null 2>&1 || fail "tar is required."
command -v sha256sum >/dev/null 2>&1 || fail "sha256sum is required."

if command -v curl >/dev/null 2>&1; then
  get() { curl -fLsS --connect-timeout 15 --max-time 120 "$1" -o "$2"; }
elif command -v wget >/dev/null 2>&1; then
  get() { wget -q -T 120 -O "$2" "$1"; }
else
  fail "Install curl or wget first."
fi

echo "Checking latest GitHub release..."
get "$API" "$TMPDIR/release.json" || fail "No accessible GitHub release. Publish a compiled .ipk in Releases first."
# GitHub release assets are identified by a stable filename, not arbitrary JSON parsing.
ASSET="oscam-stability_1.3.0_all.ipk"
URL="https://github.com/$REPO/releases/latest/download/$ASSET"
SUMURL="$URL.sha256"
get "$URL" "$TMPDIR/$ASSET" || fail "Release asset $ASSET is missing. Upload the compiled .ipk to GitHub Releases."
get "$SUMURL" "$TMPDIR/$ASSET.sha256" || fail "Missing checksum file $ASSET.sha256. Refusing unverified installation."
EXPECTED="$(awk 'NR==1 {print $1}' "$TMPDIR/$ASSET.sha256")"
ACTUAL="$(sha256sum "$TMPDIR/$ASSET" | awk '{print $1}')"
[ "$EXPECTED" = "$ACTUAL" ] || fail "SHA256 mismatch, refusing installation."

BACKUP="/tmp/oscam-config-$(date +%Y%m%d-%H%M%S).tar.gz"
if [ -d /etc/tuxbox/config ]; then
  tar -czf "$BACKUP" -C /etc/tuxbox config || fail "Could not back up configuration."
  echo "Configuration backup: $BACKUP"
else
  echo "No /etc/tuxbox/config directory to back up."
fi
echo "Installing $ASSET..."
opkg install "$TMPDIR/$ASSET" || fail "opkg installation failed; backup (if created): $BACKUP"
echo "Installed. Select/restart oscam-stability in the Softcam menu."
echo "Backup (if created): $BACKUP"
