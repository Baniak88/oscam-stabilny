#!/bin/sh
# Chromebook Linux installer for a successfully built GitHub Actions preview.
# Does not start OSCam, remove the existing OSCam 11715, or alter reader config.
set -eu

repo=Baniak88/oscam-stabilny
run_id=44948892005
artifact=oscam-stability-armv7-static-preview
package=oscam-stability_1.3.0_armv7-static-preview.ipk
receiver=${1:-root@192.168.1.188}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
for cmd in gh ssh scp sha256sum; do
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd is missing. On Chromebook install gh and openssh-client."
done
gh auth status >/dev/null 2>&1 || die "Run gh auth login first."
conclusion=$(gh run view "$run_id" --repo "$repo" --json conclusion --jq '.conclusion') || die "Cannot check GitHub Actions run."
[ "$conclusion" = success ] || die "Build not successful yet (conclusion: $conclusion). Do not install."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
gh run download "$run_id" --repo "$repo" --name "$artifact" --dir "$work" || die "Artifact unavailable."
(cd "$work" && sha256sum -c "$package.sha256") || die "Package SHA256 verification failed."
[ -s "$work/$package" ] || die "Package is missing."

# Do not install to a wrong model or replace existing OSCam.
ssh "$receiver" '
  model=$(cat /proc/stb/info/model 2>/dev/null || true)
  arch=$(uname -m)
  [ "$model" = h11 ] || { echo "Expected H11, got: $model" >&2; exit 1; }
  case "$arch" in armv7*) ;; *) echo "Expected ARMv7, got: $arch" >&2; exit 1 ;; esac
  command -v opkg >/dev/null 2>&1 || exit 1
  [ ! -e /etc/init.d/softcam.oscam-stability ] || {
    echo "OSCam Stability already installed; refusing overwrite" >&2; exit 1;
  }
  mkdir -p /root/oscam-stability-backup || exit 1
  chmod 700 /root/oscam-stability-backup
  tar -czf /root/oscam-stability-backup/config-before-stability.tar.gz -C /etc tuxbox/config || exit 1
  echo "Receiver compatibility and configuration backup OK"
' || die "Receiver check/backup failed; nothing installed."

scp "$work/$package" "$receiver:/tmp/$package" || die "Cannot upload package."
ssh "$receiver" "opkg install '/tmp/$package'" || die "opkg installation failed. Existing softcam was not deliberately removed."
echo "Installed preview IPK. Existing OSCam remains selected."
echo "Do not start OSCam Stability until the preview is validated on this receiver."
