#!/bin/sh
set -eu

if [ "$#" -ne 4 ]; then
    printf 'Usage: %s ARMv7_BINARY AARCH64_BINARY OPENSSL_LICENSE OUTPUT_IPK\n' "$0" >&2
    exit 2
fi

scripts=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/control" "$stage/root/etc/init.d" "$stage/root/usr/lib/oscam-stability" "$stage/root/usr/share/licenses/oscam-stability"
install -m 644 "$scripts/control" "$stage/control/control"
install -m 755 "$scripts/prerm" "$stage/control/prerm"
install -m 755 "$scripts/softcam.oscam-stability" "$stage/root/etc/init.d/softcam.oscam-stability"
install -m 755 "$1" "$stage/root/usr/lib/oscam-stability/oscam-arm"
install -m 755 "$2" "$stage/root/usr/lib/oscam-stability/oscam-aarch64"
install -m 644 "$scripts/../COPYING" "$stage/root/usr/share/licenses/oscam-stability/COPYING"
install -m 644 "$3" "$stage/root/usr/share/licenses/oscam-stability/OPENSSL-LICENSE"
printf '2.0\n' > "$stage/debian-binary"
tar --sort=name --owner=0 --group=0 -czf "$stage/control.tar.gz" -C "$stage/control" .
tar --sort=name --owner=0 --group=0 -czf "$stage/data.tar.gz" -C "$stage/root" .
ar cr "$stage/package.ipk" "$stage/debian-binary" "$stage/control.tar.gz" "$stage/data.tar.gz"
mv "$stage/package.ipk" "$4"
