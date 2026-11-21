#!/bin/sh
# Install persistent OpenATV OSCamInfo compatibility for a running OSCam Stability.
# Keeps the OSCam process, reader configuration and selected softcam untouched.
set -eu

service=/etc/init.d/softcam.oscam-stability
pidfile=/var/run/oscam-stability/oscam.pid
version=/var/run/oscam-stability/oscam.version
compat=/tmp/.oscam/oscam.version
source_url=https://raw.githubusercontent.com/Baniak88/oscam-stabilny/main/openatv-package/softcam.oscam-stability

fail() { echo "ERROR: $*" >&2; exit 1; }
[ "$(id -u)" -eq 0 ] || fail "Run as root"
[ -f "$service" ] && [ ! -L "$service" ] || fail "Expected regular service file: $service"
[ -r "$pidfile" ] || fail "OSCam Stability PID file missing"
IFS= read -r pid < "$pidfile" || fail "Cannot read PID"
case "$pid" in ''|*[!0-9]*) fail "Invalid OSCam PID" ;; esac
exe=$(readlink "/proc/$pid/exe" 2>/dev/null || true)
case "$exe" in
    /usr/lib/oscam-stability/oscam-arm|/usr/lib/oscam-stability/oscam-aarch64) ;;
    *) fail "OSCam Stability is not running; no changes made" ;;
esac
[ -s "$version" ] || fail "Missing OSCam runtime version file: $version"
command -v wget >/dev/null 2>&1 || fail "wget is required"

tmp=$(mktemp /etc/init.d/.softcam.oscam-stability.XXXXXX) || fail "Cannot create temporary service file"
trap 'rm -f "$tmp"' EXIT HUP INT TERM
wget -q -T 30 -O "$tmp" "$source_url" || fail "Cannot download service from GitHub"
sh -n "$tmp" || fail "Downloaded service failed shell syntax check"
grep -q '^binary_dir=/usr/lib/oscam-stability$' "$tmp" || fail "Unexpected service content"
grep -q '^publish_enigma2_version()' "$tmp" || fail "Version integration missing"
grep -q '^unpublish_enigma2_version()' "$tmp" || fail "Version cleanup missing"

backup_dir=/etc/oscam-stability-backup
mkdir -p "$backup_dir" || fail "Cannot create backup directory"
chmod 700 "$backup_dir"
backup="$backup_dir/softcam.oscam-stability.$(date +%Y%m%d-%H%M%S).$$"
cp -p "$service" "$backup" || fail "Cannot back up existing service"
chmod 600 "$backup"
chmod 755 "$tmp"
mv -f "$tmp" "$service" || fail "Cannot install updated service"

# This service's start command only publishes the version link if the CAM
# is already running. It does not restart or interrupt the running process.
if ! "$service" start; then
    cp "$backup" "$service"
    chmod 755 "$service"
    fail "Service verification failed; restored original service"
fi

if [ ! -L "$compat" ] || [ "$(readlink "$compat")" != "$version" ]; then
    echo "WARNING: OpenATV version link not published. An existing CAM link was not overwritten."
    echo "Inspect $compat before making further changes."
    exit 1
fi

echo "Persistent OpenATV compatibility installed."
echo "Version link: $compat -> $(readlink "$compat")"
echo "Service backup: $backup"
"$service" status
grep -E '^(Version|ConfigDir|WebifPort):' "$compat" || true
echo "No OSCam restart; reader and WebIF configuration unchanged."
