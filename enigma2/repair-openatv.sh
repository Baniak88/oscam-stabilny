#!/bin/sh
# OpenATV OSCam Info compatibility, no CAM restart or Enigma2 file replacement.
set -eu
pidfile=/var/run/oscam-stability/oscam.pid
service=/etc/init.d/softcam.oscam-stability
selected=/etc/init.d/softcam
compat=/tmp/.oscam/oscam.version
runtime=/var/run/oscam-stability
die() { echo "ERROR: $*" >&2; exit 1; }
[ "$(id -u)" = 0 ] || die "Run as root"
[ -f "$service" ] || die "Stability service missing"
[ -r "$pidfile" ] || die "Stability not running (no PID file)"
IFS= read -r pid < "$pidfile" || die "Cannot read PID"
case "$pid" in ''|*[!0-9]*) die "Invalid PID" ;; esac
exe=$(readlink "/proc/$pid/exe" 2>/dev/null || true)
case "$exe" in /usr/lib/oscam-stability/oscam-arm|/usr/lib/oscam-stability/oscam-aarch64) ;; *) die "PID is not OSCam Stability" ;; esac
version=
for file in "$runtime/oscam.version" "$runtime/.oscam/oscam.version"; do
    if [ -s "$file" ] && grep -qi '^WebifPort:' "$file" && grep -qi '^ConfigDir:' "$file"; then
        version=$file
        break
    fi
done
[ -n "$version" ] || die "No valid oscam.version found in $runtime"
if [ -e "$compat" ] || [ -L "$compat" ]; then
    [ "$(readlink "$compat" 2>/dev/null || true)" = "$version" ] || die "Another OSCam owns $compat; refusing overwrite"
    echo "Version link already correct"
else
    mkdir -p /tmp/.oscam
    ln -s "$version" "$compat"
    echo "Created version link: $compat"
fi
if [ -L "$selected" ]; then
    target=$(readlink "$selected")
    case "$target" in
        softcam.oscam-stability|*/softcam.oscam-stability) echo "Stability already selected" ;;
        *) echo "Different softcam selected ($target); use OpenATV Softcam Settings" ;;
    esac
elif [ -e "$selected" ]; then
    echo "Non-symlink $selected exists; leaving unchanged"
else
    ln -s "$service" "$selected"
    echo "Selected running Stability in OpenATV"
fi
echo "Restart Enigma2 GUI and open Softcam Settings > Info"
echo "No OSCam process or reader settings changed"
