#!/usr/bin/env nu

const current_dir = path self .

let action = [
    clipboard
    toggle-external-display
] | to text | bemenu

cd $current_dir
match $action {
    clipboard => { clipman pick --tool bemenu },
    toggle-external-display => { ./toggle-external-display.nu },
}
