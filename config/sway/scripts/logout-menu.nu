#!/usr/bin/env nu

let action = [suspend reboot shutdown logout] | to text | bemenu

match $action {
    suspend => { swaylock --color 000000 },
    reboot => { systemctl reboot },
    shutdown => { systemctl poweroff },
    logout => { swaymsg exit },
}
