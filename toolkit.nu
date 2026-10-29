const repo_dir = path self .

# Create a symlink
def symlink [
    existing: path   # The existing file
    new_link_name: path  # The name of the symlink
    --force(-f)     # if target exists moves it to
] {
    print $"(ansi purple_bold)Creating symlink(ansi reset) ($existing) --> ($new_link_name)"
    if (not ($existing | path exists)) {
        print $"(ansi purple_bold)not found: (ansi reset) ($existing)"
        return
    }
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

use packages.nu

export def "setup nushell" [] {
    print $"(ansi purple_bold)setup nushell(ansi reset)"
    let nushell_dir = match $nu.os-info.name {
        "windows" => '~\AppData\Roaming\nushell' ,
        "macos" => "~/Library/Application Support/nushell" ,
        _ => "~/.config/nushell" ,
    }
    if not ($nushell_dir | path exists) { mkdir $nushell_dir }

    if not ($repo_dir | path join 'config/nushell/src/os-this-machine.nu' | path exists) {
        match $nu.os-info.name {
            "windows" => 'use os-windows.nu *' ,
            "macos" => "use os-mac.nu *" ,
            _ => "use os-linux.nu *" ,
        } | save ($repo_dir | path join 'config/nushell/src/os-this-machine.nu')
    }

    symlink --force ($repo_dir | path join 'config/nushell/env.nu') ($nushell_dir | path join "env.nu")
    symlink --force ($repo_dir | path join 'config/nushell/config.nu') ($nushell_dir | path join "config.nu")
}

export def "setup fd" [] {
    print $"(ansi purple_bold)setup fd(ansi reset)"
    if $nu.os-info.family == 'windows' {
        symlink --force ($repo_dir | path join 'config/fd') ~/AppData/Roaming/fd
    } else {
        symlink --force ($repo_dir | path join 'config/fd') ~/.config/fd
    }
}

def "install glazewm" [] {
    print $"(ansi purple_bold)install glazewm(ansi reset)"
    let config_dir = '~/.glzr/glazewm'
    # cargo install --git https://github.com/Dutch-Raptor/GAT-GWM.git --features=no_console
    symlink --force ($repo_dir | path join 'config/glazewm/') $config_dir
}

export def "setup foot" [] {
    print $"(ansi purple_bold)setup foot(ansi reset)"
    let config_dir = '~/.config/foot'
    symlink --force ($repo_dir | path join 'config/foot/') $config_dir
}

export def "setup aba" [] {
    print $"(ansi purple_bold)setup aba(ansi reset)"
    symlink --force ($repo_dir | path join 'local/share/aba.toml') ~/.local/share/aba.toml
}

def "install sway" [] {
    print $"(ansi purple_bold)install sway(ansi reset)"
    if not ('/usr/bin/sway' | path exists) {
        print $"(ansi pi)sudo apt install -y foot sway swayidle kanshi wl-clipboard brightnessctl wlsunset zathura wf-recorder mako-notifier blueman alacritty wofi clipman bemenu udiskie golang(ansi reset)"
        sudo apt install -y foot sway swayidle kanshi wl-clipboard brightnessctl wlsunset zathura wf-recorder mako-notifier blueman alacritty wofi clipman bemenu udiskie golang
        go install github.com/darkhz/bluetuith@latest
        # install volume manager
        print $"(ansi pi)sudo apt install -y pamixer(ansi reset)"
        sudo apt install -y pamixer
        # install wifi manager
        print $"(ansi pi)sudo apt install -y libdbus-1-dev pkg-config(ansi reset)"
        sudo apt install -y libdbus-1-dev pkg-config
        if (which impala | is-empty) {
            cargo install impala
        }
        # install bluetooth manager
        if (which bluetui | is-empty) {
            cargo install bluetui
        }
        symlink --force ($repo_dir | path join 'config/waybar/') ~/.config/waybar
        symlink --force ($repo_dir | path join 'config/sway/') ~/.config/sway
        symlink --force ($repo_dir | path join 'config/fuzzel/') ~/.config/fuzzel
        symlink --force ($repo_dir | path join 'config/kanshi/') ~/.config/kanshi
    }
}

def "install zig" [] {
    print $"(ansi purple_bold)install zig(ansi reset)"
    let id = version | get build_os | parse "{os}-{arch}" | $"($in.0.arch)-($in.0.os)"
    let pkg = http get https://ziglang.org/download/index.json | get master | get $id
    let file_name = $pkg.tarball | path basename
    let dir = mktemp -d
    cd $dir
    http get $pkg.tarball | save $file_name
    ouch decompress $file_name | complete | ignore
    let uncompressed = ls | where $it.type == dir | first | get name
    try { mv $uncompressed ~/bin }
}

export def "setup flowlauncher" [] {
    print $"(ansi purple_bold)setup flowlauncher(ansi reset)"
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

def "install neovim" [] {
    print $"(ansi purple_bold)install neovim(ansi reset)"
    cd ~/src
    if (not ('kickstart.nvim' | path exists)) {
        git clone https://github.com/francescelies/kickstart.nvim
    }
    cd kickstart.nvim
    nu bootstrap.nu

    cd ~/src
    if (not ('neovim' | path exists)) {
        git clone https://github.com/neovim/neovim --depth 1
    }
    cd neovim
    if (not ('/usr/local/bin/nvim' | path exists)) {
        make CMAKE_BUILD_TYPE=Release
        print $"(ansi pi)neovim: make install(ansi reset)"
        print $"(ansi pi)sudo make install(ansi reset)"
        sudo make install
    }
}

export def "setup kanata" [] {
    let config_dir = match $nu.os-info.name {
        "windows" => '~\AppData\Roaming\kanata' ,
        "macos" => '~/Library/Application Support/kanata' ,
        _ => "~/.config/kanata" ,
    }
    symlink --force ($repo_dir | path join 'config/kanata/') $config_dir
}

export def "setup pueue" [] {
    let config_dir = match $nu.os-info.name {
        "windows" => '~\AppData\Roaming\pueue' ,
        "macos" => '~/Library/Application Support/pueue' ,
        _ => "~/.config/pueue" ,
    }
    symlink --force ($repo_dir | path join 'config/pueue/') $config_dir
}

export def "install fonts" [] {
    print $"(ansi purple_bold)install fonts(ansi reset)"
    let dirs = (ls config/fonts/ | where type == dir)
    mut copied = false
    for row in $dirs {
        let dir = $row.name
        if not (('/usr/local/share/fonts' | path join ($dir | path basename)) | path exists) {
            print $"(ansi pi)cp -r ($dir) /usr/local/share/fonts/(ansi reset)"
            print $"(ansi pi)sudo cp -r $dir /usr/local/share/fonts/(ansi reset)"
            sudo cp -r $dir /usr/local/share/fonts/
            $copied = true
        }
    }
    if $copied {
        print $"(ansi pi)fc-cache -fv(ansi reset)"
        print $"(ansi pi)sudo fc-cache -fv(ansi reset)"
        sudo fc-cache -fv
    }
}

export def "setup python" [] {
    print $"(ansi purple_bold)setup python(ansi reset)"
    # uv
    if (which ^uv | is-empty ) {
        match $nu.os-info.name {
            "windows" => { powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex" }
            _ => { curl -LsSf https://astral.sh/uv/install.sh | sh },
        }
    }

    # create home python virtual environment
    cd ~
    print $"(ansi purple_bold)setup python venv: ($packages.packages.python)(ansi reset)"
    if not ('.venv' | path exists) { uv venv }
    uv pip install ...($packages.packages.python)

    print $"(ansi purple_bold)setup python tools: ($packages.packages.python-tools)(ansi reset)"
    ($packages.packages.python-tools) | each { uv tool install $in }

    symlink --force ($repo_dir | path join 'config/ipython/config.py') ~/.ipython/profile_default/ipython_config.py

    # prevent pip from installing packages in the global installation
    mkdir ~/.pip/
    "
    [install]
    require-virtualenv = true
    [uninstall]
    require-virtualenv = true
    " | save -f ~/.pip/pip.conf
}

export def "install wezterm" [method: string@["flatpak" "source"] = "source"] {
    print $"(ansi purple_bold)install wezterm(ansi reset)"
    if not (which wezterm | is-empty) {
        print $"(ansi yellow)wezterm already installed(ansi reset)"
        return
    }
    if $method == "source" {
        if (which ^openssl | is-empty) or (not ('/usr/include/openssl/ssl.h' | path exists)) {
            print $"(ansi pi)sudo apt install -y libssl-dev pkg-setup libwayland-dev librust-wayland-client-dev libxkbcommon-dev libfontconfig1-dev(ansi reset)"
            sudo apt install -y libssl-dev pkg-setup libwayland-dev librust-wayland-client-dev libxkbcommon-dev libfontconfig1-dev
        }
        cd ~/src/oss
        if not ('~/src/oss/wezterm' | path exists) {
            git clone --depth 1 https://github.com/wez/wezterm
        }
        cd wezterm
        cargo build --release
        print $"(ansi pi)sudo cp target/release/wezterm /usr/local/bin/wezterm(ansi reset)"
        sudo cp target/release/wezterm /usr/local/bin/wezterm
    } else {
        if (which flatpak | is-empty) { sudo apt install -y flatpak }
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        flatpak install -y flathub org.wezfurlong.wezterm
    }
}

export def "setup yt-dlp" [] {
    print $"(ansi purple_bold)setup yt-dlp(ansi reset)"
    let yt_dlp = "~/bin/yt-dlp" | path expand
    if (not ($yt_dlp | path exists)) { http get https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp | save -f $yt_dlp }
}

def "install debian packages" [] {
    print $"(ansi pi)install debian packages(ansi reset)"
    print $"(ansi pi)sudo apt install -y ...($packages.packages.debian)(ansi reset)"
    sudo apt install -y ...($packages.packages.debian)
    print $"(ansi pi)sudo systemctl enable syncthing@cesc.service(ansi reset)"
    sudo systemctl enable syncthing@cesc.service
    print $"(ansi pi)sudo apt show ntpsec-ntpdate(ansi reset)"
    sudo apt show ntpsec-ntpdate
}

def "install keyd-remap" [] {
    print $"(ansi purple_bold)install keyd-remap(ansi reset)"
    if (not ('~/src/oss/keyd' | path exists)) {
        git clone https://github.com/rvaiya/keyd ~/src/oss/keyd
    }
    if (not ('/usr/local/bin/keyd' | path exists)) {
        cd ~/src/oss/keyd
        make
        print $"(ansi pi)sudo make install(ansi reset)"
        sudo make install
        print $"(ansi pi)sudo cp ($repo_dir | path join 'config/keyd/default.conf') /etc/keyd/default.conf(ansi reset)"
        sudo cp ($repo_dir | path join 'config/keyd/default.conf') /etc/keyd/default.conf
        print $"(ansi pi)sudo systemctl enable --now keyd(ansi reset)"
        sudo systemctl enable --now keyd
    }
}

def "linux setup terminal" [] {
    # rm -rf ~/.config/wezterm
    # rm -rf ~/.config/zellij
    ln -snf ("./config/alacritty" | path expand) ~/.config/alacritty
    ln -snf ("./config/wezterm" | path expand) ~/.config/wezterm
    ln -snf ("./config/zellij" | path expand) ~/.config/zellij
}

def "macos setup wm" [] {
    print $"(ansi pi)macos setup wm(ansi reset)"
    ln -shf ("./config/aerospace" | path expand) ~/.config/aerospace
}

def "macos setup terminal" [] {
    print $"(ansi pi)macos setup terminal(ansi reset)"
    # rm -rf ~/.config/wezterm
    # rm -rf ~/.config/zellij
    ln -shf ("./config/alacritty" | path expand) ~/.config/alacritty
    ln -shf ("./config/wezterm" | path expand) ~/.config/wezterm
    ln -shf ("./config/zellij" | path expand) ~/.config/zellij
}

export def "windows setup terminal" [] {
    symlink --force ("./config/wezterm" | path expand) ~/.config/wezterm
    symlink --force ("./config/alacritty/" | path expand) ~/AppData/Roaming/alacritty
    symlink --force ("./config/zellij" | path expand) ~/AppData/Roaming/Zellij/config/
}

export def "linux fix printer-samsung-M2026" [] {
    print $"(ansi pi)linux fix printer-samsung-M2026(ansi reset)"
    if not (samsung-uld-copy | path exists) {
        git clone https://github.com/francescElies/samsung-uld-copy
    }
    cd samsung-uld-copy
    just
}

export def "linux fix wifi-after-sleep" [] {
    print $"(ansi pi)linux fix wifi-after-sleep(ansi reset)"
    su -c "cp fixes/wifi_rand_mac.conf /etc/NetworkManager/conf.d/"
}

export def "linux fix closed-laptop-lid-should-not-suspend" [] {
  print $"(ansi pi)sudo mkdir /etc/systemd/logind.conf.d/(ansi reset)"
  sudo mkdir /etc/systemd/logind.conf.d/
  print $"(ansi pi)sudo cp fixes/ignore-closed-lid.conf /etc/systemd/logind.conf.d/ignore-closed-lid.conf(ansi reset)"
  sudo cp fixes/ignore-closed-lid.conf /etc/systemd/logind.conf.d/ignore-closed-lid.conf
}

def "go packages" [] {
    print 'go packages skiped'
    # go install ...($packages.packages.go-install)
}

def "rust packages" [] {
    print $"(ansi purple_bold)rust packages(ansi reset)"
    if (which ^cargo-binstall | is-empty ) { cargo install cargo-binstall }
    cargo binstall -y ...($packages.packages.rust-pkgs)

    if $nu.os-info.family != 'windows' {
        if not ('/usr/local/bin/tldr' | path exists) { sudo cp ~/.cargo/bin/tldr /usr/local/bin/ }
        if not ('/usr/local/bin/difft' | path exists) { sudo cp ~/.cargo/bin/difft /usr/local/bin/ }
        if not ('/usr/local/bin/btm' | path exists) { sudo cp ~/.cargo/bin/btm /usr/local/bin/ }
        if not ('/usr/local/bin/ouch' | path exists) { sudo cp ~/.cargo/bin/ouch /usr/local/bin/ }
        if not ('/usr/local/bin/diskonaut' | path exists) { sudo cp ~/.cargo/bin/diskonaut /usr/local/bin/ }
        if not ('/usr/local/bin/tree-sitter' | path exists) { sudo cp ~/.cargo/bin/tree-sitter /usr/local/bin/ }
    }
}

def "rust dev-packages" [] {
    print $"(ansi purple_bold)rust dev-packages(ansi reset)"
    cargo binstall -q -y ...($packages.packages.rust-dev-pkgs)
}

export def "setup himalaya" [] {
    let config_dir = match $nu.os-info.name {
        "windows" => '~\AppData\Roaming\himalaya' ,
        "macos" => "~/Library/Application Support/himalaya" ,
        _ => "~/.config/himalaya" ,
    }
    if not ($config_dir | path exists) { mkdir $config_dir }
    symlink --force ($repo_dir | path join 'config/himalaya') $config_dir
}

export def "setup broot" [] {
    let broot_config_dir = match $nu.os-info.name {
        "windows" => '~\AppData\Roaming\dystroy\broot' ,
        _ => "~/.config/broot" ,
    }
    if not ($broot_config_dir | path exists) { mkdir $broot_config_dir }
    symlink --force ($repo_dir | path join 'config/broot') $broot_config_dir
}

export def "setup psql" [] {
    symlink --force ($repo_dir | path join 'config/.psqlrc') ~/.psqlrc
}

export def "setup gnome-apps" [] {
    print $"(ansi purple_bold)setup gnome-apps(ansi reset)"
    let apps_dir = ($repo_dir | path join 'config/nushell/src/linux/gnome-apps')
    for file in (ls $apps_dir | where type == file) {
        let name = ($file.name | path basename)
        if ($name | str ends-with '.desktop') {
            print $"(ansi pi)sudo cp $file.name /usr/share/applications/$name(ansi reset)"
            sudo cp $file.name /usr/share/applications/$name
        } else {
            print $"(ansi pi)sudo cp $file.name /usr/share/icons/hicolor/256x256/apps/$name(ansi reset)"
            sudo cp $file.name /usr/share/icons/hicolor/256x256/apps/$name
        }
    }
    print $"(ansi pi)sudo update-desktop-database /usr/share/applications(ansi reset)"
    sudo update-desktop-database /usr/share/applications
}

export def "setup git" [] {
  # https://www.youtube.com/watch?v=aolI_Rz0ZqY
  # Apply some useful defaults
  # ^gmy-defaults
  #
  # Give me all my pull requests as local refs
  # ^git setup remote.origin.fetch '+refs/pull/*:refs/remotes/origin/pull/*'
  #
  # Conditional ~/.gitconfig
  #
  # [includelf "gitdir:~/projects/work/"]
  #   path = /s/.gitconfig
  # [includelf "gitdir:~/src/oss/"]
  #   path = ~/projects/oss/.gitconfig
  #
  # Accidentally cloned http repo version?
  # [url "git@github.com:"]
  #   insteadOf = "https://github.com/"
  # ^git maintenance start

  # https://jvns.ca/blog/2024/02/16/popular-git-config-options/#help-autocorrect-10
  ^git setup --global tag.sort -version:refname
  ^git setup --global branch.sort -committerdate
  ^git setup --global diff.algorithm histogram
  ^git setup --global fetch.prune true
  ^git setup --global help.autocorrect 10
  ^git setup --global help.autocorrect prompt
  ^git setup --global init.defaultBranch main
  ^git setup --global interactive.diffFilter delta --color-only
  ^git setup --global log.date iso
  # ^git setup --global merge.conflictstyle zdiff3
  ^git setup --global pull.rebase true
  ^git setup --global push.autosetupremote true
  ^git setup --global push.default current
  ^git setup --global rebase.autosquash true
  ^git setup --global rebase.autostash true
  ^git setup --global rebase.missingCommitsCheck error
  ^git setup --global rebase.updateRefs true

  ^git setup --global rebase.instructionFormat "(%an, %as) %s"

  # gpg
  # ^git setup --global format.signOff true
  # ^git setup --global user.signingKey 3B90F50EE678CC468870A2BEC6514C960DD0AC0B
  # ^git setup --global commit.gpgsign true
  # ^git setup --global tag.gpgsign true

  # Avoid data corruption
  ^git setup --global transfer.fsckobjects true
  ^git setup --global fetch.fsckobjects true
  ^git setup --global receive.fsckObjects true

  ^git setup --global merge.tool nvimdiff
  ^git setup --global merge.conflictstyle diff3
  ^git setup --global mergetool.nvimdiff.cmd 'nvim -d $LOCAL $REMOTE $MERGED -c "$wincmd w" -c "wincmd J"'
  ^git setup --global diff.tool nvimdiff
  ^git setup --global diff.colorMoved default


  # REuse REordered REsolution, tells ^git to remember conflicts so if it sees them again he won't ask about it.
  ^git setup --global rerere.enabled true
  ^git setup --global branch.sort -committerdate
  # ^git setup gpg.format ssh
  # ^git setup user.signingkey ~/.ssh/id_ed25519

  # Big repository stuff
  #
  # ^git clone filters:
  # ^git clone --fitter=blob:none
  # ^git clone --fitter=tree:zero
  #
  # See multipack indexes, reachability bitmaps and geometric repacking
  # https://github.blog/2021-04-29-scaling-monorepo-maintenance
  # ^git maintenance start will also write the commit-graph
  ^git setup --global fetch.writeCommitGraph true
  # file system monitory
  ^git setup --global core.untrackedcache true
  ^git setup --global feature.manyfiles true
  ^git setup --global core.fsmonitor true

  # ^git setup --global commit.template ($repo_dir | path join 'config/git/commit-template')
}

export def "setup bashrc" [] { symlink --force ($repo_dir | path join 'config/.bashrc') ~/.bashrc }
export def "setup inputrc" [] { symlink --force ($repo_dir | path join 'config/.inputrc') ~/.inputrc }
export def "setup radare2" [] { symlink --force ($repo_dir | path join 'config/.radare2rc') ~/.radare2rc }

export def "setup bacon" [] {
    let bacon_config_dir = match $nu.os-info.name {
        "windows" => '~\AppData\Roaming\dystroy\bacon\config' ,
        "macos" => '~/Library/Application Support/org.dystroy.bacon' ,
        _ => "~/.config/bacon" ,
    }
    if not ($bacon_config_dir | path exists) { mkdir $bacon_config_dir }
    symlink --force ($repo_dir | path join 'config/bacon') $bacon_config_dir
}

export def "setup meli" [] {
    let config_dir = match $nu.os-info.name {
        "windows" => 'TODO' ,
        "macos" => '~/.config/meli' ,
        _ => "~/.config/meli" ,
    }
    if not ($config_dir | path exists) { mkdir $config_dir }
    symlink --force ($repo_dir | path join 'config/meli') $config_dir
}

export def "setup aerc" [] {
    let config_dir = match $nu.os-info.name {
        "windows" => 'TODO' ,
        "macos" => '~/Library/Preferences/aerc/' ,
        _ => "~/.config/aerc" ,
    }
    if not ($config_dir | path exists) { mkdir $config_dir }
    symlink --force ($repo_dir | path join 'config/aerc') $config_dir
}

export def "setup neomutt" [] {
    let config_dir = match $nu.os-info.name {
        "windows" => 'TODO' ,
        _ => "~/.config/neomutt" ,
    }
    symlink --force ($repo_dir | path join 'config/neomutt') $config_dir
}

export def "setup herdr" [] {
    let config_dir = "~/.config/herdr"
    symlink --force ($repo_dir | path join 'config/herdr') $config_dir
}

export def "setup searxng" [] {
    symlink --force ($repo_dir | path join 'config/searxng') ~/searxng
    let conf = ("($repo_dir | path join 'config/searxng')" | path expand)
    podman rm -f searxng
    let secret = (random chars --length 64)
    podman create --name searxng --restart unless-stopped -p 8888:8080 -e $"SEARXNG_SECRET=($secret)" -v $"($conf):/etc/searxng" docker.io/searxng/searxng
}

export def bootstrap [] {
    mkdir ~/bin
    mkdir ~/src/work
    mkdir ~/src/oss

    mut errors = []
    def run-step [name: string, action: closure]: nothing -> string {
        try { do $action; "" } catch { |err| $"($name): ($err.msg)" }
    }
    let r1 = (run-step "setup git" { setup git })
    if $r1 != "" { $errors = ($errors | append $r1) }
    let r2 = (run-step "setup inputrc" { setup inputrc })
    if $r2 != "" { $errors = ($errors | append $r2) }
    let r3 = (run-step "setup bashrc" { setup bashrc })
    if $r3 != "" { $errors = ($errors | append $r3) }
    let r4 = (run-step "setup nushell" { setup nushell })
    if $r4 != "" { $errors = ($errors | append $r4) }
    let r5 = (run-step "setup fd" { setup fd })
    if $r5 != "" { $errors = ($errors | append $r5) }
    let r6 = (run-step "setup yt-dlp" { setup yt-dlp })
    if $r6 != "" { $errors = ($errors | append $r6) }
    let r7 = (run-step "setup bacon" { setup bacon })
    if $r7 != "" { $errors = ($errors | append $r7) }
    let r8 = (run-step "setup aerc" { setup aerc })
    if $r8 != "" { $errors = ($errors | append $r8) }
    let r9 = (run-step "setup neomutt" { setup neomutt })
    if $r9 != "" { $errors = ($errors | append $r9) }
    let r10 = (run-step "setup herdr" { setup herdr })
    if $r10 != "" { $errors = ($errors | append $r10) }
    let r11 = (run-step "setup meli" { setup meli })
    if $r11 != "" { $errors = ($errors | append $r11) }
    let r12 = (run-step "setup radare2" { setup radare2 })
    if $r12 != "" { $errors = ($errors | append $r12) }
    let r13 = (run-step "setup psql" { setup psql })
    if $r13 != "" { $errors = ($errors | append $r13) }
    let r14 = (run-step "setup broot" { setup broot })
    if $r14 != "" { $errors = ($errors | append $r14) }
    let r15 = (run-step "setup himalaya" { setup himalaya })
    if $r15 != "" { $errors = ($errors | append $r15) }
    let r16 = (run-step "setup pueue" { setup pueue })
    if $r16 != "" { $errors = ($errors | append $r16) }
    let r17 = (run-step "setup kanata" { setup kanata })
    if $r17 != "" { $errors = ($errors | append $r17) }
    let r18 = (run-step "setup python" { setup python })
    if $r18 != "" { $errors = ($errors | append $r18) }

    match $nu.os-info.name {
        "windows" => {
            if (which ^rustup | is-empty ) {
                input $"(ansi purple_bold)Install https://rustup.rs/(ansi reset) once done press enter."
                rustup component add llvm-tools rust-analyzer
            }
            install glazewm
            setup flowlauncher
            let winget_install = $"winget install --silent ($packages.packages.windows | str join ' ')"
            input $"(ansi bb)run as admin(ansi reset): (ansi pi)($winget_install)(ansi reset) - press enter when done"
            windows setup terminal
            symlink --force ($repo_dir | path join 'bin/windows-os/win-update.ps1') ~/Desktop/win-update.ps1
            symlink --force ($repo_dir | path join 'bin/windows-os/admin-term.ps1') ~/Desktop/admin-term.ps1
        },
        "linux" => {
            if (which sudo | is-empty) { error make {msg: "sudo required on Linux"} }
            if (which ^rustup | is-empty ) {
                curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
                rustup component add llvm-tools rust-analyzer
            }
            install sway
            setup foot
            setup aba
            install keyd-remap
            install fonts
            if not (which nano | is-empty) { sudo apt remove -y nano }
            if (which age | is-empty) { install debian packages }
            linux setup terminal
            install neovim  # last might take long
        }
        "macos" => {
            if (which ^rustup | is-empty ) {
                curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
                rustup component add llvm-tools rust-analyzer
            }

            brew install --force ...($packages.packages.mac-brew)
            brew install --force --cask ...($packages.packages.mac-brew-cask)
            macos setup terminal
            macos setup wm
        },
        _ => {

        },
    }
    rust packages
    go packages
    if (which zig | is-empty) {
        install zig
    }
    print $"(ansi purple_bold)to manage secrets https://github.com/getsops/sops/releases(ansi reset)"
    if ($errors | is-not-empty) {
        print ""
        print $"(ansi red_bold)Errors during bootstrap:(ansi reset)"
        for err in $errors { print $"  - ($err)" }
    }
    print ""
    print $"(ansi green_bold)Bootstrap complete. Verification:(ansi reset)"
    for tool in [nu git curl rg fzf fd nvim] {
        let found = if (which $tool | is-empty) { "MISSING" } else { "ok" }
        print $"  ($tool): ($found)"
    }
}
export def dotfiles-selftest [] {
    # ensure selftest image exists
    let image_exists = try { podman image exists localhost/selftest; true } catch { false }
    if not $image_exists {
        print "Building selftest image..."
        ^podman build -t localhost/selftest ($repo_dir | path join 'bin/containers/selftest')
    }
    ^podman run --rm -it -w /dotfiles -v $"($env.PWD):/dotfiles:Z" localhost/selftest bash -c "nu -c 'use toolkit.nu; toolkit bootstrap' || bash"
}

export def pi [...args] {
    let image_exists = try { podman image exists localhost/pi; true } catch { false }
    if not $image_exists {
        print "Building pi image..."
        ^podman build -t localhost/pi ($repo_dir | path join 'bin/containers/pi')
    }
    ^podman run --rm -it -e ANTHROPIC_API_KEY -v $"($env.PWD):/workspace" -v pi-agent-home:/root/.pi/agent localhost/pi ...$args
}

