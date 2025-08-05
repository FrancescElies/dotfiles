#!/usr/bin/env nu

let action = [ logout reboot shutdown suspend ] | to text | bemenu

match $action {
    suspend => { swaylock --color 000000 },
    reboot => { systemctl reboot },
    shutdown => { systemctl poweroff },
    logout => { swaymsg exit },
}
