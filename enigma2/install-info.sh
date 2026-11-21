#!/bin/sh
# Install native Enigma2 information screen, no OSCam restart.
set -eu
BASE="https://raw.githubusercontent.com/Baniak88/oscam-stabilny/main/enigma2/OSCamStabilityInfo"
TARGET="/usr/lib/enigma2/python/Plugins/Extensions/OSCamStabilityInfo"
[ "$(id -u)" -eq 0 ] || { echo "Run as root" >&2; exit 1; }
[ -d /usr/lib/enigma2/python/Plugins/Extensions ] || { echo "Enigma2 Extensions directory missing" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 is required" >&2; exit 1; }
TMP="$(mktemp -d /tmp/oscam-info.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
download() {
    if command -v wget >/dev/null 2>&1; then
        wget -q -T 30 -O "$2" "$1"
    elif command -v curl >/dev/null 2>&1; then
        curl -fLsS --connect-timeout 15 --max-time 30 "$1" -o "$2"
    else
        echo "wget or curl required" >&2; exit 1
    fi
}
download "$BASE/plugin.py" "$TMP/plugin.py"
download "$BASE/__init__.py" "$TMP/__init__.py"
python3 -m py_compile "$TMP/plugin.py" || { echo "Python syntax check failed" >&2; exit 1; }
mkdir -p "$TARGET"
for f in plugin.py __init__.py; do
    [ ! -f "$TARGET/$f" ] || cp -p "$TARGET/$f" "$TARGET/$f.bak"
    cp "$TMP/$f" "$TARGET/$f"
done
echo "OSCam Stability Info installed in $TARGET"
echo "Restart Enigma2 GUI (not necessarily full receiver reboot) to load the plugin."
echo "Plugin menu > OSCam Stability Info"
