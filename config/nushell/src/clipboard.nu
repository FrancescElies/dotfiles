# https://github.com/nushell/nu_scripts/blob/main/modules/system/mod.nu

# print a command name as dimmed and italic
export def pretty-command [] {
    let command = $in
    return $"(ansi default_dimmed)(ansi default_italic)($command)(ansi reset)"
}

# give a hint error when the clip command is not available on the system
export def check-clipboard [
    clipboard: string  # the clipboard command name
    --system: string  # some information about the system running, for better error
] {
    if (which $clipboard | is-empty) {
        error make --unspanned {
            msg: $"(ansi red)clipboard_not_found(ansi reset):
    you are running ($system)
    but
    the ($clipboard | pretty-command) clipboard command was not found on your system."
        }
    }
}

# put the end of a pipe into the system clipboard to copy contents
export def clip [
    --silent # do not print the content of the clipboard to the standard output
    --no-notify  # do not throw a notification (only on linux)
    --no-strip # do not strip ANSI escape sequences from a string
    --expand (-e) # auto-expand the data given as input
    --codepage (-c): int  # the id of the codepage to use (only on Windows), see https://en.wikipedia.org/wiki/Windows_code_page, e.g. 65001 is for UTF-8
] {
    let input = (
        $in
        | if $expand { table --expand } else { table }
        | into string
        | if $no_strip {} else { ansi strip }
    )

    match $nu.os-info.name {
        "linux" => {
            if ($env.WAYLAND_DISPLAY? | is-empty) {
                check-clipboard xclip --system $"('xorg' | pretty-command) on linux"
                $input | xclip -sel clip
            } else {
                check-clipboard wl-copy --system $"('wayland' | pretty-command) on linux"
                $input | wl-copy
            }
        },
        "windows" => {
            if $codepage != null {
                chcp $codepage
            }
            check-clipboard clip.exe --system "Windows"
            $input | clip.exe
        },
        "macos" => {
            check-clipboard pbcopy --system "MacOS"
            $input | pbcopy
        },
        "android" => {
            check-clipboard termux-clipboard-set --system "Termux"
            $input | termux-clipboard-set
        },
        _ => {
            error make --unspanned {
                msg: $"(ansi red)unknown_operating_system(ansi reset):
    '($nu.os-info.name)' is not supported by the ('clip' | pretty-command) command.

    please open a feature request in the [issue tracker](char lparen)https://github.com/nushell/nushell/issues/new/choose(char rparen) to add your operating system to the standard library."
            }
        },
    }

    if not $silent {
        print $input
        print $"(ansi white_italic)(ansi white_dimmed)saved to clipboard(ansi reset)"
    }

    if (not $no_notify) and ($nu.os-info.name == linux) {
        notify-send "std clip" "saved to clipboard"
    }
}
