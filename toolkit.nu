# Create a symlink
export def symlink [
    existing: path   # The existing file
    new_link_name: path  # The name of the symlink
    --force(-f)     # if target exists moves it to
] {
    print $"(ansi purple_bold)Creating symlink(ansi reset) ($existing) --> ($new_link_name)"
    let existing = ($existing | path expand --strict | path split | path join)
    let $new_link_name = ($new_link_name | path expand --no-symlink | path split | path join)


    # create parent folder if it doesn't exist
    mkdir ($new_link_name | path dirname)

    if ($force and ($new_link_name | path exists)) {
       rm --recursive $new_link_name
    }

    if $nu.os-info.family == 'windows' {
        if ($existing | path type) == 'dir' {
            print $"dir link created ($new_link_name)"
            mklink /D $new_link_name $existing
        } else {
            print $"file link created ($new_link_name)"
            mklink $new_link_name $existing
        }
    } else {
        print $"link created ($new_link_name)"
        ln -s $existing $new_link_name | ignore
    }
}

export def ask_yes_no [question: string] {
    return (
        match (input $"(ansi purple_bold)($question)(ansi reset) [y/n]") {
          "y" | "yes" | "Y" => true,
          _ => false,
        }
    )
}


export def "config glazewm" [] {
    let config_dir = '~/.glzr/glazewm'
    symlink --force ~/src/dotfiles/config/glazewm/ $config_dir
}

export def "config foot" [] {
    let config_dir = '~/.config/foot'
    symlink --force ~/src/dotfiles/config/foot/ $config_dir
}

export def "config sway" [] {
    let config_dir = '~/.config/sway'
    symlink --force ~/src/dotfiles/config/sway/ $config_dir
}

# broken on windows, using workaround
# YAZI_CONFIG_HOME=~/src/dotfiles/config/yazi/
export def "config yazi" [] {
    let config_dir = match $nu.os-info.name {
        "windows" => '~\AppData\Roaming\yazi' ,
        _ => "~/.config/yazi" ,
    }
    symlink --force ~/src/dotfiles/config/yazi/ $config_dir
}

export def "config flowlauncher" [] {
    let config_dir = '~\AppData\Roaming\FlowLauncher'
    symlink --force ~/src/dotfiles/config/flowlauncher/ $config_dir
}

export def "config pueue" [] {
    let config_dir = match $nu.os-info.name {
        "windows" => '~\AppData\Roaming\pueue' ,
        "macos" => '~/Library/Application Support/pueue' ,
        _ => "~/.config/pueue" ,
    }
    symlink --force ~/src/dotfiles/config/pueue/ $config_dir
}

export def "config broot" [] {
    let broot_config_dir = match $nu.os-info.name {
        "windows" => '~\AppData\Roaming\dystroy\broot' ,
        _ => "~/.config/broot" ,
    }
    if not ($broot_config_dir | path exists) { mkdir $broot_config_dir }
    symlink --force ~/src/dotfiles/config/broot $broot_config_dir
}

export def "config bacon" [] {
    let bacon_config_dir = match $nu.os-info.name {
        "windows" => '~\AppData\Roaming\dystroy\bacon\config' ,
        "macos" => '~/Library/Application Support/org.dystroy.bacon' ,
        _ => "~/.config/bacon" ,
    }
    if not ($bacon_config_dir | path exists) { mkdir $bacon_config_dir }
    symlink --force ~/src/dotfiles/config/bacon $bacon_config_dir
}

export def "config nushell" [] {
    if (not ('~/src/nushell-config' | path exists)) {
        git clone https://github.com/francescelies/nushell-config ~/src/nushell-config
        cd ~/src/nushell-config
        nu bootstrap.nu
    }
}

export def "config python" [] {
    # uv
    if (which ^uv | is-empty ) {
        match $nu.os-info.name {
            "windows" => { powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex" }
            _ => { curl -LsSf https://astral.sh/uv/install.sh | sh },
        }
    }

    # prevent pip from installing packages in the global installation
    mkdir ~/.pip/
    "
    [install]
    require-virtualenv = true
    [uninstall]
    require-virtualenv = true
    " | save -f ~/.pip/pip.conf
}

export def "config yt-dlp" [] {
    let yt_dlp = "~/bin/yt-dlp" | path expand
    if (not ($yt_dlp | path exists)) { http get https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp | save -f $yt_dlp }
}

export def "config keyd-remap" [] {
    if (not ('~/src/oss/keyd' | path exists)) {
        git clone https://github.com/rvaiya/keyd ~/src/oss/keyd
        cd ~/src/oss/keyd
        make
        sudo make install
        "
[ids]

*

[main]

# Maps capslock to escape when pressed and control when held.
capslock = overload(control, esc)

# Remaps the escape key to capslock
esc = capslock
" | sudo tee /etc/keyd/default.conf

        sudo systemctl enable --now keyd
    }


}

export def bootstrap [] {
    mkdir ~/src/work
    mkdir ~/src/oss

    symlink --force ~/src/dotfiles/.inputrc ~/.inputrc

    config nushell
    config python
    config yt-dlp
    config bacon
    config broot
    config pueue
    config yazi

    match $nu.os-info.name {
        "windows" => {
            config glazewm
            config flowlauncher
        },
        "linux" => {
            config sway
            config foot
            # config keyd-remap
        }
        "macos" => {

        },
        _ => {

        },
    }
}

export def main [] { help toolkit }
