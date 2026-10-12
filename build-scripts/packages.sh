#!/bin/bash
# =============================================================================
# Stage 2 packages — install RPMs, macbook-lighter, weather-oclock, mbpfan,
# configure dconf defaults, and enable/mask systemd services
# =============================================================================
set -euo pipefail

echo "▸ Installing RPM packages from packages.rpm"
dnf5 -y install \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
find /etc/yum.repos.d/ -name '*rawhide*' -delete 2>/dev/null || true
find /usr/share/dnf5/repos.d/ -name '*rawhide*' -delete 2>/dev/null || true
grep -v '^\s*#' /tmp/packages.rpm | grep -v '^\s*$' | xargs dnf5 install -y --refresh
dnf5 remove -y gnome
