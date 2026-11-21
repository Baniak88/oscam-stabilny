#!/bin/sh
# Zgemma H7 / OpenATV 6.4, ARMv7 static OSCam Stability preview.
# Install alongside the existing OSCam; do not start or switch CAMs.
set -eu

base=https://github.com/Baniak88/oscam-stabilny/releases/download/h11s-armv7-preview-1
pkg=oscam-stability_1.3.0_armv7-static-preview.ipk
dest=/tmp/oscam-h7-preview
fail() { echo "ERROR: $*" >&2; exit 1; }

[ "$(id -u)" = 0 ] || fail "Run as root"
model=$(cat /proc/stb/info/model 2>/dev/null || true)
arch=$(uname -m)
[ "$model" = h7 ] || fail "This installer is for Zgemma H7 (found: $model)"
case "$arch" in armv7*) ;; *) fail "ARMv7 required (found: $arch)" ;; esac
command -v opkg >/dev/null 2>&1 || fail "opkg missing"
command -v sha256sum >/dev/null 2>&1 || fail "sha256sum missing"
command -v wget >/dev/null 2>&1 || fail "wget missing"
command -v tar >/dev/null 2>&1 || fail "tar missing"
[ ! -e /etc/init.d/softcam.oscam-stability ] || fail "Stability service already exists; refusing overwrite"
[ -d /etc/tuxbox/config ] || fail "Expected /etc/tuxbox/config missing"

mkdir -p "$dest"
echo "Downloading published ARMv7 static preview..."
wget -T 30 -O "$dest/$pkg" "$base/$pkg" || fail "Preview IPK download failed"
wget -T 30 -O "$dest/$pkg.sha256" "$base/$pkg.sha256" || fail "Preview SHA256 download failed"
(cd "$dest" && sha256sum -c "$pkg.sha256") || fail "SHA256 verification failed"

backup=/root/oscam-stability-backup
mkdir -p "$backup"
chmod 700 "$backup"
archive="$backup/config-before-h7-stability-$(date +%Y%m%d-%H%M%S).tar.gz"
tar -czf "$archive" -C /etc tuxbox/config || fail "Configuration backup failed"
chmod 600 "$archive"
echo "Backup: $archive"
echo "Installing preview package without force flags..."
opkg install "$dest/$pkg" || fail "opkg installation failed. Existing OSCam was not deliberately removed."
echo "Checking installed binary (without starting the CAM)..."
if /usr/lib/oscam-stability/oscam-arm -V > "$dest/version.txt" 2>&1; then
    grep -E '^(Version|Compiler|DVB API support|Web interface support):' "$dest/version.txt" || cat "$dest/version.txt"
    echo "Binary version check passed."
else
    echo "WARNING: binary version test failed on H7. Do not start this CAM."
    cat "$dest/version.txt"
    exit 1
fi
echo "OSCam Stability preview installed but NOT started or selected."
echo "Existing OSCam configuration and selected service were not modified."
echo "Do not run two OSCam instances at the same time."
