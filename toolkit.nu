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

export def "install glazewm" [] {
    print $"(ansi purple_bold)install glazewm(ansi reset)"
    let config_dir = '~/.glzr/glazewm'
    cargo install --git https://github.com/Dutch-Raptor/GAT-GWM.git --features=no_console
    symlink --force ~/src/dotfiles/config/glazewm/ $config_dir
}

export def "config foot" [] {
    print $"(ansi purple_bold)config foot(ansi reset)"
    let config_dir = '~/.config/foot'
    symlink --force ~/src/dotfiles/config/foot/ $config_dir
}

export def "install sway" [] {
    print $"(ansi purple_bold)install sway(ansi reset)"
    sudo apt install -y foot sway swayidle kanshi wl-clipboard brightnessctl wlsunset zathura wf-recorder mako-notifier blueman alacritty wofi clipman bemenu udiskie golang
    go install github.com/darkhz/bluetuith@latest
    # install volume manager
    sudo apt install -y pamixer
    # install wifi manager
    sudo apt install -y libdbus-1-dev pkg-config
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

export def "install zig" [] {
    print $"(ansi purple_bold)install zig(ansi reset)"
    let id = version | get build_os | parse "{os}-{arch}" | $"($in.0.arch)-($in.0.os)"
    let pkg = http get https://ziglang.org/download/index.json | get master | get $id
    let file_name = $pkg.tarball | path basename
    let dir = mktemp -d
    cd $dir
    http get $pkg.tarball | save $file_name
    let _ = ouch decompress $file_name | complete
    let uncompressed = ls | where $it.type == dir | first | get name
    mv $uncompressed ~/bin/
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

export def "install nvim" [] {
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

export def "config pueue" [] {
    let config_dir = match $nu.os-info.name {
        "windows" => '~\AppData\Roaming\pueue' ,
        "macos" => '~/Library/Application Support/pueue' ,
        _ => "~/.config/pueue" ,
    }
    symlink --force ~/src/dotfiles/config/pueue/ $config_dir
}

export def "install fonts" [] {
    print $"(ansi purple_bold)install fonts(ansi reset)"
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

export def "install keyd-remap" [] {
    print $"(ansi purple_bold)install keyd-remap(ansi reset)"
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

    let alacritty_conf = ($env.APPDATA | path join "alacritty")
    rm -rf $alacritty_conf
    mklink /j ($alacritty_conf | path expand)  ('~/src/dotfiles/config/alacritty' | path expand --strict)
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
    cargo binstall -y ...(open $packages_toml | get rust-pkgs | transpose | get column0)

    if $nu.os-info.family != 'windows' {
        sudo cp ~/.cargo/bin/tldr  /usr/local/bin/
        sudo cp ~/.cargo/bin/difft  /usr/local/bin/
        sudo cp ~/.cargo/bin/btm   /usr/local/bin/
        sudo cp ~/.cargo/bin/ouch  /usr/local/bin/
    }
}

export def "rust dev-packages" [] {
    cargo binstall -y ...(open $packages_toml | get rust-dev-pkgs | transpose | get column0)
}

export def "config broot" [] {
    let broot_config_dir = match $nu.os-info.name {
        "windows" => '~\AppData\Roaming\dystroy\broot' ,
        _ => "~/.config/broot" ,
    }
    if not ($broot_config_dir | path exists) { mkdir $broot_config_dir }
    symlink --force ~/src/dotfiles/config/broot $broot_config_dir
}

export def "config psql" [] {
    symlink --force ~/src/dotfiles/config/.psqlrc ~/.psqlrc
}

export def "config radare2" [] {
    symlink --force ~/src/dotfiles/config/.radare2rc ~/.radare2rc
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

export def bootstrap [] {
    mkdir ~/bin
    mkdir ~/src/work
    mkdir ~/src/oss

    symlink --force ~/src/dotfiles/.inputrc ~/.inputrc

    config fd
    config python
    config yt-dlp
    config bacon
    config radare2
    config psql
    config broot
    config pueue

    match $nu.os-info.name {
        "windows" => {
            if (which ^rustup | is-empty ) {
                input $"(ansi purple_bold)Install https://rustup.rs/(ansi reset) once done press enter."
            }
            install glazewm
            config flowlauncher
            let winget_install = $"winget install --silent (open $packages_toml  | get windows | transpose | get column0 | str join ' ')"
            input $"(ansi bb)run as admin(ansi reset): (ansi pi)($winget_install)(ansi reset) - press enter when done"
            windows config terminal
        },
        "linux" => {
            if (which ^rustup | is-empty ) {
                curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
                rustup component add llvm-tools rust-analyzer
            }
            install sway
            config foot
            install keyd-remap
            install fonts
            sudo apt remove -y nano
            sudo apt install -y ...(open packages.toml | get debian | transpose | get column0)
            install nvim  # last might take long
            linux config terminal
        }
        "macos" => {
            if (which ^rustup | is-empty ) {
                curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
                rustup component add llvm-tools rust-analyzer
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
    if (which zig | is-empty) {
        install zig
    }
}
