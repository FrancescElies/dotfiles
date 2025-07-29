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
    print $"(ansi purple_bold)config glazewm(ansi reset)"
    let config_dir = '~/.glzr/glazewm'
    symlink --force ~/src/dotfiles/config/glazewm/ $config_dir
}

export def "config foot" [] {
    print $"(ansi purple_bold)config foot(ansi reset)"
    let config_dir = '~/.config/foot'
    symlink --force ~/src/dotfiles/config/foot/ $config_dir
}

export def "config sway" [] {
    print $"(ansi purple_bold)config sway(ansi reset)"
    let config_dir = '~/.config/sway'
    symlink --force ~/src/dotfiles/config/sway/ $config_dir
}

# broken on windows, using workaround
# YAZI_CONFIG_HOME=~/src/dotfiles/config/yazi/
export def "config yazi" [] {
    print $"(ansi purple_bold)config yazi(ansi reset)"
    let config_dir = match $nu.os-info.name {
        "windows" => '~\AppData\Roaming\yazi' ,
        _ => "~/.config/yazi" ,
    }
    symlink --force ~/src/dotfiles/config/yazi/ $config_dir
}

export def "config flowlauncher" [] {
    print $"(ansi purple_bold)config flowlauncher(ansi reset)"
    let config_dir = '~\AppData\Roaming\FlowLauncher'
    symlink --force ~/src/dotfiles/config/flowlauncher/ $config_dir
}

export def "config nvim" [] {
    print $"(ansi purple_bold)config nvim(ansi reset)"
    cd ~/src
    if (not ('nushell-config' | path exists)) {
        git clone https://github.com/francescelies/kickstart.nvim
    }
    cd kickstart.nvim
    nu bootstrap.nu

    cd ~/src
    if (not ('neovim' | path exists)) {
        git clone https://github.com/neovim/neovim --depth 1
    }
    cd neovim
    make CMAKE_BUILD_TYPE=RelWithDebInfo
    print $"(ansi pi)neovim: make install(ansi reset)"
    su -c "make install"
}


export def "config nushell" [] {
    print $"(ansi purple_bold)config nushell(ansi reset)"
    cd ~/src
    if (not ('nushell-config' | path exists)) {
        git clone https://github.com/francescelies/nushell-config
    }
    cd ~/src/nushell-config
    nu bootstrap.nu
}

export def "config fonts" [] {
    print $"(ansi purple_bold)config fonts(ansi reset)"
    ls config/fonts/ | where type == dir | each {
        print $"(ansi pi)cp -r ($in.name) /usr/local/share/fonts/(ansi reset)"
        su -c $"cp -r ($in.name) /usr/local/share/fonts/"
    }
}

export def "config python" [] {
    print $"(ansi purple_bold)config python(ansi reset)"
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
    print $"(ansi purple_bold)config yt-dlp(ansi reset)"
    let yt_dlp = "~/bin/yt-dlp" | path expand
    if (not ($yt_dlp | path exists)) { http get https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp | save -f $yt_dlp }
}

export def "config keyd-remap" [] {
    print $"(ansi purple_bold)config keyd-remap(ansi reset)"
    if (not ('~/src/oss/keyd' | path exists)) {
        git clone https://github.com/rvaiya/keyd ~/src/oss/keyd
        cd ~/src/oss/keyd
        make
        su -c "make install"
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
            config fonts
        }
        "macos" => {

        },
        _ => {

        },
    }
}
