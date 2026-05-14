#!/usr/bin/env nu

const current_dir = path self .

let menu = {  bemenu --no-overlap --prompt '  run: ' --list 15 --center --width-factor 0.3  }

let action = [
    clipboard
    bluetuith
    # blueman
    wifi
    toggle-external-display
    mount-usb
    umount-usb
    firefox
] | to text | do $menu

cd $current_dir
match $action {
    clipboard => {
        clipman pick --tool bemenu --tool-args="--no-overlap --prompt '  run: ' --list 15 --center --width-factor 0.3" | wl-copy
        wl-paste --paste-once
    },
    bluetuith => { alacritty -e nu -e bluetuith },
    # blueman => { blueman-manager },
    wifi => {
        let action = [
            nmtui
            fzf
            on
            off
            status
        ] | to text | do $menu
        match $action {
            nmtui => { alacritty -e nmtui },
            fzf => {
                let ssid = nmcli -t -f SSID dev wifi list | do $menu
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
    "mount-usb" => {
        let device = lsblk -r -o PATH,MOUNTPOINT,TRAN | from csv --separator ' ' | where TRAN == usb | get PATH | to text | do $menu
        udisksctl mount -b $"($device)1"
        let path = lsblk -r -o PATH,MOUNTPOINT | from csv --separator ' ' | where PATH == $"($device)1" | get MOUNTPOINT.0
        notify-send "Mount USB" $"($device)1 is now at ($path), see `lsblk -f`"
    },
    "umount-usb" => {
        let device = lsblk -r -o PATH,MOUNTPOINT,TRAN | from csv --separator ' ' | where TRAN == usb | get PATH | to text | do $menu
        let path = lsblk -r -o PATH,MOUNTPOINT | from csv --separator ' ' | where PATH == $"($device)1" | get MOUNTPOINT.0
        udisksctl unmount -b $"($device)1"
        notify-send "UnMount USB" $"($device)1 removed form ($path), see `lsblk -f`"
    },
    "firefox" => {
        firefox
    }
    _ => { notify-send Err $"($action) not found" }
}
