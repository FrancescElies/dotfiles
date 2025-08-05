#!/usr/bin/env nu

let displays = swaymsg -t get_outputs -r | from json
let active_displays =  $displays | where $it.active
let inactive_displays = $displays | where not $it.active

if ($inactive_displays | is-not-empty) {
    $inactive_displays | each { swaymsg  $"output ($in.name) enable"}
} else {
    # disable all external
    $active_displays | where $it.name =~ "HDMI" | each { swaymsg  $"output ($in.name) disable"}
}


