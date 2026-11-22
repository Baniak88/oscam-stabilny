#!/bin/sh
# OSCam Stability installer for OpenATV receivers (architecture-aware).
# Installs only a verified, published package for a supported CPU.
# Does not replace, stop, start or select an existing OSCam service.
set -eu

REPO=Baniak88/oscam-stabilny
PKGNAME=enigma2-softcams-oscam-stability
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" = 0 ] || fail "Run as root on the receiver."
command -v opkg >/dev/null 2>&1 || fail "opkg is missing; an OpenATV/opkg image is required."
command -v sha256sum >/dev/null 2>&1 || fail "sha256sum is required."
command -v tar >/dev/null 2>&1 || fail "tar is required."
if command -v wget >/dev/null 2>&1; then
    get() { wget -T 90 -O "$2" "$1"; }
elif command -v curl >/dev/null 2>&1; then
    get() { curl -fL --connect-timeout 20 --max-time 120 -o "$2" "$1"; }
else
    fail "wget or curl is required."
fi

MODEL=$(cat /proc/stb/info/model 2>/dev/null || printf unknown)
ARCH=$(uname -m)
printf 'Receiver model: %s\nCPU architecture: %s\n' "$MODEL" "$ARCH"

# This mapping is intentionally explicit. A published ARMv7 preview is
# NOT an ARM64 build, and a matching CPU does not guarantee device support.
case "$ARCH" in
    armv7*|armhf)
        TAG=h11s-armv7-preview-1
        ASSET=oscam-stability_1.3.0_armv7-static-preview.ipk
        ;;
    aarch64|arm64)
        fail "ARM64 detected. No verified ARM64 release is published yet; nothing installed."
        ;;
    *)
        fail "No verified package for architecture $ARCH; nothing installed."
        ;;
esac

if [ -e /etc/init.d/softcam.oscam-stability ] || [ -L /etc/init.d/softcam.oscam-stability ]; then
    fail "OSCam Stability service already exists. Refusing to overwrite it."
fi
if opkg list-installed | grep -q "^$PKGNAME "; then
    fail "OSCam Stability package already installed. Refusing to overwrite it."
fi

TMPDIR=$(mktemp -d /tmp/oscam-stability.XXXXXX) || fail "Cannot create temporary directory."
trap 'rm -rf "$TMPDIR"' EXIT HUP INT TERM
URL="https://github.com/$REPO/releases/download/$TAG/$ASSET"

printf 'Downloading published package: %s\n' "$TAG"
get "$URL" "$TMPDIR/$ASSET" || fail "Package download failed. Check GitHub Releases and receiver internet access."
get "$URL.sha256" "$TMPDIR/$ASSET.sha256" || fail "Checksum download failed. Refusing installation."

EXPECTED=$(awk 'NR==1 {print $1}' "$TMPDIR/$ASSET.sha256")
ACTUAL=$(sha256sum "$TMPDIR/$ASSET" | awk '{print $1}')
[ -n "$EXPECTED" ] && [ "$EXPECTED" = "$ACTUAL" ] || fail "SHA256 mismatch. Refusing installation."
printf 'SHA256 verification passed.\n'

# Preserve the original configuration on persistent storage.
BACKUPDIR=/root/oscam-stability-backup
mkdir -p "$BACKUPDIR" || fail "Cannot create backup directory."
chmod 700 "$BACKUPDIR"
# A fresh OpenATV installation may have no OSCam configuration at all.
# Back up any existing config locations, but do not create dummy credentials or
# refuse a side-by-side binary install just because /etc/tuxbox/config is absent.
FOUND_CONFIG=0
for CONFIGDIR in /etc/tuxbox/config /etc/tuxbox/config/oscam* /etc/oscam /var/tuxbox/config /var/tuxbox/config/oscam*; do
    [ -d "$CONFIGDIR" ] || continue
    [ -f "$CONFIGDIR/oscam.conf" ] || continue
    FOUND_CONFIG=1
    SAFE_NAME=$(printf '%s' "$CONFIGDIR" | tr '/' '_')
    BACKUP="$BACKUPDIR/config-before-stability-${SAFE_NAME}-$(date +%Y%m%d-%H%M%S).tar.gz"
    tar -czf "$BACKUP" -C / "${CONFIGDIR#/}" || fail "Configuration backup failed; nothing installed."
    chmod 600 "$BACKUP"
    printf 'Configuration backup: %s\n' "$BACKUP"
done
if [ "$FOUND_CONFIG" -eq 0 ]; then
    printf 'NOTICE: No existing oscam.conf was found in standard locations.\n'
    printf 'Installing the binary and service only. OSCam Stability will NOT start\n'
    printf 'until an authorized local OSCam configuration is supplied.\n'
fi

printf 'Installing side-by-side preview without force flags...\n'
opkg install "$TMPDIR/$ASSET" || fail "opkg failed. Do not force-overwrite the existing softcam."

BIN=/usr/lib/oscam-stability/oscam-arm
[ -x "$BIN" ] || fail "Package installed but OSCam binary missing. Do not start it."
if "$BIN" -V > "$TMPDIR/version.txt" 2>&1; then
    grep -E '^(Version|Compiler|DVB API support|Web interface support):' "$TMPDIR/version.txt" || cat "$TMPDIR/version.txt"
    printf 'Binary version test passed.\n'
else
    cat "$TMPDIR/version.txt"
    fail "Installed binary did not pass -V test. Do not select or start this service."
fi
printf 'OSCam Stability installed, but NOT started or selected.\n'
printf 'Your existing OSCam and reader configuration have not been changed by this installer.\n'
printf 'This is a preview build; receiver playback has not been validated.\n'
