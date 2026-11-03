# tams-dots

**A ready-to-use Hyprland desktop for Arch Linux**: tams-shell bar & panels, automatic colors,
a login screen with a moving video background, and an Arch-styled boot menu & startup animation.
One command installs everything.

🇮🇩 Bahasa Indonesia: [README.md](README.md) (the most detailed guide)

## Supported machines

| Machine | Status |
|---|---|
| ✅ Intel / AMD laptops & desktops (64-bit) | Fully supported |
| ✅ Intel, AMD, NVIDIA GTX 16xx / RTX and newer GPUs | Drivers installed automatically |
| ⚠️ Older NVIDIA (GTX 10xx and below) | Works, install the driver manually ([wiki](https://wiki.archlinux.org/title/NVIDIA)) |
| ✅ Arch Linux, CachyOS, EndeavourOS and other Arch-based distros | Tested on CachyOS |
| ⚠️ Intel Macs (before late 2020) | Works, Wi-Fi/keyboard/trackpad may need extra drivers |
| 🧪 Apple Silicon M1/M2 via [Asahi Arch Linux ARM](https://asahi-alarm.org) | Experimental, untested; packages unavailable on ARM are skipped |
| ❌ M3/M4 Macs, Windows, non-Arch distros | Not supported |

Any username works.

## Install

On a fresh Arch Linux (archinstall: GRUB bootloader, Minimal profile, PipeWire, NetworkManager)
or CachyOS (GRUB, Hyprland or No Desktop), logged in as a normal user with sudo:

```bash
sudo pacman -Syu --needed git
git clone https://github.com/tammysuryana/tams-dots.git ~/tams-dots
cd ~/tams-dots
./install.sh          # or ./install.sh --yes to accept all recommended answers
reboot
```

Do **not** run `./install.sh` with `sudo`; it asks for your password when needed.
The installer is safe to re-run if it stops halfway. Overwritten configs are backed up to `~/.tams-dots-backup-<date>`.

| Option | What it does |
|---|---|
| `--yes` | Accept every recommended answer |
| `--configs-only` | Only copy configs (no packages, no system themes) |
| `--update` | Update the shell and default Hyprland config, keep your personal settings |

After reboot pick the **Hyprland** session, log in, and press **`Super + /`** for the keybind cheatsheet.
Settings: `Super + Esc`. Display modes: `Super + Alt + P`.

## Personal settings (kept on update)

`~/.config/hypr/custom/*.lua` (keybinds, autostart, env), `~/.config/hypr/monitors.lua`,
`~/.config/fish/conf.d/pribadi.fish`.

## Login & boot themes

```bash
sudo bash ~/tams-dots/theme/sddm.sh install /path/to/video-or-image   # custom login background
sudo bash ~/tams-dots/theme/sddm.sh uninstall                        # restore default login screen
sudo bash ~/tams-dots/theme/boot.sh uninstall                        # restore previous GRUB/Plymouth
```

## License & credits

GNU GPL-3.0 ([LICENSE](LICENSE)). tams-shell is a modified derivative of *illogical-impulse* by end-4
(via pctrade's fork), and the boot themes derive from CachyOS themes. Full credits in [NOTICE](NOTICE).
"Arch Linux" and the Arch logo are trademarks of Arch Linux; this is not an official Arch Linux project.
