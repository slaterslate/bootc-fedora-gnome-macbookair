#!/bin/bash
# =============================================================================
# Stage 1 builder — compile out-of-tree kernel modules
# Broadcom WiFi (akmod-wl) + FaceTimeHD camera (patjak/facetimehd)
# =============================================================================
set -euo pipefail

echo "▸ Upgrading kernel packages"
dnf5 upgrade -y 'kernel*' --refresh

echo "▸ Installing kernel-devel and build tools"
dnf5 -y install kernel-devel akmods wget git make gcc --refresh

KERNEL_VERSION="$(rpm -q kernel-core --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}')"
FEDORA_RELEASE="$(rpm -E '%fedora')"
echo "▸ Detected kernel: ${KERNEL_VERSION}  (Fedora ${FEDORA_RELEASE})"

# ── Broadcom WiFi (from RPMFusion Non-Free) ──
echo "▸ Enabling RPMFusion Non-Free repository"
dnf5 -y install \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_RELEASE}.noarch.rpm"

echo "▸ Installing and building akmod-wl (Broadcom WiFi)"
dnf5 -y install akmod-wl
akmods --force --kernels "${KERNEL_VERSION}" --kmod wl

# ── FaceTimeHD camera (kmod built from patjak/facetimehd source) ──
echo "▸ Enabling COPR for facetimehd-kmod-common"
if [ "${FEDORA_RELEASE}" -ge 41 ]; then
    COPR_RELEASE="rawhide"
else
    COPR_RELEASE="${FEDORA_RELEASE}"
fi
curl -LsSf -o /etc/yum.repos.d/_copr_mulderje-facetimehd-kmod.repo \
    "https://copr.fedorainfracloud.org/coprs/mulderje/facetimehd-kmod/repo/fedora-${COPR_RELEASE}/mulderje-facetimehd-kmod-fedora-${COPR_RELEASE}.repo"

echo "▸ Building FaceTimeHD kmod from source (patjak/facetimehd)"
git clone --depth 1 https://github.com/patjak/facetimehd.git /tmp/facetimehd
make -C /usr/src/kernels/${KERNEL_VERSION} M=/tmp/facetimehd modules

dnf5 clean all && rm -rf /var/cache/libdnf5 /var/lib/dnf

echo "▸ Building FaceTimeHD firmware from source"
git clone --depth 1 https://github.com/patjak/facetimehd-firmware.git /tmp/facetimehd-firmware
cd /tmp/facetimehd-firmware && make && make install

echo "▸ Builder stage complete"
