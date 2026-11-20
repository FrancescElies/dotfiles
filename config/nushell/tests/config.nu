# Run using the actual environment and config:
# nu --env-config config/nushell/env.nu --config config/nushell/config.nu --interactive config/nushell/tests/config.nu
use std/assert

$env.config.hooks.env_change.TEST_SENTINEL = []
$env.config.hooks.env_change.PWD ++= [{__test_hook: true, code: {|| null }}]
source ../config.nu
source ../config.nu

let names = [abbr fzf_files find_file_and_edit open_editor go_Up_to_root_dir jump_to_subdir jump_to_project fuzzy_module]
let bindings = $env.config.keybindings | where {|binding| $binding.name in $names }
assert equal ($bindings | length) 8
assert equal ($bindings | uniq-by name | length) 8
assert equal ($bindings | where name == go_Up_to_root_dir | get 0.modifier) alt
assert equal ($bindings | where name == fuzzy_module | get 0.modifier) control
assert equal ($env.config.menus | where name == abbr_menu | length) 1
assert equal ($env.config.hooks.env_change.PWD | where {|hook| $hook.__dotfiles_hook? | default false } | length) 6
assert equal ($env.config.hooks.env_change.PWD | where {|hook| $hook.__test_hook? | default false } | length) 1
assert equal $env.config.hooks.env_change.TEST_SENTINEL []
assert equal ($env | columns | where {|name| ($name | str lowercase) == path } | length) 1
assert equal ($env.PATH | where {|entry| $entry starts-with '~' } | length) 0
assert equal ($env.PATH | length) ($env.PATH | uniq | length)
# Nu's Tab and Shift+Tab defaults have not been removed.
assert ($env.config.keybindings | any {|binding| $binding.keycode == tab })
let max_versions = 'Max use ' | commandline complete --detailed | get value
assert ('921' in $max_versions)

let original_directory = pwd
let temp = mktemp --directory
$env.DOTFILES_PROJECT_TRUST_FILE = $temp | path join trusted-projects.nuon
$env.FNM_MULTISHELL_PATH = $temp
let project = $temp | path join project
let child = $project | path join child
mkdir $child ($project | path join toolkit)
"export-env { $env.DOTFILES_TEST_ENV_LOADED = 'yes' }" | save ($project | path join env.nu)
'' | save ($project | path join toolkit.nu)
'' | save ($project | path join toolkit/mod.nu)
'' | save ($project | path join package.json)
try {
    let hooks = $env.config.hooks.env_change.PWD | where {|hook| $hook.__dotfiles_hook? | default false }
    for index in [1 2 3 4] {
        let condition = $hooks | get $index | get condition
        assert equal (do $condition null $project) false
    }
    project trust $project
    for index in [1 2 3 4] {
        let condition = $hooks | get $index | get condition
        assert equal (do $condition null $project) true
        assert equal (do $condition null $child) false
    }
    let cleanup = $hooks | first
    assert equal (do $cleanup.condition) false
    let load = $hooks | get 3.code
    let script = $"($load)\nprint $env.DOTFILES_TEST_ENV_LOADED\n($cleanup.code)\nprint \($env.DOTFILES_TEST_ENV_LOADED? == null\)"
    cd $project
    let result = ^$nu.current-exe --no-config-file -c $script | lines
    assert equal $result [yes 'true']
    cd $original_directory
    print 'config tests passed'
} catch {|err|
    print --stderr $err.rendered
    cd $original_directory
    rm --recursive --force $temp
    error make {msg: $err.msg}
}
rm --recursive --force $temp
