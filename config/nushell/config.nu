# https://github.com/nushell/nushell/blob/main/crates/nu-config/default_files/default_config.nu

$env.NU_LIB_DIRS = ["~/src/dotfiles/config/nushell/src"]

# cog -r config.nu
#
# [[[cog
# import cog
# import os, glob
# from pathlib import Path
# nu_files = sorted(Path(x) for x in glob.glob('src/*.nu') if not Path(x).name.startswith("os-"))
# for file in nu_files:
#     this_repo = Path("~/src/dotfiles/config/nushell")
#     cog.outl(f"use {this_repo / file} *".replace('\\', '/'))
# ]]]*/
use ~/src/dotfiles/config/nushell/src/ai.nu *
use ~/src/dotfiles/config/nushell/src/arr.nu *
use ~/src/dotfiles/config/nushell/src/ado-completions.nu *
use ~/src/dotfiles/config/nushell/src/broot.nu *
use ~/src/dotfiles/config/nushell/src/cargo-completions.nu *
use ~/src/dotfiles/config/nushell/src/clipboard.nu *
use ~/src/dotfiles/config/nushell/src/config-runtime.nu *
use ~/src/dotfiles/config/nushell/src/docs.nu * # NOTE: a bit slow
use ~/src/dotfiles/config/nushell/src/fd-completions.nu *
use ~/src/dotfiles/config/nushell/src/zellij-status.nu *
use ~/src/dotfiles/config/nushell/src/zig-completions.nu *
# use ~/src/dotfiles/config/nushell/src/flamegraph-completions.nu *
# use ~/src/dotfiles/config/nushell/src/fnm.nu *
# use ~/src/dotfiles/config/nushell/src/history-utils.nu *
# use ~/src/dotfiles/config/nushell/src/hosts-completions.nu *
use ~/src/dotfiles/config/nushell/src/just-completions.nu *
# use ~/src/dotfiles/config/nushell/src/man.nu *
use ~/src/dotfiles/config/nushell/src/maxmsp-completions.nu *
use ~/src/dotfiles/config/nushell/src/media-completions.nu *
use ~/src/dotfiles/config/nushell/src/miniserve-completions.nu *
use ~/src/dotfiles/config/nushell/src/my-functions.nu *
use ~/src/dotfiles/config/nushell/src/git-aliases.nu *
use ~/src/dotfiles/config/nushell/src/git-completions.nu *
use ~/src/dotfiles/config/nushell/src/git-tools.nu *
use ~/src/dotfiles/config/nushell/src/ouch-completions.nu *
use ~/src/dotfiles/config/nushell/src/podman-completions.nu *
use ~/src/dotfiles/config/nushell/src/pueue-completions.nu *
use ~/src/dotfiles/config/nushell/src/reverse-eng.nu *
use ~/src/dotfiles/config/nushell/src/rg-completions.nu *
use ~/src/dotfiles/config/nushell/src/rust.nu *
use ~/src/dotfiles/config/nushell/src/rustup-completions.nu *
use ~/src/dotfiles/config/nushell/src/ssh-completions.nu *
use ~/src/dotfiles/config/nushell/src/symlinks.nu *
use ~/src/dotfiles/config/nushell/src/watchexec-completions.nu *

# use ~/src/dotfiles/config/nushell/src/vpn.nu *
# [[[end]]]

# https://www.nushell.sh/blog/2024-12-04-configuration_preview.html
#
# Finding overridden values
#
# let defaults = nu -n -c "$env.config = {}; $env.config | reject color_config keybindings menus | to nuon" | from nuon | transpose key default
# let current = $env.config | reject color_config keybindings menus | transpose key current
# $current | merge $defaults | where $it.current != $it.default

# learning about configuration options
# config nu --default  | nu-highlight

$env.config.show_banner = false
# $env.config.buffer_editor = ["nvim" "-u" "~/src/kickstart.nvim/minimal-vimrc.vim"]
$env.config.buffer_editor = ["nvim"]
$env.config.shell_integration.osc7 = true
$env.config.shell_integration.osc133 = false # causing autoscrolling issues
# https://www.nushell.sh/book/custom_completions.html
# $env.config.completions.algorithm = "prefix"
$env.config.completions.algorithm = "fuzzy"
$env.config.table.header_on_separator = true

$env.config.history = {
    file_format: sqlite
    max_size: 1_000_000
    sync_on_enter: true
    isolation: true
}

$env.config.cursor_shape = {
    # block, underscore, line, blink_block, blink_underscore, blink_line, inherit to skip setting cursor shape
    emacs: line
    vi_insert: line
    vi_normal: underscore
}

$env.config.edit_mode = "vi"

# Project hooks have one owner; env.nu only initializes fnm's environment.
# Trust is exact-directory and defaults to an empty persistent allowlist.
def "env-change pwd toolkit" [--directory] {
    {
        condition: (if $directory {
            {|_, after| (project is-trusted $after) and ($after | path join 'toolkit' 'mod.nu' | path exists) }
        } else {
            {|_, after| (project is-trusted $after) and ($after | path join 'toolkit.nu' | path exists) }
        })
        code: ([
            "print -n $'(ansi defu)(ansi defb)toolkit(ansi reset) module (ansi yi)detected(ansi reset)... '"
            $"use (if $directory { 'toolkit/' } else { 'toolkit.nu' })"
            "print $'(ansi gb)activated!(ansi reset)'"
        ] | str join "\n")
    }
}

# Preserve third-party hooks; replace only entries tagged as ours on re-source.
$env.config.hooks.env_change.PWD = (
    $env.config.hooks.env_change.PWD? | default []
    | where {|hook| not ($hook.__dotfiles_hook? | default false) }
    | append ([
        # Drop the previous project's env overlay before loading another one.
        {
            condition: {|| (overlay list | where active and name == 'project-env' | is-not-empty) }
            code: 'overlay hide project-env'
        }
        (env-change pwd toolkit)
        (env-change pwd toolkit --directory)
        {
            condition: {|_, after| (project is-trusted $after) and ($after | path join env.nu | path exists) }
            code: "overlay use env.nu as project-env"
        }
        {
            condition: {|_, after| (
                ($env.FNM_MULTISHELL_PATH? != null)
                and (project is-trusted $after)
                and (['.nvmrc' '.node-version' 'package.json'] | any {|file| $after | path join $file | path exists })
            ) }
            code: {|| ^fnm use --install-if-missing --silent-if-unchanged }
        }
        { code: {|_, after| project sync-path $after } }
    ] | each {|hook| $hook | insert __dotfiles_hook true })
)

# Also clear stale Rust paths after re-sourcing or restarting in another directory.
project sync-path $env.PWD

# OSC 133 semantic prompt marks (read by zellij for the inbox: done/failed commands).
# Emitted by hand because the built-in `shell_integration.osc133` causes autoscroll issues.
def osc133 [mark: string] {
    print -n $"\e]133;($mark)\e\\"
}

# These hooks are owned by this file and assigned (not appended), so re-sourcing
# config.nu does not stack duplicate emitters.
$env.config.hooks.pre_execution = [
    {||
        osc7501 "working"
        osc133 "C"
    }
]

# Single prompt hook. Order matters: D (command finished + status) before A (new prompt).
$env.config.hooks.pre_prompt = [
    {||
        let ran = ($env.CMD_DURATION_MS? != null)
        let code = $env.LAST_EXIT_CODE? | default 0
        if $ran { osc133 $"D;($code)" }
        osc133 "A"
        # pane title = zellij pane id, refreshed at each prompt
        print -n $"\e]0;pane ($env.ZELLIJ_PANE_ID? | default '-') ($env.PWD | path basename)\e\\"
        if $ran {
            if $code == 0 { osc7501 "done" } else { osc7501 "error" }
        } else {
            osc7501 "idle"
        }
    }
]

# Remove our own entries before appending, without replacing Nu's default menus.
$env.config.menus = ($env.config.menus | where {|menu| $menu.name != abbr_menu })
$env.config.menus ++= [
    {
        name: abbr_menu
        only_buffer_difference: false
        marker: "👀 "
        type: {
            layout: columnar
            columns: 1
            col_width: 20
            col_padding: 2
        }
        style: {text: green, selected_text: green_reverse, description_text: yellow}
        source: {|token|
            scope aliases
            | where name == $token.text
            | each {|elt| {value: $elt.expansion }}
        }
    }
]

# The default config record. This is where much of your global configuration is setup.
#
# https://www.nushell.sh/book/line_editor.html#vi-normal-actions
# keycodes: none control alt shift shift_alt alt_shift control_alt alt_control control_shift shift_control control_alt_shift control_shift_alt
const dotfiles_binding_names = [
    abbr fzf_files find_file_and_edit open_editor go_Up_to_root_dir
    jump_to_subdir jump_to_project fuzzy_module
]
$env.config.keybindings = (
    $env.config.keybindings | where {|binding| $binding.name not-in $dotfiles_binding_names }
)
$env.config.keybindings ++= [
    # https://www.nushell.sh/blog/2024-05-15-top-nushell-hacks.html
    {
        name: abbr
        modifier: control
        keycode: space
        mode: [emacs, vi_normal, vi_insert]
        event: [
            {send: menu, name: abbr_menu}
            {edit: insertchar, value: ' '}
        ]
    }
    {
        name: fzf_files
        modifier: control
        keycode: char_t
        mode: [emacs, vi_normal, vi_insert]
        event: [
            {
                send: executehostcommand
                cmd: "pick file insert"
            }
        ]
    }
    {
        name: find_file_and_edit
        modifier: control
        keycode: char_f
        mode: [emacs, vi_normal, vi_insert]
        event: {send: executehostcommand, cmd: "nvim '+FFFFind'"}
    }
    {
        name: open_editor
        modifier: alt
        keycode: char_g # pi uses same keybind
        mode: [vi_normal, vi_insert]
        event: {send: OpenEditor}
    }
    {
        name: go_Up_to_root_dir
        modifier: alt
        keycode: char_u
        mode: [emacs, vi_normal, vi_insert]
        event: {send: executehostcommand, cmd: "cdroot"}
    }
    {
        name: jump_to_subdir
        modifier: alt
        keycode: char_c
        mode: [emacs, vi_normal, vi_insert]
        event: [
            {
                send: executehostcommand
                cmd: "pick directory"
            }
        ]
    }
    {
        name: jump_to_project
        modifier: alt_shift
        keycode: char_c
        mode: [emacs, vi_normal, vi_insert]
        event: {send: executehostcommand, cmd: 'goto'}
    }
    {
        # nu_scripts/custom-menus/fuzzy/modules.nu
        name: fuzzy_module
        modifier: control
        keycode: char_u
        mode: [emacs, vi_normal, vi_insert]
        event: {
            send: executehostcommand
            cmd: 'pick module'
        }
    }

    # NOTE: clunky, doesn't work nicely with multiline
    # {
    #     # nu_scripts/custom-menus/fuzzy/history.nu
    #     name: fuzzy_history
    #     modifier: control
    #     keycode: char_h
    #     mode: [emacs, vi_normal, vi_insert]
    #     event: {
    #         send: executehostcommand
    #         cmd: "commandline edit --insert (
    #         history
    #         | each { |it| $it.command }
    #         | uniq
    #         | reverse
    #         | input list --fuzzy
    #         $'Please choose a (ansi magenta)command from history(ansi reset):'
    #         )"
    #     }
    # }
]

# cargo binstall starship
# mkdir ~/.cache/starship
# starship init nu | save -f ~/.cache/starship/init.nu
# https://starship.rs/guide/
#
# mkdir ($nu.data-dir | path join "vendor/autoload")
# starship init nu | save -f ($nu.data-dir | path join "vendor/autoload/starship.nu")

source ~/src/dotfiles/config/nushell/src/os-this-machine.nu

const ctrl_bindings = [
    $"insert (ansi rb)t(ansi reset)arget, edit (ansi rb)f(ansi reset)ile"
    $"(ansi rb)j(ansi reset)ump"
    $"(ansi rb)u(ansi reset)se \(fuzzy\)"
    $"(ansi rb)space(ansi reset) \(expands alias\)"
]
source ~/src/dotfiles/config/.zoxide.nu

# print $"(ansi defb)ctrl-i(ansi reset): (ansi defr)TAB(ansi reset), (ansi defb)ctrl-m(ansi reset): (ansi defr)ENTER(ansi reset), (ansi defb)ctrl-[(ansi reset): (ansi defr)ESC(ansi reset)"
print $"(ansi rb)ctrl(ansi reset): ($ctrl_bindings | str join ', ')"

# right prompt: zellij pane id next to the date
$env.PROMPT_COMMAND_RIGHT = {||
    let pane = $env.ZELLIJ_PANE_ID? | default "-"
    $"(ansi grey)pane ($pane)  (date now | format date '%a %Y-%m-%d %H:%M')(ansi reset)"
}
