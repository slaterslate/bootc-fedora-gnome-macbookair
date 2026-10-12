# =============================================================================
# bootc-fedora-gnome-macbookair — Fedora 45 Optimized
# Immutable Fedora 45 + GNOME 51 image tailored for MacBook Air A1466 (7,2).
# Includes Broadcom WiFi, FaceTimeHD camera, and MacBook-specific optimizations.
#
# NOTE: This Containerfile uses external bash scripts (in build-scripts/)
# instead of Dockerfile heredocs (RUN <<EOF ... EOF), because heredoc
# support in Podman/Buildah's Dockerfile parser is unreliable across versions.
# External scripts work with every Podman, Buildah, and Docker version.
# =============================================================================

# ── Stage 1: Build out-of-tree kernel modules ──────────────────────────────
FROM quay.io/fedora/fedora-bootc:45 AS builder

COPY --chmod=755 build-scripts/builder.sh /tmp/builder.sh
RUN /tmp/builder.sh

# ── Stage 2: Final bootable image ──────────────────────────────────────────
FROM quay.io/fedora/fedora-bootc:45

# Build scripts
COPY --chmod=755 build-scripts/sysconfig.sh /tmp/sysconfig.sh
COPY --chmod=755 build-scripts/packages.sh /tmp/packages.sh

# Copy pre-built kernel module RPMs from builder
COPY --from=builder /var/cache/akmods/wl/kmod-wl*.rpm /tmp/kmods/
# FaceTimeHD module compiled from patjak/facetimehd source
COPY --from=builder /tmp/facetimehd/facetimehd.ko /tmp/facetimehd.ko

# Copy FaceTimeHD firmware and repo config from builder
COPY --from=builder /usr/lib/firmware/facetimehd/ /usr/lib/firmware/facetimehd/
COPY --from=builder /etc/yum.repos.d/_copr_mulderje-facetimehd-kmod.repo /etc/yum.repos.d/

# ── Copy project configuration files to their final destinations ──
# Packages list
COPY packages.rpm /tmp/packages.rpm
# First-login Flatpak bootstrap
COPY --chmod=755 post-install.sh /usr/bin/post-install.sh
COPY post-install.service /usr/lib/systemd/user/post-install.service
# MacBook keyboard: fn key behavior, swap alt/cmd
COPY hid-apple.conf /usr/lib/modprobe.d/hid-apple.conf
# Dracut: optimized initramfs
COPY dracut-optimize.conf /usr/lib/dracut/conf.d/macbook-optimize.conf
# Kernel modules: ensure coretemp + applesmc loaded at boot
COPY modules-load.conf /usr/lib/modules-load.d/macbook.conf
# Audio power save: Intel HDA codec off when idle
COPY audio-power-save.conf /usr/lib/modprobe.d/audio-power-save.conf
# Udev: user-writable screen + keyboard backlight
COPY 90-backlight.rules /usr/lib/udev/rules.d/90-backlight.rules
COPY 91-leds.rules /usr/lib/udev/rules.d/91-leds.rules
# Udev: exclude bcm5974 trackpad from USB autosuspend
COPY 92-trackpad-autosuspend.rules /usr/lib/udev/rules.d/92-trackpad-autosuspend.rules
# Udev: prevent Thunderbolt switch from entering D3cold
COPY 94-thunderbolt-pm.rules /usr/lib/udev/rules.d/94-thunderbolt-pm.rules
# I/O scheduler tuning
COPY 60-ioscheduler.rules /usr/lib/udev/rules.d/60-ioscheduler.rules
# Suspend: disable spurious wakeup sources (XHC1, EHC1, EHC2)
COPY suspend-fix.service /usr/lib/systemd/system/suspend-fix.service
# Suspend: Broadcom wl WiFi interface reset
COPY --chmod=755 wl-suspend.sh /usr/local/bin/wl-suspend.sh
COPY wl-suspend.service /usr/lib/systemd/system/wl-suspend.service
# Suspend: stop heavy services before sleep for fast resume
COPY --chmod=755 sleep-helpers.sh /usr/local/bin/sleep-helpers.sh
COPY sleep-helpers.service /usr/lib/systemd/system/sleep-helpers.service
# Resume: restart macbook-lighter after user.slice is thawed
COPY --chmod=755 resume-lighter.sh /usr/local/bin/resume-lighter.sh
COPY resume-lighter.service /usr/lib/systemd/system/resume-lighter.service
# Suspend configuration
COPY sleep.conf /usr/lib/systemd/sleep.conf.d/macbook.conf
COPY logind.conf /usr/lib/systemd/logind.conf.d/macbook.conf
# Lid wakeup guard: re-suspend if lid is still closed
COPY --chmod=755 lid-wakeup-guard.sh /usr/local/bin/lid-wakeup-guard.sh
COPY lid-wakeup-guard.service /usr/lib/systemd/system/lid-wakeup-guard.service
# Udev: re-enable LID0 wakeup when lid opens
COPY 93-lid-wakeup.rules /usr/lib/udev/rules.d/93-lid-wakeup.rules
# Fan control: custom mbpfan curve for A1466
COPY mbpfan.conf /etc/mbpfan.conf
# Power management: tuned custom profile
COPY tuned-macbook-profile/ /etc/tuned/macbook-profile/
# Zram swap tuning
COPY zram.conf /etc/systemd/zram-generator.conf
# Locale configuration
COPY locale.conf /etc/locale.conf
# WiFi power save
COPY wifi-power-save.conf /usr/lib/modprobe.d/wifi-power-save.conf
# NetworkManager WiFi powersave
COPY wifi-powersave.conf /etc/NetworkManager/conf.d/wifi-powersave.conf

# ── System configuration & kernel module installation ──
RUN /tmp/sysconfig.sh

# ── Stage 2.1: Install GNOME Shell (minimal) ────────────────────────────────
RUN echo "▸ Installing GNOME Shell (minimal)" && \
    dnf5 install gnome-shell -y && \
    dnf5 clean all && \
    rm -rfv /var/cache/* \
    /var/log/* \
    /var/tmp/* \
    /var/cache/libdnf5/* /var/lib/dnf/*

# ── Stage 2.2: Install RPM packages & configure services ────────────────────
RUN /tmp/packages.sh

# ── Lint the final image ──
RUN bootc container lint
