#!/usr/bin/env nu

let action = [ lock logout shutdown reboot ] | to text | bemenu

match $action {
    lock => { swaylock --color 000000 },
    logout => { swaymsg exit },
    shutdown => { systemctl poweroff },
    reboot => { systemctl reboot },
}
