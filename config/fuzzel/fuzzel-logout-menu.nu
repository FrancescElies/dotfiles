#!/usr/bin/env nu

let action = [suspend reboot shutdown logout] | to text | fuzzel --dmenu

match $action {
    suspend => { swaylock --color 000000 },
    reboot => { systemctl reboot },
    shutdown => { systemctl poweroff },
    logout => { swaymsg exit },
}
