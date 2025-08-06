const current_dir = path self .
const packages_toml = ($current_dir | path join packages.toml)

# Create a symlink
def symlink [
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

def ask_yes_no [question: string] {
    return (
        match (input $"(ansi purple_bold)($question)(ansi reset) [y/n]") {
          "y" | "yes" | "Y" => true,
          _ => false,
        }
    )
}

export def "config fd" [] {
    if $nu.os-info.family == 'windows' {
        symlink --force ~/src/dotfiles/config/fd ~/AppData/Roaming/fd
    } else {
        symlink --force ~/src/dotfiles/config/fd ~/.config/fd
    }
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
    sudo apt install -y foot sway swayidle kanshi wl-clipboard brightnessctl wlsunset zathura wf-recorder mako-notifier blueman alacritty wofi clipman bemenu
    go install github.com/darkhz/bluetuith@latest
    # install wifi manager
    sudo apt install libdbus-1-dev pkg-config
    if (which impala | is-empty) {
        cargo install impala
    }
    # install bluetooth manager
    if (which bluetui | is-empty) {
        cargo install bluetui
    }
    symlink --force ~/src/dotfiles/config/sway/ ~/.config/sway
    symlink --force ~/src/dotfiles/config/fuzzel/ ~/.config/fuzzel
    symlink --force ~/src/dotfiles/config/kanshi/ ~/.config/kanshi
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
    let config_dir = '~\AppData\Roaming\FlowLauncher' | path expand
    let settings_file = $config_dir | path join Settings/Settings.json
    if ($settings_file | path exists) {
        let settings = open  --raw $settings_file
        ( $settings
        | str replace '"Hotkey": "Alt \u002B Space"' '"Hotkey": "Alt \u002B D"'
        | save -f $settings_file
        )
    }
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
    sudo make install
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
        sudo cp -r ($in.name) /usr/local/share/fonts/
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

    # create home python virtual environment
    cd ~
    if not ('.venv' | path exists) {
        uv venv
    }
    uv pip install ...(open $packages_toml | get python | transpose | get column0)

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
    }
    cd ~/src/oss/keyd
    make
    sudo make install
    sudo cp ~/src/dotfiles/config/keyd/default.conf /etc/keyd/default.conf
    sudo systemctl enable --now keyd
}

export def "linux config terminal" [] {
    # rm -rf ~/.config/wezterm
    # rm -rf ~/.config/zellij
    ln -snf ("./config/alacritty" | path expand) ~/.config/alacritty
    ln -snf ("./config/wezterm" | path expand) ~/.config/wezterm
    ln -snf ("./config/zellij" | path expand) ~/.config/zellij
}

export def "macos config wm" [] {
    print $"(ansi pi)macos config wm(ansi reset)"
    ln -shf ("./config/aerospace" | path expand) ~/.config/aerospace
}

export def "macos config terminal" [] {
    print $"(ansi pi)macos config terminal(ansi reset)"
    # rm -rf ~/.config/wezterm
    # rm -rf ~/.config/zellij
    ln -shf ("./config/alacritty" | path expand) ~/.config/alacritty
    ln -shf ("./config/wezterm" | path expand) ~/.config/wezterm
    ln -shf ("./config/zellij" | path expand) ~/.config/zellij
}

export def "windows config terminal" [] {
    rm -rf ~/.config/wezterm
    mklink /j ("~/.config/wezterm" | path expand)  ('~/src/dotfiles/config/wezterm' | path expand --strict)
    mklink /j ($env.APPDATA | path join "alacritty" | path expand)  ('~/src/dotfiles/alacritty' | path expand --strict)

    nu ./windows-terminal/install.nu
}


export def "linux fix printer-samsung-M2026" [] {
    print $"(ansi pi)linux fix printer-samsung-M2026(ansi reset)"
    git clone https://github.com/francescElies/samsung-uld-copy
    cd samsung-uld-copy
    just
}

export def "linux fix wifi-after-sleep" [] {
    print $"(ansi pi)linux fix wifi-after-sleep(ansi reset)"
    su -c "cp fixes/wifi_rand_mac.conf /etc/NetworkManager/conf.d/"
}

export def "linux fix closed-laptop-lid-should-not-suspend" [] {
  sudo mkdir /etc/systemd/logind.conf.d/
  sudo cp fixes/ignore-closed-lid.conf /etc/systemd/logind.conf.d/ignore-closed-lid.conf
}

export def "rust packages" [] {
    if (which ^cargo-binstall | is-empty ) { cargo install cargo-binstall }
    ~/.cargo/bin/cargo binstall -y ...(open $packages_toml | get rust-pkgs | transpose | get column0)
    sudo cp ~/.cargo/bin/tldr  /usr/local/bin/
    sudo cp ~/.cargo/bin/difft  /usr/local/bin/
    sudo cp ~/.cargo/bin/btm   /usr/local/bin/
    sudo cp ~/.cargo/bin/ouch  /usr/local/bin/
}

export def "rust dev-packages" [] {
    ~/.cargo/bin/cargo binstall -y ...(open $packages_toml | get rust-dev-pkgs | transpose | get column0)
}

export def bootstrap [] {
    mkdir ~/src/work
    mkdir ~/src/oss

    symlink --force ~/src/dotfiles/.inputrc ~/.inputrc

    config fd
    config nushell
    config python
    config yt-dlp
    config yazi

    match $nu.os-info.name {
        "windows" => {
            if (which ^rustup | is-empty ) {
                input $"(ansi purple_bold)Install https://rustup.rs/(ansi reset) once done press enter."
            }
            if (not (try { open src/os-this-machine.nu | str contains "use os-windows.nu *" } catch { false })) {
                "use os-windows.nu *" | save --append src/os-this-machine.nu
            }
            config glazewm
            config flowlauncher
            sudo winget install --silent ...(open $packages_toml  | get windows | transpose | get column0)
            windows config terminal
        },
        "linux" => {
            if (which ^rustup | is-empty ) {
                curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
                ~/.cargo/bin/rustup component add llvm-tools rust-analyzer
            }
            if (not (try { open src/os-this-machine.nu | str contains "use os-linux.nu *" } catch { false })) {
                "use os-linux.nu *" | save --append src/os-this-machine.nu
            }
            config sway
            config foot
            config keyd-remap
            config fonts
            sudo apt remove -y nano
            sudo apt install -y ...(open packages.toml | get debian | transpose | get column0)
            config nvim  # last might take long
            linux config terminal
        }
        "macos" => {
            if (which ^rustup | is-empty ) {
                curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
                ~/.cargo/bin/rustup component add llvm-tools rust-analyzer
            }
            if (not (try { open src/os-this-machine.nu | str contains "use os-mac.nu *" } catch { false })) {
                "use os-mac.nu *" | save --append src/os-this-machine.nu
            }

            brew install --force ...(open packages.toml | get mac-brew | transpose | get column0)
            brew install --force --cask ...(open packages.toml | get mac-brew-cask | transpose | get column0)
            macos config terminal
            macos config wm
        },
        _ => {

        },
    }
    rust packages
}
