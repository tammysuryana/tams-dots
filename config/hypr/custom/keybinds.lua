-- Keybind kustom. Lihat https://wiki.hypr.land/Configuring/Binds/
-- Baris --#! = kolom baru di cheatsheet, --##! = judul bagian.
-- Tambahkan { description = "..." } supaya muncul di cheatsheet.
--#!
--##! User
hl.bind("CTRL + SUPER + Slash", hl.dsp.exec_cmd("xdg-open ~/.config/tams-dots/config.json"), { description = "User: Edit shell config" })
hl.bind("CTRL + SUPER + ALT + Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"), { description = "User: Edit extra keybinds" })
hl.bind("SUPER + Escape", hl.dsp.global("quickshell:settingsToggle"), { description = "User: Toggle tams-shell settings" })
hl.bind("SUPER + ALT + P", hl.dsp.exec_cmd("python3 $HOME/.config/hypr/custom/scripts/display-mode.py menu"), { description = "User: Mode tampilan (laptop/eksternal/extend/mirror)" })

-- Pengganti `binditn = Super, catchall, global, quickshell:searchToggleReleaseInterrupt`
-- dari keybinds.conf lama: di Hyprland 0.57 catchall hanya boleh di submap, jadi
-- pencarian ikut terbuka saat Super dilepas sehabis Super+1 dst. Bind per tombol.
do
    local interrupt = hl.dsp.global("quickshell:searchToggleReleaseInterrupt")
    local keys = {
        "Left", "Right", "Up", "Down", "Tab", "Return", "Space", "BackSpace", "Delete", "Escape",
        "Home", "End", "Prior", "Next", "Insert", "Print",
        "Minus", "Equal", "BracketLeft", "BracketRight", "Backslash", "Semicolon", "Apostrophe",
        "Grave", "Comma", "Period", "Slash",
    }
    for i = 0, 9 do table.insert(keys, tostring(i)) end
    for c = string.byte("A"), string.byte("Z") do table.insert(keys, string.char(c)) end
    for i = 1, 12 do table.insert(keys, "F" .. i) end
    for _, mods in ipairs({ "SUPER", "SUPER + SHIFT", "SUPER + ALT", "SUPER + CTRL", "SUPER + SHIFT + ALT", "SUPER + CTRL + SHIFT" }) do
        for _, key in ipairs(keys) do
            hl.bind(mods .. " + " .. key, interrupt, { non_consuming = true })
        end
    end
    for _, btn in ipairs({ "mouse:272", "mouse:273", "mouse:274", "mouse:275" }) do
        hl.bind("SUPER + " .. btn, interrupt, { non_consuming = true })
    end
    hl.bind("CTRL + SUPER_L", interrupt)
    hl.bind("CTRL + SUPER_R", interrupt)
end
