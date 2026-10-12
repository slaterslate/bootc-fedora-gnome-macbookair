# bootc-fedora-gnome-macbookair — Fedora 45 Optimized

Immutable Fedora 45 image with GNOME Shell, tailored for MacBook Air A1466 (7,2). Automated daily builds and ISO generation via GitHub Actions.

## Project Structure

```
.
├── .github/work
```

## Quick Start

### Build the Container Image

```
git clone https://github.com/YOURUSER/bootc-fed
```

### Generate an ISO (GitHub Actions)

1. Push to `main` — the container image builds automatically.
2. Run the **Build ISO** workflow manually from the Actions tab.
3. Download the ISO artifact when the workflow completes.

## Fedora 45 Changes Applied

| Change ↕▾ | Status ↕▾ |
|---|---|
| −Base image `fedora-bootc:45` | ✅ Applied |
| −RPM signature enforcement | ✅ Handled (dnf5 used) |
| −Repo config relocation (`/etc` → `/usr`) | ✅ Handled |
| −kmscon console | ✅ Included |
| −GNOME 51 | ✅ Applied |
| −systemd 262 | ✅ Compatible |
| −Podman 6 | ✅ Compatible |
⚙

## Optimizations Applied

- **Kernel args**: `nowatchdog`, `nmi_watchdog=0`, `skew_tick=1`, `i915.fastboot=1`
- **Storage**: Btrfs `compress=zstd:1,noatime,ssd,discard=async`
- **Zram**: `zstd`, capped at 4 GiB
- **Boot speed**: `i915` removed from initramfs, masked Plymouth/wait-online
- **DNF5**: `install_weak_deps=False`, `tsflags=nodocs`

## How to Update

```
sudo bootc upgrade --check
sudo bootc upgrade
sudo reboot
```

## License

MIT

## Credits

Inspired by [Ferlinuxdebian/bootc-gnome-minimal](https://github.com/Ferlinuxdebian/bootc-gnome-minimal).