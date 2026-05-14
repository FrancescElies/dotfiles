#!/usr/bin/env nu
let menu = {  bemenu --no-overlap --prompt '  run: ' --list 15 --center --width-factor 0.3  }
let action = [ lock logout shutdown reboot ] | to text | do $menu

match $action {
    lock => { swaylock --color 000000 },
    logout => { swaymsg exit },
    shutdown => { systemctl poweroff },
    reboot => { systemctl reboot },
}
