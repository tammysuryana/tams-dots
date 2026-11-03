-- Program yang ikut jalan saat Hyprland mulai. Tambahkan punyamu di dalam fungsi ini.
hl.on("hyprland.start", function()
    hl.exec_cmd("nm-applet")
    -- Atur layar otomatis ala Windows (colok HDMI -> mode terakhir, cabut -> layar laptop nyala).
    -- Menu: SUPER+ALT+P. Lihat custom/scripts/display-mode.py
    hl.exec_cmd("python3 $HOME/.config/hypr/custom/scripts/display-mode.py daemon")
end)
