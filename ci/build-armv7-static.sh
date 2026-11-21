#!/bin/sh
# Build an ARMv7 hard-float, fully static musl OSCam Stability preview IPK.
# Static linking avoids dependence on the receiver's glibc/OpenSSL versions.
set -eu

repo=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
mkdir -p "$repo/dist" "$work/toolchain" "$work/openssl-build"

TOOLCHAIN_URL="https://toolchains.bootlin.com/downloads/releases/toolchains/armv7-eabihf/tarballs/armv7-eabihf--musl--stable-2024.05-1.tar.xz"
SSL_URL="https://www.openssl.org/source/openssl-3.5.9.tar.gz"
SSL_SHA256="603f5602e2eef00d77fbd429d34dcd5822bb301757a1bc9cdb24c670f1eb859a"

curl --fail --location --retry 3 --output "$work/toolchain.tar.xz" "$TOOLCHAIN_URL"
tar -xJf "$work/toolchain.tar.xz" -C "$work/toolchain"
gcc=$(find "$work/toolchain" -name '*-gcc' | grep '/bin/' | head -n 1)
[ -n "$gcc" ] && [ -x "$gcc" ] || { echo "ARMv7 cross-compiler not found" >&2; exit 1; }
cross=${gcc%gcc}
export PATH="$(dirname "$gcc"):$PATH"

curl --fail --location --retry 3 --output "$work/openssl.tar.gz" "$SSL_URL"
printf '%s  %s\n' "$SSL_SHA256" "$work/openssl.tar.gz" | sha256sum -c -
mkdir -p "$work/openssl-src"
tar -xzf "$work/openssl.tar.gz" -C "$work/openssl-src" --strip-components=1
(
    cd "$work/openssl-build"
    "$work/openssl-src/Configure" linux-armv4 no-shared no-tests no-module --cross-compile-prefix="$cross"
    make -j2 build_libs
)

(
    cd "$repo"
    make -j2 CROSS="$cross" HOSTCC=gcc USE_SSL=1 \
        SSL_LIB="$work/openssl-build/libssl.a" \
        LIBCRYPTO_LIB="$work/openssl-build/libcrypto.a" \
        EXTRA_CFLAGS="-I$work/openssl-build/include -I$work/openssl-src/include" \
        EXTRA_LDFLAGS="-static" \
        CONF_DIR=/etc/tuxbox/config \
        VER=2.26.11-11975-stability1.3.0 GIT_SHA=7476c327 \
        OSCAM_BIN="$work/oscam-arm"
)
[ -s "$work/oscam-arm" ] || { echo "Binary missing" >&2; exit 1; }
file "$work/oscam-arm"
readelf -h "$work/oscam-arm" | grep -q 'Machine:.*ARM' || { echo "Wrong ELF architecture" >&2; exit 1; }
if readelf -l "$work/oscam-arm" | grep -q INTERP; then
    echo "Binary unexpectedly requires a dynamic loader" >&2
    exit 1
fi
if readelf -d "$work/oscam-arm" 2>/dev/null | grep -q NEEDED; then
    echo "Binary unexpectedly requires shared libraries" >&2
    exit 1
fi
qemu-arm-static "$work/oscam-arm" -V > "$work/version.txt"
grep -q 'stability1.3.0' "$work/version.txt" || { cat "$work/version.txt"; exit 1; }

stage="$work/package"
mkdir -p "$stage/control" "$stage/root/etc/init.d" \
    "$stage/root/usr/lib/oscam-stability" "$stage/root/usr/share/licenses/oscam-stability"
cat > "$stage/control/control" <<'EOF'
Package: enigma2-softcams-oscam-stability
Version: 1.3.0-armv7preview1
Architecture: all
Maintainer: OSCam Stability build
Section: utils
Priority: optional
Description: OSCam Stability 1.3.0 static ARMv7 preview for OpenATV.
 Requires ARMv7 hard-float; does not automatically select or start the softcam.
EOF
cp "$repo/openatv-package/prerm" "$stage/control/prerm"
chmod 755 "$stage/control/prerm"
cp "$repo/openatv-package/softcam.oscam-stability" "$stage/root/etc/init.d/softcam.oscam-stability"
chmod 755 "$stage/root/etc/init.d/softcam.oscam-stability"
cp "$work/oscam-arm" "$stage/root/usr/lib/oscam-stability/oscam-arm"
chmod 755 "$stage/root/usr/lib/oscam-stability/oscam-arm"
cp "$repo/COPYING" "$stage/root/usr/share/licenses/oscam-stability/COPYING"
cp "$work/openssl-src/LICENSE.txt" "$stage/root/usr/share/licenses/oscam-stability/OPENSSL-LICENSE"
printf '2.0\n' > "$work/debian-binary"
tar -czf "$work/control.tar.gz" -C "$stage/control" .
tar -czf "$work/data.tar.gz" -C "$stage/root" .
out="$repo/dist/oscam-stability_1.3.0_armv7-static-preview.ipk"
ar cr "$out" "$work/debian-binary" "$work/control.tar.gz" "$work/data.tar.gz"
(cd "$repo/dist" && sha256sum "$(basename "$out")" > "$(basename "$out").sha256")
echo "Build and QEMU version check passed: $out"
