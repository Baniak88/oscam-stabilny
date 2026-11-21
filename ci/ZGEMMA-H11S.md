# Zgemma H11.S (ARMv7, OpenATV 6.4): test build

Detected from the receiver (21 November 2026):
- Model: h11
- CPU: armv7l
- Image: OpenATV 6.4 (2021 build)
- Runtime loader: /lib/ld-linux-armhf.so.3 (glibc)
- Existing package: enigma2-plugin-softcams-oscam-stable 1.20+svn11715-r0
- OSCam Stability is not installed.

## Why a static build?

A truly static ARMv7 hard-float executable built with musl can run on
many glibc-based ARMv7 Linux images without needing the musl loader.
The target must still support the required kernel interfaces and CPU
instruction set. Compatibility with H11.S is **not yet verified**.

## Build

GitHub Actions workflow:
[Build ARMv7 static OSCam preview](../.github/workflows/build-armv7-static.yml)

Open the repository Actions tab, select **Build ARMv7 static OSCam preview**,
choose **Run workflow**, and inspect the result. The job builds a static
ARMv7 executable, checks ELF architecture and dynamic dependencies, runs
`oscam -V` under QEMU, then uploads a preview IPK and SHA256 as workflow
artifacts. These tests **do not verify actual operation on a receiver**.

The build uses the source from this repository and a fixed OpenSSL 3.5.9
source SHA256. The Bootlin toolchain URL is fixed but its archive checksum
is not currently pinned, so review the toolchain provenance before treating
the artifact as a release.

## Important installation precautions

This is a **build preview, not a validated installable release**.
Do not use the existing `install.sh` on the H11.S: it expects a GitHub
Release asset `oscam-stability_1.3.0_all.ipk`, which is not published.
Do not use `opkg --force-overwrite` or remove the existing OSCam package.

The preview IPK includes an init script and a separate binary location.
The existing `oscam-stable` package and configuration should remain intact,
but package installation has **not** been validated against the H11.S image.

Before any installation, save a backup of the current softcam and its
configuration to persistent storage. Test a standalone static binary's
`-V` command first, without stopping the existing softcam, and confirm
its runtime loader requirements. Do not run two CAM processes at once.

The `/tmp/.oscam/oscam.version` symlink is created by the Stability init
script when the new service is selected and started; it is not evidence of
successful reception or decryption.

## Current status

- Cross-build script committed.
- GitHub Actions workflow committed.
- No confirmed successful CI build yet.
- No physical H11.S execution test yet.
- No GitHub Release/IPK download link yet.
