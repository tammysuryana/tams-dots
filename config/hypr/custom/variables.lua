-- Variabel kustom: menimpa nilai default di hyprland/variables.lua
-- File ini tidak ditimpa saat update tams-dots.

-- Folder config quickshell yang dipakai (~/.config/quickshell/tams-shell)
hl.env("qsConfig", "tams-shell")

-- Terminal: utamakan $TERMINAL (kitty -1), lalu fallback
terminal = "~/.config/hypr/hyprland/scripts/launch_first_available.sh \"${TERMINAL}\" 'kitty -1' 'foot' 'alacritty' 'wezterm' 'konsole' 'kgx' 'uxterm' 'xterm'"
fileManager = "~/.config/hypr/hyprland/scripts/launch_first_available.sh 'dolphin' 'nautilus' 'nemo' 'thunar' \"${TERMINAL}\" 'kitty -1 fish -c yazi'"
