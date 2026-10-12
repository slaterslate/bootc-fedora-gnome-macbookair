#!/bin/bash
# =============================================================================
# Stage 2 sysconfig — kernel args, dracut, bootc best practices, kmod install
# =============================================================================
set -euo pipefail

echo "▸ Creating required directories"
mkdir -vp /var/roothome /data /var/home
mkdir -vp /usr/lib/systemd/sleep.conf.d /usr/lib/systemd/logind.conf.d

echo "▸ Installing kernel-modules-extra for broader hardware support"
dnf5 -y install kernel-modules-extra --refresh

echo "▸ Regenerating initramfs with optimized dracut config"
kver="$(rpm -q kernel-core --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
dracut -f "/usr/lib/modules/${kver}/initramfs.img" "${kver}"

mkdir -p /usr/lib/bootc/kargs.d/
cat > /usr/lib/bootc/kargs.d/10-macbook.toml <<'KARGS'
kargs = ["acpi_osi=!Darwin", "acpi_osi=!Windows 2012"]
match-architectures = ["x86_64"]
KARGS

cat > /usr/lib/bootc/kargs.d/20-macbook-power.toml <<'KARGS'
kargs = [
  "i915.enable_psr=1",
  "i915.enable_dc=2",
  "i915.enable_fbc=1",
  "i915.enable_guc=2",
  "i915.fastboot=1",
  "pcie_aspm=active",
  "mem_sleep_default=deep",
  "nowatchdog",
  "nmi_watchdog=0",
  "skew_tick=1",
  "transparent_hugepage=madvise",
  "zswap.enabled=0"
]
match-architectures = ["x86_64"]
KARGS

cat > /usr/lib/bootc/kargs.d/30-macbook-hardware.toml <<'KARGS'
kargs = [
  "nvme_core.default_ps_max_latency_us=55000",
  "usbcore.autosuspend=5"
]
match-architectures = ["x86_64"]
KARGS

mkdir -p /usr/lib/systemd/system-sleep
cat > /usr/lib/systemd/system-sleep/restore-backlight.sh <<'HOOK'
#!/bin/bash
BACKLIGHT=/sys/class/backlight/intel_backlight
case "$1" in
    pre)
        cat "$BACKLIGHT/brightness" > /tmp/backlight-brightness 2>/dev/null || true
        ;;
    post)
        sleep 1
        if [ -f /tmp/backlight-brightness ]; then
            cat /tmp/backlight-brightness > "$BACKLIGHT/brightness" 2>/dev/null || true
        fi
        ;;
esac
HOOK
chmod +x /usr/lib/systemd/system-sleep/restore-backlight.sh

FEDORA_RELEASE="$(rpm -E '%fedora')"
dnf5 -y install \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_RELEASE}.noarch.rpm"

echo "▸ Installing Broadcom WiFi kernel module (kmod-wl)"
dnf5 -y install /tmp/kmods/kmod-wl-*.rpm

echo "▸ Installing FaceTimeHD camera kernel module (built from patjak/facetimehd)"
dnf5 -y install facetimehd-kmod-common
install -D /tmp/facetimehd.ko \
    /usr/lib/modules/${kver}/extra/facetimehd/facetimehd.ko
depmod -a "${kver}"
rm -f /tmp/facetimehd.ko

echo "▸ Setting up writable /opt and /usr/local"
rm -rvf /opt && mkdir -vp /var/opt && ln -vs /var/opt /opt
mkdir -vp /var/usrlocal && mv -v /usr/local/* /var/usrlocal/ 2>/dev/null || true
rm -rvf /usr/local && ln -vs /var/usrlocal /usr/local

mkdir -p /usr/lib/systemd/journald.conf.d
printf '[Journal]\nStorage=persistent\n' > /usr/lib/systemd/journald.conf.d/persistent.conf

mkdir -p /usr/lib/ostree
cat > /usr/lib/ostree/prepare-root.conf <<'COMPOSEFS'
[composefs]
enabled = true
COMPOSEFS

echo "▸ Setting timezone to America/Santiago"
ln -sf /usr/share/zoneinfo/America/Santiago /etc/localtime

echo "▸ Configuring keyboard layout (latam)"
cat > /etc/vconsole.conf <<'VCONSOLE'
KEYMAP=latam
VCONSOLE

echo "▸ Configuring DNF5 for minimal image size"
cat >> /etc/dnf/dnf.conf <<'DNF'
tsflags=nodocs
install_weak_deps=False
DNF

echo "▸ Cleaning up build artifacts"
rm -rvf /tmp/kmods
rm -rvf /usr/etc
rm -rvf /boot/*
dnf5 clean all
rm -rfv /var/cache/* \
        /var/log/* \
        /var/tmp/* \
        /var/lib/dnf/* \
        /var/cache/libdnf5/*

echo "▸ Sysconfig stage complete"
