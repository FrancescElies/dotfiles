# https://github.com/nushell/nushell/blob/main/crates/nu-utils/src/default_files/default_env.nu

# Nushell Environment Config File
#

match $nu.os-info.name {
    "windows" => {
        $env.HOME = ('~' | path expand)
        $env.path ++= [
            '~/AppData/Local/bob/nvim-bin'
            '~/AppData/Roaming/Python/Python312/Scripts'
            '~/AppData/Roaming/Python/Scripts'
            ('/Program Files/WinHTTrack' | path expand)
            ('/Program Files/Neovim/bin' | path expand)
            ('/Program Files/WIBU-SYSTEMS/AxProtector/Devkit/bin' | path expand)
            ('/Program Files/CodeMeter/DevKit/bin' | path expand)
            ('/Program Files/LLVM/bin' | path expand)
            ('/Program Files/nodejs' | path expand)
            ("/Program Files/Cycling '74/Max 9" | path expand)
        ]
    },
    "macos" => {
        $env.path ++= [
            '/opt/homebrew/bin'
            '/usr/local/bin'
            '~/Library/Python/3.12/bin'
        ]
    },
    "linux" => {
        $env.path ++= [
            '/home/linuxbrew/.linuxbrew/bin'
            '/usr/local/bin'
            '/usr/local/go/bin'
            '/var/lib/flatpak/exports/share'
            '~/.local/share/bob/nvim-bin'
            "~/.rye/shims"
            '~/.local/share/flatpak/exports/share'
        ]
    },
    _ => { $env.path = $env.path },
}

# common paths
$env.path ++= [
    '~/.zvm/bin'
    '~/.zvm/self'
    '~/src/radare2/prefix/bin'
    '~/go/bin'
    '~/.cargo/bin'
    # pipx puts binaries in .local/bin
    '~/.local/bin'
    '~/bin'
]
try { $env.path ++= ( ls ~/bin | where type == dir | get name ) }
try { $env.path ++= ( ls ~/bin/*/bin | get name ) }
try { $env.path ++= ( ls /usr/local/*/bin | get name ) }

$env.path = ( $env.path | uniq )


$env.SHELL = "nu"  # makes broot open nu
$env.EDITOR = "nvim"
$env.MANPAGER = "nvim +Man!"
# $env.MANPAGER = "nvim -u NORC --clean +Man!"  # faster man pager

$env.PYTHONUNBUFFERED = 1
$env.PYTHONBREAKPOINT = "ipdb.set_trace"
$env.RIPGREP_CONFIG_PATH  = ("~/src/dotfiles/config/nushell/src/.ripgreprc" | path expand)

$env.BR_INSTALL = "no"
$env.BROOT_CONFIG_DIR = ("~/src/dotfiles/config/nushell/broot-config" | path expand)

$env.FZF_DEFAULT_COMMAND = "fd --type file --hidden"

$env.RUST_BACKTRACE = 1
$env.RUSTC_WRAPPER = 'sccache'

$env.RESTIC_PASSWORD_COMMAND = 'secret-tool lookup service restic'

touch ~/.nu-start-dir
# HACK: for alacritty, make we don't auto switch folders when using nvim's terminal
if ($env.NVIM? | is-empty) {
    print $"(ansi def)changed dir using .nu-start-dir(ansi reset)"
    try { cd ( open ~/.nu-start-dir ) } catch { cd ~ }
}
