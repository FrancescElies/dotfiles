# Run: nu --no-config-file config/nushell/tests/runtime.nu
use std/assert
use ../src/config-runtime.nu *

const runtime_module = path self | path dirname | path join ../src/config-runtime.nu | path expand
let original_directory = pwd
let temp = mktemp --directory
$env.DOTFILES_PROJECT_TRUST_FILE = $temp | path join trusted-projects.nuon
let project = $temp | path join project
let child = $project | path join child
let other = $temp | path join other
mkdir $child $other
'' | save ($project | path join Cargo.lock)
'' | save ($other | path join Cargo.lock)

try {
    assert equal (project trusted) []
    assert equal (project is-trusted $project) false
    project trust $project
    project trust $project
    assert equal (project trusted | length) 1
    assert equal (project is-trusted $project) true
    assert equal (project is-trusted $child) false
    assert equal (project is-trusted $other) false
    assert equal (project is-trusted ($temp | path join missing)) false

    # Repeated visits do not duplicate additions; pre-existing paths survive.
    let preexisting = $project | path join target/debug | path expand
    let baseline = [$preexisting ($temp | path join bin)]
    # Match env.nu's top-level cleanup for mixed-case Windows PATH keys.
    let aliases = $env | columns | where {|name| ($name | str lowercase) == path and $name != PATH }
    for name in $aliases { hide-env $name }
    $env.PATH = $baseline
    project sync-path $project
    assert equal ($env.PATH | length) 5
    let first = $env.PATH
    project sync-path $project
    assert equal $env.PATH $first
    let child_code = $"use (nu quote-path $runtime_module) *; project sync-path (nu quote-path $child); $env.PATH | to json --raw"
    let child_path = ^$nu.current-exe --no-config-file -c $child_code | from json
    assert equal $child_path $baseline
    project sync-path $child
    assert equal $env.PATH $baseline
    project trust $other
    project sync-path $other
    assert equal ($env.PATH | length) 6
    project sync-path $project
    assert equal $env.PATH $first
    project untrust $project
    project sync-path $project
    assert equal $env.PATH $baseline
    assert equal (project is-trusted $project) false

    # Corrupt/maliciously typed trust data must never authorize loading code.
    '[1]' | save --force $env.DOTFILES_PROJECT_TRUST_FILE
    assert equal (project is-trusted $other) false
    'not valid nuon {' | save --force $env.DOTFILES_PROJECT_TRUST_FILE
    assert equal (project is-trusted $other) false

    let before = pwd
    cd selected null
    assert equal (pwd) $before
    cd selected ''
    assert equal (pwd) $before
    cd selected $child
    assert equal (pwd | path expand) ($child | path expand)
    cd $before

    # Parse the generated literal with a fresh Nu, not merely a JSON parser.
    # Use the executable's absolute path because PATH is intentionally isolated.
    for value in [
        'a b'
        r#'C:\files\some project\file.txt'#
        r#'single\' and "double" quotes'#
        r#'dollar$and(parentheses)[brackets]'#
        "line\nbreak"
        "tab\there"
        "escape\u{001b}here"
        "end'#and'##and'###"
    ] {
        let literal = nu quote-path $value
        let result = ^$nu.current-exe --no-config-file -c $"($literal) | to json --raw" | from json
        assert equal $result $value
    }
    print 'runtime tests passed'
} catch {|err|
    print --stderr $err.rendered
    cd $original_directory
    rm --recursive --force $temp
    error make {msg: $err.msg}
}
rm --recursive --force $temp
