#!/usr/bin/env nu

const current_dir = path self .

let action = [
    clipboard
    bluetuith
    # blueman
    wifi
    toggle-external-display
] | to text | bemenu

cd $current_dir
match $action {
    clipboard => { clipman pick --tool bemenu },
    bluetuith => { alacritty -e nu -e bluetuith },
    # blueman => { blueman-manager },
    wifi => {
        let action = [
            nmtui
            fzf
            on
            off
            status
        ] | to text | bemenu
        match $action {
            nmtui => { alacritty -e nmtui },
            fzf => {
                let ssid = nmcli -t -f SSID dev wifi list | bemenu
                nmcli dev wifi connect $ssid
            },
            on => { nmcli radio wifi on },
            off => { nmcli radio wifi off },
            status => {
                alacritty -e nmcli connection show --active
            },
            _ => { notify-send Err $"($action) not found" }
        }
    }
    toggle-external-display => {
        let displays = swaymsg -t get_outputs -r | from json
        let active_displays =  $displays | where $it.active
        let inactive_displays = $displays | where not $it.active

        if ($inactive_displays | is-not-empty) {
            $inactive_displays | each { swaymsg  $"output ($in.name) enable"}
        } else {
            # disable all external
            $active_displays | where $it.name =~ "HDMI" | each { swaymsg  $"output ($in.name) disable"}
        }
    },
    _ => { notify-send Err $"($action) not found" }
}
