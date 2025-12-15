use src/symlinks.nu symlink

export def main [] {
    let nushell_dir = match $nu.os-info.name {
        "windows" => '~\AppData\Roaming\nushell' ,
        "macos" => "~/Library/Application Support/nushell" ,
        _ => "~/.config/nushell" ,
    }
    if not ($nushell_dir | path exists) { mkdir $nushell_dir }
    symlink --force ~/src/dotfiles/config/nushell/env.nu ($nushell_dir | path join "env.nu")
    symlink --force ~/src/dotfiles/config/nushell/config.nu ($nushell_dir | path join "config.nu")
}

main
