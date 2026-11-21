#!/bin/sh
# H11.S direct-receiver installation from a published GitHub prerelease.
# Does not start/switch softcams or change OSCam configuration.
set -eu
repo=https://github.com/Baniak88/oscam-stabilny/releases/download/h11s-armv7-preview-1
pkg=oscam-stability_1.3.0_armv7-static-preview.ipk
dest=/tmp/oscam-h11s-preview
fail() { echo "ERROR: $*" >&2; exit 1; }
[ "$(id -u)" = 0 ] || fail "Run as root"
model=$(cat /proc/stb/info/model 2>/dev/null || true)
arch=$(uname -m)
[ "$model" = h11 ] || fail "This installer is for Zgemma H11 (found: $model)"
case "$arch" in armv7*) ;; *) fail "ARMv7 required (found: $arch)" ;; esac
command -v opkg >/dev/null 2>&1 || fail "opkg missing"
command -v sha256sum >/dev/null 2>&1 || fail "sha256sum missing"
command -v wget >/dev/null 2>&1 || fail "wget missing"
[ ! -e /etc/init.d/softcam.oscam-stability ] || fail "Stability service already exists; refusing overwrite"
[ -d /etc/tuxbox/config ] || fail "Expected /etc/tuxbox/config missing"
mkdir -p "$dest"
wget -T 30 -O "$dest/$pkg" "$repo/$pkg" || fail "Preview release IPK is not yet published or download failed"
wget -T 30 -O "$dest/$pkg.sha256" "$repo/$pkg.sha256" || fail "Release SHA256 unavailable"
(cd "$dest" && sha256sum -c "$pkg.sha256") || fail "SHA256 verification failed"
backup=/root/oscam-stability-backup
mkdir -p "$backup"
chmod 700 "$backup"
archive="$backup/config-before-stability-$(date +%Y%m%d-%H%M%S).tar.gz"
tar -czf "$archive" -C /etc tuxbox/config || fail "Configuration backup failed"
chmod 600 "$archive"
echo "Backup: $archive"
echo "Installing side-by-side package without force flags..."
opkg install "$dest/$pkg" || fail "Package install failed; current OSCam was not deliberately removed"
echo "Preview installed, but not started or selected."
echo "Existing OSCam 11715 remains selected. Do not start two OSCam instances."
echo "Before use, test the new binary with: /usr/lib/oscam-stability/oscam-arm -V"
